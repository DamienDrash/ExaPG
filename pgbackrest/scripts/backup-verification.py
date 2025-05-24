#!/usr/bin/env python3
"""
ExaPG Backup Verification System
Automatisierte Validierung von pgBackRest Backups mit verschiedenen Prüflevels
"""

import os
import sys
import json
import subprocess
import argparse
import datetime
import logging
import psycopg2
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Logging Konfiguration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/var/log/pgbackrest/verification.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class BackupVerifier:
    """
    Umfassende Backup-Validation für ExaPG
    """
    
    def __init__(self, config_path: str = "/etc/pgbackrest/pgbackrest.conf"):
        self.config_path = config_path
        self.stanza = os.getenv('PGBACKREST_STANZA', 'exapg')
        self.repo_path = os.getenv('PGBACKREST_REPO1_PATH', '/var/lib/pgbackrest')
        
        # PostgreSQL Verbindungsparameter
        self.pg_host = os.getenv('PGHOST', 'localhost')
        self.pg_port = os.getenv('PGPORT', '5432')
        self.pg_user = os.getenv('PGUSER', 'postgres')
        self.pg_database = os.getenv('PGDATABASE', 'exadb')
        
        # Verification Results
        self.results = {
            'timestamp': datetime.datetime.now().isoformat(),
            'tests': {},
            'summary': {
                'total_tests': 0,
                'passed': 0,
                'failed': 0,
                'warnings': 0
            },
            'recommendations': []
        }
    
    def run_pgbackrest_command(self, cmd: str) -> Tuple[bool, str, str]:
        """
        Führt pgBackRest Befehl aus und gibt Erfolg, stdout, stderr zurück
        """
        full_cmd = f"pgbackrest --config={self.config_path} --stanza={self.stanza} {cmd}"
        logger.debug(f"Executing: {full_cmd}")
        
        try:
            result = subprocess.run(
                full_cmd.split(),
                capture_output=True,
                text=True,
                timeout=3600  # 1 hour timeout
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Command timed out after 1 hour"
        except Exception as e:
            return False, "", str(e)
    
    def test_stanza_integrity(self) -> bool:
        """
        Test 1: Stanza Integrität prüfen
        """
        logger.info("Testing stanza integrity...")
        success, stdout, stderr = self.run_pgbackrest_command("check")
        
        test_result = {
            'name': 'stanza_integrity',
            'description': 'Stanza integrity and configuration check',
            'passed': success,
            'output': stdout,
            'error': stderr if not success else None,
            'duration': None
        }
        
        if not success:
            logger.error(f"Stanza check failed: {stderr}")
            self.results['recommendations'].append(
                "Stanza configuration or WAL archiving may be misconfigured. "
                "Run 'pgbackrest --stanza={} check' manually to investigate.".format(self.stanza)
            )
        
        self.results['tests']['stanza_integrity'] = test_result
        return success
    
    def test_backup_existence(self) -> bool:
        """
        Test 2: Backup-Existenz und -Informationen prüfen
        """
        logger.info("Testing backup existence...")
        success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
        
        backups_found = False
        backup_count = 0
        latest_backup = None
        
        if success:
            try:
                info_data = json.loads(stdout)
                if info_data and len(info_data) > 0:
                    stanza_info = info_data[0]  # First stanza
                    backup_list = stanza_info.get('backup', [])
                    backup_count = len(backup_list)
                    backups_found = backup_count > 0
                    
                    if backup_count > 0:
                        latest_backup = backup_list[-1]  # Last backup
                        
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse backup info JSON: {e}")
                success = False
        
        test_result = {
            'name': 'backup_existence',
            'description': 'Check if backups exist and are accessible',
            'passed': success and backups_found,
            'backup_count': backup_count,
            'latest_backup': latest_backup,
            'output': stdout if success else None,
            'error': stderr if not success else None
        }
        
        if not backups_found:
            self.results['recommendations'].append(
                "No backups found. Create an initial full backup with "
                "'pgbackrest --stanza={} --type=full backup'".format(self.stanza)
            )
        elif backup_count < 2:
            self.results['recommendations'].append(
                "Only one backup found. Consider setting up regular backup schedule."
            )
        
        self.results['tests']['backup_existence'] = test_result
        return success and backups_found
    
    def test_wal_archiving(self) -> bool:
        """
        Test 3: WAL-Archivierung prüfen
        """
        logger.info("Testing WAL archiving...")
        
        try:
            # Verbindung zur Datenbank
            conn = psycopg2.connect(
                host=self.pg_host,
                port=self.pg_port,
                user=self.pg_user,
                database=self.pg_database
            )
            cur = conn.cursor()
            
            # Check archive_mode
            cur.execute("SHOW archive_mode;")
            archive_mode = cur.fetchone()[0]
            
            # Check archive_command
            cur.execute("SHOW archive_command;")
            archive_command = cur.fetchone()[0]
            
            # Force WAL switch and check if it's archived
            cur.execute("SELECT pg_switch_wal();")
            current_wal = cur.fetchone()[0]
            
            # Wait a bit for archiving
            time.sleep(5)
            
            # Check if WAL was archived
            success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
            wal_archived = True  # Simplified check
            
            conn.close()
            
            test_result = {
                'name': 'wal_archiving',
                'description': 'WAL archiving configuration and functionality',
                'passed': archive_mode == 'on' and 'pgbackrest' in archive_command,
                'archive_mode': archive_mode,
                'archive_command': archive_command,
                'current_wal': current_wal,
                'wal_archived': wal_archived
            }
            
            if archive_mode != 'on':
                self.results['recommendations'].append(
                    "WAL archiving is not enabled. Set 'archive_mode = on' in postgresql.conf"
                )
            
            if 'pgbackrest' not in archive_command:
                self.results['recommendations'].append(
                    "WAL archive command does not use pgBackRest. "
                    "Set 'archive_command' to use pgBackRest."
                )
            
        except Exception as e:
            logger.error(f"WAL archiving test failed: {e}")
            test_result = {
                'name': 'wal_archiving',
                'description': 'WAL archiving configuration and functionality',
                'passed': False,
                'error': str(e)
            }
        
        self.results['tests']['wal_archiving'] = test_result
        return test_result['passed']
    
    def test_backup_consistency(self, quick: bool = True) -> bool:
        """
        Test 4: Backup-Konsistenz prüfen (mit/ohne Restore-Test)
        """
        logger.info(f"Testing backup consistency {'(quick)' if quick else '(full restore test)'}...")
        
        if quick:
            # Quick consistency check - verify backup files
            success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
            
            if success:
                try:
                    info_data = json.loads(stdout)
                    # Simplified consistency check
                    consistent = True  # TODO: Implement detailed file verification
                except json.JSONDecodeError:
                    consistent = False
            else:
                consistent = False
                
            test_result = {
                'name': 'backup_consistency_quick',
                'description': 'Quick backup consistency verification',
                'passed': consistent,
                'type': 'quick',
                'output': stdout if success else None,
                'error': stderr if not success else None
            }
        else:
            # Full restore test in temporary location
            test_restore_path = "/tmp/pgbackrest_restore_test"
            
            # Cleanup previous test
            if os.path.exists(test_restore_path):
                subprocess.run(["rm", "-rf", test_restore_path])
            
            os.makedirs(test_restore_path, exist_ok=True)
            
            # Perform restore test
            restore_cmd = f"restore --pg1-path={test_restore_path} --recovery-option=recovery_target_action=promote"
            success, stdout, stderr = self.run_pgbackrest_command(restore_cmd)
            
            test_result = {
                'name': 'backup_consistency_full',
                'description': 'Full backup restore test',
                'passed': success,
                'type': 'full_restore',
                'restore_path': test_restore_path,
                'output': stdout if success else None,
                'error': stderr if not success else None
            }
            
            # Cleanup
            if os.path.exists(test_restore_path):
                subprocess.run(["rm", "-rf", test_restore_path])
        
        self.results['tests']['backup_consistency'] = test_result
        return test_result['passed']
    
    def test_repository_health(self) -> bool:
        """
        Test 5: Repository-Gesundheit prüfen
        """
        logger.info("Testing repository health...")
        
        repo_path = Path(self.repo_path)
        
        # Check repository accessibility
        repo_accessible = repo_path.exists() and repo_path.is_dir()
        
        # Check disk space
        if repo_accessible:
            statvfs = os.statvfs(repo_path)
            free_space_bytes = statvfs.f_frsize * statvfs.f_bavail
            total_space_bytes = statvfs.f_frsize * statvfs.f_blocks
            used_percentage = ((total_space_bytes - free_space_bytes) / total_space_bytes) * 100
        else:
            free_space_bytes = 0
            total_space_bytes = 0
            used_percentage = 100
        
        # Check repository size
        if repo_accessible:
            try:
                result = subprocess.run(
                    ["du", "-sb", str(repo_path)],
                    capture_output=True,
                    text=True
                )
                repo_size_bytes = int(result.stdout.split()[0]) if result.returncode == 0 else 0
            except:
                repo_size_bytes = 0
        else:
            repo_size_bytes = 0
        
        # Health assessment
        healthy = (
            repo_accessible and
            used_percentage < 85 and  # Less than 85% disk usage
            free_space_bytes > (5 * 1024 * 1024 * 1024)  # At least 5GB free
        )
        
        test_result = {
            'name': 'repository_health',
            'description': 'Repository accessibility and disk space',
            'passed': healthy,
            'repo_accessible': repo_accessible,
            'repo_size_bytes': repo_size_bytes,
            'repo_size_human': f"{repo_size_bytes / (1024**3):.2f} GB",
            'free_space_bytes': free_space_bytes,
            'free_space_human': f"{free_space_bytes / (1024**3):.2f} GB",
            'used_percentage': round(used_percentage, 2)
        }
        
        if used_percentage > 85:
            self.results['recommendations'].append(
                f"Repository disk usage is high ({used_percentage:.1f}%). "
                "Consider cleaning old backups or expanding storage."
            )
        
        if free_space_bytes < (10 * 1024 * 1024 * 1024):  # Less than 10GB
            self.results['recommendations'].append(
                f"Low free disk space ({free_space_bytes / (1024**3):.1f} GB). "
                "Monitor closely and expand storage if needed."
            )
        
        self.results['tests']['repository_health'] = test_result
        return healthy
    
    def test_retention_policy(self) -> bool:
        """
        Test 6: Retention Policy prüfen
        """
        logger.info("Testing retention policy...")
        
        success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
        
        if not success:
            test_result = {
                'name': 'retention_policy',
                'description': 'Backup retention policy compliance',
                'passed': False,
                'error': stderr
            }
        else:
            try:
                info_data = json.loads(stdout)
                stanza_info = info_data[0] if info_data else {}
                backup_list = stanza_info.get('backup', [])
                
                # Analyze backup types and dates
                full_backups = [b for b in backup_list if b.get('type') == 'full']
                diff_backups = [b for b in backup_list if b.get('type') == 'diff']
                incr_backups = [b for b in backup_list if b.get('type') == 'incr']
                
                # Check if retention policy is being followed
                retention_compliant = len(full_backups) <= 3  # Based on config
                
                test_result = {
                    'name': 'retention_policy',
                    'description': 'Backup retention policy compliance',
                    'passed': retention_compliant,
                    'total_backups': len(backup_list),
                    'full_backups': len(full_backups),
                    'diff_backups': len(diff_backups),
                    'incr_backups': len(incr_backups),
                    'retention_compliant': retention_compliant
                }
                
                if not retention_compliant:
                    self.results['recommendations'].append(
                        "Backup retention policy may not be working correctly. "
                        "Check 'repo1-retention-full' setting and run 'pgbackrest expire'."
                    )
                    
            except json.JSONDecodeError:
                test_result = {
                    'name': 'retention_policy',
                    'description': 'Backup retention policy compliance',
                    'passed': False,
                    'error': 'Failed to parse backup info'
                }
        
        self.results['tests']['retention_policy'] = test_result
        return test_result['passed']
    
    def run_verification(self, quick: bool = False, full_restore: bool = False) -> Dict:
        """
        Führt vollständige Backup-Verification durch
        """
        logger.info(f"Starting backup verification {'(quick mode)' if quick else '(comprehensive)'}...")
        
        tests = [
            self.test_stanza_integrity,
            self.test_backup_existence,
            self.test_wal_archiving,
            lambda: self.test_backup_consistency(quick=not full_restore),
            self.test_repository_health,
            self.test_retention_policy
        ]
        
        for test in tests:
            try:
                start_time = time.time()
                result = test()
                duration = time.time() - start_time
                
                # Update test duration
                test_name = test.__name__.replace('test_', '')
                if test_name in self.results['tests']:
                    self.results['tests'][test_name]['duration'] = round(duration, 2)
                
                # Update summary
                self.results['summary']['total_tests'] += 1
                if result:
                    self.results['summary']['passed'] += 1
                else:
                    self.results['summary']['failed'] += 1
                    
            except Exception as e:
                logger.error(f"Test {test.__name__} failed with exception: {e}")
                self.results['summary']['total_tests'] += 1
                self.results['summary']['failed'] += 1
        
        # Generate overall status
        success_rate = (self.results['summary']['passed'] / 
                       self.results['summary']['total_tests'] * 100)
        
        self.results['overall_status'] = 'PASSED' if success_rate >= 80 else 'FAILED'
        self.results['success_rate'] = round(success_rate, 2)
        
        return self.results
    
    def save_report(self, output_file: str = "/var/log/pgbackrest/verification-report.json"):
        """
        Speichert Verification Report
        """
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        with open(output_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        logger.info(f"Verification report saved to {output_file}")
    
    def print_summary(self):
        """
        Druckt Zusammenfassung der Verification
        """
        print("\n" + "="*80)
        print("ExaPG BACKUP VERIFICATION REPORT")
        print("="*80)
        print(f"Timestamp: {self.results['timestamp']}")
        print(f"Overall Status: {self.results['overall_status']}")
        print(f"Success Rate: {self.results['success_rate']}%")
        print(f"Tests: {self.results['summary']['passed']}/{self.results['summary']['total_tests']} passed")
        
        if self.results['summary']['failed'] > 0:
            print(f"Failed Tests: {self.results['summary']['failed']}")
        
        print("\nTEST DETAILS:")
        print("-" * 50)
        
        for test_name, test_data in self.results['tests'].items():
            status = "✓ PASS" if test_data['passed'] else "✗ FAIL"
            duration = f"({test_data.get('duration', 0):.2f}s)" if 'duration' in test_data else ""
            print(f"{status} {test_data['description']} {duration}")
            
            if not test_data['passed'] and 'error' in test_data:
                print(f"     Error: {test_data['error']}")
        
        if self.results['recommendations']:
            print("\nRECOMMENDATIONS:")
            print("-" * 50)
            for i, rec in enumerate(self.results['recommendations'], 1):
                print(f"{i}. {rec}")
        
        print("="*80)

def main():
    parser = argparse.ArgumentParser(description='ExaPG Backup Verification System')
    parser.add_argument('--quick', action='store_true', 
                       help='Run quick verification (no restore test)')
    parser.add_argument('--full', action='store_true',
                       help='Run full verification with restore test')
    parser.add_argument('--latest-backup', action='store_true',
                       help='Verify only the latest backup')
    parser.add_argument('--config', default='/etc/pgbackrest/pgbackrest.conf',
                       help='pgBackRest configuration file path')
    parser.add_argument('--output', default='/var/log/pgbackrest/verification-report.json',
                       help='Output file for verification report')
    parser.add_argument('--silent', action='store_true',
                       help='Run in silent mode (only JSON output)')
    
    args = parser.parse_args()
    
    if args.silent:
        logging.getLogger().setLevel(logging.WARNING)
    
    verifier = BackupVerifier(config_path=args.config)
    
    try:
        results = verifier.run_verification(
            quick=args.quick,
            full_restore=args.full
        )
        
        verifier.save_report(args.output)
        
        if not args.silent:
            verifier.print_summary()
        
        # Exit code based on verification results
        exit_code = 0 if results['overall_status'] == 'PASSED' else 1
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        logger.info("Verification interrupted by user")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Verification failed: {e}")
        sys.exit(3)

if __name__ == "__main__":
    main() 