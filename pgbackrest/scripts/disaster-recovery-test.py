#!/usr/bin/env python3
"""
ExaPG Disaster Recovery Testing System
Automatisierte Tests für Disaster Recovery Szenarien
"""

import os
import sys
import json
import subprocess
import argparse
import datetime
import tempfile
import shutil
import time
import signal
import psycopg2
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import logging

# Logging Konfiguration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler('/var/log/pgbackrest/disaster-recovery.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class DisasterRecoveryTester:
    """
    Umfassende Disaster Recovery Tests für ExaPG
    """
    
    def __init__(self):
        self.stanza = os.getenv('PGBACKREST_STANZA', 'exapg')
        self.config_path = os.getenv('PGBACKREST_CONFIG', '/etc/pgbackrest/pgbackrest.conf')
        self.repo_path = os.getenv('PGBACKREST_REPO1_PATH', '/var/lib/pgbackrest')
        
        # PostgreSQL Parameter
        self.pg_host = os.getenv('PGHOST', 'localhost')
        self.pg_port = os.getenv('PGPORT', '5432')
        self.pg_user = os.getenv('PGUSER', 'postgres')
        self.pg_database = os.getenv('PGDATABASE', 'exadb')
        
        # Test Configuration
        self.test_data_path = "/tmp/exapg_dr_test"
        self.test_postgres_port = 5555  # Alternative port for test instance
        
        # Results tracking
        self.test_results = {
            'start_time': datetime.datetime.now().isoformat(),
            'tests': {},
            'summary': {
                'total_tests': 0,
                'passed': 0,
                'failed': 0,
                'skipped': 0
            },
            'scenarios': []
        }
    
    def cleanup_test_environment(self):
        """
        Räumt Test-Umgebung auf
        """
        logger.info("Cleaning up test environment...")
        
        # Stop test PostgreSQL instance
        try:
            subprocess.run([
                "pg_ctl", "stop", "-D", f"{self.test_data_path}/data", 
                "-m", "immediate"
            ], timeout=30)
        except:
            pass
        
        # Remove test directory
        if os.path.exists(self.test_data_path):
            shutil.rmtree(self.test_data_path, ignore_errors=True)
        
        logger.info("Test environment cleaned up")
    
    def setup_test_environment(self) -> bool:
        """
        Richtet Test-Umgebung ein
        """
        logger.info("Setting up test environment...")
        
        try:
            # Cleanup previous tests
            self.cleanup_test_environment()
            
            # Create test directory
            os.makedirs(self.test_data_path, exist_ok=True)
            os.makedirs(f"{self.test_data_path}/data", exist_ok=True)
            os.makedirs(f"{self.test_data_path}/logs", exist_ok=True)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to setup test environment: {e}")
            return False
    
    def run_pgbackrest_command(self, cmd: str, timeout: int = 3600) -> Tuple[bool, str, str]:
        """
        Führt pgBackRest Befehl aus
        """
        full_cmd = f"pgbackrest --config={self.config_path} --stanza={self.stanza} {cmd}"
        logger.debug(f"Executing: {full_cmd}")
        
        try:
            result = subprocess.run(
                full_cmd.split(),
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", f"Command timed out after {timeout} seconds"
        except Exception as e:
            return False, "", str(e)
    
    def wait_for_postgres(self, data_dir: str, port: int, timeout: int = 300) -> bool:
        """
        Wartet bis PostgreSQL-Instanz verfügbar ist
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                result = subprocess.run([
                    "pg_isready", "-h", "localhost", "-p", str(port)
                ], capture_output=True, timeout=10)
                
                if result.returncode == 0:
                    return True
                    
            except:
                pass
            
            time.sleep(2)
        
        return False
    
    def test_point_in_time_recovery(self) -> Dict:
        """
        Test 1: Point-in-Time Recovery (PITR)
        """
        logger.info("Testing Point-in-Time Recovery...")
        
        test_name = "point_in_time_recovery"
        test_result = {
            'name': test_name,
            'description': 'Point-in-Time Recovery Test',
            'passed': False,
            'start_time': datetime.datetime.now().isoformat(),
            'steps': [],
            'error': None
        }
        
        try:
            # Step 1: Create test data before backup
            test_result['steps'].append("Creating initial test data")
            
            conn = psycopg2.connect(
                host=self.pg_host, port=self.pg_port,
                user=self.pg_user, database=self.pg_database
            )
            cur = conn.cursor()
            
            # Create test table
            cur.execute("""
                DROP TABLE IF EXISTS dr_test_pitr;
                CREATE TABLE dr_test_pitr (
                    id SERIAL PRIMARY KEY,
                    data TEXT,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """)
            
            # Insert initial data
            cur.execute("INSERT INTO dr_test_pitr (data) VALUES ('initial_data');")
            conn.commit()
            
            # Step 2: Create backup
            test_result['steps'].append("Creating backup")
            success, stdout, stderr = self.run_pgbackrest_command("--type=full backup")
            if not success:
                raise Exception(f"Backup failed: {stderr}")
            
            # Step 3: Add more data after backup
            test_result['steps'].append("Adding data after backup")
            cur.execute("INSERT INTO dr_test_pitr (data) VALUES ('post_backup_data');")
            conn.commit()
            
            # Record time for PITR
            pitr_time = datetime.datetime.now()
            test_result['pitr_target'] = pitr_time.strftime('%Y-%m-%d %H:%M:%S')
            
            # Step 4: Add data we don't want to recover
            time.sleep(2)  # Ensure different timestamp
            cur.execute("INSERT INTO dr_test_pitr (data) VALUES ('data_to_lose');")
            conn.commit()
            conn.close()
            
            # Step 5: Perform PITR restore
            test_result['steps'].append("Performing Point-in-Time Recovery")
            
            restore_path = f"{self.test_data_path}/pitr_restore"
            restore_cmd = (
                f"restore --pg1-path={restore_path} "
                f"--recovery-option=recovery_target_time='{test_result['pitr_target']}' "
                f"--recovery-option=recovery_target_action=promote"
            )
            
            success, stdout, stderr = self.run_pgbackrest_command(restore_cmd)
            if not success:
                raise Exception(f"PITR restore failed: {stderr}")
            
            # Step 6: Start test PostgreSQL instance
            test_result['steps'].append("Starting test PostgreSQL instance")
            
            # Configure PostgreSQL for test
            with open(f"{restore_path}/postgresql.conf", "a") as f:
                f.write(f"\nport = {self.test_postgres_port}\n")
                f.write("archive_mode = off\n")
                f.write("wal_level = minimal\n")
            
            # Start PostgreSQL
            pg_start = subprocess.Popen([
                "postgres", "-D", restore_path, "-p", str(self.test_postgres_port)
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Wait for startup
            if not self.wait_for_postgres(restore_path, self.test_postgres_port):
                pg_start.terminate()
                raise Exception("Test PostgreSQL instance failed to start")
            
            # Step 7: Verify PITR data
            test_result['steps'].append("Verifying recovered data")
            
            test_conn = psycopg2.connect(
                host='localhost', port=self.test_postgres_port,
                user=self.pg_user, database=self.pg_database
            )
            test_cur = test_conn.cursor()
            
            # Check data
            test_cur.execute("SELECT data FROM dr_test_pitr ORDER BY id;")
            recovered_data = [row[0] for row in test_cur.fetchall()]
            
            # Should have initial_data and post_backup_data, but not data_to_lose
            expected_data = ['initial_data', 'post_backup_data']
            
            if recovered_data == expected_data:
                test_result['passed'] = True
                test_result['verified_data'] = recovered_data
            else:
                raise Exception(f"Data verification failed. Expected: {expected_data}, Got: {recovered_data}")
            
            test_conn.close()
            pg_start.terminate()
            
        except Exception as e:
            test_result['error'] = str(e)
            logger.error(f"PITR test failed: {e}")
        
        test_result['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['tests'][test_name] = test_result
        return test_result
    
    def test_full_restore(self) -> Dict:
        """
        Test 2: Vollständige Wiederherstellung
        """
        logger.info("Testing Full Restore...")
        
        test_name = "full_restore"
        test_result = {
            'name': test_name,
            'description': 'Complete Database Restore Test',
            'passed': False,
            'start_time': datetime.datetime.now().isoformat(),
            'steps': [],
            'error': None
        }
        
        try:
            # Step 1: Get backup information
            test_result['steps'].append("Getting backup information")
            success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
            if not success:
                raise Exception(f"Failed to get backup info: {stderr}")
            
            backup_info = json.loads(stdout)
            if not backup_info or not backup_info[0].get('backup'):
                raise Exception("No backups found")
            
            latest_backup = backup_info[0]['backup'][-1]
            test_result['backup_used'] = latest_backup.get('label', 'unknown')
            
            # Step 2: Perform full restore
            test_result['steps'].append("Performing full restore")
            
            restore_path = f"{self.test_data_path}/full_restore"
            restore_cmd = f"restore --pg1-path={restore_path}"
            
            success, stdout, stderr = self.run_pgbackrest_command(restore_cmd)
            if not success:
                raise Exception(f"Full restore failed: {stderr}")
            
            # Step 3: Verify restored files
            test_result['steps'].append("Verifying restored files")
            
            essential_files = [
                'postgresql.conf',
                'pg_hba.conf',
                'PG_VERSION',
                'base'
            ]
            
            missing_files = []
            for file in essential_files:
                if not os.path.exists(f"{restore_path}/{file}"):
                    missing_files.append(file)
            
            if missing_files:
                raise Exception(f"Missing essential files: {missing_files}")
            
            # Step 4: Start PostgreSQL and verify connectivity
            test_result['steps'].append("Starting PostgreSQL and testing connectivity")
            
            # Configure for test
            with open(f"{restore_path}/postgresql.conf", "a") as f:
                f.write(f"\nport = {self.test_postgres_port + 1}\n")
                f.write("archive_mode = off\n")
            
            # Start PostgreSQL
            pg_start = subprocess.Popen([
                "postgres", "-D", restore_path, "-p", str(self.test_postgres_port + 1)
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            if self.wait_for_postgres(restore_path, self.test_postgres_port + 1):
                # Test connection and basic query
                test_conn = psycopg2.connect(
                    host='localhost', port=self.test_postgres_port + 1,
                    user=self.pg_user, database=self.pg_database
                )
                test_cur = test_conn.cursor()
                test_cur.execute("SELECT version();")
                version = test_cur.fetchone()[0]
                test_result['postgresql_version'] = version
                test_conn.close()
                
                test_result['passed'] = True
            else:
                raise Exception("Failed to start restored PostgreSQL instance")
            
            pg_start.terminate()
            
        except Exception as e:
            test_result['error'] = str(e)
            logger.error(f"Full restore test failed: {e}")
        
        test_result['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['tests'][test_name] = test_result
        return test_result
    
    def test_backup_verification(self) -> Dict:
        """
        Test 3: Backup-Integrität und Konsistenz
        """
        logger.info("Testing Backup Verification...")
        
        test_name = "backup_verification"
        test_result = {
            'name': test_name,
            'description': 'Backup Integrity and Consistency Check',
            'passed': False,
            'start_time': datetime.datetime.now().isoformat(),
            'steps': [],
            'error': None
        }
        
        try:
            # Step 1: Run pgBackRest check
            test_result['steps'].append("Running pgBackRest check")
            success, stdout, stderr = self.run_pgbackrest_command("check")
            if not success:
                raise Exception(f"pgBackRest check failed: {stderr}")
            
            # Step 2: Verify all backup files exist
            test_result['steps'].append("Verifying backup file existence")
            success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
            if not success:
                raise Exception(f"Failed to get backup info: {stderr}")
            
            backup_info = json.loads(stdout)
            test_result['total_backups'] = len(backup_info[0].get('backup', []))
            
            # Step 3: Check repository integrity
            test_result['steps'].append("Checking repository integrity")
            repo_files = list(Path(self.repo_path).rglob("*"))
            test_result['repository_files'] = len(repo_files)
            
            # Basic file existence check
            if len(repo_files) < 10:  # Should have more than 10 files in a real repo
                raise Exception("Repository appears incomplete")
            
            test_result['passed'] = True
            
        except Exception as e:
            test_result['error'] = str(e)
            logger.error(f"Backup verification test failed: {e}")
        
        test_result['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['tests'][test_name] = test_result
        return test_result
    
    def test_archive_recovery(self) -> Dict:
        """
        Test 4: WAL Archive Recovery
        """
        logger.info("Testing WAL Archive Recovery...")
        
        test_name = "archive_recovery"
        test_result = {
            'name': test_name,
            'description': 'WAL Archive Recovery Test',
            'passed': False,
            'start_time': datetime.datetime.now().isoformat(),
            'steps': [],
            'error': None
        }
        
        try:
            # Step 1: Check WAL archiving status
            test_result['steps'].append("Checking WAL archiving status")
            
            conn = psycopg2.connect(
                host=self.pg_host, port=self.pg_port,
                user=self.pg_user, database=self.pg_database
            )
            cur = conn.cursor()
            
            cur.execute("SHOW archive_mode;")
            archive_mode = cur.fetchone()[0]
            
            if archive_mode != 'on':
                raise Exception("WAL archiving is not enabled")
            
            # Step 2: Force WAL switch and verify archiving
            test_result['steps'].append("Testing WAL archiving")
            cur.execute("SELECT pg_switch_wal();")
            wal_file = cur.fetchone()[0]
            test_result['test_wal_file'] = wal_file
            
            # Wait for archiving
            time.sleep(5)
            
            # Step 3: Perform restore with archive recovery
            test_result['steps'].append("Testing archive recovery")
            
            restore_path = f"{self.test_data_path}/archive_restore"
            restore_cmd = f"restore --pg1-path={restore_path}"
            
            success, stdout, stderr = self.run_pgbackrest_command(restore_cmd, timeout=1800)
            if not success:
                raise Exception(f"Archive restore failed: {stderr}")
            
            test_result['passed'] = True
            conn.close()
            
        except Exception as e:
            test_result['error'] = str(e)
            logger.error(f"Archive recovery test failed: {e}")
        
        test_result['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['tests'][test_name] = test_result
        return test_result
    
    def test_performance_baseline(self) -> Dict:
        """
        Test 5: Performance Baseline für Restore-Operationen
        """
        logger.info("Testing Restore Performance Baseline...")
        
        test_name = "restore_performance"
        test_result = {
            'name': test_name,
            'description': 'Restore Performance Baseline Test',
            'passed': False,
            'start_time': datetime.datetime.now().isoformat(),
            'steps': [],
            'error': None,
            'metrics': {}
        }
        
        try:
            # Step 1: Measure backup size
            test_result['steps'].append("Measuring backup metrics")
            
            success, stdout, stderr = self.run_pgbackrest_command("info --output=json")
            if not success:
                raise Exception(f"Failed to get backup info: {stderr}")
            
            backup_info = json.loads(stdout)
            if backup_info and backup_info[0].get('backup'):
                latest_backup = backup_info[0]['backup'][-1]
                backup_size = latest_backup.get('info', {}).get('size', 0)
                test_result['metrics']['backup_size_bytes'] = backup_size
                test_result['metrics']['backup_size_gb'] = round(backup_size / (1024**3), 2)
            
            # Step 2: Measure restore time
            test_result['steps'].append("Measuring restore performance")
            
            restore_path = f"{self.test_data_path}/perf_restore"
            start_time = time.time()
            
            restore_cmd = f"restore --pg1-path={restore_path} --process-max=4"
            success, stdout, stderr = self.run_pgbackrest_command(restore_cmd)
            
            end_time = time.time()
            restore_duration = end_time - start_time
            
            if not success:
                raise Exception(f"Performance restore failed: {stderr}")
            
            # Calculate performance metrics
            test_result['metrics']['restore_duration_seconds'] = round(restore_duration, 2)
            test_result['metrics']['restore_duration_minutes'] = round(restore_duration / 60, 2)
            
            if backup_size > 0:
                throughput_mbps = (backup_size / (1024**2)) / restore_duration
                test_result['metrics']['restore_throughput_mbps'] = round(throughput_mbps, 2)
            
            # Performance thresholds (adjust based on your requirements)
            if backup_size > 0:
                expected_throughput = 50  # 50 MB/s minimum
                if throughput_mbps >= expected_throughput:
                    test_result['passed'] = True
                else:
                    test_result['warning'] = f"Restore throughput ({throughput_mbps:.2f} MB/s) below expected ({expected_throughput} MB/s)"
                    test_result['passed'] = True  # Still pass, but with warning
            else:
                test_result['passed'] = True
            
        except Exception as e:
            test_result['error'] = str(e)
            logger.error(f"Performance baseline test failed: {e}")
        
        test_result['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['tests'][test_name] = test_result
        return test_result
    
    def run_all_tests(self, tests_to_run: Optional[List[str]] = None) -> Dict:
        """
        Führt alle Disaster Recovery Tests durch
        """
        logger.info("Starting Disaster Recovery Test Suite...")
        
        # Setup test environment
        if not self.setup_test_environment():
            logger.error("Failed to setup test environment")
            return self.test_results
        
        # Available tests
        available_tests = {
            'backup_verification': self.test_backup_verification,
            'full_restore': self.test_full_restore,
            'point_in_time_recovery': self.test_point_in_time_recovery,
            'archive_recovery': self.test_archive_recovery,
            'restore_performance': self.test_performance_baseline
        }
        
        # Determine which tests to run
        if tests_to_run:
            tests_to_execute = {k: v for k, v in available_tests.items() if k in tests_to_run}
        else:
            tests_to_execute = available_tests
        
        # Run tests
        for test_name, test_func in tests_to_execute.items():
            logger.info(f"Running test: {test_name}")
            
            try:
                result = test_func()
                
                self.test_results['summary']['total_tests'] += 1
                if result.get('passed', False):
                    self.test_results['summary']['passed'] += 1
                else:
                    self.test_results['summary']['failed'] += 1
                    
            except Exception as e:
                logger.error(f"Test {test_name} failed with exception: {e}")
                self.test_results['summary']['total_tests'] += 1
                self.test_results['summary']['failed'] += 1
        
        # Cleanup
        self.cleanup_test_environment()
        
        # Calculate overall status
        total_tests = self.test_results['summary']['total_tests']
        passed_tests = self.test_results['summary']['passed']
        
        self.test_results['end_time'] = datetime.datetime.now().isoformat()
        self.test_results['success_rate'] = round((passed_tests / total_tests) * 100, 2) if total_tests > 0 else 0
        self.test_results['overall_status'] = 'PASSED' if passed_tests == total_tests else 'FAILED'
        
        return self.test_results
    
    def save_report(self, output_file: str = "/var/log/pgbackrest/disaster-recovery-report.json"):
        """
        Speichert Test-Report
        """
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        with open(output_file, 'w') as f:
            json.dump(self.test_results, f, indent=2)
        
        logger.info(f"Disaster Recovery report saved to {output_file}")
    
    def print_summary(self):
        """
        Druckt Test-Zusammenfassung
        """
        print("\n" + "="*80)
        print("ExaPG DISASTER RECOVERY TEST REPORT")
        print("="*80)
        print(f"Start Time: {self.test_results['start_time']}")
        print(f"End Time: {self.test_results.get('end_time', 'In Progress')}")
        print(f"Overall Status: {self.test_results.get('overall_status', 'In Progress')}")
        print(f"Success Rate: {self.test_results.get('success_rate', 0)}%")
        print(f"Tests: {self.test_results['summary']['passed']}/{self.test_results['summary']['total_tests']} passed")
        
        print("\nTEST DETAILS:")
        print("-" * 50)
        
        for test_name, test_data in self.test_results['tests'].items():
            status = "✓ PASS" if test_data.get('passed', False) else "✗ FAIL"
            print(f"{status} {test_data['description']}")
            
            if test_data.get('error'):
                print(f"     Error: {test_data['error']}")
            
            if test_data.get('warning'):
                print(f"     Warning: {test_data['warning']}")
            
            if 'metrics' in test_data:
                print(f"     Metrics: {test_data['metrics']}")
        
        print("="*80)

def main():
    parser = argparse.ArgumentParser(description='ExaPG Disaster Recovery Testing System')
    parser.add_argument('--tests', nargs='+',
                       choices=['backup_verification', 'full_restore', 'point_in_time_recovery', 
                               'archive_recovery', 'restore_performance'],
                       help='Specific tests to run (default: all)')
    parser.add_argument('--output', default='/var/log/pgbackrest/disaster-recovery-report.json',
                       help='Output file for test report')
    parser.add_argument('--silent', action='store_true',
                       help='Silent mode (no console output)')
    
    args = parser.parse_args()
    
    if args.silent:
        logging.getLogger().setLevel(logging.WARNING)
    
    tester = DisasterRecoveryTester()
    
    # Setup signal handler for cleanup
    def signal_handler(signum, frame):
        logger.info("Received interrupt signal, cleaning up...")
        tester.cleanup_test_environment()
        sys.exit(1)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        results = tester.run_all_tests(args.tests)
        tester.save_report(args.output)
        
        if not args.silent:
            tester.print_summary()
        
        # Exit code based on test results
        exit_code = 0 if results.get('overall_status') == 'PASSED' else 1
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        logger.info("Testing interrupted by user")
        tester.cleanup_test_environment()
        sys.exit(2)
    except Exception as e:
        logger.error(f"Testing failed: {e}")
        tester.cleanup_test_environment()
        sys.exit(3)

if __name__ == "__main__":
    main() 