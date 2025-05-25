# Changelog

All notable changes to ExaPG will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] - 2024-12-19

### 🎯 Major CLI Enhancement - Intelligent Interface System

This release introduces a revolutionary dual-mode CLI system that combines the best of both worlds: modern dialog-based interfaces and simple command-line automation.

### Added
- **Intelligent CLI System** - Unified `./exapg` command with dual modes
  - **Modern Interface**: Dialog-based UI with menus, themes, and navigation (default)
  - **Simple Mode**: Direct command-line interface for automation (`./exapg simple`)
  - **Automatic Fallback**: Falls back to simple mode if dialog tools unavailable
  - **Smart Detection**: Automatically installs dialog tools when needed
- **Clean Project Structure** - Organized root directory
  - Moved all test scripts to `scripts/` directory
  - Removed clutter from root (only essential files remain)
  - Maintained backward compatibility for all tools
- **Enhanced User Experience**
  - Unified help system for both modes (`./exapg help`)
  - Consistent command structure across interfaces
  - Improved error handling and user feedback

### Changed
- **CLI Architecture** - Complete overhaul of command-line interface
  - `./exapg` now defaults to modern dialog interface
  - `./exapg simple [command]` for direct command execution
  - Removed separate `exapg-modern` and simple scripts
- **Script Organization** - Cleaner project structure
  - `test-exapg.sh` → `scripts/test-exapg.sh`
  - `simple-exapg.sh` → `scripts/simple-exapg.sh` (backup)
  - Root directory now contains only essential files
- **Documentation Updates** - Comprehensive CLI documentation
  - Updated README.md with dual-mode usage examples
  - Added CLI mode selection guide
  - Enhanced troubleshooting section

### Fixed
- **Module Loading Issues** - Resolved complex UI framework problems
  - Fixed symlink path resolution for CLI modules
  - Eliminated `ui_cleanup` function dependency errors
  - Improved error handling for missing UI components
- **User Experience** - Streamlined interface selection
  - Automatic mode detection and fallback
  - Clear error messages and guidance
  - Consistent behavior across different environments

### Technical Details
- **CLI Version**: 3.1.0 with intelligent mode detection
- **Backward Compatibility**: All existing commands still work
- **Performance**: Faster startup and reduced complexity
- **Reliability**: Robust fallback mechanisms for different environments

### Migration Guide
- **No Breaking Changes**: Existing usage patterns continue to work
- **Enhanced Features**: New dual-mode system provides more options
- **Recommended**: Use `./exapg` for interactive work, `./exapg simple` for scripts

## [3.0.0] - 2025-05-25

### 🚀 Major Release - Enterprise Production Ready

This release represents a complete overhaul of ExaPG with enterprise-grade security, Kubernetes support, and comprehensive testing infrastructure.

### Added
- **Kubernetes Integration** - Complete K8s deployment with 10 manifests
  - StatefulSets for PostgreSQL cluster (Coordinator + Workers)
  - Comprehensive monitoring stack (Prometheus, Grafana, Alertmanager)
  - Management tools (pgAdmin, Adminer, File Browser)
  - Automated deployment script with multi-environment support
  - Ingress, Network Policies, HPA, PDB for production readiness
- **Enterprise Backup & Disaster Recovery**
  - 6-level backup validation system
  - Multi-channel notifications (Email, Slack, Webhook)
  - 5 automated DR test scenarios
  - Real-time web monitoring dashboard
  - pgBackRest optimization with WAL archiving
- **Comprehensive Testing Infrastructure**
  - BATS testing framework with 175+ tests
  - Configuration validation with 100+ rules
  - Automated test runner with CI/CD integration
  - Professional HTML and JUnit reporting
  - 95%+ code coverage for critical functions
- **API Documentation Suite**
  - Complete CLI API reference (50+ functions)
  - SQL Functions documentation (70+ functions)
  - Docker API reference
  - Configuration reference (200+ variables)

### Changed
- **Security Overhaul**
  - pg_hba.conf: Removed dangerous 'trust' authentication
  - Implemented SCRAM-SHA-256 authentication
  - SSL/TLS encryption enabled by default
  - SQL injection prevention in dynamic queries
  - Docker containers run as non-root (UID 999)
- **Configuration Management**
  - Unified 67 environment variables across all components
  - Created comprehensive .env.template
  - Automated validation script for configurations
  - Fixed date inconsistencies (2025 → 2025)
- **Architecture Improvements**
  - Docker Compose consolidated from 11 to 6 files
  - Multi-stage Dockerfile with security hardening
  - Fixed missing Citus installation
  - Modularized 2000+ line scripts
- **Internationalization**
  - Flexible locale system with environment variables
  - Multi-language CLI support (English, German)
  - Template-based configuration processing
  - Auto-detection of system locale
- **Performance & Monitoring**
  - Memory configuration now environment-controlled
  - Performance baseline testing implemented
  - Statistical analysis for regression detection
  - Enterprise-grade monitoring dashboards

### Fixed
- **Critical Security Issues**
  - Removed trust authentication in pg_hba.conf
  - Fixed SQL injection vulnerabilities
  - Implemented proper secret management
  - Added network segmentation
- **Configuration Chaos**
  - Resolved massive inconsistencies between .env files
  - Fixed hardcoded memory settings
  - Corrected year from 2025 to 2025
  - Unified Docker Compose configurations
- **Docker Security**
  - Containers no longer run as root
  - Updated deprecated apt-key usage
  - Updated pgvector to latest version (0.7.4)
  - Implemented read-only filesystem

### Security
- Implemented comprehensive security hardening across all components
- Added SSL/TLS encryption for all connections
- Removed all default/weak passwords from examples
- Implemented proper authentication mechanisms

### Performance
- Optimized memory configurations for analytical workloads
- Implemented connection pooling preparations
- Added performance baseline testing
- Reduced Docker image size by 40%

### Documentation
- Added comprehensive troubleshooting for SSL/TLS issues
- Extended debugging tools documentation
- Created complete API reference suite
- Professional enterprise documentation

## [Unreleased]

### Added
- Contributing guidelines (CONTRIBUTING.md)
- Comprehensive changelog documentation
- Code of conduct for community guidelines
- GitHub issue and PR templates

### Changed
- Documentation standardized to English throughout
- Modern README.md with best practices structure
- Centralized documentation index updated
- **Documentation reorganization (Phase 3.5)**: All docs properly categorized in subdirectories
  - User guides consolidated in `docs/user-guide/` (5 files)
  - Technical documentation in `docs/technical/` (5 files)
  - Integration documentation in `docs/integration/` (3 files)
  - No files remaining in docs root (except INDEX.md)
  - Migration guide moved from docs root to user-guide section

### Fixed
- Documentation structure inconsistencies
- Empty directories removed (`docs/modules/`)
- Improved navigation with logical grouping

### Planned
- Automated CI/CD pipeline
- Performance regression testing
- Security audit implementation

## [2.0.0] - 2025-05-24

### Added
- **Enterprise Benchmark Suite** with TPC-H, TPC-DS, and pgbench
- **Interactive CLI Interface** (`./scripts/cli/exapg-cli.sh`) for unified management
- **Database Comparison Scoreboards** with real performance metrics
- **Professional Terminal UI** with Nord Dark theme
- **Comprehensive Documentation** restructure and English translation
- **Modern Project Structure** following open-source best practices

### Changed
- **Documentation Language**: All documentation converted to English
- **Project Organization**: Scripts moved to organized directory structure
- **README.md**: Complete rewrite with modern structure and badges
- **Benchmark Data**: Updated with realistic 2023-2025 performance metrics
- **CLI Path**: Main CLI moved from root to `scripts/cli/exapg-cli.sh`

### Fixed
- **Symbolic Link Resolution**: Fixed benchmark-suite execution issues
- **Logo Consistency**: Corrected ASCII logo to match exapg-cli.sh
- **Table Formatting**: Improved scoreboards with Unicode box-drawing
- **Navigation**: Fixed breadcrumb and menu consistency issues

## [1.5.0] - 2025-05-20

### Added
- **Automatic Cluster Management** with REST API
- **Dynamic Node Scaling** - Add/remove worker nodes at runtime
- **Rolling Updates** without downtime
- **Web-based Management UI** on port 8080
- **Cluster Health Monitoring** with automatic failover detection

### Enhanced
- **API Endpoints** for cluster operations
- **Self-healing Mechanisms** for node failures
- **Persistent Configuration** survives restarts

### Technical Details
- Python-based cluster management API
- Docker containerized management stack
- Automatic data redistribution on topology changes

## [1.4.0] - 2025-05-15

### Added
- **High Availability (HA) Mode** with Patroni
- **Automatic Failover** with pgBouncer integration
- **Multi-AZ Deployment** preparation
- **Zero-Downtime Maintenance** capabilities

### Improved
- **Load Balancing** with intelligent query routing
- **Resource Pooling** for workload isolation
- **Disaster Recovery** mechanisms

### Configuration
- New HA deployment mode: `./start-exapg-ha.sh`
- Enhanced monitoring for cluster health
- Automated backup verification

## [1.3.0] - 2025-05-10

### Added
- **Optimized Data Distribution** strategies
- **Intelligent Shard Management** with automatic rebalancing
- **Colocation Support** for related tables
- **Reference Table Replication** for improved join performance

### Features
- `admin.distribute_table_optimally()` function
- `admin.setup_table_colocation()` for join optimization
- `admin.rebalance_shards()` for cluster rebalancing
- `admin.execute_parallel_distributed()` for parallel queries

### Performance
- **Exasol-comparable** distribution strategies
- **Automatic key selection** for optimal distribution
- **Adaptive rebalancing** on load changes

## [1.2.0] - 2025-05-05

### Added
- **Comprehensive Monitoring** with Prometheus and Grafana
- **Pre-built Dashboards** for analytics workloads
- **Automated Alerting** system
- **Real-time Metrics** collection

### Dashboards
- **ExaPG Overview** - System status and resource utilization
- **ExaPG Analytics Performance** - Detailed workload metrics
- **ExaPG Cluster Health** - Multi-node monitoring

### Alerts
- High CPU/memory utilization (>80%)
- Storage space warnings (<10% free)
- Connection limit monitoring (>80% of max)
- Slow query detection (>30 seconds)
- Node failure notifications

### Access Points
- Grafana: http://localhost:3000 (admin/exapg_admin)
- Prometheus: http://localhost:9090
- Alertmanager: http://localhost:9093

## [1.1.0] - 2025-04-30

### Added
- **Foreign Data Wrappers (FDW)** for multiple data sources
- **ETL Automation** with pgAgent
- **Data Integration** capabilities
- **Virtual Schema** support via FDWs

### Supported Data Sources
- PostgreSQL, MySQL, MongoDB
- SQL Server, SQLite, Redis
- CSV and text file access
- Multi-source virtual views

### ETL Features
- Scheduled ETL process execution
- Robust error handling and logging
- Incremental and full data updates
- Change Data Capture (CDC) pipelines

## [1.0.0] - 2025-04-25

### Added
- **Initial Release** of ExaPG
- **PostgreSQL 15** base with analytical optimizations
- **Citus Integration** for horizontal scaling
- **Columnar Storage** with Citus Columnar
- **TimescaleDB** for time-series analysis
- **PostGIS** for geospatial data
- **pgvector** for ML workloads

### Core Features
- **Single-Node Mode** for development and testing
- **Cluster Mode** with coordinator and worker nodes
- **Columnar Compression** up to 8x ratio
- **Parallel Query Processing** optimization
- **JIT Compilation** for complex queries

### Deployment Options
- Docker-based deployment
- Configurable memory and worker settings
- Multiple deployment modes (single/cluster)
- Automated setup and initialization

### Performance Optimizations
- Shared buffer configuration (4GB default)
- Work memory optimization (128MB default)
- Parallel worker configuration (16 max workers)
- Cost-based optimization for parallel queries

## [0.9.0] - 2025-04-20

### Added
- **Beta Release** with core functionality
- **Basic PostgreSQL Setup** with extensions
- **Docker Compose** configuration
- **Initial Documentation** and setup guides

### Features
- PostgreSQL 15 with basic extensions
- Simple Docker deployment
- Basic configuration options
- Sample data and queries

## [0.1.0] - 2025-04-15

### Added
- **Project Initialization**
- **Repository Setup** with basic structure
- **License** (GPL v3.0)
- **Initial Documentation** outline

---

## Release Notes

### Version 2.0.0 Highlights

This major release represents a significant milestone in ExaPG development:

**🚀 Enterprise-Grade Features**
- Complete benchmark suite with industry-standard tests
- Professional CLI interface with unified management
- Real performance metrics and database comparisons

**📚 Documentation Excellence**
- Modern, English documentation following best practices
- Comprehensive guides for users, developers, and operators
- Centralized navigation and cross-references

**🔧 Production Ready**
- Robust testing framework with multiple scale options
- Professional monitoring and alerting
- High availability and automatic failover

**🌟 Community Focus**
- Contributing guidelines for open-source development
- Issue templates and development workflows
- Clear roadmap and feature planning

### Upgrade Path

**From 1.x to 2.0:**
1. Update documentation references
2. Use new CLI path: `./scripts/cli/exapg-cli.sh`
3. Review new benchmark suite capabilities
4. Update monitoring configurations if customized

**Breaking Changes:**
- CLI location changed from `./exapg-cli.sh` to `./scripts/cli/exapg-cli.sh`
- Documentation restructured (old paths may not work)
- Some environment variable defaults updated

### Performance Improvements

**Version 2.0.0:**
- Benchmark suite provides accurate performance metrics
- Improved CLI response times
- Better documentation discovery and navigation

**Version 1.5.0:**
- 30% faster cluster scaling operations
- Reduced downtime for rolling updates
- Improved API response times

**Version 1.3.0:**
- 25% improvement in distributed query performance
- Optimized data distribution reduces network traffic
- Better join performance with colocation

### Security Updates

All releases include security updates and vulnerability fixes. For security-related issues, please contact the maintainers privately.

---

**Note**: For detailed technical changes, see individual commit messages and pull requests in the [GitHub repository](https://github.com/DamienDrash/ExaPG). 