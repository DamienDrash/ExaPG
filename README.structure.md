# ExaPG Projektstruktur

Die Projektstruktur von ExaPG wurde optimiert, um eine bessere Trennung von Komponenten und einfachere Wartung zu ermöglichen.

## Hauptordnerstruktur

```
exapg/
├── config/                 # Alle Konfigurationsdateien
│   ├── postgresql/         # PostgreSQL-spezifische Konfigurationen
│   └── init/               # Initialisierungsskripte
├── sql/                    # SQL-Funktionen und -Skripte
│   ├── analytics/          # Analytische Funktionen
│   ├── parallel/           # Parallelverarbeitungsfunktionen
│   └── partitioning/       # Partitionierungsfunktionen
├── scripts/                # Shell-Skripte
│   ├── setup/              # Setup- und Initialisierungsskripte
│   └── maintenance/        # Wartungsskripte
├── monitoring/             # Monitoring-Tools
│   ├── alertmanager/       # Alertmanager-Konfiguration
│   ├── grafana/            # Grafana-Dashboards und -Konfiguration
│   ├── postgres_exporter/  # PostgreSQL-Exporter-Konfiguration
│   └── prometheus/         # Prometheus-Konfiguration
├── pgbackrest/             # Backup-Konfiguration
│   └── conf/               # pgBackRest-Konfiguration
├── docker/                 # Docker-spezifische Dateien
│   ├── Dockerfile          # Basis-Dockerfile
│   ├── Dockerfile.citus    # Dockerfile für Citus-Extension
│   └── docker-compose/     # Docker-Compose-Konfigurationen
└── docs/                   # Dokumentation
    └── images/             # Bilder für die Dokumentation
```

## Beschreibung der Ordner

### /config
Enthält alle Konfigurationsdateien, die für PostgreSQL und die Initialisierung benötigt werden.
- `postgresql/`: PostgreSQL-Konfigurationsdateien (postgresql.conf, pg_hba.conf)
- `init/`: Initialisierungsskripte für Docker-Container

### /sql
Enthält alle SQL-Skripte, die in der Datenbank ausgeführt werden.
- `analytics/`: SQL-Funktionen für analytische Workloads (columnar storage, optimierte Aggregationen)
- `parallel/`: SQL-Funktionen für Parallelverarbeitung und optimierte Worker-Verteilung
- `partitioning/`: SQL-Funktionen für Datenpartitionierung (Zeit, Liste, Hash)

### /scripts
Enthält Shell-Skripte für Setup, Wartung und Betrieb.
- `setup/`: Initialisierungsskripte, die beim Start ausgeführt werden
- `maintenance/`: Skripte für Wartungsaufgaben (Backups, Überwachung, Bereinigung)

### /monitoring
Enthält Konfigurationen für das Monitoring-System.
- `alertmanager/`: Konfiguration für die Alerting-Komponente
- `grafana/`: Grafana-Dashboards und -Konfiguration
- `postgres_exporter/`: Konfiguration für den PostgreSQL-Metriken-Exporter
- `prometheus/`: Prometheus-Konfiguration für die Metrik-Sammlung

### /pgbackrest
Enthält die Konfiguration für die Backup-Lösung pgBackRest.
- `conf/`: pgBackRest-Konfigurationsdateien

### /docker
Enthält Docker-spezifische Dateien.
- `Dockerfile`: Basis-Dockerfile zum Erstellen des ExaPG-Images
- `Dockerfile.citus`: Dockerfile für die Citus-Erweiterung
- `docker-compose/`: Docker-Compose-Konfigurationen für verschiedene Deployment-Szenarien

### /docs
Enthält Dokumentation und Anleitungen.
- `images/`: Bilder für die Dokumentation

## Hauptstartkripte (im Wurzelverzeichnis)

- `start-exapg.sh`: Startet die Standard-ExaPG-Umgebung
- `start-exapg-fdw.sh`: Startet ExaPG mit Foreign Data Wrapper-Unterstützung
- `start-monitoring.sh`: Startet den Monitoring-Stack
- `stop-monitoring.sh`: Stoppt den Monitoring-Stack

## Abhängigkeiten

Alle Skripte und Konfigurationsdateien wurden aktualisiert, um die neue Ordnerstruktur zu berücksichtigen. Die Docker-Compose-Dateien referenzieren die neuen Pfade korrekt und alle Start-Skripte wurden angepasst. 