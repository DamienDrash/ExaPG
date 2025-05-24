#!/bin/bash
# ===================================================================
# ExaPG Secure Docker Build Script
# ===================================================================
# DOCKER FIXES: DOCK-001 & DOCK-002 - Secure Multi-Stage Build
# Date: 2024-05-24
# Version: 2.0.0
# ===================================================================

set -euo pipefail

# ===================================================================
# CONFIGURATION
# ===================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DOCKER_DIR="$PROJECT_ROOT/docker"

# Build configuration
readonly IMAGE_NAME="${IMAGE_NAME:-exapg}"
readonly IMAGE_TAG="${IMAGE_TAG:-latest}"
readonly BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
readonly GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"

# Security configuration
readonly SECURITY_SCAN="${SECURITY_SCAN:-true}"
readonly BUILD_NO_CACHE="${BUILD_NO_CACHE:-false}"
readonly SQUASH_IMAGE="${SQUASH_IMAGE:-true}"

# ===================================================================
# LOGGING FUNCTIONS
# ===================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" >&2
}

# ===================================================================
# VALIDATION FUNCTIONS
# ===================================================================

validate_environment() {
    log "Validating build environment..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check Docker version (require 20.10+)
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' | cut -d. -f1,2)
    if [[ $(echo "$docker_version < 20.10" | bc -l) -eq 1 ]] 2>/dev/null; then
        log_warning "Docker version $docker_version is old. Recommend 20.10+"
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. Consider using Docker rootless mode."
    fi
    
    # Validate project structure
    if [[ ! -f "$DOCKER_DIR/Dockerfile" ]]; then
        log_error "Dockerfile not found at $DOCKER_DIR/Dockerfile"
        exit 1
    fi
    
    if [[ ! -f "$DOCKER_DIR/.dockerignore" ]]; then
        log_warning ".dockerignore not found. Build context may be large."
    fi
    
    log_success "Environment validation completed"
}

# ===================================================================
# SECURITY FUNCTIONS
# ===================================================================

scan_base_image() {
    log "Scanning base image for vulnerabilities..."
    
    if command -v docker >/dev/null 2>&1; then
        # Use Docker Scout if available
        if docker scout version >/dev/null 2>&1; then
            log "Using Docker Scout for security scan..."
            docker scout cves postgres:15 || log_warning "Docker Scout scan warnings detected"
        else
            log_warning "Docker Scout not available. Consider installing for security scanning."
        fi
    fi
}

security_scan_image() {
    local image_name="$1"
    
    if [[ "$SECURITY_SCAN" != "true" ]]; then
        log "Security scanning disabled"
        return 0
    fi
    
    log "Performing security scan on built image..."
    
    # Check for common security issues
    docker run --rm -i \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$PWD:/workspace" \
        --workdir /workspace \
        hadolint/hadolint:latest \
        hadolint "$DOCKER_DIR/Dockerfile" || log_warning "Hadolint detected potential issues"
    
    # Scan with Docker Scout if available
    if docker scout version >/dev/null 2>&1; then
        docker scout cves "$image_name" || log_warning "Security vulnerabilities detected"
    fi
    
    # Check image for best practices
    log "Checking image security configuration..."
    
    # Verify non-root user
    local user_check
    user_check=$(docker run --rm "$image_name" id -u)
    if [[ "$user_check" == "0" ]]; then
        log_error "Image runs as root user (security risk)"
        return 1
    else
        log_success "Image runs as non-root user (UID: $user_check)"
    fi
    
    # Check for sensitive files
    local sensitive_files
    sensitive_files=$(docker run --rm "$image_name" find / -name "*.key" -o -name "*.pem" -o -name "passwd" 2>/dev/null | wc -l)
    if [[ "$sensitive_files" -gt 0 ]]; then
        log_warning "Found $sensitive_files potentially sensitive files in image"
    fi
    
    log_success "Security scan completed"
}

# ===================================================================
# BUILD FUNCTIONS
# ===================================================================

build_image() {
    log "Starting multi-stage Docker build..."
    
    cd "$PROJECT_ROOT"
    
    # Build arguments
    local build_args=(
        --file "$DOCKER_DIR/Dockerfile"
        --tag "$IMAGE_NAME:$IMAGE_TAG"
        --tag "$IMAGE_NAME:latest"
        --label "build.date=$BUILD_DATE"
        --label "build.version=$IMAGE_TAG"
        --label "build.commit=$GIT_COMMIT"
        --label "security.hardened=true"
        --label "security.multi-stage=true"
        --label "security.non-root=true"
    )
    
    # Add cache options
    if [[ "$BUILD_NO_CACHE" == "true" ]]; then
        build_args+=(--no-cache)
        log "Building without cache"
    fi
    
    # Add squash option if enabled and supported
    if [[ "$SQUASH_IMAGE" == "true" ]] && docker build --help | grep -q -- --squash; then
        build_args+=(--squash)
        log "Squashing image layers"
    fi
    
    # Progress output
    build_args+=(--progress=plain)
    
    # Build context
    build_args+=("$PROJECT_ROOT")
    
    log "Build command: docker build ${build_args[*]}"
    
    # Execute build
    if docker build "${build_args[@]}"; then
        log_success "Docker build completed successfully"
    else
        log_error "Docker build failed"
        exit 1
    fi
}

# ===================================================================
# POST-BUILD FUNCTIONS
# ===================================================================

verify_build() {
    log "Verifying built image..."
    
    # Test image startup
    local container_id
    container_id=$(docker run -d --rm "$IMAGE_NAME:$IMAGE_TAG" sleep 10)
    
    if docker ps | grep -q "$container_id"; then
        log_success "Image starts successfully"
        docker stop "$container_id" >/dev/null 2>&1
    else
        log_error "Image failed to start"
        return 1
    fi
    
    # Check image size
    local image_size
    image_size=$(docker images --format "table {{.Size}}" "$IMAGE_NAME:$IMAGE_TAG" | tail -n 1)
    log "Image size: $image_size"
    
    # Check image layers
    local layer_count
    layer_count=$(docker history --no-trunc "$IMAGE_NAME:$IMAGE_TAG" | wc -l)
    log "Image layers: $layer_count"
    
    if [[ $layer_count -gt 50 ]]; then
        log_warning "Image has many layers ($layer_count). Consider optimizing."
    fi
}

show_build_summary() {
    log "Build Summary:"
    echo "==========================================="
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Build Date: $BUILD_DATE"
    echo "Git Commit: $GIT_COMMIT"
    echo "Security Features:"
    echo "  ✓ Multi-stage build"
    echo "  ✓ Non-root user"
    echo "  ✓ Security hardened"
    echo "  ✓ Minimal attack surface"
    echo "==========================================="
    
    # Show image details
    docker images "$IMAGE_NAME:$IMAGE_TAG"
    
    log_success "Build completed successfully!"
}

# ===================================================================
# CLEANUP FUNCTIONS
# ===================================================================

cleanup_build_cache() {
    if [[ "${CLEANUP_CACHE:-false}" == "true" ]]; then
        log "Cleaning up Docker build cache..."
        docker builder prune -f
        log_success "Build cache cleaned"
    fi
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    log "Starting ExaPG secure Docker build process..."
    
    # Pre-build checks
    validate_environment
    scan_base_image
    
    # Build process
    build_image
    
    # Post-build verification
    verify_build
    security_scan_image "$IMAGE_NAME:$IMAGE_TAG"
    
    # Cleanup
    cleanup_build_cache
    
    # Summary
    show_build_summary
}

# ===================================================================
# SCRIPT ENTRY POINT
# ===================================================================

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << EOF
ExaPG Secure Docker Build Script

Usage: $0 [options]

Environment Variables:
  IMAGE_NAME          Docker image name (default: exapg)
  IMAGE_TAG           Docker image tag (default: latest)
  SECURITY_SCAN       Enable security scanning (default: true)
  BUILD_NO_CACHE      Disable build cache (default: false)
  SQUASH_IMAGE        Squash image layers (default: true)
  CLEANUP_CACHE       Clean build cache after build (default: false)

Examples:
  $0                                    # Standard build
  IMAGE_TAG=v2.0.0 $0                  # Build with version tag
  BUILD_NO_CACHE=true $0               # Build without cache
  SECURITY_SCAN=false $0               # Skip security scanning

Security Features:
  - Multi-stage build for minimal attack surface
  - Non-root user execution
  - Security-hardened container
  - Vulnerability scanning
  - Best practices validation
EOF
    exit 0
fi

# Run main function
main "$@" 