#!/bin/bash
# ExaPG - Stop Virtual Schemas
# Skript zum Stoppen des ExaPG-Systems mit Virtual Schemas

set -e

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Stoppe ExaPG mit Virtual Schemas...${NC}"

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    docker compose -f docker/docker-compose/docker-compose.virtual_schemas.yml down
else
    # Docker Compose V1 (Fallback)
    docker-compose -f docker/docker-compose/docker-compose.virtual_schemas.yml down
fi

echo -e "${GREEN}ExaPG mit Virtual Schemas wurde gestoppt.${NC}"
echo -e "${YELLOW}Die Daten bleiben in Docker-Volumes erhalten und sind bei erneutem Start verfügbar.${NC}"
echo -e "${YELLOW}Um alle Daten zu löschen, führen Sie aus:${NC}"
echo -e "${RED}docker volume rm \$(docker volume ls -q | grep exapg)${NC}" 