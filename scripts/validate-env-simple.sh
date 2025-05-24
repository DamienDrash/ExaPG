#!/bin/bash
# Simplified ExaPG Environment Variables Validation Script
# CRITICAL FIX: Validates core environment variables

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
SUCCESS=0

# Load environment file
ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    exit 1
fi

source "$ENV_FILE"

echo "🔍 ExaPG Environment Configuration Validation (Simplified)"
echo "==========================================================="
echo -e "Date: $(date)"
echo -e "Environment File: $ENV_FILE"
echo ""

# Simple validation function
check_required() {
    local var_name="$1"
    local var_value=$(eval "echo \${${var_name}:-}")
    
    if [[ -z "$var_value" ]]; then
        echo -e "${RED}❌ ERROR: Required variable $var_name is not defined${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✅ SUCCESS: $var_name = '$var_value'${NC}"
        SUCCESS=$((SUCCESS + 1))
    fi
}

echo "📋 Checking Critical Variables..."
echo "--------------------------------"

# Core variables required for basic deployment
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
    check_required "$var"
done

echo ""
echo "📊 Validation Summary"
echo "====================="
echo -e "${GREEN}✅ Successful checks: $SUCCESS${NC}"
echo -e "${RED}❌ Errors: $ERRORS${NC}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}💥 Validation FAILED with $ERRORS errors${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 Core Validation PASSED!${NC}"
    echo -e "Run the full validation script for complete checks."
    exit 0
fi 