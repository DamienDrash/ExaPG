#!/bin/bash
# ===================================================================
# ExaPG CLI UI Framework Core
# ===================================================================
# ARCHITECTURE FIX: Extracted from 2221-line terminal-ui.sh monolith
# I18N FIX: I18N-002 - Integrated multilingual support
# Date: 2024-05-24
# Version: 3.0.0 (Modular + I18N)
# ===================================================================

# ===================================================================
# LOAD I18N FRAMEWORK
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly I18N_DIR="$SCRIPT_DIR/../i18n"

# Load internationalization framework
if [[ -f "$I18N_DIR/messages.sh" ]]; then
    source "$I18N_DIR/messages.sh"
else
    echo "ERROR: I18N framework not found" >&2
    exit 1
fi

# ===================================================================
# GLOBAL CONFIGURATION
# ===================================================================

readonly EXAPG_VERSION="3.0.0"
readonly EXAPG_PROFILES_DIR="config/profiles"
readonly EXAPG_DEFAULT_PROFILE="default"

# UI Configuration
readonly UI_WIDTH=120
readonly UI_HEIGHT=40
readonly DIALOG_WIDTH=80
readonly DIALOG_HEIGHT=20

# Navigation Stack
declare -a MENU_STACK=()
CURRENT_MENU="main"
EXAPG_CURRENT_PROFILE=""

# ===================================================================
# COLOR THEMES & STYLING
# ===================================================================

# Color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_UNDERLINE='\033[4m'

# Primary colors
readonly COLOR_PRIMARY='\033[0;34m'      # Blue
readonly COLOR_SUCCESS='\033[0;32m'      # Green
readonly COLOR_WARNING='\033[0;33m'      # Yellow
readonly COLOR_ERROR='\033[0;31m'        # Red
readonly COLOR_INFO='\033[0;36m'         # Cyan

# Background colors
readonly BG_PRIMARY='\033[44m'
readonly BG_SUCCESS='\033[42m'
readonly BG_WARNING='\033[43m'
readonly BG_ERROR='\033[41m'

# Theme configuration
declare -A THEMES=(
    ["dark.primary"]="${COLOR_PRIMARY}"
    ["dark.success"]="${COLOR_SUCCESS}"
    ["dark.warning"]="${COLOR_WARNING}"
    ["dark.error"]="${COLOR_ERROR}"
    ["dark.info"]="${COLOR_INFO}"
    ["dark.reset"]="${COLOR_RESET}"
    ["dark.bold"]="${COLOR_BOLD}"
)

CURRENT_THEME="dark"

# ===================================================================
# BASIC UI FUNCTIONS (I18N-enabled)
# ===================================================================

# Clear screen with branding
ui_clear() {
    clear
    ui_header
}

# Print header with branding (I18N)
ui_header() {
    local width=${1:-$UI_WIDTH}
    echo -e "${THEMES[${CURRENT_THEME}.primary]}${THEMES[${CURRENT_THEME}.bold]}"
    printf '═%.0s' $(seq 1 $width)
    echo
    local header_text
    header_text=$(msg "app_title")
    printf "%-${width}s" "  $header_text v${EXAPG_VERSION}"
    echo
    printf '═%.0s' $(seq 1 $width)
    echo -e "${THEMES[${CURRENT_THEME}.reset]}"
    echo
}

# Print section header (I18N)
ui_section() {
    local title_key="$1"
    local width=${2:-$UI_WIDTH}
    local title
    title=$(msg "$title_key")
    
    echo
    echo -e "${THEMES[${CURRENT_THEME}.info]}${THEMES[${CURRENT_THEME}.bold]}"
    printf "▶ %-$((width-3))s" "$title"
    echo -e "${THEMES[${CURRENT_THEME}.reset]}"
    printf '─%.0s' $(seq 1 $width)
    echo
}

# Print subsection (I18N)
ui_subsection() {
    local title_key="$1"
    local title
    title=$(msg "$title_key")
    echo
    echo -e "${THEMES[${CURRENT_THEME}.primary]}  ● $title${THEMES[${CURRENT_THEME}.reset]}"
}

# Print status message (I18N)
ui_status() {
    local level="$1"
    local message_key="$2"
    shift 2
    local timestamp=$(date '+%H:%M:%S')
    local message
    message=$(msg "$message_key" "$@")
    
    case "$level" in
        "info")
            echo -e "${THEMES[${CURRENT_THEME}.info]}[$timestamp] ℹ  $message${THEMES[${CURRENT_THEME}.reset]}"
            ;;
        "success")
            echo -e "${THEMES[${CURRENT_THEME}.success]}[$timestamp] ✓  $message${THEMES[${CURRENT_THEME}.reset]}"
            ;;
        "warning")
            echo -e "${THEMES[${CURRENT_THEME}.warning]}[$timestamp] ⚠  $message${THEMES[${CURRENT_THEME}.reset]}"
            ;;
        "error")
            echo -e "${THEMES[${CURRENT_THEME}.error]}[$timestamp] ✗  $message${THEMES[${CURRENT_THEME}.reset]}"
            ;;
        *)
            echo -e "[$timestamp] $message"
            ;;
    esac
}

# Progress bar (I18N)
ui_progress() {
    local current="$1"
    local total="$2"
    local message_key="$3"
    shift 3
    local width=50
    local message
    message=$(msg "$message_key" "$@")
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${THEMES[${CURRENT_THEME}.info]}%s [" "$message"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%% (%d/%d)${THEMES[${CURRENT_THEME}.reset]}" "$percentage" "$current" "$total"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Spinner animation (I18N)
ui_spinner() {
    local pid=$1
    local message_key="$2"
    shift 2
    local message
    message=$(msg "$message_key" "$@")
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${THEMES[${CURRENT_THEME}.info]}${spinner_chars:$i:1} %s${THEMES[${CURRENT_THEME}.reset]}" "$message"
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        local success_msg
        success_msg=$(msg "completed")
        printf "\r${THEMES[${CURRENT_THEME}.success]}✓ %s${THEMES[${CURRENT_THEME}.reset]}\n" "$success_msg"
    else
        local failed_msg
        failed_msg=$(msg "failed")
        printf "\r${THEMES[${CURRENT_THEME}.error]}✗ %s${THEMES[${CURRENT_THEME}.reset]}\n" "$failed_msg"
    fi
    
    return $exit_code
}

# ===================================================================
# INPUT FUNCTIONS (I18N-enabled)
# ===================================================================

# Read user input with prompt (I18N)
ui_read() {
    local prompt_key="$1"
    local default="$2"
    local variable_name="$3"
    local prompt
    prompt=$(msg "$prompt_key")
    
    if [ -n "$default" ]; then
        echo -e -n "${THEMES[${CURRENT_THEME}.primary]}$prompt${THEMES[${CURRENT_THEME}.dim]} [$default]${THEMES[${CURRENT_THEME}.reset]}: "
    else
        echo -e -n "${THEMES[${CURRENT_THEME}.primary]}$prompt${THEMES[${CURRENT_THEME}.reset]}: "
    fi
    
    read -r input
    
    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi
    
    if [ -n "$variable_name" ]; then
        declare -g "$variable_name=$input"
    else
        echo "$input"
    fi
}

# Read password securely (I18N)
ui_read_password() {
    local prompt_key="$1"
    local variable_name="$2"
    local prompt
    prompt=$(msg "$prompt_key")
    
    echo -e -n "${THEMES[${CURRENT_THEME}.primary]}$prompt${THEMES[${CURRENT_THEME}.reset]}: "
    read -s -r password
    echo
    
    if [ -n "$variable_name" ]; then
        declare -g "$variable_name=$password"
    else
        echo "$password"
    fi
}

# Confirmation dialog (I18N)
ui_confirm() {
    local prompt_key="$1"
    local default="${2:-n}"
    local prompt
    prompt=$(msg "$prompt_key")
    
    if [ "$default" = "y" ]; then
        echo -e -n "${THEMES[${CURRENT_THEME}.warning]}$prompt${THEMES[${CURRENT_THEME}.dim]} [Y/n]${THEMES[${CURRENT_THEME}.reset]}: "
    else
        echo -e -n "${THEMES[${CURRENT_THEME}.warning]}$prompt${THEMES[${CURRENT_THEME}.dim]} [y/N]${THEMES[${CURRENT_THEME}.reset]}: "
    fi
    
    read -r response
    
    if [ -z "$response" ]; then
        response="$default"
    fi
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss]|[Jj]|[Jj][Aa])  # Support German "Ja"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ===================================================================
# LANGUAGE FUNCTIONS
# ===================================================================

# Show language selection menu
ui_language_menu() {
    ui_clear
    ui_section "language_selection_title"
    
    echo "  1) English"
    echo "  2) Deutsch"
    echo "  3) Français"
    echo "  4) Español"
    echo
    
    local current_lang
    current_lang=$(get_language)
    msgln "info_general" "$(msg 'language_changed' "$current_lang")"
    
    echo
    ui_read "language_selection_prompt" "" choice
    
    case "$choice" in
        "1") set_language "en" ;;
        "2") set_language "de" ;;
        "3") set_language "fr" ;;
        "4") set_language "es" ;;
        *) 
            ui_status "error" "invalid_selection"
            ui_wait_key
            return 1
            ;;
    esac
    
    ui_status "success" "language_changed" "$(get_language)"
    ui_wait_key
}

# ===================================================================
# UTILITY FUNCTIONS (I18N-enabled)
# ===================================================================

# Wait for key press (I18N)
ui_wait_key() {
    local message_key="${1:-prompt_continue}"
    local message
    message=$(msg "$message_key")
    echo
    echo -e "${THEMES[${CURRENT_THEME}.dim]}$message${THEMES[${CURRENT_THEME}.reset]}"
    read -n 1 -s
}

# Show loading animation (I18N)
ui_loading() {
    local message_key="$1"
    local duration="${2:-3}"
    
    for i in $(seq 1 $duration); do
        ui_progress $i $duration "$message_key"
        sleep 1
    done
}

# Footer with navigation hints (I18N)
ui_footer() {
    echo
    printf '─%.0s' $(seq 1 $UI_WIDTH)
    echo
    local nav_help
    nav_help=$(msg "help_navigation")
    echo -e "${THEMES[${CURRENT_THEME}.dim]}$nav_help${THEMES[${CURRENT_THEME}.reset]}"
}

# ===================================================================
# INITIALIZATION
# ===================================================================

# Initialize UI framework
ui_init() {
    # Set terminal title (I18N)
    local title
    title=$(msg "app_title")
    echo -ne "\033]0;$title v${EXAPG_VERSION}\007"
    
    # Enable mouse support if available
    if command -v tput >/dev/null 2>&1; then
        tput smcup 2>/dev/null || true
    fi
    
    # Set initial screen
    ui_clear
}

# Cleanup UI framework
ui_cleanup() {
    if command -v tput >/dev/null 2>&1; then
        tput rmcup 2>/dev/null || true
    fi
    echo -e "${THEMES[${CURRENT_THEME}.reset]}"
}

# Error handler for UI
ui_error_handler() {
    local exit_code=$?
    ui_status "error" "error_general" "exit code: $exit_code"
    ui_cleanup
    exit $exit_code
}

# Setup error handling
trap ui_error_handler ERR

# ===================================================================
# EXPORT FUNCTIONS
# ===================================================================

# Make functions available to other modules
declare -fx ui_clear ui_header ui_section ui_subsection ui_status
declare -fx ui_progress ui_spinner ui_read ui_read_password ui_confirm
declare -fx ui_wait_key ui_loading ui_footer ui_init ui_cleanup
declare -fx ui_language_menu 