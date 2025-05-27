#!/bin/bash
# Simple Nord Fix - Startet ExaPG ohne Dialog-Fehler

echo "🔧 Simple Nord Fix - Behebt alle Dialog-Probleme"
echo "================================================"

# 1. Alle defekten Dialog-Dateien löschen
rm -f /tmp/exapg_dialogrc_* /tmp/contextual_dialogrc_*

# 2. Erstelle einfache, funktionierende Dialog-Konfiguration
cat > /tmp/simple_nord << 'EOF'
use_colors = ON
use_shadow = ON
screen_color = (WHITE,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,ON)
title_color = (CYAN,BLACK,ON)
border_color = (CYAN,BLACK,ON)
border2_color = (BLUE,BLACK,ON)
button_active_color = (BLACK,GREEN,ON)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,YELLOW,ON)
button_key_inactive_color = (YELLOW,BLACK,ON)
button_label_active_color = (BLACK,GREEN,ON)
button_label_inactive_color = (CYAN,BLACK,OFF)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,ON)
menubox_border2_color = (BLUE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,CYAN,ON)
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,YELLOW,ON)
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,ON)
inputbox_border2_color = (BLUE,BLACK,ON)
form_active_text_color = (BLACK,CYAN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (BLUE,BLACK,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)
gauge_color = (BLACK,CYAN,ON)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (MAGENTA,BLACK,ON)
searchbox_border_color = (CYAN,BLACK,ON)
searchbox_border2_color = (BLUE,BLACK,ON)
position_indicator_color = (GREEN,BLACK,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)
itemhelp_color = (MAGENTA,BLACK,ON)
EOF

# 3. Setze Umgebungsvariablen
export DIALOGRC="/tmp/simple_nord"
export DIALOGOPTS="--colors --no-shadow"

echo "✅ Simple Nord Fix abgeschlossen!"
echo ""
echo "Starte ExaPG mit funktionierendem Theme:"
echo "DIALOGRC=/tmp/simple_nord ./exapg"
echo ""

# 4. Starte ExaPG direkt
DIALOGRC=/tmp/simple_nord ./exapg 