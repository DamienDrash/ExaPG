# 🚀 ExaPG - PostgreSQL Analytics Database

**ExaPG** ist eine hochperformante PostgreSQL-basierte Analytics-Datenbank, optimiert für Single-Node-Deployments mit Enterprise-Features.

## ✨ Features

- 🔥 **Single-Node Analytics**: Optimiert für hohe Performance ohne Cluster-Komplexität
- 📊 **JSON Analytics**: Vollständige JSONB-Unterstützung für moderne Datenstrukturen
- ⚡ **Performance**: JIT-Compilation und parallele Query-Verarbeitung
- 🗂️ **Time-Series**: Partitionierte Tabellen für Zeitreihendaten
- 🔍 **Full-Text Search**: Erweiterte Suchfunktionen mit pg_trgm
- 🛡️ **Enterprise Security**: MD5-Authentifizierung und SSL-Support
- 📈 **Monitoring**: Integrierte Performance-Überwachung
- 🧪 **Testing Framework**: Umfassende Test-Suite mit BATS
- 🎨 **Modern UI**: Nord Theme Enhanced mit semantischen Farben und visueller Hierarchie

## 🎨 Nord Theme Enhanced

ExaPG verfügt über ein professionelles **Nord Theme Enhanced v5.0** mit semantischer Farbkodierung:

### Semantische Farbstrategie
- 🔵 **CYAN** - Primäre Aktionen, Navigation, Titel
- 🔷 **BLUE** - Strukturelemente, Borders, Management
- 🟢 **GREEN** - Erfolg, positive Aktionen, OK-Buttons
- 🟡 **YELLOW** - Warnungen, Shortcuts, Aufmerksamkeit
- 🔴 **RED** - Fehler, kritische Aktionen, Exit-Warnungen
- 🟣 **MAGENTA** - Info, Hilfe, Spezialfunktionen

### Design-Features
- **Visuelle Hierarchie**: 4-stufige Farbhierarchie für bessere Orientierung
- **Semantische Buttons**: Grün für OK, Rot für Warnungen, Cyan für neutrale Aktionen
- **Intelligente Menü-Navigation**: Farbkodierte Kategorien und auffällige Nummerierung
- **Kontextuelle Anpassung**: Theme passt sich verschiedenen UI-Bereichen an
- **Barrierefreiheit**: WCAG-konforme Kontraste und High-Contrast-Variante

## 🚀 Quick Start

### 1. Single-Node Deployment

```bash
# Einfaches Deployment
./deploy-single-node.sh

# Oder mit CLI (empfohlen - zeigt Nord Theme)
./exapg
```

### 2. Datenbankverbindung

```bash
# Direkte Verbindung
psql -h localhost -p 5432 -U postgres

# Über Docker
docker exec -it exapg-coordinator psql -U postgres

# Über CLI
./exapg simple shell
```

### 3. Analytics testen

```sql
-- Analytics-Schema anzeigen
\dt analytics.*

-- Demo-Daten anzeigen
SELECT * FROM analytics.demo_events LIMIT 5;

-- JSON-Query
SELECT event_data->>'browser' as browser, COUNT(*) 
FROM analytics.demo_events 
WHERE event_data ? 'browser'
GROUP BY browser;
```

## 📁 Projektstruktur

```
exapg/
├── 📄 README.md                    # Diese Datei
├── 📄 LICENSE                      # MIT Lizenz
├── 📄 CHANGELOG.md                 # Versionshistorie
├── 📄 .env                         # Umgebungskonfiguration
├── 🔧 exapg                        # CLI Wrapper (Haupteinstieg)
├── 🚀 deploy-single-node.sh        # Deployment-Script
│
├── 📁 config/                      # Konfigurationsdateien
│   ├── postgresql/                 # PostgreSQL-Konfigurationen
│   ├── init/                       # Initialisierungs-Scripts
│   ├── ssl/                        # SSL-Zertifikate
│   └── profiles/                   # Deployment-Profile
│
├── 🐳 docker/                      # Docker-Konfigurationen
│   ├── docker-compose/             # Docker Compose Dateien
│   ├── Dockerfile                  # Multi-Stage Production Build
│   └── scripts/                    # Docker-spezifische Scripts
│
├── 📜 scripts/                     # Verwaltungs-Scripts
│   ├── cli/                        # CLI-Tools
│   │   ├── exapg                   # Haupt-CLI-Script
│   │   ├── terminal-ui.sh          # Dialog-Interface
│   │   └── nord-theme-enhanced.sh  # Nord Theme Optimierungen
│   ├── setup/                      # Setup-Scripts
│   ├── maintenance/                # Wartungs-Scripts
│   └── validation/                 # Validierungs-Scripts
│
├── 🗄️ sql/                         # SQL-Dateien
│   ├── analytics/                  # Analytics-Funktionen
│   ├── partitioning/               # Partitionierungs-Strategien
│   └── parallel/                   # Parallelisierungs-Funktionen
│
├── 🧪 tests/                       # Test-Suite
│   ├── unit/                       # Unit-Tests
│   ├── integration/                # Integrations-Tests
│   └── e2e/                        # End-to-End-Tests
│
├── 📊 benchmark/                   # Performance-Benchmarks
│   ├── benchmark-suite             # Benchmark-Tool
│   ├── configs/                    # Benchmark-Konfigurationen
│   └── results/                    # Benchmark-Ergebnisse
│
├── 📚 docs/                        # Dokumentation
│   ├── user-guide/                 # Benutzerhandbuch
│   ├── technical/                  # Technische Dokumentation
│   └── api/                        # API-Dokumentation
│
└── 📈 monitoring/                  # Monitoring-Stack
    ├── grafana/                    # Grafana-Dashboards
    ├── prometheus/                 # Prometheus-Konfiguration
    └── alertmanager/               # Alert-Konfiguration
```

## 🛠️ CLI-Tools

### Haupt-CLI mit Nord Theme

```bash
# Modern Dialog Interface (empfohlen) - zeigt Nord Theme Enhanced
./exapg

# Simple CLI Mode
./exapg simple [command]

# Verfügbare Commands:
./exapg simple deploy    # Cluster deployen
./exapg simple status    # Status prüfen
./exapg simple shell     # Datenbankverbindung
./exapg simple stop      # Services stoppen
./exapg simple test      # Tests ausführen
```

### Theme-Optimierungen

```bash
# Nord Theme Enhanced aktivieren/testen
./scripts/cli/nord-theme-enhanced.sh

# Theme-Einstellungen im CLI
./exapg
# → Wählen Sie "5" für "Theme Settings"
# → 4 professionelle Themes verfügbar
```

### Spezielle Tools

```bash
# Benchmark-Suite
./benchmark-suite

# Validierung
./scripts/validate-config.sh

# Tests ausführen
./tests/setup.sh && bats tests/
```

## 🧪 Testing & Qualitätssicherung

ExaPG verfügt über eine umfassende Test-Suite:

```bash
# Test-Framework installieren
./tests/setup.sh

# Unit-Tests
bats tests/unit/

# Integration-Tests
bats tests/integration/

# End-to-End-Tests (optional)
EXAPG_RUN_E2E_TESTS=true bats tests/e2e/

# Alle Tests
bats tests/
```

### Test-Kategorien

- **Unit-Tests**: CLI-Funktionen, Docker-Utils, Validierung
- **Integration-Tests**: Deployment-Workflows, Service-Integration
- **E2E-Tests**: Vollständige Deployment-Szenarien
- **Performance-Tests**: Benchmark-Suite für Performance-Regression
- **UI-Tests**: 100% Funktionalität aller 6 UI-Bereiche verifiziert

## 📊 Performance-Features

### Analytics-Optimierungen

- **JIT-Compilation**: Automatische Query-Optimierung
- **Parallel Processing**: Multi-Core-Nutzung für große Queries
- **Columnar Storage**: Effiziente Speicherung für Analytics
- **Partitioning**: Automatische Partitionierung für Time-Series

### Monitoring

- **pg_stat_statements**: Query-Performance-Tracking
- **Grafana Dashboards**: Visuelle Performance-Überwachung
- **Prometheus Metrics**: Systemmetriken und Alerts
- **Health Checks**: Automatische Systemüberwachung

## 🔧 Konfiguration

### Umgebungsvariablen (.env)

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

### Profile

ExaPG unterstützt verschiedene Deployment-Profile:

- `single-node-optimized`: Optimiert für Single-Node-Performance
- `development`: Entwicklungsumgebung mit Debug-Features
- `production`: Produktionsumgebung mit Security-Hardening

## 🚀 Deployment-Optionen

### 1. Single-Node (Empfohlen)

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
- **Database Performance**: Query-Performance, Connections
- **Analytics Metrics**: Custom Business Metrics

### Management UI

```bash
# Management UI starten
./exapg simple deploy
# Zugriff: http://localhost:3000
```

## 🛡️ Security

### Authentifizierung

- **MD5-Passwort-Authentifizierung**: Standard für lokale Verbindungen
- **SSL/TLS-Unterstützung**: Verschlüsselte Verbindungen
- **Role-Based Access Control**: Granulare Berechtigungen

### Security-Validierung

```bash
# Security-Check ausführen
./scripts/validate-config.sh --mode security
```

## 📚 Dokumentation

- **User Guide**: `docs/user-guide/`
- **Technical Docs**: `docs/technical/`
- **API Reference**: `docs/api/`
- **Integration Guide**: `docs/integration/`

## 🤝 Contributing

Siehe `CONTRIBUTING.md` für Entwicklungsrichtlinien.

## 📄 Lizenz

MIT License - siehe `LICENSE` Datei.

## 🆘 Support

- **Issues**: GitHub Issues für Bug-Reports
- **Discussions**: GitHub Discussions für Fragen
- **Documentation**: Vollständige Docs in `docs/`

---

**ExaPG v3.2.1** - Enterprise PostgreSQL Analytics Database  
🚀 **Produktionsbereit** | 🧪 **Vollständig getestet** | 📊 **Performance-optimiert** | ✅ **100% UI-Funktionalität verifiziert** | 🎨 **Nord Theme Enhanced v5.0** 