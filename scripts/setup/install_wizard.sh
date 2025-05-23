#!/bin/bash
# ExaPG Complete Installation Wizard
# Vollständiger Installationsassistent mit moderner Benutzeroberfläche

set -e

# Farbdefinitionen
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Global Variables
INSTALL_DIR=$(pwd)
LOG_FILE="/tmp/exapg_install.log"
CONFIG_FILE=".env"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    ExaPG Installation Wizard                        ║"
    echo "║                                                                      ║"
    echo "║           PostgreSQL-basierte Alternative zu Exasol                 ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo -e "${BOLD}${CYAN}▶ $1${NC}"
    echo -e "${CYAN}$(printf '═%.0s' $(seq 1 ${#1}))${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if dialog is available for advanced UI
check_ui_capabilities() {
    if command -v dialog &> /dev/null; then
        UI_AVAILABLE=true
        export DIALOGRC=/tmp/exapg_dialogrc
        cat > $DIALOGRC << 'EOF'
use_colors = ON
screen_color = (WHITE,BLUE,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (BLUE,WHITE,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
EOF
    else
        UI_AVAILABLE=false
    fi
}

# System Requirements Check
check_system_requirements() {
    print_section "System-Voraussetzungen prüfen"
    
    local requirements_met=true
    
    # Docker prüfen
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Docker gefunden: Version $docker_version"
    else
        print_error "Docker ist nicht installiert"
        requirements_met=false
    fi
    
    # Docker Compose prüfen
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Docker Compose gefunden: Version $compose_version"
    else
        print_error "Docker Compose ist nicht installiert"
        requirements_met=false
    fi
    
    # System Resources prüfen
    local total_ram=$(free -g | grep '^Mem:' | awk '{print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_info "System-Ressourcen:"
    echo "  RAM: ${total_ram}GB"
    echo "  CPU Cores: $cpu_cores"
    echo "  Verfügbarer Speicher: ${disk_space}GB"
    
    if [ "$total_ram" -lt 4 ]; then
        print_warning "Empfohlen: Mindestens 4GB RAM für optimale Performance"
    fi
    
    if [ "$disk_space" -lt 10 ]; then
        print_warning "Empfohlen: Mindestens 10GB freier Speicher"
    fi
    
    # Git prüfen
    if command -v git &> /dev/null; then
        print_success "Git gefunden"
    else
        print_warning "Git ist nicht installiert (optional für Updates)"
    fi
    
    if [ "$requirements_met" = false ]; then
        echo ""
        print_error "Einige Voraussetzungen sind nicht erfüllt."
        echo ""
        echo "Installation von Docker und Docker Compose:"
        echo "Ubuntu/Debian: sudo apt-get install docker.io docker-compose"
        echo "CentOS/RHEL:   sudo yum install docker docker-compose"
        echo "Arch Linux:    sudo pacman -S docker docker-compose"
        echo ""
        exit 1
    fi
    
    echo ""
    print_success "Alle System-Voraussetzungen erfüllt!"
    sleep 2
}

# Advanced Configuration with Dialog
advanced_config_dialog() {
    if [ "$UI_AVAILABLE" = true ]; then
        exec 3>&1
        values=$(dialog --title "ExaPG Konfiguration" \
                        --form "Konfigurieren Sie ExaPG-Parameter:" 20 60 12 \
                        "Cluster Name:"             1 1 "exapg-cluster"    1 25 25 0 \
                        "Container Prefix:"         2 1 "exapg"            2 25 25 0 \
                        "PostgreSQL Password:"      3 1 "postgres"         3 25 25 0 \
                        "Koordinator Port:"         4 1 "5432"             4 25 25 0 \
                        "Worker Anzahl:"            5 1 "2"                5 25 25 0 \
                        "Shared Memory (GB):"       6 1 "4"                6 25 25 0 \
                        "Work Memory (MB):"         7 1 "256"              7 25 25 0 \
                        "Max Workers:"              8 1 "8"                8 25 25 0 \
                        "Enable JIT:"               9 1 "on"               9 25 25 0 \
                        "Enable SSL:"              10 1 "off"             10 25 25 0 \
                        "Backup Retention (days):" 11 1 "7"               11 25 25 0 \
                        2>&1 1>&3)
        exec 3>&-
        
        if [ $? -eq 0 ]; then
            IFS=$'\n' read -rd '' -a config_values <<<"$values"
            
            CLUSTER_NAME="${config_values[0]}"
            CONTAINER_NAME="${config_values[1]}"
            POSTGRES_PASSWORD="${config_values[2]}"
            COORDINATOR_PORT="${config_values[3]}"
            WORKER_COUNT="${config_values[4]}"
            SHARED_BUFFERS="${config_values[5]}GB"
            WORK_MEM="${config_values[6]}MB"
            MAX_PARALLEL_WORKERS="${config_values[7]}"
            JIT_ENABLED="${config_values[8]}"
            SSL_ENABLED="${config_values[9]}"
            BACKUP_RETENTION="${config_values[10]}"
        fi
    else
        advanced_config_manual
    fi
}

# Manual Configuration Input
advanced_config_manual() {
    print_section "Erweiterte Konfiguration"
    
    read -p "Cluster Name [$CLUSTER_NAME]: " input
    CLUSTER_NAME=${input:-$CLUSTER_NAME}
    
    read -p "Container Prefix [$CONTAINER_NAME]: " input
    CONTAINER_NAME=${input:-$CONTAINER_NAME}
    
    read -s -p "PostgreSQL Password [$POSTGRES_PASSWORD]: " input
    POSTGRES_PASSWORD=${input:-$POSTGRES_PASSWORD}
    echo ""
    
    read -p "Koordinator Port [$COORDINATOR_PORT]: " input
    COORDINATOR_PORT=${input:-$COORDINATOR_PORT}
    
    read -p "Anzahl Worker-Knoten [$WORKER_COUNT]: " input
    WORKER_COUNT=${input:-$WORKER_COUNT}
    
    read -p "Shared Memory in GB [4]: " input
    SHARED_BUFFERS="${input:-4}GB"
    
    read -p "Work Memory in MB [256]: " input
    WORK_MEM="${input:-256}MB"
    
    read -p "Max Parallel Workers [8]: " input
    MAX_PARALLEL_WORKERS=${input:-8}
    
    read -p "JIT Kompilierung aktivieren? [j/N]: " input
    JIT_ENABLED=$([[ "$input" =~ ^[jJ]$ ]] && echo "on" || echo "off")
    
    read -p "SSL verschlüsselung aktivieren? [j/N]: " input
    SSL_ENABLED=$([[ "$input" =~ ^[jJ]$ ]] && echo "on" || echo "off")
}

# Component Selection
select_components() {
    if [ "$UI_AVAILABLE" = true ]; then
        exec 3>&1
        selection=$(dialog --title "Komponenten-Auswahl" \
                          --checklist "Wählen Sie die zu installierenden Komponenten:" 20 70 10 \
                          "standard"     "ExaPG Standard"                     ON \
                          "citus"        "Citus (Verteilte Datenbank)"       OFF \
                          "ha"           "Hochverfügbarkeit (Patroni)"       OFF \
                          "monitoring"   "Monitoring (Grafana/Prometheus)"   ON \
                          "management"   "Management UI"                     ON \
                          "udf"          "UDF Framework (Lua/Python/R)"     OFF \
                          "fdw"          "Virtual Schemas (FDW)"             OFF \
                          "etl"          "ETL-Tools (Airflow)"               OFF \
                          "backup"       "Backup-Tools (pgBackRest)"         ON \
                          2>&1 1>&3)
        exec 3>&-
        
        SELECTED_COMPONENTS=($selection)
    else
        select_components_manual
    fi
}

select_components_manual() {
    print_section "Komponenten-Auswahl"
    
    SELECTED_COMPONENTS=("standard")
    
    echo "Wählen Sie zusätzliche Komponenten:"
    echo ""
    
    read -p "Citus (Verteilte Datenbank) installieren? [j/N]: " input
    [[ "$input" =~ ^[jJ]$ ]] && SELECTED_COMPONENTS+=("citus")
    
    read -p "Hochverfügbarkeit (Patroni) installieren? [j/N]: " input
    [[ "$input" =~ ^[jJ]$ ]] && SELECTED_COMPONENTS+=("ha")
    
    read -p "Monitoring (Grafana/Prometheus) installieren? [J/n]: " input
    [[ ! "$input" =~ ^[nN]$ ]] && SELECTED_COMPONENTS+=("monitoring")
    
    read -p "Management UI installieren? [J/n]: " input
    [[ ! "$input" =~ ^[nN]$ ]] && SELECTED_COMPONENTS+=("management")
    
    read -p "UDF Framework (Lua/Python/R) installieren? [j/N]: " input
    [[ "$input" =~ ^[jJ]$ ]] && SELECTED_COMPONENTS+=("udf")
    
    read -p "Virtual Schemas (FDW) installieren? [j/N]: " input
    [[ "$input" =~ ^[jJ]$ ]] && SELECTED_COMPONENTS+=("fdw")
    
    read -p "ETL-Tools (Airflow) installieren? [j/N]: " input
    [[ "$input" =~ ^[jJ]$ ]] && SELECTED_COMPONENTS+=("etl")
    
    read -p "Backup-Tools (pgBackRest) installieren? [J/n]: " input
    [[ ! "$input" =~ ^[nN]$ ]] && SELECTED_COMPONENTS+=("backup")
}

# Generate Configuration
generate_config() {
    print_section "Konfiguration erstellen"
    
    cat > "$CONFIG_FILE" << EOF
# ExaPG Configuration - Generated by Installation Wizard
# $(date)

# Cluster Configuration
CLUSTER_NAME=$CLUSTER_NAME
CONTAINER_NAME=$CONTAINER_NAME
DEPLOYMENT_MODE=single

# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=exapg
COORDINATOR_PORT=$COORDINATOR_PORT

# Performance Configuration
SHARED_BUFFERS=$SHARED_BUFFERS
WORK_MEM=$WORK_MEM
MAINTENANCE_WORK_MEM=1GB
EFFECTIVE_CACHE_SIZE=6GB
MAX_PARALLEL_WORKERS=$MAX_PARALLEL_WORKERS
MAX_PARALLEL_WORKERS_PER_GATHER=4
JIT=$JIT_ENABLED

# Worker Configuration
WORKER_COUNT=$WORKER_COUNT
WORKER_PORT_START=5433
WORKER_MEMORY_LIMIT=4G

# Network Configuration
COORDINATOR_MEMORY_LIMIT=6G
SHARED_MEMORY_SIZE=4G
EFFECTIVE_IO_CONCURRENCY=200

# SSL Configuration
SSL_ENABLED=$SSL_ENABLED

# Backup Configuration
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION

# Monitoring Configuration
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
MANAGEMENT_UI_PORT=3001

# Component Flags
$(for component in "${SELECTED_COMPONENTS[@]}"; do
    echo "INSTALL_$(echo $component | tr '[:lower:]' '[:upper:]')=true"
done)
EOF

    print_success "Konfiguration erstellt: $CONFIG_FILE"
}

# Installation Progress with Dialog
install_with_progress() {
    local total_steps=7
    local current_step=0
    
    if [ "$UI_AVAILABLE" = true ]; then
        (
        # Step 1: Cleanup
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Bereinige vorherige Installation..."
        echo "XXX"
        cleanup_previous_installation
        sleep 1
        
        # Step 2: Network
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Erstelle Docker-Netzwerk..."
        echo "XXX"
        create_docker_network
        sleep 1
        
        # Step 3: Images
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Lade Docker-Images..."
        echo "XXX"
        pull_docker_images
        sleep 2
        
        # Step 4: Core Components
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Installiere Kern-Komponenten..."
        echo "XXX"
        install_core_components
        sleep 3
        
        # Step 5: Additional Components
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Installiere zusätzliche Komponenten..."
        echo "XXX"
        install_additional_components
        sleep 2
        
        # Step 6: Initialize Database
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Initialisiere Datenbank..."
        echo "XXX"
        initialize_database
        sleep 2
        
        # Step 7: Final Setup
        current_step=$((current_step + 1))
        echo "XXX"
        echo "$((current_step * 100 / total_steps))"
        echo "Führe finale Konfiguration durch..."
        echo "XXX"
        finalize_installation
        sleep 1
        
        ) | dialog --gauge "ExaPG Installation läuft..." 8 60 0
    else
        install_manual_progress
    fi
}

install_manual_progress() {
    print_section "Installation läuft"
    
    echo "1/7: Bereinige vorherige Installation..."
    cleanup_previous_installation
    
    echo "2/7: Erstelle Docker-Netzwerk..."
    create_docker_network
    
    echo "3/7: Lade Docker-Images..."
    pull_docker_images
    
    echo "4/7: Installiere Kern-Komponenten..."
    install_core_components
    
    echo "5/7: Installiere zusätzliche Komponenten..."
    install_additional_components
    
    echo "6/7: Initialisiere Datenbank..."
    initialize_database
    
    echo "7/7: Führe finale Konfiguration durch..."
    finalize_installation
}

# Installation Steps
cleanup_previous_installation() {
    docker-compose down -v 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    log "Vorherige Installation bereinigt"
}

create_docker_network() {
    docker network create exapg-network 2>/dev/null || true
    log "Docker-Netzwerk erstellt"
}

pull_docker_images() {
    docker pull citusdata/citus:12.1 >> "$LOG_FILE" 2>&1 || true
    docker pull postgres:15 >> "$LOG_FILE" 2>&1 || true
    docker pull grafana/grafana:latest >> "$LOG_FILE" 2>&1 || true
    docker pull prom/prometheus:latest >> "$LOG_FILE" 2>&1 || true
    log "Docker-Images geladen"
}

install_core_components() {
    # Build ExaPG Image
    docker build -t exapg:latest -f docker/Dockerfile . >> "$LOG_FILE" 2>&1
    
    # Start Core Components
    docker-compose -f docker/docker-compose/docker-compose.yml up -d coordinator >> "$LOG_FILE" 2>&1
    
    log "Kern-Komponenten installiert"
}

install_additional_components() {
    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            "monitoring")
                docker-compose -f docker/docker-compose/docker-compose.monitoring.yml up -d >> "$LOG_FILE" 2>&1
                ;;
            "management")
                docker-compose -f docker/docker-compose/docker-compose.management-ui.yml up -d >> "$LOG_FILE" 2>&1
                ;;
            "citus")
                docker-compose -f docker/docker-compose/docker-compose.citus.yml up -d >> "$LOG_FILE" 2>&1
                ;;
            "ha")
                docker-compose -f docker/docker-compose/docker-compose.ha.yml up -d >> "$LOG_FILE" 2>&1
                ;;
            "backup")
                docker-compose -f docker/docker-compose/docker-compose.backup.yml up -d >> "$LOG_FILE" 2>&1
                ;;
        esac
    done
    log "Zusätzliche Komponenten installiert"
}

initialize_database() {
    # Wait for database to be ready
    sleep 10
    
    # Initialize database with ExaPG functions
    docker exec exapg-coordinator psql -U postgres -d postgres << 'EOF' >> "$LOG_FILE" 2>&1 || true
-- Create Schemas
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS streaming;
CREATE SCHEMA IF NOT EXISTS exa_system;

-- Load Extensions
CREATE EXTENSION IF NOT EXISTS citus;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Basic Setup Complete
SELECT 'ExaPG initialized successfully' as status;
EOF

    log "Datenbank initialisiert"
}

finalize_installation() {
    # Make CLI executable
    chmod +x exapg-cli.sh
    chmod +x scripts/cli/exapg-cli-functions.sh
    chmod +x scripts/optimization/performance_tuning_wizard.sh
    
    # Create symlink
    ln -sf exapg-cli.sh exapg 2>/dev/null || true
    
    log "Installation finalisiert"
}

# Installation Summary
show_installation_summary() {
    print_header
    print_section "Installation abgeschlossen!"
    echo ""
    
    print_success "ExaPG wurde erfolgreich installiert!"
    echo ""
    
    echo -e "${BOLD}Installierte Komponenten:${NC}"
    for component in "${SELECTED_COMPONENTS[@]}"; do
        case $component in
            "standard") echo "  ✓ ExaPG Standard (Port: $COORDINATOR_PORT)" ;;
            "monitoring") echo "  ✓ Monitoring (Grafana: http://localhost:3000)" ;;
            "management") echo "  ✓ Management UI (http://localhost:3001)" ;;
            "citus") echo "  ✓ Citus Cluster" ;;
            "ha") echo "  ✓ Hochverfügbarkeit" ;;
            "backup") echo "  ✓ Backup-Tools" ;;
        esac
    done
    
    echo ""
    echo -e "${BOLD}Nächste Schritte:${NC}"
    echo "1. Starten Sie die ExaPG CLI:"
    echo -e "   ${CYAN}./exapg${NC}"
    echo ""
    echo "2. Verbinden Sie sich zur Datenbank:"
    echo -e "   ${CYAN}psql -h localhost -p $COORDINATOR_PORT -U postgres -d exapg${NC}"
    echo ""
    echo "3. Führen Sie Performance-Optimierung durch:"
    echo -e "   ${CYAN}./scripts/optimization/performance_tuning_wizard.sh${NC}"
    echo ""
    
    if [[ " ${SELECTED_COMPONENTS[@]} " =~ " monitoring " ]]; then
        echo "4. Überwachen Sie die Performance:"
        echo -e "   ${CYAN}http://localhost:3000${NC} (admin/admin)"
        echo ""
    fi
    
    echo -e "${YELLOW}Logs:${NC} $LOG_FILE"
    echo -e "${YELLOW}Konfiguration:${NC} $CONFIG_FILE"
    echo ""
}

# Main Installation Flow
main() {
    # Initialize
    print_header
    check_ui_capabilities
    
    # Default values
    CLUSTER_NAME="exapg-cluster"
    CONTAINER_NAME="exapg"
    POSTGRES_PASSWORD="postgres"
    COORDINATOR_PORT="5432"
    WORKER_COUNT="2"
    BACKUP_RETENTION="7"
    
    # System check
    check_system_requirements
    
    # Configuration
    print_header
    echo -e "${YELLOW}Möchten Sie eine erweiterte Konfiguration durchführen? [j/N]:${NC}"
    read -r advanced_config
    
    if [[ "$advanced_config" =~ ^[jJ]$ ]]; then
        advanced_config_dialog
    fi
    
    # Component selection
    print_header
    select_components
    
    # Generate config
    generate_config
    
    # Confirmation
    print_header
    print_section "Installations-Zusammenfassung"
    echo ""
    echo -e "${BOLD}Cluster:${NC} $CLUSTER_NAME"
    echo -e "${BOLD}Komponenten:${NC} ${SELECTED_COMPONENTS[*]}"
    echo -e "${BOLD}Port:${NC} $COORDINATOR_PORT"
    echo -e "${BOLD}Worker:${NC} $WORKER_COUNT"
    echo ""
    
    read -p "Installation starten? [J/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        echo "Installation abgebrochen."
        exit 0
    fi
    
    # Install
    print_header
    install_with_progress
    
    # Summary
    show_installation_summary
    
    # Auto-start CLI
    read -p "Möchten Sie die ExaPG CLI jetzt starten? [J/n]: " start_cli
    if [[ ! "$start_cli" =~ ^[nN]$ ]]; then
        ./exapg
    fi
}

# Error handling
trap 'print_error "Installation fehlgeschlagen! Siehe Log: $LOG_FILE"' ERR

# Start installation
main "$@" 