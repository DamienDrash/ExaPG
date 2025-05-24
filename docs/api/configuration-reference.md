# ExaPG Configuration Reference

**Version:** 1.0.0  
**Datum:** 2024-12-28  
**Status:** Production Ready  

---

## 📋 Übersicht

Diese Referenz dokumentiert alle Konfigurationsoptionen für ExaPG, einschließlich Environment Variables, PostgreSQL-Einstellungen, Docker-Konfiguration und Deployment-Parameter.

## 🔧 Environment Variables

### **Core Database Configuration**

| Variable | Default | Beschreibung | Beispiel |
|----------|---------|--------------|----------|
| `POSTGRES_DB` | `exadb` | Hauptdatenbank-Name | `exadb` |
| `POSTGRES_USER` | `postgres` | Hauptbenutzer | `postgres` |
| `POSTGRES_PASSWORD` | *required* | Hauptbenutzer-Passwort | `SecurePassword123!` |
| `POSTGRES_HOST` | `localhost` | Database Host | `coordinator` |
| `POSTGRES_PORT` | `5432` | Database Port | `5432` |

### **Deployment Configuration**

| Variable | Default | Beschreibung | Werte |
|----------|---------|--------------|-------|
| `DEPLOYMENT_MODE` | `standalone` | Deployment-Modus | `standalone`, `cluster`, `ha` |
| `COMPOSE_PROJECT_NAME` | `exapg` | Docker Compose Projekt-Name | `exapg_prod` |
| `ENVIRONMENT` | `development` | Umgebung | `development`, `staging`, `production` |
| `CLUSTER_NAME` | `exapg-cluster` | Cluster-Bezeichnung | `production-cluster` |

### **Service Ports**

| Variable | Default | Beschreibung | Bereich |
|----------|---------|--------------|---------|
| `COORDINATOR_PORT` | `5432` | Coordinator-Port | `1024-65535` |
| `WORKER1_PORT` | `5433` | Worker 1 Port | `1024-65535` |
| `WORKER2_PORT` | `5434` | Worker 2 Port | `1024-65535` |
| `PGBOUNCER_PORT` | `6432` | pgBouncer Port | `1024-65535` |
| `PROMETHEUS_PORT` | `9090` | Prometheus Port | `1024-65535` |
| `GRAFANA_PORT` | `3000` | Grafana Port | `1024-65535` |
| `MGMT_BACKEND_PORT` | `8000` | Management Backend Port | `1024-65535` |
| `MGMT_FRONTEND_PORT` | `3001` | Management Frontend Port | `1024-65535` |

### **PostgreSQL Memory Configuration**

| Variable | Default | Beschreibung | Format |
|----------|---------|--------------|--------|
| `POSTGRES_SHARED_BUFFERS` | `256MB` | Shared Buffers | `128MB`, `1GB`, `2048MB` |
| `POSTGRES_WORK_MEM` | `4MB` | Work Memory | `4MB`, `16MB`, `64MB` |
| `POSTGRES_EFFECTIVE_CACHE_SIZE` | `1GB` | Effective Cache Size | `512MB`, `4GB`, `8GB` |
| `POSTGRES_MAINTENANCE_WORK_MEM` | `64MB` | Maintenance Work Memory | `64MB`, `256MB`, `1GB` |
| `POSTGRES_WAL_BUFFERS` | `16MB` | WAL Buffers | `16MB`, `32MB`, `64MB` |

### **Resource Limits**

| Variable | Default | Beschreibung | Format |
|----------|---------|--------------|--------|
| `COORDINATOR_MEMORY_LIMIT` | `2GB` | Coordinator Memory Limit | `1GB`, `4GB`, `8GB` |
| `WORKER_MEMORY_LIMIT` | `1GB` | Worker Memory Limit | `512MB`, `2GB`, `4GB` |
| `COORDINATOR_CPU_LIMIT` | `2.0` | Coordinator CPU Limit | `1.0`, `2.0`, `4.0` |
| `WORKER_CPU_LIMIT` | `1.0` | Worker CPU Limit | `0.5`, `1.0`, `2.0` |

### **Security Configuration**

| Variable | Default | Beschreibung | Beispiel |
|----------|---------|--------------|----------|
| `SSL_ENABLED` | `false` | SSL/TLS aktivieren | `true`, `false` |
| `SSL_CERT_FILE` | `/ssl/server.crt` | SSL-Zertifikat-Pfad | `/config/ssl/cert.pem` |
| `SSL_KEY_FILE` | `/ssl/server.key` | SSL-Schlüssel-Pfad | `/config/ssl/key.pem` |
| `API_SECRET_KEY` | *generated* | API Secret Key | `32-char-secret-key` |
| `JWT_SECRET` | *generated* | JWT Secret | `jwt-secret-key` |

### **Monitoring Configuration**

| Variable | Default | Beschreibung | Format |
|----------|---------|--------------|--------|
| `MONITORING_ENABLED` | `true` | Monitoring aktivieren | `true`, `false` |
| `METRICS_RETENTION_DAYS` | `30` | Metrics Retention | `7`, `30`, `90` |
| `LOG_LEVEL` | `INFO` | Log-Level | `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `GRAFANA_USER` | `admin` | Grafana Admin User | `admin` |
| `GRAFANA_PASSWORD` | *required* | Grafana Admin Passwort | `SecurePassword123!` |

### **Internationalization**

| Variable | Default | Beschreibung | Beispiel |
|----------|---------|--------------|----------|
| `EXAPG_LOCALE` | `en_US.UTF-8` | System Locale | `de_DE.UTF-8`, `fr_FR.UTF-8` |
| `EXAPG_TIMEZONE` | `UTC` | Zeitzone | `Europe/Berlin`, `America/New_York` |
| `EXAPG_LANGUAGE` | `en` | UI-Sprache | `de`, `fr`, `es` |
| `EXAPG_TEXT_SEARCH_CONFIG` | `pg_catalog.english` | Text Search Config | `pg_catalog.german` |

### **Backup Configuration**

| Variable | Default | Beschreibung | Format |
|----------|---------|--------------|--------|
| `BACKUP_ENABLED` | `true` | Backup aktivieren | `true`, `false` |
| `BACKUP_SCHEDULE` | `0 2 * * *` | Backup-Schedule (Cron) | `0 2 * * *` |
| `BACKUP_RETENTION_DAYS` | `30` | Backup-Aufbewahrungszeit | `7`, `30`, `90` |
| `BACKUP_LOCATION` | `./backups` | Backup-Verzeichnis | `/opt/exapg/backups` |

## 📊 PostgreSQL Configuration Files

### **postgresql.conf Template**

```bash
# ExaPG PostgreSQL Configuration Template
# Version: 1.0.0

# =============================================================================
# CONNECTION AND AUTHENTICATION
# =============================================================================

listen_addresses = '*'
port = ${POSTGRES_PORT:-5432}
max_connections = ${POSTGRES_MAX_CONNECTIONS:-200}

# SSL Configuration
ssl = ${SSL_ENABLED:-off}
ssl_cert_file = '${SSL_CERT_FILE:-/ssl/server.crt}'
ssl_key_file = '${SSL_KEY_FILE:-/ssl/server.key}'
ssl_prefer_server_ciphers = on
ssl_protocols = 'TLSv1.2,TLSv1.3'

# =============================================================================
# RESOURCE USAGE (except WAL)
# =============================================================================

# Memory Settings
shared_buffers = ${POSTGRES_SHARED_BUFFERS:-256MB}
work_mem = ${POSTGRES_WORK_MEM:-4MB}
maintenance_work_mem = ${POSTGRES_MAINTENANCE_WORK_MEM:-64MB}
effective_cache_size = ${POSTGRES_EFFECTIVE_CACHE_SIZE:-1GB}

# Background Writer
bgwriter_delay = ${POSTGRES_BGWRITER_DELAY:-200ms}
bgwriter_lru_maxpages = ${POSTGRES_BGWRITER_LRU_MAXPAGES:-100}
bgwriter_lru_multiplier = ${POSTGRES_BGWRITER_LRU_MULTIPLIER:-2.0}

# =============================================================================
# WRITE AHEAD LOG
# =============================================================================

wal_level = ${POSTGRES_WAL_LEVEL:-replica}
wal_buffers = ${POSTGRES_WAL_BUFFERS:-16MB}
wal_writer_delay = ${POSTGRES_WAL_WRITER_DELAY:-200ms}
checkpoint_completion_target = ${POSTGRES_CHECKPOINT_COMPLETION_TARGET:-0.9}
max_wal_size = ${POSTGRES_MAX_WAL_SIZE:-1GB}
min_wal_size = ${POSTGRES_MIN_WAL_SIZE:-80MB}

# =============================================================================
# REPLICATION
# =============================================================================

max_wal_senders = ${POSTGRES_MAX_WAL_SENDERS:-10}
wal_keep_size = ${POSTGRES_WAL_KEEP_SIZE:-100MB}
hot_standby = ${POSTGRES_HOT_STANDBY:-on}

# =============================================================================
# QUERY TUNING
# =============================================================================

# Planner Cost Constants
random_page_cost = ${POSTGRES_RANDOM_PAGE_COST:-1.1}
effective_io_concurrency = ${POSTGRES_EFFECTIVE_IO_CONCURRENCY:-200}

# Other Planner Options
default_statistics_target = ${POSTGRES_DEFAULT_STATISTICS_TARGET:-100}

# =============================================================================
# REPORTING AND LOGGING
# =============================================================================

# Logging
log_destination = '${POSTGRES_LOG_DESTINATION:-stderr}'
logging_collector = ${POSTGRES_LOGGING_COLLECTOR:-off}
log_directory = '${POSTGRES_LOG_DIRECTORY:-/var/log/postgresql}'
log_filename = '${POSTGRES_LOG_FILENAME:-postgresql-%Y-%m-%d_%H%M%S.log}'
log_rotation_age = ${POSTGRES_LOG_ROTATION_AGE:-1d}
log_rotation_size = ${POSTGRES_LOG_ROTATION_SIZE:-10MB}

# What to Log
log_line_prefix = '${POSTGRES_LOG_LINE_PREFIX:-%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h }'
log_min_duration_statement = ${POSTGRES_LOG_MIN_DURATION_STATEMENT:-1000}
log_statement = '${POSTGRES_LOG_STATEMENT:-none}'
log_lock_waits = ${POSTGRES_LOG_LOCK_WAITS:-on}
log_temp_files = ${POSTGRES_LOG_TEMP_FILES:-10MB}

# =============================================================================
# STATISTICS
# =============================================================================

track_activities = ${POSTGRES_TRACK_ACTIVITIES:-on}
track_counts = ${POSTGRES_TRACK_COUNTS:-on}
track_io_timing = ${POSTGRES_TRACK_IO_TIMING:-on}
track_functions = ${POSTGRES_TRACK_FUNCTIONS:-all}

# =============================================================================
# CITUS CONFIGURATION
# =============================================================================

# Load Citus Extension
shared_preload_libraries = '${POSTGRES_SHARED_PRELOAD_LIBRARIES:-citus,pg_stat_statements,timescaledb}'

# Citus Settings
citus.shard_count = ${CITUS_SHARD_COUNT:-32}
citus.shard_replication_factor = ${CITUS_SHARD_REPLICATION_FACTOR:-1}
citus.max_worker_nodes_tracked = ${CITUS_MAX_WORKER_NODES_TRACKED:-1024}

# =============================================================================
# TIMESCALEDB CONFIGURATION
# =============================================================================

timescaledb.max_background_workers = ${TIMESCALEDB_MAX_BACKGROUND_WORKERS:-8}

# =============================================================================
# LOCALE AND FORMATTING
# =============================================================================

datestyle = '${POSTGRES_DATESTYLE:-iso, mdy}'
timezone = '${EXAPG_TIMEZONE:-UTC}'
lc_messages = '${EXAPG_LOCALE:-en_US.UTF-8}'
lc_monetary = '${EXAPG_LOCALE:-en_US.UTF-8}'
lc_numeric = '${EXAPG_LOCALE:-en_US.UTF-8}'
lc_time = '${EXAPG_LOCALE:-en_US.UTF-8}'
default_text_search_config = '${EXAPG_TEXT_SEARCH_CONFIG:-pg_catalog.english}'
```

### **pg_hba.conf Template**

```bash
# ExaPG pg_hba.conf Template
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             all                                     md5

# IPv4 local connections
host    all             postgres        127.0.0.1/32           md5
host    all             all             127.0.0.1/32           md5

# IPv6 local connections
host    all             postgres        ::1/128                 md5
host    all             all             ::1/128                 md5

# Docker network connections (adjust subnet as needed)
hostssl all             all             172.20.0.0/16          md5
host    all             all             172.20.0.0/16          md5

# Production network connections (configure for your environment)
# hostssl all             all             192.168.1.0/24         md5
# hostssl all             all             10.0.0.0/8             md5

# Replication connections
host    replication     postgres        172.20.0.0/16          md5
hostssl replication     postgres        172.20.0.0/16          md5

# Citus worker connections
hostssl ${POSTGRES_DB}  postgres        coordinator            cert
hostssl ${POSTGRES_DB}  postgres        worker1                cert
hostssl ${POSTGRES_DB}  postgres        worker2                cert
```

## 🔧 Advanced Configuration

### **Performance Tuning Parameters**

| Kategorie | Parameter | Entwicklung | Produktion | High-Load |
|-----------|-----------|-------------|------------|-----------|
| **Memory** | `shared_buffers` | `128MB` | `25% RAM` | `40% RAM` |
| **Memory** | `work_mem` | `4MB` | `16MB` | `32MB` |
| **Memory** | `effective_cache_size` | `512MB` | `75% RAM` | `80% RAM` |
| **WAL** | `wal_buffers` | `16MB` | `32MB` | `64MB` |
| **WAL** | `max_wal_size` | `1GB` | `4GB` | `8GB` |
| **Connections** | `max_connections` | `100` | `200` | `500` |

### **Citus-specific Configuration**

| Parameter | Default | Beschreibung | Empfehlung |
|-----------|---------|--------------|------------|
| `citus.shard_count` | `32` | Anzahl Shards | `2 * CPU_Cores * Worker_Count` |
| `citus.shard_replication_factor` | `1` | Shard-Replikation | `1` (Standalone), `2` (HA) |
| `citus.max_worker_nodes_tracked` | `1024` | Max tracked Workers | `Anzahl_Worker * 2` |
| `citus.worker_min_messages` | `WARNING` | Worker Log Level | `WARNING`, `ERROR` |

### **TimescaleDB Configuration**

| Parameter | Default | Beschreibung | Verwendung |
|-----------|---------|--------------|------------|
| `timescaledb.max_background_workers` | `8` | Background Workers | `CPU_Cores / 2` |
| `timescaledb.restoring` | `off` | Restore Mode | `on` während Restore |
| `timescaledb.telemetry_level` | `basic` | Telemetrie | `off` (Produktion) |

## 🚀 Deployment Templates

### **Development Environment**
```bash
# .env.development
DEPLOYMENT_MODE=standalone
ENVIRONMENT=development
LOG_LEVEL=DEBUG

# Database
POSTGRES_DB=exadb_dev
POSTGRES_USER=postgres
POSTGRES_PASSWORD=dev_password

# Monitoring
MONITORING_ENABLED=true
GRAFANA_PASSWORD=dev_grafana

# Resources (minimal)
COORDINATOR_MEMORY_LIMIT=1GB
POSTGRES_SHARED_BUFFERS=128MB
POSTGRES_WORK_MEM=4MB
```

### **Staging Environment**
```bash
# .env.staging
DEPLOYMENT_MODE=cluster
ENVIRONMENT=staging
LOG_LEVEL=INFO

# Database
POSTGRES_DB=exadb_staging
POSTGRES_USER=postgres
POSTGRES_PASSWORD=staging_secure_password

# Monitoring
MONITORING_ENABLED=true
GRAFANA_PASSWORD=staging_grafana_password

# Resources (moderate)
COORDINATOR_MEMORY_LIMIT=2GB
WORKER_MEMORY_LIMIT=1GB
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_WORK_MEM=8MB
```

### **Production Environment**
```bash
# .env.production
DEPLOYMENT_MODE=ha
ENVIRONMENT=production
LOG_LEVEL=WARNING

# Database
POSTGRES_DB=exadb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=very_secure_production_password

# Security
SSL_ENABLED=true
SSL_CERT_FILE=/config/ssl/production.crt
SSL_KEY_FILE=/config/ssl/production.key

# Monitoring
MONITORING_ENABLED=true
GRAFANA_PASSWORD=secure_grafana_password

# Resources (high-performance)
COORDINATOR_MEMORY_LIMIT=8GB
WORKER_MEMORY_LIMIT=4GB
POSTGRES_SHARED_BUFFERS=2GB
POSTGRES_WORK_MEM=32MB
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB

# Backup
BACKUP_ENABLED=true
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=30
```

## 🔒 Security Best Practices

### **Password Requirements**
- Mindestlänge: 12 Zeichen
- Mindestens 1 Großbuchstabe
- Mindestens 1 Kleinbuchstabe
- Mindestens 1 Ziffer
- Mindestens 1 Sonderzeichen

### **SSL/TLS Configuration**
```bash
# SSL-Zertifikat generieren
openssl req -new -x509 -days 365 -nodes -text \
    -out config/ssl/server.crt \
    -keyout config/ssl/server.key \
    -subj "/CN=exapg-coordinator"

# Berechtigungen setzen
chmod 600 config/ssl/server.key
chmod 644 config/ssl/server.crt
```

### **Network Security**
```bash
# pg_hba.conf für Produktion
hostssl all all 10.0.0.0/8     md5
hostssl all all 192.168.0.0/16 md5
# Niemals: host all all 0.0.0.0/0 trust
```

## ⚡ Performance Optimization

### **Memory Calculation**
```bash
# Automatische Memory-Berechnung
TOTAL_RAM=$(free -b | awk '/^Mem:/{print $2}')
SHARED_BUFFERS=$((TOTAL_RAM / 4))  # 25% of RAM
EFFECTIVE_CACHE_SIZE=$((TOTAL_RAM * 3 / 4))  # 75% of RAM
WORK_MEM=$((TOTAL_RAM / 1024 / 100))  # ~1% of RAM per connection
```

### **Storage Optimization**
```bash
# SSD-optimierte Einstellungen
POSTGRES_RANDOM_PAGE_COST=1.1
POSTGRES_EFFECTIVE_IO_CONCURRENCY=200

# HDD-optimierte Einstellungen
POSTGRES_RANDOM_PAGE_COST=4.0
POSTGRES_EFFECTIVE_IO_CONCURRENCY=2
```

## 📚 Configuration Validation

### **Validation Script Usage**
```bash
# Alle Konfigurationen validieren
./scripts/validate-config.sh all

# Spezifische Bereiche validieren
./scripts/validate-config.sh postgresql
./scripts/validate-config.sh docker
./scripts/validate-config.sh env
```

### **Common Configuration Errors**
| Fehler | Ursache | Lösung |
|--------|---------|---------|
| `shared_buffers` zu groß | >40% RAM | Reduzieren auf 25-30% RAM |
| `max_connections` zu hoch | >1000 | pgBouncer verwenden |
| SSL-Dateien nicht gefunden | Falsche Pfade | Pfade prüfen, Berechtigungen setzen |
| Worker-Verbindung fehlschlägt | Netzwerk-Konfiguration | Docker-Netzwerk prüfen |

## 🔗 Siehe auch

- [CLI Functions API](cli-api.md)
- [SQL Functions Reference](sql-functions.md)
- [Docker API Reference](docker-api.md)

---

**© 2024 ExaPG Project - Configuration Reference v1.0.0** 