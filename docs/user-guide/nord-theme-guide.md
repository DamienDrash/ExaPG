# 🎨 Nord Dark Theme Guide für ExaPG

## Übersicht

ExaPG verwendet das **Nord Dark Theme** als Standard für die moderne Terminal UI. Das Nord Theme basiert auf der offiziellen [Nord-Farbpalette](https://www.nordtheme.com/) und bietet eine professionelle, augenschonende Arbeitsumgebung.

## 🎯 Aktuelle Nord Implementation

### Standard-Konfiguration

Das Nord Dark Theme ist bereits als Standard in ExaPG konfiguriert:

```bash
# In scripts/cli/terminal-ui.sh
EXAPG_THEME="${EXAPG_THEME:-nord-dark}"
```

### Verfügbare Themes

ExaPG bietet 4 professionelle Themes:

1. **Nord Dark** (Standard) - Professionelles dunkles Theme
2. **Nord Light** - Helles Theme für Tageslicht
3. **Nord High Contrast** - Barrierefreiheit/Accessibility
4. **Classic Terminal** - Retro grün-auf-schwarz

## 🚀 Nord Theme aktivieren

### Option 1: Umgebungsvariable

```bash
export EXAPG_THEME="nord-dark"
./exapg
```

### Option 2: Im laufenden Programm

1. Starten Sie ExaPG: `./exapg`
2. Wählen Sie "5" für "Theme Settings"
3. Wählen Sie "1" für "Nord Dark Theme (Recommended)"

### Option 3: Enhanced Nord Experience

Für die vollständige Nord-Erfahrung verwenden Sie den Nord Terminal Enhancer:

```bash
./scripts/cli/nord-terminal-enhancer.sh
```

## 🎨 Nord Farbpalette

### Polar Night (Dunkle Hintergründe)
- **nord0**: `#2E3440` - Basis Hintergrund
- **nord1**: `#3B4252` - Sekundär Hintergrund
- **nord2**: `#434C5E` - Card/Panel Hintergrund
- **nord3**: `#4C566A` - Subtle Hintergrund

### Snow Storm (Helle Texte)
- **nord4**: `#D8DEE9` - Sekundär Text
- **nord5**: `#E5E9F0` - Standard Text
- **nord6**: `#ECEFF4` - Primär Text

### Frost (Blaue Akzente)
- **nord7**: `#8FBCBB` - Subtle Cyan
- **nord8**: `#88C0D0` - Standard Cyan
- **nord9**: `#81A1C1` - Helles Blau
- **nord10**: `#5E81AC` - Standard Blau

### Aurora (Bunte Akzente)
- **nord11**: `#BF616A` - Fehler/Warnung
- **nord12**: `#D08770` - Orange-ish
- **nord13**: `#EBCB8B` - Highlights
- **nord14**: `#A3BE8C` - Erfolg/Bestätigung
- **nord15**: `#B48EAD` - Spezial/Info

## 🔧 Enhanced Nord Features

### Nord Terminal Enhancer

Das `nord-terminal-enhancer.sh` Script bietet erweiterte Funktionen:

```bash
# Vollständige Nord-Erfahrung
./scripts/cli/nord-terminal-enhancer.sh

# Optionen:
# 1) Apply Nord colors to current terminal
# 2) Create Nord-themed bash prompt  
# 3) Generate terminal profile configurations
# 4) Apply enhanced Nord theme to ExaPG UI
# 5) All of the above
# 6) Test Nord colors
```

### Enhanced Features

1. **Terminal-Farben**: Setzt alle 16 Terminal-Farben auf Nord-Palette
2. **Nord-Prompt**: Erstellt einen Nord-themed Bash-Prompt
3. **Terminal-Profile**: Generiert Profile für iTerm2, Windows Terminal, Gnome Terminal
4. **Enhanced UI**: Verbesserte Dialog-Konfiguration mit optimierten Nord-Farben

### Nord-Styled Status Messages

```bash
# Verwendung der Nord-Status-Funktionen
source scripts/cli/nord-terminal-enhancer.sh

ui_status_nord "info" "Information message"
ui_status_nord "success" "Success message"  
ui_status_nord "warning" "Warning message"
ui_status_nord "error" "Error message"
```

## 📱 Terminal-Kompatibilität

### Unterstützte Terminals

- **Linux**: gnome-terminal, konsole, xterm, terminator
- **macOS**: iTerm2, Terminal.app
- **Windows**: Windows Terminal, WSL
- **SSH**: Vollständig SSH-kompatibel

### Anforderungen

- **256-Farben-Unterstützung**: `tput colors` sollte 256 zeigen
- **UTF-8-Encoding**: Für korrekte Symbol-Darstellung
- **Dialog v1.3+**: Für optimale Theme-Unterstützung

### Terminal-Setup prüfen

```bash
# Farb-Unterstützung prüfen
echo "Terminal colors: $(tput colors)"
echo "Terminal type: $TERM"

# UTF-8 prüfen
echo "Locale: $LC_ALL"

# Dialog-Version prüfen
dialog --version
```

## 🎯 Optimale Einstellungen

### Empfohlene Schriftarten

Für die beste Nord-Erfahrung verwenden Sie eine Monospace-Schrift:

- **JetBrains Mono** (empfohlen)
- **Fira Code**
- **Source Code Pro**
- **Cascadia Code**

### Terminal-Einstellungen

- **Schriftgröße**: 12-14pt
- **Zeilenhöhe**: 1.2-1.4
- **Transparenz**: 90-95% (optional)
- **Blur-Effekt**: Leicht (optional)

### Farbtiefe

```bash
# Optimale Terminal-Konfiguration
export TERM="xterm-256color"
export COLORTERM="truecolor"
```

## 🔧 Anpassungen

### Custom Nord Theme

Sie können das Nord Theme anpassen, indem Sie die `generate_enhanced_nord_dark_theme()` Funktion modifizieren:

```bash
# In scripts/cli/nord-terminal-enhancer.sh
generate_enhanced_nord_dark_theme() {
    # Ihre Anpassungen hier
}
```

### Eigene Farben hinzufügen

```bash
# Beispiel: Eigene Akzentfarbe
readonly CUSTOM_ACCENT="ff/79/c6"  # Pink

# In der Theme-Funktion verwenden
special_color = (MAGENTA,BLACK,ON)
```

## 🐛 Troubleshooting

### Problem: Farben werden nicht angezeigt

**Lösung 1**: Terminal-Unterstützung prüfen
```bash
echo $TERM  # sollte "xterm-256color" oder ähnlich sein
tput colors # sollte 256 zeigen
```

**Lösung 2**: TERM-Variable setzen
```bash
export TERM="xterm-256color"
```

### Problem: Dialog zeigt keine Farben

**Lösung**: DIALOGRC-Variable prüfen
```bash
echo $DIALOGRC  # sollte auf temporäre Konfiguration zeigen
ls -la $DIALOGRC  # Datei sollte existieren
```

### Problem: SSH-Verbindung zeigt falsche Farben

**Lösung**: Terminal-Forwarding aktivieren
```bash
ssh -t user@host "TERM=$TERM bash"
```

### Problem: Themes werden nicht gespeichert

**Lösung**: Umgebungsvariable persistent setzen
```bash
echo 'export EXAPG_THEME="nord-dark"' >> ~/.bashrc
source ~/.bashrc
```

## 📊 Theme-Vergleich

| Feature | Nord Dark | Nord Light | High Contrast | Classic |
|---------|-----------|------------|---------------|---------|
| **Augenschonung** | ✅ Excellent | ⚠️ Gut | ✅ Excellent | ✅ Gut |
| **Professionalität** | ✅ Hoch | ✅ Hoch | ⚠️ Mittel | ⚠️ Retro |
| **Barrierefreiheit** | ✅ Gut | ✅ Gut | ✅ Excellent | ⚠️ Mittel |
| **Lesbarkeit** | ✅ Excellent | ✅ Excellent | ✅ Maximum | ✅ Gut |
| **Moderne Ästhetik** | ✅ Excellent | ✅ Excellent | ⚠️ Funktional | ❌ Retro |

## 🚀 Best Practices

### 1. Konsistente Theme-Nutzung

```bash
# Setzen Sie das Theme global
export EXAPG_THEME="nord-dark"

# Verwenden Sie den Enhanced Mode
./scripts/cli/nord-terminal-enhancer.sh
```

### 2. Terminal-Optimierung

```bash
# Optimale Terminal-Konfiguration
export TERM="xterm-256color"
export COLORTERM="truecolor"
export LC_ALL="en_US.UTF-8"
```

### 3. Professionelle Arbeitsumgebung

- Verwenden Sie Nord für alle Terminal-Anwendungen
- Nutzen Sie passende Editor-Themes (VS Code Nord, Vim Nord)
- Konfigurieren Sie Ihr System-Theme entsprechend

### 4. Team-Konsistenz

```bash
# Team-weite Konfiguration
echo 'export EXAPG_THEME="nord-dark"' >> /etc/profile.d/exapg.sh
```

## 📚 Weitere Ressourcen

- **Offizielle Nord Website**: https://www.nordtheme.com/
- **Nord GitHub**: https://github.com/arcticicestudio/nord
- **ExaPG Dokumentation**: [docs/INDEX.md](../INDEX.md)
- **Terminal UI Referenz**: [cli-reference.md](cli-reference.md)

## 🎨 Fazit

Das Nord Dark Theme in ExaPG bietet:

- ✅ **Professionelle Ästhetik** mit offizieller Nord-Farbpalette
- ✅ **Augenschonende Arbeitsumgebung** für lange Sessions
- ✅ **Vollständige Barrierefreiheit** mit High-Contrast-Option
- ✅ **Terminal-Kompatibilität** für alle gängigen Terminals
- ✅ **Einfache Aktivierung** mit einem Befehl
- ✅ **Erweiterte Anpassungen** für Power-User

Das Nord Theme macht ExaPG zu einer visuell ansprechenden und professionellen Arbeitsumgebung für PostgreSQL-Analytics. 