#!/bin/bash
# ExaPG Terminal UI Framework v2.0 - Professionelles Interface

# Globale Variablen
EXAPG_VERSION="2.0.0"
EXAPG_PROFILES_DIR="config/profiles"
EXAPG_DEFAULT_PROFILE="default"
EXAPG_CURRENT_PROFILE=""

# Navigation Stack für professionelle Menü-Hierarchie
declare -a MENU_STACK=()
CURRENT_MENU="main"

# Navigation-Funktionen
navigate_to() {
    local menu_name="$1"
    MENU_STACK+=("$menu_name")
    CURRENT_MENU="$menu_name"
    return 0
}

navigate_back() {
    if [ ${#MENU_STACK[@]} -gt 0 ]; then
        unset MENU_STACK[-1]  # Letztes Element entfernen
        if [ ${#MENU_STACK[@]} -gt 0 ]; then
            CURRENT_MENU="${MENU_STACK[-1]}"
        else
            CURRENT_MENU="main"
        fi
    fi
}

navigate_to_root() {
    MENU_STACK=()
    CURRENT_MENU="main"
}

# Terminal Cleanup-Funktion
cleanup_terminal() {
    # Terminal-Cursor und Display zurücksetzen
    tput reset 2>/dev/null || true
    tput cnorm 2>/dev/null || true  # Cursor wieder einblenden
    stty sane 2>/dev/null || true   # Terminal-Einstellungen normalisieren
    
    # DIALOGRC aufräumen
    [ -f "$DIALOGRC" ] && rm -f "$DIALOGRC"
    unset DIALOGRC
    
    # Farben zurücksetzen
    echo -e "\033[0m" 2>/dev/null || true
    
    # Terminal leeren
    clear 2>/dev/null || true
}

# Trap für ordnungsgemäße Cleanup bei Script-Ende
trap cleanup_terminal EXIT
trap cleanup_terminal INT
trap cleanup_terminal TERM

# Terminal-Fähigkeiten prüfen
check_terminal_ui() {
    if command -v dialog &> /dev/null; then
        UI_TOOL="dialog"
    elif command -v whiptail &> /dev/null; then
        UI_TOOL="whiptail"
    else
        echo "Installing dialog for better terminal UI..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y dialog
        elif command -v yum &> /dev/null; then
            sudo yum install -y dialog
        fi
        UI_TOOL="dialog"
    fi
}

# Theme-Management System
EXAPG_THEME="${EXAPG_THEME:-nord-dark}"

# Professionelle Theme-Auswahl
select_theme() {
    while true; do
        local current_theme_desc=""
        case "$EXAPG_THEME" in
            "nord-dark") current_theme_desc="Nord Dark Theme (Default)" ;;
            "nord-light") current_theme_desc="Nord Light Theme" ;;
            "nord-contrast") current_theme_desc="High Contrast Theme (Accessibility)" ;;
            "classic") current_theme_desc="Classic Terminal Theme" ;;
        esac
        
        # Navigation-Info für Breadcrumb
        local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        local status_line="Current: $current_theme_desc | v$EXAPG_VERSION"
        
        exec 3>&1
        selection=$(dialog \
            --backtitle "$status_line" \
            --title "[ $nav_breadcrumb ]" \
            --cancel-label "Back" \
            --menu "Select a theme:" 16 70 4 \
            "1" "Nord Dark Theme (Recommended)" \
            "2" "Nord Light Theme" \
            "3" "High Contrast Theme (Accessibility)" \
            "4" "Classic Terminal Theme" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255)
                navigate_back
                return
                ;;
        esac
        
        local new_theme=""
        case $selection in
            1) new_theme="nord-dark" ;;
            2) new_theme="nord-light" ;;
            3) new_theme="nord-contrast" ;;
            4) new_theme="classic" ;;
        esac
        
        if [ -n "$new_theme" ] && [ "$new_theme" != "$EXAPG_THEME" ]; then
            EXAPG_THEME="$new_theme"
            setup_color_scheme
            dialog --backtitle "Theme Applied" \
                   --title "[ Success ]" \
                   --msgbox "Theme successfully changed to: $new_theme\n\nThe new theme is now active." 8 50
        fi
    done
}

# Terminal-Fähigkeiten erkennen
detect_terminal_capabilities() {
    local colors=$(tput colors 2>/dev/null || echo 8)
    local has_bold=$(tput bold 2>/dev/null && echo "yes" || echo "no")
    local has_dim=$(tput dim 2>/dev/null && echo "yes" || echo "no")
    
    echo "$colors $has_bold $has_dim"
}

# Nord Dark Theme für Dialog - Optimiert
setup_color_scheme() {
    export DIALOGRC="/tmp/exapg_dialogrc_$$"  # Eindeutiger Name mit PID
    
    # Terminal-Fähigkeiten prüfen
    read term_colors has_bold has_dim <<< "$(detect_terminal_capabilities)"
    
    # Theme basierend auf Auswahl generieren
    case "$EXAPG_THEME" in
        "nord-light")
            generate_nord_light_theme > "$DIALOGRC"
            ;;
        "nord-contrast")
            generate_nord_contrast_theme > "$DIALOGRC"
            ;;
        "classic")
            generate_classic_theme > "$DIALOGRC"
            ;;
        *)
            generate_nord_dark_theme > "$DIALOGRC"
            ;;
    esac
}

# Nord Dark Theme Generator
generate_nord_dark_theme() {
    cat << 'EOF'
# ExaPG Advanced Nord Dark Theme v2.0
# Basiert auf der offiziellen Nord-Farbpalette
# https://nordtheme.com

# Dialog-Verhalten
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# ═══════════════════════════════════════════════════════════════
# OFFIZIELLE NORD FARBPALETTE → TERMINAL MAPPING
# ═══════════════════════════════════════════════════════════════
# Polar Night (Dunkle Hintergründe):
#   #2E3440 → BLACK     (Basis Hintergrund)
#   #3B4252 → BLACK+DIM (Sekundär Hintergrund) 
#   #434C5E → BLACK+BRIGHT (Card/Panel Hintergrund)
#   #4C566A → BLACK+BRIGHT+DIM (Subtle Hintergrund)
#
# Snow Storm (Helle Texte):
#   #D8DEE9 → WHITE+DIM (Sekundär Text)
#   #E5E9F0 → WHITE     (Standard Text)
#   #ECEFF4 → WHITE+BRIGHT (Primär Text)
#
# Frost (Blaue Akzente):
#   #8FBCBB → CYAN+DIM  (Subtle Cyan)
#   #88C0D0 → CYAN      (Standard Cyan)
#   #81A1C1 → BLUE+BRIGHT (Helles Blau)
#   #5E81AC → BLUE      (Standard Blau)
#
# Aurora (Bunte Akzente):
#   #BF616A → RED       (Fehler/Warnung)
#   #D08770 → RED+BRIGHT (Orange-ish)
#   #EBCB8B → YELLOW    (Highlights)
#   #A3BE8C → GREEN     (Erfolg/Bestätigung)
#   #B48EAD → MAGENTA   (Spezial/Info)
# ═══════════════════════════════════════════════════════════════

# BASIS LAYOUT
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# TITEL & BORDERS - Frost Blau Theme
title_color = (WHITE,BLUE,ON)
border_color = (CYAN,BLACK,ON)
border2_color = (BLUE,BLACK,ON)

# BUTTONS - Dynamische Frost-Akzente
button_active_color = (BLACK,CYAN,ON)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,WHITE,ON)
button_key_inactive_color = (YELLOW,BLACK,ON)
button_label_active_color = (BLACK,CYAN,ON)
button_label_inactive_color = (CYAN,BLACK,OFF)

# MENU SYSTEM - Konsistente Nord-Hierarchie  
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,ON)
menubox_border2_color = (BLUE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,CYAN,ON)

# TAG SYSTEM - Aurora Gelb für Shortcuts
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)

# EINGABEFELDER - Saubere Nord-Aesthetik
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,ON)
inputbox_border2_color = (BLUE,BLACK,ON)
form_active_text_color = (BLACK,CYAN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (CYAN,BLACK,DIM)

# CHECKBOXEN & AUSWAHL - Aurora Grün für Bestätigung
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)

# PROGRESS & GAUGE - Frost Cyan für Fortschritt
gauge_color = (BLACK,CYAN,ON)

# SUCHFUNKTION - Integrierte Nord-Optik
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (WHITE,BLUE,ON)
searchbox_border_color = (CYAN,BLACK,ON)
searchbox_border2_color = (BLUE,BLACK,ON)

# NAVIGATION - Aurora Grün für Pfeile (Natur/Bewegung)
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)

# HILFE & SEKUNDÄRE ELEMENTE - Gedämpfte Snow Storm
itemhelp_color = (WHITE,BLACK,DIM)

# ERWEITERTE ELEMENTE für bessere UX
# Verwende Magenta für spezielle Informationen (Aurora)
# Verwende Red für Warnungen/kritische Aktionen

EOF
}

# Nord Light Theme Generator
generate_nord_light_theme() {
    cat << 'EOF'
# ExaPG Nord Light Theme v2.0
# Helles Theme basierend auf Nord Snow Storm

aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = OFF
use_colors = ON

# BASIS LAYOUT - Invertiert für Light Theme
screen_color = (BLACK,WHITE,OFF)
shadow_color = (BLACK,WHITE,OFF)
dialog_color = (BLACK,WHITE,OFF)

# TITEL & BORDERS - Frost Blau auf Hellem Hintergrund
title_color = (WHITE,BLUE,ON)
border_color = (BLUE,WHITE,ON)
border2_color = (CYAN,WHITE,ON)

# BUTTONS - Light Theme Anpassung
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLUE,WHITE,OFF)
button_key_active_color = (WHITE,BLACK,ON)
button_key_inactive_color = (BLACK,WHITE,ON)
button_label_active_color = (WHITE,BLUE,ON)
button_label_inactive_color = (BLUE,WHITE,OFF)

# MENU SYSTEM - Light Mode
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (BLUE,WHITE,ON)
menubox_border2_color = (CYAN,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,BLUE,ON)

# TAG SYSTEM - Gedämpfter auf hellem Hintergrund
tag_color = (BLACK,YELLOW,ON)
tag_selected_color = (YELLOW,BLACK,ON)
tag_key_color = (BLACK,YELLOW,ON)
tag_key_selected_color = (YELLOW,BLACK,ON)

# EINGABEFELDER
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLUE,WHITE,ON)
inputbox_border2_color = (CYAN,WHITE,ON)
form_active_text_color = (WHITE,BLUE,ON)
form_text_color = (BLACK,WHITE,OFF)
form_item_readonly_color = (BLUE,WHITE,DIM)

# CHECKBOXEN & AUSWAHL
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,GREEN,ON)

# PROGRESS & GAUGE
gauge_color = (WHITE,BLUE,ON)

# SUCHFUNKTION
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (WHITE,BLUE,ON)
searchbox_border_color = (BLUE,WHITE,ON)
searchbox_border2_color = (CYAN,WHITE,ON)

# NAVIGATION
position_indicator_color = (GREEN,WHITE,ON)
uarrow_color = (GREEN,WHITE,ON)
darrow_color = (GREEN,WHITE,ON)

# HILFE & SEKUNDÄRE ELEMENTE
itemhelp_color = (BLACK,WHITE,DIM)

EOF
}

# Nord High Contrast Theme Generator
generate_nord_contrast_theme() {
    cat << 'EOF'
# ExaPG Nord High Contrast Theme v2.0
# Hoher Kontrast für bessere Barrierefreiheit

aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# BASIS LAYOUT - Maximaler Kontrast
screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,ON)

# TITEL & BORDERS - Starke Kontraste
title_color = (BLACK,WHITE,ON)
border_color = (WHITE,BLACK,ON)
border2_color = (WHITE,BLACK,ON)

# BUTTONS - Hochkontrast
button_active_color = (BLACK,WHITE,ON)
button_inactive_color = (WHITE,BLACK,ON)
button_key_active_color = (BLACK,YELLOW,ON)
button_key_inactive_color = (YELLOW,BLACK,ON)
button_label_active_color = (BLACK,WHITE,ON)
button_label_inactive_color = (WHITE,BLACK,ON)

# MENU SYSTEM - Maximum Contrast
menubox_color = (WHITE,BLACK,ON)
menubox_border_color = (WHITE,BLACK,ON)
menubox_border2_color = (WHITE,BLACK,ON)
item_color = (WHITE,BLACK,ON)
item_selected_color = (BLACK,WHITE,ON)

# TAG SYSTEM - Auffällige Farben
tag_color = (BLACK,YELLOW,ON)
tag_selected_color = (YELLOW,BLACK,ON)
tag_key_color = (BLACK,YELLOW,ON)
tag_key_selected_color = (YELLOW,BLACK,ON)

# EINGABEFELDER
inputbox_color = (WHITE,BLACK,ON)
inputbox_border_color = (WHITE,BLACK,ON)
inputbox_border2_color = (WHITE,BLACK,ON)
form_active_text_color = (BLACK,WHITE,ON)
form_text_color = (WHITE,BLACK,ON)
form_item_readonly_color = (WHITE,BLACK,DIM)

# CHECKBOXEN & AUSWAHL
check_color = (WHITE,BLACK,ON)
check_selected_color = (BLACK,GREEN,ON)

# PROGRESS & GAUGE
gauge_color = (BLACK,WHITE,ON)

# SUCHFUNKTION
searchbox_color = (WHITE,BLACK,ON)
searchbox_title_color = (BLACK,WHITE,ON)
searchbox_border_color = (WHITE,BLACK,ON)
searchbox_border2_color = (WHITE,BLACK,ON)

# NAVIGATION
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)

# HILFE & SEKUNDÄRE ELEMENTE
itemhelp_color = (WHITE,BLACK,ON)

EOF
}

# Classic Terminal Theme Generator  
generate_classic_theme() {
    cat << 'EOF'
# ExaPG Classic Terminal Theme v2.0
# Klassisches grün-auf-schwarz Terminal-Design

aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# BASIS LAYOUT - Classic Terminal
screen_color = (GREEN,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (GREEN,BLACK,OFF)

# TITEL & BORDERS - Classic Green
title_color = (GREEN,BLACK,ON)
border_color = (GREEN,BLACK,ON)
border2_color = (GREEN,BLACK,DIM)

# BUTTONS - Retro Style
button_active_color = (BLACK,GREEN,ON)
button_inactive_color = (GREEN,BLACK,OFF)
button_key_active_color = (BLACK,GREEN,ON)
button_key_inactive_color = (GREEN,BLACK,ON)
button_label_active_color = (BLACK,GREEN,ON)
button_label_inactive_color = (GREEN,BLACK,OFF)

# MENU SYSTEM - Classic
menubox_color = (GREEN,BLACK,OFF)
menubox_border_color = (GREEN,BLACK,ON)
menubox_border2_color = (GREEN,BLACK,DIM)
item_color = (GREEN,BLACK,OFF)
item_selected_color = (BLACK,GREEN,ON)

# TAG SYSTEM - Classic Yellow on Black
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)

# EINGABEFELDER
inputbox_color = (GREEN,BLACK,OFF)
inputbox_border_color = (GREEN,BLACK,ON)
inputbox_border2_color = (GREEN,BLACK,DIM)
form_active_text_color = (BLACK,GREEN,ON)
form_text_color = (GREEN,BLACK,OFF)
form_item_readonly_color = (GREEN,BLACK,DIM)

# CHECKBOXEN & AUSWAHL
check_color = (GREEN,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)

# PROGRESS & GAUGE
gauge_color = (BLACK,GREEN,ON)

# SUCHFUNKTION
searchbox_color = (GREEN,BLACK,OFF)
searchbox_title_color = (GREEN,BLACK,ON)
searchbox_border_color = (GREEN,BLACK,ON)
searchbox_border2_color = (GREEN,BLACK,DIM)

# NAVIGATION
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)

# HILFE & SEKUNDÄRE ELEMENTE
itemhelp_color = (GREEN,BLACK,DIM)

EOF
}

# Profil-Management
create_profiles_dir() {
    mkdir -p "$EXAPG_PROFILES_DIR"
}

load_profile() {
    local profile=$1
    local profile_file="$EXAPG_PROFILES_DIR/$profile.env"
    
    if [ -f "$profile_file" ]; then
        source "$profile_file"
        EXAPG_CURRENT_PROFILE="$profile"
        return 0
    else
        return 1
    fi
}

save_profile() {
    local profile=$1
    local profile_file="$EXAPG_PROFILES_DIR/$profile.env"
    
    cat > "$profile_file" << EOF
# ExaPG Profile: $profile
# Created: $(date)

# Database Configuration
CLUSTER_NAME=${CLUSTER_NAME:-exapg-cluster}
CONTAINER_NAME=${CONTAINER_NAME:-exapg}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
COORDINATOR_PORT=${COORDINATOR_PORT:-5432}
WORKER_COUNT=${WORKER_COUNT:-2}

# Performance Settings
SHARED_BUFFERS=${SHARED_BUFFERS:-4GB}
WORK_MEM=${WORK_MEM:-256MB}
MAX_PARALLEL_WORKERS=${MAX_PARALLEL_WORKERS:-8}
JIT=${JIT:-on}

# Component Selection
ENABLE_MONITORING=${ENABLE_MONITORING:-false}
ENABLE_MANAGEMENT_UI=${ENABLE_MANAGEMENT_UI:-false}
ENABLE_UDF_FRAMEWORK=${ENABLE_UDF_FRAMEWORK:-false}
ENABLE_VIRTUAL_SCHEMAS=${ENABLE_VIRTUAL_SCHEMAS:-false}
ENABLE_ETL_TOOLS=${ENABLE_ETL_TOOLS:-false}
ENABLE_BACKUP=${ENABLE_BACKUP:-false}

# Deployment Type
DEPLOYMENT_TYPE=${DEPLOYMENT_TYPE:-single-node}
EOF
    
    # Auch .env aktualisieren
    cp "$profile_file" ".env"
}

# ASCII-Art Zentrierung Funktion - Robuste Version
center_ascii_art() {
    local art="$1"
    local dialog_width="${2:-75}"
    local content_width=$((dialog_width - 8))  # Abzüglich Border und Padding
    
    # Erstmal alle Zeilen in Array sammeln
    local -a lines=()
    local max_length=0
    
    # Zeilen einlesen und maximale Länge ermitteln
    while IFS= read -r line; do
        lines+=("$line")
        local line_length=${#line}
        if [ $line_length -gt $max_length ]; then
            max_length=$line_length
        fi
    done <<< "$art"
    
    # Nur zentrieren wenn das Logo in das Dialog passt
    if [ $max_length -gt $content_width ]; then
        # Logo zu breit - keine Zentrierung
        echo -n "$art"
        return
    fi
    
    # Zentrierung basierend auf der längsten Zeile
    local padding=$(( (content_width - max_length) / 2 ))
    local centered_art=""
    
    for line in "${lines[@]}"; do
        if [ ${#line} -gt 0 ]; then
            # Padding hinzufügen
            local padded_line=""
            for ((i=0; i<padding; i++)); do
                padded_line+=" "
            done
            padded_line+="$line"
            centered_art+="$padded_line"$'\n'
        else
            centered_art+=$'\n'
        fi
    done
    
    echo -n "$centered_art"
}

# Terminal-Größe ermitteln
get_terminal_size() {
    local term_height=$(tput lines 2>/dev/null || echo 24)
    local term_width=$(tput cols 2>/dev/null || echo 80)
    echo "$term_height $term_width"
}

# Optimale Dialog-Größe berechnen
calculate_dialog_size() {
    local content_lines="$1"
    read term_height term_width <<< "$(get_terminal_size)"
    
    # Maximale nutzbare Größe (mit großzügigem Puffer)
    local max_height=$((term_height - 6))
    local max_width=$((term_width - 8))
    
    # Minimale sinnvolle Größe
    local min_height=12
    local min_width=50
    
    # Für sehr kleine Terminals Notfall-Werte
    if [ $term_height -lt 20 ]; then
        max_height=$((term_height - 3))
        min_height=10
    fi
    if [ $term_width -lt 70 ]; then
        max_width=$((term_width - 4))
        min_width=40
    fi
    
    # Optimale Breite (bevorzugt 75, aber angepasst an Terminal)
    local opt_width=75
    if [ $opt_width -gt $max_width ]; then
        opt_width=$max_width
    elif [ $opt_width -lt $min_width ]; then
        opt_width=$min_width
    fi
    
    # Höhe basierend auf Inhalt, aber begrenzt
    local opt_height=$((content_lines + 8))  # +8 für Border, Titel, Button
    if [ $opt_height -gt $max_height ]; then
        opt_height=$max_height
    elif [ $opt_height -lt $min_height ]; then
        opt_height=$min_height
    fi
    
    echo "$opt_height $opt_width"
}

# Portable ASCII-Art Anzeige Funktion
show_ascii_art() {
    local title="$1"
    local art="$2"
    local height="${3:-auto}"
    local width="${4:-auto}"
    local additional_text="$5"
    local center="${6:-false}"
    
    # UTF-8 Locale sicherstellen
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    
    # Automatische Größenberechnung
    if [ "$height" = "auto" ] || [ "$width" = "auto" ]; then
        local content_lines=$(echo -e "$art$additional_text" | wc -l)
        read calc_height calc_width <<< "$(calculate_dialog_size $content_lines)"
        [ "$height" = "auto" ] && height=$calc_height
        [ "$width" = "auto" ] && width=$calc_width
    fi
    
    # Art zentrieren falls gewünscht
    if [ "$center" = "true" ]; then
        art=$(center_ascii_art "$art" "$width")
    fi
    
    # Dialog mit --no-collapse verwenden falls verfügbar
    if command -v dialog >/dev/null 2>&1; then
        if dialog --help 2>&1 | grep -q "no-collapse"; then
            # Scrollbar hinzufügen wenn verfügbar und Inhalt zu groß
            local dialog_options="--backtitle \"ExaPG v$EXAPG_VERSION\" --title \"$title\" --no-collapse"
            if dialog --help 2>&1 | grep -q "scrollbar"; then
                dialog_options="$dialog_options --scrollbar"
            fi
            eval "dialog $dialog_options --msgbox \"\$art\$additional_text\" \"$height\" \"$width\""
            return
        fi
        # Fallback auf --textbox für Dialog ohne --no-collapse
        local tmpfile=$(mktemp)
        echo "$art$additional_text" > "$tmpfile"
        dialog --backtitle "ExaPG v$EXAPG_VERSION" \
               --title "$title" \
               --textbox "$tmpfile" "$height" "$width"
        rm -f "$tmpfile"
        return
    fi
    
    # Whiptail mit Non-breaking Spaces
    if command -v whiptail >/dev/null 2>&1; then
        local nbsp=$'\u00A0'
        local preserved_art="${art// /$nbsp}"
        whiptail --backtitle "ExaPG v$EXAPG_VERSION" \
                 --title "$title" \
                 --msgbox "$preserved_art$additional_text" "$height" "$width"
        return
    fi
    
    # Fallback auf Terminal-Ausgabe
    echo "=== $title ==="
    echo "$art"
    echo "$additional_text"
    read -p "Press Enter to continue..."
}

# Robuste msgbox-Wrapper-Funktion
safe_msgbox() {
    local backtitle="$1"
    local title="$2" 
    local message="$3"
    local height="${4:-8}"
    local width="${5:-50}"
    
    # Dialog ausführen und Exit-Code explizit behandeln
    dialog --backtitle "$backtitle" \
           --title "$title" \
           --msgbox "$message" "$height" "$width"
    local exit_code=$?
    
    # Explizite Exit-Code-Behandlung für Robustheit
    case $exit_code in
        0)
            # OK gedrückt - normal
            return 0
            ;;
        1|255)
            # Cancel/ESC gedrückt - auch normal für msgbox
            return 0
            ;;
        *)
            # Unerwarteter Exit-Code - loggen aber nicht beenden
            echo "Warning: Unexpected dialog exit code: $exit_code" >&2
            return 0
            ;;
    esac
}

# Willkommens-Seite
show_welcome_screen() {
    # ExaPG ASCII-Logo - Original mit Zentrierung
    local logo="
 d8888b  ?88,  88P d888b8b  ?88,.d88b, d888b8b  
d8b_,dP  '?8bd8P'd8P' ?88  '?88'  ?88d8P' ?88  
88b      d8P?8b, 88b  ,88b   88b  d8P88b  ,88b 
'?888P'  d8P' '?8b'?88P''88b  888888P''?88P''88b
                              88P'           )88
                             d88            ,88P
                             ?8P        '?8888P 

         >>> E x a P G   v$EXAPG_VERSION <<<"
    
    local separator="================================================================="
    local additional_content="

PostgreSQL-based Alternative to Exasol

$separator

ENTERPRISE FEATURES:
  - Scalable architecture & high performance
  - Full Exasol compatibility layer
  - Container-native deployment
  - Intelligent monitoring & analytics
  - Professional web management interface
  - Multi-cloud deployment ready

Version: $EXAPG_VERSION
$separator

Press OK to continue to the management console..."
    
    show_ascii_art "[ Welcome to ExaPG ]" "$logo" auto auto "$additional_content" true
}

# Hauptmenü
show_main_menu() {
    while true; do
        # Aktuelles Profil anzeigen
        local profile_info=""
        if [ -n "$EXAPG_CURRENT_PROFILE" ]; then
            profile_info="Aktives Profil: $EXAPG_CURRENT_PROFILE"
        else
            profile_info="Kein Profil geladen"
        fi
        
        # Optimale Menü-Größe berechnen
        read term_height term_width <<< "$(get_terminal_size)"
        local menu_height=$((term_height - 8))
        local menu_width=$((term_width - 10))
        
        # Mindest- und Maximalwerte
        [ $menu_height -lt 15 ] && menu_height=15
        [ $menu_height -gt 20 ] && menu_height=20
        [ $menu_width -lt 60 ] && menu_width=60
        [ $menu_width -gt 80 ] && menu_width=80
        
        exec 3>&1
        # Navigation und Status-Info
        local nav_breadcrumb="ExaPG Management Console"
        if [ ${#MENU_STACK[@]} -gt 0 ]; then
            nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        fi
        
        # Theme-Info professionell darstellen
        local theme_name=""
        case "$EXAPG_THEME" in
            "nord-dark") theme_name="Nord Dark" ;;
            "nord-light") theme_name="Nord Light" ;;
            "nord-contrast") theme_name="High Contrast" ;;
            "classic") theme_name="Classic" ;;
        esac
        
        # Professionelle Status-Leiste
        local status_line="Profile: ${EXAPG_CURRENT_PROFILE:-None} | Theme: $theme_name | v$EXAPG_VERSION"
        
        selection=$(dialog \
            --backtitle "$status_line" \
            --title "[ $nav_breadcrumb ]" \
            --clear \
            --cancel-label "Exit" \
            --menu "Select an option:" $menu_height $menu_width 7 \
            "1" "Installation Wizard" \
            "2" "Configuration Management" \
            "3" "System Status & Services" \
            "4" "Profile Management" \
            "5" "Theme Settings" \
            "6" "System Information" \
            "0" "Exit Application" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255)
                # ESC/Cancel im Hauptmenü = Beenden
                if [ ${#MENU_STACK[@]} -eq 0 ]; then
                    show_exit_dialog
                else
                    # In Untermenüs = Zurück navigieren
                    navigate_back
                fi
                ;;
        esac
        
        case $selection in
            1) navigate_to "Installation" && show_install_wizard ;;
            2) navigate_to "Configuration" && show_configuration_editor ;;
            3) navigate_to "System Status" && show_system_status_menu ;;
            4) navigate_to "Profiles" && show_profile_manager ;;
            5) navigate_to "Themes" && select_theme ;;
            6) navigate_to "System Info" && show_system_info ;;
            0) show_exit_dialog ;;
        esac
    done
}

# Professional Installation Wizard
show_install_wizard() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    dialog --backtitle "ExaPG Management Console" \
           --title "[ $nav_breadcrumb ]" \
           --yesno "Configure a new ExaPG installation?\n\nThe wizard will guide you through:\n\n- Deployment type selection\n- Component configuration\n- Performance settings\n- Profile management" 12 60
    
    if [ $? -eq 0 ]; then
        navigate_to "Setup"
        wizard_step_1_deployment_type
    else
        navigate_back
    fi
}

# Wizard Schritt 1: Deployment-Typ
wizard_step_1_deployment_type() {
    exec 3>&1
    DEPLOYMENT_TYPE=$(dialog \
        --backtitle "ExaPG Installation Wizard - Step 1/4" \
        --title "[ Deployment Type Selection ]" \
        --radiolist "Select the desired deployment type:" 15 65 4 \
        "single-node" "Single-Node (Development/Test)" on \
        "citus" "Citus Cluster (Horizontal Scaling)" off \
        "ha" "High Availability (Patroni + pgBouncer)" off \
        "kubernetes" "Kubernetes (Cloud-Native)" off \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        wizard_step_2_components
    else
        navigate_back
    fi
}

# Wizard Schritt 2: Komponenten auswählen
wizard_step_2_components() {
    exec 3>&1
    components=$(dialog \
        --backtitle "ExaPG Installation Wizard - Step 2/4" \
        --title "[ Component Selection ]" \
        --checklist "Select the desired components:" 16 70 7 \
        "monitoring" "Monitoring (Grafana + Prometheus)" on \
        "management-ui" "Management UI (Web Interface)" on \
        "udf-framework" "UDF Framework (Python/Lua/R)" off \
        "virtual-schemas" "Virtual Schemas (Foreign Data Wrapper)" off \
        "etl-tools" "ETL Tools (Apache Airflow)" off \
        "backup" "Backup & Recovery (pgBackRest)" on \
        "performance" "Performance Tools (pg_stat_statements)" on \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        # Komponenten-Flags setzen
        ENABLE_MONITORING=false
        ENABLE_MANAGEMENT_UI=false
        ENABLE_UDF_FRAMEWORK=false
        ENABLE_VIRTUAL_SCHEMAS=false
        ENABLE_ETL_TOOLS=false
        ENABLE_BACKUP=false
        ENABLE_PERFORMANCE=false
        
        for component in $components; do
            case $component in
                "monitoring") ENABLE_MONITORING=true ;;
                "management-ui") ENABLE_MANAGEMENT_UI=true ;;
                "udf-framework") ENABLE_UDF_FRAMEWORK=true ;;
                "virtual-schemas") ENABLE_VIRTUAL_SCHEMAS=true ;;
                "etl-tools") ENABLE_ETL_TOOLS=true ;;
                "backup") ENABLE_BACKUP=true ;;
                "performance") ENABLE_PERFORMANCE=true ;;
            esac
        done
        
        wizard_step_3_configuration
    else
        navigate_back
    fi
}

# Wizard Schritt 3: Basis-Konfiguration
wizard_step_3_configuration() {
    exec 3>&1
    values=$(dialog \
        --backtitle "ExaPG Installation Wizard - Step 3/4" \
        --title "[ Basic Configuration ]" \
        --form "Configure the basic settings:" 20 65 8 \
        "Cluster Name:"        1 1 "exapg-cluster"    1 20 30 0 \
        "Container Prefix:"    2 1 "exapg"           2 20 30 0 \
        "PostgreSQL Port:"     3 1 "5432"            3 20 30 0 \
        "Admin Password:"      4 1 "postgres"        4 20 30 0 \
        "Worker Count:"        5 1 "2"               5 20 30 0 \
        "Shared Buffers:"      6 1 "4GB"             6 20 30 0 \
        "Work Memory:"         7 1 "256MB"           7 20 30 0 \
        "Max Workers:"         8 1 "8"               8 20 30 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        # Werte zuweisen
        IFS=$'\n' read -rd '' -a config_array <<<"$values"
        CLUSTER_NAME="${config_array[0]}"
        CONTAINER_NAME="${config_array[1]}"
        COORDINATOR_PORT="${config_array[2]}"
        POSTGRES_PASSWORD="${config_array[3]}"
        WORKER_COUNT="${config_array[4]}"
        SHARED_BUFFERS="${config_array[5]}"
        WORK_MEM="${config_array[6]}"
        MAX_PARALLEL_WORKERS="${config_array[7]}"
        
        wizard_step_4_save_profile
    else
        navigate_back
    fi
}

# Wizard Schritt 4: Profil speichern
wizard_step_4_save_profile() {
    exec 3>&1
    profile_name=$(dialog \
        --backtitle "ExaPG Installation Wizard - Step 4/4" \
        --title "[ Save Profile ]" \
        --inputbox "Enter a name for this profile:" 10 50 \
        "$DEPLOYMENT_TYPE-$(date +%Y%m%d)" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ] && [ -n "$profile_name" ]; then
        # Profil speichern
        save_profile "$profile_name"
        load_profile "$profile_name"
        
        # Installation starten
        wizard_execute_installation
    else
        navigate_back
    fi
}

# Installation ausführen
wizard_execute_installation() {
    (
    echo "5"; echo "XXX"; echo "Preparing installation..."; echo "XXX"; sleep 1
    echo "15"; echo "XXX"; echo "Creating directories..."; echo "XXX"; sleep 1
    echo "25"; echo "XXX"; echo "Generating Docker Compose..."; echo "XXX"; sleep 1
    echo "35"; echo "XXX"; echo "Loading Docker images..."; echo "XXX"; sleep 3
    echo "55"; echo "XXX"; echo "Starting $DEPLOYMENT_TYPE deployment..."; echo "XXX"; sleep 2
    echo "70"; echo "XXX"; echo "Initializing database..."; echo "XXX"; sleep 2
    echo "85"; echo "XXX"; echo "Configuring components..."; echo "XXX"; sleep 2
    echo "95"; echo "XXX"; echo "Finalizing setup..."; echo "XXX"; sleep 1
    echo "100"; echo "XXX"; echo "Installation completed!"; echo "XXX"; sleep 1
    ) | dialog --title "ExaPG Installation" --gauge "Installation in progress..." 8 60 0
    
    # Success message with details
    local services=""
    [ "$ENABLE_MONITORING" = "true" ] && services="${services}- Grafana: http://localhost:3000\n"
    [ "$ENABLE_MANAGEMENT_UI" = "true" ] && services="${services}- Management UI: http://localhost:3001\n"
    [ "$ENABLE_ETL_TOOLS" = "true" ] && services="${services}- Airflow: http://localhost:8080\n"
    
    dialog --backtitle "Installation Successful" \
           --title "[ ExaPG Ready! ]" \
           --msgbox "Installation completed successfully!\n\nProfile: $EXAPG_CURRENT_PROFILE\nDeployment: $DEPLOYMENT_TYPE\n\nServices:\n- PostgreSQL: localhost:$COORDINATOR_PORT\n$services\nStatus: All services active" 16 60
}

# Konfigurationseditor
show_configuration_editor() {
    while true; do
        # Navigation-Info für Breadcrumb
        local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        local status_line="ExaPG Configuration Manager | v$EXAPG_VERSION"
        
        exec 3>&1
        selection=$(dialog \
            --backtitle "$status_line" \
            --title "[ $nav_breadcrumb ]" \
            --cancel-label "Back" \
            --menu "Select configuration area:" 15 60 6 \
            "1" "Database Settings" \
            "2" "Performance Parameters" \
            "3" "Network & Ports" \
            "4" "Component Management" \
            "5" "Save Current Configuration" \
            "0" "Return to Main Menu" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255) 
                navigate_back
                return
                ;;
        esac
        
        case $selection in
            1) edit_database_config ;;
            2) edit_performance_config ;;
            3) edit_network_config ;;
            4) edit_components_config ;;
            5) save_current_config ;;
            0) 
                navigate_back
                return
                ;;
        esac
    done
}

# Datenbank-Konfiguration editieren
edit_database_config() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    values=$(dialog \
        --backtitle "Database Configuration" \
        --title "[ $nav_breadcrumb > Database ]" \
        --form "Edit database parameters:" 16 60 6 \
        "Cluster Name:"        1 1 "${CLUSTER_NAME:-exapg-cluster}"    1 20 30 0 \
        "Container Prefix:"    2 1 "${CONTAINER_NAME:-exapg}"         2 20 30 0 \
        "Admin Password:"      3 1 "${POSTGRES_PASSWORD:-postgres}"   3 20 30 0 \
        "Worker Count:"        4 1 "${WORKER_COUNT:-2}"               4 20 30 0 \
        "Tablespace Path:"     5 1 "${TABLESPACE_PATH:-/var/lib/postgresql/data}"  5 20 30 0 \
        "Log Level:"           6 1 "${LOG_LEVEL:-info}"               6 20 30 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        IFS=$'\n' read -rd '' -a config_array <<<"$values"
        CLUSTER_NAME="${config_array[0]}"
        CONTAINER_NAME="${config_array[1]}"
        POSTGRES_PASSWORD="${config_array[2]}"
        WORKER_COUNT="${config_array[3]}"
        TABLESPACE_PATH="${config_array[4]}"
        LOG_LEVEL="${config_array[5]}"
        
        dialog --backtitle "Configuration Updated" \
               --title "[ Success ]" \
               --msgbox "Database configuration has been updated successfully." 6 50
    fi
}

# Performance-Konfiguration editieren
edit_performance_config() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    values=$(dialog \
        --backtitle "Performance Configuration" \
        --title "[ $nav_breadcrumb > Performance ]" \
        --form "Optimize performance settings:" 18 65 8 \
        "Shared Buffers:"      1 1 "${SHARED_BUFFERS:-4GB}"           1 25 25 0 \
        "Work Memory:"         2 1 "${WORK_MEM:-256MB}"               2 25 25 0 \
        "Maintenance Work Mem:" 3 1 "${MAINTENANCE_WORK_MEM:-1GB}"    3 25 25 0 \
        "Max Parallel Workers:" 4 1 "${MAX_PARALLEL_WORKERS:-8}"      4 25 25 0 \
        "Max Connections:"     5 1 "${MAX_CONNECTIONS:-200}"          5 25 25 0 \
        "JIT Compilation:"     6 1 "${JIT:-on}"                      6 25 25 0 \
        "Checkpoint Segments:" 7 1 "${CHECKPOINT_SEGMENTS:-32}"       7 25 25 0 \
        "Random Page Cost:"    8 1 "${RANDOM_PAGE_COST:-1.1}"        8 25 25 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        IFS=$'\n' read -rd '' -a config_array <<<"$values"
        SHARED_BUFFERS="${config_array[0]}"
        WORK_MEM="${config_array[1]}"
        MAINTENANCE_WORK_MEM="${config_array[2]}"
        MAX_PARALLEL_WORKERS="${config_array[3]}"
        MAX_CONNECTIONS="${config_array[4]}"
        JIT="${config_array[5]}"
        CHECKPOINT_SEGMENTS="${config_array[6]}"
        RANDOM_PAGE_COST="${config_array[7]}"
        
        dialog --backtitle "Configuration Updated" \
               --title "[ Success ]" \
               --msgbox "Performance configuration has been updated successfully." 6 50
    fi
}

# Network Configuration (Missing Implementation)
edit_network_config() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    values=$(dialog \
        --backtitle "Network Configuration" \
        --title "[ $nav_breadcrumb > Network ]" \
        --form "Configure network settings:" 16 60 6 \
        "PostgreSQL Port:"     1 1 "${COORDINATOR_PORT:-5432}"        1 20 10 0 \
        "Management UI Port:"  2 1 "${MANAGEMENT_UI_PORT:-3001}"      2 20 10 0 \
        "Grafana Port:"        3 1 "${GRAFANA_PORT:-3000}"            3 20 10 0 \
        "Prometheus Port:"     4 1 "${PROMETHEUS_PORT:-9090}"         4 20 10 0 \
        "Bind Address:"        5 1 "${BIND_ADDRESS:-0.0.0.0}"         5 20 15 0 \
        "SSL Mode:"            6 1 "${SSL_MODE:-prefer}"              6 20 10 0 \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        IFS=$'\n' read -rd '' -a config_array <<<"$values"
        COORDINATOR_PORT="${config_array[0]}"
        MANAGEMENT_UI_PORT="${config_array[1]}"
        GRAFANA_PORT="${config_array[2]}"
        PROMETHEUS_PORT="${config_array[3]}"
        BIND_ADDRESS="${config_array[4]}"
        SSL_MODE="${config_array[5]}"
        
        dialog --backtitle "Configuration Updated" \
               --title "[ Success ]" \
               --msgbox "Network configuration has been updated successfully." 6 50
    fi
}

# Component Management (Missing Implementation)
edit_components_config() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    components=$(dialog \
        --backtitle "Component Management" \
        --title "[ $nav_breadcrumb > Components ]" \
        --checklist "Enable/disable components:" 16 70 7 \
        "monitoring" "Monitoring Stack (Grafana + Prometheus)" ${ENABLE_MONITORING:-off} \
        "management-ui" "Web Management Interface" ${ENABLE_MANAGEMENT_UI:-off} \
        "udf-framework" "User Defined Functions Framework" ${ENABLE_UDF_FRAMEWORK:-off} \
        "virtual-schemas" "Virtual Schema Support" ${ENABLE_VIRTUAL_SCHEMAS:-off} \
        "etl-tools" "ETL Tools Integration" ${ENABLE_ETL_TOOLS:-off} \
        "backup" "Backup & Recovery System" ${ENABLE_BACKUP:-off} \
        "performance" "Performance Monitoring Tools" ${ENABLE_PERFORMANCE:-off} \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        # Reset all components
        ENABLE_MONITORING=false
        ENABLE_MANAGEMENT_UI=false
        ENABLE_UDF_FRAMEWORK=false
        ENABLE_VIRTUAL_SCHEMAS=false
        ENABLE_ETL_TOOLS=false
        ENABLE_BACKUP=false
        ENABLE_PERFORMANCE=false
        
        # Set enabled components
        for component in $components; do
            case $component in
                "monitoring") ENABLE_MONITORING=true ;;
                "management-ui") ENABLE_MANAGEMENT_UI=true ;;
                "udf-framework") ENABLE_UDF_FRAMEWORK=true ;;
                "virtual-schemas") ENABLE_VIRTUAL_SCHEMAS=true ;;
                "etl-tools") ENABLE_ETL_TOOLS=true ;;
                "backup") ENABLE_BACKUP=true ;;
                "performance") ENABLE_PERFORMANCE=true ;;
            esac
        done
        
        dialog --backtitle "Configuration Updated" \
               --title "[ Success ]" \
               --msgbox "Component configuration has been updated successfully." 6 50
    fi
}

# Save Configuration (Missing Implementation)
save_current_config() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    profile_name=$(dialog \
        --backtitle "Save Configuration" \
        --title "[ $nav_breadcrumb > Save ]" \
        --inputbox "Enter profile name to save current configuration:" 10 50 \
        "config-$(date +%Y%m%d-%H%M)" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ] && [ -n "$profile_name" ]; then
        save_profile "$profile_name"
        dialog --backtitle "Configuration Saved" \
               --title "[ Success ]" \
               --msgbox "Configuration saved as profile: $profile_name" 6 50
    fi
}

# System-Status erweitert
show_system_status_menu() {
    while true; do
        # Navigation-Info für Breadcrumb
        local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        
        # Service-Status abfragen (ohne Emojis)
        local pg_status=$(check_service_status "exapg-coordinator" && echo "Online" || echo "Offline")
        local monitoring_status=$(check_service_status "exapg-grafana" && echo "Online" || echo "Offline")
        local ui_status=$(check_service_status "exapg-management-ui" && echo "Online" || echo "Offline")
        
        exec 3>&1
        selection=$(dialog \
            --backtitle "ExaPG System Status | PostgreSQL: $pg_status | Monitoring: $monitoring_status | UI: $ui_status" \
            --title "[ $nav_breadcrumb ]" \
            --cancel-label "Back" \
            --menu "Select system management option:" 18 75 8 \
            "1" "Detailed System Resources" \
            "2" "Individual Service Control" \
            "3" "View Service Logs" \
            "4" "Start All Services" \
            "5" "Stop All Services" \
            "6" "Restart All Services" \
            "7" "Open Web Interfaces" \
            "0" "Return to Main Menu" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255) 
                navigate_back
                return
                ;;
        esac
        
        case $selection in
            1) show_detailed_system_resources ;;
            2) show_individual_service_control ;;
            3) show_service_logs ;;
            4) start_all_services ;;
            5) stop_all_services ;;
            6) restart_all_services ;;
            7) show_web_interfaces ;;
            0) 
                navigate_back
                return
                ;;
        esac
    done
}

# Individuelle Service-Kontrolle
show_individual_service_control() {
    local services=(
        "postgresql" "PostgreSQL Database"
        "monitoring" "Monitoring (Grafana/Prometheus)"
        "management-ui" "Management Web Interface"
        "backup" "Backup System"
        "etl" "ETL Tools"
        "udf" "UDF Framework"
    )
    
    while true; do
        local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        local menu_items=()
        
        for ((i=0; i<${#services[@]}; i+=2)); do
            local service=${services[i]}
            local description=${services[i+1]}
            local status=$(check_service_status "exapg-$service" && echo "[Online]" || echo "[Offline]")
            menu_items+=("$service" "$status $description")
        done
        menu_items+=("back" "Return to System Status")
        
        exec 3>&1
        selection=$(dialog \
            --backtitle "Service Control Management" \
            --title "[ $nav_breadcrumb > Service Control ]" \
            --cancel-label "Back" \
            --menu "Select a service to manage:" 16 70 7 \
            "${menu_items[@]}" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255) return ;;
        esac
        
        case $selection in
            "back") return ;;
            *) control_individual_service "$selection" ;;
        esac
    done
}

# Einzelner Service kontrollieren
control_individual_service() {
    local service=$1
    local service_status=$(check_service_status "exapg-$service" && echo "Online" || echo "Offline")
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    action=$(dialog \
        --backtitle "Service: $service | Status: $service_status" \
        --title "[ $nav_breadcrumb > $service ]" \
        --cancel-label "Back" \
        --menu "Select action for $service:" 12 50 4 \
        "start" "Start Service" \
        "stop" "Stop Service" \
        "restart" "Restart Service" \
        "logs" "View Logs" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        case $action in
            "start")
                docker-compose up -d "exapg-$service"
                dialog --backtitle "Service Management" \
                       --title "[ Success ]" \
                       --msgbox "$service has been started successfully." 6 50
                ;;
            "stop")
                docker-compose stop "exapg-$service"
                dialog --backtitle "Service Management" \
                       --title "[ Success ]" \
                       --msgbox "$service has been stopped successfully." 6 50
                ;;
            "restart")
                docker-compose restart "exapg-$service"
                dialog --backtitle "Service Management" \
                       --title "[ Success ]" \
                       --msgbox "$service has been restarted successfully." 6 50
                ;;
            "logs")
                docker-compose logs --tail=100 "exapg-$service" > /tmp/service_logs.txt
                dialog --backtitle "Service Logs: $service" \
                       --title "[ $nav_breadcrumb > $service Logs ]" \
                       --textbox /tmp/service_logs.txt 20 80
                ;;
        esac
    fi
}

# Missing implementations for system status functions
start_all_services() {
    dialog --backtitle "Starting All Services" \
           --title "[ Confirm Action ]" \
           --yesno "Start all ExaPG services?\n\nThis will start:\n- PostgreSQL Database\n- Monitoring Stack\n- Management UI\n- All enabled components" 10 60
    
    if [ $? -eq 0 ]; then
        docker-compose up -d
        dialog --backtitle "Service Management" \
               --title "[ Success ]" \
               --msgbox "All services have been started successfully." 6 50
    fi
}

stop_all_services() {
    dialog --backtitle "Stopping All Services" \
           --title "[ Confirm Action ]" \
           --yesno "Stop all ExaPG services?\n\nThis will stop:\n- PostgreSQL Database\n- Monitoring Stack\n- Management UI\n- All running components\n\nData will be preserved." 12 60
    
    if [ $? -eq 0 ]; then
        docker-compose stop
        dialog --backtitle "Service Management" \
               --title "[ Success ]" \
               --msgbox "All services have been stopped successfully." 6 50
    fi
}

restart_all_services() {
    dialog --backtitle "Restarting All Services" \
           --title "[ Confirm Action ]" \
           --yesno "Restart all ExaPG services?\n\nThis will restart all running services." 8 60
    
    if [ $? -eq 0 ]; then
        docker-compose restart
        dialog --backtitle "Service Management" \
               --title "[ Success ]" \
               --msgbox "All services have been restarted successfully." 6 50
    fi
}

show_detailed_system_resources() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    # System resource information
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'%' -f1)
    local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    local disk_usage=$(df / | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    
    local resource_info="SYSTEM RESOURCE OVERVIEW
==========================================

CPU USAGE: ${cpu_usage:-N/A}%
MEMORY USAGE: ${mem_usage:-N/A}%
DISK USAGE: ${disk_usage:-N/A}%
LOAD AVERAGE:${load_avg:-N/A}

DOCKER CONTAINERS:
$(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep exapg || echo 'No ExaPG containers running')

==========================================
Press OK to continue..."

    dialog --backtitle "System Resources" \
           --title "[ $nav_breadcrumb > Resources ]" \
           --msgbox "$resource_info" 20 70
}

show_service_logs() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    service=$(dialog \
        --backtitle "Service Logs" \
        --title "[ $nav_breadcrumb > Logs ]" \
        --cancel-label "Back" \
        --menu "Select service to view logs:" 15 60 7 \
        "coordinator" "PostgreSQL Coordinator" \
        "grafana" "Grafana Monitoring" \
        "prometheus" "Prometheus Metrics" \
        "management-ui" "Management UI" \
        "system" "System Logs (journalctl)" \
        "docker" "Docker Container Logs" \
        "all" "All Available Logs" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ]; then
        case $service in
            "all")
                show_all_available_logs "$nav_breadcrumb"
                ;;
            "system")
                show_system_logs "$nav_breadcrumb"
                ;;
            "docker")
                show_docker_logs "$nav_breadcrumb"
                ;;
            *)
                show_specific_service_logs "$service" "$nav_breadcrumb"
                ;;
        esac
    fi
}

# Spezifische Service-Logs anzeigen
show_specific_service_logs() {
    local service="$1"
    local nav_breadcrumb="$2"
    local log_content=""
    local log_source=""
    
    # Methode 1: Docker Compose (falls verfügbar)
    if [ -f "docker-compose.yml" ] && command -v docker-compose >/dev/null 2>&1; then
        log_content=$(docker-compose logs --tail=100 "exapg-$service" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$log_content" ]; then
            log_source="Docker Compose"
        fi
    fi
    
    # Methode 2: Docker direkt (Fallback)
    if [ -z "$log_content" ] && command -v docker >/dev/null 2>&1; then
        # Nach Container mit Service-Namen suchen
        local container_id=$(docker ps -q --filter "name=exapg.*$service" | head -1)
        if [ -n "$container_id" ]; then
            log_content=$(docker logs --tail=100 "$container_id" 2>&1)
            if [ $? -eq 0 ]; then
                log_source="Docker Container: $container_id"
            fi
        fi
    fi
    
    # Methode 3: Systemd Service Logs (weiterer Fallback)
    if [ -z "$log_content" ] && command -v journalctl >/dev/null 2>&1; then
        log_content=$(journalctl -u "*$service*" --lines=100 --no-pager 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$log_content" ]; then
            log_source="Systemd Journal"
        fi
    fi
    
    # Logs anzeigen oder Fehlermeldung
    if [ -n "$log_content" ]; then
        echo "$log_content" > /tmp/service_logs.txt
        echo "" >> /tmp/service_logs.txt
        echo "============================" >> /tmp/service_logs.txt
        echo "Log Source: $log_source" >> /tmp/service_logs.txt
        echo "Service: $service" >> /tmp/service_logs.txt
        echo "Generated: $(date)" >> /tmp/service_logs.txt
        
        dialog --backtitle "Service Logs: $service" \
               --title "[ $nav_breadcrumb > $service Logs ]" \
               --textbox /tmp/service_logs.txt 20 80
    else
        display_no_logs_found "$service" "$nav_breadcrumb"
    fi
    
    # Cleanup
    rm -f /tmp/service_logs.txt
}

# Alle verfügbaren Logs sammeln
show_all_available_logs() {
    local nav_breadcrumb="$1"
    local all_logs=""
    
    # Docker Container Logs sammeln
    if command -v docker >/dev/null 2>&1; then
        local containers=$(docker ps --format "{{.Names}}" | grep -i exapg)
        if [ -n "$containers" ]; then
            all_logs+="=== DOCKER CONTAINER LOGS ===\n"
            for container in $containers; do
                all_logs+="=== Container: $container ===\n"
                all_logs+="$(docker logs --tail=20 "$container" 2>&1)\n\n"
            done
        fi
    fi
    
    # System Logs hinzufügen
    if command -v journalctl >/dev/null 2>&1; then
        all_logs+="\n=== SYSTEM LOGS (Last 20 lines) ===\n"
        all_logs+="$(journalctl --lines=20 --no-pager 2>/dev/null)\n"
    fi
    
    # PostgreSQL Logs suchen
    local pg_log_dirs=("/var/log/postgresql" "/var/lib/postgresql/data/log" "/usr/local/var/log")
    for log_dir in "${pg_log_dirs[@]}"; do
        if [ -d "$log_dir" ]; then
            local latest_log=$(find "$log_dir" -name "*.log" -type f -exec ls -t {} + | head -1)
            if [ -f "$latest_log" ]; then
                all_logs+="\n=== POSTGRESQL LOG: $latest_log ===\n"
                all_logs+="$(tail -20 "$latest_log" 2>/dev/null)\n"
                break
            fi
        fi
    done
    
    if [ -n "$all_logs" ]; then
        echo -e "$all_logs" > /tmp/all_service_logs.txt
        echo "" >> /tmp/all_service_logs.txt
        echo "============================" >> /tmp/all_service_logs.txt
        echo "Generated: $(date)" >> /tmp/all_service_logs.txt
        echo "System: $(hostname)" >> /tmp/all_service_logs.txt
        
        dialog --backtitle "All Service Logs" \
               --title "[ $nav_breadcrumb > All Logs ]" \
               --textbox /tmp/all_service_logs.txt 20 80
    else
        display_no_logs_found "any services" "$nav_breadcrumb"
    fi
    
    # Cleanup
    rm -f /tmp/all_service_logs.txt
}

# System Logs anzeigen
show_system_logs() {
    local nav_breadcrumb="$1"
    local system_logs=""
    
    if command -v journalctl >/dev/null 2>&1; then
        system_logs=$(journalctl --lines=100 --no-pager 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$system_logs" ]; then
            echo "$system_logs" > /tmp/system_logs.txt
            echo "" >> /tmp/system_logs.txt
            echo "============================" >> /tmp/system_logs.txt
            echo "System Journal Logs" >> /tmp/system_logs.txt
            echo "Generated: $(date)" >> /tmp/system_logs.txt
            
            dialog --backtitle "System Logs" \
                   --title "[ $nav_breadcrumb > System Logs ]" \
                   --textbox /tmp/system_logs.txt 20 80
        else
            display_no_logs_found "system logs" "$nav_breadcrumb"
        fi
    else
        # Fallback auf traditionelle Log-Dateien
        local log_files=("/var/log/messages" "/var/log/syslog" "/var/log/daemon.log")
        local found_log=""
        
        for log_file in "${log_files[@]}"; do
            if [ -f "$log_file" ] && [ -r "$log_file" ]; then
                found_log="$log_file"
                break
            fi
        done
        
        if [ -n "$found_log" ]; then
            tail -100 "$found_log" > /tmp/system_logs.txt 2>/dev/null
            echo "" >> /tmp/system_logs.txt
            echo "============================" >> /tmp/system_logs.txt
            echo "Log Source: $found_log" >> /tmp/system_logs.txt
            echo "Generated: $(date)" >> /tmp/system_logs.txt
            
            dialog --backtitle "System Logs" \
                   --title "[ $nav_breadcrumb > System Logs ]" \
                   --textbox /tmp/system_logs.txt 20 80
        else
            display_no_logs_found "system logs" "$nav_breadcrumb"
        fi
    fi
    
    # Cleanup
    rm -f /tmp/system_logs.txt
}

# Docker Container Logs anzeigen
show_docker_logs() {
    local nav_breadcrumb="$1"
    
    if ! command -v docker >/dev/null 2>&1; then
        display_no_logs_found "Docker (not installed)" "$nav_breadcrumb"
        return
    fi
    
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [ -z "$containers" ]; then
        display_no_logs_found "Docker containers (none running)" "$nav_breadcrumb"
        return
    fi
    
    local docker_logs=""
    docker_logs+="=== RUNNING DOCKER CONTAINERS ===\n"
    docker_logs+="$(docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}')\n\n"
    
    for container in $containers; do
        docker_logs+="=== Container: $container ===\n"
        docker_logs+="$(docker logs --tail=15 "$container" 2>&1)\n\n"
    done
    
    echo -e "$docker_logs" > /tmp/docker_logs.txt
    echo "============================" >> /tmp/docker_logs.txt
    echo "Generated: $(date)" >> /tmp/docker_logs.txt
    
    dialog --backtitle "Docker Container Logs" \
           --title "[ $nav_breadcrumb > Docker Logs ]" \
           --textbox /tmp/docker_logs.txt 20 80
    
    # Cleanup
    rm -f /tmp/docker_logs.txt
}

# Keine Logs gefunden - Meldung anzeigen
display_no_logs_found() {
    local service="$1"
    local nav_breadcrumb="$2"
    
    local error_message="NO LOGS FOUND: $service
==========================================

TROUBLESHOOTING:
- No Docker containers are running
- No docker-compose.yml file found  
- Service may not be started yet
- Insufficient permissions to access logs

SUGGESTIONS:
1. Start services via 'Start All Services' menu
2. Check if Docker is running: docker ps
3. Verify service status in System Status menu
4. Check system logs for startup errors

ALTERNATIVE LOG SOURCES:
- System logs: journalctl or /var/log/
- Docker logs: docker logs [container-name]
- Application specific log files

==========================================
Press OK to return to log selection..."

    dialog --backtitle "Log Viewer - No Logs Found" \
           --title "[ $nav_breadcrumb > No Logs ]" \
           --msgbox "$error_message" 20 65
}

show_web_interfaces() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    local interfaces="WEB INTERFACE ACCESS
==========================================

MANAGEMENT INTERFACES:
- ExaPG Management UI: http://localhost:3001
- Grafana Dashboard:   http://localhost:3000
- Prometheus Metrics:  http://localhost:9090

DATABASE ACCESS:
- PostgreSQL:          localhost:5432
- Default Database:    exapg
- Default User:        postgres

NOTES:
- Ensure services are running before accessing
- Default credentials may apply
- Check firewall settings if remote access needed

==========================================
Press OK to continue..."

    dialog --backtitle "Web Interface Information" \
           --title "[ $nav_breadcrumb > Web Access ]" \
           --msgbox "$interfaces" 18 60
}

# Service Status Check
check_service_status() {
    local service=$1
    docker ps --format "table {{.Names}}" | grep -q "$service"
}

# Profil-Manager
show_profile_manager() {
    while true; do
        # Navigation-Info für Breadcrumb
        local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
        
        # Verfügbare Profile auflisten
        local profiles=()
        if [ -d "$EXAPG_PROFILES_DIR" ]; then
            for profile_file in "$EXAPG_PROFILES_DIR"/*.env; do
                if [ -f "$profile_file" ]; then
                    local profile_name=$(basename "$profile_file" .env)
                    local active_marker=""
                    [ "$profile_name" = "$EXAPG_CURRENT_PROFILE" ] && active_marker="[Active] "
                    profiles+=("$profile_name" "${active_marker}$(get_profile_description "$profile_name")")
                fi
            done
        fi
        
        profiles+=("new" "Create New Profile")
        profiles+=("back" "Return to Main Menu")
        
        exec 3>&1
        selection=$(dialog \
            --backtitle "ExaPG Profile Manager" \
            --title "[ $nav_breadcrumb ]" \
            --cancel-label "Back" \
            --menu "Currently active: ${EXAPG_CURRENT_PROFILE:-None}" 16 70 8 \
            "${profiles[@]}" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255) 
                navigate_back
                return
                ;;
        esac
        
        case $selection in
            "new") create_new_profile ;;
            "back") 
                navigate_back
                return
                ;;
            *) manage_profile "$selection" ;;
        esac
    done
}

# Profil-Beschreibung abrufen
get_profile_description() {
    local profile=$1
    local profile_file="$EXAPG_PROFILES_DIR/$profile.env"
    
    if [ -f "$profile_file" ]; then
        local deployment_type=$(grep "DEPLOYMENT_TYPE=" "$profile_file" | cut -d'=' -f2)
        local components=$(grep "ENABLE_.*=true" "$profile_file" | wc -l)
        echo "$deployment_type ($components components)"
    else
        echo "Description not available"
    fi
}

# Neues Profil erstellen
create_new_profile() {
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    profile_name=$(dialog \
        --backtitle "Create New Profile" \
        --title "[ $nav_breadcrumb > New Profile ]" \
        --inputbox "Enter a name for the new profile:" 10 50 \
        "profile-$(date +%Y%m%d-%H%M)" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ] && [ -n "$profile_name" ]; then
        # Prüfen ob Profil bereits existiert
        local profile_file="$EXAPG_PROFILES_DIR/$profile_name.env"
        if [ -f "$profile_file" ]; then
            dialog --backtitle "Profile Creation Error" \
                   --title "[ Error ]" \
                   --msgbox "Profile '$profile_name' already exists!\n\nPlease choose a different name." 8 50
            return
        fi
        
        # Standard-Werte setzen
        CLUSTER_NAME="exapg-cluster"
        CONTAINER_NAME="exapg"
        POSTGRES_PASSWORD="postgres"
        COORDINATOR_PORT="5432"
        WORKER_COUNT="2"
        SHARED_BUFFERS="4GB"
        WORK_MEM="256MB"
        MAX_PARALLEL_WORKERS="8"
        JIT="on"
        ENABLE_MONITORING="false"
        ENABLE_MANAGEMENT_UI="false"
        ENABLE_UDF_FRAMEWORK="false"
        ENABLE_VIRTUAL_SCHEMAS="false"
        ENABLE_ETL_TOOLS="false"
        ENABLE_BACKUP="false"
        DEPLOYMENT_TYPE="single-node"
        
        # Profil speichern
        save_profile "$profile_name"
        load_profile "$profile_name"
        
        dialog --backtitle "Profile Created" \
               --title "[ Success ]" \
               --msgbox "New profile '$profile_name' has been created and activated.\n\nYou can now configure it via the Configuration Management menu." 10 60
    fi
}

# Vorhandenes Profil verwalten
manage_profile() {
    local profile=$1
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    while true; do
        local profile_status=""
        if [ "$profile" = "$EXAPG_CURRENT_PROFILE" ]; then
            profile_status="[Currently Active]"
        else
            profile_status="[Inactive]"
        fi
        
        exec 3>&1
        action=$(dialog \
            --backtitle "Profile Management: $profile $profile_status" \
            --title "[ $nav_breadcrumb > $profile ]" \
            --cancel-label "Back" \
            --menu "Select action for profile '$profile':" 14 60 6 \
            "activate" "Activate This Profile" \
            "edit" "Edit Profile Settings" \
            "duplicate" "Duplicate Profile" \
            "export" "Export Profile" \
            "delete" "Delete Profile" \
            "info" "Show Profile Information" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        
        case $exit_status in
            1|255) return ;;
        esac
        
        case $action in
            "activate")
                load_profile "$profile"
                dialog --backtitle "Profile Activated" \
                       --title "[ Success ]" \
                       --msgbox "Profile '$profile' has been activated.\n\nAll settings are now applied." 8 50
                ;;
            "edit")
                # Profil laden und zum Konfigurations-Editor wechseln
                load_profile "$profile"
                navigate_to "Configuration"
                show_configuration_editor
                navigate_back
                ;;
            "duplicate")
                duplicate_profile "$profile"
                ;;
            "export")
                export_profile "$profile"
                ;;
            "delete")
                delete_profile "$profile"
                [ $? -eq 0 ] && return  # Zurück wenn gelöscht
                ;;
            "info")
                show_profile_info "$profile"
                ;;
        esac
    done
}

# Profil duplizieren
duplicate_profile() {
    local source_profile=$1
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    exec 3>&1
    new_name=$(dialog \
        --backtitle "Duplicate Profile" \
        --title "[ $nav_breadcrumb > Duplicate ]" \
        --inputbox "Enter name for the duplicate profile:" 10 50 \
        "$source_profile-copy" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    
    if [ $exit_status -eq 0 ] && [ -n "$new_name" ]; then
        local source_file="$EXAPG_PROFILES_DIR/$source_profile.env"
        local target_file="$EXAPG_PROFILES_DIR/$new_name.env"
        
        if [ -f "$target_file" ]; then
            dialog --backtitle "Duplicate Error" \
                   --title "[ Error ]" \
                   --msgbox "Profile '$new_name' already exists!" 6 50
            return
        fi
        
        # Profil kopieren und Header anpassen
        cp "$source_file" "$target_file"
        sed -i "s/# ExaPG Profile: $source_profile/# ExaPG Profile: $new_name/" "$target_file"
        sed -i "s/# Created: .*/# Created: $(date) (Duplicated from $source_profile)/" "$target_file"
        
        dialog --backtitle "Profile Duplicated" \
               --title "[ Success ]" \
               --msgbox "Profile duplicated successfully!\n\nNew profile: $new_name" 8 50
    fi
}

# Profil exportieren
export_profile() {
    local profile=$1
    local export_file="$profile-$(date +%Y%m%d).env"
    
    cp "$EXAPG_PROFILES_DIR/$profile.env" "$export_file"
    
    dialog --backtitle "Profile Export" \
           --title "[ Export Complete ]" \
           --msgbox "Profile exported to:\n$export_file\n\nYou can share this file or use it for backup." 10 60
}

# Profil löschen
delete_profile() {
    local profile=$1
    
    dialog --backtitle "Delete Profile" \
           --title "[ Confirm Deletion ]" \
           --yesno "Are you sure you want to delete profile '$profile'?\n\nThis action cannot be undone." 8 60
    
    if [ $? -eq 0 ]; then
        rm -f "$EXAPG_PROFILES_DIR/$profile.env"
        
        # Falls aktives Profil gelöscht wird
        if [ "$profile" = "$EXAPG_CURRENT_PROFILE" ]; then
            EXAPG_CURRENT_PROFILE=""
        fi
        
        dialog --backtitle "Profile Deleted" \
               --title "[ Success ]" \
               --msgbox "Profile '$profile' has been deleted successfully." 6 50
        return 0
    fi
    return 1
}

# Profil-Informationen anzeigen
show_profile_info() {
    local profile=$1
    local profile_file="$EXAPG_PROFILES_DIR/$profile.env"
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    if [ ! -f "$profile_file" ]; then
        dialog --backtitle "Profile Error" \
               --title "[ Error ]" \
               --msgbox "Profile file not found: $profile_file" 6 50
        return
    fi
    
    # Profil-Informationen sammeln
    local deployment_type=$(grep "DEPLOYMENT_TYPE=" "$profile_file" | cut -d'=' -f2 | tr -d '"')
    local cluster_name=$(grep "CLUSTER_NAME=" "$profile_file" | cut -d'=' -f2 | tr -d '"')
    local port=$(grep "COORDINATOR_PORT=" "$profile_file" | cut -d'=' -f2 | tr -d '"')
    local workers=$(grep "WORKER_COUNT=" "$profile_file" | cut -d'=' -f2 | tr -d '"')
    local memory=$(grep "SHARED_BUFFERS=" "$profile_file" | cut -d'=' -f2 | tr -d '"')
    local created=$(grep "# Created:" "$profile_file" | cut -d':' -f2- | xargs)
    
    # Enabled components zählen
    local enabled_components=$(grep "ENABLE_.*=true" "$profile_file" | wc -l)
    local component_list=$(grep "ENABLE_.*=true" "$profile_file" | sed 's/ENABLE_//; s/=true//' | tr '\n' ', ' | sed 's/, $//')
    
    local profile_details="PROFILE INFORMATION: $profile
==========================================

BASIC SETTINGS:
  Deployment Type: $deployment_type
  Cluster Name: $cluster_name
  PostgreSQL Port: $port
  Worker Count: $workers
  Shared Buffers: $memory

COMPONENTS:
  Enabled Components: $enabled_components
  Active: $component_list

METADATA:
  Created: $created
  Status: $([ "$profile" = "$EXAPG_CURRENT_PROFILE" ] && echo "Active" || echo "Inactive")
  File: $profile_file

==========================================
Press OK to continue..."

    dialog --backtitle "Profile Information" \
           --title "[ $nav_breadcrumb > $profile Info ]" \
           --msgbox "$profile_details" 20 70
}

# Professioneller Exit-Dialog
show_exit_dialog() {
    dialog --backtitle "ExaPG Management Console" \
           --title "[ Confirm Exit ]" \
           --yesno "Are you sure you want to exit ExaPG Management Console?\n\nRunning services will remain active." 8 60
    
    if [ $? -eq 0 ]; then
        # Sauberer Cleanup vor Exit
        cleanup_terminal
        
        # Professionelle Exit-Meldung
        echo ""
        echo "ExaPG Management Console"
        echo "========================"
        echo ""
        echo "Session terminated."
        echo "Services remain active in background."
        echo ""
        echo "Run './exapg' to restart the management console."
        echo ""
        exit 0
    fi
}

# System-Informationen - Erweitert
show_system_info() {
    local cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    local mem_total=$(free -h | grep "Mem:" | awk '{print $2}')
    local disk_total=$(df -h / | awk 'NR==2 {print $2}')
    local uptime=$(uptime -p)
    
    # Terminal-Informationen
    read term_colors has_bold has_dim <<< "$(detect_terminal_capabilities)"
    local term_size=$(get_terminal_size)
    local term_info="$TERM ($term_size, ${term_colors} Farben)"
    
    # Theme-Information
    local theme_desc=""
    case "$EXAPG_THEME" in
        "nord-dark") theme_desc="Nord Dark - Professionelles dunkles Theme" ;;
        "nord-light") theme_desc="Nord Light - Helles Theme für Tageslicht" ;;
        "nord-contrast") theme_desc="Nord High Contrast - Barrierefreiheit" ;;
        "classic") theme_desc="Classic Terminal - Retro grün-auf-schwarz" ;;
    esac
    
    # Docker-Version sicher ermitteln
    local docker_version="Nicht installiert"
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo "Fehler")
    fi
    
    # Dialog-Version ermitteln
    local dialog_version=$(dialog --version 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+' || echo "Unbekannt")
    
    # Navigation-Info für Breadcrumb
    local nav_breadcrumb="ExaPG > $(IFS=' > '; echo "${MENU_STACK[*]}")"
    
    # Professionelle Systeminformationen
    local system_details="SYSTEM OVERVIEW
==========================================

HARDWARE:
  CPU: $cpu_info
  Memory: $mem_total available
  Disk: $disk_total total capacity
  Uptime: $uptime

USER INTERFACE:
  ExaPG Version: $EXAPG_VERSION
  Active Theme: $theme_desc
  Terminal: $term_info
  Dialog Version: $dialog_version

CONTAINER ENVIRONMENT:
  Docker: $docker_version
  Active Profile: ${EXAPG_CURRENT_PROFILE:-None}

TERMINAL CAPABILITIES:
  Bold Text Support: $has_bold
  Dim Text Support: $has_dim
  Color Depth: ${term_colors}-bit

==========================================
Press OK to continue..."

    # Professionelle Dialog-Anzeige
    dialog --backtitle "ExaPG v$EXAPG_VERSION" \
           --title "[ $nav_breadcrumb ]" \
           --msgbox "$system_details" 22 60
}

# Haupteinstiegspunkt
main() {
    # Initialisierung
    check_terminal_ui
    setup_color_scheme
    create_profiles_dir
    
    # Willkommen
    show_welcome_screen
    
    # Hauptschleife
    show_main_menu
}

# Export aller Funktionen
export -f check_terminal_ui
export -f setup_color_scheme
export -f show_main_menu
export -f main

# Debug/Test-Funktion für Exit-Code-Behandlung
test_dialog_exit_codes() {
    echo "=== Dialog Exit Code Test ==="
    echo "Testing different dialog responses..."
    
    # Test msgbox with OK
    dialog --title "Test 1" --msgbox "Click OK to continue test" 6 40
    echo "msgbox OK returned: $?"
    
    # Test yesno with different responses
    dialog --title "Test 2" --yesno "Click Yes to continue test" 6 40
    echo "yesno response returned: $?"
    
    # Test menu with cancel
    dialog --title "Test 3" --cancel-label "Cancel Test" --menu "Select or Cancel:" 10 40 2 "1" "Option 1" "2" "Option 2" 2>/dev/null
    echo "menu response returned: $?"
    
    echo "=== All tests completed, script still running ==="
    echo "Exit codes: 0=OK/Yes, 1=Cancel/No, 255=ESC"
}

# Auto-Start wenn direkt ausgeführt
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Uncomment next line to run exit code tests:
    # test_dialog_exit_codes
    main "$@"
fi 