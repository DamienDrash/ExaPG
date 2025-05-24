#!/bin/bash
"""
ExaPG Backup Manager
Master script for comprehensive backup management, verification, and disaster recovery
"""

set -euo pipefail

# Script information
SCRIPT_NAME="ExaPG Backup Manager"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
BACKUP_CONFIG_FILE="${BACKUP_CONFIG_FILE:-$PROJECT_ROOT/.env}"
PGBACKREST_SCRIPTS_DIR="${PGBACKREST_SCRIPTS_DIR:-$PROJECT_ROOT/pgbackrest/scripts}"
LOG_DIR="${LOG_DIR:-/var/log/pgbackrest}"
TEMP_DIR="${TEMP_DIR:-/tmp/exapg-backup-manager}"

# Default values
DEFAULT_STANZA="exapg"
DEFAULT_BACKUP_TYPE="incr"
DEFAULT_VERIFICATION_MODE="quick"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${BLUE}INFO${NC}: $1"
}

log_success() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}SUCCESS${NC}: $1"
}

log_warning() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}WARNING${NC}: $1"
}

log_error() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}ERROR${NC}: $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${PURPLE}DEBUG${NC}: $1"
    fi
}

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Load configuration
load_config() {
    if [[ -f "$BACKUP_CONFIG_FILE" ]]; then
        log_info "Loading configuration from $BACKUP_CONFIG_FILE"
        set -a  # Export all variables
        # shellcheck source=/dev/null
        source "$BACKUP_CONFIG_FILE"
        set +a
    else
        log_warning "Configuration file not found: $BACKUP_CONFIG_FILE"
    fi
    
    # Set defaults for missing variables
    export PGBACKREST_STANZA="${PGBACKREST_STANZA:-$DEFAULT_STANZA}"
    export PGHOST="${PGHOST:-localhost}"
    export PGPORT="${PGPORT:-5432}"
    export PGUSER="${PGUSER:-postgres}"
    export PGDATABASE="${PGDATABASE:-exadb}"
}

# Validate dependencies
validate_dependencies() {
    log_info "Validating dependencies..."
    
    local missing_deps=()
    
    # Check required commands
    local required_commands=(
        "pgbackrest"
        "psql"
        "pg_isready"
        "python3"
        "docker"
        "docker-compose"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check required scripts
    local required_scripts=(
        "$PGBACKREST_SCRIPTS_DIR/backup-scheduler.sh"
        "$PGBACKREST_SCRIPTS_DIR/backup-verification.py"
        "$PGBACKREST_SCRIPTS_DIR/backup-notification.py"
        "$PGBACKREST_SCRIPTS_DIR/disaster-recovery-test.py"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            missing_deps+=("$script")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            log_error "  - $dep"
        done
        error_exit "Please install missing dependencies before continuing"
    fi
    
    log_success "All dependencies validated"
}

# Create backup
create_backup() {
    local backup_type="${1:-$DEFAULT_BACKUP_TYPE}"
    local additional_args="${2:-}"
    
    log_info "Creating $backup_type backup..."
    
    # Validate backup type
    case "$backup_type" in
        full|diff|incr)
            ;;
        *)
            error_exit "Invalid backup type: $backup_type. Must be full, diff, or incr"
            ;;
    esac
    
    # Check if pgBackRest is available
    if ! pgbackrest --stanza="$PGBACKREST_STANZA" check >/dev/null 2>&1; then
        error_exit "pgBackRest stanza check failed. Please verify configuration."
    fi
    
    # Execute backup
    local backup_start_time=$(date +%s)
    
    if pgbackrest --stanza="$PGBACKREST_STANZA" --type="$backup_type" $additional_args backup; then
        local backup_end_time=$(date +%s)
        local backup_duration=$((backup_end_time - backup_start_time))
        
        log_success "$backup_type backup completed in ${backup_duration}s"
        
        # Send notification if enabled
        if [[ -f "$PGBACKREST_SCRIPTS_DIR/backup-notification.py" ]]; then
            python3 "$PGBACKREST_SCRIPTS_DIR/backup-notification.py" \
                --type="$backup_type" \
                --status=success \
                --duration="$backup_duration" || true
        fi
        
        return 0
    else
        log_error "$backup_type backup failed"
        
        # Send failure notification
        if [[ -f "$PGBACKREST_SCRIPTS_DIR/backup-notification.py" ]]; then
            python3 "$PGBACKREST_SCRIPTS_DIR/backup-notification.py" \
                --type="$backup_type" \
                --status=failed || true
        fi
        
        return 1
    fi
}

# Verify backups
verify_backups() {
    local verification_mode="${1:-$DEFAULT_VERIFICATION_MODE}"
    
    log_info "Running backup verification (mode: $verification_mode)..."
    
    if [[ ! -f "$PGBACKREST_SCRIPTS_DIR/backup-verification.py" ]]; then
        error_exit "Backup verification script not found"
    fi
    
    local verify_args=""
    case "$verification_mode" in
        quick)
            verify_args="--quick"
            ;;
        full)
            verify_args="--full"
            ;;
        latest)
            verify_args="--latest-backup"
            ;;
        *)
            error_exit "Invalid verification mode: $verification_mode. Must be quick, full, or latest"
            ;;
    esac
    
    if python3 "$PGBACKREST_SCRIPTS_DIR/backup-verification.py" $verify_args; then
        log_success "Backup verification completed successfully"
        return 0
    else
        log_error "Backup verification failed"
        return 1
    fi
}

# Test disaster recovery
test_disaster_recovery() {
    local test_types="${1:-backup_verification,full_restore}"
    
    log_info "Running disaster recovery tests: $test_types"
    
    if [[ ! -f "$PGBACKREST_SCRIPTS_DIR/disaster-recovery-test.py" ]]; then
        error_exit "Disaster recovery test script not found"
    fi
    
    local test_args=""
    if [[ "$test_types" != "all" ]]; then
        IFS=',' read -ra test_array <<< "$test_types"
        test_args="--tests ${test_array[*]}"
    fi
    
    if python3 "$PGBACKREST_SCRIPTS_DIR/disaster-recovery-test.py" $test_args; then
        log_success "Disaster recovery tests completed successfully"
        return 0
    else
        log_error "Disaster recovery tests failed"
        return 1
    fi
}

# Show backup information
show_backup_info() {
    log_info "Retrieving backup information..."
    
    if pgbackrest --stanza="$PGBACKREST_STANZA" info; then
        return 0
    else
        error_exit "Failed to retrieve backup information"
    fi
}

# Show backup status
show_backup_status() {
    log_info "ExaPG Backup System Status"
    echo "=================================="
    
    # Basic system info
    echo "Timestamp: $(date)"
    echo "Stanza: $PGBACKREST_STANZA"
    echo "Host: $PGHOST:$PGPORT"
    echo "Database: $PGDATABASE"
    echo ""
    
    # pgBackRest version
    echo "pgBackRest Version:"
    pgbackrest version | head -1
    echo ""
    
    # Stanza check
    echo "Stanza Health Check:"
    if pgbackrest --stanza="$PGBACKREST_STANZA" check >/dev/null 2>&1; then
        echo -e "  Status: ${GREEN}✓ HEALTHY${NC}"
    else
        echo -e "  Status: ${RED}✗ UNHEALTHY${NC}"
    fi
    echo ""
    
    # Repository info
    echo "Repository Information:"
    if pgbackrest --stanza="$PGBACKREST_STANZA" info --output=json >/dev/null 2>&1; then
        local backup_count
        backup_count=$(pgbackrest --stanza="$PGBACKREST_STANZA" info --output=json | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data and data[0].get('backup'):
    print(len(data[0]['backup']))
else:
    print(0)
" 2>/dev/null || echo "0")
        
        echo "  Total Backups: $backup_count"
        
        if [[ "$backup_count" -gt 0 ]]; then
            local latest_backup
            latest_backup=$(pgbackrest --stanza="$PGBACKREST_STANZA" info --output=json | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data and data[0].get('backup'):
    latest = data[0]['backup'][-1]
    print(f\"{latest.get('type', 'unknown')} - {latest.get('timestamp', {}).get('start', 'unknown')}\")
else:
    print('No backups')
" 2>/dev/null || echo "Unknown")
            
            echo "  Latest Backup: $latest_backup"
        fi
    else
        echo -e "  Status: ${RED}✗ ERROR${NC}"
    fi
    echo ""
    
    # PostgreSQL connectivity
    echo "PostgreSQL Connectivity:"
    if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
        echo -e "  Status: ${GREEN}✓ CONNECTED${NC}"
    else
        echo -e "  Status: ${RED}✗ DISCONNECTED${NC}"
    fi
    echo ""
    
    # Docker containers (if available)
    if command -v docker >/dev/null 2>&1; then
        echo "Docker Containers:"
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(pgbackrest|backup)" 2>/dev/null; then
            docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(pgbackrest|backup)" | sed 's/^/  /'
        else
            echo "  No backup containers running"
        fi
        echo ""
    fi
    
    # Recent logs
    if [[ -d "$LOG_DIR" ]]; then
        echo "Recent Activity:"
        if find "$LOG_DIR" -name "*.log" -mtime -1 -exec tail -n 3 {} \; 2>/dev/null | head -10; then
            :
        else
            echo "  No recent log activity"
        fi
    fi
}

# Start backup monitoring dashboard
start_dashboard() {
    local port="${1:-8080}"
    
    log_info "Starting backup monitoring dashboard on port $port..."
    
    if [[ -f "$PGBACKREST_SCRIPTS_DIR/backup-monitoring-dashboard.py" ]]; then
        python3 "$PGBACKREST_SCRIPTS_DIR/backup-monitoring-dashboard.py" --port="$port"
    else
        error_exit "Backup monitoring dashboard script not found"
    fi
}

# Deploy backup infrastructure
deploy_backup_infrastructure() {
    local environment="${1:-development}"
    
    log_info "Deploying backup infrastructure for $environment environment..."
    
    # Check if docker-compose files exist
    local compose_file="$PROJECT_ROOT/docker/docker-compose/docker-compose.backup.yml"
    if [[ ! -f "$compose_file" ]]; then
        error_exit "Backup Docker Compose file not found: $compose_file"
    fi
    
    # Deploy with Docker Compose
    cd "$PROJECT_ROOT"
    
    case "$environment" in
        development)
            log_info "Deploying development backup infrastructure..."
            docker-compose -f "$compose_file" up -d
            ;;
        production)
            log_info "Deploying production backup infrastructure..."
            docker-compose -f "$compose_file" -f "docker/docker-compose/docker-compose.backup.prod.yml" up -d
            ;;
        *)
            error_exit "Unknown environment: $environment. Use development or production"
            ;;
    esac
    
    # Wait for services to be ready
    log_info "Waiting for backup services to be ready..."
    sleep 10
    
    # Verify deployment
    if docker-compose -f "$compose_file" ps | grep -q "Up"; then
        log_success "Backup infrastructure deployed successfully"
    else
        error_exit "Backup infrastructure deployment failed"
    fi
}

# Stop backup infrastructure
stop_backup_infrastructure() {
    log_info "Stopping backup infrastructure..."
    
    local compose_file="$PROJECT_ROOT/docker/docker-compose/docker-compose.backup.yml"
    cd "$PROJECT_ROOT"
    
    if docker-compose -f "$compose_file" down; then
        log_success "Backup infrastructure stopped"
    else
        log_error "Failed to stop backup infrastructure"
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups according to retention policy..."
    
    if pgbackrest --stanza="$PGBACKREST_STANZA" expire; then
        log_success "Backup cleanup completed"
    else
        log_error "Backup cleanup failed"
    fi
}

# Show help
show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    backup [TYPE]              Create backup (full|diff|incr, default: incr)
    verify [MODE]              Verify backups (quick|full|latest, default: quick)
    test-dr [TESTS]           Run disaster recovery tests
    info                      Show backup information
    status                    Show backup system status
    dashboard [PORT]          Start monitoring dashboard (default port: 8080)
    deploy [ENV]              Deploy backup infrastructure (development|production)
    stop                      Stop backup infrastructure
    cleanup                   Clean up old backups
    help                      Show this help

OPTIONS:
    --config FILE             Configuration file (default: .env)
    --stanza NAME            pgBackRest stanza name (default: exapg)
    --debug                   Enable debug output
    --dry-run                 Show what would be done without executing

EXAMPLES:
    $0 backup full                    # Create full backup
    $0 verify quick                   # Quick backup verification
    $0 test-dr full_restore          # Test full restore capability
    $0 status                        # Show system status
    $0 dashboard 8080               # Start dashboard on port 8080
    $0 deploy production            # Deploy production backup infrastructure

ENVIRONMENT VARIABLES:
    PGBACKREST_STANZA           pgBackRest stanza name
    PGHOST                      PostgreSQL host
    PGPORT                      PostgreSQL port
    PGUSER                      PostgreSQL user
    PGPASSWORD                  PostgreSQL password
    PGDATABASE                  PostgreSQL database
    BACKUP_CONFIG_FILE          Configuration file path
    DEBUG                       Enable debug mode (true|false)

For more information, see docs/user-guide/backup-management.md
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                BACKUP_CONFIG_FILE="$2"
                shift 2
                ;;
            --stanza)
                PGBACKREST_STANZA="$2"
                shift 2
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
}

# Main function
main() {
    # Parse global arguments first
    parse_arguments "$@"
    
    # After parsing, rebuild arguments
    local args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config|--stanza|--debug|--dry-run)
                # Skip these as they're already processed
                if [[ "$1" == "--config" ]] || [[ "$1" == "--stanza" ]]; then
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # Restore arguments
    set -- "${args[@]}"
    
    # Show header
    log_info "$SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Load configuration
    load_config
    
    # Validate dependencies
    validate_dependencies
    
    # Handle commands
    local command="${1:-help}"
    
    case "$command" in
        backup)
            create_backup "${2:-$DEFAULT_BACKUP_TYPE}" "${3:-}"
            ;;
        verify)
            verify_backups "${2:-$DEFAULT_VERIFICATION_MODE}"
            ;;
        test-dr)
            test_disaster_recovery "${2:-backup_verification,full_restore}"
            ;;
        info)
            show_backup_info
            ;;
        status)
            show_backup_status
            ;;
        dashboard)
            start_dashboard "${2:-8080}"
            ;;
        deploy)
            deploy_backup_infrastructure "${2:-development}"
            ;;
        stop)
            stop_backup_infrastructure
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Trap for cleanup
cleanup_temp() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup_temp EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

# Run main function
main "$@" 