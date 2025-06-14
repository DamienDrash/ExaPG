#!/bin/bash
set -e

# ExaPG Single-Node Citus Initialization Script
# Optimiert für Single-Node Analytics mit permanenten Fixes

echo "🚀 Initialisiere ExaPG Single-Node Analytics Cluster..."

# Warte bis PostgreSQL bereit ist
until pg_isready -U postgres; do
  echo "Warte auf PostgreSQL..."
  sleep 2
done

echo "✓ PostgreSQL ist bereit"

# Erstelle Citus Extension
psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
    -- Erstelle Citus Extension
    CREATE EXTENSION IF NOT EXISTS citus;
    
    -- Erstelle zusätzliche Extensions für Analytics
    CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
    CREATE EXTENSION IF NOT EXISTS btree_gin;
    CREATE EXTENSION IF NOT EXISTS btree_gist;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS uuid-ossp;
    
    -- Setze Single-Node Citus Konfiguration
    ALTER SYSTEM SET citus.node_conninfo = 'sslmode=disable';
    ALTER SYSTEM SET citus.shard_count = 4;
    ALTER SYSTEM SET citus.shard_replication_factor = 1;
    ALTER SYSTEM SET citus.node_connection_timeout = 30000;
    ALTER SYSTEM SET citus.max_worker_nodes_tracked = 32;
    
    -- Lade Konfiguration neu
    SELECT pg_reload_conf();
    
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
    
    -- Erstelle Columnar Demo Tabelle
    CREATE TABLE IF NOT EXISTS analytics.demo_metrics (
        id BIGSERIAL,
        metric_name VARCHAR(100),
        metric_value NUMERIC,
        tags JSONB,
        timestamp TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Setze Columnar Storage für Metrics
    SELECT alter_table_set_access_method('analytics.demo_metrics', 'columnar');
    
    -- Erstelle Reference Table für Lookups
    CREATE TABLE IF NOT EXISTS analytics.event_types (
        id SERIAL PRIMARY KEY,
        name VARCHAR(50) UNIQUE NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Mache event_types zu einer Reference Table
    SELECT create_reference_table('analytics.event_types');
    
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
    
    -- Zeige Cluster-Status
    SELECT 'ExaPG Single-Node Analytics Cluster erfolgreich initialisiert!' as status;
    SELECT version() as postgresql_version;
    SELECT citus_version() as citus_version;
    
    -- Zeige verfügbare Tabellen
    SELECT schemaname, tablename, tableowner 
    FROM pg_tables 
    WHERE schemaname IN ('analytics', 'etl', 'monitoring')
    ORDER BY schemaname, tablename;
    
EOSQL

echo "✅ ExaPG Single-Node Analytics Cluster erfolgreich initialisiert!"
echo "📊 Analytics-Schema erstellt mit Demo-Daten"
echo "🗂️  Columnar Storage für Metrics aktiviert"
echo "🔗 Reference Tables für Lookups konfiguriert"
echo "🚀 System bereit für Analytics-Workloads!" 