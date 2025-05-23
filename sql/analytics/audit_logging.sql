-- ExaPG Audit Logging System
-- Umfassendes Audit-Logging für Sicherheit und Compliance

-- Erstelle Audit-Schema
CREATE SCHEMA IF NOT EXISTS audit;

-- Audit-Log-Tabelle für alle Datenbankaktivitäten
CREATE TABLE IF NOT EXISTS audit.activity_log (
    log_id BIGSERIAL PRIMARY KEY,
    session_id TEXT,
    user_name TEXT NOT NULL,
    client_ip INET,
    application_name TEXT,
    command_tag TEXT,
    query_text TEXT,
    query_hash TEXT,
    table_names TEXT[],
    affected_rows BIGINT,
    execution_time_ms BIGINT,
    error_message TEXT,
    severity TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    database_name TEXT,
    schema_name TEXT,
    operation_type TEXT -- SELECT, INSERT, UPDATE, DELETE, DDL, etc.
) PARTITION BY RANGE (logged_at);

-- Partitionierung für bessere Performance
CREATE TABLE IF NOT EXISTS audit.activity_log_y2024m01 PARTITION OF audit.activity_log
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE IF NOT EXISTS audit.activity_log_y2024m02 PARTITION OF audit.activity_log
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE IF NOT EXISTS audit.activity_log_y2024m03 PARTITION OF audit.activity_log
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE IF NOT EXISTS audit.activity_log_y2024m04 PARTITION OF audit.activity_log
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

-- Index für effiziente Abfragen
CREATE INDEX IF NOT EXISTS idx_audit_log_user_time ON audit.activity_log (user_name, logged_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation ON audit.activity_log (operation_type, logged_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_table ON audit.activity_log USING GIN (table_names);
CREATE INDEX IF NOT EXISTS idx_audit_log_client_ip ON audit.activity_log (client_ip, logged_at);

-- Login/Logout-Tracking
CREATE TABLE IF NOT EXISTS audit.session_log (
    session_id TEXT PRIMARY KEY,
    user_name TEXT NOT NULL,
    client_ip INET,
    application_name TEXT,
    login_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_time TIMESTAMP WITH TIME ZONE,
    session_duration INTERVAL,
    queries_executed BIGINT DEFAULT 0,
    data_read_bytes BIGINT DEFAULT 0,
    data_written_bytes BIGINT DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_reason TEXT -- normal, timeout, error, killed
);

-- Index für Session-Tracking
CREATE INDEX IF NOT EXISTS idx_session_log_user_login ON audit.session_log (user_name, login_time);
CREATE INDEX IF NOT EXISTS idx_session_log_active ON audit.session_log (logout_time) WHERE logout_time IS NULL;

-- Schema-Änderungen protokollieren
CREATE TABLE IF NOT EXISTS audit.schema_changes (
    change_id BIGSERIAL PRIMARY KEY,
    user_name TEXT NOT NULL,
    object_type TEXT, -- TABLE, INDEX, FUNCTION, etc.
    object_name TEXT,
    schema_name TEXT,
    change_type TEXT, -- CREATE, ALTER, DROP
    ddl_command TEXT,
    old_definition TEXT,
    new_definition TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    client_ip INET,
    application_name TEXT
);

-- Berechtigungsänderungen protokollieren
CREATE TABLE IF NOT EXISTS audit.permission_changes (
    change_id BIGSERIAL PRIMARY KEY,
    grantor TEXT NOT NULL,
    grantee TEXT NOT NULL,
    object_type TEXT,
    object_name TEXT,
    permission TEXT,
    action TEXT, -- GRANT, REVOKE
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    client_ip INET,
    application_name TEXT
);

-- Sicherheitsereignisse
CREATE TABLE IF NOT EXISTS audit.security_events (
    event_id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL, -- LOGIN_FAILED, PERMISSION_DENIED, SQL_INJECTION_ATTEMPT, etc.
    user_name TEXT,
    client_ip INET,
    event_description TEXT,
    severity TEXT, -- LOW, MEDIUM, HIGH, CRITICAL
    query_text TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    additional_data JSONB
);

-- Performance-Audit für kritische Queries
CREATE TABLE IF NOT EXISTS audit.performance_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    user_name TEXT NOT NULL,
    query_hash TEXT,
    query_text TEXT,
    execution_time_ms BIGINT,
    rows_examined BIGINT,
    rows_returned BIGINT,
    temp_files_created INTEGER,
    temp_bytes_used BIGINT,
    shared_buffers_hit BIGINT,
    shared_buffers_read BIGINT,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    explain_plan TEXT,
    client_ip INET
); 