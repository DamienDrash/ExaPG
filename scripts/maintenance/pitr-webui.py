#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ExaPG Point-in-Time Recovery Web UI
Eine benutzerfreundliche Web-Oberfläche für PostgreSQL Point-in-Time-Recovery mit pgBackRest
"""

import os
import json
import logging
import subprocess
import tempfile
from datetime import datetime, timedelta
from functools import wraps

from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_wtf import FlaskForm
from flask_wtf.csrf import CSRFProtect
from wtforms import StringField, SelectField, DateTimeField, BooleanField, PasswordField, TextAreaField
from wtforms.validators import DataRequired, Optional
import psycopg2
from psycopg2.extras import DictCursor
from werkzeug.security import check_password_hash, generate_password_hash

# Module für die PITR-Funktionalität importieren
import pitr_libs as pitr

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    filename='/var/log/pitr-manager/pitr-webui.log'
)
logger = logging.getLogger('pitr-webui')

# Flask-App erstellen
app = Flask(__name__, template_folder='templates', static_folder='static')
app.config['SECRET_KEY'] = os.environ.get('FLASK_SECRET_KEY', 'exapg_pitr_secret_key')
app.config['PGBACKREST_STANZA'] = os.environ.get('PGBACKREST_STANZA', 'exapg')
app.config['PGBACKREST_CONFIG'] = os.environ.get('PGBACKREST_CONFIG', '/etc/pgbackrest/pgbackrest.conf')
app.config['ADMIN_PASSWORD'] = os.environ.get('ADMIN_PASSWORD', generate_password_hash('admin123'))

# CSRF-Schutz aktivieren
csrf = CSRFProtect(app)

# Formularklassen definieren
class LoginForm(FlaskForm):
    username = StringField('Benutzername', validators=[DataRequired()])
    password = PasswordField('Passwort', validators=[DataRequired()])
    
class PITRForm(FlaskForm):
    recovery_type = SelectField('Wiederherstellungstyp', choices=[
        ('latest', 'Zum neuesten Backup'),
        ('time', 'Point-in-Time (Zeitpunkt)'),
        ('lsn', 'LSN (Log Sequence Number)'),
        ('backup_label', 'Spezifisches Backup')
    ])
    recovery_time = DateTimeField('Wiederherstellungszeitpunkt', format='%Y-%m-%d %H:%M:%S', validators=[Optional()])
    recovery_lsn = StringField('LSN', validators=[Optional()])
    backup_label = SelectField('Backup Label', choices=[], validators=[Optional()])
    target_dir = StringField('Ziel-Verzeichnis', validators=[DataRequired()])
    restore_command = TextAreaField('Wiederherstellungsbefehl (Vorschau)')
    verify_first = BooleanField('Backup vor der Wiederherstellung überprüfen', default=True)
    delta_mode = BooleanField('Delta-Modus (schnellere Wiederherstellung für Testzwecke)', default=False)

# Authentifizierungs-Decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Routen definieren
@app.route('/')
@login_required
def index():
    """Hauptseite der PITR-Web-UI"""
    # Holen der Backup-Informationen
    backup_info = pitr.get_backup_info(app.config['PGBACKREST_CONFIG'], app.config['PGBACKREST_STANZA'])
    
    # Erstellen der Statistiken für das Dashboard
    stats = {}
    if backup_info:
        latest_backup = backup_info['latest_backup'] if 'latest_backup' in backup_info else None
        
        if latest_backup:
            stats['latest_backup_time'] = latest_backup['time']
            stats['latest_backup_type'] = latest_backup['type'].upper()
            stats['backup_count'] = len(backup_info['backups']) if 'backups' in backup_info else 0
            stats['wal_segments'] = backup_info['wal_segments'] if 'wal_segments' in backup_info else 'N/A'
            stats['pitr_window'] = backup_info['pitr_window'] if 'pitr_window' in backup_info else 'N/A'
        else:
            stats['latest_backup_time'] = 'Kein Backup gefunden'
            stats['latest_backup_type'] = 'N/A'
            stats['backup_count'] = 0
            stats['wal_segments'] = 'N/A'
            stats['pitr_window'] = 'N/A'
    else:
        stats['latest_backup_time'] = 'Kein Backup gefunden'
        stats['latest_backup_type'] = 'N/A'
        stats['backup_count'] = 0
        stats['wal_segments'] = 'N/A'
        stats['pitr_window'] = 'N/A'
    
    # Holen der letzten Wiederherstellungsversuche
    restore_log = pitr.get_restore_log()
    
    return render_template('index.html', stats=stats, restore_log=restore_log)

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login-Seite"""
    form = LoginForm()
    
    if form.validate_on_submit():
        username = form.username.data
        password = form.password.data
        
        # Überprüfe die Anmeldedaten (vereinfacht)
        if username == 'admin' and check_password_hash(app.config['ADMIN_PASSWORD'], password):
            session['logged_in'] = True
            session['username'] = username
            flash('Login erfolgreich', 'success')
            return redirect(url_for('index'))
        else:
            flash('Ungültige Anmeldedaten', 'danger')
    
    return render_template('login.html', form=form)

@app.route('/logout')
def logout():
    """Logout-Route"""
    session.pop('logged_in', None)
    session.pop('username', None)
    flash('Erfolgreich abgemeldet', 'success')
    return redirect(url_for('login'))

@app.route('/backups')
@login_required
def backups():
    """Seite zur Anzeige aller Backups"""
    backup_info = pitr.get_backup_info(app.config['PGBACKREST_CONFIG'], app.config['PGBACKREST_STANZA'])
    
    return render_template('backups.html', backup_info=backup_info)

@app.route('/restore', methods=['GET', 'POST'])
@login_required
def restore():
    """Seite für die Wiederherstellung"""
    form = PITRForm()
    
    # Backup-Labels für die Dropdown-Liste laden
    backup_info = pitr.get_backup_info(app.config['PGBACKREST_CONFIG'], app.config['PGBACKREST_STANZA'])
    
    if backup_info and 'backups' in backup_info:
        labels = [(backup['label'], f"{backup['label']} ({backup['type'].upper()} - {backup['time']})") 
                  for backup in backup_info['backups']]
        form.backup_label.choices = labels
    else:
        form.backup_label.choices = [('', 'Keine Backups verfügbar')]
    
    # Wenn es sich um eine POST-Anfrage handelt
    if form.validate_on_submit():
        recovery_type = form.recovery_type.data
        target_dir = form.target_dir.data
        verify_first = form.verify_first.data
        delta_mode = form.delta_mode.data
        
        # Wiederherstellungsparameter basierend auf dem ausgewählten Typ
        restore_params = {
            'config': app.config['PGBACKREST_CONFIG'],
            'stanza': app.config['PGBACKREST_STANZA'],
            'target': target_dir,
            'verify': verify_first,
            'delta': delta_mode
        }
        
        if recovery_type == 'latest':
            # Zum neuesten Backup wiederherstellen
            pass  # Keine zusätzlichen Parameter
        elif recovery_type == 'time':
            # Point-in-Time-Wiederherstellung
            restore_params['type'] = 'time'
            restore_params['time'] = form.recovery_time.data.strftime('%Y-%m-%d %H:%M:%S')
        elif recovery_type == 'lsn':
            # Wiederherstellung zu einer bestimmten LSN
            restore_params['type'] = 'lsn'
            restore_params['lsn'] = form.recovery_lsn.data
        elif recovery_type == 'backup_label':
            # Wiederherstellung eines bestimmten Backups
            restore_params['type'] = 'name'
            restore_params['name'] = form.backup_label.data
        
        # Wiederherstellungsbefehl erstellen und anzeigen
        cmd = pitr.build_restore_command(restore_params)
        form.restore_command.data = cmd
        
        # Wenn der Benutzer den Befehl ausführen möchte
        if 'execute' in request.form:
            try:
                result = pitr.execute_restore(restore_params)
                if result['success']:
                    flash(f"Wiederherstellung erfolgreich gestartet: {result['message']}", 'success')
                    return redirect(url_for('restore_status', job_id=result['job_id']))
                else:
                    flash(f"Fehler bei der Wiederherstellung: {result['message']}", 'danger')
            except Exception as e:
                flash(f"Fehler bei der Wiederherstellung: {str(e)}", 'danger')
    
    return render_template('restore.html', form=form)

@app.route('/restore-status/<job_id>')
@login_required
def restore_status(job_id):
    """Seite zur Anzeige des Status einer Wiederherstellung"""
    status = pitr.get_restore_status(job_id)
    
    return render_template('restore_status.html', status=status, job_id=job_id)

@app.route('/api/status/<job_id>')
@login_required
def api_status(job_id):
    """API-Endpunkt für den Status einer Wiederherstellung"""
    status = pitr.get_restore_status(job_id)
    
    return jsonify(status)

@app.route('/audit-log')
@login_required
def audit_log():
    """Seite zur Anzeige des Audit-Logs"""
    logs = pitr.get_audit_log()
    
    return render_template('audit_log.html', logs=logs)

@app.route('/settings', methods=['GET', 'POST'])
@login_required
def settings():
    """Seite für Einstellungen"""
    # Hier könnten Einstellungen wie Stanza, Konfigurationsdatei, usw. angepasst werden
    
    return render_template('settings.html')

@app.route('/validation')
@login_required
def validation():
    """Seite zur Backup-Validierung"""
    validation_results = pitr.get_validation_results()
    
    return render_template('validation.html', results=validation_results)

@app.route('/api/validate-backup', methods=['POST'])
@login_required
def api_validate_backup():
    """API-Endpunkt zur Backup-Validierung"""
    # Backup-Label aus der Anfrage holen
    data = request.get_json()
    backup_label = data.get('backup_label', '')
    
    # Backup überprüfen
    result = pitr.validate_backup(app.config['PGBACKREST_CONFIG'], app.config['PGBACKREST_STANZA'], backup_label)
    
    return jsonify(result)

# 404-Fehlerseite
@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

# 500-Fehlerseite
@app.errorhandler(500)
def server_error(e):
    return render_template('500.html'), 500

if __name__ == '__main__':
    port = int(os.environ.get('PITR_LISTEN_PORT', 8080))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    
    # Flask-App starten
    app.run(host='0.0.0.0', port=port, debug=debug) 