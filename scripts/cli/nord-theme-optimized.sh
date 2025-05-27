#!/bin/bash
# Nord Theme Optimized - Behebt die identifizierten Design-Probleme
# Implementiert semantische Farben und kontextuelle Themes

# ═══════════════════════════════════════════════════════════════
# OPTIMIERTE NORD THEME IMPLEMENTATION
# ═══════════════════════════════════════════════════════════════

# Erweiterte Dialog-Konfiguration mit semantischen Farben
generate_optimized_nord_theme() {
    cat << 'EOF'
# ExaPG Optimized Nord Dark Theme v4.0 - SEMANTIC COLORS ACTIVE
# Behebt monotone Farbgebung und implementiert visuelle Hierarchie

# Dialog-Verhalten
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# ═══════════════════════════════════════════════════════════════
# OPTIMIERTE NORD FARBSTRATEGIE - AKTIVE SEMANTIK
# ═══════════════════════════════════════════════════════════════
# 🔵 CYAN (4) - Primäre Aktionen, wichtige Navigation
# 🔷 BLUE (6) - Strukturelemente, Management
# 🟢 GREEN (2) - Erfolg, Status, Gesundheit
# 🟡 YELLOW (3) - Warnungen, Aufmerksamkeit, Anpassungen
# 🔴 RED (1) - Fehler, kritische Aktionen
# 🟣 MAGENTA (5) - Info, Profile, Spezialfunktionen
# ⚪ WHITE (7) - Standard Text, Information
# ⚫ BLACK (0) - Hintergrund, Struktur
# ═══════════════════════════════════════════════════════════════

# BASIS LAYOUT - Optimierter Nord Look
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# TITEL & BORDERS - Hierarchische Frost-Farben mit mehr Kontrast
title_color = (CYAN,BLACK,ON)           # 🔵 Primäre Aufmerksamkeit
border_color = (BLUE,BLACK,ON)          # 🔷 Strukturelle Elemente
border2_color = (CYAN,BLACK,ON)         # 🔵 Verstärkte Sekundäre Borders

# BUTTONS - Optimierte semantische Farbkodierung
button_active_color = (BLACK,GREEN,ON)      # 🟢 Grün für positive Aktionen (OK)
button_inactive_color = (CYAN,BLACK,OFF)    # 🔵 Cyan für neutrale Buttons
button_key_active_color = (BLACK,YELLOW,ON) # 🟡 Gelb für Keyboard-Shortcuts
button_key_inactive_color = (YELLOW,BLACK,ON) # 🟡 Verstärkte Shortcuts
button_label_active_color = (BLACK,GREEN,ON)    # 🟢 Konsistent mit Button
button_label_inactive_color = (CYAN,BLACK,OFF)  # 🔵 Cyan statt langweiliges Weiß

# MENU SYSTEM - Optimierte Hierarchie mit verstärkten Farben
menubox_color = (WHITE,BLACK,OFF)           # ⚪ Standard Hintergrund
menubox_border_color = (BLUE,BLACK,ON)      # 🔷 Strukturelle Begrenzung
menubox_border2_color = (CYAN,BLACK,ON)     # 🔵 Verstärkte Akzent-Border
item_color = (WHITE,BLACK,OFF)              # ⚪ Standard Menü-Items
item_selected_color = (BLACK,CYAN,ON)       # 🔵 Verstärkte Primäre Selektion

# TAG SYSTEM - Verstärkte Aufmerksamkeits-Farben
tag_color = (YELLOW,BLACK,ON)               # 🟡 Auffällige Tags
tag_selected_color = (BLACK,YELLOW,ON)      # 🟡 Invertierte Selektion
tag_key_color = (YELLOW,BLACK,ON)           # 🟡 Konsistente Shortcuts
tag_key_selected_color = (BLACK,YELLOW,ON)  # 🟡 Aktive Shortcuts

# EINGABEFELDER - Verstärkte Input-Ästhetik
inputbox_color = (WHITE,BLACK,OFF)          # ⚪ Standard Input
inputbox_border_color = (CYAN,BLACK,ON)     # 🔵 Verstärkte Input-Borders
inputbox_border2_color = (BLUE,BLACK,ON)    # 🔷 Sekundäre Struktur
form_active_text_color = (BLACK,CYAN,ON)    # 🔵 Aktive Eingabe
form_text_color = (WHITE,BLACK,OFF)         # ⚪ Standard Text
form_item_readonly_color = (BLUE,BLACK,ON)  # 🔷 Verstärkte Readonly-Felder

# CHECKBOXEN & AUSWAHL - Verstärktes semantisches Grün
check_color = (WHITE,BLACK,OFF)             # ⚪ Unselected
check_selected_color = (BLACK,GREEN,ON)     # 🟢 Verstärktes Erfolg-Grün

# PROGRESS & GAUGE - Verstärkte Fortschrittsanzeige
gauge_color = (BLACK,CYAN,ON)               # 🔵 Primärer Fortschritt

# SUCHFUNKTION - Verstärkte Such-UI
searchbox_color = (WHITE,BLACK,OFF)         # ⚪ Such-Hintergrund
searchbox_title_color = (MAGENTA,BLACK,ON)  # 🟣 Info-Magenta für Such-Titel
searchbox_border_color = (CYAN,BLACK,ON)    # 🔵 Verstärkte Such-Border
searchbox_border2_color = (BLUE,BLACK,ON)   # 🔷 Sekundäre Struktur

# NAVIGATION - Verstärkte Bewegungs-Grün
position_indicator_color = (GREEN,BLACK,ON) # 🟢 Positions-Indikator
uarrow_color = (GREEN,BLACK,ON)             # 🟢 Aufwärts-Pfeil
darrow_color = (GREEN,BLACK,ON)             # 🟢 Abwärts-Pfeil

# HILFE & SEKUNDÄRE ELEMENTE - Verstärkte Info-Magenta
itemhelp_color = (MAGENTA,BLACK,ON)         # 🟣 Verstärkte Hilfe-Text

# ERWEITERTE SEMANTISCHE ELEMENTE - Optimiert
week_number_color = (MAGENTA,BLACK,ON)      # 🟣 Wochen-Info
weekday_color = (BLUE,BLACK,ON)             # 🔷 Wochentage
day_color = (WHITE,BLACK,OFF)               # ⚪ Standard Tage
day_selected_color = (BLACK,CYAN,ON)        # 🔵 Ausgewählter Tag
month_color = (CYAN,BLACK,ON)               # 🔵 Monat-Header
year_color = (YELLOW,BLACK,ON)              # 🟡 Jahr-Anzeige

# Text-Viewer - Optimiert für bessere Lesbarkeit
textbox_color = (WHITE,BLACK,OFF)           # ⚪ Text-Hintergrund
textbox_border_color = (BLUE,BLACK,ON)      # 🔷 Text-Border
textbox_border2_color = (CYAN,BLACK,ON)     # 🔵 Verstärkte Text-Border

EOF
}

# Kontextuelle Theme-Anpassungen
apply_contextual_colors() {
    local context="$1"
    local temp_dialogrc="/tmp/contextual_dialogrc_$$"
    
    case "$context" in
        "status")
            # Grün-dominiertes Theme für Status-Anzeigen
            generate_optimized_nord_theme > "$temp_dialogrc"
            cat >> "$temp_dialogrc" << 'EOF'
# STATUS CONTEXT OVERRIDES
title_color = (GREEN,BLACK,ON)
border_color = (GREEN,BLACK,ON)
button_active_color = (BLACK,GREEN,ON)
EOF
            ;;
        "warning")
            # Gelb-akzentuiertes Theme für Warnungen
            generate_optimized_nord_theme > "$temp_dialogrc"
            cat >> "$temp_dialogrc" << 'EOF'
# WARNING CONTEXT OVERRIDES
title_color = (YELLOW,BLACK,ON)
border_color = (YELLOW,BLACK,ON)
button_active_color = (BLACK,YELLOW,ON)
EOF
            ;;
        "error")
            # Rot-akzentuiertes Theme für Fehler
            generate_optimized_nord_theme > "$temp_dialogrc"
            cat >> "$temp_dialogrc" << 'EOF'
# ERROR CONTEXT OVERRIDES
title_color = (RED,BLACK,ON)
border_color = (RED,BLACK,ON)
button_active_color = (BLACK,RED,ON)
EOF
            ;;
        "success")
            # Grün-akzentuiertes Theme für Erfolg
            generate_optimized_nord_theme > "$temp_dialogrc"
            cat >> "$temp_dialogrc" << 'EOF'
# SUCCESS CONTEXT OVERRIDES
title_color = (GREEN,BLACK,ON)
border_color = (GREEN,BLACK,ON)
button_active_color = (BLACK,GREEN,ON)
EOF
            ;;
        *)
            # Standard optimiertes Theme
            generate_optimized_nord_theme > "$temp_dialogrc"
            ;;
    esac
    
    export DIALOGRC="$temp_dialogrc"
    export DIALOGOPTS="--colors --no-shadow --ascii-lines"
}

# Optimierte Terminal-Farbsetzung
apply_optimized_terminal_colors() {
    # Verstärkte Nord-Farben für bessere Sichtbarkeit
    if [ "$(tput colors 2>/dev/null || echo 8)" -ge 256 ]; then
        # Terminal-Hintergrund und -Vordergrund
        printf '\033]11;#2E3440\007'  # Nord0 Background
        printf '\033]10;#ECEFF4\007'  # Nord6 Foreground (heller für besseren Kontrast)
        printf '\033]12;#88C0D0\007'  # Nord8 Cursor
        
        # Optimierte 16-Farben-Palette
        printf '\033]4;0;#2E3440\007'   # black -> nord0 (dunkler)
        printf '\033]4;1;#BF616A\007'   # red -> nord11
        printf '\033]4;2;#A3BE8C\007'   # green -> nord14
        printf '\033]4;3;#EBCB8B\007'   # yellow -> nord13
        printf '\033]4;4;#5E81AC\007'   # blue -> nord10
        printf '\033]4;5;#B48EAD\007'   # magenta -> nord15
        printf '\033]4;6;#88C0D0\007'   # cyan -> nord8
        printf '\033]4;7;#ECEFF4\007'   # white -> nord6 (heller)
        printf '\033]4;8;#4C566A\007'   # bright black -> nord3
        printf '\033]4;9;#D08770\007'   # bright red -> nord12
        printf '\033]4;10;#A3BE8C\007'  # bright green -> nord14
        printf '\033]4;11;#EBCB8B\007'  # bright yellow -> nord13
        printf '\033]4;12;#81A1C1\007'  # bright blue -> nord9
        printf '\033]4;13;#B48EAD\007'  # bright magenta -> nord15
        printf '\033]4;14;#8FBCBB\007'  # bright cyan -> nord7
        printf '\033]4;15;#ECEFF4\007'  # bright white -> nord6
    fi
}

# Semantische Dialog-Funktionen mit optimierten Farben
show_optimized_dialog() {
    local type="$1"
    local title="$2"
    local message="$3"
    
    apply_contextual_colors "$type"
    
    case "$type" in
        "success")
            dialog --colors \
                   --backtitle "✅ Success" \
                   --title "[ $title ]" \
                   --msgbox "$message" 8 50
            ;;
        "warning")
            dialog --colors \
                   --backtitle "⚠️ Warning" \
                   --title "[ $title ]" \
                   --msgbox "$message" 8 50
            ;;
        "error")
            dialog --colors \
                   --backtitle "❌ Error" \
                   --title "[ $title ]" \
                   --msgbox "$message" 8 50
            ;;
        "info")
            apply_contextual_colors "default"
            dialog --colors \
                   --backtitle "ℹ️ Information" \
                   --title "[ $title ]" \
                   --msgbox "$message" 8 50
            ;;
    esac
    
    rm -f "$DIALOGRC"
}

# Optimiertes Hauptmenü mit semantischen Farben
show_optimized_main_menu() {
    apply_contextual_colors "default"
    
    # Verwende Dialog-Farbcodes für semantische Menü-Items
    dialog --colors \
           --backtitle "ExaPG v2.0.0 - Optimized Nord Theme" \
           --title "[ ExaPG Management Console ]" \
           --cancel-label "Exit" \
           --menu "Select an option:" 16 70 6 \
           "1" "\Z4🔧 Installation Wizard\Zn" \
           "2" "\Z6⚙️ Configuration Management\Zn" \
           "3" "\Z2📊 System Status & Services\Zn" \
           "4" "\Z5👤 Profile Management\Zn" \
           "5" "\Z3🎨 Theme Settings\Zn" \
           "6" "\Z7ℹ️ System Information\Zn"
}

# Optimierte Status-Anzeige mit dynamischen Farben
show_optimized_status() {
    apply_contextual_colors "status"
    
    # Sammle System-Informationen (vereinfacht für Kompatibilität)
    local cpu_usage="26.6"
    local mem_usage="26.3"
    local disk_usage="28"
    
    # Dynamische Farbkodierung basierend auf Werten
    local cpu_color="\Z2"  # Grün
    local mem_color="\Z2"  # Grün
    local disk_color="\Z2" # Grün
    
    # Farben basierend auf Schwellenwerten anpassen (vereinfacht)
    if [ "${cpu_usage%.*}" -gt 70 ]; then cpu_color="\Z1"; fi  # Rot
    if [ "${cpu_usage%.*}" -gt 50 ]; then cpu_color="\Z3"; fi  # Gelb
    
    if [ "${mem_usage%.*}" -gt 80 ]; then mem_color="\Z1"; fi  # Rot
    if [ "${mem_usage%.*}" -gt 60 ]; then mem_color="\Z3"; fi  # Gelb
    
    if [ "$disk_usage" -gt 80 ]; then disk_color="\Z1"; fi  # Rot
    if [ "$disk_usage" -gt 60 ]; then disk_color="\Z3"; fi  # Gelb
    
    local status_text="SYSTEM RESOURCE OVERVIEW
==========================================

${cpu_color}CPU USAGE: ${cpu_usage}%\Zn
${mem_color}MEMORY USAGE: ${mem_usage}%\Zn
${disk_color}DISK USAGE: ${disk_usage}%\Zn
LOAD AVERAGE: 1.07, 1.11, 1.04

DOCKER CONTAINERS:
\Z2exapg-coordinator Up 2 days (healthy)\Zn

==========================================
Press OK to continue..."

    dialog --colors \
           --backtitle "ExaPG > System Status > Resources" \
           --title "[ System Status ]" \
           --msgbox "$status_text" 16 50
    
    rm -f "$DIALOGRC"
}

# Demo der optimierten Themes
demo_optimized_themes() {
    echo "🎨 Optimized Nord Theme Demo"
    echo "============================="
    
    # Terminal-Farben optimiert setzen
    apply_optimized_terminal_colors
    
    echo "1. Standard optimiertes Menü..."
    sleep 1
    show_optimized_main_menu
    
    echo "2. Optimierte Status-Anzeige..."
    sleep 1
    show_optimized_status
    
    echo "3. Semantische Dialog-Typen..."
    sleep 1
    
    show_optimized_dialog "success" "Operation Successful" "✅ Die Operation wurde erfolgreich abgeschlossen!\n\nAlle Änderungen wurden gespeichert."
    
    show_optimized_dialog "warning" "Attention Required" "⚠️ Achtung: Hohe CPU-Auslastung erkannt!\n\nBitte überprüfen Sie die laufenden Prozesse."
    
    show_optimized_dialog "error" "Critical Error" "❌ Kritischer Fehler aufgetreten!\n\nDie Datenbankverbindung konnte nicht hergestellt werden."
    
    show_optimized_dialog "info" "Information" "ℹ️ System-Information\n\nExaPG läuft stabil mit optimierten Nord-Farben."
    
    clear
    echo "✅ Optimized Nord Theme Demo abgeschlossen!"
    echo
    echo "Verbesserungen:"
    echo "🔵 CYAN - Verstärkte primäre Navigation"
    echo "🔷 BLUE - Klarere strukturelle Elemente"
    echo "🟢 GREEN - Dynamische Status-Farben"
    echo "🟡 YELLOW - Aufmerksamkeits-Optimierung"
    echo "🔴 RED - Kritische Aktionen hervorgehoben"
    echo "🟣 MAGENTA - Verbesserte Info-Darstellung"
}

# Integration in ExaPG
apply_optimized_theme_to_exapg() {
    echo "🔧 Applying Optimized Nord Theme to ExaPG..."
    
    # Backup erstellen
    if [ ! -f scripts/cli/terminal-ui.sh.optimized-backup ]; then
        cp scripts/cli/terminal-ui.sh scripts/cli/terminal-ui.sh.optimized-backup
        echo "📁 Optimized backup created"
    fi
    
    # Optimierte Theme-Funktion hinzufügen
    cat >> scripts/cli/terminal-ui.sh << 'EOF'

# ═══════════════════════════════════════════════════════════════
# OPTIMIZED NORD THEME INTEGRATION - Enhanced semantic colors
# ═══════════════════════════════════════════════════════════════

# Optimized Nord Theme Generator
generate_optimized_nord_theme() {
EOF
    generate_optimized_nord_theme | sed 's/^/    /' >> scripts/cli/terminal-ui.sh
    cat >> scripts/cli/terminal-ui.sh << 'EOF'
}

# Enhanced color application
apply_optimized_terminal_colors() {
EOF
    declare -f apply_optimized_terminal_colors | sed '1,2d;$d' | sed 's/^/    /' >> scripts/cli/terminal-ui.sh
    cat >> scripts/cli/terminal-ui.sh << 'EOF'
}

# Contextual color application
apply_contextual_colors() {
EOF
    declare -f apply_contextual_colors | sed '1,2d;$d' | sed 's/^/    /' >> scripts/cli/terminal-ui.sh
    cat >> scripts/cli/terminal-ui.sh << 'EOF'
}
EOF
    
    # Bestehende Funktionen optimieren
    sed -i 's/generate_modern_nord_dark_theme/generate_optimized_nord_theme/g' scripts/cli/terminal-ui.sh
    sed -i 's/apply_nord_terminal_colors/apply_optimized_terminal_colors/g' scripts/cli/terminal-ui.sh
    
    echo "✅ Optimized Nord Theme successfully integrated!"
    echo "   Enhanced features:"
    echo "   • Verstärkte semantische Farben"
    echo "   • Kontextuelle Theme-Anpassung"
    echo "   • Dynamische Status-Farbkodierung"
    echo "   • Verbesserte Benutzerfreundlichkeit"
}

# Hauptmenü
main() {
    clear
    echo -e "\033[38;2;136;192;208m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;235;203;139m🎨 Optimized Nord Theme für ExaPG\033[0m                       \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;229;233;240mBehebt monotone Farben & verstärkt Semantik\033[0m             \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo
    echo -e "\033[38;2;163;190;140m1)\033[0m \033[38;2;229;233;240mDemo - Zeige optimierte Themes\033[0m"
    echo -e "\033[38;2;163;190;140m2)\033[0m \033[38;2;229;233;240mApply - Integriere Optimierungen\033[0m"
    echo -e "\033[38;2;163;190;140m3)\033[0m \033[38;2;229;233;240mRestore - Backup wiederherstellen\033[0m"
    echo -e "\033[38;2;191;97;106m0)\033[0m \033[38;2;229;233;240mExit\033[0m"
    echo
    
    read -p "$(echo -e '\033[38;2;136;192;208mWähle Option (0-3):\033[0m ') " choice
    
    case $choice in
        1) demo_optimized_themes ;;
        2) apply_optimized_theme_to_exapg ;;
        3) 
            if [ -f scripts/cli/terminal-ui.sh.optimized-backup ]; then
                cp scripts/cli/terminal-ui.sh.optimized-backup scripts/cli/terminal-ui.sh
                echo "✅ Optimized backup restored!"
            else
                echo "❌ No optimized backup found!"
            fi
            ;;
        0) echo -e "\033[38;2;163;190;140m✅ Auf Wiedersehen!\033[0m"; exit 0 ;;
        *) echo -e "\033[38;2;191;97;106m❌ Ungültige Option\033[0m" ;;
    esac
}

# Export functions
export -f generate_optimized_nord_theme
export -f apply_contextual_colors
export -f apply_optimized_terminal_colors
export -f show_optimized_dialog

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi 