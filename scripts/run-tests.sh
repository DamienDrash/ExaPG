#!/bin/bash
# ===================================================================
# ExaPG Automated Test Runner
# ===================================================================
# TESTING FIX: TEST-003 - Automated Test Runner for CI/CD
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TESTS_DIR="$PROJECT_ROOT/tests"

# Test configuration
readonly DEFAULT_TIMEOUT=300
readonly DEFAULT_RETRY_COUNT=3
readonly DEFAULT_PARALLEL_JOBS=4

# Output directories
readonly TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
readonly COVERAGE_DIR="$TEST_RESULTS_DIR/coverage"
readonly REPORTS_DIR="$TEST_RESULTS_DIR/reports"

# ===================================================================
# LOGGING
# ===================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[TEST-RUNNER]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[TEST-RUNNER] ✓${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[TEST-RUNNER] ⚠${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[TEST-RUNNER] ✗${NC} $*" >&2
}

log_info() {
    echo -e "${CYAN}[TEST-RUNNER] ℹ${NC} $*" >&2
}

log_stage() {
    echo -e "${PURPLE}[TEST-RUNNER] ▶${NC} $*" >&2
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Create required directories
setup_test_environment() {
    log "Setting up test environment..."
    
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$COVERAGE_DIR"
    mkdir -p "$REPORTS_DIR"
    
    # Create test logs directory
    mkdir -p "$TEST_RESULTS_DIR/logs"
    
    # Set test environment variables
    export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-$DEFAULT_TIMEOUT}"
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp/exapg_tests}"
    export TEST_RUNNER_LOG_FILE="$TEST_RESULTS_DIR/logs/test-runner.log"
    
    # Create test tmpdir
    mkdir -p "$BATS_TMPDIR"
    
    log_success "Test environment setup completed"
}

# Check if BATS is available
check_bats() {
    if [[ ! -f "$TESTS_DIR/bats/bin/bats" ]]; then
        log_warning "BATS not found, setting up..."
        
        if [[ -f "$TESTS_DIR/setup.sh" ]]; then
            cd "$TESTS_DIR"
            bash setup.sh
        else
            log_error "BATS setup script not found"
            return 1
        fi
    fi
    
    export PATH="$TESTS_DIR/bats/bin:$PATH"
    
    if ! command -v bats >/dev/null 2>&1; then
        log_error "BATS is not available after setup"
        return 1
    fi
    
    log_success "BATS is available"
    return 0
}

# Run a specific test suite
run_test_suite() {
    local suite_name="$1"
    local test_path="$2"
    local output_format="${3:-tap}"
    local timeout="${4:-$DEFAULT_TIMEOUT}"
    
    log_stage "Running $suite_name tests..."
    
    local output_file="$TEST_RESULTS_DIR/${suite_name}-results.${output_format}"
    local log_file="$TEST_RESULTS_DIR/logs/${suite_name}.log"
    
    # Create test command
    local test_cmd="timeout $timeout bats"
    
    # Add output format
    case "$output_format" in
        "tap")
            test_cmd="$test_cmd --tap"
            ;;
        "junit")
            test_cmd="$test_cmd --formatter junit"
            ;;
        "pretty")
            test_cmd="$test_cmd --pretty"
            ;;
    esac
    
    # Add test path
    test_cmd="$test_cmd $test_path"
    
    # Run tests with error handling
    local start_time=$(date +%s)
    local exit_code=0
    
    if eval "$test_cmd" > "$output_file" 2> "$log_file"; then
        log_success "$suite_name tests passed"
    else
        exit_code=$?
        log_error "$suite_name tests failed (exit code: $exit_code)"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Generate test summary
    generate_test_summary "$suite_name" "$output_file" "$duration" "$exit_code"
    
    return $exit_code
}

# Generate test summary
generate_test_summary() {
    local suite_name="$1"
    local results_file="$2"
    local duration="$3"
    local exit_code="$4"
    
    local summary_file="$TEST_RESULTS_DIR/${suite_name}-summary.txt"
    
    # Count test results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    if [[ -f "$results_file" ]]; then
        if grep -q "^1\\.\\." "$results_file"; then
            # TAP format
            total_tests=$(grep "^1\\.\\." "$results_file" | cut -d'.' -f3)
            passed_tests=$(grep -c "^ok " "$results_file" 2>/dev/null || echo 0)
            failed_tests=$(grep -c "^not ok " "$results_file" 2>/dev/null || echo 0)
            skipped_tests=$(grep -c "# SKIP" "$results_file" 2>/dev/null || echo 0)
        fi
    fi
    
    # Create summary
    cat > "$summary_file" << EOF
Test Suite: $suite_name
Duration: ${duration}s
Exit Code: $exit_code
Status: $([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")

Test Results:
- Total: $total_tests
- Passed: $passed_tests
- Failed: $failed_tests
- Skipped: $skipped_tests

Generated: $(date)
EOF

    log_info "$suite_name summary: $passed_tests/$total_tests passed (${duration}s)"
}

# Run unit tests
run_unit_tests() {
    local parallel="${1:-false}"
    local format="${2:-tap}"
    
    log_stage "Running unit tests..."
    
    if [[ ! -d "$TESTS_DIR/unit" ]]; then
        log_warning "Unit tests directory not found"
        return 0
    fi
    
    local unit_tests=($(find "$TESTS_DIR/unit" -name "*.bats" | sort))
    
    if [[ ${#unit_tests[@]} -eq 0 ]]; then
        log_warning "No unit tests found"
        return 0
    fi
    
    local exit_code=0
    
    if [[ "$parallel" == "true" ]]; then
        # Run tests in parallel
        log_info "Running ${#unit_tests[@]} unit test files in parallel..."
        
        local pids=()
        local job_count=0
        local max_jobs="${EXAPG_TEST_PARALLEL_JOBS:-$DEFAULT_PARALLEL_JOBS}"
        
        for test_file in "${unit_tests[@]}"; do
            local test_name=$(basename "$test_file" .bats)
            
            # Wait if we've reached max parallel jobs
            if [[ $job_count -ge $max_jobs ]]; then
                wait "${pids[0]}" || exit_code=1
                pids=("${pids[@]:1}")  # Remove first element
                ((job_count--))
            fi
            
            # Start test in background
            (run_test_suite "unit-$test_name" "$test_file" "$format") &
            pids+=($!)
            ((job_count++))
        done
        
        # Wait for remaining jobs
        for pid in "${pids[@]}"; do
            wait "$pid" || exit_code=1
        done
    else
        # Run tests sequentially
        for test_file in "${unit_tests[@]}"; do
            local test_name=$(basename "$test_file" .bats)
            run_test_suite "unit-$test_name" "$test_file" "$format" || exit_code=1
        done
    fi
    
    return $exit_code
}

# Run integration tests
run_integration_tests() {
    local format="${1:-tap}"
    
    log_stage "Running integration tests..."
    
    if [[ ! -d "$TESTS_DIR/integration" ]]; then
        log_warning "Integration tests directory not found"
        return 0
    fi
    
    # Set environment for integration tests
    export EXAPG_RUN_INTEGRATION_TESTS=true
    
    local integration_tests=($(find "$TESTS_DIR/integration" -name "*.bats" | sort))
    
    if [[ ${#integration_tests[@]} -eq 0 ]]; then
        log_warning "No integration tests found"
        return 0
    fi
    
    local exit_code=0
    
    # Run integration tests sequentially (they may have dependencies)
    for test_file in "${integration_tests[@]}"; do
        local test_name=$(basename "$test_file" .bats)
        run_test_suite "integration-$test_name" "$test_file" "$format" 600 || exit_code=1
    done
    
    return $exit_code
}

# Run end-to-end tests
run_e2e_tests() {
    local format="${1:-tap}"
    
    log_stage "Running end-to-end tests..."
    
    if [[ ! -d "$TESTS_DIR/e2e" ]]; then
        log_warning "E2E tests directory not found"
        return 0
    fi
    
    # Check if E2E tests are enabled
    if [[ "${EXAPG_RUN_E2E_TESTS:-false}" != "true" ]]; then
        log_warning "E2E tests disabled (set EXAPG_RUN_E2E_TESTS=true to enable)"
        return 0
    fi
    
    local e2e_tests=($(find "$TESTS_DIR/e2e" -name "*.bats" | sort))
    
    if [[ ${#e2e_tests[@]} -eq 0 ]]; then
        log_warning "No E2E tests found"
        return 0
    fi
    
    local exit_code=0
    
    # Run E2E tests sequentially with longer timeout
    for test_file in "${e2e_tests[@]}"; do
        local test_name=$(basename "$test_file" .bats)
        run_test_suite "e2e-$test_name" "$test_file" "$format" 900 || exit_code=1
    done
    
    return $exit_code
}

# Run configuration validation
run_config_validation() {
    log_stage "Running configuration validation..."
    
    local config_script="$PROJECT_ROOT/scripts/validate-config.sh"
    
    if [[ ! -f "$config_script" ]]; then
        log_error "Configuration validation script not found: $config_script"
        return 1
    fi
    
    local output_file="$TEST_RESULTS_DIR/config-validation.log"
    local summary_file="$TEST_RESULTS_DIR/config-validation-summary.txt"
    
    local start_time=$(date +%s)
    local exit_code=0
    
    if bash "$config_script" > "$output_file" 2>&1; then
        log_success "Configuration validation passed"
    else
        exit_code=$?
        log_error "Configuration validation failed"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Create summary
    cat > "$summary_file" << EOF
Configuration Validation Summary
===============================
Duration: ${duration}s
Exit Code: $exit_code
Status: $([ $exit_code -eq 0 ] && echo "PASSED" || echo "FAILED")

Output file: $output_file
Generated: $(date)
EOF

    return $exit_code
}

# Generate HTML report
generate_html_report() {
    log_stage "Generating HTML test report..."
    
    local html_report="$REPORTS_DIR/test-report.html"
    
    cat > "$html_report" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ExaPG Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid #007bff; }
        .summary-card.passed { border-left-color: #28a745; }
        .summary-card.failed { border-left-color: #dc3545; }
        .summary-card.warning { border-left-color: #ffc107; }
        .test-suite { margin-bottom: 20px; border: 1px solid #ddd; border-radius: 8px; overflow: hidden; }
        .test-suite-header { background: #007bff; color: white; padding: 15px; font-weight: bold; }
        .test-suite-header.passed { background: #28a745; }
        .test-suite-header.failed { background: #dc3545; }
        .test-suite-content { padding: 15px; }
        .test-details { margin-top: 10px; }
        .status-badge { padding: 4px 8px; border-radius: 4px; color: white; font-size: 12px; font-weight: bold; }
        .status-passed { background: #28a745; }
        .status-failed { background: #dc3545; }
        .status-skipped { background: #6c757d; }
        .timestamp { color: #666; font-size: 12px; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 4px; overflow-x: auto; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ExaPG Test Report</h1>
            <p class="timestamp">Generated: {{TIMESTAMP}}</p>
        </div>
        
        <div class="summary">
            {{SUMMARY_CARDS}}
        </div>
        
        <div class="test-results">
            {{TEST_SUITES}}
        </div>
    </div>
</body>
</html>
EOF

    # Generate summary data
    local total_suites=0
    local passed_suites=0
    local failed_suites=0
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    # Process test results
    local summary_cards=""
    local test_suites=""
    
    for summary_file in "$TEST_RESULTS_DIR"/*-summary.txt; do
        if [[ -f "$summary_file" ]]; then
            local suite_name=$(basename "$summary_file" -summary.txt)
            local status="UNKNOWN"
            local duration="0"
            local suite_total=0
            local suite_passed=0
            local suite_failed=0
            local suite_skipped=0
            
            # Parse summary file
            while IFS= read -r line; do
                case "$line" in
                    "Status: PASSED") status="PASSED"; ((passed_suites++)) ;;
                    "Status: FAILED") status="FAILED"; ((failed_suites++)) ;;
                    "Duration: "*) duration="${line#Duration: }" ;;
                    "- Total: "*) suite_total="${line#- Total: }" ;;
                    "- Passed: "*) suite_passed="${line#- Passed: }" ;;
                    "- Failed: "*) suite_failed="${line#- Failed: }" ;;
                    "- Skipped: "*) suite_skipped="${line#- Skipped: }" ;;
                esac
            done < "$summary_file"
            
            ((total_suites++))
            ((total_tests += suite_total))
            ((passed_tests += suite_passed))
            ((failed_tests += suite_failed))
            ((skipped_tests += suite_skipped))
            
            # Create test suite HTML
            local suite_class=$([ "$status" = "PASSED" ] && echo "passed" || echo "failed")
            test_suites+="
            <div class=\"test-suite\">
                <div class=\"test-suite-header $suite_class\">
                    $suite_name - $status ($duration)
                </div>
                <div class=\"test-suite-content\">
                    <div class=\"test-details\">
                        <span class=\"status-badge status-passed\">Passed: $suite_passed</span>
                        <span class=\"status-badge status-failed\">Failed: $suite_failed</span>
                        <span class=\"status-badge status-skipped\">Skipped: $suite_skipped</span>
                    </div>
                </div>
            </div>"
        fi
    done
    
    # Create summary cards
    summary_cards="
    <div class=\"summary-card $([ $failed_suites -eq 0 ] && echo "passed" || echo "failed")\">
        <h3>Test Suites</h3>
        <p>$passed_suites/$total_suites passed</p>
    </div>
    <div class=\"summary-card $([ $failed_tests -eq 0 ] && echo "passed" || echo "failed")\">
        <h3>Test Cases</h3>
        <p>$passed_tests/$total_tests passed</p>
    </div>
    <div class=\"summary-card $([ $skipped_tests -eq 0 ] && echo "passed" || echo "warning")\">
        <h3>Skipped</h3>
        <p>$skipped_tests tests</p>
    </div>
    <div class=\"summary-card\">
        <h3>Overall Status</h3>
        <p>$([ $failed_suites -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")</p>
    </div>"
    
    # Replace placeholders
    sed -i "s|{{TIMESTAMP}}|$(date)|g" "$html_report"
    sed -i "s|{{SUMMARY_CARDS}}|$summary_cards|g" "$html_report"
    sed -i "s|{{TEST_SUITES}}|$test_suites|g" "$html_report"
    
    log_success "HTML report generated: $html_report"
}

# Generate JUnit XML report
generate_junit_report() {
    log_stage "Generating JUnit XML report..."
    
    local junit_report="$REPORTS_DIR/junit-report.xml"
    
    cat > "$junit_report" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
EOF

    # Process each test suite
    for results_file in "$TEST_RESULTS_DIR"/*-results.tap; do
        if [[ -f "$results_file" ]]; then
            local suite_name=$(basename "$results_file" -results.tap)
            local summary_file="$TEST_RESULTS_DIR/${suite_name}-summary.txt"
            
            local total_tests=0
            local failed_tests=0
            local duration=0
            
            if [[ -f "$summary_file" ]]; then
                total_tests=$(grep "^- Total:" "$summary_file" | cut -d: -f2 | xargs)
                failed_tests=$(grep "^- Failed:" "$summary_file" | cut -d: -f2 | xargs)
                duration=$(grep "^Duration:" "$summary_file" | cut -d: -f2 | xargs | tr -d 's')
            fi
            
            cat >> "$junit_report" << EOF
  <testsuite name="$suite_name" tests="$total_tests" failures="$failed_tests" time="$duration">
EOF

            # Parse TAP results and convert to JUnit format
            local test_count=0
            while IFS= read -r line; do
                if [[ "$line" =~ ^(ok|not\ ok)\ [0-9]+\ (.+)$ ]]; then
                    local status="${BASH_REMATCH[1]}"
                    local test_name="${BASH_REMATCH[2]}"
                    
                    if [[ "$status" == "ok" ]]; then
                        echo "    <testcase name=\"$test_name\" />" >> "$junit_report"
                    else
                        echo "    <testcase name=\"$test_name\">" >> "$junit_report"
                        echo "      <failure message=\"Test failed\">$test_name failed</failure>" >> "$junit_report"
                        echo "    </testcase>" >> "$junit_report"
                    fi
                fi
            done < "$results_file"
            
            echo "  </testsuite>" >> "$junit_report"
        fi
    done
    
    echo "</testsuites>" >> "$junit_report"
    
    log_success "JUnit report generated: $junit_report"
}

# Cleanup function
cleanup_test_environment() {
    log "Cleaning up test environment..."
    
    # Remove temporary files
    if [[ -n "${BATS_TMPDIR:-}" && -d "$BATS_TMPDIR" ]]; then
        rm -rf "$BATS_TMPDIR" 2>/dev/null || true
    fi
    
    # Clean up any test containers
    if command -v docker >/dev/null 2>&1; then
        docker ps -a --filter "label=com.exapg.test=true" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
        docker network ls --filter "label=com.exapg.test=true" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
        docker volume ls --filter "label=com.exapg.test=true" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
    fi
    
    log_success "Test environment cleanup completed"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    local test_type="${1:-all}"
    local output_format="${2:-tap}"
    local parallel="${3:-false}"
    
    log "Starting ExaPG test suite..."
    log "Test type: $test_type"
    log "Output format: $output_format"
    log "Parallel execution: $parallel"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Setup test environment
    setup_test_environment
    
    # Check BATS availability
    if ! check_bats; then
        log_error "Cannot proceed without BATS testing framework"
        exit 1
    fi
    
    # Trap for cleanup
    trap cleanup_test_environment EXIT
    
    local total_exit_code=0
    
    # Run tests based on type
    case "$test_type" in
        "unit")
            run_unit_tests "$parallel" "$output_format" || total_exit_code=1
            ;;
        "integration")
            run_integration_tests "$output_format" || total_exit_code=1
            ;;
        "e2e")
            run_e2e_tests "$output_format" || total_exit_code=1
            ;;
        "config")
            run_config_validation || total_exit_code=1
            ;;
        "all")
            # Run all test types
            run_config_validation || total_exit_code=1
            run_unit_tests "$parallel" "$output_format" || total_exit_code=1
            run_integration_tests "$output_format" || total_exit_code=1
            
            # Only run E2E tests if explicitly enabled
            if [[ "${EXAPG_RUN_E2E_TESTS:-false}" == "true" ]]; then
                run_e2e_tests "$output_format" || total_exit_code=1
            else
                log_info "E2E tests skipped (set EXAPG_RUN_E2E_TESTS=true to enable)"
            fi
            ;;
        *)
            log_error "Unknown test type: $test_type"
            log_error "Valid types: unit, integration, e2e, config, all"
            exit 1
            ;;
    esac
    
    # Generate reports
    generate_html_report
    generate_junit_report
    
    # Final summary
    echo
    log "Test execution completed"
    
    if [[ $total_exit_code -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed (exit code: $total_exit_code)"
    fi
    
    log_info "Test results: $TEST_RESULTS_DIR"
    log_info "HTML report: $REPORTS_DIR/test-report.html"
    log_info "JUnit report: $REPORTS_DIR/junit-report.xml"
    
    return $total_exit_code
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Automated Test Runner

This script runs the complete ExaPG test suite with various options for
different testing scenarios.

Usage: $0 [test_type] [output_format] [parallel]

Test Types:
  unit          - Run only unit tests
  integration   - Run only integration tests
  e2e           - Run only end-to-end tests
  config        - Run only configuration validation
  all           - Run all tests (default)

Output Formats:
  tap           - TAP format (default)
  junit         - JUnit XML format
  pretty        - Human-readable format

Parallel Execution:
  true          - Run unit tests in parallel
  false         - Run tests sequentially (default)

Environment Variables:
  EXAPG_RUN_E2E_TESTS=true         - Enable E2E tests
  EXAPG_RUN_INTEGRATION_TESTS=true - Enable integration tests
  EXAPG_TEST_PARALLEL_JOBS=4       - Number of parallel jobs
  BATS_TEST_TIMEOUT=300            - Test timeout in seconds

Examples:
  $0                               # Run all tests
  $0 unit tap true                # Run unit tests in parallel
  $0 integration                  # Run only integration tests
  $0 config                       # Run only configuration validation

Output:
  test-results/                   - Test results and logs
  test-results/reports/           - HTML and JUnit reports

Exit codes:
  0 - All tests passed
  1 - One or more tests failed
EOF
    exit 0
fi

# Run main function
main "${1:-all}" "${2:-tap}" "${3:-false}" 