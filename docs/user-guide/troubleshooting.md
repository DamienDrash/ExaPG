# ExaPG Troubleshooting Guide

This guide helps you diagnose and resolve common issues with ExaPG.

## Table of Contents

- [Quick Diagnosis](#quick-diagnosis)
- [Installation Issues](#installation-issues)
- [Connection Problems](#connection-problems)
- [Performance Issues](#performance-issues)
- [Memory Issues](#memory-issues)
- [Cluster Problems](#cluster-problems)
- [SSL/TLS Problems](#ssltls-problems)
- [Extension Issues](#extension-issues)
- [Data Issues](#data-issues)
- [Monitoring Problems](#monitoring-problems)
- [Common Error Messages](#common-error-messages)
- [Advanced Debugging Tools](#advanced-debugging-tools)
- [Performance Profiling](#performance-profiling)
- [Network Debugging](#network-debugging)
- [Log Analysis](#log-analysis)
- [Getting Help](#getting-help)

## Quick Diagnosis

### System Health Check

Run this comprehensive health check first:

```bash
# Check if Docker is running
docker info > /dev/null 2>&1 && echo "✓ Docker is running" || echo "✗ Docker is not running"

# Check ExaPG containers
docker-compose ps

# Check database connectivity
docker exec -it exapg-coordinator psql -U postgres -c "SELECT version();" 2>/dev/null && echo "✓ Database is accessible" || echo "✗ Database connection failed"

# Check disk space
df -h | grep -E "/$|/var/lib/docker"

# Check memory usage
free -h

# Check ports
netstat -tulpn | grep -E "5432|8080|3000|9090" 2>/dev/null || ss -tulpn | grep -E "5432|8080|3000|9090"
```

### Quick Fix Script

```bash
#!/bin/bash
# Save as fix-common-issues.sh

echo "Running ExaPG Quick Fix..."

# Fix permission issues
sudo chown -R $(whoami):docker /var/run/docker.sock 2>/dev/null

# Clean up stopped containers
docker container prune -f

# Remove unused volumes
docker volume prune -f

# Restart Docker
sudo systemctl restart docker

echo "Quick fix completed. Try starting ExaPG again."
```

## Installation Issues

### Docker Installation Failed

**Problem**: Docker installation script fails

**Solutions**:

1. **Update system packages**:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   # or
   sudo yum update -y
   ```

2. **Manual Docker installation**:
   ```bash
   # Remove old versions
   sudo apt-get remove docker docker-engine docker.io containerd runc
   
   # Install from official repository
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

3. **Add user to docker group**:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

### Docker Compose Not Found

**Problem**: `docker-compose: command not found`

**Solution**:
```bash
# Install Docker Compose standalone
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Or use Docker Compose plugin
docker compose version  # Note: no hyphen
```

### Permission Denied Errors

**Problem**: `permission denied while trying to connect to the Docker daemon socket`

**Solution**:
```bash
# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group (recommended)
sudo usermod -aG docker $USER
# Log out and back in or run:
newgrp docker
```

## Connection Problems

### Cannot Connect to Database

**Problem**: `psql: could not connect to server`

**Diagnostic steps**:

1. **Check if container is running**:
   ```bash
   docker ps | grep exapg-coordinator
   ```

2. **Check container logs**:
   ```bash
   docker logs exapg-coordinator --tail 50
   ```

3. **Verify port binding**:
   ```bash
   docker port exapg-coordinator
   ```

**Common solutions**:

1. **Port conflict**:
   ```bash
   # Check if port 5432 is in use
   sudo lsof -i :5432
   
   # Change port in .env
   POSTGRES_PORT=5433
   ```

2. **Firewall blocking**:
   ```bash
   # Allow PostgreSQL port
   sudo ufw allow 5432/tcp
   # or
   sudo firewall-cmd --permanent --add-port=5432/tcp
   sudo firewall-cmd --reload
   ```

3. **Container networking issue**:
   ```bash
   # Restart with network cleanup
   docker-compose down
   docker network prune -f
   docker-compose up -d
   ```

### Connection Timeout

**Problem**: Connection attempts timeout

**Solutions**:

1. **Increase connection timeout**:
   ```bash
   # In connection string
   psql "postgresql://postgres:password@localhost:5432/exadb?connect_timeout=30"
   ```

2. **Check Docker network**:
   ```bash
   # Inspect network
   docker network inspect exapg_default
   
   # Recreate network
   docker-compose down
   docker network rm exapg_default
   docker-compose up -d
   ```

### Authentication Failed

**Problem**: `FATAL: password authentication failed`

**Solutions**:

1. **Check credentials**:
   ```bash
   # View current password in .env
   grep POSTGRES_PASSWORD .env
   ```

2. **Reset password**:
   ```bash
   # Connect as superuser
   docker exec -it exapg-coordinator psql -U postgres
   
   # Change password
   ALTER USER postgres PASSWORD 'new_password';
   ```

3. **Fix pg_hba.conf**:
   ```bash
   # Edit authentication config
   docker exec -it exapg-coordinator bash
   echo "local all all trust" >> /var/lib/postgresql/data/pg_hba.conf
   pg_ctl reload
   ```

## Performance Issues

### Slow Queries

**Problem**: Queries running slowly

**Diagnostic queries**:

```sql
-- Check currently running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Find slow queries
SELECT query, calls, total_time, mean, stddev_time, rows
FROM pg_stat_statements
ORDER BY mean DESC
LIMIT 10;

-- Check table statistics
SELECT schemaname, tablename, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

**Solutions**:

1. **Run ANALYZE**:
   ```sql
   ANALYZE;  -- Update all statistics
   VACUUM ANALYZE;  -- Clean and analyze
   ```

2. **Check indexes**:
   ```sql
   -- Find missing indexes
   SELECT schemaname, tablename, attname, n_distinct, correlation
   FROM pg_stats
   WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
   AND n_distinct > 100
   AND correlation < 0.1
   ORDER BY n_distinct DESC;
   ```

3. **Tune memory settings**:
   ```bash
   # Edit .env
   SHARED_BUFFERS=4GB
   WORK_MEM=256MB
   EFFECTIVE_CACHE_SIZE=12GB
   
   # Restart
   docker-compose restart coordinator
   ```

### High Memory Usage

**Problem**: Excessive memory consumption

**Diagnostics**:
```bash
# Check container memory usage
docker stats --no-stream

# Check PostgreSQL memory
docker exec -it exapg-coordinator psql -U postgres -c "SHOW shared_buffers;"
docker exec -it exapg-coordinator psql -U postgres -c "SHOW work_mem;"
```

**Solutions**:

1. **Limit container memory**:
   ```yaml
   # In docker-compose.yml
   services:
     coordinator:
       mem_limit: 8g
       memswap_limit: 8g
   ```

2. **Adjust PostgreSQL settings**:
   ```sql
   -- Reduce work_mem for specific session
   SET work_mem = '64MB';
   
   -- Or globally in postgresql.conf
   ALTER SYSTEM SET work_mem = '64MB';
   SELECT pg_reload_conf();
   ```

### Disk Space Issues

**Problem**: `No space left on device`

**Diagnostics**:
```bash
# Check disk usage
df -h
du -sh /var/lib/docker/*

# Find large files
find /var/lib/docker -type f -size +1G -exec ls -lh {} \;
```

**Solutions**:

1. **Clean Docker resources**:
   ```bash
   # Remove unused images
   docker image prune -a -f
   
   # Clean build cache
   docker builder prune -f
   
   # Remove logs
   find /var/lib/docker/containers -name "*.log" -exec truncate -s 0 {} \;
   ```

2. **Move Docker data directory**:
   ```bash
   # Stop Docker
   sudo systemctl stop docker
   
   # Move data
   sudo mv /var/lib/docker /new/path/docker
   
   # Create symlink
   sudo ln -s /new/path/docker /var/lib/docker
   
   # Start Docker
   sudo systemctl start docker
   ```

## Memory Issues

### High Memory Usage

**Problem**: Excessive memory consumption

**Diagnostics**:
```bash
# Check container memory usage
docker stats --no-stream

# Check PostgreSQL memory
docker exec -it exapg-coordinator psql -U postgres -c "SHOW shared_buffers;"
docker exec -it exapg-coordinator psql -U postgres -c "SHOW work_mem;"
```

**Solutions**:

1. **Limit container memory**:
   ```yaml
   # In docker-compose.yml
   services:
     coordinator:
       mem_limit: 8g
       memswap_limit: 8g
   ```

2. **Adjust PostgreSQL settings**:
   ```sql
   -- Reduce work_mem for specific session
   SET work_mem = '64MB';
   
   -- Or globally in postgresql.conf
   ALTER SYSTEM SET work_mem = '64MB';
   SELECT pg_reload_conf();
   ```

## Cluster Problems

### Worker Node Not Connecting

**Problem**: Worker nodes fail to join cluster

**Diagnostics**:
```sql
-- Check node status
SELECT * FROM pg_dist_node;

-- Check replication status
SELECT * FROM pg_stat_replication;
```

**Solutions**:

1. **Verify network connectivity**:
   ```bash
   # From worker, ping coordinator
   docker exec -it exapg-worker1 ping coordinator
   
   # Check DNS resolution
   docker exec -it exapg-worker1 nslookup coordinator
   ```

2. **Re-add worker node**:
   ```sql
   -- Remove and re-add worker
   SELECT citus_remove_node('worker1', 5432);
   SELECT citus_add_node('worker1', 5432);
   ```

### Data Distribution Issues

**Problem**: Uneven data distribution across nodes

**Diagnostics**:
```sql
-- Check shard distribution
SELECT nodename, count(*) 
FROM pg_dist_shard_placement 
GROUP BY nodename;

-- Check table distribution
SELECT logicalrelid, colocationid, partmethod, partkey 
FROM pg_dist_partition;
```

**Solutions**:

1. **Rebalance shards**:
   ```sql
   SELECT rebalance_table_shards();
   ```

2. **Recreate distribution**:
   ```sql
   -- Undistribute and redistribute
   SELECT undistribute_table('tablename');
   SELECT create_distributed_table('tablename', 'distribution_column');
   ```

## SSL/TLS Problems

### SSL Certificate Issues

**Problem**: `SSL certificate verification failed` or `SSL connection not available`

**Diagnostic Steps**:

1. **Check SSL configuration**:
   ```bash
   # Check if SSL is enabled
   docker exec -it exapg-coordinator psql -U postgres -c "SHOW ssl;"
   
   # Check SSL certificate files
   docker exec -it exapg-coordinator ls -la /etc/ssl/certs/
   docker exec -it exapg-coordinator ls -la /etc/ssl/private/
   ```

2. **Verify certificate validity**:
   ```bash
   # Check certificate expiration
   docker exec -it exapg-coordinator openssl x509 -in /etc/ssl/certs/server.crt -noout -dates
   
   # Verify certificate chain
   docker exec -it exapg-coordinator openssl verify -CAfile /etc/ssl/certs/ca.crt /etc/ssl/certs/server.crt
   ```

**Solutions**:

1. **Generate new SSL certificates**:
   ```bash
   # Create SSL certificate directory
   mkdir -p config/ssl
   
   # Generate private key
   openssl genrsa -out config/ssl/server.key 2048
   
   # Generate certificate
   openssl req -new -x509 -key config/ssl/server.key -out config/ssl/server.crt -days 365 \
     -subj "/C=US/ST=State/L=City/O=Organization/CN=exapg-coordinator"
   
   # Set proper permissions
   chmod 600 config/ssl/server.key
   chmod 644 config/ssl/server.crt
   ```

2. **Update Docker Compose SSL configuration**:
   ```yaml
   # In docker-compose.yml
   coordinator:
     volumes:
       - ./config/ssl:/etc/ssl/certs:ro
       - ./config/ssl:/etc/ssl/private:ro
     environment:
       - POSTGRES_SSL=on
       - POSTGRES_SSL_CERT_FILE=/etc/ssl/certs/server.crt
       - POSTGRES_SSL_KEY_FILE=/etc/ssl/private/server.key
   ```

3. **Fix certificate permissions**:
   ```bash
   # Fix ownership (PostgreSQL runs as user postgres, UID 999)
   docker exec -it exapg-coordinator chown postgres:postgres /etc/ssl/private/server.key
   docker exec -it exapg-coordinator chmod 600 /etc/ssl/private/server.key
   ```

### SSL Connection Refused

**Problem**: `SSL connection refused` or `SSL not supported`

**Solutions**:

1. **Enable SSL in postgresql.conf**:
   ```sql
   -- Connect to database and enable SSL
   ALTER SYSTEM SET ssl = 'on';
   ALTER SYSTEM SET ssl_cert_file = '/etc/ssl/certs/server.crt';
   ALTER SYSTEM SET ssl_key_file = '/etc/ssl/private/server.key';
   SELECT pg_reload_conf();
   ```

2. **Update pg_hba.conf for SSL**:
   ```bash
   # Edit pg_hba.conf to require SSL
   docker exec -it exapg-coordinator bash -c "
   echo 'hostssl all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf
   echo 'host all all 0.0.0.0/0 reject' >> /var/lib/postgresql/data/pg_hba.conf
   "
   
   # Reload configuration
   docker exec -it exapg-coordinator psql -U postgres -c "SELECT pg_reload_conf();"
   ```

3. **Test SSL connection**:
   ```bash
   # Test SSL connection with psql
   docker exec -it exapg-coordinator psql "sslmode=require host=localhost dbname=exadb user=postgres"
   
   # Test with openssl
   docker exec -it exapg-coordinator openssl s_client -connect localhost:5432 -starttls postgres
   ```

### SSL Certificate Verification Failed

**Problem**: `SSL certificate verification failed` or `certificate verify failed`

**Solutions**:

1. **Use self-signed certificate with proper configuration**:
   ```bash
   # Connect with SSL but skip verification
   psql "sslmode=require sslcert=client.crt sslkey=client.key sslrootcert=ca.crt host=localhost dbname=exadb user=postgres"
   ```

2. **Configure client certificate authentication**:
   ```bash
   # Generate client certificate
   openssl genrsa -out config/ssl/client.key 2048
   openssl req -new -key config/ssl/client.key -out config/ssl/client.csr \
     -subj "/C=US/ST=State/L=City/O=Organization/CN=postgres"
   openssl x509 -req -in config/ssl/client.csr -CA config/ssl/ca.crt -CAkey config/ssl/ca.key \
     -out config/ssl/client.crt -days 365 -CAcreateserial
   ```

3. **Update pg_hba.conf for certificate authentication**:
   ```bash
   # Add certificate authentication
   docker exec -it exapg-coordinator bash -c "
   echo 'hostssl all postgres 0.0.0.0/0 cert' >> /var/lib/postgresql/data/pg_hba.conf
   "
   ```

## Extension Issues

### Extension Not Found

**Problem**: `ERROR: extension "extension_name" does not exist`

**Solutions**:

1. **Check available extensions**:
   ```sql
   SELECT * FROM pg_available_extensions WHERE name LIKE '%extension%';
   ```

2. **Install missing extension**:
   ```bash
   # For Citus
   docker exec -it exapg-coordinator apt-get update
   docker exec -it exapg-coordinator apt-get install postgresql-15-citus-11.2
   
   # Restart container
   docker-compose restart coordinator
   ```

3. **Load extension in database**:
   ```sql
   CREATE EXTENSION IF NOT EXISTS citus;
   CREATE EXTENSION IF NOT EXISTS timescaledb;
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

### Extension Version Conflicts

**Problem**: `ERROR: extension "x" has no update path`

**Solution**:
```sql
-- Check current version
SELECT * FROM pg_extension WHERE extname = 'extension_name';

-- Drop and recreate
DROP EXTENSION extension_name CASCADE;
CREATE EXTENSION extension_name;
```

## Data Issues

### Data Corruption

**Problem**: `ERROR: invalid page in block`

**Emergency recovery**:

1. **Set zero_damaged_pages temporarily**:
   ```sql
   SET zero_damaged_pages = on;
   VACUUM FULL damaged_table;
   SET zero_damaged_pages = off;
   ```

2. **Restore from backup**:
   ```bash
   # Stop database
   docker-compose stop coordinator
   
   # Restore
   docker run --rm -v exapg_pgdata:/data -v $(pwd)/backup:/backup alpine tar xzf /backup/pgdata-backup.tar.gz -C /data
   
   # Start database
   docker-compose start coordinator
   ```

### Transaction ID Wraparound

**Problem**: `WARNING: database "x" must be vacuumed within X transactions`

**Solution**:
```sql
-- Emergency vacuum
SET vacuum_freeze_table_age = 0;
VACUUM FREEZE;

-- Check progress
SELECT datname, age(datfrozenxid) FROM pg_database;
```

## Monitoring Problems

### Grafana Not Accessible

**Problem**: Cannot access Grafana dashboard

**Solutions**:

1. **Check container status**:
   ```bash
   docker ps | grep grafana
   docker logs exapg-grafana
   ```

2. **Reset admin password**:
   ```bash
   docker exec -it exapg-grafana grafana-cli admin reset-admin-password newpassword
   ```

3. **Fix permissions**:
   ```bash
   docker exec -it exapg-grafana chown -R grafana:grafana /var/lib/grafana
   ```

### Missing Metrics

**Problem**: Prometheus not collecting metrics

**Solutions**:

1. **Check exporters**:
   ```bash
   # Verify postgres_exporter
   curl http://localhost:9187/metrics
   ```

2. **Fix Prometheus config**:
   ```yaml
   # prometheus.yml
   scrape_configs:
     - job_name: 'postgres'
       static_configs:
         - targets: ['postgres_exporter:9187']
   ```

## Common Error Messages

### "could not resize shared memory segment"

**Solution**:
```bash
# Increase shared memory
echo "kernel.shmmax = 134217728" | sudo tee -a /etc/sysctl.conf
echo "kernel.shmall = 2097152" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### "too many connections"

**Solution**:
```sql
-- Check current connections
SELECT count(*) FROM pg_stat_activity;

-- Increase max connections
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

### "out of shared memory"

**Solution**:
```sql
-- Increase max_locks_per_transaction
ALTER SYSTEM SET max_locks_per_transaction = 128;
SELECT pg_reload_conf();
```

## Advanced Debugging Tools

### Container-Level Debugging

**System Information Collection**:
```bash
# Comprehensive system diagnostics
./scripts/collect-system-info.sh() {
  echo "=== ExaPG System Diagnostics ==="
  
  # Docker environment
  echo "--- Docker Information ---"
  docker version
  docker info | grep -E "(Server Version|Storage Driver|Logging Driver|Cgroup Driver)"
  
  # Container status
  echo "--- Container Status ---"
  docker-compose ps -a
  
  # Resource usage
  echo "--- Resource Usage ---"
  docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
  
  # Network information
  echo "--- Network Information ---"
  docker network ls
  docker network inspect exapg_default | jq '.[0].IPAM'
  
  # Volume information
  echo "--- Volume Information ---"
  docker volume ls | grep exapg
  docker system df
}
```

**Process Analysis**:
```bash
# PostgreSQL process analysis
analyze_postgres_processes() {
  # Get process information
  docker exec -it exapg-coordinator bash -c "
    echo '=== PostgreSQL Processes ==='
    ps aux | grep postgres
    
    echo '=== Active Connections ==='
    psql -U postgres -d exadb -c \"
      SELECT pid, usename, application_name, client_addr, state, 
             query_start, state_change, query 
      FROM pg_stat_activity 
      WHERE state != 'idle' 
      ORDER BY query_start;
    \"
    
    echo '=== Lock Information ==='
    psql -U postgres -d exadb -c \"
      SELECT l.locktype, l.database, l.relation, l.page, l.tuple, l.virtualxid,
             l.transactionid, l.mode, l.granted, a.query
      FROM pg_locks l
      LEFT JOIN pg_stat_activity a ON l.pid = a.pid
      WHERE NOT l.granted
      ORDER BY l.pid;
    \"
  "
}
```

**Configuration Dump**:
```bash
# Complete configuration analysis
dump_configuration() {
  docker exec -it exapg-coordinator bash -c "
    echo '=== PostgreSQL Configuration ==='
    psql -U postgres -d exadb -c \"
      SELECT name, setting, unit, context, boot_val, reset_val
      FROM pg_settings
      WHERE name IN (
        'shared_buffers', 'work_mem', 'maintenance_work_mem',
        'effective_cache_size', 'max_connections', 'wal_buffers',
        'checkpoint_completion_target', 'random_page_cost'
      )
      ORDER BY name;
    \"
    
    echo '=== Extension Information ==='
    psql -U postgres -d exadb -c \"
      SELECT extname, extversion, extrelocatable
      FROM pg_extension
      ORDER BY extname;
    \"
  "
}
```

### Database-Level Debugging

**Query Analysis Tools**:
```bash
# Advanced query analysis
analyze_query_performance() {
  docker exec -it exapg-coordinator psql -U postgres -d exadb << 'EOF'
-- Enable detailed query analysis
SET log_statement = 'all';
SET log_duration = on;
SET log_lock_waits = on;
SET log_min_duration_statement = 100;

-- Check for long-running queries
SELECT 
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query,
  state,
  wait_event_type,
  wait_event
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '30 seconds'
AND state != 'idle'
ORDER BY duration DESC;

-- Analyze table statistics
SELECT 
  schemaname,
  tablename,
  n_live_tup,
  n_dead_tup,
  n_tup_ins,
  n_tup_upd,
  n_tup_del,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_tup_read,
  idx_tup_fetch,
  idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY schemaname, tablename;
EOF
}
```

**Index Analysis**:
```bash
# Index optimization analysis
analyze_indexes() {
  docker exec -it exapg-coordinator psql -U postgres -d exadb << 'EOF'
-- Find unused indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan < 50
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find duplicate indexes
SELECT 
  pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
  (array_agg(idx))[1] AS idx1, 
  (array_agg(idx))[2] AS idx2
FROM (
  SELECT 
    indexrelid::regclass AS idx, 
    (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
     COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
  FROM pg_index
) sub
GROUP BY KEY 
HAVING COUNT(*) > 1
ORDER BY SUM(pg_relation_size(idx)) DESC;

-- Analyze table bloat
SELECT 
  tablename,
  pg_size_pretty(pg_total_relation_size(tablename::regclass)) as size,
  pg_size_pretty(pg_relation_size(tablename::regclass)) as table_size,
  pg_size_pretty(pg_total_relation_size(tablename::regclass) - pg_relation_size(tablename::regclass)) as index_size
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(tablename::regclass) DESC;
EOF
}
```

## Performance Profiling

### Query Performance Profiling

**Detailed EXPLAIN Analysis**:
```bash
# Query profiling with detailed analysis
profile_query() {
  local query="$1"
  
  docker exec -it exapg-coordinator psql -U postgres -d exadb << EOF
-- Enable timing and analyze
\timing on

-- Detailed execution plan
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON) $query;

-- Show query planning time
SET track_planning = on;
EXPLAIN ANALYZE $query;

-- Check if parallel execution is possible
SET max_parallel_workers_per_gather = 4;
EXPLAIN (ANALYZE, BUFFERS) $query;
EOF
}
```

**Benchmark Testing**:
```bash
# Performance benchmarking
run_benchmarks() {
  echo "=== Running ExaPG Performance Benchmarks ==="
  
  # Initialize pgbench
  docker exec -it exapg-coordinator bash -c "
    # Install pgbench if not available
    apt-get update && apt-get install -y postgresql-contrib
    
    # Initialize benchmark database
    pgbench -i -s 10 -U postgres exadb
    
    # Run read-only benchmark
    echo 'Running read-only benchmark...'
    pgbench -S -c 10 -j 2 -T 60 -U postgres exadb
    
    # Run read-write benchmark
    echo 'Running read-write benchmark...'
    pgbench -c 10 -j 2 -T 60 -U postgres exadb
    
    # Custom analytical workload
    echo 'Running analytical workload...'
    pgbench -f <(cat << 'BENCH_EOF'
SELECT 
  AVG(abalance) as avg_balance,
  COUNT(*) as account_count,
  SUM(abalance) as total_balance
FROM pgbench_accounts
WHERE abalance > 1000
GROUP BY bid
ORDER BY avg_balance DESC
LIMIT 10;
BENCH_EOF
    ) -c 5 -j 1 -T 30 -U postgres exadb
  "
}
```

**Connection Pool Analysis**:
```bash
# Analyze connection pooling performance
analyze_connections() {
  docker exec -it exapg-coordinator psql -U postgres -d exadb << 'EOF'
-- Connection statistics
SELECT 
  state,
  COUNT(*) as connection_count,
  AVG(EXTRACT(EPOCH FROM (now() - state_change))) as avg_duration_seconds
FROM pg_stat_activity
GROUP BY state
ORDER BY connection_count DESC;

-- Check for connection limits
SELECT 
  setting as max_connections,
  (SELECT COUNT(*) FROM pg_stat_activity) as current_connections,
  ROUND(((SELECT COUNT(*) FROM pg_stat_activity)::float / setting::float) * 100, 2) as usage_percent
FROM pg_settings 
WHERE name = 'max_connections';

-- Wait events analysis
SELECT 
  wait_event_type,
  wait_event,
  COUNT(*) as wait_count
FROM pg_stat_activity
WHERE wait_event IS NOT NULL
GROUP BY wait_event_type, wait_event
ORDER BY wait_count DESC;
EOF
}
```

### Resource Profiling

**Memory Usage Analysis**:
```bash
# Comprehensive memory analysis
analyze_memory_usage() {
  echo "=== Memory Usage Analysis ==="
  
  # System memory
  echo "--- System Memory ---"
  free -h
  
  # Container memory
  echo "--- Container Memory ---"
  docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}"
  
  # PostgreSQL memory usage
  echo "--- PostgreSQL Memory Configuration ---"
  docker exec -it exapg-coordinator psql -U postgres -d exadb -c "
    SELECT 
      name,
      setting,
      unit,
      CASE 
        WHEN unit = '8kB' THEN pg_size_pretty((setting::bigint) * 8192)
        WHEN unit = 'kB' THEN pg_size_pretty((setting::bigint) * 1024)
        WHEN unit = 'MB' THEN pg_size_pretty((setting::bigint) * 1024 * 1024)
        ELSE setting || COALESCE(unit, '')
      END as formatted_value
    FROM pg_settings
    WHERE name IN (
      'shared_buffers', 'work_mem', 'maintenance_work_mem',
      'effective_cache_size', 'wal_buffers', 'temp_buffers'
    )
    ORDER BY name;
  "
  
  # Check for memory-intensive queries
  echo "--- Memory-Intensive Queries ---"
  docker exec -it exapg-coordinator psql -U postgres -d exadb -c "
    SELECT 
      query,
      calls,
      total_time,
      mean_time,
      temp_blks_read,
      temp_blks_written,
      local_blks_read,
      local_blks_written
    FROM pg_stat_statements
    WHERE temp_blks_read > 0 OR temp_blks_written > 0
    ORDER BY temp_blks_written DESC
    LIMIT 10;
  "
}
```

**I/O Performance Analysis**:
```bash
# I/O performance analysis
analyze_io_performance() {
  echo "=== I/O Performance Analysis ==="
  
  # System I/O statistics
  echo "--- System I/O Statistics ---"
  iostat -x 1 3 2>/dev/null || echo "iostat not available"
  
  # PostgreSQL I/O statistics
  echo "--- PostgreSQL I/O Statistics ---"
  docker exec -it exapg-coordinator psql -U postgres -d exadb -c "
    SELECT 
      tablename,
      heap_blks_read,
      heap_blks_hit,
      CASE 
        WHEN heap_blks_read + heap_blks_hit > 0 
        THEN ROUND((heap_blks_hit::float / (heap_blks_read + heap_blks_hit)) * 100, 2)
        ELSE 0
      END as cache_hit_ratio,
      idx_blks_read,
      idx_blks_hit,
      CASE 
        WHEN idx_blks_read + idx_blks_hit > 0
        THEN ROUND((idx_blks_hit::float / (idx_blks_read + idx_blks_hit)) * 100, 2)
        ELSE 0
      END as idx_cache_hit_ratio
    FROM pg_statio_user_tables
    WHERE heap_blks_read + heap_blks_hit > 0
    ORDER BY heap_blks_read + heap_blks_hit DESC
    LIMIT 20;
  "
  
  # WAL statistics
  echo "--- WAL Statistics ---"
  docker exec -it exapg-coordinator psql -U postgres -d exadb -c "
    SELECT 
      pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as wal_written,
      pg_size_pretty(pg_stat_file('pg_wal/').size) as current_wal_size;
  "
}
```

## Network Debugging

### Network Connectivity Testing

**Container Network Analysis**:
```bash
# Comprehensive network analysis
analyze_network() {
  echo "=== Network Connectivity Analysis ==="
  
  # Docker network information
  echo "--- Docker Network Configuration ---"
  docker network ls
  docker network inspect exapg_default | jq '.[0].IPAM.Config'
  
  # Container IP addresses
  echo "--- Container IP Addresses ---"
  for container in coordinator worker1 worker2; do
    if docker ps | grep -q "exapg-$container"; then
      ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "exapg-$container")
      echo "$container: $ip"
    fi
  done
  
  # Port bindings
  echo "--- Port Bindings ---"
  docker-compose ps --format "table {{.Name}}\t{{.Ports}}"
  
  # Test connectivity between containers
  echo "--- Inter-Container Connectivity ---"
  if docker ps | grep -q "exapg-coordinator"; then
    docker exec exapg-coordinator bash -c "
      for target in worker1 worker2; do
        if nslookup \$target >/dev/null 2>&1; then
          ping -c 2 \$target >/dev/null 2>&1 && echo \"\$target: ✓ reachable\" || echo \"\$target: ✗ unreachable\"
        else
          echo \"\$target: ✗ DNS resolution failed\"
        fi
      done
    "
  fi
}
```

**Network Performance Testing**:
```bash
# Network performance benchmarks
test_network_performance() {
  echo "=== Network Performance Testing ==="
  
  # Latency testing
  echo "--- Latency Testing ---"
  docker exec exapg-coordinator bash -c "
    for target in worker1 worker2; do
      if nslookup \$target >/dev/null 2>&1; then
        echo \"Testing latency to \$target:\"
        ping -c 10 \$target | tail -1
      fi
    done
  "
  
  # Bandwidth testing (if iperf3 is available)
  echo "--- Bandwidth Testing ---"
  docker exec exapg-coordinator bash -c "
    if command -v iperf3 >/dev/null; then
      # Start iperf3 server on worker1 if available
      timeout 30 iperf3 -s &
      sleep 2
      # Test bandwidth from coordinator to worker1
      timeout 10 iperf3 -c worker1 -t 5 2>/dev/null || echo 'iperf3 test failed'
    else
      echo 'iperf3 not available for bandwidth testing'
    fi
  "
  
  # PostgreSQL connection testing
  echo "--- PostgreSQL Connection Testing ---"
  docker exec exapg-coordinator bash -c "
    for target in worker1 worker2; do
      echo \"Testing PostgreSQL connection to \$target:\"
      timeout 5 psql -h \$target -U postgres -d exadb -c 'SELECT 1;' >/dev/null 2>&1 && 
        echo \"\$target: ✓ PostgreSQL connection successful\" || 
        echo \"\$target: ✗ PostgreSQL connection failed\"
    done
  "
}
```

**Firewall and Security Analysis**:
```bash
# Security and firewall analysis
analyze_security() {
  echo "=== Security Analysis ==="
  
  # Check open ports
  echo "--- Open Ports ---"
  netstat -tulpn | grep -E ":(5432|8080|3000|9090|9187)" || ss -tulpn | grep -E ":(5432|8080|3000|9090|9187)"
  
  # UFW status (if available)
  echo "--- Firewall Status ---"
  if command -v ufw >/dev/null; then
    sudo ufw status verbose
  elif command -v firewall-cmd >/dev/null; then
    sudo firewall-cmd --list-all
  else
    echo "No firewall management tool detected"
  fi
  
  # SSL/TLS configuration
  echo "--- SSL/TLS Configuration ---"
  docker exec exapg-coordinator psql -U postgres -d exadb -c "
    SELECT name, setting 
    FROM pg_settings 
    WHERE name LIKE 'ssl%' OR name = 'password_encryption'
    ORDER BY name;
  "
  
  # Check pg_hba.conf security
  echo "--- pg_hba.conf Security Analysis ---"
  docker exec exapg-coordinator bash -c "
    echo 'Checking for insecure authentication methods:'
    grep -n 'trust' /var/lib/postgresql/data/pg_hba.conf | head -5
    echo 'Checking for wide-open access:'
    grep -n '0.0.0.0/0' /var/lib/postgresql/data/pg_hba.conf | head -5
  "
}
```

## Log Analysis

### Centralized Log Collection

**Log Aggregation Script**:
```bash
# Comprehensive log collection
collect_logs() {
  local output_dir="exapg-logs-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$output_dir"
  
  echo "=== Collecting ExaPG Logs ==="
  echo "Output directory: $output_dir"
  
  # Container logs
  echo "--- Collecting Container Logs ---"
  for service in coordinator worker1 worker2 prometheus grafana; do
    if docker ps | grep -q "exapg-$service"; then
      echo "Collecting logs for $service..."
      docker logs exapg-$service --timestamps > "$output_dir/$service.log" 2>&1
    fi
  done
  
  # PostgreSQL logs from inside containers
  echo "--- Collecting PostgreSQL Internal Logs ---"
  docker exec exapg-coordinator bash -c "
    if [ -d /var/log/postgresql ]; then
      tar czf /tmp/postgresql-logs.tar.gz /var/log/postgresql/
    fi
  " 2>/dev/null
  
  if docker exec exapg-coordinator test -f /tmp/postgresql-logs.tar.gz; then
    docker cp exapg-coordinator:/tmp/postgresql-logs.tar.gz "$output_dir/"
  fi
  
  # System logs
  echo "--- Collecting System Logs ---"
  if command -v journalctl >/dev/null; then
    journalctl -u docker --since "1 hour ago" > "$output_dir/docker-system.log" 2>/dev/null
  fi
  
  # Configuration files
  echo "--- Collecting Configuration Files ---"
  if [ -f .env ]; then
    # Sanitize passwords before copying
    sed 's/PASSWORD=.*/PASSWORD=***REDACTED***/g' .env > "$output_dir/env-sanitized.txt"
  fi
  
  if [ -f docker-compose.yml ]; then
    cp docker-compose.yml "$output_dir/"
  fi
  
  echo "--- Log Collection Summary ---"
  ls -lh "$output_dir/"
  echo "Logs collected in: $output_dir"
}
```

**Log Analysis Tools**:
```bash
# Log analysis and pattern detection
analyze_logs() {
  local log_dir="${1:-./exapg-logs-*}"
  
  echo "=== Log Analysis Report ==="
  
  # Error pattern analysis
  echo "--- Error Patterns ---"
  for log_file in $log_dir/*.log; do
    if [ -f "$log_file" ]; then
      echo "Analyzing $(basename $log_file):"
      grep -i "error\|fatal\|panic\|fail" "$log_file" | tail -10
      echo ""
    fi
  done
  
  # Connection analysis
  echo "--- Connection Patterns ---"
  grep -h "connection" $log_dir/*.log | \
    grep -v "connection authorized" | \
    sort | uniq -c | sort -nr | head -10
  
  # Performance warnings
  echo "--- Performance Warnings ---"
  grep -h "slow\|performance\|timeout\|deadlock" $log_dir/*.log | \
    tail -20
  
  # Security events
  echo "--- Security Events ---"
  grep -h "authentication\|authorization\|ssl\|certificate" $log_dir/*.log | \
    tail -10
}
```

**Real-time Log Monitoring**:
```bash
# Real-time log monitoring
monitor_logs_realtime() {
  echo "=== Real-time Log Monitoring ==="
  echo "Press Ctrl+C to stop monitoring"
  
  # Monitor all container logs simultaneously
  docker-compose logs -f --tail=10 &
  COMPOSE_PID=$!
  
  # Monitor specific error patterns
  {
    while true; do
      docker logs exapg-coordinator --tail=5 2>&1 | \
        grep -i "error\|warning\|fatal" | \
        while read line; do
          echo "[$(date '+%H:%M:%S')] ALERT: $line"
        done
      sleep 5
    done
  } &
  MONITOR_PID=$!
  
  # Cleanup on exit
  trap "kill $COMPOSE_PID $MONITOR_PID 2>/dev/null" EXIT
  wait
}
```

### Performance Log Analysis

**Query Performance Monitoring**:
```bash
# Query performance log analysis
analyze_query_logs() {
  echo "=== Query Performance Analysis ==="
  
  # Enable query logging for analysis
  docker exec exapg-coordinator psql -U postgres -d exadb << 'EOF'
-- Configure logging for performance analysis
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log queries > 1s
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_lock_waits = on;
ALTER SYSTEM SET log_temp_files = 10240;  -- Log temp files > 10MB
SELECT pg_reload_conf();

-- Show current query performance
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  stddev_time,
  max_time,
  min_time
FROM pg_stat_statements
WHERE calls > 5
ORDER BY total_time DESC
LIMIT 20;
EOF

  # Analyze recent slow queries from logs
  echo "--- Recent Slow Queries ---"
  docker logs exapg-coordinator --since="1h" 2>&1 | \
    grep "duration:" | \
    sort -t: -k6 -nr | \
    head -10
}
```

## Getting Help

### Collect Diagnostic Information

Before seeking help, collect this information:

```bash
#!/bin/bash
# Save as collect-diagnostics.sh

echo "Collecting ExaPG diagnostics..."

# System info
echo "=== System Information ===" > exapg-diagnostics.txt
uname -a >> exapg-diagnostics.txt
docker --version >> exapg-diagnostics.txt
docker-compose --version >> exapg-diagnostics.txt

# Container status
echo -e "\n=== Container Status ===" >> exapg-diagnostics.txt
docker-compose ps >> exapg-diagnostics.txt

# Recent logs
echo -e "\n=== Recent Logs ===" >> exapg-diagnostics.txt
docker-compose logs --tail=100 >> exapg-diagnostics.txt

# Disk usage
echo -e "\n=== Disk Usage ===" >> exapg-diagnostics.txt
df -h >> exapg-diagnostics.txt

# Memory usage
echo -e "\n=== Memory Usage ===" >> exapg-diagnostics.txt
free -h >> exapg-diagnostics.txt

echo "Diagnostics saved to exapg-diagnostics.txt"
```

### Where to Get Help

1. **Documentation**: [docs/INDEX.md](../INDEX.md)
2. **GitHub Issues**: [Report bugs](https://github.com/DamienDrash/ExaPG/issues)
3. **Discussions**: [Community forum](https://github.com/DamienDrash/ExaPG/discussions)
4. **Stack Overflow**: Tag with `exapg` and `postgresql`

### Providing Good Bug Reports

Include:
- ExaPG version
- Deployment mode (single/cluster/ha)
- Error messages (full text)
- Steps to reproduce
- Diagnostic output
- What you've already tried

---

**Still having issues?** Join our [community discussions](https://github.com/DamienDrash/ExaPG/discussions) for help from other users and maintainers. 