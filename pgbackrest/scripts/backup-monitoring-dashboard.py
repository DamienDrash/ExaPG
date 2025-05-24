#!/usr/bin/env python3
"""
ExaPG Backup Monitoring Dashboard
Web-Dashboard für umfassendes Backup-Monitoring
"""

import os
import sys
import json
import subprocess
import datetime
import time
import threading
from pathlib import Path
from typing import Dict, List, Optional
from flask import Flask, render_template_string, jsonify, request
import sqlite3
import schedule

class BackupMonitoringDashboard:
    """
    Web-Dashboard für Backup-Monitoring
    """
    
    def __init__(self):
        self.app = Flask(__name__)
        self.stanza = os.getenv('PGBACKREST_STANZA', 'exapg')
        self.config_path = os.getenv('PGBACKREST_CONFIG', '/etc/pgbackrest/pgbackrest.conf')
        self.repo_path = os.getenv('PGBACKREST_REPO1_PATH', '/var/lib/pgbackrest')
        self.db_path = '/var/log/pgbackrest/monitoring.db'
        
        # Dashboard configuration
        self.dashboard_port = int(os.getenv('BACKUP_DASHBOARD_PORT', '8080'))
        self.refresh_interval = int(os.getenv('BACKUP_DASHBOARD_REFRESH', '300'))  # 5 minutes
        
        # Initialize database
        self.init_database()
        
        # Setup routes
        self.setup_routes()
        
        # Start background monitoring
        self.start_background_monitoring()
    
    def init_database(self):
        """
        Initialisiert SQLite-Datenbank für Metriken
        """
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Backup history table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS backup_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                backup_type TEXT,
                backup_label TEXT,
                status TEXT,
                duration_seconds INTEGER,
                size_bytes INTEGER,
                error_message TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Verification history table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS verification_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                test_type TEXT,
                status TEXT,
                success_rate REAL,
                total_tests INTEGER,
                passed_tests INTEGER,
                failed_tests INTEGER,
                details TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Repository metrics table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS repository_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                repo_size_bytes INTEGER,
                free_space_bytes INTEGER,
                total_space_bytes INTEGER,
                backup_count INTEGER,
                oldest_backup_age_days INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Performance metrics table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS performance_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                operation_type TEXT,
                duration_seconds REAL,
                throughput_mbps REAL,
                cpu_usage_percent REAL,
                memory_usage_mb REAL,
                io_wait_percent REAL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def collect_backup_metrics(self) -> Dict:
        """
        Sammelt aktuelle Backup-Metriken
        """
        try:
            # pgBackRest info
            result = subprocess.run([
                'pgbackrest', '--config', self.config_path, 
                '--stanza', self.stanza, 'info', '--output=json'
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                return {'error': result.stderr}
            
            backup_info = json.loads(result.stdout)
            stanza_info = backup_info[0] if backup_info else {}
            
            # Repository metrics
            repo_stats = self.get_repository_stats()
            
            # Latest backup info
            backup_list = stanza_info.get('backup', [])
            latest_backup = backup_list[-1] if backup_list else None
            
            metrics = {
                'timestamp': datetime.datetime.now().isoformat(),
                'total_backups': len(backup_list),
                'latest_backup': latest_backup,
                'repository': repo_stats,
                'backup_types': self.analyze_backup_types(backup_list),
                'health_status': self.calculate_health_status(backup_list, repo_stats)
            }
            
            return metrics
            
        except Exception as e:
            return {'error': str(e)}
    
    def get_repository_stats(self) -> Dict:
        """
        Ermittelt Repository-Statistiken
        """
        try:
            repo_path = Path(self.repo_path)
            
            if not repo_path.exists():
                return {'error': 'Repository path does not exist'}
            
            # Disk space
            statvfs = os.statvfs(repo_path)
            free_space_bytes = statvfs.f_frsize * statvfs.f_bavail
            total_space_bytes = statvfs.f_frsize * statvfs.f_blocks
            used_space_bytes = total_space_bytes - free_space_bytes
            used_percentage = (used_space_bytes / total_space_bytes) * 100
            
            # Repository size
            result = subprocess.run(
                ['du', '-sb', str(repo_path)],
                capture_output=True, text=True
            )
            repo_size_bytes = int(result.stdout.split()[0]) if result.returncode == 0 else 0
            
            return {
                'path': str(repo_path),
                'size_bytes': repo_size_bytes,
                'size_gb': round(repo_size_bytes / (1024**3), 2),
                'free_space_bytes': free_space_bytes,
                'free_space_gb': round(free_space_bytes / (1024**3), 2),
                'total_space_bytes': total_space_bytes,
                'total_space_gb': round(total_space_bytes / (1024**3), 2),
                'used_percentage': round(used_percentage, 2)
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def analyze_backup_types(self, backup_list: List[Dict]) -> Dict:
        """
        Analysiert Backup-Typen und -Häufigkeiten
        """
        type_counts = {'full': 0, 'diff': 0, 'incr': 0}
        
        for backup in backup_list:
            backup_type = backup.get('type', 'unknown')
            if backup_type in type_counts:
                type_counts[backup_type] += 1
        
        return type_counts
    
    def calculate_health_status(self, backup_list: List[Dict], repo_stats: Dict) -> Dict:
        """
        Berechnet Gesundheitsstatus des Backup-Systems
        """
        health = {
            'overall': 'healthy',
            'issues': [],
            'score': 100
        }
        
        # Check backup freshness
        if backup_list:
            latest_backup = backup_list[-1]
            backup_time_str = latest_backup.get('timestamp', {}).get('start', '')
            
            if backup_time_str:
                try:
                    backup_time = datetime.datetime.strptime(backup_time_str, '%Y-%m-%d %H:%M:%S%z')
                    age_hours = (datetime.datetime.now(backup_time.tzinfo) - backup_time).total_seconds() / 3600
                    
                    if age_hours > 48:  # More than 2 days old
                        health['issues'].append(f'Latest backup is {age_hours:.1f} hours old')
                        health['score'] -= 30
                    elif age_hours > 24:  # More than 1 day old
                        health['issues'].append(f'Latest backup is {age_hours:.1f} hours old')
                        health['score'] -= 15
                except:
                    health['issues'].append('Cannot parse latest backup timestamp')
                    health['score'] -= 10
        else:
            health['issues'].append('No backups found')
            health['score'] = 0
        
        # Check disk space
        if 'used_percentage' in repo_stats:
            used_pct = repo_stats['used_percentage']
            if used_pct > 90:
                health['issues'].append(f'Repository disk usage very high ({used_pct:.1f}%)')
                health['score'] -= 40
            elif used_pct > 80:
                health['issues'].append(f'Repository disk usage high ({used_pct:.1f}%)')
                health['score'] -= 20
        
        # Check backup count
        if len(backup_list) < 3:
            health['issues'].append('Few backups available (less than 3)')
            health['score'] -= 15
        
        # Determine overall status
        if health['score'] >= 80:
            health['overall'] = 'healthy'
        elif health['score'] >= 60:
            health['overall'] = 'warning'
        else:
            health['overall'] = 'critical'
        
        return health
    
    def store_metrics(self, metrics: Dict):
        """
        Speichert Metriken in der Datenbank
        """
        if 'error' in metrics:
            return
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Store repository metrics
        if 'repository' in metrics and 'error' not in metrics['repository']:
            repo = metrics['repository']
            cursor.execute('''
                INSERT INTO repository_metrics 
                (timestamp, repo_size_bytes, free_space_bytes, total_space_bytes, backup_count)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                metrics['timestamp'],
                repo.get('size_bytes', 0),
                repo.get('free_space_bytes', 0),
                repo.get('total_space_bytes', 0),
                metrics.get('total_backups', 0)
            ))
        
        conn.commit()
        conn.close()
    
    def get_historical_data(self, hours: int = 24) -> Dict:
        """
        Holt historische Daten für Dashboard
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Repository metrics over time
        cursor.execute('''
            SELECT timestamp, repo_size_bytes, free_space_bytes, backup_count
            FROM repository_metrics
            WHERE created_at >= datetime('now', '-{} hours')
            ORDER BY created_at
        '''.format(hours))
        
        repo_history = []
        for row in cursor.fetchall():
            repo_history.append({
                'timestamp': row[0],
                'repo_size_gb': round(row[1] / (1024**3), 2) if row[1] else 0,
                'free_space_gb': round(row[2] / (1024**3), 2) if row[2] else 0,
                'backup_count': row[3]
            })
        
        # Recent backup history
        cursor.execute('''
            SELECT timestamp, backup_type, status, duration_seconds, size_bytes
            FROM backup_history
            WHERE created_at >= datetime('now', '-{} hours')
            ORDER BY created_at DESC
            LIMIT 20
        '''.format(hours))
        
        backup_history = []
        for row in cursor.fetchall():
            backup_history.append({
                'timestamp': row[0],
                'backup_type': row[1],
                'status': row[2],
                'duration_minutes': round(row[3] / 60, 1) if row[3] else 0,
                'size_gb': round(row[4] / (1024**3), 2) if row[4] else 0
            })
        
        conn.close()
        
        return {
            'repository_history': repo_history,
            'backup_history': backup_history
        }
    
    def setup_routes(self):
        """
        Konfiguriert Flask-Routen
        """
        
        @self.app.route('/')
        def dashboard():
            return render_template_string(self.get_dashboard_template())
        
        @self.app.route('/api/metrics')
        def api_metrics():
            current_metrics = self.collect_backup_metrics()
            historical_data = self.get_historical_data()
            
            return jsonify({
                'current': current_metrics,
                'historical': historical_data,
                'last_updated': datetime.datetime.now().isoformat()
            })
        
        @self.app.route('/api/health')
        def api_health():
            metrics = self.collect_backup_metrics()
            if 'error' in metrics:
                return jsonify({'status': 'error', 'message': metrics['error']}), 500
            
            health = metrics.get('health_status', {})
            return jsonify(health)
        
        @self.app.route('/api/verification/run', methods=['POST'])
        def api_run_verification():
            # Run backup verification
            try:
                result = subprocess.run([
                    'python3', '/usr/local/bin/backup-verification.py', '--quick', '--silent'
                ], capture_output=True, text=True, timeout=300)
                
                return jsonify({
                    'success': result.returncode == 0,
                    'output': result.stdout,
                    'error': result.stderr if result.returncode != 0 else None
                })
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)}), 500
    
    def get_dashboard_template(self) -> str:
        """
        HTML Template für das Dashboard
        """
        return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ExaPG Backup Monitoring Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 1rem 2rem; }
        .header h1 { margin: 0; }
        .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; padding: 2rem; }
        .card { background: white; border-radius: 8px; padding: 1.5rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card h3 { margin-bottom: 1rem; color: #2c3e50; }
        .metric { display: flex; justify-content: space-between; margin-bottom: 0.5rem; }
        .metric-value { font-weight: bold; }
        .health-healthy { color: #27ae60; }
        .health-warning { color: #f39c12; }
        .health-critical { color: #e74c3c; }
        .chart-container { width: 100%; height: 300px; }
        .refresh-btn { background: #3498db; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer; }
        .refresh-btn:hover { background: #2980b9; }
        .status-indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }
        .status-healthy { background-color: #27ae60; }
        .status-warning { background-color: #f39c12; }
        .status-critical { background-color: #e74c3c; }
        .backup-history { max-height: 400px; overflow-y: auto; }
        .backup-item { padding: 0.5rem; border-bottom: 1px solid #eee; }
        .backup-item:last-child { border-bottom: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ExaPG Backup Monitoring Dashboard</h1>
        <button class="refresh-btn" onclick="refreshDashboard()">🔄 Refresh</button>
    </div>
    
    <div class="dashboard">
        <div class="card">
            <h3>System Health</h3>
            <div id="health-status">
                <div class="metric">
                    <span>Status:</span>
                    <span id="health-overall" class="metric-value">Loading...</span>
                </div>
                <div class="metric">
                    <span>Health Score:</span>
                    <span id="health-score" class="metric-value">-</span>
                </div>
                <div id="health-issues"></div>
            </div>
        </div>
        
        <div class="card">
            <h3>Backup Summary</h3>
            <div id="backup-summary">
                <div class="metric">
                    <span>Total Backups:</span>
                    <span id="total-backups" class="metric-value">-</span>
                </div>
                <div class="metric">
                    <span>Latest Backup:</span>
                    <span id="latest-backup" class="metric-value">-</span>
                </div>
                <div class="metric">
                    <span>Full Backups:</span>
                    <span id="full-backups" class="metric-value">-</span>
                </div>
                <div class="metric">
                    <span>Incremental:</span>
                    <span id="incr-backups" class="metric-value">-</span>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>Repository Status</h3>
            <div id="repository-status">
                <div class="metric">
                    <span>Repository Size:</span>
                    <span id="repo-size" class="metric-value">-</span>
                </div>
                <div class="metric">
                    <span>Free Space:</span>
                    <span id="free-space" class="metric-value">-</span>
                </div>
                <div class="metric">
                    <span>Disk Usage:</span>
                    <span id="disk-usage" class="metric-value">-</span>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>Repository Growth</h3>
            <div class="chart-container">
                <canvas id="repo-growth-chart"></canvas>
            </div>
        </div>
        
        <div class="card">
            <h3>Backup History (Last 24h)</h3>
            <div id="backup-history" class="backup-history">
                <div>Loading...</div>
            </div>
        </div>
        
        <div class="card">
            <h3>Actions</h3>
            <button class="refresh-btn" onclick="runVerification()" style="margin-bottom: 1rem; width: 100%;">
                🔍 Run Backup Verification
            </button>
            <button class="refresh-btn" onclick="downloadReport()" style="width: 100%;">
                📊 Download Report
            </button>
            <div id="action-result" style="margin-top: 1rem;"></div>
        </div>
    </div>

    <script>
        let repoGrowthChart = null;
        
        function refreshDashboard() {
            fetch('/api/metrics')
                .then(response => response.json())
                .then(data => {
                    updateDashboard(data);
                })
                .catch(error => {
                    console.error('Error refreshing dashboard:', error);
                    document.getElementById('health-overall').textContent = 'Error loading data';
                });
        }
        
        function updateDashboard(data) {
            const current = data.current;
            const historical = data.historical;
            
            // Update health status
            if (current.health_status) {
                const health = current.health_status;
                const healthElement = document.getElementById('health-overall');
                healthElement.textContent = health.overall.toUpperCase();
                healthElement.className = `metric-value health-${health.overall}`;
                
                document.getElementById('health-score').textContent = health.score + '/100';
                
                const issuesElement = document.getElementById('health-issues');
                if (health.issues && health.issues.length > 0) {
                    issuesElement.innerHTML = '<strong>Issues:</strong><ul>' + 
                        health.issues.map(issue => `<li>${issue}</li>`).join('') + '</ul>';
                } else {
                    issuesElement.innerHTML = '<div style="color: #27ae60;">✓ No issues detected</div>';
                }
            }
            
            // Update backup summary
            document.getElementById('total-backups').textContent = current.total_backups || '-';
            
            if (current.latest_backup) {
                const latest = current.latest_backup;
                const timestamp = latest.timestamp ? latest.timestamp.start : 'Unknown';
                document.getElementById('latest-backup').textContent = 
                    `${latest.type} (${timestamp})`;
            }
            
            if (current.backup_types) {
                document.getElementById('full-backups').textContent = current.backup_types.full || 0;
                document.getElementById('incr-backups').textContent = current.backup_types.incr || 0;
            }
            
            // Update repository status
            if (current.repository && !current.repository.error) {
                const repo = current.repository;
                document.getElementById('repo-size').textContent = repo.size_gb + ' GB';
                document.getElementById('free-space').textContent = repo.free_space_gb + ' GB';
                document.getElementById('disk-usage').textContent = repo.used_percentage + '%';
            }
            
            // Update backup history
            updateBackupHistory(historical.backup_history);
            
            // Update repository growth chart
            updateRepoGrowthChart(historical.repository_history);
        }
        
        function updateBackupHistory(history) {
            const container = document.getElementById('backup-history');
            
            if (!history || history.length === 0) {
                container.innerHTML = '<div>No recent backups</div>';
                return;
            }
            
            container.innerHTML = history.map(backup => `
                <div class="backup-item">
                    <div style="display: flex; justify-content: space-between;">
                        <strong>${backup.backup_type.toUpperCase()}</strong>
                        <span class="status-indicator status-${backup.status === 'success' ? 'healthy' : 'critical'}"></span>
                    </div>
                    <div style="font-size: 0.9em; color: #666;">
                        ${backup.timestamp} • ${backup.duration_minutes}min • ${backup.size_gb}GB
                    </div>
                </div>
            `).join('');
        }
        
        function updateRepoGrowthChart(history) {
            const ctx = document.getElementById('repo-growth-chart').getContext('2d');
            
            if (repoGrowthChart) {
                repoGrowthChart.destroy();
            }
            
            if (!history || history.length === 0) {
                return;
            }
            
            repoGrowthChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: history.map(item => {
                        const date = new Date(item.timestamp);
                        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
                    }),
                    datasets: [
                        {
                            label: 'Repository Size (GB)',
                            data: history.map(item => item.repo_size_gb),
                            borderColor: '#3498db',
                            backgroundColor: 'rgba(52, 152, 219, 0.1)',
                            tension: 0.4
                        },
                        {
                            label: 'Backup Count',
                            data: history.map(item => item.backup_count),
                            borderColor: '#e74c3c',
                            backgroundColor: 'rgba(231, 76, 60, 0.1)',
                            yAxisID: 'y1',
                            tension: 0.4
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: { display: true, text: 'Size (GB)' }
                        },
                        y1: {
                            type: 'linear',
                            position: 'right',
                            beginAtZero: true,
                            title: { display: true, text: 'Count' },
                            grid: { drawOnChartArea: false }
                        }
                    }
                }
            });
        }
        
        function runVerification() {
            const resultDiv = document.getElementById('action-result');
            resultDiv.innerHTML = '<div>Running verification...</div>';
            
            fetch('/api/verification/run', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        resultDiv.innerHTML = '<div style="color: #27ae60;">✓ Verification completed successfully</div>';
                    } else {
                        resultDiv.innerHTML = `<div style="color: #e74c3c;">✗ Verification failed: ${data.error}</div>`;
                    }
                    
                    // Refresh dashboard after verification
                    setTimeout(refreshDashboard, 2000);
                })
                .catch(error => {
                    resultDiv.innerHTML = `<div style="color: #e74c3c;">Error: ${error}</div>`;
                });
        }
        
        function downloadReport() {
            window.open('/api/metrics', '_blank');
        }
        
        // Auto-refresh every 5 minutes
        setInterval(refreshDashboard, 300000);
        
        // Initial load
        refreshDashboard();
    </script>
</body>
</html>
        '''
    
    def start_background_monitoring(self):
        """
        Startet Background-Monitoring Thread
        """
        def monitoring_worker():
            # Schedule periodic data collection
            schedule.every(5).minutes.do(self.collect_and_store_metrics)
            
            while True:
                schedule.run_pending()
                time.sleep(60)  # Check every minute
        
        # Start monitoring thread
        monitoring_thread = threading.Thread(target=monitoring_worker, daemon=True)
        monitoring_thread.start()
    
    def collect_and_store_metrics(self):
        """
        Sammelt und speichert Metriken
        """
        metrics = self.collect_backup_metrics()
        if 'error' not in metrics:
            self.store_metrics(metrics)
    
    def run(self):
        """
        Startet das Dashboard
        """
        print(f"Starting ExaPG Backup Monitoring Dashboard on port {self.dashboard_port}")
        print(f"Dashboard URL: http://localhost:{self.dashboard_port}")
        
        # Initial metrics collection
        self.collect_and_store_metrics()
        
        # Start Flask app
        self.app.run(
            host='0.0.0.0',
            port=self.dashboard_port,
            debug=False,
            threaded=True
        )

def main():
    """
    Hauptfunktion
    """
    import argparse
    
    parser = argparse.ArgumentParser(description='ExaPG Backup Monitoring Dashboard')
    parser.add_argument('--port', type=int, default=8080,
                       help='Dashboard port (default: 8080)')
    parser.add_argument('--refresh-interval', type=int, default=300,
                       help='Metrics refresh interval in seconds (default: 300)')
    
    args = parser.parse_args()
    
    # Set environment variables from args
    os.environ['BACKUP_DASHBOARD_PORT'] = str(args.port)
    os.environ['BACKUP_DASHBOARD_REFRESH'] = str(args.refresh_interval)
    
    try:
        dashboard = BackupMonitoringDashboard()
        dashboard.run()
    except KeyboardInterrupt:
        print("\nDashboard stopped by user")
    except Exception as e:
        print(f"Dashboard failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 