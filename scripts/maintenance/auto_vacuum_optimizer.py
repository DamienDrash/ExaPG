#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ExaPG Automatische Vacuum- und Maintenance-Optimierung
-----------------------------------------------------

Dieses Skript überwacht und optimiert die Vacuum- und Maintenance-Prozesse 
in einer ExaPG-PostgreSQL-Datenbank. Es identifiziert Tabellen, die eine Wartung 
benötigen, passt Vacuum-Parameter dynamisch an und plant Wartungsarbeiten 
außerhalb der Hauptbetriebszeiten.

Funktionen:
- Überwachung von Tabellen mit hohem Bloat und toten Tupeln
- Automatische Anpassung von Vacuum-Parametern basierend auf Tabellencharakteristiken
- Priorisierung von Vacuum-Operationen für kritische Tabellen
- Planung von Maintenance-Arbeiten in Zeiten niedriger Datenbankauslastung
- Erstellung von optimierten VACUUM- und ANALYZE-Zeitplänen
"""

import argparse
import os
import sys
import time
import logging
import psycopg2
from psycopg2.extras import DictCursor
import json
import datetime
from tabulate import tabulate
import random

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('auto_vacuum_optimizer')

class VacuumOptimizer:
    def __init__(self, conn_params, threshold_dead_tuples=10000, threshold_bloat_percent=20,
                 maintenance_window=None, dry_run=False, parallel_jobs=2):
        """
        Initialisiert den VacuumOptimizer.
        
        Args:
            conn_params: Verbindungsparameter für PostgreSQL
            threshold_dead_tuples: Schwellenwert für tote Tupel
            threshold_bloat_percent: Schwellenwert für Bloat in Prozent
            maintenance_window: Zeitfenster für Wartung (z.B. "22:00-06:00")
            dry_run: Wenn True, werden Befehle nur angezeigt aber nicht ausgeführt
            parallel_jobs: Anzahl der Vacuum-Jobs, die parallel laufen können
        """
        self.conn_params = conn_params
        self.threshold_dead_tuples = threshold_dead_tuples
        self.threshold_bloat_percent = threshold_bloat_percent
        self.maintenance_window = self.parse_maintenance_window(maintenance_window)
        self.dry_run = dry_run
        self.parallel_jobs = parallel_jobs
        self.conn = None
        self.cursor = None
        self.connect()
        
    def parse_maintenance_window(self, window_str):
        """Parst das Wartungsfenster aus dem String-Format."""
        if not window_str:
            return None
            
        try:
            start_time, end_time = window_str.split('-')
            start_hour, start_minute = map(int, start_time.split(':'))
            end_hour, end_minute = map(int, end_time.split(':'))
            
            return {
                'start': {'hour': start_hour, 'minute': start_minute},
                'end': {'hour': end_hour, 'minute': end_minute}
            }
        except Exception as e:
            logger.error(f"Fehler beim Parsen des Wartungsfensters '{window_str}': {e}")
            logger.error("Format sollte 'HH:MM-HH:MM' sein, z.B. '22:00-06:00'")
            return None
            
    def is_in_maintenance_window(self):
        """Überprüft, ob die aktuelle Zeit im Wartungsfenster liegt."""
        if not self.maintenance_window:
            return True  # Wenn kein Fenster definiert ist, immer True
            
        now = datetime.datetime.now()
        current_hour, current_minute = now.hour, now.minute
        
        start = self.maintenance_window['start']
        end = self.maintenance_window['end']
        
        # Wenn Startzeit > Endzeit, handelt es sich um ein Fenster über Mitternacht
        if start['hour'] > end['hour'] or (start['hour'] == end['hour'] and start['minute'] > end['minute']):
            return (current_hour > start['hour'] or (current_hour == start['hour'] and current_minute >= start['minute']) or
                    current_hour < end['hour'] or (current_hour == end['hour'] and current_minute < end['minute']))
        else:
            return ((current_hour > start['hour'] or (current_hour == start['hour'] and current_minute >= start['minute'])) and
                    (current_hour < end['hour'] or (current_hour == end['hour'] and current_minute < end['minute'])))
        
    def connect(self):
        """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=DictCursor)
            logger.info("Verbindung zur Datenbank hergestellt")
        except Exception as e:
            logger.error(f"Verbindungsfehler: {e}")
            sys.exit(1)
            
    def get_database_activity(self):
        """Ermittelt die aktuelle Datenbankauslastung."""
        query = """
        SELECT
            count(*) as active_connections
        FROM
            pg_stat_activity
        WHERE
            state = 'active'
            AND pid <> pg_backend_pid()
            AND query NOT LIKE '%pg_stat_activity%';
        """
        try:
            self.cursor.execute(query)
            result = self.cursor.fetchone()
            return result['active_connections'] if result else 0
        except Exception as e:
            logger.error(f"Fehler beim Ermitteln der Datenbankauslastung: {e}")
            return 0
            
    def get_tables_needing_vacuum(self):
        """Identifiziert Tabellen, die einen VACUUM benötigen."""
        query = """
        SELECT
            schemaname, 
            relname as tablename,
            n_dead_tup as dead_tuples,
            n_live_tup as live_tuples,
            CASE WHEN n_live_tup > 0 
                THEN round(100.0 * n_dead_tup / (n_dead_tup + n_live_tup), 2)
                ELSE 0 
            END as dead_tuples_percent,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
        FROM
            pg_stat_user_tables
        WHERE
            n_dead_tup > %s
            OR (n_live_tup > 0 AND n_dead_tup > n_live_tup * %s / 100.0)
        ORDER BY
            n_dead_tup DESC;
        """
        try:
            self.cursor.execute(query, (self.threshold_dead_tuples, self.threshold_bloat_percent))
            return self.cursor.fetchall()
        except Exception as e:
            logger.error(f"Fehler beim Identifizieren von Tabellen für VACUUM: {e}")
            return []
            
    def get_table_bloat(self, schema, table):
        """Ermittelt den Bloat für eine bestimmte Tabelle."""
        query = """
        SELECT
            current_database() AS db, schemaname, tblname, bs*tblpages AS size,
            CASE WHEN tblpages - est_tblpages > 0 THEN 100 * (tblpages - est_tblpages) / tblpages::float ELSE 0 END AS bloat_percent,
            CASE WHEN tblpages - est_tblpages > 0 THEN (tblpages - est_tblpages) * bs ELSE 0 END AS bloat_size
        FROM (
            SELECT
                schemaname, tblname, bs, tblpages, ceil( (tblpages * fillfactor) / 100 ) AS est_tblpages, fillfactor
            FROM (
                SELECT
                    current_database() AS db, schemaname, tblname, bs,
                    CASE WHEN tblpages > 0 THEN tblpages ELSE NULL END AS tblpages,
                    CASE WHEN fillfactor > 0 THEN fillfactor ELSE 100 END AS fillfactor
                FROM (
                    SELECT
                        ns.nspname AS schemaname,
                        ct.relname AS tblname,
                        current_setting('block_size')::numeric AS bs,
                        CASE WHEN cl.relpages > 0 THEN cl.relpages ELSE pg_relation_size(cl.oid) / ((current_setting('block_size')::numeric)) END AS tblpages,
                        CASE WHEN cl.reloptions IS NULL THEN 100 ELSE (regexp_split_to_array(array_to_string(cl.reloptions, ' '), '='))[2]::integer END AS fillfactor
                    FROM
                        pg_catalog.pg_class cl
                        JOIN pg_catalog.pg_namespace ns ON cl.relnamespace = ns.oid
                        JOIN pg_catalog.pg_class ct ON cl.reltoastrelid = ct.oid
                    WHERE
                        cl.relkind = 'r'
                ) AS foo
            ) AS foo2
        ) AS foo3
        WHERE schemaname = %s AND tblname = %s;
        """
        try:
            self.cursor.execute(query, (schema, table))
            result = self.cursor.fetchone()
            return result['bloat_percent'] if result else 0
        except Exception as e:
            logger.error(f"Fehler beim Ermitteln des Bloats für {schema}.{table}: {e}")
            return 0
            
    def get_table_size(self, schema, table):
        """Ermittelt die Größe einer Tabelle in MB."""
        query = """
        SELECT pg_size_pretty(pg_total_relation_size(%s)) as size,
               pg_total_relation_size(%s) as size_bytes;
        """
        try:
            self.cursor.execute(query, (f"{schema}.{table}", f"{schema}.{table}"))
            result = self.cursor.fetchone()
            return {
                'pretty': result['size'],
                'bytes': result['size_bytes']
            }
        except Exception as e:
            logger.error(f"Fehler beim Ermitteln der Größe für {schema}.{table}: {e}")
            return {'pretty': 'unbekannt', 'bytes': 0}
            
    def calculate_table_statistics(self, tables_needing_vacuum):
        """Berechnet zusätzliche Statistiken für Tabellen, die einen VACUUM benötigen."""
        enriched_tables = []
        
        for table in tables_needing_vacuum:
            schema = table['schemaname']
            tablename = table['tablename']
            
            # Bloat-Prozentsatz ermitteln
            bloat_percent = self.get_table_bloat(schema, tablename)
            
            # Tabellengröße ermitteln
            size = self.get_table_size(schema, tablename)
            
            # Zeit seit dem letzten Vacuum berechnen
            last_vacuum = table['last_vacuum'] or table['last_autovacuum']
            days_since_vacuum = None
            if last_vacuum:
                days_since_vacuum = (datetime.datetime.now() - last_vacuum).days
            
            # Priorität berechnen (basierend auf Bloat, toten Tupeln und Zeit seit dem letzten Vacuum)
            priority = 0
            if bloat_percent > 0:
                priority += bloat_percent * 0.5  # Bloat-Faktor
            priority += min(table['dead_tuples_percent'], 50) * 0.3  # Tote Tupel Faktor (max 50%)
            if days_since_vacuum is not None:
                priority += min(days_since_vacuum, 30) * 0.2  # Zeit-Faktor (max 30 Tage)
            
            enriched_tables.append({
                **table,
                'bloat_percent': bloat_percent,
                'size': size['pretty'],
                'size_bytes': size['bytes'],
                'days_since_vacuum': days_since_vacuum,
                'priority': priority
            })
        
        # Nach Priorität sortieren
        return sorted(enriched_tables, key=lambda x: x['priority'], reverse=True)
        
    def generate_vacuum_parameters(self, table_stats):
        """
        Generiert optimale Vacuum-Parameter basierend auf Tabellenstatistiken.
        
        Dies ist eine einfache Heuristik, die für verschiedene Tabellengrößen und Bloat-Werte
        angepasste Parameter zurückgibt.
        """
        size_bytes = table_stats['size_bytes']
        bloat_percent = table_stats['bloat_percent']
        dead_tuples_percent = table_stats['dead_tuples_percent']
        
        params = []
        
        # Basisparameter
        if size_bytes > 10 * 1024 * 1024 * 1024:  # > 10 GB
            params.append("PARALLEL 4")  # Hohe Parallelität für große Tabellen
        elif size_bytes > 1 * 1024 * 1024 * 1024:  # > 1 GB
            params.append("PARALLEL 2")  # Mittlere Parallelität für mittelgroße Tabellen
        
        # Bei hohem Bloat oder vielen toten Tupeln FULL verwenden
        if bloat_percent > 30 or dead_tuples_percent > 40:
            params.append("FULL")
        
        # Bei sehr großen Tabellen Index-Only-Vacuum vermeiden, um Blockierung zu reduzieren
        if size_bytes > 50 * 1024 * 1024 * 1024:  # > 50 GB
            params.append("INDEX_CLEANUP TRUE")
        
        # Aggressive Parameter für kritische Tabellen
        if bloat_percent > 50 or dead_tuples_percent > 60:
            params.append("DISABLE_PAGE_SKIPPING")
        
        return params
        
    def execute_vacuum(self, schema, table, params=None):
        """Führt einen VACUUM für die angegebene Tabelle aus."""
        vacuum_command = f"VACUUM"
        if params and len(params) > 0:
            vacuum_command += f" ({', '.join(params)})"
        vacuum_command += f" {schema}.{table};"
        
        try:
            logger.info(f"Führe aus: {vacuum_command}")
            if not self.dry_run:
                start_time = time.time()
                self.cursor.execute(vacuum_command)
                duration = time.time() - start_time
                logger.info(f"VACUUM für {schema}.{table} abgeschlossen (Dauer: {duration:.2f} Sekunden)")
                return True
            else:
                logger.info(f"[Testmodus] Würde ausführen: {vacuum_command}")
                return True
        except Exception as e:
            logger.error(f"Fehler beim Ausführen von VACUUM für {schema}.{table}: {e}")
            return False
            
    def execute_analyze(self, schema, table):
        """Führt einen ANALYZE für die angegebene Tabelle aus."""
        analyze_command = f"ANALYZE {schema}.{table};"
        
        try:
            logger.info(f"Führe aus: {analyze_command}")
            if not self.dry_run:
                start_time = time.time()
                self.cursor.execute(analyze_command)
                duration = time.time() - start_time
                logger.info(f"ANALYZE für {schema}.{table} abgeschlossen (Dauer: {duration:.2f} Sekunden)")
                return True
            else:
                logger.info(f"[Testmodus] Würde ausführen: {analyze_command}")
                return True
        except Exception as e:
            logger.error(f"Fehler beim Ausführen von ANALYZE für {schema}.{table}: {e}")
            return False
    
    def get_current_vacuum_processes(self):
        """Ermittelt die Anzahl der aktuell laufenden VACUUM-Prozesse."""
        query = """
        SELECT count(*) as count
        FROM pg_stat_activity
        WHERE query LIKE 'VACUUM%'
          AND pid <> pg_backend_pid();
        """
        try:
            self.cursor.execute(query)
            result = self.cursor.fetchone()
            return result['count'] if result else 0
        except Exception as e:
            logger.error(f"Fehler beim Ermitteln laufender VACUUM-Prozesse: {e}")
            return 0
    
    def run_maintenance(self):
        """Führt die Wartungsarbeiten aus."""
        logger.info("Starte Vacuum-Optimizer")
        
        # Überprüfen, ob wir im Wartungsfenster sind
        if self.maintenance_window and not self.is_in_maintenance_window():
            logger.info(f"Aktuell außerhalb des Wartungsfensters. Keine Aktionen werden ausgeführt.")
            return
            
        # Datenbankauslastung überprüfen
        activity = self.get_database_activity()
        logger.info(f"Aktuelle Datenbankauslastung: {activity} aktive Verbindungen")
        
        # Wenn zu viel los ist, verzögern (außer im Wartungsfenster)
        if activity > 20 and not (self.maintenance_window and self.is_in_maintenance_window()):
            logger.info(f"Hohe Datenbankauslastung. Wartung wird aufgeschoben.")
            return
            
        # Tabellen identifizieren, die einen VACUUM benötigen
        tables_needing_vacuum = self.get_tables_needing_vacuum()
        if not tables_needing_vacuum:
            logger.info("Keine Tabellen benötigen einen VACUUM.")
            return
            
        logger.info(f"{len(tables_needing_vacuum)} Tabellen benötigen einen VACUUM")
        
        # Zusätzliche Statistiken berechnen und Prioritäten setzen
        enriched_tables = self.calculate_table_statistics(tables_needing_vacuum)
        
        # Ausgabe der Tabellen mit Statistiken
        self.print_table_statistics(enriched_tables)
        
        # VACUUM für jede Tabelle ausführen (nach Priorität)
        for table in enriched_tables:
            schema = table['schemaname']
            tablename = table['tablename']
            
            # Aktuelle VACUUM-Prozesse überprüfen und ggf. warten
            current_vacuums = self.get_current_vacuum_processes()
            while current_vacuums >= self.parallel_jobs and not self.dry_run:
                logger.info(f"Bereits {current_vacuums} VACUUM-Prozesse aktiv. Warte...")
                time.sleep(30)  # 30 Sekunden warten und erneut prüfen
                current_vacuums = self.get_current_vacuum_processes()
            
            # Optimale Vacuum-Parameter generieren
            params = self.generate_vacuum_parameters(table)
            logger.info(f"Für {schema}.{tablename} (Priorität: {table['priority']:.2f}): VACUUM {', '.join(params) if params else ''}")
            
            # VACUUM ausführen
            success = self.execute_vacuum(schema, tablename, params)
            
            # Bei Erfolg auch ANALYZE ausführen, falls länger her
            if success:
                last_analyze = table['last_analyze'] or table['last_autoanalyze']
                days_since_analyze = None
                if last_analyze:
                    days_since_analyze = (datetime.datetime.now() - last_analyze).days
                
                if days_since_analyze is None or days_since_analyze > 7:
                    self.execute_analyze(schema, tablename)
            
            # Kurze Pause zwischen den Tabellen, um der Datenbank zu erlauben, sich zu erholen
            if not self.dry_run:
                time.sleep(2)  # 2 Sekunden Pause
                
        logger.info("Wartungsarbeiten abgeschlossen")
                
    def print_table_statistics(self, tables):
        """Gibt Tabellenstatistiken in tabellarischer Form aus."""
        headers = ["Schema", "Tabelle", "Größe", "Tote Tupel %", "Bloat %", "Tage seit Vacuum", "Priorität"]
        table_data = []
        
        for table in tables:
            table_data.append([
                table['schemaname'],
                table['tablename'],
                table['size'],
                f"{table['dead_tuples_percent']:.2f}%",
                f"{table['bloat_percent']:.2f}%",
                str(table['days_since_vacuum']) if table['days_since_vacuum'] is not None else "Nie",
                f"{table['priority']:.2f}"
            ])
        
        print("\nTabellen, die einen VACUUM benötigen:")
        print(tabulate(table_data, headers=headers, tablefmt="grid"))
    
    def close(self):
        """Schließt die Datenbankverbindung."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            logger.debug("Datenbankverbindung geschlossen")

def parse_args():
    """Verarbeitet Kommandozeilenargumente."""
    parser = argparse.ArgumentParser(description='ExaPG Automatische Vacuum-Optimierung')
    
    parser.add_argument('-H', '--host', default='localhost',
                        help='PostgreSQL-Host (Standard: localhost)')
    parser.add_argument('-p', '--port', type=int, default=5432,
                        help='PostgreSQL-Port (Standard: 5432)')
    parser.add_argument('-d', '--dbname', required=True,
                        help='PostgreSQL-Datenbankname')
    parser.add_argument('-U', '--user', required=True,
                        help='PostgreSQL-Benutzername')
    parser.add_argument('-P', '--password',
                        help='PostgreSQL-Passwort (alternativ kann PGPASSWORD Umgebungsvariable verwendet werden)')
    parser.add_argument('-t', '--threshold-dead-tuples', type=int, default=10000,
                        help='Schwellenwert für tote Tupel (Standard: 10000)')
    parser.add_argument('-b', '--threshold-bloat-percent', type=float, default=20.0,
                        help='Schwellenwert für Bloat in Prozent (Standard: 20.0)')
    parser.add_argument('-w', '--maintenance-window',
                        help='Wartungsfenster im Format "HH:MM-HH:MM", z.B. "22:00-06:00"')
    parser.add_argument('-j', '--parallel-jobs', type=int, default=2,
                        help='Anzahl paralleler Vacuum-Jobs (Standard: 2)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Testmodus: Befehle nur anzeigen, nicht ausführen')
    
    return parser.parse_args()

def main():
    """Hauptfunktion."""
    args = parse_args()
    
    # Verbindungsparameter
    conn_params = {
        'host': args.host,
        'port': args.port,
        'dbname': args.dbname,
        'user': args.user,
    }
    
    # Passwort aus Argument oder Umgebungsvariable
    if args.password:
        conn_params['password'] = args.password
    elif 'PGPASSWORD' in os.environ:
        conn_params['password'] = os.environ['PGPASSWORD']
    
    # Vacuum-Optimizer ausführen
    optimizer = VacuumOptimizer(
        conn_params=conn_params,
        threshold_dead_tuples=args.threshold_dead_tuples,
        threshold_bloat_percent=args.threshold_bloat_percent,
        maintenance_window=args.maintenance_window,
        dry_run=args.dry_run,
        parallel_jobs=args.parallel_jobs
    )
    
    try:
        optimizer.run_maintenance()
    finally:
        optimizer.close()

if __name__ == '__main__':
    main() 