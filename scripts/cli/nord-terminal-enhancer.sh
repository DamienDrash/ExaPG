#!/bin/bash
# Nord Terminal Enhancer for ExaPG v1.0
# Enhanced Nord Dark Theme integration for professional terminal experience
# Based on official Nord color palette: https://www.nordtheme.com/

set -euo pipefail

# Nord Color Palette Constants
readonly NORD0="2e/34/40"   # Polar Night - darkest
readonly NORD1="3b/42/52"   # Polar Night
readonly NORD2="43/4c/5e"   # Polar Night
readonly NORD3="4c/56/6a"   # Polar Night - lightest

readonly NORD4="d8/de/e9"   # Snow Storm - darkest
readonly NORD5="e5/e9/f0"   # Snow Storm
readonly NORD6="ec/ef/f4"   # Snow Storm - lightest

readonly NORD7="8f/bc/bb"   # Frost - teal
readonly NORD8="88/c0/d0"   # Frost - light blue
readonly NORD9="81/a1/c1"   # Frost - blue
readonly NORD10="5e/81/ac"  # Frost - dark blue

readonly NORD11="bf/61/6a"  # Aurora - red
readonly NORD12="d0/87/70"  # Aurora - orange
readonly NORD13="eb/cb/8b"  # Aurora - yellow
readonly NORD14="a3/be/8c"  # Aurora - green
readonly NORD15="b4/8e/ad"  # Aurora - purple

# Enhanced Nord Dark Theme Generator for Dialog
generate_enhanced_nord_dark_theme() {
    cat << 'EOF'
# ExaPG Enhanced Nord Dark Theme v3.0
# Optimized for better terminal visibility and Nord compliance
# https://nordtheme.com

# Dialog-Verhalten
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# ═══════════════════════════════════════════════════════════════
# ENHANCED NORD DARK PALETTE MAPPING
# ═══════════════════════════════════════════════════════════════
# Polar Night (Dark backgrounds):
#   nord0: #2E3440 → BLACK (Base background)
#   nord1: #3B4252 → BLACK+DIM (Elevated background)
#   nord2: #434C5E → BLACK+BRIGHT (Selection background)
#   nord3: #4C566A → BLACK+BRIGHT+DIM (Highlight background)
#
# Snow Storm (Light foregrounds):
#   nord4: #D8DEE9 → WHITE+DIM (Subtle text)
#   nord5: #E5E9F0 → WHITE (Default text)
#   nord6: #ECEFF4 → WHITE+BRIGHT (Emphasized text)
#
# Frost (Cool accent colors):
#   nord7: #8FBCBB → CYAN+DIM (Subtle accent)
#   nord8: #88C0D0 → CYAN (Primary accent)
#   nord9: #81A1C1 → BLUE+BRIGHT (Secondary accent)
#   nord10: #5E81AC → BLUE (Tertiary accent)
#
# Aurora (Warm accent colors):
#   nord11: #BF616A → RED (Error/Danger)
#   nord12: #D08770 → RED+BRIGHT (Warning orange)
#   nord13: #EBCB8B → YELLOW (Attention/Highlight)
#   nord14: #A3BE8C → GREEN (Success/Confirmation)
#   nord15: #B48EAD → MAGENTA (Special/Info)
# ═══════════════════════════════════════════════════════════════

# BASE LAYOUT - Pure Nord
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# TITLE & BORDERS - Frost accents
title_color = (WHITE,BLUE,ON)
border_color = (CYAN,BLACK,ON)
border2_color = (BLUE,BLACK,ON)

# BUTTONS - Interactive Frost elements
button_active_color = (BLACK,CYAN,ON)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,WHITE,ON)
button_key_inactive_color = (YELLOW,BLACK,ON)
button_label_active_color = (BLACK,CYAN,ON)
button_label_inactive_color = (WHITE,BLACK,OFF)

# MENU SYSTEM - Clean Nord hierarchy
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,ON)
menubox_border2_color = (BLUE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,CYAN,ON)

# TAG SYSTEM - Aurora yellow for visibility
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)

# INPUT FIELDS - Clean Nord aesthetic
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,ON)
inputbox_border2_color = (BLUE,BLACK,ON)
form_active_text_color = (BLACK,CYAN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (WHITE,BLACK,DIM)

# CHECKBOXES & SELECTION - Aurora green for positive feedback
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)

# PROGRESS & GAUGE - Frost cyan for progress indication
gauge_color = (BLACK,CYAN,ON)

# SEARCH FUNCTION - Integrated Nord look
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (WHITE,BLUE,ON)
searchbox_border_color = (CYAN,BLACK,ON)
searchbox_border2_color = (BLUE,BLACK,ON)

# NAVIGATION - Aurora green for movement/direction
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)

# HELP & SECONDARY ELEMENTS - Subtle Snow Storm
itemhelp_color = (WHITE,BLACK,DIM)

EOF
}

# Apply Nord colors to terminal
apply_nord_terminal_colors() {
    # Only apply if terminal supports 256 colors
    if [ "$(tput colors 2>/dev/null || echo 8)" -ge 256 ]; then
        echo "Applying Nord color scheme to terminal..."
        
        # Set the 16 terminal colors to Nord palette
        # Black/Grey
        echo -ne "\033]4;0;rgb:${NORD1}\007"   # black
        echo -ne "\033]4;8;rgb:${NORD3}\007"   # bright black
        
        # Red
        echo -ne "\033]4;1;rgb:${NORD11}\007"  # red
        echo -ne "\033]4;9;rgb:${NORD11}\007"  # bright red
        
        # Green
        echo -ne "\033]4;2;rgb:${NORD14}\007"  # green
        echo -ne "\033]4;10;rgb:${NORD14}\007" # bright green
        
        # Yellow
        echo -ne "\033]4;3;rgb:${NORD13}\007"  # yellow
        echo -ne "\033]4;11;rgb:${NORD13}\007" # bright yellow
        
        # Blue
        echo -ne "\033]4;4;rgb:${NORD10}\007"  # blue
        echo -ne "\033]4;12;rgb:${NORD9}\007"  # bright blue
        
        # Magenta
        echo -ne "\033]4;5;rgb:${NORD15}\007"  # magenta
        echo -ne "\033]4;13;rgb:${NORD15}\007" # bright magenta
        
        # Cyan
        echo -ne "\033]4;6;rgb:${NORD8}\007"   # cyan
        echo -ne "\033]4;14;rgb:${NORD7}\007"  # bright cyan
        
        # White
        echo -ne "\033]4;7;rgb:${NORD5}\007"   # white
        echo -ne "\033]4;15;rgb:${NORD6}\007"  # bright white
        
        # Set default foreground and background
        echo -ne "\033]10;rgb:${NORD4}\007"    # foreground
        echo -ne "\033]11;rgb:${NORD0}\007"    # background
        echo -ne "\033]12;rgb:${NORD4}\007"    # cursor
        
        echo "✓ Nord colors applied successfully!"
    else
        echo "⚠ Terminal does not support 256 colors. Nord theme may not display correctly."
    fi
}

# Create Nord-themed banner
create_nord_banner() {
    # Using Nord colors for the banner
    local NORD_BLUE="\033[38;2;94;129;172m"      # nord10
    local NORD_CYAN="\033[38;2;136;192;208m"     # nord8
    local NORD_GREEN="\033[38;2;163;190;140m"    # nord14
    local NORD_WHITE="\033[38;2;229;233;240m"    # nord5
    local NORD_YELLOW="\033[38;2;235;203;139m"   # nord13
    local RESET="\033[0m"
    
    cat << EOF
${NORD_BLUE}
 ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗ 
 ██╔════╝╚██╗██╔╝██╔══██╗██╔══██╗██╔════╝ 
 █████╗   ╚███╔╝ ███████║██████╔╝██║  ███╗
 ██╔══╝   ██╔██╗ ██╔══██║██╔═══╝ ██║   ██║
 ███████╗██╔╝ ██╗██║  ██║██║     ╚██████╔╝
 ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ╚═════╝ 
${NORD_CYAN}
 PostgreSQL Analytics Platform ${NORD_WHITE}v3.2.0${RESET}
 ${NORD_GREEN}Nord Dark Theme Enabled${RESET}
 ${NORD_YELLOW}Professional Terminal Experience${RESET}
EOF
}

# Nord-styled status messages
ui_status_nord() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    # Nord color codes
    local NORD_RED="\033[38;2;191;97;106m"       # nord11
    local NORD_GREEN="\033[38;2;163;190;140m"    # nord14
    local NORD_YELLOW="\033[38;2;235;203;139m"   # nord13
    local NORD_CYAN="\033[38;2;136;192;208m"     # nord8
    local NORD_WHITE="\033[38;2;229;233;240m"    # nord5
    local RESET="\033[0m"
    
    case "$level" in
        "info")
            echo -e "${NORD_CYAN}[$timestamp] ℹ  $message${RESET}"
            ;;
        "success")
            echo -e "${NORD_GREEN}[$timestamp] ✓  $message${RESET}"
            ;;
        "warning")
            echo -e "${NORD_YELLOW}[$timestamp] ⚠  $message${RESET}"
            ;;
        "error")
            echo -e "${NORD_RED}[$timestamp] ✗  $message${RESET}"
            ;;
        *)
            echo -e "${NORD_WHITE}[$timestamp] $message${RESET}"
            ;;
    esac
}

# Create Nord-themed prompt
create_nord_prompt() {
    local prompt_file="$HOME/.nord_prompt"
    
    cat << 'EOF' > "$prompt_file"
# Nord-themed bash prompt
export PS1='\[\033[38;2;136;192;208m\]\u\[\033[38;2;229;233;240m\]@\[\033[38;2;163;190;140m\]\h\[\033[38;2;229;233;240m\]:\[\033[38;2;129;161;193m\]\w\[\033[38;2;235;203;139m\]$\[\033[0m\] '

# Nord-themed LS colors
export LS_COLORS='di=38;2;136;192;208:ln=38;2;129;161;193:ex=38;2;163;190;140:*.tar=38;2;235;203;139:*.zip=38;2;235;203;139:*.gz=38;2;235;203;139:*.bz2=38;2;235;203;139:*.xz=38;2;235;203;139'

# Nord-themed grep colors
export GREP_COLORS='ms=38;2;235;203;139:mc=38;2;235;203;139:sl=:cx=:fn=38;2;129;161;193:ln=38;2;163;190;140:bn=38;2;163;190;140:se=38;2;76;86;106'
EOF

    # Add to bashrc if not already present
    if ! grep -q "source.*\.nord_prompt" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Nord theme for ExaPG" >> "$HOME/.bashrc"
        echo "source $prompt_file" >> "$HOME/.bashrc"
        echo "✓ Nord prompt added to ~/.bashrc"
    else
        echo "✓ Nord prompt already configured in ~/.bashrc"
    fi
}

# Create terminal profile configurations
create_terminal_profiles() {
    local profiles_dir="$HOME/.nord-terminal-profiles"
    mkdir -p "$profiles_dir"
    
    # iTerm2 profile
    cat << EOF > "$profiles_dir/nord-iterm2.json"
{
  "name": "Nord ExaPG",
  "background": "#2E3440",
  "foreground": "#D8DEE9",
  "black": "#3B4252",
  "red": "#BF616A",
  "green": "#A3BE8C",
  "yellow": "#EBCB8B",
  "blue": "#81A1C1",
  "purple": "#B48EAD",
  "cyan": "#88C0D0",
  "white": "#E5E9F0",
  "brightBlack": "#4C566A",
  "brightRed": "#BF616A",
  "brightGreen": "#A3BE8C",
  "brightYellow": "#EBCB8B",
  "brightBlue": "#81A1C1",
  "brightPurple": "#B48EAD",
  "brightCyan": "#8FBCBB",
  "brightWhite": "#ECEFF4",
  "cursorColor": "#D8DEE9",
  "selectionBackground": "#434C5E"
}
EOF

    # Windows Terminal profile
    cat << EOF > "$profiles_dir/nord-windows-terminal.json"
{
    "name": "Nord ExaPG",
    "background": "#2E3440",
    "foreground": "#D8DEE9",
    "black": "#3B4252",
    "red": "#BF616A",
    "green": "#A3BE8C",
    "yellow": "#EBCB8B",
    "blue": "#81A1C1",
    "purple": "#B48EAD",
    "cyan": "#88C0D0",
    "white": "#E5E9F0",
    "brightBlack": "#4C566A",
    "brightRed": "#BF616A",
    "brightGreen": "#A3BE8C",
    "brightYellow": "#EBCB8B",
    "brightBlue": "#81A1C1",
    "brightPurple": "#B48EAD",
    "brightCyan": "#8FBCBB",
    "brightWhite": "#ECEFF4",
    "cursorColor": "#D8DEE9",
    "selectionBackground": "#434C5E"
}
EOF

    # Gnome Terminal profile
    cat << EOF > "$profiles_dir/nord-gnome-terminal.sh"
#!/bin/bash
# Nord theme for Gnome Terminal
# Run this script to apply Nord colors to Gnome Terminal

# Create new profile
profile_id=\$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:\$profile_id/ visible-name 'Nord ExaPG'

# Set colors
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:\$profile_id/ use-theme-colors false
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:\$profile_id/ background-color '#2E3440'
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:\$profile_id/ foreground-color '#D8DEE9'

# Set palette
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:\$profile_id/ palette "['#3B4252', '#BF616A', '#A3BE8C', '#EBCB8B', '#81A1C1', '#B48EAD', '#88C0D0', '#E5E9F0', '#4C566A', '#BF616A', '#A3BE8C', '#EBCB8B', '#81A1C1', '#B48EAD', '#8FBCBB', '#ECEFF4']"

echo "Nord theme applied to Gnome Terminal!"
EOF
    chmod +x "$profiles_dir/nord-gnome-terminal.sh"
    
    echo "✓ Terminal profiles created in $profiles_dir"
}

# Main function
main() {
    echo "Nord Terminal Enhancer for ExaPG"
    echo "================================"
    echo
    
    # Show Nord banner
    create_nord_banner
    echo
    
    echo "This script will enhance your terminal with the Nord color scheme."
    echo
    echo "Available options:"
    echo "1) Apply Nord colors to current terminal"
    echo "2) Create Nord-themed bash prompt"
    echo "3) Generate terminal profile configurations"
    echo "4) Apply enhanced Nord theme to ExaPG UI"
    echo "5) All of the above"
    echo "6) Test Nord colors"
    echo
    read -p "Your choice (1-6): " choice
    
    case $choice in
        1)
            apply_nord_terminal_colors
            ;;
        2)
            create_nord_prompt
            ;;
        3)
            create_terminal_profiles
            ;;
        4)
            echo "Enhanced Nord theme for ExaPG UI:"
            generate_enhanced_nord_dark_theme > /tmp/nord_enhanced_theme.dialogrc
            echo "✓ Enhanced theme generated at /tmp/nord_enhanced_theme.dialogrc"
            echo "  This will be automatically used when EXAPG_THEME=nord-dark"
            ;;
        5)
            ui_status_nord "info" "Applying complete Nord terminal experience..."
            apply_nord_terminal_colors
            create_nord_prompt
            create_terminal_profiles
            ui_status_nord "success" "Nord terminal enhancement completed!"
            ;;
        6)
            echo "Testing Nord colors..."
            ui_status_nord "info" "This is an info message"
            ui_status_nord "success" "This is a success message"
            ui_status_nord "warning" "This is a warning message"
            ui_status_nord "error" "This is an error message"
            echo
            echo "Color test completed!"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo
    echo "Nord Terminal Enhancement completed!"
    echo
    echo "Next steps:"
    echo "- Restart your terminal or run 'source ~/.bashrc' for prompt changes"
    echo "- Import terminal profiles if using iTerm2/Windows Terminal"
    echo "- Run './exapg' to experience the enhanced Nord UI"
    echo
    echo "For the best experience, use a monospace font like:"
    echo "- JetBrains Mono"
    echo "- Fira Code"
    echo "- Source Code Pro"
}

# Export functions for use in other scripts
export -f generate_enhanced_nord_dark_theme
export -f apply_nord_terminal_colors
export -f create_nord_banner
export -f ui_status_nord

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi 