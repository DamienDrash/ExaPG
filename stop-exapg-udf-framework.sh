#!/bin/bash
# ExaPG - UDF-Framework stoppen
# Dieses Skript stoppt die ExaPG-Umgebung mit UDF-Framework-Unterstützung

set -e

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Stoppen der ExaPG-Umgebung mit UDF-Framework
stop_exapg_udf_framework() {
    echo -e "${BLUE}Stoppe ExaPG mit UDF-Framework...${NC}"
    
    # Prüfe, ob Docker und Docker Compose installiert sind
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut.${NC}"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut.${NC}"
        exit 1
    fi
    
    # Lade Umgebungsvariablen, falls vorhanden
    if [ -f .env ]; then
        echo -e "${GREEN}Lade Umgebungsvariablen aus .env-Datei...${NC}"
        source .env
    else
        echo -e "${YELLOW}Keine .env-Datei gefunden. Verwende Standardwerte...${NC}"
    fi
    
    # Stoppe die Services mit Docker Compose
    echo -e "${BLUE}Stoppe Docker-Container...${NC}"
    docker compose -f docker/docker-compose/docker-compose.udf_framework.yml down
    
    # Prüfe, ob die Container erfolgreich gestoppt wurden
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ExaPG mit UDF-Framework wurde erfolgreich gestoppt.${NC}"
        
        # Frage den Benutzer, ob die Volumes gelöscht werden sollen
        read -p "Möchten Sie auch alle persistenten Daten löschen? (j/n): " delete_volumes
        if [[ "$delete_volumes" =~ ^[jJ]$ ]]; then
            echo -e "${YELLOW}Lösche Docker-Volumes...${NC}"
            docker volume rm $(docker volume ls -q | grep -E "exapg_exapg-data|exapg_jupyter-data|exapg_r-data") 2>/dev/null || true
            echo -e "${GREEN}Docker-Volumes wurden gelöscht.${NC}"
        else
            echo -e "${GREEN}Docker-Volumes wurden beibehalten.${NC}"
        fi
    else
        echo -e "${RED}Fehler beim Stoppen von ExaPG mit UDF-Framework.${NC}"
        exit 1
    fi
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - UDF-Framework stoppen${NC}"
    echo -e "${BLUE}============================${NC}"
    
    # Stoppe ExaPG mit UDF-Framework
    stop_exapg_udf_framework
}

# Führe Hauptfunktion aus
main 