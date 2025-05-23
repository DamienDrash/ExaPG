#!/bin/bash
# ExaPG - Setup ETL-Framework
# Skript zur automatisierten Einrichtung des ETL-Frameworks für verschiedene Datenquellen und CDC

set -e

# Standardwerte für Umgebungsvariablen
POSTGRES_HOST=${POSTGRES_HOST:-exapg}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-postgres}
KAFKA_HOST=${KAFKA_HOST:-kafka}
KAFKA_PORT=${KAFKA_PORT:-9092}
CONNECT_HOST=${CONNECT_HOST:-connect}
CONNECT_PORT=${CONNECT_PORT:-8083}
ETL_BATCH_SIZE=${ETL_BATCH_SIZE:-100000}
ETL_PARALLEL_JOBS=${ETL_PARALLEL_JOBS:-8}

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Ausführen von SQL-Befehlen
run_sql() {
    local sql="$1"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql"
}

# Funktion zum Ausführen von SQL-Dateien
run_sql_file() {
    local file="$1"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$file"
}

# Funktion zum Warten auf einen Service
wait_for_service() {
    local host="$1"
    local port="$2"
    local service_name="$3"
    local max_attempts=30
    local attempt=1
    
    echo -e "${BLUE}Warte auf $service_name ($host:$port)...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" >/dev/null 2>&1; then
            echo -e "${GREEN}$service_name ist verfügbar!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Warte auf $service_name (Versuch $attempt/$max_attempts)...${NC}"
        sleep 2
        attempt=$((attempt+1))
    done
    
    echo -e "${RED}$service_name ist nach $max_attempts Versuchen nicht verfügbar!${NC}"
    return 1
}

# Funktion zum Einrichten des ETL-Frameworks in der Datenbank
setup_etl_database() {
    echo -e "${BLUE}Richte ETL-Framework in der Datenbank ein...${NC}"
    
    # Führe die Framework-SQL-Skripte aus
    if [ -f "/docker-entrypoint-initdb.d/create_etl_framework.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_etl_framework.sql"
    elif [ -f "/sql/etl/create_etl_framework.sql" ]; then
        run_sql_file "/sql/etl/create_etl_framework.sql"
    else
        echo -e "${RED}ETL-Framework-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    # Führe die Utility-SQL-Skripte aus
    if [ -f "/docker-entrypoint-initdb.d/create_etl_utils.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_etl_utils.sql"
    elif [ -f "/sql/etl/create_etl_utils.sql" ]; then
        run_sql_file "/sql/etl/create_etl_utils.sql"
    else
        echo -e "${RED}ETL-Utils-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    # Führe die Beispiel-ETL-Jobs-SQL-Skripte aus
    if [ -f "/docker-entrypoint-initdb.d/example_etl_jobs.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/example_etl_jobs.sql"
    elif [ -f "/sql/etl/example_etl_jobs.sql" ]; then
        run_sql_file "/sql/etl/example_etl_jobs.sql"
    else
        echo -e "${RED}Beispiel-ETL-Jobs-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}ETL-Framework wurde in der Datenbank eingerichtet.${NC}"
}

# Funktion zum Konfigurieren von Kafka
setup_kafka() {
    if [ "$ETL_CDC_ENABLED" != "true" ]; then
        echo -e "${YELLOW}CDC ist deaktiviert. Kafka-Setup wird übersprungen.${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Konfiguriere Kafka für CDC...${NC}"
    
    # Warte auf Kafka
    wait_for_service "$KAFKA_HOST" "$KAFKA_PORT" "Kafka" || return 1
    
    # Erstelle Kafka-Topics für CDC
    # Dies wird normalerweise automatisch von Debezium Connect durchgeführt
    
    echo -e "${GREEN}Kafka für CDC konfiguriert.${NC}"
}

# Funktion zum Konfigurieren von Debezium Connect
setup_debezium_connect() {
    if [ "$ETL_CDC_ENABLED" != "true" ]; then
        echo -e "${YELLOW}CDC ist deaktiviert. Debezium Connect-Setup wird übersprungen.${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Konfiguriere Debezium Connect für CDC...${NC}"
    
    # Warte auf Debezium Connect
    wait_for_service "$CONNECT_HOST" "$CONNECT_PORT" "Debezium Connect" || return 1
    
    # Liste der vorhandenen Connectoren abrufen
    echo -e "${BLUE}Prüfe vorhandene Connectoren...${NC}"
    CONNECTORS=$(curl -s "http://$CONNECT_HOST:$CONNECT_PORT/connectors")
    
    # Hole CDC-Konfigurationen aus der Datenbank
    echo -e "${BLUE}Hole CDC-Konfigurationen aus der Datenbank...${NC}"
    
    # Verwende psql, um Connectoren zu holen
    CDC_CONFIGS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT connector_name, connector_config FROM etl_framework.cdc_configurations WHERE enabled = true;")
    
    if [ -z "$CDC_CONFIGS" ]; then
        echo -e "${YELLOW}Keine aktiven CDC-Konfigurationen gefunden.${NC}"
        return 0
    fi
    
    # Verarbeite jede CDC-Konfiguration
    echo "$CDC_CONFIGS" | while read -r connector_name connector_config; do
        if [ -z "$connector_name" ]; then
            continue
        fi
        
        # Bereinige Whitespace
        connector_name=$(echo "$connector_name" | xargs)
        
        # Prüfe, ob der Connector bereits existiert
        if [[ $CONNECTORS == *"$connector_name"* ]]; then
            echo -e "${YELLOW}Connector '$connector_name' existiert bereits. Überspringe...${NC}"
            continue
        fi
        
        echo -e "${BLUE}Erstelle Connector '$connector_name'...${NC}"
        
        # Extrahiere die Connector-Konfiguration
        CONNECTOR_CONFIG=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT connector_config::text FROM etl_framework.cdc_configurations WHERE connector_name = '$connector_name';")
        
        # Bereinige die JSON-Konfiguration
        CONNECTOR_CONFIG=$(echo "$CONNECTOR_CONFIG" | tr -d '[:space:]' | sed 's/^{//;s/}$//')
        
        # Erstelle den Connector
        curl -s -X POST -H "Content-Type: application/json" \
          --data "{$CONNECTOR_CONFIG}" \
          "http://$CONNECT_HOST:$CONNECT_PORT/connectors" > /dev/null
          
        echo -e "${GREEN}Connector '$connector_name' erstellt.${NC}"
    done
    
    echo -e "${GREEN}Debezium Connect für CDC konfiguriert.${NC}"
}

# Funktion zum Konfigurieren von Airflow für ETL-Orchestrierung
setup_airflow_dags() {
    echo -e "${BLUE}Konfiguriere Airflow DAGs für ETL-Orchestrierung...${NC}"
    
    # Stelle sicher, dass das Airflow DAGs-Verzeichnis existiert
    AIRFLOW_DAGS_DIR="/opt/airflow/dags"
    if [ ! -d "$AIRFLOW_DAGS_DIR" ]; then
        echo -e "${YELLOW}Airflow DAGs-Verzeichnis nicht gefunden. Übersprunge...${NC}"
        return 0
    fi
    
    # Kopiere ETL-DAGs nach Airflow, falls vorhanden
    if [ -d "/scripts/etl" ]; then
        cp -r /scripts/etl/*.py "$AIRFLOW_DAGS_DIR/" 2>/dev/null || true
        echo -e "${GREEN}ETL-DAGs wurden nach Airflow kopiert.${NC}"
    else
        echo -e "${YELLOW}Keine ETL-DAGs zum Kopieren gefunden.${NC}"
    fi
}

# Funktion zum Ausführen der ersten ETL-Jobs zum Testen
run_initial_etl_jobs() {
    echo -e "${BLUE}Führe initiale ETL-Jobs aus...${NC}"
    
    # Hole eine Liste aller verfügbaren ETL-Jobs
    JOB_IDS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT job_id FROM etl_framework.etl_jobs WHERE enabled = true;")
    
    if [ -z "$JOB_IDS" ]; then
        echo -e "${YELLOW}Keine aktiven ETL-Jobs gefunden.${NC}"
        return 0
    fi
    
    # Führe jeden Job aus
    for job_id in $JOB_IDS; do
        if [ -z "$job_id" ]; then
            continue
        fi
        
        # Bereinige Whitespace
        job_id=$(echo "$job_id" | xargs)
        
        echo -e "${BLUE}Führe ETL-Job mit ID $job_id aus...${NC}"
        
        # Führe den ETL-Job aus
        result=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT etl_framework.run_etl_job($job_id, true);")
        
        echo -e "${GREEN}ETL-Job $job_id ausgeführt: $result${NC}"
    done
    
    echo -e "${GREEN}Initiale ETL-Jobs wurden ausgeführt.${NC}"
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - ETL-Framework Einrichtung${NC}"
    echo -e "${BLUE}===============================${NC}"
    
    # Warte auf PostgreSQL
    wait_for_service "$POSTGRES_HOST" "$POSTGRES_PORT" "PostgreSQL" || exit 1
    
    # Setze die ETL-Konfiguration auf
    setup_etl_database
    
    # Konfiguriere Kafka
    setup_kafka
    
    # Konfiguriere Debezium Connect
    setup_debezium_connect
    
    # Konfiguriere Airflow
    setup_airflow_dags
    
    # Führe initiale ETL-Jobs aus
    run_initial_etl_jobs
    
    echo -e "${GREEN}ETL-Framework wurde erfolgreich eingerichtet!${NC}"
    echo -e "${GREEN}Sie können nun ETL-Jobs über die folgenden Wege ausführen:${NC}"
    echo -e "${YELLOW}1. Manuell: SELECT etl_framework.run_etl_job(job_id);${NC}"
    echo -e "${YELLOW}2. Automatisiert: Airflow DAGs auf http://localhost:8080${NC}"
    echo -e "${YELLOW}3. CDC: Änderungen werden automatisch über Kafka verfolgt und verarbeitet${NC}"
}

# Skript ausführen
main 