#!/bin/bash
# ExaPG PITR Manager Entrypoint-Skript

set -e

# Log-Funktion
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Verzeichnisse erstellen
mkdir -p /var/log/pitr-manager /var/lib/pitr-manager /var/lib/pitr-manager/restores

# Umgebungsvariablen setzen, falls nicht gesetzt
export PITR_LISTEN_PORT=${PITR_LISTEN_PORT:-8080}
export PGBACKREST_STANZA=${PGBACKREST_STANZA:-exapg}
export PGBACKREST_CONFIG=${PGBACKREST_CONFIG:-/etc/pgbackrest/pgbackrest.conf}
export PGHOST=${PGHOST:-postgres}
export PGPORT=${PGPORT:-5432}
export PGUSER=${PGUSER:-postgres}
export PGPASSWORD=${PGPASSWORD:-postgres}
export PGDATABASE=${PGDATABASE:-postgres}
export RETENTION_DAYS=${RETENTION_DAYS:-14}
export FLASK_DEBUG=${FLASK_DEBUG:-false}

# Überprüfe die Konfigurationsdatei
if [ ! -f "$PGBACKREST_CONFIG" ]; then
  log "WARNUNG: Die Konfigurationsdatei '$PGBACKREST_CONFIG' existiert nicht."
fi

# Kopiere die HTML-Templates, falls sie nicht existieren
if [ ! -d "/app/templates" ] || [ "$(ls -A /app/templates 2>/dev/null)" = "" ]; then
  log "Erstelle Template-Verzeichnis..."
  mkdir -p /app/templates
  if [ -d "/app/templates.default" ]; then
    cp -r /app/templates.default/* /app/templates/
  fi
fi

# Kopiere statische Dateien, falls sie nicht existieren
if [ ! -d "/app/static" ] || [ "$(ls -A /app/static 2>/dev/null)" = "" ]; then
  log "Erstelle Static-Verzeichnis..."
  mkdir -p /app/static
  if [ -d "/app/static.default" ]; then
    cp -r /app/static.default/* /app/static/
  fi
fi

# Prüfe PgBackRest-Installation
if ! command -v pgbackrest &> /dev/null; then
  log "FEHLER: pgBackRest ist nicht installiert!"
  exit 1
fi

# Warte auf PostgreSQL-Verfügbarkeit, falls aktiviert
if [ "${WAIT_FOR_POSTGRES:-true}" = "true" ]; then
  log "Warte auf PostgreSQL-Verfügbarkeit..."
  PG_RETRIES=30
  until pg_isready -h $PGHOST -p $PGPORT -U $PGUSER || [ $PG_RETRIES -eq 0 ]; do
    log "PostgreSQL ist noch nicht bereit - verbleibende Versuche: $PG_RETRIES"
    PG_RETRIES=$((PG_RETRIES-1))
    sleep 5
  done
  
  if [ $PG_RETRIES -eq 0 ]; then
    log "WARNUNG: PostgreSQL ist nicht erreichbar, aber wir fahren trotzdem fort."
  else
    log "PostgreSQL ist bereit!"
  fi
fi

# Prüfe, ob die Stanza existiert, falls aktiviert
if [ "${CHECK_STANZA:-true}" = "true" ]; then
  log "Prüfe pgBackRest-Stanza '$PGBACKREST_STANZA'..."
  if ! pgbackrest --config=$PGBACKREST_CONFIG --stanza=$PGBACKREST_STANZA info &> /dev/null; then
    log "WARNUNG: Stanza '$PGBACKREST_STANZA' existiert nicht oder ist nicht erreichbar."
    log "Die PITR-Funktionalität könnte eingeschränkt sein."
  else
    log "Stanza '$PGBACKREST_STANZA' ist verfügbar."
  fi
fi

# Aufräumen von alten Logs
if [ "${CLEANUP_OLD_LOGS:-true}" = "true" ]; then
  log "Bereinige alte Log-Dateien..."
  find /var/log/pitr-manager -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
  find /var/lib/pitr-manager/restores -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
fi

# Führe den angegebenen Befehl aus
log "Starte PITR Manager mit Befehl: $@"
exec "$@" 