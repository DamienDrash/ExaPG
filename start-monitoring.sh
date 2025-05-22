#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hilfsfunktionen
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Prüfen, ob Docker läuft
if ! docker info >/dev/null 2>&1; then
    error "Docker ist nicht gestartet oder der Benutzer hat keine Berechtigungen."
    exit 1
fi

# Prüfen, ob ExaPG bereits läuft
if ! docker ps | grep -q exapg-coordinator; then
    warning "ExaPG scheint nicht zu laufen. Das Monitoring wird ohne Datenbankmetriken gestartet."
    warning "Starten Sie ExaPG mit './start-exapg.sh', um alle Metriken zu erhalten."
fi

# Umgebungsvariablen für Grafana laden
if [ -f .env ]; then
    source .env
    export GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
    export GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
    info "Grafana-Anmeldedaten: Benutzer: $GRAFANA_ADMIN_USER, Passwort: $GRAFANA_ADMIN_PASSWORD"
else
    warning ".env-Datei nicht gefunden. Standard-Anmeldedaten für Grafana werden verwendet."
    export GRAFANA_ADMIN_USER=admin
    export GRAFANA_ADMIN_PASSWORD=admin
fi

# Starte den Monitoring-Stack
info "Starte den Monitoring-Stack (Prometheus, Grafana, Exporters)..."
docker compose -f docker-compose.monitoring.yml up -d

# Prüfe, ob die Container laufen
sleep 5
if docker ps | grep -q exapg-prometheus && docker ps | grep -q exapg-grafana; then
    success "Monitoring-Stack erfolgreich gestartet!"
    echo -e "\nZugriff auf die Monitoring-Tools:"
    echo -e "- Prometheus: http://localhost:9090"
    echo -e "- Grafana: http://localhost:3000 (Anmeldung mit $GRAFANA_ADMIN_USER / $GRAFANA_ADMIN_PASSWORD)"
    echo -e "- Alertmanager: http://localhost:9093\n"
    
    echo -e "Grafana-Dashboards:"
    echo -e "- ExaPG Overview: http://localhost:3000/d/exapg-overview"
    echo -e "- ExaPG Analytische Leistung: http://localhost:3000/d/exapg-analytics\n"
else
    error "Einige Monitoring-Container konnten nicht gestartet werden."
    docker compose -f docker-compose.monitoring.yml logs
    exit 1
fi 