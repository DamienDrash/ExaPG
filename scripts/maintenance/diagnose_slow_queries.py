#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ExaPG Selbstdiagnose-Werkzeug für langsame Abfragen
---------------------------------------------------

Dieses Skript identifiziert langsame Abfragen in PostgreSQL, führt automatisch EXPLAIN ANALYZE aus
und gibt Optimierungsempfehlungen basierend auf den Ergebnissen.

Funktionen:
- Identifizierung langsamer Abfragen über pg_stat_statements
- Automatische Ausführung von EXPLAIN ANALYZE für langsame Abfragen
- Analyse der Ausführungspläne und Identifizierung von Engpässen
- Generierung von Optimierungsempfehlungen
- Speicherung der Ergebnisse in einer Diagnose-Tabelle
- E-Mail-Benachrichtigung (optional)
"""

import argparse
import os
import re
import sys
import time
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import DictCursor
import json
import pandas as pd
import matplotlib.pyplot as plt
from tabulate import tabulate

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger('diagnose_slow_queries')

# Konstanten
DEFAULT_SLOW_QUERY_THRESHOLD = 1000  # in Millisekunden
DEFAULT_MAX_QUERIES = 10
DEFAULT_HISTORY_DAYS = 7

# Muster für die Analyse von EXPLAIN-Ausgaben
PATTERNS = {
    'seq_scan': r'Seq Scan on ([^\s]+)',
    'missing_index': r'Seq Scan on ([^\s]+)(?!.*Index)',
    'expensive_sort': r'Sort.*cost=([0-9.]+)\.\.([0-9.]+)',
    'high_cost_join': r'(Hash Join|Nested Loop|Merge Join).*cost=([0-9.]+)\.\.([0-9.]+)',
    'low_rows_estimate': r'rows=([0-9]+) .* actual rows=([0-9]+)',
}

class SlowQueryDiagnoser:
    def __init__(self, conn_params, threshold_ms=DEFAULT_SLOW_QUERY_THRESHOLD, 
                 max_queries=DEFAULT_MAX_QUERIES, history_days=DEFAULT_HISTORY_DAYS):
        """
        Initialisiert den SlowQueryDiagnoser.
        
        Args:
            conn_params: Verbindungsparameter für PostgreSQL
            threshold_ms: Schwellenwert für langsame Abfragen in Millisekunden
            max_queries: Maximale Anzahl an Abfragen zur Analyse
            history_days: Anzahl der Tage für die Verlaufsanalyse
        """
        self.conn_params = conn_params
        self.threshold_ms = threshold_ms
        self.max_queries = max_queries
        self.history_days = history_days
        self.conn = None
        self.cursor = None
        self.connect()
        self.ensure_diagnosis_table()
        
    def connect(self):
        """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=DictCursor)
            logger.info("Verbindung zur Datenbank hergestellt")
        except Exception as e:
            logger.error(f"Verbindungsfehler: {e}")
            sys.exit(1)
            
    def ensure_diagnosis_table(self):
        """Erstellt die Tabelle für Diagnoseergebnisse, falls sie nicht existiert."""
        query = """
        CREATE TABLE IF NOT EXISTS exapg_query_diagnosis (
            id SERIAL PRIMARY KEY,
            query_id BIGINT,
            query_text TEXT,
            diagnosis_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            execution_time_ms FLOAT,
            calls INTEGER,
            explain_plan TEXT,
            issues JSONB,
            recommendations JSONB
        );
        """
        try:
            self.cursor.execute(query)
            self.conn.commit()
            logger.debug("Diagnose-Tabelle bereitgestellt")
        except Exception as e:
            logger.error(f"Fehler beim Erstellen der Diagnose-Tabelle: {e}")
            self.conn.rollback()
    
    def get_slow_queries(self):
        """Identifiziert langsame Abfragen basierend auf pg_stat_statements."""
        query = """
        SELECT
            queryid,
            query,
            mean_exec_time as execution_time_ms,
            calls,
            total_exec_time / 1000 as total_time_sec
        FROM
            pg_stat_statements
        WHERE
            mean_exec_time > %s
            AND query NOT LIKE '%%pg_stat_statements%%'
            AND query NOT LIKE '%%exapg_query_diagnosis%%'
            AND query NOT LIKE '%%information_schema%%'
        ORDER BY
            mean_exec_time DESC
        LIMIT %s;
        """
        try:
            self.cursor.execute(query, (self.threshold_ms, self.max_queries))
            return self.cursor.fetchall()
        except Exception as e:
            logger.error(f"Fehler beim Abrufen langsamer Abfragen: {e}")
            return []
    
    def run_explain_analyze(self, query_text):
        """Führt EXPLAIN ANALYZE für eine Abfrage aus."""
        # Sicherstellen, dass die Abfrage mit einem Semikolon endet
        if not query_text.strip().endswith(';'):
            query_text = query_text.strip() + ';'
            
        # Entferne bestehende EXPLAIN, falls vorhanden
        query_text = re.sub(r'^EXPLAIN\s+(?:ANALYZE\s+)?', '', query_text, flags=re.IGNORECASE)
        
        explain_query = f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query_text}"
        try:
            self.cursor.execute(explain_query)
            return self.cursor.fetchone()[0]
        except Exception as e:
            logger.error(f"Fehler beim Ausführen von EXPLAIN ANALYZE: {e}")
            return None
    
    def analyze_explain_plan(self, explain_json):
        """Analysiert den EXPLAIN PLAN und identifiziert potenzielle Probleme."""
        if not explain_json:
            return {}, {}
            
        issues = {
            'seq_scans': [],
            'missing_indexes': [],
            'expensive_sorts': [],
            'high_cost_joins': [],
            'estimation_errors': []
        }
        
        recommendations = {
            'create_indexes': [],
            'update_statistics': [],
            'rewrite_queries': [],
            'add_joins': [],
            'config_changes': []
        }
        
        plan = explain_json[0]['Plan']
        
        # Rekursive Funktion zum Durchlaufen des Plans
        def traverse_plan(node, depth=0):
            # Sequential Scans identifizieren
            if node.get('Node Type') == 'Seq Scan':
                table_name = node.get('Relation Name')
                rows = node.get('Plan Rows', 0)
                cost = node.get('Total Cost', 0)
                
                issues['seq_scans'].append({
                    'table': table_name,
                    'rows': rows,
                    'cost': cost
                })
                
                # Prüfen, ob ein Index hilfreich sein könnte
                if rows > 100 and cost > 1000:
                    filter_cond = node.get('Filter', '')
                    if filter_cond:
                        cols = re.findall(r'([a-zA-Z0-9_]+) [=<>]', filter_cond)
                        if cols:
                            recommendations['create_indexes'].append({
                                'table': table_name,
                                'columns': cols,
                                'filter': filter_cond
                            })
            
            # Teure Sortierungen identifizieren
            if node.get('Node Type') == 'Sort':
                cost = node.get('Total Cost', 0)
                if cost > 10000:
                    issues['expensive_sorts'].append({
                        'keys': node.get('Sort Key', []),
                        'cost': cost
                    })
                    recommendations['create_indexes'].append({
                        'type': 'sort_improvement',
                        'keys': node.get('Sort Key', [])
                    })
            
            # Teure Joins identifizieren
            if 'Join' in node.get('Node Type', ''):
                cost = node.get('Total Cost', 0)
                if cost > 50000:
                    issues['high_cost_joins'].append({
                        'type': node.get('Node Type'),
                        'cost': cost
                    })
                    if 'Hash' not in node.get('Node Type', '') and cost > 100000:
                        recommendations['rewrite_queries'].append({
                            'type': 'consider_hash_join',
                            'cost': cost
                        })
            
            # Schätzfehler identifizieren
            if 'Plan Rows' in node and 'Actual Rows' in node:
                plan_rows = node.get('Plan Rows', 0)
                actual_rows = node.get('Actual Rows', 0)
                if plan_rows > 0 and actual_rows > 0:
                    ratio = max(plan_rows / actual_rows, actual_rows / plan_rows)
                    if ratio > 100:  # Schätzung weicht um mehr als Faktor 100 ab
                        issues['estimation_errors'].append({
                            'node': node.get('Node Type'),
                            'plan_rows': plan_rows,
                            'actual_rows': actual_rows,
                            'ratio': ratio
                        })
                        recommendations['update_statistics'].append({
                            'table': node.get('Relation Name', 'unbekannt'),
                            'ratio': ratio
                        })
            
            # Rekursiv alle Unterknoten durchlaufen
            for child_key in ['Plans', 'Subplans']:
                if child_key in node:
                    for child in node[child_key]:
                        traverse_plan(child, depth + 1)
        
        traverse_plan(plan)
        
        # Empfehlungen für Konfigurationsänderungen
        if plan.get('Total Cost', 0) > 100000:
            recommendations['config_changes'].append({
                'param': 'work_mem',
                'reason': 'Hohe Gesamtkosten könnten auf Speichermangel hindeuten'
            })
            
        if any(issue.get('cost', 0) > 50000 for issue in issues['seq_scans']):
            recommendations['config_changes'].append({
                'param': 'random_page_cost',
                'reason': 'Eventuell sollte random_page_cost reduziert werden, um Index-Nutzung zu fördern'
            })
            
        return issues, recommendations
    
    def store_diagnosis(self, query_id, query_text, exec_time_ms, calls, explain_json, issues, recommendations):
        """Speichert die Diagnoseergebnisse in der Datenbank."""
        query = """
        INSERT INTO exapg_query_diagnosis
            (query_id, query_text, execution_time_ms, calls, explain_plan, issues, recommendations)
        VALUES
            (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id;
        """
        try:
            self.cursor.execute(
                query, 
                (
                    query_id, 
                    query_text, 
                    exec_time_ms, 
                    calls, 
                    json.dumps(explain_json) if explain_json else None,
                    json.dumps(issues),
                    json.dumps(recommendations)
                )
            )
            diagnosis_id = self.cursor.fetchone()[0]
            self.conn.commit()
            logger.info(f"Diagnose mit ID {diagnosis_id} gespeichert")
            return diagnosis_id
        except Exception as e:
            logger.error(f"Fehler beim Speichern der Diagnose: {e}")
            self.conn.rollback()
            return None
            
    def get_historical_data(self, query_id):
        """Ruft historische Daten für eine Abfrage ab."""
        query = """
        SELECT
            diagnosis_time,
            execution_time_ms
        FROM
            exapg_query_diagnosis
        WHERE
            query_id = %s
            AND diagnosis_time > NOW() - INTERVAL %s DAY
        ORDER BY
            diagnosis_time ASC;
        """
        try:
            self.cursor.execute(query, (query_id, self.history_days))
            return self.cursor.fetchall()
        except Exception as e:
            logger.error(f"Fehler beim Abrufen historischer Daten: {e}")
            return []
            
    def create_trend_plot(self, history_data, query_id):
        """Erstellt einen Plot für den Trend der Ausführungszeit."""
        if not history_data:
            return None
            
        df = pd.DataFrame(history_data)
        df.columns = ['timestamp', 'exec_time_ms']
        
        plt.figure(figsize=(10, 6))
        plt.plot(df['timestamp'], df['exec_time_ms'], marker='o')
        plt.title(f'Ausführungszeit-Trend für Query ID {query_id}')
        plt.xlabel('Datum')
        plt.ylabel('Ausführungszeit (ms)')
        plt.grid(True)
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        filename = f"/tmp/query_{query_id}_trend.png"
        plt.savefig(filename)
        plt.close()
        return filename
        
    def send_email_report(self, email_config, diagnoses):
        """Sendet einen E-Mail-Bericht mit den Diagnoseergebnissen."""
        if not email_config or not diagnoses:
            return
            
        try:
            msg = MIMEMultipart()
            msg['From'] = email_config['from']
            msg['To'] = email_config['to']
            msg['Subject'] = f"ExaPG Langsame Abfragen Diagnose - {datetime.now().strftime('%Y-%m-%d')}"
            
            body = """
            <html>
            <head>
                <style>
                    table { border-collapse: collapse; width: 100%; }
                    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                    th { background-color: #f2f2f2; }
                    tr:nth-child(even) { background-color: #f9f9f9; }
                    .warning { color: orange; }
                    .critical { color: red; }
                </style>
            </head>
            <body>
                <h2>ExaPG Langsame Abfragen Diagnose</h2>
                <p>Die folgenden langsamen Abfragen wurden identifiziert und analysiert:</p>
                <table>
                    <tr>
                        <th>Abfrage-ID</th>
                        <th>Ausführungszeit (ms)</th>
                        <th>Aufrufe</th>
                        <th>Probleme</th>
                        <th>Empfehlungen</th>
                    </tr>
            """
            
            for d in diagnoses:
                issues_count = sum(len(v) for v in d['issues'].values())
                severity_class = "critical" if d['execution_time_ms'] > 5000 else "warning"
                
                body += f"""
                    <tr class="{severity_class}">
                        <td>{d['query_id']}</td>
                        <td>{d['execution_time_ms']:.2f}</td>
                        <td>{d['calls']}</td>
                        <td>{issues_count}</td>
                        <td>{len(d['recommendations'].get('create_indexes', []))} Index(e), {len(d['recommendations'].get('config_changes', []))} Konfigurationsänderung(en)</td>
                    </tr>
                """
            
            body += """
                </table>
                <p>Für detaillierte Diagnosen prüfen Sie bitte die exapg_query_diagnosis Tabelle.</p>
            </body>
            </html>
            """
            
            msg.attach(MIMEText(body, 'html'))
            
            server = smtplib.SMTP(email_config['smtp_server'], email_config['smtp_port'])
            if email_config.get('use_tls', False):
                server.starttls()
            if 'username' in email_config and 'password' in email_config:
                server.login(email_config['username'], email_config['password'])
            server.send_message(msg)
            server.quit()
            
            logger.info(f"E-Mail-Bericht an {email_config['to']} gesendet")
        except Exception as e:
            logger.error(f"Fehler beim Senden des E-Mail-Berichts: {e}")
    
    def run_diagnosis(self, email_config=None):
        """Führt die gesamte Diagnose aus."""
        logger.info(f"Starte Diagnose mit Schwellenwert {self.threshold_ms}ms")
        
        slow_queries = self.get_slow_queries()
        if not slow_queries:
            logger.info("Keine langsamen Abfragen gefunden.")
            return
            
        logger.info(f"{len(slow_queries)} langsame Abfragen gefunden")
        
        diagnoses = []
        for query_data in slow_queries:
            query_id = query_data['queryid']
            query_text = query_data['query']
            execution_time_ms = query_data['execution_time_ms']
            calls = query_data['calls']
            
            logger.info(f"Analysiere Abfrage {query_id} (Ausführungszeit: {execution_time_ms:.2f}ms)")
            
            explain_json = self.run_explain_analyze(query_text)
            issues, recommendations = self.analyze_explain_plan(explain_json)
            
            diagnosis_id = self.store_diagnosis(
                query_id, query_text, execution_time_ms, calls, explain_json, issues, recommendations
            )
            
            history_data = self.get_historical_data(query_id)
            if history_data and len(history_data) > 1:
                trend_plot = self.create_trend_plot(history_data, query_id)
                logger.info(f"Trend-Plot erstellt: {trend_plot}")
            
            diagnoses.append({
                'diagnosis_id': diagnosis_id,
                'query_id': query_id,
                'execution_time_ms': execution_time_ms,
                'calls': calls,
                'issues': issues,
                'recommendations': recommendations
            })
            
        # Ausgabe der Diagnose
        self.print_diagnosis_summary(diagnoses)
        
        # E-Mail-Bericht senden, falls konfiguriert
        if email_config:
            self.send_email_report(email_config, diagnoses)
            
        return diagnoses
        
    def print_diagnosis_summary(self, diagnoses):
        """Gibt eine Zusammenfassung der Diagnose aus."""
        if not diagnoses:
            return
            
        headers = ["ID", "Ausführungszeit (ms)", "Aufrufe", "Hauptprobleme", "Empfehlungen"]
        table_data = []
        
        for d in diagnoses:
            issues_summary = []
            if d['issues'].get('seq_scans'):
                issues_summary.append(f"{len(d['issues']['seq_scans'])} Seq Scans")
            if d['issues'].get('expensive_sorts'):
                issues_summary.append(f"{len(d['issues']['expensive_sorts'])} Teure Sortierungen")
            if d['issues'].get('estimation_errors'):
                issues_summary.append(f"{len(d['issues']['estimation_errors'])} Schätzfehler")
                
            recommendations_summary = []
            if d['recommendations'].get('create_indexes'):
                recommendations_summary.append(f"{len(d['recommendations']['create_indexes'])} Index(e) erstellen")
            if d['recommendations'].get('update_statistics'):
                recommendations_summary.append(f"Statistiken aktualisieren")
            if d['recommendations'].get('config_changes'):
                recommendations_summary.append(f"{len(d['recommendations']['config_changes'])} Konfigurationsänderung(en)")
                
            table_data.append([
                d['query_id'],
                f"{d['execution_time_ms']:.2f}",
                d['calls'],
                ", ".join(issues_summary) or "Keine",
                ", ".join(recommendations_summary) or "Keine"
            ])
            
        print("\nZusammenfassung der Diagnose:")
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
    parser = argparse.ArgumentParser(description='ExaPG Selbstdiagnose-Werkzeug für langsame Abfragen')
    
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
    parser.add_argument('-t', '--threshold', type=float, default=DEFAULT_SLOW_QUERY_THRESHOLD,
                        help=f'Schwellenwert für langsame Abfragen in Millisekunden (Standard: {DEFAULT_SLOW_QUERY_THRESHOLD})')
    parser.add_argument('-m', '--max-queries', type=int, default=DEFAULT_MAX_QUERIES,
                        help=f'Maximale Anzahl zu analysierender Abfragen (Standard: {DEFAULT_MAX_QUERIES})')
    parser.add_argument('--history-days', type=int, default=DEFAULT_HISTORY_DAYS,
                        help=f'Anzahl der Tage für die Verlaufsanalyse (Standard: {DEFAULT_HISTORY_DAYS})')
    parser.add_argument('--email', action='store_true',
                        help='E-Mail-Bericht senden')
    parser.add_argument('--email-to',
                        help='E-Mail-Empfänger')
    parser.add_argument('--email-from',
                        help='E-Mail-Absender')
    parser.add_argument('--smtp-server',
                        help='SMTP-Server')
    parser.add_argument('--smtp-port', type=int, default=25,
                        help='SMTP-Port (Standard: 25)')
    parser.add_argument('--smtp-user',
                        help='SMTP-Benutzername')
    parser.add_argument('--smtp-password',
                        help='SMTP-Passwort')
    parser.add_argument('--smtp-tls', action='store_true',
                        help='TLS für SMTP verwenden')
    
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
    
    # E-Mail-Konfiguration
    email_config = None
    if args.email and args.email_to and args.email_from and args.smtp_server:
        email_config = {
            'to': args.email_to,
            'from': args.email_from,
            'smtp_server': args.smtp_server,
            'smtp_port': args.smtp_port,
            'use_tls': args.smtp_tls,
        }
        if args.smtp_user and args.smtp_password:
            email_config['username'] = args.smtp_user
            email_config['password'] = args.smtp_password
    
    # Diagnose durchführen
    diagnoser = SlowQueryDiagnoser(
        conn_params=conn_params,
        threshold_ms=args.threshold,
        max_queries=args.max_queries,
        history_days=args.history_days
    )
    
    try:
        diagnoser.run_diagnosis(email_config)
    finally:
        diagnoser.close()

if __name__ == '__main__':
    main() 