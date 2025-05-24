#!/bin/bash
# ===================================================================
# ExaPG Performance Configuration Optimizer
# ===================================================================
# PERFORMANCE FIX: PERF-001 - Environment-controlled Memory Settings
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly CONFIG_TEMPLATE="$PROJECT_ROOT/config/postgresql/postgresql.conf.template"
readonly CONFIG_OUTPUT="$PROJECT_ROOT/config/postgresql/postgresql.conf"

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-OPT] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-OPT] [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-OPT] [SUCCESS] $*" >&2
}

# ===================================================================
# SYSTEM DETECTION
# ===================================================================

detect_system_resources() {
    log "Detecting system resources..."
    
    # Detect total memory
    if [[ -f "/proc/meminfo" ]]; then
        TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    else
        # Fallback for non-Linux systems
        TOTAL_MEM_GB=8
        log "Could not detect memory, using default: ${TOTAL_MEM_GB}GB"
    fi
    
    # Detect CPU cores
    if command -v nproc >/dev/null 2>&1; then
        CPU_CORES=$(nproc)
    else
        CPU_CORES=4
        log "Could not detect CPU cores, using default: $CPU_CORES"
    fi
    
    log "System Resources:"
    log "  Total Memory: ${TOTAL_MEM_GB}GB"
    log "  CPU Cores: $CPU_CORES"
}

# ===================================================================
# PERFORMANCE CALCULATIONS
# ===================================================================

calculate_optimal_settings() {
    log "Calculating optimal PostgreSQL settings..."
    
    # Memory calculations based on PostgreSQL best practices
    
    # shared_buffers: 25% of RAM (max 8GB for single instance)
    SHARED_BUFFERS_GB=$(( TOTAL_MEM_GB / 4 ))
    if [[ $SHARED_BUFFERS_GB -gt 8 ]]; then
        SHARED_BUFFERS_GB=8
    fi
    if [[ $SHARED_BUFFERS_GB -lt 1 ]]; then
        SHARED_BUFFERS_GB=1
    fi
    
    # effective_cache_size: 75% of RAM
    EFFECTIVE_CACHE_SIZE_GB=$(( TOTAL_MEM_GB * 3 / 4 ))
    if [[ $EFFECTIVE_CACHE_SIZE_GB -lt 1 ]]; then
        EFFECTIVE_CACHE_SIZE_GB=1
    fi
    
    # work_mem: Depends on connection count and complexity
    # Formula: (RAM - shared_buffers) / (max_connections * 3)
    AVAILABLE_FOR_WORK=$(( (TOTAL_MEM_GB - SHARED_BUFFERS_GB) * 1024 ))
    MAX_CONNECTIONS=${POSTGRES_MAX_CONNECTIONS:-1000}
    WORK_MEM_MB=$(( AVAILABLE_FOR_WORK / (MAX_CONNECTIONS * 3) ))
    if [[ $WORK_MEM_MB -lt 4 ]]; then
        WORK_MEM_MB=4
    fi
    if [[ $WORK_MEM_MB -gt 1024 ]]; then
        WORK_MEM_MB=1024
    fi
    
    # maintenance_work_mem: 5% of RAM (max 2GB)
    MAINTENANCE_WORK_MEM_GB=$(( TOTAL_MEM_GB / 20 ))
    if [[ $MAINTENANCE_WORK_MEM_GB -gt 2 ]]; then
        MAINTENANCE_WORK_MEM_GB=2
    fi
    if [[ $MAINTENANCE_WORK_MEM_GB -lt 1 ]]; then
        MAINTENANCE_WORK_MEM_GB=1
    fi
    MAINTENANCE_WORK_MEM_MB=$(( MAINTENANCE_WORK_MEM_GB * 1024 ))
    
    # WAL buffers: 3% of shared_buffers (between 1MB and 16MB)
    WAL_BUFFERS_MB=$(( SHARED_BUFFERS_GB * 1024 * 3 / 100 ))
    if [[ $WAL_BUFFERS_MB -lt 1 ]]; then
        WAL_BUFFERS_MB=1
    fi
    if [[ $WAL_BUFFERS_MB -gt 16 ]]; then
        WAL_BUFFERS_MB=16
    fi
    
    # Parallel settings based on CPU cores
    MAX_PARALLEL_WORKERS=$CPU_CORES
    if [[ $MAX_PARALLEL_WORKERS -gt 32 ]]; then
        MAX_PARALLEL_WORKERS=32
    fi
    
    MAX_PARALLEL_WORKERS_PER_GATHER=$(( CPU_CORES / 2 ))
    if [[ $MAX_PARALLEL_WORKERS_PER_GATHER -lt 2 ]]; then
        MAX_PARALLEL_WORKERS_PER_GATHER=2
    fi
    if [[ $MAX_PARALLEL_WORKERS_PER_GATHER -gt 8 ]]; then
        MAX_PARALLEL_WORKERS_PER_GATHER=8
    fi
    
    MAX_PARALLEL_MAINTENANCE_WORKERS=$(( CPU_CORES / 4 ))
    if [[ $MAX_PARALLEL_MAINTENANCE_WORKERS -lt 1 ]]; then
        MAX_PARALLEL_MAINTENANCE_WORKERS=1
    fi
    if [[ $MAX_PARALLEL_MAINTENANCE_WORKERS -gt 4 ]]; then
        MAX_PARALLEL_MAINTENANCE_WORKERS=4
    fi
    
    log "Calculated optimal settings:"
    log "  shared_buffers: ${SHARED_BUFFERS_GB}GB"
    log "  effective_cache_size: ${EFFECTIVE_CACHE_SIZE_GB}GB"
    log "  work_mem: ${WORK_MEM_MB}MB"
    log "  maintenance_work_mem: ${MAINTENANCE_WORK_MEM_MB}MB"
    log "  wal_buffers: ${WAL_BUFFERS_MB}MB"
    log "  max_parallel_workers: $MAX_PARALLEL_WORKERS"
    log "  max_parallel_workers_per_gather: $MAX_PARALLEL_WORKERS_PER_GATHER"
    log "  max_parallel_maintenance_workers: $MAX_PARALLEL_MAINTENANCE_WORKERS"
}

# ===================================================================
# WORKLOAD SPECIFIC TUNING
# ===================================================================

get_workload_profile() {
    local workload="${EXAPG_WORKLOAD_PROFILE:-balanced}"
    
    case "$workload" in
        "oltp")
            log "Optimizing for OLTP workload..."
            # More connections, smaller work_mem
            WORK_MEM_MB=$(( WORK_MEM_MB / 2 ))
            if [[ $WORK_MEM_MB -lt 4 ]]; then
                WORK_MEM_MB=4
            fi
            ;;
        "analytics")
            log "Optimizing for Analytics workload..."
            # Fewer connections, larger work_mem, more parallel workers
            WORK_MEM_MB=$(( WORK_MEM_MB * 2 ))
            MAX_PARALLEL_WORKERS_PER_GATHER=$(( MAX_PARALLEL_WORKERS_PER_GATHER * 2 ))
            if [[ $MAX_PARALLEL_WORKERS_PER_GATHER -gt $CPU_CORES ]]; then
                MAX_PARALLEL_WORKERS_PER_GATHER=$CPU_CORES
            fi
            ;;
        "mixed"|"balanced")
            log "Using balanced workload profile..."
            # Default settings calculated above
            ;;
        *)
            log "Unknown workload profile: $workload, using balanced"
            ;;
    esac
}

# ===================================================================
# ENVIRONMENT VARIABLE EXPORT
# ===================================================================

export_performance_variables() {
    log "Exporting performance environment variables..."
    
    # Core memory settings
    export POSTGRES_SHARED_BUFFERS="${SHARED_BUFFERS_GB}GB"
    export POSTGRES_EFFECTIVE_CACHE_SIZE="${EFFECTIVE_CACHE_SIZE_GB}GB"
    export POSTGRES_WORK_MEM="${WORK_MEM_MB}MB"
    export POSTGRES_MAINTENANCE_WORK_MEM="${MAINTENANCE_WORK_MEM_MB}MB"
    export POSTGRES_WAL_BUFFERS="${WAL_BUFFERS_MB}MB"
    
    # Parallel processing
    export POSTGRES_MAX_PARALLEL_WORKERS="$MAX_PARALLEL_WORKERS"
    export POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER="$MAX_PARALLEL_WORKERS_PER_GATHER"
    export POSTGRES_MAX_PARALLEL_MAINTENANCE_WORKERS="$MAX_PARALLEL_MAINTENANCE_WORKERS"
    
    # Performance tuning
    export POSTGRES_RANDOM_PAGE_COST="1.1"  # SSD optimized
    export POSTGRES_EFFECTIVE_IO_CONCURRENCY="200"  # SSD optimized
    export POSTGRES_CHECKPOINT_COMPLETION_TARGET="0.9"
    export POSTGRES_CHECKPOINT_TIMEOUT="5min"
    
    # Analytics-specific settings
    export POSTGRES_DEFAULT_STATISTICS_TARGET="100"
    export POSTGRES_CONSTRAINT_EXCLUSION="partition"
    export POSTGRES_ENABLE_PARTITION_PRUNING="on"
    export POSTGRES_ENABLE_PARTITIONWISE_JOIN="on"
    export POSTGRES_ENABLE_PARTITIONWISE_AGGREGATE="on"
    
    # Write performance variables to file for Docker Compose
    local env_file="$PROJECT_ROOT/.env.performance"
    cat > "$env_file" << EOF
# ===================================================================
# ExaPG Auto-Generated Performance Settings
# ===================================================================
# Generated: $(date)
# System: ${TOTAL_MEM_GB}GB RAM, ${CPU_CORES} CPU cores
# Workload: ${EXAPG_WORKLOAD_PROFILE:-balanced}
# ===================================================================

# Core Memory Settings
POSTGRES_SHARED_BUFFERS=${SHARED_BUFFERS_GB}GB
POSTGRES_EFFECTIVE_CACHE_SIZE=${EFFECTIVE_CACHE_SIZE_GB}GB
POSTGRES_WORK_MEM=${WORK_MEM_MB}MB
POSTGRES_MAINTENANCE_WORK_MEM=${MAINTENANCE_WORK_MEM_MB}MB
POSTGRES_WAL_BUFFERS=${WAL_BUFFERS_MB}MB

# Parallel Processing
POSTGRES_MAX_PARALLEL_WORKERS=$MAX_PARALLEL_WORKERS
POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER=$MAX_PARALLEL_WORKERS_PER_GATHER
POSTGRES_MAX_PARALLEL_MAINTENANCE_WORKERS=$MAX_PARALLEL_MAINTENANCE_WORKERS

# Performance Tuning
POSTGRES_RANDOM_PAGE_COST=1.1
POSTGRES_EFFECTIVE_IO_CONCURRENCY=200
POSTGRES_CHECKPOINT_COMPLETION_TARGET=0.9
POSTGRES_CHECKPOINT_TIMEOUT=5min

# Analytics Optimization
POSTGRES_DEFAULT_STATISTICS_TARGET=100
POSTGRES_CONSTRAINT_EXCLUSION=partition
POSTGRES_ENABLE_PARTITION_PRUNING=on
POSTGRES_ENABLE_PARTITIONWISE_JOIN=on
POSTGRES_ENABLE_PARTITIONWISE_AGGREGATE=on
EOF
    
    log_success "Performance settings written to: $env_file"
}

# ===================================================================
# VALIDATION
# ===================================================================

validate_settings() {
    log "Validating performance settings..."
    
    # Check if settings are reasonable
    local total_allocated=$(( SHARED_BUFFERS_GB + (WORK_MEM_MB * MAX_CONNECTIONS / 1024) + MAINTENANCE_WORK_MEM_GB ))
    
    if [[ $total_allocated -gt $TOTAL_MEM_GB ]]; then
        log_error "Warning: Total allocated memory (${total_allocated}GB) exceeds system memory (${TOTAL_MEM_GB}GB)"
        log_error "Consider reducing max_connections or work_mem"
    fi
    
    if [[ $SHARED_BUFFERS_GB -gt $(( TOTAL_MEM_GB / 2 )) ]]; then
        log_error "Warning: shared_buffers (${SHARED_BUFFERS_GB}GB) is very large relative to system memory"
    fi
    
    log_success "Performance settings validation completed"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    log "Starting ExaPG performance optimization..."
    
    # Detect system resources
    detect_system_resources
    
    # Calculate optimal settings
    calculate_optimal_settings
    
    # Apply workload-specific tuning
    get_workload_profile
    
    # Export environment variables
    export_performance_variables
    
    # Validate settings
    validate_settings
    
    log_success "Performance optimization completed successfully!"
    log "To apply settings: source .env.performance && docker-compose restart"
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Performance Configuration Optimizer

This script automatically calculates optimal PostgreSQL performance settings
based on your system resources and workload profile.

Usage: $0 [options]

Environment Variables:
  EXAPG_WORKLOAD_PROFILE    Workload type: oltp, analytics, balanced (default)
  POSTGRES_MAX_CONNECTIONS  Max database connections (default: 1000)

Examples:
  $0                                    # Auto-optimize for balanced workload
  EXAPG_WORKLOAD_PROFILE=analytics $0   # Optimize for analytics workload
  EXAPG_WORKLOAD_PROFILE=oltp $0        # Optimize for OLTP workload

Workload Profiles:
  oltp        - High concurrency, small transactions
  analytics   - Low concurrency, large analytical queries
  balanced    - Mixed workload (default)

Output:
  .env.performance - Generated performance settings for Docker Compose
EOF
    exit 0
fi

# Run main function
main "$@" 