#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Paralleler Datenmigrator für Exasol zu ExaPG

Dieses Skript führt eine parallele Datenmigration von Exasol zu ExaPG durch.
Es verwendet mehrere Arbeiter (Workers), um die Migration zu beschleunigen.

Beispielverwendung:
    python3 parallel_migrator.py --source "exa:user/password@host:port" \
      --target "postgresql://postgres:postgres@localhost:5432/exapg" \
      --tables customer,orders,sales \
      --workers 8
"""

import os
import sys
import argparse
import logging
import subprocess
import tempfile
import re
import time
import threading
import queue
import psycopg2
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

# Logging-Konfiguration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('parallel_migration.log')
    ]
)
logger = logging.getLogger('parallel_migrator')

class ExasolExtractor:
    """Klasse zum Extrahieren von Daten aus Exasol."""
    
    def __init__(self, dsn):
        """Initialisiert den Extraktor mit der DSN."""
        self.dsn = dsn
    
    def get_table_list(self, schema=None, include_tables=None, exclude_tables=None):
        """Gibt eine Liste der Tabellen zurück."""
        where_clauses = ["table_schema NOT IN ('SYS', 'EXA_STATISTICS', 'EXA_LOGS')"]
        
        if schema:
            where_clauses.append(f"table_schema = '{schema}'")
        
        if include_tables:
            include_list = "', '".join(include_tables.split(','))
            where_clauses.append(f"table_name IN ('{include_list}')")
        
        if exclude_tables:
            exclude_list = "', '".join(exclude_tables.split(','))
            where_clauses.append(f"table_name NOT IN ('{exclude_list}')")
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
        SELECT table_schema, table_name 
        FROM EXA_ALL_TABLES 
        WHERE {where_clause}
        ORDER BY table_schema, table_name
        """
        
        return self.run_query(sql)
    
    def get_table_schema(self, schema, table):
        """Gibt das Schema einer Tabelle zurück."""
        sql = f"""
        SELECT 
            column_name, 
            data_type || 
                CASE 
                    WHEN data_type IN ('DECIMAL') THEN '(' || numeric_precision || ',' || numeric_scale || ')'
                    WHEN data_type IN ('VARCHAR', 'CHAR') THEN '(' || character_maximum_length || ')'
                    ELSE ''
                END as column_type,
            ordinal_position
        FROM 
            EXA_ALL_COLUMNS 
        WHERE 
            table_schema = '{schema}'
            AND table_name = '{table}'
        ORDER BY 
            ordinal_position
        """
        
        return self.run_query(sql)
    
    def get_table_row_count(self, schema, table):
        """Gibt die Anzahl der Zeilen in einer Tabelle zurück."""
        sql = f"SELECT COUNT(*) as row_count FROM {schema}.{table}"
        result = self.run_query(sql)
        return int(result[0]['ROW_COUNT']) if result else 0
    
    def export_table_data(self, schema, table, output_file, batch_size=100000, offset=0, limit=None):
        """Exportiert Daten aus einer Tabelle in eine CSV-Datei."""
        # Spaltenliste erstellen
        columns = self.get_table_schema(schema, table)
        column_list = ", ".join([col['COLUMN_NAME'] for col in columns])
        
        # SQL für den Export erstellen
        sql = f"SELECT {column_list} FROM {schema}.{table}"
        
        # Limit und Offset hinzufügen, wenn angegeben
        if limit is not None:
            sql += f" LIMIT {limit}"
        if offset > 0:
            sql += f" OFFSET {offset}"
        
        # Temporäre SQL-Datei erstellen
        with tempfile.NamedTemporaryFile(mode='w+', suffix='.sql', delete=False) as query_file:
            query_file.write(sql)
            query_file_path = query_file.name
        
        try:
            # Exasol-Befehl zum Exportieren der Daten
            cmd = [
                'exaplus', '-c', self.dsn, 
                '-q', query_file_path, 
                '-o', output_file,
                '-L', '-x', '-s', ',', 
                '--null', ''  # NULL-Werte als leere Strings darstellen
            ]
            
            subprocess.check_call(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Erste Zeile (Header) entfernen, da wir keinen Header für COPY benötigen
            with open(output_file, 'r') as f:
                lines = f.readlines()
            
            with open(output_file, 'w') as f:
                f.writelines(lines[1:])
            
            return True
        except Exception as e:
            logger.error(f"Fehler beim Exportieren von {schema}.{table}: {str(e)}")
            return False
        finally:
            # Temporäre SQL-Datei löschen
            os.unlink(query_file_path)
    
    def run_query(self, query):
        """Führt eine SQL-Abfrage gegen Exasol aus und gibt das Ergebnis zurück."""
        try:
            # Temporäre Datei für die Abfrage erstellen
            with tempfile.NamedTemporaryFile(mode='w+', suffix='.sql', delete=False) as query_file:
                query_file.write(query)
                query_file_path = query_file.name
            
            # Temporäre Datei für das Ergebnis erstellen
            result_file_path = tempfile.mktemp(suffix='.csv')
            
            # Befehl zum Ausführen der Abfrage mit exaplus
            cmd = [
                'exaplus', '-c', self.dsn, 
                '-q', query_file_path, 
                '-o', result_file_path,
                '-L', '-x', '-s', ','
            ]
            
            # Abfrage ausführen
            subprocess.check_call(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Ergebnis einlesen
            with open(result_file_path, 'r') as f:
                result = f.read().strip()
            
            # Temporäre Dateien löschen
            os.unlink(query_file_path)
            os.unlink(result_file_path)
            
            # CSV in Liste von Wörterbüchern konvertieren
            lines = result.strip().split('\n')
            if not lines or len(lines) <= 1:
                return []
                
            headers = lines[0].split(',')
            data = []
            
            for line in lines[1:]:
                values = line.split(',')
                row = {}
                for i, header in enumerate(headers):
                    row[header.strip()] = values[i] if i < len(values) else None
                data.append(row)
            
            return data
        
        except Exception as e:
            logger.error(f"Fehler bei der Ausführung der Exasol-Abfrage: {str(e)}")
            raise

class PostgresLoader:
    """Klasse zum Laden von Daten in PostgreSQL."""
    
    def __init__(self, dsn):
        """Initialisiert den Loader mit der DSN."""
        self.dsn = dsn
        self.conn = None
    
    def connect(self):
        """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
        try:
            self.conn = psycopg2.connect(self.dsn)
            self.conn.autocommit = False
            return True
        except Exception as e:
            logger.error(f"Fehler bei der Verbindung zu PostgreSQL: {str(e)}")
            return False
    
    def disconnect(self):
        """Trennt die Verbindung zur Datenbank."""
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def table_exists(self, schema, table):
        """Prüft, ob eine Tabelle existiert."""
        try:
            with self.conn.cursor() as cursor:
                cursor.execute(
                    "SELECT EXISTS(SELECT 1 FROM information_schema.tables "
                    "WHERE table_schema = %s AND table_name = %s)",
                    (schema, table)
                )
                return cursor.fetchone()[0]
        except Exception as e:
            logger.error(f"Fehler beim Prüfen der Tabelle {schema}.{table}: {str(e)}")
            return False
    
    def create_schema(self, schema):
        """Erstellt ein Schema, falls es nicht existiert."""
        try:
            with self.conn.cursor() as cursor:
                cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
                self.conn.commit()
                return True
        except Exception as e:
            logger.error(f"Fehler beim Erstellen des Schemas {schema}: {str(e)}")
            self.conn.rollback()
            return False
    
    def truncate_table(self, schema, table):
        """Leert eine Tabelle."""
        try:
            with self.conn.cursor() as cursor:
                cursor.execute(f"TRUNCATE TABLE {schema}.{table}")
                self.conn.commit()
                return True
        except Exception as e:
            logger.error(f"Fehler beim Leeren der Tabelle {schema}.{table}: {str(e)}")
            self.conn.rollback()
            return False
    
    def import_data(self, schema, table, input_file, truncate=False):
        """Importiert Daten aus einer CSV-Datei in eine Tabelle."""
        try:
            # Sicherstellen, dass das Schema existiert
            self.create_schema(schema)
            
            # Tabelle leeren, falls gewünscht
            if truncate and self.table_exists(schema, table):
                self.truncate_table(schema, table)
            
            # Daten importieren
            with self.conn.cursor() as cursor:
                with open(input_file, 'r') as f:
                    cursor.copy_expert(
                        f"COPY {schema}.{table} FROM STDIN WITH CSV DELIMITER ',' NULL ''",
                        f
                    )
                self.conn.commit()
                
                # Zeilen zählen
                cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
                row_count = cursor.fetchone()[0]
                
                return row_count
        except Exception as e:
            logger.error(f"Fehler beim Importieren in {schema}.{table}: {str(e)}")
            self.conn.rollback()
            return 0

class MigrationWorker:
    """Worker für die parallele Migration."""
    
    def __init__(self, worker_id, exasol_dsn, postgres_dsn, task_queue, result_queue, batch_size=100000):
        """Initialisiert den Worker."""
        self.worker_id = worker_id
        self.exasol_dsn = exasol_dsn
        self.postgres_dsn = postgres_dsn
        self.task_queue = task_queue
        self.result_queue = result_queue
        self.batch_size = batch_size
        self.exasol = ExasolExtractor(exasol_dsn)
        self.postgres = PostgresLoader(postgres_dsn)
        self.tmp_dir = tempfile.mkdtemp(prefix=f"migration_worker_{worker_id}_")
        self.active = True
    
    def run(self):
        """Führt die Worker-Schleife aus."""
        logger.info(f"Worker {self.worker_id} gestartet")
        
        # PostgreSQL-Verbindung herstellen
        if not self.postgres.connect():
            logger.error(f"Worker {self.worker_id} konnte keine Verbindung zu PostgreSQL herstellen")
            self.result_queue.put({
                'worker_id': self.worker_id,
                'status': 'error',
                'message': 'Verbindungsfehler zu PostgreSQL'
            })
            return
        
        try:
            while self.active:
                try:
                    # Aufgabe aus der Warteschlange holen
                    task = self.task_queue.get(timeout=1)
                    
                    # Prüfen, ob es sich um ein Stop-Signal handelt
                    if task is None:
                        logger.info(f"Worker {self.worker_id} erhielt Stop-Signal")
                        break
                    
                    # Aufgabe verarbeiten
                    schema = task['schema']
                    table = task['table']
                    offset = task.get('offset', 0)
                    limit = task.get('limit')
                    truncate = task.get('truncate', False)
                    
                    logger.info(f"Worker {self.worker_id} verarbeitet {schema}.{table} (Offset: {offset}, Limit: {limit})")
                    
                    # Temporäre CSV-Datei erstellen
                    csv_file = os.path.join(self.tmp_dir, f"{schema}_{table}_{offset}_{limit}.csv")
                    
                    # Daten exportieren
                    start_time = time.time()
                    export_success = self.exasol.export_table_data(
                        schema, table, csv_file, self.batch_size, offset, limit
                    )
                    export_duration = time.time() - start_time
                    
                    if not export_success:
                        self.result_queue.put({
                            'worker_id': self.worker_id,
                            'schema': schema,
                            'table': table,
                            'status': 'error',
                            'message': f"Fehler beim Exportieren von {schema}.{table}"
                        })
                        self.task_queue.task_done()
                        continue
                    
                    # Daten importieren
                    start_time = time.time()
                    imported_rows = self.postgres.import_data(schema, table, csv_file, truncate)
                    import_duration = time.time() - start_time
                    
                    # Ergebnis melden
                    self.result_queue.put({
                        'worker_id': self.worker_id,
                        'schema': schema,
                        'table': table,
                        'offset': offset,
                        'limit': limit,
                        'exported_rows': 0,  # Würde Dateianalyse erfordern
                        'imported_rows': imported_rows,
                        'export_duration': export_duration,
                        'import_duration': import_duration,
                        'status': 'success' if imported_rows > 0 else 'warning'
                    })
                    
                    # Temporäre Datei löschen
                    if os.path.exists(csv_file):
                        os.unlink(csv_file)
                    
                    # Aufgabe als erledigt markieren
                    self.task_queue.task_done()
                
                except queue.Empty:
                    # Keine Aufgaben in der Warteschlange
                    time.sleep(0.1)
                
                except Exception as e:
                    logger.error(f"Worker {self.worker_id} Fehler: {str(e)}")
                    self.result_queue.put({
                        'worker_id': self.worker_id,
                        'status': 'error',
                        'message': str(e)
                    })
                    self.task_queue.task_done()
        
        finally:
            # Aufräumen
            self.postgres.disconnect()
            
            # Temporäres Verzeichnis löschen
            try:
                if os.path.exists(self.tmp_dir):
                    for f in os.listdir(self.tmp_dir):
                        os.unlink(os.path.join(self.tmp_dir, f))
                    os.rmdir(self.tmp_dir)
            except Exception as e:
                logger.warning(f"Worker {self.worker_id} konnte temporäres Verzeichnis nicht löschen: {str(e)}")
            
            logger.info(f"Worker {self.worker_id} beendet")
    
    def stop(self):
        """Stoppt den Worker."""
        self.active = False

class ParallelMigrator:
    """Hauptklasse für die parallele Migration."""
    
    def __init__(self, source_dsn, target_dsn, num_workers=4, batch_size=100000):
        """Initialisiert den Migrator."""
        self.source_dsn = source_dsn
        self.target_dsn = target_dsn
        self.num_workers = num_workers
        self.batch_size = batch_size
        self.exasol = ExasolExtractor(source_dsn)
        self.task_queue = queue.Queue()
        self.result_queue = queue.Queue()
        self.workers = []
        self.worker_threads = []
        self.results = []
        self.stats = {
            'total_tables': 0,
            'processed_tables': 0,
            'total_rows': 0,
            'exported_rows': 0,
            'imported_rows': 0,
            'success': 0,
            'warnings': 0,
            'errors': 0,
            'start_time': None,
            'end_time': None
        }
    
    def start_workers(self):
        """Startet die Worker-Threads."""
        for i in range(self.num_workers):
            worker = MigrationWorker(
                i, self.source_dsn, self.target_dsn,
                self.task_queue, self.result_queue, self.batch_size
            )
            self.workers.append(worker)
            
            thread = threading.Thread(target=worker.run)
            thread.daemon = True
            thread.start()
            self.worker_threads.append(thread)
    
    def stop_workers(self):
        """Stoppt alle Worker."""
        for _ in range(len(self.workers)):
            self.task_queue.put(None)
        
        for worker in self.workers:
            worker.stop()
        
        for thread in self.worker_threads:
            thread.join(timeout=5)
    
    def process_results(self):
        """Verarbeitet die Ergebnisse aus der Ergebniswarteschlange."""
        thread = threading.Thread(target=self._process_results_thread)
        thread.daemon = True
        thread.start()
        return thread
    
    def _process_results_thread(self):
        """Thread zum Verarbeiten der Ergebnisse."""
        while True:
            try:
                result = self.result_queue.get(timeout=1)
                
                if result['status'] == 'success':
                    self.stats['success'] += 1
                    self.stats['imported_rows'] += result['imported_rows']
                    logger.info(
                        f"Migration von {result['schema']}.{result['table']} erfolgreich: "
                        f"{result['imported_rows']} Zeilen importiert "
                        f"(Export: {result['export_duration']:.2f}s, Import: {result['import_duration']:.2f}s)"
                    )
                
                elif result['status'] == 'warning':
                    self.stats['warnings'] += 1
                    logger.warning(
                        f"Migration von {result['schema']}.{result['table']} mit Warnung: "
                        f"{result.get('message', 'Keine Zeilen importiert')}"
                    )
                
                elif result['status'] == 'error':
                    self.stats['errors'] += 1
                    logger.error(
                        f"Migration von {result.get('schema', '?')}.{result.get('table', '?')} "
                        f"fehlgeschlagen: {result.get('message', 'Unbekannter Fehler')}"
                    )
                
                self.results.append(result)
                self.result_queue.task_done()
                
                # Prüfen, ob alle Tabellen verarbeitet wurden
                if len(self.results) >= self.stats['total_tables']:
                    break
            
            except queue.Empty:
                # Keine Ergebnisse in der Warteschlange
                time.sleep(0.1)
            
            except Exception as e:
                logger.error(f"Fehler bei der Verarbeitung der Ergebnisse: {str(e)}")
    
    def migrate(self, schema=None, tables=None, exclude_tables=None, truncate=True):
        """Führt die Migration durch."""
        self.stats['start_time'] = datetime.now()
        
        # Worker starten
        self.start_workers()
        
        try:
            # Prozess zum Verarbeiten der Ergebnisse starten
            result_thread = self.process_results()
            
            # Tabellen auflisten
            table_list = self.exasol.get_table_list(schema, tables, exclude_tables)
            
            if not table_list:
                logger.warning("Keine Tabellen gefunden, die den Kriterien entsprechen.")
                return False
            
            self.stats['total_tables'] = len(table_list)
            logger.info(f"{self.stats['total_tables']} Tabellen zur Migration gefunden")
            
            # Aufgaben erstellen und in die Warteschlange einfügen
            for table_info in table_list:
                schema_name = table_info['TABLE_SCHEMA']
                table_name = table_info['TABLE_NAME']
                
                # Zeilenanzahl ermitteln
                row_count = self.exasol.get_table_row_count(schema_name, table_name)
                self.stats['total_rows'] += row_count
                
                logger.info(f"Tabelle {schema_name}.{table_name} hat {row_count} Zeilen")
                
                # Bei kleinen Tabellen oder wenn kein Batching gewünscht ist
                if row_count <= self.batch_size or self.batch_size <= 0:
                    self.task_queue.put({
                        'schema': schema_name,
                        'table': table_name,
                        'truncate': truncate
                    })
                    truncate = False  # Nur beim ersten Batch truncate
                else:
                    # Große Tabellen in Batches aufteilen
                    for offset in range(0, row_count, self.batch_size):
                        self.task_queue.put({
                            'schema': schema_name,
                            'table': table_name,
                            'offset': offset,
                            'limit': min(self.batch_size, row_count - offset),
                            'truncate': truncate and offset == 0
                        })
            
            # Auf Fertigstellung warten
            self.task_queue.join()
            result_thread.join(timeout=10)
            
            self.stats['end_time'] = datetime.now()
            duration = (self.stats['end_time'] - self.stats['start_time']).total_seconds()
            
            # Statistik ausgeben
            logger.info("\n" + "="*80)
            logger.info(f"Migration abgeschlossen in {duration:.2f} Sekunden")
            logger.info(f"Tabellen gesamt: {self.stats['total_tables']}")
            logger.info(f"Zeilen gesamt: {self.stats['total_rows']}")
            logger.info(f"Zeilen importiert: {self.stats['imported_rows']}")
            logger.info(f"Erfolgreiche Migrationen: {self.stats['success']}")
            logger.info(f"Migrationen mit Warnungen: {self.stats['warnings']}")
            logger.info(f"Fehlgeschlagene Migrationen: {self.stats['errors']}")
            logger.info("="*80)
            
            return self.stats['errors'] == 0
        
        finally:
            # Worker stoppen
            self.stop_workers()

def main():
    """Hauptfunktion."""
    parser = argparse.ArgumentParser(description='Parallele Datenmigration von Exasol zu ExaPG')
    
    parser.add_argument('--source', required=True, 
                        help='Exasol-DSN im Format "exa:user/password@host:port"')
    parser.add_argument('--target', required=True, 
                        help='PostgreSQL-DSN im Format "postgresql://user:password@host:port/dbname"')
    parser.add_argument('--schema', 
                        help='Zu migrierendes Schema (standardmäßig alle)')
    parser.add_argument('--tables', 
                        help='Kommagetrennte Liste der zu migrierenden Tabellen')
    parser.add_argument('--exclude-tables', 
                        help='Kommagetrennte Liste der zu ignorierenden Tabellen')
    parser.add_argument('--workers', type=int, default=4, 
                        help='Anzahl der parallelen Worker (Standard: 4)')
    parser.add_argument('--batch-size', type=int, default=100000, 
                        help='Batchgröße für große Tabellen (Standard: 100000, 0 für keine Batches)')
    parser.add_argument('--no-truncate', action='store_true', 
                        help='Tabellen vor dem Import nicht leeren')
    parser.add_argument('--verbose', action='store_true', 
                        help='Ausführliche Ausgabe')
    
    args = parser.parse_args()
    
    # Verbose-Modus
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # Migration durchführen
    migrator = ParallelMigrator(
        args.source, args.target, args.workers, args.batch_size
    )
    
    success = migrator.migrate(
        args.schema, args.tables, args.exclude_tables, not args.no_truncate
    )
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 