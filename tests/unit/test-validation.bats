#!/usr/bin/env bats
# ===================================================================
# ExaPG Validation Functions Unit Tests
# ===================================================================
# TESTING FIX: TEST-001 - Unit Tests for Validation Functions
# Date: 2024-05-24
# ===================================================================

# Load test helpers
load '../test-helpers.bash'

# Test setup and teardown
setup() {
    setup_test
    
    # Source validation utilities for testing
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
    
    # Create test validation environment
    mkdir -p "$TEST_TEMP_DIR/scripts"
    mkdir -p "$TEST_TEMP_DIR/config"
    
    # Create mock validation functions for testing
    cat > "$TEST_TEMP_DIR/scripts/validation.sh" << 'EOF'
#!/bin/bash

# Validation utility functions for testing
validate_email() {
    local email="$1"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_ip_address() {
    local ip="$1"
    local ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ ! "$ip" =~ $ip_regex ]]; then
        return 1
    fi
    
    # Check each octet
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]]; then
            return 1
        fi
        # Check for leading zeros (except 0 itself)
        if [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]]; then
            return 1
        fi
    done
    
    return 0
}

validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi
    
    return 0
}

validate_domain() {
    local domain="$1"
    local domain_regex="^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"
    
    if [[ ${#domain} -gt 253 ]]; then
        return 1
    fi
    
    if [[ "$domain" =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_url() {
    local url="$1"
    local url_regex="^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?(/.*)?$"
    
    if [[ "$url" =~ $url_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_postgres_connection_string() {
    local conn_string="$1"
    
    # Basic format: postgresql://user:password@host:port/database
    local postgres_regex="^postgresql://[^:]+:[^@]+@[^:]+:[0-9]+/[^/]+$"
    
    if [[ "$conn_string" =~ $postgres_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_memory_size() {
    local memory="$1"
    local memory_regex="^[0-9]+[KMG]B?$"
    
    if [[ "$memory" =~ $memory_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_cpu_count() {
    local cpus="$1"
    
    if [[ ! "$cpus" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $cpus -lt 1 || $cpus -gt 1024 ]]; then
        return 1
    fi
    
    return 0
}

validate_file_path() {
    local path="$1"
    local check_exists="${2:-false}"
    
    # Basic path validation
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Check for invalid characters
    if [[ "$path" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    # Check if file should exist
    if [[ "$check_exists" == "true" && ! -f "$path" ]]; then
        return 1
    fi
    
    return 0
}

validate_directory_path() {
    local path="$1"
    local check_exists="${2:-false}"
    
    # Basic path validation
    if [[ -z "$path" ]]; then
        return 1
    fi
    
    # Check for invalid characters
    if [[ "$path" =~ [[:cntrl:]] ]]; then
        return 1
    fi
    
    # Check if directory should exist
    if [[ "$check_exists" == "true" && ! -d "$path" ]]; then
        return 1
    fi
    
    return 0
}

validate_username() {
    local username="$1"
    local username_regex="^[a-zA-Z0-9_-]{3,32}$"
    
    if [[ "$username" =~ $username_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"
    
    # Check minimum length
    if [[ ${#password} -lt $min_length ]]; then
        return 1
    fi
    
    # Check for at least one uppercase letter
    if [[ ! "$password" =~ [A-Z] ]]; then
        return 1
    fi
    
    # Check for at least one lowercase letter
    if [[ ! "$password" =~ [a-z] ]]; then
        return 1
    fi
    
    # Check for at least one digit
    if [[ ! "$password" =~ [0-9] ]]; then
        return 1
    fi
    
    return 0
}

validate_json() {
    local json_string="$1"
    
    echo "$json_string" | python3 -m json.tool >/dev/null 2>&1 || \
    echo "$json_string" | python -m json.tool >/dev/null 2>&1
}

validate_yaml() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi
    
    python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null || \
    python -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null
}

validate_env_var() {
    local var_name="$1"
    local var_value="$2"
    local required="${3:-false}"
    
    # Check if variable name is valid
    if [[ ! "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        return 1
    fi
    
    # Check if required variable is set
    if [[ "$required" == "true" && -z "$var_value" ]]; then
        return 1
    fi
    
    return 0
}

validate_semver() {
    local version="$1"
    local semver_regex="^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$"
    
    if [[ "$version" =~ $semver_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_cron_expression() {
    local cron_expr="$1"
    
    # Basic cron validation (5 fields)
    IFS=' ' read -ra FIELDS <<< "$cron_expr"
    
    if [[ ${#FIELDS[@]} -ne 5 ]]; then
        return 1
    fi
    
    # Validate each field (simplified)
    local minute="${FIELDS[0]}"
    local hour="${FIELDS[1]}"
    local day="${FIELDS[2]}"
    local month="${FIELDS[3]}"
    local dow="${FIELDS[4]}"
    
    # Basic range checks
    if [[ "$minute" != "*" && ! "$minute" =~ ^[0-9,-/]+$ ]]; then
        return 1
    fi
    
    if [[ "$hour" != "*" && ! "$hour" =~ ^[0-9,-/]+$ ]]; then
        return 1
    fi
    
    return 0
}

validate_docker_image() {
    local image="$1"
    local image_regex="^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*(:[a-zA-Z0-9._-]+)?$"
    
    if [[ "$image" =~ $image_regex ]]; then
        return 0
    else
        return 1
    fi
}

validate_database_name() {
    local db_name="$1"
    local db_regex="^[a-zA-Z][a-zA-Z0-9_]{0,62}$"
    
    if [[ "$db_name" =~ $db_regex ]]; then
        return 0
    else
        return 1
    fi
}
EOF
    
    # Source the validation functions
    source "$TEST_TEMP_DIR/scripts/validation.sh"
}

teardown() {
    teardown_test
}

# ===================================================================
# EMAIL VALIDATION TESTS
# ===================================================================

@test "validate_email accepts valid email addresses" {
    run validate_email "user@example.com"
    assert_success
    
    run validate_email "test.email+tag@domain.co.uk"
    assert_success
    
    run validate_email "user123@sub.domain.org"
    assert_success
    
    run validate_email "first.last@company-name.com"
    assert_success
}

@test "validate_email rejects invalid email addresses" {
    run validate_email "invalid.email"
    assert_failure
    
    run validate_email "@domain.com"
    assert_failure
    
    run validate_email "user@"
    assert_failure
    
    run validate_email "user@domain"
    assert_failure
    
    run validate_email "user..double@domain.com"
    assert_failure
}

# ===================================================================
# IP ADDRESS VALIDATION TESTS
# ===================================================================

@test "validate_ip_address accepts valid IP addresses" {
    run validate_ip_address "192.168.1.1"
    assert_success
    
    run validate_ip_address "10.0.0.1"
    assert_success
    
    run validate_ip_address "127.0.0.1"
    assert_success
    
    run validate_ip_address "0.0.0.0"
    assert_success
    
    run validate_ip_address "255.255.255.255"
    assert_success
}

@test "validate_ip_address rejects invalid IP addresses" {
    run validate_ip_address "256.1.1.1"
    assert_failure
    
    run validate_ip_address "192.168.1"
    assert_failure
    
    run validate_ip_address "192.168.1.1.1"
    assert_failure
    
    run validate_ip_address "192.168.01.1"
    assert_failure
    
    run validate_ip_address "not.an.ip.address"
    assert_failure
}

# ===================================================================
# PORT VALIDATION TESTS
# ===================================================================

@test "validate_port accepts valid port numbers" {
    run validate_port "80"
    assert_success
    
    run validate_port "443"
    assert_success
    
    run validate_port "8080"
    assert_success
    
    run validate_port "65535"
    assert_success
    
    run validate_port "1"
    assert_success
}

@test "validate_port rejects invalid port numbers" {
    run validate_port "0"
    assert_failure
    
    run validate_port "65536"
    assert_failure
    
    run validate_port "-1"
    assert_failure
    
    run validate_port "abc"
    assert_failure
    
    run validate_port "8080.5"
    assert_failure
}

# ===================================================================
# DOMAIN VALIDATION TESTS
# ===================================================================

@test "validate_domain accepts valid domains" {
    run validate_domain "example.com"
    assert_success
    
    run validate_domain "sub.domain.org"
    assert_success
    
    run validate_domain "test-domain.co.uk"
    assert_success
    
    run validate_domain "a.b"
    assert_success
}

@test "validate_domain rejects invalid domains" {
    run validate_domain ""
    assert_failure
    
    run validate_domain ".example.com"
    assert_failure
    
    run validate_domain "example..com"
    assert_failure
    
    run validate_domain "example.com."
    assert_failure
    
    # Test very long domain
    local long_domain=$(printf 'a%.0s' {1..255})
    run validate_domain "$long_domain.com"
    assert_failure
}

# ===================================================================
# URL VALIDATION TESTS
# ===================================================================

@test "validate_url accepts valid URLs" {
    run validate_url "http://example.com"
    assert_success
    
    run validate_url "https://www.example.com"
    assert_success
    
    run validate_url "https://example.com:8080"
    assert_success
    
    run validate_url "http://sub.domain.org/path/to/resource"
    assert_success
}

@test "validate_url rejects invalid URLs" {
    run validate_url "ftp://example.com"
    assert_failure
    
    run validate_url "http://"
    assert_failure
    
    run validate_url "not-a-url"
    assert_failure
    
    run validate_url "http://example"
    assert_failure
}

# ===================================================================
# POSTGRES CONNECTION STRING TESTS
# ===================================================================

@test "validate_postgres_connection_string accepts valid connection strings" {
    run validate_postgres_connection_string "postgresql://user:password@localhost:5432/database"
    assert_success
    
    run validate_postgres_connection_string "postgresql://postgres:secret@db.example.com:5432/exadb"
    assert_success
}

@test "validate_postgres_connection_string rejects invalid connection strings" {
    run validate_postgres_connection_string "mysql://user:password@localhost:3306/database"
    assert_failure
    
    run validate_postgres_connection_string "postgresql://user@localhost:5432/database"
    assert_failure
    
    run validate_postgres_connection_string "postgresql://user:password@localhost/database"
    assert_failure
}

# ===================================================================
# MEMORY SIZE VALIDATION TESTS
# ===================================================================

@test "validate_memory_size accepts valid memory sizes" {
    run validate_memory_size "1GB"
    assert_success
    
    run validate_memory_size "512MB"
    assert_success
    
    run validate_memory_size "2048KB"
    assert_success
    
    run validate_memory_size "4G"
    assert_success
    
    run validate_memory_size "1024M"
    assert_success
}

@test "validate_memory_size rejects invalid memory sizes" {
    run validate_memory_size "1TB"
    assert_failure
    
    run validate_memory_size "invalid"
    assert_failure
    
    run validate_memory_size "1.5GB"
    assert_failure
    
    run validate_memory_size "GB"
    assert_failure
}

# ===================================================================
# CPU COUNT VALIDATION TESTS
# ===================================================================

@test "validate_cpu_count accepts valid CPU counts" {
    run validate_cpu_count "1"
    assert_success
    
    run validate_cpu_count "4"
    assert_success
    
    run validate_cpu_count "16"
    assert_success
    
    run validate_cpu_count "128"
    assert_success
}

@test "validate_cpu_count rejects invalid CPU counts" {
    run validate_cpu_count "0"
    assert_failure
    
    run validate_cpu_count "-1"
    assert_failure
    
    run validate_cpu_count "1025"
    assert_failure
    
    run validate_cpu_count "abc"
    assert_failure
    
    run validate_cpu_count "4.5"
    assert_failure
}

# ===================================================================
# FILE PATH VALIDATION TESTS
# ===================================================================

@test "validate_file_path accepts valid file paths" {
    run validate_file_path "/path/to/file.txt"
    assert_success
    
    run validate_file_path "relative/path/file.txt"
    assert_success
    
    run validate_file_path "./file.txt"
    assert_success
    
    run validate_file_path "../parent/file.txt"
    assert_success
}

@test "validate_file_path rejects invalid file paths" {
    run validate_file_path ""
    assert_failure
    
    # Test with control characters
    run validate_file_path $'/path/with\ncontrol/chars'
    assert_failure
}

@test "validate_file_path checks file existence when requested" {
    # Create a test file
    local test_file="$TEST_TEMP_DIR/test_file.txt"
    echo "test content" > "$test_file"
    
    run validate_file_path "$test_file" "true"
    assert_success
    
    run validate_file_path "/nonexistent/file.txt" "true"
    assert_failure
}

# ===================================================================
# DIRECTORY PATH VALIDATION TESTS
# ===================================================================

@test "validate_directory_path accepts valid directory paths" {
    run validate_directory_path "/path/to/directory"
    assert_success
    
    run validate_directory_path "relative/directory"
    assert_success
    
    run validate_directory_path "."
    assert_success
    
    run validate_directory_path ".."
    assert_success
}

@test "validate_directory_path checks directory existence when requested" {
    run validate_directory_path "$TEST_TEMP_DIR" "true"
    assert_success
    
    run validate_directory_path "/nonexistent/directory" "true"
    assert_failure
}

# ===================================================================
# USERNAME VALIDATION TESTS
# ===================================================================

@test "validate_username accepts valid usernames" {
    run validate_username "user123"
    assert_success
    
    run validate_username "test_user"
    assert_success
    
    run validate_username "admin-user"
    assert_success
    
    run validate_username "a1b2c3"
    assert_success
}

@test "validate_username rejects invalid usernames" {
    run validate_username "ab"
    assert_failure
    
    run validate_username "user@domain"
    assert_failure
    
    run validate_username "user with spaces"
    assert_failure
    
    local long_username=$(printf 'a%.0s' {1..40})
    run validate_username "$long_username"
    assert_failure
}

# ===================================================================
# PASSWORD STRENGTH VALIDATION TESTS
# ===================================================================

@test "validate_password_strength accepts strong passwords" {
    run validate_password_strength "StrongPass123"
    assert_success
    
    run validate_password_strength "MySecure1Pass"
    assert_success
    
    run validate_password_strength "Complex9Password"
    assert_success
}

@test "validate_password_strength rejects weak passwords" {
    run validate_password_strength "weak"
    assert_failure
    
    run validate_password_strength "nouppercase123"
    assert_failure
    
    run validate_password_strength "NOLOWERCASE123"
    assert_failure
    
    run validate_password_strength "NoNumbers"
    assert_failure
    
    run validate_password_strength "Short1"
    assert_failure
}

@test "validate_password_strength respects minimum length" {
    run validate_password_strength "Strong1" 8
    assert_failure
    
    run validate_password_strength "Strong12" 8
    assert_success
    
    run validate_password_strength "VeryLongPassword123" 20
    assert_success
}

# ===================================================================
# JSON VALIDATION TESTS
# ===================================================================

@test "validate_json accepts valid JSON" {
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        skip "Python not available for JSON validation"
    fi
    
    run validate_json '{"key": "value"}'
    assert_success
    
    run validate_json '{"array": [1, 2, 3], "nested": {"key": "value"}}'
    assert_success
    
    run validate_json '[]'
    assert_success
}

@test "validate_json rejects invalid JSON" {
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        skip "Python not available for JSON validation"
    fi
    
    run validate_json '{"invalid": json}'
    assert_failure
    
    run validate_json '{missing_quotes: "value"}'
    assert_failure
    
    run validate_json '{"trailing": "comma",}'
    assert_failure
}

# ===================================================================
# YAML VALIDATION TESTS
# ===================================================================

@test "validate_yaml accepts valid YAML file" {
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        skip "Python not available for YAML validation"
    fi
    
    local yaml_file="$TEST_TEMP_DIR/valid.yaml"
    cat > "$yaml_file" << 'EOF'
name: ExaPG
version: 1.0.0
config:
  port: 5432
  enabled: true
EOF
    
    run validate_yaml "$yaml_file"
    assert_success
}

@test "validate_yaml rejects invalid YAML file" {
    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        skip "Python not available for YAML validation"
    fi
    
    local yaml_file="$TEST_TEMP_DIR/invalid.yaml"
    cat > "$yaml_file" << 'EOF'
name: ExaPG
version: 1.0.0
config:
  port: 5432
  invalid_yaml: [
    - missing_bracket
EOF
    
    run validate_yaml "$yaml_file"
    assert_failure
}

# ===================================================================
# ENVIRONMENT VARIABLE VALIDATION TESTS
# ===================================================================

@test "validate_env_var accepts valid environment variable names" {
    run validate_env_var "VALID_VAR" "value"
    assert_success
    
    run validate_env_var "DB_PASSWORD" "secret"
    assert_success
    
    run validate_env_var "_UNDERSCORE_VAR" "value"
    assert_success
}

@test "validate_env_var rejects invalid environment variable names" {
    run validate_env_var "invalid-var" "value"
    assert_failure
    
    run validate_env_var "123_VAR" "value"
    assert_failure
    
    run validate_env_var "var with spaces" "value"
    assert_failure
}

@test "validate_env_var checks required variables" {
    run validate_env_var "REQUIRED_VAR" "" "true"
    assert_failure
    
    run validate_env_var "REQUIRED_VAR" "value" "true"
    assert_success
    
    run validate_env_var "OPTIONAL_VAR" "" "false"
    assert_success
}

# ===================================================================
# SEMVER VALIDATION TESTS
# ===================================================================

@test "validate_semver accepts valid semantic versions" {
    run validate_semver "1.0.0"
    assert_success
    
    run validate_semver "2.1.3"
    assert_success
    
    run validate_semver "1.0.0-alpha"
    assert_success
    
    run validate_semver "1.0.0-beta.1"
    assert_success
    
    run validate_semver "1.0.0+build.123"
    assert_success
}

@test "validate_semver rejects invalid semantic versions" {
    run validate_semver "1.0"
    assert_failure
    
    run validate_semver "v1.0.0"
    assert_failure
    
    run validate_semver "1.0.0.0"
    assert_failure
    
    run validate_semver "1.a.0"
    assert_failure
}

# ===================================================================
# INTEGRATION TESTS
# ===================================================================

@test "validation functions work together in realistic scenarios" {
    # Validate a complete database configuration
    run validate_ip_address "192.168.1.100"
    assert_success
    
    run validate_port "5432"
    assert_success
    
    run validate_database_name "exadb"
    assert_success
    
    run validate_username "postgres"
    assert_success
    
    run validate_password_strength "SecurePassword123"
    assert_success
    
    # Combine into connection string
    run validate_postgres_connection_string "postgresql://postgres:SecurePassword123@192.168.1.100:5432/exadb"
    assert_success
}

@test "validation functions handle edge cases gracefully" {
    # Test with empty strings
    run validate_email ""
    assert_failure
    
    run validate_ip_address ""
    assert_failure
    
    run validate_port ""
    assert_failure
    
    # Test with very long inputs
    local long_string=$(printf 'a%.0s' {1..1000})
    run validate_username "$long_string"
    assert_failure
} 