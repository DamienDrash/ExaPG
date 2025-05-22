-- ExaPG Parallelverarbeitungsfunktionen
-- Optimierte SQL-Funktionen für analytische Workloads mit maximaler Parallelität

-- Sicherstellen, dass Admin-Schema existiert
CREATE SCHEMA IF NOT EXISTS admin;

-- Parallele Aggregatfunktionen mit optimierter Verteilung
CREATE OR REPLACE FUNCTION admin.parallel_sum(
    schema_name text,
    table_name text, 
    column_name text,
    where_clause text DEFAULT NULL
) RETURNS numeric AS $$
DECLARE
    result numeric;
    query text;
    fully_qualified_name text := schema_name || '.' || table_name;
BEGIN
    -- Erstelle optimierte parallele Abfrage
    IF where_clause IS NULL THEN
        query := format('SELECT sum(%I) FROM %I.%I', 
                        column_name, schema_name, table_name);
    ELSE
        query := format('SELECT sum(%I) FROM %I.%I WHERE %s', 
                        column_name, schema_name, table_name, where_clause);
    END IF;
    
    -- Lokale Parallelitätsoptimierungen
    SET LOCAL max_parallel_workers_per_gather = 8;
    SET LOCAL parallel_tuple_cost = 0.01;
    SET LOCAL parallel_setup_cost = 10;
    
    -- Abfrage ausführen
    EXECUTE query INTO result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Parallele Analytik-Funktionen
CREATE OR REPLACE FUNCTION admin.parallel_analytics(
    query text,
    partition_column text DEFAULT NULL,
    partition_count int DEFAULT 8
) RETURNS SETOF record AS $$
DECLARE
    partitioned_queries text[];
    union_query text := '';
    i int;
    r record;
BEGIN
    -- Optimiere Parallelität für analytische Abfragen
    SET LOCAL max_parallel_workers_per_gather = 8;
    SET LOCAL work_mem = '1GB';
    
    -- Wenn kein Partitionswert angegeben, direkt ausführen
    IF partition_column IS NULL THEN
        -- Optimierte Parallelität für eine einzelne Abfrage
        SET LOCAL parallel_tuple_cost = 0.01;
        FOR r IN EXECUTE query
        LOOP
            RETURN NEXT r;
        END LOOP;
        RETURN;
    END IF;
    
    -- Partitioniere die Abfrage für manuelle Parallelität
    FOR i IN 0..partition_count-1 LOOP
        partitioned_queries[i] := 
            replace(
                query,
                'WHERE',
                format('WHERE (hashtext(%I) %% %s) = %s AND', 
                      partition_column, partition_count, i)
            );
        
        -- Setze keine WHERE-Klausel ein
        IF position('WHERE' IN partitioned_queries[i]) = 0 THEN
            partitioned_queries[i] := 
                replace(
                    query,
                    'FROM',
                    format('FROM WHERE (hashtext(%I) %% %s) = %s AND', 
                          partition_column, partition_count, i)
                );
        END IF;
        
        IF i > 0 THEN
            union_query := union_query || ' UNION ALL ';
        END IF;
        union_query := union_query || partitioned_queries[i];
    END LOOP;
    
    -- Ausführen mit Parallelität
    FOR r IN EXECUTE union_query
    LOOP
        RETURN NEXT r;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Optimierte parallele Window-Funktion
CREATE OR REPLACE FUNCTION admin.parallel_window_calc(
    table_schema text,
    table_name text,
    partition_column text,
    order_column text,
    window_function text,
    target_column text,
    where_clause text DEFAULT NULL
) RETURNS SETOF record AS $$
DECLARE
    query text;
    r record;
BEGIN
    -- Konstruiere Abfrage mit Window-Funktion
    IF where_clause IS NULL THEN
        query := format(
            'SELECT *, %s OVER (PARTITION BY %I ORDER BY %I) AS window_result
             FROM %I.%I',
            window_function || '(' || target_column || ')',
            partition_column,
            order_column,
            table_schema,
            table_name
        );
    ELSE
        query := format(
            'SELECT *, %s OVER (PARTITION BY %I ORDER BY %I) AS window_result
             FROM %I.%I
             WHERE %s',
            window_function || '(' || target_column || ')',
            partition_column,
            order_column,
            table_schema,
            table_name,
            where_clause
        );
    END IF;
    
    -- Maximale Parallelität
    SET LOCAL max_parallel_workers_per_gather = 8;
    SET LOCAL parallel_tuple_cost = 0.01;
    SET LOCAL work_mem = '1GB';
    
    -- Ausführen
    FOR r IN EXECUTE query
    LOOP
        RETURN NEXT r;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Optimierte parallele Partitionierung für analytische Tabellen
CREATE OR REPLACE FUNCTION admin.create_parallel_partitioned_table(
    source_schema text,
    source_table text,
    target_schema text,
    target_table text,
    partition_column text,
    partition_type text DEFAULT 'RANGE',
    partition_spec text DEFAULT NULL
) RETURNS void AS $$
DECLARE
    column_list text := '';
    create_stmt text;
    copy_stmt text;
BEGIN
    -- Spaltenliste generieren
    SELECT string_agg(column_name, ', ') INTO column_list
    FROM information_schema.columns
    WHERE table_schema = source_schema
    AND table_name = source_table;
    
    -- Zielschema erstellen, falls nicht vorhanden
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', target_schema);
    
    -- Partitionierte Tabelle erstellen
    create_stmt := format(
        'CREATE TABLE %I.%I (
            LIKE %I.%I
        ) PARTITION BY %s (%I)',
        target_schema, 
        target_table,
        source_schema,
        source_table,
        partition_type,
        partition_column
    );
    
    EXECUTE create_stmt;
    
    -- Partitionen definieren, falls angegeben
    IF partition_spec IS NOT NULL THEN
        EXECUTE partition_spec;
    END IF;
    
    -- Daten mit Parallelität kopieren
    copy_stmt := format(
        'INSERT INTO %I.%I SELECT * FROM %I.%I',
        target_schema,
        target_table,
        source_schema,
        source_table
    );
    
    -- Maximale Parallelität für den Kopiervorgang
    SET LOCAL max_parallel_workers_per_gather = 8;
    SET LOCAL maintenance_work_mem = '2GB';
    
    EXECUTE copy_stmt;
    
    RAISE NOTICE 'Partitionierte Tabelle %I.%I aus %I.%I erstellt',
                 target_schema, target_table, source_schema, source_table;
END;
$$ LANGUAGE plpgsql;

-- Beispiel für Verwendung:
COMMENT ON FUNCTION admin.parallel_sum IS 
'Parallele Summenberechnung mit optimierten Einstellungen.
Beispiel: SELECT admin.parallel_sum(''public'', ''customer'', ''amount'', ''region = ''EU'''')';

COMMENT ON FUNCTION admin.parallel_analytics IS
'Führt analytische Abfragen mit optimierter Parallelität aus.
Beispiel: SELECT * FROM admin.parallel_analytics(
    ''SELECT customer_id, sum(amount) FROM sales GROUP BY customer_id'', 
    ''customer_id'', 8) AS (customer_id int, total numeric)';

COMMENT ON FUNCTION admin.parallel_window_calc IS
'Wendet Window-Funktionen mit optimierter Parallelität an.
Beispiel: SELECT * FROM admin.parallel_window_calc(
    ''public'', ''sales'', ''region'', ''date'', ''sum'', ''amount'')
    AS (id int, region text, date date, amount numeric, window_result numeric)';

COMMENT ON FUNCTION admin.create_parallel_partitioned_table IS
'Erstellt eine partitionierte Tabelle mit optimierter Parallelität.
Beispiel: SELECT admin.create_parallel_partitioned_table(
    ''public'', ''sales'', ''analytics'', ''sales_partitioned'', ''date'', ''RANGE'',
    ''CREATE TABLE analytics.sales_y2023 PARTITION OF analytics.sales_partitioned 
     FOR VALUES FROM (''2023-01-01'') TO (''2024-01-01'')'')'; 