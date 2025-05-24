# ===================================================================
# ExaPG CLI Messages - Deutsch
# ===================================================================
# I18N FIX: I18N-002 - Deutsche Sprachdatei
# Date: 2024-05-24
# ===================================================================

# Allgemeine Anwendungsmeldungen
MESSAGES["app_title"]="ExaPG - PostgreSQL Analytische Datenbank"
MESSAGES["app_version"]="ExaPG v%s"
MESSAGES["app_description"]="Hochperformante analytische PostgreSQL-Datenbank mit Citus-Clustering"

# Menüs und Navigation
MESSAGES["main_menu_title"]="ExaPG Hauptmenü"
MESSAGES["deployment_menu_title"]="Deployment-Verwaltung"
MESSAGES["monitoring_menu_title"]="Überwachung & Analytics"
MESSAGES["performance_menu_title"]="Performance-Tests"
MESSAGES["config_menu_title"]="Konfigurationsverwaltung"

# Allgemeine Aktionen
MESSAGES["starting"]="Starte %s..."
MESSAGES["stopping"]="Stoppe %s..."
MESSAGES["restarting"]="Starte %s neu..."
MESSAGES["deploying"]="Deploye %s..."
MESSAGES["configuring"]="Konfiguriere %s..."
MESSAGES["validating"]="Validiere %s..."
MESSAGES["completed"]="Erfolgreich abgeschlossen"
MESSAGES["failed"]="Operation fehlgeschlagen"

# Status-Meldungen
MESSAGES["status_running"]="Läuft"
MESSAGES["status_stopped"]="Gestoppt"
MESSAGES["status_starting"]="Startet"
MESSAGES["status_healthy"]="Gesund"
MESSAGES["status_unhealthy"]="Ungesund"
MESSAGES["status_unknown"]="Unbekannt"

# Deployment-Meldungen
MESSAGES["deployment_single_node"]="Einzelknoten-Deployment"
MESSAGES["deployment_cluster"]="Cluster-Deployment"
MESSAGES["deployment_ha"]="Hochverfügbarkeits-Deployment"
MESSAGES["deployment_type_prompt"]="Wählen Sie den Deployment-Typ (1-3)"
MESSAGES["deployment_success"]="Deployment erfolgreich abgeschlossen!"
MESSAGES["deployment_failed"]="Deployment fehlgeschlagen. Überprüfen Sie die Logs."

# Überwachungs-Meldungen
MESSAGES["monitoring_dashboard"]="Öffne Überwachungs-Dashboard..."
MESSAGES["monitoring_metrics"]="Zeige System-Metriken..."
MESSAGES["monitoring_alerts"]="Verwalte Alarme..."
MESSAGES["monitoring_unavailable"]="Überwachungsdienste nicht verfügbar"

# Performance-Meldungen
MESSAGES["performance_benchmark"]="Führe Performance-Benchmark aus..."
MESSAGES["performance_analysis"]="Analysiere Performance-Ergebnisse..."
MESSAGES["performance_baseline"]="Erstelle Performance-Baseline..."
MESSAGES["performance_report"]="Generiere Performance-Bericht..."

# Konfigurations-Meldungen
MESSAGES["config_processing"]="Verarbeite Konfigurations-Templates..."
MESSAGES["config_validation"]="Validiere Konfiguration..."
MESSAGES["config_applied"]="Konfiguration erfolgreich angewendet"
MESSAGES["config_invalid"]="Ungültige Konfiguration erkannt"

# Fehlermeldungen
MESSAGES["error_general"]="Ein Fehler ist aufgetreten: %s"
MESSAGES["error_connection"]="Verbindung fehlgeschlagen"
MESSAGES["error_authentication"]="Authentifizierung fehlgeschlagen"
MESSAGES["error_permission"]="Berechtigung verweigert"
MESSAGES["error_not_found"]="Ressource nicht gefunden: %s"
MESSAGES["error_invalid_input"]="Ungültige Eingabe: %s"
MESSAGES["error_timeout"]="Operation abgelaufen"

# Warnmeldungen
MESSAGES["warning_general"]="Warnung: %s"
MESSAGES["warning_deprecated"]="Veraltete Funktion: %s"
MESSAGES["warning_performance"]="Performance-Warnung: %s"
MESSAGES["warning_memory"]="Hohe Speichernutzung: %s"

# Erfolgsmeldungen
MESSAGES["success_general"]="Erfolg: %s"
MESSAGES["success_connection"]="Verbindung hergestellt"
MESSAGES["success_deployment"]="Deployment erfolgreich"
MESSAGES["success_configuration"]="Konfiguration aktualisiert"

# Informationsmeldungen
MESSAGES["info_general"]="Info: %s"
MESSAGES["info_loading"]="Lade..."
MESSAGES["info_waiting"]="Warte auf Antwort..."
MESSAGES["info_processing"]="Verarbeite..."

# Benutzerinteraktion
MESSAGES["prompt_continue"]="Drücken Sie eine beliebige Taste zum Fortfahren..."
MESSAGES["prompt_confirm"]="Sind Sie sicher? (j/N)"
MESSAGES["prompt_choice"]="Wählen Sie eine Option"
MESSAGES["prompt_enter_value"]="Wert eingeben"
MESSAGES["invalid_selection"]="Ungültige Auswahl"

# Internationalisierung
MESSAGES["language_selection_title"]="Sprachauswahl"
MESSAGES["language_selection_prompt"]="Sprache auswählen"
MESSAGES["language_changed"]="Sprache geändert zu: %s"
MESSAGES["language_unavailable"]="Sprache nicht verfügbar: %s"

# Hilfe-Meldungen
MESSAGES["help_title"]="ExaPG CLI Hilfe"
MESSAGES["help_navigation"]="Navigation: Zahlentasten für Auswahl, 'b' für zurück, 'q' zum Beenden"
MESSAGES["help_commands"]="Verfügbare Befehle: deploy, status, stop, restart, logs, monitor"
MESSAGES["help_options"]="Optionen: --help, --version, --config"

# Docker und Container-Meldungen
MESSAGES["docker_starting"]="Starte Docker-Container..."
MESSAGES["docker_stopping"]="Stoppe Docker-Container..."
MESSAGES["docker_building"]="Erstelle Docker-Images..."
MESSAGES["docker_not_available"]="Docker ist nicht verfügbar"
MESSAGES["container_running"]="Container läuft"
MESSAGES["container_stopped"]="Container gestoppt"

# Datenbank-Meldungen
MESSAGES["db_connecting"]="Verbinde zur Datenbank..."
MESSAGES["db_connected"]="Datenbankverbindung hergestellt"
MESSAGES["db_disconnected"]="Datenbankverbindung getrennt"
MESSAGES["db_initializing"]="Initialisiere Datenbank..."
MESSAGES["db_ready"]="Datenbank ist bereit"

# Cluster-Meldungen
MESSAGES["cluster_forming"]="Bilde Cluster..."
MESSAGES["cluster_ready"]="Cluster ist bereit"
MESSAGES["cluster_scaling"]="Skaliere Cluster..."
MESSAGES["cluster_status"]="Cluster-Status: %s"
MESSAGES["worker_adding"]="Füge Worker-Knoten hinzu..."
MESSAGES["worker_removing"]="Entferne Worker-Knoten..."

# Log-Meldungen
MESSAGES["log_viewing"]="Zeige Logs..."
MESSAGES["log_clearing"]="Lösche Logs..."
MESSAGES["log_archiving"]="Archiviere Logs..."
MESSAGES["log_level_changed"]="Log-Level geändert zu: %s" 