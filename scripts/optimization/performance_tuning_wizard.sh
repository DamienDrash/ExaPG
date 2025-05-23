#!/bin/bash
# ExaPG Performance Tuning Wizard
# Automatische Optimierung basierend auf Hardware und Workload

# Farbdefinitionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_message() {
    echo -e "${BLUE}[Tuning]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Tuning]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[Tuning]${NC} $1"
}

print_error() {
    echo -e "${RED}[Tuning]${NC} $1"
}

# System-Analyse
analyze_system() {
    print_message "Analysiere System-Hardware..."
    
    # CPU Information
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
    CPU_MODEL=$(lscpu | grep 'Model name:' | cut -d':' -f2 | sed 's/^ *//')
    
    # Memory Information
    TOTAL_RAM=$(free -g | grep '^Mem:' | awk '{print $2}')
    AVAILABLE_RAM=$(free -g | grep '^Mem:' | awk '{print $7}')
    
    # Storage Information
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $2}')
    DISK_TYPE=$(lsblk -o NAME,ROTA | grep -v NAME | head -1 | awk '{print $2}')
    
    # Network Information
    NETWORK_SPEED=$(ethtool eth0 2>/dev/null | grep Speed | awk '{print $2}' || echo "Unknown")
    
    print_success "System-Analyse abgeschlossen:"
    echo "  CPU: $CPU_MODEL ($CPU_CORES Cores, $CPU_THREADS Threads)"
    echo "  RAM: ${TOTAL_RAM}GB total, ${AVAILABLE_RAM}GB verfügbar"
    echo "  Speicher: $DISK_SPACE ($( [ "$DISK_TYPE" = "0" ] && echo "SSD" || echo "HDD" ))"
    echo "  Netzwerk: $NETWORK_SPEED"
    echo ""
}

# Workload-Analyse
analyze_workload() {
    print_message "Analysiere Datenbank-Workload..."
    
    # Checke ob PostgreSQL läuft
    if ! docker ps | grep -q exapg-coordinator; then
        print_warning "ExaPG-Container läuft nicht. Starte für Workload-Analyse..."
        docker-compose -f docker/docker-compose/docker-compose.yml up -d coordinator
        sleep 10
    fi
    
    # Führe Workload-Analyse durch
    cat > /tmp/workload_analysis.sql << 'EOF'
-- Workload-Analyse Queries
SELECT 
    'Query Performance' as metric,
    ROUND(AVG(total_time)::numeric, 2) as avg_time_ms,
    COUNT(*) as query_count
FROM pg_stat_statements 
WHERE total_time > 0;

SELECT 
    'Most Time Consuming Queries' as analysis,
    LEFT(query, 80) as query_sample,
    ROUND(total_time::numeric, 2) as total_time_ms,
    calls,
    ROUND((total_time/calls)::numeric, 2) as avg_time_ms
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 5;

SELECT 
    'Table Sizes' as analysis,
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;

SELECT 
    'Index Usage' as analysis,
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC 
LIMIT 10;
EOF

    docker exec exapg-coordinator psql -U postgres -d postgres -f /tmp/workload_analysis.sql > /tmp/workload_results.txt 2>/dev/null || true
    
    if [ -f /tmp/workload_results.txt ]; then
        print_success "Workload-Analyse abgeschlossen"
        WORKLOAD_TYPE="analytical"  # Default
        
        # Analysiere Workload-Typ basierend auf Ergebnissen
        if grep -q "INSERT\|UPDATE\|DELETE" /tmp/workload_results.txt; then
            WORKLOAD_TYPE="mixed"
        fi
        
        print_message "Erkannter Workload-Typ: $WORKLOAD_TYPE"
    else
        print_warning "Workload-Analyse nicht möglich, verwende Standard-Einstellungen"
        WORKLOAD_TYPE="analytical"
    fi
}

# PostgreSQL-Parameter optimieren
optimize_postgresql_config() {
    print_message "Optimiere PostgreSQL-Konfiguration für $WORKLOAD_TYPE Workload..."
    
    # Berechne optimale Werte basierend auf Hardware
    SHARED_BUFFERS_GB=$((TOTAL_RAM / 4))
    WORK_MEM_MB=$((TOTAL_RAM * 1024 / (CPU_CORES * 4)))
    MAINTENANCE_WORK_MEM_GB=$((TOTAL_RAM / 8))
    EFFECTIVE_CACHE_SIZE_GB=$((TOTAL_RAM * 3 / 4))
    
    # Max Connections basierend auf RAM
    MAX_CONNECTIONS=$((TOTAL_RAM * 10))
    if [ $MAX_CONNECTIONS -gt 200 ]; then
        MAX_CONNECTIONS=200
    fi
    
    # Max Worker Processes
    MAX_WORKERS=$((CPU_CORES * 2))
    if [ $MAX_WORKERS -gt 32 ]; then
        MAX_WORKERS=32
    fi
    
    # Checkpoint-Einstellungen basierend auf Storage-Typ
    if [ "$DISK_TYPE" = "0" ]; then  # SSD
        CHECKPOINT_COMPLETION_TARGET="0.9"
        WAL_BUFFERS="16MB"
        RANDOM_PAGE_COST="1.1"
    else  # HDD
        CHECKPOINT_COMPLETION_TARGET="0.7"
        WAL_BUFFERS="8MB"
        RANDOM_PAGE_COST="4.0"
    fi
    
    # Erstelle optimierte Konfiguration
    cat > /tmp/postgresql_optimized.conf << EOF
# ExaPG Performance-optimierte Konfiguration
# Generiert von Performance Tuning Wizard

# Memory Settings
shared_buffers = ${SHARED_BUFFERS_GB}GB
work_mem = ${WORK_MEM_MB}MB
maintenance_work_mem = ${MAINTENANCE_WORK_MEM_GB}GB
effective_cache_size = ${EFFECTIVE_CACHE_SIZE_GB}GB

# Connection Settings
max_connections = $MAX_CONNECTIONS

# Parallel Processing
max_worker_processes = $MAX_WORKERS
max_parallel_workers = $MAX_WORKERS
max_parallel_workers_per_gather = $((CPU_CORES / 2))
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1

# Storage Optimization
random_page_cost = $RANDOM_PAGE_COST
seq_page_cost = 1.0
effective_io_concurrency = $((CPU_CORES * 2))

# WAL Settings
wal_buffers = $WAL_BUFFERS
checkpoint_completion_target = $CHECKPOINT_COMPLETION_TARGET
wal_writer_delay = 200ms

# Query Planner
default_statistics_target = 100
constraint_exclusion = partition

# JIT Compilation
jit = on
jit_above_cost = 100000
jit_inline_above_cost = 500000
jit_optimize_above_cost = 500000

# Logging
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on

# Autovacuum Tuning
autovacuum = on
autovacuum_max_workers = $((CPU_CORES / 2))
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50

# Additional Analytics Optimizations
EOF

    if [ "$WORKLOAD_TYPE" = "analytical" ]; then
        cat >> /tmp/postgresql_optimized.conf << EOF

# Analytical Workload Optimizations
enable_hashagg = on
enable_hashjoin = on
enable_nestloop = off
enable_mergejoin = on
hash_mem_multiplier = 2.0
max_parallel_maintenance_workers = $((CPU_CORES / 2))
EOF
    fi
    
    print_success "PostgreSQL-Konfiguration optimiert"
    
    # Backup der aktuellen Konfiguration
    if [ -f config/postgresql/postgresql.conf ]; then
        cp config/postgresql/postgresql.conf config/postgresql/postgresql.conf.backup.$(date +%Y%m%d_%H%M%S)
        print_message "Backup der aktuellen Konfiguration erstellt"
    fi
    
    # Neue Konfiguration anwenden
    cp /tmp/postgresql_optimized.conf config/postgresql/postgresql.conf
    print_success "Neue Konfiguration angewendet"
}

# Citus-spezifische Optimierungen
optimize_citus_config() {
    if [ "$1" = "citus" ]; then
        print_message "Optimiere Citus-spezifische Parameter..."
        
        cat >> config/postgresql/postgresql.conf << EOF

# Citus-specific optimizations
citus.max_worker_nodes_tracked = $((CPU_CORES * 4))
citus.executor_type = 'adaptive'
citus.task_executor_type = 'adaptive'
citus.max_adaptive_executor_pool_size = $CPU_CORES
citus.enable_repartition_joins = on
citus.enable_fast_path_router_planner = on
citus.log_multi_join_order = on
citus.limit_clause_row_fetch_count = 100000
EOF
        
        print_success "Citus-Konfiguration optimiert"
    fi
}

# Index-Empfehlungen generieren
generate_index_recommendations() {
    print_message "Generiere Index-Empfehlungen..."
    
    cat > /tmp/index_analysis.sql << 'EOF'
-- Fehlende Indizes basierend auf Query-Patterns
WITH missing_indexes AS (
    SELECT 
        schemaname,
        tablename,
        seq_scan,
        seq_tup_read,
        seq_tup_read / seq_scan as avg_seq_read
    FROM pg_stat_user_tables 
    WHERE seq_scan > 0
        AND seq_tup_read / seq_scan > 1000
),
unused_indexes AS (
    SELECT 
        schemaname,
        tablename,
        indexname,
        idx_scan
    FROM pg_stat_user_indexes 
    WHERE idx_scan < 10
)
SELECT 'Missing Indexes' as recommendation_type,
       'CREATE INDEX ON ' || schemaname || '.' || tablename || ' (column_name);' as recommendation
FROM missing_indexes
UNION ALL
SELECT 'Unused Indexes' as recommendation_type,
       'DROP INDEX ' || schemaname || '.' || indexname || ';' as recommendation  
FROM unused_indexes;
EOF

    docker exec exapg-coordinator psql -U postgres -d postgres -f /tmp/index_analysis.sql > /tmp/index_recommendations.txt 2>/dev/null || true
    
    if [ -f /tmp/index_recommendations.txt ] && [ -s /tmp/index_recommendations.txt ]; then
        print_success "Index-Empfehlungen generiert:"
        cat /tmp/index_recommendations.txt
    else
        print_message "Keine spezifischen Index-Empfehlungen verfügbar"
    fi
}

# Monitoring-Setup optimieren
optimize_monitoring() {
    print_message "Optimiere Monitoring-Konfiguration..."
    
    # pg_stat_statements aktivieren
    cat >> config/postgresql/postgresql.conf << EOF

# Monitoring and Statistics
shared_preload_libraries = 'pg_stat_statements,citus'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.track_utility = on
pg_stat_statements.save = on
track_activity_query_size = 2048
track_io_timing = on
EOF

    print_success "Monitoring-Konfiguration optimiert"
}

# Hauptfunktion
main() {
    echo ""
    echo -e "${BOLD}${BLUE}ExaPG Performance Tuning Wizard${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo ""
    
    # System analysieren
    analyze_system
    
    # Workload analysieren
    analyze_workload
    
    # Deployment-Typ erfragen
    echo -e "${YELLOW}Welchen Deployment-Typ optimieren Sie?${NC}"
    echo "1) Standard PostgreSQL"
    echo "2) Citus Cluster"
    echo "3) Hochverfügbarkeits-Setup"
    read -p "Auswahl [1-3]: " deployment_choice
    
    case $deployment_choice in
        2) DEPLOYMENT_TYPE="citus" ;;
        3) DEPLOYMENT_TYPE="ha" ;;
        *) DEPLOYMENT_TYPE="standard" ;;
    esac
    
    print_message "Optimiere für: $DEPLOYMENT_TYPE deployment"
    
    # Konfigurationen optimieren
    optimize_postgresql_config
    
    if [ "$DEPLOYMENT_TYPE" = "citus" ]; then
        optimize_citus_config "citus"
    fi
    
    optimize_monitoring
    
    # Index-Empfehlungen
    generate_index_recommendations
    
    echo ""
    print_success "Performance-Optimierung abgeschlossen!"
    echo ""
    echo -e "${YELLOW}Nächste Schritte:${NC}"
    echo "1. Starten Sie ExaPG neu, um die Konfiguration zu aktivieren:"
    echo "   docker-compose restart"
    echo ""
    echo "2. Überwachen Sie die Performance über Grafana:"
    echo "   http://localhost:3000"
    echo ""
    echo "3. Führen Sie regelmäßige Analysen durch:"
    echo "   ./scripts/optimization/performance_tuning_wizard.sh"
    echo ""
    
    # Neustart anbieten
    read -p "Möchten Sie ExaPG jetzt neu starten? [j/N]: " restart_choice
    if [[ "$restart_choice" =~ ^[jJ]$ ]]; then
        print_message "Starte ExaPG mit neuer Konfiguration neu..."
        docker-compose -f docker/docker-compose/docker-compose.yml restart
        print_success "ExaPG wurde mit optimierter Konfiguration neu gestartet!"
    fi
}

# Skript ausführen
main "$@" 