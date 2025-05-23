#!/bin/bash
# ExaPG Backup-Scheduler für pgBackRest
# Optimiert für analytische Workloads und große Datenmengen

set -e

# Log-Funktion
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Standard-Werte
BACKUP_TYPE="incr"
STANZA=${PGBACKREST_STANZA:-"exapg"}
CONFIG=${PGBACKREST_CONFIG:-"/etc/pgbackrest/pgbackrest.conf"}
PARALLEL=${BACKUP_PARALLEL:-"4"}
COMPRESS_LEVEL=${COMPRESS_LEVEL:-"3"}
START_FAST=${START_FAST:-"y"}
NOTIFICATION=${NOTIFICATION:-"y"}
CHECK_AFTER_BACKUP=${CHECK_AFTER_BACKUP:-"y"}

# Hilfefunktion
show_help() {
  echo "ExaPG Backup-Scheduler für pgBackRest"
  echo "Nutzung: $0 [Optionen]"
  echo ""
  echo "Optionen:"
  echo "  --type=TYPE         Backup-Typ: full, diff, incr (Standard: incr)"
  echo "  --stanza=NAME       Stanza-Name (Standard: $STANZA)"
  echo "  --config=PATH       Konfigurationsdatei (Standard: $CONFIG)"
  echo "  --parallel=NUM      Parallelität (Standard: $PARALLEL)"
  echo "  --compress=LEVEL    Kompressionsgrad 0-9 (Standard: $COMPRESS_LEVEL)"
  echo "  --check             Backup nach Erstellung prüfen (aktiviert)"
  echo "  --no-check          Backup nach Erstellung nicht prüfen"
  echo "  --no-notification   Keine Benachrichtigungen senden"
  echo "  --help              Diese Hilfe anzeigen"
  exit 0
}

# Parameter verarbeiten
for i in "$@"; do
  case $i in
    --type=*)
      BACKUP_TYPE="${i#*=}"
      ;;
    --stanza=*)
      STANZA="${i#*=}"
      ;;
    --config=*)
      CONFIG="${i#*=}"
      ;;
    --parallel=*)
      PARALLEL="${i#*=}"
      ;;
    --compress=*)
      COMPRESS_LEVEL="${i#*=}"
      ;;
    --check)
      CHECK_AFTER_BACKUP="y"
      ;;
    --no-check)
      CHECK_AFTER_BACKUP="n"
      ;;
    --no-notification)
      NOTIFICATION="n"
      ;;
    --help)
      show_help
      ;;
    *)
      echo "Unbekannte Option: $i"
      show_help
      ;;
  esac
done

# Prüfe, ob die Stanza existiert
log "Prüfe, ob Stanza '$STANZA' existiert..."
if ! pgbackrest --config=$CONFIG --stanza=$STANZA info &>/dev/null; then
  log "FEHLER: Stanza '$STANZA' existiert nicht. Bitte zuerst erstellen."
  exit 1
fi

# Backup-Beginn protokollieren
START_TIME=$(date +%s)
log "Starte $BACKUP_TYPE Backup der Stanza '$STANZA'..."

# Backup ausführen
BACKUP_CMD="pgbackrest --config=$CONFIG --stanza=$STANZA --type=$BACKUP_TYPE"
BACKUP_CMD="$BACKUP_CMD --compress-level=$COMPRESS_LEVEL --process-max=$PARALLEL"

if [ "$START_FAST" = "y" ]; then
  BACKUP_CMD="$BACKUP_CMD --start-fast"
fi

# Für vollständige Backups: Delta-Option für optimale Performance
if [ "$BACKUP_TYPE" = "full" ]; then
  BACKUP_CMD="$BACKUP_CMD --delta"
  log "Full-Backup mit Delta-Option für schnellere Verarbeitung..."
else
  log "Inkrementeller/Differentieller Backup..."
fi

# Backup ausführen
log "Führe aus: $BACKUP_CMD"
if ! $BACKUP_CMD backup; then
  log "FEHLER: Backup fehlgeschlagen!"
  
  # Bei Fehler Benachrichtigung senden
  if [ "$NOTIFICATION" = "y" ] && [ -x /usr/local/bin/backup-notification.py ]; then
    /usr/local/bin/backup-notification.py --type=$BACKUP_TYPE --status=failed
  fi
  
  exit 1
fi

# Backup-Dauer berechnen
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))
log "Backup erfolgreich abgeschlossen in ${DURATION_MIN}m ${DURATION_SEC}s."

# Backup-Prüfung durchführen
if [ "$CHECK_AFTER_BACKUP" = "y" ] && [ -x /usr/local/bin/backup-verification.py ]; then
  log "Führe Backup-Prüfung durch..."
  /usr/local/bin/backup-verification.py --quick --latest-backup
fi

# Erfolgs-Benachrichtigung senden
if [ "$NOTIFICATION" = "y" ] && [ -x /usr/local/bin/backup-notification.py ]; then
  log "Sende Benachrichtigung..."
  /usr/local/bin/backup-notification.py --type=$BACKUP_TYPE --status=success --duration=$DURATION
fi

# Repository-Information anzeigen
log "Aktueller Repository-Status:"
pgbackrest --config=$CONFIG --stanza=$STANZA info

exit 0 