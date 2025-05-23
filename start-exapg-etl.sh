#!/bin/bash
# ExaPG - ETL-Framework starten
# Dieses Skript startet die ExaPG-Umgebung mit ETL-Framework-Unterstützung

set -e

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Start der ExaPG-Umgebung mit ETL-Framework
start_exapg_etl() {
    echo -e "${BLUE}Starte ExaPG mit ETL-Framework...${NC}"
    
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
    
    # Setze ETL-Framework-Umgebungsvariablen
    export ETL_FRAMEWORK_ENABLED=true
    export ETL_BATCH_SIZE=${ETL_BATCH_SIZE:-100000}
    export ETL_PARALLEL_JOBS=${ETL_PARALLEL_JOBS:-8}
    export ETL_CDC_ENABLED=${ETL_CDC_ENABLED:-true}
    export ETL_DATA_QUALITY_ENABLED=${ETL_DATA_QUALITY_ENABLED:-true}
    
    # Setze Airflow-Umgebungsvariablen
    export AIRFLOW_USER=${AIRFLOW_USER:-admin}
    export AIRFLOW_PASSWORD=${AIRFLOW_PASSWORD:-admin}
    
    # Aktivierungsstatus anzeigen
    echo -e "${GREEN}ETL-Framework aktiviert mit folgenden Konfigurationen:${NC}"
    echo -e "${GREEN}- Batch-Größe: ${ETL_BATCH_SIZE}${NC}"
    echo -e "${GREEN}- Parallele Jobs: ${ETL_PARALLEL_JOBS}${NC}"
    [ "$ETL_CDC_ENABLED" = "true" ] && echo -e "${GREEN}- CDC (Change Data Capture): Aktiviert${NC}" || echo -e "${GREEN}- CDC (Change Data Capture): Deaktiviert${NC}"
    [ "$ETL_DATA_QUALITY_ENABLED" = "true" ] && echo -e "${GREEN}- Datenqualitätsprüfungen: Aktiviert${NC}" || echo -e "${GREEN}- Datenqualitätsprüfungen: Deaktiviert${NC}"
    
    # Erstelle Datenverzeichnis, falls es nicht existiert
    if [ ! -d "data" ]; then
        mkdir -p data
        echo -e "${GREEN}Datenverzeichnis für ETL-Prozesse erstellt.${NC}"
    fi
    
    # Erstelle scripts/etl-Verzeichnis, falls es nicht existiert
    if [ ! -d "scripts/etl" ]; then
        mkdir -p scripts/etl
        echo -e "${GREEN}ETL-Skriptverzeichnis erstellt.${NC}"
    fi
    
    # Starte die Services mit Docker Compose
    echo -e "${BLUE}Starte Docker-Container...${NC}"
    docker compose -f docker/docker-compose/docker-compose.etl.yml up -d
    
    # Prüfe, ob die Container erfolgreich gestartet wurden
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ExaPG mit ETL-Framework wurde erfolgreich gestartet.${NC}"
        
        # Zeige Verbindungsinformationen an
        echo -e "${BLUE}Verbindungsinformationen:${NC}"
        echo -e "${YELLOW}PostgreSQL: localhost:5432${NC}"
        echo -e "${YELLOW}Benutzername: ${POSTGRES_USER:-postgres}${NC}"
        echo -e "${YELLOW}Passwort: ${POSTGRES_PASSWORD:-postgres}${NC}"
        echo -e "${YELLOW}Datenbank: ${POSTGRES_DB:-postgres}${NC}"
        
        # Zeige CDC-Informationen an, falls aktiviert
        if [ "$ETL_CDC_ENABLED" = "true" ]; then
            echo -e "${BLUE}CDC-Informationen:${NC}"
            echo -e "${YELLOW}Kafka: localhost:9092${NC}"
            echo -e "${YELLOW}Debezium Connect: http://localhost:8083${NC}"
        fi
        
        # Zeige ETL-Orchestrierungsinformationen an
        echo -e "${BLUE}ETL-Orchestrierung:${NC}"
        echo -e "${YELLOW}Airflow: http://localhost:8080${NC}"
        echo -e "${YELLOW}Airflow Benutzername: ${AIRFLOW_USER:-admin}${NC}"
        echo -e "${YELLOW}Airflow Passwort: ${AIRFLOW_PASSWORD:-admin}${NC}"
        
        # Zeige Beispiel-Befehle an
        echo -e "${BLUE}Beispielbefehle zum Ausführen von ETL-Jobs:${NC}"
        echo -e "${YELLOW}psql -h localhost -p 5432 -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} -c \"SELECT * FROM etl_framework.active_jobs;\"${NC}"
        echo -e "${YELLOW}psql -h localhost -p 5432 -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} -c \"SELECT etl_framework.run_etl_job(1);\"${NC}"
        
        echo -e "${GREEN}Die Setup-Phase für das ETL-Framework läuft automatisch. Bitte warten Sie einige Minuten, bis alle Komponenten initialisiert sind.${NC}"
    else
        echo -e "${RED}Fehler beim Starten von ExaPG mit ETL-Framework.${NC}"
        exit 1
    fi
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - ETL-Framework${NC}"
    echo -e "${BLUE}====================${NC}"
    
    # Starte ExaPG mit ETL-Framework
    start_exapg_etl
}

# Führe Hauptfunktion aus
main 