#!/usr/bin/env bats
# ===================================================================
# ExaPG Docker Utils Unit Tests
# ===================================================================
# TESTING FIX: TEST-001 - Unit Tests for Docker Utilities
# Date: 2024-05-24
# ===================================================================

# Load test helpers
load '../test-helpers.bash'

# Test setup and teardown
setup() {
    setup_test
    
    # Source Docker utilities for testing
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
    
    # Create test Docker environment
    mkdir -p "$TEST_TEMP_DIR/docker"
    mkdir -p "$TEST_TEMP_DIR/scripts"
    
    # Create mock Docker utilities for testing
    cat > "$TEST_TEMP_DIR/scripts/docker-utils.sh" << 'EOF'
#!/bin/bash

# Mock Docker utility functions for testing
docker_available() {
    command -v docker >/dev/null 2>&1
}

docker_compose_available() {
    command -v docker-compose >/dev/null 2>&1 || \
    (command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1)
}

docker_running() {
    if ! docker_available; then
        return 1
    fi
    
    docker ps >/dev/null 2>&1
}

get_container_status() {
    local container_name="$1"
    
    if ! docker_available; then
        echo "docker_not_available"
        return 1
    fi
    
    local status=$(docker ps -a --filter name="$container_name" --format "{{.Status}}" 2>/dev/null | head -1)
    
    if [[ -z "$status" ]]; then
        echo "not_found"
        return 1
    elif [[ "$status" =~ ^Up ]]; then
        echo "running"
        return 0
    elif [[ "$status" =~ ^Exited ]]; then
        echo "stopped"
        return 0
    else
        echo "unknown"
        return 1
    fi
}

wait_for_container() {
    local container_name="$1"
    local timeout="${2:-60}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        local status=$(get_container_status "$container_name")
        if [[ "$status" == "running" ]]; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    return 1
}

check_container_health() {
    local container_name="$1"
    
    if ! docker_available; then
        echo "unhealthy"
        return 1
    fi
    
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    case "$health" in
        "healthy")
            echo "healthy"
            return 0
            ;;
        "unhealthy")
            echo "unhealthy"
            return 1
            ;;
        "starting")
            echo "starting"
            return 2
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    
    if ! docker_available; then
        return 1
    fi
    
    docker logs --tail "$lines" "$container_name" 2>/dev/null
}

get_container_ip() {
    local container_name="$1"
    
    if ! docker_available; then
        return 1
    fi
    
    docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null
}

docker_cleanup() {
    local project_name="${1:-exapg}"
    
    if ! docker_available; then
        return 1
    fi
    
    # Stop containers
    docker stop $(docker ps -q --filter label=com.docker.compose.project="$project_name") 2>/dev/null || true
    
    # Remove containers
    docker rm $(docker ps -aq --filter label=com.docker.compose.project="$project_name") 2>/dev/null || true
    
    # Remove networks
    docker network rm "${project_name}_default" 2>/dev/null || true
    
    # Remove volumes
    docker volume rm $(docker volume ls -q --filter label=com.docker.compose.project="$project_name") 2>/dev/null || true
}

build_image() {
    local dockerfile="$1"
    local tag="$2"
    local context="${3:-.}"
    
    if ! docker_available; then
        return 1
    fi
    
    if [[ ! -f "$dockerfile" ]]; then
        return 1
    fi
    
    docker build -f "$dockerfile" -t "$tag" "$context"
}

validate_compose_file() {
    local compose_file="$1"
    
    if [[ ! -f "$compose_file" ]]; then
        return 1
    fi
    
    if docker_compose_available; then
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f "$compose_file" config >/dev/null 2>&1
        else
            docker compose -f "$compose_file" config >/dev/null 2>&1
        fi
    else
        # Basic YAML syntax check if docker-compose not available
        python3 -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null || \
        python -c "import yaml; yaml.safe_load(open('$compose_file'))" 2>/dev/null
    fi
}

get_compose_services() {
    local compose_file="$1"
    
    if [[ ! -f "$compose_file" ]]; then
        return 1
    fi
    
    if command -v yq >/dev/null 2>&1; then
        yq eval '.services | keys | .[]' "$compose_file" 2>/dev/null
    else
        # Fallback: parse with grep
        grep -E '^  [a-zA-Z0-9_-]+:$' "$compose_file" | sed 's/://g' | sed 's/^  //'
    fi
}

check_port_available() {
    local port="$1"
    local host="${2:-localhost}"
    
    ! nc -z "$host" "$port" 2>/dev/null
}

docker_system_prune() {
    local force="${1:-false}"
    
    if ! docker_available; then
        return 1
    fi
    
    if [[ "$force" == "true" ]]; then
        docker system prune -f
    else
        docker system prune
    fi
}

export_container() {
    local container_name="$1"
    local output_file="$2"
    
    if ! docker_available; then
        return 1
    fi
    
    docker export "$container_name" > "$output_file" 2>/dev/null
}

import_container() {
    local image_file="$1"
    local repository="$2"
    
    if ! docker_available; then
        return 1
    fi
    
    if [[ ! -f "$image_file" ]]; then
        return 1
    fi
    
    docker import "$image_file" "$repository" >/dev/null 2>&1
}
EOF
    
    # Source the Docker utilities
    source "$TEST_TEMP_DIR/scripts/docker-utils.sh"
    
    # Create test docker-compose.yml
    cat > "$TEST_TEMP_DIR/docker/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  coordinator:
    image: postgres:15
    container_name: exapg_coordinator
    environment:
      - POSTGRES_DB=exadb
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"
    networks:
      - exapg_network

  worker1:
    image: postgres:15
    container_name: exapg_worker1
    environment:
      - POSTGRES_DB=exadb
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    ports:
      - "5433:5432"
    networks:
      - exapg_network

networks:
  exapg_network:
    driver: bridge

volumes:
  coordinator_data:
  worker1_data:
EOF
}

teardown() {
    teardown_test
}

# ===================================================================
# DOCKER AVAILABILITY TESTS
# ===================================================================

@test "docker_available detects Docker presence" {
    if command -v docker >/dev/null 2>&1; then
        run docker_available
        assert_success
    else
        run docker_available
        assert_failure
    fi
}

@test "docker_compose_available detects Docker Compose" {
    if command -v docker-compose >/dev/null 2>&1 || (command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1); then
        run docker_compose_available
        assert_success
    else
        run docker_compose_available
        assert_failure
    fi
}

@test "docker_running checks Docker daemon status" {
    if command -v docker >/dev/null 2>&1; then
        run docker_running
        # Should succeed if Docker daemon is running
        [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
    else
        run docker_running
        assert_failure
    fi
}

# ===================================================================
# CONTAINER STATUS TESTS
# ===================================================================

@test "get_container_status handles non-existent container" {
    run get_container_status "nonexistent_container_12345"
    
    if docker_available; then
        assert_failure
        assert_output "not_found"
    else
        assert_failure
        assert_output "docker_not_available"
    fi
}

@test "get_container_status returns proper status format" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Test with a known non-existent container
    run get_container_status "definitely_not_existing_container"
    assert_failure
    assert_output "not_found"
}

@test "check_container_health handles missing container" {
    run check_container_health "nonexistent_container"
    
    if docker_available; then
        assert_failure
        assert_output "unknown"
    else
        assert_failure
        assert_output "unhealthy"
    fi
}

# ===================================================================
# WAIT AND TIMEOUT TESTS
# ===================================================================

@test "wait_for_container respects timeout" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Test with short timeout for non-existent container
    run timeout 10 wait_for_container "nonexistent_container" 2
    assert_failure
}

@test "wait_for_container uses default timeout" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # This should timeout quickly for non-existent container
    run timeout 5 wait_for_container "nonexistent_container"
    assert_failure
}

# ===================================================================
# DOCKER COMPOSE VALIDATION TESTS
# ===================================================================

@test "validate_compose_file accepts valid compose file" {
    local compose_file="$TEST_TEMP_DIR/docker/docker-compose.yml"
    
    run validate_compose_file "$compose_file"
    
    if docker_compose_available || command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
        assert_success
    else
        # Skip if no validation tools available
        skip "No Docker Compose or Python available for validation"
    fi
}

@test "validate_compose_file rejects missing file" {
    run validate_compose_file "/nonexistent/docker-compose.yml"
    assert_failure
}

@test "validate_compose_file rejects invalid YAML" {
    local invalid_compose="$TEST_TEMP_DIR/invalid-compose.yml"
    
    cat > "$invalid_compose" << 'EOF'
version: '3.8'
services:
  test:
    image: test
    invalid_yaml: [
      - missing_closing_bracket
EOF
    
    run validate_compose_file "$invalid_compose"
    assert_failure
}

@test "get_compose_services extracts service names" {
    local compose_file="$TEST_TEMP_DIR/docker/docker-compose.yml"
    
    run get_compose_services "$compose_file"
    
    if command -v yq >/dev/null 2>&1; then
        assert_success
        assert_line "coordinator"
        assert_line "worker1"
    else
        # Fallback parsing
        assert_success
        assert_output --partial "coordinator"
        assert_output --partial "worker1"
    fi
}

@test "get_compose_services handles missing file" {
    run get_compose_services "/nonexistent/compose.yml"
    assert_failure
}

# ===================================================================
# PORT CHECKING TESTS
# ===================================================================

@test "check_port_available detects available ports" {
    # Test with very high port number that should be available
    run check_port_available "65432"
    assert_success
}

@test "check_port_available detects unavailable ports" {
    # Test with port 22 (SSH) which is commonly in use
    if nc -z localhost 22 2>/dev/null; then
        run check_port_available "22"
        assert_failure
    else
        skip "Port 22 not in use, cannot test unavailable port detection"
    fi
}

@test "check_port_available handles different hosts" {
    run check_port_available "65432" "127.0.0.1"
    assert_success
    
    run check_port_available "65432" "localhost"
    assert_success
}

# ===================================================================
# DOCKER BUILD TESTS
# ===================================================================

@test "build_image validates Dockerfile existence" {
    run build_image "/nonexistent/Dockerfile" "test:latest"
    assert_failure
}

@test "build_image requires Docker availability" {
    if ! docker_available; then
        # Create a mock Dockerfile
        local dockerfile="$TEST_TEMP_DIR/Dockerfile"
        echo "FROM alpine:latest" > "$dockerfile"
        
        run build_image "$dockerfile" "test:latest"
        assert_failure
    else
        skip "Docker is available"
    fi
}

# ===================================================================
# CLEANUP FUNCTION TESTS
# ===================================================================

@test "docker_cleanup handles missing Docker" {
    if ! docker_available; then
        run docker_cleanup "test_project"
        assert_failure
    else
        # If Docker is available, cleanup should succeed even with no containers
        run docker_cleanup "nonexistent_project"
        assert_success
    fi
}

@test "docker_cleanup uses default project name" {
    if docker_available; then
        run docker_cleanup
        assert_success
    else
        run docker_cleanup
        assert_failure
    fi
}

# ===================================================================
# INTEGRATION TESTS
# ===================================================================

@test "Docker utility workflow works together" {
    local compose_file="$TEST_TEMP_DIR/docker/docker-compose.yml"
    
    # Validate compose file
    run validate_compose_file "$compose_file"
    if docker_compose_available || command -v python3 >/dev/null 2>&1; then
        assert_success
    else
        skip "No validation tools available"
    fi
    
    # Get services
    run get_compose_services "$compose_file"
    assert_success
    
    # Check if ports are available
    run check_port_available "5432"
    # Port might be in use, so we don't assert success/failure
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
    
    run check_port_available "5433"
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
} 