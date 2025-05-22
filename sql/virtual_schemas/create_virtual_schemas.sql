-- ExaPG - Virtual Schemas Einrichtung
-- SQL-Skript zum Erstellen und Konfigurieren von Virtual Schemas in PostgreSQL

-- Erstelle ein Schema für die Virtual Schemas Meta-Daten
CREATE SCHEMA IF NOT EXISTS vs_metadata;

-- Erstelle Tabelle zur Verwaltung der Virtual Schema Konfigurationen
CREATE TABLE IF NOT EXISTS vs_metadata.schemas (
    schema_id SERIAL PRIMARY KEY,
    schema_name VARCHAR(100) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL,
    connection_string TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    enabled BOOLEAN DEFAULT TRUE,
    pushdown_enabled BOOLEAN DEFAULT TRUE,
    refresh_interval INT DEFAULT 3600,    -- Aktualisierungsintervall in Sekunden
    options JSONB DEFAULT '{}'::JSONB     -- Zusätzliche Optionen je nach Datenquellentyp
);

-- Erstelle Tabelle zur Verwaltung der Virtual Schema Tabellen
CREATE TABLE IF NOT EXISTS vs_metadata.tables (
    table_id SERIAL PRIMARY KEY,
    schema_id INT REFERENCES vs_metadata.schemas(schema_id) ON DELETE CASCADE,
    table_name VARCHAR(100) NOT NULL,
    remote_table_name VARCHAR(100) NOT NULL,
    column_mapping JSONB DEFAULT '{}'::JSONB,
    filter_condition TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    enabled BOOLEAN DEFAULT TRUE,
    UNIQUE(schema_id, table_name)
);

-- Erstelle Tabelle zur Protokollierung der Zugriffe auf Virtual Schemas
CREATE TABLE IF NOT EXISTS vs_metadata.access_log (
    log_id SERIAL PRIMARY KEY,
    schema_name VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    query_text TEXT,
    execution_time INTERVAL,
    rows_returned BIGINT,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_name VARCHAR(100) NOT NULL,
    client_ip VARCHAR(40),
    pushdown_applied BOOLEAN
);

-- Erstelle Tabelle für die Tabellen-Statistiken zur Optimierung der Abfragepläne
CREATE TABLE IF NOT EXISTS vs_metadata.table_stats (
    stats_id SERIAL PRIMARY KEY,
    schema_id INT REFERENCES vs_metadata.schemas(schema_id) ON DELETE CASCADE,
    table_name VARCHAR(100) NOT NULL,
    row_count BIGINT,
    avg_row_size INT,
    column_stats JSONB,
    last_refreshed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(schema_id, table_name)
);

-- Erstelle Funktionen zur Verwaltung von Virtual Schemas

-- Funktion zum Erstellen eines neuen Virtual Schemas
CREATE OR REPLACE FUNCTION vs_metadata.create_virtual_schema(
    p_schema_name VARCHAR(100),
    p_source_type VARCHAR(50),
    p_connection_string TEXT,
    p_options JSONB DEFAULT '{}'::JSONB
) RETURNS INT AS $$
DECLARE
    v_schema_id INT;
BEGIN
    -- Prüfe, ob das Schema bereits existiert
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = p_schema_name) THEN
        -- Erstelle das Schema
        EXECUTE 'CREATE SCHEMA ' || quote_ident(p_schema_name);
    END IF;
    
    -- Füge Schema-Metadaten hinzu
    INSERT INTO vs_metadata.schemas (schema_name, source_type, connection_string, options)
    VALUES (p_schema_name, p_source_type, p_connection_string, p_options)
    RETURNING schema_id INTO v_schema_id;
    
    RETURN v_schema_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Hinzufügen einer Tabelle zu einem Virtual Schema
CREATE OR REPLACE FUNCTION vs_metadata.add_virtual_table(
    p_schema_name VARCHAR(100),
    p_table_name VARCHAR(100),
    p_remote_table_name VARCHAR(100),
    p_column_mapping JSONB DEFAULT '{}'::JSONB,
    p_filter_condition TEXT DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    v_schema_id INT;
    v_table_id INT;
    v_source_type VARCHAR(50);
    v_connection_string TEXT;
    v_options JSONB;
    v_server_name TEXT;
    v_fdw_name TEXT;
    v_sql TEXT;
BEGIN
    -- Suche Schema-ID
    SELECT schema_id, source_type, connection_string, options
    INTO v_schema_id, v_source_type, v_connection_string, v_options
    FROM vs_metadata.schemas
    WHERE schema_name = p_schema_name;
    
    IF v_schema_id IS NULL THEN
        RAISE EXCEPTION 'Virtual Schema "%" nicht gefunden', p_schema_name;
    END IF;
    
    -- Bestimme den Server-Namen basierend auf Schema und Quelle
    v_server_name := p_schema_name || '_' || v_source_type || '_server';
    
    -- Bestimme den FDW-Namen basierend auf dem Quellentyp
    CASE v_source_type
        WHEN 'postgres' THEN v_fdw_name := 'postgres_fdw';
        WHEN 'mysql' THEN v_fdw_name := 'mysql_fdw';
        WHEN 'mssql' THEN v_fdw_name := 'tds_fdw';
        WHEN 'mongodb' THEN v_fdw_name := 'mongo_fdw';
        WHEN 'redis' THEN v_fdw_name := 'redis_fdw';
        WHEN 'sqlite' THEN v_fdw_name := 'sqlite_fdw';
        WHEN 'oracle' THEN v_fdw_name := 'jdbc_fdw'; -- Oracle über JDBC
        WHEN 'file' THEN v_fdw_name := 'file_fdw';
        WHEN 'elastic' THEN v_fdw_name := 'elastic_fdw';
        ELSE RAISE EXCEPTION 'Nicht unterstützter Quellentyp: %', v_source_type;
    END CASE;
    
    -- Erstelle Fremdtabelle basierend auf dem Quellentyp
    CASE v_source_type
        WHEN 'postgres' THEN
            -- Erstelle Foreign Table für PostgreSQL
            EXECUTE format(
                'CREATE FOREIGN TABLE %I.%I (%s) SERVER %I OPTIONS (schema_name %L, table_name %L)',
                p_schema_name,
                p_table_name,
                vs_metadata.get_column_definitions(v_schema_id, p_column_mapping, v_source_type, v_connection_string, p_remote_table_name),
                v_server_name,
                split_part(p_remote_table_name, '.', 1),
                split_part(p_remote_table_name, '.', 2)
            );
        
        WHEN 'mysql' THEN
            -- Erstelle Foreign Table für MySQL
            EXECUTE format(
                'CREATE FOREIGN TABLE %I.%I (%s) SERVER %I OPTIONS (dbname %L, table_name %L)',
                p_schema_name,
                p_table_name,
                vs_metadata.get_column_definitions(v_schema_id, p_column_mapping, v_source_type, v_connection_string, p_remote_table_name),
                v_server_name,
                v_options->>'dbname',
                p_remote_table_name
            );
            
        WHEN 'mssql' THEN
            -- Erstelle Foreign Table für SQL Server
            EXECUTE format(
                'CREATE FOREIGN TABLE %I.%I (%s) SERVER %I OPTIONS (database %L, schema_name %L, table_name %L)',
                p_schema_name,
                p_table_name,
                vs_metadata.get_column_definitions(v_schema_id, p_column_mapping, v_source_type, v_connection_string, p_remote_table_name),
                v_server_name,
                v_options->>'database',
                split_part(p_remote_table_name, '.', 1),
                split_part(p_remote_table_name, '.', 2)
            );
            
        WHEN 'mongodb' THEN
            -- Erstelle Foreign Table für MongoDB
            EXECUTE format(
                'CREATE FOREIGN TABLE %I.%I (%s) SERVER %I OPTIONS (database %L, collection %L)',
                p_schema_name,
                p_table_name,
                vs_metadata.get_column_definitions(v_schema_id, p_column_mapping, v_source_type, v_connection_string, p_remote_table_name),
                v_server_name,
                v_options->>'database',
                p_remote_table_name
            );
            
        WHEN 'redis' THEN
            -- Erstelle Foreign Table für Redis
            EXECUTE format(
                'CREATE FOREIGN TABLE %I.%I (key TEXT, value TEXT) SERVER %I OPTIONS (database %L, key_pattern %L)',
                p_schema_name,
                p_table_name,
                v_server_name,
                COALESCE(v_options->>'database', '0'),
                p_remote_table_name || ':*'
            );
            
        -- Füge weitere Quellentypen nach Bedarf hinzu
        
        ELSE
            RAISE EXCEPTION 'Nicht implementierter Quellentyp: %', v_source_type;
    END CASE;
    
    -- Füge Tabellen-Metadaten hinzu
    INSERT INTO vs_metadata.tables (schema_id, table_name, remote_table_name, column_mapping, filter_condition)
    VALUES (v_schema_id, p_table_name, p_remote_table_name, p_column_mapping, p_filter_condition)
    RETURNING table_id INTO v_table_id;
    
    -- Falls ein Filter existiert, erstelle eine View mit dem Filter
    IF p_filter_condition IS NOT NULL AND p_filter_condition != '' THEN
        EXECUTE format(
            'CREATE OR REPLACE VIEW %I.%I_filtered AS SELECT * FROM %I.%I WHERE %s',
            p_schema_name,
            p_table_name,
            p_schema_name,
            p_table_name,
            p_filter_condition
        );
    END IF;
    
    RETURN v_table_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Einrichten eines Foreign Data Wrapper Servers
CREATE OR REPLACE FUNCTION vs_metadata.setup_fdw_server(
    p_schema_name VARCHAR(100),
    p_source_type VARCHAR(50),
    p_connection_string TEXT,
    p_options JSONB DEFAULT '{}'::JSONB
) RETURNS TEXT AS $$
DECLARE
    v_server_name TEXT;
    v_fdw_extension TEXT;
    v_server_options TEXT := '';
BEGIN
    -- Bestimme den Server-Namen
    v_server_name := p_schema_name || '_' || p_source_type || '_server';
    
    -- Bestimme die zu aktivierende Erweiterung basierend auf dem Quellentyp
    CASE p_source_type
        WHEN 'postgres' THEN 
            v_fdw_extension := 'postgres_fdw';
            
            -- Analysiere Connection-String für PostgreSQL
            v_server_options := format(
                'host %L, port %L, dbname %L',
                COALESCE(p_options->>'host', split_part(split_part(p_connection_string, '@', 2), ':', 1)),
                COALESCE(p_options->>'port', split_part(split_part(p_connection_string, ':', 3), '/', 1)),
                COALESCE(p_options->>'dbname', split_part(split_part(p_connection_string, '/', 2), '?', 1))
            );
            
        WHEN 'mysql' THEN 
            v_fdw_extension := 'mysql_fdw';
            
            -- Server-Optionen für MySQL
            v_server_options := format(
                'host %L, port %L',
                COALESCE(p_options->>'host', split_part(p_connection_string, ':', 1)),
                COALESCE(p_options->>'port', '3306')
            );
            
        WHEN 'mssql' THEN 
            v_fdw_extension := 'tds_fdw';
            
            -- Server-Optionen für SQL Server
            v_server_options := format(
                'servername %L, port %L, tds_version %L',
                COALESCE(p_options->>'host', split_part(p_connection_string, ':', 1)),
                COALESCE(p_options->>'port', '1433'),
                COALESCE(p_options->>'tds_version', '7.4')
            );
            
        WHEN 'mongodb' THEN 
            v_fdw_extension := 'mongo_fdw';
            
            -- Server-Optionen für MongoDB
            v_server_options := format(
                'host %L, port %L',
                COALESCE(p_options->>'host', split_part(p_connection_string, ':', 1)),
                COALESCE(p_options->>'port', '27017')
            );
            
        WHEN 'redis' THEN 
            v_fdw_extension := 'redis_fdw';
            
            -- Server-Optionen für Redis
            v_server_options := format(
                'host %L, port %L',
                COALESCE(p_options->>'host', split_part(p_connection_string, ':', 1)),
                COALESCE(p_options->>'port', '6379')
            );
            
        WHEN 'sqlite' THEN 
            v_fdw_extension := 'sqlite_fdw';
            
            -- Server-Optionen für SQLite
            v_server_options := format('database %L', p_connection_string);
            
        -- Weitere Datenquellen nach Bedarf hinzufügen
            
        ELSE
            RAISE EXCEPTION 'Nicht unterstützter Quellentyp: %', p_source_type;
    END CASE;
    
    -- Aktiviere die Erweiterung, falls sie noch nicht aktiv ist
    EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I', v_fdw_extension);
    
    -- Prüfe, ob der Server bereits existiert
    IF EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = v_server_name) THEN
        -- Server existiert bereits, aktualisiere die Optionen
        EXECUTE format('ALTER SERVER %I OPTIONS (SET %s)', v_server_name, v_server_options);
    ELSE
        -- Erstelle neuen Server
        EXECUTE format('CREATE SERVER %I FOREIGN DATA WRAPPER %I OPTIONS (%s)', 
                      v_server_name, v_fdw_extension, v_server_options);
    END IF;
    
    -- Erstelle User Mapping basierend auf dem Quellentyp
    CASE p_source_type
        WHEN 'postgres' THEN
            EXECUTE format(
                'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS (user %L, password %L)',
                v_server_name,
                COALESCE(p_options->>'user', split_part(split_part(p_connection_string, '//', 2), ':', 1)),
                COALESCE(p_options->>'password', split_part(split_part(p_connection_string, ':', 2), '@', 1))
            );
            
        WHEN 'mysql' THEN
            EXECUTE format(
                'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS (username %L, password %L)',
                v_server_name,
                COALESCE(p_options->>'user', split_part(split_part(p_connection_string, '@', 1), ':', 1)),
                COALESCE(p_options->>'password', split_part(split_part(p_connection_string, ':', 2), '@', 1))
            );
            
        WHEN 'mssql' THEN
            EXECUTE format(
                'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS (username %L, password %L)',
                v_server_name,
                COALESCE(p_options->>'user', 'sa'),
                COALESCE(p_options->>'password', '')
            );
            
        WHEN 'mongodb' THEN
            EXECUTE format(
                'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS (username %L, password %L)',
                v_server_name,
                COALESCE(p_options->>'user', ''),
                COALESCE(p_options->>'password', '')
            );
            
        WHEN 'redis' THEN
            IF p_options->>'password' IS NOT NULL THEN
                EXECUTE format(
                    'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS (password %L)',
                    v_server_name,
                    p_options->>'password'
                );
            ELSE
                EXECUTE format(
                    'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS ()',
                    v_server_name
                );
            END IF;
            
        WHEN 'sqlite' THEN
            -- SQLite hat keine Authentifizierung
            EXECUTE format(
                'CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER %I OPTIONS ()',
                v_server_name
            );
            
        -- Weitere Quellentypen nach Bedarf
            
        ELSE
            RAISE EXCEPTION 'Nicht unterstützter Quellentyp für User Mapping: %', p_source_type;
    END CASE;
    
    RETURN v_server_name;
END;
$$ LANGUAGE plpgsql;

-- Erstelle eine Funktion zum Importieren aller Tabellen aus einer externen Datenquelle
CREATE OR REPLACE FUNCTION vs_metadata.import_all_tables(
    p_schema_name VARCHAR(100)
) RETURNS INTEGER AS $$
DECLARE
    v_source_type VARCHAR(50);
    v_connection_string TEXT;
    v_options JSONB;
    v_schema_id INT;
    v_server_name TEXT;
    v_remote_schema TEXT;
    v_table_record RECORD;
    v_imported_count INT := 0;
    v_sql TEXT;
BEGIN
    -- Hole Schema-Informationen
    SELECT schema_id, source_type, connection_string, options
    INTO v_schema_id, v_source_type, v_connection_string, v_options
    FROM vs_metadata.schemas
    WHERE schema_name = p_schema_name;
    
    IF v_schema_id IS NULL THEN
        RAISE EXCEPTION 'Virtual Schema "%" nicht gefunden', p_schema_name;
    END IF;
    
    -- Server-Name basierend auf Schema
    v_server_name := p_schema_name || '_' || v_source_type || '_server';
    
    -- Importiere Tabellen basierend auf dem Quellentyp
    CASE v_source_type
        WHEN 'postgres' THEN
            -- Bestimme Remote-Schema (standardmäßig 'public', falls nicht angegeben)
            v_remote_schema := COALESCE(v_options->>'schema', 'public');
            
            -- PostgreSQL: Hole alle Tabellen aus dem Information Schema
            FOR v_table_record IN 
                EXECUTE format(
                    'SELECT table_name FROM information_schema.tables 
                     WHERE table_schema = %L 
                       AND table_type = ''BASE TABLE''
                       AND table_name NOT LIKE ''pg_%%''', 
                    v_remote_schema
                )
            LOOP
                -- Importiere jede Tabelle
                PERFORM vs_metadata.add_virtual_table(
                    p_schema_name,
                    v_table_record.table_name,
                    v_remote_schema || '.' || v_table_record.table_name
                );
                v_imported_count := v_imported_count + 1;
            END LOOP;
            
        WHEN 'mysql' THEN
            -- MySQL: Hole alle Tabellen
            v_sql := format(
                'SELECT table_name FROM information_schema.tables 
                 WHERE table_schema = %L 
                   AND table_type = ''BASE TABLE''',
                v_options->>'dbname'
            );
            
            FOR v_table_record IN 
                EXECUTE v_sql
            LOOP
                -- Importiere jede Tabelle
                PERFORM vs_metadata.add_virtual_table(
                    p_schema_name,
                    v_table_record.table_name,
                    v_table_record.table_name
                );
                v_imported_count := v_imported_count + 1;
            END LOOP;
            
        WHEN 'mssql' THEN
            -- SQL Server: Hole alle Tabellen
            v_remote_schema := COALESCE(v_options->>'schema', 'dbo');
            
            v_sql := format(
                'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
                 WHERE TABLE_SCHEMA = %L 
                   AND TABLE_TYPE = ''BASE TABLE''',
                v_remote_schema
            );
            
            FOR v_table_record IN 
                EXECUTE v_sql
            LOOP
                -- Importiere jede Tabelle
                PERFORM vs_metadata.add_virtual_table(
                    p_schema_name,
                    v_table_record.table_name,
                    v_remote_schema || '.' || v_table_record.table_name
                );
                v_imported_count := v_imported_count + 1;
            END LOOP;
            
        -- Weitere Quellentypen können hier implementiert werden
        
        ELSE
            RAISE EXCEPTION 'Automatischer Import für Quellentyp % nicht implementiert', v_source_type;
    END CASE;
    
    RETURN v_imported_count;
END;
$$ LANGUAGE plpgsql;

-- Erstelle eine Prozedur zum Aktualisieren der Statistiken für bessere Abfragepläne
CREATE OR REPLACE PROCEDURE vs_metadata.refresh_table_stats(
    p_schema_name VARCHAR(100),
    p_table_name VARCHAR(100) DEFAULT NULL
) AS $$
DECLARE
    v_schema_id INT;
    v_table_record RECORD;
    v_stats_sql TEXT;
    v_row_count BIGINT;
    v_avg_row_size INT;
    v_column_stats JSONB;
BEGIN
    -- Hole Schema-ID
    SELECT schema_id
    INTO v_schema_id
    FROM vs_metadata.schemas
    WHERE schema_name = p_schema_name;
    
    IF v_schema_id IS NULL THEN
        RAISE EXCEPTION 'Virtual Schema "%" nicht gefunden', p_schema_name;
    END IF;
    
    -- Wenn keine spezifische Tabelle angegeben wurde, aktualisiere alle Tabellen im Schema
    IF p_table_name IS NULL THEN
        FOR v_table_record IN 
            SELECT table_name 
            FROM vs_metadata.tables 
            WHERE schema_id = v_schema_id AND enabled = TRUE
        LOOP
            CALL vs_metadata.refresh_table_stats(p_schema_name, v_table_record.table_name);
        END LOOP;
    ELSE
        -- Sammle Statistiken für die Tabelle
        EXECUTE format('ANALYZE %I.%I', p_schema_name, p_table_name);
        
        -- Berechne Anzahl der Zeilen
        EXECUTE format('SELECT COUNT(*) FROM %I.%I', p_schema_name, p_table_name) INTO v_row_count;
        
        -- Berechne durchschnittliche Zeilengröße und Spaltenstatistiken (vereinfacht)
        EXECUTE format(
            'SELECT pg_total_relation_size(%L) / NULLIF(%s, 0) AS avg_row_size,
                    jsonb_object_agg(attname, jsonb_build_object(
                        ''null_frac'', null_frac,
                        ''n_distinct'', n_distinct,
                        ''most_common_vals'', most_common_vals::text,
                        ''most_common_freqs'', most_common_freqs::text
                    )) AS column_stats
             FROM pg_stats
             WHERE schemaname = %L AND tablename = %L
             GROUP BY 1',
            p_schema_name || '.' || p_table_name,
            v_row_count,
            p_schema_name,
            p_table_name
        ) INTO v_avg_row_size, v_column_stats;
        
        -- Speichere Statistiken in der Metadaten-Tabelle
        INSERT INTO vs_metadata.table_stats (schema_id, table_name, row_count, avg_row_size, column_stats, last_refreshed)
        VALUES (v_schema_id, p_table_name, v_row_count, v_avg_row_size, v_column_stats, CURRENT_TIMESTAMP)
        ON CONFLICT (schema_id, table_name) 
        DO UPDATE SET 
            row_count = EXCLUDED.row_count,
            avg_row_size = EXCLUDED.avg_row_size,
            column_stats = EXCLUDED.column_stats,
            last_refreshed = CURRENT_TIMESTAMP;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Erstelle eine Funktion zum Löschen eines Virtual Schemas
CREATE OR REPLACE FUNCTION vs_metadata.drop_virtual_schema(
    p_schema_name VARCHAR(100),
    p_cascade BOOLEAN DEFAULT FALSE
) RETURNS BOOLEAN AS $$
DECLARE
    v_schema_id INT;
    v_server_name TEXT;
    v_source_type VARCHAR(50);
    v_cascade_option TEXT := '';
BEGIN
    -- Hole Schema-ID und Quellentyp
    SELECT schema_id, source_type
    INTO v_schema_id, v_source_type
    FROM vs_metadata.schemas
    WHERE schema_name = p_schema_name;
    
    IF v_schema_id IS NULL THEN
        RAISE EXCEPTION 'Virtual Schema "%" nicht gefunden', p_schema_name;
    END IF;
    
    -- Server-Name basierend auf Schema
    v_server_name := p_schema_name || '_' || v_source_type || '_server';
    
    -- CASCADE Option falls erforderlich
    IF p_cascade THEN
        v_cascade_option := ' CASCADE';
    END IF;
    
    -- Schema und alle enthaltenen Objekte löschen
    EXECUTE format('DROP SCHEMA IF EXISTS %I%s', p_schema_name, v_cascade_option);
    
    -- User Mapping löschen
    EXECUTE format('DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER %I', v_server_name);
    
    -- Server löschen
    EXECUTE format('DROP SERVER IF EXISTS %I%s', v_server_name, v_cascade_option);
    
    -- Metadaten löschen (cascaded durch Fremdschlüssel)
    DELETE FROM vs_metadata.schemas WHERE schema_id = v_schema_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Schließlich erstellen wir eine Aggregatfunktion für die Protokollierung von Virtual Schema Zugriffen
CREATE OR REPLACE FUNCTION vs_metadata.log_schema_access() RETURNS event_trigger AS $$
DECLARE
    v_obj record;
    v_schema_name text;
    v_table_name text;
    v_query_text text;
    v_start_time timestamptz;
    v_execution_time interval;
    v_rows_returned bigint;
BEGIN
    SELECT query, query_start INTO v_query_text, v_start_time 
    FROM pg_stat_activity 
    WHERE pid = pg_backend_pid();
    
    v_execution_time := clock_timestamp() - v_start_time;
    
    -- Extrahiere Schema- und Tabellennamen (vereinfacht)
    v_schema_name := split_part(tg_tag, '.', 1);
    v_table_name := split_part(tg_tag, '.', 2);
    
    -- Prüfe, ob es sich um ein Virtual Schema handelt
    IF EXISTS (SELECT 1 FROM vs_metadata.schemas WHERE schema_name = v_schema_name) THEN
        -- Protokolliere Zugriff
        INSERT INTO vs_metadata.access_log (
            schema_name, 
            table_name, 
            query_text, 
            execution_time, 
            rows_returned, 
            user_name, 
            client_ip,
            pushdown_applied
        ) VALUES (
            v_schema_name,
            v_table_name,
            v_query_text,
            v_execution_time,
            NULL, -- Zeilen können nicht direkt bestimmt werden
            current_user,
            inet_client_addr(),
            -- Pushdown muss manuell bestimmt werden über EXPLAIN
            (v_query_text ILIKE '%foreign scan%')
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Erstelle einen Event-Trigger für die Protokollierung
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'virtual_schema_access_log') THEN
        CREATE EVENT TRIGGER virtual_schema_access_log ON ddl_command_end
        EXECUTE FUNCTION vs_metadata.log_schema_access();
    END IF;
END $$; 