#!/bin/bash
# Stop Backup-Komponenten für ExaPG

set -e

# Verzeichnis des Skripts als Basis-Verzeichnis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

# Log-Funktion
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Funktion zum Prüfen, ob Docker installiert ist
check_docker() {
  if ! command -v docker &> /dev/null; then
    log "FEHLER: Docker ist nicht installiert"
    exit 1
  fi
  
  if ! command -v docker-compose &> /dev/null; then
    log "FEHLER: Docker Compose ist nicht installiert"
    exit 1
  fi
}

# Funktion zum Laden der Umgebungsvariablen
load_env() {
  if [ -f "$BASE_DIR/.env" ]; then
    log "Lade Umgebungsvariablen aus .env Datei"
    set -a
    source "$BASE_DIR/.env"
    set +a
  else
    log "WARNUNG: Keine .env Datei gefunden, verwende Standardwerte"
  fi
}

# Funktion zum Stoppen der Backup-Komponenten
stop_backup() {
  log "Stoppe pgBackRest Backup-Komponenten..."
  
  # Prüfe, ob Docker-Compose-Datei existiert
  if [ ! -f "$BASE_DIR/docker/docker-compose/docker-compose.backup.yml" ]; then
    log "FEHLER: Docker-Compose-Datei nicht gefunden: $BASE_DIR/docker/docker-compose/docker-compose.backup.yml"
    exit 1
  fi
  
  # Führe docker-compose down aus
  cd "$BASE_DIR"
  docker-compose -f "$BASE_DIR/docker/docker-compose/docker-compose.backup.yml" down
  
  if [ $? -eq 0 ]; then
    log "Backup-Komponenten erfolgreich gestoppt"
  else
    log "FEHLER: Backup-Komponenten konnten nicht gestoppt werden"
    exit 1
  fi
}

# Funktion zum Anzeigen der Hilfe
show_help() {
  echo "ExaPG Backup Stop-Skript"
  echo "Verwendung: $0 [Optionen]"
  echo ""
  echo "Optionen:"
  echo "  --help     Diese Hilfe anzeigen"
  echo "  --remove   Container und Netzwerke entfernen (Standard)"
  echo "  --volumes  Auch Volumes entfernen (Vorsicht: Löscht Backup-Daten!)"
  echo ""
}

# Hauptfunktion
main() {
  # Parameter verarbeiten
  REMOVE_VOLUMES=false
  
  for arg in "$@"; do
    case $arg in
      --help)
        show_help
        exit 0
        ;;
      --volumes)
        REMOVE_VOLUMES=true
        ;;
    esac
  done
  
  # Prüfe Voraussetzungen
  check_docker
  
  # Lade Umgebungsvariablen
  load_env
  
  # Stoppe Backup-Komponenten
  stop_backup
  
  # Entferne Volumes, falls gewünscht
  if [ "$REMOVE_VOLUMES" = true ]; then
    log "Entferne Backup-Volumes..."
    docker volume rm exapg_pgbackrest_data exapg_pgbackrest_spool exapg_pgbackrest_logs exapg_backup_verification_logs exapg_pitr_data || true
    log "Backup-Volumes entfernt"
  fi
}

# Führe Hauptfunktion aus
main "$@" 