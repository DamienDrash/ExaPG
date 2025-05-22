#!/usr/bin/env python3
# ExaPG - Update Backends
# Aktualisiert die pgBouncer-Backend-Konfiguration basierend auf dem Patroni-Status in etcd

import os
import sys
import time
import json
import logging
import subprocess
import etcd3
import psycopg2
from datetime import datetime

# Konfiguration
ETCD_HOST = os.environ.get('ETCD_HOST', 'etcd')
ETCD_PORT = int(os.environ.get('ETCD_PORT', '2379'))
PGBOUNCER_CONFIG = '/etc/pgbouncer/pgbouncer.ini'
PGBOUNCER_PORT = int(os.environ.get('PGBOUNCER_LISTEN_PORT', '6432'))
LOG_FILE = '/var/log/pgbouncer/update-backends.log'

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename=LOG_FILE,
    filemode='a'
)
logger = logging.getLogger('update-backends')

def get_patroni_leaders():
    """Ermittelt die aktuellen Patroni-Leader über etcd"""
    leaders = {}
    
    try:
        # Verbindung zu etcd herstellen
        etcd = etcd3.client(host=ETCD_HOST, port=ETCD_PORT)
        
        # Cluster-Scopes
        scopes = ['exapg-coordinator', 'exapg-worker-1', 'exapg-worker-2']
        
        for scope in scopes:
            key = f'/service/{scope}/leader'
            result = etcd.get(key)
            
            if result[0]:
                leader_data = json.loads(result[0].decode('utf-8'))
                leader_name = leader_data.get('name')
                leaders[scope] = leader_name
                logger.info(f"Leader für {scope}: {leader_name}")
            else:
                logger.warning(f"Kein Leader für {scope} gefunden")
        
        return leaders
    
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Leader: {e}")
        # Fallback: Shell-Skript verwenden
        return get_leaders_from_script()

def get_leaders_from_script():
    """Fallback-Methode, die das Shell-Skript zum Ermitteln der Leader verwendet"""
    leaders = {}
    
    try:
        for scope in ['exapg-coordinator', 'exapg-worker-1', 'exapg-worker-2']:
            cmd = ['/scripts/get-primary.sh', scope]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            if result.stdout.strip():
                leaders[scope] = result.stdout.strip()
                logger.info(f"Leader für {scope} (via Skript): {leaders[scope]}")
    
    except Exception as e:
        logger.error(f"Fehler beim Ausführen des get-primary-Skripts: {e}")
    
    return leaders

def update_pgbouncer_config(leaders):
    """Aktualisiert die pgBouncer-Konfiguration mit den aktuellen Leaders"""
    if not leaders.get('exapg-coordinator'):
        logger.error("Kein Coordinator-Leader verfügbar, überspringe Update")
        return False
    
    coordinator = leaders['exapg-coordinator']
    worker1 = leaders.get('exapg-worker-1', 'nicht verfügbar')
    worker2 = leaders.get('exapg-worker-2', 'nicht verfügbar')
    
    # Temporäre Konfigurationsdatei erstellen
    temp_config = f"{PGBOUNCER_CONFIG}.tmp"
    
    try:
        # Aktuelle Konfiguration lesen
        with open(PGBOUNCER_CONFIG, 'r') as f:
            config_lines = f.readlines()
        
        # Neue Konfiguration erstellen
        new_config = []
        in_databases_section = False
        section_replaced = False
        
        for line in config_lines:
            if line.strip() == '[databases]':
                in_databases_section = True
                new_config.append('[databases]\n')
                new_config.append(f'* = host={coordinator} port=5432 dbname=postgres\n')
                section_replaced = True
            elif in_databases_section and line.strip().startswith('['):
                in_databases_section = False
                new_config.append('\n')
                new_config.append(line)
            elif not in_databases_section:
                new_config.append(line)
        
        # Füge Kommentare hinzu
        new_config.append(f'\n# Automatisch aktualisiert: {datetime.now()}\n')
        new_config.append(f'# Coordinator: {coordinator}\n')
        new_config.append(f'# Worker 1: {worker1}\n')
        new_config.append(f'# Worker 2: {worker2}\n')
        
        # Schreibe die neue Konfiguration
        with open(temp_config, 'w') as f:
            f.writelines(new_config)
        
        # Prüfe, ob es Änderungen gibt
        has_changes = False
        try:
            result = subprocess.run(['diff', '-q', PGBOUNCER_CONFIG, temp_config], capture_output=True)
            has_changes = result.returncode != 0
        except:
            # Wenn diff fehlschlägt, nehmen wir an, dass es Änderungen gibt
            has_changes = True
        
        if has_changes:
            # Konfiguration aktualisieren
            os.rename(temp_config, PGBOUNCER_CONFIG)
            logger.info(f"PgBouncer-Konfiguration aktualisiert mit Coordinator: {coordinator}")
            
            # PgBouncer neu laden
            try:
                reload_pgbouncer()
                logger.info("PgBouncer neu geladen")
                return True
            except Exception as e:
                logger.error(f"Fehler beim Neuladen von PgBouncer: {e}")
                return False
        else:
            logger.info("Keine Änderungen an der PgBouncer-Konfiguration erforderlich")
            os.remove(temp_config)
            return True
    
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der PgBouncer-Konfiguration: {e}")
        return False

def reload_pgbouncer():
    """Lädt PgBouncer neu"""
    try:
        # Zunächst versuchen wir, über psql die RELOAD-Anweisung zu senden
        conn = psycopg2.connect(
            host='localhost',
            port=PGBOUNCER_PORT,
            user='postgres',
            database='pgbouncer'
        )
        conn.autocommit = True
        
        with conn.cursor() as cur:
            cur.execute('RELOAD;')
        
        conn.close()
        return True
    
    except Exception as e:
        logger.warning(f"Konnte PgBouncer nicht über psql neu laden: {e}")
        
        # Alternative: Sende SIGHUP an den PgBouncer-Prozess
        try:
            pid = subprocess.check_output(['pidof', 'pgbouncer']).decode().strip()
            if pid:
                subprocess.run(['kill', '-HUP', pid], check=True)
                return True
        except Exception as e:
            logger.error(f"Konnte PgBouncer nicht über Signal neu laden: {e}")
            raise

def main():
    """Hauptfunktion"""
    logger.info("Update-Backends-Service gestartet")
    
    watch_mode = len(sys.argv) > 1 and sys.argv[1] == '--watch'
    
    if watch_mode:
        logger.info("Watch-Modus aktiviert, überwache Änderungen kontinuierlich")
        
        while True:
            leaders = get_patroni_leaders()
            if leaders:
                update_pgbouncer_config(leaders)
            
            time.sleep(10)  # Alle 10 Sekunden prüfen
    
    else:
        logger.info("Einmaliger Modus, aktualisiere PgBouncer-Konfiguration")
        leaders = get_patroni_leaders()
        if leaders:
            update_pgbouncer_config(leaders)

if __name__ == "__main__":
    main() 