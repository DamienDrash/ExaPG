#!/bin/bash
# ===================================================================
# ExaPG Test Script - Simple Version for Testing
# ===================================================================
# Simplified version to test basic ExaPG functionality
# Date: 2024-12-19
# ===================================================================

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    echo "ExaPG Test Script v1.0.0"
    echo "PostgreSQL Analytical Database"
    echo "Project Root: $PROJECT_ROOT"
}

# Show help
show_help() {
    cat << EOF
ExaPG Test Script - Simple Testing Tool

USAGE:
    $SCRIPT_NAME [command]

COMMANDS:
    status      Check current Docker status
    k8s         Test Kubernetes deployment
    docker      Test Docker deployment (basic)
    validate    Validate environment
    help        Show this help
    version     Show version

EXAMPLES:
    $SCRIPT_NAME status     # Check what's running
    $SCRIPT_NAME k8s        # Deploy to Kubernetes
    $SCRIPT_NAME validate   # Validate setup

EOF
}

# Check Docker status
check_docker_status() {
    log_info "Checking Docker status..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running"
        return 1
    fi
    
    log_success "Docker is available"
    
    # Show running containers
    local containers
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10)
    
    if [[ -n "$containers" && "$containers" != "NAMES"* ]]; then
        log_info "Running containers:"
        echo "$containers"
    else
        log_info "No containers currently running"
    fi
    
    # Show available images
    local images
    images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10)
    
    if [[ -n "$images" && "$images" != "REPOSITORY"* ]]; then
        log_info "Available images:"
        echo "$images"
    else
        log_info "No Docker images available"
    fi
}

# Test Kubernetes deployment
test_kubernetes() {
    log_info "Testing Kubernetes deployment..."
    
    # Check if we have a k8s directory
    if [[ ! -d "k8s" ]]; then
        log_error "No k8s directory found"
        return 1
    fi
    
    log_success "Found k8s directory with manifests:"
    find k8s -name "*.yaml" | sort
    
    # Check if deploy script exists
    if [[ -f "k8s/deploy.sh" ]]; then
        log_success "Found k8s/deploy.sh deployment script"
        log_info "To deploy, run: cd k8s && ./deploy.sh"
    else
        log_warning "No k8s/deploy.sh found"
    fi
    
    # Check kubectl availability
    if command -v kubectl >/dev/null 2>&1; then
        log_success "kubectl is available"
        kubectl version --client --short 2>/dev/null || true
    else
        log_warning "kubectl not found"
    fi
}

# Simple Docker test
test_docker() {
    log_info "Testing Docker deployment..."
    
    # Look for docker-compose files
    local compose_files
    compose_files=$(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null || true)
    
    if [[ -n "$compose_files" ]]; then
        log_success "Found Docker Compose files:"
        echo "$compose_files"
    else
        log_warning "No docker-compose files found"
    fi
    
    # Look for Dockerfiles
    local dockerfiles
    dockerfiles=$(find . -name "Dockerfile*" 2>/dev/null || true)
    
    if [[ -n "$dockerfiles" ]]; then
        log_success "Found Dockerfiles:"
        echo "$dockerfiles"
    else
        log_warning "No Dockerfiles found"
    fi
    
    # Simple postgres test
    log_info "Testing simple PostgreSQL container..."
    if docker run --rm -d --name test-postgres -e POSTGRES_PASSWORD=test postgres:15 >/dev/null 2>&1; then
        sleep 3
        if docker exec test-postgres psql -U postgres -c "SELECT version();" >/dev/null 2>&1; then
            log_success "PostgreSQL container test successful"
        else
            log_error "PostgreSQL container test failed"
        fi
        docker stop test-postgres >/dev/null 2>&1 || true
    else
        log_error "Failed to start test PostgreSQL container"
    fi
}

# Validate environment
validate_environment() {
    log_info "Validating ExaPG environment..."
    
    local errors=0
    
    # Check required tools
    local tools=("docker" "docker-compose" "git")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "Found: $tool"
        else
            log_error "Missing: $tool"
            ((errors++))
        fi
    done
    
    # Check Docker
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon not accessible"
        ((errors++))
    fi
    
    # Check project files
    local important_files=(".env" "README.md" "CHANGELOG.md")
    for file in "${important_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Found: $file"
        else
            log_warning "Missing: $file"
        fi
    done
    
    # Check if .env exists, if not create from template
    if [[ ! -f ".env" ]] && [[ -f ".env.template" ]]; then
        log_info "Creating .env from template..."
        cp ".env.template" ".env"
        log_success "Created .env from template"
    fi
    
    # Summary
    if [[ $errors -eq 0 ]]; then
        log_success "Environment validation passed!"
        return 0
    else
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
}

# Main function
main() {
    cd "$PROJECT_ROOT" || exit 1
    
    case "${1:-status}" in
        "status")
            check_docker_status
            ;;
        "k8s"|"kubernetes")
            test_kubernetes
            ;;
        "docker")
            test_docker
            ;;
        "validate")
            validate_environment
            ;;
        "help"|"--help"|"h")
            show_help
            ;;
        "version"|"--version")
            show_version
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main with arguments
main "$@" 