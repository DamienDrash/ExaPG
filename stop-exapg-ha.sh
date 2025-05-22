#!/bin/bash
# ExaPG - Stop High Availability Cluster
# Skript zum Stoppen des hochverfügbaren ExaPG-Systems

set -e

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "Stoppe hochverfügbares ExaPG-System..."

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    docker compose -f docker/docker-compose/docker-compose.ha.yml down
else
    # Docker Compose V1 (Fallback)
    docker-compose -f docker/docker-compose/docker-compose.ha.yml down
fi

echo "Das hochverfügbare ExaPG-System wurde gestoppt."
echo "Die Daten bleiben in Docker-Volumes erhalten." 