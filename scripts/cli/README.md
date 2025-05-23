# ExaPG CLI-Komponenten

Dieses Verzeichnis enthält die Skripte und Funktionen für die zentrale Kommandozeilenschnittstelle (CLI) von ExaPG.

## Übersicht

Die CLI-Komponenten bilden das Herzstück der neuen, vereinheitlichten Benutzerschnittstelle für ExaPG. Sie ersetzen die Vielzahl separater Start- und Stopp-Skripte mit einer zentralen, interaktiven Oberfläche.

## Dateien im Verzeichnis

- **exapg-cli-functions.sh**: Enthält die Kernfunktionen der CLI, darunter Menüs, Status-Abfragen und Aktionen
- **migration.sh**: Migriert die alten Start/Stop-Skripte vom Wurzelverzeichnis nach scripts/setup und ersetzt sie durch Symlinks
- **install-completion.sh**: Installiert Bash-Completion für ExaPG-Kommandos

## Verwendung

Die CLI-Funktionen werden durch das Hauptskript `exapg-cli.sh` im Wurzelverzeichnis aufgerufen. Dieses lädt die Funktionen aus `exapg-cli-functions.sh`.

### Migrationshinweis

Führen Sie `migration.sh` aus, um die ursprünglichen Start/Stop-Skripte ins `scripts/setup` Verzeichnis zu verschieben und durch Symlinks zur zentralen CLI zu ersetzen.

### Bash-Completion

Um die Bash-Completion für ExaPG-Kommandos zu aktivieren:

```bash
./scripts/cli/install-completion.sh
```

Nach der Installation können Sie TAB-Vervollständigung für ExaPG-Kommandos verwenden. 