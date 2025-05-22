#!/bin/bash
set -e

# Farbdefinitionen für bessere Lesbarkeit
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion zum Anzeigen von Nachrichten
print_message() {
  echo -e "${BLUE}[ExaPG]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG]${NC} $1"
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

# Lade Standardwerte für .env, falls sie noch nicht existiert
if [ ! -f .env ]; then
  print_message "Keine .env-Datei gefunden. Erstelle Standardkonfiguration..."
  cat > .env <<EOL
# PostgreSQL Konfiguration
POSTGRES_VERSION=15
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=exadb
POSTGRES_PORT=5432
CONTAINER_NAME=exapg

# Deployment-Modus (single, cluster)
DEPLOYMENT_MODE=single
WORKER_COUNT=2

# Systemressourcen (erhöht für analytische Workloads)
SHARED_MEMORY_SIZE=4g
CONTAINER_MEMORY_LIMIT=8g
COORDINATOR_MEMORY_LIMIT=8g
WORKER_MEMORY_LIMIT=8g

# Analytische Einstellungen
MAX_PARALLEL_WORKERS=16
EFFECTIVE_CACHE_SIZE=6GB
SHARED_BUFFERS=2GB
WORK_MEM=128MB

# Citus Einstellungen
CITUS_SHARD_COUNT=32
CITUS_REPLICATION_FACTOR=1

# Netzwerk und Ports
COORDINATOR_PORT=5432
WORKER_PORT_START=5433

# Zeitzone
TIMEZONE=Europe/Berlin
EOL
  print_success ".env-Datei mit Standardkonfiguration erstellt."
fi

# Lade Konfiguration aus .env
source .env

# Frage nach dem gewünschten Deployment-Modus, falls nicht als Parameter angegeben
MODE=${1:-$DEPLOYMENT_MODE}
if [ "$MODE" != "single" ] && [ "$MODE" != "cluster" ]; then
  print_message "Bitte wählen Sie den Deployment-Modus:"
  echo "1) Single-Node (Standard, für Entwicklung und kleine Deployments)"
  echo "2) Cluster (für größere Deployments mit Skalierung)"
  read -p "Wählen Sie [1/2]: " mode_choice
  
  case $mode_choice in
    2)
      MODE="cluster"
      ;;
    *)
      MODE="single"
      ;;
  esac
fi

# Aktualisiere die .env-Datei mit dem ausgewählten Modus
sed -i "s/DEPLOYMENT_MODE=.*/DEPLOYMENT_MODE=$MODE/" .env

print_message "Starte ExaPG im $MODE-Modus..."

# Stoppe alle laufenden Container und bereinige Volumes
print_message "Stoppe vorherige Instanzen und bereinige Volumes..."
docker-compose down -v 2>/dev/null || true

# Starte die Container entsprechend dem gewählten Modus
if [ "$MODE" == "single" ]; then
  print_message "Starte Single-Node-Modus..."
  docker-compose up -d coordinator
elif [ "$MODE" == "cluster" ]; then
  print_message "Starte Cluster-Modus mit $WORKER_COUNT Worker-Knoten..."
  docker-compose --profile cluster up -d
else
  print_error "Ungültiger Modus: $MODE"
  exit 1
fi

# Warte auf die Initialisierung
print_message "Warte auf Initialisierung der Datenbank..."
sleep 10

# Überprüfe den Status der Container
COORDINATOR_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME}-coordinator 2>/dev/null || echo "not_found")

if [ "$COORDINATOR_STATUS" == "healthy" ]; then
  print_success "ExaPG wurde erfolgreich gestartet!"
  echo ""
  echo "Verbindungsinformationen:"
  echo "------------------------"
  echo "Host:     localhost"
  echo "Port:     $COORDINATOR_PORT"
  echo "Benutzer: $POSTGRES_USER"
  echo "Passwort: $POSTGRES_PASSWORD"
  echo "Datenbank: $POSTGRES_DB"
  echo ""
  echo "Führen Sie folgenden Befehl aus, um eine SQL-Konsole zu öffnen:"
  echo "docker exec -it ${CONTAINER_NAME}-coordinator psql -U $POSTGRES_USER -d $POSTGRES_DB"
else
  print_error "ExaPG konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs:"
  echo "docker-compose logs"
fi 