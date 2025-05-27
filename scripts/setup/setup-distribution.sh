#!/bin/bash
# ExaPG Cluster Distribution Setup Script
# Automatische Konfiguration der Citus-Cluster-Verteilung

set -e

echo "🔧 ExaPG Cluster Distribution Setup"
echo "⏰ $(date)"

# Umgebungsvariablen
COORDINATOR_HOST=${COORDINATOR_HOST:-coordinator}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-postgres}

# Funktion für PostgreSQL-Befehle
execute_sql() {
    local sql="$1"
    echo "📝 Executing: $sql"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$COORDINATOR_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql"
}

echo "🚀 Starte Cluster-Setup..."

# 1. Citus-Extension aktivieren
echo "✅ Aktiviere Citus-Extension..."
execute_sql "CREATE EXTENSION IF NOT EXISTS citus;"

# 2. Worker-Nodes hinzufügen
echo "✅ Füge Worker-Nodes hinzu..."
execute_sql "SELECT citus_add_node('worker-1', 5432);" || echo "⚠️ Worker-1 bereits hinzugefügt oder nicht erreichbar"
execute_sql "SELECT citus_add_node('worker-2', 5432);" || echo "⚠️ Worker-2 bereits hinzugefügt oder nicht erreichbar"

# 3. Cluster-Status überprüfen
echo "✅ Überprüfe Cluster-Status..."
execute_sql "SELECT * FROM citus_get_active_worker_nodes();"

# 4. Test-Tabelle für verteilte Daten erstellen
echo "✅ Erstelle Test-Tabelle für Analytics..."
execute_sql "CREATE TABLE IF NOT EXISTS analytics_demo (
    id BIGSERIAL,
    user_id BIGINT,
    event_type TEXT,
    event_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);"

# 5. Tabelle verteilen (falls Worker verfügbar)
echo "✅ Verteile Tabelle (falls Worker verfügbar)..."
execute_sql "SELECT create_distributed_table('analytics_demo', 'user_id');" || echo "⚠️ Tabelle nicht verteilt - läuft als Single-Node"

# 6. Sample-Daten einfügen
echo "✅ Füge Sample-Daten ein..."
execute_sql "INSERT INTO analytics_demo (user_id, event_type, event_data) VALUES 
    (1, 'login', '{\"ip\": \"192.168.1.1\", \"browser\": \"Chrome\"}'),
    (2, 'purchase', '{\"amount\": 99.99, \"product\": \"Analytics License\"}'),
    (3, 'view', '{\"page\": \"/dashboard\", \"duration\": 45}'),
    (1, 'logout', '{\"session_duration\": 1800}');"

echo "🎉 Cluster-Setup abgeschlossen!"
echo "📊 Verwende: SELECT * FROM analytics_demo; zum Testen" 