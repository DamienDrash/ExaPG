#!/bin/bash
# ===================================================================
# ExaPG Simple CLI - Fallback when main CLI has issues
# ===================================================================
# Simple alternative to exapg-cli.sh for basic functionality
# Date: 2024-12-19
# ===================================================================

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLI_VERSION="3.0.0-simple"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Print functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Show version
show_version() {
    echo "ExaPG Simple CLI v$CLI_VERSION"
    echo "PostgreSQL Analytical Database Management Tool"
    echo "Simplified interface without complex modules"
    echo "Project Root: $PROJECT_ROOT"
}

# Show help
show_help() {
    cat << EOF
ExaPG Simple CLI v$CLI_VERSION - PostgreSQL Analytical Database

USAGE:
    $0 [command]

COMMANDS:
    deploy          Deploy ExaPG (Docker Compose)
    k8s             Deploy to Kubernetes
    status          Check deployment status
    validate        Validate environment
    benchmark       Run benchmarks
    config          Show configuration
    test            Run basic tests
    help            Show this help
    version         Show version

EXAMPLES:
    $0                  # Interactive mode
    $0 deploy           # Start deployment
    $0 k8s              # Kubernetes deployment
    $0 status           # Check status
    $0 benchmark        # Run benchmarks

ALTERNATIVE TOOLS:
    ./test-exapg.sh             # Basic testing
    ./benchmark/benchmark-cli.sh # Detailed benchmarks
    cd k8s && ./deploy.sh       # Direct K8s deployment

EOF
}

# Interactive menu
interactive_menu() {
    while true; do
        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    ExaPG Simple CLI v$CLI_VERSION                    ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  1) Deploy Analytics Cluster (Docker)                       ║"
        echo "║  2) Deploy to Kubernetes                                     ║"
        echo "║  3) Check Status                                             ║"
        echo "║  4) Run Benchmarks                                           ║"
        echo "║  5) Validate Environment                                     ║"
        echo "║  6) Show Configuration                                       ║"
        echo "║  7) Run Tests                                                ║"
        echo "║  8) Help                                                     ║"
        echo "║  9) Exit                                                     ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo
        echo -n "Choose option [1-9]: "
        read -r choice
        
        case "$choice" in
            1) deploy_docker ;;
            2) deploy_kubernetes ;;
            3) check_status ;;
            4) run_benchmarks ;;
            5) validate_environment ;;
            6) show_configuration ;;
            7) run_tests ;;
            8) show_help ;;
            9) 
                echo "Goodbye!"
                exit 0
                ;;
            "")
                continue
                ;;
            *)
                log_error "Invalid choice: $choice"
                ;;
        esac
        
        echo
        echo -n "Press Enter to continue..."
        read -r
    done
}

# Deploy Docker
deploy_docker() {
    log_info "Starting Docker Analytics Cluster deployment..."
    
    if [[ ! -f "docker/docker-compose/docker-compose.citus.yml" ]]; then
        log_error "Citus compose file not found"
        return 1
    fi
    
    echo "Available deployment options:"
    echo "  1) Analytics Cluster (Citus)"
    echo "  2) Production Setup"
    echo "  3) With Monitoring"
    echo -n "Choose [1-3]: "
    read -r deploy_choice
    
    case "$deploy_choice" in
        1)
            log_info "Deploying Citus Analytics Cluster..."
            cd docker/docker-compose
            docker-compose -f docker-compose.citus.yml up -d
            ;;
        2)
            log_info "Deploying Production Setup..."
            cd docker/docker-compose
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
            ;;
        3)
            log_info "Deploying with Monitoring..."
            cd docker/docker-compose
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.monitoring.yml up -d
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_success "Deployment started successfully!"
        log_info "Use './simple-exapg.sh status' to check progress"
    else
        log_error "Deployment failed"
    fi
}

# Deploy Kubernetes
deploy_kubernetes() {
    log_info "Starting Kubernetes deployment..."
    
    if [[ ! -d "k8s" ]]; then
        log_error "No k8s directory found"
        return 1
    fi
    
    if [[ ! -f "k8s/deploy.sh" ]]; then
        log_error "No k8s/deploy.sh script found"
        return 1
    fi
    
    echo "Kubernetes deployment options:"
    echo "  1) Development (dev)"
    echo "  2) Staging (staging)" 
    echo "  3) Production (prod)"
    echo -n "Choose environment [1-3]: "
    read -r env_choice
    
    case "$env_choice" in
        1) ENV="dev" ;;
        2) ENV="staging" ;;
        3) ENV="prod" ;;
        *) 
            log_error "Invalid choice"
            return 1
            ;;
    esac
    
    cd k8s
    ./deploy.sh "$ENV" --all
    
    if [[ $? -eq 0 ]]; then
        log_success "Kubernetes deployment started!"
        log_info "Use 'kubectl get pods -n exapg' to check status"
    else
        log_error "Kubernetes deployment failed"
    fi
}

# Check status
check_status() {
    log_info "Checking ExaPG deployment status..."
    
    # Check Docker
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q exapg; then
        log_success "Docker containers running:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep exapg
    else
        log_warning "No ExaPG Docker containers running"
    fi
    
    # Check Kubernetes
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl get namespace exapg >/dev/null 2>&1; then
            log_success "Kubernetes deployment found:"
            kubectl get pods -n exapg
        else
            log_warning "No Kubernetes deployment found"
        fi
    else
        log_warning "kubectl not available"
    fi
}

# Run benchmarks
run_benchmarks() {
    log_info "Starting benchmark suite..."
    
    if [[ -f "benchmark/benchmark-cli.sh" ]]; then
        ./benchmark/benchmark-cli.sh
    else
        log_warning "Benchmark CLI not found, running basic performance test..."
        if [[ -f "scripts/performance/test-performance.sh" ]]; then
            ./scripts/performance/test-performance.sh
        else
            log_error "No benchmark tools available"
        fi
    fi
}

# Validate environment
validate_environment() {
    log_info "Validating ExaPG environment..."
    
    if [[ -f "test-exapg.sh" ]]; then
        ./test-exapg.sh validate
    else
        log_error "test-exapg.sh not found"
        return 1
    fi
}

# Show configuration
show_configuration() {
    log_info "ExaPG Configuration:"
    
    if [[ -f ".env" ]]; then
        log_success "Environment file found:"
        echo "Key variables from .env:"
        grep -E "^(DEPLOYMENT_MODE|WORKER_COUNT|SHARED_BUFFERS|POSTGRES_)" .env | head -10
    else
        log_warning ".env file not found"
    fi
    
    echo
    log_info "Available profiles:"
    if [[ -d "config/profiles" ]]; then
        ls -1 config/profiles/ | sed 's/^/  - /'
    else
        log_warning "No profiles directory found"
    fi
    
    echo
    log_info "Available compose files:"
    if [[ -d "docker/docker-compose" ]]; then
        ls -1 docker/docker-compose/*.yml | sed 's/^/  - /'
    else
        log_warning "No compose files found"
    fi
}

# Run tests
run_tests() {
    log_info "Running ExaPG tests..."
    
    if [[ -f "test-exapg.sh" ]]; then
        echo "Available test options:"
        echo "  1) Basic status check"
        echo "  2) Docker functionality"
        echo "  3) Kubernetes readiness"
        echo "  4) All tests"
        echo -n "Choose [1-4]: "
        read -r test_choice
        
        case "$test_choice" in
            1) ./test-exapg.sh status ;;
            2) ./test-exapg.sh docker ;;
            3) ./test-exapg.sh k8s ;;
            4) ./test-exapg.sh validate && ./test-exapg.sh docker && ./test-exapg.sh k8s ;;
            *) log_error "Invalid choice" ;;
        esac
    else
        log_error "test-exapg.sh not found"
    fi
}

# Main function
main() {
    cd "$PROJECT_ROOT" || exit 1
    
    case "${1:-interactive}" in
        "deploy")
            deploy_docker
            ;;
        "k8s"|"kubernetes")
            deploy_kubernetes
            ;;
        "status")
            check_status
            ;;
        "benchmark")
            run_benchmarks
            ;;
        "validate")
            validate_environment
            ;;
        "config")
            show_configuration
            ;;
        "test")
            run_tests
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "version"|"--version")
            show_version
            ;;
        "interactive"|"")
            interactive_menu
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 