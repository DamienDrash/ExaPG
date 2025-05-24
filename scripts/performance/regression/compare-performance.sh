#!/bin/bash
# ===================================================================
# ExaPG Performance Comparison Tool
# ===================================================================
# PERFORMANCE FIX: PERF-002 - Performance Regression Testing
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly BASELINE_DIR="$SCRIPT_DIR/../baseline"
readonly RESULTS_DIR="$PROJECT_ROOT/benchmark/results"
readonly REPORTS_DIR="$PROJECT_ROOT/benchmark/reports"

# Database connection
readonly DB_HOST="${POSTGRES_HOST:-localhost}"
readonly DB_PORT="${POSTGRES_PORT:-5432}"
readonly DB_NAME="${POSTGRES_DB:-exadb}"
readonly DB_USER="${POSTGRES_USER:-postgres}"

# Performance test parameters
readonly WARMUP_RUNS=2
readonly TEST_RUNS=5
readonly TIMEOUT_SECONDS=3600

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-COMPARE] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-COMPARE] [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF-COMPARE] [SUCCESS] $*" >&2
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Setup directories
setup_directories() {
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$RESULTS_DIR/current"
    mkdir -p "$RESULTS_DIR/baseline"
}

# Check database connectivity
check_database() {
    log "Checking database connectivity..."
    
    if ! command -v psql >/dev/null 2>&1; then
        log_error "psql command not found. Please install PostgreSQL client."
        return 1
    fi
    
    if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Cannot connect to database: $DB_HOST:$DB_PORT/$DB_NAME"
        return 1
    fi
    
    log_success "Database connection verified"
}

# Get PostgreSQL version and configuration
get_system_info() {
    log "Collecting system information..."
    
    local info_file="$RESULTS_DIR/current/system_info.json"
    
    cat > "$info_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "postgresql_version": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" | xargs)",
    "shared_buffers": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW shared_buffers;" | xargs)",
    "work_mem": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW work_mem;" | xargs)",
    "effective_cache_size": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW effective_cache_size;" | xargs)",
    "max_parallel_workers": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW max_parallel_workers;" | xargs)",
    "max_parallel_workers_per_gather": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW max_parallel_workers_per_gather;" | xargs)",
    "jit": "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW jit;" | xargs)",
    "system": {
        "cpu_cores": "$(nproc 2>/dev/null || echo "unknown")",
        "memory_gb": "$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "unknown")",
        "disk_space": "$(df -h . 2>/dev/null | awk 'NR==2{print $4}' || echo "unknown")"
    }
}
EOF
    
    log "System information saved to: $info_file"
}

# ===================================================================
# BENCHMARK EXECUTION
# ===================================================================

# Execute single SQL file with timing
execute_sql_benchmark() {
    local sql_file="$1"
    local benchmark_name="$2"
    local run_number="$3"
    
    local result_file="$RESULTS_DIR/current/${benchmark_name}_run${run_number}.json"
    local temp_output="/tmp/perf_output_$$"
    
    log "Running $benchmark_name (run $run_number)..."
    
    # Start timing
    local start_time=$(date +%s.%N)
    
    # Execute SQL with timing and capture output
    timeout "$TIMEOUT_SECONDS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -v ON_ERROR_STOP=1 \
        -c "\timing on" \
        -f "$sql_file" > "$temp_output" 2>&1
    
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Parse timing information from psql output
    local query_times=()
    while IFS= read -r line; do
        if [[ "$line" =~ Time:\ ([0-9]+\.[0-9]+)\ ms ]]; then
            query_times+=("${BASH_REMATCH[1]}")
        fi
    done < "$temp_output"
    
    # Calculate statistics
    local total_query_time=0
    local query_count=${#query_times[@]}
    
    if [[ $query_count -gt 0 ]]; then
        for time in "${query_times[@]}"; do
            total_query_time=$(echo "$total_query_time + $time" | bc -l)
        done
    fi
    
    # Save results to JSON
    cat > "$result_file" << EOF
{
    "benchmark": "$benchmark_name",
    "run_number": $run_number,
    "timestamp": "$(date -Iseconds)",
    "total_time_seconds": $total_time,
    "total_query_time_ms": $total_query_time,
    "query_count": $query_count,
    "exit_code": $exit_code,
    "individual_query_times_ms": [$(IFS=,; echo "${query_times[*]}")],
    "avg_query_time_ms": $(echo "scale=3; $total_query_time / $query_count" | bc -l 2>/dev/null || echo "0"),
    "queries_per_second": $(echo "scale=3; $query_count / $total_time" | bc -l 2>/dev/null || echo "0")
}
EOF
    
    # Cleanup
    rm -f "$temp_output"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$benchmark_name run $run_number completed (${total_time}s)"
    else
        log_error "$benchmark_name run $run_number failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Run complete benchmark suite
run_benchmark_suite() {
    local suite_name="$1"
    log "Starting benchmark suite: $suite_name"
    
    # Benchmark configurations
    local -A benchmarks=(
        ["tpch"]="$BASELINE_DIR/tpch-baseline.sql"
        ["oltp"]="$BASELINE_DIR/oltp-baseline.sql"
        ["analytics"]="$BASELINE_DIR/analytics-baseline.sql"
    )
    
    # Run specified benchmark or all if not specified
    local benchmark_list
    if [[ "$suite_name" == "all" ]]; then
        benchmark_list=(tpch oltp analytics)
    else
        benchmark_list=("$suite_name")
    fi
    
    for benchmark in "${benchmark_list[@]}"; do
        if [[ ! -f "${benchmarks[$benchmark]}" ]]; then
            log_error "Benchmark file not found: ${benchmarks[$benchmark]}"
            continue
        fi
        
        log "Running $benchmark benchmark..."
        
        # Warmup runs
        for ((i=1; i<=WARMUP_RUNS; i++)); do
            log "Warmup run $i for $benchmark..."
            execute_sql_benchmark "${benchmarks[$benchmark]}" "${benchmark}_warmup" "$i" || true
        done
        
        # Actual test runs
        local successful_runs=0
        for ((i=1; i<=TEST_RUNS; i++)); do
            if execute_sql_benchmark "${benchmarks[$benchmark]}" "$benchmark" "$i"; then
                ((successful_runs++))
            fi
        done
        
        log "Completed $benchmark: $successful_runs/$TEST_RUNS successful runs"
    done
}

# ===================================================================
# PERFORMANCE COMPARISON
# ===================================================================

# Calculate statistics from multiple runs
calculate_statistics() {
    local benchmark="$1"
    local stats_file="$RESULTS_DIR/current/${benchmark}_statistics.json"
    
    log "Calculating statistics for $benchmark..."
    
    # Collect all successful run data
    local times=()
    local query_counts=()
    local qps_values=()
    
    for run_file in "$RESULTS_DIR/current/${benchmark}_run"*.json; do
        if [[ -f "$run_file" ]]; then
            local exit_code=$(jq -r '.exit_code' "$run_file")
            if [[ "$exit_code" == "0" ]]; then
                times+=($(jq -r '.total_time_seconds' "$run_file"))
                query_counts+=($(jq -r '.query_count' "$run_file"))
                qps_values+=($(jq -r '.queries_per_second' "$run_file"))
            fi
        fi
    done
    
    if [[ ${#times[@]} -eq 0 ]]; then
        log_error "No successful runs found for $benchmark"
        return 1
    fi
    
    # Calculate statistics using awk
    local stats_output=$(printf '%s\n' "${times[@]}" | awk '
    BEGIN { sum = 0; sum2 = 0; min = 999999; max = 0; count = 0 }
    {
        sum += $1
        sum2 += $1 * $1
        if ($1 < min) min = $1
        if ($1 > max) max = $1
        times[count++] = $1
    }
    END {
        mean = sum / count
        variance = (sum2 - sum * sum / count) / (count - 1)
        stddev = sqrt(variance)
        
        # Calculate median
        for (i = 0; i < count - 1; i++) {
            for (j = i + 1; j < count; j++) {
                if (times[i] > times[j]) {
                    temp = times[i]
                    times[i] = times[j]
                    times[j] = temp
                }
            }
        }
        
        if (count % 2 == 1) {
            median = times[int(count/2)]
        } else {
            median = (times[count/2-1] + times[count/2]) / 2
        }
        
        printf "%.6f %.6f %.6f %.6f %.6f %.6f\n", mean, median, stddev, min, max, variance
    }')
    
    read -r mean median stddev min max variance <<< "$stats_output"
    
    # Calculate average queries per second
    local avg_qps=$(printf '%s\n' "${qps_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    
    # Save statistics
    cat > "$stats_file" << EOF
{
    "benchmark": "$benchmark",
    "timestamp": "$(date -Iseconds)",
    "successful_runs": ${#times[@]},
    "total_runs": $TEST_RUNS,
    "execution_time_seconds": {
        "mean": $mean,
        "median": $median,
        "std_dev": $stddev,
        "min": $min,
        "max": $max,
        "variance": $variance
    },
    "queries_per_second": {
        "average": $avg_qps
    },
    "raw_times": [$(IFS=,; echo "${times[*]}")]
}
EOF
    
    log_success "Statistics calculated for $benchmark"
}

# Compare current results with baseline
compare_with_baseline() {
    local benchmark="$1"
    
    local current_stats="$RESULTS_DIR/current/${benchmark}_statistics.json"
    local baseline_stats="$RESULTS_DIR/baseline/${benchmark}_statistics.json"
    local comparison_file="$REPORTS_DIR/${benchmark}_comparison_$(date +%Y%m%d_%H%M%S).json"
    
    if [[ ! -f "$current_stats" ]]; then
        log_error "Current statistics not found: $current_stats"
        return 1
    fi
    
    if [[ ! -f "$baseline_stats" ]]; then
        log "No baseline found for $benchmark, creating new baseline"
        cp "$current_stats" "$baseline_stats"
        return 0
    fi
    
    log "Comparing $benchmark performance with baseline..."
    
    # Extract key metrics
    local current_mean=$(jq -r '.execution_time_seconds.mean' "$current_stats")
    local baseline_mean=$(jq -r '.execution_time_seconds.mean' "$baseline_stats")
    local current_qps=$(jq -r '.queries_per_second.average' "$current_stats")
    local baseline_qps=$(jq -r '.queries_per_second.average' "$baseline_stats")
    
    # Calculate percentage changes
    local time_change=$(echo "scale=2; ($current_mean - $baseline_mean) / $baseline_mean * 100" | bc -l)
    local qps_change=$(echo "scale=2; ($current_qps - $baseline_qps) / $baseline_qps * 100" | bc -l)
    
    # Determine regression status
    local regression_threshold=5.0  # 5% regression threshold
    local regression_status="PASS"
    
    if (( $(echo "$time_change > $regression_threshold" | bc -l) )); then
        regression_status="REGRESSION"
    fi
    
    # Create comparison report
    cat > "$comparison_file" << EOF
{
    "benchmark": "$benchmark",
    "timestamp": "$(date -Iseconds)",
    "comparison": {
        "execution_time": {
            "current_mean": $current_mean,
            "baseline_mean": $baseline_mean,
            "change_percent": $time_change,
            "change_seconds": $(echo "$current_mean - $baseline_mean" | bc -l)
        },
        "queries_per_second": {
            "current": $current_qps,
            "baseline": $baseline_qps,
            "change_percent": $qps_change
        },
        "regression_status": "$regression_status",
        "regression_threshold_percent": $regression_threshold
    },
    "current_stats": $(cat "$current_stats"),
    "baseline_stats": $(cat "$baseline_stats")
}
EOF
    
    log "Comparison report saved: $comparison_file"
    
    # Log summary
    log "Performance comparison for $benchmark:"
    log "  Execution time: ${current_mean}s (${time_change:+$time_change}% vs baseline)"
    log "  Queries/sec: ${current_qps} (${qps_change:+$qps_change}% vs baseline)"
    log "  Status: $regression_status"
    
    if [[ "$regression_status" == "REGRESSION" ]]; then
        log_error "Performance regression detected for $benchmark!"
        return 1
    else
        log_success "$benchmark performance within acceptable range"
        return 0
    fi
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    local benchmark_suite="${1:-all}"
    
    log "Starting ExaPG performance comparison..."
    log "Benchmark suite: $benchmark_suite"
    
    # Setup
    setup_directories
    check_database
    get_system_info
    
    # Run benchmarks
    run_benchmark_suite "$benchmark_suite"
    
    # Calculate statistics and compare
    local benchmarks_to_process
    if [[ "$benchmark_suite" == "all" ]]; then
        benchmarks_to_process=(tpch oltp analytics)
    else
        benchmarks_to_process=("$benchmark_suite")
    fi
    
    local overall_status="PASS"
    for benchmark in "${benchmarks_to_process[@]}"; do
        if calculate_statistics "$benchmark"; then
            if ! compare_with_baseline "$benchmark"; then
                overall_status="REGRESSION"
            fi
        fi
    done
    
    # Final status
    log "Performance comparison completed"
    log "Overall status: $overall_status"
    
    if [[ "$overall_status" == "REGRESSION" ]]; then
        log_error "Performance regressions detected!"
        return 1
    else
        log_success "No performance regressions detected"
        return 0
    fi
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Performance Comparison Tool

This script runs performance benchmarks and compares results with baseline.

Usage: $0 [benchmark_suite]

Benchmark Suites:
  all        - Run all benchmarks (default)
  tpch       - TPC-H analytical queries
  oltp       - OLTP transactional queries  
  analytics  - Star schema analytics queries

Environment Variables:
  POSTGRES_HOST     - Database host (default: localhost)
  POSTGRES_PORT     - Database port (default: 5432)
  POSTGRES_DB       - Database name (default: exadb)
  POSTGRES_USER     - Database user (default: postgres)

Examples:
  $0                # Run all benchmarks
  $0 tpch          # Run only TPC-H benchmark
  $0 oltp          # Run only OLTP benchmark
  $0 analytics     # Run only analytics benchmark

Output:
  benchmark/results/current/  - Current test results
  benchmark/results/baseline/ - Baseline results for comparison
  benchmark/reports/          - Comparison reports
EOF
    exit 0
fi

# Run main function
main "${1:-all}" 