#!/bin/bash
# ===================================================================
# ExaPG Docker Init - I18N Template Processing
# ===================================================================
# I18N FIX: I18N-001 - Process configuration templates at startup
# Date: 2024-05-24
# ===================================================================

set -euo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [I18N-INIT] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [I18N-INIT] [ERROR] $*" >&2
}

# Setup I18N environment
setup_i18n_environment() {
    log "Setting up internationalization environment..."
    
    export EXAPG_LOCALE="${EXAPG_LOCALE:-en_US.UTF-8}"
    export EXAPG_TIMEZONE="${EXAPG_TIMEZONE:-UTC}"
    export EXAPG_LANGUAGE="${EXAPG_LANGUAGE:-en}"
    
    # Auto-detect from system LANG
    if [[ -n "${LANG:-}" && "${LANG}" != "C" ]]; then
        export EXAPG_LOCALE="${LANG}"
        export EXAPG_LANGUAGE="${LANG:0:2}"
    fi
    
    # Validate locale
    if ! locale -a | grep -q "^${EXAPG_LOCALE}$" 2>/dev/null; then
        log_error "Locale $EXAPG_LOCALE not available, falling back to en_US.UTF-8"
        export EXAPG_LOCALE="en_US.UTF-8"
        export EXAPG_LANGUAGE="en"
    fi
    
    # Set system locale
    export LANG="$EXAPG_LOCALE"
    export LC_ALL="$EXAPG_LOCALE"
    
    log "I18N Environment: LOCALE=$EXAPG_LOCALE, TIMEZONE=$EXAPG_TIMEZONE, LANGUAGE=$EXAPG_LANGUAGE"
}

# Process templates
process_templates() {
    log "Processing configuration templates..."
    
    local template_processor="/scripts/init/process-config-templates.sh"
    
    if [[ -f "$template_processor" ]]; then
        chmod +x "$template_processor"
        "$template_processor" || {
            log_error "Template processing failed"
            return 1
        }
    else
        log "No template processor found, skipping"
    fi
}

# Main execution
main() {
    log "Starting I18N template processing..."
    
    # Only run in container
    if [[ ! -f "/.dockerenv" ]]; then
        exit 0
    fi
    
    setup_i18n_environment
    
    if [[ -f "/etc/postgresql/postgresql.conf.template" ]]; then
        process_templates
    fi
    
    log "I18N template processing completed"
}

main "$@" 