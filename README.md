# 🚀 ExaPG - PostgreSQL Analytics Database

**ExaPG** is a high-performance PostgreSQL-based analytics database, optimized for single-node deployments with enterprise features.

## ✨ Features

- 🔥 **Single-Node Analytics**: Optimized for high performance without cluster complexity
- 📊 **JSON Analytics**: Full JSONB support for modern data structures
- ⚡ **Performance**: JIT compilation and parallel query processing
- 🗂️ **Time-Series**: Partitioned tables for time-series data
- 🔍 **Full-Text Search**: Advanced search capabilities with pg_trgm
- 🛡️ **Enterprise Security**: MD5 authentication and SSL support
- 📈 **Monitoring**: Integrated performance monitoring
- 🧪 **Testing Framework**: Comprehensive test suite with BATS
- 🎨 **Modern UI**: Nord Theme Enhanced with semantic colors and visual hierarchy

## 🎨 Nord Theme Enhanced

ExaPG features a professional **Nord Theme Enhanced v5.0** with semantic color coding:

### Semantic Color Strategy
- 🔵 **CYAN** - Primary actions, navigation, titles
- 🔷 **BLUE** - Structural elements, borders, management
- 🟢 **GREEN** - Success, positive actions, OK buttons
- 🟡 **YELLOW** - Warnings, shortcuts, attention
- 🔴 **RED** - Errors, critical actions, exit warnings
- 🟣 **MAGENTA** - Info, help, special functions

### Design Features
- **Visual Hierarchy**: 4-level color hierarchy for better orientation
- **Semantic Buttons**: Green for OK, Red for warnings, Cyan for neutral actions
- **Intelligent Menu Navigation**: Color-coded categories with prominent numbering
- **Contextual Adaptation**: Theme adapts to different UI areas
- **Accessibility**: WCAG-compliant contrasts with High-Contrast variant

## 🚀 Quick Start

### 1. Single-Node Deployment

```bash
# Simple deployment
./deploy-single-node.sh

# Or with CLI (recommended - shows Nord Theme)
./exapg
```

### 2. Database Connection

```bash
# Direct connection
psql -h localhost -p 5432 -U postgres

# Via Docker
docker exec -it exapg-coordinator psql -U postgres

# Via CLI
./exapg simple shell
```

### 3. Test Analytics

```sql
-- Show analytics schema
\dt analytics.*

-- Show demo data
SELECT * FROM analytics.demo_events LIMIT 5;

-- JSON query
SELECT event_data->>'browser' as browser, COUNT(*) 
FROM analytics.demo_events 
WHERE event_data ? 'browser'
GROUP BY browser;
```

## 📁 Project Structure

```
exapg/
├── 📄 README.md                    # This file
├── 📄 LICENSE                      # MIT License
├── 📄 CHANGELOG.md                 # Version history
├── 📄 .env                         # Environment configuration
├── 🔧 exapg                        # CLI Wrapper (main entry point)
├── 🚀 deploy-single-node.sh        # Deployment script
│
├── 📁 config/                      # Configuration files
│   ├── postgresql/                 # PostgreSQL configurations
│   ├── init/                       # Initialization scripts
│   ├── ssl/                        # SSL certificates
│   └── profiles/                   # Deployment profiles
│
├── 🐳 docker/                      # Docker configurations
│   ├── docker-compose/             # Docker Compose files
│   ├── Dockerfile                  # Multi-stage production build
│   └── scripts/                    # Docker-specific scripts
│
├── 📜 scripts/                     # Management scripts
│   ├── cli/                        # CLI tools
│   │   ├── exapg                   # Main CLI script
│   │   ├── terminal-ui.sh          # Dialog interface
│   │   └── nord-theme-enhanced.sh  # Nord Theme optimizations
│   ├── setup/                      # Setup scripts
│   ├── maintenance/                # Maintenance scripts
│   └── validation/                 # Validation scripts
│
├── 🗄️ sql/                         # SQL files
│   ├── analytics/                  # Analytics functions
│   ├── partitioning/               # Partitioning strategies
│   └── parallel/                   # Parallelization functions
│
├── 🧪 tests/                       # Test suite
│   ├── unit/                       # Unit tests
│   ├── integration/                # Integration tests
│   └── e2e/                        # End-to-end tests
│
├── 📊 benchmark/                   # Performance benchmarks
│   ├── benchmark-suite             # Benchmark tool
│   ├── configs/                    # Benchmark configurations
│   └── results/                    # Benchmark results
│
├── 📚 docs/                        # Documentation
│   ├── user-guide/                 # User manual
│   ├── technical/                  # Technical documentation
│   └── api/                        # API documentation
│
└── 📈 monitoring/                  # Monitoring stack
    ├── grafana/                    # Grafana dashboards
    ├── prometheus/                 # Prometheus configuration
    └── alertmanager/               # Alert configuration
```

## 🛠️ CLI Tools

### Main CLI with Nord Theme

```bash
# Modern Dialog Interface (recommended) - shows Nord Theme Enhanced
./exapg

# Simple CLI Mode
./exapg simple [command]

# Available commands:
./exapg simple deploy    # Deploy cluster
./exapg simple status    # Check status
./exapg simple shell     # Database connection
./exapg simple stop      # Stop services
./exapg simple test      # Run tests
```

### Theme Optimizations

```bash
# Activate/test Nord Theme Enhanced
./scripts/cli/nord-theme-enhanced.sh

# Theme settings in CLI
./exapg
# → Select "5" for "Theme Settings"
# → 4 professional themes available
```

### Special Tools

```bash
# Benchmark Suite (with Nord Theme Enhanced)
./benchmark-suite

# Validation
./scripts/validate-config.sh

# Run tests
./tests/setup.sh && bats tests/
```

## 🧪 Testing & Quality Assurance

ExaPG features a comprehensive test suite:

```bash
# Install test framework
./tests/setup.sh

# Unit tests
bats tests/unit/

# Integration tests
bats tests/integration/

# End-to-end tests (optional)
EXAPG_RUN_E2E_TESTS=true bats tests/e2e/

# All tests
bats tests/
```

### Test Categories

- **Unit Tests**: CLI functions, Docker utils, validation
- **Integration Tests**: Deployment workflows, service integration
- **E2E Tests**: Complete deployment scenarios
- **Performance Tests**: Benchmark suite for performance regression
- **UI Tests**: 100% functionality of all 6 UI areas verified

## 📊 Performance Features

### Analytics Optimizations

- **JIT Compilation**: Automatic query optimization
- **Parallel Processing**: Multi-core utilization for large queries
- **Columnar Storage**: Efficient storage for analytics
- **Partitioning**: Automatic partitioning for time-series

### Monitoring

- **pg_stat_statements**: Query performance tracking
- **Grafana Dashboards**: Visual performance monitoring
- **Prometheus Metrics**: System metrics and alerts
- **Health Checks**: Automatic system monitoring

## 🔧 Configuration

### Environment Variables (.env)

```bash
# Database Configuration
POSTGRES_PASSWORD=postgres
COORDINATOR_PORT=5432

# Performance Settings
SHARED_BUFFERS=2GB
WORK_MEM=512MB
MAX_PARALLEL_WORKERS=8

# Features
ENABLE_MONITORING=true
ENABLE_MANAGEMENT_UI=true

# UI Theme (optional)
EXAPG_THEME=nord-dark-enhanced
```

### Profiles

ExaPG supports different deployment profiles:

- `single-node-optimized`: Optimized for single-node performance
- `development`: Development environment with debug features
- `production`: Production environment with security hardening

## 🚀 Deployment Options

### 1. Single-Node (Recommended)

```bash
./deploy-single-node.sh
```

### 2. Docker Compose

```bash
cd docker/docker-compose
docker-compose up -d
```

### 3. Kubernetes (K8s)

```bash
kubectl apply -f k8s/
```

## 📈 Monitoring & Management

### Grafana Dashboards

- **System Overview**: CPU, Memory, Disk I/O
- **Database Performance**: Query performance, connections
- **Analytics Metrics**: Custom business metrics

### Management UI

```bash
# Start Management UI
./exapg simple deploy
# Access: http://localhost:3000
```

## 🛡️ Security

### Authentication

- **MD5 Password Authentication**: Standard for local connections
- **SSL/TLS Support**: Encrypted connections
- **Role-Based Access Control**: Granular permissions

### Security Validation

```bash
# Run security check
./scripts/validate-config.sh --mode security
```

## 📚 Documentation

- **User Guide**: `docs/user-guide/`
- **Technical Docs**: `docs/technical/`
- **API Reference**: `docs/api/`
- **Integration Guide**: `docs/integration/`

## 🤝 Contributing

See `CONTRIBUTING.md` for development guidelines.

## 📄 License

MIT License - see `LICENSE` file.

## 🆘 Support

- **Issues**: GitHub Issues for bug reports
- **Discussions**: GitHub Discussions for questions
- **Documentation**: Complete docs in `docs/`

---

**ExaPG v3.2.2** - Enterprise PostgreSQL Analytics Database  
🚀 **Production Ready** | 🧪 **Fully Tested** | 📊 **Performance Optimized** | ✅ **100% UI Functionality Verified** | 🎨 **Nord Theme Enhanced v5.0** | 📊 **Benchmark Suite Integrated** 