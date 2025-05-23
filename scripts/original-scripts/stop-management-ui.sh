#!/bin/bash

# stop-management-ui.sh
# Dieses Skript stoppt die ExaPG Management-UI
#
# ExaPG - PostgreSQL-basierte analytische Datenbank-Plattform

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # Keine Farbe

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                ExaPG Management-UI stoppen                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Prüfen, ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker ist nicht installiert!${NC}"
    exit 1
fi

# Prüfen, ob Docker Compose installiert ist
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose ist nicht installiert!${NC}"
    exit 1
fi

# Management-UI stoppen
echo -e "${YELLOW}Management-UI wird gestoppt...${NC}"

cd docker/docker-compose && docker-compose -f docker-compose.management-ui.yml down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Management-UI wurde erfolgreich gestoppt!${NC}"
else
    echo -e "${RED}Fehler beim Stoppen der Management-UI!${NC}"
    exit 1
fi 