-- ExaPG - UDF-Framework Hilfsfunktionen
-- SQL-Skript mit Hilfsfunktionen für das UDF-Framework

-- Funktion zum vereinfachten Erstellen einer Python-UDF
CREATE OR REPLACE FUNCTION udf_framework.create_python_udf(
    p_schema_name VARCHAR(100),
    p_function_name VARCHAR(100),
    p_parameters TEXT,
    p_return_type TEXT,
    p_source TEXT,
    p_description TEXT DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
BEGIN
    -- Registriere die UDF im Katalog
    v_udf_id := udf_framework.register_udf(
        p_function_name, 
        p_schema_name, 
        'plpython3u', 
        p_description, 
        p_source, 
        p_parameters, 
        p_return_type, 
        p_tags
    );
    
    -- Deploye die UDF
    PERFORM udf_framework.deploy_udf(v_udf_id);
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum vereinfachten Erstellen einer R-UDF
CREATE OR REPLACE FUNCTION udf_framework.create_r_udf(
    p_schema_name VARCHAR(100),
    p_function_name VARCHAR(100),
    p_parameters TEXT,
    p_return_type TEXT,
    p_source TEXT,
    p_description TEXT DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
BEGIN
    -- Registriere die UDF im Katalog
    v_udf_id := udf_framework.register_udf(
        p_function_name, 
        p_schema_name, 
        'plr', 
        p_description, 
        p_source, 
        p_parameters, 
        p_return_type, 
        p_tags
    );
    
    -- Deploye die UDF
    PERFORM udf_framework.deploy_udf(v_udf_id);
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum vereinfachten Erstellen einer Lua-UDF
CREATE OR REPLACE FUNCTION udf_framework.create_lua_udf(
    p_schema_name VARCHAR(100),
    p_function_name VARCHAR(100),
    p_parameters TEXT,
    p_return_type TEXT,
    p_source TEXT,
    p_description TEXT DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
BEGIN
    -- Registriere die UDF im Katalog
    v_udf_id := udf_framework.register_udf(
        p_function_name, 
        p_schema_name, 
        'pllua', 
        p_description, 
        p_source, 
        p_parameters, 
        p_return_type, 
        p_tags
    );
    
    -- Deploye die UDF
    PERFORM udf_framework.deploy_udf(v_udf_id);
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum vereinfachten Erstellen einer SQL-UDF
CREATE OR REPLACE FUNCTION udf_framework.create_sql_udf(
    p_schema_name VARCHAR(100),
    p_function_name VARCHAR(100),
    p_parameters TEXT,
    p_return_type TEXT,
    p_source TEXT,
    p_description TEXT DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
BEGIN
    -- Registriere die UDF im Katalog
    v_udf_id := udf_framework.register_udf(
        p_function_name, 
        p_schema_name, 
        'sql', 
        p_description, 
        p_source, 
        p_parameters, 
        p_return_type, 
        p_tags
    );
    
    -- Deploye die UDF
    PERFORM udf_framework.deploy_udf(v_udf_id);
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Exportieren einer UDF im Exasol-kompatiblen Format
CREATE OR REPLACE FUNCTION udf_framework.export_udf_to_exasol(
    p_udf_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_udf_record RECORD;
    v_exasol_script TEXT;
    v_language TEXT;
BEGIN
    -- Hole UDF-Details aus dem Katalog
    SELECT * INTO v_udf_record FROM udf_framework.udf_catalog WHERE udf_id = p_udf_id;
    
    IF v_udf_record IS NULL THEN
        RAISE EXCEPTION 'UDF mit ID % wurde nicht gefunden', p_udf_id;
    END IF;
    
    -- Konvertiere PostgreSQL-Sprachname zu Exasol-Sprachname
    CASE v_udf_record.udf_language
        WHEN 'plpython3u' THEN v_language := 'PYTHON';
        WHEN 'plr' THEN v_language := 'R';
        WHEN 'pllua' THEN v_language := 'LUA';
        WHEN 'sql' THEN v_language := 'SQL';
        ELSE v_language := v_udf_record.udf_language;  -- Fallback
    END CASE;
    
    -- Erstelle Exasol-Script
    v_exasol_script := format(
        E'CREATE OR REPLACE %s SCRIPT %I.%I (%s) RETURNS %s AS\n%s\n/\n',
        v_language,
        v_udf_record.udf_schema,
        v_udf_record.udf_name,
        v_udf_record.udf_signature,
        v_udf_record.udf_return_type,
        v_udf_record.udf_source
    );
    
    RETURN v_exasol_script;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Importieren einer Exasol-UDF
CREATE OR REPLACE FUNCTION udf_framework.import_exasol_udf(
    p_exasol_script TEXT,
    p_schema_name VARCHAR(100) DEFAULT 'public'
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
    v_language TEXT;
    v_function_name TEXT;
    v_parameters TEXT;
    v_return_type TEXT;
    v_source TEXT;
    v_pg_language TEXT;
BEGIN
    -- Vereinfachter Parser für Exasol-Syntax (in einer realen Implementierung müsste dies komplexer sein)
    -- Extrahiere Sprache
    v_language := regexp_replace(p_exasol_script, E'^CREATE\\s+OR\\s+REPLACE\\s+(\\w+)\\s+SCRIPT.*$', E'\\1', 'i');
    
    -- Konvertiere Exasol-Sprachname zu PostgreSQL-Sprachname
    CASE upper(v_language)
        WHEN 'PYTHON' THEN v_pg_language := 'plpython3u';
        WHEN 'R' THEN v_pg_language := 'plr';
        WHEN 'LUA' THEN v_pg_language := 'pllua';
        WHEN 'SQL' THEN v_pg_language := 'sql';
        ELSE v_pg_language := 'sql';  -- Fallback
    END CASE;
    
    -- Extrahiere Funktionsname
    v_function_name := regexp_replace(p_exasol_script, E'^CREATE\\s+OR\\s+REPLACE\\s+\\w+\\s+SCRIPT\\s+\\w+\\.(\\w+)\\s+.*$', E'\\1', 'i');
    
    -- Extrahiere Parameter
    v_parameters := regexp_replace(p_exasol_script, E'^CREATE\\s+OR\\s+REPLACE\\s+\\w+\\s+SCRIPT\\s+\\w+\\.\\w+\\s*\\(([^)]*)\\)\\s+RETURNS.*$', E'\\1', 'i');
    
    -- Extrahiere Rückgabetyp
    v_return_type := regexp_replace(p_exasol_script, E'^CREATE\\s+OR\\s+REPLACE\\s+\\w+\\s+SCRIPT\\s+\\w+\\.\\w+\\s*\\([^)]*\\)\\s+RETURNS\\s+([^\\s]+)\\s+AS.*$', E'\\1', 'i');
    
    -- Extrahiere Quellcode
    v_source := regexp_replace(p_exasol_script, E'^CREATE\\s+OR\\s+REPLACE\\s+\\w+\\s+SCRIPT\\s+\\w+\\.\\w+\\s*\\([^)]*\\)\\s+RETURNS\\s+[^\\s]+\\s+AS\\s*\\n(.*)\\n/\\s*$', E'\\1', 'is');
    
    -- Anpasse Quellcode basierend auf der Sprache
    CASE v_pg_language
        WHEN 'plpython3u' THEN
            -- Konvertiere Exasol-Python-Syntax zu PostgreSQL-Python-Syntax
            v_source := regexp_replace(v_source, 'exa\\.', 'plpy.', 'g');
        WHEN 'plr' THEN
            -- Konvertiere Exasol-R-Syntax zu PostgreSQL-R-Syntax
            v_source := v_source;  -- Meist kompatibel
        WHEN 'pllua' THEN
            -- Konvertiere Exasol-Lua-Syntax zu PostgreSQL-Lua-Syntax
            v_source := regexp_replace(v_source, 'exasol\\.', 'pg.', 'g');
        ELSE
            -- SQL ist meist direkt kompatibel
            v_source := v_source;
    END CASE;
    
    -- Erstelle UDF basierend auf der Sprache
    CASE v_pg_language
        WHEN 'plpython3u' THEN
            v_udf_id := udf_framework.create_python_udf(
                p_schema_name,
                v_function_name,
                v_parameters,
                v_return_type,
                v_source,
                'Importiert von Exasol',
                ARRAY['exasol', 'imported']
            );
        WHEN 'plr' THEN
            v_udf_id := udf_framework.create_r_udf(
                p_schema_name,
                v_function_name,
                v_parameters,
                v_return_type,
                v_source,
                'Importiert von Exasol',
                ARRAY['exasol', 'imported']
            );
        WHEN 'pllua' THEN
            v_udf_id := udf_framework.create_lua_udf(
                p_schema_name,
                v_function_name,
                v_parameters,
                v_return_type,
                v_source,
                'Importiert von Exasol',
                ARRAY['exasol', 'imported']
            );
        ELSE
            v_udf_id := udf_framework.create_sql_udf(
                p_schema_name,
                v_function_name,
                v_parameters,
                v_return_type,
                v_source,
                'Importiert von Exasol',
                ARRAY['exasol', 'imported']
            );
    END CASE;
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zur Batch-Ausführung einer UDF über einen Datensatz
CREATE OR REPLACE FUNCTION udf_framework.batch_execute_udf(
    p_udf_id INTEGER,
    p_query TEXT,
    p_batch_size INTEGER DEFAULT 1000
) RETURNS TABLE (
    batch_number INTEGER,
    execution_time INTERVAL,
    rows_processed BIGINT,
    success BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    v_udf_record RECORD;
    v_batch_query TEXT;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_total_rows BIGINT;
    v_processed_rows BIGINT := 0;
    v_batch_number INTEGER := 0;
    v_success BOOLEAN;
    v_error_message TEXT;
    v_execution_time INTERVAL;
    v_cur refcursor;
BEGIN
    -- Hole UDF-Details aus dem Katalog
    SELECT * INTO v_udf_record FROM udf_framework.udf_catalog WHERE udf_id = p_udf_id;
    
    IF v_udf_record IS NULL THEN
        RAISE EXCEPTION 'UDF mit ID % wurde nicht gefunden', p_udf_id;
    END IF;
    
    -- Ermittle Gesamtzahl der Zeilen
    EXECUTE 'SELECT COUNT(*) FROM (' || p_query || ') AS subq' INTO v_total_rows;
    
    -- Verarbeite die Daten in Batches
    FOR i IN 0..CEIL(v_total_rows::float / p_batch_size)-1 LOOP
        v_batch_number := i + 1;
        
        -- Erstelle Batch-Abfrage
        v_batch_query := p_query || ' OFFSET ' || (i * p_batch_size) || ' LIMIT ' || p_batch_size;
        
        -- Führe UDF für jede Zeile im Batch aus
        BEGIN
            v_start_time := clock_timestamp();
            
            -- Öffne Cursor für die Batch-Query
            OPEN v_cur FOR EXECUTE v_batch_query;
            
            -- Verarbeite jede Zeile
            LOOP
                -- Hole nächste Zeile
                FETCH v_cur INTO v_udf_record;
                EXIT WHEN NOT FOUND;
                
                -- Hier wäre die eigentliche UDF-Ausführung für jede Zeile
                -- Dies ist eine vereinfachte Implementierung
                v_processed_rows := v_processed_rows + 1;
            END LOOP;
            
            -- Schließe Cursor
            CLOSE v_cur;
            
            v_end_time := clock_timestamp();
            v_execution_time := v_end_time - v_start_time;
            v_success := TRUE;
            v_error_message := NULL;
            
        EXCEPTION WHEN OTHERS THEN
            -- Fehlerbehandlung
            IF v_cur IS OPEN THEN
                CLOSE v_cur;
            END IF;
            
            v_end_time := clock_timestamp();
            v_execution_time := v_end_time - v_start_time;
            v_success := FALSE;
            v_error_message := SQLERRM;
        END;
        
        -- Protokolliere Batch-Ausführung
        INSERT INTO udf_framework.udf_execution_stats (
            udf_id,
            execution_time,
            rows_processed,
            executed_by,
            success,
            error_message
        ) VALUES (
            p_udf_id,
            v_execution_time,
            COALESCE(v_processed_rows, 0) - (v_batch_number - 1) * p_batch_size,
            CURRENT_USER,
            v_success,
            v_error_message
        );
        
        -- Gib Ergebnisse zurück
        batch_number := v_batch_number;
        execution_time := v_execution_time;
        rows_processed := COALESCE(v_processed_rows, 0) - (v_batch_number - 1) * p_batch_size;
        success := v_success;
        error_message := v_error_message;
        RETURN NEXT;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql; 