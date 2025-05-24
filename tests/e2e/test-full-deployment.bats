#!/usr/bin/env bats
# ===================================================================
# ExaPG End-to-End Full Deployment Tests
# ===================================================================
# TESTING FIX: TEST-001 - End-to-End Tests for Complete Workflows
# Date: 2024-05-24
# ===================================================================

# Load test helpers
load '../test-helpers.bash'

# Test setup and teardown
setup() {
    setup_test
    
    # Only run E2E tests if explicitly enabled
    if [[ "${EXAPG_RUN_E2E_TESTS:-false}" != "true" ]]; then
        skip "E2E tests disabled (set EXAPG_RUN_E2E_TESTS=true to enable)"
    fi
    
    # Check prerequisites
    if ! docker_available || ! docker_compose_available; then
        skip "Docker or Docker Compose not available for E2E tests"
    fi
    
    # Set up E2E test environment
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
    export E2E_PROJECT_NAME="exapg_e2e_$$"
    export E2E_NETWORK_NAME="${E2E_PROJECT_NAME}_network"
    
    # Create test directory structure
    mkdir -p "$TEST_TEMP_DIR/e2e"
    mkdir -p "$TEST_TEMP_DIR/e2e/docker"
    mkdir -p "$TEST_TEMP_DIR/e2e/config"
    mkdir -p "$TEST_TEMP_DIR/e2e/scripts"
    
    # Create comprehensive E2E docker-compose
    create_e2e_docker_compose
    
    # Create E2E configuration
    create_e2e_configuration
    
    # Create E2E deployment script
    create_e2e_deployment_script
}

teardown() {
    # Cleanup E2E environment
    if [[ -n "${E2E_PROJECT_NAME:-}" ]]; then
        cleanup_e2e_deployment 2>/dev/null || true
    fi
    
    teardown_test
}

# ===================================================================
# E2E SETUP FUNCTIONS
# ===================================================================

create_e2e_docker_compose() {
    cat > "$TEST_TEMP_DIR/e2e/docker/docker-compose.yml" << EOF
version: '3.8'

services:
  coordinator:
    image: postgres:15-alpine
    container_name: ${E2E_PROJECT_NAME}_coordinator
    environment:
      - POSTGRES_DB=exadb
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=e2e_password
    ports:
      - "5432:5432"
    volumes:
      - coordinator_data:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d exadb"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - ${E2E_NETWORK_NAME}
    labels:
      - "com.exapg.component=coordinator"
      - "com.exapg.e2e=true"

  worker1:
    image: postgres:15-alpine
    container_name: ${E2E_PROJECT_NAME}_worker1
    environment:
      - POSTGRES_DB=exadb
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=e2e_password
    ports:
      - "5433:5432"
    volumes:
      - worker1_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d exadb"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - ${E2E_NETWORK_NAME}
    labels:
      - "com.exapg.component=worker"
      - "com.exapg.e2e=true"
    depends_on:
      coordinator:
        condition: service_healthy

  worker2:
    image: postgres:15-alpine
    container_name: ${E2E_PROJECT_NAME}_worker2
    environment:
      - POSTGRES_DB=exadb
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=e2e_password
    ports:
      - "5434:5432"
    volumes:
      - worker2_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d exadb"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - ${E2E_NETWORK_NAME}
    labels:
      - "com.exapg.component=worker"
      - "com.exapg.e2e=true"
    depends_on:
      coordinator:
        condition: service_healthy

  monitoring:
    image: prom/prometheus:latest
    container_name: ${E2E_PROJECT_NAME}_monitoring
    ports:
      - "9090:9090"
    volumes:
      - monitoring_data:/prometheus
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - ${E2E_NETWORK_NAME}
    labels:
      - "com.exapg.component=monitoring"
      - "com.exapg.e2e=true"
    depends_on:
      - coordinator

networks:
  ${E2E_NETWORK_NAME}:
    driver: bridge
    labels:
      - "com.exapg.e2e=true"

volumes:
  coordinator_data:
    labels:
      - "com.exapg.e2e=true"
  worker1_data:
    labels:
      - "com.exapg.e2e=true"
  worker2_data:
    labels:
      - "com.exapg.e2e=true"
  monitoring_data:
    labels:
      - "com.exapg.e2e=true"
EOF

    # Create init SQL for database setup
    mkdir -p "$TEST_TEMP_DIR/e2e/docker/init"
    cat > "$TEST_TEMP_DIR/e2e/docker/init/01-setup.sql" << 'EOF'
-- E2E Test Database Setup
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create test schemas
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS staging;

-- Create test tables
CREATE TABLE IF NOT EXISTS analytics.sales (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL
);

-- Insert test data
INSERT INTO analytics.sales (date, amount, customer_id, product_id)
SELECT 
    CURRENT_DATE - (RANDOM() * 365)::INTEGER,
    (RANDOM() * 1000)::DECIMAL(10,2),
    (RANDOM() * 1000)::INTEGER + 1,
    (RANDOM() * 100)::INTEGER + 1
FROM generate_series(1, 1000);

-- Create test user
CREATE USER IF NOT EXISTS exapg_test WITH PASSWORD 'test_password';
GRANT CONNECT ON DATABASE exadb TO exapg_test;
GRANT USAGE ON SCHEMA analytics TO exapg_test;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO exapg_test;
EOF

    # Create Prometheus configuration
    cat > "$TEST_TEMP_DIR/e2e/docker/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'exapg-coordinator'
    static_configs:
      - targets: ['coordinator:5432']

  - job_name: 'exapg-workers'
    static_configs:
      - targets: ['worker1:5432', 'worker2:5432']
EOF
}

create_e2e_configuration() {
    cat > "$TEST_TEMP_DIR/e2e/config/e2e.env" << EOF
# E2E Test Configuration
COMPOSE_PROJECT_NAME=${E2E_PROJECT_NAME}
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=exadb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=e2e_password

# Cluster configuration
WORKER1_PORT=5433
WORKER2_PORT=5434

# Monitoring
PROMETHEUS_PORT=9090

# Test settings
E2E_TIMEOUT=300
E2E_RETRY_COUNT=5
E2E_WAIT_INTERVAL=10
EOF
}

create_e2e_deployment_script() {
    cat > "$TEST_TEMP_DIR/e2e/scripts/e2e-deploy.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

# E2E Deployment Functions
e2e_deploy_full_stack() {
    local timeout="${1:-300}"
    
    echo "Deploying full ExaPG stack for E2E testing..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")/../docker"
    
    # Pull images first
    docker-compose pull
    
    # Start all services
    docker-compose up -d
    
    # Wait for all services to be healthy
    local services=("coordinator" "worker1" "worker2" "monitoring")
    
    for service in "${services[@]}"; do
        echo "Waiting for $service to be healthy..."
        
        local count=0
        while [[ $count -lt $timeout ]]; do
            if [[ "$service" == "monitoring" ]]; then
                # Prometheus doesn't have healthcheck, just check if running
                if docker ps --filter "name=${E2E_PROJECT_NAME}_${service}" --filter "status=running" | grep -q "$service"; then
                    echo "$service is running"
                    break
                fi
            else
                local health=$(docker inspect --format='{{.State.Health.Status}}' "${E2E_PROJECT_NAME}_${service}" 2>/dev/null || echo "unknown")
                if [[ "$health" == "healthy" ]]; then
                    echo "$service is healthy"
                    break
                fi
            fi
            
            sleep 5
            ((count += 5))
        done
        
        if [[ $count -ge $timeout ]]; then
            echo "Timeout waiting for $service to be healthy"
            return 1
        fi
    done
    
    echo "Full stack deployment completed successfully"
    return 0
}

e2e_test_database_operations() {
    echo "Testing database operations..."
    
    # Test coordinator connection
    PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -c "SELECT COUNT(*) FROM analytics.sales;" || return 1
    
    # Test worker1 connection
    PGPASSWORD=e2e_password psql -h localhost -p 5433 -U postgres -d exadb -c "SELECT 1;" || return 1
    
    # Test worker2 connection
    PGPASSWORD=e2e_password psql -h localhost -p 5434 -U postgres -d exadb -c "SELECT 1;" || return 1
    
    # Test complex query
    PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -c "
        SELECT 
            DATE_TRUNC('month', date) as month,
            COUNT(*) as transaction_count,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM analytics.sales 
        WHERE date >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY DATE_TRUNC('month', date)
        ORDER BY month;
    " || return 1
    
    echo "Database operations test completed successfully"
    return 0
}

e2e_test_cluster_connectivity() {
    echo "Testing cluster connectivity..."
    
    # Test network connectivity between services
    docker exec "${E2E_PROJECT_NAME}_coordinator" ping -c 1 worker1 >/dev/null 2>&1 || return 1
    docker exec "${E2E_PROJECT_NAME}_coordinator" ping -c 1 worker2 >/dev/null 2>&1 || return 1
    docker exec "${E2E_PROJECT_NAME}_worker1" ping -c 1 coordinator >/dev/null 2>&1 || return 1
    
    echo "Cluster connectivity test completed successfully"
    return 0
}

e2e_test_monitoring() {
    echo "Testing monitoring stack..."
    
    # Test Prometheus endpoint
    curl -f http://localhost:9090/api/v1/query?query=up >/dev/null 2>&1 || return 1
    
    echo "Monitoring test completed successfully"
    return 0
}

e2e_test_data_consistency() {
    echo "Testing data consistency across cluster..."
    
    # Insert test data on coordinator
    PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -c "
        INSERT INTO analytics.sales (date, amount, customer_id, product_id)
        VALUES (CURRENT_DATE, 999.99, 9999, 9999);
    " || return 1
    
    # Wait a moment for potential replication
    sleep 2
    
    # Verify data exists
    local coordinator_count=$(PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -t -c "
        SELECT COUNT(*) FROM analytics.sales WHERE customer_id = 9999;
    " | xargs)
    
    if [[ "$coordinator_count" != "1" ]]; then
        echo "Data consistency test failed: expected 1 record, got $coordinator_count"
        return 1
    fi
    
    echo "Data consistency test completed successfully"
    return 0
}

e2e_cleanup() {
    echo "Cleaning up E2E environment..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")/../docker"
    
    # Stop and remove all services
    docker-compose down --volumes --remove-orphans
    
    # Remove any remaining containers with E2E labels
    docker ps -a --filter "label=com.exapg.e2e=true" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove networks with E2E labels
    docker network ls --filter "label=com.exapg.e2e=true" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
    
    # Remove volumes with E2E labels
    docker volume ls --filter "label=com.exapg.e2e=true" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
    
    echo "E2E cleanup completed"
}

e2e_run_full_test_suite() {
    echo "Running complete E2E test suite..."
    
    # Deploy full stack
    if ! e2e_deploy_full_stack; then
        echo "E2E deployment failed"
        return 1
    fi
    
    # Run all tests
    local tests=(
        "e2e_test_database_operations"
        "e2e_test_cluster_connectivity"
        "e2e_test_monitoring"
        "e2e_test_data_consistency"
    )
    
    for test in "${tests[@]}"; do
        echo "Running $test..."
        if ! $test; then
            echo "E2E test $test failed"
            return 1
        fi
    done
    
    echo "All E2E tests completed successfully"
    return 0
}
EOF

    chmod +x "$TEST_TEMP_DIR/e2e/scripts/e2e-deploy.sh"
    
    # Source the E2E deployment functions
    source "$TEST_TEMP_DIR/e2e/scripts/e2e-deploy.sh"
}

cleanup_e2e_deployment() {
    echo "Cleaning up E2E deployment..."
    
    cd "$TEST_TEMP_DIR/e2e/docker" 2>/dev/null || return 0
    
    # Use docker-compose to clean up
    docker-compose down --volumes --remove-orphans 2>/dev/null || true
    
    # Remove any containers with our E2E project name
    docker ps -a --filter "name=${E2E_PROJECT_NAME}" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
    
    # Remove networks
    docker network ls --filter "name=${E2E_PROJECT_NAME}" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
    
    # Remove volumes
    docker volume ls --filter "name=${E2E_PROJECT_NAME}" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
}

# ===================================================================
# E2E TEST CASES
# ===================================================================

@test "e2e: full stack deployment" {
    test_log "Starting full stack deployment E2E test"
    
    # Deploy the full stack
    run e2e_deploy_full_stack 180
    assert_success
    assert_output --partial "Full stack deployment completed successfully"
    
    # Verify all containers are running
    run docker ps --filter "name=${E2E_PROJECT_NAME}" --format "{{.Names}}"
    assert_success
    assert_line --partial "coordinator"
    assert_line --partial "worker1"
    assert_line --partial "worker2"
    assert_line --partial "monitoring"
    
    test_log "Full stack deployment E2E test completed"
}

@test "e2e: database operations across cluster" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing database operations across cluster"
    
    # Test database operations
    run e2e_test_database_operations
    assert_success
    assert_output --partial "Database operations test completed successfully"
    
    test_log "Database operations E2E test completed"
}

@test "e2e: cluster network connectivity" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing cluster network connectivity"
    
    # Test network connectivity
    run e2e_test_cluster_connectivity
    assert_success
    assert_output --partial "Cluster connectivity test completed successfully"
    
    test_log "Cluster connectivity E2E test completed"
}

@test "e2e: monitoring stack integration" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing monitoring stack integration"
    
    # Test monitoring
    run e2e_test_monitoring
    assert_success
    assert_output --partial "Monitoring test completed successfully"
    
    test_log "Monitoring integration E2E test completed"
}

@test "e2e: data consistency and persistence" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing data consistency and persistence"
    
    # Test data consistency
    run e2e_test_data_consistency
    assert_success
    assert_output --partial "Data consistency test completed successfully"
    
    test_log "Data consistency E2E test completed"
}

@test "e2e: complete test suite" {
    test_log "Running complete E2E test suite"
    
    # Run the full test suite
    run e2e_run_full_test_suite
    assert_success
    assert_output --partial "All E2E tests completed successfully"
    
    test_log "Complete E2E test suite finished"
}

@test "e2e: recovery and resilience" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing recovery and resilience"
    
    # Stop a worker and verify coordinator still works
    run docker stop "${E2E_PROJECT_NAME}_worker1"
    assert_success
    
    # Test that coordinator is still functional
    run timeout 30 bash -c "PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -c 'SELECT COUNT(*) FROM analytics.sales;'"
    assert_success
    
    # Restart the worker
    run docker start "${E2E_PROJECT_NAME}_worker1"
    assert_success
    
    # Wait for it to be healthy again
    sleep 10
    
    # Test that worker is functional again
    run timeout 30 bash -c "PGPASSWORD=e2e_password psql -h localhost -p 5433 -U postgres -d exadb -c 'SELECT 1;'"
    assert_success
    
    test_log "Recovery and resilience E2E test completed"
}

@test "e2e: performance under load" {
    # Ensure stack is deployed first
    run e2e_deploy_full_stack 120
    assert_success
    
    test_log "Testing performance under load"
    
    # Create a simple load test
    run timeout 60 bash -c '
        for i in {1..100}; do
            PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -c "
                INSERT INTO analytics.sales (date, amount, customer_id, product_id)
                VALUES (CURRENT_DATE, RANDOM() * 1000, RANDOM() * 1000 + 1, RANDOM() * 100 + 1);
            " >/dev/null 2>&1 &
            
            if (( i % 10 == 0 )); then
                wait
            fi
        done
        wait
    '
    assert_success
    
    # Verify data was inserted
    local count=$(PGPASSWORD=e2e_password psql -h localhost -p 5432 -U postgres -d exadb -t -c "SELECT COUNT(*) FROM analytics.sales;" | xargs)
    
    # Should have at least 1000 + 100 = 1100 records
    if [[ $count -lt 1100 ]]; then
        fail "Expected at least 1100 records, got $count"
    fi
    
    test_log "Performance under load E2E test completed"
}

@test "e2e: cleanup and resource management" {
    test_log "Testing cleanup and resource management"
    
    # Run cleanup
    run e2e_cleanup
    assert_success
    assert_output --partial "E2E cleanup completed"
    
    # Verify no containers are running
    run docker ps --filter "name=${E2E_PROJECT_NAME}" --format "{{.Names}}"
    assert_success
    refute_output --partial "coordinator"
    refute_output --partial "worker"
    refute_output --partial "monitoring"
    
    # Verify no networks remain
    run docker network ls --filter "name=${E2E_PROJECT_NAME}" --format "{{.Name}}"
    assert_success
    refute_output --partial "${E2E_PROJECT_NAME}"
    
    test_log "Cleanup and resource management E2E test completed"
} 