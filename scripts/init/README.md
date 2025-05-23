# Initialisierungsskripte

Dieses Verzeichnis enthält Skripte und SQL-Dateien zur Initialisierung und Konfiguration der ExaPG-Datenbankumgebungen.

## Übersicht

Die Initialisierungsskripte sind für die Ersteinrichtung verschiedener ExaPG-Komponenten zuständig. Sie werden beim Start der Container ausgeführt und führen grundlegende Konfigurationen und Setups durch.

## Inhalt

### Shell-Skripte
- **init-db.sh**: Grundlegende Datenbankinitialisierung
- **init-analytics.sh**: Initialisierung der analytischen Funktionen
- **init-coordinator.sh**: Einrichtung des Koordinator-Knotens in einem Cluster
- **init-worker.sh**: Einrichtung der Worker-Knoten in einem Cluster
- **init-fdw.sh**: Konfiguration der Foreign Data Wrapper

### SQL-Skripte
- **create-tables.sql**: Erstellt Basistabellen
- **create-columnar-tables.sql**: Erstellt Tabellen mit Columnar-Speicherformat
- **create_partition_strategies.sql**: Definiert Partitionierungsstrategien
- **fdw-examples.sql**: Beispiele für Foreign Data Wrapper-Konfigurationen

## Verwendung

Diese Skripte werden in der Regel automatisch von Docker-Containern beim Start ausgeführt. Sie können aber auch manuell für Testzwecke oder bei der Entwicklung ausgeführt werden:

```bash
# Beispiel für die manuelle Ausführung eines Initialisierungsskripts
./scripts/init/init-db.sh
```

## Abhängigkeiten

Die Initialisierungsskripte sind abhängig von:
- PostgreSQL-Installation
- Entsprechende Erweiterungen (Citus, FDW, etc.)
- Konfigurationen im config/-Verzeichnis

## Hinweis

Änderungen an diesen Skripten sollten sorgfältig getestet werden, da sie grundlegende Datenbankfunktionen betreffen. 