#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ExaPG Index-Empfehlungssystem
-----------------------------

Dieses Skript analysiert den aktuellen Workload einer PostgreSQL-Datenbank,
identifiziert potenziell nützliche Indizes und gibt Empfehlungen für neue
Indizes aus, die die Performance verbessern könnten.

Funktionen:
- Analyse der häufigsten und teuersten Abfragen aus pg_stat_statements
- Identifizierung von Tabellen und Spalten, die von Indexierung profitieren würden
- Bewertung der potenziellen Performance-Vorteile neuer Indizes
- Generierung von CREATE INDEX Anweisungen
- Berücksichtigung bestehender Indizes, um Duplikate zu vermeiden
- Unterstützung für hypoindexes zur Simulation von Indizes
"""

import argparse
import os
import sys
import logging
import psycopg2
from psycopg2.extras import DictCursor
import json
import re
from collections import defaultdict, Counter
from tabulate import tabulate

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('index_advisor')

class IndexAdvisor:
    def __init__(self, conn_params, min_calls=10, max_indexes=10, min_benefit_percent=10):
        """
        Initialisiert den IndexAdvisor.
        
        Args:
            conn_params: Verbindungsparameter für PostgreSQL
            min_calls: Mindestanzahl an Aufrufen, bevor eine Abfrage für die Indexierung betrachtet wird
            max_indexes: Maximale Anzahl an empfohlenen Indizes
            min_benefit_percent: Minimaler Prozentsatz an potenzieller Verbesserung
        """
        self.conn_params = conn_params
        self.min_calls = min_calls
        self.max_indexes = max_indexes
        self.min_benefit_percent = min_benefit_percent
        self.conn = None
        self.cursor = None
        self.connect()
        self.ensure_hypoindex_extension()
        
    def connect(self):
        """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=DictCursor)
            logger.info("Verbindung zur Datenbank hergestellt")
        except Exception as e:
            logger.error(f"Verbindungsfehler: {e}")
            sys.exit(1)
    
    def ensure_hypoindex_extension(self):
        """Stellt sicher, dass die HypoPG-Erweiterung verfügbar ist."""
        try:
            self.cursor.execute("SELECT 1 FROM pg_extension WHERE extname = 'hypopg';")
            if not self.cursor.fetchone():
                logger.warning("HypoPG-Erweiterung nicht installiert. Simulation von Indizes wird nicht verfügbar sein.")
        except Exception as e:
            logger.warning(f"Konnte HypoPG-Status nicht überprüfen: {e}")
    
    def get_existing_indexes(self):
        """Sammelt Informationen über bestehende Indizes."""
        query = """
        SELECT
            t.relname AS table_name,
            i.relname AS index_name,
            array_to_string(array_agg(a.attname ORDER BY k.i), ',') AS column_names,
            ix.indisunique AS is_unique,
            am.amname AS index_type
        FROM
            pg_class t
            JOIN pg_index ix ON t.oid = ix.indrelid
            JOIN pg_class i ON i.oid = ix.indexrelid
            JOIN pg_am am ON i.relam = am.oid
            JOIN pg_namespace n ON n.oid = t.relnamespace
            JOIN pg_attribute a ON a.attrelid = t.oid
            JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY AS k(attnum, i) ON a.attnum = k.attnum
        WHERE
            t.relkind = 'r'
            AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
            AND NOT ix.indisprimary
        GROUP BY
            t.relname, i.relname, ix.indisunique, am.amname
        ORDER BY
            t.relname, i.relname;
        """
        try:
            self.cursor.execute(query)
            return self.cursor.fetchall()
        except Exception as e:
            logger.error(f"Fehler beim Abrufen bestehender Indizes: {e}")
            return []

    def get_expensive_queries(self):
        """Identifiziert teure Abfragen basierend auf pg_stat_statements."""
        query = """
        SELECT
            queryid,
            query,
            calls,
            total_time / 1000 as total_time_sec,
            mean_time / 1000 as mean_time_sec,
            rows
        FROM
            pg_stat_statements
        WHERE
            calls >= %s
            AND query NOT LIKE '%%pg_stat_statements%%'
            AND query NOT LIKE '%%pg_catalog%%'
            AND query NOT LIKE '%%information_schema%%'
            AND query ~* '(SELECT|UPDATE|DELETE)'
        ORDER BY
            total_time DESC
        LIMIT 100;
        """
        try:
            self.cursor.execute(query, (self.min_calls,))
            return self.cursor.fetchall()
        except Exception as e:
            logger.error(f"Fehler beim Abrufen teurer Abfragen: {e}")
            return []

    def extract_tables_and_columns(self, query_text):
        """
        Extrahiert Tabellen und Spalten aus einer Abfrage.
        
        Diese Methode verwendet einfache reguläre Ausdrücke, um Tabellen und
        Spalten aus WHERE, JOIN und ORDER BY Klauseln zu extrahieren.
        """
        tables = set()
        columns = defaultdict(set)
        
        # Einfaches Tabellen-Extraktionsmuster
        table_pattern = r'FROM\s+([a-zA-Z0-9_\.]+)|\bJOIN\s+([a-zA-Z0-9_\.]+)'
        table_matches = re.finditer(table_pattern, query_text, re.IGNORECASE)
        
        for match in table_matches:
            table_name = match.group(1) or match.group(2)
            if '.' in table_name:
                table_name = table_name.split('.')[-1]
            tables.add(table_name)
        
        # Spalten aus WHERE-Klausel extrahieren
        where_pattern = r'WHERE\s+(.+?)(?:ORDER BY|GROUP BY|LIMIT|$)'
        where_matches = re.search(where_pattern, query_text, re.IGNORECASE | re.DOTALL)
        
        if where_matches:
            where_clause = where_matches.group(1)
            # Spalten in Bedingungen finden
            column_pattern = r'([a-zA-Z0-9_\.]+)\s*(?:=|>|<|>=|<=|<>|!=|\bIN\b|\bLIKE\b)'
            column_matches = re.finditer(column_pattern, where_clause)
            
            for match in column_matches:
                col_name = match.group(1)
                if '.' in col_name:
                    table_name, col_name = col_name.split('.')
                    tables.add(table_name)
                    columns[table_name].add(col_name)
                else:
                    # Wenn kein Tabellenpräfix, füge zu allen Tabellen hinzu
                    for table in tables:
                        columns[table].add(col_name)
        
        # Spalten aus ORDER BY-Klausel extrahieren
        order_pattern = r'ORDER BY\s+(.+?)(?:LIMIT|$)'
        order_matches = re.search(order_pattern, query_text, re.IGNORECASE)
        
        if order_matches:
            order_clause = order_matches.group(1)
            # Spalten in ORDER BY finden
            order_cols = [col.strip() for col in order_clause.split(',')]
            for col in order_cols:
                col_name = col.split()[0]  # Richtung (ASC/DESC) entfernen
                if '.' in col_name:
                    table_name, col_name = col_name.split('.')
                    tables.add(table_name)
                    columns[table_name].add(col_name)
                else:
                    # Wenn kein Tabellenpräfix, füge zu allen Tabellen hinzu
                    for table in tables:
                        columns[table].add(col_name)
        
        return tables, columns
    
    def validate_tables_and_columns(self, tables, columns):
        """
        Überprüft, ob die extrahierten Tabellen und Spalten tatsächlich existieren.
        """
        valid_tables = set()
        valid_columns = defaultdict(set)
        
        # Überprüfe jede Tabelle
        for table in tables:
            try:
                self.cursor.execute(f"SELECT 1 FROM information_schema.tables WHERE table_name = %s", (table,))
                if self.cursor.fetchone():
                    valid_tables.add(table)
            except Exception as e:
                logger.debug(f"Tabelle {table} kann nicht validiert werden: {e}")
        
        # Überprüfe jede Spalte für valide Tabellen
        for table in valid_tables:
            for column in columns[table]:
                try:
                    self.cursor.execute(
                        "SELECT 1 FROM information_schema.columns WHERE table_name = %s AND column_name = %s",
                        (table, column)
                    )
                    if self.cursor.fetchone():
                        valid_columns[table].add(column)
                except Exception as e:
                    logger.debug(f"Spalte {column} in Tabelle {table} kann nicht validiert werden: {e}")
        
        return valid_tables, valid_columns
    
    def analyze_index_candidates(self, expensive_queries):
        """
        Analysiert teure Abfragen und identifiziert potenzielle Indexkandidaten.
        """
        index_candidates = []
        existing_indexes = self.get_existing_indexes()
        
        # Extrahiere alle bestehenden Indizes für den Vergleich
        existing_index_signatures = set()
        for idx in existing_indexes:
            table_name = idx['table_name']
            columns = idx['column_names'].split(',')
            # Erstelle eine Signatur für jede Tabellen-Spalten-Kombination
            for i in range(1, len(columns) + 1):
                signature = f"{table_name}:{','.join(sorted(columns[:i]))}"
                existing_index_signatures.add(signature)
        
        # Analysiere jede teure Abfrage
        for query_data in expensive_queries:
            query_text = query_data['query']
            query_id = query_data['queryid']
            total_time = query_data['total_time_sec']
            calls = query_data['calls']
            
            tables, columns = self.extract_tables_and_columns(query_text)
            valid_tables, valid_columns = self.validate_tables_and_columns(tables, columns)
            
            for table in valid_tables:
                if valid_columns[table]:
                    # Einzelspaltenindizes
                    for column in valid_columns[table]:
                        signature = f"{table}:{column}"
                        if signature not in existing_index_signatures:
                            # Potenzieller neuer Index
                            index_candidates.append({
                                'table': table,
                                'columns': [column],
                                'query_ids': [query_id],
                                'total_time': total_time,
                                'calls': calls,
                                'signature': signature
                            })
                    
                    # Mehrspaltenindizes für Tabellen mit mehreren Filterbedingungen
                    if len(valid_columns[table]) > 1:
                        columns_list = sorted(list(valid_columns[table]))
                        signature = f"{table}:{','.join(columns_list)}"
                        if signature not in existing_index_signatures:
                            # Potenzieller neuer Mehrspaltensindex
                            index_candidates.append({
                                'table': table,
                                'columns': columns_list,
                                'query_ids': [query_id],
                                'total_time': total_time,
                                'calls': calls,
                                'signature': signature
                            })
        
        # Zusammenfassen doppelter Indexkandidaten
        consolidated_candidates = {}
        for candidate in index_candidates:
            signature = candidate['signature']
            if signature in consolidated_candidates:
                consolidated_candidates[signature]['query_ids'].append(candidate['query_ids'][0])
                consolidated_candidates[signature]['total_time'] += candidate['total_time']
                consolidated_candidates[signature]['calls'] += candidate['calls']
            else:
                consolidated_candidates[signature] = candidate
        
        # Sortiere nach potenzieller Zeitersparnis
        sorted_candidates = sorted(
            consolidated_candidates.values(),
            key=lambda x: x['total_time'],
            reverse=True
        )
        
        return sorted_candidates[:self.max_indexes]
    
    def simulate_index_benefits(self, index_candidates):
        """
        Simuliert die Vorteile der vorgeschlagenen Indizes mit HypoPG, falls verfügbar.
        """
        results = []
        
        # Prüfe, ob HypoPG verfügbar ist
        self.cursor.execute("SELECT 1 FROM pg_extension WHERE extname = 'hypopg';")
        hypo_available = bool(self.cursor.fetchone())
        
        if not hypo_available:
            logger.warning("HypoPG ist nicht verfügbar. Simulation wird übersprungen.")
            # Standardbewertung ohne Simulation zurückgeben
            for candidate in index_candidates:
                candidate['benefit_percent'] = None
                candidate['create_statement'] = self.generate_create_statement(
                    candidate['table'], candidate['columns']
                )
                results.append(candidate)
            return results
        
        # HypoPG ist verfügbar, führe Simulation für jeden Kandidaten durch
        for candidate in index_candidates:
            table = candidate['table']
            columns = candidate['columns']
            query_ids = candidate['query_ids']
            
            # Erstelle hypothetischen Index
            create_statement = self.generate_create_statement(table, columns)
            try:
                # HypoPG versucht, einen hypothetischen Index zu erstellen
                self.cursor.execute(f"SELECT * FROM hypopg_create_index('{create_statement}');")
                hypo_index = self.cursor.fetchone()
                hypo_index_oid = hypo_index['indexrelid']
                
                # Performance mit Index für jede Abfrage messen
                total_benefit = 0
                measured_queries = 0
                
                for query_id in query_ids:
                    # Abfrage finden
                    self.cursor.execute(
                        "SELECT query FROM pg_stat_statements WHERE queryid = %s",
                        (query_id,)
                    )
                    query_row = self.cursor.fetchone()
                    if query_row:
                        query_text = query_row['query']
                        
                        # Originale Ausführungszeit messen
                        self.cursor.execute(f"EXPLAIN (ANALYZE, FORMAT JSON) {query_text}")
                        original_plan = self.cursor.fetchone()[0]
                        original_cost = original_plan[0]['Plan']['Total Cost']
                        
                        # Ausführungszeit mit hypothetischem Index messen
                        self.cursor.execute(f"SET hypopg.enabled = on;")
                        self.cursor.execute(f"EXPLAIN (ANALYZE, FORMAT JSON) {query_text}")
                        hypo_plan = self.cursor.fetchone()[0]
                        hypo_cost = hypo_plan[0]['Plan']['Total Cost']
                        self.cursor.execute(f"SET hypopg.enabled = off;")
                        
                        # Berechne Verbesserung in Prozent
                        if original_cost > 0:
                            benefit = (original_cost - hypo_cost) / original_cost * 100
                            total_benefit += benefit
                            measured_queries += 1
                
                # Durchschnittliche Verbesserung berechnen
                avg_benefit = total_benefit / measured_queries if measured_queries > 0 else 0
                
                # Hypothetischen Index löschen
                self.cursor.execute(f"SELECT * FROM hypopg_drop_index({hypo_index_oid});")
                
                # Ergebnis hinzufügen
                candidate['benefit_percent'] = avg_benefit
                candidate['create_statement'] = create_statement
                
                if avg_benefit >= self.min_benefit_percent:
                    results.append(candidate)
                
            except Exception as e:
                logger.error(f"Fehler bei der Simulation des Index {create_statement}: {e}")
                candidate['benefit_percent'] = None
                candidate['create_statement'] = create_statement
                results.append(candidate)
        
        # Nach Benefit sortieren
        results = sorted(results, key=lambda x: x['benefit_percent'] or 0, reverse=True)
        return results
    
    def generate_create_statement(self, table, columns):
        """Erzeugt ein CREATE INDEX Statement für die angegebene Tabelle und Spalten."""
        columns_str = ', '.join(columns)
        index_name = f"idx_{table}_{'_'.join(columns)}"
        # Kürze lange Indexnamen
        if len(index_name) > 63:
            index_name = index_name[:59] + "_idx"
        create_statement = f"CREATE INDEX {index_name} ON {table} ({columns_str})"
        return create_statement

    def run_analysis(self):
        """Führt die gesamte Indexanalyse durch."""
        logger.info("Starte Index-Analyse...")
        
        # Teure Abfragen abrufen
        expensive_queries = self.get_expensive_queries()
        if not expensive_queries:
            logger.info("Keine teuren Abfragen für die Analyse gefunden.")
            return []
        
        logger.info(f"{len(expensive_queries)} teure Abfragen gefunden")
        
        # Potenziell nützliche Indizes identifizieren
        index_candidates = self.analyze_index_candidates(expensive_queries)
        logger.info(f"{len(index_candidates)} potenzielle Index-Kandidaten identifiziert")
        
        # Indexvorteile simulieren
        recommended_indexes = self.simulate_index_benefits(index_candidates)
        logger.info(f"{len(recommended_indexes)} Indizes werden empfohlen")
        
        return recommended_indexes
    
    def print_recommendations(self, recommendations):
        """Gibt Empfehlungen in tabellarischer Form aus."""
        if not recommendations:
            print("\nKeine Index-Empfehlungen gefunden.")
            return
        
        headers = ["Tabelle", "Spalten", "Erwartete Verbesserung", "CREATE INDEX Statement"]
        table_data = []
        
        for rec in recommendations:
            benefit = f"{rec['benefit_percent']:.2f}%" if rec['benefit_percent'] is not None else "Unbekannt"
            table_data.append([
                rec['table'],
                ", ".join(rec['columns']),
                benefit,
                rec['create_statement']
            ])
        
        print("\nEmpfohlene Indizes:")
        print(tabulate(table_data, headers=headers, tablefmt="grid"))
        
        # SQL-Skript ausgeben
        print("\nSQL-Skript für empfohlene Indizes:")
        for rec in recommendations:
            print(f"{rec['create_statement']};")
    
    def close(self):
        """Schließt die Datenbankverbindung."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()

def parse_args():
    """Verarbeitet Kommandozeilenargumente."""
    parser = argparse.ArgumentParser(description='ExaPG Index-Empfehlungssystem')
    
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
    parser.add_argument('-c', '--min-calls', type=int, default=10,
                        help='Mindestanzahl an Aufrufen, bevor eine Abfrage betrachtet wird (Standard: 10)')
    parser.add_argument('-m', '--max-indexes', type=int, default=10,
                        help='Maximale Anzahl an empfohlenen Indizes (Standard: 10)')
    parser.add_argument('-b', '--min-benefit', type=float, default=10.0,
                        help='Minimaler Prozentsatz an potenzieller Verbesserung (Standard: 10.0)')
    parser.add_argument('-o', '--output', 
                        help='Ausgabedatei für SQL-Skript (optional)')
    
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
    
    # Index-Analyse durchführen
    advisor = IndexAdvisor(
        conn_params=conn_params,
        min_calls=args.min_calls,
        max_indexes=args.max_indexes,
        min_benefit_percent=args.min_benefit
    )
    
    try:
        recommendations = advisor.run_analysis()
        advisor.print_recommendations(recommendations)
        
        # In Datei schreiben, falls gewünscht
        if args.output and recommendations:
            with open(args.output, 'w') as f:
                f.write("-- ExaPG Index-Empfehlungen\n")
                f.write(f"-- Generiert am: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
                for rec in recommendations:
                    f.write(f"{rec['create_statement']};\n")
                logger.info(f"SQL-Skript in {args.output} geschrieben")
                
    finally:
        advisor.close()

if __name__ == '__main__':
    main() 