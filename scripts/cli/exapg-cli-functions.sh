#!/bin/bash
# ExaPG CLI - Funktionsbibliothek

# Farbdefinitionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# Hilfsfunktionen für Ausgabe
print_message() {
  echo -e "${BLUE}[ExaPG]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[ExaPG]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[ExaPG]${NC} $1"
}

print_error() {
  echo -e "${RED}[ExaPG]${NC} $1"
}

print_info() {
  echo -e "${CYAN}[ExaPG]${NC} $1"
}

# Voraussetzungen prüfen
check_prerequisites() {
  # Docker prüfen
  if ! command -v docker &> /dev/null; then
    print_error "Docker wurde nicht gefunden. Bitte installieren Sie Docker."
    return 1
  fi

  # Docker Compose prüfen
  if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose wurde nicht gefunden. Bitte installieren Sie Docker Compose."
    return 1
  fi

  # .env Datei prüfen und ggf. erstellen
  if [ ! -f .env ]; then
    print_message "Keine .env-Datei gefunden. Erstelle Standardkonfiguration..."
    cp .env.example .env
    print_success ".env-Datei mit Standardkonfiguration erstellt."
  fi

  # Lade Konfiguration aus .env
  source .env
  return 0
}

# Banner anzeigen
show_banner() {
  clear
  echo -e "${BLUE}${BOLD}"
  echo "  ______           ____   _____ "
  echo " |  ____|         |  _ \ / ____|"
  echo " | |__  __  ____ _| |_) | |  __ "
  echo " |  __| \ \/ / _\` |  __/| | |_ |"
  echo " | |____ >  < (_| | |   | |__| |"
  echo " |______/_/\_\__,_|_|    \_____|"
  echo -e "${NC}"
  echo -e " ${YELLOW}PostgreSQL-basierte Alternative zu Exasol${NC}"
  echo -e " ${CYAN}Version: ${VERSION}${NC}"
  echo ""
}

# 1. ExaPG Standard
start_exapg() {
  local mode=${1:-$DEPLOYMENT_MODE}
  
  print_message "Starte ExaPG im $mode-Modus..."
  
  # Stoppe alle laufenden Container und bereinige Volumes
  print_message "Stoppe vorherige Instanzen und bereinige Volumes..."
  docker-compose -f docker/docker-compose/docker-compose.yml down -v 2>/dev/null || true
  
  # Starte die Container entsprechend dem gewählten Modus
  if [ "$mode" == "single" ]; then
    print_message "Starte Single-Node-Modus..."
    docker-compose -f docker/docker-compose/docker-compose.yml up -d coordinator
  elif [ "$mode" == "cluster" ]; then
    print_message "Starte Cluster-Modus mit $WORKER_COUNT Worker-Knoten..."
    docker-compose -f docker/docker-compose/docker-compose.yml --profile cluster up -d
  else
    print_error "Ungültiger Modus: $mode"
    return 1
  fi
  
  # Warte auf die Initialisierung
  print_message "Warte auf Initialisierung der Datenbank..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe den Status der Container
  COORDINATOR_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME}-coordinator 2>/dev/null || echo "not_found")
  
  if [ "$COORDINATOR_STATUS" == "healthy" ]; then
    print_success "ExaPG wurde erfolgreich gestartet!"
    display_connection_info
    
    # Setup-Skripte ausführen
    print_message "Führe Initialisierungsskripte aus..."
    docker exec -it ${CONTAINER_NAME}-coordinator bash -c "cd /scripts/setup && ./setup-parallel-processing.sh"
    return 0
  else
    print_error "ExaPG konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs mit 'docker-compose logs'"
    return 1
  fi
}

stop_exapg() {
  print_message "Stoppe ExaPG..."
  docker-compose -f docker/docker-compose/docker-compose.yml down
  print_success "ExaPG wurde gestoppt."
}

# 2. ExaPG mit Citus
start_exapg_citus() {
  print_message "Starte ExaPG mit Citus-Extension..."
  docker-compose -f docker/docker-compose/docker-compose.citus.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.citus.yml up -d
  
  print_message "Warte auf Initialisierung der Citus-Cluster..."
  for i in {1..15}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe den Status der Container
  COORDINATOR_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME}-citus-coordinator 2>/dev/null || echo "not_found")
  
  if [ "$COORDINATOR_STATUS" == "healthy" ]; then
    print_success "ExaPG mit Citus wurde erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Verbindungsinformationen Citus-Cluster:${NC}"
    echo -e "────────────────────────────────────"
    echo -e "${BOLD}Host:${NC}     localhost"
    echo -e "${BOLD}Port:${NC}     $COORDINATOR_PORT"
    echo -e "${BOLD}Benutzer:${NC} $POSTGRES_USER"
    echo -e "${BOLD}Passwort:${NC} $POSTGRES_PASSWORD"
    echo -e "${BOLD}Datenbank:${NC} $POSTGRES_DB"
    echo ""
    echo -e "${ITALIC}Führen Sie folgenden Befehl aus, um eine SQL-Konsole zu öffnen:${NC}"
    echo -e "${BOLD}docker exec -it ${CONTAINER_NAME}-citus-coordinator psql -U $POSTGRES_USER -d $POSTGRES_DB${NC}"
    return 0
  else
    print_error "Citus-Cluster konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_exapg_citus() {
  print_message "Stoppe ExaPG Citus-Cluster..."
  docker-compose -f docker/docker-compose/docker-compose.citus.yml down
  print_success "Citus-Cluster wurde gestoppt."
}

# 3. ExaPG HA (Hochverfügbarkeit)
start_exapg_ha() {
  print_message "Starte ExaPG mit Hochverfügbarkeit (Patroni/pgBouncer)..."
  docker-compose -f docker/docker-compose/docker-compose.ha.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.ha.yml up -d
  
  print_message "Warte auf Initialisierung des HA-Clusters..."
  for i in {1..20}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob Patroni und pgBouncer laufen
  PATRONI_STATUS=$(docker inspect --format='{{.State.Status}}' ${CONTAINER_NAME}-patroni-node1 2>/dev/null || echo "not_found")
  
  if [ "$PATRONI_STATUS" == "running" ]; then
    print_success "ExaPG HA-Cluster wurde erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Verbindungsinformationen HA-Cluster (über pgBouncer):${NC}"
    echo -e "───────────────────────────────────────────────"
    echo -e "${BOLD}Host:${NC}     localhost"
    echo -e "${BOLD}Port:${NC}     6432"
    echo -e "${BOLD}Benutzer:${NC} $POSTGRES_USER"
    echo -e "${BOLD}Passwort:${NC} $POSTGRES_PASSWORD"
    echo -e "${BOLD}Datenbank:${NC} $POSTGRES_DB"
    return 0
  else
    print_error "HA-Cluster konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_exapg_ha() {
  print_message "Stoppe ExaPG HA-Cluster..."
  docker-compose -f docker/docker-compose/docker-compose.ha.yml down
  print_success "HA-Cluster wurde gestoppt."
}

# 4. Monitoring
start_monitoring() {
  print_message "Starte Monitoring-Stack (Prometheus, Grafana, Alertmanager)..."
  docker-compose -f docker/docker-compose/docker-compose.monitoring.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.monitoring.yml up -d
  
  print_message "Warte auf Initialisierung des Monitoring-Stacks..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob Grafana läuft
  GRAFANA_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-grafana 2>/dev/null || echo "not_found")
  
  if [ "$GRAFANA_STATUS" == "running" ]; then
    print_success "Monitoring-Stack wurde erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Zugriff auf die Monitoring-Tools:${NC}"
    echo -e "───────────────────────────────"
    echo -e "${BOLD}Grafana:${NC}       http://localhost:3000 (admin/admin)"
    echo -e "${BOLD}Prometheus:${NC}    http://localhost:9090"
    echo -e "${BOLD}Alertmanager:${NC}  http://localhost:9093"
    return 0
  else
    print_error "Monitoring-Stack konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_monitoring() {
  print_message "Stoppe Monitoring-Stack..."
  docker-compose -f docker/docker-compose/docker-compose.monitoring.yml down
  print_success "Monitoring-Stack wurde gestoppt."
}

# 5. Management-UI
start_management_ui() {
  print_message "Starte Management-UI..."
  docker-compose -f docker/docker-compose/docker-compose.management.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.management.yml up -d
  
  print_message "Warte auf Initialisierung der Management-UI..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob UI-Container laufen
  UI_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-management-ui 2>/dev/null || echo "not_found")
  
  if [ "$UI_STATUS" == "running" ]; then
    print_success "Management-UI wurde erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Zugriff auf die Management-UI:${NC}"
    echo -e "─────────────────────────────"
    echo -e "${BOLD}URL:${NC}       http://localhost:3001"
    echo -e "${BOLD}Benutzer:${NC}  admin"
    echo -e "${BOLD}Passwort:${NC}  admin"
    return 0
  else
    print_error "Management-UI konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_management_ui() {
  print_message "Stoppe Management-UI..."
  docker-compose -f docker/docker-compose/docker-compose.management.yml down
  print_success "Management-UI wurde gestoppt."
}

# 6. UDF Framework
start_udf_framework() {
  print_message "Starte UDF-Framework (LuaJIT, Python, R)..."
  docker-compose -f docker/docker-compose/docker-compose.udf_framework.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.udf_framework.yml up -d
  
  print_message "Warte auf Initialisierung des UDF-Frameworks..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob Framework-Container laufen
  UDF_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-udf-controller 2>/dev/null || echo "not_found")
  
  if [ "$UDF_STATUS" == "running" ]; then
    print_success "UDF-Framework wurde erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Zugriff auf das UDF-Framework:${NC}"
    echo -e "─────────────────────────────"
    echo -e "${BOLD}Jupyter Notebooks:${NC} http://localhost:8888"
    echo -e "${BOLD}R-Studio:${NC}         http://localhost:8787 (user/rstudio)"
    return 0
  else
    print_error "UDF-Framework konnte nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_udf_framework() {
  print_message "Stoppe UDF-Framework..."
  docker-compose -f docker/docker-compose/docker-compose.udf_framework.yml down
  print_success "UDF-Framework wurde gestoppt."
}

# 7. Virtual Schemas
start_virtual_schemas() {
  print_message "Starte Virtual Schemas (Foreign Data Wrapper)..."
  docker-compose -f docker/docker-compose/docker-compose.fdw.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.fdw.yml up -d
  
  print_message "Warte auf Initialisierung der Virtual Schemas..."
  for i in {1..15}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob FDW-Container laufen
  FDW_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-fdw-controller 2>/dev/null || echo "not_found")
  
  if [ "$FDW_STATUS" == "running" ]; then
    print_success "Virtual Schemas wurden erfolgreich gestartet!"
    return 0
  else
    print_error "Virtual Schemas konnten nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_virtual_schemas() {
  print_message "Stoppe Virtual Schemas..."
  docker-compose -f docker/docker-compose/docker-compose.fdw.yml down
  print_success "Virtual Schemas wurden gestoppt."
}

# 8. ETL-Tools
start_etl() {
  print_message "Starte ETL-Tools..."
  docker-compose -f docker/docker-compose/docker-compose.etl.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.etl.yml up -d
  
  print_message "Warte auf Initialisierung der ETL-Tools..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob ETL-Container laufen
  ETL_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-etl-controller 2>/dev/null || echo "not_found")
  
  if [ "$ETL_STATUS" == "running" ]; then
    print_success "ETL-Tools wurden erfolgreich gestartet!"
    echo ""
    echo -e "${CYAN}Zugriff auf die ETL-Tools:${NC}"
    echo -e "─────────────────────────"
    echo -e "${BOLD}Airflow:${NC}    http://localhost:8080 (airflow/airflow)"
    return 0
  else
    print_error "ETL-Tools konnten nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_etl() {
  print_message "Stoppe ETL-Tools..."
  docker-compose -f docker/docker-compose/docker-compose.etl.yml down
  print_success "ETL-Tools wurden gestoppt."
}

# 9. Backup-Tools
start_backup() {
  print_message "Starte Backup-Tools (pgBackRest)..."
  docker-compose -f docker/docker-compose/docker-compose.backup.yml down -v 2>/dev/null || true
  docker-compose -f docker/docker-compose/docker-compose.backup.yml up -d
  
  print_message "Warte auf Initialisierung der Backup-Tools..."
  for i in {1..10}; do
    echo -n "."
    sleep 1
  done
  echo ""
  
  # Überprüfe ob Backup-Container laufen
  BACKUP_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-backup-controller 2>/dev/null || echo "not_found")
  
  if [ "$BACKUP_STATUS" == "running" ]; then
    print_success "Backup-Tools wurden erfolgreich gestartet!"
    return 0
  else
    print_error "Backup-Tools konnten nicht korrekt gestartet werden. Überprüfen Sie die Logs."
    return 1
  fi
}

stop_backup() {
  print_message "Stoppe Backup-Tools..."
  docker-compose -f docker/docker-compose/docker-compose.backup.yml down
  print_success "Backup-Tools wurden gestoppt."
}

# Status-Check mit verbesserter Darstellung
status_check() {
  print_message "Prüfe Status der ExaPG-Komponenten..."
  
  echo ""
  box_width=60
  
  echo -e "┌$( printf '─%.0s' $(seq 1 $box_width) )┐"
  echo -e "│ ${BOLD}Komponente${NC}                         │ ${BOLD}Status${NC}                │"
  echo -e "├$( printf '─%.0s' $(seq 1 $box_width) )┤"
  
  # Standard ExaPG
  EXAPG_STATUS=$(docker inspect --format='{{.State.Status}}' ${CONTAINER_NAME}-coordinator 2>/dev/null || echo "nicht aktiv")
  if [[ "$EXAPG_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "ExaPG Standard" "$EXAPG_STATUS"
  
  # Citus
  CITUS_STATUS=$(docker inspect --format='{{.State.Status}}' ${CONTAINER_NAME}-citus-coordinator 2>/dev/null || echo "nicht aktiv")
  if [[ "$CITUS_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "ExaPG Citus" "$CITUS_STATUS"
  
  # HA-Cluster
  HA_STATUS=$(docker inspect --format='{{.State.Status}}' ${CONTAINER_NAME}-patroni-node1 2>/dev/null || echo "nicht aktiv")
  if [[ "$HA_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "ExaPG HA-Cluster" "$HA_STATUS"
  
  # Monitoring
  MONITORING_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-grafana 2>/dev/null || echo "nicht aktiv")
  if [[ "$MONITORING_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "Monitoring" "$MONITORING_STATUS"
  
  # Management-UI
  UI_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-management-ui 2>/dev/null || echo "nicht aktiv")
  if [[ "$UI_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "Management-UI" "$UI_STATUS"
  
  # UDF-Framework
  UDF_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-udf-controller 2>/dev/null || echo "nicht aktiv")
  if [[ "$UDF_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "UDF-Framework" "$UDF_STATUS"
  
  # Virtual Schemas
  FDW_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-fdw-controller 2>/dev/null || echo "nicht aktiv")
  if [[ "$FDW_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "Virtual Schemas" "$FDW_STATUS"
  
  # ETL-Tools
  ETL_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-etl-controller 2>/dev/null || echo "nicht aktiv")
  if [[ "$ETL_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "ETL-Tools" "$ETL_STATUS"
  
  # Backup-Tools
  BACKUP_STATUS=$(docker inspect --format='{{.State.Status}}' exapg-backup-controller 2>/dev/null || echo "nicht aktiv")
  if [[ "$BACKUP_STATUS" == "running" ]]; then
    status_color="${GREEN}"
  else
    status_color="${RED}"
  fi
  printf "│ %-35s │ ${status_color}%-23s${NC} │\n" "Backup-Tools" "$BACKUP_STATUS"
  
  echo -e "└$( printf '─%.0s' $(seq 1 $box_width) )┘"
  
  # Systeminfo anzeigen
  echo -e "\n${CYAN}Systeminfo:${NC}"
  echo -e " • CPU:    $(nproc) Kerne"
  echo -e " • RAM:    $(free -h | awk '/^Mem:/ {print $2}')"
  echo -e " • Disk:   $(df -h / | awk 'NR==2 {print $4 " frei von " $2}')"
  
  # Aktuelle Konfiguration
  echo -e "\n${CYAN}Aktuelle Konfiguration:${NC}"
  echo -e " • Modus:  $DEPLOYMENT_MODE"
  echo -e " • Worker: $WORKER_COUNT"
  echo -e " • Port:   $COORDINATOR_PORT"
}

# Verbesserte Funktion für die Anzeige von Verbindungsinformationen
display_connection_info() {
  echo ""
  echo -e "${CYAN}Verbindungsinformationen:${NC}"
  echo -e "────────────────────────"
  echo -e "${BOLD}Host:${NC}     localhost"
  echo -e "${BOLD}Port:${NC}     $COORDINATOR_PORT"
  echo -e "${BOLD}Benutzer:${NC} $POSTGRES_USER"
  echo -e "${BOLD}Passwort:${NC} $POSTGRES_PASSWORD"
  echo -e "${BOLD}Datenbank:${NC} $POSTGRES_DB"
  echo ""
  echo -e "${ITALIC}Führen Sie folgenden Befehl aus, um eine SQL-Konsole zu öffnen:${NC}"
  echo -e "${BOLD}docker exec -it ${CONTAINER_NAME}-coordinator psql -U $POSTGRES_USER -d $POSTGRES_DB${NC}"
}

# Verbesserte Funktion zum Stoppen aller Komponenten
stop_all() {
  print_message "Stoppe alle ExaPG-Komponenten..."
  
  # Stoppe alle Docker-Compose-Stacks
  components=(
    "ExaPG Standard" 
    "ExaPG Citus" 
    "ExaPG HA-Cluster" 
    "Monitoring" 
    "Management-UI" 
    "UDF-Framework" 
    "Virtual Schemas" 
    "ETL-Tools" 
    "Backup-Tools"
  )
  
  for component in "${components[@]}"; do
    echo -ne "${BLUE}[ExaPG]${NC} Stoppe $component..."
    
    case "$component" in
      "ExaPG Standard")
        docker-compose -f docker/docker-compose/docker-compose.yml down > /dev/null 2>&1
        ;;
      "ExaPG Citus")
        docker-compose -f docker/docker-compose/docker-compose.citus.yml down > /dev/null 2>&1
        ;;
      "ExaPG HA-Cluster")
        docker-compose -f docker/docker-compose/docker-compose.ha.yml down > /dev/null 2>&1
        ;;
      "Monitoring")
        docker-compose -f docker/docker-compose/docker-compose.monitoring.yml down > /dev/null 2>&1
        ;;
      "Management-UI")
        docker-compose -f docker/docker-compose/docker-compose.management.yml down > /dev/null 2>&1
        ;;
      "UDF-Framework")
        docker-compose -f docker/docker-compose/docker-compose.udf_framework.yml down > /dev/null 2>&1
        ;;
      "Virtual Schemas")
        docker-compose -f docker/docker-compose/docker-compose.fdw.yml down > /dev/null 2>&1
        ;;
      "ETL-Tools")
        docker-compose -f docker/docker-compose/docker-compose.etl.yml down > /dev/null 2>&1
        ;;
      "Backup-Tools")
        docker-compose -f docker/docker-compose/docker-compose.backup.yml down > /dev/null 2>&1
        ;;
    esac
    
    if [ $? -eq 0 ]; then
      echo -e "\r${BLUE}[ExaPG]${NC} Stoppe $component... ${GREEN}OK${NC}    "
    else
      echo -e "\r${BLUE}[ExaPG]${NC} Stoppe $component... ${RED}Fehlgeschlagen${NC}"
    fi
  done
  
  print_success "Alle ExaPG-Komponenten wurden gestoppt."
}

# Konfigurationseinstellungen bearbeiten
edit_config() {
  if command -v nano &> /dev/null; then
    nano .env
  elif command -v vim &> /dev/null; then
    vim .env
  else
    print_error "Weder nano noch vim wurde gefunden. Bitte installieren Sie einen Text-Editor."
  fi
  
  # Lade Konfiguration neu
  source .env
  print_success "Konfiguration wurde neu geladen."
} 