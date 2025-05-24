#!/bin/bash
# ===================================================================
# ExaPG Performance Regression Report Generator
# ===================================================================
# PERFORMANCE FIX: PERF-002 - Comprehensive Performance Reporting
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly RESULTS_DIR="$PROJECT_ROOT/benchmark/results"
readonly REPORTS_DIR="$PROJECT_ROOT/benchmark/reports"

# Report configuration
readonly REPORT_TEMPLATE_DIR="$SCRIPT_DIR/../templates"
readonly OUTPUT_FORMAT="${REPORT_FORMAT:-html}"  # html, markdown, json

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPORT-GEN] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPORT-GEN] [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [REPORT-GEN] [SUCCESS] $*" >&2
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [[ "$OUTPUT_FORMAT" == "html" ]] && ! command -v pandoc >/dev/null 2>&1; then
        log "Warning: pandoc not found. HTML reports will be basic format."
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing tools and try again."
        return 1
    fi
}

# Setup directories
setup_directories() {
    mkdir -p "$REPORTS_DIR/html"
    mkdir -p "$REPORTS_DIR/markdown"
    mkdir -p "$REPORTS_DIR/json"
    mkdir -p "$REPORTS_DIR/assets"
}

# ===================================================================
# DATA COLLECTION AND ANALYSIS
# ===================================================================

# Collect all test results
collect_test_data() {
    log "Collecting test data..."
    
    local data_file="$REPORTS_DIR/json/collected_data.json"
    
    # Initialize data structure
    cat > "$data_file" << 'EOF'
{
    "metadata": {},
    "system_info": {},
    "benchmarks": {}
}
EOF
    
    # Add metadata
    jq --arg timestamp "$(date -Iseconds)" \
       --arg version "$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")" \
       --arg hostname "$(hostname)" \
       '.metadata = {
           "generated": $timestamp,
           "version": $version,
           "hostname": $hostname,
           "tool": "ExaPG Performance Regression Report"
       }' "$data_file" > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
    
    # Add system information if available
    if [[ -f "$RESULTS_DIR/current/system_info.json" ]]; then
        jq --slurpfile sysinfo "$RESULTS_DIR/current/system_info.json" \
           '.system_info = $sysinfo[0]' "$data_file" > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
    fi
    
    # Collect benchmark data
    for benchmark in tpch oltp analytics; do
        log "Collecting data for $benchmark..."
        
        local stats_file="$RESULTS_DIR/current/${benchmark}_statistics.json"
        local baseline_file="$RESULTS_DIR/baseline/${benchmark}_statistics.json"
        
        if [[ -f "$stats_file" ]]; then
            # Add current results
            jq --slurpfile stats "$stats_file" \
               --arg benchmark "$benchmark" \
               '.benchmarks[$benchmark].current = $stats[0]' \
               "$data_file" > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
            
            # Add baseline if available
            if [[ -f "$baseline_file" ]]; then
                jq --slurpfile baseline "$baseline_file" \
                   --arg benchmark "$benchmark" \
                   '.benchmarks[$benchmark].baseline = $baseline[0]' \
                   "$data_file" > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
            fi
            
            # Add individual run data
            local runs_data="["
            local first=true
            for run_file in "$RESULTS_DIR/current/${benchmark}_run"*.json; do
                if [[ -f "$run_file" ]]; then
                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        runs_data+=","
                    fi
                    runs_data+=$(cat "$run_file")
                fi
            done
            runs_data+="]"
            
            echo "$runs_data" | jq --arg benchmark "$benchmark" \
                '. as $runs | {} | .benchmarks[$benchmark].individual_runs = $runs' \
                | jq -s --slurpfile main "$data_file" \
                '$main[0] * .[0]' > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
        fi
    done
    
    log_success "Test data collected: $data_file"
}

# Calculate performance trends
calculate_trends() {
    local data_file="$REPORTS_DIR/json/collected_data.json"
    
    log "Calculating performance trends..."
    
    # Add trend calculations using jq
    jq '
    # Calculate overall trends and statistics
    .analysis = {
        "summary": {
            "total_benchmarks": (.benchmarks | keys | length),
            "benchmarks_with_baseline": [.benchmarks | to_entries[] | select(.value.baseline != null) | .key] | length,
            "overall_status": "ANALYZING"
        },
        "trends": {},
        "recommendations": []
    } |
    
    # Calculate individual benchmark trends
    .analysis.trends = (.benchmarks | to_entries | map({
        benchmark: .key,
        has_baseline: (.value.baseline != null),
        current_performance: (
            if .value.current then {
                mean_time: .value.current.execution_time_seconds.mean,
                queries_per_second: .value.current.queries_per_second.average,
                successful_runs: .value.current.successful_runs,
                total_runs: .value.current.total_runs
            } else null end
        ),
        baseline_performance: (
            if .value.baseline then {
                mean_time: .value.baseline.execution_time_seconds.mean,
                queries_per_second: .value.baseline.queries_per_second.average
            } else null end
        ),
        change_percent: (
            if (.value.baseline and .value.current) then
                ((.value.current.execution_time_seconds.mean - .value.baseline.execution_time_seconds.mean) / .value.baseline.execution_time_seconds.mean * 100)
            else null end
        ),
        status: (
            if (.value.baseline and .value.current) then
                if ((.value.current.execution_time_seconds.mean - .value.baseline.execution_time_seconds.mean) / .value.baseline.execution_time_seconds.mean * 100) > 5 then
                    "REGRESSION"
                elif ((.value.current.execution_time_seconds.mean - .value.baseline.execution_time_seconds.mean) / .value.baseline.execution_time_seconds.mean * 100) < -5 then
                    "IMPROVEMENT"
                else
                    "STABLE"
                end
            else
                "NO_BASELINE"
            end
        )
    }) | reduce .[] as $item ({}; .[$item.benchmark] = $item)) |
    
    # Calculate overall status
    .analysis.summary.overall_status = (
        if (.analysis.trends | to_entries | map(.value.status) | any(. == "REGRESSION")) then
            "REGRESSION_DETECTED"
        elif (.analysis.trends | to_entries | map(.value.status) | any(. == "IMPROVEMENT")) then
            "IMPROVEMENT_DETECTED"
        else
            "STABLE"
        end
    ) |
    
    # Generate recommendations
    .analysis.recommendations = (
        (.analysis.trends | to_entries | map(
            if .value.status == "REGRESSION" then
                "Performance regression detected in " + .key + " benchmark. Consider investigating query plans and system configuration."
            elif .value.status == "IMPROVEMENT" then
                "Performance improvement detected in " + .key + " benchmark. Document changes for future reference."
            elif .value.status == "NO_BASELINE" then
                "No baseline available for " + .key + " benchmark. Run baseline establishment."
            else
                empty
            end
        )) + 
        (if (.analysis.summary.benchmarks_with_baseline < .analysis.summary.total_benchmarks) then
            ["Consider establishing baselines for all benchmarks to enable proper regression testing."]
        else [] end)
    )
    ' "$data_file" > "$data_file.tmp" && mv "$data_file.tmp" "$data_file"
    
    log_success "Performance trends calculated"
}

# ===================================================================
# REPORT GENERATION
# ===================================================================

# Generate HTML report
generate_html_report() {
    local data_file="$REPORTS_DIR/json/collected_data.json"
    local output_file="$REPORTS_DIR/html/performance_report_$(date +%Y%m%d_%H%M%S).html"
    
    log "Generating HTML report..."
    
    # Generate HTML content
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ExaPG Performance Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header .subtitle {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .section {
            background: white;
            border-radius: 10px;
            padding: 25px;
            margin-bottom: 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .section h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
            margin-top: 0;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            text-transform: uppercase;
        }
        .status-pass { background: #d4edda; color: #155724; }
        .status-regression { background: #f8d7da; color: #721c24; }
        .status-improvement { background: #d1ecf1; color: #0c5460; }
        .status-no-baseline { background: #fff3cd; color: #856404; }
        .benchmark-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .benchmark-card {
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 20px;
            background: white;
        }
        .benchmark-card h3 {
            margin-top: 0;
            color: #495057;
        }
        .performance-chart {
            height: 200px;
            background: #f8f9fa;
            border-radius: 5px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
            margin: 15px 0;
        }
        .recommendations {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px;
            border-radius: 5px;
        }
        .recommendations h4 {
            margin-top: 0;
            color: #1976d2;
        }
        .recommendations ul {
            margin-bottom: 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            border: 1px solid #e9ecef;
            padding: 12px;
            text-align: left;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
EOF
    
    # Add dynamic content using jq
    jq -r '
    def status_class:
        if . == "REGRESSION_DETECTED" or . == "REGRESSION" then "status-regression"
        elif . == "IMPROVEMENT_DETECTED" or . == "IMPROVEMENT" then "status-improvement"
        elif . == "STABLE" then "status-pass"
        else "status-no-baseline"
        end;
        
    def status_text:
        if . == "REGRESSION_DETECTED" then "Regression Detected"
        elif . == "IMPROVEMENT_DETECTED" then "Improvement Detected"
        elif . == "STABLE" then "Stable"
        elif . == "REGRESSION" then "Regression"
        elif . == "IMPROVEMENT" then "Improvement"
        elif . == "NO_BASELINE" then "No Baseline"
        else .
        end;
    
    # Header
    "    <div class=\"header\">",
    "        <h1>ExaPG Performance Report</h1>",
    "        <div class=\"subtitle\">Generated: " + .metadata.generated + "</div>",
    "        <div class=\"subtitle\">Version: " + .metadata.version + " | Host: " + .metadata.hostname + "</div>",
    "    </div>",
    
    # Executive Summary
    "    <div class=\"section\">",
    "        <h2>Executive Summary</h2>",
    "        <div class=\"metrics-grid\">",
    "            <div class=\"metric-card\">",
    "                <div class=\"metric-value\">" + (.analysis.summary.total_benchmarks | tostring) + "</div>",
    "                <div class=\"metric-label\">Total Benchmarks</div>",
    "            </div>",
    "            <div class=\"metric-card\">",
    "                <div class=\"metric-value\">" + (.analysis.summary.benchmarks_with_baseline | tostring) + "</div>",
    "                <div class=\"metric-label\">With Baseline</div>",
    "            </div>",
    "            <div class=\"metric-card\">",
    "                <div class=\"metric-value\">",
    "                    <span class=\"status-badge " + (.analysis.summary.overall_status | status_class) + "\">",
    "                        " + (.analysis.summary.overall_status | status_text),
    "                    </span>",
    "                </div>",
    "                <div class=\"metric-label\">Overall Status</div>",
    "            </div>",
    "        </div>",
    "    </div>",
    
    # System Information
    (if .system_info then
        "    <div class=\"section\">",
        "        <h2>System Information</h2>",
        "        <table>",
        "            <tr><th>PostgreSQL Version</th><td>" + .system_info.postgresql_version + "</td></tr>",
        "            <tr><th>Shared Buffers</th><td>" + .system_info.shared_buffers + "</td></tr>",
        "            <tr><th>Work Memory</th><td>" + .system_info.work_mem + "</td></tr>",
        "            <tr><th>Effective Cache Size</th><td>" + .system_info.effective_cache_size + "</td></tr>",
        "            <tr><th>CPU Cores</th><td>" + .system_info.system.cpu_cores + "</td></tr>",
        "            <tr><th>Memory (GB)</th><td>" + .system_info.system.memory_gb + "</td></tr>",
        "        </table>",
        "    </div>"
    else empty end),
    
    # Benchmark Results
    "    <div class=\"section\">",
    "        <h2>Benchmark Results</h2>",
    "        <div class=\"benchmark-grid\">",
    
    (.analysis.trends | to_entries[] | 
        "            <div class=\"benchmark-card\">",
        "                <h3>" + (.key | ascii_upcase) + " Benchmark</h3>",
        "                <div class=\"status-badge " + (.value.status | status_class) + "\">" + (.value.status | status_text) + "</div>",
        
        (if .value.current_performance then
            "                <div class=\"performance-chart\">",
            "                    <div>",
            "                        <div>Avg Execution Time: " + (.value.current_performance.mean_time | tonumber | . * 1000 | floor | tostring) + "ms</div>",
            "                        <div>Queries/sec: " + (.value.current_performance.queries_per_second | tonumber | floor | tostring) + "</div>",
            "                        <div>Success Rate: " + (.value.current_performance.successful_runs | tostring) + "/" + (.value.current_performance.total_runs | tostring) + "</div>",
            "                    </div>",
            "                </div>"
        else
            "                <div class=\"performance-chart\">No current data available</div>"
        end),
        
        (if (.value.change_percent and (.value.change_percent | type) == "number") then
            "                <div style=\"margin-top: 10px;\">",
            "                    <strong>vs Baseline:</strong> " + (if .value.change_percent > 0 then "+" else "" end) + (.value.change_percent | tonumber | . * 100 | floor / 100 | tostring) + "%",
            "                </div>"
        else empty end),
        
        "            </div>"
    ),
    
    "        </div>",
    "    </div>",
    
    # Recommendations
    (if (.analysis.recommendations | length) > 0 then
        "    <div class=\"section\">",
        "        <h2>Recommendations</h2>",
        "        <div class=\"recommendations\">",
        "            <h4>Action Items:</h4>",
        "            <ul>",
        (.analysis.recommendations[] | "                <li>" + . + "</li>"),
        "            </ul>",
        "        </div>",
        "    </div>"
    else empty end),
    
    # Footer
    "    <div class=\"footer\">",
    "        <p>Report generated by ExaPG Performance Regression Testing Suite</p>",
    "    </div>",
    "</body>",
    "</html>"
    ' "$data_file" >> "$output_file"
    
    log_success "HTML report generated: $output_file"
    echo "$output_file"
}

# Generate Markdown report
generate_markdown_report() {
    local data_file="$REPORTS_DIR/json/collected_data.json"
    local output_file="$REPORTS_DIR/markdown/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    log "Generating Markdown report..."
    
    # Generate Markdown content using jq
    jq -r '
    def status_emoji:
        if . == "REGRESSION_DETECTED" or . == "REGRESSION" then "🔴"
        elif . == "IMPROVEMENT_DETECTED" or . == "IMPROVEMENT" then "🟢"
        elif . == "STABLE" then "🟡"
        else "⚪"
        end;
    
    "# ExaPG Performance Report",
    "",
    "**Generated:** " + .metadata.generated,
    "**Version:** " + .metadata.version,
    "**Host:** " + .metadata.hostname,
    "",
    "## Executive Summary",
    "",
    "| Metric | Value |",
    "|--------|-------|",
    "| Total Benchmarks | " + (.analysis.summary.total_benchmarks | tostring) + " |",
    "| Benchmarks with Baseline | " + (.analysis.summary.benchmarks_with_baseline | tostring) + " |",
    "| Overall Status | " + (.analysis.summary.overall_status | status_emoji) + " " + .analysis.summary.overall_status + " |",
    "",
    
    (if .system_info then
        "## System Information",
        "",
        "| Component | Value |",
        "|-----------|-------|",
        "| PostgreSQL Version | " + .system_info.postgresql_version + " |",
        "| Shared Buffers | " + .system_info.shared_buffers + " |",
        "| Work Memory | " + .system_info.work_mem + " |",
        "| Effective Cache Size | " + .system_info.effective_cache_size + " |",
        "| CPU Cores | " + .system_info.system.cpu_cores + " |",
        "| Memory (GB) | " + .system_info.system.memory_gb + " |",
        ""
    else empty end),
    
    "## Benchmark Results",
    "",
    (.analysis.trends | to_entries[] | 
        "### " + (.key | ascii_upcase) + " Benchmark",
        "",
        "**Status:** " + (.value.status | status_emoji) + " " + .value.status,
        "",
        (if .value.current_performance then
            "- **Average Execution Time:** " + (.value.current_performance.mean_time | tonumber | . * 1000 | floor | tostring) + "ms",
            "- **Queries per Second:** " + (.value.current_performance.queries_per_second | tonumber | floor | tostring),
            "- **Success Rate:** " + (.value.current_performance.successful_runs | tostring) + "/" + (.value.current_performance.total_runs | tostring) + " runs"
        else
            "- No current performance data available"
        end),
        "",
        (if (.value.change_percent and (.value.change_percent | type) == "number") then
            "**Change vs Baseline:** " + (if .value.change_percent > 0 then "+" else "" end) + (.value.change_percent | tonumber | . * 100 | floor / 100 | tostring) + "%",
            ""
        else empty end)
    ),
    
    (if (.analysis.recommendations | length) > 0 then
        "## Recommendations",
        "",
        (.analysis.recommendations[] | "- " + .),
        ""
    else empty end),
    
    "---",
    "*Report generated by ExaPG Performance Regression Testing Suite*"
    ' "$data_file" > "$output_file"
    
    log_success "Markdown report generated: $output_file"
    echo "$output_file"
}

# Generate comprehensive JSON report
generate_json_report() {
    local data_file="$REPORTS_DIR/json/collected_data.json"
    local output_file="$REPORTS_DIR/json/performance_report_$(date +%Y%m%d_%H%M%S).json"
    
    log "Generating JSON report..."
    
    # Copy and format the collected data
    jq '.' "$data_file" > "$output_file"
    
    log_success "JSON report generated: $output_file"
    echo "$output_file"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    local format="${1:-$OUTPUT_FORMAT}"
    
    log "Starting ExaPG performance report generation..."
    log "Output format: $format"
    
    # Setup
    check_dependencies
    setup_directories
    
    # Collect and analyze data
    collect_test_data
    calculate_trends
    
    # Generate reports
    local report_files=()
    
    case "$format" in
        "html")
            report_files+=($(generate_html_report))
            ;;
        "markdown"|"md")
            report_files+=($(generate_markdown_report))
            ;;
        "json")
            report_files+=($(generate_json_report))
            ;;
        "all")
            report_files+=($(generate_html_report))
            report_files+=($(generate_markdown_report))
            report_files+=($(generate_json_report))
            ;;
        *)
            log_error "Unknown format: $format"
            log_error "Supported formats: html, markdown, json, all"
            return 1
            ;;
    esac
    
    # Summary
    log_success "Report generation completed!"
    log "Generated reports:"
    for file in "${report_files[@]}"; do
        log "  - $file"
    done
    
    # Open HTML report if available and on desktop
    if [[ "$format" == "html" ]] || [[ "$format" == "all" ]]; then
        local html_file=$(echo "${report_files[0]}")
        if [[ -f "$html_file" ]] && command -v xdg-open >/dev/null 2>&1; then
            log "Opening report in browser..."
            xdg-open "$html_file" 2>/dev/null || true
        fi
    fi
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Performance Regression Report Generator

This script generates comprehensive performance reports from benchmark results.

Usage: $0 [format]

Output Formats:
  html       - Interactive HTML report (default)
  markdown   - Markdown report for documentation
  json       - Structured JSON data
  all        - Generate all formats

Environment Variables:
  REPORT_FORMAT  - Default output format (default: html)

Examples:
  $0           # Generate HTML report
  $0 markdown  # Generate Markdown report
  $0 all       # Generate all report formats

Prerequisites:
  - jq (required for JSON processing)
  - pandoc (optional, for enhanced HTML formatting)

Output Directories:
  benchmark/reports/html/      - HTML reports
  benchmark/reports/markdown/  - Markdown reports  
  benchmark/reports/json/      - JSON reports
EOF
    exit 0
fi

# Run main function
main "${1:-}" 