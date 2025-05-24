#!/bin/bash
# ===================================================================
# ExaPG Testing Framework Setup
# ===================================================================
# TESTING FIX: TEST-001 - BATS Installation and Setup
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly BATS_VERSION="v1.10.0"
readonly BATS_DIR="$SCRIPT_DIR/bats"

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST-SETUP] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST-SETUP] [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [TEST-SETUP] [SUCCESS] $*" >&2
}

# ===================================================================
# BATS INSTALLATION
# ===================================================================

install_bats() {
    log "Installing BATS (Bash Automated Testing System)..."
    
    # Create bats directory
    mkdir -p "$BATS_DIR"
    
    # Check if BATS is already installed
    if [[ -f "$BATS_DIR/bin/bats" ]]; then
        log "BATS already installed, checking version..."
        local current_version=$("$BATS_DIR/bin/bats" --version | cut -d' ' -f2)
        if [[ "$current_version" == "${BATS_VERSION#v}" ]]; then
            log_success "BATS $current_version is up to date"
            return 0
        else
            log "Updating BATS from $current_version to ${BATS_VERSION#v}"
            rm -rf "$BATS_DIR"
            mkdir -p "$BATS_DIR"
        fi
    fi
    
    # Install BATS
    log "Downloading BATS $BATS_VERSION..."
    
    if command -v git >/dev/null 2>&1; then
        # Use git if available
        git clone --depth 1 --branch "$BATS_VERSION" \
            https://github.com/bats-core/bats-core.git \
            "$BATS_DIR/bats-core"
        
        # Install BATS
        cd "$BATS_DIR/bats-core"
        ./install.sh "$BATS_DIR"
        cd "$PROJECT_ROOT"
        
        # Cleanup
        rm -rf "$BATS_DIR/bats-core"
    else
        # Fallback to curl/wget
        local temp_dir="/tmp/bats-$$"
        mkdir -p "$temp_dir"
        
        if command -v curl >/dev/null 2>&1; then
            curl -L "https://github.com/bats-core/bats-core/archive/refs/tags/$BATS_VERSION.tar.gz" \
                | tar -xz -C "$temp_dir" --strip-components=1
        elif command -v wget >/dev/null 2>&1; then
            wget -O- "https://github.com/bats-core/bats-core/archive/refs/tags/$BATS_VERSION.tar.gz" \
                | tar -xz -C "$temp_dir" --strip-components=1
        else
            log_error "Neither git, curl, nor wget found. Cannot install BATS."
            return 1
        fi
        
        # Install BATS
        cd "$temp_dir"
        ./install.sh "$BATS_DIR"
        cd "$PROJECT_ROOT"
        
        # Cleanup
        rm -rf "$temp_dir"
    fi
    
    # Install BATS helper libraries
    install_bats_helpers
    
    log_success "BATS installation completed"
}

# Install BATS helper libraries
install_bats_helpers() {
    log "Installing BATS helper libraries..."
    
    local helpers_dir="$BATS_DIR/helpers"
    mkdir -p "$helpers_dir"
    
    # Install bats-support (test helpers)
    if [[ ! -d "$helpers_dir/bats-support" ]]; then
        git clone --depth 1 \
            https://github.com/bats-core/bats-support.git \
            "$helpers_dir/bats-support" 2>/dev/null || {
            log "Warning: Could not install bats-support"
        }
    fi
    
    # Install bats-assert (assertion helpers)
    if [[ ! -d "$helpers_dir/bats-assert" ]]; then
        git clone --depth 1 \
            https://github.com/bats-core/bats-assert.git \
            "$helpers_dir/bats-assert" 2>/dev/null || {
            log "Warning: Could not install bats-assert"
        }
    fi
    
    # Install bats-file (file testing helpers)
    if [[ ! -d "$helpers_dir/bats-file" ]]; then
        git clone --depth 1 \
            https://github.com/bats-core/bats-file.git \
            "$helpers_dir/bats-file" 2>/dev/null || {
            log "Warning: Could not install bats-file"
        }
    fi
}

# ===================================================================
# TEST ENVIRONMENT SETUP
# ===================================================================

setup_test_environment() {
    log "Setting up test environment..."
    
    # Create test directories
    mkdir -p "$SCRIPT_DIR/unit"
    mkdir -p "$SCRIPT_DIR/integration"
    mkdir -p "$SCRIPT_DIR/e2e"
    mkdir -p "$SCRIPT_DIR/fixtures"
    mkdir -p "$SCRIPT_DIR/tmp"
    
    # Create test configuration
    create_test_config
    
    # Create test utilities
    create_test_utilities
    
    log_success "Test environment setup completed"
}

create_test_config() {
    log "Creating test configuration..."
    
    cat > "$SCRIPT_DIR/test.conf" << 'EOF'
# ===================================================================
# ExaPG Test Configuration
# ===================================================================

# Test database settings
TEST_DB_HOST=localhost
TEST_DB_PORT=5432
TEST_DB_NAME=exadb_test
TEST_DB_USER=postgres
TEST_DB_PASSWORD=test_password

# Docker test settings
TEST_COMPOSE_PROJECT=exapg_test
TEST_NETWORK=exapg_test_network

# Test timeout settings
TEST_TIMEOUT_SHORT=30
TEST_TIMEOUT_MEDIUM=120
TEST_TIMEOUT_LONG=300

# Test data settings
TEST_DATA_SIZE=small
TEST_PARALLEL_JOBS=2

# Cleanup settings
TEST_CLEANUP_ON_SUCCESS=true
TEST_CLEANUP_ON_FAILURE=false
EOF
}

create_test_utilities() {
    log "Creating test utilities..."
    
    cat > "$SCRIPT_DIR/test-helpers.bash" << 'EOF'
#!/bin/bash
# ===================================================================
# ExaPG Test Helper Functions
# ===================================================================

# Load BATS helpers if available
if [[ -f "${BATS_TEST_DIRNAME}/bats/helpers/bats-support/load.bash" ]]; then
    load "bats/helpers/bats-support/load.bash"
fi

if [[ -f "${BATS_TEST_DIRNAME}/bats/helpers/bats-assert/load.bash" ]]; then
    load "bats/helpers/bats-assert/load.bash"
fi

if [[ -f "${BATS_TEST_DIRNAME}/bats/helpers/bats-file/load.bash" ]]; then
    load "bats/helpers/bats-file/load.bash"
fi

# Test configuration
if [[ -f "${BATS_TEST_DIRNAME}/test.conf" ]]; then
    source "${BATS_TEST_DIRNAME}/test.conf"
fi

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Setup test environment for each test
setup_test() {
    # Create temporary directory for test
    export TEST_TEMP_DIR="${BATS_TEST_DIRNAME}/tmp/test_$$_${BATS_TEST_NUMBER}"
    mkdir -p "$TEST_TEMP_DIR"
    
    # Set test environment variables
    export EXAPG_TEST_MODE=true
    export EXAPG_LOG_LEVEL=ERROR
    export EXAPG_TEST_DIR="$TEST_TEMP_DIR"
}

# Cleanup after each test
teardown_test() {
    # Cleanup temporary files if test passed
    if [[ "$TEST_CLEANUP_ON_SUCCESS" == "true" ]] && [[ -z "${BATS_TEST_FAILED:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    fi
    
    # Always cleanup on failure if configured
    if [[ "$TEST_CLEANUP_ON_FAILURE" == "true" ]] && [[ -n "${BATS_TEST_FAILED:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
    fi
}

# Wait for service to be ready
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-60}"
    local count=0
    
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            return 1
        fi
        sleep 1
        ((count++))
    done
    return 0
}

# Check if Docker is available
docker_available() {
    command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1
}

# Check if Docker Compose is available
docker_compose_available() {
    (command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1)
}

# Start test database
start_test_database() {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Stop any existing test containers
    docker stop "${TEST_COMPOSE_PROJECT}_postgres_1" 2>/dev/null || true
    docker rm "${TEST_COMPOSE_PROJECT}_postgres_1" 2>/dev/null || true
    
    # Start test PostgreSQL container
    docker run -d \
        --name "${TEST_COMPOSE_PROJECT}_postgres_1" \
        -e POSTGRES_DB="$TEST_DB_NAME" \
        -e POSTGRES_USER="$TEST_DB_USER" \
        -e POSTGRES_PASSWORD="$TEST_DB_PASSWORD" \
        -p "${TEST_DB_PORT}:5432" \
        postgres:15-alpine
    
    # Wait for database to be ready
    wait_for_service "$TEST_DB_HOST" "$TEST_DB_PORT" 60
}

# Stop test database
stop_test_database() {
    docker stop "${TEST_COMPOSE_PROJECT}_postgres_1" 2>/dev/null || true
    docker rm "${TEST_COMPOSE_PROJECT}_postgres_1" 2>/dev/null || true
}

# Execute SQL on test database
execute_sql() {
    local sql="$1"
    docker exec "${TEST_COMPOSE_PROJECT}_postgres_1" \
        psql -U "$TEST_DB_USER" -d "$TEST_DB_NAME" -c "$sql"
}

# Assert command succeeds
assert_command_success() {
    local cmd="$1"
    run bash -c "$cmd"
    assert_success
}

# Assert command fails
assert_command_failure() {
    local cmd="$1"
    run bash -c "$cmd"
    assert_failure
}

# Assert file contains string
assert_file_contains() {
    local file="$1"
    local string="$2"
    assert_file_exists "$file"
    run grep -q "$string" "$file"
    assert_success
}

# Assert file does not contain string
assert_file_not_contains() {
    local file="$1"
    local string="$2"
    if [[ -f "$file" ]]; then
        run grep -q "$string" "$file"
        assert_failure
    fi
}

# Create test file with content
create_test_file() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

# Generate random string
random_string() {
    local length="${1:-10}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Log test message
test_log() {
    echo "# $*" >&3
}
EOF
}

# ===================================================================
# VALIDATION
# ===================================================================

validate_installation() {
    log "Validating BATS installation..."
    
    # Check BATS binary
    if [[ ! -f "$BATS_DIR/bin/bats" ]]; then
        log_error "BATS binary not found"
        return 1
    fi
    
    # Check BATS version
    local version=$("$BATS_DIR/bin/bats" --version 2>/dev/null || echo "unknown")
    log "BATS version: $version"
    
    # Check helper libraries
    local helpers_dir="$BATS_DIR/helpers"
    for helper in bats-support bats-assert bats-file; do
        if [[ -d "$helpers_dir/$helper" ]]; then
            log "✓ $helper installed"
        else
            log "⚠ $helper not available (optional)"
        fi
    done
    
    # Test BATS with simple test
    create_validation_test
    
    log_success "BATS installation validated"
}

create_validation_test() {
    local test_file="$SCRIPT_DIR/validation.bats"
    
    cat > "$test_file" << 'EOF'
#!/usr/bin/env bats

@test "BATS is working correctly" {
    result="$(echo 'Hello, BATS!')"
    [ "$result" = "Hello, BATS!" ]
}

@test "Basic arithmetic works" {
    result="$((2 + 2))"
    [ "$result" -eq 4 ]
}

@test "Environment variable access" {
    export TEST_VAR="test_value"
    [ "$TEST_VAR" = "test_value" ]
}
EOF
    
    # Run validation test
    log "Running validation test..."
    if "$BATS_DIR/bin/bats" "$test_file"; then
        log_success "Validation test passed"
    else
        log_error "Validation test failed"
        return 1
    fi
    
    # Cleanup validation test
    rm -f "$test_file"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    log "Setting up ExaPG Testing Framework..."
    
    # Install BATS
    install_bats
    
    # Setup test environment
    setup_test_environment
    
    # Validate installation
    validate_installation
    
    log_success "ExaPG Testing Framework setup completed!"
    
    # Print usage information
    cat << EOF

ExaPG Testing Framework is now ready!

Usage:
  # Run all tests
  $BATS_DIR/bin/bats tests/unit/*.bats tests/integration/*.bats

  # Run specific test suite
  $BATS_DIR/bin/bats tests/unit/
  $BATS_DIR/bin/bats tests/integration/
  $BATS_DIR/bin/bats tests/e2e/

  # Run single test file
  $BATS_DIR/bin/bats tests/unit/test-cli-functions.bats

  # Run with verbose output
  $BATS_DIR/bin/bats -t tests/unit/

Available test helpers:
  - bats-support: Enhanced test support
  - bats-assert: Assertion helpers
  - bats-file: File testing helpers

Test configuration: tests/test.conf
Test helpers: tests/test-helpers.bash

Next steps:
1. Create your test files in tests/unit/, tests/integration/, tests/e2e/
2. Use 'source tests/test-helpers.bash' in your test files
3. Run tests with the BATS binary

EOF
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Testing Framework Setup

This script installs and configures BATS (Bash Automated Testing System)
for ExaPG project testing.

Usage: $0 [options]

Options:
  -h, --help    Show this help message
  --force       Force reinstallation even if BATS exists
  --no-helpers  Skip installation of BATS helper libraries

Examples:
  $0                    # Install BATS and setup testing framework
  $0 --force           # Force reinstallation
  $0 --no-helpers      # Install only core BATS

The script will:
1. Install BATS v1.10.0
2. Install helper libraries (bats-support, bats-assert, bats-file)
3. Create test directory structure
4. Set up test configuration and utilities
5. Validate installation

After installation, you can run tests with:
  tests/bats/bin/bats tests/unit/*.bats
EOF
    exit 0
fi

# Handle options
for arg in "$@"; do
    case $arg in
        --force)
            rm -rf "$BATS_DIR"
            ;;
        --no-helpers)
            export SKIP_HELPERS=true
            ;;
    esac
done

# Run main function
main "$@" 