#!/bin/bash
# ExaPG - Stop Cluster Management
# Skript zum Stoppen des Cluster-Management-Systems

set -e

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "Stoppe ExaPG Cluster-Management-System..."

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    docker compose -f docker/docker-compose/docker-compose.cluster-management.yml down
else
    # Docker Compose V1 (Fallback)
    docker-compose -f docker/docker-compose/docker-compose.cluster-management.yml down
fi

echo "Das ExaPG Cluster-Management-System wurde gestoppt." 