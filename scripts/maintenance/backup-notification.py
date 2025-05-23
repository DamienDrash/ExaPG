#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ExaPG Backup-Benachrichtigungssystem für pgBackRest
Sendet Benachrichtigungen über Backup-Status und -Fehler
"""

import argparse
import json
import logging
import os
import smtplib
import subprocess
import sys
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import requests

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('backup-notification')

# Standardwerte
DEFAULT_CONFIG = '/etc/pgbackrest/pgbackrest.conf'
DEFAULT_STANZA = 'exapg'

class BackupNotifier:
    def __init__(self, args):
        self.args = args
        self.config = args.config
        self.stanza = args.stanza
        self.subject = args.subject
        self.message = args.message
        self.type = args.type
        self.status = args.status
        self.duration = args.duration
        
        # Lade Benachrichtigungskonfiguration aus Umgebungsvariablen
        self.email_config = {
            'enabled': os.environ.get('EMAIL_NOTIFICATIONS', 'false').lower() == 'true',
            'smtp_server': os.environ.get('SMTP_SERVER', 'localhost'),
            'smtp_port': int(os.environ.get('SMTP_PORT', '25')),
            'smtp_user': os.environ.get('SMTP_USER', ''),
            'smtp_password': os.environ.get('SMTP_PASSWORD', ''),
            'from_email': os.environ.get('FROM_EMAIL', 'exapg-backup@localhost'),
            'to_email': os.environ.get('TO_EMAIL', 'admin@localhost'),
            'use_tls': os.environ.get('SMTP_TLS', 'false').lower() == 'true'
        }
        
        self.slack_config = {
            'enabled': os.environ.get('SLACK_ENABLED', 'false').lower() == 'true',
            'webhook_url': os.environ.get('SLACK_WEBHOOK_URL', ''),
            'channel': os.environ.get('SLACK_CHANNEL', '#monitoring')
        }
        
        self.telegram_config = {
            'enabled': os.environ.get('TELEGRAM_ENABLED', 'false').lower() == 'true',
            'bot_token': os.environ.get('TELEGRAM_BOT_TOKEN', ''),
            'chat_id': os.environ.get('TELEGRAM_CHAT_ID', '')
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
    
    def get_backup_info(self):
        """Holt Informationen über das neueste Backup"""
        cmd = f"pgbackrest --config={self.config} --stanza={self.stanza} info --output=json"
        stdout, stderr, returncode = self.run_command(cmd)
        
        if returncode != 0:
            logger.error(f"Fehler beim Abrufen der Backup-Informationen: {stderr}")
            return None
        
        try:
            info = json.loads(stdout)
            stanza_info = info[0]  # Stanza Info
            
            if not stanza_info.get('backup'):
                logger.error(f"Keine Backups gefunden für Stanza '{self.stanza}'")
                return None
            
            # Neuestes Backup
            latest_backup = stanza_info['backup'][0]
            
            # Formatiere Backup-Zeit
            backup_time = datetime.strptime(latest_backup['timestamp']['start'], "%Y-%m-%dT%H:%M:%S")
            backup_time_str = backup_time.strftime('%Y-%m-%d %H:%M:%S')
            
            # Berechne Backup-Größe in MB
            backup_size_mb = round(latest_backup['info']['size'] / (1024*1024), 2) if 'info' in latest_backup else "N/A"
            
            # Berechne Backup-Alter in Stunden
            backup_age = (datetime.now() - backup_time).total_seconds() / 3600  # Stunden
            backup_age_str = f"{round(backup_age, 1)} Stunden"
            
            return {
                'label': latest_backup['label'],
                'type': latest_backup['type'],
                'time': backup_time_str,
                'age': backup_age_str,
                'size_mb': backup_size_mb
            }
        except Exception as e:
            logger.error(f"Fehler beim Parsen der Backup-Informationen: {e}")
            return None
    
    def format_notification(self):
        """Formatiert die Benachrichtigung basierend auf gegebenen oder automatisch ermittelten Informationen"""
        # Wenn Subject und Message direkt angegeben wurden, verwende diese
        if self.message and self.subject:
            return self.subject, self.message
        
        # Sonst baue Nachricht basierend auf Backup-Status und -Typ
        backup_info = self.get_backup_info()
        
        if self.status == 'success':
            subject = f"ExaPG Backup erfolgreich: {self.type.upper()}"
            
            if backup_info:
                message = f"""
Backup erfolgreich abgeschlossen:
------------------------------
Typ:        {self.type.upper()}
Stanza:     {self.stanza}
Label:      {backup_info['label']}
Zeit:       {backup_info['time']}
Größe:      {backup_info['size_mb']} MB
Dauer:      {int(self.duration/60)}m {self.duration%60}s
------------------------------
"""
            else:
                message = f"Backup vom Typ {self.type.upper()} für Stanza '{self.stanza}' erfolgreich abgeschlossen."
                if self.duration:
                    message += f" Dauer: {int(self.duration/60)}m {self.duration%60}s"
        
        elif self.status == 'failed':
            subject = f"FEHLER: ExaPG Backup fehlgeschlagen: {self.type.upper()}"
            message = f"Backup vom Typ {self.type.upper()} für Stanza '{self.stanza}' ist fehlgeschlagen."
            
        else:
            # Allgemeine Benachrichtigung mit Backup-Status
            if backup_info:
                subject = f"ExaPG Backup-Status: {self.stanza}"
                message = f"""
Backup-Status für Stanza '{self.stanza}':
------------------------------
Neuestes Backup:  {backup_info['label']}
Typ:              {backup_info['type']}
Zeit:             {backup_info['time']}
Alter:            {backup_info['age']}
Größe:            {backup_info['size_mb']} MB
------------------------------
"""
            else:
                subject = f"ExaPG Backup-Status: {self.stanza}"
                message = f"Keine Backups gefunden für Stanza '{self.stanza}'."
        
        return subject, message
    
    def send_email(self, subject, message):
        """Sendet eine E-Mail-Benachrichtigung"""
        if not self.email_config['enabled']:
            logger.info("E-Mail-Benachrichtigungen sind deaktiviert.")
            return False
        
        if not self.email_config['to_email']:
            logger.error("Keine Empfänger-E-Mail-Adresse konfiguriert.")
            return False
        
        try:
            logger.info(f"Sende E-Mail an {self.email_config['to_email']}...")
            
            msg = MIMEMultipart()
            msg['From'] = self.email_config['from_email']
            msg['To'] = self.email_config['to_email']
            msg['Subject'] = subject
            
            msg.attach(MIMEText(message, 'plain'))
            
            if self.email_config['use_tls']:
                smtp = smtplib.SMTP_SSL(self.email_config['smtp_server'], self.email_config['smtp_port'])
            else:
                smtp = smtplib.SMTP(self.email_config['smtp_server'], self.email_config['smtp_port'])
            
            if self.email_config['smtp_user'] and self.email_config['smtp_password']:
                smtp.login(self.email_config['smtp_user'], self.email_config['smtp_password'])
            
            smtp.send_message(msg)
            smtp.quit()
            
            logger.info("E-Mail erfolgreich gesendet.")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Senden der E-Mail: {e}")
            return False
    
    def send_slack(self, subject, message):
        """Sendet eine Slack-Benachrichtigung"""
        if not self.slack_config['enabled']:
            logger.info("Slack-Benachrichtigungen sind deaktiviert.")
            return False
        
        if not self.slack_config['webhook_url']:
            logger.error("Keine Slack Webhook-URL konfiguriert.")
            return False
        
        try:
            logger.info(f"Sende Slack-Benachrichtigung an {self.slack_config['channel']}...")
            
            # Farbcodierung basierend auf Status
            color = "#36a64f"  # Grün für Erfolg
            if self.status == 'failed':
                color = "#ff0000"  # Rot für Fehler
            
            payload = {
                "channel": self.slack_config['channel'],
                "username": "ExaPG Backup",
                "text": subject,
                "attachments": [
                    {
                        "color": color,
                        "text": message,
                        "footer": f"ExaPG Backup | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                    }
                ]
            }
            
            response = requests.post(
                self.slack_config['webhook_url'],
                json=payload
            )
            
            if response.status_code == 200:
                logger.info("Slack-Benachrichtigung erfolgreich gesendet.")
                return True
            else:
                logger.error(f"Fehler beim Senden der Slack-Benachrichtigung: {response.status_code} {response.text}")
                return False
        except Exception as e:
            logger.error(f"Fehler beim Senden der Slack-Benachrichtigung: {e}")
            return False
    
    def send_telegram(self, subject, message):
        """Sendet eine Telegram-Benachrichtigung"""
        if not self.telegram_config['enabled']:
            logger.info("Telegram-Benachrichtigungen sind deaktiviert.")
            return False
        
        if not self.telegram_config['bot_token'] or not self.telegram_config['chat_id']:
            logger.error("Telegram Bot-Token oder Chat-ID nicht konfiguriert.")
            return False
        
        try:
            logger.info("Sende Telegram-Benachrichtigung...")
            
            text = f"*{subject}*\n\n{message}"
            
            url = f"https://api.telegram.org/bot{self.telegram_config['bot_token']}/sendMessage"
            payload = {
                "chat_id": self.telegram_config['chat_id'],
                "text": text,
                "parse_mode": "Markdown"
            }
            
            response = requests.post(url, json=payload)
            
            if response.status_code == 200:
                logger.info("Telegram-Benachrichtigung erfolgreich gesendet.")
                return True
            else:
                logger.error(f"Fehler beim Senden der Telegram-Benachrichtigung: {response.status_code} {response.text}")
                return False
        except Exception as e:
            logger.error(f"Fehler beim Senden der Telegram-Benachrichtigung: {e}")
            return False
    
    def send_notifications(self):
        """Sendet Benachrichtigungen über alle konfigurierten Kanäle"""
        subject, message = self.format_notification()
        
        success = True
        if self.email_config['enabled']:
            success = self.send_email(subject, message) and success
        
        if self.slack_config['enabled']:
            success = self.send_slack(subject, message) and success
        
        if self.telegram_config['enabled']:
            success = self.send_telegram(subject, message) and success
        
        if not (self.email_config['enabled'] or self.slack_config['enabled'] or self.telegram_config['enabled']):
            logger.warning("Keine Benachrichtigungskanäle aktiviert!")
            
        return success

def parse_args():
    parser = argparse.ArgumentParser(description='ExaPG Backup-Benachrichtigungssystem')
    parser.add_argument('--config', default=DEFAULT_CONFIG, help='pgBackRest-Konfigurationsdatei')
    parser.add_argument('--stanza', default=DEFAULT_STANZA, help='Stanza-Name')
    parser.add_argument('--subject', help='Betreff der Nachricht')
    parser.add_argument('--message', help='Nachrichtentext')
    parser.add_argument('--type', choices=['full', 'diff', 'incr'], default='incr', help='Backup-Typ')
    parser.add_argument('--status', choices=['success', 'failed', 'info'], default='info', help='Backup-Status')
    parser.add_argument('--duration', type=int, default=0, help='Backup-Dauer in Sekunden')
    parser.add_argument('--verbose', action='store_true', help='Ausführliche Ausgaben')
    return parser.parse_args()

def main():
    args = parse_args()
    
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    notifier = BackupNotifier(args)
    success = notifier.send_notifications()
    
    return 0 if success else 1

if __name__ == '__main__':
    sys.exit(main()) 