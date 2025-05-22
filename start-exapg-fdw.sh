#!/bin/bash
# ExaPG FDW (Foreign Data Wrapper) Start-Skript

set -e

# Farbdefinitionen für bessere Lesbarkeit
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zum Anzeigen von Nachrichten
print_message() {
  echo -e "${BLUE}[ExaPG FDW]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG FDW]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG FDW]${NC} $1"
}

# Überprüfe, ob Docker und Docker Compose installiert sind
if ! command -v docker &> /dev/null; then
  print_error "Docker wurde nicht gefunden. Bitte installieren Sie Docker."
  exit 1
fi

if ! command -v docker-compose &> /dev/null; then
  print_error "Docker Compose wurde nicht gefunden. Bitte installieren Sie Docker Compose."
  exit 1
fi

# Lade Konfiguration aus .env
if [ -f .env ]; then
  source .env
else
  print_error "Keine .env-Datei gefunden. Bitte erstellen Sie zuerst eine .env-Datei."
  exit 1
fi

print_message "Starte ExaPG mit aktivierten Foreign Data Wrappern..."

# Stoppe alle laufenden Container und bereinige Volumes
print_message "Stoppe vorherige Instanzen und bereinige Volumes..."
docker-compose -f docker/docker-compose/docker-compose.fdw.yml down -v 2>/dev/null || true

# Starte die FDW-Container
print_message "Starte FDW-Modus..."
docker-compose -f docker/docker-compose/docker-compose.fdw.yml up -d

# Warte auf die Initialisierung
print_message "Warte auf Initialisierung der Datenbank und externen Datenquellen..."
sleep 15

# Überprüfe den Status der Container
COORDINATOR_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME:-exapg}-coordinator 2>/dev/null || echo "not_found")
MYSQL_STATUS=$(docker ps --filter "name=exapg-mysql" --format "{{.Status}}" | grep -q "Up" && echo "running" || echo "stopped")
MONGODB_STATUS=$(docker ps --filter "name=exapg-mongodb" --format "{{.Status}}" | grep -q "Up" && echo "running" || echo "stopped")

if [ "$COORDINATOR_STATUS" == "healthy" ] && [ "$MYSQL_STATUS" == "running" ] && [ "$MONGODB_STATUS" == "running" ]; then
  print_success "ExaPG mit Foreign Data Wrappern wurde erfolgreich gestartet!"
  echo ""
  echo "Verfügbare Datenquellen:"
  echo "----------------------"
  echo "PostgreSQL: localhost:${COORDINATOR_PORT:-5432} (postgres/postgres)"
  echo "MySQL:      localhost:3306 (root/mysql_root_password)"
  echo "MongoDB:    localhost:27017 (root/mongo_root_password)"
  echo "Redis:      localhost:6379"
  echo ""
  echo "Führen Sie folgenden Befehl aus, um eine SQL-Konsole zu öffnen:"
  echo "docker exec -it ${CONTAINER_NAME:-exapg}-coordinator psql -U postgres"
  
  # Setup-Skripte ausführen
  echo "Führe Initialisierungsskripte aus..."
  docker exec -it ${CONTAINER_NAME:-exapg}-coordinator bash -c "cd /scripts/setup && ./setup-parallel-processing.sh"
else
  print_error "ExaPG FDW konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs:"
  echo "docker-compose -f docker/docker-compose/docker-compose.fdw.yml logs"
fi 