#!/bin/bash
# Nord Theme Fix für ExaPG - Echte Nord-Farben!
# Behebt das Problem mit dem grauen Dialog-Theme

set -euo pipefail

# Nord Farbpalette (RGB Hex-Werte)
readonly NORD0="#2E3440"   # Polar Night - darkest
readonly NORD1="#3B4252"   # Polar Night
readonly NORD2="#434C5E"   # Polar Night
readonly NORD3="#4C566A"   # Polar Night - lightest
readonly NORD4="#D8DEE9"   # Snow Storm - darkest
readonly NORD5="#E5E9F0"   # Snow Storm
readonly NORD6="#ECEFF4"   # Snow Storm - lightest
readonly NORD7="#8FBCBB"   # Frost - teal
readonly NORD8="#88C0D0"   # Frost - light blue
readonly NORD9="#81A1C1"   # Frost - blue
readonly NORD10="#5E81AC"  # Frost - dark blue
readonly NORD11="#BF616A"  # Aurora - red
readonly NORD12="#D08770"  # Aurora - orange
readonly NORD13="#EBCB8B"  # Aurora - yellow
readonly NORD14="#A3BE8C"  # Aurora - green
readonly NORD15="#B48EAD"  # Aurora - purple

# Terminal auf Nord-Farben umstellen
apply_nord_terminal_colors() {
    echo "🎨 Applying Nord colors to terminal..."
    
    # Terminal-Hintergrund und -Vordergrund
    printf '\033]11;%s\007' "$NORD0"  # Background
    printf '\033]10;%s\007' "$NORD4"  # Foreground
    printf '\033]12;%s\007' "$NORD8"  # Cursor
    
    # 16-Farben-Palette auf Nord umstellen
    printf '\033]4;0;%s\007' "$NORD1"   # black
    printf '\033]4;1;%s\007' "$NORD11"  # red
    printf '\033]4;2;%s\007' "$NORD14"  # green
    printf '\033]4;3;%s\007' "$NORD13"  # yellow
    printf '\033]4;4;%s\007' "$NORD10"  # blue
    printf '\033]4;5;%s\007' "$NORD15"  # magenta
    printf '\033]4;6;%s\007' "$NORD8"   # cyan
    printf '\033]4;7;%s\007' "$NORD5"   # white
    printf '\033]4;8;%s\007' "$NORD3"   # bright black
    printf '\033]4;9;%s\007' "$NORD12"  # bright red
    printf '\033]4;10;%s\007' "$NORD14" # bright green
    printf '\033]4;11;%s\007' "$NORD13" # bright yellow
    printf '\033]4;12;%s\007' "$NORD9"  # bright blue
    printf '\033]4;13;%s\007' "$NORD15" # bright magenta
    printf '\033]4;14;%s\007' "$NORD7"  # bright cyan
    printf '\033]4;15;%s\007' "$NORD6"  # bright white
    
    echo "✅ Terminal colors updated to Nord palette!"
}

# Funktionierende DIALOGRC erstellen
create_working_nord_dialogrc() {
    local dialogrc_path="${1:-/tmp/exapg_nord_dialogrc_$$}"
    
    echo "🔧 Creating working Nord DIALOGRC at: $dialogrc_path"
    
    cat > "$dialogrc_path" << 'EOF'
# ExaPG Nord Dark Theme - WORKING VERSION
# This will actually show Nord colors!

# CRITICAL: Enable colors
use_colors = ON
use_shadow = ON
separate_widget = ""
tab_len = 0
visit_items = ON

# Base layout - Nord Polar Night background with Snow Storm text
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# Title and borders - Nord Frost (Cyan/Blue accents)
title_color = (CYAN,BLACK,ON)
border_color = (CYAN,BLACK,ON)
border2_color = (BLUE,BLACK,ON)

# Buttons - Interactive Nord Frost elements
button_active_color = (BLACK,CYAN,ON)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,WHITE,ON)
button_key_inactive_color = (YELLOW,BLACK,ON)
button_label_active_color = (BLACK,CYAN,ON)
button_label_inactive_color = (WHITE,BLACK,OFF)

# Menu system - Clean Nord hierarchy
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,ON)
menubox_border2_color = (BLUE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,CYAN,ON)

# Tags - Aurora yellow for visibility
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)

# Input fields - Clean Nord aesthetic
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,ON)
inputbox_border2_color = (BLUE,BLACK,ON)
form_active_text_color = (BLACK,CYAN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (WHITE,BLACK,DIM)

# Checkboxes - Aurora green for positive feedback
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)

# Progress bars - Frost cyan
gauge_color = (BLACK,CYAN,ON)

# Search function
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (CYAN,BLACK,ON)
searchbox_border_color = (CYAN,BLACK,ON)
searchbox_border2_color = (BLUE,BLACK,ON)

# Navigation - Aurora green
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)

# Help text
itemhelp_color = (WHITE,BLACK,DIM)

# Calendar (if used)
week_number_color = (YELLOW,BLACK,ON)
weekday_color = (CYAN,BLACK,ON)
day_color = (WHITE,BLACK,OFF)
day_selected_color = (BLACK,CYAN,ON)
month_color = (YELLOW,BLACK,ON)
year_color = (YELLOW,BLACK,ON)

# Text viewer
textbox_color = (WHITE,BLACK,OFF)
textbox_border_color = (CYAN,BLACK,ON)
textbox_border2_color = (BLUE,BLACK,ON)
EOF
    
    echo "✅ Nord DIALOGRC created successfully!"
    echo "$dialogrc_path"
}

# Test Dialog mit Nord-Farben
test_nord_dialog() {
    local dialogrc_path="$1"
    
    echo "🧪 Testing Nord Dialog..."
    
    export DIALOGRC="$dialogrc_path"
    export DIALOGOPTS="--colors --no-shadow"
    
    dialog --colors \
           --backtitle "ExaPG Nord Theme Test" \
           --title "\Z6[\Zb Nord Dark Theme Active \Zn\Z6]\Zn" \
           --msgbox "\n\Z6This should now show proper Nord colors:\Zn\n\n\Z2✓\Zn \Z7Green for success (Aurora)\Zn\n\Z1✗\Zn \Z7Red for errors (Aurora)\Zn\n\Z3★\Zn \Z7Yellow highlights (Aurora)\Zn\n\Z4●\Zn \Z7Blue accents (Frost)\Zn\n\Z6◆\Zn \Z7Cyan elements (Frost)\Zn\n\n\Z7Background should be dark Nord blue!\Zn" 16 50
    
    clear
}

# Alternative: Whiptail mit Nord-Farben
setup_whiptail_nord() {
    echo "🔄 Setting up Whiptail with Nord colors..."
    
    export NEWT_COLORS='
root=white,black
window=white,black
border=cyan,black
shadow=black,black
title=cyan,black
button=black,cyan
actbutton=white,blue
checkbox=white,black
actcheckbox=black,green
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,cyan
textbox=white,black
acttextbox=black,cyan
helpline=white,black
roottext=white,black
emptyscale=black,black
fullscale=cyan,black
disentry=white,black
compactbutton=white,black
actsellistbox=black,cyan
sellistbox=white,black
'
    
    echo "✅ Whiptail Nord colors configured!"
}

# Test Whiptail
test_whiptail_nord() {
    setup_whiptail_nord
    
    whiptail --title "ExaPG Nord Theme Test" \
             --msgbox "This is Whiptail with Nord colors!\n\nShould show:\n• Cyan borders and highlights\n• Dark background\n• Proper contrast\n\nMuch better than gray dialog!" 12 50
}

# ExaPG mit korrektem Nord-Theme starten
start_exapg_with_nord() {
    echo "🚀 Starting ExaPG with proper Nord theme..."
    
    # Terminal vorbereiten
    apply_nord_terminal_colors
    
    # DIALOGRC erstellen und setzen
    local dialogrc_path
    dialogrc_path=$(create_working_nord_dialogrc)
    export DIALOGRC="$dialogrc_path"
    
    # Dialog-Optionen setzen
    export DIALOGOPTS="--colors --no-shadow"
    export DIALOG_EXTRA_ARGS="--colors"
    
    # Theme explizit setzen
    export EXAPG_THEME="nord-dark"
    
    # Zusätzliche Umgebungsvariablen
    export NCURSES_NO_UTF8_ACS=1
    
    echo "✅ Nord theme setup complete!"
    echo "================================"
    echo "Terminal: $TERM"
    echo "DIALOGRC: $DIALOGRC"
    echo "Theme: $EXAPG_THEME"
    echo "Colors: $(tput colors)"
    echo
    
    # ExaPG starten
    echo "Starting ExaPG with Nord theme in 2 seconds..."
    sleep 2
    ./scripts/cli/terminal-ui.sh
}

# Installiere bessere Dialog-Alternative
install_cdialog() {
    echo "📦 Installing cdialog (better color support)..."
    
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y cdialog
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y cdialog
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y cdialog
    else
        echo "❌ Package manager not found. Please install cdialog manually."
        return 1
    fi
    
    echo "✅ cdialog installed! You can now use 'cdialog' instead of 'dialog'"
}

# Debug aktuelles Setup
debug_current_setup() {
    echo "🔍 Current Dialog Setup Debug"
    echo "============================="
    echo "TERM: $TERM"
    echo "Colors: $(tput colors)"
    echo "DIALOGRC: ${DIALOGRC:-not set}"
    echo "DIALOGOPTS: ${DIALOGOPTS:-not set}"
    echo "EXAPG_THEME: ${EXAPG_THEME:-not set}"
    echo
    
    echo "Dialog version:"
    dialog --version 2>&1 | head -1
    echo
    
    echo "Dialog color support:"
    if dialog --help 2>&1 | grep -q "colors"; then
        echo "✅ Dialog supports --colors option"
    else
        echo "❌ Dialog does NOT support --colors option"
    fi
    echo
    
    echo "Available dialog alternatives:"
    command -v whiptail >/dev/null && echo "✅ whiptail available" || echo "❌ whiptail not found"
    command -v cdialog >/dev/null && echo "✅ cdialog available" || echo "❌ cdialog not found"
    echo
    
    if [ -n "${DIALOGRC:-}" ] && [ -f "$DIALOGRC" ]; then
        echo "DIALOGRC file contents (first 10 lines):"
        head -10 "$DIALOGRC"
    else
        echo "❌ No DIALOGRC file found"
    fi
}

# Hauptmenü mit Nord-Farben
show_main_menu() {
    clear
    
    # Nord-farbiges Banner
    echo -e "\033[38;2;136;192;208m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;235;203;139m🎨 Nord Theme Fix für ExaPG\033[0m                           \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;229;233;240mBehebt das graue Dialog-Problem!\033[0m                      \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo
    echo -e "\033[38;2;163;190;140m1)\033[0m \033[38;2;229;233;240mQuick Test - Teste Nord Dialog sofort\033[0m"
    echo -e "\033[38;2;163;190;140m2)\033[0m \033[38;2;229;233;240mStart ExaPG with working Nord Theme\033[0m"
    echo -e "\033[38;2;163;190;140m3)\033[0m \033[38;2;229;233;240mTest Whiptail alternative (often better)\033[0m"
    echo -e "\033[38;2;163;190;140m4)\033[0m \033[38;2;229;233;240mInstall cdialog (enhanced dialog)\033[0m"
    echo -e "\033[38;2;163;190;140m5)\033[0m \033[38;2;229;233;240mApply Nord colors to terminal only\033[0m"
    echo -e "\033[38;2;163;190;140m6)\033[0m \033[38;2;229;233;240mDebug current setup\033[0m"
    echo -e "\033[38;2;163;190;140m7)\033[0m \033[38;2;235;203;139mFull Nord fix (recommended)\033[0m"
    echo -e "\033[38;2;191;97;106m0)\033[0m \033[38;2;229;233;240mExit\033[0m"
    echo
}

# Hauptprogramm
main() {
    while true; do
        show_main_menu
        read -p "$(echo -e '\033[38;2;136;192;208mWähle Option (0-7):\033[0m ') " choice
        echo
        
        case $choice in
            1)
                apply_nord_terminal_colors
                dialogrc_path=$(create_working_nord_dialogrc)
                test_nord_dialog "$dialogrc_path"
                ;;
            2)
                start_exapg_with_nord
                ;;
            3)
                apply_nord_terminal_colors
                test_whiptail_nord
                ;;
            4)
                install_cdialog
                ;;
            5)
                apply_nord_terminal_colors
                echo "✅ Terminal colors updated to Nord!"
                ;;
            6)
                debug_current_setup
                ;;
            7)
                echo "🔧 Applying full Nord fix..."
                apply_nord_terminal_colors
                dialogrc_path=$(create_working_nord_dialogrc)
                test_nord_dialog "$dialogrc_path"
                echo
                echo "✅ Full fix applied! Now starting ExaPG..."
                sleep 2
                start_exapg_with_nord
                ;;
            0)
                echo -e "\033[38;2;163;190;140m✅ Auf Wiedersehen!\033[0m"
                exit 0
                ;;
            *)
                echo -e "\033[38;2;191;97;106m❌ Ungültige Option. Bitte wählen Sie 0-7.\033[0m"
                ;;
        esac
        
        if [ "$choice" != "2" ] && [ "$choice" != "7" ]; then
            echo
            read -p "$(echo -e '\033[38;2;136;192;208mDrücken Sie Enter um fortzufahren...\033[0m')"
        fi
    done
}

# Script direkt ausführen
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi 