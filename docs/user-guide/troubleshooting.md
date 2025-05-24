# ExaPG Troubleshooting Guide

This guide helps you diagnose and resolve common issues with ExaPG.

## Table of Contents

- [Quick Diagnosis](#quick-diagnosis)
- [Installation Issues](#installation-issues)
- [Connection Problems](#connection-problems)
- [Performance Issues](#performance-issues)
- [Cluster Problems](#cluster-problems)
- [Extension Issues](#extension-issues)
- [Data Issues](#data-issues)
- [Monitoring Problems](#monitoring-problems)
- [Common Error Messages](#common-error-messages)
- [Debug Tools](#debug-tools)
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

## Debug Tools

### Enable Detailed Logging

```sql
-- Enable statement logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
SELECT pg_reload_conf();

-- Check logs
docker logs exapg-coordinator -f
```

### Performance Analysis

```bash
# Install pg_stat_statements
docker exec -it exapg-coordinator psql -U postgres -c "CREATE EXTENSION pg_stat_statements;"

# Top queries by time
docker exec -it exapg-coordinator psql -U postgres -c "SELECT query, calls, total_time, mean FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

### Container Debugging

```bash
# Enter container shell
docker exec -it exapg-coordinator bash

# Check processes
ps aux | grep postgres

# Network debugging
netstat -tulpn
ping -c 3 worker1
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