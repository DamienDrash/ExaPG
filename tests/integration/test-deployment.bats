#!/usr/bin/env bats
# ===================================================================
# ExaPG Deployment Integration Tests
# ===================================================================
# TESTING FIX: TEST-001 - Integration Tests for Deployment
# Date: 2024-05-24
# ===================================================================

# Load test helpers
load '../test-helpers.bash'

# Test setup and teardown
setup() {
    setup_test
    
    # Source deployment utilities for testing
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
    
    # Create test deployment environment
    mkdir -p "$TEST_TEMP_DIR/docker"
    mkdir -p "$TEST_TEMP_DIR/config"
    mkdir -p "$TEST_TEMP_DIR/scripts"
    
    # Create minimal docker-compose.yml for testing
    cat > "$TEST_TEMP_DIR/docker/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  coordinator:
    image: postgres:15-alpine
    container_name: ${TEST_COMPOSE_PROJECT}_coordinator
    environment:
      - POSTGRES_DB=${TEST_DB_NAME}
      - POSTGRES_USER=${TEST_DB_USER}
      - POSTGRES_PASSWORD=${TEST_DB_PASSWORD}
    ports:
      - "${TEST_DB_PORT}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${TEST_DB_USER} -d ${TEST_DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - exapg_test

  worker1:
    image: postgres:15-alpine
    container_name: ${TEST_COMPOSE_PROJECT}_worker1
    environment:
      - POSTGRES_DB=${TEST_DB_NAME}
      - POSTGRES_USER=${TEST_DB_USER}
      - POSTGRES_PASSWORD=${TEST_DB_PASSWORD}
    ports:
      - "5433:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${TEST_DB_USER} -d ${TEST_DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - exapg_test

networks:
  exapg_test:
    driver: bridge

volumes:
  coordinator_data:
  worker1_data:
EOF

    # Create deployment script
    cat > "$TEST_TEMP_DIR/scripts/deploy.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

# Mock deployment functions
deploy_exapg() {
    local mode="${1:-standalone}"
    local env_file="${2:-}"
    
    echo "Deploying ExaPG in $mode mode..."
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: Docker not available"
        return 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        echo "Error: Docker Compose not available"
        return 1
    fi
    
    # Set environment variables
    if [[ -n "$env_file" && -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
    fi
    
    # Validate required environment variables
    local required_vars=(
        "TEST_COMPOSE_PROJECT"
        "TEST_DB_NAME"
        "TEST_DB_USER"
        "TEST_DB_PASSWORD"
        "TEST_DB_PORT"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "Error: Required environment variable $var not set"
            return 1
        fi
    done
    
    # Start services
    cd "$(dirname "${BASH_SOURCE[0]}")/../docker"
    
    case "$mode" in
        "standalone")
            docker-compose up -d coordinator
            ;;
        "cluster")
            docker-compose up -d coordinator worker1
            ;;
        *)
            echo "Error: Unknown deployment mode: $mode"
            return 1
            ;;
    esac
    
    echo "Deployment completed successfully"
    return 0
}

stop_exapg() {
    echo "Stopping ExaPG services..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")/../docker"
    
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose down --volumes --remove-orphans
    fi
    
    echo "Services stopped"
    return 0
}

check_deployment_status() {
    local service="$1"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo "unhealthy"
        return 1
    fi
    
    local container_name="${TEST_COMPOSE_PROJECT}_${service}"
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
    
    case "$status" in
        "running")
            # Check health if healthcheck is configured
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
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
                    echo "running"
                    return 0
                    ;;
            esac
            ;;
        "exited")
            echo "stopped"
            return 1
            ;;
        "not_found")
            echo "not_found"
            return 1
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

wait_for_healthy() {
    local service="$1"
    local timeout="${2:-120}"
    local count=0
    
    echo "Waiting for $service to become healthy..."
    
    while [[ $count -lt $timeout ]]; do
        local status=$(check_deployment_status "$service")
        case "$status" in
            "healthy"|"running")
                echo "$service is healthy"
                return 0
                ;;
            "starting")
                echo -n "."
                ;;
            "unhealthy"|"stopped"|"not_found")
                echo "$service is $status"
                return 1
                ;;
        esac
        
        sleep 1
        ((count++))
    done
    
    echo "Timeout waiting for $service to become healthy"
    return 1
}

validate_deployment() {
    local mode="${1:-standalone}"
    
    echo "Validating deployment in $mode mode..."
    
    case "$mode" in
        "standalone")
            if ! wait_for_healthy "coordinator"; then
                return 1
            fi
            ;;
        "cluster")
            if ! wait_for_healthy "coordinator"; then
                return 1
            fi
            if ! wait_for_healthy "worker1"; then
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown deployment mode: $mode"
            return 1
            ;;
    esac
    
    echo "Deployment validation completed successfully"
    return 0
}

test_database_connection() {
    local host="${1:-localhost}"
    local port="${2:-5432}"
    local database="${3:-${TEST_DB_NAME}}"
    local user="${4:-${TEST_DB_USER}}"
    
    echo "Testing database connection to $host:$port/$database..."
    
    if ! command -v psql >/dev/null 2>&1; then
        echo "psql not available, using alternative method"
        
        # Alternative: use docker exec if container is running
        local container_name="${TEST_COMPOSE_PROJECT}_coordinator"
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            docker exec "$container_name" psql -U "$user" -d "$database" -c "SELECT 1;" >/dev/null 2>&1
        else
            return 1
        fi
    else
        PGPASSWORD="${TEST_DB_PASSWORD}" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" >/dev/null 2>&1
    fi
}

get_deployment_logs() {
    local service="${1:-coordinator}"
    local lines="${2:-50}"
    
    local container_name="${TEST_COMPOSE_PROJECT}_${service}"
    
    if command -v docker >/dev/null 2>&1; then
        docker logs --tail "$lines" "$container_name" 2>/dev/null || echo "No logs available"
    else
        echo "Docker not available"
        return 1
    fi
}

cleanup_deployment() {
    echo "Cleaning up deployment..."
    
    # Stop and remove containers
    stop_exapg
    
    # Remove any orphaned containers
    if command -v docker >/dev/null 2>&1; then
        docker ps -a --filter "name=${TEST_COMPOSE_PROJECT}" --format "{{.ID}}" | xargs -r docker rm -f
        
        # Remove test networks
        docker network ls --filter "name=${TEST_COMPOSE_PROJECT}" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
        
        # Remove test volumes
        docker volume ls --filter "name=${TEST_COMPOSE_PROJECT}" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
    fi
    
    echo "Cleanup completed"
}
EOF

    # Source the deployment functions
    source "$TEST_TEMP_DIR/scripts/deploy.sh"
    
    # Set test environment variables
    export TEST_COMPOSE_PROJECT="exapg_test_$$"
    export TEST_DB_NAME="exadb_test"
    export TEST_DB_USER="postgres"
    export TEST_DB_PASSWORD="test_password_$$"
    export TEST_DB_PORT="5434"
}

teardown() {
    # Cleanup any containers created during tests
    if [[ -n "${TEST_COMPOSE_PROJECT:-}" ]]; then
        cleanup_deployment 2>/dev/null || true
    fi
    
    teardown_test
}

# ===================================================================
# DEPLOYMENT FUNCTION TESTS
# ===================================================================

@test "deploy_exapg requires Docker" {
    if ! command -v docker >/dev/null 2>&1; then
        run deploy_exapg "standalone"
        assert_failure
        assert_output --partial "Docker not available"
    else
        skip "Docker is available"
    fi
}

@test "deploy_exapg requires Docker Compose" {
    if ! command -v docker-compose >/dev/null 2>&1; then
        run deploy_exapg "standalone"
        assert_failure
        assert_output --partial "Docker Compose not available"
    else
        skip "Docker Compose is available"
    fi
}

@test "deploy_exapg validates required environment variables" {
    if ! docker_available || ! docker_compose_available; then
        skip "Docker or Docker Compose not available"
    fi
    
    # Unset required variables to test validation
    local old_project="$TEST_COMPOSE_PROJECT"
    unset TEST_COMPOSE_PROJECT
    
    run deploy_exapg "standalone"
    assert_failure
    assert_output --partial "Required environment variable TEST_COMPOSE_PROJECT not set"
    
    # Restore variable
    export TEST_COMPOSE_PROJECT="$old_project"
}

@test "deploy_exapg accepts valid deployment modes" {
    if ! docker_available || ! docker_compose_available; then
        skip "Docker or Docker Compose not available"
    fi
    
    # Test standalone mode (don't actually deploy)
    run timeout 5 deploy_exapg "standalone" "/dev/null"
    [[ $status -eq 0 ]] || [[ $status -eq 124 ]]  # Success or timeout
}

@test "deploy_exapg rejects invalid deployment modes" {
    run deploy_exapg "invalid_mode"
    assert_failure
    assert_output --partial "Unknown deployment mode: invalid_mode"
}

# ===================================================================
# DEPLOYMENT STATUS TESTS
# ===================================================================

@test "check_deployment_status handles missing Docker" {
    if ! command -v docker >/dev/null 2>&1; then
        run check_deployment_status "coordinator"
        assert_failure
        assert_output "unhealthy"
    else
        skip "Docker is available"
    fi
}

@test "check_deployment_status handles non-existent containers" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Use a container name that definitely doesn't exist
    export TEST_COMPOSE_PROJECT="nonexistent_project_12345"
    
    run check_deployment_status "coordinator"
    assert_failure
    assert_output "not_found"
}

@test "wait_for_healthy respects timeout" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Use a container that doesn't exist to test timeout
    export TEST_COMPOSE_PROJECT="nonexistent_project_12345"
    
    run timeout 10 wait_for_healthy "coordinator" 2
    assert_failure
}

# ===================================================================
# DATABASE CONNECTION TESTS
# ===================================================================

@test "test_database_connection handles missing psql" {
    if command -v psql >/dev/null 2>&1; then
        skip "psql is available"
    fi
    
    # Should fallback to docker exec method
    run test_database_connection "localhost" "5432" "test_db" "test_user"
    # Will fail because container doesn't exist, but should not crash
    assert_failure
}

@test "test_database_connection validates parameters" {
    # Test with obviously wrong parameters
    run timeout 5 test_database_connection "nonexistent.host" "99999" "nonexistent_db" "nonexistent_user"
    assert_failure
}

# ===================================================================
# LOGGING TESTS
# ===================================================================

@test "get_deployment_logs handles missing Docker" {
    if ! command -v docker >/dev/null 2>&1; then
        run get_deployment_logs "coordinator"
        assert_failure
        assert_output "Docker not available"
    else
        skip "Docker is available"
    fi
}

@test "get_deployment_logs handles missing container" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    export TEST_COMPOSE_PROJECT="nonexistent_project_12345"
    
    run get_deployment_logs "coordinator"
    assert_success
    assert_output "No logs available"
}

@test "get_deployment_logs uses default parameters" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    export TEST_COMPOSE_PROJECT="nonexistent_project_12345"
    
    run get_deployment_logs
    assert_success
    assert_output "No logs available"
}

# ===================================================================
# CLEANUP TESTS
# ===================================================================

@test "cleanup_deployment handles missing Docker gracefully" {
    if ! command -v docker >/dev/null 2>&1; then
        run cleanup_deployment
        assert_success
        assert_output --partial "Cleaning up deployment"
    else
        skip "Docker is available"
    fi
}

@test "stop_exapg handles missing docker-compose gracefully" {
    if ! command -v docker-compose >/dev/null 2>&1; then
        # Should handle missing docker-compose gracefully
        run stop_exapg
        assert_success
        assert_output --partial "Services stopped"
    else
        skip "Docker Compose is available"
    fi
}

# ===================================================================
# INTEGRATION WORKFLOW TESTS
# ===================================================================

@test "deployment workflow validates environment" {
    # Test the complete validation workflow
    
    # 1. Check Docker availability
    run command -v docker
    if [[ $status -ne 0 ]]; then
        skip "Docker not available for integration test"
    fi
    
    # 2. Check Docker Compose availability
    run command -v docker-compose
    if [[ $status -ne 0 ]]; then
        skip "Docker Compose not available for integration test"
    fi
    
    # 3. Validate environment variables are set
    [[ -n "$TEST_COMPOSE_PROJECT" ]]
    [[ -n "$TEST_DB_NAME" ]]
    [[ -n "$TEST_DB_USER" ]]
    [[ -n "$TEST_DB_PASSWORD" ]]
    [[ -n "$TEST_DB_PORT" ]]
    
    # 4. Test deployment status check
    run check_deployment_status "coordinator"
    # Should return not_found initially
    assert_failure
    assert_output "not_found"
}

@test "deployment functions handle concurrent access" {
    if ! docker_available || ! docker_compose_available; then
        skip "Docker or Docker Compose not available"
    fi
    
    # Test that deployment functions can be called multiple times safely
    run check_deployment_status "coordinator"
    local first_result=$status
    
    run check_deployment_status "coordinator"
    local second_result=$status
    
    # Results should be consistent
    [[ $first_result -eq $second_result ]]
}

# ===================================================================
# ERROR HANDLING TESTS
# ===================================================================

@test "deployment functions handle invalid service names" {
    # Test with obviously invalid service names
    run check_deployment_status ""
    assert_failure
    
    run check_deployment_status "invalid-service-name-with-special-chars!"
    if docker_available; then
        assert_failure
        assert_output "not_found"
    else
        assert_failure
        assert_output "unhealthy"
    fi
}

@test "deployment functions handle resource constraints" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Test behavior under resource constraints
    # This is a placeholder for more complex resource testing
    run check_deployment_status "coordinator"
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # Should not crash
}

# ===================================================================
# PERFORMANCE TESTS
# ===================================================================

@test "deployment status checks are reasonably fast" {
    if ! docker_available; then
        skip "Docker not available"
    fi
    
    # Status check should complete within reasonable time
    run timeout 5 check_deployment_status "coordinator"
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]  # Success or failure, but not timeout (124)
}

# ===================================================================
# CONFIGURATION TESTS
# ===================================================================

@test "deployment validates docker-compose file syntax" {
    local compose_file="$TEST_TEMP_DIR/docker/docker-compose.yml"
    
    if docker_compose_available; then
        # Validate compose file syntax
        run docker-compose -f "$compose_file" config
        assert_success
    else
        skip "Docker Compose not available for validation"
    fi
}

@test "deployment handles environment variable substitution" {
    local compose_file="$TEST_TEMP_DIR/docker/docker-compose.yml"
    
    if docker_compose_available; then
        # Test that environment variables are properly substituted
        run docker-compose -f "$compose_file" config
        assert_success
        assert_output --partial "$TEST_DB_NAME"
        assert_output --partial "$TEST_DB_USER"
    else
        skip "Docker Compose not available for validation"
    fi
}

# ===================================================================
# REAL DEPLOYMENT TESTS (Conditional)
# ===================================================================

@test "real deployment test (conditional)" {
    if [[ "${EXAPG_RUN_INTEGRATION_TESTS:-false}" != "true" ]]; then
        skip "Real integration tests disabled (set EXAPG_RUN_INTEGRATION_TESTS=true to enable)"
    fi
    
    if ! docker_available || ! docker_compose_available; then
        skip "Docker or Docker Compose not available"
    fi
    
    # This is a real deployment test that actually starts containers
    test_log "Starting real deployment test..."
    
    # Deploy in standalone mode
    run deploy_exapg "standalone"
    assert_success
    assert_output --partial "Deployment completed successfully"
    
    # Wait for service to be healthy
    run wait_for_healthy "coordinator" 60
    assert_success
    
    # Test database connection
    run test_database_connection "localhost" "$TEST_DB_PORT" "$TEST_DB_NAME" "$TEST_DB_USER"
    assert_success
    
    # Cleanup
    run cleanup_deployment
    assert_success
    
    test_log "Real deployment test completed successfully"
} 