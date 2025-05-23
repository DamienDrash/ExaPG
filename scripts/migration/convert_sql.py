#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Exasol zu ExaPG SQL Konverter

Dieses Skript konvertiert Exasol-SQL-Abfragen in ExaPG-kompatible SQL-Abfragen.
Es unterstützt die Konvertierung einzelner Dateien oder ganzer Verzeichnisse.

Beispielverwendung:
    python3 convert_sql.py --input exasol_query.sql --output exapg_query.sql
    python3 convert_sql.py --input-dir exasol_scripts/ --output-dir exapg_scripts/
"""

import os
import re
import sys
import argparse
import glob
from pathlib import Path
import logging

# Logging-Konfiguration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('exasol2exapg')

# Mapping von Exasol-Funktionen zu ExaPG-Funktionen
FUNCTION_MAPPING = {
    # Datumsfunktionen
    r'ADD_DAYS\s*\(([^,]+),\s*([^)]+)\)': r'(\1 + (\2) * INTERVAL \'1 day\')',
    r'ADD_MONTHS\s*\(([^,]+),\s*([^)]+)\)': r'(\1 + (\2) * INTERVAL \'1 month\')',
    r'ADD_YEARS\s*\(([^,]+),\s*([^)]+)\)': r'(\1 + (\2) * INTERVAL \'1 year\')',
    r'DAYS_BETWEEN\s*\(([^,]+),\s*([^)]+)\)': r'(\2 - \1)',
    r'SECONDS_BETWEEN\s*\(([^,]+),\s*([^)]+)\)': r'EXTRACT(EPOCH FROM (\2 - \1))',
    
    # Zeichenkettenfunktionen
    r'INSTR\s*\(([^,]+),\s*([^)]+)\)': r'POSITION(\2 IN \1)',
    r'REGEXP_SUBSTR\s*\(([^,]+),\s*([^)]+)\)': r'substring(\1 from \2)',
    
    # NULL-Behandlung
    r'NVL\s*\(([^,]+),\s*([^)]+)\)': r'COALESCE(\1, \2)',
    r'NULLIFZERO\s*\(([^)]+)\)': r'NULLIF(\1, 0)',
    r'ZEROIFNULL\s*\(([^)]+)\)': r'COALESCE(\1, 0)',
    
    # Mathematische Funktionen
    r'DIV\s*\(([^,]+),\s*([^)]+)\)': r'floor(\1 / \2)',
    
    # Typkonvertierungen
    r'TO_DATE\s*\(([^,]+),\s*([^)]+)\)': r'TO_DATE(\1, \2)',
    r'TO_CHAR\s*\(([^,]+),\s*([^)]+)\)': r'TO_CHAR(\1, \2)',
    
    # Aggregatfunktionen
    r'MEDIAN\s*\(([^)]+)\)': r'PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY \1)',
}

# Mapping von Systemtabellen
SYSTEM_TABLE_MAPPING = {
    r'EXA_ALL_TABLES': r'pg_tables',
    r'EXA_ALL_COLUMNS': r'information_schema.columns',
    r'EXA_DBA_USERS': r'pg_user',
    r'EXA_USER_SESSIONS': r'pg_stat_activity',
    r'EXA_ALL_CONSTRAINTS': r'information_schema.table_constraints',
    r'EXA_ALL_INDICES': r'pg_indexes',
}

# Syntaxmapping für spezielle SQL-Konstrukte
SYNTAX_MAPPING = {
    # MERGE INTO
    r'MERGE\s+INTO\s+([^\s]+)\s+([^\s]+)\s+USING\s+([^\s]+)\s+([^\s]+)\s+ON\s+\(([^)]+)\)\s+WHEN\s+MATCHED\s+THEN\s+UPDATE\s+SET\s+([^;]+)\s+WHEN\s+NOT\s+MATCHED\s+THEN\s+INSERT\s+\(([^)]+)\)\s+VALUES\s+\(([^)]+)\)': 
    r'INSERT INTO \1 (\7) SELECT \8 FROM \3 \4 ON CONFLICT DO UPDATE SET \6',
    
    # CONNECT BY
    r'SELECT\s+(.+?)\s+FROM\s+([^\s]+)\s+START\s+WITH\s+(.+?)\s+CONNECT\s+BY\s+PRIOR\s+([^\s]+)\s*=\s*([^\s]+)':
    r'WITH RECURSIVE tree AS (\n  SELECT \1 FROM \2 WHERE \3\n  UNION ALL\n  SELECT t.\1 FROM \2 t JOIN tree tr ON t.\5 = tr.\4\n)\nSELECT \1 FROM tree',
    
    # IMPORT/EXPORT
    r'IMPORT\s+INTO\s+([^\s]+)\s+FROM\s+CSV\s+AT\s+[^\s]+\s+USER\s+[^\s]+\s+IDENTIFIED\s+BY\s+[^\s]+\s+FILE\s+\'([^\']+)\'':
    r'COPY \1 FROM \'\2\' WITH (FORMAT csv, DELIMITER \',\')',
    
    r'EXPORT\s+([^\s]+)\s+INTO\s+CSV\s+AT\s+[^\s]+\s+USER\s+[^\s]+\s+IDENTIFIED\s+BY\s+[^\s]+\s+FILE\s+\'([^\']+)\'':
    r'COPY \1 TO \'\2\' WITH (FORMAT csv, DELIMITER \',\')',
    
    # LIMIT/OFFSET
    r'SELECT\s+(.+?)\s+LIMIT\s+(\d+)\s+OFFSET\s+(\d+)':
    r'SELECT \1 OFFSET \3 ROWS FETCH FIRST \2 ROWS ONLY',
    
    # Distribution Keys in CREATE TABLE
    r'CREATE\s+TABLE\s+([^\s(]+)\s*\(([^)]+)\)\s+DISTRIBUTE\s+BY\s+([^;]+)':
    r'CREATE TABLE \1 (\2) PARTITION BY HASH (\3)',
}

def convert_sql(sql_content):
    """Konvertiert Exasol-SQL in ExaPG-SQL."""
    # Original-SQL für Debugging
    original_sql = sql_content
    
    # Funktionen ersetzen
    for exasol_pattern, exapg_pattern in FUNCTION_MAPPING.items():
        sql_content = re.sub(exasol_pattern, exapg_pattern, sql_content, flags=re.IGNORECASE)
    
    # Systemtabellen ersetzen
    for exasol_table, exapg_table in SYSTEM_TABLE_MAPPING.items():
        sql_content = re.sub(r'\b' + exasol_table + r'\b', exapg_table, sql_content, flags=re.IGNORECASE)
    
    # Syntaxkonstrukte ersetzen
    for exasol_syntax, exapg_syntax in SYNTAX_MAPPING.items():
        sql_content = re.sub(exasol_syntax, exapg_syntax, sql_content, flags=re.IGNORECASE | re.DOTALL)
    
    # Wenn sich etwas geändert hat, fügen wir einen Kommentar hinzu
    if sql_content != original_sql:
        sql_content = f"-- Automatisch konvertiert von Exasol zu ExaPG\n-- Original:\n/*\n{original_sql}\n*/\n\n{sql_content}"
    
    return sql_content

def process_file(input_file, output_file):
    """Verarbeitet eine einzelne SQL-Datei."""
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        converted_sql = convert_sql(sql_content)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(converted_sql)
        
        logger.info(f"Konvertiert: {input_file} -> {output_file}")
        return True
    except Exception as e:
        logger.error(f"Fehler bei der Konvertierung von {input_file}: {str(e)}")
        return False

def process_directory(input_dir, output_dir, recursive=True):
    """Verarbeitet ein Verzeichnis mit SQL-Dateien."""
    # Ausgabeverzeichnis erstellen, falls es nicht existiert
    os.makedirs(output_dir, exist_ok=True)
    
    # Dateimuster
    pattern = os.path.join(input_dir, '**/*.sql' if recursive else '*.sql')
    
    # Alle passenden Dateien verarbeiten
    success_count = 0
    error_count = 0
    
    for input_file in glob.glob(pattern, recursive=recursive):
        relative_path = os.path.relpath(input_file, input_dir)
        output_file = os.path.join(output_dir, relative_path)
        
        # Zielverzeichnis erstellen, falls es nicht existiert
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        if process_file(input_file, output_file):
            success_count += 1
        else:
            error_count += 1
    
    logger.info(f"Verarbeitung abgeschlossen: {success_count} Dateien erfolgreich konvertiert, {error_count} Fehler")
    return success_count, error_count

def main():
    """Hauptfunktion."""
    parser = argparse.ArgumentParser(description='Konvertiert Exasol-SQL in ExaPG-SQL')
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--input', help='Eingabe-SQL-Datei (Exasol)')
    group.add_argument('--input-dir', help='Eingabeverzeichnis mit SQL-Dateien')
    
    parser.add_argument('--output', help='Ausgabe-SQL-Datei (ExaPG)')
    parser.add_argument('--output-dir', help='Ausgabeverzeichnis für konvertierte Dateien')
    parser.add_argument('--non-recursive', action='store_true', help='Verzeichnisse nicht rekursiv durchsuchen')
    parser.add_argument('--verbose', action='store_true', help='Ausführliche Ausgabe')
    
    args = parser.parse_args()
    
    # Verbose-Modus
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # Einzelne Datei verarbeiten
    if args.input:
        if not args.output:
            parser.error("Bei Verwendung von --input ist --output erforderlich.")
        
        if process_file(args.input, args.output):
            logger.info("Konvertierung erfolgreich.")
            return 0
        else:
            logger.error("Konvertierung fehlgeschlagen.")
            return 1
    
    # Verzeichnis verarbeiten
    elif args.input_dir:
        if not args.output_dir:
            parser.error("Bei Verwendung von --input-dir ist --output-dir erforderlich.")
        
        success_count, error_count = process_directory(
            args.input_dir, 
            args.output_dir, 
            recursive=not args.non_recursive
        )
        
        if error_count == 0:
            logger.info(f"Alle Dateien ({success_count}) erfolgreich konvertiert.")
            return 0
        else:
            logger.warning(f"{success_count} Dateien konvertiert, {error_count} Fehler.")
            return 1

if __name__ == "__main__":
    sys.exit(main()) 