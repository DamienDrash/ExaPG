#!/bin/bash
# Stop-Skript für Monitoring mit Prometheus/Grafana

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

# Überprüfe, ob Docker installiert ist
if ! command -v docker &> /dev/null; then
  print_error "Docker wurde nicht gefunden. Bitte installieren Sie Docker."
  exit 1
fi

if ! command -v docker-compose &> /dev/null; then
  print_error "Docker Compose wurde nicht gefunden. Bitte installieren Sie Docker Compose."
  exit 1
fi

print_message "Stoppe Monitoring-Stack..."

# Stoppe den Monitoring-Stack
docker-compose -f docker/docker-compose/docker-compose.monitoring.yml down

# Überprüfe, ob alle Container gestoppt wurden
if ! docker ps | grep -q "exapg-prometheus\|exapg-grafana\|exapg-alertmanager\|exapg-postgres-exporter"; then
  print_success "Monitoring-Stack wurde erfolgreich gestoppt."
else
  print_error "Einige Monitoring-Container laufen noch."
  docker ps | grep "exapg-prometheus\|exapg-grafana\|exapg-alertmanager\|exapg-postgres-exporter"
fi 