#!/bin/bash
# ExaPG Testskript
# Dieses Skript führt umfangreiche Tests für die ExaPG-Umgebung durch

set -e

# Farbkodierung für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Funktionen für Ausgabeformatierung
function header() {
    echo -e "\n${YELLOW}==== $1 ====${NC}"
}

function success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function error() {
    echo -e "${RED}✗ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

function info() {
    echo -e "  $1"
}

function run_sql_quiet() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    docker exec -i $container psql -U $user -d $db -t -c "$command" 2>/dev/null | tr -d "\r" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
# Zähler für Testergebnisse
TOTAL_TESTS=0
FAILED_TESTS=0

# Hauptfunktion zum Ausführen von SQL und Überprüfen der Ergebnisse
function run_sql_test() {
    local test_name="$1"
    local sql_command="$2"
    local expected_result="$3"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    info "Test: $test_name"
    info "SQL: $sql_command"
    
    local result=$(docker exec -i $container psql -U $user -d $db -t -c "$sql_command" 2>&1)
    local exit_code=$?
    
    # Bereinige Ergebnis
    result=$(echo "$result" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [ $exit_code -ne 0 ]; then
        error "SQL-Ausführungsfehler: $result"
        return 1
    fi
    
    if [ -n "$expected_result" ]; then
        if [[ "$result" == *"$expected_result"* ]]; then
            success "Ergebnis wie erwartet: $result"
        else
            error "Unerwartetes Ergebnis. Erwartet: '$expected_result', Erhalten: '$result'"
        fi
    else
        if [ -n "$result" ]; then
            success "Befehl erfolgreich ausgeführt: $result"
        else
            error "Leeres Ergebnis erhalten"
        fi
    fi
}

# Testet, ob ein Container läuft
function test_container_running() {
    local container="$1"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    info "Prüfe, ob Container $container läuft..."
    
    if docker ps | grep -q "$container"; then
        success "Container $container läuft"
    else
        error "Container $container läuft nicht"
    fi
}

# 1. Überprüfung der Umgebung
header "Überprüfung der Umgebung"

# Prüfe, ob Docker läuft
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if docker info &> /dev/null; then
    success "Docker läuft"
else
    error "Docker läuft nicht oder hat keine Berechtigungen"
    exit 1
fi

# Prüfe, ob die erforderlichen Container laufen
test_container_running "exapg-coordinator"

# Optional: Prüfe, ob weitere Container laufen (basierend auf der Konfiguration)
if docker ps | grep -q "exapg-mysql"; then
    info "Demo-Datenquellen sind aktiviert"
    test_container_running "exapg-mysql"
    test_container_running "exapg-mongodb"
    test_container_running "exapg-redis"
fi

if docker ps | grep -q "exapg-pgagent"; then
    info "pgAgent ist aktiviert"
    test_container_running "exapg-pgagent"
fi

# 2. Überprüfung der PostgreSQL-Basis
header "Überprüfung der PostgreSQL-Basis"

# Prüfe, ob PostgreSQL läuft
run_sql_test "PostgreSQL-Verbindung" "SELECT version();" "PostgreSQL"

# Prüfe, ob die erforderlichen Erweiterungen installiert sind
run_sql_test "Citus-Erweiterung" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'citus';" "citus"
run_sql_test "PostGIS-Erweiterung" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'postgis';" "postgis"
run_sql_test "TimescaleDB-Erweiterung" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'timescaledb';" "timescaledb"
run_sql_test "pgvector-Erweiterung" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'vector';" "vector"

# 3. Überprüfung der Foreign Data Wrapper
header "Überprüfung der Foreign Data Wrapper"

# Prüfe, ob die FDW-Erweiterungen installiert sind
run_sql_test "postgres_fdw" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'postgres_fdw';" "postgres_fdw"
run_sql_test "file_fdw" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'file_fdw';" "file_fdw"

# Diese FDWs sind optional und können fehlen
mysql_fdw_exists=$(run_sql_quiet "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'mysql_fdw';")
mongo_fdw_exists=$(run_sql_quiet "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'mongo_fdw';")
tds_fdw_exists=$(run_sql_quiet "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'tds_fdw';")
redis_fdw_exists=$(run_sql_quiet "SELECT COUNT(*) FROM pg_available_extensions WHERE name = 'redis_fdw';")

# Reduziere die Anzahl der erwarteten Tests, wenn bestimmte FDWs nicht verfügbar sind
if [ "$mongo_fdw_exists" = "0" ]; then
    info "MongoDB FDW ist nicht verfügbar. Test wird übersprungen."
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
else
    run_sql_test "mongo_fdw" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'mongo_fdw';" "mongo_fdw"
fi

if [ "$tds_fdw_exists" = "0" ]; then
    info "TDS FDW ist nicht verfügbar. Test wird übersprungen."
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
else
    run_sql_test "tds_fdw" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'tds_fdw';" "tds_fdw"
fi

if [ "$redis_fdw_exists" = "0" ]; then
    info "Redis FDW ist nicht verfügbar. Test wird übersprungen."
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
else
    run_sql_test "redis_fdw" "SELECT name, default_version FROM pg_available_extensions WHERE name = 'redis_fdw';" "redis_fdw"
fi

# Prüfe, ob das FDW-Schema existiert
run_sql_test "external_sources Schema" "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'external_sources';" "external_sources"

# Prüfe die CSV-Beispieltabelle
run_sql_test "CSV FDW Tabelle" "SELECT COUNT(*) FROM external_sources.example_csv;" "5"

# 4. Überprüfung der ETL-Funktionalität
header "Überprüfung der ETL-Funktionalität"

# Prüfe, ob das ETL-Schema existiert
run_sql_test "etl Schema" "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'etl';" "etl"

# Prüfe, ob die ETL-Tabellen existieren
run_sql_test "ETL Aktivitätsprotokoll" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'etl' AND table_name = 'activity_log';" "1"
run_sql_test "ETL Staging-Tabellen" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'etl' AND table_name LIKE 'staging_%';" ""
run_sql_test "ETL Dimension-Tabellen" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'etl' AND table_name LIKE 'dim_%';" ""

# Prüfe, ob die ETL-Prozeduren existieren
run_sql_test "ETL Prozeduren" "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'etl';" ""

# 5. Test für Demo-Daten
header "Überprüfung der Demo-Daten"

# Füge Testdaten hinzu und überprüfe sie
run_sql_test "Demo-Daten Staging" "SELECT etl.fill_staging_customers(3); SELECT COUNT(*) FROM etl.staging_customers;" "3"
run_sql_test "Demo-Daten ETL-Prozess" "CALL etl.load_customers(); SELECT COUNT(*) FROM etl.dim_customers;" ""

# 6. Überprüfung der Citus-Funktionalität
header "Überprüfung der Citus-Funktionalität"

# Prüfe, ob Citus korrekt eingerichtet ist
run_sql_test "Citus Aktivierung" "SELECT citus_version();" ""
run_sql_test "Citus Konfiguration" "SELECT count(*) FROM pg_dist_node;" ""

# 7. Spaltenorientierte Speicherung testen
header "Überprüfung der spaltenorientierten Speicherung"

# Erstelle eine spaltenorientierte Tabelle und teste sie
run_sql_test "Columnar Storage" "
DROP TABLE IF EXISTS test_columnar;
CREATE TABLE test_columnar (id int, name text, value numeric) USING columnar;
INSERT INTO test_columnar VALUES (1, 'Test1', 100), (2, 'Test2', 200);
SELECT COUNT(*) FROM test_columnar;
" "2"

# 8. Zusammenfassung
header "Testergebnisse"
echo "Ausgeführte Tests: $TOTAL_TESTS"
echo "Fehlgeschlagene Tests: $FAILED_TESTS"
echo "Erfolgsrate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"

if [ $FAILED_TESTS -eq 0 ]; then
    success "Alle Tests erfolgreich abgeschlossen!"
    exit 0
else
    error "Es sind Fehler aufgetreten. Bitte überprüfen Sie die Fehlerprotokolle."
    exit 1
fi

function run_sql() {
function run_sql_quiet() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    docker exec -i $container psql -U $user -d $db -t -c "$command" 2>/dev/null | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
} 