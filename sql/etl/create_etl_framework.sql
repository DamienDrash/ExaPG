-- ExaPG - ETL-Framework
-- SQL-Skript zum Erstellen und Konfigurieren des ETL-Frameworks in PostgreSQL

-- Erstelle ein Schema für das ETL-Framework
CREATE SCHEMA IF NOT EXISTS etl_framework;

-- Aktiviere die notwendigen Erweiterungen für ETL
DO $$
BEGIN
  -- Aktiviere pg_stat_statements für Performance-Monitoring
  EXECUTE 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements';
  
  -- Aktiviere tablefunc für komplexe Pivot-Operationen
  EXECUTE 'CREATE EXTENSION IF NOT EXISTS tablefunc';
  
  -- Aktiviere file_fdw für direktes Lesen von Dateien (CSV, etc.)
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'file_fdw') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS file_fdw';
    RAISE NOTICE 'file_fdw wurde aktiviert';
  ELSE
    RAISE NOTICE 'file_fdw ist nicht verfügbar';
  END IF;
END $$;

-- Erstelle tabelle für ETL-Job Definitionen
CREATE TABLE IF NOT EXISTS etl_framework.etl_jobs (
    job_id SERIAL PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL UNIQUE,
    job_description TEXT,
    source_type VARCHAR(50) NOT NULL, -- 'database', 'file', 'api', etc.
    source_connection JSONB,
    target_schema VARCHAR(100) NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    transformation_sql TEXT,
    parallel_workers INTEGER DEFAULT 1,
    batch_size INTEGER DEFAULT 10000,
    is_incremental BOOLEAN DEFAULT FALSE,
    incremental_column VARCHAR(100),
    last_value TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT CURRENT_USER,
    tags VARCHAR[]
);

-- Erstelle Tabelle für ETL-Job-Ausführungsprotokolle
CREATE TABLE IF NOT EXISTS etl_framework.etl_job_runs (
    run_id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES etl_framework.etl_jobs(job_id),
    start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'RUNNING', -- 'RUNNING', 'SUCCESS', 'FAILED', 'ABORTED'
    rows_processed BIGINT DEFAULT 0,
    rows_loaded BIGINT DEFAULT 0,
    rows_rejected BIGINT DEFAULT 0,
    error_message TEXT,
    execution_details JSONB
);

-- Erstelle Tabelle für ETL-Datenqualitätsprüfungen
CREATE TABLE IF NOT EXISTS etl_framework.data_quality_checks (
    check_id SERIAL PRIMARY KEY,
    check_name VARCHAR(100) NOT NULL,
    job_id INTEGER REFERENCES etl_framework.etl_jobs(job_id),
    check_type VARCHAR(50) NOT NULL, -- 'null_check', 'unique_check', 'range_check', 'regex_check', 'referential_check', 'custom_sql'
    check_sql TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'ERROR', -- 'WARNING', 'ERROR', 'CRITICAL'
    threshold FLOAT, -- für prozentuale Prüfungen
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle Tabelle für Datenqualitätsprüfungsergebnisse
CREATE TABLE IF NOT EXISTS etl_framework.data_quality_results (
    result_id SERIAL PRIMARY KEY,
    run_id INTEGER REFERENCES etl_framework.etl_job_runs(run_id),
    check_id INTEGER REFERENCES etl_framework.data_quality_checks(check_id),
    execution_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    passed BOOLEAN,
    value_checked FLOAT, -- tatsächlicher Wert, der geprüft wurde
    error_records JSONB, -- Fehlerhafte Datensätze (begrenzt auf eine Stichprobe)
    error_message TEXT
);

-- Erstelle Tabelle für CDC-Konfigurationen (Change Data Capture)
CREATE TABLE IF NOT EXISTS etl_framework.cdc_configurations (
    config_id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES etl_framework.etl_jobs(job_id),
    source_schema VARCHAR(100) NOT NULL,
    source_table VARCHAR(100) NOT NULL,
    connector_name VARCHAR(100) NOT NULL UNIQUE,
    connector_config JSONB NOT NULL,
    topic_name VARCHAR(100) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle Tabelle für Metadaten-Mapping (Quell- zu Zielschema)
CREATE TABLE IF NOT EXISTS etl_framework.column_mappings (
    mapping_id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES etl_framework.etl_jobs(job_id),
    source_column VARCHAR(100) NOT NULL,
    target_column VARCHAR(100) NOT NULL,
    data_type VARCHAR(50) NOT NULL,
    transformation_rule TEXT, -- SQL-Ausdruck für die Transformation
    is_primary_key BOOLEAN DEFAULT FALSE,
    is_nullable BOOLEAN DEFAULT TRUE,
    default_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(job_id, target_column)
);

-- Erstelle Tabelle für Scheduling-Informationen
CREATE TABLE IF NOT EXISTS etl_framework.etl_schedules (
    schedule_id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES etl_framework.etl_jobs(job_id),
    schedule_type VARCHAR(20) NOT NULL, -- 'cron', 'interval', 'once'
    schedule_value TEXT NOT NULL, -- cron-Ausdruck oder Interval-Definition
    next_run TIMESTAMP WITH TIME ZONE,
    last_run TIMESTAMP WITH TIME ZONE,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle optimierte Indizes für das ETL-Framework
CREATE INDEX IF NOT EXISTS idx_etl_job_runs_job_id ON etl_framework.etl_job_runs(job_id);
CREATE INDEX IF NOT EXISTS idx_etl_job_runs_status ON etl_framework.etl_job_runs(status);
CREATE INDEX IF NOT EXISTS idx_data_quality_results_run_id ON etl_framework.data_quality_results(run_id);
CREATE INDEX IF NOT EXISTS idx_data_quality_checks_job_id ON etl_framework.data_quality_checks(job_id);
CREATE INDEX IF NOT EXISTS idx_column_mappings_job_id ON etl_framework.column_mappings(job_id);
CREATE INDEX IF NOT EXISTS idx_etl_schedules_job_id ON etl_framework.etl_schedules(job_id);
CREATE INDEX IF NOT EXISTS idx_etl_schedules_next_run ON etl_framework.etl_schedules(next_run);
CREATE INDEX IF NOT EXISTS idx_cdc_configurations_job_id ON etl_framework.cdc_configurations(job_id);

-- Erstelle Funktion zum Registrieren eines ETL-Jobs
CREATE OR REPLACE FUNCTION etl_framework.register_etl_job(
    p_job_name VARCHAR(100),
    p_job_description TEXT,
    p_source_type VARCHAR(50),
    p_source_connection JSONB,
    p_target_schema VARCHAR(100),
    p_target_table VARCHAR(100),
    p_transformation_sql TEXT DEFAULT NULL,
    p_parallel_workers INTEGER DEFAULT 1,
    p_batch_size INTEGER DEFAULT 10000,
    p_is_incremental BOOLEAN DEFAULT FALSE,
    p_incremental_column VARCHAR(100) DEFAULT NULL,
    p_tags VARCHAR[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Prüfe, ob der Job bereits existiert
    SELECT job_id INTO v_job_id FROM etl_framework.etl_jobs WHERE job_name = p_job_name;
    
    IF v_job_id IS NOT NULL THEN
        -- Aktualisiere den bestehenden Job
        UPDATE etl_framework.etl_jobs
        SET job_description = p_job_description,
            source_type = p_source_type,
            source_connection = p_source_connection,
            target_schema = p_target_schema,
            target_table = p_target_table,
            transformation_sql = p_transformation_sql,
            parallel_workers = p_parallel_workers,
            batch_size = p_batch_size,
            is_incremental = p_is_incremental,
            incremental_column = p_incremental_column,
            last_modified = CURRENT_TIMESTAMP,
            tags = p_tags
        WHERE job_id = v_job_id;
    ELSE
        -- Erstelle einen neuen Job
        INSERT INTO etl_framework.etl_jobs(
            job_name,
            job_description,
            source_type,
            source_connection,
            target_schema,
            target_table,
            transformation_sql,
            parallel_workers,
            batch_size,
            is_incremental,
            incremental_column,
            tags
        ) VALUES (
            p_job_name,
            p_job_description,
            p_source_type,
            p_source_connection,
            p_target_schema,
            p_target_table,
            p_transformation_sql,
            p_parallel_workers,
            p_batch_size,
            p_is_incremental,
            p_incremental_column,
            p_tags
        ) RETURNING job_id INTO v_job_id;
        
        -- Erstelle das Zielschema, falls es nicht existiert
        EXECUTE 'CREATE SCHEMA IF NOT EXISTS ' || quote_ident(p_target_schema);
    END IF;
    
    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Hinzufügen einer Datenqualitätsprüfung
CREATE OR REPLACE FUNCTION etl_framework.add_data_quality_check(
    p_job_id INTEGER,
    p_check_name VARCHAR(100),
    p_check_type VARCHAR(50),
    p_check_sql TEXT,
    p_severity VARCHAR(20) DEFAULT 'ERROR',
    p_threshold FLOAT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_check_id INTEGER;
BEGIN
    -- Prüfe, ob der ETL-Job existiert
    IF NOT EXISTS (SELECT 1 FROM etl_framework.etl_jobs WHERE job_id = p_job_id) THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Prüfe, ob die Prüfung bereits existiert
    SELECT check_id INTO v_check_id 
    FROM etl_framework.data_quality_checks 
    WHERE job_id = p_job_id AND check_name = p_check_name;
    
    IF v_check_id IS NOT NULL THEN
        -- Aktualisiere die bestehende Prüfung
        UPDATE etl_framework.data_quality_checks
        SET check_type = p_check_type,
            check_sql = p_check_sql,
            severity = p_severity,
            threshold = p_threshold,
            last_modified = CURRENT_TIMESTAMP
        WHERE check_id = v_check_id;
    ELSE
        -- Erstelle eine neue Prüfung
        INSERT INTO etl_framework.data_quality_checks(
            job_id,
            check_name,
            check_type,
            check_sql,
            severity,
            threshold
        ) VALUES (
            p_job_id,
            p_check_name,
            p_check_type,
            p_check_sql,
            p_severity,
            p_threshold
        ) RETURNING check_id INTO v_check_id;
    END IF;
    
    RETURN v_check_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Aktivieren der CDC für einen ETL-Job
CREATE OR REPLACE FUNCTION etl_framework.enable_cdc(
    p_job_id INTEGER,
    p_connector_name VARCHAR(100),
    p_topic_name VARCHAR(100) DEFAULT NULL,
    p_connector_config JSONB DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_config_id INTEGER;
    v_source_schema VARCHAR(100);
    v_source_table VARCHAR(100);
    v_source_type VARCHAR(50);
    v_source_connection JSONB;
    v_connector_config JSONB;
    v_topic_name VARCHAR(100);
BEGIN
    -- Hole Job-Informationen
    SELECT source_type, source_connection, target_schema, target_table
    INTO v_source_type, v_source_connection, v_source_schema, v_source_table
    FROM etl_framework.etl_jobs
    WHERE job_id = p_job_id;
    
    IF v_source_type IS NULL THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Erstelle Standard-Connector-Konfiguration, falls nicht angegeben
    IF p_connector_config IS NULL THEN
        v_connector_config := jsonb_build_object(
            'name', p_connector_name,
            'config', jsonb_build_object(
                'connector.class', 'io.debezium.connector.postgresql.PostgresConnector',
                'database.hostname', v_source_connection->>'host',
                'database.port', COALESCE(v_source_connection->>'port', '5432'),
                'database.user', v_source_connection->>'user',
                'database.password', v_source_connection->>'password',
                'database.dbname', v_source_connection->>'database',
                'database.server.name', p_connector_name,
                'table.include.list', v_source_schema || '.' || v_source_table,
                'plugin.name', 'pgoutput',
                'snapshot.mode', 'initial'
            )
        );
    ELSE
        v_connector_config := p_connector_config;
    END IF;
    
    -- Setze Standard-Topic-Namen, falls nicht angegeben
    IF p_topic_name IS NULL THEN
        v_topic_name := p_connector_name || '.' || v_source_schema || '.' || v_source_table;
    ELSE
        v_topic_name := p_topic_name;
    END IF;
    
    -- Prüfe, ob die CDC-Konfiguration bereits existiert
    SELECT config_id INTO v_config_id
    FROM etl_framework.cdc_configurations
    WHERE job_id = p_job_id;
    
    IF v_config_id IS NOT NULL THEN
        -- Aktualisiere die bestehende Konfiguration
        UPDATE etl_framework.cdc_configurations
        SET connector_name = p_connector_name,
            connector_config = v_connector_config,
            topic_name = v_topic_name,
            last_modified = CURRENT_TIMESTAMP
        WHERE config_id = v_config_id;
    ELSE
        -- Erstelle eine neue Konfiguration
        INSERT INTO etl_framework.cdc_configurations(
            job_id,
            source_schema,
            source_table,
            connector_name,
            connector_config,
            topic_name
        ) VALUES (
            p_job_id,
            v_source_schema,
            v_source_table,
            p_connector_name,
            v_connector_config,
            v_topic_name
        ) RETURNING config_id INTO v_config_id;
    END IF;
    
    RETURN v_config_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle Funktion zum Hinzufügen eines Spalten-Mappings
CREATE OR REPLACE FUNCTION etl_framework.add_column_mapping(
    p_job_id INTEGER,
    p_source_column VARCHAR(100),
    p_target_column VARCHAR(100),
    p_data_type VARCHAR(50),
    p_transformation_rule TEXT DEFAULT NULL,
    p_is_primary_key BOOLEAN DEFAULT FALSE,
    p_is_nullable BOOLEAN DEFAULT TRUE,
    p_default_value TEXT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_mapping_id INTEGER;
BEGIN
    -- Prüfe, ob der ETL-Job existiert
    IF NOT EXISTS (SELECT 1 FROM etl_framework.etl_jobs WHERE job_id = p_job_id) THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Prüfe, ob das Mapping bereits existiert
    SELECT mapping_id INTO v_mapping_id
    FROM etl_framework.column_mappings
    WHERE job_id = p_job_id AND target_column = p_target_column;
    
    IF v_mapping_id IS NOT NULL THEN
        -- Aktualisiere das bestehende Mapping
        UPDATE etl_framework.column_mappings
        SET source_column = p_source_column,
            data_type = p_data_type,
            transformation_rule = p_transformation_rule,
            is_primary_key = p_is_primary_key,
            is_nullable = p_is_nullable,
            default_value = p_default_value,
            last_modified = CURRENT_TIMESTAMP
        WHERE mapping_id = v_mapping_id;
    ELSE
        -- Erstelle ein neues Mapping
        INSERT INTO etl_framework.column_mappings(
            job_id,
            source_column,
            target_column,
            data_type,
            transformation_rule,
            is_primary_key,
            is_nullable,
            default_value
        ) VALUES (
            p_job_id,
            p_source_column,
            p_target_column,
            p_data_type,
            p_transformation_rule,
            p_is_primary_key,
            p_is_nullable,
            p_default_value
        ) RETURNING mapping_id INTO v_mapping_id;
    END IF;
    
    RETURN v_mapping_id;
END;
$$ LANGUAGE plpgsql;

-- Erstelle praktische Views für ETL-Verwaltung
CREATE OR REPLACE VIEW etl_framework.active_jobs AS
SELECT 
    j.job_id,
    j.job_name,
    j.source_type,
    j.target_schema,
    j.target_table,
    j.is_incremental,
    COUNT(DISTINCT r.run_id) AS total_runs,
    MAX(r.start_time) AS last_run,
    COUNT(DISTINCT m.mapping_id) AS column_count,
    COUNT(DISTINCT q.check_id) AS quality_checks,
    CASE WHEN c.config_id IS NOT NULL THEN TRUE ELSE FALSE END AS cdc_enabled,
    j.parallel_workers,
    j.batch_size,
    j.tags
FROM 
    etl_framework.etl_jobs j
    LEFT JOIN etl_framework.etl_job_runs r ON j.job_id = r.job_id
    LEFT JOIN etl_framework.column_mappings m ON j.job_id = m.job_id
    LEFT JOIN etl_framework.data_quality_checks q ON j.job_id = q.job_id
    LEFT JOIN etl_framework.cdc_configurations c ON j.job_id = c.job_id
WHERE 
    j.enabled = TRUE
GROUP BY 
    j.job_id, j.job_name, j.source_type, j.target_schema, j.target_table, 
    j.is_incremental, j.parallel_workers, j.batch_size, j.tags, c.config_id;

-- Erstelle View für ETL-Job-Statistiken
CREATE OR REPLACE VIEW etl_framework.job_statistics AS
SELECT 
    j.job_id,
    j.job_name,
    COUNT(r.run_id) AS total_runs,
    AVG(EXTRACT(EPOCH FROM (r.end_time - r.start_time))) AS avg_runtime_seconds,
    MAX(EXTRACT(EPOCH FROM (r.end_time - r.start_time))) AS max_runtime_seconds,
    MIN(EXTRACT(EPOCH FROM (r.end_time - r.start_time))) AS min_runtime_seconds,
    SUM(r.rows_processed) AS total_rows_processed,
    SUM(r.rows_loaded) AS total_rows_loaded,
    SUM(r.rows_rejected) AS total_rows_rejected,
    (SUM(r.rows_rejected)::FLOAT / NULLIF(SUM(r.rows_processed), 0) * 100) AS rejection_rate_percent,
    COUNT(CASE WHEN r.status = 'SUCCESS' THEN 1 END) AS successful_runs,
    COUNT(CASE WHEN r.status = 'FAILED' THEN 1 END) AS failed_runs,
    (COUNT(CASE WHEN r.status = 'SUCCESS' THEN 1 END)::FLOAT / NULLIF(COUNT(r.run_id), 0) * 100) AS success_rate_percent
FROM 
    etl_framework.etl_jobs j
    LEFT JOIN etl_framework.etl_job_runs r ON j.job_id = r.job_id
GROUP BY 
    j.job_id, j.job_name; 