-- ExaPG Streaming und Real-time Processing
-- Erweiterte ETL-Funktionen für kontinuierliche Datenverarbeitung

-- Schema für Streaming-Funktionen
CREATE SCHEMA IF NOT EXISTS streaming;

-- Change Data Capture (CDC) Framework
CREATE TABLE IF NOT EXISTS streaming.cdc_log (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation CHAR(1) NOT NULL, -- I, U, D
    old_values JSONB,
    new_values JSONB,
    change_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    transaction_id BIGINT,
    user_name TEXT DEFAULT CURRENT_USER,
    application_name TEXT
);

-- CDC Trigger Function
CREATE OR REPLACE FUNCTION streaming.cdc_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    old_values JSONB;
    new_values JSONB;
BEGIN
    -- Konvertiere Zeilen zu JSON
    IF TG_OP = 'DELETE' THEN
        old_values := to_jsonb(OLD);
        new_values := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        old_values := NULL;
        new_values := to_jsonb(NEW);
    ELSE -- UPDATE
        old_values := to_jsonb(OLD);
        new_values := to_jsonb(NEW);
    END IF;
    
    -- Log Change
    INSERT INTO streaming.cdc_log (
        table_name,
        operation,
        old_values,
        new_values,
        transaction_id,
        application_name
    ) VALUES (
        TG_TABLE_NAME,
        CASE TG_OP 
            WHEN 'INSERT' THEN 'I'
            WHEN 'UPDATE' THEN 'U'
            WHEN 'DELETE' THEN 'D'
        END,
        old_values,
        new_values,
        txid_current(),
        current_setting('application_name', true)
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Aktivieren von CDC für eine Tabelle
CREATE OR REPLACE FUNCTION streaming.enable_cdc(
    schema_name TEXT,
    table_name TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    trigger_name TEXT;
    full_table_name TEXT;
BEGIN
    trigger_name := 'cdc_trigger_' || table_name;
    full_table_name := schema_name || '.' || table_name;
    
    -- Erstelle Trigger
    EXECUTE format('
        CREATE TRIGGER %I
        AFTER INSERT OR UPDATE OR DELETE ON %s
        FOR EACH ROW EXECUTE FUNCTION streaming.cdc_trigger_function()
    ', trigger_name, full_table_name);
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Fehler beim Aktivieren von CDC für %: %', full_table_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Materialized View Refresh Framework
CREATE TABLE IF NOT EXISTS streaming.refresh_schedule (
    id SERIAL PRIMARY KEY,
    view_name TEXT NOT NULL UNIQUE,
    refresh_interval INTERVAL NOT NULL,
    last_refresh TIMESTAMP WITH TIME ZONE,
    next_refresh TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    refresh_mode TEXT DEFAULT 'COMPLETE' -- COMPLETE, INCREMENTAL
);

-- Funktion zum Planen von Materialized View Refreshes
CREATE OR REPLACE FUNCTION streaming.schedule_refresh(
    view_name TEXT,
    refresh_interval INTERVAL,
    refresh_mode TEXT DEFAULT 'COMPLETE'
) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO streaming.refresh_schedule (
        view_name,
        refresh_interval,
        next_refresh,
        refresh_mode
    ) VALUES (
        view_name,
        refresh_interval,
        CURRENT_TIMESTAMP + refresh_interval,
        refresh_mode
    )
    ON CONFLICT (view_name) DO UPDATE SET
        refresh_interval = EXCLUDED.refresh_interval,
        refresh_mode = EXCLUDED.refresh_mode,
        next_refresh = CURRENT_TIMESTAMP + EXCLUDED.refresh_interval;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Automatischer Refresh-Prozess
CREATE OR REPLACE FUNCTION streaming.process_scheduled_refreshes()
RETURNS INTEGER AS $$
DECLARE
    refresh_rec RECORD;
    refreshed_count INTEGER := 0;
BEGIN
    FOR refresh_rec IN 
        SELECT * FROM streaming.refresh_schedule 
        WHERE is_active = TRUE 
        AND next_refresh <= CURRENT_TIMESTAMP
    LOOP
        BEGIN
            -- Refresh Materialized View
            EXECUTE format('REFRESH MATERIALIZED VIEW %I', refresh_rec.view_name);
            
            -- Update Schedule
            UPDATE streaming.refresh_schedule 
            SET 
                last_refresh = CURRENT_TIMESTAMP,
                next_refresh = CURRENT_TIMESTAMP + refresh_interval
            WHERE id = refresh_rec.id;
            
            refreshed_count := refreshed_count + 1;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Fehler beim Refresh von %: %', refresh_rec.view_name, SQLERRM;
        END;
    END LOOP;
    
    RETURN refreshed_count;
END;
$$ LANGUAGE plpgsql;

-- Real-time Aggregation Framework
CREATE OR REPLACE FUNCTION streaming.create_real_time_aggregate(
    source_table TEXT,
    aggregate_name TEXT,
    group_columns TEXT[],
    aggregate_columns TEXT[],
    time_window INTERVAL DEFAULT '1 hour'::INTERVAL
) RETURNS BOOLEAN AS $$
DECLARE
    sql_command TEXT;
    group_clause TEXT;
    agg_clause TEXT;
BEGIN
    -- Erstelle GROUP BY Klausel
    group_clause := array_to_string(group_columns, ', ');
    
    -- Erstelle Aggregations-Klausel
    agg_clause := array_to_string(
        ARRAY(
            SELECT 'SUM(' || col || ') as sum_' || col || ', ' ||
                   'AVG(' || col || ') as avg_' || col || ', ' ||
                   'COUNT(' || col || ') as count_' || col
            FROM unnest(aggregate_columns) as col
        ), ', '
    );
    
    -- Erstelle Materialized View für Real-time Aggregation
    sql_command := format('
        CREATE MATERIALIZED VIEW %I AS
        SELECT 
            %s,
            %s,
            COUNT(*) as total_rows,
            date_trunc(''hour'', CURRENT_TIMESTAMP) as window_start
        FROM %I
        WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL ''%s''
        GROUP BY %s, date_trunc(''hour'', CURRENT_TIMESTAMP)
    ', aggregate_name, group_clause, agg_clause, source_table, time_window, group_clause);
    
    EXECUTE sql_command;
    
    -- Schedule Refresh alle 5 Minuten
    PERFORM streaming.schedule_refresh(aggregate_name, '5 minutes'::INTERVAL);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Stream Processing Functions
CREATE OR REPLACE FUNCTION streaming.process_stream(
    source_table TEXT,
    target_table TEXT,
    processing_function TEXT,
    batch_size INTEGER DEFAULT 1000
) RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
    batch_sql TEXT;
BEGIN
    -- Erstelle Batch-Processing SQL
    batch_sql := format('
        WITH batch_data AS (
            SELECT * FROM %I 
            WHERE processed = FALSE 
            LIMIT %s
        ),
        processed_data AS (
            SELECT %s(row_to_json(batch_data.*)) as result
            FROM batch_data
        )
        INSERT INTO %I 
        SELECT (result).* FROM processed_data
    ', source_table, batch_size, processing_function, target_table);
    
    EXECUTE batch_sql;
    GET DIAGNOSTICS processed_count = ROW_COUNT;
    
    -- Markiere verarbeitete Datensätze
    EXECUTE format('
        UPDATE %I SET processed = TRUE 
        WHERE id IN (
            SELECT id FROM %I 
            WHERE processed = FALSE 
            LIMIT %s
        )
    ', source_table, source_table, batch_size);
    
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Event Sourcing Framework
CREATE TABLE IF NOT EXISTS streaming.event_store (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    event_data JSONB NOT NULL,
    event_version INTEGER NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB,
    UNIQUE(aggregate_id, event_version)
);

-- Index für Performance
CREATE INDEX IF NOT EXISTS idx_event_store_aggregate_id ON streaming.event_store(aggregate_id);
CREATE INDEX IF NOT EXISTS idx_event_store_timestamp ON streaming.event_store(event_timestamp);
CREATE INDEX IF NOT EXISTS idx_event_store_type ON streaming.event_store(event_type);

-- Funktion zum Hinzufügen von Events
CREATE OR REPLACE FUNCTION streaming.append_event(
    aggregate_id UUID,
    event_type TEXT,
    event_data JSONB,
    metadata JSONB DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    next_version INTEGER;
    event_id BIGINT;
BEGIN
    -- Bestimme nächste Version
    SELECT COALESCE(MAX(event_version), 0) + 1 
    INTO next_version
    FROM streaming.event_store 
    WHERE aggregate_id = append_event.aggregate_id;
    
    -- Füge Event hinzu
    INSERT INTO streaming.event_store (
        aggregate_id,
        event_type,
        event_data,
        event_version,
        metadata
    ) VALUES (
        append_event.aggregate_id,
        event_type,
        event_data,
        next_version,
        metadata
    ) RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Abrufen von Events
CREATE OR REPLACE FUNCTION streaming.get_events(
    aggregate_id UUID,
    from_version INTEGER DEFAULT 1
) RETURNS TABLE(
    event_type TEXT,
    event_data JSONB,
    event_version INTEGER,
    event_timestamp TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        es.event_type,
        es.event_data,
        es.event_version,
        es.event_timestamp
    FROM streaming.event_store es
    WHERE es.aggregate_id = get_events.aggregate_id
    AND es.event_version >= from_version
    ORDER BY es.event_version;
END;
$$ LANGUAGE plpgsql;

-- Stream Analytics Functions
CREATE OR REPLACE FUNCTION streaming.sliding_window_aggregate(
    table_name TEXT,
    timestamp_column TEXT,
    value_column TEXT,
    window_size INTERVAL,
    slide_interval INTERVAL DEFAULT NULL
) RETURNS TABLE(
    window_start TIMESTAMP WITH TIME ZONE,
    window_end TIMESTAMP WITH TIME ZONE,
    count_values BIGINT,
    sum_values NUMERIC,
    avg_values NUMERIC,
    min_values NUMERIC,
    max_values NUMERIC
) AS $$
DECLARE
    slide_int INTERVAL;
BEGIN
    slide_int := COALESCE(slide_interval, window_size);
    
    RETURN QUERY EXECUTE format('
        SELECT 
            time_bucket(%L, %I) as window_start,
            time_bucket(%L, %I) + %L as window_end,
            COUNT(%I)::BIGINT as count_values,
            SUM(%I) as sum_values,
            AVG(%I) as avg_values,
            MIN(%I) as min_values,
            MAX(%I) as max_values
        FROM %I
        WHERE %I >= CURRENT_TIMESTAMP - %L
        GROUP BY time_bucket(%L, %I)
        ORDER BY window_start
    ', slide_int, timestamp_column, slide_int, timestamp_column, window_size,
       value_column, value_column, value_column, value_column, value_column,
       table_name, timestamp_column, window_size * 2, slide_int, timestamp_column);
END;
$$ LANGUAGE plpgsql;

-- Grant Permissions
GRANT USAGE ON SCHEMA streaming TO PUBLIC;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA streaming TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA streaming TO PUBLIC;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA streaming TO PUBLIC; 