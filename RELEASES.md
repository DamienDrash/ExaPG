# ExaPG Releases

## Latest Release

### Version 3.0.0 - Enterprise Production Ready (December 19, 2024)

The 3.0.0 release is a major milestone that transforms ExaPG into an enterprise-grade analytical database platform with production-ready security, Kubernetes support, and comprehensive testing.

**🎯 Key Highlights:**
- **Kubernetes Native** - Complete K8s deployment with StatefulSets, monitoring, and management tools
- **Enterprise Security** - SCRAM-SHA-256 auth, SSL/TLS encryption, non-root containers
- **Production Ready** - 175+ automated tests, disaster recovery, professional monitoring
- **Cloud Native** - Multi-environment support, GitOps ready, horizontal scaling

**📥 Download:**
```bash
git clone https://github.com/DamienDrash/ExaPG.git --branch v3.0.0
cd ExaPG
./exapg
```

**🚀 Kubernetes Deployment:**
```bash
cd k8s
./deploy.sh prod --all
```

**📚 Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md#300---2024-12-19)

---

## Stable Releases

### Version 2.0.0 - Enterprise Benchmark Suite (May 24, 2024)

The 2.0.0 release introduced enterprise-grade features and professional tooling.

**Features:**
- Enterprise Benchmark Suite with TPC-H, TPC-DS, pgbench
- Interactive CLI Interface for unified management
- Professional documentation in English
- Real performance metrics and comparisons

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v2.0.0`

### Version 1.5.0 - Automatic Cluster Management (May 20, 2024)

**Features:**
- Dynamic cluster scaling with REST API
- Rolling updates without downtime
- Web-based management UI
- Self-healing mechanisms

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.5.0`

### Version 1.4.0 - High Availability (May 15, 2024)

**Features:**
- High availability with Patroni
- Automatic failover
- Zero-downtime maintenance
- pgBouncer integration

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.4.0`

### Version 1.3.0 - Optimized Distribution (May 10, 2024)

**Features:**
- Intelligent data distribution
- Automatic shard rebalancing
- Join optimization with colocation
- Parallel query execution

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.3.0`

### Version 1.2.0 - Monitoring Stack (May 5, 2024)

**Features:**
- Prometheus and Grafana integration
- Pre-built analytical dashboards
- Automated alerting system
- Real-time performance metrics

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.2.0`

### Version 1.1.0 - Data Integration (April 30, 2024)

**Features:**
- Foreign Data Wrappers for multiple sources
- ETL automation with pgAgent
- Virtual schema support
- CDC pipeline implementation

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.1.0`

### Version 1.0.0 - Initial Release (April 25, 2024)

**Features:**
- PostgreSQL 15 with analytical optimizations
- Citus integration for horizontal scaling
- Columnar storage with 8x compression
- TimescaleDB, PostGIS, pgvector extensions

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.0.0`

---

## Pre-Releases

### Version 0.9.0 - Beta (April 20, 2024)
- Core functionality implementation
- Basic Docker deployment
- Initial documentation

### Version 0.1.0 - Alpha (April 15, 2024)
- Project initialization
- Repository structure setup

---

## Installation

### Quick Start (Latest Release)

```bash
# Clone the latest release
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG

# Start with interactive CLI
./exapg
```

### Specific Version

```bash
# Clone a specific version
git clone https://github.com/DamienDrash/ExaPG.git --branch v2.0.0
cd ExaPG

# Configure and start
cp .env.example .env
./exapg
```

### Docker Installation

```bash
# Start with the interactive CLI and select deployment mode
./exapg
# Option 1: ExaPG Standard (Single-node)
# Option 2: ExaPG Citus (Cluster mode)
# Option 3: ExaPG HA (High availability)

# For advanced users who prefer direct docker-compose:
docker-compose up -d
```

---

## Release Schedule

ExaPG follows a time-based release schedule:

- **Major Releases (x.0.0)**: Quarterly (with significant features)
- **Minor Releases (x.y.0)**: Monthly (with features and improvements)
- **Patch Releases (x.y.z)**: As needed (bug fixes and security updates)

### Upcoming Releases

- **v3.1.0** (January 2025): Connection pooling, advanced health checks
- **v3.2.0** (February 2025): CloudNativePG operator integration
- **v4.0.0** (Q2 2025): Service mesh integration, multi-region support

---

## Support Policy

| Version | Status | Support Until |
|---------|--------|---------------|
| 3.0.x | **Current** | December 2025 |
| 2.0.x | Supported | June 2025 |
| 1.5.x | Supported | December 2024 |
| 1.4.x | Maintenance | November 2024 |
| 1.3.x | Maintenance | October 2024 |
| 1.2.x | End of Life | - |
| 1.1.x | End of Life | - |
| 1.0.x | End of Life | - |
| < 1.0 | End of Life | - |

**Support Levels:**
- **Current**: Active development, all fixes
- **Supported**: Security and critical bug fixes
- **Maintenance**: Security fixes only
- **End of Life**: No updates

---

## Verify Releases

### Using Git Tags

```bash
# List all available versions
git tag -l

# Verify a specific tag
git tag -v v2.0.0
```

### Checksums

Release checksums are available in the GitHub release assets.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on:
- Development setup
- Testing procedures  
- Pull request process
- Release procedures

---

## More Information

- **Full Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Documentation**: [docs/INDEX.md](docs/INDEX.md)
- **Roadmap**: See [GitHub Issues](https://github.com/DamienDrash/ExaPG/issues)
- **Support**: [GitHub Discussions](https://github.com/DamienDrash/ExaPG/discussions)

---

*For the latest updates, star and watch the [ExaPG repository](https://github.com/DamienDrash/ExaPG).* 