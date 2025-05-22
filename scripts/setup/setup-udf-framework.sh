#!/bin/bash
# ExaPG - Setup UDF-Framework
# Skript zur automatisierten Einrichtung des UDF-Frameworks für Python, R und Lua-UDFs

set -e

# Standardwerte für Umgebungsvariablen
POSTGRES_HOST=${POSTGRES_HOST:-exapg}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-postgres}

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zum Ausführen von SQL-Befehlen
run_sql() {
    local sql="$1"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql"
}

# Funktion zum Ausführen von SQL-Dateien
run_sql_file() {
    local file="$1"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$file"
}

# Funktion zur Prüfung, ob eine Datenbank erreichbar ist
check_database() {
    local db_host="$1"
    local db_port="$2"
    local max_attempts=30
    local attempt=1
    
    echo -e "${BLUE}Prüfe Verbindung zu $db_host:$db_port...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$db_host" "$db_port" >/dev/null 2>&1; then
            echo -e "${GREEN}Verbindung zu $db_host:$db_port hergestellt!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Warte auf $db_host:$db_port (Versuch $attempt/$max_attempts)...${NC}"
        sleep 2
        attempt=$((attempt+1))
    done
    
    echo -e "${RED}Konnte keine Verbindung zu $db_host:$db_port herstellen!${NC}"
    return 1
}

# Prüfe, welche UDF-Sprachen aktiviert werden sollen
check_enabled_languages() {
    echo -e "${BLUE}Prüfe aktivierte UDF-Sprachen...${NC}"
    
    UDF_ENABLE_PYTHON=${UDF_ENABLE_PYTHON:-true}
    UDF_ENABLE_R=${UDF_ENABLE_R:-true}
    UDF_ENABLE_LUA=${UDF_ENABLE_LUA:-true}
    
    # Aktivierungsstring für Logs
    local enabled_languages=""
    
    if [ "$UDF_ENABLE_PYTHON" = "true" ]; then
        enabled_languages+="Python "
    fi
    
    if [ "$UDF_ENABLE_R" = "true" ]; then
        enabled_languages+="R "
    fi
    
    if [ "$UDF_ENABLE_LUA" = "true" ]; then
        enabled_languages+="Lua "
    fi
    
    echo -e "${GREEN}Aktivierte UDF-Sprachen: ${enabled_languages}${NC}"
}

# Funktion zum Einrichten der benötigten Erweiterungen
setup_extensions() {
    echo -e "${BLUE}Richte PostgreSQL-Erweiterungen ein...${NC}"
    
    # Spracherweiterungen
    if [ "$UDF_ENABLE_PYTHON" = "true" ]; then
        run_sql "CREATE EXTENSION IF NOT EXISTS plpython3u;"
        echo -e "${GREEN}PL/Python-Erweiterung aktiviert${NC}"
    fi
    
    if [ "$UDF_ENABLE_R" = "true" ]; then
        run_sql "CREATE EXTENSION IF NOT EXISTS plr;"
        echo -e "${GREEN}PL/R-Erweiterung aktiviert${NC}"
    fi
    
    if [ "$UDF_ENABLE_LUA" = "true" ]; then
        run_sql "CREATE EXTENSION IF NOT EXISTS pllua;"
        echo -e "${GREEN}PL/Lua-Erweiterung aktiviert${NC}"
    fi
    
    # Weitere nützliche Erweiterungen
    run_sql "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    echo -e "${GREEN}pg_stat_statements-Erweiterung aktiviert${NC}"
}

# Funktion zum Kopieren der Hilfsbibliotheken
setup_helper_libraries() {
    echo -e "${BLUE}Kopiere Hilfsbibliotheken für UDFs...${NC}"
    
    # Erstelle Verzeichnisse falls nicht vorhanden
    if [ "$UDF_ENABLE_PYTHON" = "true" ]; then
        # Stelle sicher, dass Python-Hilfsbibliothek verfügbar ist
        if [ -f "/usr/lib/python3/dist-packages/udf_helpers.py" ]; then
            echo -e "${GREEN}Python-Hilfsbibliothek bereits installiert${NC}"
        else
            echo -e "${YELLOW}Installiere Python-Hilfsbibliothek...${NC}"
            if [ -f "/sql/udf_framework/python/udf_helpers.py" ]; then
                cp /sql/udf_framework/python/udf_helpers.py /usr/lib/python3/dist-packages/
                echo -e "${GREEN}Python-Hilfsbibliothek installiert${NC}"
            else
                echo -e "${RED}Python-Hilfsbibliothek nicht gefunden!${NC}"
            fi
        fi
    fi
    
    if [ "$UDF_ENABLE_R" = "true" ]; then
        # Stelle sicher, dass R-Hilfsbibliothek verfügbar ist
        if [ -f "/usr/lib/R/site-library/udf_helpers.R" ]; then
            echo -e "${GREEN}R-Hilfsbibliothek bereits installiert${NC}"
        else
            echo -e "${YELLOW}Installiere R-Hilfsbibliothek...${NC}"
            if [ -f "/sql/udf_framework/r/udf_helpers.R" ]; then
                cp /sql/udf_framework/r/udf_helpers.R /usr/lib/R/site-library/
                echo -e "${GREEN}R-Hilfsbibliothek installiert${NC}"
            else
                echo -e "${RED}R-Hilfsbibliothek nicht gefunden!${NC}"
            fi
        fi
    fi
    
    if [ "$UDF_ENABLE_LUA" = "true" ]; then
        # Stelle sicher, dass Lua-Hilfsbibliothek verfügbar ist
        if [ -f "/usr/share/postgresql/15/extension/udf_helpers.lua" ]; then
            echo -e "${GREEN}Lua-Hilfsbibliothek bereits installiert${NC}"
        else
            echo -e "${YELLOW}Installiere Lua-Hilfsbibliothek...${NC}"
            if [ -f "/sql/udf_framework/lua/udf_helpers.lua" ]; then
                cp /sql/udf_framework/lua/udf_helpers.lua /usr/share/postgresql/15/extension/
                echo -e "${GREEN}Lua-Hilfsbibliothek installiert${NC}"
            else
                echo -e "${RED}Lua-Hilfsbibliothek nicht gefunden!${NC}"
            fi
        fi
    fi
}

# Funktion zum Einrichten der UDF-Framework-Datenbankobjekte
setup_udf_framework() {
    echo -e "${BLUE}Richte UDF-Framework-Datenbankobjekte ein...${NC}"
    
    # Führe die Framework-SQL-Skripte aus
    if [ -f "/docker-entrypoint-initdb.d/create_udf_framework.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_udf_framework.sql"
    elif [ -f "/sql/udf_framework/create_udf_framework.sql" ]; then
        run_sql_file "/sql/udf_framework/create_udf_framework.sql"
    else
        echo -e "${RED}UDF-Framework-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    if [ -f "/docker-entrypoint-initdb.d/create_udf_utils.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_udf_utils.sql"
    elif [ -f "/sql/udf_framework/create_udf_utils.sql" ]; then
        run_sql_file "/sql/udf_framework/create_udf_utils.sql"
    else
        echo -e "${RED}UDF-Framework-Utils-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}UDF-Framework-Datenbankobjekte wurden erstellt${NC}"
}

# Funktion zum Einrichten der Beispiel-UDFs
setup_example_udfs() {
    echo -e "${BLUE}Installiere Beispiel-UDFs...${NC}"
    
    # Erstelle notwendige Schemas
    run_sql "CREATE SCHEMA IF NOT EXISTS analytics;"
    run_sql "CREATE SCHEMA IF NOT EXISTS utilities;"
    
    # Führe die Beispiel-UDFs-SQL-Skript aus
    if [ -f "/docker-entrypoint-initdb.d/example_udfs.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/example_udfs.sql"
    elif [ -f "/sql/udf_framework/example_udfs.sql" ]; then
        run_sql_file "/sql/udf_framework/example_udfs.sql"
    else
        echo -e "${RED}Beispiel-UDFs-SQL-Skript nicht gefunden!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Beispiel-UDFs wurden installiert${NC}"
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - UDF-Framework Einrichtung${NC}"
    echo -e "${BLUE}===============================${NC}"
    
    # Prüfe, ob PostgreSQL läuft
    check_database "$POSTGRES_HOST" "$POSTGRES_PORT" || exit 1
    
    # Prüfe aktivierte Sprachen
    check_enabled_languages
    
    # Richte Erweiterungen ein
    setup_extensions
    
    # Kopiere Hilfsbibliotheken
    setup_helper_libraries
    
    # Richte UDF-Framework-Datenbankobjekte ein
    setup_udf_framework
    
    # Richte Beispiel-UDFs ein
    setup_example_udfs
    
    echo -e "${GREEN}UDF-Framework wurde erfolgreich eingerichtet!${NC}"
    echo -e "${GREEN}Sie können nun benutzerdefinierte Funktionen mit Python, R und Lua erstellen.${NC}"
    
    # Beispielabfragen anzeigen
    echo -e "${BLUE}Beispielabfragen für UDF-Framework:${NC}"
    echo -e "${YELLOW}-- Verfügbare UDFs anzeigen:${NC}"
    echo -e "${YELLOW}SELECT * FROM udf_framework.udf_catalog_view;${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- Python-UDF ausführen:${NC}"
    echo -e "${YELLOW}SELECT analytics.text_analysis('Dies ist ein Beispieltext zur Analyse');${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- R-UDF ausführen:${NC}"
    echo -e "${YELLOW}SELECT analytics.calculate_statistics(ARRAY[1.5, 2.5, 3.5, 4.5, 5.5]);${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- Lua-UDF ausführen:${NC}"
    echo -e "${YELLOW}SELECT utilities.format_string('hello world', 'title');${NC}"
}

# Skript ausführen
main 