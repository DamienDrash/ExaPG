# ExaPG Installation Guide

This guide covers all installation methods and deployment configurations for ExaPG.

## Table of Contents

- [Installation Methods](#installation-methods)
- [Docker Installation](#docker-installation)
- [Manual Installation](#manual-installation)
- [Configuration Options](#configuration-options)
- [Deployment Modes](#deployment-modes)
- [Production Setup](#production-setup)
- [Cloud Deployment](#cloud-deployment)
- [Verification](#verification)
- [Upgrading](#upgrading)
- [Uninstallation](#uninstallation)

## Installation Methods

ExaPG supports multiple installation methods:

1. **Docker (Recommended)** - Containerized deployment
2. **Manual Installation** - Direct installation on host
3. **Kubernetes** - Cloud-native deployment (coming soon)
4. **Package Managers** - APT/YUM repositories (coming soon)

## Docker Installation

### Prerequisites

#### Install Docker

**Ubuntu/Debian:**
```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**RHEL/CentOS:**
```bash
# Install dependencies
sudo yum install -y yum-utils

# Add Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker
# Or download from https://www.docker.com/products/docker-desktop
```

### Docker Compose Installation

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Apply executable permissions
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### ExaPG Installation Steps

#### 1. Clone Repository

```bash
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG
```

#### 2. Configure Environment

```bash
# Copy example configuration
cp .env.example .env

# Edit configuration
nano .env
```

**Key configuration options:**
```env
# Deployment mode
DEPLOYMENT_MODE=single  # Options: single, cluster, ha

# Resource allocation
COORDINATOR_MEMORY_LIMIT=8g
WORKER_MEMORY_LIMIT=8g
SHARED_BUFFERS=2GB
WORK_MEM=128MB

# Network configuration
POSTGRES_PORT=5432
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090

# Security
POSTGRES_PASSWORD=secure_password
GRAFANA_ADMIN_PASSWORD=secure_admin_password
```

#### 3. Start ExaPG

```bash
# Using interactive CLI (recommended)
./scripts/cli/exapg-cli.sh

# Or direct start
./start-exapg.sh
```

## Manual Installation

For advanced users who prefer direct installation:

### 1. Install PostgreSQL 15

```bash
# Ubuntu/Debian
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install postgresql-15 postgresql-contrib-15

# RHEL/CentOS
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum install -y postgresql15-server postgresql15-contrib
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
```

### 2. Install Extensions

```bash
# Citus
curl https://install.citusdata.com/community/deb.sh | sudo bash
sudo apt-get install postgresql-15-citus-11.2

# TimescaleDB
sudo add-apt-repository ppa:timescale/timescaledb-ppa
sudo apt-get update
sudo apt-get install timescaledb-2-postgresql-15

# PostGIS
sudo apt-get install postgresql-15-postgis-3

# pgvector
cd /tmp
git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### 3. Configure PostgreSQL

Edit `/etc/postgresql/15/main/postgresql.conf`:
```conf
# ExaPG optimizations
shared_preload_libraries = 'citus,timescaledb,pg_stat_statements'
shared_buffers = 4GB
work_mem = 256MB
maintenance_work_mem = 1GB
effective_cache_size = 12GB
max_worker_processes = 16
max_parallel_workers_per_gather = 8
max_parallel_workers = 16
```

## Configuration Options

### Memory Configuration

Optimize based on available RAM:

**8GB System:**
```env
SHARED_BUFFERS=2GB
WORK_MEM=64MB
MAINTENANCE_WORK_MEM=512MB
EFFECTIVE_CACHE_SIZE=6GB
```

**16GB System:**
```env
SHARED_BUFFERS=4GB
WORK_MEM=128MB
MAINTENANCE_WORK_MEM=1GB
EFFECTIVE_CACHE_SIZE=12GB
```

**32GB+ System:**
```env
SHARED_BUFFERS=8GB
WORK_MEM=256MB
MAINTENANCE_WORK_MEM=2GB
EFFECTIVE_CACHE_SIZE=24GB
```

### Network Configuration

```env
# PostgreSQL
POSTGRES_PORT=5432
POSTGRES_HOST=0.0.0.0

# Web interfaces
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
MANAGEMENT_UI_PORT=8080

# Cluster communication
CITUS_COORDINATOR_PORT=5432
CITUS_WORKER_PORT_START=5433
```

### Security Configuration

```env
# Database security
POSTGRES_PASSWORD=ChangeMeNow!
POSTGRES_SSL_MODE=require
POSTGRES_SSL_CERT=/path/to/server.crt
POSTGRES_SSL_KEY=/path/to/server.key

# Web interface security
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=SecurePassword123!
GRAFANA_ALLOW_ANONYMOUS=false

# Network security
ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8
```

## Deployment Modes

### Single-Node Deployment

Best for:
- Development environments
- Small workloads
- Testing and evaluation

```bash
DEPLOYMENT_MODE=single ./start-exapg.sh
```

### Cluster Deployment

Best for:
- Production workloads
- Horizontal scaling needs
- High-performance analytics

```bash
DEPLOYMENT_MODE=cluster WORKER_COUNT=3 ./start-exapg-citus.sh
```

Configuration options:
```env
WORKER_COUNT=3
REPLICATION_FACTOR=2
SHARD_COUNT=32
```

### High-Availability Deployment

Best for:
- Mission-critical applications
- Zero-downtime requirements
- Disaster recovery

```bash
./start-exapg-ha.sh
```

Features:
- Primary/standby replication
- Automatic failover with Patroni
- Load balancing with pgBouncer
- Synchronous replication option

## Production Setup

### Pre-Production Checklist

- [ ] Change all default passwords
- [ ] Configure SSL/TLS certificates
- [ ] Set up firewall rules
- [ ] Configure backup strategy
- [ ] Enable monitoring and alerting
- [ ] Document recovery procedures
- [ ] Test failover scenarios
- [ ] Benchmark performance

### Security Hardening

```bash
# Generate SSL certificates
openssl req -new -x509 -days 365 -nodes -text -out server.crt -keyout server.key -subj "/CN=exapg.example.com"
chmod 600 server.key
chown postgres:postgres server.key server.crt

# Configure pg_hba.conf for SSL
echo "hostssl all all 0.0.0.0/0 md5" >> /etc/postgresql/15/main/pg_hba.conf
```

### Backup Configuration

```bash
# Install pgBackRest
sudo apt-get install pgbackrest

# Configure backup repository
sudo mkdir -p /var/lib/pgbackrest
sudo chown postgres:postgres /var/lib/pgbackrest

# Create pgBackRest configuration
cat > /etc/pgbackrest.conf << EOF
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
repo1-retention-diff=7
repo1-retention-archive=7

[exadb]
pg1-path=/var/lib/postgresql/15/main
pg1-port=5432
pg1-database=exadb
EOF
```

### Monitoring Setup

```bash
# Start monitoring stack
./start-monitoring.sh

# Configure alerting
cat > monitoring/alertmanager/alertmanager.yml << EOF
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'exapg-alerts@example.com'
  smtp_auth_username: 'username@gmail.com'
  smtp_auth_password: 'app-password'

route:
  receiver: 'email-notifications'

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
EOF
```

## Cloud Deployment

### AWS Deployment

```bash
# Use EC2 instances with:
# - Instance type: m5.2xlarge or larger
# - Storage: GP3 SSD with 3000+ IOPS
# - Network: Enhanced networking enabled

# Security groups:
# - Port 5432: Database access
# - Port 3000: Grafana
# - Port 8080: Management UI
```

### Azure Deployment

```bash
# Use VMs with:
# - Size: Standard_D8s_v3 or larger
# - Managed disks: Premium SSD
# - Accelerated networking: Enabled

# Network security groups:
# - Same port requirements as AWS
```

### Google Cloud Platform

```bash
# Use Compute Engine with:
# - Machine type: n2-standard-8 or larger
# - Persistent disk: SSD
# - Network: Premium tier
```

## Verification

### Basic Health Check

```bash
# Check all containers
docker-compose ps

# Test database connection
docker exec -it exapg-coordinator psql -U postgres -c "SELECT version();"

# Check extensions
docker exec -it exapg-coordinator psql -U postgres -d exadb -c "SELECT * FROM pg_extension;"

# Verify cluster status (if applicable)
docker exec -it exapg-coordinator psql -U postgres -d exadb -c "SELECT * FROM pg_dist_node;"
```

### Performance Verification

```bash
# Run benchmark suite
./benchmark-suite

# Quick performance test
./scripts/test-performance.sh small
```

## Upgrading

### Minor Version Upgrades

```bash
# Pull latest images
docker-compose pull

# Stop services
docker-compose down

# Start with new version
docker-compose up -d
```

### Major Version Upgrades

```bash
# Backup data first
docker exec exapg-coordinator pg_dumpall -U postgres > backup.sql

# Stop old version
docker-compose down

# Update docker-compose.yml with new version
# Start new version
docker-compose up -d

# Restore if needed
docker exec -i exapg-coordinator psql -U postgres < backup.sql
```

## Uninstallation

### Docker Cleanup

```bash
# Stop all services
./scripts/cli/exapg-cli.sh
# Select 'x' to stop all

# Remove containers
docker-compose down -v

# Remove images (optional)
docker rmi $(docker images | grep exapg | awk '{print $3}')

# Clean up volumes (WARNING: deletes data)
docker volume prune
```

### Manual Cleanup

```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove packages
sudo apt-get remove postgresql-15* citus* timescaledb* postgis*

# Clean configuration
sudo rm -rf /etc/postgresql
sudo rm -rf /var/lib/postgresql
```

---

**Need help?** Check our [Troubleshooting Guide](troubleshooting.md) or visit the [Community Support](https://github.com/DamienDrash/ExaPG/discussions) forum. 