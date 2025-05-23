# ExaPG CLI

Eine interaktive Terminal-Schnittstelle für die Verwaltung der ExaPG-Umgebung.

## Übersicht

Die ExaPG CLI ersetzt die Vielzahl der separaten Start- und Stopp-Skripte im Root-Verzeichnis mit einer einheitlichen, benutzerfreundlichen Schnittstelle. Sie bietet ein interaktives Menü zur Verwaltung aller ExaPG-Komponenten und -Funktionen.

## Features

- **Einheitliche Benutzeroberfläche**: Ein zentrales Skript für alle Operationen statt vieler separater Skripte
- **Interaktives Menü**: Einfache Navigation durch die verschiedenen ExaPG-Funktionen
- **Komponenten-Management**: Starten und Stoppen einzelner Komponenten oder der gesamten Umgebung
- **Statuskontrolle**: Übersichtliche Darstellung des Laufzeitstatus aller Komponenten
- **Konfigurationsmanagement**: Direkter Zugriff auf die Konfigurationsdateien
- **Modernes UI**: Optisch ansprechendes Terminal-Interface mit Farben und Rahmen
- **Systeminfo**: Anzeige relevanter Systeminformationen und aktueller Konfiguration
- **Komponenten-spezifische Menüs**: Einfache Verwaltung einzelner Komponenten

## Neue Funktionen

Die modernisierte CLI bietet folgende Verbesserungen gegenüber der ursprünglichen Version:

1. **Verbesserte Benutzeroberfläche**:
   - Farbige Ausgabe für bessere Lesbarkeit
   - Rahmen und Tabellen zur strukturierten Darstellung
   - ASCII-Art Logo für professionelles Erscheinungsbild

2. **Komponenten-Status auf einen Blick**:
   - Zeigt beim Start automatisch an, welche Komponenten aktiv sind
   - Farbige Status-Indikatoren (grün für aktiv, rot für inaktiv)

3. **Erweiterte Konfigurationsmöglichkeiten**:
   - Interaktive Assistenten für die Konfiguration jeder Komponente
   - Möglichkeit, Konfigurationen zu ändern und Komponenten neu zu starten

4. **Detaillierte Systeminformationen**:
   - Zeigt CPU, RAM und Festplattennutzung
   - Aktuelle Konfigurationseinstellungen auf einen Blick

5. **Verbessertes Startverhalten**:
   - Die Bedienoberfläche zeigt den aktuellen Status, bevor Aktionen ausgeführt werden
   - Optionen zum Starten/Stoppen basierend auf dem aktuellen Zustand

## Verwendung

```bash
./exapg
```

Nach dem Start wird das neue, modern gestaltete Interface angezeigt:

### Hauptmenü-Optionen

1. **ExaPG Standard starten/stoppen**: Startet oder stoppt die Standard-ExaPG-Umgebung je nach aktuellem Status
2. **ExaPG Citus starten/stoppen**: Startet oder stoppt die verteilte Datenbank mit Citus-Extension
3. **ExaPG HA starten/stoppen**: Startet oder stoppt die Hochverfügbarkeitskonfiguration
4. **Monitoring starten/stoppen**: Startet oder stoppt den Monitoring-Stack
5. **Management-UI starten/stoppen**: Startet oder stoppt die webbasierte Verwaltungsoberfläche
6. **UDF-Framework starten/stoppen**: Startet oder stoppt die Umgebung für benutzerdefinierte Funktionen
7. **Virtual Schemas starten/stoppen**: Startet oder stoppt die Foreign Data Wrapper
8. **ETL-Tools starten/stoppen**: Startet oder stoppt die ETL-Verarbeitungsumgebung
9. **Backup-Tools starten/stoppen**: Startet oder stoppt die Backup-Umgebung

**Zusätzliche Optionen:**
- **c**: System konfigurieren (Systemweite Konfiguration)
- **s**: Detaillierten Status anzeigen
- **e**: Konfigurationseinstellungen bearbeiten (.env-Datei)
- **x**: Alle Komponenten stoppen
- **q**: Beenden

### Komponenten-Menüs

Wenn eine Komponente ausgewählt wird, wird ein kontextsensitives Menü angezeigt:

**Für aktive Komponenten:**
- **Stoppen**: Stoppt die Komponente
- **Neustarten**: Stoppt und startet die Komponente neu
- **Konfigurieren**: Öffnet den Konfigurationsassistenten für die Komponente

**Für inaktive Komponenten:**
- **Starten**: Startet die Komponente
- **Konfigurieren und starten**: Konfiguriert die Komponente und startet sie anschließend

## Vorteile

1. **Vereinfachte Bedienung**: Keine Notwendigkeit, sich mehrere Skriptnamen zu merken
2. **Reduzierte Fehleranfälligkeit**: Geführte Benutzerinteraktion statt manueller Skriptausführung
3. **Bessere Übersicht**: Klarer Überblick über den Status aller Komponenten
4. **Einfachere Wartung**: Ein zentrales Skript statt vieler separater Dateien

## Technische Details

Die CLI nutzt im Hintergrund die bestehenden Docker Compose-Konfigurationen, bietet aber eine einheitliche Schnittstelle für deren Verwaltung. Sie prüft automatisch die Voraussetzungen und zeigt detaillierte Fehler- und Statusmeldungen an.

## Migrationshinweis

Diese CLI ersetzt die folgenden Skripte im Root-Verzeichnis:

- start-exapg.sh
- start-exapg-citus.sh
- start-exapg-fdw.sh
- start-exapg-ha.sh
- start-exapg-udf-framework.sh
- start-exapg-virtual-schemas.sh
- start-exapg-etl.sh
- start-backup.sh
- start-cluster-management.sh
- start-management-ui.sh
- start-monitoring.sh
- stop-backup.sh
- stop-cluster-management.sh
- stop-exapg-etl.sh
- stop-exapg-ha.sh
- stop-exapg-udf-framework.sh
- stop-exapg-virtual-schemas.sh
- stop-management-ui.sh
- stop-monitoring.sh

Diese Skripte werden in das Verzeichnis `scripts/setup/` verschoben und durch Symlinks zur neuen CLI ersetzt, um die Verzeichnisstruktur übersichtlicher zu gestalten.

## Installation

### Standardinstallation

Setzen Sie die CLI-Skripte ausführbar:

```bash
chmod +x exapg-cli.sh
chmod +x scripts/cli/exapg-cli-functions.sh
```

Erstellen Sie optional einen symbolischen Link für einfachen Zugriff:

```bash
ln -sf exapg-cli.sh exapg
```

### Migration von alten Skripten

Für eine sanfte Migration von den alten Start- und Stopp-Skripten bietet ExaPG ein Migrationsskript:

```bash
./scripts/cli/migration.sh
```

Dieses Skript:
1. Sichert alle bestehenden Start- und Stopp-Skripte in `scripts/setup/`
2. Ersetzt die Skripte durch Symlinks zur neuen CLI
3. Leitet Benutzer zur neuen CLI weiter, wenn sie versehentlich alte Skriptnamen verwenden

### Bash-Completion

Für eine verbesserte Benutzererfahrung kann die Bash-Completion für ExaPG-Kommandos aktiviert werden:

```bash
./scripts/cli/install-completion.sh
```

Nach der Installation können Sie TAB-Vervollständigung für ExaPG-Kommandos verwenden. 