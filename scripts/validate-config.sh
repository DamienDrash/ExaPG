#!/bin/bash
# ===================================================================
# ExaPG Configuration Validation Script
# ===================================================================
# TESTING FIX: TEST-002 - Comprehensive Configuration Validation
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validation thresholds and limits
readonly MIN_MEMORY_GB=2
readonly MAX_MEMORY_GB=1024
readonly MIN_CPU_CORES=1
readonly MAX_CPU_CORES=1024
readonly MIN_PORT=1024
readonly MAX_PORT=65535

# Configuration files to validate
readonly CONFIG_FILES=(
    ".env"
    ".env.template"
    "docker-compose.yml"
    "config/postgresql/postgresql.conf"
    "config/postgresql/pg_hba.conf"
)

# ===================================================================
# LOGGING
# ===================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[CONFIG-VALIDATOR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[CONFIG-VALIDATOR] ✓${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[CONFIG-VALIDATOR] ⚠${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[CONFIG-VALIDATOR] ✗${NC} $*" >&2
}

# ===================================================================
# VALIDATION FUNCTIONS
# ===================================================================

# Validate Docker Compose configuration
validate_docker_compose() {
    local compose_file="$1"
    local errors=0
    
    log "Validating Docker Compose file: $compose_file"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    # Check YAML syntax
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null; then
            log_error "Invalid YAML syntax in $compose_file"
            ((errors++))
        fi
    elif command -v python >/dev/null 2>&1; then
        if ! python -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null; then
            log_error "Invalid YAML syntax in $compose_file"
            ((errors++))
        fi
    fi
    
    # Validate with docker-compose if available
    if command -v docker-compose >/dev/null 2>&1; then
        if ! docker-compose -f "$compose_file" config >/dev/null 2>&1; then
            log_error "Docker Compose validation failed for $compose_file"
            ((errors++))
        else
            log_success "Docker Compose syntax is valid"
        fi
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
            log_error "Docker Compose validation failed for $compose_file"
            ((errors++))
        else
            log_success "Docker Compose syntax is valid"
        fi
    else
        log_warning "Docker Compose not available for validation"
    fi
    
    # Check for required services
    local required_services=("coordinator")
    for service in "${required_services[@]}"; do
        if ! grep -q "^  $service:" "$compose_file"; then
            log_error "Required service '$service' not found in $compose_file"
            ((errors++))
        fi
    done
    
    # Check for proper volume definitions
    if grep -q "volumes:" "$compose_file"; then
        log_success "Volume definitions found"
    else
        log_warning "No volume definitions found - data may not persist"
    fi
    
    # Check for network definitions
    if grep -q "networks:" "$compose_file"; then
        log_success "Network definitions found"
    else
        log_warning "No custom network definitions found"
    fi
    
    # Check for health checks
    if grep -q "healthcheck:" "$compose_file"; then
        log_success "Health checks configured"
    else
        log_warning "No health checks configured"
    fi
    
    return $errors
}

# Validate PostgreSQL configuration
validate_postgresql_config() {
    local config_file="$1"
    local errors=0
    
    log "Validating PostgreSQL configuration: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "PostgreSQL config file not found: $config_file"
        return 1
    fi
    
    # Check for dangerous configurations
    local dangerous_settings=(
        "fsync = off"
        "synchronous_commit = off"
        "full_page_writes = off"
    )
    
    for setting in "${dangerous_settings[@]}"; do
        if grep -q "^[[:space:]]*$setting" "$config_file"; then
            log_warning "Potentially dangerous setting found: $setting"
        fi
    done
    
    # Check memory settings
    local shared_buffers=$(grep "^[[:space:]]*shared_buffers" "$config_file" | head -1 | cut -d'=' -f2 | tr -d ' ')
    if [[ -n "$shared_buffers" ]]; then
        validate_memory_setting "shared_buffers" "$shared_buffers" || ((errors++))
    fi
    
    local work_mem=$(grep "^[[:space:]]*work_mem" "$config_file" | head -1 | cut -d'=' -f2 | tr -d ' ')
    if [[ -n "$work_mem" ]]; then
        validate_memory_setting "work_mem" "$work_mem" || ((errors++))
    fi
    
    # Check connection settings
    local max_connections=$(grep "^[[:space:]]*max_connections" "$config_file" | head -1 | cut -d'=' -f2 | tr -d ' ')
    if [[ -n "$max_connections" ]]; then
        if [[ "$max_connections" =~ ^[0-9]+$ ]]; then
            if [[ $max_connections -lt 10 ]]; then
                log_warning "max_connections ($max_connections) is very low"
            elif [[ $max_connections -gt 10000 ]]; then
                log_warning "max_connections ($max_connections) is very high"
            else
                log_success "max_connections is reasonable: $max_connections"
            fi
        else
            log_error "Invalid max_connections value: $max_connections"
            ((errors++))
        fi
    fi
    
    # Check port configuration
    local port=$(grep "^[[:space:]]*port" "$config_file" | head -1 | cut -d'=' -f2 | tr -d ' ')
    if [[ -n "$port" ]]; then
        validate_port "port" "$port" || ((errors++))
    fi
    
    return $errors
}

# Validate pg_hba.conf
validate_pg_hba_config() {
    local hba_file="$1"
    local errors=0
    
    log "Validating pg_hba.conf: $hba_file"
    
    if [[ ! -f "$hba_file" ]]; then
        log_error "pg_hba.conf file not found: $hba_file"
        return 1
    fi
    
    # Check for extremely permissive configurations
    if grep -q "trust" "$hba_file"; then
        if grep -q "0.0.0.0/0.*trust" "$hba_file"; then
            log_error "CRITICAL SECURITY ISSUE: Trust authentication from any host (0.0.0.0/0)"
            ((errors++))
        else
            log_warning "Trust authentication found (check if this is intended)"
        fi
    fi
    
    # Check for recommended authentication methods
    if grep -q "md5\|scram-sha-256" "$hba_file"; then
        log_success "Secure authentication methods found"
    else
        log_warning "No secure authentication methods (md5/scram-sha-256) found"
    fi
    
    # Check for SSL configurations
    if grep -q "hostssl" "$hba_file"; then
        log_success "SSL connections configured"
    else
        log_warning "No SSL connection configurations found"
    fi
    
    # Validate IP address ranges
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*host ]]; then
            local ip_range=$(echo "$line" | awk '{print $4}')
            if [[ -n "$ip_range" && "$ip_range" != "all" ]]; then
                validate_ip_range "$ip_range" || {
                    log_error "Invalid IP range in pg_hba.conf: $ip_range"
                    ((errors++))
                }
            fi
        fi
    done < "$hba_file"
    
    return $errors
}

# Validate environment variables
validate_environment_variables() {
    local env_file="$1"
    local errors=0
    
    log "Validating environment variables: $env_file"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Source the environment file safely
    local temp_env="/tmp/exapg_env_$$"
    grep '^[A-Z_][A-Z0-9_]*=' "$env_file" > "$temp_env" 2>/dev/null || true
    
    if [[ -s "$temp_env" ]]; then
        set -a
        source "$temp_env"
        set +a
    fi
    
    rm -f "$temp_env"
    
    # Critical environment variables
    local critical_vars=(
        "POSTGRES_PASSWORD"
        "DEPLOYMENT_MODE"
    )
    
    for var in "${critical_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Critical environment variable not set: $var"
            ((errors++))
        else
            log_success "Critical variable set: $var"
        fi
    done
    
    # Validate specific variable values
    if [[ -n "${DEPLOYMENT_MODE:-}" ]]; then
        case "${DEPLOYMENT_MODE}" in
            "standalone"|"cluster"|"ha")
                log_success "Valid deployment mode: $DEPLOYMENT_MODE"
                ;;
            *)
                log_error "Invalid deployment mode: $DEPLOYMENT_MODE"
                ((errors++))
                ;;
        esac
    fi
    
    # Validate memory settings
    for mem_var in POSTGRES_SHARED_BUFFERS POSTGRES_WORK_MEM POSTGRES_EFFECTIVE_CACHE_SIZE; do
        if [[ -n "${!mem_var:-}" ]]; then
            validate_memory_setting "$mem_var" "${!mem_var}" || ((errors++))
        fi
    done
    
    # Validate port settings
    for port_var in COORDINATOR_PORT WORKER_PORT MONITORING_PORT; do
        if [[ -n "${!port_var:-}" ]]; then
            validate_port "$port_var" "${!port_var}" || ((errors++))
        fi
    done
    
    # Validate password strength
    if [[ -n "${POSTGRES_PASSWORD:-}" ]]; then
        validate_password_strength "POSTGRES_PASSWORD" "${POSTGRES_PASSWORD}" || ((errors++))
    fi
    
    # Check for empty passwords
    local password_vars=(
        "POSTGRES_PASSWORD"
        "PGBOUNCER_PASSWORD"
        "MONITORING_PASSWORD"
    )
    
    for var in "${password_vars[@]}"; do
        if [[ "${!var:-}" == "" || "${!var:-}" == "password" || "${!var:-}" == "changeme" ]]; then
            log_error "Weak or empty password for $var"
            ((errors++))
        fi
    done
    
    return $errors
}

# Validate memory setting
validate_memory_setting() {
    local setting_name="$1"
    local setting_value="$2"
    
    # Convert memory value to MB for validation
    local memory_mb
    if [[ "$setting_value" =~ ^([0-9]+)([KMG]B?)$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            "KB"|"K")
                memory_mb=$((number / 1024))
                ;;
            "MB"|"M"|"")
                memory_mb=$number
                ;;
            "GB"|"G")
                memory_mb=$((number * 1024))
                ;;
            *)
                log_error "Invalid memory unit for $setting_name: $unit"
                return 1
                ;;
        esac
    else
        log_error "Invalid memory format for $setting_name: $setting_value"
        return 1
    fi
    
    # Validate reasonable ranges
    case "$setting_name" in
        "shared_buffers"|"POSTGRES_SHARED_BUFFERS")
            if [[ $memory_mb -lt 64 ]]; then
                log_warning "$setting_name ($setting_value) is very small"
            elif [[ $memory_mb -gt 8192 ]]; then
                log_warning "$setting_name ($setting_value) is very large"
            else
                log_success "$setting_name is reasonable: $setting_value"
            fi
            ;;
        "work_mem"|"POSTGRES_WORK_MEM")
            if [[ $memory_mb -lt 1 ]]; then
                log_warning "$setting_name ($setting_value) is very small"
            elif [[ $memory_mb -gt 1024 ]]; then
                log_warning "$setting_name ($setting_value) is very large"
            else
                log_success "$setting_name is reasonable: $setting_value"
            fi
            ;;
        *)
            log_success "$setting_name format is valid: $setting_value"
            ;;
    esac
    
    return 0
}

# Validate port number
validate_port() {
    local port_name="$1"
    local port_value="$2"
    
    if [[ ! "$port_value" =~ ^[0-9]+$ ]]; then
        log_error "Invalid port format for $port_name: $port_value"
        return 1
    fi
    
    if [[ $port_value -lt $MIN_PORT ]]; then
        log_warning "$port_name ($port_value) is below recommended minimum ($MIN_PORT)"
    elif [[ $port_value -gt $MAX_PORT ]]; then
        log_error "$port_name ($port_value) exceeds maximum ($MAX_PORT)"
        return 1
    else
        log_success "$port_name is valid: $port_value"
    fi
    
    return 0
}

# Validate IP range
validate_ip_range() {
    local ip_range="$1"
    
    # Handle CIDR notation
    if [[ "$ip_range" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip="${ip_range%/*}"
        local cidr="${ip_range#*/}"
        
        # Validate IP address
        if ! validate_ip_address "$ip"; then
            return 1
        fi
        
        # Validate CIDR
        if [[ $cidr -lt 0 || $cidr -gt 32 ]]; then
            return 1
        fi
        
        return 0
    fi
    
    # Handle single IP
    if [[ "$ip_range" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        validate_ip_address "$ip_range"
        return $?
    fi
    
    return 1
}

# Validate IP address
validate_ip_address() {
    local ip="$1"
    
    IFS='.' read -ra OCTETS <<< "$ip"
    
    if [[ ${#OCTETS[@]} -ne 4 ]]; then
        return 1
    fi
    
    for octet in "${OCTETS[@]}"; do
        if [[ ! "$octet" =~ ^[0-9]+$ ]] || [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]]; then
            return 1
        fi
        
        # Check for leading zeros
        if [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Validate password strength
validate_password_strength() {
    local password_name="$1"
    local password="$2"
    local min_length=8
    
    if [[ ${#password} -lt $min_length ]]; then
        log_error "$password_name is too short (minimum $min_length characters)"
        return 1
    fi
    
    local has_upper=false
    local has_lower=false
    local has_digit=false
    local has_special=false
    
    if [[ "$password" =~ [A-Z] ]]; then has_upper=true; fi
    if [[ "$password" =~ [a-z] ]]; then has_lower=true; fi
    if [[ "$password" =~ [0-9] ]]; then has_digit=true; fi
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then has_special=true; fi
    
    local strength=0
    $has_upper && ((strength++))
    $has_lower && ((strength++))
    $has_digit && ((strength++))
    $has_special && ((strength++))
    
    case $strength in
        4)
            log_success "$password_name has strong password"
            ;;
        3)
            log_success "$password_name has good password"
            ;;
        2)
            log_warning "$password_name has weak password"
            ;;
        *)
            log_error "$password_name has very weak password"
            return 1
            ;;
    esac
    
    return 0
}

# Validate system resources
validate_system_resources() {
    log "Validating system resources..."
    
    # Check available memory
    if command -v free >/dev/null 2>&1; then
        local total_memory_kb=$(free | awk '/^Mem:/{print $2}')
        local total_memory_gb=$((total_memory_kb / 1024 / 1024))
        
        if [[ $total_memory_gb -lt $MIN_MEMORY_GB ]]; then
            log_error "Insufficient memory: ${total_memory_gb}GB (minimum: ${MIN_MEMORY_GB}GB)"
            return 1
        else
            log_success "Sufficient memory available: ${total_memory_gb}GB"
        fi
    else
        log_warning "Cannot check memory (free command not available)"
    fi
    
    # Check CPU cores
    if command -v nproc >/dev/null 2>&1; then
        local cpu_cores=$(nproc)
        
        if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
            log_error "Insufficient CPU cores: $cpu_cores (minimum: $MIN_CPU_CORES)"
            return 1
        else
            log_success "Sufficient CPU cores available: $cpu_cores"
        fi
    else
        log_warning "Cannot check CPU cores (nproc command not available)"
    fi
    
    # Check disk space
    local available_space=$(df -BG "$PROJECT_ROOT" | awk 'NR==2{print $4}' | tr -d 'G')
    if [[ $available_space -lt 10 ]]; then
        log_warning "Low disk space: ${available_space}GB available"
    else
        log_success "Sufficient disk space: ${available_space}GB available"
    fi
    
    return 0
}

# Validate dependencies
validate_dependencies() {
    log "Validating dependencies..."
    
    local required_commands=("docker")
    local optional_commands=("docker-compose" "psql" "curl")
    
    local missing_required=()
    local missing_optional=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_required+=("$cmd")
        fi
    done
    
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_optional+=("$cmd")
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_required[*]}"
        return 1
    else
        log_success "All required dependencies are available"
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Missing optional dependencies: ${missing_optional[*]}"
    else
        log_success "All optional dependencies are available"
    fi
    
    # Check Docker daemon
    if command -v docker >/dev/null 2>&1; then
        if docker ps >/dev/null 2>&1; then
            log_success "Docker daemon is running"
        else
            log_error "Docker daemon is not running or not accessible"
            return 1
        fi
    fi
    
    return 0
}

# Generate validation report
generate_validation_report() {
    local total_errors="$1"
    local total_warnings="$2"
    local report_file="$PROJECT_ROOT/validation-report.txt"
    
    cat > "$report_file" << EOF
ExaPG Configuration Validation Report
=====================================
Generated: $(date)
Hostname: $(hostname)

Summary:
- Errors: $total_errors
- Warnings: $total_warnings
- Status: $([ $total_errors -eq 0 ] && echo "PASS" || echo "FAIL")

Configuration Files Validated:
$(printf '- %s\n' "${CONFIG_FILES[@]}")

Recommendations:
EOF

    if [[ $total_errors -gt 0 ]]; then
        cat >> "$report_file" << EOF
- Fix all errors before deploying to production
- Review security configurations in pg_hba.conf
- Ensure strong passwords are used
EOF
    fi
    
    if [[ $total_warnings -gt 0 ]]; then
        cat >> "$report_file" << EOF
- Review warnings for potential optimizations
- Consider adjusting memory settings based on available resources
- Implement SSL/TLS for secure connections
EOF
    fi
    
    if [[ $total_errors -eq 0 && $total_warnings -eq 0 ]]; then
        cat >> "$report_file" << EOF
- Configuration appears to be optimal
- Regular validation is recommended
- Monitor performance after deployment
EOF
    fi
    
    log "Validation report generated: $report_file"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    local total_errors=0
    local total_warnings=0
    local config_mode="${1:-all}"
    
    log "Starting ExaPG configuration validation..."
    log "Validation mode: $config_mode"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Validate system resources and dependencies
    if [[ "$config_mode" == "all" || "$config_mode" == "system" ]]; then
        validate_system_resources || ((total_errors++))
        validate_dependencies || ((total_errors++))
    fi
    
    # Validate Docker Compose files
    if [[ "$config_mode" == "all" || "$config_mode" == "docker" ]]; then
        for compose_file in docker-compose*.yml docker/docker-compose*.yml; do
            if [[ -f "$compose_file" ]]; then
                validate_docker_compose "$compose_file" || ((total_errors++))
            fi
        done
    fi
    
    # Validate PostgreSQL configuration
    if [[ "$config_mode" == "all" || "$config_mode" == "postgresql" ]]; then
        for pg_config in config/postgresql/*.conf; do
            if [[ -f "$pg_config" ]]; then
                validate_postgresql_config "$pg_config" || ((total_errors++))
            fi
        done
        
        # Validate pg_hba.conf
        if [[ -f "config/postgresql/pg_hba.conf" ]]; then
            validate_pg_hba_config "config/postgresql/pg_hba.conf" || ((total_errors++))
        fi
    fi
    
    # Validate environment variables
    if [[ "$config_mode" == "all" || "$config_mode" == "env" ]]; then
        for env_file in .env .env.template .env.example; do
            if [[ -f "$env_file" ]]; then
                validate_environment_variables "$env_file" || ((total_errors++))
            fi
        done
    fi
    
    # Generate report
    generate_validation_report "$total_errors" "$total_warnings"
    
    # Summary
    echo
    log "Configuration validation completed"
    log "Total errors: $total_errors"
    log "Total warnings: $total_warnings"
    
    if [[ $total_errors -eq 0 ]]; then
        log_success "All critical validations passed!"
        return 0
    else
        log_error "Configuration validation failed with $total_errors errors"
        return 1
    fi
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Configuration Validation Script

This script validates ExaPG configuration files for correctness, security,
and best practices.

Usage: $0 [mode]

Validation Modes:
  all         - Validate all configurations (default)
  system      - Validate system resources and dependencies
  docker      - Validate Docker Compose files
  postgresql  - Validate PostgreSQL configuration files
  env         - Validate environment variables

Examples:
  $0                    # Validate all configurations
  $0 postgresql        # Validate only PostgreSQL configs
  $0 docker           # Validate only Docker configurations

The script validates:
- Docker Compose file syntax and configuration
- PostgreSQL configuration parameters
- pg_hba.conf security settings
- Environment variable completeness and format
- System resource availability
- Dependency requirements
- Password strength
- Network and security configurations

Exit codes:
  0 - All validations passed
  1 - One or more validations failed

Output:
  validation-report.txt - Detailed validation report
EOF
    exit 0
fi

# Run main function
main "${1:-all}" 