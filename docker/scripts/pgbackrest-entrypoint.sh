#!/bin/bash
set -e

# pgBackRest Container Entrypoint
# Handles initialization, configuration validation, and service startup

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_warning() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
}

# Configuration validation
validate_environment() {
    log_info "Validating environment configuration..."
    
    local errors=0
    
    # Required environment variables
    local required_vars=(
        "PGBACKREST_STANZA"
        "PGHOST"
        "PGPORT"
        "PGUSER"
        "PGPASSWORD"
        "PGDATABASE"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required environment variable $var is not set"
            errors=$((errors + 1))
        fi
    done
    
    # Check if pgBackRest config exists
    if [[ ! -f "$PGBACKREST_CONFIG" ]]; then
        log_error "pgBackRest configuration file not found: $PGBACKREST_CONFIG"
        errors=$((errors + 1))
    fi
    
    # Check repository directory
    if [[ ! -d "$PGBACKREST_REPO1_PATH" ]]; then
        log_warning "Repository directory does not exist, will be created: $PGBACKREST_REPO1_PATH"
        mkdir -p "$PGBACKREST_REPO1_PATH"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        exit 1
    fi
    
    log_info "Environment validation successful"
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    log_info "Waiting for PostgreSQL to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
            log_info "PostgreSQL is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: PostgreSQL not ready, waiting..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log_error "PostgreSQL did not become ready within timeout"
    return 1
}

# Initialize pgBackRest stanza
initialize_stanza() {
    log_info "Initializing pgBackRest stanza: $PGBACKREST_STANZA"
    
    # Check if stanza already exists
    if pgbackrest --stanza="$PGBACKREST_STANZA" info >/dev/null 2>&1; then
        log_info "Stanza $PGBACKREST_STANZA already exists"
        
        # Verify stanza health
        if ! pgbackrest --stanza="$PGBACKREST_STANZA" check >/dev/null 2>&1; then
            log_warning "Stanza check failed, attempting to repair..."
            
            # Attempt stanza upgrade/repair
            if ! pgbackrest --stanza="$PGBACKREST_STANZA" --force stanza-upgrade; then
                log_error "Failed to repair stanza, manual intervention may be required"
                return 1
            fi
        fi
        
        return 0
    fi
    
    # Create new stanza
    log_info "Creating new stanza: $PGBACKREST_STANZA"
    
    if ! pgbackrest --stanza="$PGBACKREST_STANZA" stanza-create; then
        log_error "Failed to create stanza"
        return 1
    fi
    
    # Verify stanza creation
    if ! pgbackrest --stanza="$PGBACKREST_STANZA" check; then
        log_error "Stanza verification failed after creation"
        return 1
    fi
    
    log_info "Stanza $PGBACKREST_STANZA created successfully"
    
    # Create initial full backup if enabled
    if [[ "${BACKUP_CREATE_INITIAL:-true}" == "true" ]]; then
        log_info "Creating initial full backup..."
        
        if pgbackrest --stanza="$PGBACKREST_STANZA" --type=full backup; then
            log_info "Initial backup created successfully"
        else
            log_warning "Initial backup failed, but continuing..."
        fi
    fi
}

# Setup WAL archiving
setup_wal_archiving() {
    log_info "Verifying WAL archiving configuration..."
    
    # Check if WAL archiving is enabled
    local archive_mode
    archive_mode=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc "SHOW archive_mode;" 2>/dev/null)
    
    if [[ "$archive_mode" != "on" ]]; then
        log_warning "WAL archiving is not enabled in PostgreSQL (archive_mode=$archive_mode)"
        log_warning "For point-in-time recovery, enable archive_mode=on in postgresql.conf"
    else
        log_info "WAL archiving is enabled"
    fi
    
    # Check archive command
    local archive_command
    archive_command=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc "SHOW archive_command;" 2>/dev/null)
    
    if [[ "$archive_command" != *"pgbackrest"* ]]; then
        log_warning "Archive command does not appear to use pgBackRest: $archive_command"
    else
        log_info "Archive command is configured for pgBackRest"
    fi
}

# Setup cron jobs
setup_cron() {
    log_info "Setting up backup schedule..."
    
    if [[ "${BACKUP_SCHEDULE_ENABLED:-true}" == "true" ]]; then
        # Process crontab template with environment variables
        local crontab_template="/usr/local/bin/crontab"
        local crontab_processed="/tmp/crontab_processed"
        
        if [[ -f "$crontab_template" ]]; then
            # Replace environment variables in crontab
            envsubst < "$crontab_template" > "$crontab_processed"
            
            # Install crontab
            crontab "$crontab_processed"
            
            log_info "Backup schedule installed"
        else
            log_warning "Crontab template not found, backup scheduling disabled"
        fi
    else
        log_info "Backup scheduling is disabled"
    fi
}

# Health check function
health_check() {
    local timeout=${1:-30}
    
    # Check pgBackRest
    if ! timeout "$timeout" pgbackrest --stanza="$PGBACKREST_STANZA" check >/dev/null 2>&1; then
        log_error "pgBackRest health check failed"
        return 1
    fi
    
    # Check PostgreSQL connectivity
    if ! timeout "$timeout" pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
        log_error "PostgreSQL connectivity check failed"
        return 1
    fi
    
    # Check repository accessibility
    if [[ ! -w "$PGBACKREST_REPO1_PATH" ]]; then
        log_error "Repository is not writable: $PGBACKREST_REPO1_PATH"
        return 1
    fi
    
    return 0
}

# Signal handlers
cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    
    # Stop any running backup processes gracefully
    if pgrep -f "pgbackrest.*backup" >/dev/null; then
        log_info "Stopping running backup processes..."
        pkill -TERM -f "pgbackrest.*backup" || true
        sleep 5
        pkill -KILL -f "pgbackrest.*backup" || true
    fi
    
    # Stop cron
    if pgrep crond >/dev/null; then
        log_info "Stopping cron daemon..."
        pkill -TERM crond || true
    fi
    
    log_info "Cleanup completed"
    exit 0
}

# Setup signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Main initialization sequence
main() {
    log_info "Starting pgBackRest container initialization..."
    log_info "pgBackRest version: $(pgbackrest version | head -1)"
    
    # Validate environment
    validate_environment
    
    # Wait for PostgreSQL
    if ! wait_for_postgres; then
        log_error "PostgreSQL is not available, cannot continue"
        exit 1
    fi
    
    # Initialize stanza
    if ! initialize_stanza; then
        log_error "Failed to initialize pgBackRest stanza"
        exit 1
    fi
    
    # Setup WAL archiving verification
    setup_wal_archiving
    
    # Setup cron schedule
    setup_cron
    
    # Initial health check
    if ! health_check 60; then
        log_error "Initial health check failed"
        exit 1
    fi
    
    log_info "pgBackRest container initialization completed successfully"
    
    # If no command provided, start cron daemon
    if [[ $# -eq 0 ]] || [[ "$1" == "crond" ]]; then
        log_info "Starting cron daemon..."
        exec crond -f -l 8
    else
        log_info "Executing command: $*"
        exec "$@"
    fi
}

# Handle special commands
case "${1:-}" in
    "health-check")
        if health_check; then
            echo "Health check passed"
            exit 0
        else
            echo "Health check failed"
            exit 1
        fi
        ;;
    "test-backup")
        log_info "Running test backup..."
        pgbackrest --stanza="$PGBACKREST_STANZA" --type=full backup
        ;;
    "info")
        pgbackrest --stanza="$PGBACKREST_STANZA" info
        ;;
    "check")
        pgbackrest --stanza="$PGBACKREST_STANZA" check
        ;;
    *)
        main "$@"
        ;;
esac 