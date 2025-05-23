#!/bin/bash
# Optimierung der Parallelverarbeitung für ExaPG
# Dieses Skript konfiguriert PostgreSQL für maximale Parallelität bei analytischen Workloads

set -e

echo "Optimiere PostgreSQL für maximale Parallelverarbeitung..."

# Ermittle CPU-Kerne (in Container-Umgebung eher konservativ einschätzen)
# Minimum 8, für echte Exasol-ähnliche Performance besser 16+
CPU_CORES=8

# Optimierte Werte basierend auf CPU-Kernanzahl
max_workers=$((CPU_CORES * 2))                  # 2 Worker pro CPU-Kern
max_workers_per_gather=$((CPU_CORES))           # 1 Worker pro CPU-Kern
max_parallel_maintenance=$((CPU_CORES / 2))     # Für Wartungsoperationen
effective_io_concurrency=$((CPU_CORES * 20))    # Hoher Wert für SSDs

echo "Konfiguration für $CPU_CORES CPU-Kerne: max_workers=$max_workers, workers_per_gather=$max_workers_per_gather"

# Anwenden der Optimierungen
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Grundlegende Parallelverarbeitung
    ALTER SYSTEM SET max_worker_processes = $max_workers;
    ALTER SYSTEM SET max_parallel_workers = $max_workers;
    ALTER SYSTEM SET max_parallel_workers_per_gather = $max_workers_per_gather;
    ALTER SYSTEM SET max_parallel_maintenance_workers = $max_parallel_maintenance;
    
    -- Parallele Abfragen aggressiver einsetzen
    ALTER SYSTEM SET parallel_setup_cost = 100;          -- Stark reduziert (Standard: 1000)
    ALTER SYSTEM SET parallel_tuple_cost = 0.01;         -- Stark reduziert (Standard: 0.1)
    ALTER SYSTEM SET min_parallel_table_scan_size = '8MB'; -- Parallel ab 8MB
    ALTER SYSTEM SET min_parallel_index_scan_size = '512kB'; -- Parallel ab 512kB
    
    -- Citus-spezifische Einstellungen (falls vorhanden)
    ALTER SYSTEM SET citus.max_adaptive_executor_pool_size = $max_workers;
    ALTER SYSTEM SET citus.max_worker_nodes_tracked = 64;
    
    -- I/O Optimierung für Parallelität
    ALTER SYSTEM SET effective_io_concurrency = $effective_io_concurrency;
    
    -- Parallel-freundliche Speichereinstellungen
    ALTER SYSTEM SET maintenance_work_mem = '2GB';   -- Bei Wartungsoperationen mehr Speicher pro Worker
    
    -- Einstellungen für Verteilungsstrategien in Citus
    ALTER SYSTEM SET default_table_access_method = 'heap';  -- Heap für schreibintensive Operationen
    ALTER SYSTEM SET citus.shard_count = 32;          -- Mehr Shards für bessere Verteilung
    ALTER SYSTEM SET citus.shard_replication_factor = 1;  -- Keine Replikation in Entwicklungsumgebungen
    
    -- Optimierte Hash-Join-Parallelisierung
    ALTER SYSTEM SET enable_hashagg = on;
    ALTER SYSTEM SET enable_hashjoin = on;
    ALTER SYSTEM SET enable_parallel_hash = on;
    ALTER SYSTEM SET enable_parallel_append = on;
EOSQL

# Indextune für Parallelität
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Hilfsfunktion zur Optimierung von Indizes für Parallelität
    CREATE OR REPLACE FUNCTION admin.optimize_indices_for_parallel(schema_name text) 
    RETURNS void AS \$\$
    DECLARE
        idx_record record;
    BEGIN
        -- Erstelle Schema wenn nicht vorhanden
        EXECUTE 'CREATE SCHEMA IF NOT EXISTS admin';
        
        -- Finde alle Indizes im angegebenen Schema
        FOR idx_record IN 
            SELECT 
                schemaname, 
                tablename, 
                indexname
            FROM 
                pg_indexes 
            WHERE 
                schemaname = schema_name
        LOOP
            -- Setze Index-Parameter für Parallelverarbeitung
            EXECUTE format('ALTER INDEX %I.%I SET (parallel_workers = %s)',
                          idx_record.schemaname, 
                          idx_record.indexname,
                          max_parallel_maintenance);
                          
            RAISE NOTICE 'Index %.% optimiert für parallele Verarbeitung',
                          idx_record.schemaname, idx_record.indexname;
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;
EOSQL

# Erstelle Cluster-Verteilungsfunktion (für Citus)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Funktion zur optimalen Verteilung auf Cluster-Knoten
    CREATE OR REPLACE FUNCTION admin.distribute_table_optimally(
        table_schema text,
        table_name text,
        distribution_column text DEFAULT NULL,
        colocation_group text DEFAULT NULL
    ) 
    RETURNS void AS \$\$
    DECLARE
        fully_qualified_name text := table_schema || '.' || table_name;
        dist_column text := distribution_column;
    BEGIN
        -- Fehlerprüfung
        IF (SELECT COUNT(*) FROM pg_extension WHERE extname = 'citus') = 0 THEN
            RAISE NOTICE 'Citus ist nicht installiert - keine Verteilung möglich';
            RETURN;
        END IF;
        
        -- Besten Verteilungsschlüssel automatisch wählen, wenn nicht angegeben
        IF dist_column IS NULL THEN
            -- Primärschlüssel oder einen eindeutigen Index wählen
            SELECT c.column_name INTO dist_column
            FROM information_schema.key_column_usage c
            JOIN information_schema.table_constraints tc 
                ON c.constraint_name = tc.constraint_name
            WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
              AND c.table_schema = table_schema
              AND c.table_name = table_name
            ORDER BY tc.constraint_type DESC  -- PRIMARY KEY bevorzugen
            LIMIT 1;
            
            -- Fallback auf erste Spalte, wenn kein PK oder Unique gefunden
            IF dist_column IS NULL THEN
                SELECT column_name INTO dist_column
                FROM information_schema.columns
                WHERE table_schema = table_schema
                  AND table_name = table_name
                ORDER BY ordinal_position
                LIMIT 1;
            END IF;
        END IF;
        
        -- Tabelle verteilen
        BEGIN
            IF colocation_group IS NOT NULL THEN
                EXECUTE format('SELECT create_distributed_table(%L, %L, colocate_with := %L)',
                            fully_qualified_name, dist_column, colocation_group);
            ELSE
                EXECUTE format('SELECT create_distributed_table(%L, %L)',
                            fully_qualified_name, dist_column);
            END IF;
            
            RAISE NOTICE 'Tabelle % erfolgreich mit Verteilungsschlüssel % verteilt',
                        fully_qualified_name, dist_column;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Fehler bei Verteilung von %: %', fully_qualified_name, SQLERRM;
        END;
    END;
    \$\$ LANGUAGE plpgsql;
EOSQL

# Erstelle Schema für parallele Abfrageoptimierer
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Funktion zur dynamischen Parallelitätsoptimierung basierend auf der Abfrage
    CREATE OR REPLACE FUNCTION admin.execute_parallel_optimized(
        query text,
        desired_parallelism int DEFAULT NULL
    ) 
    RETURNS void AS \$\$
    DECLARE
        current_parallel_workers_per_gather int;
        current_work_mem text;
        estimated_size bigint;
        recommended_parallelism int;
    BEGIN
        -- Aktuelle Einstellungen merken
        SHOW max_parallel_workers_per_gather INTO current_parallel_workers_per_gather;
        SHOW work_mem INTO current_work_mem;
        
        -- Größe der Abfrage abschätzen (vereinfacht)
        BEGIN
            EXECUTE 'EXPLAIN (FORMAT JSON) ' || query INTO estimated_size;
            -- JSON-Ausgabe analysieren und Größe ermitteln würde hier stehen
            estimated_size := 100000000; -- Annahme für diesen einfachen Fall
        EXCEPTION
            WHEN OTHERS THEN
                estimated_size := 10000000; -- Standardannahme
        END;
        
        -- Optimalen Parallelismus berechnen, falls nicht angegeben
        IF desired_parallelism IS NULL THEN
            IF estimated_size < 10000000 THEN -- 10MB
                recommended_parallelism := 2;
            ELSIF estimated_size < 100000000 THEN -- 100MB
                recommended_parallelism := 4;
            ELSIF estimated_size < 1000000000 THEN -- 1GB
                recommended_parallelism := 8;
            ELSE
                recommended_parallelism := 16;
            END IF;
        ELSE 
            recommended_parallelism := desired_parallelism;
        END IF;
        
        -- Temporäre Einstellungen für maximale Parallelität setzen
        EXECUTE 'SET LOCAL max_parallel_workers_per_gather = ' || recommended_parallelism;
        EXECUTE 'SET LOCAL work_mem = ''512MB''';  -- Mehr Speicher pro Worker
        
        -- Abfrage ausführen
        EXECUTE query;
        
        RAISE NOTICE 'Abfrage mit Parallelitätsgrad % ausgeführt', recommended_parallelism;
    END;
    \$\$ LANGUAGE plpgsql;
EOSQL

echo "Parallelverarbeitungsoptimierung abgeschlossen. Führe 'SELECT pg_reload_conf();' aus, um die Änderungen zu aktivieren."
echo "Hinweis: Einige Einstellungen benötigen einen Neustart der Datenbank." 