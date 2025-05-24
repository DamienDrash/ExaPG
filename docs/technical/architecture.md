# ExaPG Projektstruktur

Die Projektstruktur von ExaPG wurde optimiert, um eine bessere Trennung von Komponenten und einfachere Wartung zu ermöglichen.

## Hauptordnerstruktur

```
exapg/
├── config/                 # Alle Konfigurationsdateien
│   ├── postgresql/         # PostgreSQL-spezifische Konfigurationen
│   ├── init/               # Initialisierungsskripte
│   ├── ha/                 # Hochverfügbarkeitskonfiguration
│   └── pgbouncer/          # PgBouncer-Konfiguration
├── sql/                    # SQL-Funktionen und -Skripte
│   ├── analytics/          # Analytische Funktionen
│   ├── parallel/           # Parallelverarbeitungsfunktionen
│   ├── partitioning/       # Partitionierungsfunktionen
│   ├── distribution/       # Verteilungsstrategien für Cluster
│   ├── etl/                # ETL-bezogene SQL-Funktionen
│   ├── compat/             # Kompatibilitätsfunktionen für Exasol
│   ├── udf_framework/      # User-Defined Functions Framework
│   │   ├── lua/            # Lua-Funktionen
│   │   ├── python/         # Python-Funktionen
│   │   └── r/              # R-Funktionen
│   └── virtual_schemas/    # Virtual Schema SQL-Funktionen
├── scripts/                # Shell-Skripte
│   ├── setup/              # Start/Stop-Skripte (migriert)
│   ├── maintenance/        # Wartungsskripte
│   ├── cli/                # CLI-Funktionalität
│   ├── optimization/       # Optimierungsskripte
│   ├── performance/        # Performance-Test-Skripte
│   ├── init/               # Initialisierungsskripte
│   ├── etl/                # ETL-Skripte
│   ├── migration/          # Migrationsskripte
│   ├── cluster-management/ # Cluster-Management-Skripte
│   └── original-scripts/   # Archiv für ursprüngliche Skripte
├── monitoring/             # Monitoring-Tools
│   ├── alertmanager/       # Alertmanager-Konfiguration
│   ├── grafana/            # Grafana-Dashboards und -Konfiguration
│   │   ├── dashboards/     # Grafana-Dashboards
│   │   └── provisioning/   # Grafana-Provisioning-Konfiguration
│   ├── postgres_exporter/  # PostgreSQL-Exporter-Konfiguration
│   └── prometheus/         # Prometheus-Konfiguration
├── pgbackrest/             # Backup-Konfiguration
│   ├── conf/               # pgBackRest-Konfiguration
│   └── scripts/            # pgBackRest-Skripte
├── docker/                 # Docker-spezifische Dateien
│   ├── docker-compose/     # Docker-Compose-Konfigurationen
│   └── Dockerfiles für verschiedene Komponenten
├── management-ui/          # Web-basierte Verwaltungsoberfläche
│   ├── backend/            # Backend-Code
│   └── frontend/           # Frontend-Code
└── docs/                   # Dokumentation
    └── images/             # Bilder für die Dokumentation
```

## Beschreibung der Ordner

### /config
Enthält alle Konfigurationsdateien, die für PostgreSQL und die Initialisierung benötigt werden.
- `postgresql/`: PostgreSQL-Konfigurationsdateien (postgresql.conf, pg_hba.conf)
- `init/`: Initialisierungsskripte für Docker-Container
- `ha/`: Konfigurationen für Hochverfügbarkeit (Patroni, etc.)
- `pgbouncer/`: Konfigurationen für PgBouncer

### /sql
Enthält alle SQL-Skripte, die in der Datenbank ausgeführt werden.
- `analytics/`: SQL-Funktionen für analytische Workloads (columnar storage, optimierte Aggregationen)
- `parallel/`: SQL-Funktionen für Parallelverarbeitung und optimierte Worker-Verteilung
- `partitioning/`: SQL-Funktionen für Datenpartitionierung (Zeit, Liste, Hash)
- `distribution/`: SQL-Funktionen für die Verteilung von Daten auf Cluster-Knoten
- `etl/`: ETL-bezogene SQL-Funktionen
- `compat/`: Kompatibilitätsfunktionen für Exasol
- `udf_framework/`: Framework für benutzerdefinierte Funktionen (Lua, Python, R)
- `virtual_schemas/`: SQL-Funktionen für virtuelle Schemata

### /scripts
Enthält Shell-Skripte für Setup, Wartung und Betrieb.
- `setup/`: Migrierte Start/Stop-Skripte
- `maintenance/`: Skripte für Wartungsaufgaben (Backups, Überwachung, Bereinigung)
- `cli/`: Skripte für die Kommandozeilenschnittstelle
- `optimization/`: Skripte für Performance-Optimierungen
- `performance/`: Skripte für Performance-Tests
- `init/`: Skripte für die Initialisierung der Datenbank
- `etl/`: Skripte für ETL-Prozesse
- `migration/`: Skripte für Datenmigration
- `cluster-management/`: Skripte für Cluster-Management
- `original-scripts/`: Archiv für ursprüngliche Skripte

### /monitoring
Enthält Konfigurationen für das Monitoring-System.
- `alertmanager/`: Konfiguration für die Alerting-Komponente
- `grafana/`: Grafana-Dashboards und -Konfiguration
- `postgres_exporter/`: Konfiguration für den PostgreSQL-Metriken-Exporter
- `prometheus/`: Prometheus-Konfiguration für die Metrik-Sammlung

### /pgbackrest
Enthält die Konfiguration für die Backup-Lösung pgBackRest.
- `conf/`: pgBackRest-Konfigurationsdateien
- `scripts/`: Skripte für pgBackRest

### /docker
Enthält Docker-spezifische Dateien.
- Verschiedene Dockerfiles für spezifische Umgebungen (Standard, Citus, FDW, etc.)
- `docker-compose/`: Docker-Compose-Konfigurationen für verschiedene Deployment-Szenarien

### /management-ui
Enthält den Code für die webbasierte Verwaltungsoberfläche.
- `backend/`: Backend-Code (API, Datenbankzugriff)
- `frontend/`: Frontend-Code (React-Anwendung)

### /docs
Enthält Dokumentation und Anleitungen.
- `images/`: Bilder für die Dokumentation

## Hauptstruktur

- `exapg-cli.sh`: Zentrale CLI-Steuerung für alle ExaPG-Komponenten
- `exapg`: Symbolischer Link zur CLI für einfachen Zugriff

Die historischen Start- und Stopp-Skripte wurden aus dem Hauptverzeichnis entfernt und sind als Original-Versionen in `scripts/setup/` archiviert.

## Abhängigkeiten

Alle Skripte und Konfigurationsdateien wurden aktualisiert, um die neue Ordnerstruktur zu berücksichtigen. Die Docker-Compose-Dateien referenzieren die neuen Pfade korrekt und alle Start-Skripte wurden angepasst. 