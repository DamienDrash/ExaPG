#!/bin/bash
# ExaPG CLI - Interaktives Terminal-Interface für ExaPG
# Ersetzt alle separaten start-* und stop-* Skripte

# Farbdefinitionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Banner und Versionsinformationen
VERSION="1.0.0"

# Lade Funktionsbibliothek
source scripts/cli/exapg-cli-functions.sh

show_banner() {
  clear
  echo -e "${BLUE}${BOLD}"
  echo "  ______           ____   _____ "
  echo " |  ____|         |  _ \ / ____|"
  echo " | |__  __  ____ _| |_) | |  __ "
  echo " |  __| \ \/ / _\` |  __/| | |_ |"
  echo " | |____ >  < (_| | |   | |__| |"
  echo " |______/_/\_\__,_|_|    \_____|"
  echo -e "${NC}"
  echo -e " ${YELLOW}PostgreSQL-basierte Alternative zu Exasol${NC}"
  echo -e " ${CYAN}Version: ${VERSION}${NC}"
  echo ""
}

# Hilfsfunktionen für Ausgabe
print_message() {
  echo -e "${BLUE}[ExaPG]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[ExaPG]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG]${NC} $1"
}

# Voraussetzungen prüfen
check_prerequisites() {
  # Docker prüfen
  if ! command -v docker &> /dev/null; then
    print_error "Docker wurde nicht gefunden. Bitte installieren Sie Docker."
    return 1
  fi

  # Docker Compose prüfen
  if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose wurde nicht gefunden. Bitte installieren Sie Docker Compose."
    return 1
  fi

  # .env Datei prüfen und ggf. erstellen
  if [ ! -f .env ]; then
    print_message "Keine .env-Datei gefunden. Erstelle Standardkonfiguration..."
    cp .env.example .env
    print_success ".env-Datei mit Standardkonfiguration erstellt."
  fi

  # Lade Konfiguration aus .env
  source .env
  return 0
}

# Hauptmenü anzeigen
show_main_menu() {
  while true; do
    show_banner
    echo "Hauptmenü"
    echo "---------"
    echo "1) ExaPG Standard starten"
    echo "2) ExaPG Citus (verteilte Datenbank) starten"
    echo "3) ExaPG HA (Hochverfügbarkeit) starten"
    echo "4) Monitoring starten"
    echo "5) Management-UI starten"
    echo "6) UDF-Framework starten (LuaJIT, Python, R)"
    echo "7) Virtual Schemas starten (Foreign Data Wrapper)"
    echo "8) ETL-Tools starten"
    echo "9) Backup-Tools starten"
    echo ""
    echo "s) Status aller Komponenten anzeigen"
    echo "e) Konfigurationseinstellungen bearbeiten (.env)"
    echo "x) Alle Komponenten stoppen"
    echo "q) Beenden"
    echo ""
    read -p "Auswahl: " choice
    
    case $choice in
      1)
        # Deployment-Modus abfragen
        echo ""
        echo "ExaPG Standard-Modus auswählen:"
        echo "1) Single-Node (für Entwicklung und kleine Deployments)"
        echo "2) Cluster (für größere Deployments mit Skalierung)"
        read -p "Wählen Sie [1/2]: " mode_choice
        
        case $mode_choice in
          2)
            start_exapg "cluster"
            ;;
          *)
            start_exapg "single"
            ;;
        esac
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      2)
        start_exapg_citus
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      3)
        start_exapg_ha
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      4)
        start_monitoring
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      5)
        start_management_ui
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      6)
        start_udf_framework
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      7)
        start_virtual_schemas
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      8)
        start_etl
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      9)
        start_backup
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      s|S)
        status_check
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      e|E)
        edit_config
        ;;
      x|X)
        stop_all
        read -p "Drücken Sie Enter, um fortzufahren..."
        ;;
      q|Q)
        echo "Auf Wiedersehen!"
        exit 0
        ;;
      *)
        print_error "Ungültige Auswahl!"
        sleep 1
        ;;
    esac
  done
}

# Hauptprogramm
main() {
  # Prüfe Voraussetzungen
  if ! check_prerequisites; then
    print_error "Voraussetzungen nicht erfüllt. Bitte installieren Sie die fehlenden Komponenten."
    exit 1
  fi
  
  # Zeige Hauptmenü
  show_main_menu
}

# Starte Hauptprogramm
main 