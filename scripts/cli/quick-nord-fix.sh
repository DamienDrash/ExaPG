#!/bin/bash
# Quick Nord Fix - Sofort sichtbare Verbesserungen

echo "🎨 Quick Nord Fix - Sofortige Verbesserungen"
echo "============================================="

# 1. Terminal-Hintergrund dunkler machen
echo "1. Setze dunkleren Hintergrund..."
printf '\033]11;#1e222a\007'  # Noch dunkler als Nord0

# 2. Logo-Farbe ändern
echo "2. Ändere Logo-Farbe zu Cyan..."
# Das wird in der ASCII-Art-Funktion angewendet

# 3. Sofortige Dialog-Verbesserung
echo "3. Erstelle optimierte Dialog-Konfiguration..."
cat > /tmp/quick_nord_fix << 'EOF'
# Quick Nord Fix - Sofort sichtbare Farben
use_colors = ON
use_shadow = ON

# Dunkler Hintergrund
screen_color = (WHITE,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)

# CYAN Titel und Borders
title_color = (CYAN,BLACK,ON)
border_color = (CYAN,BLACK,ON)
border2_color = (CYAN,BLACK,ON)

# GRÜNE OK-Buttons
button_active_color = (BLACK,GREEN,ON)
button_inactive_color = (CYAN,BLACK,OFF)

# CYAN Menü-Selektion
item_selected_color = (BLACK,CYAN,ON)
menubox_border_color = (CYAN,BLACK,ON)

# GELBE Tags
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,YELLOW,ON)

EOF

export DIALOGRC="/tmp/quick_nord_fix"
export DIALOGOPTS="--colors --no-shadow"

echo "4. Teste die Verbesserungen..."
dialog --colors \
       --backtitle "Quick Nord Fix Demo" \
       --title "[ Sofortige Verbesserungen ]" \
       --msgbox "✅ Verbesserungen angewendet!\n\n🔵 Cyan Titel und Borders\n🟢 Grüne OK-Buttons\n🟡 Gelbe Tags\n⚫ Dunkler Hintergrund\n\nDie Farben sollten jetzt sichtbar sein!" 12 50

echo "✅ Quick Nord Fix abgeschlossen!"
echo ""
echo "Jetzt starten Sie ExaPG:"
echo "./exapg" 