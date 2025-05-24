#!/bin/bash
# ExaPG CLI v2.0 - Moderne Terminal-UI für ExaPG
# PostgreSQL-basierte Alternative zu Exasol

# Removed 'set -e' to allow proper dialog exit code handling

# Banner und Versionsinformationen  
VERSION="2.0.0"

# Basis-Verzeichnis bestimmen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Terminal-UI Framework laden
if [ -f "scripts/cli/terminal-ui.sh" ]; then
    source "scripts/cli/terminal-ui.sh"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to load terminal UI framework!"
        exit 1
    fi
else
    echo "Error: Terminal UI framework not found!"
    echo "Please run the installation:"
    echo "./scripts/setup/install_wizard.sh"
    exit 1
fi

# Alte CLI-Funktionen entfernt - Direkt zur modernen UI

# Hauptprogramm - Direkt zur modernen UI
main() {
    # Terminal-UI starten
    if command -v dialog &> /dev/null; then
        # Moderne UI direkt starten
        check_terminal_ui
        setup_color_scheme
        create_profiles_dir
        show_welcome_screen
        show_main_menu
    else
        echo "Dialog-Tool wird installiert..."
        if command -v yum &> /dev/null; then
            sudo yum install -y dialog
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install -y dialog
        fi
        
        # Nach Installation erneut versuchen
        exec "$0" "$@"
    fi
}

# Direkt starten
main "$@" 