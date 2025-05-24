# ExaPG Releases

## Latest Release

### Version 2.0.0 - Enterprise Benchmark Suite (May 24, 2024)

The 2.0.0 release represents a major milestone in ExaPG development with enterprise-grade features and professional tooling.

**🎯 Key Highlights:**
- **Enterprise Benchmark Suite** with industry-standard TPC-H, TPC-DS, and pgbench tests
- **Interactive CLI Interface** replacing multiple scripts with unified management
- **Professional Documentation** completely rewritten in English with modern structure
- **Real Performance Metrics** based on 2023-2024 database comparisons

**📥 Download:**
```bash
git clone https://github.com/DamienDrash/ExaPG.git --branch v2.0.0
cd ExaPG
./scripts/cli/exapg-cli.sh
```

**📚 Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md#200---2024-05-24)

---

## Stable Releases

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
./scripts/cli/exapg-cli.sh
```

### Specific Version

```bash
# Clone a specific version
git clone https://github.com/DamienDrash/ExaPG.git --branch v2.0.0
cd ExaPG

# Configure and start
cp .env.example .env
./scripts/cli/exapg-cli.sh
```

### Docker Installation

```bash
# Using Docker Compose
docker-compose up -d

# Or with specific deployment mode
./start-exapg.sh         # Single-node
./start-exapg-citus.sh   # Cluster mode
./start-exapg-ha.sh      # High availability
```

---

## Release Schedule

ExaPG follows a time-based release schedule:

- **Major Releases (x.0.0)**: Quarterly (with significant features)
- **Minor Releases (x.y.0)**: Monthly (with features and improvements)
- **Patch Releases (x.y.z)**: As needed (bug fixes and security updates)

### Upcoming Releases

- **v2.1.0** (June 2024): CI/CD integration, automated testing
- **v2.2.0** (July 2024): Cloud deployment templates
- **v3.0.0** (Q3 2024): Enterprise security features

---

## Support Policy

| Version | Status | Support Until |
|---------|--------|---------------|
| 2.0.x | **Current** | June 2025 |
| 1.5.x | Supported | December 2024 |
| 1.4.x | Supported | November 2024 |
| 1.3.x | Supported | October 2024 |
| 1.2.x | Maintenance | September 2024 |
| 1.1.x | Maintenance | August 2024 |
| 1.0.x | Maintenance | July 2024 |
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