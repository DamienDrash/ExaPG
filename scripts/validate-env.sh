#!/bin/bash
# ===================================================================
# ExaPG Environment Variables Validation Script
# ===================================================================
# CRITICAL FIX: Validates all environment variables for consistency
# Date: 2024-05-24
# Version: 1.0.0
#
# Usage: 
#   ./scripts/validate-env.sh
#   ./scripts/validate-env.sh --strict  # Exit on first error
#   ./scripts/validate-env.sh --report  # Generate detailed report
# ===================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script options
STRICT_MODE=false
REPORT_MODE=false

# Counters
ERRORS=0
WARNINGS=0
SUCCESS=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --report)
            REPORT_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--strict] [--report]"
            echo "  --strict  Exit on first error"
            echo "  --report  Generate detailed validation report"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Load environment file
ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo -e "${YELLOW}HINT: Copy .env.template to .env first${NC}"
    exit 1
fi

# Source the .env file
set -a  # automatically export all variables
source "$ENV_FILE"
set +a

echo "🔍 ExaPG Environment Configuration Validation"
echo "=================================================="
echo -e "Date: $(date)"
echo -e "Environment File: $ENV_FILE"
echo ""

# ===================================================================
# VALIDATION FUNCTIONS
# ===================================================================

log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ERRORS=$((ERRORS + 1))
    if [[ "$STRICT_MODE" == "true" ]]; then
        exit 1
    fi
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS: $1${NC}"
    SUCCESS=$((SUCCESS + 1))
}

log_info() {
    echo -e "${BLUE}ℹ️  INFO: $1${NC}"
}

validate_required_var() {
    local var_name="$1"
    local var_value
    
    # Use eval for safer indirect variable access
    var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -z "$var_value" ]]; then
        log_error "Required variable $var_name is not defined"
        return 1
    else
        log_success "Required variable $var_name is defined: '$var_value'"
        return 0
    fi
}

validate_numeric() {
    local var_name="$1"
    local var_value
    
    var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -n "$var_value" ]] && ! [[ "$var_value" =~ ^[0-9]+$ ]]; then
        log_error "Variable $var_name='$var_value' must be numeric"
        return 1
    elif [[ -n "$var_value" ]]; then
        log_success "Variable $var_name='$var_value' is numeric"
    fi
    return 0
}

validate_memory_format() {
    local var_name="$1"
    local var_value
    
    var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -n "$var_value" ]] && ! [[ "$var_value" =~ ^[0-9]+[KMG]B?$ ]]; then
        log_error "Variable $var_name='$var_value' must be in format like 4GB, 512MB, 1024KB"
        return 1
    elif [[ -n "$var_value" ]]; then
        log_success "Variable $var_name='$var_value' has valid memory format"
    fi
    return 0
}

validate_port() {
    local var_name="$1"
    local var_value
    
    var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -n "$var_value" ]]; then
        if ! [[ "$var_value" =~ ^[0-9]+$ ]] || [[ "$var_value" -lt 1024 ]] || [[ "$var_value" -gt 65535 ]]; then
            log_error "Variable $var_name='$var_value' must be a valid port (1024-65535)"
            return 1
        else
            log_success "Variable $var_name='$var_value' is a valid port"
        fi
    fi
    return 0
}

validate_boolean() {
    local var_name="$1"
    local var_value
    
    var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -n "$var_value" ]] && ! [[ "$var_value" =~ ^(true|false|yes|no|on|off|1|0)$ ]]; then
        log_error "Variable $var_name='$var_value' must be boolean (true/false, yes/no, on/off, 1/0)"
        return 1
    elif [[ -n "$var_value" ]]; then
        log_success "Variable $var_name='$var_value' is a valid boolean"
    fi
    return 0
}

check_port_conflicts() {
    local ports=("$@")
    local seen_ports=()
    
    for port in "${ports[@]}"; do
        if [[ " ${seen_ports[*]} " =~ " ${port} " ]]; then
            log_error "Port conflict detected: $port is used multiple times"
            return 1
        fi
        seen_ports+=("$port")
    done
    return 0
}

# ===================================================================
# CRITICAL VARIABLES VALIDATION
# ===================================================================

echo "📋 Validating Critical Variables..."
echo "-----------------------------------"

# Core deployment variables
CRITICAL_VARS=(
    "DEPLOYMENT_MODE"
    "POSTGRES_PASSWORD"
    "COORDINATOR_PORT"
    "WORKER_COUNT"
    "SHARED_BUFFERS"
    "WORK_MEM"
    "COORDINATOR_MEMORY_LIMIT"
    "WORKER_MEMORY_LIMIT"
    "CONTAINER_NAME"
    "POSTGRES_USER"
    "POSTGRES_DB"
)

for var in "${CRITICAL_VARS[@]}"; do
    validate_required_var "$var"
done

# ===================================================================
# DATA TYPE VALIDATION
# ===================================================================

echo ""
echo "🔢 Validating Data Types..."
echo "----------------------------"

# Numeric variables
NUMERIC_VARS=(
    "WORKER_COUNT"
    "MAX_PARALLEL_WORKERS"
    "MAX_PARALLEL_WORKERS_PER_GATHER"
    "ETL_BATCH_SIZE"
    "ETL_PARALLEL_JOBS"
    "BACKUP_RETENTION_DAYS"
    "COLUMNAR_STRIPE_ROW_COUNT"
    "COLUMNAR_COMPRESSION_LEVEL"
)

for var in "${NUMERIC_VARS[@]}"; do
    validate_numeric "$var"
done

# Memory format variables
MEMORY_VARS=(
    "SHARED_BUFFERS"
    "EFFECTIVE_CACHE_SIZE"
    "WORK_MEM"
    "MAINTENANCE_WORK_MEM"
    "COORDINATOR_MEMORY_LIMIT"
    "WORKER_MEMORY_LIMIT"
    "SHARED_MEMORY_SIZE"
)

for var in "${MEMORY_VARS[@]}"; do
    validate_memory_format "$var"
done

# Port variables
PORT_VARS=(
    "COORDINATOR_PORT"
    "POSTGRES_PORT"
    "WORKER_PORT_START"
    "WORKER_PORT_START_2"
    "PROMETHEUS_PORT"
    "GRAFANA_PORT"
    "ALERTMANAGER_PORT"
    "PG_EXPORTER_PORT"
    "NODE_EXPORTER_PORT"
)

for var in "${PORT_VARS[@]}"; do
    validate_port "$var"
done

# Boolean variables
BOOLEAN_VARS=(
    "ENABLE_MONITORING"
    "ENABLE_MANAGEMENT_UI"
    "ENABLE_UDF_FRAMEWORK"
    "ENABLE_VIRTUAL_SCHEMAS"
    "ENABLE_ETL_TOOLS"
    "ENABLE_BACKUP"
    "ENABLE_HA"
    "ETL_CDC_ENABLED"
    "ETL_DATA_QUALITY_ENABLED"
    "BACKUP_COMPRESSION"
    "DEBUG"
    "BENCHMARK_MODE"
)

for var in "${BOOLEAN_VARS[@]}"; do
    validate_boolean "$var"
done

# ===================================================================
# LOGICAL VALIDATION
# ===================================================================

echo ""
echo "🧠 Validating Logical Consistency..."
echo "--------------------------------------"

# Check deployment mode consistency
DEPLOYMENT_MODE_VAL=$(eval "echo \${DEPLOYMENT_MODE:-}")
WORKER_COUNT_VAL=$(eval "echo \${WORKER_COUNT:-0}")

if [[ "$DEPLOYMENT_MODE_VAL" == "single" ]] && [[ "$WORKER_COUNT_VAL" -gt 0 ]]; then
    log_warning "DEPLOYMENT_MODE=single but WORKER_COUNT=${WORKER_COUNT_VAL}. Consider setting WORKER_COUNT=0 for single-node deployment"
fi

if [[ "$DEPLOYMENT_MODE_VAL" == "cluster" ]] && [[ "$WORKER_COUNT_VAL" -eq 0 ]]; then
    log_error "DEPLOYMENT_MODE=cluster but WORKER_COUNT=0. Cluster deployment requires at least 1 worker"
fi

# Check port conflicts
USED_PORTS=()
COORDINATOR_PORT_VAL=$(eval "echo \${COORDINATOR_PORT:-}")
WORKER_PORT_START_VAL=$(eval "echo \${WORKER_PORT_START:-}")
WORKER_PORT_START_2_VAL=$(eval "echo \${WORKER_PORT_START_2:-}")
PROMETHEUS_PORT_VAL=$(eval "echo \${PROMETHEUS_PORT:-}")
GRAFANA_PORT_VAL=$(eval "echo \${GRAFANA_PORT:-}")
ENABLE_MONITORING_VAL=$(eval "echo \${ENABLE_MONITORING:-false}")

[[ -n "$COORDINATOR_PORT_VAL" ]] && USED_PORTS+=("$COORDINATOR_PORT_VAL")
[[ -n "$WORKER_PORT_START_VAL" ]] && USED_PORTS+=("$WORKER_PORT_START_VAL")
[[ -n "$WORKER_PORT_START_2_VAL" ]] && USED_PORTS+=("$WORKER_PORT_START_2_VAL")
[[ -n "$PROMETHEUS_PORT_VAL" ]] && [[ "$ENABLE_MONITORING_VAL" == "true" ]] && USED_PORTS+=("$PROMETHEUS_PORT_VAL")
[[ -n "$GRAFANA_PORT_VAL" ]] && [[ "$ENABLE_MONITORING_VAL" == "true" ]] && USED_PORTS+=("$GRAFANA_PORT_VAL")

if [[ ${#USED_PORTS[@]} -gt 0 ]]; then
    check_port_conflicts "${USED_PORTS[@]}"
fi

# Check memory consistency (simplified check)
SHARED_BUFFERS_VAL=$(eval "echo \${SHARED_BUFFERS:-}")
COORDINATOR_MEMORY_LIMIT_VAL=$(eval "echo \${COORDINATOR_MEMORY_LIMIT:-}")

if [[ -n "$SHARED_BUFFERS_VAL" ]] && [[ -n "$COORDINATOR_MEMORY_LIMIT_VAL" ]]; then
    log_info "Memory settings: SHARED_BUFFERS=${SHARED_BUFFERS_VAL}, COORDINATOR_MEMORY_LIMIT=${COORDINATOR_MEMORY_LIMIT_VAL}"
    # Note: For detailed memory validation, manual review recommended
fi

# Check SSL configuration consistency (if SSL certificates exist)
if [[ -f "config/ssl/server.crt" ]] && [[ -f "config/ssl/server.key" ]]; then
    log_success "SSL certificates found - secure configuration ready"
else
    log_warning "SSL certificates not found - consider running SSL setup for production"
fi

# ===================================================================
# DOCKER COMPOSE COMPATIBILITY CHECK
# ===================================================================

echo ""
echo "🐳 Validating Docker Compose Compatibility..."
echo "-----------------------------------------------"

# Check for variables required by docker-compose files
DOCKER_REQUIRED_VARS=(
    "POSTGRES_PASSWORD"
    "CONTAINER_NAME"
    "COORDINATOR_PORT"
)

for var in "${DOCKER_REQUIRED_VARS[@]}"; do
    var_value=$(eval "echo \${${var}:-}")
    if [[ -z "$var_value" ]]; then
        log_error "Variable $var is required by docker-compose.yml but not defined"
    else
        log_success "Docker required variable $var is defined"
    fi
done

# Check docker-compose.yml syntax (if docker-compose is available)
if command -v docker-compose >/dev/null 2>&1; then
    if docker-compose -f docker/docker-compose/docker-compose.yml config >/dev/null 2>&1; then
        log_success "docker-compose.yml syntax is valid"
    else
        log_error "docker-compose.yml has syntax errors"
    fi
else
    log_info "docker-compose not available - skipping syntax check"
fi

# ===================================================================
# FINAL REPORT
# ===================================================================

echo ""
echo "📊 Validation Summary"
echo "====================="
echo -e "${GREEN}✅ Successful checks: $SUCCESS${NC}"
echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
echo -e "${RED}❌ Errors: $ERRORS${NC}"
echo ""

if [[ "$REPORT_MODE" == "true" ]]; then
    REPORT_FILE="validation-report-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "ExaPG Environment Validation Report"
        echo "Generated: $(date)"
        echo "Environment File: $ENV_FILE"
        echo ""
        echo "Summary:"
        echo "- Successful checks: $SUCCESS"
        echo "- Warnings: $WARNINGS"
        echo "- Errors: $ERRORS"
        echo ""
        echo "Environment Variables:"
        env | grep -E '^(POSTGRES_|DEPLOYMENT_|COORDINATOR_|WORKER_|SHARED_|WORK_|MAINTENANCE_|MAX_|EFFECTIVE_|CONTAINER_|CLUSTER_|ENABLE_|COLUMNAR_|ETL_|BACKUP_|GRAFANA_|PROMETHEUS_|ALERT)' | sort
    } > "$REPORT_FILE"
    echo "📄 Detailed report saved to: $REPORT_FILE"
fi

# Exit status
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}💥 Validation FAILED with $ERRORS errors${NC}"
    echo -e "${BLUE}🔧 Please fix the errors above and run validation again${NC}"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Validation completed with $WARNINGS warnings${NC}"
    echo -e "${BLUE}💡 Consider addressing the warnings for optimal configuration${NC}"
    exit 0
else
    echo -e "${GREEN}🎉 Validation PASSED - Configuration is ready for deployment!${NC}"
    exit 0
fi 