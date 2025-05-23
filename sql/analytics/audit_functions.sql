-- ExaPG Audit Logging Functions
-- Funktionen für Audit-Logging und Compliance-Reporting

-- Funktion zum Protokollieren von Aktivitäten
CREATE OR REPLACE FUNCTION audit.log_activity(
    p_session_id TEXT,
    p_user_name TEXT,
    p_client_ip INET,
    p_application_name TEXT,
    p_command_tag TEXT,
    p_query_text TEXT,
    p_table_names TEXT[],
    p_affected_rows BIGINT DEFAULT NULL,
    p_execution_time_ms BIGINT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.activity_log (
        session_id, user_name, client_ip, application_name,
        command_tag, query_text, query_hash, table_names,
        affected_rows, execution_time_ms, error_message,
        operation_type, database_name, schema_name,
        severity
    ) VALUES (
        p_session_id, p_user_name, p_client_ip, p_application_name,
        p_command_tag, p_query_text, 
        md5(p_query_text), p_table_names,
        p_affected_rows, p_execution_time_ms, p_error_message,
        CASE 
            WHEN p_command_tag ILIKE 'SELECT%' THEN 'SELECT'
            WHEN p_command_tag ILIKE 'INSERT%' THEN 'INSERT'
            WHEN p_command_tag ILIKE 'UPDATE%' THEN 'UPDATE'
            WHEN p_command_tag ILIKE 'DELETE%' THEN 'DELETE'
            WHEN p_command_tag ILIKE 'CREATE%' THEN 'DDL'
            WHEN p_command_tag ILIKE 'ALTER%' THEN 'DDL'
            WHEN p_command_tag ILIKE 'DROP%' THEN 'DDL'
            ELSE 'OTHER'
        END,
        current_database(),
        current_schema(),
        CASE 
            WHEN p_error_message IS NOT NULL THEN 'ERROR'
            WHEN p_execution_time_ms > 10000 THEN 'WARNING'
            ELSE 'INFO'
        END
    );
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Protokollieren von Session-Aktivitäten
CREATE OR REPLACE FUNCTION audit.log_session_start(
    p_session_id TEXT,
    p_user_name TEXT,
    p_client_ip INET,
    p_application_name TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.session_log (
        session_id, user_name, client_ip, application_name
    ) VALUES (
        p_session_id, p_user_name, p_client_ip, p_application_name
    ) ON CONFLICT (session_id) DO UPDATE SET
        login_time = NOW(),
        last_activity = NOW();
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Protokollieren von Session-Ende
CREATE OR REPLACE FUNCTION audit.log_session_end(
    p_session_id TEXT,
    p_logout_reason TEXT DEFAULT 'normal'
) RETURNS VOID AS $$
BEGIN
    UPDATE audit.session_log SET
        logout_time = NOW(),
        session_duration = NOW() - login_time,
        logout_reason = p_logout_reason
    WHERE session_id = p_session_id
    AND logout_time IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Protokollieren von Sicherheitsereignissen
CREATE OR REPLACE FUNCTION audit.log_security_event(
    p_event_type TEXT,
    p_user_name TEXT,
    p_client_ip INET,
    p_event_description TEXT,
    p_severity TEXT DEFAULT 'MEDIUM',
    p_query_text TEXT DEFAULT NULL,
    p_additional_data JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.security_events (
        event_type, user_name, client_ip, event_description,
        severity, query_text, additional_data
    ) VALUES (
        p_event_type, p_user_name, p_client_ip, p_event_description,
        p_severity, p_query_text, p_additional_data
    );
    
    -- Bei kritischen Ereignissen sofortige Benachrichtigung
    IF p_severity = 'CRITICAL' THEN
        PERFORM pg_notify('security_alert', 
            json_build_object(
                'event_type', p_event_type,
                'user_name', p_user_name,
                'client_ip', p_client_ip,
                'description', p_event_description,
                'occurred_at', NOW()
            )::text
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger-Funktion für automatisches Audit-Logging
CREATE OR REPLACE FUNCTION audit.audit_trigger_function() RETURNS TRIGGER AS $$
DECLARE
    audit_query TEXT;
    affected_rows BIGINT;
BEGIN
    -- Bestimme die Anzahl der betroffenen Zeilen
    affected_rows := CASE 
        WHEN TG_OP = 'DELETE' THEN 1
        WHEN TG_OP = 'UPDATE' THEN 1
        WHEN TG_OP = 'INSERT' THEN 1
        ELSE 0
    END;
    
    -- Erstelle Audit-Eintrag
    audit_query := format('Operation: %s on table %s.%s', 
                         TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME);
    
    INSERT INTO audit.activity_log (
        user_name, command_tag, query_text, operation_type,
        table_names, affected_rows, database_name, schema_name
    ) VALUES (
        current_user, TG_OP, audit_query, TG_OP,
        ARRAY[TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME],
        affected_rows, current_database(), TG_TABLE_SCHEMA
    );
    
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- Views für Audit-Reporting
CREATE OR REPLACE VIEW audit.daily_activity_summary AS
SELECT 
    date_trunc('day', logged_at) as activity_date,
    user_name,
    operation_type,
    count(*) as operation_count,
    avg(execution_time_ms) as avg_execution_time,
    sum(affected_rows) as total_affected_rows
FROM audit.activity_log 
WHERE logged_at >= current_date - interval '30 days'
GROUP BY date_trunc('day', logged_at), user_name, operation_type
ORDER BY activity_date DESC, operation_count DESC;

CREATE OR REPLACE VIEW audit.security_events_summary AS
SELECT 
    date_trunc('hour', occurred_at) as event_hour,
    event_type,
    severity,
    count(*) as event_count,
    array_agg(DISTINCT user_name) as affected_users,
    array_agg(DISTINCT client_ip::text) as source_ips
FROM audit.security_events
WHERE occurred_at >= current_date - interval '7 days'
GROUP BY date_trunc('hour', occurred_at), event_type, severity
ORDER BY event_hour DESC, event_count DESC;

CREATE OR REPLACE VIEW audit.active_sessions AS
SELECT 
    s.session_id,
    s.user_name,
    s.client_ip,
    s.application_name,
    s.login_time,
    s.last_activity,
    NOW() - s.last_activity as idle_time,
    s.queries_executed,
    pg_size_pretty(s.data_read_bytes) as data_read,
    pg_size_pretty(s.data_written_bytes) as data_written
FROM audit.session_log s
WHERE s.logout_time IS NULL
ORDER BY s.login_time DESC;

-- Funktion für Compliance-Reports
CREATE OR REPLACE FUNCTION audit.generate_compliance_report(
    p_start_date DATE,
    p_end_date DATE,
    p_user_filter TEXT DEFAULT NULL
) RETURNS TABLE (
    report_section TEXT,
    metric_name TEXT,
    metric_value TEXT,
    compliance_status TEXT
) AS $$
BEGIN
    -- Benutzeraktivität
    RETURN QUERY
    SELECT 
        'User Activity'::TEXT,
        'Total Queries'::TEXT,
        count(*)::TEXT,
        CASE WHEN count(*) > 0 THEN 'COMPLIANT' ELSE 'NO_ACTIVITY' END
    FROM audit.activity_log 
    WHERE logged_at::date BETWEEN p_start_date AND p_end_date
    AND (p_user_filter IS NULL OR user_name = p_user_filter);
    
    -- Sicherheitsereignisse
    RETURN QUERY
    SELECT 
        'Security Events'::TEXT,
        'Critical Events'::TEXT,
        count(*)::TEXT,
        CASE WHEN count(*) = 0 THEN 'COMPLIANT' ELSE 'REQUIRES_ATTENTION' END
    FROM audit.security_events
    WHERE occurred_at::date BETWEEN p_start_date AND p_end_date
    AND severity = 'CRITICAL'
    AND (p_user_filter IS NULL OR user_name = p_user_filter);
    
    -- Schema-Änderungen
    RETURN QUERY
    SELECT 
        'Schema Changes'::TEXT,
        'DDL Operations'::TEXT,
        count(*)::TEXT,
        'LOGGED'::TEXT
    FROM audit.schema_changes
    WHERE changed_at::date BETWEEN p_start_date AND p_end_date
    AND (p_user_filter IS NULL OR user_name = p_user_filter);
    
    -- Performance-Probleme
    RETURN QUERY
    SELECT 
        'Performance'::TEXT,
        'Slow Queries (>5s)'::TEXT,
        count(*)::TEXT,
        CASE WHEN count(*) < 10 THEN 'ACCEPTABLE' ELSE 'REQUIRES_OPTIMIZATION' END
    FROM audit.performance_audit
    WHERE executed_at::date BETWEEN p_start_date AND p_end_date
    AND execution_time_ms > 5000
    AND (p_user_filter IS NULL OR user_name = p_user_filter);
END;
$$ LANGUAGE plpgsql;

-- Automatische Partitionierung neuer Monate
CREATE OR REPLACE FUNCTION audit.create_monthly_partition(partition_date DATE)
RETURNS VOID AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    start_date := date_trunc('month', partition_date);
    end_date := start_date + interval '1 month';
    partition_name := 'activity_log_y' || to_char(start_date, 'YYYY') || 'm' || to_char(start_date, 'MM');
    
    EXECUTE format('CREATE TABLE IF NOT EXISTS audit.%I PARTITION OF audit.activity_log 
                    FOR VALUES FROM (%L) TO (%L)',
                   partition_name, start_date, end_date);
END;
$$ LANGUAGE plpgsql;

-- Aufräumen alter Audit-Daten (nach gesetzlichen Aufbewahrungsfristen)
CREATE OR REPLACE FUNCTION audit.cleanup_old_audit_data(retention_months INTEGER DEFAULT 84) -- 7 Jahre
RETURNS INTEGER AS $$
DECLARE
    cutoff_date DATE;
    deleted_count INTEGER := 0;
BEGIN
    cutoff_date := current_date - (retention_months || ' months')::interval;
    
    -- Lösche alte Activity Logs
    DELETE FROM audit.activity_log WHERE logged_at::date < cutoff_date;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Lösche alte Security Events
    DELETE FROM audit.security_events WHERE occurred_at::date < cutoff_date;
    
    -- Lösche abgeschlossene Sessions
    DELETE FROM audit.session_log 
    WHERE logout_time IS NOT NULL 
    AND logout_time::date < cutoff_date;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Funktion zur Erkennung verdächtiger Aktivitäten
CREATE OR REPLACE FUNCTION audit.detect_suspicious_activity()
RETURNS TABLE (
    alert_type TEXT,
    user_name TEXT,
    client_ip INET,
    description TEXT,
    severity TEXT,
    event_count BIGINT
) AS $$
BEGIN
    -- Mehrfache fehlgeschlagene Logins
    RETURN QUERY
    SELECT 
        'MULTIPLE_LOGIN_FAILURES'::TEXT,
        se.user_name,
        se.client_ip,
        'Multiple login failures within 1 hour'::TEXT,
        'HIGH'::TEXT,
        count(*)
    FROM audit.security_events se
    WHERE se.event_type = 'LOGIN_FAILED'
    AND se.occurred_at > NOW() - interval '1 hour'
    GROUP BY se.user_name, se.client_ip
    HAVING count(*) >= 5;
    
    -- Ungewöhnliche Query-Patterns
    RETURN QUERY
    SELECT 
        'UNUSUAL_QUERY_PATTERN'::TEXT,
        al.user_name,
        al.client_ip,
        'High volume of queries in short time'::TEXT,
        'MEDIUM'::TEXT,
        count(*)
    FROM audit.activity_log al
    WHERE al.logged_at > NOW() - interval '10 minutes'
    GROUP BY al.user_name, al.client_ip
    HAVING count(*) > 1000;
    
    -- Zugriff auf sensible Tabellen außerhalb der Geschäftszeiten
    RETURN QUERY
    SELECT 
        'OFF_HOURS_SENSITIVE_ACCESS'::TEXT,
        al.user_name,
        al.client_ip,
        'Access to sensitive data outside business hours'::TEXT,
        'HIGH'::TEXT,
        count(*)
    FROM audit.activity_log al
    WHERE al.logged_at > NOW() - interval '1 hour'
    AND (EXTRACT(hour FROM al.logged_at) < 8 OR EXTRACT(hour FROM al.logged_at) > 18)
    AND EXISTS (
        SELECT 1 FROM unnest(al.table_names) AS tn(table_name)
        WHERE tn.table_name ILIKE '%customer%' 
        OR tn.table_name ILIKE '%payment%'
        OR tn.table_name ILIKE '%sensitive%'
    )
    GROUP BY al.user_name, al.client_ip
    HAVING count(*) > 0;
END;
$$ LANGUAGE plpgsql;

-- Berechtigungen für Audit-Schema
GRANT USAGE ON SCHEMA audit TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA audit TO PUBLIC;

-- Nur Superuser können Audit-Daten modifizieren
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA audit FROM PUBLIC;

COMMENT ON SCHEMA audit IS 'ExaPG Audit Logging System für Compliance und Sicherheit';
COMMENT ON FUNCTION audit.log_activity IS 'Protokolliert Datenbankaktivitäten für Audit-Zwecke';
COMMENT ON FUNCTION audit.log_security_event IS 'Protokolliert Sicherheitsereignisse';
COMMENT ON FUNCTION audit.generate_compliance_report IS 'Generiert Compliance-Reports für Audits';
COMMENT ON FUNCTION audit.detect_suspicious_activity IS 'Erkennt verdächtige Aktivitäten automatisch'; 