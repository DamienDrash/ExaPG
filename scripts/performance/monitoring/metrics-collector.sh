#!/bin/bash
# ===================================================================
# ExaPG Performance Metrics Collector
# ===================================================================
# PERFORMANCE FIX: PERF-002 - Real-time Performance Monitoring
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly METRICS_DIR="$PROJECT_ROOT/benchmark/metrics"

# Database connection
readonly DB_HOST="${POSTGRES_HOST:-localhost}"
readonly DB_PORT="${POSTGRES_PORT:-5432}"
readonly DB_NAME="${POSTGRES_DB:-exadb}"
readonly DB_USER="${POSTGRES_USER:-postgres}"

# Collection parameters
readonly COLLECTION_INTERVAL="${METRICS_INTERVAL:-60}"  # seconds
readonly RETENTION_DAYS="${METRICS_RETENTION:-30}"      # days
readonly OUTPUT_FORMAT="${METRICS_FORMAT:-json}"        # json, csv, prometheus

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [METRICS] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [METRICS] [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [METRICS] [SUCCESS] $*" >&2
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Setup directories
setup_directories() {
    mkdir -p "$METRICS_DIR/current"
    mkdir -p "$METRICS_DIR/historical"
    mkdir -p "$METRICS_DIR/alerts"
}

# Check database connectivity
check_database() {
    if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Cannot connect to database: $DB_HOST:$DB_PORT/$DB_NAME"
        return 1
    fi
}

# ===================================================================
# METRICS COLLECTION
# ===================================================================

# Collect PostgreSQL performance metrics
collect_postgres_metrics() {
    local timestamp=$(date -Iseconds)
    local metrics_file="$METRICS_DIR/current/postgres_$(date +%Y%m%d_%H%M%S).json"
    
    log "Collecting PostgreSQL performance metrics..."
    
    # Execute metrics queries and format as JSON
    cat << 'EOF' | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' > /tmp/metrics_raw_$$
-- Database-level metrics
SELECT 'database_stats' as metric_type,
       datname,
       numbackends,
       xact_commit,
       xact_rollback,
       blks_read,
       blks_hit,
       tup_returned,
       tup_fetched,
       tup_inserted,
       tup_updated,
       tup_deleted,
       conflicts,
       temp_files,
       temp_bytes,
       deadlocks,
       blk_read_time,
       blk_write_time,
       stats_reset
FROM pg_stat_database 
WHERE datname = current_database();

-- Connection metrics
SELECT 'connection_stats' as metric_type,
       state,
       COUNT(*) as count
FROM pg_stat_activity
WHERE state IS NOT NULL
GROUP BY state;

-- Table-level metrics for top 10 tables by activity
SELECT 'table_stats' as metric_type,
       schemaname,
       relname,
       seq_scan,
       seq_tup_read,
       idx_scan,
       idx_tup_fetch,
       n_tup_ins,
       n_tup_upd,
       n_tup_del,
       n_tup_hot_upd,
       n_live_tup,
       n_dead_tup,
       n_mod_since_analyze,
       last_vacuum,
       last_autovacuum,
       last_analyze,
       last_autoanalyze,
       vacuum_count,
       autovacuum_count,
       analyze_count,
       autoanalyze_count
FROM pg_stat_user_tables
ORDER BY (seq_tup_read + idx_tup_fetch) DESC
LIMIT 10;

-- Index usage metrics
SELECT 'index_stats' as metric_type,
       schemaname,
       tablename,
       indexname,
       idx_scan,
       idx_tup_read,
       idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan > 0
ORDER BY idx_scan DESC
LIMIT 20;

-- Lock metrics
SELECT 'lock_stats' as metric_type,
       mode,
       COUNT(*) as count
FROM pg_locks
GROUP BY mode;

-- Background writer metrics
SELECT 'bgwriter_stats' as metric_type,
       checkpoints_timed,
       checkpoints_req,
       checkpoint_write_time,
       checkpoint_sync_time,
       buffers_checkpoint,
       buffers_clean,
       maxwritten_clean,
       buffers_backend,
       buffers_backend_fsync,
       buffers_alloc,
       stats_reset
FROM pg_stat_bgwriter;

-- WAL metrics
SELECT 'wal_stats' as metric_type,
       wal_records,
       wal_fpi,
       wal_bytes,
       wal_buffers_full,
       wal_write,
       wal_sync,
       wal_write_time,
       wal_sync_time,
       stats_reset
FROM pg_stat_wal;

-- Query performance metrics (pg_stat_statements if available)
SELECT 'query_stats' as metric_type,
       query,
       calls,
       total_exec_time,
       min_exec_time,
       max_exec_time,
       mean_exec_time,
       stddev_exec_time,
       rows,
       100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
WHERE calls > 10
ORDER BY total_exec_time DESC
LIMIT 20;
EOF
    
    # Convert raw output to JSON
    python3 - << EOF > "$metrics_file"
import json
import sys
from datetime import datetime

metrics = {
    "timestamp": "$timestamp",
    "host": "$DB_HOST",
    "port": $DB_PORT,
    "database": "$DB_NAME",
    "metrics": {}
}

# Read raw metrics data
with open('/tmp/metrics_raw_$$', 'r') as f:
    lines = f.readlines()

current_type = None
for line in lines:
    line = line.strip()
    if not line:
        continue
    
    parts = line.split('|')
    if len(parts) < 2:
        continue
        
    metric_type = parts[0]
    
    if metric_type not in metrics["metrics"]:
        metrics["metrics"][metric_type] = []
    
    # Parse data based on metric type
    if metric_type == "database_stats":
        metrics["metrics"][metric_type].append({
            "datname": parts[1],
            "numbackends": int(parts[2]) if parts[2] else 0,
            "xact_commit": int(parts[3]) if parts[3] else 0,
            "xact_rollback": int(parts[4]) if parts[4] else 0,
            "blks_read": int(parts[5]) if parts[5] else 0,
            "blks_hit": int(parts[6]) if parts[6] else 0,
            "tup_returned": int(parts[7]) if parts[7] else 0,
            "tup_fetched": int(parts[8]) if parts[8] else 0,
            "tup_inserted": int(parts[9]) if parts[9] else 0,
            "tup_updated": int(parts[10]) if parts[10] else 0,
            "tup_deleted": int(parts[11]) if parts[11] else 0,
            "conflicts": int(parts[12]) if parts[12] else 0,
            "temp_files": int(parts[13]) if parts[13] else 0,
            "temp_bytes": int(parts[14]) if parts[14] else 0,
            "deadlocks": int(parts[15]) if parts[15] else 0,
            "blk_read_time": float(parts[16]) if parts[16] else 0.0,
            "blk_write_time": float(parts[17]) if parts[17] else 0.0,
            "stats_reset": parts[18] if parts[18] else None
        })
    elif metric_type == "connection_stats":
        metrics["metrics"][metric_type].append({
            "state": parts[1],
            "count": int(parts[2]) if parts[2] else 0
        })
    elif metric_type == "table_stats":
        metrics["metrics"][metric_type].append({
            "schema": parts[1],
            "table": parts[2],
            "seq_scan": int(parts[3]) if parts[3] else 0,
            "seq_tup_read": int(parts[4]) if parts[4] else 0,
            "idx_scan": int(parts[5]) if parts[5] else 0,
            "idx_tup_fetch": int(parts[6]) if parts[6] else 0,
            "n_tup_ins": int(parts[7]) if parts[7] else 0,
            "n_tup_upd": int(parts[8]) if parts[8] else 0,
            "n_tup_del": int(parts[9]) if parts[9] else 0,
            "n_tup_hot_upd": int(parts[10]) if parts[10] else 0,
            "n_live_tup": int(parts[11]) if parts[11] else 0,
            "n_dead_tup": int(parts[12]) if parts[12] else 0,
            "n_mod_since_analyze": int(parts[13]) if parts[13] else 0,
            "last_vacuum": parts[14] if parts[14] else None,
            "last_autovacuum": parts[15] if parts[15] else None,
            "last_analyze": parts[16] if parts[16] else None,
            "last_autoanalyze": parts[17] if parts[17] else None,
            "vacuum_count": int(parts[18]) if parts[18] else 0,
            "autovacuum_count": int(parts[19]) if parts[19] else 0,
            "analyze_count": int(parts[20]) if parts[20] else 0,
            "autoanalyze_count": int(parts[21]) if parts[21] else 0
        })

print(json.dumps(metrics, indent=2))
EOF
    
    # Cleanup
    rm -f /tmp/metrics_raw_$$
    
    log_success "PostgreSQL metrics collected: $metrics_file"
    echo "$metrics_file"
}

# Collect system-level metrics
collect_system_metrics() {
    local timestamp=$(date -Iseconds)
    local metrics_file="$METRICS_DIR/current/system_$(date +%Y%m%d_%H%M%S).json"
    
    log "Collecting system performance metrics..."
    
    # Collect system metrics using standard tools
    cat > "$metrics_file" << EOF
{
    "timestamp": "$timestamp",
    "hostname": "$(hostname)",
    "system_metrics": {
        "cpu": {
            "load_average": {
                "1min": $(uptime | awk '{print $(NF-2)}' | tr -d ','),
                "5min": $(uptime | awk '{print $(NF-1)}' | tr -d ','),
                "15min": $(uptime | awk '{print $NF}')
            },
            "cpu_count": $(nproc),
            "cpu_usage": $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | tr -d '%us,')
        },
        "memory": {
            "total_gb": $(free -g | awk '/^Mem:/{print $2}'),
            "used_gb": $(free -g | awk '/^Mem:/{print $3}'),
            "free_gb": $(free -g | awk '/^Mem:/{print $4}'),
            "available_gb": $(free -g | awk '/^Mem:/{print $7}'),
            "cached_gb": $(free -g | awk '/^Mem:/{print $6}'),
            "usage_percent": $(free | awk '/^Mem:/{printf "%.1f", $3/$2 * 100}')
        },
        "disk": {
            "filesystem": "$(df -h . | awk 'NR==2{print $1}')",
            "total": "$(df -h . | awk 'NR==2{print $2}')",
            "used": "$(df -h . | awk 'NR==2{print $3}')",
            "available": "$(df -h . | awk 'NR==2{print $4}')",
            "usage_percent": "$(df -h . | awk 'NR==2{print $5}')"
        },
        "network": {
            "connections": $(netstat -an 2>/dev/null | wc -l || echo "0"),
            "tcp_established": $(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo "0")
        },
        "processes": {
            "total": $(ps aux | wc -l),
            "postgres_processes": $(ps aux | grep postgres | grep -v grep | wc -l)
        }
    }
}
EOF
    
    log_success "System metrics collected: $metrics_file"
    echo "$metrics_file"
}

# Generate Prometheus metrics format
generate_prometheus_metrics() {
    local latest_postgres_file=$(ls -t "$METRICS_DIR/current/postgres_"*.json 2>/dev/null | head -1)
    local latest_system_file=$(ls -t "$METRICS_DIR/current/system_"*.json 2>/dev/null | head -1)
    local output_file="$METRICS_DIR/current/prometheus_metrics.txt"
    
    if [[ ! -f "$latest_postgres_file" ]] || [[ ! -f "$latest_system_file" ]]; then
        log_error "Missing metrics files for Prometheus export"
        return 1
    fi
    
    log "Generating Prometheus metrics..."
    
    # Generate Prometheus format metrics
    {
        echo "# HELP exapg_postgres_connections Number of PostgreSQL connections by state"
        echo "# TYPE exapg_postgres_connections gauge"
        
        jq -r '.metrics.connection_stats[]? | "exapg_postgres_connections{state=\"" + .state + "\"} " + (.count | tostring)' "$latest_postgres_file"
        
        echo "# HELP exapg_postgres_transactions_total Total number of committed transactions"
        echo "# TYPE exapg_postgres_transactions_total counter"
        
        jq -r '.metrics.database_stats[]? | "exapg_postgres_transactions_total{type=\"commit\"} " + (.xact_commit | tostring)' "$latest_postgres_file"
        jq -r '.metrics.database_stats[]? | "exapg_postgres_transactions_total{type=\"rollback\"} " + (.xact_rollback | tostring)' "$latest_postgres_file"
        
        echo "# HELP exapg_postgres_cache_hit_ratio PostgreSQL buffer cache hit ratio"
        echo "# TYPE exapg_postgres_cache_hit_ratio gauge"
        
        jq -r '.metrics.database_stats[]? | "exapg_postgres_cache_hit_ratio " + ((.blks_hit / (.blks_hit + .blks_read) * 100) | tostring)' "$latest_postgres_file"
        
        echo "# HELP exapg_system_cpu_usage_percent System CPU usage percentage"
        echo "# TYPE exapg_system_cpu_usage_percent gauge"
        
        jq -r '"exapg_system_cpu_usage_percent " + (.system_metrics.cpu.cpu_usage | tostring)' "$latest_system_file"
        
        echo "# HELP exapg_system_memory_usage_percent System memory usage percentage"
        echo "# TYPE exapg_system_memory_usage_percent gauge"
        
        jq -r '"exapg_system_memory_usage_percent " + (.system_metrics.memory.usage_percent | tostring)' "$latest_system_file"
        
        echo "# HELP exapg_system_load_average System load average"
        echo "# TYPE exapg_system_load_average gauge"
        
        jq -r '"exapg_system_load_average{period=\"1m\"} " + (.system_metrics.cpu.load_average."1min" | tostring)' "$latest_system_file"
        jq -r '"exapg_system_load_average{period=\"5m\"} " + (.system_metrics.cpu.load_average."5min" | tostring)' "$latest_system_file"
        jq -r '"exapg_system_load_average{period=\"15m\"} " + (.system_metrics.cpu.load_average."15min" | tostring)' "$latest_system_file"
        
    } > "$output_file"
    
    log_success "Prometheus metrics generated: $output_file"
}

# ===================================================================
# DATA MANAGEMENT
# ===================================================================

# Archive old metrics
archive_old_metrics() {
    log "Archiving old metrics..."
    
    local archive_date=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d)
    
    # Move old files to historical directory
    find "$METRICS_DIR/current" -name "*.json" -type f -mtime +$RETENTION_DAYS -exec mv {} "$METRICS_DIR/historical/" \; 2>/dev/null || true
    
    # Compress historical files older than 7 days
    find "$METRICS_DIR/historical" -name "*.json" -type f -mtime +7 -exec gzip {} \; 2>/dev/null || true
    
    # Remove very old compressed files (beyond retention period)
    find "$METRICS_DIR/historical" -name "*.gz" -type f -mtime +$((RETENTION_DAYS * 2)) -delete 2>/dev/null || true
    
    log_success "Old metrics archived"
}

# ===================================================================
# ALERTING
# ===================================================================

# Check for performance alerts
check_performance_alerts() {
    local latest_postgres_file=$(ls -t "$METRICS_DIR/current/postgres_"*.json 2>/dev/null | head -1)
    local latest_system_file=$(ls -t "$METRICS_DIR/current/system_"*.json 2>/dev/null | head -1)
    
    if [[ ! -f "$latest_postgres_file" ]] || [[ ! -f "$latest_system_file" ]]; then
        return 0
    fi
    
    log "Checking performance alerts..."
    
    local alerts=()
    
    # Check CPU usage
    local cpu_usage=$(jq -r '.system_metrics.cpu.cpu_usage' "$latest_system_file")
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        alerts+=("HIGH_CPU_USAGE: $cpu_usage%")
    fi
    
    # Check memory usage
    local memory_usage=$(jq -r '.system_metrics.memory.usage_percent' "$latest_system_file")
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        alerts+=("HIGH_MEMORY_USAGE: $memory_usage%")
    fi
    
    # Check PostgreSQL connections
    local active_connections=$(jq -r '.metrics.connection_stats[]? | select(.state=="active") | .count' "$latest_postgres_file")
    if [[ "$active_connections" != "null" ]] && [[ $active_connections -gt 100 ]]; then
        alerts+=("HIGH_CONNECTION_COUNT: $active_connections active connections")
    fi
    
    # Check cache hit ratio
    local cache_hit_ratio=$(jq -r '.metrics.database_stats[]? | (.blks_hit / (.blks_hit + .blks_read) * 100)' "$latest_postgres_file")
    if [[ "$cache_hit_ratio" != "null" ]] && (( $(echo "$cache_hit_ratio < 90" | bc -l) )); then
        alerts+=("LOW_CACHE_HIT_RATIO: $cache_hit_ratio%")
    fi
    
    # Generate alert file if there are any alerts
    if [[ ${#alerts[@]} -gt 0 ]]; then
        local alert_file="$METRICS_DIR/alerts/alert_$(date +%Y%m%d_%H%M%S).json"
        
        cat > "$alert_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "alert_count": ${#alerts[@]},
    "alerts": [
$(printf '        "%s"' "${alerts[0]}")
$(printf ',\n        "%s"' "${alerts[@]:1}")
    ]
}
EOF
        
        log_error "Performance alerts detected: ${#alerts[@]} alerts"
        for alert in "${alerts[@]}"; do
            log_error "  - $alert"
        done
        
        return 1
    else
        log_success "No performance alerts detected"
        return 0
    fi
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

# Continuous monitoring mode
continuous_monitoring() {
    log "Starting continuous monitoring mode (interval: ${COLLECTION_INTERVAL}s)"
    
    while true; do
        collect_postgres_metrics >/dev/null
        collect_system_metrics >/dev/null
        
        if [[ "$OUTPUT_FORMAT" == "prometheus" ]]; then
            generate_prometheus_metrics
        fi
        
        check_performance_alerts || true
        archive_old_metrics
        
        sleep "$COLLECTION_INTERVAL"
    done
}

# Single collection
single_collection() {
    log "Running single metrics collection..."
    
    local postgres_file=$(collect_postgres_metrics)
    local system_file=$(collect_system_metrics)
    
    if [[ "$OUTPUT_FORMAT" == "prometheus" ]]; then
        generate_prometheus_metrics
    fi
    
    check_performance_alerts || true
    
    log_success "Single collection completed"
    echo "PostgreSQL metrics: $postgres_file"
    echo "System metrics: $system_file"
}

main() {
    local mode="${1:-single}"
    
    log "Starting ExaPG metrics collector..."
    
    # Setup
    setup_directories
    check_database
    
    case "$mode" in
        "continuous"|"daemon")
            continuous_monitoring
            ;;
        "single"|"once")
            single_collection
            ;;
        *)
            log_error "Unknown mode: $mode"
            log_error "Supported modes: single, continuous"
            return 1
            ;;
    esac
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Performance Metrics Collector

This script collects PostgreSQL and system performance metrics for monitoring.

Usage: $0 [mode]

Modes:
  single      - Collect metrics once and exit (default)
  continuous  - Run continuous monitoring daemon

Environment Variables:
  POSTGRES_HOST      - Database host (default: localhost)
  POSTGRES_PORT      - Database port (default: 5432)
  POSTGRES_DB        - Database name (default: exadb)
  POSTGRES_USER      - Database user (default: postgres)
  METRICS_INTERVAL   - Collection interval in seconds (default: 60)
  METRICS_RETENTION  - Retention period in days (default: 30)
  METRICS_FORMAT     - Output format: json, prometheus (default: json)

Examples:
  $0 single              # Collect metrics once
  $0 continuous          # Run continuous monitoring
  METRICS_INTERVAL=30 $0 continuous  # Monitor every 30 seconds

Output:
  benchmark/metrics/current/     - Current metrics files
  benchmark/metrics/historical/  - Archived metrics
  benchmark/metrics/alerts/      - Performance alerts
EOF
    exit 0
fi

# Run main function
main "${1:-single}" 