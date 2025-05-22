#!/bin/bash
# ExaPG - Setup Distribution Strategies
# Skript zur Einrichtung optimierter Datenverteilungsstrategien
# Vergleichbar mit Exasol's automatischer Datenverteilung

set -e

# Set default paths for different environments
if [ -d "/sql" ]; then
    # Docker-Container-Umgebung
    SQL_DIR="/sql/distribution"
    CONFIG_DIR="/etc/postgresql"
else
    # Lokale Entwicklungsumgebung
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    SQL_DIR="$PROJECT_ROOT/sql/distribution"
    CONFIG_DIR="$PROJECT_ROOT/config/postgresql"
fi

echo "Starte Einrichtung der optimierten Datenverteilungsstrategien..."

# PostgreSQL-Verbindungsparameter aus Umgebungsdatei laden oder Umgebungsvariablen verwenden
if [ -z "$POSTGRES_HOST" ]; then
    if [ -f "/app/.env" ]; then
        # Docker-Container mit gemounteter .env-Datei
        source "/app/.env"
    elif [ -f "$PROJECT_ROOT/.env" ]; then
        # Lokale Entwicklungsumgebung
        source "$PROJECT_ROOT/.env"
    else
        echo "WARNUNG: Keine .env Datei gefunden. Verwende Standardwerte für die Verbindung."
        # Standardwerte setzen
        POSTGRES_HOST="coordinator"
        POSTGRES_PORT="5432"
        POSTGRES_USER="postgres"
        POSTGRES_PASSWORD="postgres"
        POSTGRES_DB="postgres"
    fi
fi

# Überprüfen, ob alle notwendigen Variablen gesetzt sind
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "FEHLER: Nicht alle notwendigen Datenbankverbindungsparameter sind gesetzt."
    echo "Benötigt werden: POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    exit 1
fi

# Standard-Port setzen, falls nicht definiert
if [ -z "$POSTGRES_PORT" ]; then
    POSTGRES_PORT="5432"
fi

# Prüfen, ob Citus installiert ist oder installiert werden soll
check_citus() {
    echo "Prüfe, ob Citus-Erweiterung verfügbar ist..."
    
    CITUS_INSTALLED=$(PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'citus';")
    
    if [ "$CITUS_INSTALLED" -eq "1" ]; then
        echo "Citus ist bereits installiert."
        return 0
    else
        echo "Citus ist nicht installiert. Prüfe, ob die Erweiterung verfügbar ist..."
        CITUS_AVAILABLE=$(PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'citus';")
        
        if [ "$CITUS_AVAILABLE" -eq "1" ]; then
            echo "Citus ist verfügbar. Installation wird gestartet..."
            PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "CREATE EXTENSION citus;"
            echo "Citus erfolgreich installiert."
            return 0
        else
            echo "WARNUNG: Citus ist nicht verfügbar. Die Datenverteilungsstrategien benötigen Citus."
            echo "Bitte installieren Sie zuerst PostgreSQL mit Citus-Extension."
            return 1
        fi
    fi
}

# PostgreSQL-Konfiguration für optimale Datenverteilung aktualisieren
update_postgresql_config() {
    echo "Aktualisiere PostgreSQL-Konfiguration für optimale Datenverteilung..."
    
    # Prüfen, ob wir Schreibrechte auf die Konfigurationsdatei haben
    if [ -w "$CONFIG_DIR/postgresql.conf" ]; then
        # Sichern der aktuellen Konfiguration
        cp "$CONFIG_DIR/postgresql.conf" "$CONFIG_DIR/postgresql.conf.bak"
        
        # Parameter für optimale Datenverteilung setzen
        cat << EOF >> "$CONFIG_DIR/postgresql.conf"

# Optimierte Konfiguration für Datenverteilung (Citus)
citus.shard_count = 32                        # Default Anzahl Shards pro Tabelle
citus.shard_replication_factor = 1            # Für Produktivumgebungen auf 2 erhöhen
citus.enable_repartition_joins = on           # Ermöglicht verteilte Joins über Knoten hinweg
citus.node_connection_timeout = 10000         # Timeout für Knotenverbindungen (ms)
citus.max_adaptive_executor_pool_size = 16    # Max Verbindungen pro Knoten
citus.log_remote_commands = on                # Logging für einfachere Fehlerbehebung

# Parallele Verarbeitung auf Knoten optimieren
max_parallel_workers_per_gather = 8           # Parallel Worker pro Gather
max_parallel_workers = 16                     # Parallele Worker insgesamt
parallel_setup_cost = 100                     # Niedrigere Kosten für parallele Ausführungspläne
parallel_tuple_cost = 0.01                    # Niedrigere Kosten für parallele Ausführungspläne
EOF
        
        echo "PostgreSQL-Konfiguration erfolgreich aktualisiert."
        echo "HINWEIS: Ein Neustart von PostgreSQL ist erforderlich, um die Änderungen zu übernehmen."
    else
        echo "WARNUNG: Keine Schreibrechte auf die PostgreSQL-Konfigurationsdatei."
        echo "Bitte fügen Sie die folgenden Parameter manuell zu Ihrer postgresql.conf hinzu:"
        cat << EOF

# Optimierte Konfiguration für Datenverteilung (Citus)
citus.shard_count = 32
citus.shard_replication_factor = 1
citus.enable_repartition_joins = on
citus.node_connection_timeout = 10000
citus.max_adaptive_executor_pool_size = 16
citus.log_remote_commands = on

# Parallele Verarbeitung auf Knoten optimieren
max_parallel_workers_per_gather = 8
max_parallel_workers = 16
parallel_setup_cost = 100
parallel_tuple_cost = 0.01
EOF
    fi
}

# Datenverteilungsstrategien auf der Datenbank installieren
install_distribution_strategies() {
    echo "Installiere optimierte Datenverteilungsstrategien..."
    
    # SQL-Skript ausführen
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f "$SQL_DIR/create_distribution_strategies.sql"
    
    echo "Datenverteilungsstrategien erfolgreich installiert."
}

# Beispiel-Queries für die Verwendung
show_examples() {
    echo "------------------------------------------------"
    echo "BEISPIELE FÜR DIE VERWENDUNG DER VERTEILUNGSSTRATEGIEN:"
    echo "------------------------------------------------"
    echo "-- Automatische optimale Verteilung einer Tabelle"
    echo "SELECT admin.distribute_table_optimally('public', 'sales');"
    echo ""
    echo "-- Automatische Verteilung aller Tabellen im Schema"
    echo "SELECT admin.distribute_schema('analytics');"
    echo ""
    echo "-- Tabellen für optimale Joins kolokieren"
    echo "SELECT admin.setup_table_colocation("
    echo "    'public', "
    echo "    ARRAY['customers', 'orders', 'order_items']"
    echo ");"
    echo ""
    echo "-- Rebalancing nach Hinzufügen neuer Knoten"
    echo "SELECT admin.rebalance_shards();"
    echo ""
    echo "-- Abfrage mit optimaler Parallelität"
    echo "SELECT admin.execute_parallel_distributed('"
    echo "    SELECT "
    echo "        date_trunc(''month'', order_date) as month,"
    echo "        SUM(order_amount) as total_sales"
    echo "    FROM orders"
    echo "    GROUP BY 1"
    echo "    ORDER BY 1"
    echo "');"
    echo "------------------------------------------------"
}

# Hauptprogramm
main() {
    echo "ExaPG - Einrichtung optimierter Datenverteilungsstrategien"
    echo "========================================================"
    
    # Prüfen und ggf. installieren von Citus
    if check_citus; then
        # PostgreSQL-Konfiguration aktualisieren
        update_postgresql_config
        
        # Datenverteilungsstrategien installieren
        install_distribution_strategies
        
        # Beispiele anzeigen
        show_examples
        
        echo "========================================================"
        echo "Einrichtung der optimierten Datenverteilungsstrategien abgeschlossen."
        echo "Die ExaPG-Distribution ist nun mit Exasol vergleichbar konfiguriert."
    else
        echo "FEHLER: Die Einrichtung der Datenverteilungsstrategien konnte nicht abgeschlossen werden."
        exit 1
    fi
}

# Skript ausführen
main 