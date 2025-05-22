#!/bin/bash
# ExaPG - pgBouncer Healthcheck
# Prüft, ob pgBouncer läuft und korrekt konfiguriert ist

set -e

# Port, auf dem pgBouncer horcht
PORT=${PGBOUNCER_LISTEN_PORT:-6432}

# Prüfe, ob pgBouncer-Prozess läuft
if ! pgrep -x pgbouncer > /dev/null; then
    echo "pgBouncer-Prozess nicht gefunden!"
    exit 1
fi

# Prüfe, ob pgBouncer auf dem konfigurierten Port lauscht
if ! netstat -tuln | grep -q ":$PORT"; then
    echo "pgBouncer lauscht nicht auf Port $PORT!"
    exit 1
fi

# Versuche, eine Verbindung zum pgBouncer herzustellen
if ! psql -h localhost -p $PORT -U postgres -c "SHOW CONFIG" pgbouncer > /dev/null 2>&1; then
    echo "Kann keine Verbindung zu pgBouncer herstellen!"
    exit 1
fi

# Prüfe, ob pgBouncer eine Verbindung zu den PostgreSQL-Servern herstellen kann
if ! psql -h localhost -p $PORT -U postgres -c "SHOW DATABASES" pgbouncer | grep -q "ACTIVE"; then
    echo "pgBouncer hat keine aktiven Datenbankverbindungen!"
    exit 1
fi

# Alles OK
echo "pgBouncer ist gesund!"
exit 0 