#!/bin/bash
set -e

# ExaPG Simple Analytics Initialization Script
# PostgreSQL 15 mit Analytics-Extensions (ohne Citus)

echo "🚀 Initialisiere ExaPG Simple Analytics System..."

# Warte bis PostgreSQL bereit ist
until pg_isready -U postgres; do
  echo "Warte auf PostgreSQL..."
  sleep 2
done

echo "✓ PostgreSQL ist bereit"

# Erstelle Extensions und Analytics-Schema
psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
    -- Erstelle Analytics Extensions
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
    CREATE EXTENSION IF NOT EXISTS btree_gin;
    CREATE EXTENSION IF NOT EXISTS btree_gist;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS uuid-ossp;
    CREATE EXTENSION IF NOT EXISTS hstore;
    
    -- Erstelle Analytics-Schema
    CREATE SCHEMA IF NOT EXISTS analytics;
    CREATE SCHEMA IF NOT EXISTS etl;
    CREATE SCHEMA IF NOT EXISTS monitoring;
    
    -- Erstelle Demo Analytics Tabelle
    CREATE TABLE IF NOT EXISTS analytics.demo_events (
        id BIGSERIAL PRIMARY KEY,
        event_type VARCHAR(50) NOT NULL,
        user_id INTEGER,
        session_id UUID,
        event_data JSONB,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Erstelle Metrics Tabelle
    CREATE TABLE IF NOT EXISTS analytics.demo_metrics (
        id BIGSERIAL PRIMARY KEY,
        metric_name VARCHAR(100),
        metric_value NUMERIC,
        tags JSONB,
        timestamp TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Erstelle Event Types Lookup Tabelle
    CREATE TABLE IF NOT EXISTS analytics.event_types (
        id SERIAL PRIMARY KEY,
        name VARCHAR(50) UNIQUE NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Füge Demo-Daten ein
    INSERT INTO analytics.event_types (name, description) VALUES
        ('login', 'User login event'),
        ('logout', 'User logout event'),
        ('page_view', 'Page view event'),
        ('purchase', 'Purchase event')
    ON CONFLICT (name) DO NOTHING;
    
    INSERT INTO analytics.demo_events (event_type, user_id, session_id, event_data) VALUES
        ('login', 1001, gen_random_uuid(), '{"ip": "192.168.1.100", "browser": "Chrome"}'),
        ('page_view', 1001, gen_random_uuid(), '{"page": "/dashboard", "duration": 45}'),
        ('purchase', 1002, gen_random_uuid(), '{"product_id": 123, "amount": 99.99}'),
        ('logout', 1001, gen_random_uuid(), '{"session_duration": 1800}')
    ON CONFLICT DO NOTHING;
    
    INSERT INTO analytics.demo_metrics (metric_name, metric_value, tags) VALUES
        ('cpu_usage', 75.5, '{"host": "server1", "region": "eu-west"}'),
        ('memory_usage', 82.3, '{"host": "server1", "region": "eu-west"}'),
        ('response_time', 245, '{"endpoint": "/api/users", "method": "GET"}'),
        ('error_rate', 0.02, '{"service": "auth", "environment": "prod"}')
    ON CONFLICT DO NOTHING;
    
    -- Erstelle Indizes für Performance
    CREATE INDEX IF NOT EXISTS idx_demo_events_type ON analytics.demo_events(event_type);
    CREATE INDEX IF NOT EXISTS idx_demo_events_user ON analytics.demo_events(user_id);
    CREATE INDEX IF NOT EXISTS idx_demo_events_created ON analytics.demo_events(created_at);
    CREATE INDEX IF NOT EXISTS idx_demo_events_data ON analytics.demo_events USING GIN(event_data);
    CREATE INDEX IF NOT EXISTS idx_demo_metrics_name ON analytics.demo_metrics(metric_name);
    CREATE INDEX IF NOT EXISTS idx_demo_metrics_timestamp ON analytics.demo_metrics(timestamp);
    CREATE INDEX IF NOT EXISTS idx_demo_metrics_tags ON analytics.demo_metrics USING GIN(tags);
    
    -- Erstelle Views für Analytics
    CREATE OR REPLACE VIEW analytics.event_summary AS
    SELECT 
        event_type,
        COUNT(*) as event_count,
        COUNT(DISTINCT user_id) as unique_users,
        MIN(created_at) as first_event,
        MAX(created_at) as last_event
    FROM analytics.demo_events
    GROUP BY event_type;
    
    CREATE OR REPLACE VIEW analytics.user_activity AS
    SELECT 
        user_id,
        COUNT(*) as total_events,
        COUNT(DISTINCT event_type) as event_types,
        MIN(created_at) as first_activity,
        MAX(created_at) as last_activity
    FROM analytics.demo_events
    WHERE user_id IS NOT NULL
    GROUP BY user_id;
    
    CREATE OR REPLACE VIEW analytics.metrics_summary AS
    SELECT 
        metric_name,
        COUNT(*) as measurement_count,
        AVG(metric_value) as avg_value,
        MIN(metric_value) as min_value,
        MAX(metric_value) as max_value,
        MIN(timestamp) as first_measurement,
        MAX(timestamp) as last_measurement
    FROM analytics.demo_metrics
    GROUP BY metric_name;
    
    -- Erstelle Partitionierte Tabelle für Time-Series
    CREATE TABLE IF NOT EXISTS analytics.time_series_data (
        id BIGSERIAL,
        timestamp TIMESTAMPTZ NOT NULL,
        metric_name VARCHAR(100) NOT NULL,
        value NUMERIC NOT NULL,
        tags JSONB,
        PRIMARY KEY (id, timestamp)
    ) PARTITION BY RANGE (timestamp);
    
    -- Erstelle Partitionen für aktuelle und nächste Monate
    CREATE TABLE IF NOT EXISTS analytics.time_series_data_current PARTITION OF analytics.time_series_data
    FOR VALUES FROM (date_trunc('month', CURRENT_DATE)) TO (date_trunc('month', CURRENT_DATE + INTERVAL '1 month'));
    
    CREATE TABLE IF NOT EXISTS analytics.time_series_data_next PARTITION OF analytics.time_series_data
    FOR VALUES FROM (date_trunc('month', CURRENT_DATE + INTERVAL '1 month')) TO (date_trunc('month', CURRENT_DATE + INTERVAL '2 months'));
    
    -- Zeige System-Status
    SELECT 'ExaPG Simple Analytics System erfolgreich initialisiert!' as status;
    SELECT version() as postgresql_version;
    
    -- Zeige verfügbare Extensions
    SELECT name, default_version, installed_version 
    FROM pg_available_extensions 
    WHERE installed_version IS NOT NULL
    ORDER BY name;
    
    -- Zeige verfügbare Tabellen
    SELECT schemaname, tablename, tableowner 
    FROM pg_tables 
    WHERE schemaname IN ('analytics', 'etl', 'monitoring')
    ORDER BY schemaname, tablename;
    
EOSQL

echo "✅ ExaPG Simple Analytics System erfolgreich initialisiert!"
echo "📊 Analytics-Schema erstellt mit Demo-Daten"
echo "🗂️  Partitionierte Time-Series-Tabellen konfiguriert"
echo "📈 Analytics Views für Reporting verfügbar"
echo "🚀 System bereit für Analytics-Workloads!" 