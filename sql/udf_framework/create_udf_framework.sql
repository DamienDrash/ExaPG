-- ExaPG - UDF-Framework
-- SQL-Skript zum Erstellen und Konfigurieren des UDF-Frameworks in PostgreSQL

-- Erstelle ein Schema für das UDF-Framework
CREATE SCHEMA IF NOT EXISTS udf_framework;

-- Aktiviere die notwendigen Erweiterungen für UDFs
DO $$
BEGIN
  -- Aktiviere plpython3u (Python 3 untrusted)
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plpython3u') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS plpython3u';
    RAISE NOTICE 'PL/Python3U wurde aktiviert';
  ELSE
    RAISE NOTICE 'PL/Python3U ist nicht verfügbar';
  END IF;
  
  -- Aktiviere plr (R)
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plr') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS plr';
    RAISE NOTICE 'PL/R wurde aktiviert';
  ELSE
    RAISE NOTICE 'PL/R ist nicht verfügbar';
  END IF;
  
  -- Aktiviere pllua (Lua)
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pllua') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS pllua';
    RAISE NOTICE 'PL/Lua wurde aktiviert';
  ELSE
    RAISE NOTICE 'PL/Lua ist nicht verfügbar';
  END IF;
  
  -- Statistik-Extension für Performance-Monitoring
  EXECUTE 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements';
END $$;

-- Erstelle Tabelle zur Verwaltung von UDFs
CREATE TABLE IF NOT EXISTS udf_framework.udf_catalog (
    udf_id SERIAL PRIMARY KEY,
    udf_name VARCHAR(100) NOT NULL UNIQUE,
    udf_schema VARCHAR(100) NOT NULL,
    udf_language VARCHAR(50) NOT NULL,
    udf_description TEXT,
    udf_source TEXT NOT NULL,
    udf_signature TEXT NOT NULL,
    udf_return_type TEXT NOT NULL,
    udf_owner VARCHAR(100) NOT NULL,
    udf_tags VARCHAR[],
    udf_created TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    udf_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle Tabelle für UDF-Ausführungsstatistiken
CREATE TABLE IF NOT EXISTS udf_framework.udf_execution_stats (
    execution_id SERIAL PRIMARY KEY,
    udf_id INTEGER REFERENCES udf_framework.udf_catalog(udf_id),
    execution_time INTERVAL,
    memory_usage BIGINT,
    rows_processed BIGINT,
    executed_by VARCHAR(100),
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN,
    error_message TEXT
);

-- Erstelle Tabelle für UDF-Parameter und -Beispiele
CREATE TABLE IF NOT EXISTS udf_framework.udf_examples (
    example_id SERIAL PRIMARY KEY,
    udf_id INTEGER REFERENCES udf_framework.udf_catalog(udf_id),
    example_name VARCHAR(100),
    example_description TEXT,
    example_parameters TEXT,
    example_result TEXT
);

-- Erstelle Funktion zum Registrieren einer UDF im Katalog
CREATE OR REPLACE FUNCTION udf_framework.register_udf(
    p_udf_name VARCHAR(100),
    p_udf_schema VARCHAR(100),
    p_udf_language VARCHAR(50),
    p_udf_description TEXT,
    p_udf_source TEXT,
    p_udf_signature TEXT,
    p_udf_return_type TEXT,
    p_udf_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_udf_id INTEGER;
BEGIN
    -- Prüfe, ob die UDF bereits im Katalog existiert
    SELECT udf_id INTO v_udf_id FROM udf_framework.udf_catalog 
    WHERE udf_name = p_udf_name AND udf_schema = p_udf_schema;
    
    IF v_udf_id IS NOT NULL THEN
        -- Aktualisiere die bestehende UDF
        UPDATE udf_framework.udf_catalog 
        SET udf_language = p_udf_language,
            udf_description = p_udf_description,
            udf_source = p_udf_source,
            udf_signature = p_udf_signature,
            udf_return_type = p_udf_return_type,
            udf_tags = p_udf_tags,
            udf_modified = CURRENT_TIMESTAMP,
            udf_owner = CURRENT_USER
        WHERE udf_id = v_udf_id;
    ELSE
        -- Füge eine neue UDF zum Katalog hinzu
        INSERT INTO udf_framework.udf_catalog (
            udf_name, 
            udf_schema, 
            udf_language, 
            udf_description, 
            udf_source, 
            udf_signature, 
            udf_return_type, 
            udf_owner, 
            udf_tags
        ) VALUES (
            p_udf_name,
            p_udf_schema,
            p_udf_language,
            p_udf_description,
            p_udf_source,
            p_udf_signature,
            p_udf_return_type,
            CURRENT_USER,
            p_udf_tags
        ) RETURNING udf_id INTO v_udf_id;
    END IF;
    
    RETURN v_udf_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Installieren einer UDF
CREATE OR REPLACE FUNCTION udf_framework.deploy_udf(
    p_udf_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_udf_record RECORD;
    v_sql TEXT;
BEGIN
    -- Hole UDF-Details aus dem Katalog
    SELECT * INTO v_udf_record FROM udf_framework.udf_catalog WHERE udf_id = p_udf_id;
    
    IF v_udf_record IS NULL THEN
        RAISE EXCEPTION 'UDF mit ID % wurde nicht gefunden', p_udf_id;
    END IF;
    
    -- Erstelle oder ersetze die Funktion
    v_sql := format(
        'CREATE OR REPLACE FUNCTION %I.%I(%s) RETURNS %s AS $UDF_BODY$
        %s
        $UDF_BODY$ LANGUAGE %s',
        v_udf_record.udf_schema,
        v_udf_record.udf_name,
        v_udf_record.udf_signature,
        v_udf_record.udf_return_type,
        v_udf_record.udf_source,
        v_udf_record.udf_language
    );
    
    -- Führe das SQL-Statement aus
    BEGIN
        EXECUTE v_sql;
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN
        -- Protokolliere den Fehler
        INSERT INTO udf_framework.udf_execution_stats (
            udf_id,
            execution_time,
            executed_by,
            success,
            error_message
        ) VALUES (
            p_udf_id,
            interval '0',
            CURRENT_USER,
            FALSE,
            SQLERRM
        );
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Hinzufügen eines UDF-Beispiels
CREATE OR REPLACE FUNCTION udf_framework.add_udf_example(
    p_udf_id INTEGER,
    p_example_name VARCHAR(100),
    p_example_description TEXT,
    p_example_parameters TEXT,
    p_example_result TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_example_id INTEGER;
BEGIN
    INSERT INTO udf_framework.udf_examples (
        udf_id,
        example_name,
        example_description,
        example_parameters,
        example_result
    ) VALUES (
        p_udf_id,
        p_example_name,
        p_example_description,
        p_example_parameters,
        p_example_result
    ) RETURNING example_id INTO v_example_id;
    
    RETURN v_example_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Löschen einer UDF
CREATE OR REPLACE FUNCTION udf_framework.drop_udf(
    p_udf_id INTEGER,
    p_cascade BOOLEAN DEFAULT FALSE
) RETURNS BOOLEAN AS $$
DECLARE
    v_udf_record RECORD;
    v_sql TEXT;
    v_cascade_option TEXT := '';
BEGIN
    -- Hole UDF-Details aus dem Katalog
    SELECT * INTO v_udf_record FROM udf_framework.udf_catalog WHERE udf_id = p_udf_id;
    
    IF v_udf_record IS NULL THEN
        RAISE EXCEPTION 'UDF mit ID % wurde nicht gefunden', p_udf_id;
    END IF;
    
    -- Setze CASCADE-Option, falls benötigt
    IF p_cascade THEN
        v_cascade_option := ' CASCADE';
    END IF;
    
    -- Lösche die Funktion
    v_sql := format(
        'DROP FUNCTION IF EXISTS %I.%I(%s)%s',
        v_udf_record.udf_schema,
        v_udf_record.udf_name,
        regexp_replace(v_udf_record.udf_signature, '^(.*?)\s.*$', '\1'), -- Extrahiere nur Datentypen für die DROP-Anweisung
        v_cascade_option
    );
    
    -- Führe das SQL-Statement aus
    BEGIN
        EXECUTE v_sql;
        
        -- Entferne die UDF aus dem Katalog
        DELETE FROM udf_framework.udf_catalog WHERE udf_id = p_udf_id;
        
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Views für UDF-Katalog-Übersicht
CREATE OR REPLACE VIEW udf_framework.udf_catalog_view AS
SELECT 
    c.udf_id,
    c.udf_schema || '.' || c.udf_name AS fully_qualified_name,
    c.udf_language,
    c.udf_description,
    c.udf_signature,
    c.udf_return_type,
    c.udf_owner,
    c.udf_tags,
    c.udf_created,
    c.udf_modified,
    COUNT(DISTINCT e.example_id) AS example_count,
    COUNT(DISTINCT s.execution_id) AS execution_count,
    AVG(s.execution_time) AS avg_execution_time
FROM 
    udf_framework.udf_catalog c
    LEFT JOIN udf_framework.udf_examples e ON c.udf_id = e.udf_id
    LEFT JOIN udf_framework.udf_execution_stats s ON c.udf_id = s.udf_id
GROUP BY 
    c.udf_id, c.udf_schema, c.udf_name;

-- Erstelle Trigger-Funktion zur Protokollierung von UDF-Ausführungen
CREATE OR REPLACE FUNCTION udf_framework.log_udf_execution() RETURNS event_trigger AS $$
DECLARE
    v_obj record;
    v_udf_id INTEGER;
    v_execution_time INTERVAL;
    v_rows_processed BIGINT;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    -- Dieser Trigger ist vereinfacht und muss in einer realen Umgebung erweitert werden
    -- In einer echten Implementierung würden wir pg_stat_statements oder andere Extensions verwenden
    -- um die tatsächlichen Ausführungsinformationen zu erhalten
    
    FOR v_obj IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
        IF v_obj.command_tag = 'SELECT' THEN
            -- Versuche, die UDF-ID zu ermitteln (vereinfacht)
            SELECT udf_id INTO v_udf_id 
            FROM udf_framework.udf_catalog
            WHERE format('%I.%I', udf_schema, udf_name) = v_obj.object_identity;
            
            IF v_udf_id IS NOT NULL THEN
                -- Protokolliere die Ausführung
                INSERT INTO udf_framework.udf_execution_stats (
                    udf_id,
                    execution_time,
                    executed_by,
                    success
                ) VALUES (
                    v_udf_id,
                    COALESCE(v_execution_time, interval '0'),
                    CURRENT_USER,
                    TRUE
                );
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Erstelle einen Event-Trigger für die UDF-Ausführungsprotokollierung
-- Hinweis: In einer realen Umgebung würde man präzisere Methoden verwenden
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'udf_execution_logger') THEN
        CREATE EVENT TRIGGER udf_execution_logger ON ddl_command_end
        EXECUTE FUNCTION udf_framework.log_udf_execution();
    END IF;
END $$; 