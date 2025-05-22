#!/bin/bash
# Setup-Skript für die Parallelverarbeitung in ExaPG
# Dieses Skript richtet alle Parallelverarbeitungsoptimierungen nach dem Systemstart ein

set -e

echo "Richte ExaPG Parallelverarbeitungsoptimierungen ein..."

# Warten bis PostgreSQL vollständig hochgefahren ist
echo "Warte auf PostgreSQL..."
until pg_isready -q; do
    echo "PostgreSQL noch nicht bereit - warte weitere 5 Sekunden"
    sleep 5
done

# Basispfad für SQL-Skripte
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.."
PARALLEL_SQL="${BASE_DIR}/sql/parallel/create_parallel_functions.sql"
PARALLEL_SCRIPT="${BASE_DIR}/scripts/setup/parallel-processing.sh"

echo "Lade parallele SQL-Funktionen aus ${PARALLEL_SQL}..."

# Starte als postgres-Benutzer
if command -v gosu &> /dev/null; then
    EXEC="gosu postgres"
else
    EXEC="su postgres -c"
fi

# Führe das Parallelverarbeitungsskript aus, wenn es existiert
if [ -f "$PARALLEL_SCRIPT" ]; then
    echo "Führe Parallelverarbeitungsskript aus: ${PARALLEL_SCRIPT}"
    chmod +x "$PARALLEL_SCRIPT"
    $EXEC "$PARALLEL_SCRIPT"
fi

# Lade die SQL-Funktionen für parallele Verarbeitung
if [ -f "$PARALLEL_SQL" ]; then
    echo "Lade SQL-Funktionen für parallele Verarbeitung: ${PARALLEL_SQL}"
    $EXEC "psql -v ON_ERROR_STOP=1 -f ${PARALLEL_SQL}"
else
    echo "WARNUNG: Parallele SQL-Funktionen nicht gefunden: ${PARALLEL_SQL}"
fi

# Konfiguriere zusätzliche Parallelitätsparameter
$EXEC "psql -v ON_ERROR_STOP=1 -c \"
    -- Optimiere Parallelität für alle Tabellen
    CREATE OR REPLACE FUNCTION admin.optimize_tables_for_parallel() RETURNS void AS \\\$\\\$
    DECLARE
        tbl record;
    BEGIN
        FOR tbl IN 
            SELECT schemaname, tablename 
            FROM pg_tables 
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        LOOP
            -- VACUUM ANALYZE für Statistikaktualisierung
            EXECUTE 'VACUUM ANALYZE ' || quote_ident(tbl.schemaname) || '.' || quote_ident(tbl.tablename);
            RAISE NOTICE 'Optimiere % für parallele Abfragen', tbl.schemaname || '.' || tbl.tablename;
        END LOOP;
        RETURN;
    END;
    \\\$\\\$ LANGUAGE plpgsql;

    -- Optimiere Parallelität für Indizes
    CREATE OR REPLACE FUNCTION admin.rebuild_indices_parallel() RETURNS void AS \\\$\\\$
    DECLARE
        idx record;
    BEGIN
        FOR idx IN 
            SELECT 
                schemaname, 
                tablename, 
                indexname, 
                indexdef
            FROM 
                pg_indexes
            WHERE 
                schemaname NOT IN ('pg_catalog', 'information_schema')
        LOOP
            -- Indizes mit Parallelität neu erstellen
            EXECUTE 'DROP INDEX IF EXISTS ' || 
                    quote_ident(idx.schemaname) || '.' || quote_ident(idx.indexname);
                    
            -- Extrahiere den CREATE INDEX-Teil und füge PARALLEL-Option hinzu
            EXECUTE regexp_replace(
                idx.indexdef, 
                'CREATE INDEX', 
                'CREATE INDEX CONCURRENTLY', 
                'g'
            );
            
            RAISE NOTICE 'Index % optimiert für parallele Verarbeitung', idx.indexname;
        END LOOP;
        RETURN;
    END;
    \\\$\\\$ LANGUAGE plpgsql;

    -- Setze temporär für alle Sitzungen
    ALTER SYSTEM SET max_parallel_workers_per_gather = 8;
    ALTER SYSTEM SET max_parallel_workers = 16;
    ALTER SYSTEM SET parallel_tuple_cost = 0.01;
    ALTER SYSTEM SET parallel_setup_cost = 100;
    ALTER SYSTEM SET min_parallel_table_scan_size = '8MB';
    ALTER SYSTEM SET min_parallel_index_scan_size = '512kB';
    
    -- Aktiviere Hash-Joins und parallele Hash-Verarbeitung
    ALTER SYSTEM SET enable_hashjoin = on;
    ALTER SYSTEM SET enable_parallel_hash = on;
    
    -- Lade die Konfiguration neu
    SELECT pg_reload_conf();
\""

echo "Parallelverarbeitungsoptimierungen erfolgreich eingerichtet!"
echo "Verwende die admin.* Funktionen für optimierte parallele Analysen." 