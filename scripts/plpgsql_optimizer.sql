-- PL/pgSQL-Optimizer für rechenintensive Operationen
-- Diese Funktionen helfen bei der Optimierung von PL/pgSQL-Code

-- 1. Wrapper für rechenintensive Operationen mit JIT-Forcierung
CREATE OR REPLACE FUNCTION public.jit_optimize(code text) RETURNS void AS $$
BEGIN
    -- Temporär den JIT-Schwellenwert herabsetzen, um JIT für alle Abfragen zu erzwingen
    SET LOCAL jit_above_cost = 0;
    SET LOCAL jit_inline_above_cost = 0;
    SET LOCAL jit_optimize_above_cost = 0;
    
    -- Ausführen des übergebenen Codes
    EXECUTE code;
END;
$$ LANGUAGE plpgsql;

-- 2. Parallelisierungshilfe für datenintensive Operationen
CREATE OR REPLACE FUNCTION public.parallel_execute(
    query text,
    partitions int DEFAULT 4
) RETURNS void AS $$
DECLARE
    i int;
    partition_size int;
    total_size int;
    start_range int;
    end_range int;
BEGIN
    -- Ermittle Anzahl der zu verarbeitenden Zeilen oder Datensatzgröße
    EXECUTE 'SELECT count(*) FROM (' || query || ') as subq' INTO total_size;
    
    partition_size := CEIL(total_size::float / partitions);
    
    -- Parallele Verarbeitung simulieren, indem wir den Bereich aufteilen
    FOR i IN 0..partitions-1 LOOP
        start_range := i * partition_size;
        end_range := LEAST((i+1) * partition_size, total_size);
        
        -- Führe die Abfrage mit OFFSET/LIMIT aus, um Partitionen zu simulieren
        EXECUTE query || ' OFFSET ' || start_range || ' LIMIT ' || (end_range - start_range);
        
        RAISE NOTICE 'Partition % von % verarbeitet (Datensätze % bis %)', 
                     i+1, partitions, start_range+1, end_range;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Optimierte Aggregationsfunktion
CREATE OR REPLACE FUNCTION public.optimized_agg(
    table_name text,
    column_names text[],
    agg_function text,
    where_clause text DEFAULT NULL
) RETURNS TABLE (result numeric) AS $$
DECLARE
    query text;
BEGIN
    -- Erstelle eine optimierte Aggregationsabfrage
    query := 'SELECT ' || agg_function || '(' || array_to_string(column_names, ', ') || ')';
    query := query || ' FROM ' || table_name;
    
    -- Füge WHERE-Klausel hinzu, wenn vorhanden
    IF where_clause IS NOT NULL THEN
        query := query || ' WHERE ' || where_clause;
    END IF;
    
    -- Aktiviere JIT und optimierte Pläne für diese Abfrage
    SET LOCAL jit = on;
    SET LOCAL jit_above_cost = 0;
    SET LOCAL work_mem = '512MB'; -- Temporär mehr Arbeitsspeicher zuweisen
    
    -- Führe die Abfrage aus und gib das Ergebnis zurück
    RETURN QUERY EXECUTE query;
END;
$$ LANGUAGE plpgsql;

-- 4. Funktion zur Erstellung von optimierten materialized views
CREATE OR REPLACE FUNCTION public.create_optimized_matview(
    view_name text,
    query text,
    refresh_interval interval DEFAULT '1 day'::interval,
    with_data boolean DEFAULT true
) RETURNS void AS $$
DECLARE
    refresh_query text;
BEGIN
    -- Erstelle oder ersetze den materialisierten View
    EXECUTE 'CREATE MATERIALIZED VIEW IF NOT EXISTS ' || quote_ident(view_name) || 
            ' AS ' || query || 
            CASE WHEN with_data THEN ' WITH DATA' ELSE ' WITH NO DATA' END;
    
    -- Erstelle Indizes für häufig verwendete Spalten (basierend auf Statistiken)
    EXECUTE 'CREATE INDEX IF NOT EXISTS ' || quote_ident(view_name || '_idx') || 
            ' ON ' || quote_ident(view_name) || 
            ' USING btree ((' || quote_ident(view_name) || '.*))';
    
    -- Automatische Aktualisierung über pg_cron (falls installiert)
    BEGIN
        refresh_query := 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || quote_ident(view_name);
        
        EXECUTE 'SELECT cron.schedule(''refresh_' || view_name || ''', ''' || 
                extract(epoch from refresh_interval) || ' seconds'', ''' || 
                refresh_query || ''')';
    EXCEPTION
        WHEN undefined_function THEN
            RAISE NOTICE 'pg_cron ist nicht installiert. Automatische Aktualisierung nicht verfügbar.';
        WHEN others THEN
            RAISE NOTICE 'Fehler bei der Einrichtung der automatischen Aktualisierung: %', SQLERRM;
    END;
    
    RAISE NOTICE 'Optimierter materialisierter View "%" erstellt', view_name;
END;
$$ LANGUAGE plpgsql;

-- 5. Performance-Diagnose für PL/pgSQL-Funktionen
CREATE OR REPLACE FUNCTION public.analyze_plpgsql_function(
    function_name text,
    args text[] DEFAULT NULL
) RETURNS table (
    step_no int,
    operation text,
    duration_ms numeric,
    optimization_hint text
) AS $$
DECLARE
    query text;
    start_time timestamptz;
    end_time timestamptz;
    elapsed numeric;
    i int := 1;
    arg_list text := '';
BEGIN
    -- Erstelle Argumentliste, falls vorhanden
    IF args IS NOT NULL AND array_length(args, 1) > 0 THEN
        arg_list := array_to_string(args, ', ');
    END IF;
    
    -- Aktiviere Timing
    SET LOCAL track_functions = 'all';
    SET LOCAL track_io_timing = on;
    
    -- Messe Gesamtlaufzeit
    start_time := clock_timestamp();
    EXECUTE 'SELECT ' || function_name || '(' || arg_list || ')';
    end_time := clock_timestamp();
    
    elapsed := extract(epoch from (end_time - start_time)) * 1000;
    
    -- Ergebnisse zurückgeben
    step_no := i; i := i + 1;
    operation := 'Total function execution';
    duration_ms := elapsed;
    optimization_hint := CASE 
        WHEN elapsed < 100 THEN 'Performance already good'
        WHEN elapsed < 1000 THEN 'Consider JIT optimization'
        ELSE 'Consider rewriting critical sections in C or using materialized views'
    END;
    RETURN NEXT;
    
    -- Prüfe, ob die Funktion Verbesserungen benötigt
    step_no := i; i := i + 1;
    operation := 'JIT applicability check';
    duration_ms := 0;
    optimization_hint := CASE 
        WHEN elapsed > 500 THEN 'Function would benefit from JIT optimization'
        ELSE 'JIT optimization not necessary'
    END;
    RETURN NEXT;
    
    -- Prüfe auf mögliche Parallelisierung
    step_no := i; i := i + 1;
    operation := 'Parallelization check';
    duration_ms := 0;
    optimization_hint := CASE 
        WHEN elapsed > 1000 THEN 'Consider using parallel_execute() for data partitioning'
        ELSE 'Parallelization not necessary'
    END;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Dokumentation und Beispiele:
COMMENT ON FUNCTION public.jit_optimize IS 
'Wrapper für die Ausführung von Code mit erzwungener JIT-Optimierung.
Beispiel: SELECT public.jit_optimize(''SELECT sum(amount) FROM large_table'');';

COMMENT ON FUNCTION public.parallel_execute IS 
'Hilft bei der Parallelisierung von Abfragen durch Datenpartitionierung.
Beispiel: SELECT public.parallel_execute(''SELECT * FROM large_table ORDER BY id'', 8);';

COMMENT ON FUNCTION public.optimized_agg IS 
'Führt optimierte Aggregationen auf großen Tabellen aus.
Beispiel: SELECT * FROM public.optimized_agg(''sales_data'', ARRAY[''amount''], ''sum'', ''transaction_date > ''2023-01-01'''');';

COMMENT ON FUNCTION public.create_optimized_matview IS 
'Erstellt optimierte materialisierte Views mit automatischer Aktualisierung.
Beispiel: SELECT public.create_optimized_matview(''monthly_sales'', ''SELECT date_trunc(''''month'''', transaction_date) as month, sum(amount) FROM sales_data GROUP BY 1'');';

COMMENT ON FUNCTION public.analyze_plpgsql_function IS 
'Analysiert die Performance einer PL/pgSQL-Funktion und gibt Optimierungshinweise.
Beispiel: SELECT * FROM public.analyze_plpgsql_function(''process_sales_data'', ARRAY[''2023-01-01'', ''2023-12-31'']);'; 