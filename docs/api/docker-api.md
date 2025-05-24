# ExaPG Docker API Reference

**Version:** 1.0.0  
**Datum:** 2024-12-28  
**Status:** Production Ready  

---

## 📋 Übersicht

ExaPG nutzt Docker und Docker Compose für Container-Orchestrierung und Multi-Service-Deployments. Diese Referenz dokumentiert alle verfügbaren Docker-Services, Konfigurationen und Management-APIs.

## 🐳 Core Services

### **Coordinator (PostgreSQL + Citus)**

#### Service Definition
```yaml
coordinator:
  image: exapg/postgres:latest
  container_name: ${COMPOSE_PROJECT_NAME}_coordinator
  ports:
    - "${COORDINATOR_PORT:-5432}:5432"
  environment:
    - POSTGRES_DB=${POSTGRES_DB}
    - POSTGRES_USER=${POSTGRES_USER}
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    - CITUS_ROLE=coordinator
  volumes:
    - coordinator_data:/var/lib/postgresql/data
    - ./config/postgresql:/etc/postgresql
    - ./sql/init:/docker-entrypoint-initdb.d
  networks:
    - exapg_network
```

#### Environment Variables
| Variable | Default | Beschreibung |
|----------|---------|--------------|
| `POSTGRES_DB` | `exadb` | Datenbank-Name |
| `POSTGRES_USER` | `postgres` | Datenbank-User |
| `POSTGRES_PASSWORD` | `required` | Datenbank-Passwort |
| `CITUS_ROLE` | `coordinator` | Citus-Rolle |
| `COORDINATOR_PORT` | `5432` | Externer Port |

#### Health Check
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

### **Worker Nodes**

#### Worker Service Template
```yaml
worker1:
  image: exapg/postgres:latest
  container_name: ${COMPOSE_PROJECT_NAME}_worker1
  ports:
    - "${WORKER1_PORT:-5433}:5432"
  environment:
    - POSTGRES_DB=${POSTGRES_DB}
    - POSTGRES_USER=${POSTGRES_USER}
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    - CITUS_ROLE=worker
    - COORDINATOR_HOST=coordinator
    - COORDINATOR_PORT=5432
  volumes:
    - worker1_data:/var/lib/postgresql/data
    - ./config/postgresql:/etc/postgresql
  networks:
    - exapg_network
  depends_on:
    coordinator:
      condition: service_healthy
```

#### Worker Scaling
```bash
# Dynamic Worker Scaling
docker-compose up --scale worker=3
```

### **Monitoring Stack**

#### Prometheus
```yaml
prometheus:
  image: prom/prometheus:latest
  container_name: ${COMPOSE_PROJECT_NAME}_prometheus
  ports:
    - "${PROMETHEUS_PORT:-9090}:9090"
  volumes:
    - prometheus_data:/prometheus
    - ./monitoring/prometheus:/etc/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--web.console.libraries=/etc/prometheus/console_libraries'
    - '--web.console.templates=/etc/prometheus/consoles'
    - '--storage.tsdb.retention.time=200h'
    - '--web.enable-lifecycle'
  networks:
    - exapg_network
```

#### Grafana
```yaml
grafana:
  image: grafana/grafana:latest
  container_name: ${COMPOSE_PROJECT_NAME}_grafana
  ports:
    - "${GRAFANA_PORT:-3000}:3000"
  environment:
    - GF_SECURITY_ADMIN_USER=${GRAFANA_USER:-admin}
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    - GF_INSTALL_PLUGINS=grafana-piechart-panel
  volumes:
    - grafana_data:/var/lib/grafana
    - ./monitoring/grafana:/etc/grafana/provisioning
  networks:
    - exapg_network
```

#### Postgres Exporter
```yaml
postgres_exporter:
  image: prometheuscommunity/postgres-exporter:latest
  container_name: ${COMPOSE_PROJECT_NAME}_postgres_exporter
  environment:
    - DATA_SOURCE_NAME=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@coordinator:5432/${POSTGRES_DB}?sslmode=disable
  ports:
    - "${POSTGRES_EXPORTER_PORT:-9187}:9187"
  networks:
    - exapg_network
  depends_on:
    - coordinator
```

### **Management UI**

#### Backend API
```yaml
management_backend:
  build: ./management-ui/backend
  container_name: ${COMPOSE_PROJECT_NAME}_mgmt_backend
  ports:
    - "${MGMT_BACKEND_PORT:-8000}:8000"
  environment:
    - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@coordinator:5432/${POSTGRES_DB}
    - API_SECRET_KEY=${API_SECRET_KEY}
  volumes:
    - ./management-ui/backend:/app
  networks:
    - exapg_network
  depends_on:
    coordinator:
      condition: service_healthy
```

#### Frontend UI
```yaml
management_frontend:
  build: ./management-ui/frontend
  container_name: ${COMPOSE_PROJECT_NAME}_mgmt_frontend
  ports:
    - "${MGMT_FRONTEND_PORT:-3001}:3000"
  environment:
    - REACT_APP_API_URL=http://localhost:${MGMT_BACKEND_PORT:-8000}
  volumes:
    - ./management-ui/frontend:/app
    - /app/node_modules
  networks:
    - exapg_network
  depends_on:
    - management_backend
```

### **pgBouncer (Connection Pooling)**

```yaml
pgbouncer:
  image: pgbouncer/pgbouncer:latest
  container_name: ${COMPOSE_PROJECT_NAME}_pgbouncer
  ports:
    - "${PGBOUNCER_PORT:-6432}:6432"
  environment:
    - DATABASES_HOST=coordinator
    - DATABASES_PORT=5432
    - DATABASES_USER=${POSTGRES_USER}
    - DATABASES_PASSWORD=${POSTGRES_PASSWORD}
    - DATABASES_DBNAME=${POSTGRES_DB}
    - POOL_MODE=transaction
    - MAX_CLIENT_CONN=100
    - DEFAULT_POOL_SIZE=20
  volumes:
    - ./config/pgbouncer:/etc/pgbouncer
  networks:
    - exapg_network
  depends_on:
    coordinator:
      condition: service_healthy
```

## 🔧 Docker Compose Files

### **Base Configuration**
```bash
docker/
├── docker-compose.yml              # Core services (coordinator, workers)
├── docker-compose.override.yml     # Development overrides
├── docker-compose.prod.yml         # Production configuration
├── docker-compose.monitoring.yml   # Monitoring stack
├── docker-compose.mgmt.yml         # Management UI
├── docker-compose.ha.yml           # High Availability setup
└── docker-compose.security.yml     # Security hardening
```

### **Environment-based Deployment**

#### Development
```bash
# Entwicklung (mit Hot-Reload)
docker-compose up
# Uses: docker-compose.yml + docker-compose.override.yml
```

#### Production
```bash
# Produktion
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

#### Full Stack mit Monitoring
```bash
# Komplett-Stack
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.monitoring.yml \
  -f docker-compose.mgmt.yml \
  up -d
```

## 🌐 Network Configuration

### **Network Definition**
```yaml
networks:
  exapg_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
    labels:
      - "com.exapg.network=main"
```

### **Service Networks**
```yaml
# Interne Services (Coordinator, Workers)
coordinator:
  networks:
    exapg_network:
      ipv4_address: 172.20.0.10

worker1:
  networks:
    exapg_network:
      ipv4_address: 172.20.0.11

# Monitoring Services
prometheus:
  networks:
    exapg_network:
      ipv4_address: 172.20.0.20
```

## 💾 Volume Management

### **Volume Definitions**
```yaml
volumes:
  coordinator_data:
    driver: local
    labels:
      - "com.exapg.volume=database"
      
  worker1_data:
    driver: local
    labels:
      - "com.exapg.volume=database"
      
  prometheus_data:
    driver: local
    labels:
      - "com.exapg.volume=monitoring"
      
  grafana_data:
    driver: local
    labels:
      - "com.exapg.volume=monitoring"
```

### **External Volume Binding**
```yaml
# Production Volume Configuration
coordinator:
  volumes:
    - /opt/exapg/data/coordinator:/var/lib/postgresql/data
    - /opt/exapg/config:/etc/postgresql:ro
    - /opt/exapg/logs:/var/log/postgresql
```

## 🔒 Security Configuration

### **Security Hardening**
```yaml
# docker-compose.security.yml
coordinator:
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL
  cap_add:
    - CHOWN
    - DAC_OVERRIDE
    - FOWNER
    - SETGID
    - SETUID
  read_only: true
  tmpfs:
    - /tmp
    - /var/run/postgresql
  user: "999:999"  # postgres user
```

### **SSL/TLS Configuration**
```yaml
coordinator:
  volumes:
    - ./config/ssl:/var/lib/postgresql/ssl:ro
  environment:
    - POSTGRES_SSL=on
    - POSTGRES_SSL_CERT_FILE=/var/lib/postgresql/ssl/server.crt
    - POSTGRES_SSL_KEY_FILE=/var/lib/postgresql/ssl/server.key
```

## 📊 Container Management Commands

### **Service Management**

#### Start Services
```bash
# Einzelne Services starten
docker-compose up coordinator
docker-compose up coordinator worker1 worker2

# Mit Dependency-Resolution
docker-compose up --build
```

#### Stop Services
```bash
# Graceful Stop
docker-compose stop

# Force Stop mit Cleanup
docker-compose down --volumes --remove-orphans
```

#### Scaling
```bash
# Worker horizontal skalieren
docker-compose up --scale worker=5

# Einzelne Services skalieren
docker-compose up --scale prometheus=2 --scale grafana=1
```

### **Container Operations**

#### Logs & Debugging
```bash
# Live-Logs verfolgen
docker-compose logs -f coordinator

# Logs mit Timestamps
docker-compose logs -t --since=1h

# Container Shell
docker-compose exec coordinator bash
docker-compose exec coordinator psql -U postgres -d exadb
```

#### Health Checks
```bash
# Service Health überprüfen
docker-compose ps

# Detaillierte Health-Informationen
docker inspect $(docker-compose ps -q coordinator) | jq '.[0].State.Health'
```

### **Backup & Restore**

#### Database Backup
```bash
# SQL Dump
docker-compose exec coordinator pg_dump -U postgres exadb > backup.sql

# Binary Backup
docker-compose exec coordinator pg_basebackup -U postgres -D /backup -Ft -z
```

#### Volume Backup
```bash
# Volume Backup
docker run --rm -v exapg_coordinator_data:/source:ro -v $(pwd):/backup alpine tar czf /backup/coordinator_backup.tar.gz -C /source .

# Volume Restore
docker run --rm -v exapg_coordinator_data:/target -v $(pwd):/backup alpine tar xzf /backup/coordinator_backup.tar.gz -C /target
```

## 🔧 Custom Images

### **Dockerfile Multi-Stage Build**
```dockerfile
# Build Stage
FROM postgres:15 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-15 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Build Citus
WORKDIR /tmp
RUN git clone https://github.com/citusdata/citus.git \
    && cd citus \
    && make \
    && make install

# Runtime Stage
FROM postgres:15 AS runtime

# Copy extensions from builder
COPY --from=builder /usr/lib/postgresql/15/lib/ /usr/lib/postgresql/15/lib/
COPY --from=builder /usr/share/postgresql/15/extension/ /usr/share/postgresql/15/extension/

# ExaPG configuration
COPY config/postgresql/postgresql.conf /etc/postgresql/
COPY scripts/init/ /docker-entrypoint-initdb.d/

# Non-root user
USER postgres

EXPOSE 5432
```

### **Image Building**
```bash
# Base Image bauen
docker build -t exapg/postgres:latest -f docker/Dockerfile .

# Multi-Architecture Build
docker buildx build --platform linux/amd64,linux/arm64 -t exapg/postgres:latest .

# Development Build mit Cache
docker build --target development -t exapg/postgres:dev .
```

## 📈 Performance Optimization

### **Resource Limits**
```yaml
coordinator:
  deploy:
    resources:
      limits:
        memory: 4G
        cpus: '2.0'
      reservations:
        memory: 2G
        cpus: '1.0'
```

### **Shared Memory Configuration**
```yaml
coordinator:
  shm_size: 256m
  volumes:
    - type: tmpfs
      target: /dev/shm
      tmpfs:
        size: 256m
```

## 🔍 Monitoring & Alerting

### **Container Metrics**
```yaml
# Prometheus Scrape Configuration
scrape_configs:
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        port: 9323
    relabel_configs:
      - source_labels: [__meta_docker_container_label_com_exapg_monitor]
        action: keep
        regex: true
```

### **Service Discovery**
```yaml
coordinator:
  labels:
    - "com.exapg.monitor=true"
    - "com.exapg.service=database"
    - "com.exapg.role=coordinator"

worker1:
  labels:
    - "com.exapg.monitor=true"
    - "com.exapg.service=database"
    - "com.exapg.role=worker"
```

## 🚀 Deployment Workflows

### **CI/CD Integration**
```yaml
# GitLab CI Example
deploy:
  stage: deploy
  script:
    - docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull
    - docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
    - docker-compose -f docker-compose.yml -f docker-compose.prod.yml ps
  only:
    - main
```

### **Blue-Green Deployment**
```bash
# Blue-Green mit Docker Compose
export COMPOSE_PROJECT_NAME=exapg_blue
docker-compose up -d

# Switch traffic (via Load Balancer)
export COMPOSE_PROJECT_NAME=exapg_green
docker-compose up -d

# Cleanup old environment
export COMPOSE_PROJECT_NAME=exapg_blue
docker-compose down
```

## 📚 Siehe auch

- [CLI Functions API](cli-api.md)
- [SQL Functions Reference](sql-functions.md)
- [Configuration Reference](configuration-reference.md)

---

**© 2024 ExaPG Project - Docker API Reference v1.0.0** 