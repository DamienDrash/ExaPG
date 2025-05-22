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

# Prüfen, ob der Monitoring-Stack läuft
if ! docker ps | grep -q "exapg-prometheus\|exapg-grafana"; then
    warning "Monitoring-Stack scheint nicht zu laufen."
    exit 0
fi

# Stoppe den Monitoring-Stack
info "Stoppe den Monitoring-Stack..."
docker compose -f docker-compose.monitoring.yml down

# Prüfen, ob die Container noch laufen
if docker ps | grep -q "exapg-prometheus\|exapg-grafana"; then
    error "Monitoring-Stack konnte nicht vollständig gestoppt werden."
    exit 1
else
    success "Monitoring-Stack erfolgreich gestoppt!"
fi 