#!/bin/bash
# ExaPG - Setup Virtual Schemas
# Skript zur automatisierten Einrichtung von Virtual Schemas und FDW-Verbindungen

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

# Funktion zur Einrichtung eines Virtual Schemas für eine PostgreSQL-Datenbank
setup_postgres_schema() {
    local schema_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local dbname="$6"
    
    echo -e "${BLUE}Richte PostgreSQL Virtual Schema '$schema_name' ein...${NC}"
    
    # Erstelle Connection-String
    local conn_str="postgresql://$user:$password@$host:$port/$dbname"
    
    # Erstelle Virtual Schema
    run_sql "SELECT vs_metadata.create_virtual_schema('$schema_name', 'postgres', '$conn_str');"
    
    # Server einrichten
    run_sql "SELECT vs_metadata.setup_fdw_server('$schema_name', 'postgres', '$conn_str');"
    
    # Alle Tabellen importieren
    run_sql "SELECT vs_metadata.import_all_tables('$schema_name');"
    
    # Statistiken aktualisieren
    run_sql "CALL vs_metadata.refresh_table_stats('$schema_name');"
    
    echo -e "${GREEN}PostgreSQL Virtual Schema '$schema_name' erfolgreich eingerichtet!${NC}"
}

# Funktion zur Einrichtung eines Virtual Schemas für eine MySQL-Datenbank
setup_mysql_schema() {
    local schema_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local dbname="$6"
    
    echo -e "${BLUE}Richte MySQL Virtual Schema '$schema_name' ein...${NC}"
    
    # Erstelle Connection-String
    local conn_str="mysql://$user:$password@$host:$port"
    
    # Erstelle Virtual Schema mit Optionen
    run_sql "SELECT vs_metadata.create_virtual_schema('$schema_name', 'mysql', '$conn_str', 
        '{\"dbname\": \"$dbname\", \"port\": \"$port\"}');"
    
    # Server einrichten
    run_sql "SELECT vs_metadata.setup_fdw_server('$schema_name', 'mysql', '$conn_str', 
        '{\"dbname\": \"$dbname\"}');"
    
    # Alle Tabellen importieren
    run_sql "SELECT vs_metadata.import_all_tables('$schema_name');"
    
    # Statistiken aktualisieren
    run_sql "CALL vs_metadata.refresh_table_stats('$schema_name');"
    
    echo -e "${GREEN}MySQL Virtual Schema '$schema_name' erfolgreich eingerichtet!${NC}"
}

# Funktion zur Einrichtung eines Virtual Schemas für eine SQL Server-Datenbank
setup_mssql_schema() {
    local schema_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local dbname="$6"
    
    echo -e "${BLUE}Richte SQL Server Virtual Schema '$schema_name' ein...${NC}"
    
    # Erstelle Connection-String
    local conn_str="mssql://$user:$password@$host:$port"
    
    # Erstelle Virtual Schema mit Optionen
    run_sql "SELECT vs_metadata.create_virtual_schema('$schema_name', 'mssql', '$conn_str', 
        '{\"database\": \"$dbname\", \"port\": \"$port\", \"schema\": \"dbo\"}');"
    
    # Server einrichten
    run_sql "SELECT vs_metadata.setup_fdw_server('$schema_name', 'mssql', '$conn_str', 
        '{\"database\": \"$dbname\"}');"
    
    # Manuelles Importieren einiger Beispiel-Tabellen (da auto-import für MSSQL noch nicht vollständig implementiert ist)
    run_sql "SELECT vs_metadata.add_virtual_table('$schema_name', 'example_table', 'dbo.example_table');"
    
    # Statistiken aktualisieren
    run_sql "CALL vs_metadata.refresh_table_stats('$schema_name');"
    
    echo -e "${GREEN}SQL Server Virtual Schema '$schema_name' erfolgreich eingerichtet!${NC}"
}

# Funktion zur Einrichtung eines Virtual Schemas für eine MongoDB-Datenbank
setup_mongodb_schema() {
    local schema_name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local dbname="$6"
    
    echo -e "${BLUE}Richte MongoDB Virtual Schema '$schema_name' ein...${NC}"
    
    # Erstelle Connection-String
    local conn_str="mongodb://$user:$password@$host:$port"
    
    # Erstelle Virtual Schema mit Optionen
    run_sql "SELECT vs_metadata.create_virtual_schema('$schema_name', 'mongodb', '$conn_str', 
        '{\"database\": \"$dbname\", \"port\": \"$port\"}');"
    
    # Server einrichten
    run_sql "SELECT vs_metadata.setup_fdw_server('$schema_name', 'mongodb', '$conn_str', 
        '{\"database\": \"$dbname\"}');"
    
    # Manuelles Importieren einiger Beispiel-Collections
    run_sql "SELECT vs_metadata.add_virtual_table('$schema_name', 'users', 'users', 
        '{\"_id\": {\"type\": \"TEXT\", \"nullable\": false}, 
          \"name\": {\"type\": \"TEXT\", \"nullable\": true}, 
          \"email\": {\"type\": \"TEXT\", \"nullable\": true}, 
          \"metadata\": {\"type\": \"JSONB\", \"nullable\": true}}');"
    
    echo -e "${GREEN}MongoDB Virtual Schema '$schema_name' erfolgreich eingerichtet!${NC}"
}

# Funktion zur Einrichtung eines Virtual Schemas für eine Redis-Datenbank
setup_redis_schema() {
    local schema_name="$1"
    local host="$2"
    local port="$3"
    local password="$4"
    
    echo -e "${BLUE}Richte Redis Virtual Schema '$schema_name' ein...${NC}"
    
    # Erstelle Connection-String
    local conn_str="redis://$host:$port"
    
    # Erstelle Virtual Schema mit Optionen
    run_sql "SELECT vs_metadata.create_virtual_schema('$schema_name', 'redis', '$conn_str', 
        '{\"port\": \"$port\", \"password\": \"$password\", \"database\": \"0\"}');"
    
    # Server einrichten
    run_sql "SELECT vs_metadata.setup_fdw_server('$schema_name', 'redis', '$conn_str', 
        '{\"password\": \"$password\", \"database\": \"0\"}');"
    
    # Manuelles Importieren eines Beispiel-Schlüsselmusters
    run_sql "SELECT vs_metadata.add_virtual_table('$schema_name', 'user_data', 'user');"
    
    echo -e "${GREEN}Redis Virtual Schema '$schema_name' erfolgreich eingerichtet!${NC}"
}

# Hauptfunktion
main() {
    echo -e "${BLUE}ExaPG - Virtual Schemas Einrichtung${NC}"
    echo -e "${BLUE}===============================${NC}"
    
    # Prüfe, ob PostgreSQL läuft
    check_database "$POSTGRES_HOST" "$POSTGRES_PORT" || exit 1
    
    echo -e "${BLUE}Installiere Virtual Schemas Infrastruktur...${NC}"
    
    # Führe die erforderlichen SQL-Dateien aus
    if [ -f "/docker-entrypoint-initdb.d/create_virtual_schemas.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_virtual_schemas.sql"
    else
        run_sql_file "/sql/virtual_schemas/create_virtual_schemas.sql"
    fi
    
    if [ -f "/docker-entrypoint-initdb.d/create_schema_utils.sql" ]; then
        run_sql_file "/docker-entrypoint-initdb.d/create_schema_utils.sql"
    else
        run_sql_file "/sql/virtual_schemas/create_schema_utils.sql"
    fi
    
    # Verbindungen für verschiedene Datenbanken einrichten, falls Umgebungsvariablen vorhanden sind
    
    # MySQL
    if [ -n "$MYSQL_HOST" ]; then
        check_database "$MYSQL_HOST" "${MYSQL_PORT:-3306}" && \
        setup_mysql_schema "mysql_vs" "$MYSQL_HOST" "${MYSQL_PORT:-3306}" \
            "${MYSQL_USER:-mysqluser}" "${MYSQL_PASSWORD:-mysqlpass}" "${MYSQL_DATABASE:-testdb}"
    fi
    
    # MS SQL Server
    if [ -n "$MSSQL_HOST" ]; then
        check_database "$MSSQL_HOST" "${MSSQL_PORT:-1433}" && \
        setup_mssql_schema "mssql_vs" "$MSSQL_HOST" "${MSSQL_PORT:-1433}" \
            "${MSSQL_USER:-sa}" "${MSSQL_PASSWORD:-StrongPassword123!}" "${MSSQL_DATABASE:-master}"
    fi
    
    # MongoDB
    if [ -n "$MONGODB_HOST" ]; then
        check_database "$MONGODB_HOST" "${MONGODB_PORT:-27017}" && \
        setup_mongodb_schema "mongodb_vs" "$MONGODB_HOST" "${MONGODB_PORT:-27017}" \
            "${MONGODB_USER:-root}" "${MONGODB_PASSWORD:-example}" "${MONGODB_DATABASE:-testdb}"
    fi
    
    # Redis
    if [ -n "$REDIS_HOST" ]; then
        check_database "$REDIS_HOST" "${REDIS_PORT:-6379}" && \
        setup_redis_schema "redis_vs" "$REDIS_HOST" "${REDIS_PORT:-6379}" \
            "${REDIS_PASSWORD:-redis123}"
    fi
    
    echo -e "${GREEN}Virtual Schemas wurden erfolgreich eingerichtet!${NC}"
    echo -e "${GREEN}Sie können nun über SQL auf die externen Datenquellen zugreifen.${NC}"
    
    # Beispielabfragen anzeigen
    echo -e "${BLUE}Beispielabfragen für Virtual Schemas:${NC}"
    echo -e "${YELLOW}-- MySQL-Daten abfragen:${NC}"
    echo -e "${YELLOW}SELECT * FROM mysql_vs.users;${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- SQL Server-Daten abfragen:${NC}"
    echo -e "${YELLOW}SELECT * FROM mssql_vs.example_table;${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- MongoDB-Daten abfragen:${NC}"
    echo -e "${YELLOW}SELECT * FROM mongodb_vs.users;${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- Redis-Daten abfragen:${NC}"
    echo -e "${YELLOW}SELECT * FROM redis_vs.user_data;${NC}"
    echo -e "${YELLOW}"
    echo -e "${YELLOW}-- Schema-Informationen anzeigen:${NC}"
    echo -e "${YELLOW}SELECT * FROM vs_metadata.get_foreign_table_info('mysql_vs');${NC}"
}

# Skript ausführen
main 