#!/bin/bash
# Modern Nord Theme für ExaPG - Optimierte Version mit semantischen Farben
# Behebt Monotonie und fügt moderne UI-Hierarchie hinzu

# Moderne Nord Dark Theme Generator mit semantischen Farben
generate_modern_nord_dark_theme() {
    cat << 'EOF'
# ExaPG Modern Nord Dark Theme v3.0 - SEMANTIC COLORS
# Optimiert für moderne UI-Hierarchie und bessere UX
# https://nordtheme.com

# Dialog-Verhalten
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# ═══════════════════════════════════════════════════════════════
# MODERNE NORD FARBSTRATEGIE - SEMANTISCHE HIERARCHIE
# ═══════════════════════════════════════════════════════════════
# 🔵 PRIMÄR: CYAN (Nord8) - Hauptaktionen, wichtige Navigation
# 🔷 SEKUNDÄR: BLUE (Nord10) - Strukturelemente, Borders
# 🟢 ERFOLG: GREEN (Nord14) - Positive Aktionen, Bestätigungen
# 🟡 WARNUNG: YELLOW (Nord13) - Aufmerksamkeit, Shortcuts
# 🔴 FEHLER: RED (Nord11) - Kritische Aktionen, Probleme
# 🟣 INFO: MAGENTA (Nord15) - Spezielle Informationen, Hilfe
# ⚪ TEXT: WHITE (Nord5/6) - Standard Text, Lesbarkeit
# ⚫ HINTERGRUND: BLACK (Nord0/1) - Basis, Struktur
# ═══════════════════════════════════════════════════════════════

# BASIS LAYOUT - Moderner Nord Look
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# TITEL & BORDERS - Hierarchische Frost-Farben
title_color = (CYAN,BLACK,ON)           # 🔵 Primäre Aufmerksamkeit
border_color = (BLUE,BLACK,ON)          # 🔷 Strukturelle Elemente
border2_color = (CYAN,BLACK,DIM)        # 🔵 Sekundäre Borders

# BUTTONS - Semantische Farbkodierung nach Funktion
button_active_color = (BLACK,GREEN,ON)      # 🟢 Erfolg-Grün für aktive Buttons
button_inactive_color = (BLUE,BLACK,OFF)    # 🔷 Gedämpftes Blau für inaktive
button_key_active_color = (BLACK,YELLOW,ON) # 🟡 Gelb für Keyboard-Shortcuts
button_key_inactive_color = (YELLOW,BLACK,DIM) # 🟡 Gedämpfte Shortcuts
button_label_active_color = (BLACK,GREEN,ON)    # 🟢 Konsistent mit Button
button_label_inactive_color = (WHITE,BLACK,OFF) # ⚪ Standard Text

# MENU SYSTEM - Moderne Hierarchie mit Farbdifferenzierung
menubox_color = (WHITE,BLACK,OFF)           # ⚪ Standard Hintergrund
menubox_border_color = (BLUE,BLACK,ON)      # 🔷 Strukturelle Begrenzung
menubox_border2_color = (CYAN,BLACK,ON)     # 🔵 Akzent-Border
item_color = (WHITE,BLACK,OFF)              # ⚪ Standard Menü-Items
item_selected_color = (BLACK,CYAN,ON)       # 🔵 Primäre Selektion

# TAG SYSTEM - Aufmerksamkeits-Gelb für wichtige Elemente
tag_color = (YELLOW,BLACK,ON)               # 🟡 Auffällige Tags
tag_selected_color = (BLACK,YELLOW,ON)      # 🟡 Invertierte Selektion
tag_key_color = (YELLOW,BLACK,ON)           # 🟡 Konsistente Shortcuts
tag_key_selected_color = (BLACK,YELLOW,ON)  # 🟡 Aktive Shortcuts

# EINGABEFELDER - Moderne Input-Ästhetik
inputbox_color = (WHITE,BLACK,OFF)          # ⚪ Standard Input
inputbox_border_color = (CYAN,BLACK,ON)     # 🔵 Primäre Input-Borders
inputbox_border2_color = (BLUE,BLACK,ON)    # 🔷 Sekundäre Struktur
form_active_text_color = (BLACK,CYAN,ON)    # 🔵 Aktive Eingabe
form_text_color = (WHITE,BLACK,OFF)         # ⚪ Standard Text
form_item_readonly_color = (BLUE,BLACK,DIM) # 🔷 Readonly-Felder

# CHECKBOXEN & AUSWAHL - Semantisches Grün für Bestätigung
check_color = (WHITE,BLACK,OFF)             # ⚪ Unselected
check_selected_color = (BLACK,GREEN,ON)     # 🟢 Erfolg-Grün für Selected

# PROGRESS & GAUGE - Dynamische Fortschrittsanzeige
gauge_color = (BLACK,CYAN,ON)               # 🔵 Primärer Fortschritt

# SUCHFUNKTION - Spezialisierte Such-UI
searchbox_color = (WHITE,BLACK,OFF)         # ⚪ Such-Hintergrund
searchbox_title_color = (MAGENTA,BLACK,ON)  # 🟣 Info-Magenta für Such-Titel
searchbox_border_color = (CYAN,BLACK,ON)    # 🔵 Primäre Such-Border
searchbox_border2_color = (BLUE,BLACK,ON)   # 🔷 Sekundäre Struktur

# NAVIGATION - Bewegungs-Grün für Richtungsanzeigen
position_indicator_color = (GREEN,BLACK,ON) # 🟢 Positions-Indikator
uarrow_color = (GREEN,BLACK,ON)             # 🟢 Aufwärts-Pfeil
darrow_color = (GREEN,BLACK,ON)             # 🟢 Abwärts-Pfeil

# HILFE & SEKUNDÄRE ELEMENTE - Info-Magenta für Hilfe
itemhelp_color = (MAGENTA,BLACK,DIM)        # 🟣 Hilfe-Text

# ERWEITERTE SEMANTISCHE ELEMENTE
# Kalender - Spezialisierte Farben für Zeitangaben
week_number_color = (MAGENTA,BLACK,ON)      # 🟣 Wochen-Info
weekday_color = (BLUE,BLACK,ON)             # 🔷 Wochentage
day_color = (WHITE,BLACK,OFF)               # ⚪ Standard Tage
day_selected_color = (BLACK,CYAN,ON)        # 🔵 Ausgewählter Tag
month_color = (CYAN,BLACK,ON)               # 🔵 Monat-Header
year_color = (YELLOW,BLACK,ON)              # 🟡 Jahr-Anzeige

# Text-Viewer - Optimiert für Lesbarkeit
textbox_color = (WHITE,BLACK,OFF)           # ⚪ Text-Hintergrund
textbox_border_color = (BLUE,BLACK,ON)      # 🔷 Text-Border
textbox_border2_color = (CYAN,BLACK,DIM)    # 🔵 Sekundäre Text-Border

# SPEZIELLE DIALOG-TYPEN - Semantische Farbkodierung
# Erfolgs-Dialoge
success_dialog_color = (WHITE,GREEN,OFF)    # 🟢 Erfolgs-Hintergrund
success_border_color = (GREEN,BLACK,ON)     # 🟢 Erfolgs-Border
success_title_color = (BLACK,GREEN,ON)      # 🟢 Erfolgs-Titel

# Warn-Dialoge
warning_dialog_color = (BLACK,YELLOW,OFF)   # 🟡 Warn-Hintergrund
warning_border_color = (YELLOW,BLACK,ON)    # 🟡 Warn-Border
warning_title_color = (BLACK,YELLOW,ON)     # 🟡 Warn-Titel

# Fehler-Dialoge
error_dialog_color = (WHITE,RED,OFF)        # 🔴 Fehler-Hintergrund
error_border_color = (RED,BLACK,ON)         # 🔴 Fehler-Border
error_title_color = (WHITE,RED,ON)          # 🔴 Fehler-Titel

# Info-Dialoge
info_dialog_color = (WHITE,MAGENTA,OFF)     # 🟣 Info-Hintergrund
info_border_color = (MAGENTA,BLACK,ON)      # 🟣 Info-Border
info_title_color = (WHITE,MAGENTA,ON)       # 🟣 Info-Titel

EOF
}

# Erweiterte Dialog-Funktionen mit semantischen Farben
show_success_dialog() {
    local title="$1"
    local message="$2"
    
    # Temporäre DIALOGRC für Erfolgs-Dialog
    local temp_dialogrc="/tmp/success_dialogrc_$$"
    generate_modern_nord_dark_theme > "$temp_dialogrc"
    
    # Erfolgs-spezifische Anpassungen
    cat >> "$temp_dialogrc" << 'EOF'
# Erfolgs-Dialog Overrides
dialog_color = (WHITE,GREEN,OFF)
title_color = (BLACK,GREEN,ON)
border_color = (GREEN,BLACK,ON)
button_active_color = (BLACK,GREEN,ON)
EOF
    
    DIALOGRC="$temp_dialogrc" dialog \
        --colors \
        --backtitle "✅ Success" \
        --title "[ $title ]" \
        --msgbox "$message" 8 50
    
    rm -f "$temp_dialogrc"
}

show_warning_dialog() {
    local title="$1"
    local message="$2"
    
    local temp_dialogrc="/tmp/warning_dialogrc_$$"
    generate_modern_nord_dark_theme > "$temp_dialogrc"
    
    cat >> "$temp_dialogrc" << 'EOF'
# Warn-Dialog Overrides
dialog_color = (BLACK,YELLOW,OFF)
title_color = (BLACK,YELLOW,ON)
border_color = (YELLOW,BLACK,ON)
button_active_color = (BLACK,YELLOW,ON)
EOF
    
    DIALOGRC="$temp_dialogrc" dialog \
        --colors \
        --backtitle "⚠️ Warning" \
        --title "[ $title ]" \
        --msgbox "$message" 8 50
    
    rm -f "$temp_dialogrc"
}

show_error_dialog() {
    local title="$1"
    local message="$2"
    
    local temp_dialogrc="/tmp/error_dialogrc_$$"
    generate_modern_nord_dark_theme > "$temp_dialogrc"
    
    cat >> "$temp_dialogrc" << 'EOF'
# Fehler-Dialog Overrides
dialog_color = (WHITE,RED,OFF)
title_color = (WHITE,RED,ON)
border_color = (RED,BLACK,ON)
button_active_color = (BLACK,RED,ON)
EOF
    
    DIALOGRC="$temp_dialogrc" dialog \
        --colors \
        --backtitle "❌ Error" \
        --title "[ $title ]" \
        --msgbox "$message" 8 50
    
    rm -f "$temp_dialogrc"
}

show_info_dialog() {
    local title="$1"
    local message="$2"
    
    local temp_dialogrc="/tmp/info_dialogrc_$$"
    generate_modern_nord_dark_theme > "$temp_dialogrc"
    
    cat >> "$temp_dialogrc" << 'EOF'
# Info-Dialog Overrides
dialog_color = (WHITE,MAGENTA,OFF)
title_color = (WHITE,MAGENTA,ON)
border_color = (MAGENTA,BLACK,ON)
button_active_color = (BLACK,MAGENTA,ON)
EOF
    
    DIALOGRC="$temp_dialogrc" dialog \
        --colors \
        --backtitle "ℹ️ Information" \
        --title "[ $title ]" \
        --msgbox "$message" 8 50
    
    rm -f "$temp_dialogrc"
}

# Demo der modernen semantischen Farben
demo_modern_nord_theme() {
    echo "🎨 Modern Nord Theme Demo - Semantische Farben"
    echo "=============================================="
    
    # Terminal auf Nord umstellen
    printf '\033]11;#2E3440\007'  # Nord0 Background
    printf '\033]10;#D8DEE9\007'  # Nord4 Foreground
    
    # Standard Dialog mit modernem Theme
    export DIALOGRC="/tmp/modern_nord_dialogrc"
    generate_modern_nord_dark_theme > "$DIALOGRC"
    export DIALOGOPTS="--colors --no-shadow"
    
    # Demo-Sequenz
    dialog --colors \
           --backtitle "Modern Nord Theme Demo" \
           --title "🔵 Standard Dialog (Cyan)" \
           --msgbox "Dies ist ein Standard-Dialog mit Cyan-Akzenten.\n\nBeachten Sie:\n• Cyan Borders (Primär)\n• Blue Struktur (Sekundär)\n• Grüne Buttons (Erfolg)" 12 50
    
    show_success_dialog "Erfolg Dialog" "✅ Operation erfolgreich!\n\nGrüne Farben signalisieren Erfolg und positive Aktionen."
    
    show_warning_dialog "Warnung Dialog" "⚠️ Achtung erforderlich!\n\nGelbe Farben ziehen Aufmerksamkeit auf wichtige Informationen."
    
    show_error_dialog "Fehler Dialog" "❌ Ein Fehler ist aufgetreten!\n\nRote Farben signalisieren Probleme und kritische Situationen."
    
    show_info_dialog "Info Dialog" "ℹ️ Zusätzliche Information\n\nMagenta wird für spezielle Informationen und Hilfe verwendet."
    
    # Cleanup
    rm -f "$DIALOGRC"
    clear
    
    echo "✅ Modern Nord Theme Demo abgeschlossen!"
    echo
    echo "Semantische Farbkodierung:"
    echo "🔵 CYAN - Primäre Aktionen, Navigation"
    echo "🔷 BLUE - Strukturelemente, Borders"  
    echo "🟢 GREEN - Erfolg, positive Aktionen"
    echo "🟡 YELLOW - Warnungen, Aufmerksamkeit"
    echo "🔴 RED - Fehler, kritische Aktionen"
    echo "🟣 MAGENTA - Info, Hilfe, Spezialfunktionen"
}

# Integration in ExaPG - SICHERE VERSION
apply_modern_nord_to_exapg() {
    echo "🔧 Applying Modern Nord Theme to ExaPG..."
    
    # Backup der aktuellen terminal-ui.sh
    if [ ! -f scripts/cli/terminal-ui.sh.backup ]; then
        cp scripts/cli/terminal-ui.sh scripts/cli/terminal-ui.sh.backup
        echo "📁 Backup created: scripts/cli/terminal-ui.sh.backup"
    fi
    
    # Prüfe ob die moderne Theme-Funktion bereits existiert
    if grep -q "generate_modern_nord_dark_theme" scripts/cli/terminal-ui.sh; then
        echo "✅ Modern Nord Theme already integrated!"
        return 0
    fi
    
    # Sichere Integration: Füge die moderne Theme-Funktion am Ende hinzu
    echo "" >> scripts/cli/terminal-ui.sh
    echo "# ═══════════════════════════════════════════════════════════════" >> scripts/cli/terminal-ui.sh
    echo "# MODERN NORD THEME INTEGRATION - Added by nord-theme-modern.sh" >> scripts/cli/terminal-ui.sh
    echo "# ═══════════════════════════════════════════════════════════════" >> scripts/cli/terminal-ui.sh
    echo "" >> scripts/cli/terminal-ui.sh
    
    # Moderne Theme-Funktion hinzufügen
    cat >> scripts/cli/terminal-ui.sh << 'EOF'
# Modern Nord Theme Generator (injected by nord-theme-modern.sh)
generate_modern_nord_dark_theme() {
    cat << 'THEME_EOF'
# ExaPG Modern Nord Dark Theme v3.0 - SEMANTIC COLORS
# Optimiert für moderne UI-Hierarchie und bessere UX
# https://nordtheme.com

# Dialog-Verhalten
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = ON
use_shadow = ON
use_colors = ON

# ═══════════════════════════════════════════════════════════════
# MODERNE NORD FARBSTRATEGIE - SEMANTISCHE HIERARCHIE
# ═══════════════════════════════════════════════════════════════
# 🔵 PRIMÄR: CYAN (Nord8) - Hauptaktionen, wichtige Navigation
# 🔷 SEKUNDÄR: BLUE (Nord10) - Strukturelemente, Borders
# 🟢 ERFOLG: GREEN (Nord14) - Positive Aktionen, Bestätigungen
# 🟡 WARNUNG: YELLOW (Nord13) - Aufmerksamkeit, Shortcuts
# 🔴 FEHLER: RED (Nord11) - Kritische Aktionen, Probleme
# 🟣 INFO: MAGENTA (Nord15) - Spezielle Informationen, Hilfe
# ⚪ TEXT: WHITE (Nord5/6) - Standard Text, Lesbarkeit
# ⚫ HINTERGRUND: BLACK (Nord0/1) - Basis, Struktur
# ═══════════════════════════════════════════════════════════════

# BASIS LAYOUT - Moderner Nord Look
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (WHITE,BLACK,OFF)

# TITEL & BORDERS - Hierarchische Frost-Farben
title_color = (CYAN,BLACK,ON)           # 🔵 Primäre Aufmerksamkeit
border_color = (BLUE,BLACK,ON)          # 🔷 Strukturelle Elemente
border2_color = (CYAN,BLACK,DIM)        # 🔵 Sekundäre Borders

# BUTTONS - Semantische Farbkodierung nach Funktion
button_active_color = (BLACK,GREEN,ON)      # 🟢 Erfolg-Grün für aktive Buttons
button_inactive_color = (BLUE,BLACK,OFF)    # 🔷 Gedämpftes Blau für inaktive
button_key_active_color = (BLACK,YELLOW,ON) # 🟡 Gelb für Keyboard-Shortcuts
button_key_inactive_color = (YELLOW,BLACK,DIM) # 🟡 Gedämpfte Shortcuts
button_label_active_color = (BLACK,GREEN,ON)    # 🟢 Konsistent mit Button
button_label_inactive_color = (WHITE,BLACK,OFF) # ⚪ Standard Text

# MENU SYSTEM - Moderne Hierarchie mit Farbdifferenzierung
menubox_color = (WHITE,BLACK,OFF)           # ⚪ Standard Hintergrund
menubox_border_color = (BLUE,BLACK,ON)      # 🔷 Strukturelle Begrenzung
menubox_border2_color = (CYAN,BLACK,ON)     # 🔵 Akzent-Border
item_color = (WHITE,BLACK,OFF)              # ⚪ Standard Menü-Items
item_selected_color = (BLACK,CYAN,ON)       # 🔵 Primäre Selektion

# TAG SYSTEM - Aufmerksamkeits-Gelb für wichtige Elemente
tag_color = (YELLOW,BLACK,ON)               # 🟡 Auffällige Tags
tag_selected_color = (BLACK,YELLOW,ON)      # 🟡 Invertierte Selektion
tag_key_color = (YELLOW,BLACK,ON)           # 🟡 Konsistente Shortcuts
tag_key_selected_color = (BLACK,YELLOW,ON)  # 🟡 Aktive Shortcuts

# EINGABEFELDER - Moderne Input-Ästhetik
inputbox_color = (WHITE,BLACK,OFF)          # ⚪ Standard Input
inputbox_border_color = (CYAN,BLACK,ON)     # 🔵 Primäre Input-Borders
inputbox_border2_color = (BLUE,BLACK,ON)    # 🔷 Sekundäre Struktur
form_active_text_color = (BLACK,CYAN,ON)    # 🔵 Aktive Eingabe
form_text_color = (WHITE,BLACK,OFF)         # ⚪ Standard Text
form_item_readonly_color = (BLUE,BLACK,DIM) # 🔷 Readonly-Felder

# CHECKBOXEN & AUSWAHL - Semantisches Grün für Bestätigung
check_color = (WHITE,BLACK,OFF)             # ⚪ Unselected
check_selected_color = (BLACK,GREEN,ON)     # 🟢 Erfolg-Grün für Selected

# PROGRESS & GAUGE - Dynamische Fortschrittsanzeige
gauge_color = (BLACK,CYAN,ON)               # 🔵 Primärer Fortschritt

# SUCHFUNKTION - Spezialisierte Such-UI
searchbox_color = (WHITE,BLACK,OFF)         # ⚪ Such-Hintergrund
searchbox_title_color = (MAGENTA,BLACK,ON)  # 🟣 Info-Magenta für Such-Titel
searchbox_border_color = (CYAN,BLACK,ON)    # 🔵 Primäre Such-Border
searchbox_border2_color = (BLUE,BLACK,ON)   # 🔷 Sekundäre Struktur

# NAVIGATION - Bewegungs-Grün für Richtungsanzeigen
position_indicator_color = (GREEN,BLACK,ON) # 🟢 Positions-Indikator
uarrow_color = (GREEN,BLACK,ON)             # 🟢 Aufwärts-Pfeil
darrow_color = (GREEN,BLACK,ON)             # 🟢 Abwärts-Pfeil

# HILFE & SEKUNDÄRE ELEMENTE - Info-Magenta für Hilfe
itemhelp_color = (MAGENTA,BLACK,DIM)        # 🟣 Hilfe-Text

# ERWEITERTE SEMANTISCHE ELEMENTE
# Kalender - Spezialisierte Farben für Zeitangaben
week_number_color = (MAGENTA,BLACK,ON)      # 🟣 Wochen-Info
weekday_color = (BLUE,BLACK,ON)             # 🔷 Wochentage
day_color = (WHITE,BLACK,OFF)               # ⚪ Standard Tage
day_selected_color = (BLACK,CYAN,ON)        # 🔵 Ausgewählter Tag
month_color = (CYAN,BLACK,ON)               # 🔵 Monat-Header
year_color = (YELLOW,BLACK,ON)              # 🟡 Jahr-Anzeige

# Text-Viewer - Optimiert für Lesbarkeit
textbox_color = (WHITE,BLACK,OFF)           # ⚪ Text-Hintergrund
textbox_border_color = (BLUE,BLACK,ON)      # 🔷 Text-Border
textbox_border2_color = (CYAN,BLACK,DIM)    # 🔵 Sekundäre Text-Border

# SPEZIELLE DIALOG-TYPEN - Semantische Farbkodierung
# Erfolgs-Dialoge
success_dialog_color = (WHITE,GREEN,OFF)    # 🟢 Erfolgs-Hintergrund
success_border_color = (GREEN,BLACK,ON)     # 🟢 Erfolgs-Border
success_title_color = (BLACK,GREEN,ON)      # 🟢 Erfolgs-Titel

# Warn-Dialoge
warning_dialog_color = (BLACK,YELLOW,OFF)   # 🟡 Warn-Hintergrund
warning_border_color = (YELLOW,BLACK,ON)    # 🟡 Warn-Border
warning_title_color = (BLACK,YELLOW,ON)     # 🟡 Warn-Titel

# Fehler-Dialoge
error_dialog_color = (WHITE,RED,OFF)        # 🔴 Fehler-Hintergrund
error_border_color = (RED,BLACK,ON)         # 🔴 Fehler-Border
error_title_color = (WHITE,RED,ON)          # 🔴 Fehler-Titel

# Info-Dialoge
info_dialog_color = (WHITE,MAGENTA,OFF)     # 🟣 Info-Hintergrund
info_border_color = (MAGENTA,BLACK,ON)      # 🟣 Info-Border
info_title_color = (WHITE,MAGENTA,ON)       # 🟣 Info-Titel

THEME_EOF
}
EOF
    
    # Jetzt die bestehende generate_nord_dark_theme Funktion modifizieren
    # Sichere Methode: Erstelle eine temporäre Datei
    local temp_file="/tmp/terminal_ui_modified_$$"
    
    # Kopiere alles bis zur generate_nord_dark_theme Funktion
    awk '
    /^# Nord Dark Theme Generator - MODERN OPTIMIZED$/ { 
        print "# Nord Dark Theme Generator - MODERN OPTIMIZED"
        print "generate_nord_dark_theme() {"
        print "    generate_modern_nord_dark_theme"
        print "}"
        # Überspringe die alte Funktion bis zur nächsten Funktion
        while (getline > 0 && !/^}$/) { }
        next
    }
    /^generate_nord_dark_theme\(\) \{$/ {
        print "# Nord Dark Theme Generator - MODERN OPTIMIZED"
        print "generate_nord_dark_theme() {"
        print "    generate_modern_nord_dark_theme"
        print "}"
        # Überspringe die alte Funktion bis zur schließenden Klammer
        while (getline > 0 && !/^}$/) { }
        next
    }
    { print }
    ' scripts/cli/terminal-ui.sh > "$temp_file"
    
    # Ersetze die Originaldatei
    mv "$temp_file" scripts/cli/terminal-ui.sh
    chmod +x scripts/cli/terminal-ui.sh
    
    echo "✅ Modern Nord Theme successfully integrated!"
    echo "   Original backup: scripts/cli/terminal-ui.sh.backup"
    echo "   Integration method: Safe append + function redirect"
    echo ""
    echo "🎨 The modern theme is now active with:"
    echo "   🔵 CYAN - Primary actions, navigation"
    echo "   🔷 BLUE - Structural elements, borders"  
    echo "   🟢 GREEN - Success, positive actions"
    echo "   🟡 YELLOW - Warnings, attention"
    echo "   🔴 RED - Errors, critical actions"
    echo "   🟣 MAGENTA - Info, help, special functions"
}

# Hauptmenü
main() {
    clear
    echo -e "\033[38;2;136;192;208m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;235;203;139m🎨 Modern Nord Theme für ExaPG\033[0m                          \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m  \033[38;2;229;233;240mSemantische Farben & moderne UI-Hierarchie\033[0m              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m║\033[0m                                                              \033[38;2;136;192;208m║\033[0m"
    echo -e "\033[38;2;136;192;208m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo
    echo -e "\033[38;2;163;190;140m1)\033[0m \033[38;2;229;233;240mDemo - Zeige semantische Farben\033[0m"
    echo -e "\033[38;2;163;190;140m2)\033[0m \033[38;2;229;233;240mApply - Integriere in ExaPG\033[0m"
    echo -e "\033[38;2;163;190;140m3)\033[0m \033[38;2;229;233;240mRestore - Backup wiederherstellen\033[0m"
    echo -e "\033[38;2;191;97;106m0)\033[0m \033[38;2;229;233;240mExit\033[0m"
    echo
    
    read -p "$(echo -e '\033[38;2;136;192;208mWähle Option (0-3):\033[0m ') " choice
    
    case $choice in
        1) demo_modern_nord_theme ;;
        2) apply_modern_nord_to_exapg ;;
        3) 
            if [ -f scripts/cli/terminal-ui.sh.backup ]; then
                cp scripts/cli/terminal-ui.sh.backup scripts/cli/terminal-ui.sh
                echo "✅ Backup restored!"
            else
                echo "❌ No backup found!"
            fi
            ;;
        0) echo -e "\033[38;2;163;190;140m✅ Auf Wiedersehen!\033[0m"; exit 0 ;;
        *) echo -e "\033[38;2;191;97;106m❌ Ungültige Option\033[0m" ;;
    esac
}

# Export functions
export -f generate_modern_nord_dark_theme
export -f show_success_dialog
export -f show_warning_dialog
export -f show_error_dialog
export -f show_info_dialog

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi 