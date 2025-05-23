#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ExaPG Backup-Metrik-Exporter für Prometheus
Sammelt Metriken über Backups und WAL-Archive für Prometheus
"""

import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('backup-metrics')

# Standardwerte
PGBACKREST_CONFIG = os.environ.get('PGBACKREST_CONFIG', '/etc/pgbackrest/pgbackrest.conf')
PGBACKREST_STANZA = os.environ.get('PGBACKREST_STANZA', 'exapg')
METRICS_FILE = os.environ.get('METRICS_FILE', '/var/lib/verification-data/metrics.txt')
METRICS_PORT = int(os.environ.get('METRICS_PORT', '9187'))
UPDATE_INTERVAL = int(os.environ.get('METRICS_UPDATE_INTERVAL', '900'))  # 15 Minuten

# Metriken-Dictionary
metrics = {
    'pgbackrest_last_backup_time': 0,
    'pgbackrest_last_backup_age_seconds': 0,
    'pgbackrest_backup_size_bytes': 0,
    'pgbackrest_backup_count_total': 0,
    'pgbackrest_backup_count_full': 0,
    'pgbackrest_backup_count_diff': 0,
    'pgbackrest_backup_count_incr': 0,
    'pgbackrest_wal_segments_total': 0,
    'pgbackrest_backup_success': 0,
    'pgbackrest_archive_success': 0,
    'pgbackrest_backup_duration_seconds': 0,
    'pgbackrest_repo_size_bytes': 0,
    'pgbackrest_stanza_status': 0,  # 0=problem, 1=OK
    'pgbackrest_validation_status': 0  # 0=failed, 1=success
}

def run_command(cmd):
    """Führt einen Shell-Befehl aus und gibt Ausgabe und Rückgabecode zurück"""
    try:
        logger.debug(f"Führe Befehl aus: {cmd}")
        process = subprocess.Popen(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
        )
        stdout, stderr = process.communicate()
        return stdout, stderr, process.returncode
    except Exception as e:
        logger.error(f"Fehler bei Befehlsausführung: {e}")
        return "", str(e), 1

def collect_backup_metrics():
    """Sammelt Metriken über pgBackRest-Backups"""
    global metrics
    
    cmd = f"pgbackrest --config={PGBACKREST_CONFIG} --stanza={PGBACKREST_STANZA} info --output=json"
    stdout, stderr, returncode = run_command(cmd)
    
    if returncode != 0:
        logger.error(f"Fehler beim Abrufen der Backup-Informationen: {stderr}")
        metrics['pgbackrest_stanza_status'] = 0
        return
    
    try:
        info = json.loads(stdout)
        if not info:
            logger.warning("Keine Stanza-Informationen gefunden")
            metrics['pgbackrest_stanza_status'] = 0
            return
            
        stanza_info = info[0]  # Erste Stanza
        metrics['pgbackrest_stanza_status'] = 1
        
        # Backup-Informationen
        if 'backup' in stanza_info and stanza_info['backup']:
            # Backup-Zähler zurücksetzen
            metrics['pgbackrest_backup_count_total'] = len(stanza_info['backup'])
            metrics['pgbackrest_backup_count_full'] = 0
            metrics['pgbackrest_backup_count_diff'] = 0
            metrics['pgbackrest_backup_count_incr'] = 0
            
            # Neuestes Backup
            latest_backup = stanza_info['backup'][0]
            
            # Backup-Zeit in Unix-Timestamp
            backup_time = datetime.strptime(latest_backup['timestamp']['start'], "%Y-%m-%dT%H:%M:%S")
            metrics['pgbackrest_last_backup_time'] = int(backup_time.timestamp())
            
            # Alter des neuesten Backups in Sekunden
            backup_age = (datetime.now() - backup_time).total_seconds()
            metrics['pgbackrest_last_backup_age_seconds'] = int(backup_age)
            
            # Backup-Größe
            if 'info' in latest_backup and 'size' in latest_backup['info']:
                metrics['pgbackrest_backup_size_bytes'] = latest_backup['info']['size']
            
            # Backup-Dauer
            if 'timestamp' in latest_backup and 'stop' in latest_backup['timestamp']:
                start_time = datetime.strptime(latest_backup['timestamp']['start'], "%Y-%m-%dT%H:%M:%S")
                stop_time = datetime.strptime(latest_backup['timestamp']['stop'], "%Y-%m-%dT%H:%M:%S")
                duration = (stop_time - start_time).total_seconds()
                metrics['pgbackrest_backup_duration_seconds'] = int(duration)
            
            # Zähle verschiedene Backup-Typen
            for backup in stanza_info['backup']:
                if backup['type'] == 'full':
                    metrics['pgbackrest_backup_count_full'] += 1
                elif backup['type'] == 'diff':
                    metrics['pgbackrest_backup_count_diff'] += 1
                elif backup['type'] == 'incr':
                    metrics['pgbackrest_backup_count_incr'] += 1
        else:
            logger.warning("Keine Backups in der Stanza gefunden")
            # Setze Zeit- und Größenmetriken auf 0
            metrics['pgbackrest_last_backup_time'] = 0
            metrics['pgbackrest_last_backup_age_seconds'] = 0
            metrics['pgbackrest_backup_size_bytes'] = 0
            metrics['pgbackrest_backup_duration_seconds'] = 0
        
        # WAL-Archiv-Informationen
        if 'archive' in stanza_info:
            # Anzahl der WAL-Segmente schätzen
            min_wal = stanza_info['archive'].get('min')
            max_wal = stanza_info['archive'].get('max')
            
            if min_wal and max_wal:
                # Extrahiere die hexadezimalen Teile
                try:
                    min_parts = min_wal.split('/')
                    max_parts = max_wal.split('/')
                    
                    if len(min_parts) >= 2 and len(max_parts) >= 2:
                        wal_min_num = int(min_parts[1], 16)
                        wal_max_num = int(max_parts[1], 16)
                        metrics['pgbackrest_wal_segments_total'] = wal_max_num - wal_min_num + 1
                except (ValueError, IndexError) as e:
                    logger.error(f"Fehler beim Parsen der WAL-Segment-Nummern: {e}")
        
        # Repository-Größe
        if 'db' in stanza_info and stanza_info['db']:
            db_info = stanza_info['db'][0]  # Erste DB
            if 'repo' in db_info and 'size' in db_info['repo']:
                metrics['pgbackrest_repo_size_bytes'] = db_info['repo']['size']
        
        # Stanza-Status
        metrics['pgbackrest_backup_success'] = 1  # Annahme: OK, wenn Info abrufbar ist
        
    except Exception as e:
        logger.error(f"Fehler beim Verarbeiten der Backup-Informationen: {e}")
        metrics['pgbackrest_stanza_status'] = 0

def collect_validation_metrics():
    """Sammelt Metriken über die Validierung der Backups"""
    global metrics
    
    # Überprüfe, ob eine Validierungsdatei existiert und lese den neuesten Status
    try:
        validation_file = '/var/lib/verification-data/latest.json'
        if os.path.exists(validation_file):
            with open(validation_file, 'r') as f:
                validation_data = json.load(f)
                
                # Setze Validierungsstatus basierend auf 'success'-Feld
                metrics['pgbackrest_validation_status'] = 1 if validation_data.get('success', False) else 0
        else:
            # Wenn keine Datei existiert, keine Änderung am Standardwert vornehmen
            logger.debug("Keine Validierungsdatei gefunden")
    except Exception as e:
        logger.error(f"Fehler beim Lesen der Validierungsergebnisse: {e}")

def write_metrics_file():
    """Schreibt die Metriken in eine Datei für Prometheus Node Exporter Textfile Collector"""
    try:
        with open(METRICS_FILE, 'w') as f:
            timestamp = int(time.time())
            
            # Stanza-Label für alle Metriken hinzufügen
            stanza_label = f'stanza="{PGBACKREST_STANZA}"'
            
            for name, value in metrics.items():
                f.write(f"{name}{{{stanza_label}}} {value} {timestamp}000\n")
        
        logger.info(f"Metriken wurden in {METRICS_FILE} geschrieben")
    except Exception as e:
        logger.error(f"Fehler beim Schreiben der Metriken-Datei: {e}")

class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP-Handler für Prometheus-Metriken"""
    
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            
            # Stanza-Label für alle Metriken
            stanza_label = f'stanza="{PGBACKREST_STANZA}"'
            
            # Aktuelle Metriken ausgeben
            for name, value in metrics.items():
                self.wfile.write(f"{name}{{{stanza_label}}} {value}\n".encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

def metrics_server():
    """Startet einen HTTP-Server für Prometheus-Metriken"""
    server = HTTPServer(('0.0.0.0', METRICS_PORT), MetricsHandler)
    logger.info(f"Metriken-Server gestartet auf Port {METRICS_PORT}")
    server.serve_forever()

def update_metrics_loop():
    """Aktualisiert die Metriken regelmäßig"""
    while True:
        try:
            collect_backup_metrics()
            collect_validation_metrics()
            write_metrics_file()
        except Exception as e:
            logger.error(f"Fehler bei der Metrikenaktualisierung: {e}")
        
        time.sleep(UPDATE_INTERVAL)

def main():
    """Hauptfunktion"""
    # Initialisiere Metriken
    collect_backup_metrics()
    collect_validation_metrics()
    write_metrics_file()
    
    # Wenn als Dienst gestartet, führe Dauerschleife aus
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        # Starte Metriken-Server in einem Thread
        server_thread = threading.Thread(target=metrics_server)
        server_thread.daemon = True
        server_thread.start()
        
        # Starte Update-Schleife
        update_metrics_loop()
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 