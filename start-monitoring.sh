#!/bin/bash
# Start-Skript für Monitoring mit Prometheus/Grafana

set -e

# Farbdefinitionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Funktion zum Anzeigen von Nachrichten
print_message() {
  echo -e "${BLUE}[ExaPG Monitoring]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG Monitoring]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG Monitoring]${NC} $1"
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

print_message "Starte Monitoring-Stack (Prometheus, Grafana, PostgreSQL Exporter)..."

# Lade Umgebungsvariablen, falls vorhanden
if [ -f .env ]; then
  source .env
fi

# Starte Monitoring-Stack
docker-compose -f docker/docker-compose/docker-compose.monitoring.yml up -d

# Warte auf die Initialisierung
print_message "Warte auf Initialisierung der Monitoring-Dienste..."
sleep 5

# Überprüfe, ob Dienste gestartet wurden
GRAFANA_STATUS=$(docker ps --filter "name=exapg-grafana" --format "{{.Status}}" | grep -q "Up" && echo "running" || echo "stopped")
PROMETHEUS_STATUS=$(docker ps --filter "name=exapg-prometheus" --format "{{.Status}}" | grep -q "Up" && echo "running" || echo "stopped")

if [ "$GRAFANA_STATUS" == "running" ] && [ "$PROMETHEUS_STATUS" == "running" ]; then
  print_success "Monitoring-Stack wurde erfolgreich gestartet!"
  echo ""
  echo "Zugangsinformationen:"
  echo "---------------------"
  echo "Grafana:     http://localhost:3000 (admin/admin)"
  echo "Prometheus:  http://localhost:9090"
  echo "Alertmanager: http://localhost:9093"
  echo ""
  echo "PostgreSQL-Metriken werden automatisch gesammelt."
else
  print_error "Monitoring-Stack konnte nicht korrekt gestartet werden."
  echo "Überprüfen Sie die Logs: docker-compose -f docker/docker-compose/docker-compose.monitoring.yml logs"
fi 