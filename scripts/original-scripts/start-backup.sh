#!/bin/bash
# Start Backup-Komponenten für ExaPG

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

# Funktion zum Starten der Backup-Komponenten
start_backup() {
  log "Starte pgBackRest Backup-Komponenten..."
  
  # Prüfe, ob Docker-Compose-Datei existiert
  if [ ! -f "$BASE_DIR/docker/docker-compose/docker-compose.backup.yml" ]; then
    log "FEHLER: Docker-Compose-Datei nicht gefunden: $BASE_DIR/docker/docker-compose/docker-compose.backup.yml"
    exit 1
  fi
  
  # Stelle sicher, dass Konfigurationsverzeichnisse existieren
  mkdir -p "$BASE_DIR/pgbackrest/conf"
  
  # Führe docker-compose up aus
  cd "$BASE_DIR"
  docker-compose -f "$BASE_DIR/docker/docker-compose/docker-compose.backup.yml" up -d
  
  if [ $? -eq 0 ]; then
    log "Backup-Komponenten erfolgreich gestartet"
    log "pgBackRest läuft unter: localhost"
    log "PITR-Manager ist unter http://localhost:8081 erreichbar"
    log "Anmeldedaten für PITR-Manager: admin / admin123"
  else
    log "FEHLER: Backup-Komponenten konnten nicht gestartet werden"
    exit 1
  fi
}

# Funktion zum Anzeigen der Hilfe
show_help() {
  echo "ExaPG Backup Start-Skript"
  echo "Verwendung: $0 [Optionen]"
  echo ""
  echo "Optionen:"
  echo "  --help     Diese Hilfe anzeigen"
  echo "  --detach   Im Hintergrund starten (Standard)"
  echo "  --console  Im Vordergrund starten"
  echo ""
}

# Hauptfunktion
main() {
  # Parameter verarbeiten
  DETACH=true
  
  for arg in "$@"; do
    case $arg in
      --help)
        show_help
        exit 0
        ;;
      --detach)
        DETACH=true
        ;;
      --console)
        DETACH=false
        ;;
    esac
  done
  
  # Prüfe Voraussetzungen
  check_docker
  
  # Lade Umgebungsvariablen
  load_env
  
  # Starte Backup-Komponenten
  start_backup
}

# Führe Hauptfunktion aus
main "$@"