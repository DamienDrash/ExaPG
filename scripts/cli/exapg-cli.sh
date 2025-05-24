#!/bin/bash
# ===================================================================
# ExaPG CLI - Modular Entry Point
# ===================================================================
# ARCHITECTURE FIX: Replaced 2221-line terminal-ui.sh monolith
# Date: 2024-05-24
# Version: 3.0.0 (Modular Architecture)
#
# Usage:
#   ./scripts/cli/exapg-cli.sh           # Interactive mode
#   ./scripts/cli/exapg-cli.sh deploy    # Direct command
#   ./scripts/cli/exapg-cli.sh --help    # Show help
# ===================================================================

set -euo pipefail

# ===================================================================
# GLOBAL CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly CLI_VERSION="3.0.0"

# Module paths
readonly CORE_DIR="$SCRIPT_DIR/core"
readonly MODULES_DIR="$SCRIPT_DIR/modules" 
readonly UTILS_DIR="$SCRIPT_DIR/utils"

# ===================================================================
# BOOTSTRAP & MODULE LOADING
# ===================================================================

# Load core modules
load_core_modules() {
    local modules=(
        "$CORE_DIR/ui-framework.sh"
        "$CORE_DIR/navigation.sh"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$module" ]]; then
            source "$module"
        else
            echo "ERROR: Core module not found: $module" >&2
            exit 1
        fi
    done
}

# Load utility modules
load_utility_modules() {
    local utils=(
        "$UTILS_DIR/validation.sh"
        "$UTILS_DIR/logging.sh"
        "$UTILS_DIR/docker-utils.sh"
    )
    
    for util in "${utils[@]}"; do
        if [[ -f "$util" ]]; then
            source "$util"
        else
            echo "WARNING: Utility module not found: $util" >&2
        fi
    done
}

# Load feature modules on demand
load_feature_module() {
    local module_name="$1"
    local module_path="$MODULES_DIR/${module_name}.sh"
    
    if [[ -f "$module_path" ]]; then
        source "$module_path"
        return 0
    else
        ui_status "error" "Feature module not found: $module_name"
        return 1
    fi
}

# ===================================================================
# ENVIRONMENT SETUP
# ===================================================================

# Setup environment and change to project root
setup_environment() {
    cd "$PROJECT_ROOT" || {
        echo "ERROR: Cannot access project root: $PROJECT_ROOT" >&2
        exit 1
    }
    
    # Check for required files
    if [[ ! -f ".env" ]]; then
        echo "WARNING: .env file not found. Creating from template..."
        if [[ -f ".env.template" ]]; then
            cp ".env.template" ".env"
        else
            echo "ERROR: .env.template not found. Cannot continue." >&2
            exit 1
        fi
    fi
    
    # Load environment variables
    set -a
    source ".env"
    set +a
    
    # Validate environment
    if [[ -f "scripts/validate-env-simple.sh" ]]; then
        if ! bash "scripts/validate-env-simple.sh" >/dev/null 2>&1; then
            echo "WARNING: Environment validation failed. Some features may not work."
        fi
    fi
}

# ===================================================================
# MAIN APPLICATION LOOP
# ===================================================================

# Main interactive loop
main_loop() {
    local choice
    
    # Initialize UI
    ui_init
    
    while true; do
        ui_clear
        show_breadcrumb
        
        # Get current menu and render it
        local menu_title
        menu_title=$(get_menu_title)
        local menu_ref
        menu_ref=$(get_current_menu_ref)
        
        # Use nameref to get menu array
        local -n current_menu="$menu_ref"
        render_menu "$menu_title" current_menu
        
        # Read user choice
        echo -ne "${THEMES[${CURRENT_THEME}.primary]}Choose an option: ${THEMES[${CURRENT_THEME}.reset]}"
        read -r choice
        
        # Handle global shortcuts
        case "$choice" in
            "h"|"help")
                show_help
                continue
                ;;
            "q"|"quit"|"exit")
                confirm_exit
                continue
                ;;
            "b"|"back")
                if [[ "$CURRENT_MENU" != "main" ]]; then
                    navigate_back
                else
                    ui_status "warning" "Already at main menu"
                    ui_wait_key
                fi
                continue
                ;;
        esac
        
        # Handle menu-specific choices
        handle_menu_selection "$CURRENT_MENU" "$choice"
    done
}

# ===================================================================
# DIRECT COMMAND INTERFACE
# ===================================================================

# Handle direct commands (non-interactive mode)
handle_direct_command() {
    local command="$1"
    shift
    
    case "$command" in
        "deploy"|"deployment")
            load_feature_module "deployment"
            start_deployment "$@"
            ;;
        "status")
            load_feature_module "deployment"
            check_deployment_status "$@"
            ;;
        "stop")
            load_feature_module "deployment"
            stop_deployment "$@"
            ;;
        "restart")
            load_feature_module "deployment"
            restart_deployment "$@"
            ;;
        "logs")
            load_feature_module "deployment"
            view_logs "$@"
            ;;
        "monitor"|"monitoring")
            load_feature_module "monitoring"
            open_dashboard "$@"
            ;;
        "metrics")
            load_feature_module "monitoring"
            view_metrics "$@"
            ;;
        "benchmark"|"performance")
            load_feature_module "performance"
            run_benchmark "$@"
            ;;
        "backup")
            load_feature_module "backup"
            manage_backup "$@"
            ;;
        "config"|"configure")
            manage_configuration "$@"
            ;;
        "validate")
            validate_environment "$@"
            ;;
        "version"|"--version")
            show_version
            ;;
        "help"|"--help")
            show_help_text
            ;;
        *)
            echo "ERROR: Unknown command: $command" >&2
            echo "Use '$0 --help' for available commands" >&2
            exit 1
            ;;
    esac
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Show version information
show_version() {
    echo "ExaPG CLI v$CLI_VERSION"
    echo "PostgreSQL Analytical Database Management Tool"
    echo "Architecture: Modular (Core + Modules + Utils)"
    echo
    echo "Components:"
    echo "  - Core UI Framework: $(wc -l < "$CORE_DIR/ui-framework.sh") lines"
    echo "  - Navigation System: $(wc -l < "$CORE_DIR/navigation.sh") lines"
    echo "  - Available Modules: $(find "$MODULES_DIR" -name "*.sh" 2>/dev/null | wc -l || echo "0")"
    echo "  - Utility Functions: $(find "$UTILS_DIR" -name "*.sh" 2>/dev/null | wc -l || echo "0")"
    echo
    echo "Total reduction from monolith: ~$(( $(wc -l < scripts/cli/terminal-ui.sh || echo 2221) - $(wc -l < "$0") )) lines"
}

# Show help text for command line usage
show_help_text() {
    cat << EOF
ExaPG CLI v$CLI_VERSION - PostgreSQL Analytical Database Management

USAGE:
    $0                          # Interactive mode (recommended)
    $0 <command> [options]      # Direct command execution
    $0 --help                   # Show this help
    $0 --version                # Show version information

COMMANDS:
    deploy          Start a new ExaPG deployment
    status          Check deployment status
    stop            Stop running deployment
    restart         Restart deployment services
    logs            View deployment logs
    monitor         Open monitoring dashboard
    metrics         View system metrics
    benchmark       Run performance benchmarks
    backup          Manage backups
    config          Configuration management
    validate        Validate environment setup

EXAMPLES:
    $0                          # Start interactive CLI
    $0 deploy --profile prod    # Deploy with production profile
    $0 status                   # Quick status check
    $0 monitor                  # Open monitoring dashboard
    $0 benchmark --quick        # Run quick benchmark

INTERACTIVE MODE:
    In interactive mode, navigate using:
    - Number keys to select options
    - 'b' to go back
    - 'q' to quit
    - 'h' for help

FILES:
    .env                        # Environment configuration
    config/profiles/            # Deployment profiles
    docker/docker-compose/      # Container configurations
    logs/                       # Application logs

For detailed documentation, visit: docs/user-guide/
For troubleshooting, visit: docs/user-guide/troubleshooting.md
EOF
}

# Validate environment setup
validate_environment() {
    echo "🔍 Validating ExaPG environment..."
    
    local errors=0
    
    # Check for required tools
    local required_tools=("docker" "docker-compose")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "❌ Missing required tool: $tool"
            ((errors++))
        else
            echo "✅ Found: $tool"
        fi
    done
    
    # Check environment file
    if [[ -f "scripts/validate-env.sh" ]]; then
        echo "🔧 Running environment validation..."
        if bash "scripts/validate-env.sh"; then
            echo "✅ Environment validation passed"
        else
            echo "⚠️  Environment validation warnings detected"
        fi
    fi
    
    # Check Docker
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker daemon is running"
    else
        echo "❌ Docker daemon is not accessible"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "🎉 Environment validation successful!"
        return 0
    else
        echo "💥 Environment validation failed with $errors errors"
        return 1
    fi
}

# Manage configuration
manage_configuration() {
    echo "⚙️  Configuration Management"
    echo "=========================="
    
    # List available profiles
    if [[ -d "config/profiles" ]]; then
        echo "Available profiles:"
        ls -1 config/profiles/ | sed 's/^/  - /'
    fi
    
    # Show current environment
    echo
    echo "Current environment variables:"
    echo "  DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-not set}"
    echo "  WORKER_COUNT=${WORKER_COUNT:-not set}"
    echo "  SHARED_BUFFERS=${SHARED_BUFFERS:-not set}"
    
    # Offer to run validation
    echo
    if command -v "./scripts/validate-env.sh" >/dev/null 2>&1; then
        echo "Run validation? [y/N]"
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            bash "scripts/validate-env.sh"
        fi
    fi
}

# ===================================================================
# SIGNAL HANDLERS
# ===================================================================

# Cleanup on exit
cleanup() {
    ui_cleanup
    echo "ExaPG CLI terminated."
}

# Handle interrupt signals
interrupt_handler() {
    echo
    ui_status "warning" "Received interrupt signal"
    if ui_confirm "Do you want to exit ExaPG CLI?" "y"; then
        cleanup
        exit 130
    fi
}

# Setup signal handlers
trap cleanup EXIT
trap interrupt_handler INT TERM

# ===================================================================
# MAIN ENTRY POINT
# ===================================================================

main() {
    # Load modules
    load_core_modules
    load_utility_modules
    
    # Setup environment
    setup_environment
    
    # Check if running in interactive or command mode
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        main_loop
    else
        # Command mode
        handle_direct_command "$@"
    fi
}

# Run main function with all arguments
main "$@" 