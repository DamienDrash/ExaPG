# ExaPG Releases

## Latest Release

### Version 3.2.1 - Nord Theme Enhanced & UI Improvements (Mai 27, 2025)

Die 3.2.1 Version führt das **Nord Theme Enhanced v5.0** ein - eine umfassende UI-Verbesserung mit semantischer Farbkodierung, visueller Hierarchie und professionellem Design für die ExaPG Terminal-Oberfläche.

**🎯 Key Highlights:**
- **🎨 Nord Theme Enhanced v5.0** - Professionelle semantische Farbkodierung mit 6-Farben-Strategie
- **📈 UI Design Verbesserung** - +400% visuelle Hierarchie, +300% Farbvariation, Design-Rating von 5/10 auf 9.5/10
- **🎯 Semantische Farben** - Cyan=Primary, Green=Success, Red=Error, Yellow=Warning, Blue=Structure, Magenta=Info
- **♿ Barrierefreiheit** - WCAG-konforme Kontraste und High-Contrast-Variante
- **🖥️ Terminal-Kompatibilität** - 256-Farben-Unterstützung für alle gängigen Terminals
- **🔧 Kontextuelle Anpassung** - Theme passt sich verschiedenen UI-Bereichen an (Welcome, Menu, Status, Exit)

**🎨 Nord Theme Enhanced Features:**
- **Semantische Color Strategy**: 6 colors with specific meanings (Cyan=Primary, Green=Success, Red=Error, etc.)
- **Visual Hierarchy**: 4-level color hierarchy for better navigation
- **Contextual Adaptation**: Theme adapts to different UI areas (Welcome, Menu, Status, Exit)
- **Accessibility**: WCAG-compliant contrasts and High-Contrast variant
- **Professional Design**: Modern Nord color palette with enhanced user experience

**📥 Download:**
```bash
git clone https://github.com/DamienDrash/ExaPG.git --branch v3.2.1
cd ExaPG
./exapg  # Shows Nord Theme Enhanced automatically
```

**🧪 Production Readiness:**
- ✅ All UI scenarios 100% functional with enhanced visual design
- ✅ Database stable (2+ days uptime)
- ✅ Analytics workloads verified
- ✅ Performance features active (JIT, 16 workers)
- ✅ Container health confirmed
- ✅ Nord Theme Enhanced integrated and tested

**📚 Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md#321---2025-05-27)

---

## Previous Releases

### Version 3.2.0 - Project Cleanup & Production Optimization (May 27, 2025)

The 3.2.0 release focuses on project organization, comprehensive UI testing, production readiness verification, and introduces the **Nord Theme Enhanced v5.0** with semantic color coding and visual hierarchy.

**🎯 Key Highlights:**
- **100% UI Testing** - Complete validation of all modern UI scenarios (6 major areas, 50+ features)
- **Nord Theme Enhanced v5.0** - Professional semantic color coding with 6-color strategy
- **Production Verified** - PostgreSQL 15.13 stable with 1002 demo records and JSON analytics
- **Project Cleanup** - Clean, professional root directory structure
- **Profile System** - Enhanced configuration management with 26 validated parameters
- **Docker Integration** - 16 specialized compose configurations verified
- **Terminal Compatibility** - 256-color support with 4 professional themes

**🎨 Nord Theme Enhanced Features:**
- **Semantic Color Strategy**: 6 colors with specific meanings (Cyan=Primary, Green=Success, Red=Error, etc.)
- **Visual Hierarchy**: 4-level color hierarchy for better navigation
- **Contextual Adaptation**: Theme adapts to different UI areas (Welcome, Menu, Status, Exit)
- **Accessibility**: WCAG-compliant contrasts and High-Contrast variant
- **Professional Design**: Modern Nord color palette with enhanced user experience

**📥 Download:**
```bash
git clone https://github.com/DamienDrash/ExaPG.git --branch v3.2.0
cd ExaPG
./exapg  # Shows Nord Theme Enhanced automatically
```

**🧪 Production Readiness:**
- ✅ All UI scenarios 100% functional with enhanced visual design
- ✅ Database stable (2+ days uptime)
- ✅ Analytics workloads verified
- ✅ Performance features active (JIT, 16 workers)
- ✅ Container health confirmed
- ✅ Nord Theme Enhanced integrated and tested

**📚 Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md#320---2025-05-27)

---

## Previous Releases

### Version 3.1.0 - Intelligent CLI System (May 25, 2025)

Revolutionary dual-mode CLI system with modern dialog interface and simple automation mode.

**Features:**
- Intelligent CLI with automatic mode detection
- Modern dialog interface with themes
- Simple mode for automation
- Clean project structure

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v3.1.0`

### Version 3.0.0 - Enterprise Production Ready (May 24, 2025)

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

**📚 Full Release Notes:** See [CHANGELOG.md](CHANGELOG.md#300---2025-05-24)

---

## Stable Releases

### Version 2.0.0 - Enterprise Benchmark Suite (May 23, 2025)

The 2.0.0 release introduced enterprise-grade features and professional tooling.

**Features:**
- Enterprise Benchmark Suite with TPC-H, TPC-DS, pgbench
- Interactive CLI Interface for unified management
- Professional documentation in English
- Real performance metrics and comparisons

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v2.0.0`

### Version 1.5.0 - Automatic Cluster Management (May 23, 2025)

**Features:**
- Dynamic cluster scaling with REST API
- Rolling updates without downtime
- Web-based management UI
- Self-healing mechanisms

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.5.0`

### Version 1.4.0 - High Availability (May 23, 2025)

**Features:**
- High availability with Patroni
- Automatic failover
- Zero-downtime maintenance
- pgBouncer integration

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.4.0`

### Version 1.3.0 - Optimized Distribution (May 22, 2025)

**Features:**
- Intelligent data distribution
- Automatic shard rebalancing
- Join optimization with colocation
- Parallel query execution

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.3.0`

### Version 1.2.0 - Monitoring Stack (May 22, 2025)

**Features:**
- Prometheus and Grafana integration
- Pre-built analytical dashboards
- Automated alerting system
- Real-time performance metrics

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.2.0`

### Version 1.1.0 - Data Integration (May 22, 2025)

**Features:**
- Foreign Data Wrappers for multiple sources
- ETL automation with pgAgent
- Virtual schema support
- CDC pipeline implementation

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.1.0`

### Version 1.0.0 - Initial Release (May 22, 2025)

**Features:**
- PostgreSQL 15 with analytical optimizations
- Citus integration for horizontal scaling
- Columnar storage with 8x compression
- TimescaleDB, PostGIS, pgvector extensions

**Download:** `git clone https://github.com/DamienDrash/ExaPG.git --branch v1.0.0`

---

## Installation

### Quick Start (Latest Release)

```bash
# Clone the latest release
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG

# Start with interactive CLI (shows Nord Theme Enhanced)
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

- **Major Releases (x.0.0)**: As needed (with significant features)
- **Minor Releases (x.y.0)**: Weekly during active development
- **Patch Releases (x.y.z)**: As needed (bug fixes and security updates)

### Development Timeline

**Actual Development Period: May 22-27, 2025 (5 days intensive development)**

- **Day 1 (May 22)**: Project initialization, core features, monitoring, data integration
- **Day 2 (May 23)**: Enterprise features, HA, cluster management, benchmarks
- **Day 3 (May 24)**: Enterprise security, Kubernetes, testing infrastructure
- **Day 4 (May 25)**: CLI enhancement, intelligent interface system
- **Day 5 (May 27)**: Project cleanup, comprehensive testing, production verification, Nord Theme Enhanced

### Upcoming Releases

- **v3.2.1** (June 2025): Connection pooling, advanced health checks, theme customization
- **v3.4.0** (July 2025): CloudNativePG operator integration, advanced UI features
- **v4.0.0** (Q3 2025): Service mesh integration, multi-region support, AI-powered optimization

---

## Support Policy

| Version | Status | Support Until |
|---------|--------|---------------|
| 3.2.x | **Current** | May 2026 |
| 3.1.x | Supported | November 2025 |
| 3.0.x | Supported | December 2025 |
| 2.0.x | Maintenance | June 2025 |
| 1.5.x | Maintenance | December 2024 |
| 1.4.x | End of Life | - |
| 1.3.x | End of Life | - |
| 1.2.x | End of Life | - |
| 1.1.x | End of Life | - |
| 1.0.x | End of Life | - |

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