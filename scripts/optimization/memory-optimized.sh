#!/bin/bash
# In-Memory-Optimierung für analytische Workloads in ExaPG
# Dieses Skript konfiguriert PostgreSQL für maximale In-Memory-Performance

set -e

echo "Optimiere PostgreSQL für In-Memory-Verarbeitung..."

# Feste Werte für Container-Umgebung
# In einer realen Umgebung würden wir hier den verfügbaren RAM ermitteln
shared_buffers=4096        # 4GB 
effective_cache_size=8192  # 8GB
work_mem=1024              # 1GB
maint_work_mem=2048        # 2GB

echo "Konfiguration: shared_buffers=${shared_buffers}MB, work_mem=${work_mem}MB"

# Anwenden der Optimierungen
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Speichernutzung optimieren
    ALTER SYSTEM SET shared_buffers = '${shared_buffers}MB';
    ALTER SYSTEM SET effective_cache_size = '${effective_cache_size}MB';
    ALTER SYSTEM SET work_mem = '${work_mem}MB';
    ALTER SYSTEM SET maintenance_work_mem = '${maint_work_mem}MB';
    
    -- JIT-Optimierung für analytische Abfragen
    ALTER SYSTEM SET jit = on;
    ALTER SYSTEM SET jit_above_cost = 10000;        -- Aggressiverer Einsatz von JIT
    ALTER SYSTEM SET jit_inline_above_cost = 15000; -- Zusätzliche Optimierungen
    ALTER SYSTEM SET jit_optimize_above_cost = 15000;
    
    -- Parallele Verarbeitung optimieren
    ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
    ALTER SYSTEM SET max_parallel_workers = 8;
    ALTER SYSTEM SET max_parallel_maintenance_workers = 4;
    
    -- Planner-Optimierungen für analytische Abfragen
    ALTER SYSTEM SET random_page_cost = 1.1;         -- SSD/NVMe-optimiert
    ALTER SYSTEM SET effective_io_concurrency = 200; -- Hoher Wert für SSDs
    ALTER SYSTEM SET default_statistics_target = 500; -- Genauere Statistiken für den Planner
    
    -- Weitere Optimierungen
    ALTER SYSTEM SET synchronous_commit = 'off';     -- Performance über Durability stellen
    ALTER SYSTEM SET wal_buffers = '16MB';           -- Größerer WAL-Puffer
    ALTER SYSTEM SET checkpoint_timeout = '30min';   -- Seltenere Checkpoints
    ALTER SYSTEM SET checkpoint_completion_target = 0.9; -- Sanftere Checkpoints
EOSQL

echo "In-Memory-Optimierung abgeschlossen. Führe 'SELECT pg_reload_conf();' aus, um die Änderungen zu aktivieren."
echo "Hinweis: Einige Einstellungen benötigen einen Neustart der Datenbank." 