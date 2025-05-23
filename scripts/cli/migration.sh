#!/bin/bash
# ExaPG CLI - Migrationsskript
# Verschiebt alte Start/Stop-Skripte ins scripts/setup Verzeichnis

# Ausgabefunktionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Liste der zu verschiebenden Skripte
OLD_SCRIPTS=(
  "start-exapg.sh"
  "start-exapg-citus.sh"
  "start-exapg-fdw.sh"
  "start-exapg-ha.sh"
  "start-exapg-udf-framework.sh"
  "start-exapg-virtual-schemas.sh"
  "start-exapg-etl.sh"
  "start-backup.sh"
  "start-cluster-management.sh"
  "start-management-ui.sh"
  "start-monitoring.sh"
  "stop-backup.sh"
  "stop-cluster-management.sh"
  "stop-exapg-etl.sh"
  "stop-exapg-ha.sh"
  "stop-exapg-udf-framework.sh"
  "stop-exapg-virtual-schemas.sh"
  "stop-management-ui.sh"
  "stop-monitoring.sh"
)

# Prüfen, ob wir im richtigen Verzeichnis sind
if [ ! -f "exapg-cli.sh" ]; then
  print_error "Dieses Skript muss im ExaPG-Hauptverzeichnis ausgeführt werden!"
  exit 1
fi

# Erstelle Verzeichnis für originale Skripte
SCRIPTS_DIR="scripts/setup"
if [ ! -d "$SCRIPTS_DIR" ]; then
  print_message "Erstelle Verzeichnis für originale Skripte: $SCRIPTS_DIR"
  mkdir -p "$SCRIPTS_DIR"
fi

# Verschieben der alten Skripte
for script in "${OLD_SCRIPTS[@]}"; do
  if [ -f "$script" ]; then
    print_message "Verschiebe $script nach $SCRIPTS_DIR/$script"
    
    # Kopiere Skript in das Zielverzeichnis
    cp "$script" "$SCRIPTS_DIR/$script"
    
    # Entferne Original und ersetze durch Symlink
    print_message "Erstelle Symlink für $script zur CLI..."
    rm "$script"
    ln -sf "exapg-cli.sh" "$script"
    
    print_success "$script wurde verschoben und durch Symlink ersetzt."
  else
    print_warning "Skript $script wurde nicht gefunden, überspringe..."
  fi
done

print_success "Migration abgeschlossen. Alte Skripte wurden nach $SCRIPTS_DIR verschoben."
print_message "Für jedes alte Skript wurde ein Symlink zur neuen CLI erstellt."
print_message "Verwenden Sie ./exapg oder ./exapg-cli.sh, um die neue CLI zu starten." 