#!/bin/bash
# ===================================================================
# ExaPG CLI Navigation Core
# ===================================================================
# ARCHITECTURE FIX: Extracted navigation logic from terminal-ui.sh
# Date: 2024-05-24
# ===================================================================

# ===================================================================
# NAVIGATION STACK MANAGEMENT
# ===================================================================

# Navigate to a specific menu
navigate_to() {
    local menu_name="$1"
    MENU_STACK+=("$CURRENT_MENU")
    CURRENT_MENU="$menu_name"
    ui_status "info" "Navigated to: $menu_name"
    return 0
}

# Navigate back to previous menu
navigate_back() {
    if [ ${#MENU_STACK[@]} -gt 0 ]; then
        CURRENT_MENU="${MENU_STACK[-1]}"
        unset MENU_STACK[-1]
        ui_status "info" "Navigated back to: $CURRENT_MENU"
    else
        CURRENT_MENU="main"
        ui_status "info" "Returned to main menu"
    fi
    return 0
}

# Navigate to main menu
navigate_home() {
    MENU_STACK=()
    CURRENT_MENU="main"
    ui_status "info" "Returned to main menu"
    return 0
}

# Get current navigation path
get_navigation_path() {
    local path="/"
    for menu in "${MENU_STACK[@]}"; do
        path+="$menu/"
    done
    path+="$CURRENT_MENU"
    echo "$path"
}

# ===================================================================
# MENU DEFINITIONS
# ===================================================================

# Main menu options
declare -A MAIN_MENU=(
    ["1"]="deployment:Deployment Management"
    ["2"]="monitoring:Monitoring & Analytics" 
    ["3"]="backup:Backup & Recovery"
    ["4"]="performance:Performance Testing"
    ["5"]="config:Configuration Management"
    ["6"]="cluster:Cluster Operations"
    ["7"]="security:Security Management"
    ["8"]="help:Help & Documentation"
    ["q"]="quit:Exit ExaPG CLI"
)

# Deployment submenu
declare -A DEPLOYMENT_MENU=(
    ["1"]="deploy:Start Deployment"
    ["2"]="status:Check Status"
    ["3"]="stop:Stop Services"
    ["4"]="restart:Restart Services"
    ["5"]="logs:View Logs"
    ["6"]="profiles:Manage Profiles"
    ["b"]="back:← Back to Main Menu"
)

# Monitoring submenu
declare -A MONITORING_MENU=(
    ["1"]="dashboard:Open Dashboard"
    ["2"]="metrics:View Metrics"
    ["3"]="alerts:Manage Alerts"
    ["4"]="grafana:Grafana Management"
    ["5"]="prometheus:Prometheus Config"
    ["b"]="back:← Back to Main Menu"
)

# Performance submenu
declare -A PERFORMANCE_MENU=(
    ["1"]="benchmark:Run Benchmark"
    ["2"]="tpch:TPC-H Tests"
    ["3"]="stress:Stress Testing"
    ["4"]="analysis:Performance Analysis"
    ["5"]="reports:Generate Reports"
    ["b"]="back:← Back to Main Menu"
)

# ===================================================================
# MENU RENDERING
# ===================================================================

# Render menu options
render_menu() {
    local menu_name="$1"
    local -n menu_ref="$2"
    
    ui_section "$menu_name"
    
    local max_key_width=0
    local max_desc_width=0
    
    # Calculate column widths
    for key in "${!menu_ref[@]}"; do
        local option="${menu_ref[$key]}"
        local desc="${option#*:}"
        
        if [ ${#key} -gt $max_key_width ]; then
            max_key_width=${#key}
        fi
        if [ ${#desc} -gt $max_desc_width ]; then
            max_desc_width=${#desc}
        fi
    done
    
    # Sort keys for consistent display
    local sorted_keys=($(printf '%s\n' "${!menu_ref[@]}" | sort))
    
    # Render options
    for key in "${sorted_keys[@]}"; do
        local option="${menu_ref[$key]}"
        local action="${option%%:*}"
        local desc="${option#*:}"
        
        printf "  %s%-${max_key_width}s%s │ %s\n" \
            "${THEMES[${CURRENT_THEME}.primary]}" \
            "$key" \
            "${THEMES[${CURRENT_THEME}.reset]}" \
            "$desc"
    done
    
    echo
    ui_footer
}

# ===================================================================
# MENU HANDLING
# ===================================================================

# Handle menu selection
handle_menu_selection() {
    local menu_name="$1"
    local choice="$2"
    
    case "$menu_name" in
        "main")
            handle_main_menu "$choice"
            ;;
        "deployment")
            handle_deployment_menu "$choice"
            ;;
        "monitoring")
            handle_monitoring_menu "$choice"
            ;;
        "performance")
            handle_performance_menu "$choice"
            ;;
        "backup")
            handle_backup_menu "$choice"
            ;;
        "config")
            handle_config_menu "$choice"
            ;;
        "cluster")
            handle_cluster_menu "$choice"
            ;;
        "security")
            handle_security_menu "$choice"
            ;;
        *)
            ui_status "error" "Unknown menu: $menu_name"
            return 1
            ;;
    esac
}

# Handle main menu selections
handle_main_menu() {
    local choice="$1"
    
    case "$choice" in
        "1")
            navigate_to "deployment"
            ;;
        "2")
            navigate_to "monitoring"
            ;;
        "3")
            navigate_to "backup"
            ;;
        "4")
            navigate_to "performance"
            ;;
        "5")
            navigate_to "config"
            ;;
        "6")
            navigate_to "cluster"
            ;;
        "7")
            navigate_to "security"
            ;;
        "8")
            show_help
            ;;
        "q"|"quit")
            confirm_exit
            ;;
        *)
            ui_status "error" "Invalid selection: $choice"
            ui_wait_key
            ;;
    esac
}

# Handle deployment menu selections
handle_deployment_menu() {
    local choice="$1"
    
    case "$choice" in
        "1")
            # Load deployment module
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/deployment.sh"
            start_deployment
            ;;
        "2")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/deployment.sh"
            check_deployment_status
            ;;
        "3")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/deployment.sh"
            stop_deployment
            ;;
        "4")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/deployment.sh"
            restart_deployment
            ;;
        "5")
            source "$(dirname "${BASH_SOURCE[0]}")/../utils/logging.sh"
            view_logs
            ;;
        "6")
            manage_profiles
            ;;
        "b"|"back")
            navigate_back
            ;;
        *)
            ui_status "error" "Invalid selection: $choice"
            ui_wait_key
            ;;
    esac
}

# Handle monitoring menu selections
handle_monitoring_menu() {
    local choice="$1"
    
    case "$choice" in
        "1")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/monitoring.sh"
            open_dashboard
            ;;
        "2")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/monitoring.sh"
            view_metrics
            ;;
        "3")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/monitoring.sh"
            manage_alerts
            ;;
        "4")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/monitoring.sh"
            manage_grafana
            ;;
        "5")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/monitoring.sh"
            configure_prometheus
            ;;
        "b"|"back")
            navigate_back
            ;;
        *)
            ui_status "error" "Invalid selection: $choice"
            ui_wait_key
            ;;
    esac
}

# Handle performance menu selections
handle_performance_menu() {
    local choice="$1"
    
    case "$choice" in
        "1"|"2"|"3"|"4"|"5")
            source "$(dirname "${BASH_SOURCE[0]}")/../modules/performance.sh"
            handle_performance_action "$choice"
            ;;
        "b"|"back")
            navigate_back
            ;;
        *)
            ui_status "error" "Invalid selection: $choice"
            ui_wait_key
            ;;
    esac
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Show help information
show_help() {
    ui_clear
    ui_section "ExaPG CLI Help"
    
    cat << EOF
🔧 NAVIGATION
  - Use number keys to select menu options
  - Press 'b' to go back to previous menu
  - Press 'q' to quit the application
  - Press 'h' for help (from any menu)

📋 MAIN FEATURES
  1. Deployment Management - Start, stop, and manage ExaPG deployments
  2. Monitoring & Analytics - View metrics, dashboards, and alerts
  3. Backup & Recovery - Manage backups and disaster recovery
  4. Performance Testing - Run benchmarks and performance analysis
  5. Configuration Management - Manage settings and profiles
  6. Cluster Operations - Scale and manage cluster nodes
  7. Security Management - Configure authentication and SSL
  8. Help & Documentation - Access guides and troubleshooting

🚀 QUICK START
  - Select option 1 to start a new deployment
  - Use option 2 to monitor your running cluster
  - Check option 8 for detailed documentation

📚 DOCUMENTATION
  - User Guide: docs/user-guide/
  - Technical Docs: docs/technical/
  - Troubleshooting: docs/user-guide/troubleshooting.md
EOF
    
    ui_wait_key "Press any key to return to main menu..."
    navigate_home
}

# Confirm exit
confirm_exit() {
    ui_clear
    if ui_confirm "Are you sure you want to exit ExaPG CLI?" "n"; then
        ui_status "info" "Thank you for using ExaPG CLI!"
        ui_cleanup
        exit 0
    fi
}

# Get current menu reference
get_current_menu_ref() {
    case "$CURRENT_MENU" in
        "main")
            echo "MAIN_MENU"
            ;;
        "deployment")
            echo "DEPLOYMENT_MENU"
            ;;
        "monitoring")
            echo "MONITORING_MENU"
            ;;
        "performance")
            echo "PERFORMANCE_MENU"
            ;;
        *)
            echo "MAIN_MENU"
            ;;
    esac
}

# Get menu title
get_menu_title() {
    case "$CURRENT_MENU" in
        "main")
            echo "ExaPG Main Menu"
            ;;
        "deployment")
            echo "Deployment Management"
            ;;
        "monitoring") 
            echo "Monitoring & Analytics"
            ;;
        "performance")
            echo "Performance Testing"
            ;;
        "backup")
            echo "Backup & Recovery"
            ;;
        "config")
            echo "Configuration Management"
            ;;
        "cluster")
            echo "Cluster Operations"
            ;;
        "security")
            echo "Security Management"
            ;;
        *)
            echo "ExaPG Menu"
            ;;
    esac
}

# ===================================================================
# BREADCRUMB NAVIGATION
# ===================================================================

# Show navigation breadcrumb
show_breadcrumb() {
    local path="Home"
    
    for menu in "${MENU_STACK[@]}"; do
        path+=" → $(get_menu_display_name "$menu")"
    done
    
    if [ "$CURRENT_MENU" != "main" ]; then
        path+=" → $(get_menu_display_name "$CURRENT_MENU")"
    fi
    
    echo -e "${THEMES[${CURRENT_THEME}.dim]}📍 $path${THEMES[${CURRENT_THEME}.reset]}"
    echo
}

# Get display name for menu
get_menu_display_name() {
    case "$1" in
        "main") echo "Home" ;;
        "deployment") echo "Deployment" ;;
        "monitoring") echo "Monitoring" ;;
        "performance") echo "Performance" ;;
        "backup") echo "Backup" ;;
        "config") echo "Configuration" ;;
        "cluster") echo "Cluster" ;;
        "security") echo "Security" ;;
        *) echo "$1" ;;
    esac
}

# ===================================================================
# EXPORT FUNCTIONS
# ===================================================================

# Export navigation functions
declare -fx navigate_to navigate_back navigate_home get_navigation_path
declare -fx render_menu handle_menu_selection show_help confirm_exit
declare -fx get_current_menu_ref get_menu_title show_breadcrumb 