#!/bin/bash
set -e

# Log-Funktion
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Konfiguration prüfen
if [ ! -f "$PGBACKREST_CONFIG" ]; then
  log "WARNUNG: Konfigurationsdatei $PGBACKREST_CONFIG nicht gefunden. Verwende Standardkonfiguration."
  export PGBACKREST_CONFIG=/etc/pgbackrest/pgbackrest.conf
fi

# Warten auf PostgreSQL-Verfügbarkeit
log "Warte auf PostgreSQL-Server..."
until pg_isready -h $PGHOST -p $PGPORT -U $PGUSER; do
  log "PostgreSQL noch nicht verfügbar - warte 5 Sekunden..."
  sleep 5
done
log "PostgreSQL ist bereit!"

# Stanza prüfen und ggf. erstellen
log "Prüfe pgBackRest Stanza..."
if ! pgbackrest --stanza=$PGBACKREST_STANZA info &>/dev/null; then
  log "Stanza existiert nicht. Erstelle neue Stanza..."
  
  # Check if we need to create a repository
  if [ ! -d "$PGBACKREST_REPO1_PATH/backup" ]; then
    log "Repository-Verzeichnis wird erstellt..."
    mkdir -p $PGBACKREST_REPO1_PATH/backup
  fi
  
  # Erstelle Stanza
  pgbackrest --stanza=$PGBACKREST_STANZA stanza-create
  
  if [ $? -eq 0 ]; then
    log "Stanza erfolgreich erstellt."
    
    # Initialer Backup
    log "Erstelle initialen Full-Backup..."
    pgbackrest --stanza=$PGBACKREST_STANZA --type=full backup
    log "Initialer Backup abgeschlossen."
  else
    log "FEHLER: Stanza konnte nicht erstellt werden!"
  fi
else
  log "Stanza existiert bereits."
  
  # Prüfe, ob Stanza gültig ist
  log "Prüfe Stanza-Status..."
  pgbackrest --stanza=$PGBACKREST_STANZA check
  
  if [ $? -ne 0 ]; then
    log "WARNUNG: Stanza-Check fehlgeschlagen. Versuche Reparatur..."
    pgbackrest --stanza=$PGBACKREST_STANZA --force stanza-upgrade
  fi
fi

# WAL-Archivierung aktivieren
log "Prüfe WAL-Archivierung..."
ARCHIVE_MODE=$(psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -tAc "SHOW archive_mode;")
if [ "$ARCHIVE_MODE" != "on" ]; then
  log "WAL-Archivierung ist nicht aktiviert. PostgreSQL muss mit 'archive_mode=on' konfiguriert werden."
fi

# Stanze für Citus-Cluster einrichten (falls konfiguriert)
if [ -f "/etc/pgbackrest/pgbackrest-parallel.conf" ]; then
  log "Parallel-Konfiguration für Citus-Cluster gefunden."
  if [ -n "$WORKER_HOSTS" ]; then
    log "Initialisiere Stanza für Citus-Cluster mit Workers: $WORKER_HOSTS"
    # Implementierung für Citus-spezifische Konfiguration
  fi
fi

# Starte Cron für geplante Backups
log "Starte Cron-Dienst für geplante Backups..."
if [ "$1" = "cron" ]; then
  exec crond -f -l 8
else
  # Führe übergebenes Kommando aus
  log "Führe Befehl aus: $@"
  exec "$@"
fi 