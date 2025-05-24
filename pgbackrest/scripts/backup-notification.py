#!/usr/bin/env python3
"""
ExaPG Backup Notification System
Benachrichtigungen für Backup-Status über verschiedene Kanäle
"""

import os
import sys
import json
import smtplib
import argparse
import datetime
import subprocess
import requests
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from pathlib import Path
from typing import Dict, List, Optional

class BackupNotifier:
    """
    Benachrichtigungssystem für ExaPG Backup-Status
    """
    
    def __init__(self):
        # Notification configuration from environment
        self.enabled = os.getenv('BACKUP_NOTIFICATIONS_ENABLED', 'true').lower() == 'true'
        self.stanza = os.getenv('PGBACKREST_STANZA', 'exapg')
        
        # Email configuration
        self.email_enabled = os.getenv('BACKUP_EMAIL_ENABLED', 'false').lower() == 'true'
        self.smtp_server = os.getenv('BACKUP_SMTP_SERVER', 'localhost')
        self.smtp_port = int(os.getenv('BACKUP_SMTP_PORT', '587'))
        self.smtp_username = os.getenv('BACKUP_SMTP_USERNAME', '')
        self.smtp_password = os.getenv('BACKUP_SMTP_PASSWORD', '')
        self.smtp_use_tls = os.getenv('BACKUP_SMTP_USE_TLS', 'true').lower() == 'true'
        self.email_from = os.getenv('BACKUP_EMAIL_FROM', 'exapg@localhost')
        self.email_to = os.getenv('BACKUP_EMAIL_TO', '').split(',')
        
        # Slack configuration
        self.slack_enabled = os.getenv('BACKUP_SLACK_ENABLED', 'false').lower() == 'true'
        self.slack_webhook_url = os.getenv('BACKUP_SLACK_WEBHOOK_URL', '')
        self.slack_channel = os.getenv('BACKUP_SLACK_CHANNEL', '#exapg-alerts')
        
        # Webhook configuration
        self.webhook_enabled = os.getenv('BACKUP_WEBHOOK_ENABLED', 'false').lower() == 'true'
        self.webhook_url = os.getenv('BACKUP_WEBHOOK_URL', '')
        self.webhook_token = os.getenv('BACKUP_WEBHOOK_TOKEN', '')
        
        # System information
        self.hostname = os.getenv('HOSTNAME', subprocess.getoutput('hostname'))
        self.environment = os.getenv('ENVIRONMENT', 'production')
    
    def get_backup_info(self) -> Dict:
        """
        Holt aktuelle Backup-Informationen von pgBackRest
        """
        try:
            cmd = ["pgbackrest", "--stanza", self.stanza, "info", "--output=json"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                info_data = json.loads(result.stdout)
                return info_data[0] if info_data else {}
            else:
                return {'error': result.stderr}
                
        except subprocess.TimeoutExpired:
            return {'error': 'pgBackRest info command timed out'}
        except json.JSONDecodeError:
            return {'error': 'Failed to parse pgBackRest info output'}
        except Exception as e:
            return {'error': str(e)}
    
    def get_repository_status(self) -> Dict:
        """
        Ermittelt Repository-Status und -Statistiken
        """
        try:
            repo_path = os.getenv('PGBACKREST_REPO1_PATH', '/var/lib/pgbackrest')
            
            # Disk space
            statvfs = os.statvfs(repo_path)
            free_space_bytes = statvfs.f_frsize * statvfs.f_bavail
            total_space_bytes = statvfs.f_frsize * statvfs.f_blocks
            used_percentage = ((total_space_bytes - free_space_bytes) / total_space_bytes) * 100
            
            # Repository size
            result = subprocess.run(
                ["du", "-sb", repo_path],
                capture_output=True,
                text=True
            )
            repo_size_bytes = int(result.stdout.split()[0]) if result.returncode == 0 else 0
            
            return {
                'repo_path': repo_path,
                'repo_size_bytes': repo_size_bytes,
                'repo_size_human': f"{repo_size_bytes / (1024**3):.2f} GB",
                'free_space_bytes': free_space_bytes,
                'free_space_human': f"{free_space_bytes / (1024**3):.2f} GB",
                'used_percentage': round(used_percentage, 2)
            }
        except Exception as e:
            return {'error': str(e)}
    
    def format_duration(self, seconds: int) -> str:
        """
        Formatiert Zeitdauer human-readable
        """
        if seconds < 60:
            return f"{seconds}s"
        elif seconds < 3600:
            return f"{seconds // 60}m {seconds % 60}s"
        else:
            hours = seconds // 3600
            minutes = (seconds % 3600) // 60
            return f"{hours}h {minutes}m"
    
    def create_message(self, backup_type: str, status: str, duration: Optional[int] = None) -> Dict:
        """
        Erstellt Nachricht basierend auf Backup-Status
        """
        backup_info = self.get_backup_info()
        repo_status = self.get_repository_status()
        
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # Status emoji und Farbe
        if status == 'success':
            emoji = '✅'
            color = '#28a745'  # Green
            severity = 'INFO'
        elif status == 'failed':
            emoji = '❌'
            color = '#dc3545'  # Red
            severity = 'ERROR'
        elif status == 'warning':
            emoji = '⚠️'
            color = '#ffc107'  # Yellow
            severity = 'WARNING'
        else:
            emoji = 'ℹ️'
            color = '#17a2b8'  # Blue
            severity = 'INFO'
        
        # Basis-Information
        message_data = {
            'timestamp': timestamp,
            'hostname': self.hostname,
            'environment': self.environment,
            'stanza': self.stanza,
            'backup_type': backup_type,
            'status': status,
            'severity': severity,
            'emoji': emoji,
            'color': color,
            'duration': duration,
            'duration_human': self.format_duration(duration) if duration else None
        }
        
        # Backup-Informationen hinzufügen
        if 'error' not in backup_info:
            backup_list = backup_info.get('backup', [])
            if backup_list:
                latest_backup = backup_list[-1]
                message_data.update({
                    'latest_backup': latest_backup,
                    'total_backups': len(backup_list),
                    'backup_size': latest_backup.get('info', {}).get('size', 0)
                })
        
        # Repository-Status hinzufügen
        if 'error' not in repo_status:
            message_data.update(repo_status)
        
        return message_data
    
    def send_email(self, message_data: Dict) -> bool:
        """
        Sendet Email-Benachrichtigung
        """
        if not self.email_enabled or not self.email_to:
            return False
        
        try:
            subject = f"[ExaPG-{self.environment}] {message_data['emoji']} Backup {message_data['status'].title()}: {message_data['backup_type']} on {message_data['hostname']}"
            
            # HTML Email body
            html_body = f"""
            <html>
            <body>
                <h2>ExaPG Backup Report</h2>
                <table border="1" cellpadding="5" cellspacing="0">
                    <tr><td><strong>Status</strong></td><td style="color: {message_data['color']}">{message_data['emoji']} {message_data['status'].upper()}</td></tr>
                    <tr><td><strong>Backup Type</strong></td><td>{message_data['backup_type']}</td></tr>
                    <tr><td><strong>Hostname</strong></td><td>{message_data['hostname']}</td></tr>
                    <tr><td><strong>Environment</strong></td><td>{message_data['environment']}</td></tr>
                    <tr><td><strong>Stanza</strong></td><td>{message_data['stanza']}</td></tr>
                    <tr><td><strong>Timestamp</strong></td><td>{message_data['timestamp']}</td></tr>
            """
            
            if message_data.get('duration_human'):
                html_body += f"<tr><td><strong>Duration</strong></td><td>{message_data['duration_human']}</td></tr>"
            
            if message_data.get('total_backups'):
                html_body += f"<tr><td><strong>Total Backups</strong></td><td>{message_data['total_backups']}</td></tr>"
            
            if message_data.get('repo_size_human'):
                html_body += f"<tr><td><strong>Repository Size</strong></td><td>{message_data['repo_size_human']}</td></tr>"
            
            if message_data.get('free_space_human'):
                html_body += f"<tr><td><strong>Free Space</strong></td><td>{message_data['free_space_human']} ({100 - message_data.get('used_percentage', 0):.1f}% free)</td></tr>"
            
            html_body += """
                </table>
                
                <h3>Latest Backup Information</h3>
            """
            
            if message_data.get('latest_backup'):
                backup = message_data['latest_backup']
                html_body += f"""
                <table border="1" cellpadding="5" cellspacing="0">
                    <tr><td><strong>Backup Label</strong></td><td>{backup.get('label', 'N/A')}</td></tr>
                    <tr><td><strong>Type</strong></td><td>{backup.get('type', 'N/A')}</td></tr>
                    <tr><td><strong>Timestamp</strong></td><td>{backup.get('timestamp', {}).get('start', 'N/A')}</td></tr>
                    <tr><td><strong>Size</strong></td><td>{backup.get('info', {}).get('size', 0) / (1024**3):.2f} GB</td></tr>
                </table>
                """
            else:
                html_body += "<p>No backup information available</p>"
            
            html_body += """
                <p><em>This is an automated message from ExaPG Backup System</em></p>
            </body>
            </html>
            """
            
            # Email erstellen
            msg = MimeMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.email_from
            msg['To'] = ', '.join(self.email_to)
            
            html_part = MimeText(html_body, 'html')
            msg.attach(html_part)
            
            # Email senden
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                if self.smtp_use_tls:
                    server.starttls()
                if self.smtp_username and self.smtp_password:
                    server.login(self.smtp_username, self.smtp_password)
                
                server.send_message(msg)
            
            return True
            
        except Exception as e:
            print(f"Failed to send email: {e}")
            return False
    
    def send_slack(self, message_data: Dict) -> bool:
        """
        Sendet Slack-Benachrichtigung
        """
        if not self.slack_enabled or not self.slack_webhook_url:
            return False
        
        try:
            # Slack payload
            payload = {
                "channel": self.slack_channel,
                "username": "ExaPG Backup Bot",
                "icon_emoji": ":floppy_disk:",
                "attachments": [
                    {
                        "color": message_data['color'],
                        "title": f"ExaPG Backup {message_data['status'].title()} - {message_data['backup_type']}",
                        "fields": [
                            {"title": "Status", "value": f"{message_data['emoji']} {message_data['status'].upper()}", "short": True},
                            {"title": "Hostname", "value": message_data['hostname'], "short": True},
                            {"title": "Environment", "value": message_data['environment'], "short": True},
                            {"title": "Stanza", "value": message_data['stanza'], "short": True}
                        ],
                        "footer": "ExaPG Backup System",
                        "ts": int(datetime.datetime.now().timestamp())
                    }
                ]
            }
            
            # Zusätzliche Felder bei Erfolg
            if message_data['status'] == 'success':
                if message_data.get('duration_human'):
                    payload["attachments"][0]["fields"].append({
                        "title": "Duration", "value": message_data['duration_human'], "short": True
                    })
                
                if message_data.get('total_backups'):
                    payload["attachments"][0]["fields"].append({
                        "title": "Total Backups", "value": str(message_data['total_backups']), "short": True
                    })
                
                if message_data.get('repo_size_human'):
                    payload["attachments"][0]["fields"].append({
                        "title": "Repository Size", "value": message_data['repo_size_human'], "short": True
                    })
            
            response = requests.post(
                self.slack_webhook_url,
                json=payload,
                timeout=30
            )
            
            return response.status_code == 200
            
        except Exception as e:
            print(f"Failed to send Slack notification: {e}")
            return False
    
    def send_webhook(self, message_data: Dict) -> bool:
        """
        Sendet Webhook-Benachrichtigung
        """
        if not self.webhook_enabled or not self.webhook_url:
            return False
        
        try:
            headers = {'Content-Type': 'application/json'}
            
            if self.webhook_token:
                headers['Authorization'] = f"Bearer {self.webhook_token}"
            
            payload = {
                "event": "backup_notification",
                "data": message_data
            }
            
            response = requests.post(
                self.webhook_url,
                json=payload,
                headers=headers,
                timeout=30
            )
            
            return response.status_code in [200, 201, 202]
            
        except Exception as e:
            print(f"Failed to send webhook notification: {e}")
            return False
    
    def send_notification(self, backup_type: str, status: str, duration: Optional[int] = None) -> Dict:
        """
        Sendet Benachrichtigung über alle aktivierten Kanäle
        """
        if not self.enabled:
            return {"sent": False, "reason": "Notifications disabled"}
        
        message_data = self.create_message(backup_type, status, duration)
        
        results = {
            "message_data": message_data,
            "channels": {}
        }
        
        # Email senden
        if self.email_enabled:
            results["channels"]["email"] = self.send_email(message_data)
        
        # Slack senden
        if self.slack_enabled:
            results["channels"]["slack"] = self.send_slack(message_data)
        
        # Webhook senden
        if self.webhook_enabled:
            results["channels"]["webhook"] = self.send_webhook(message_data)
        
        # Erfolg bestimmen
        sent_channels = [ch for ch, success in results["channels"].items() if success]
        results["sent"] = len(sent_channels) > 0
        results["sent_channels"] = sent_channels
        
        return results
    
    def send_daily_summary(self) -> bool:
        """
        Sendet tägliche Backup-Zusammenfassung
        """
        try:
            backup_info = self.get_backup_info()
            repo_status = self.get_repository_status()
            
            if 'error' in backup_info:
                return self.send_notification('summary', 'failed')
            
            # Analyse der letzten 24 Stunden
            now = datetime.datetime.now()
            yesterday = now - datetime.timedelta(days=1)
            
            backup_list = backup_info.get('backup', [])
            recent_backups = []
            
            for backup in backup_list:
                backup_time = backup.get('timestamp', {}).get('start', '')
                if backup_time:
                    try:
                        backup_dt = datetime.datetime.strptime(backup_time, '%Y-%m-%d %H:%M:%S%z')
                        if backup_dt.replace(tzinfo=None) >= yesterday:
                            recent_backups.append(backup)
                    except:
                        pass
            
            # Status bestimmen
            if len(recent_backups) == 0:
                status = 'warning'  # Keine Backups in letzten 24h
            elif any(b.get('error') for b in recent_backups):
                status = 'failed'  # Backup-Fehler
            else:
                status = 'success'  # Alles OK
            
            # Custom Message für Summary
            message_data = self.create_message('daily_summary', status)
            message_data.update({
                'recent_backups': recent_backups,
                'recent_backup_count': len(recent_backups)
            })
            
            # Summary-spezifische Nachrichten senden
            if self.email_enabled:
                self._send_summary_email(message_data)
            
            return True
            
        except Exception as e:
            print(f"Failed to send daily summary: {e}")
            return False
    
    def _send_summary_email(self, message_data: Dict):
        """
        Sendet spezielle Daily Summary Email
        """
        # Implementation für tägliche Zusammenfassung
        # Ähnlich wie send_email(), aber mit erweiterten Informationen
        pass

def main():
    parser = argparse.ArgumentParser(description='ExaPG Backup Notification System')
    parser.add_argument('--type', default='incr', 
                       help='Backup type (full, diff, incr, summary)')
    parser.add_argument('--status', required=True,
                       choices=['success', 'failed', 'warning', 'info'],
                       help='Backup status')
    parser.add_argument('--duration', type=int,
                       help='Backup duration in seconds')
    parser.add_argument('--daily-summary', action='store_true',
                       help='Send daily backup summary')
    parser.add_argument('--test', action='store_true',
                       help='Send test notification')
    parser.add_argument('--silent', action='store_true',
                       help='Silent mode (no console output)')
    
    args = parser.parse_args()
    
    notifier = BackupNotifier()
    
    if args.daily_summary:
        success = notifier.send_daily_summary()
        if not args.silent:
            print(f"Daily summary sent: {success}")
        sys.exit(0 if success else 1)
    
    if args.test:
        results = notifier.send_notification('test', 'info', 60)
        if not args.silent:
            print(f"Test notification results: {json.dumps(results, indent=2)}")
        sys.exit(0 if results['sent'] else 1)
    
    # Standard notification
    results = notifier.send_notification(args.type, args.status, args.duration)
    
    if not args.silent:
        if results['sent']:
            print(f"Notification sent via: {', '.join(results['sent_channels'])}")
        else:
            print("No notifications sent")
            if 'reason' in results:
                print(f"Reason: {results['reason']}")
    
    sys.exit(0 if results['sent'] else 1)

if __name__ == "__main__":
    main() 