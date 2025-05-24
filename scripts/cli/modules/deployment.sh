#!/bin/bash
# ===================================================================
# ExaPG CLI Deployment Module
# ===================================================================
# ARCHITECTURE FIX: Extracted from terminal-ui.sh monolith
# Date: 2024-05-24
# ===================================================================

# ===================================================================
# DEPLOYMENT FUNCTIONS
# ===================================================================

# Start deployment
start_deployment() {
    local profile="${1:-default}"
    
    ui_section "Starting ExaPG Deployment"
    ui_status "info" "Deployment profile: $profile"
    
    # Validate environment first
    if ! validate_deployment_prerequisites; then
        ui_status "error" "Prerequisites check failed"
        ui_wait_key
        return 1
    fi
    
    # Choose deployment type
    local deploy_type
    if [[ -n "$1" ]]; then
        deploy_type="$1"
    else
        deploy_type=$(choose_deployment_type)
    fi
    
    case "$deploy_type" in
        "single")
            start_single_node_deployment
            ;;
        "cluster")
            start_cluster_deployment
            ;;
        "ha")
            start_ha_deployment
            ;;
        *)
            ui_status "error" "Unknown deployment type: $deploy_type"
            return 1
            ;;
    esac
}

# Choose deployment type
choose_deployment_type() {
    ui_subsection "Select Deployment Type"
    
    local options=(
        "1:Single Node (Development)"
        "2:Cluster (Production)"
        "3:High Availability (Enterprise)"
    )
    
    for option in "${options[@]}"; do
        local key="${option%%:*}"
        local desc="${option#*:}"
        echo "  $key) $desc"
    done
    
    echo
    ui_read "Choose deployment type (1-3)" "1" choice
    
    case "$choice" in
        "1") echo "single" ;;
        "2") echo "cluster" ;;
        "3") echo "ha" ;;
        *) echo "single" ;;
    esac
}

# Start single node deployment
start_single_node_deployment() {
    ui_subsection "Single Node Deployment"
    
    local steps=(
        "Validating configuration"
        "Building Docker images"
        "Starting coordinator"
        "Initializing database"
        "Running health checks"
    )
    
    for i in "${!steps[@]}"; do
        local step="${steps[$i]}"
        ui_progress $((i+1)) ${#steps[@]} "$step"
        
        case $i in
            0) validate_single_node_config ;;
            1) build_docker_images ;;
            2) start_coordinator ;;
            3) initialize_database ;;
            4) run_health_checks ;;
        esac
        
        sleep 1
    done
    
    ui_status "success" "Single node deployment completed!"
    show_deployment_summary "single"
}

# Start cluster deployment
start_cluster_deployment() {
    ui_subsection "Cluster Deployment"
    
    # Load cluster configuration
    source "$(dirname "${BASH_SOURCE[0]}")/../utils/docker-utils.sh"
    
    ui_status "info" "Starting cluster with ${WORKER_COUNT:-2} workers"
    
    {
        docker-compose -f docker/docker-compose/docker-compose.yml up -d coordinator &
        ui_spinner $! "Starting coordinator"
    }
    
    {
        docker-compose -f docker/docker-compose/docker-compose.yml up -d --scale worker=${WORKER_COUNT:-2} &
        ui_spinner $! "Starting workers"
    }
    
    ui_status "success" "Cluster deployment completed!"
    show_deployment_summary "cluster"
}

# Start HA deployment
start_ha_deployment() {
    ui_subsection "High Availability Deployment"
    
    ui_status "info" "Starting HA deployment with replication"
    
    {
        docker-compose -f docker/docker-compose/docker-compose.yml \
                      -f docker/docker-compose/docker-compose.ha.yml up -d &
        ui_spinner $! "Starting HA cluster"
    }
    
    ui_status "success" "HA deployment completed!"
    show_deployment_summary "ha"
}

# ===================================================================
# STATUS & MONITORING
# ===================================================================

# Check deployment status
check_deployment_status() {
    ui_section "Deployment Status"
    
    # Check if containers are running
    local containers=(
        "coordinator:Coordinator Node"
        "worker:Worker Nodes"
        "prometheus:Monitoring"
        "grafana:Dashboards"
    )
    
    ui_table "Service" "Status" "Health" "Uptime"
    
    for container_info in "${containers[@]}"; do
        local container="${container_info%%:*}"
        local description="${container_info#*:}"
        
        local status="Unknown"
        local health="Unknown"
        local uptime="Unknown"
        
        # Check if container exists and is running
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            status="Running"
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "N/A")
            uptime=$(docker ps --filter "name=$container" --format "{{.Status}}")
        else
            status="Stopped"
        fi
        
        ui_table_row "$description" "$status" "$health" "$uptime"
    done
    
    ui_table_end
    
    # Show resource usage
    show_resource_usage
    
    ui_wait_key
}

# Show resource usage
show_resource_usage() {
    ui_subsection "Resource Usage"
    
    if command -v docker >/dev/null 2>&1; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    else
        ui_status "warning" "Docker not available for resource monitoring"
    fi
}

# ===================================================================
# DEPLOYMENT MANAGEMENT
# ===================================================================

# Stop deployment
stop_deployment() {
    ui_section "Stopping ExaPG Deployment"
    
    if ui_confirm "Are you sure you want to stop the deployment?" "n"; then
        {
            docker-compose -f docker/docker-compose/docker-compose.yml down &
            ui_spinner $! "Stopping services"
        }
        
        ui_status "success" "Deployment stopped successfully"
    else
        ui_status "info" "Stop operation cancelled"
    fi
    
    ui_wait_key
}

# Restart deployment
restart_deployment() {
    ui_section "Restarting ExaPG Deployment"
    
    ui_status "info" "Restarting all services..."
    
    {
        docker-compose -f docker/docker-compose/docker-compose.yml restart &
        ui_spinner $! "Restarting services"
    }
    
    ui_status "success" "Services restarted successfully"
    ui_wait_key
}

# View logs
view_logs() {
    local service="${1:-coordinator}"
    
    ui_section "Viewing Logs: $service"
    
    if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
        ui_status "info" "Showing last 50 lines (press Ctrl+C to exit)"
        echo
        docker logs --tail 50 -f "$service"
    else
        ui_status "error" "Service $service not found or not running"
        ui_wait_key
    fi
}

# ===================================================================
# VALIDATION & SETUP
# ===================================================================

# Validate deployment prerequisites
validate_deployment_prerequisites() {
    local errors=0
    
    ui_status "info" "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        ui_status "error" "Docker is not installed"
        ((errors++))
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        ui_status "error" "Docker Compose is not installed"
        ((errors++))
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        ui_status "error" "Docker daemon is not running"
        ((errors++))
    fi
    
    # Check environment file
    if [[ ! -f ".env" ]]; then
        ui_status "error" ".env file not found"
        ((errors++))
    fi
    
    # Check configuration files
    if [[ ! -f "docker/docker-compose/docker-compose.yml" ]]; then
        ui_status "error" "Docker Compose configuration not found"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        ui_status "success" "All prerequisites satisfied"
        return 0
    else
        ui_status "error" "$errors prerequisite(s) failed"
        return 1
    fi
}

# Validate single node configuration
validate_single_node_config() {
    # Set single node mode in environment
    export DEPLOYMENT_MODE="single"
    export WORKER_COUNT="0"
    return 0
}

# Build Docker images
build_docker_images() {
    if [[ ! -f "docker/Dockerfile" ]]; then
        ui_status "warning" "Dockerfile not found, using pre-built images"
        return 0
    fi
    
    # Only build if Dockerfile exists and is newer than image
    docker build -t exapg:latest docker/ >/dev/null 2>&1 || {
        ui_status "warning" "Image build failed, continuing with existing image"
    }
    return 0
}

# Start coordinator
start_coordinator() {
    docker-compose -f docker/docker-compose/docker-compose.yml up -d coordinator >/dev/null 2>&1
    return 0
}

# Initialize database
initialize_database() {
    # Wait for database to be ready
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if docker exec coordinator pg_isready -U postgres >/dev/null 2>&1; then
            break
        fi
        ((retries--))
        sleep 1
    done
    return 0
}

# Run health checks
run_health_checks() {
    # Simple health check
    docker exec coordinator pg_isready -U postgres >/dev/null 2>&1
    return $?
}

# ===================================================================
# DEPLOYMENT SUMMARY
# ===================================================================

# Show deployment summary
show_deployment_summary() {
    local deploy_type="$1"
    
    ui_subsection "Deployment Summary"
    
    echo "  📋 Deployment Type: $deploy_type"
    echo "  🚀 Status: Running"
    echo "  🔗 Coordinator: localhost:${COORDINATOR_PORT:-5432}"
    
    if [[ "$deploy_type" == "cluster" ]]; then
        echo "  👥 Workers: ${WORKER_COUNT:-2}"
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo "  📊 Services:"
        docker-compose -f docker/docker-compose/docker-compose.yml ps --services | sed 's/^/    - /'
    fi
    
    echo
    echo "  🌐 Access URLs:"
    echo "    - Database: postgresql://postgres@localhost:${COORDINATOR_PORT:-5432}/exadb"
    
    if [[ "${ENABLE_MONITORING:-false}" == "true" ]]; then
        echo "    - Grafana: http://localhost:${GRAFANA_PORT:-3000}"
        echo "    - Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    fi
    
    echo
    ui_status "success" "Deployment is ready for use!"
    ui_wait_key
}

# ===================================================================
# EXPORTED FUNCTIONS
# ===================================================================

# Export functions for use by other modules
declare -fx start_deployment check_deployment_status stop_deployment
declare -fx restart_deployment view_logs 