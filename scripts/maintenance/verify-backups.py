#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ExaPG Backup-Verifizierung für pgBackRest
Umfassendes Verifizierungsskript für Backup-Integrität und Wiederherstellbarkeit
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import DictCursor

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('backup-verifier')

# Standardwerte
DEFAULT_CONFIG = '/etc/pgbackrest/pgbackrest.conf'
DEFAULT_STANZA = 'exapg'
DEFAULT_TEMP_DIR = '/tmp/restore-test'
ANALYTICAL_TABLES_QUERY = """
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema') 
    AND table_schema NOT LIKE 'pg_%'
    ORDER BY table_schema, table_name
    LIMIT 5
"""

class BackupVerifier:
    def __init__(self, args):
        self.args = args
        self.config = args.config
        self.stanza = args.stanza
        self.temp_dir = args.temp_dir
        self.results = {
            'verification_time': datetime.now().isoformat(),
            'stanza': self.stanza,
            'success': False,
            'checks': [],
            'errors': []
        }
        
        # Metrics für Prometheus
        self.metrics = {
            'backup_verification_success': 0,
            'backup_verification_duration': 0,
            'backup_verification_errors': 0,
            'backup_age_hours': 0,
            'backup_size_mb': 0
        }
        
        # DB Verbindung
        self.db_params = {
            'host': os.environ.get('PGHOST', 'localhost'),
            'port': os.environ.get('PGPORT', '5432'),
            'user': os.environ.get('PGUSER', 'postgres'),
            'password': os.environ.get('PGPASSWORD', 'postgres'),
            'database': os.environ.get('PGDATABASE', 'postgres')
        }
    
    def run_command(self, cmd):
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
    
    def add_check_result(self, name, success, description, details=None):
        """Fügt ein Prüfergebnis hinzu"""
        result = {
            'name': name,
            'success': success,
            'description': description,
            'timestamp': datetime.now().isoformat()
        }
        if details:
            result['details'] = details
        
        self.results['checks'].append(result)
        
        if not success and details:
            self.results['errors'].append(f"{name}: {details}")
    
    def verify_backup_info(self):
        """Prüft, ob Backups existieren und liefert Informationen zurück"""
        logger.info("Prüfe vorhandene Backups...")
        
        cmd = f"pgbackrest --config={self.config} --stanza={self.stanza} info --output=json"
        stdout, stderr, returncode = self.run_command(cmd)
        
        if returncode != 0:
            self.add_check_result(
                'backup_info', False, 
                "Konnte keine Backup-Informationen abrufen", 
                stderr
            )
            return False
        
        try:
            info = json.loads(stdout)
            backup_info = info[0]  # Stanza Info
            
            if not backup_info.get('backup'):
                self.add_check_result(
                    'backup_exists', False,
                    "Keine Backups gefunden für diese Stanza"
                )
                return False
            
            # Neuestes Backup
            latest_backup = backup_info['backup'][0]
            backup_label = latest_backup['label']
            backup_time = datetime.strptime(latest_backup['timestamp']['start'], "%Y-%m-%dT%H:%M:%S")
            backup_age = (datetime.now() - backup_time).total_seconds() / 3600  # Stunden
            
            self.metrics['backup_age_hours'] = backup_age
            
            self.add_check_result(
                'latest_backup', True,
                f"Neuestes Backup gefunden: {backup_label}",
                {
                    'label': backup_label,
                    'type': latest_backup['type'],
                    'time': backup_time.isoformat(),
                    'age_hours': round(backup_age, 1),
                    'size_mb': round(latest_backup['info']['size'] / (1024*1024), 2) if 'info' in latest_backup else "N/A"
                }
            )
            
            # WAL-Archive prüfen
            if 'archive' in backup_info:
                self.add_check_result(
                    'wal_archive', True,
                    "WAL-Archive vorhanden",
                    {
                        'min': backup_info['archive'].get('min'),
                        'max': backup_info['archive'].get('max')
                    }
                )
            else:
                self.add_check_result(
                    'wal_archive', False,
                    "Keine WAL-Archive gefunden"
                )
            
            return True
        except Exception as e:
            logger.error(f"Fehler beim Parsen der Backup-Informationen: {e}")
            self.add_check_result(
                'backup_info_parse', False,
                "Fehler beim Parsen der Backup-Informationen",
                str(e)
            )
            return False
    
    def check_backup_integrity(self):
        """Prüft die Integrität der Backups mit dem pgBackRest-Check-Befehl"""
        logger.info("Prüfe Backup-Integrität...")
        
        cmd = f"pgbackrest --config={self.config} --stanza={self.stanza} check"
        stdout, stderr, returncode = self.run_command(cmd)
        
        success = returncode == 0
        self.add_check_result(
            'backup_integrity', success,
            "Backup-Integritätsprüfung",
            stderr if not success else None
        )
        
        return success
    
    def test_restore(self):
        """Führt einen Test-Restore durch, wenn --full angegeben wurde"""
        if not self.args.full:
            logger.info("Überspringe Test-Restore (nur bei --full aktiviert)...")
            return True
        
        logger.info(f"Führe Test-Restore in temporäres Verzeichnis durch: {self.temp_dir}")
        
        # Temporäres Verzeichnis vorbereiten
        if os.path.exists(self.temp_dir):
            self.run_command(f"rm -rf {self.temp_dir}/*")
        else:
            os.makedirs(self.temp_dir, exist_ok=True)
        
        # Test-Restore durchführen
        cmd = (
            f"pgbackrest --config={self.config} --stanza={self.stanza} "
            f"--delta restore --target-action=pause --target={self.temp_dir}"
        )
        
        start_time = time.time()
        stdout, stderr, returncode = self.run_command(cmd)
        duration = time.time() - start_time
        
        success = returncode == 0
        self.metrics['restore_duration'] = duration
        
        self.add_check_result(
            'test_restore', success,
            "Test-Restore in temporäres Verzeichnis",
            {
                'duration_seconds': round(duration, 1),
                'error': stderr if not success else None
            }
        )
        
        # Prüfe Dateistruktur des wiederhergestellten Verzeichnisses
        if success:
            file_count_cmd = f"find {self.temp_dir} -type f | wc -l"
            file_count, _, _ = self.run_command(file_count_cmd)
            
            self.add_check_result(
                'restore_file_check', True,
                "Überprüfung der wiederhergestellten Dateien",
                {
                    'file_count': file_count.strip()
                }
            )
        
        return success
    
    def test_analytical_query_data(self):
        """Prüft, ob analytische Daten gelesen werden können"""
        if not self.args.verify_data:
            logger.info("Überspringe Datenverifizierung (--verify-data nicht angegeben)...")
            return True
        
        logger.info("Führe analytische Abfragen zur Datenverifizierung durch...")
        
        try:
            conn = psycopg2.connect(**self.db_params)
            cursor = conn.cursor(cursor_factory=DictCursor)
            
            # Finde große analytische Tabellen
            cursor.execute(ANALYTICAL_TABLES_QUERY)
            tables = cursor.fetchall()
            
            if not tables:
                self.add_check_result(
                    'analytical_data_check', False,
                    "Keine analytischen Tabellen gefunden"
                )
                return False
            
            # Führe Stichproben-Abfragen durch
            verified_tables = []
            for schema, table in tables:
                sample_query = f"SELECT COUNT(*) FROM {schema}.{table}"
                cursor.execute(sample_query)
                count = cursor.fetchone()[0]
                
                checksum_query = f"""
                SELECT SUM(hash_numeric(t.*::text))
                FROM (SELECT * FROM {schema}.{table} LIMIT 1000) t
                """
                
                try:
                    cursor.execute(checksum_query)
                    checksum = cursor.fetchone()[0]
                except Exception:
                    # Fallback, falls hash_numeric nicht verfügbar ist
                    checksum = "N/A"
                
                verified_tables.append({
                    'schema': schema,
                    'table': table,
                    'row_count': count,
                    'checksum': str(checksum) if checksum else "N/A"
                })
            
            self.add_check_result(
                'analytical_data_check', True,
                f"{len(verified_tables)} analytische Tabellen verifiziert",
                {'tables': verified_tables}
            )
            
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"Fehler bei Datenverifizierung: {e}")
            self.add_check_result(
                'analytical_data_check', False,
                "Fehler bei Datenverifizierung",
                str(e)
            )
            return False
    
    def save_results(self):
        """Speichert die Ergebnisse"""
        self.results['success'] = all(check['success'] for check in self.results['checks'])
        self.metrics['backup_verification_success'] = 1 if self.results['success'] else 0
        self.metrics['backup_verification_errors'] = len(self.results['errors'])
        
        # Speichere detaillierte Ergebnisse
        results_file = self.args.output
        if results_file:
            with open(results_file, 'w') as f:
                json.dump(self.results, f, indent=2)
            logger.info(f"Ergebnisse wurden gespeichert in: {results_file}")
        
        # Prometheus-Metriken
        if self.args.metrics_file:
            with open(self.args.metrics_file, 'w') as f:
                for name, value in self.metrics.items():
                    f.write(f"{name} {value}\n")
            logger.info(f"Metriken wurden gespeichert in: {self.args.metrics_file}")
        
        return self.results['success']
    
    def run(self):
        """Führt alle Verifizierungsschritte aus"""
        start_time = time.time()
        logger.info(f"Starte Backup-Verifizierung für Stanza '{self.stanza}'...")
        
        # Führe alle Prüfungen durch
        success = self.verify_backup_info()
        
        if success:
            self.check_backup_integrity()
            self.test_restore()
            self.test_analytical_query_data()
        
        # Zeitmessung
        duration = time.time() - start_time
        self.metrics['backup_verification_duration'] = duration
        logger.info(f"Backup-Verifizierung abgeschlossen in {round(duration, 1)} Sekunden.")
        
        # Speichere Ergebnisse
        success = self.save_results()
        
        # Sende Benachrichtigung bei Fehlern
        if self.args.notify and not success:
            self.send_notification()
        
        return 0 if success else 1
    
    def send_notification(self):
        """Sendet Benachrichtigung über fehlgeschlagene Verifizierung"""
        try:
            logger.info("Sende Benachrichtigung über fehlgeschlagene Verifizierung...")
            
            notification_script = '/usr/local/bin/backup-notification.py'
            if not os.path.exists(notification_script):
                logger.error(f"Benachrichtigungsskript nicht gefunden: {notification_script}")
                return
            
            errors = '\n'.join(self.results['errors'])
            cmd = (
                f"python3 {notification_script} "
                f"--subject 'Backup-Verifizierung fehlgeschlagen' "
                f"--message 'Fehler bei der Backup-Verifizierung:\n{errors}'"
            )
            
            self.run_command(cmd)
        except Exception as e:
            logger.error(f"Fehler beim Senden der Benachrichtigung: {e}")

def parse_args():
    parser = argparse.ArgumentParser(description='ExaPG Backup-Verifizierung')
    parser.add_argument('--config', default=DEFAULT_CONFIG, help='pgBackRest-Konfigurationsdatei')
    parser.add_argument('--stanza', default=DEFAULT_STANZA, help='Stanza-Name')
    parser.add_argument('--temp-dir', default=DEFAULT_TEMP_DIR, help='Temporäres Verzeichnis für Test-Restore')
    parser.add_argument('--output', default='/var/log/backup-verification/latest.json', help='Ausgabedatei für Ergebnisse')
    parser.add_argument('--metrics-file', default='/var/lib/verification-data/metrics.txt', help='Ausgabedatei für Metriken')
    parser.add_argument('--quick', action='store_true', help='Nur einfache Prüfungen durchführen')
    parser.add_argument('--full', action='store_true', help='Vollständige Verifizierung mit Test-Restore')
    parser.add_argument('--verify-data', action='store_true', help='Analytische Daten verifizieren')
    parser.add_argument('--latest-backup', action='store_true', help='Nur das neueste Backup prüfen')
    parser.add_argument('--notify', action='store_true', help='Benachrichtigung bei Fehlern senden')
    parser.add_argument('--verbose', action='store_true', help='Ausführliche Ausgaben')
    return parser.parse_args()

def main():
    args = parse_args()
    
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    verifier = BackupVerifier(args)
    return verifier.run()

if __name__ == '__main__':
    sys.exit(main()) 