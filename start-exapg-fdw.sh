#!/bin/bash
# Start-Skript für ExaPG mit erweiterten Datenintegrationsfunktionen
# Dieses Skript startet die ExaPG-Umgebung mit Foreign Data Wrappers und ETL-Funktionalität

set -e

echo "=== ExaPG - PostgreSQL als Exasol-Alternative mit Datenintegration ==="
echo "Startet ExaPG mit Foreign Data Wrappers und ETL-Funktionalität"
echo ""

# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Verwendung: $0 [OPTION]"
    echo ""
    echo "Optionen:"
    echo "  --help, -h               Diese Hilfe anzeigen"
    echo "  --with-demo-sources      Demo-Datenquellen (MySQL, MongoDB, Redis) starten"
    echo "  --with-pgagent           pgAgent für ETL-Automatisierung starten"
    echo "  --all                    Alle Komponenten starten"
    echo ""
    echo "Standardmäßig wird nur der ExaPG-Koordinator mit FDW-Unterstützung gestartet."
    exit 0
}

# Parameter parsen
WITH_DEMO_SOURCES=false
WITH_PGAGENT=false

for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            ;;
        --with-demo-sources)
            WITH_DEMO_SOURCES=true
            ;;
        --with-pgagent)
            WITH_PGAGENT=true
            ;;
        --all)
            WITH_DEMO_SOURCES=true
            WITH_PGAGENT=true
            ;;
        *)
            echo "Unbekannte Option: $arg"
            show_help
            ;;
    esac
done

# Prüfen, ob Docker und Docker Compose installiert sind
if ! command -v docker &> /dev/null; then
    echo "Fehler: Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Fehler: Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut."
    exit 1
fi

# Docker-Compose-Profil erstellen
COMPOSE_PROFILES="coordinator"

if [ "$WITH_PGAGENT" = true ]; then
    COMPOSE_PROFILES="$COMPOSE_PROFILES,pgagent"
fi

if [ "$WITH_DEMO_SOURCES" = true ]; then
    COMPOSE_PROFILES="$COMPOSE_PROFILES,demo-sources"
fi

echo "Starte ExaPG mit FDW-Unterstützung..."

# Services starten
if [ "$WITH_DEMO_SOURCES" = true ] && [ "$WITH_PGAGENT" = true ]; then
    echo "Starte alle Komponenten (Koordinator, pgAgent, Demo-Datenquellen)..."
    docker-compose -f docker-compose.fdw.yml up -d
elif [ "$WITH_DEMO_SOURCES" = true ]; then
    echo "Starte Koordinator und Demo-Datenquellen..."
    docker-compose -f docker-compose.fdw.yml up -d coordinator mysql mongodb redis
elif [ "$WITH_PGAGENT" = true ]; then
    echo "Starte Koordinator und pgAgent..."
    docker-compose -f docker-compose.fdw.yml up -d coordinator pgagent
else
    echo "Starte nur den Koordinator..."
    docker-compose -f docker-compose.fdw.yml up -d coordinator
fi

# Warten, bis die Datenbank bereit ist
echo "Warte, bis die Datenbank bereit ist..."
until docker exec exapg-coordinator pg_isready -U postgres > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""

# FDW-Beispiele laden
echo "Lade FDW-Beispiele..."
docker exec -i exapg-coordinator psql -U postgres -d exadb -f /scripts/fdw-examples.sql

# ETL-Jobs einrichten
echo "Richte ETL-Jobs ein..."
docker exec -i exapg-coordinator psql -U postgres -d exadb -f /scripts/setup-etl-jobs.sql

echo ""
echo "=== ExaPG mit Datenintegration wurde erfolgreich gestartet ==="
echo ""
echo "Verbindungsinformationen:"
echo "  Host:     localhost"
echo "  Port:     5432"
echo "  Benutzer: postgres"
echo "  Passwort: postgres"
echo "  Datenbank: exadb"
echo ""

if [ "$WITH_DEMO_SOURCES" = true ]; then
    echo "Demo-Datenquellen wurden gestartet:"
    echo "  MySQL:    localhost:3306 (Benutzer: mysql_user, Passwort: mysql_password)"
    echo "  MongoDB:  localhost:27017 (Benutzer: mongo_user, Passwort: mongo_password)"
    echo "  Redis:    localhost:6379"
    echo ""
fi

if [ "$WITH_PGAGENT" = true ]; then
    echo "pgAgent wurde gestartet für ETL-Automatisierung"
    echo ""
fi

echo "Verfügbare Schemas für Datenintegration:"
echo "  external_sources - Enthält Foreign Tables"
echo "  etl - Enthält ETL-Prozesse und Transformationen"
echo ""
echo "Beispiele für Abfragen:"
echo "  SELECT * FROM external_sources.example_csv;"
echo "  SELECT * FROM external_sources.combined_data;"
echo "  SELECT * FROM etl.activity_log;"
echo ""

# Optional: Shell im Container öffnen
read -p "Möchten Sie eine Postgres-Shell öffnen? (j/n): " open_shell
if [[ $open_shell == "j" || $open_shell == "J" ]]; then
    docker exec -it exapg-coordinator psql -U postgres -d exadb
fi

exit 0 