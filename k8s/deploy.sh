#!/bin/bash
# ===================================================================
# ExaPG Kubernetes Deployment Script
# ===================================================================
# CLOUD INTEGRATION FIX: Complete Kubernetes deployment automation
# Date: 2024-05-24
# 
# Usage: 
#   ./deploy.sh [ENVIRONMENT] [OPTIONS]
#   
# Environments:
#   dev       - Development environment (minimal resources)
#   staging   - Staging environment (medium resources)
#   prod      - Production environment (full resources)
#
# Options:
#   --monitoring    - Deploy monitoring stack
#   --management    - Deploy management UI
#   --backup        - Deploy backup infrastructure
#   --all           - Deploy everything (default)
#   --dry-run       - Show what would be deployed
#   --cleanup       - Remove existing deployment first
# ===================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="exapg"
ENVIRONMENT="${1:-dev}"
DEPLOY_MONITORING=false
DEPLOY_MANAGEMENT=false
DEPLOY_BACKUP=false
DEPLOY_ALL=true
DRY_RUN=false
CLEANUP=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --monitoring)
                DEPLOY_MONITORING=true
                DEPLOY_ALL=false
                shift
                ;;
            --management)
                DEPLOY_MANAGEMENT=true
                DEPLOY_ALL=false
                shift
                ;;
            --backup)
                DEPLOY_BACKUP=true
                DEPLOY_ALL=false
                shift
                ;;
            --all)
                DEPLOY_ALL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ $1 =~ ^(dev|staging|prod)$ ]]; then
                    ENVIRONMENT=$1
                else
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
ExaPG Kubernetes Deployment Script

Usage: $0 [ENVIRONMENT] [OPTIONS]

Environments:
  dev       Development environment (minimal resources)
  staging   Staging environment (medium resources)  
  prod      Production environment (full resources)

Options:
  --monitoring    Deploy monitoring stack only
  --management    Deploy management UI only
  --backup        Deploy backup infrastructure only
  --all           Deploy everything (default)
  --dry-run       Show what would be deployed
  --cleanup       Remove existing deployment first
  --help, -h      Show this help message

Examples:
  $0 dev --all                    # Deploy everything in dev environment
  $0 prod --monitoring            # Deploy only monitoring in production
  $0 staging --dry-run            # Show what would be deployed in staging
  $0 prod --cleanup --all         # Clean and redeploy everything in production
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if required files exist
    local required_files=(
        "namespace.yaml"
        "configmap.yaml"
        "secrets.yaml"
        "postgres-statefulset.yaml"
        "citus-deployment.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Apply environment-specific configurations
apply_environment_config() {
    log_info "Applying environment-specific configuration for: $ENVIRONMENT"
    
    case $ENVIRONMENT in
        dev)
            # Development environment - minimal resources
            kubectl patch configmap exapg-config -n $NAMESPACE --type merge -p '{
                "data": {
                    "shared_buffers": "1GB",
                    "work_mem": "256MB",
                    "maintenance_work_mem": "512MB",
                    "max_parallel_workers": "4"
                }
            }' 2>/dev/null || true
            ;;
        staging)
            # Staging environment - medium resources
            kubectl patch configmap exapg-config -n $NAMESPACE --type merge -p '{
                "data": {
                    "shared_buffers": "2GB",
                    "work_mem": "512MB",
                    "maintenance_work_mem": "1GB",
                    "max_parallel_workers": "8"
                }
            }' 2>/dev/null || true
            ;;
        prod)
            # Production environment - full resources
            kubectl patch configmap exapg-config -n $NAMESPACE --type merge -p '{
                "data": {
                    "shared_buffers": "4GB",
                    "work_mem": "1GB",
                    "maintenance_work_mem": "2GB",
                    "max_parallel_workers": "16"
                }
            }' 2>/dev/null || true
            ;;
    esac
}

# Deploy function with dry-run support
deploy_manifest() {
    local manifest_file=$1
    local description=$2
    
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would deploy: $description"
        kubectl apply -f "$SCRIPT_DIR/$manifest_file" --dry-run=client
    else
        log_info "Deploying: $description"
        kubectl apply -f "$SCRIPT_DIR/$manifest_file"
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment_name=$1
    local timeout=${2:-300}
    
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would wait for deployment: $deployment_name"
        return 0
    fi
    
    log_info "Waiting for deployment $deployment_name to be ready..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment_name -n $NAMESPACE; then
        log_success "Deployment $deployment_name is ready"
    else
        log_error "Deployment $deployment_name failed to become ready within ${timeout}s"
        return 1
    fi
}

# Wait for StatefulSet to be ready
wait_for_statefulset() {
    local statefulset_name=$1
    local timeout=${2:-600}
    
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would wait for StatefulSet: $statefulset_name"
        return 0
    fi
    
    log_info "Waiting for StatefulSet $statefulset_name to be ready..."
    if kubectl wait --for=condition=ready --timeout=${timeout}s pod -l app.kubernetes.io/name=exapg,app.kubernetes.io/component=${statefulset_name#exapg-} -n $NAMESPACE; then
        log_success "StatefulSet $statefulset_name is ready"
    else
        log_error "StatefulSet $statefulset_name failed to become ready within ${timeout}s"
        return 1
    fi
}

# Cleanup existing deployment
cleanup_deployment() {
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would cleanup existing deployment"
        return 0
    fi
    
    log_warning "Cleaning up existing ExaPG deployment..."
    
    # Delete in reverse order to avoid dependency issues
    kubectl delete ingress --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete service --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete deployment --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete statefulset --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete job --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete pvc --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete configmap --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete secret --all -n $NAMESPACE 2>/dev/null || true
    kubectl delete namespace $NAMESPACE 2>/dev/null || true
    
    # Wait for namespace to be fully deleted
    while kubectl get namespace $NAMESPACE &> /dev/null; do
        log_info "Waiting for namespace deletion..."
        sleep 5
    done
    
    log_success "Cleanup completed"
}

# Deploy core infrastructure
deploy_core() {
    log_info "Deploying ExaPG core infrastructure..."
    
    # Create namespace and basic configuration
    deploy_manifest "namespace.yaml" "Namespace"
    deploy_manifest "configmap.yaml" "Configuration Maps"
    deploy_manifest "secrets.yaml" "Secrets"
    
    # Deploy PostgreSQL cluster
    deploy_manifest "postgres-statefulset.yaml" "PostgreSQL Cluster (Coordinator + Workers)"
    
    # Wait for PostgreSQL to be ready
    wait_for_statefulset "exapg-coordinator" 600
    wait_for_statefulset "exapg-worker1" 600
    wait_for_statefulset "exapg-worker2" 600
    
    # Deploy Citus setup
    deploy_manifest "citus-deployment.yaml" "Citus Cluster Setup"
    
    # Wait for Citus setup job to complete
    if [[ $DRY_RUN == false ]]; then
        log_info "Waiting for Citus setup to complete..."
        kubectl wait --for=condition=complete --timeout=300s job/exapg-citus-setup -n $NAMESPACE || true
    fi
    
    log_success "Core infrastructure deployed successfully"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    deploy_manifest "monitoring-deployment.yaml" "Monitoring Stack (Prometheus, Grafana, Alertmanager)"
    
    # Wait for monitoring components
    wait_for_deployment "exapg-prometheus" 300
    wait_for_deployment "exapg-grafana" 300
    wait_for_deployment "exapg-postgres-exporter" 300
    
    log_success "Monitoring stack deployed successfully"
}

# Deploy management UI
deploy_management() {
    log_info "Deploying management UI..."
    
    deploy_manifest "management-deployment.yaml" "Management UI (pgAdmin, Adminer, File Browser)"
    
    # Wait for management components
    wait_for_deployment "exapg-pgadmin" 300
    wait_for_deployment "exapg-adminer" 300
    wait_for_deployment "exapg-management-ui" 300
    
    log_success "Management UI deployed successfully"
}

# Deploy backup infrastructure
deploy_backup() {
    log_info "Deploying backup infrastructure..."
    
    # Check if backup manifests exist
    if [[ -f "$SCRIPT_DIR/backup-deployment.yaml" ]]; then
        deploy_manifest "backup-deployment.yaml" "Backup Infrastructure"
    else
        log_warning "Backup deployment manifest not found, skipping backup deployment"
    fi
    
    log_success "Backup infrastructure deployment completed"
}

# Deploy ingress and networking
deploy_networking() {
    log_info "Deploying networking and ingress..."
    
    deploy_manifest "ingress.yaml" "Ingress and Networking"
    
    log_success "Networking deployed successfully"
}

# Show deployment status
show_status() {
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Deployment status check skipped"
        return 0
    fi
    
    log_info "ExaPG Deployment Status:"
    echo
    
    # Show pods
    echo "=== Pods ==="
    kubectl get pods -n $NAMESPACE -o wide
    echo
    
    # Show services
    echo "=== Services ==="
    kubectl get services -n $NAMESPACE
    echo
    
    # Show ingress
    echo "=== Ingress ==="
    kubectl get ingress -n $NAMESPACE
    echo
    
    # Show PVCs
    echo "=== Persistent Volume Claims ==="
    kubectl get pvc -n $NAMESPACE
    echo
}

# Show access information
show_access_info() {
    if [[ $DRY_RUN == true ]]; then
        return 0
    fi
    
    log_success "ExaPG deployment completed successfully!"
    echo
    log_info "Access Information:"
    echo "=================="
    echo
    echo "🌐 Web Interfaces:"
    echo "  Main Dashboard:    http://exapg.local"
    echo "  Grafana:          http://grafana.exapg.local"
    echo "  pgAdmin:          http://pgadmin.exapg.local"
    echo "  Prometheus:       http://prometheus.exapg.local"
    echo "  Alertmanager:     http://alertmanager.exapg.local"
    echo
    echo "🗄️  Database Access:"
    echo "  Coordinator:      db.exapg.local:5432"
    echo "  Username:         postgres"
    echo "  Password:         exapg_secure_password_123"
    echo "  Database:         exadb"
    echo
    echo "📊 Default Credentials:"
    echo "  Grafana:          admin / exapg_grafana_admin_123"
    echo "  pgAdmin:          admin@exapg.local / admin123"
    echo
    echo "⚠️  Note: Update default passwords in production!"
    echo
    echo "📖 For more information, see: https://github.com/exapg/exapg"
}

# Main deployment function
main() {
    parse_args "$@"
    
    log_info "Starting ExaPG Kubernetes deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry Run: $DRY_RUN"
    
    check_prerequisites
    
    if [[ $CLEANUP == true ]]; then
        cleanup_deployment
    fi
    
    # Always deploy core infrastructure
    deploy_core
    apply_environment_config
    
    # Deploy optional components based on flags
    if [[ $DEPLOY_ALL == true ]]; then
        deploy_monitoring
        deploy_management
        deploy_backup
        deploy_networking
    else
        if [[ $DEPLOY_MONITORING == true ]]; then
            deploy_monitoring
        fi
        
        if [[ $DEPLOY_MANAGEMENT == true ]]; then
            deploy_management
        fi
        
        if [[ $DEPLOY_BACKUP == true ]]; then
            deploy_backup
        fi
        
        # Always deploy networking if any component is deployed
        deploy_networking
    fi
    
    show_status
    show_access_info
}

# Run main function with all arguments
main "$@" 