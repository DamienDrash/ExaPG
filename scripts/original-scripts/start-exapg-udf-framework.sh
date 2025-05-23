#!/bin/bash
# ExaPG - UDF-Framework starten
# Dieses Skript startet die ExaPG-Umgebung mit UDF-Framework-Unterstützung

set -e

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Start der ExaPG-Umgebung
start_exapg_udf_framework() {
    echo -e "${BLUE}Starte ExaPG mit UDF-Framework...${NC}"
    
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
    
    # Setze UDF-Framework-Umgebungsvariablen
    export UDF_FRAMEWORK_ENABLED=true
    export UDF_ENABLE_PYTHON=${UDF_ENABLE_PYTHON:-true}
    export UDF_ENABLE_R=${UDF_ENABLE_R:-true}
    export UDF_ENABLE_LUA=${UDF_ENABLE_LUA:-true}
    
    # Aktivierungsstatus anzeigen
    echo -e "${GREEN}UDF-Framework aktiviert mit folgenden Sprachen:${NC}"
    [ "$UDF_ENABLE_PYTHON" = "true" ] && echo -e "${GREEN}- Python${NC}"
    [ "$UDF_ENABLE_R" = "true" ] && echo -e "${GREEN}- R${NC}"
    [ "$UDF_ENABLE_LUA" = "true" ] && echo -e "${GREEN}- Lua${NC}"
    
    # Starte die Services mit Docker Compose
    echo -e "${BLUE}Starte Docker-Container...${NC}"
    docker compose -f docker/docker-compose/docker-compose.udf_framework.yml up -d
    
    # Prüfe, ob die Container erfolgreich gestartet wurden
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ExaPG mit UDF-Framework wurde erfolgreich gestartet.${NC}"
        
        # Zeige Verbindungsinformationen an
        echo -e "${BLUE}Verbindungsinformationen:${NC}"
        echo -e "${YELLOW}PostgreSQL: localhost:5432${NC}"
        echo -e "${YELLOW}Benutzername: ${POSTGRES_USER:-postgres}${NC}"
        echo -e "${YELLOW}Passwort: ${POSTGRES_PASSWORD:-postgres}${NC}"
        echo -e "${YELLOW}Datenbank: ${POSTGRES_DB:-postgres}${NC}"
        
        # Zeige Informationen zu den Development-Umgebungen an
        echo -e "${BLUE}Development-Umgebungen:${NC}"
        echo -e "${YELLOW}Jupyter Notebook: http://localhost:8888${NC}"
        echo -e "${YELLOW}RStudio: http://localhost:8787${NC}"
        echo -e "${YELLOW}RStudio Benutzername: ${RSTUDIO_USER:-rstudio}${NC}"
        echo -e "${YELLOW}RStudio Passwort: ${RSTUDIO_PASSWORD:-rstudio}${NC}"
        
        # Zeige Beispiel-Befehle an
        echo -e "${BLUE}Beispielbefehle für die Verbindung mit psql:${NC}"
        echo -e "${YELLOW}psql -h localhost -p 5432 -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres}${NC}"
        
        echo -e "${BLUE}Beispielbefehle zum Testen der UDFs:${NC}"
        echo -e "${YELLOW}SELECT * FROM udf_framework.udf_catalog_view;${NC}"
        echo -e "${YELLOW}SELECT analytics.text_analysis('Dies ist ein Beispieltext zur Analyse');${NC}"
        
        echo -e "${GREEN}Die Setup-Phase für das UDF-Framework läuft automatisch. Bitte warten Sie einige Sekunden, bis alle Komponenten initialisiert sind.${NC}"
    else
        echo -e "${RED}Fehler beim Starten von ExaPG mit UDF-Framework.${NC}"
        exit 1
    fi
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - UDF-Framework${NC}"
    echo -e "${BLUE}=====================${NC}"
    
    # Starte ExaPG mit UDF-Framework
    start_exapg_udf_framework
}

# Führe Hauptfunktion aus
main 