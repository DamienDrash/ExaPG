#!/bin/bash
# ExaPG Backup-Verifier Entrypoint-Skript

set -e

# Log-Funktion
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Verzeichnisse erstellen
mkdir -p /var/log/backup-verification /var/lib/verification-data /tmp/restore-test

# Standard-Werte setzen
export PGBACKREST_STANZA=${PGBACKREST_STANZA:-exapg}
export PGBACKREST_CONFIG=${PGBACKREST_CONFIG:-/etc/pgbackrest/pgbackrest.conf}
export METRICS_PORT=${METRICS_PORT:-9187}
export VERIFICATION_INTERVAL=${VERIFICATION_INTERVAL:-86400}  # 24 Stunden in Sekunden
export SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}
export EMAIL_NOTIFICATIONS=${EMAIL_NOTIFICATIONS:-false}
export PGHOST=${PGHOST:-postgres}
export PGPORT=${PGPORT:-5432}
export PGUSER=${PGUSER:-postgres}
export PGPASSWORD=${PGPASSWORD:-postgres}
export PGDATABASE=${PGDATABASE:-postgres}

# Prüfe PgBackRest-Installation
if ! command -v pgbackrest &> /dev/null; then
  log "FEHLER: pgBackRest ist nicht installiert!"
  exit 1
fi

# Überprüfe die Konfigurationsdatei
if [ ! -f "$PGBACKREST_CONFIG" ]; then
  log "WARNUNG: Die Konfigurationsdatei '$PGBACKREST_CONFIG' existiert nicht."
fi

# Warte auf PostgreSQL-Verfügbarkeit
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

# Prüfe, ob die Stanza existiert
log "Prüfe pgBackRest-Stanza '$PGBACKREST_STANZA'..."
if ! pgbackrest --config=$PGBACKREST_CONFIG --stanza=$PGBACKREST_STANZA info &> /dev/null; then
  log "WARNUNG: Stanza '$PGBACKREST_STANZA' existiert nicht oder ist nicht erreichbar."
else
  log "Stanza '$PGBACKREST_STANZA' ist verfügbar."
fi

# Erstelle Crontab für die geplante Ausführung, falls gewünscht
if [ "$1" = "cron" ]; then
  log "Richte Cron-Job für Backup-Verifizierung ein..."
  
  # Berechne Ausführungszeit basierend auf dem Intervall
  if [ "$VERIFICATION_INTERVAL" -ge 86400 ]; then
    # Tägliche Ausführung (z.B. um 2:00 Uhr)
    CRON_SCHEDULE="0 2 * * *"
  elif [ "$VERIFICATION_INTERVAL" -ge 3600 ]; then
    # Stündliche Ausführung
    INTERVAL_HOURS=$((VERIFICATION_INTERVAL / 3600))
    CRON_SCHEDULE="0 */$INTERVAL_HOURS * * *"
  else
    # Minutenbasierte Ausführung (für Tests)
    INTERVAL_MINUTES=$((VERIFICATION_INTERVAL / 60))
    CRON_SCHEDULE="*/$INTERVAL_MINUTES * * * *"
  fi
  
  # Erstelle Crontab
  echo "$CRON_SCHEDULE root /app/scripts/verify-backups.py --full --notify > /var/log/backup-verification/scheduled-verify.log 2>&1" > /etc/cron.d/backup-verification
  echo "0 */4 * * * root /app/scripts/verify-backups.py --quick > /var/log/backup-verification/quick-verify.log 2>&1" >> /etc/cron.d/backup-verification
  echo "*/15 * * * * root /app/scripts/backup-metrics.py > /var/log/backup-verification/metrics.log 2>&1" >> /etc/cron.d/backup-verification
  
  chmod 0644 /etc/cron.d/backup-verification
  
  log "Cron-Job eingerichtet mit Schedule: $CRON_SCHEDULE"
  
  # Führe initial eine schnelle Verifizierung durch
  log "Führe initiale schnelle Verifizierung durch..."
  /app/scripts/verify-backups.py --quick
  
  # Starte Cron im Vordergrund
  log "Starte Cron-Dienst im Vordergrund..."
  exec cron -f
else
  # Führe übergebenen Befehl aus
  log "Führe Befehl aus: $@"
  exec "$@"
fi 