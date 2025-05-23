#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Exasol-Schema-Extraktor für ExaPG

Dieses Skript extrahiert das Schema aus einer Exasol-Datenbank und konvertiert es
in ein PostgreSQL-kompatibles Format für ExaPG.

Beispielverwendung:
    python3 extract_schema.py --source-dsn "exa:user/password@host:port" --output schema.sql
"""

import os
import sys
import argparse
import logging
import re
import subprocess
import tempfile
from datetime import datetime

# Logging-Konfiguration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('extract_schema')

# Exasol zu PostgreSQL Datentyp-Mapping
TYPE_MAPPING = {
    'DECIMAL': 'NUMERIC',
    'DOUBLE': 'DOUBLE PRECISION',
    'BIGINT': 'BIGINT',
    'INTEGER': 'INTEGER',
    'SMALLINT': 'SMALLINT',
    'VARCHAR\\((\\d+)\\)': 'VARCHAR(\\1)',
    'CHAR\\((\\d+)\\)': 'CHAR(\\1)',
    'BOOLEAN': 'BOOLEAN',
    'DATE': 'DATE',
    'TIMESTAMP': 'TIMESTAMP',
    'TIMESTAMP WITH LOCAL TIME ZONE': 'TIMESTAMP WITH TIME ZONE',
    'INTERVAL YEAR TO MONTH': 'INTERVAL',
    'INTERVAL DAY TO SECOND': 'INTERVAL',
    'GEOMETRY': 'GEOMETRY',  # Benötigt PostGIS
    'HASHTYPE': 'BYTEA'
}

# SQL zur Extraktion des Schemas aus Exasol
SCHEMA_EXTRACTION_SQL = """
SELECT 
    schema_name, 
    object_name, 
    object_type, 
    column_name, 
    column_type, 
    column_ordinal_position, 
    column_default, 
    column_is_nullable
FROM (
    SELECT 
        c.table_schema as schema_name,
        c.table_name as object_name,
        'TABLE' as object_type,
        c.column_name as column_name,
        c.data_type || 
            CASE 
                WHEN c.data_type IN ('DECIMAL') THEN '(' || c.numeric_precision || ',' || c.numeric_scale || ')'
                WHEN c.data_type IN ('VARCHAR', 'CHAR') THEN '(' || c.character_maximum_length || ')'
                ELSE ''
            END as column_type,
        c.ordinal_position as column_ordinal_position,
        c.column_default as column_default,
        c.is_nullable as column_is_nullable
    FROM 
        EXA_ALL_COLUMNS c
    WHERE 
        c.table_schema NOT IN ('SYS', 'EXA_STATISTICS', 'EXA_LOGS')
)
ORDER BY 
    schema_name, object_name, column_ordinal_position;
"""

# SQL zur Extraktion von Primärschlüsseln
PRIMARY_KEY_SQL = """
SELECT 
    cons.constraint_schema as schema_name,
    cons.table_name as table_name,
    cons.constraint_name as constraint_name,
    STRING_AGG(col.column_name, ',') WITHIN GROUP (ORDER BY col.ordinal_position) as key_columns
FROM 
    EXA_ALL_CONSTRAINTS cons
JOIN 
    EXA_ALL_CONSTRAINT_COLUMNS col ON cons.constraint_schema = col.constraint_schema 
    AND cons.constraint_name = col.constraint_name
WHERE 
    cons.constraint_type = 'PRIMARY KEY'
    AND cons.constraint_schema NOT IN ('SYS', 'EXA_STATISTICS', 'EXA_LOGS')
GROUP BY 
    cons.constraint_schema, cons.table_name, cons.constraint_name;
"""

# SQL zur Extraktion von Foreign Keys
FOREIGN_KEY_SQL = """
SELECT 
    cons.constraint_schema as schema_name,
    cons.table_name as table_name,
    cons.constraint_name as constraint_name,
    r.referenced_table as referenced_table,
    STRING_AGG(col.column_name, ',') WITHIN GROUP (ORDER BY col.ordinal_position) as key_columns,
    STRING_AGG(r.referenced_column, ',') WITHIN GROUP (ORDER BY col.ordinal_position) as referenced_columns
FROM 
    EXA_ALL_CONSTRAINTS cons
JOIN 
    EXA_ALL_CONSTRAINT_COLUMNS col ON cons.constraint_schema = col.constraint_schema 
    AND cons.constraint_name = col.constraint_name
JOIN 
    EXA_ALL_FOREIGN_KEYS r ON cons.constraint_schema = r.constraint_schema 
    AND cons.constraint_name = r.constraint_name
    AND col.column_name = r.column_name
WHERE 
    cons.constraint_type = 'FOREIGN KEY'
    AND cons.constraint_schema NOT IN ('SYS', 'EXA_STATISTICS', 'EXA_LOGS')
GROUP BY 
    cons.constraint_schema, cons.table_name, cons.constraint_name, r.referenced_table;
"""

# SQL zur Extraktion von Distribution Keys
DISTRIBUTION_KEY_SQL = """
SELECT 
    schema_name,
    table_name,
    STRING_AGG(column_name, ', ') WITHIN GROUP (ORDER BY distribution_order) as distribution_keys
FROM 
    EXA_ALL_DISTRIBUTION_KEYS
WHERE 
    schema_name NOT IN ('SYS', 'EXA_STATISTICS', 'EXA_LOGS')
GROUP BY 
    schema_name, table_name;
"""

def run_exasol_query(dsn, query):
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
            'exaplus', '-c', dsn, 
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

def convert_type(exasol_type):
    """Konvertiert einen Exasol-Datentyp in einen PostgreSQL-Datentyp."""
    for pattern, replacement in TYPE_MAPPING.items():
        match = re.match(pattern, exasol_type, re.IGNORECASE)
        if match:
            return re.sub(pattern, replacement, exasol_type, flags=re.IGNORECASE)
    
    # Standardrückgabe, wenn keine Übereinstimmung gefunden wurde
    logger.warning(f"Unbekannter Datentyp: {exasol_type} - wird unverändert übernommen")
    return exasol_type

def convert_default(default_value, column_type):
    """Konvertiert einen Exasol-Standardwert in einen PostgreSQL-Standardwert."""
    if default_value is None:
        return None
    
    # Spezielle Behandlung für bestimmte Typen
    if 'TIMESTAMP' in column_type.upper() and 'CURRENT_TIMESTAMP' in default_value.upper():
        return 'CURRENT_TIMESTAMP'
    elif 'DATE' in column_type.upper() and 'CURRENT_DATE' in default_value.upper():
        return 'CURRENT_DATE'
    
    return default_value

def generate_schema_sql(schema_data, pk_data, fk_data, dist_key_data):
    """Generiert PostgreSQL-Schema-SQL aus den extrahierten Exasol-Daten."""
    schema_sql = f"-- Generiert von extract_schema.py am {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    schema_sql += "-- Konvertiert von Exasol-Schema zu PostgreSQL-Schema für ExaPG\n\n"
    
    # Schemaerstellung
    schemas = set(row['SCHEMA_NAME'] for row in schema_data)
    for schema in sorted(schemas):
        schema_sql += f"CREATE SCHEMA IF NOT EXISTS {schema};\n"
    
    schema_sql += "\n-- Tabellendefinitionen\n"
    
    # Tabellen nach Schema und Namen organisieren
    tables = {}
    for row in schema_data:
        schema = row['SCHEMA_NAME']
        table = row['OBJECT_NAME']
        key = (schema, table)
        
        if key not in tables:
            tables[key] = []
        
        tables[key].append(row)
    
    # Distribution Keys in ein Dictionary für einfachen Zugriff konvertieren
    dist_keys = {}
    for row in dist_key_data:
        key = (row['SCHEMA_NAME'], row['TABLE_NAME'])
        dist_keys[key] = row['DISTRIBUTION_KEYS']
    
    # Primärschlüssel in ein Dictionary konvertieren
    primary_keys = {}
    for row in pk_data:
        key = (row['SCHEMA_NAME'], row['TABLE_NAME'])
        primary_keys[key] = row['KEY_COLUMNS']
    
    # Fremdschlüssel nach Tabellen gruppieren
    foreign_keys = {}
    for row in fk_data:
        key = (row['SCHEMA_NAME'], row['TABLE_NAME'])
        if key not in foreign_keys:
            foreign_keys[key] = []
        foreign_keys[key].append(row)
    
    # Tabellen erstellen
    for (schema, table), columns in sorted(tables.items()):
        schema_sql += f"\nCREATE TABLE {schema}.{table} (\n"
        
        # Spalten hinzufügen
        for i, col in enumerate(sorted(columns, key=lambda x: int(x['COLUMN_ORDINAL_POSITION']))):
            col_name = col['COLUMN_NAME']
            col_type = convert_type(col['COLUMN_TYPE'])
            col_nullable = "NULL" if col['COLUMN_IS_NULLABLE'] == 'YES' else "NOT NULL"
            col_default = f"DEFAULT {convert_default(col['COLUMN_DEFAULT'], col['COLUMN_TYPE'])}" if col['COLUMN_DEFAULT'] else ""
            
            schema_sql += f"    {col_name} {col_type} {col_nullable} {col_default}"
            
            # Primärschlüssel als Spaltenkonstraine hinzufügen
            if (schema, table) in primary_keys and primary_keys[(schema, table)] == col_name:
                schema_sql += " PRIMARY KEY"
            
            if i < len(columns) - 1 or (schema, table) in primary_keys or (schema, table) in foreign_keys:
                schema_sql += ","
            
            schema_sql += "\n"
        
        # Primärschlüssel als Tabellenkonstraine hinzufügen, wenn mehrere Spalten
        if (schema, table) in primary_keys and ',' in primary_keys[(schema, table)]:
            schema_sql += f"    PRIMARY KEY ({primary_keys[(schema, table)]})"
            if (schema, table) in foreign_keys:
                schema_sql += ","
            schema_sql += "\n"
        
        # Fremdschlüssel hinzufügen
        if (schema, table) in foreign_keys:
            for i, fk in enumerate(foreign_keys[(schema, table)]):
                schema_sql += f"    CONSTRAINT {fk['CONSTRAINT_NAME']} "
                schema_sql += f"FOREIGN KEY ({fk['KEY_COLUMNS']}) "
                schema_sql += f"REFERENCES {fk['REFERENCED_TABLE']} ({fk['REFERENCED_COLUMNS']})"
                
                if i < len(foreign_keys[(schema, table)]) - 1:
                    schema_sql += ","
                
                schema_sql += "\n"
        
        schema_sql += ");\n"
        
        # Distribution Keys in Partitionierung umwandeln, wenn vorhanden
        if (schema, table) in dist_keys:
            dist_key_cols = dist_keys[(schema, table)]
            schema_sql += f"\n-- Hinweis: Originale Exasol Distribution Keys: {dist_key_cols}\n"
            schema_sql += f"-- Für ExaPG empfehlen wir:\n"
            schema_sql += f"-- ALTER TABLE {schema}.{table} SET (parallel_workers = 8);\n"
            
            # Je nach Spaltentyp unterschiedliche Partitionierungsvorschläge
            date_col_match = re.search(r'(date|time|timestamp)', dist_key_cols, re.IGNORECASE)
            if date_col_match:
                schema_sql += f"-- ODER Zeitbasierte Partitionierung:\n"
                schema_sql += f"-- CREATE TABLE {schema}.{table}_partitioned (\n"
                schema_sql += f"--     LIKE {schema}.{table} INCLUDING ALL\n"
                schema_sql += f"-- ) PARTITION BY RANGE ({dist_key_cols});\n"
            else:
                schema_sql += f"-- ODER Hash-Partitionierung:\n"
                schema_sql += f"-- CREATE TABLE {schema}.{table}_partitioned (\n"
                schema_sql += f"--     LIKE {schema}.{table} INCLUDING ALL\n"
                schema_sql += f"-- ) PARTITION BY HASH ({dist_key_cols});\n"
    
    return schema_sql

def main():
    """Hauptfunktion."""
    parser = argparse.ArgumentParser(description='Extrahiert das Schema aus einer Exasol-Datenbank für ExaPG')
    
    parser.add_argument('--source-dsn', required=True, help='Exasol-DSN im Format "exa:user/password@host:port"')
    parser.add_argument('--output', required=True, help='Ausgabedatei für das generierte SQL-Schema')
    parser.add_argument('--include-schemas', help='Kommagetrennte Liste der zu extrahierenden Schemas (Standard: alle)')
    parser.add_argument('--exclude-schemas', default='SYS,EXA_STATISTICS,EXA_LOGS', 
                        help='Kommagetrennte Liste der zu ignorierenden Schemas (Standard: SYS,EXA_STATISTICS,EXA_LOGS)')
    parser.add_argument('--verbose', action='store_true', help='Ausführliche Ausgabe')
    
    args = parser.parse_args()
    
    # Verbose-Modus
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    try:
        # Schema-Daten extrahieren
        logger.info("Extrahiere Tabellen- und Spaltendefinitionen...")
        schema_data = run_exasol_query(args.source_dsn, SCHEMA_EXTRACTION_SQL)
        
        logger.info("Extrahiere Primärschlüssel...")
        pk_data = run_exasol_query(args.source_dsn, PRIMARY_KEY_SQL)
        
        logger.info("Extrahiere Fremdschlüssel...")
        fk_data = run_exasol_query(args.source_dsn, FOREIGN_KEY_SQL)
        
        logger.info("Extrahiere Distribution Keys...")
        dist_key_data = run_exasol_query(args.source_dsn, DISTRIBUTION_KEY_SQL)
        
        # Schema-SQL generieren
        logger.info("Generiere PostgreSQL-Schema...")
        schema_sql = generate_schema_sql(schema_data, pk_data, fk_data, dist_key_data)
        
        # Ausgabedatei schreiben
        with open(args.output, 'w') as f:
            f.write(schema_sql)
        
        logger.info(f"Schema erfolgreich nach {args.output} extrahiert und konvertiert")
        return 0
    
    except Exception as e:
        logger.error(f"Fehler bei der Schema-Extraktion: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 