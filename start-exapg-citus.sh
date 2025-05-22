#!/bin/bash
# ExaPG - Start Citus Cluster
# Skript zum Starten des ExaPG-Systems mit Citus für optimierte Datenverteilung

set -e

# Prüfen, ob Docker und Docker Compose installiert sind
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    echo "Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut."
    exit 1
fi

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Erstellen der PostgreSQL-Konfigurationsdateien, falls nicht vorhanden
mkdir -p config/postgresql

# Erstellen der PostgreSQL-Konfiguration für den Coordinator
if [ ! -f config/postgresql/postgresql-coordinator.conf ]; then
    cat > config/postgresql/postgresql-coordinator.conf << EOF
# Basiseinstellungen
listen_addresses = '*'
shared_preload_libraries = 'citus'

# Speicher und Verbindungen
shared_buffers = 1GB
max_connections = 100
work_mem = 32MB
maintenance_work_mem = 256MB

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
log_statement = 'ddl'
log_min_duration_statement = 1000

# Citus-spezifische Einstellungen (Coordinator)
citus.shard_count = 32
citus.shard_replication_factor = 1
citus.enable_repartition_joins = on
citus.node_connection_timeout = 10000
citus.max_adaptive_executor_pool_size = 16
citus.log_remote_commands = on
citus.coordinator_aggregation_strategy = 'row-gather'
citus.task_assignment_policy = 'greedy'

# Optimierte parallele Verarbeitung
max_worker_processes = 32
max_parallel_workers_per_gather = 8
max_parallel_workers = 16
max_parallel_maintenance_workers = 4
parallel_setup_cost = 100
parallel_tuple_cost = 0.01
min_parallel_table_scan_size = 8MB
min_parallel_index_scan_size = 512kB
EOF
fi

# Erstellen der PostgreSQL-Konfiguration für Worker-Nodes
if [ ! -f config/postgresql/postgresql-worker.conf ]; then
    cat > config/postgresql/postgresql-worker.conf << EOF
# Basiseinstellungen
listen_addresses = '*'
shared_preload_libraries = 'citus'

# Speicher und Verbindungen
shared_buffers = 1GB
max_connections = 100
work_mem = 32MB
maintenance_work_mem = 256MB

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
log_statement = 'ddl'
log_min_duration_statement = 1000

# Citus-spezifische Einstellungen (Worker)
citus.shard_count = 32
citus.shard_replication_factor = 1
citus.enable_repartition_joins = on
citus.node_connection_timeout = 10000
citus.max_adaptive_executor_pool_size = 16
citus.log_remote_commands = on

# Optimierte parallele Verarbeitung
max_worker_processes = 32
max_parallel_workers_per_gather = 8
max_parallel_workers = 16
max_parallel_maintenance_workers = 4
parallel_setup_cost = 100
parallel_tuple_cost = 0.01
min_parallel_table_scan_size = 8MB
min_parallel_index_scan_size = 512kB
EOF
fi

# Erstellen der pg_hba.conf, falls nicht vorhanden
if [ ! -f config/postgresql/pg_hba.conf ]; then
    cat > config/postgresql/pg_hba.conf << EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
host    all             all             0.0.0.0/0               md5
EOF
fi

# Skript ausführbar machen
chmod +x scripts/setup/setup-distribution.sh

echo "Starte ExaPG mit Citus für optimierte Datenverteilung..."

# Docker-Compose-Datei für Citus auswählen und starten
if command -v docker compose >/dev/null 2>&1; then
    docker compose -f docker/docker-compose/docker-compose.citus.yml up -d
else
    # Fallback auf altes docker-compose
    docker-compose -f docker/docker-compose/docker-compose.citus.yml up -d
fi

echo "Das ExaPG Citus-Cluster wurde gestartet!"
echo "=================="
echo "Coordinator läuft auf: localhost:5432"
echo "Benutzer: ${POSTGRES_USER:-postgres}"
echo "Passwort: ${POSTGRES_PASSWORD:-postgres}"
echo "Datenbank: ${POSTGRES_DB:-postgres}"
echo "=================="
echo "Ein 3-Knoten-Cluster mit 1 Coordinator und 2 Worker-Nodes ist nun aktiv."
echo "Die optimierten Datenverteilungsstrategien werden automatisch angewendet."
echo "Zum Stoppen des Clusters, führen Sie den folgenden Befehl aus:"
echo "docker compose -f docker/docker-compose/docker-compose.citus.yml down"
echo "" 