-- ExaPG Verteilungsstrategien
-- Optimierte Datenverteilung auf Cluster-Knoten für Exasol-ähnliche Performance
-- Diese Verteilungsstrategien sind für Citus-basierte PostgreSQL-Cluster optimiert

-- Sicherstellen, dass das Admin-Schema existiert
CREATE SCHEMA IF NOT EXISTS admin;

-- 1. Optimale automatische Verteilungsstrategie basierend auf Tabellenstatistiken
CREATE OR REPLACE FUNCTION admin.distribute_table_optimally(
    schema_name TEXT, 
    table_name TEXT,
    distribution_column TEXT DEFAULT NULL,
    distribution_type TEXT DEFAULT 'hash',  -- 'hash', 'range', 'append'
    colocation_group TEXT DEFAULT NULL,
    replication_factor INT DEFAULT 1,
    shard_count INT DEFAULT 32
) RETURNS VOID AS $$
DECLARE
    table_size BIGINT;
    column_stats RECORD;
    suggested_column TEXT;
    full_table_name TEXT;
    column_exists BOOLEAN;
BEGIN
    -- Prüfen, ob Citus installiert ist
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citus') THEN
        RAISE EXCEPTION 'Citus-Erweiterung ist nicht installiert. Bitte installieren Sie zuerst Citus.';
        RETURN;
    END IF;
    
    full_table_name := schema_name || '.' || table_name;
    
    -- Überprüfen, ob die Tabelle existiert
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = schema_name AND table_name = table_name
    ) THEN
        RAISE EXCEPTION 'Tabelle % existiert nicht', full_table_name;
        RETURN;
    END IF;
    
    -- Tabellengröße ermitteln
    EXECUTE format('SELECT pg_total_relation_size(%L)::BIGINT', full_table_name) INTO table_size;
    
    -- Wenn kein Verteilungsschlüssel angegeben wurde, besten Schlüssel automatisch ermitteln
    IF distribution_column IS NULL THEN
        -- Wir priorisieren in dieser Reihenfolge:
        -- 1. Primärschlüssel
        -- 2. Unique-Constraint mit hoher Kardinalität
        -- 3. Index-Spalte mit hoher Kardinalität
        -- 4. Datumsspalte (für zeitbasierte Verteilung)
        
        -- Primärschlüssel suchen
        BEGIN
            SELECT a.attname INTO suggested_column
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = full_table_name::regclass
            AND i.indisprimary;
            
            IF suggested_column IS NOT NULL THEN
                distribution_column := suggested_column;
                RAISE NOTICE 'Primärschlüssel als Verteilungsschlüssel gewählt: %', distribution_column;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Fehler bei der Suche nach Primärschlüssel: %', SQLERRM;
        END;
        
        -- Wenn kein PK gefunden, nach Unique-Index mit hoher Kardinalität suchen
        IF distribution_column IS NULL THEN
            BEGIN
                SELECT a.attname INTO suggested_column
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = full_table_name::regclass
                AND i.indisunique
                ORDER BY pg_stat_get_numscans(i.indexrelid) DESC
                LIMIT 1;
                
                IF suggested_column IS NOT NULL THEN
                    distribution_column := suggested_column;
                    RAISE NOTICE 'Unique-Index als Verteilungsschlüssel gewählt: %', distribution_column;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Fehler bei der Suche nach Unique-Index: %', SQLERRM;
            END;
        END IF;
        
        -- Wenn immer noch kein Schlüssel gefunden, suche nach Zeitstempel-/Datumsfeldern
        IF distribution_column IS NULL THEN
            BEGIN
                SELECT column_name INTO suggested_column
                FROM information_schema.columns
                WHERE table_schema = schema_name
                AND table_name = table_name
                AND data_type IN ('timestamp', 'timestamp with time zone', 'date')
                LIMIT 1;
                
                IF suggested_column IS NOT NULL THEN
                    distribution_column := suggested_column;
                    -- Wenn wir ein Datumsfeld verwenden, ändern wir die Verteilungsstrategie auf 'range'
                    distribution_type := 'range';
                    RAISE NOTICE 'Zeitstempelfeld als Verteilungsschlüssel gewählt: %', distribution_column;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Fehler bei der Suche nach Zeitstempelfeldern: %', SQLERRM;
            END;
        END IF;
        
        -- Wenn immer noch kein Schlüssel gefunden, fallback auf erste Spalte
        IF distribution_column IS NULL THEN
            BEGIN
                SELECT column_name INTO distribution_column
                FROM information_schema.columns
                WHERE table_schema = schema_name
                AND table_name = table_name
                ORDER BY ordinal_position
                LIMIT 1;
                
                RAISE NOTICE 'Keine optimale Verteilungsspalte gefunden, verwende erste Spalte: %', 
                         distribution_column;
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'Konnte keine Verteilungsspalte finden: %', SQLERRM;
            END;
        END IF;
    END IF;
    
    -- Prüfen, ob die gewählte Spalte existiert
    EXECUTE format('
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = %L AND table_name = %L AND column_name = %L
        )', schema_name, table_name, distribution_column) INTO column_exists;
    
    IF NOT column_exists THEN
        RAISE EXCEPTION 'Verteilungsspalte % existiert nicht in Tabelle %', 
                    distribution_column, full_table_name;
        RETURN;
    END IF;
    
    -- Wenn die Tabelle klein ist (< 100 MB), als Referenztabelle replizieren
    IF table_size < 100 * 1024 * 1024 AND distribution_type NOT IN ('reference', 'append') THEN
        RAISE NOTICE 'Tabelle % ist klein (% MB), wird als Referenztabelle repliziert',
                 full_table_name, ROUND(table_size/1024.0/1024.0);
        
        EXECUTE format('SELECT create_reference_table(%L)', full_table_name);
        RAISE NOTICE 'Tabelle % als Referenztabelle repliziert', full_table_name;
        RETURN;
    END IF;
    
    -- Verteilungstyp anwenden
    IF distribution_type = 'hash' THEN
        IF colocation_group IS NOT NULL THEN
            EXECUTE format(
                'SELECT create_distributed_table(%L, %L, %L, colocate_with => %L)',
                full_table_name, distribution_column, 'hash', colocation_group
            );
        ELSE
            EXECUTE format(
                'SELECT create_distributed_table(%L, %L, %L, shard_count => %s)',
                full_table_name, distribution_column, 'hash', shard_count
            );
        END IF;
        
        RAISE NOTICE 'Tabelle % mit Hash-Verteilung auf Spalte % verteilt', 
                 full_table_name, distribution_column;
    
    ELSIF distribution_type = 'range' THEN
        -- Für Range-Verteilung müssen wir die Bereiche definieren
        EXECUTE format(
            'SELECT create_distributed_table(%L, %L, %L)',
            full_table_name, distribution_column, 'range'
        );
        
        RAISE NOTICE 'Tabelle % mit Range-Verteilung auf Spalte % verteilt', 
                 full_table_name, distribution_column;
    
    ELSIF distribution_type = 'append' THEN
        EXECUTE format(
            'SELECT create_distributed_table(%L, %L, %L)',
            full_table_name, distribution_column, 'append'
        );
        
        RAISE NOTICE 'Tabelle % mit Append-Verteilung auf Spalte % verteilt', 
                 full_table_name, distribution_column;
    
    ELSIF distribution_type = 'reference' THEN
        EXECUTE format('SELECT create_reference_table(%L)', full_table_name);
        RAISE NOTICE 'Tabelle % als Referenztabelle repliziert', full_table_name;
    
    ELSE
        RAISE EXCEPTION 'Unbekannter Verteilungstyp: %', distribution_type;
    END IF;
    
    -- Verteilungsstatistiken aktualisieren
    EXECUTE format('ANALYZE %s', full_table_name);
END;
$$ LANGUAGE plpgsql;

-- 2. Automatische Verteilung für alle Tabellen in einem Schema
CREATE OR REPLACE FUNCTION admin.distribute_schema(
    schema_name TEXT,
    exclude_tables TEXT[] DEFAULT '{}'
) RETURNS VOID AS $$
DECLARE
    tables_cursor CURSOR FOR
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = schema_name
          AND table_type = 'BASE TABLE'
          AND table_name NOT IN (SELECT unnest(exclude_tables));
    
    table_record RECORD;
    total_tables INT := 0;
    distributed_tables INT := 0;
BEGIN
    -- Prüfen, ob Schema existiert
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = schema_name) THEN
        RAISE EXCEPTION 'Schema % existiert nicht', schema_name;
        RETURN;
    END IF;
    
    -- Tabellen zählen
    SELECT COUNT(*) INTO total_tables
    FROM information_schema.tables
    WHERE table_schema = schema_name
      AND table_type = 'BASE TABLE'
      AND table_name NOT IN (SELECT unnest(exclude_tables));
    
    RAISE NOTICE 'Starte Verteilung von % Tabellen im Schema %', total_tables, schema_name;
    
    -- Jeden Tabelle optimal verteilen
    OPEN tables_cursor;
    LOOP
        FETCH tables_cursor INTO table_record;
        IF NOT FOUND THEN
            EXIT;
        END IF;
        
        BEGIN
            PERFORM admin.distribute_table_optimally(schema_name, table_record.table_name);
            distributed_tables := distributed_tables + 1;
            RAISE NOTICE '% von % Tabellen verteilt: %', 
                      distributed_tables, total_tables, table_record.table_name;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Fehler bei der Verteilung von %.%: %', 
                       schema_name, table_record.table_name, SQLERRM;
        END;
    END LOOP;
    CLOSE tables_cursor;
    
    RAISE NOTICE 'Verteilung abgeschlossen: % von % Tabellen erfolgreich verteilt', 
              distributed_tables, total_tables;
END;
$$ LANGUAGE plpgsql;

-- 3. Rebalancing der Daten auf Cluster-Knoten
CREATE OR REPLACE FUNCTION admin.rebalance_shards(
    schema_name TEXT DEFAULT 'public',
    min_threshold FLOAT DEFAULT 0.2,  -- 20% Ungleichgewicht aktiviert Rebalancing
    max_source_node_lag BIGINT DEFAULT 5 * 1024 * 1024  -- max 5MB Lag für Source-Node
) RETURNS VOID AS $$
DECLARE
    worker_stats RECORD;
    total_size BIGINT := 0;
    avg_size BIGINT;
    balanced BOOLEAN := TRUE;
    rebalance_needed BOOLEAN := FALSE;
    min_node_id INT;
    max_node_id INT;
    shard_to_move BIGINT;
    source_node_id INT;
    target_node_id INT;
BEGIN
    -- Prüfen, ob Citus installiert ist
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citus') THEN
        RAISE EXCEPTION 'Citus-Erweiterung ist nicht installiert.';
    END IF;
    
    -- Statistiken für Knoten und Shards sammeln
    CREATE TEMPORARY TABLE IF NOT EXISTS node_stats AS
    SELECT 
        nodeid,
        SUM(pg_total_relation_size(
            format('%I.%I', shardminvalue::text, shardmaxvalue::text)::regclass
        )) AS total_size
    FROM pg_dist_node n
    JOIN pg_dist_shard s ON true  -- Cross join
    JOIN pg_dist_shard_placement p ON s.shardid = p.shardid AND p.nodeid = n.nodeid
    JOIN pg_dist_partition t ON s.logicalrelid = t.logicalrelid
    WHERE t.partmethod = 'h'  -- Hash-verteilte Tabellen
    AND t.logicalrelid::text LIKE format('%I.%%', schema_name)
    GROUP BY nodeid;
    
    -- Gesamtgröße und Durchschnitt berechnen
    SELECT COALESCE(SUM(total_size), 0), COALESCE(AVG(total_size), 0)
    INTO total_size, avg_size
    FROM node_stats;
    
    IF total_size = 0 THEN
        RAISE NOTICE 'Keine verteilten Daten gefunden im Schema %', schema_name;
        DROP TABLE IF EXISTS node_stats;
        RETURN;
    END IF;
    
    -- Prüfen, ob Rebalancing nötig ist
    FOR worker_stats IN (SELECT * FROM node_stats) LOOP
        IF ABS(worker_stats.total_size - avg_size) > avg_size * min_threshold THEN
            balanced := FALSE;
            rebalance_needed := TRUE;
            EXIT;
        END IF;
    END LOOP;
    
    IF balanced THEN
        RAISE NOTICE 'Cluster ist bereits gut balanciert. Kein Rebalancing nötig.';
        DROP TABLE IF EXISTS node_stats;
        RETURN;
    END IF;
    
    -- Node mit höchster und niedrigster Last finden
    SELECT nodeid INTO max_node_id
    FROM node_stats
    ORDER BY total_size DESC
    LIMIT 1;
    
    SELECT nodeid INTO min_node_id
    FROM node_stats
    ORDER BY total_size ASC
    LIMIT 1;
    
    RAISE NOTICE 'Rebalancing nötig: Node % (überlastet) -> Node % (unterlastet)',
              max_node_id, min_node_id;
    
    -- Einen Shard zum Verschieben finden
    SELECT s.shardid INTO shard_to_move
    FROM pg_dist_shard s
    JOIN pg_dist_shard_placement p ON s.shardid = p.shardid
    JOIN pg_dist_partition t ON s.logicalrelid = t.logicalrelid
    WHERE p.nodeid = max_node_id
    AND t.partmethod = 'h'  -- Hash-verteilte Tabellen
    AND t.logicalrelid::text LIKE format('%I.%%', schema_name)
    -- Shards wählen, die nicht aktiv sind für bessere Performance
    AND NOT EXISTS (
        SELECT 1 FROM pg_stat_activity
        WHERE query ~* 'FROM\s+.*' || s.shardminvalue || '.* WHERE'
    )
    ORDER BY RANDOM()  -- Zufälligen Shard wählen
    LIMIT 1;
    
    IF shard_to_move IS NULL THEN
        RAISE NOTICE 'Kein geeigneter Shard zum Verschieben gefunden.';
        DROP TABLE IF EXISTS node_stats;
        RETURN;
    END IF;
    
    -- Rebalancing mit Citus-Funktion durchführen
    RAISE NOTICE 'Verschiebe Shard % von Node % zu Node %',
              shard_to_move, max_node_id, min_node_id;
              
    -- Falls Funktion in Citus existiert, diese nutzen
    BEGIN
        PERFORM master_move_shard_placement(
            shard_to_move,
            max_node_id::text,
            min_node_id::text,
            'block_writes'  -- Besser Performance als 'auto'
        );
        
        RAISE NOTICE 'Shard % erfolgreich verschoben', shard_to_move;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Fehler beim Verschieben des Shards: %', SQLERRM;
    END;
    
    DROP TABLE IF EXISTS node_stats;
END;
$$ LANGUAGE plpgsql;

-- 4. Optimierte Kolokatierungsstrategie für verwandte Tabellen
CREATE OR REPLACE FUNCTION admin.setup_table_colocation(
    schema_name TEXT,
    tables TEXT[],
    distribution_column TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    colocation_group TEXT;
    first_table TEXT;
    i INT;
BEGIN
    IF array_length(tables, 1) <= 1 THEN
        RAISE NOTICE 'Mindestens zwei Tabellen für Kolokation erforderlich.';
        RETURN;
    END IF;
    
    -- Verwende erste Tabelle als Basis für Kolokationsgruppe
    first_table := tables[1];
    
    -- Verteile erste Tabelle (falls noch nicht verteilt)
    BEGIN
        PERFORM admin.distribute_table_optimally(
            schema_name, 
            first_table,
            distribution_column
        );
        
        -- Abfragen der Kolokationsgruppe
        EXECUTE format('
            SELECT citus.get_table_colocation_id(%L)', 
            schema_name || '.' || first_table
        ) INTO colocation_group;
        
        IF colocation_group IS NULL THEN
            RAISE EXCEPTION 'Konnte Kolokationsgruppe für % nicht ermitteln', first_table;
            RETURN;
        END IF;
        
        RAISE NOTICE 'Kolokationsgruppe % für Basistabelle % ermittelt', 
                 colocation_group, first_table;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Fehler bei der Verteilung der Basistabelle: %', SQLERRM;
        RETURN;
    END;
    
    -- Verteile restliche Tabellen mit gleicher Kolokationsgruppe
    FOR i IN 2..array_length(tables, 1) LOOP
        BEGIN
            PERFORM admin.distribute_table_optimally(
                schema_name,
                tables[i],
                distribution_column,
                'hash',  -- Hash-Verteilung für Joins
                first_table  -- Als Kolokationsreferenz
            );
            
            RAISE NOTICE 'Tabelle % für Kolokation mit % konfiguriert', 
                     tables[i], first_table;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Fehler bei der Kolokation von %: %', tables[i], SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Kolokation für % Tabellen abgeschlossen', array_length(tables, 1);
END;
$$ LANGUAGE plpgsql;

-- 5. Funktion für Abfragen mit optimaler Parallelität auf verteilten Daten
CREATE OR REPLACE FUNCTION admin.execute_parallel_distributed(
    query TEXT,
    parallel_worker_count INT DEFAULT 8
) RETURNS VOID AS $$
DECLARE
    orig_workers INT;
BEGIN
    -- Aktuellen Wert speichern
    SHOW max_parallel_workers_per_gather INTO orig_workers;
    
    -- Optimierte Einstellungen für verteilte Abfragen
    SET LOCAL max_parallel_workers_per_gather = parallel_worker_count;
    SET LOCAL citus.all_modifications_commutative TO 'true';
    SET LOCAL citus.enable_repartition_joins TO 'true';
    SET LOCAL citus.enable_repartition_inserts TO 'true';
    SET LOCAL citus.max_adaptive_executor_pool_size = parallel_worker_count * 2;
    
    -- Abfrage ausführen
    RAISE NOTICE 'Führe verteilte Abfrage mit % Worker-Prozessen aus', parallel_worker_count;
    EXECUTE query;
END;
$$ LANGUAGE plpgsql;

-- Hinzufügen von Kommentaren zu den Funktionen
COMMENT ON FUNCTION admin.distribute_table_optimally IS 
'Verteilt eine Tabelle optimal auf Cluster-Knoten basierend auf Tabellenstatistiken.
Ermittelt automatisch die beste Verteilungsspalte und -strategie.
Beispiel: SELECT admin.distribute_table_optimally(''public'', ''sales'')';

COMMENT ON FUNCTION admin.distribute_schema IS
'Verteilt alle Tabellen in einem Schema automatisch.
Beispiel: SELECT admin.distribute_schema(''public'')';

COMMENT ON FUNCTION admin.rebalance_shards IS
'Balanciert Shards auf Cluster-Knoten für gleichmäßige Lastenverteilung.
Beispiel: SELECT admin.rebalance_shards()';

COMMENT ON FUNCTION admin.setup_table_colocation IS
'Konfiguriert Tabellen für Kolokation zur Optimierung von Joins.
Beispiel: SELECT admin.setup_table_colocation(''public'', ARRAY[''orders'', ''order_items''])';

COMMENT ON FUNCTION admin.execute_parallel_distributed IS
'Führt eine Abfrage mit optimaler Parallelität auf verteilten Daten aus.
Beispiel: SELECT admin.execute_parallel_distributed(''SELECT count(*) FROM orders'')';

-- Beispiel für die Verwendung
/*
-- Automatische optimale Verteilung einer Tabelle
SELECT admin.distribute_table_optimally('public', 'sales');

-- Automatische Verteilung aller Tabellen im Schema
SELECT admin.distribute_schema('analytics');

-- Tabellen für optimale Joins kolokieren
SELECT admin.setup_table_colocation(
    'public', 
    ARRAY['customers', 'orders', 'order_items']
);

-- Rebalancing nach Hinzufügen neuer Knoten
SELECT admin.rebalance_shards();

-- Abfrage mit optimaler Parallelität
SELECT admin.execute_parallel_distributed('
    SELECT 
        date_trunc(''month'', order_date) as month,
        SUM(order_amount) as total_sales
    FROM orders
    GROUP BY 1
    ORDER BY 1
');
*/ 