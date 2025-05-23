#!/bin/bash

# start-management-ui.sh
# Dieses Skript startet die ExaPG Management-UI
#
# ExaPG - PostgreSQL-basierte analytische Datenbank-Plattform

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # Keine Farbe

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ExaPG Management-UI starten                  ║${NC}"
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

# Management-UI starten
echo -e "${YELLOW}Management-UI wird gestartet...${NC}"

cd docker/docker-compose && docker-compose -f docker-compose.management-ui.yml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Management-UI wurde erfolgreich gestartet!${NC}"
    echo -e "${GREEN}Die Oberfläche ist unter folgenden URLs erreichbar:${NC}"
    echo -e "${GREEN}  - Management-UI: http://localhost:3002${NC}"
    echo -e "${GREEN}  - pgAdmin: http://localhost:5051${NC}"
    echo -e "${GREEN}  - PostgreSQL: localhost:5435${NC}"
    echo ""
    echo -e "${YELLOW}Standardanmeldedaten für die Management-UI:${NC}"
    echo -e "${YELLOW}  Benutzername: admin${NC}"
    echo -e "${YELLOW}  Passwort: admin123${NC}"
else
    echo -e "${RED}Fehler beim Starten der Management-UI!${NC}"
    exit 1
fi 