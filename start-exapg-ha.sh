#!/bin/bash
# ExaPG - Start High Availability Cluster
# Skript zum Starten des hochverfügbaren ExaPG-Systems

set -e

# Prüfen, ob Docker und Docker Compose installiert sind
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    echo "Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut."
    exit 1
fi

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Erforderliche Verzeichnisse erstellen
mkdir -p config/ha
mkdir -p config/pgbouncer
mkdir -p scripts/maintenance

# Skripte ausführbar machen
chmod +x scripts/maintenance/*.sh

# Prüfen, ob Patroni-Konfiguration existiert
if [ ! -f config/ha/patroni-template.yml ]; then
    echo "Patroni-Konfigurationsvorlage nicht gefunden. Das System kann nicht gestartet werden."
    exit 1
fi

# Prüfen, ob pgBouncer-Konfiguration existiert
if [ ! -f config/pgbouncer/pgbouncer.ini ] || [ ! -f config/pgbouncer/userlist.txt ]; then
    echo "pgBouncer-Konfigurationsdateien nicht gefunden. Das System kann nicht gestartet werden."
    exit 1
fi

echo "Starte hochverfügbares ExaPG-System..."

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    DOCKER_COMPOSE="docker compose"
else
    # Docker Compose V1 (Fallback)
    DOCKER_COMPOSE="docker-compose"
fi

# Starten des HA-Clusters
$DOCKER_COMPOSE -f docker/docker-compose/docker-compose.ha.yml up -d

echo "Das hochverfügbare ExaPG-System wurde gestartet!"
echo "=============================================="
echo "Folgende Dienste sind verfügbar:"
echo ""
echo "pgBouncer (Load Balancer): localhost:6432"
echo "Coordinator 1: localhost:5434"
echo "Coordinator 2: localhost:5435"
echo "Patroni API 1: http://localhost:8010"
echo "Patroni API 2: http://localhost:8011"
echo "etcd: localhost:2379"
echo ""
echo "Benutzer: ${POSTGRES_USER:-postgres}"
echo "Passwort: ${POSTGRES_PASSWORD:-postgres}"
echo "Datenbank: ${POSTGRES_DB:-postgres}"
echo "=============================================="
echo "Hochverfügbarkeits-Funktionen:"
echo "- Automatisches Failover mit Patroni"
echo "- Multi-AZ-Deployment für Disaster Recovery"
echo "- Selbstheilende Cluster-Mechanismen"
echo ""
echo "Zum Stoppen des HA-Systems führen Sie den folgenden Befehl aus:"
echo "docker compose -f docker/docker-compose/docker-compose.ha.yml down"
echo ""
echo "Um den Status des Clusters zu prüfen:"
echo "curl http://localhost:8010/cluster" 