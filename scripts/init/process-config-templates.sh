#!/bin/bash
# ===================================================================
# ExaPG Configuration Template Processor
# ===================================================================
# I18N FIX: I18N-001 - Process config templates with env variables
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="/etc/postgresql"
readonly TEMPLATE_DIR="${CONFIG_DIR}"

# ===================================================================
# LOGGING
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CONFIG] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" >&2
}

# ===================================================================
# I18N DEFAULTS
# ===================================================================

set_i18n_defaults() {
    log "Setting internationalization defaults..."
    
    # Locale settings (flexible)
    export EXAPG_LOCALE="${EXAPG_LOCALE:-en_US.UTF-8}"
    export EXAPG_TIMEZONE="${EXAPG_TIMEZONE:-UTC}"
    export EXAPG_LANGUAGE="${EXAPG_LANGUAGE:-en}"
    export EXAPG_TEXT_SEARCH_CONFIG="${EXAPG_TEXT_SEARCH_CONFIG:-pg_catalog.english}"
    export EXAPG_DATESTYLE="${EXAPG_DATESTYLE:-iso, ymd}"
    
    # Detect locale from environment if available
    if [[ -n "${LANG:-}" ]] && [[ "${LANG}" != "C" ]]; then
        export EXAPG_LOCALE="${LANG}"
        log "Detected system locale: $EXAPG_LOCALE"
    fi
    
    # Set text search config based on locale
    case "${EXAPG_LOCALE}" in
        de_DE*|de_AT*|de_CH*)
            export EXAPG_TEXT_SEARCH_CONFIG="pg_catalog.german"
            ;;
        fr_FR*|fr_CA*)
            export EXAPG_TEXT_SEARCH_CONFIG="pg_catalog.french"
            ;;
        es_ES*|es_MX*)
            export EXAPG_TEXT_SEARCH_CONFIG="pg_catalog.spanish"
            ;;
        ru_RU*)
            export EXAPG_TEXT_SEARCH_CONFIG="pg_catalog.russian"
            ;;
        *)
            export EXAPG_TEXT_SEARCH_CONFIG="pg_catalog.english"
            ;;
    esac
    
    log "Locale configuration:"
    log "  EXAPG_LOCALE: $EXAPG_LOCALE"
    log "  EXAPG_TIMEZONE: $EXAPG_TIMEZONE"
    log "  EXAPG_LANGUAGE: $EXAPG_LANGUAGE"
    log "  EXAPG_TEXT_SEARCH_CONFIG: $EXAPG_TEXT_SEARCH_CONFIG"
    log "  EXAPG_DATESTYLE: $EXAPG_DATESTYLE"
}

# ===================================================================
# TEMPLATE PROCESSING
# ===================================================================

process_template() {
    local template_file="$1"
    local output_file="$2"
    
    log "Processing template: $template_file -> $output_file"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Process template with envsubst
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "$template_file" > "$output_file"
    else
        # Fallback: manual substitution for common variables
        local temp_file="/tmp/config_temp_$$"
        cp "$template_file" "$temp_file"
        
        # Replace common variables
        local vars=(
            "EXAPG_LOCALE" "EXAPG_TIMEZONE" "EXAPG_LANGUAGE"
            "EXAPG_TEXT_SEARCH_CONFIG" "EXAPG_DATESTYLE"
            "POSTGRES_PORT" "POSTGRES_SHARED_BUFFERS" "POSTGRES_WORK_MEM"
            "POSTGRES_LOG_LEVEL" "POSTGRES_SSL_ENABLED"
        )
        
        for var in "${vars[@]}"; do
            local value="${!var:-}"
            if [[ -n "$value" ]]; then
                sed -i "s/\${$var:-[^}]*}/$value/g" "$temp_file"
                sed -i "s/\${$var}/$value/g" "$temp_file"
            fi
        done
        
        mv "$temp_file" "$output_file"
    fi
    
    # Set proper permissions
    chmod 644 "$output_file"
    chown postgres:postgres "$output_file" 2>/dev/null || true
    
    log_success "Template processed successfully: $output_file"
}

# ===================================================================
# MAIN PROCESSING
# ===================================================================

process_postgresql_config() {
    log "Processing PostgreSQL configuration templates..."
    
    # Main postgresql.conf
    if [[ -f "${CONFIG_DIR}/postgresql.conf.template" ]]; then
        process_template "${CONFIG_DIR}/postgresql.conf.template" "${CONFIG_DIR}/postgresql.conf"
    else
        log_error "PostgreSQL configuration template not found"
        return 1
    fi
    
    # Coordinator-specific config
    if [[ -f "${CONFIG_DIR}/postgresql-coordinator.conf.template" ]]; then
        process_template "${CONFIG_DIR}/postgresql-coordinator.conf.template" "${CONFIG_DIR}/postgresql-coordinator.conf"
    fi
    
    # Worker-specific config  
    if [[ -f "${CONFIG_DIR}/postgresql-worker.conf.template" ]]; then
        process_template "${CONFIG_DIR}/postgresql-worker.conf.template" "${CONFIG_DIR}/postgresql-worker.conf"
    fi
    
    log_success "PostgreSQL configuration processing completed"
}

validate_config() {
    log "Validating generated configuration..."
    
    local config_file="${CONFIG_DIR}/postgresql.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check for unprocessed templates
    if grep -q '\${' "$config_file"; then
        log_error "Unprocessed template variables found in $config_file"
        grep '\${' "$config_file" | head -5
        return 1
    fi
    
    # Validate locale
    if ! locale -a | grep -q "${EXAPG_LOCALE%%.*}" 2>/dev/null; then
        log_error "Locale $EXAPG_LOCALE is not available on this system"
        log "Available locales:"
        locale -a | head -10 || true
        return 1
    fi
    
    log_success "Configuration validation completed"
}

show_config_summary() {
    log "Configuration Summary:"
    echo "========================================"
    echo "Internationalization Settings:"
    echo "  Locale: $EXAPG_LOCALE"
    echo "  Timezone: $EXAPG_TIMEZONE" 
    echo "  Language: $EXAPG_LANGUAGE"
    echo "  Text Search: $EXAPG_TEXT_SEARCH_CONFIG"
    echo "  Date Style: $EXAPG_DATESTYLE"
    echo ""
    echo "Generated Files:"
    
    for file in postgresql.conf postgresql-coordinator.conf postgresql-worker.conf; do
        if [[ -f "${CONFIG_DIR}/$file" ]]; then
            echo "  ✓ ${CONFIG_DIR}/$file"
        else
            echo "  ✗ ${CONFIG_DIR}/$file (not found)"
        fi
    done
    echo "========================================"
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    log "Starting ExaPG configuration template processing..."
    
    # Set I18N defaults
    set_i18n_defaults
    
    # Process templates
    process_postgresql_config
    
    # Validate results
    validate_config
    
    # Show summary
    show_config_summary
    
    log_success "Configuration template processing completed successfully!"
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Configuration Template Processor

This script processes PostgreSQL configuration templates with environment 
variables to support flexible internationalization.

Usage: $0 [options]

Environment Variables:
  EXAPG_LOCALE              System locale (default: en_US.UTF-8)
  EXAPG_TIMEZONE            Timezone (default: UTC)
  EXAPG_LANGUAGE            UI language (default: en)
  EXAPG_TEXT_SEARCH_CONFIG  Full-text search config (auto-detected)
  EXAPG_DATESTYLE           Date formatting (default: iso, ymd)

Examples:
  $0                                    # Use defaults (English/UTC)
  EXAPG_LOCALE=de_DE.UTF-8 $0          # German locale
  EXAPG_TIMEZONE=Europe/Berlin $0       # Berlin timezone
  EXAPG_LANGUAGE=fr $0                  # French UI

Supported Locales:
  - en_US.UTF-8 (English - default)
  - de_DE.UTF-8 (German)
  - fr_FR.UTF-8 (French)
  - es_ES.UTF-8 (Spanish)
  - ru_RU.UTF-8 (Russian)
EOF
    exit 0
fi

# Run main function
main "$@" 