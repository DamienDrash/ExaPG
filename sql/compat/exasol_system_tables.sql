-- ExaPG System Tables - Exasol-kompatible Systemtabellen
-- Emuliert Exasol-Systemtabellen für Kompatibilität

-- Schema für Systemtabellen
CREATE SCHEMA IF NOT EXISTS exa_system;

-- EXA_ALL_OBJECTS - Alle Datenbankobjekte
CREATE OR REPLACE VIEW exa_system.exa_all_objects AS
SELECT 
    n.nspname AS object_schema,
    c.relname AS object_name,
    CASE c.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED VIEW'
        WHEN 'i' THEN 'INDEX'
        WHEN 'S' THEN 'SEQUENCE'
        WHEN 'f' THEN 'FOREIGN TABLE'
        WHEN 'p' THEN 'PARTITIONED TABLE'
    END AS object_type,
    pg_catalog.obj_description(c.oid, 'pg_class') AS object_comment,
    pg_catalog.pg_get_userbyid(c.relowner) AS owner,
    c.reltuples::bigint AS row_count,
    pg_catalog.pg_size_pretty(pg_catalog.pg_table_size(c.oid)) AS object_size
FROM pg_catalog.pg_class c
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND c.relkind IN ('r','v','m','f','p');

-- EXA_ALL_COLUMNS - Alle Spalten
CREATE OR REPLACE VIEW exa_system.exa_all_columns AS
SELECT 
    n.nspname AS column_schema,
    c.relname AS column_table,
    a.attname AS column_name,
    a.attnum AS column_ordinal_position,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS column_type,
    CASE 
        WHEN a.attnotnull THEN 'NOT NULL'
        ELSE 'NULL'
    END AS column_is_nullable,
    pg_catalog.col_description(c.oid, a.attnum) AS column_comment,
    CASE 
        WHEN a.attidentity != '' THEN 'IDENTITY'
        WHEN pg_get_expr(d.adbin, d.adrelid) IS NOT NULL THEN 'DEFAULT'
        ELSE NULL
    END AS column_default_type,
    pg_get_expr(d.adbin, d.adrelid) AS column_default
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_catalog.pg_attrdef d ON (a.attrelid, a.attnum) = (d.adrelid, d.adnum)
WHERE a.attnum > 0 
    AND NOT a.attisdropped
    AND n.nspname NOT IN ('pg_catalog', 'information_schema');

-- EXA_ALL_USERS - Alle Benutzer
CREATE OR REPLACE VIEW exa_system.exa_all_users AS
SELECT 
    usename AS user_name,
    usesysid AS user_id,
    CASE 
        WHEN usesuper THEN 'DBA'
        ELSE 'USER'
    END AS user_type,
    CASE 
        WHEN valuntil IS NULL THEN 'ACTIVE'
        WHEN valuntil < CURRENT_TIMESTAMP THEN 'EXPIRED'
        ELSE 'ACTIVE'
    END AS user_status,
    usecreatedb AS can_create_db,
    usesuper AS is_superuser,
    valuntil AS password_expiry_date
FROM pg_catalog.pg_user;

-- EXA_ALL_SESSIONS - Aktive Sessions
CREATE OR REPLACE VIEW exa_system.exa_all_sessions AS
SELECT 
    pid AS session_id,
    usename AS user_name,
    datname AS database_name,
    client_addr AS client_ip,
    client_port,
    backend_start AS login_time,
    state AS session_state,
    query AS current_statement,
    wait_event_type,
    wait_event,
    pg_catalog.pg_size_pretty(pg_catalog.pg_backend_memory_contexts_total_bytes(pid)) AS memory_usage
FROM pg_catalog.pg_stat_activity
WHERE pid != pg_backend_pid();

-- EXA_ALL_SCHEMAS - Alle Schemas
CREATE OR REPLACE VIEW exa_system.exa_all_schemas AS
SELECT 
    n.nspname AS schema_name,
    pg_catalog.pg_get_userbyid(n.nspowner) AS schema_owner,
    obj_description(n.oid, 'pg_namespace') AS schema_comment,
    CASE 
        WHEN n.nspname IN ('public') THEN 'PUBLIC'
        WHEN n.nspname LIKE 'pg_%' THEN 'SYSTEM'
        ELSE 'USER'
    END AS schema_type
FROM pg_catalog.pg_namespace n
WHERE n.nspname NOT IN ('pg_toast', 'pg_temp_1', 'pg_toast_temp_1');

-- EXA_SQL_KEYWORDS - SQL Keywords (Exasol-kompatibel)
CREATE TABLE IF NOT EXISTS exa_system.exa_sql_keywords (
    keyword VARCHAR(128) PRIMARY KEY,
    reserved BOOLEAN
);

-- Füge Exasol-spezifische Keywords hinzu
INSERT INTO exa_system.exa_sql_keywords (keyword, reserved) VALUES
    ('DISTRIBUTE', true),
    ('PARTITION', true),
    ('VIRTUAL', true),
    ('SCHEMA', true),
    ('EMITS', true),
    ('SCRIPT', true),
    ('LUA', true),
    ('PYTHON', true),
    ('R', true),
    ('JAVA', true),
    ('SCALAR', true),
    ('SET', true)
ON CONFLICT (keyword) DO NOTHING;

-- EXA_STATISTICS - Statistiken
CREATE OR REPLACE VIEW exa_system.exa_statistics AS
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    attname AS column_name,
    n_distinct AS distinct_count,
    avg_width AS avg_column_width,
    correlation AS column_correlation,
    most_common_vals::text AS most_common_values,
    most_common_freqs::text AS most_common_frequencies,
    histogram_bounds::text AS histogram_bounds
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema');

-- Funktion für Exasol-kompatible CURRENT_SESSION
CREATE OR REPLACE FUNCTION exa_system.current_session()
RETURNS bigint AS $$
BEGIN
    RETURN pg_backend_pid();
END;
$$ LANGUAGE plpgsql;

-- Funktion für Exasol-kompatible CURRENT_STATEMENT
CREATE OR REPLACE FUNCTION exa_system.current_statement()
RETURNS text AS $$
BEGIN
    RETURN current_query();
END;
$$ LANGUAGE plpgsql;

-- Grant Berechtigungen
GRANT USAGE ON SCHEMA exa_system TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA exa_system TO PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA exa_system TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exa_system TO PUBLIC; 