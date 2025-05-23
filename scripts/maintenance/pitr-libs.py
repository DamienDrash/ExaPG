#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ExaPG PITR Bibliothek
Hilfsfunktionen für die PITR-Weboberfläche
"""

import json
import logging
import os
import re
import sqlite3
import subprocess
import time
import uuid
from datetime import datetime, timedelta
from threading import Thread

import psycopg2
from psycopg2.extras import DictCursor

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    filename='/var/log/pitr-manager/pitr-libs.log'
)
logger = logging.getLogger('pitr-libs')

# Pfade und Standardwerte
PITR_DB_PATH = os.environ.get('PITR_DB_PATH', '/var/lib/pitr-manager/pitr.db')
RESTORE_LOG_PATH = os.environ.get('RESTORE_LOG_PATH', '/var/lib/pitr-manager/restores')

# Datenbank initialisieren
def init_db():
    """Initialisiert die SQLite-Datenbank für die PITR-Verwaltung"""
    try:
        # Stellt sicher, dass das Verzeichnis existiert
        os.makedirs(os.path.dirname(PITR_DB_PATH), exist_ok=True)
        os.makedirs(RESTORE_LOG_PATH, exist_ok=True)
        
        # Verbindung zur Datenbank herstellen
        conn = sqlite3.connect(PITR_DB_PATH)
        cursor = conn.cursor()
        
        # Tabellen erstellen, falls sie nicht existieren
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS restore_jobs (
            id TEXT PRIMARY KEY,
            start_time TEXT,
            end_time TEXT,
            status TEXT,
            params TEXT,
            command TEXT,
            output TEXT,
            error TEXT
        )
        ''')
        
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            action TEXT,
            username TEXT,
            details TEXT
        )
        ''')
        
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS validation_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            backup_label TEXT,
            success INTEGER,
            details TEXT
        )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Datenbank erfolgreich initialisiert")
    except Exception as e:
        logger.error(f"Fehler bei der Datenbankinitialisierung: {e}")
        raise

# Datenbank beim Importieren initialisieren
init_db()

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

def get_backup_info(config, stanza):
    """Holt Informationen über die Backups einer Stanza"""
    try:
        cmd = f"pgbackrest --config={config} --stanza={stanza} info --output=json"
        stdout, stderr, returncode = run_command(cmd)
        
        if returncode != 0:
            logger.error(f"Fehler beim Abrufen der Backup-Informationen: {stderr}")
            return None
        
        info = json.loads(stdout)
        stanza_info = info[0]  # Stanza-Info
        
        result = {
            'stanza': stanza,
            'backups': [],
            'wal_segments': 0,
            'pitr_window': 'N/A'
        }
        
        # Backups extrahieren
        if 'backup' in stanza_info:
            for backup in stanza_info['backup']:
                backup_time = datetime.strptime(backup['timestamp']['start'], "%Y-%m-%dT%H:%M:%S")
                
                backup_info = {
                    'label': backup['label'],
                    'type': backup['type'],
                    'time': backup_time.strftime('%Y-%m-%d %H:%M:%S'),
                    'size_mb': round(backup['info']['size'] / (1024*1024), 2) if 'info' in backup else 0,
                    'database_size_mb': round(backup['info']['database']['size'] / (1024*1024), 2) if 'info' in backup and 'database' in backup['info'] else 0,
                    'repo_size_mb': round(backup['info']['repository']['size'] / (1024*1024), 2) if 'info' in backup and 'repository' in backup['info'] else 0
                }
                
                result['backups'].append(backup_info)
            
            # Neuestes Backup
            result['latest_backup'] = result['backups'][0] if result['backups'] else None
        
        # WAL-Archiv-Informationen
        if 'archive' in stanza_info:
            min_wal = stanza_info['archive'].get('min')
            max_wal = stanza_info['archive'].get('max')
            
            if min_wal and max_wal:
                # WAL-Segmente zählen (vereinfacht)
                wal_min_num = int(min_wal.split('/')[1], 16)
                wal_max_num = int(max_wal.split('/')[1], 16)
                result['wal_segments'] = wal_max_num - wal_min_num + 1
                
                # PITR-Fenster abschätzen
                pitr_window_hours = result['wal_segments'] / 20  # Grobe Schätzung: 20 WAL-Segmente pro Stunde
                result['pitr_window'] = f"{int(pitr_window_hours)} Stunden"
        
        return result
    except Exception as e:
        logger.error(f"Fehler beim Verarbeiten der Backup-Informationen: {e}")
        return None

def build_restore_command(params):
    """Erstellt den Befehl für die Wiederherstellung"""
    cmd = ["pgbackrest"]
    
    # Grundlegende Parameter
    cmd.append(f"--config={params['config']}")
    cmd.append(f"--stanza={params['stanza']}")
    
    # Wiederherstellungsziel
    cmd.append(f"--target={params['target']}")
    
    # Delta-Modus (für schnellere Wiederherstellung)
    if params.get('delta', False):
        cmd.append("--delta")
    
    # Point-in-Time-Recovery
    if 'type' in params:
        if params['type'] == 'time':
            cmd.append(f"--type=time")
            cmd.append(f"--target-time=\"{params['time']}\"")
        elif params['type'] == 'lsn':
            cmd.append(f"--type=lsn")
            cmd.append(f"--target-lsn={params['lsn']}")
        elif params['type'] == 'name':
            cmd.append(f"--type=name")
            cmd.append(f"--target-name={params['name']}")
    
    # Zielparameter für die Wiederherstellung
    cmd.append("--target-action=promote")
    
    # Typ des Befehls
    cmd.append("restore")
    
    return " ".join(cmd)

def async_restore(job_id, command, params):
    """Führt eine Wiederherstellung asynchron aus"""
    conn = sqlite3.connect(PITR_DB_PATH)
    cursor = conn.cursor()
    
    try:
        # Startzeit und Status aktualisieren
        cursor.execute(
            "UPDATE restore_jobs SET status = ?, start_time = ? WHERE id = ?",
            ("running", datetime.now().isoformat(), job_id)
        )
        conn.commit()
        
        # Befehl ausführen
        process = subprocess.Popen(
            command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
        )
        stdout, stderr = process.communicate()
        
        # Ausgabe und Fehler in einer Datei protokollieren
        log_file = os.path.join(RESTORE_LOG_PATH, f"{job_id}.log")
        with open(log_file, 'w') as f:
            f.write(f"=== BEFEHL ===\n{command}\n\n")
            f.write(f"=== AUSGABE ===\n{stdout}\n\n")
            f.write(f"=== FEHLER ===\n{stderr}\n\n")
        
        # Status, Endzeit, Ausgabe und Fehler aktualisieren
        status = "completed" if process.returncode == 0 else "failed"
        cursor.execute(
            "UPDATE restore_jobs SET status = ?, end_time = ?, output = ?, error = ? WHERE id = ?",
            (status, datetime.now().isoformat(), stdout, stderr, job_id)
        )
        conn.commit()
        
        # Audit-Log-Eintrag
        log_action(
            "restore",
            params.get('username', 'system'),
            json.dumps({
                'job_id': job_id,
                'status': status,
                'params': params
            })
        )
        
    except Exception as e:
        logger.error(f"Fehler bei der Wiederherstellung (Job {job_id}): {e}")
        
        # Status, Endzeit und Fehler aktualisieren
        cursor.execute(
            "UPDATE restore_jobs SET status = ?, end_time = ?, error = ? WHERE id = ?",
            ("failed", datetime.now().isoformat(), str(e), job_id)
        )
        conn.commit()
    finally:
        conn.close()

def execute_restore(params):
    """Führt die Wiederherstellung aus"""
    try:
        # Befehl erstellen
        command = build_restore_command(params)
        
        # Job-ID erstellen
        job_id = str(uuid.uuid4())
        
        # Job in der Datenbank speichern
        conn = sqlite3.connect(PITR_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(
            "INSERT INTO restore_jobs (id, start_time, status, params, command) VALUES (?, ?, ?, ?, ?)",
            (job_id, datetime.now().isoformat(), "pending", json.dumps(params), command)
        )
        conn.commit()
        conn.close()
        
        # Asynchron ausführen
        thread = Thread(target=async_restore, args=(job_id, command, params))
        thread.daemon = True
        thread.start()
        
        return {
            'success': True,
            'job_id': job_id,
            'message': 'Wiederherstellung wurde gestartet'
        }
    except Exception as e:
        logger.error(f"Fehler beim Starten der Wiederherstellung: {e}")
        return {
            'success': False,
            'message': f'Fehler beim Starten der Wiederherstellung: {str(e)}'
        }

def get_restore_status(job_id):
    """Gibt den Status einer Wiederherstellung zurück"""
    try:
        conn = sqlite3.connect(PITR_DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM restore_jobs WHERE id = ?", (job_id,))
        job = cursor.fetchone()
        conn.close()
        
        if not job:
            return {
                'success': False,
                'message': f'Job mit ID {job_id} nicht gefunden'
            }
        
        # Job als Dictionary zurückgeben
        job_dict = dict(job)
        
        # Parameter als Dictionary
        job_dict['params'] = json.loads(job_dict['params'])
        
        # Log-Datei lesen, falls vorhanden
        log_file = os.path.join(RESTORE_LOG_PATH, f"{job_id}.log")
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                job_dict['log'] = f.read()
        
        # Laufzeit berechnen
        if job_dict['start_time']:
            start_time = datetime.fromisoformat(job_dict['start_time'])
            end_time = datetime.fromisoformat(job_dict['end_time']) if job_dict['end_time'] else datetime.now()
            runtime = (end_time - start_time).total_seconds()
            job_dict['runtime_seconds'] = runtime
            job_dict['runtime_formatted'] = f"{int(runtime // 60)}m {int(runtime % 60)}s"
        
        return {
            'success': True,
            'job': job_dict
        }
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Job-Status für {job_id}: {e}")
        return {
            'success': False,
            'message': f'Fehler beim Abrufen des Job-Status: {str(e)}'
        }

def get_restore_log(limit=10):
    """Gibt die neuesten Wiederherstellungsaufträge zurück"""
    try:
        conn = sqlite3.connect(PITR_DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT id, start_time, end_time, status, command FROM restore_jobs ORDER BY start_time DESC LIMIT ?",
            (limit,)
        )
        jobs = [dict(job) for job in cursor.fetchall()]
        conn.close()
        
        # Laufzeit für jeden Job berechnen
        for job in jobs:
            if job['start_time']:
                start_time = datetime.fromisoformat(job['start_time'])
                end_time = datetime.fromisoformat(job['end_time']) if job['end_time'] else datetime.now()
                runtime = (end_time - start_time).total_seconds()
                job['runtime_seconds'] = runtime
                job['runtime_formatted'] = f"{int(runtime // 60)}m {int(runtime % 60)}s"
        
        return jobs
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Wiederherstellungsprotokolls: {e}")
        return []

def log_action(action, username, details):
    """Protokolliert eine Aktion im Audit-Log"""
    try:
        conn = sqlite3.connect(PITR_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(
            "INSERT INTO audit_log (timestamp, action, username, details) VALUES (?, ?, ?, ?)",
            (datetime.now().isoformat(), action, username, details)
        )
        conn.commit()
        conn.close()
        
        return True
    except Exception as e:
        logger.error(f"Fehler beim Protokollieren der Aktion: {e}")
        return False

def get_audit_log(limit=100):
    """Gibt die neuesten Audit-Log-Einträge zurück"""
    try:
        conn = sqlite3.connect(PITR_DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT ?",
            (limit,)
        )
        logs = [dict(log) for log in cursor.fetchall()]
        conn.close()
        
        return logs
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Audit-Logs: {e}")
        return []

def validate_backup(config, stanza, backup_label=None):
    """Validiert ein Backup"""
    try:
        # Backup-Validierungsbefehl erstellen
        cmd = f"pgbackrest --config={config} --stanza={stanza} check"
        
        if backup_label:
            cmd += f" --set={backup_label}"
        
        # Befehl ausführen
        stdout, stderr, returncode = run_command(cmd)
        
        success = returncode == 0
        
        # Ergebnis in der Datenbank speichern
        conn = sqlite3.connect(PITR_DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(
            "INSERT INTO validation_results (timestamp, backup_label, success, details) VALUES (?, ?, ?, ?)",
            (datetime.now().isoformat(), backup_label or 'all', success, stderr if not success else stdout)
        )
        conn.commit()
        conn.close()
        
        # Audit-Log-Eintrag
        log_action(
            "validate_backup",
            "system",
            json.dumps({
                'stanza': stanza,
                'backup_label': backup_label,
                'success': success
            })
        )
        
        return {
            'success': success,
            'message': stderr if not success else 'Backup-Validierung erfolgreich',
            'output': stdout
        }
    except Exception as e:
        logger.error(f"Fehler bei der Backup-Validierung: {e}")
        return {
            'success': False,
            'message': f'Fehler bei der Backup-Validierung: {str(e)}'
        }

def get_validation_results(limit=20):
    """Gibt die neuesten Validierungsergebnisse zurück"""
    try:
        conn = sqlite3.connect(PITR_DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT * FROM validation_results ORDER BY timestamp DESC LIMIT ?",
            (limit,)
        )
        results = [dict(result) for result in cursor.fetchall()]
        conn.close()
        
        return results
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Validierungsergebnisse: {e}")
        return [] 