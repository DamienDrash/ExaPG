#!/bin/bash
# ExaPG - Start Virtual Schemas
# Skript zum Starten des ExaPG-Systems mit Virtual Schemas

set -e

# Prüfen, ob Docker und Docker Compose installiert sind
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    echo "Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut."
    exit 1
fi

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Erforderliche Verzeichnisse erstellen
mkdir -p sql/virtual_schemas
mkdir -p scripts/setup

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starte ExaPG mit Virtual Schemas...${NC}"

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    DOCKER_COMPOSE="docker compose"
else
    # Docker Compose V1 (Fallback)
    DOCKER_COMPOSE="docker-compose"
fi

# Prüfen, ob Demo-Quelldatenbanken inizialisiert werden sollen
USE_EXAMPLES=${USE_EXAMPLES:-true}
if [ "$USE_EXAMPLES" == "true" ]; then
    echo -e "${YELLOW}Demo-Quelldatenbanken (MySQL, SQL Server, MongoDB, Redis) werden gestartet.${NC}"
    echo -e "${YELLOW}Um dies zu deaktivieren, setzen Sie USE_EXAMPLES=false.${NC}"
else
    echo -e "${YELLOW}Demo-Quelldatenbanken werden nicht gestartet. Nur ExaPG wird gestartet.${NC}"
    echo -e "${YELLOW}Sie können external_examples=true setzen, um die Demo-Datenbanken zu starten.${NC}"
    
    # Erstelle eine temporäre Compose-Datei ohne die Beispieldatenbanken
    TMP_DOCKER_COMPOSE="${PROJECT_DIR}/docker/docker-compose/docker-compose.virtual_schemas_minimal.yml"
    echo "version: '3.8'" > "$TMP_DOCKER_COMPOSE"
    sed -n '/services:/,/  mysql:/p' docker/docker-compose/docker-compose.virtual_schemas.yml | sed '$d' >> "$TMP_DOCKER_COMPOSE"
    echo "networks:" >> "$TMP_DOCKER_COMPOSE"
    echo "  exapg-network:" >> "$TMP_DOCKER_COMPOSE"
    echo "    driver: bridge" >> "$TMP_DOCKER_COMPOSE"
    echo "volumes:" >> "$TMP_DOCKER_COMPOSE"
    echo "  exapg-data:" >> "$TMP_DOCKER_COMPOSE"
    
    # Verwende die minimale Compose-Datei
    $DOCKER_COMPOSE -f "$TMP_DOCKER_COMPOSE" up -d
    
    # Lösche die temporäre Datei
    rm "$TMP_DOCKER_COMPOSE"
else
    # Starte das gesamte System mit allen Beispielen
    $DOCKER_COMPOSE -f docker/docker-compose/docker-compose.virtual_schemas.yml up -d
fi

echo -e "${GREEN}ExaPG mit Virtual Schemas wurde gestartet!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}PostgreSQL ist verfügbar unter: localhost:5432${NC}"
echo -e "${GREEN}Benutzer: ${POSTGRES_USER:-postgres}${NC}"
echo -e "${GREEN}Passwort: ${POSTGRES_PASSWORD:-postgres}${NC}"
echo -e "${GREEN}Datenbank: ${POSTGRES_DB:-postgres}${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Verfügbare Virtual Schemas:${NC}"

if [ "$USE_EXAMPLES" == "true" ]; then
    echo -e "${GREEN}mysql_vs - MySQL-Datenbank${NC}"
    echo -e "${GREEN}mssql_vs - SQL Server-Datenbank${NC}"
    echo -e "${GREEN}mongodb_vs - MongoDB-Datenbank${NC}"
    echo -e "${GREEN}redis_vs - Redis-Datenbank${NC}"
fi

echo -e "${GREEN}=============================================${NC}"
echo -e "${BLUE}Beispielabfragen:${NC}"
echo -e "${YELLOW}-- Verfügbare Tabellen anzeigen:${NC}"
echo -e "${YELLOW}SELECT * FROM vs_metadata.get_foreign_table_info('mysql_vs');${NC}"
echo -e "${YELLOW}-- Daten abfragen:${NC}"
echo -e "${YELLOW}SELECT * FROM mysql_vs.users;${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${BLUE}Zum Stoppen des Virtual Schemas-Systems führen Sie aus:${NC}"
echo -e "${YELLOW}./stop-exapg-virtual-schemas.sh${NC}" 