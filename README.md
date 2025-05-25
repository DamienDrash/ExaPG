# ExaPG - High-Performance PostgreSQL Analytics Platform

> A PostgreSQL-based alternative to Exasol for analytical workloads, featuring columnar storage, distributed processing, and enterprise-grade scalability.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![PostgreSQL 15](https://img.shields.io/badge/PostgreSQL-15-336791.svg)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED.svg)](https://www.docker.com/)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Deployment Modes](#deployment-modes)
- [Performance Testing](#performance-testing)
- [Monitoring](#monitoring)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Features

**🚀 High-Performance Analytics**
- Columnar storage with Citus Columnar for 8x compression
- JIT compilation for complex queries
- Parallel query processing with optimized worker configuration
- SCRAM-SHA-256 authentication for enterprise security

**📈 Horizontal Scalability**  
- Distributed processing with Citus (1 coordinator + multiple workers)
- Automatic data distribution and query parallelization
- Dynamic cluster scaling with rolling updates
- Kubernetes-native deployment with StatefulSets

**🔗 Comprehensive Data Integration**
- Foreign Data Wrappers for PostgreSQL, MySQL, MongoDB, SQL Server, Redis
- ETL automation with pgAgent
- Time-series analytics with TimescaleDB
- Disaster recovery with pgBackRest and automated validation

**🎯 Advanced Analytics Extensions**
- Geospatial analysis with PostGIS
- Vector similarity search with pgvector  
- Machine learning and AI workload support
- Multi-language support (English, German) in CLI

**📊 Enterprise Monitoring**
- Real-time metrics with Prometheus
- Pre-built Grafana dashboards
- Automated alerting and notifications
- Comprehensive health checks and status monitoring

**🔧 Enterprise Management**
- Web-based cluster management UI
- Automated backup with pgBackRest
- High availability with automatic failover
- 175+ automated tests with CI/CD integration

**☁️ Cloud Native**
- Complete Kubernetes integration (10+ manifests)
- Multi-environment support (dev/staging/prod)
- GitOps ready with ArgoCD/Flux support
- SSL/TLS encryption throughout

## Quick Start

```bash
# Clone repository
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG

# Start with modern dialog interface (recommended)
./exapg

# Or use simple command-line mode
./exapg simple deploy
```

**CLI Modes:**
- **Modern Interface**: `./exapg` - Dialog-based UI with menus and navigation
- **Simple Mode**: `./exapg simple [command]` - Direct command-line interface

**For Kubernetes deployment:**
```bash
# Deploy to Kubernetes
cd k8s
./deploy.sh prod --all

# Access services
kubectl port-forward -n exapg svc/exapg-coordinator 5432:5432
```

**Connect to Database:**
```bash
# Using simple mode
./exapg simple shell

# Or directly
docker exec -it exapg-coordinator psql -U postgres -d exadb
# Or for Kubernetes:
kubectl exec -it -n exapg exapg-coordinator-0 -- psql -U postgres -d exadb
```

**Access Web Interfaces:**
- Cluster Management: http://localhost:8080
- Grafana Monitoring: http://localhost:3000 (admin/exapg_admin)
- Prometheus: http://localhost:9090
- Kubernetes: http://exapg.local (with ingress configured)

## Architecture

ExaPG provides flexible deployment architectures:

```
┌─────────────────┐    ┌─────────────────┐    ┌────────────────────┐    ┌─────────────────┐
│   Single-Node   │    │    Cluster      │    │  High-Availability │    │   Kubernetes    │
│                 │    │                 │    │                    │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌────────────────┐ │    │ ┌─────────────┐ │
│ │ PostgreSQL  │ │    │ │ Coordinator │ │    │ │Primary+Standby │ │    │ │ StatefulSet │ │
│ │   + Citus   │ │    │ │             │ │    │ │   + Patroni    │ │    │ │+ Monitoring │ │
│ │+TimescaleDB │ │    │ └─────────────┘ │    │ │   + pgBouncer  │ │    │ │+ Management │ │
│ │  + PostGIS  │ │    │ ┌─────────────┐ │    │ └────────────────┘ │    │ └─────────────┘ │
│ │ + pgvector  │ │    │ │  Worker 1   │ │    │ ┌────────────────┐ │    │ ┌─────────────┐ │
│ └─────────────┘ │    │ │  Worker 2   │ │    │ │   Monitoring   │ │    │ │   Ingress   │ │
└─────────────────┘    │ │  Worker N   │ │    │ │ Stack + Alerts │ │    │ │  + GitOps   │ │
                       │ └─────────────┘ │    │ └────────────────┘ │    │ └─────────────┘ │
                       └─────────────────┘    └────────────────────┘    └─────────────────┘
```

**Core Components:**
- **PostgreSQL 15**: Base database with analytical optimizations
- **Citus**: Horizontal scaling and distributed queries  
- **TimescaleDB**: Efficient time-series storage and analysis
- **PostGIS**: Geospatial data processing
- **pgvector**: Vector similarity search for ML workloads
- **Prometheus/Grafana**: Comprehensive monitoring and alerting
- **Kubernetes**: Cloud-native orchestration with auto-scaling

## Installation

### System Requirements

- **Docker**: Version 19.03 or higher
- **Docker Compose**: Version 1.27 or higher  
- **Memory**: Minimum 8GB RAM (single-node), 16GB+ (cluster)
- **Storage**: SSD recommended for optimal performance
- **Network**: Ports 5432, 8080, 3000, 9090 available

### Installation Steps

1. **Clone Repository**
   ```bash
   git clone https://github.com/DamienDrash/ExaPG.git
   cd ExaPG
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env file with your settings
   ```

3. **Start ExaPG**
   ```bash
   # Interactive CLI
   ./exapg
   ```

4. **Verify Installation**
   ```bash
   ./scripts/performance/run-all-tests.sh
   ```

## Configuration

### Environment Variables

Configure ExaPG through the `.env` file:

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `DEPLOYMENT_MODE` | Deployment architecture | `single` | `single`, `cluster`, `ha` |
| `WORKER_COUNT` | Number of worker nodes | `2` | `1-10` |
| `COORDINATOR_MEMORY_LIMIT` | Coordinator memory limit | `8g` | `4g`, `8g`, `16g`, `32g` |
| `WORKER_MEMORY_LIMIT` | Worker memory limit | `8g` | `4g`, `8g`, `16g`, `32g` |
| `SHARED_BUFFERS` | PostgreSQL shared buffers | `2GB` | `1GB-8GB` |
| `WORK_MEM` | PostgreSQL work memory | `128MB` | `64MB-1GB` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` | `1024-65535` |

### Performance Tuning

**For analytical workloads:**
```env
# High-performance analytics configuration
SHARED_BUFFERS=4GB
WORK_MEM=256MB
MAINTENANCE_WORK_MEM=1GB
EFFECTIVE_CACHE_SIZE=12GB
RANDOM_PAGE_COST=1.1
```

**For time-series workloads:**
```env
# TimescaleDB optimizations
TIMESCALEDB_TELEMETRY=off
MAX_CONNECTIONS=200
CHECKPOINT_COMPLETION_TARGET=0.9
```

## Usage

### Modern Dialog Interface (Recommended)

The modern interface provides an intuitive dialog-based experience:

```bash
./exapg
```

Features:
- Interactive menus with navigation
- Theme selection and customization
- Real-time status monitoring  
- Integrated benchmark suite execution
- Log viewing and troubleshooting
- Configuration management
- Multi-language support

### Simple Command-Line Interface

For automation and scripting, use the simple mode:

```bash
# Deploy analytics cluster
./exapg simple deploy

# Check status
./exapg simple status

# Connect to database
./exapg simple shell

# Stop all services
./exapg simple stop

# Run tests
./exapg simple test

# Show help
./exapg simple help
```

### CLI Mode Selection

```bash
# Default: Modern dialog interface
./exapg

# Explicit simple mode
./exapg simple [command]

# Help for both modes
./exapg help
./exapg simple help

# Version information
./exapg version
```

### Alternative Tools

```bash
# Professional benchmark suite
./benchmark-suite

# Basic testing tool
./scripts/test-exapg.sh [validate|docker|k8s]

# Direct Kubernetes deployment
cd k8s && ./deploy.sh prod --all
```

### Database Connection

**Using Docker:**
```bash
docker exec -it exapg-coordinator psql -U postgres -d exadb
```

**External Client:**
- Host: `localhost`
- Port: `5432` 
- Username: `postgres`
- Password: `postgres`
- Database: `exadb`

### Sample Data and Queries

ExaPG includes pre-loaded sample tables:

```sql
-- Time-series sensor data
SELECT * FROM analytics.sensor_data LIMIT 10;

-- Sales analytics with columnar storage  
SELECT 
    date_trunc('month', sale_date) as month,
    SUM(amount) as total_sales
FROM analytics.sales 
GROUP BY 1 ORDER BY 1;

-- Vector similarity search
SELECT document_id, content 
FROM analytics.document_embeddings 
ORDER BY embedding <-> '[0.1,0.2,0.3]'::vector
LIMIT 5;

-- Geospatial queries
SELECT name, ST_Distance(location, ST_MakePoint(-122.4194, 37.7749)) as distance
FROM analytics.locations
ORDER BY distance LIMIT 10;
```

## Deployment Modes

### Single-Node Mode

Ideal for development, testing, and smaller production environments. Start via the CLI:

```bash
./exapg
# Select option 1: ExaPG Standard
```

- All extensions on single PostgreSQL server
- Lower hardware requirements
- Simplified management

### Cluster Mode

Horizontal scaling across multiple nodes:

```bash  
./exapg
# Select option 2: ExaPG Citus
```

- 1 coordinator + 2-10 worker nodes
- Automatic data distribution
- Parallel query processing
- Higher performance for large datasets

### High-Availability Mode

Enterprise deployment with automatic failover:

```bash
./exapg
# Select option 3: ExaPG HA
```

- Primary/standby configuration with Patroni
- Automatic failover and recovery
- Load balancing with pgBouncer
- Zero-downtime maintenance

### Kubernetes Mode

Kubernetes-native deployment with StatefulSets:

```bash
./exapg
# Select option 4: ExaPG Kubernetes
```

- Auto-scaling and rolling updates
- Comprehensive monitoring and alerting
- GitOps ready with ArgoCD/Flux support

## Performance Testing

### Built-in Test Suite

```bash
# Run comprehensive test suite
./scripts/performance/run-all-tests.sh

# Individual test categories  
./scripts/performance/test-exapg.sh         # Core functionality
./scripts/performance/test-fdw.sh           # Foreign data wrappers
./scripts/performance/test-etl.sh           # ETL processes
./scripts/performance/test-performance.sh   # Performance benchmarks

# Basic testing via CLI
./exapg simple test                         # Simple mode testing
./scripts/test-exapg.sh validate           # Environment validation
./scripts/test-exapg.sh docker             # Docker functionality
./scripts/test-exapg.sh k8s                # Kubernetes readiness
```

### Benchmark Suite

ExaPG includes an enterprise-grade benchmark suite:

```bash
# Interactive benchmark UI
./benchmark-suite

# Direct TPC-H benchmark
./benchmark/scripts/benchmark-tests.sh tpch

# PostgreSQL OLTP benchmark
./benchmark/scripts/benchmark-tests.sh pgbench

# Custom benchmark configuration
./benchmark/scripts/benchmark-tests.sh custom
```

**Performance Scale Options:**
- `small`: 10,000 records (development)
- `medium`: 100,000 records (testing)  
- `large`: 1,000,000+ records (production)

### Performance Comparison

| Feature | ExaPG | Exasol | PostgreSQL |
|---------|-------|--------|------------|
| Columnar Storage | ✅ (Citus) | ✅ (Native) | ❌ |
| In-Memory Processing | ⚡ (Partial) | ✅ (Full) | ❌ |
| Horizontal Scaling | ✅ (Citus) | ✅ (Native) | ⚡ (Limited) |
| Compression Ratio | 8x | 10-15x | 2-3x |
| SQL Compatibility | ANSI SQL | Exasol SQL | ANSI SQL |
| Data Integration | ✅ (FDW) | ⚡ (JDBC) | ⚡ (Limited) |
| Open Source | ✅ | ❌ | ✅ |

## Monitoring

### Prometheus + Grafana Stack

Start monitoring through the CLI:
```bash
./exapg
# Select option 4: Monitoring Stack
```

**Access Dashboards:**
- Grafana: http://localhost:3000 (admin/exapg_admin)
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

### Pre-built Dashboards

1. **ExaPG Overview**
   - System status and resource utilization
   - Database activity and connections
   - Query performance metrics

2. **ExaPG Analytics Performance**  
   - Analytical workload performance
   - Columnar storage efficiency
   - Cluster node utilization

3. **ExaPG Cluster Health**
   - Multi-node cluster status
   - Data distribution metrics
   - Network and replication status

### Alerting Rules

Automated alerts for:
- High CPU/memory utilization (>80%)
- Storage space low (<10% free)
- Too many connections (>80% of max)
- Slow queries (>30 seconds)
- Node failures or network issues

## Documentation

📚 **[Complete Documentation Index](docs/INDEX.md)**

### User Guides
- [Getting Started](docs/user-guide/getting-started.md) - Quick start tutorial
- [Installation Guide](docs/user-guide/installation.md) - Detailed setup instructions
- [CLI Reference](docs/user-guide/cli-reference.md) - Interactive terminal interface
- [Migration Guide](docs/user-guide/migration-guide.md) - Migrating from Exasol
- [Troubleshooting](docs/user-guide/troubleshooting.md) - Common issues and solutions

### Technical Documentation  
- [Architecture Guide](docs/technical/architecture.md) - System architecture
- [Performance Tuning](docs/technical/performance-tuning.md) - Optimization strategies
- [Columnar Storage](docs/technical/columnar-storage.md) - Column-oriented storage
- [Columnar Comparison](docs/technical/columnar-comparison.md) - Performance comparisons

### Integration Documentation
- [SQL Compatibility](docs/integration/sql-compatibility.md) - Exasol SQL support
- [Data Integration](docs/integration/data-integration.md) - FDW and ETL processes
- [Monitoring Setup](docs/integration/monitoring.md) - Prometheus/Grafana configuration

### Specialized Modules
- [Benchmark Suite](benchmark/README.md) - Performance testing framework

## Roadmap

### Recently Completed (v3.0.0 - December 2024)
- ✅ Kubernetes Integration with StatefulSets
- ✅ Enterprise Security (SCRAM-SHA-256, SSL/TLS)
- ✅ Comprehensive Testing Framework (175+ tests)
- ✅ Configuration Management (67 unified variables)
- ✅ Multi-language CLI Support
- ✅ Professional API Documentation

### Current Development (2024-2025)
- 🔄 Connection Pooling with PgBouncer
- 🔄 CloudNativePG Operator Integration
- 🔄 Service Mesh Support (Istio/Linkerd)
- 🔄 Advanced Health Checks

### Future Plans

**Phase 8: Cloud Native Excellence (Q1-Q2 2025)**
- Vertical Pod Autoscaler (VPA) integration
- Multi-region deployment support
- Advanced GitOps workflows
- Cost optimization features

**Phase 9: Advanced Analytics (Q3-Q4 2025)**
- Native columnar storage engine
- Real-time streaming analytics
- Graph database integration
- Advanced ML model deployment

**Phase 10: Enterprise Platform (2026)**
- Multi-cloud federation
- AI-powered query optimization
- Automated performance tuning
- Enterprise marketplace

For detailed roadmap, see [GitHub Issues](https://github.com/DamienDrash/ExaPG/issues).

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Fork and clone repository
git clone https://github.com/YOUR-USERNAME/ExaPG.git
cd ExaPG

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
./scripts/performance/run-all-tests.sh

# Submit pull request
```

### Code Standards

- Follow PostgreSQL SQL standards
- Use consistent Docker practices
- Include comprehensive tests
- Update documentation
- Add monitoring for new features

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

## Support

### Community Support

- **Documentation**: [docs/INDEX.md](docs/INDEX.md)
- **Issues**: [GitHub Issues](https://github.com/DamienDrash/ExaPG/issues)
- **Discussions**: [GitHub Discussions](https://github.com/DamienDrash/ExaPG/discussions)

### Commercial Support

For enterprise deployments and commercial support, please contact the development team.

### Troubleshooting

**Common Issues:**

1. **CLI Interface Issues**
   ```bash
   # If modern interface doesn't work, use simple mode
   ./exapg simple status
   
   # Check CLI version and modes
   ./exapg version
   ./exapg help
   
   # For dialog installation issues:
   sudo yum install -y dialog  # RHEL/CentOS
   sudo apt-get install -y dialog  # Ubuntu/Debian
   ```

2. **Connection Issues**
   ```bash
   # Check status via simple CLI
   ./exapg simple status
   
   # For advanced debugging:
   docker-compose ps
   docker-compose logs coordinator
   ```

3. **Performance Problems**
   ```bash
   # Run performance analysis
   ./exapg simple test
   ./scripts/performance/test-performance.sh
   
   # Check monitoring dashboards
   # First ensure monitoring is running:
   ./exapg  # Select monitoring option
   # Then access Grafana:
   open http://localhost:3000
   ```

4. **Memory Issues**
   ```bash
   # Edit configuration through simple CLI:
   ./exapg simple help  # Shows available commands
   
   # Or manually adjust settings in .env:
   COORDINATOR_MEMORY_LIMIT=16g
   SHARED_BUFFERS=4GB
   ```

---

**ExaPG** - Democratizing high-performance analytics with open-source technology.

*Built with ❤️ by the ExaPG community* 