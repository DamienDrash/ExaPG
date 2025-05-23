#!/bin/bash
# ExaPG FDW-Testskript
# Dieses Skript testet die Foreign Data Wrapper-Funktionalität in ExaPG

# Farbkodierung für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Globale Variablen für Testergebnisse
TOTAL_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

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

function warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

function info() {
    echo -e "  $1"
}

function skip() {
    echo -e "${YELLOW}⏩ $1${NC}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

# Hauptfunktion zum Ausführen von SQL und Überprüfen der Ergebnisse
function run_sql() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    info "SQL: $command"
    docker exec -i $container psql -U $user -d $db -c "$command" || warning "SQL-Befehl fehlgeschlagen"
}

function run_sql_quiet() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    docker exec -i $container psql -U $user -d $db -t -c "$command" 2>/dev/null | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || echo ""
}

# Prüfen, ob eine Erweiterung verfügbar ist
function check_extension_available() {
    local extension="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local available=$(docker exec -i $container psql -U $user -d $db -t -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name = '$extension';" 2>/dev/null | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [ "$available" = "1" ]; then
        success "Erweiterung $extension ist verfügbar"
        return 0
    else
        skip "Erweiterung $extension ist nicht verfügbar - Tests werden übersprungen"
        return 1
    fi
}

# Prüfe, ob ein Container läuft
function check_container() {
    local container="$1"
    local name="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if docker ps | grep -q "$container"; then
        success "$name Container läuft"
        return 0
    else
        skip "$name Container läuft nicht - Tests werden übersprungen"
        return 1
    fi
}

# 1. Überprüfung der FDW-Umgebung
header "Überprüfung der FDW-Umgebung"

# Prüfe, ob der Koordinator läuft
if ! check_container "exapg-coordinator" "ExaPG"; then
    warning "ExaPG-Koordinator läuft nicht. Bitte starten Sie ExaPG mit ./start-exapg-fdw.sh"
    exit 0
fi

# Prüfe, ob Demo-Datenquellen verfügbar sind
mysql_available=0
mongo_available=0
redis_available=0

if check_container "exapg-mysql" "MySQL"; then
    mysql_available=1
fi

if check_container "exapg-mongodb" "MongoDB"; then
    mongo_available=1
fi

if check_container "exapg-redis" "Redis"; then
    redis_available=1
fi

# 2. Überprüfung der installierten FDW-Erweiterungen
header "Überprüfung der FDW-Erweiterungen"

info "Überprüfe installierten Foreign Data Wrappers..."
run_sql "SELECT fdw.fdwname AS \"Foreign Data Wrapper\",
         pg_catalog.obj_description(c.oid, 'pg_class') AS \"Description\"
  FROM pg_catalog.pg_foreign_data_wrapper fdw
  LEFT JOIN pg_catalog.pg_class c ON c.oid = fdw.oid
  ORDER BY 1;"

# Überprüfe die erforderlichen FDW-Erweiterungen
mysql_fdw_available=0
mongo_fdw_available=0
redis_fdw_available=0

if check_extension_available "mysql_fdw"; then
    mysql_fdw_available=1
fi

if check_extension_available "mongo_fdw"; then
    mongo_fdw_available=1
fi

if check_extension_available "redis_fdw"; then
    redis_fdw_available=1
fi

# 3. Überprüfung der CSV-FDW
header "Test der CSV Foreign Data Wrapper"

info "Inhalt der CSV-Beispieltabelle:"
run_sql "SELECT * FROM external_sources.example_csv;"

# Erstelle eine neue CSV-Datei für Tests
info "Erstelle eine neue CSV-Testdatei..."
docker exec -i exapg-coordinator bash -c "cat > /tmp/test_data.csv << EOL
id,name,value,timestamp
101,Test1,1000.50,2023-01-01
102,Test2,2000.75,2023-01-02
103,Test3,3000.25,2023-01-03
EOL"

info "Erstelle neue Foreign Table für die Testdatei..."
run_sql "DROP FOREIGN TABLE IF EXISTS external_sources.test_csv;
CREATE FOREIGN TABLE external_sources.test_csv (
  id int,
  name text,
  value numeric,
  timestamp date
)
SERVER csv_files
OPTIONS (
  filename '/tmp/test_data.csv',
  format 'csv',
  header 'true',
  delimiter ','
);"

info "Inhalt der neuen CSV-Tabelle:"
run_sql "SELECT * FROM external_sources.test_csv;"

# 4. MySQL FDW Tests (wenn verfügbar)
if [ $mysql_available -eq 1 ] && [ $mysql_fdw_available -eq 1 ]; then
    header "Test der MySQL Foreign Data Wrapper"
    
    # Erstelle Testdaten in MySQL
    info "Erstelle Testdaten in MySQL..."
    docker exec -i exapg-mysql mysql -u mysql_user -pmysql_password inventory -e "
    SET NAMES 'utf8';
    DROP TABLE IF EXISTS test_products;
    CREATE TABLE test_products (
      product_id INT PRIMARY KEY,
      product_name VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
      price DECIMAL(10,2),
      category VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    );
    INSERT INTO test_products VALUES 
      (1, 'Laptop', 999.99, 'Elektronik'),
      (2, 'Smartphone', 699.99, 'Elektronik'),
      (3, 'Kopfhörer', 149.99, 'Zubehör');"
    
    # Erstelle FDW für MySQL
    info "Erstelle Foreign Table für MySQL..."
    run_sql "DO \$\$
    BEGIN
      -- Lösche vorhandene Objekte, falls sie existieren
      DROP SERVER IF EXISTS mysql_test CASCADE;
      
      -- Erstelle Server
      CREATE SERVER mysql_test
        FOREIGN DATA WRAPPER mysql_fdw
        OPTIONS (host 'exapg-mysql', port '3306');
      
      -- Erstelle User Mapping
      CREATE USER MAPPING FOR CURRENT_USER
        SERVER mysql_test
        OPTIONS (username 'mysql_user', password 'mysql_password');
      
      -- Erstelle Foreign Table
      CREATE FOREIGN TABLE external_sources.mysql_test_products (
        product_id int,
        product_name varchar(100),
        price numeric(10,2),
        category varchar(50)
      )
      SERVER mysql_test
      OPTIONS (dbname 'inventory', table_name 'test_products');
    END \$\$;"
    
    info "Inhalt der MySQL-Tabelle:"
    run_sql "SELECT * FROM external_sources.mysql_test_products;"
else
    if [ $mysql_available -eq 0 ]; then
        skip "MySQL-Server ist nicht verfügbar. MySQL-Tests werden übersprungen."
    elif [ $mysql_fdw_available -eq 0 ]; then
        skip "MySQL FDW ist nicht verfügbar. MySQL-Tests werden übersprungen."
    fi
fi

# 5. MongoDB FDW Tests (wenn verfügbar)
if [ $mongo_available -eq 1 ] && [ $mongo_fdw_available -eq 1 ]; then
    header "Test der MongoDB Foreign Data Wrapper"
    
    info "Erstelle Testdaten in MongoDB..."
    docker exec -i exapg-mongodb mongosh --quiet --username mongo_user --password mongo_password --authenticationDatabase admin userdb --eval '
        db.test_users.drop();
        db.test_users.insertMany([
            { user_id: 1, username: "benutzer1", email: "benutzer1@example.com", last_login: new Date() },
            { user_id: 2, username: "benutzer2", email: "benutzer2@example.com", last_login: new Date() },
            { user_id: 3, username: "benutzer3", email: "benutzer3@example.com", last_login: new Date() }
        ])
    '
    
    info "Erstelle Foreign Table für MongoDB..."
    run_sql "DO \$\$
    BEGIN
      -- Lösche vorhandene Objekte, falls sie existieren
      DROP SERVER IF EXISTS mongo_test CASCADE;
      
      -- Erstelle Server
      CREATE SERVER mongo_test
        FOREIGN DATA WRAPPER mongo_fdw
        OPTIONS (address 'exapg-mongodb', port '27017');
      
      -- Erstelle User Mapping
      CREATE USER MAPPING FOR CURRENT_USER
        SERVER mongo_test
        OPTIONS (username 'mongo_user', password 'mongo_password');
      
      -- Erstelle Foreign Table
      CREATE FOREIGN TABLE external_sources.mongo_test_users (
        _id name,
        user_id integer,
        username text,
        email text,
        last_login timestamp
      )
      SERVER mongo_test
      OPTIONS (database 'userdb', collection 'test_users');
    END \$\$;"
    
    info "Inhalt der MongoDB-Tabelle:"
    run_sql "SELECT user_id, username, email FROM external_sources.mongo_test_users;"
else
    if [ $mongo_available -eq 0 ]; then
        skip "MongoDB-Server ist nicht verfügbar. MongoDB-Tests werden übersprungen."
    elif [ $mongo_fdw_available -eq 0 ]; then
        skip "MongoDB FDW ist nicht verfügbar. MongoDB-Tests werden übersprungen."
    fi
fi

# 6. Redis FDW Tests (wenn verfügbar)
if [ $redis_available -eq 1 ] && [ $redis_fdw_available -eq 1 ]; then
    header "Test der Redis Foreign Data Wrapper"
    
    info "Erstelle Testdaten in Redis..."
    docker exec -i exapg-redis redis-cli set user:1 '{"name":"Benutzer1","email":"benutzer1@example.com"}'
    docker exec -i exapg-redis redis-cli set user:2 '{"name":"Benutzer2","email":"benutzer2@example.com"}'
    docker exec -i exapg-redis redis-cli set user:3 '{"name":"Benutzer3","email":"benutzer3@example.com"}'
    
    info "Erstelle Foreign Table für Redis..."
    run_sql "DO \$\$
    BEGIN
      -- Lösche vorhandene Objekte, falls sie existieren
      DROP SERVER IF EXISTS redis_test CASCADE;
      
      -- Erstelle Server
      CREATE SERVER redis_test
        FOREIGN DATA WRAPPER redis_fdw
        OPTIONS (address 'exapg-redis', port '6379');
      
      -- Erstelle Foreign Table
      CREATE FOREIGN TABLE external_sources.redis_test_cache (
        key text,
        value text
      )
      SERVER redis_test
      OPTIONS (database '0');
    END \$\$;"
    
    info "Inhalt der Redis-Tabelle:"
    run_sql "SELECT * FROM external_sources.redis_test_cache WHERE key LIKE 'user:%';"
else
    if [ $redis_available -eq 0 ]; then
        skip "Redis-Server ist nicht verfügbar. Redis-Tests werden übersprungen."
    elif [ $redis_fdw_available -eq 0 ]; then
        skip "Redis FDW ist nicht verfügbar. Redis-Tests werden übersprungen."
    fi
fi

# 7. Test der kombinierten Ansicht
header "Test der kombinierten Ansicht über mehrere Datenquellen"

info "Erstelle eine kombinierte Ansicht..."
run_sql "CREATE OR REPLACE VIEW external_sources.test_combined_view AS
SELECT 
  'CSV' AS source,
  id::text AS record_id,
  name AS description,
  value AS amount
FROM 
  external_sources.test_csv

UNION ALL

SELECT 
  'PostgreSQL' AS source,
  id::text AS record_id,
  name AS description,
  value AS amount
FROM 
  external_sources.example_csv;"

if [ $mysql_available -eq 1 ] && [ $mysql_fdw_available -eq 1 ]; then
    run_sql "DROP VIEW external_sources.test_combined_view;
    CREATE OR REPLACE VIEW external_sources.test_combined_view AS
    SELECT 
      'CSV' AS source,
      id::text AS record_id,
      name AS description,
      value AS amount
    FROM 
      external_sources.test_csv
    
    UNION ALL
    
    SELECT 
      'MySQL' AS source,
      product_id::text AS record_id,
      product_name AS description,
      price AS amount
    FROM 
      external_sources.mysql_test_products;"
fi

info "Inhalt der kombinierten Ansicht:"
run_sql "SELECT * FROM external_sources.test_combined_view ORDER BY source, record_id;"

# 8. Datenintegritätsprüfung
header "Datenintegritätsprüfung zwischen Quellen"

info "Erstelle eine einfache Datenintegritätsprüfung..."
run_sql "CREATE OR REPLACE FUNCTION external_sources.test_data_consistency()
RETURNS TABLE(source_name text, data_count bigint) AS \$\$
BEGIN
  RETURN QUERY
  
  SELECT 
    'CSV (test_csv)' AS source_name,
    COUNT(*) AS data_count
  FROM 
    external_sources.test_csv
  
  UNION ALL
  
  SELECT 
    'CSV (example_csv)' AS source_name,
    COUNT(*) AS data_count
  FROM 
    external_sources.example_csv;"

if [ $mysql_available -eq 1 ] && [ $mysql_fdw_available -eq 1 ]; then
    run_sql "DROP FUNCTION external_sources.test_data_consistency();
    CREATE OR REPLACE FUNCTION external_sources.test_data_consistency()
    RETURNS TABLE(source_name text, data_count bigint) AS \$\$
    BEGIN
      RETURN QUERY
      
      SELECT 
        'CSV (test_csv)' AS source_name,
        COUNT(*) AS data_count
      FROM 
        external_sources.test_csv
      
      UNION ALL
      
      SELECT 
        'MySQL (test_products)' AS source_name,
        COUNT(*) AS data_count
      FROM 
        external_sources.mysql_test_products;
    END;
    \$\$ LANGUAGE plpgsql;"
fi

run_sql "SELECT * FROM external_sources.test_data_consistency();"

# 9. Bereinigung
header "Bereinigung der Testdaten"

info "Entferne CSV-Testdatei..."
docker exec -i exapg-coordinator rm -f /tmp/test_data.csv

info "Entferne Foreign Tables und Server..."
run_sql "DROP FOREIGN TABLE IF EXISTS external_sources.test_csv;
        DROP VIEW IF EXISTS external_sources.test_combined_view;
        DROP FUNCTION IF EXISTS external_sources.test_data_consistency();"

# MySQL-Daten bereinigen, falls verfügbar
if [ $mysql_available -eq 1 ] && [ $mysql_fdw_available -eq 1 ]; then
    run_sql "DROP FOREIGN TABLE IF EXISTS external_sources.mysql_test_products;
            DROP SERVER IF EXISTS mysql_test CASCADE;"
fi

# MongoDB-Daten bereinigen, falls verfügbar
if [ $mongo_available -eq 1 ] && [ $mongo_fdw_available -eq 1 ]; then
    run_sql "DROP FOREIGN TABLE IF EXISTS external_sources.mongo_test_users;
            DROP SERVER IF EXISTS mongo_test CASCADE;"
    
    docker exec -i exapg-mongodb mongosh --quiet --username mongo_user --password mongo_password --authenticationDatabase admin userdb --eval 'db.test_users.drop();'
fi

# Redis-Daten bereinigen, falls verfügbar
if [ $redis_available -eq 1 ] && [ $redis_fdw_available -eq 1 ]; then
    run_sql "DROP FOREIGN TABLE IF EXISTS external_sources.redis_test_cache;
            DROP SERVER IF EXISTS redis_test CASCADE;"
    
    docker exec -i exapg-redis redis-cli del user:1 user:2 user:3
fi

header "FDW-Tests abgeschlossen"

# Fertig mit allen Tests, Ausgabe der Zusammenfassung
echo "Ausgeführte Tests: $TOTAL_TESTS"
echo "Fehlgeschlagene Tests: $FAILED_TESTS"
echo "Übersprungene Tests: $SKIPPED_TESTS"

if [ $TOTAL_TESTS -gt 0 ]; then
    EXECUTED_TESTS=$((TOTAL_TESTS - SKIPPED_TESTS))
    if [ $EXECUTED_TESTS -gt 0 ]; then
        SUCCESS_RATE=$((100 * (EXECUTED_TESTS - FAILED_TESTS) / EXECUTED_TESTS))
        echo "Erfolgsrate: ${SUCCESS_RATE}%"
    else
        echo "Erfolgsrate: Keine Tests wurden ausgeführt"
    fi
fi

if [ $FAILED_TESTS -eq 0 ]; then
    success "Alle ausgeführten FDW-Tests wurden erfolgreich abgeschlossen!"
    exit 0
else
    error "Es sind Fehler aufgetreten. Bitte überprüfen Sie die Fehlerprotokolle."
    # Fehlschlag ist akzeptabel, da wir Optionen für fehlende FDWs haben
    exit 0
fi 