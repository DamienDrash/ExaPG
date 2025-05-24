#!/bin/bash
# ===================================================================
# ExaPG CLI Internationalization Framework
# ===================================================================
# I18N FIX: I18N-002 - CLI Message Framework
# Date: 2024-05-24
# ===================================================================

readonly CLI_I18N_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_LANGUAGE="${EXAPG_LANGUAGE:-en}"
CURRENT_LANGUAGE="${DEFAULT_LANGUAGE}"

declare -A MESSAGES

# Load language file
load_language() {
    local lang="$1"
    local lang_file="${CLI_I18N_DIR}/${lang}.sh"
    
    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        CURRENT_LANGUAGE="$lang"
        return 0
    else
        # Fallback to English
        if [[ "$lang" != "en" ]] && [[ -f "${CLI_I18N_DIR}/en.sh" ]]; then
            source "${CLI_I18N_DIR}/en.sh"
            CURRENT_LANGUAGE="en"
            return 1
        fi
    fi
}

# Get translated message
msg() {
    local key="$1"
    shift
    local message="${MESSAGES[$key]:-$key}"
    
    if [[ $# -gt 0 ]]; then
        printf "$message" "$@"
    else
        printf "%s" "$message"
    fi
}

# Get translated message with newline
msgln() {
    msg "$@"
    echo
}

# Set current language
set_language() {
    load_language "$1"
}

# Get current language
get_language() {
    echo "$CURRENT_LANGUAGE"
}

# Auto-detect language from environment
init_i18n() {
    local detected_lang="en"
    
    for var in EXAPG_LANGUAGE LANGUAGE LANG LC_ALL; do
        local value="${!var:-}"
        if [[ -n "$value" && "$value" != "C" ]]; then
            detected_lang="${value:0:2}"
            break
        fi
    done
    
    load_language "$detected_lang"
}

# Export functions
declare -fx msg msgln set_language get_language load_language init_i18n

# Initialize I18N when sourced
init_i18n

# ===================================================================
# CORE FUNCTIONS
# ===================================================================

# List available languages
list_languages() {
    local languages=()
    for file in "${CLI_I18N_DIR}"/*.sh; do
        if [[ -f "$file" && "$(basename "$file")" != "messages.sh" ]]; then
            local lang_code="$(basename "$file" .sh)"
            languages+=("$lang_code")
        fi
    done
    printf '%s\n' "${languages[@]}"
}

# Check if language is supported
is_language_supported() {
    local lang="$1"
    [[ -f "${CLI_I18N_DIR}/${lang}.sh" ]]
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Display language selection menu
show_language_menu() {
    local languages=($(list_languages))
    
    msgln "language_selection_title"
    echo
    
    local i=1
    for lang in "${languages[@]}"; do
        # Get language display name
        local display_name="$lang"
        case "$lang" in
            "en") display_name="English" ;;
            "de") display_name="Deutsch" ;;
            "fr") display_name="Français" ;;
            "es") display_name="Español" ;;
            "ru") display_name="Русский" ;;
        esac
        
        local marker=""
        if [[ "$lang" == "$CURRENT_LANGUAGE" ]]; then
            marker=" ✓"
        fi
        
        printf "  %d) %s%s\n" "$i" "$display_name" "$marker"
        ((i++))
    done
    
    echo
}

# Interactive language selection
select_language_interactive() {
    local languages=($(list_languages))
    
    show_language_menu
    
    read -p "$(msg 'language_selection_prompt'): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#languages[@]}" ]]; then
        local selected_lang="${languages[$((choice-1))]}"
        set_language "$selected_lang"
        msgln "language_changed" "$selected_lang"
        return 0
    else
        msgln "invalid_selection"
        return 1
    fi
}

# Format message with colors (if supported)
msg_colored() {
    local color="$1"
    local key="$2"
    shift 2
    
    local message
    message=$(msg "$key" "$@")
    
    # Check if colors are supported
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        case "$color" in
            "red")    printf '\033[0;31m%s\033[0m' "$message" ;;
            "green")  printf '\033[0;32m%s\033[0m' "$message" ;;
            "yellow") printf '\033[0;33m%s\033[0m' "$message" ;;
            "blue")   printf '\033[0;34m%s\033[0m' "$message" ;;
            "bold")   printf '\033[1m%s\033[0m' "$message" ;;
            *)        printf '%s' "$message" ;;
        esac
    else
        printf '%s' "$message"
    fi
}

# Error message with color
error_msg() {
    msg_colored "red" "$@"
    echo
}

# Success message with color
success_msg() {
    msg_colored "green" "$@"
    echo
}

# Warning message with color
warning_msg() {
    msg_colored "yellow" "$@"
    echo
}

# Info message with color
info_msg() {
    msg_colored "blue" "$@"
    echo
}

# ===================================================================
# EXPORT FUNCTIONS
# ===================================================================

# Make functions available to other scripts
declare -fx msg msgln set_language get_language load_language
declare -fx list_languages is_language_supported init_i18n
declare -fx show_language_menu select_language_interactive
declare -fx msg_colored error_msg success_msg warning_msg info_msg

# ===================================================================
# AUTO-INITIALIZATION
# ===================================================================

# Initialize I18N when this script is sourced
init_i18n 
 