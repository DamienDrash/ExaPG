-- ExaPG - Virtual Schemas Hilfsfunktionen
-- SQL-Skript mit Hilfsfunktionen für die Virtual Schemas Funktionalität

-- Funktion um Spaltendefinitionen von einer Fremdquelle zu erhalten
CREATE OR REPLACE FUNCTION vs_metadata.get_column_definitions(
    p_schema_id INT,
    p_column_mapping JSONB,
    p_source_type VARCHAR(50),
    p_connection_string TEXT,
    p_remote_table_name VARCHAR(100)
) RETURNS TEXT AS $$
DECLARE
    v_column_definitions TEXT := '';
    v_column_record RECORD;
    v_query TEXT;
    v_options JSONB;
    v_schema_name TEXT;
    v_use_mapping BOOLEAN := FALSE;
BEGIN
    -- Hole die Schema-Optionen
    SELECT options, schema_name INTO v_options, v_schema_name
    FROM vs_metadata.schemas
    WHERE schema_id = p_schema_id;
    
    -- Bestimme, ob eine benutzerdefinierte Spaltenzuordnung verwendet werden soll
    IF p_column_mapping IS NOT NULL AND p_column_mapping <> '{}'::JSONB THEN
        v_use_mapping := TRUE;
        
        -- Erstelle Spaltendefinitionen aus den Mapping-Informationen
        FOR v_column_record IN 
            SELECT 
                key AS column_name, 
                value->>'type' AS data_type,
                (value->>'nullable')::BOOLEAN AS is_nullable
            FROM jsonb_each(p_column_mapping)
        LOOP
            IF v_column_definitions <> '' THEN
                v_column_definitions := v_column_definitions || ', ';
            END IF;
            
            v_column_definitions := v_column_definitions || 
                quote_ident(v_column_record.column_name) || ' ' || 
                v_column_record.data_type;
                
            IF NOT v_column_record.is_nullable THEN
                v_column_definitions := v_column_definitions || ' NOT NULL';
            END IF;
        END LOOP;
        
        RETURN v_column_definitions;
    END IF;
    
    -- Wenn keine explizite Zuordnung angegeben wurde, hole die Spalteninformationen von der Quelle
    CASE p_source_type
        WHEN 'postgres' THEN
            -- Bestimme den Schema-Namen für PostgreSQL
            DECLARE
                v_pg_schema TEXT := split_part(p_remote_table_name, '.', 1);
                v_pg_table TEXT := split_part(p_remote_table_name, '.', 2);
                v_pg_conn TEXT;
            BEGIN
                -- Erstelle temporäre Verbindung zur PostgreSQL-Datenbank
                v_pg_conn := format(
                    'host=%s port=%s dbname=%s user=%s password=%s',
                    COALESCE(v_options->>'host', split_part(split_part(p_connection_string, '@', 2), ':', 1)),
                    COALESCE(v_options->>'port', split_part(split_part(p_connection_string, ':', 3), '/', 1)),
                    COALESCE(v_options->>'dbname', split_part(split_part(p_connection_string, '/', 2), '?', 1)),
                    COALESCE(v_options->>'user', split_part(split_part(p_connection_string, '//', 2), ':', 1)),
                    COALESCE(v_options->>'password', split_part(split_part(p_connection_string, ':', 2), '@', 1))
                );
                
                -- Verwende dblink um Spalteninformationen zu holen
                PERFORM vs_metadata.ensure_dblink_extension();
                
                v_query := format(
                    'SELECT 
                        column_name, 
                        data_type, 
                        character_maximum_length,
                        numeric_precision,
                        numeric_scale,
                        is_nullable
                     FROM information_schema.columns 
                     WHERE table_schema = %L AND table_name = %L
                     ORDER BY ordinal_position',
                    v_pg_schema, v_pg_table
                );
                
                FOR v_column_record IN 
                    SELECT * FROM dblink(v_pg_conn, v_query) AS t(
                        column_name VARCHAR(100),
                        data_type VARCHAR(100),
                        character_maximum_length INT,
                        numeric_precision INT,
                        numeric_scale INT,
                        is_nullable VARCHAR(3)
                    )
                LOOP
                    IF v_column_definitions <> '' THEN
                        v_column_definitions := v_column_definitions || ', ';
                    END IF;
                    
                    -- Erstelle die Spaltendefinition basierend auf dem Datentyp
                    v_column_definitions := v_column_definitions || 
                        quote_ident(v_column_record.column_name) || ' ' || 
                        vs_metadata.map_data_type(
                            v_column_record.data_type, 
                            v_column_record.character_maximum_length,
                            v_column_record.numeric_precision,
                            v_column_record.numeric_scale,
                            'postgres'
                        );
                        
                    IF v_column_record.is_nullable = 'NO' THEN
                        v_column_definitions := v_column_definitions || ' NOT NULL';
                    END IF;
                END LOOP;
            END;
            
        WHEN 'mysql' THEN
            DECLARE
                v_mysql_conn TEXT;
            BEGIN
                -- Erstelle temporäre Verbindung zur MySQL-Datenbank über den mysql_fdw
                PERFORM vs_metadata.ensure_mysql_fdw_extension();
                
                -- MySQL-Verbindungsinformationen
                v_mysql_conn := format(
                    'host=%s port=%s dbname=%s user=%s password=%s',
                    COALESCE(v_options->>'host', split_part(p_connection_string, ':', 1)),
                    COALESCE(v_options->>'port', '3306'),
                    COALESCE(v_options->>'dbname', v_options->>'database'),
                    COALESCE(v_options->>'user', split_part(split_part(p_connection_string, '@', 1), ':', 1)),
                    COALESCE(v_options->>'password', split_part(split_part(p_connection_string, ':', 2), '@', 1))
                );
                
                -- Erstelle temporären Server und User Mapping
                EXECUTE format('CREATE SERVER IF NOT EXISTS temp_mysql_server FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host %L, port %L)',
                    COALESCE(v_options->>'host', split_part(p_connection_string, ':', 1)),
                    COALESCE(v_options->>'port', '3306')
                );
                
                EXECUTE format('CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER SERVER temp_mysql_server OPTIONS (username %L, password %L)',
                    COALESCE(v_options->>'user', split_part(split_part(p_connection_string, '@', 1), ':', 1)),
                    COALESCE(v_options->>'password', split_part(split_part(p_connection_string, ':', 2), '@', 1))
                );
                
                -- Erstelle temporäre Fremdtabelle für die Metadaten
                EXECUTE format('
                    CREATE FOREIGN TABLE IF NOT EXISTS temp_mysql_columns (
                        column_name VARCHAR(100),
                        data_type VARCHAR(100),
                        character_maximum_length INT,
                        numeric_precision INT,
                        numeric_scale INT,
                        is_nullable VARCHAR(3),
                        column_key VARCHAR(3)
                    ) SERVER temp_mysql_server OPTIONS (
                        dbname %L,
                        table_name ''information_schema.columns''
                    )',
                    COALESCE(v_options->>'dbname', 'information_schema')
                );
                
                -- Hole die Spalteninformationen
                FOR v_column_record IN 
                    EXECUTE format('
                        SELECT 
                            column_name, 
                            data_type, 
                            character_maximum_length,
                            numeric_precision,
                            numeric_scale,
                            is_nullable,
                            column_key
                        FROM temp_mysql_columns 
                        WHERE table_schema = %L AND table_name = %L
                        ORDER BY ordinal_position',
                        COALESCE(v_options->>'dbname', v_options->>'database'),
                        p_remote_table_name
                    )
                LOOP
                    IF v_column_definitions <> '' THEN
                        v_column_definitions := v_column_definitions || ', ';
                    END IF;
                    
                    -- Erstelle die Spaltendefinition basierend auf dem Datentyp
                    v_column_definitions := v_column_definitions || 
                        quote_ident(v_column_record.column_name) || ' ' || 
                        vs_metadata.map_data_type(
                            v_column_record.data_type, 
                            v_column_record.character_maximum_length,
                            v_column_record.numeric_precision,
                            v_column_record.numeric_scale,
                            'mysql'
                        );
                        
                    IF v_column_record.is_nullable = 'NO' THEN
                        v_column_definitions := v_column_definitions || ' NOT NULL';
                    END IF;
                END LOOP;
                
                -- Bereinige temporäre Objekte
                EXECUTE 'DROP FOREIGN TABLE IF EXISTS temp_mysql_columns';
                EXECUTE 'DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER temp_mysql_server';
                EXECUTE 'DROP SERVER IF EXISTS temp_mysql_server';
            END;
            
        WHEN 'mssql' THEN
            -- Ähnlich wie für MySQL/PostgreSQL, jedoch mit SQL Server-spezifischen Details
            -- Dies würde eine ähnliche Implementierung wie oben erfordern
            
            -- Platzhalter für SQL Server-Spalteninformationen
            v_column_definitions := 'id INT, name TEXT, description TEXT';
            
        WHEN 'mongodb' THEN
            -- MongoDB hat ein dynamisches Schema, daher müssen wir entweder
            -- einige Dokumente analysieren oder eine explizite Spaltenzuordnung verlangen
            v_column_definitions := 'id TEXT, data JSONB';
            
        WHEN 'redis' THEN
            -- Redis ist ein Key-Value-Store, daher gibt es standardmäßig nur key/value-Spalten
            v_column_definitions := 'key TEXT, value TEXT';
            
        ELSE
            -- Für nicht explizit behandelte Quellen, verwenden wir eine generische Spaltendefinition
            v_column_definitions := 'id INT, data JSONB';
            
    END CASE;
    
    RETURN v_column_definitions;
END;
$$ LANGUAGE plpgsql;

-- Funktion, die einen Datentyp von einer externen Quelle in einen PostgreSQL-Datentyp umwandelt
CREATE OR REPLACE FUNCTION vs_metadata.map_data_type(
    p_source_type VARCHAR(100),
    p_max_length INT,
    p_precision INT,
    p_scale INT,
    p_db_type VARCHAR(50)
) RETURNS TEXT AS $$
DECLARE
    v_pg_type TEXT;
BEGIN
    -- Normalisiere den Quelldatentyp zu Kleinbuchstaben
    p_source_type := lower(p_source_type);
    
    -- Mapping basierend auf der Quelldatenbank
    CASE p_db_type
        WHEN 'postgres' THEN
            -- PostgreSQL-zu-PostgreSQL-Mapping ist direkt
            RETURN p_source_type;
            
        WHEN 'mysql' THEN
            -- MySQL-zu-PostgreSQL-Mapping
            CASE p_source_type
                WHEN 'int' THEN v_pg_type := 'INTEGER';
                WHEN 'bigint' THEN v_pg_type := 'BIGINT';
                WHEN 'smallint' THEN v_pg_type := 'SMALLINT';
                WHEN 'tinyint' THEN 
                    IF p_max_length = 1 THEN 
                        v_pg_type := 'BOOLEAN'; 
                    ELSE 
                        v_pg_type := 'SMALLINT'; 
                    END IF;
                WHEN 'decimal' THEN v_pg_type := format('NUMERIC(%s,%s)', p_precision, p_scale);
                WHEN 'float' THEN v_pg_type := 'REAL';
                WHEN 'double' THEN v_pg_type := 'DOUBLE PRECISION';
                WHEN 'date' THEN v_pg_type := 'DATE';
                WHEN 'datetime' THEN v_pg_type := 'TIMESTAMP';
                WHEN 'timestamp' THEN v_pg_type := 'TIMESTAMP WITH TIME ZONE';
                WHEN 'time' THEN v_pg_type := 'TIME';
                WHEN 'char' THEN v_pg_type := format('CHAR(%s)', p_max_length);
                WHEN 'varchar' THEN v_pg_type := format('VARCHAR(%s)', p_max_length);
                WHEN 'text' THEN v_pg_type := 'TEXT';
                WHEN 'blob' THEN v_pg_type := 'BYTEA';
                WHEN 'json' THEN v_pg_type := 'JSONB';
                WHEN 'enum' THEN v_pg_type := 'TEXT'; -- ENUMs in MySQL umwandeln
                ELSE v_pg_type := 'TEXT'; -- Standardtyp für unbekannte Typen
            END CASE;
            
        WHEN 'mssql' THEN
            -- SQL Server-zu-PostgreSQL-Mapping
            CASE p_source_type
                WHEN 'int' THEN v_pg_type := 'INTEGER';
                WHEN 'bigint' THEN v_pg_type := 'BIGINT';
                WHEN 'smallint' THEN v_pg_type := 'SMALLINT';
                WHEN 'tinyint' THEN v_pg_type := 'SMALLINT';
                WHEN 'decimal' THEN v_pg_type := format('NUMERIC(%s,%s)', p_precision, p_scale);
                WHEN 'numeric' THEN v_pg_type := format('NUMERIC(%s,%s)', p_precision, p_scale);
                WHEN 'float' THEN v_pg_type := 'DOUBLE PRECISION';
                WHEN 'real' THEN v_pg_type := 'REAL';
                WHEN 'money' THEN v_pg_type := 'MONEY';
                WHEN 'date' THEN v_pg_type := 'DATE';
                WHEN 'datetime' THEN v_pg_type := 'TIMESTAMP';
                WHEN 'datetime2' THEN v_pg_type := 'TIMESTAMP';
                WHEN 'datetimeoffset' THEN v_pg_type := 'TIMESTAMP WITH TIME ZONE';
                WHEN 'time' THEN v_pg_type := 'TIME';
                WHEN 'char' THEN v_pg_type := format('CHAR(%s)', p_max_length);
                WHEN 'varchar' THEN v_pg_type := format('VARCHAR(%s)', p_max_length);
                WHEN 'nvarchar' THEN v_pg_type := format('VARCHAR(%s)', p_max_length);
                WHEN 'text' THEN v_pg_type := 'TEXT';
                WHEN 'ntext' THEN v_pg_type := 'TEXT';
                WHEN 'binary' THEN v_pg_type := 'BYTEA';
                WHEN 'varbinary' THEN v_pg_type := 'BYTEA';
                WHEN 'image' THEN v_pg_type := 'BYTEA';
                WHEN 'bit' THEN v_pg_type := 'BOOLEAN';
                WHEN 'uniqueidentifier' THEN v_pg_type := 'UUID';
                WHEN 'xml' THEN v_pg_type := 'XML';
                ELSE v_pg_type := 'TEXT'; -- Standardtyp für unbekannte Typen
            END CASE;
            
        ELSE
            -- Generisches Mapping für andere Quellen
            CASE 
                WHEN p_source_type LIKE '%int%' THEN v_pg_type := 'INTEGER';
                WHEN p_source_type LIKE '%char%' OR p_source_type LIKE '%text%' THEN v_pg_type := 'TEXT';
                WHEN p_source_type LIKE '%date%' OR p_source_type LIKE '%time%' THEN v_pg_type := 'TIMESTAMP';
                WHEN p_source_type LIKE '%num%' OR p_source_type LIKE '%dec%' THEN v_pg_type := 'NUMERIC';
                WHEN p_source_type LIKE '%float%' OR p_source_type LIKE '%real%' OR p_source_type LIKE '%double%' THEN v_pg_type := 'DOUBLE PRECISION';
                WHEN p_source_type LIKE '%bool%' OR p_source_type LIKE '%bit%' THEN v_pg_type := 'BOOLEAN';
                WHEN p_source_type LIKE '%blob%' OR p_source_type LIKE '%binary%' THEN v_pg_type := 'BYTEA';
                WHEN p_source_type LIKE '%json%' THEN v_pg_type := 'JSONB';
                ELSE v_pg_type := 'TEXT'; -- Standardtyp für unbekannte Typen
            END CASE;
    END CASE;
    
    RETURN v_pg_type;
END;
$$ LANGUAGE plpgsql;

-- Hilfsfunktion zur Sicherstellung, dass dblink für PostgreSQL-Verbindungen installiert ist
CREATE OR REPLACE FUNCTION vs_metadata.ensure_dblink_extension() RETURNS VOID AS $$
BEGIN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS dblink';
END;
$$ LANGUAGE plpgsql;

-- Hilfsfunktion zur Sicherstellung, dass mysql_fdw installiert ist
CREATE OR REPLACE FUNCTION vs_metadata.ensure_mysql_fdw_extension() RETURNS VOID AS $$
BEGIN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS mysql_fdw';
END;
$$ LANGUAGE plpgsql;

-- Funktion zur Abfrage der Informationen über fremde Tabellen
CREATE OR REPLACE FUNCTION vs_metadata.get_foreign_table_info(
    p_schema_name VARCHAR(100)
) RETURNS TABLE (
    table_name VARCHAR(100),
    source_type VARCHAR(50),
    remote_table VARCHAR(100),
    column_count INT,
    last_analyzed TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.table_name::VARCHAR(100),
        s.source_type,
        t.remote_table_name::VARCHAR(100),
        (SELECT COUNT(*) FROM information_schema.columns 
         WHERE table_schema = p_schema_name AND table_name = t.table_name)::INT,
        ts.last_refreshed
    FROM vs_metadata.tables t
    JOIN vs_metadata.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN vs_metadata.table_stats ts ON t.schema_id = ts.schema_id AND t.table_name = ts.table_name
    WHERE s.schema_name = p_schema_name AND t.enabled = TRUE
    ORDER BY t.table_name;
END;
$$ LANGUAGE plpgsql;

-- Erstelle eine Funktion zum Abrufen von Statistiken über die Nutzung von Virtual Schemas
CREATE OR REPLACE FUNCTION vs_metadata.get_schema_usage_stats(
    p_schema_name VARCHAR(100) DEFAULT NULL,
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date TIMESTAMP DEFAULT NULL
) RETURNS TABLE (
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    query_count BIGINT,
    total_execution_time INTERVAL,
    avg_execution_time INTERVAL,
    pushdown_percentage NUMERIC(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.schema_name::VARCHAR(100),
        al.table_name::VARCHAR(100),
        COUNT(*)::BIGINT AS query_count,
        SUM(al.execution_time) AS total_execution_time,
        AVG(al.execution_time) AS avg_execution_time,
        (SUM(CASE WHEN al.pushdown_applied THEN 1 ELSE 0 END) * 100.0 / COUNT(*))::NUMERIC(5,2) AS pushdown_percentage
    FROM vs_metadata.access_log al
    WHERE 
        (p_schema_name IS NULL OR al.schema_name = p_schema_name) AND
        (p_start_date IS NULL OR al.executed_at >= p_start_date) AND
        (p_end_date IS NULL OR al.executed_at <= p_end_date)
    GROUP BY al.schema_name, al.table_name
    ORDER BY query_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Erstelle eine Funktion zum Optimieren von Abfragen mit Pushdown
CREATE OR REPLACE FUNCTION vs_metadata.optimize_for_pushdown(
    p_query TEXT
) RETURNS TEXT AS $$
DECLARE
    v_schema_name TEXT;
    v_options JSONB;
    v_source_type TEXT;
    v_optimized_query TEXT;
BEGIN
    -- Extrahiere den Schema-Namen aus der Abfrage (vereinfacht)
    v_schema_name := regexp_replace(
        regexp_replace(p_query, '.*FROM\s+([a-zA-Z0-9_]+)\..*', '\1', 'i'),
        '.*JOIN\s+([a-zA-Z0-9_]+)\..*', '\1', 'i'
    );
    
    -- Überprüfe, ob es sich um ein Virtual Schema handelt
    SELECT source_type, options
    INTO v_source_type, v_options
    FROM vs_metadata.schemas
    WHERE schema_name = v_schema_name
      AND pushdown_enabled = TRUE;
    
    IF v_source_type IS NULL THEN
        -- Kein Virtual Schema oder Pushdown nicht aktiviert
        RETURN p_query;
    END IF;
    
    -- Optimiere basierend auf dem Quellentyp
    CASE v_source_type
        WHEN 'postgres' THEN
            -- PostgreSQL: Aktiviere Pushdown durch geeignete Hinzufügungen
            v_optimized_query := regexp_replace(
                p_query,
                'FROM\s+' || v_schema_name || '\.',
                'FROM ' || v_schema_name || '. /* +postgres_fdw(use_remote_estimate true) */ ',
                'i'
            );
            
        WHEN 'mysql' THEN
            -- MySQL: Hier könnten spezifische Optimierungen erfolgen
            v_optimized_query := p_query;
            
        WHEN 'mssql' THEN
            -- SQL Server: Hier könnten spezifische Optimierungen erfolgen
            v_optimized_query := p_query;
            
        ELSE
            -- Für andere Quellen keine spezifischen Optimierungen
            v_optimized_query := p_query;
    END CASE;
    
    RETURN v_optimized_query;
END;
$$ LANGUAGE plpgsql; 