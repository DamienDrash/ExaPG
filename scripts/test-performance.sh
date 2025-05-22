#!/bin/bash
# ExaPG Performance-Testskript
# Dieses Skript führt Leistungstests für analytische Workloads in ExaPG durch

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
}

function info() {
    echo -e "  $1"
}

# Anzahl der Testdatensätze
SMALL_DATASET=10000
MEDIUM_DATASET=100000
LARGE_DATASET=1000000

# Einstellbare Parameter
TEST_SIZE=${1:-small}  # small, medium, large
REPEAT_COUNT=${2:-3}   # Anzahl der Wiederholungen pro Test

# Setze Datensatzgröße basierend auf dem Parameter
case $TEST_SIZE in
    small)
        DATASET_SIZE=$SMALL_DATASET
        ;;
    medium)
        DATASET_SIZE=$MEDIUM_DATASET
        ;;
    large)
        DATASET_SIZE=$LARGE_DATASET
        ;;
    *)
        echo "Ungültige Testgröße. Verwende 'small', 'medium' oder 'large'."
        exit 1
        ;;
esac

# Funktionen für SQL-Ausführung
function run_sql() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    docker exec -i $container psql -U $user -d $db -c "$command"
}

function run_sql_quiet() {
    local command="$1"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    docker exec -i $container psql -U $user -d $db -t -c "$command" 2>/dev/null | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function run_sql_timing() {
    local query="$1"
    local description="$2"
    local container="exapg-coordinator"
    local db="exadb"
    local user="postgres"
    
    info "Test: $description"
    info "SQL: $query"
    
    # Abfrage mit Timing-Option ausführen
    docker exec -i $container psql -U $user -d $db -c "\\timing on" -c "$query" 2>&1
}

function measure_query_time() {
    local query="$1"
    local description="$2"
    local repeat_count="$3"
    
    info "Führe '$description' $repeat_count Mal aus..."
    
    local total_time=0
    
    for (( i=1; i<=$repeat_count; i++ )); do
        # Erstelle temporäre SQL-Datei
        local tmp_file="/tmp/exapg_query_$RANDOM.sql"
        echo "$query" > "$tmp_file"
        
        # Kopiere die SQL-Datei in den Container
        docker cp "$tmp_file" exapg-coordinator:/tmp/
        
        # Zeitmessung der Abfrage
        local start_time=$(date +%s.%N)
        docker exec -i exapg-coordinator psql -U postgres -d exadb -f "/tmp/$(basename $tmp_file)" > /dev/null 2>&1
        local end_time=$(date +%s.%N)
        
        # Berechne Laufzeit in Millisekunden
        local time_taken=$(echo "($end_time - $start_time) * 1000" | bc)
        time_taken=$(printf "%.2f" "$time_taken")
        
        info "Durchlauf $i: $time_taken ms"
        total_time=$(echo "$total_time + $time_taken" | bc)
        
        # Lösche temporäre Dateien
        rm -f "$tmp_file"
        docker exec -i exapg-coordinator rm -f "/tmp/$(basename $tmp_file)" > /dev/null 2>&1
    done
    
    # Berechne Durchschnitt
    if [ $repeat_count -gt 0 ]; then
        local avg_time=$(echo "scale=2; $total_time / $repeat_count" | bc)
        # Schreibe in die CSV-Datei
        echo "$description,$avg_time" >> performance_results.csv
        success "Durchschnittliche Zeit für '$description': $avg_time ms"
    else
        error "Keine Messungen durchgeführt"
    fi
}

# Hauptfunktion zum Erstellen von Testdaten
function create_test_data() {
    local size="$1"
    
    header "Erstelle Testdaten (Größe: $size)"
    
    # Schema für Leistungstests erstellen
    info "Erstelle Test-Schema..."
    run_sql "DROP SCHEMA IF EXISTS perf_test CASCADE;
             CREATE SCHEMA perf_test;"
    
    # Reguläre PostgreSQL-Tabelle
    info "Erstelle reguläre PostgreSQL-Tabelle..."
    run_sql "CREATE TABLE perf_test.sales_regular (
                 sale_id SERIAL PRIMARY KEY,
                 customer_id INTEGER NOT NULL,
                 product_id INTEGER NOT NULL,
                 sale_date DATE NOT NULL,
                 quantity INTEGER NOT NULL,
                 amount NUMERIC(10,2) NOT NULL,
                 region TEXT NOT NULL,
                 store_id INTEGER NOT NULL
             );"
    
    # Columnar-Tabelle
    info "Erstelle spaltenorientierte Tabelle..."
    run_sql "CREATE TABLE perf_test.sales_columnar (
                 sale_id SERIAL,
                 customer_id INTEGER NOT NULL,
                 product_id INTEGER NOT NULL,
                 sale_date DATE NOT NULL,
                 quantity INTEGER NOT NULL,
                 amount NUMERIC(10,2) NOT NULL,
                 region TEXT NOT NULL,
                 store_id INTEGER NOT NULL
             ) USING columnar;"
    
    # TimescaleDB-Hypertabelle
    info "Erstelle TimescaleDB-Hypertabelle..."
    run_sql "CREATE TABLE perf_test.sales_timescale (
                 sale_id SERIAL,
                 customer_id INTEGER NOT NULL,
                 product_id INTEGER NOT NULL,
                 sale_date TIMESTAMPTZ NOT NULL,
                 quantity INTEGER NOT NULL,
                 amount NUMERIC(10,2) NOT NULL,
                 region TEXT NOT NULL,
                 store_id INTEGER NOT NULL
             );"
    run_sql "SELECT create_hypertable('perf_test.sales_timescale', 'sale_date');"
    
    # Hilfstabellen
    info "Erstelle Hilfstabellen..."
    run_sql "CREATE TABLE perf_test.customers (
                 customer_id SERIAL PRIMARY KEY,
                 customer_name TEXT NOT NULL,
                 city TEXT NOT NULL,
                 country TEXT NOT NULL
             );
             
             CREATE TABLE perf_test.products (
                 product_id SERIAL PRIMARY KEY,
                 product_name TEXT NOT NULL,
                 category TEXT NOT NULL,
                 price NUMERIC(10,2) NOT NULL
             );"
    
    # Testdaten generieren
    info "Generiere Testdaten für $size Verkäufe..."
    
    # Hilfsdaten
    info "Fülle Hilfstabellen..."
    run_sql "INSERT INTO perf_test.customers (customer_name, city, country)
             SELECT 
                 'Kunde ' || i, 
                 CASE i % 5 
                    WHEN 0 THEN 'Berlin'
                    WHEN 1 THEN 'Hamburg'
                    WHEN 2 THEN 'München'
                    WHEN 3 THEN 'Köln'
                    ELSE 'Frankfurt'
                 END,
                 'Deutschland'
             FROM generate_series(1, 1000) i;
             
             INSERT INTO perf_test.products (product_name, category, price)
             SELECT 
                 'Produkt ' || i,
                 CASE i % 10
                    WHEN 0 THEN 'Elektronik'
                    WHEN 1 THEN 'Kleidung'
                    WHEN 2 THEN 'Haushalt'
                    WHEN 3 THEN 'Sport'
                    WHEN 4 THEN 'Lebensmittel'
                    WHEN 5 THEN 'Büro'
                    WHEN 6 THEN 'Garten'
                    WHEN 7 THEN 'Spielzeug'
                    WHEN 8 THEN 'Auto'
                    ELSE 'Sonstiges'
                 END,
                 (random() * 1000)::numeric(10,2)
             FROM generate_series(1, 500) i;"
    
    # Verkaufsdaten für reguläre Tabelle
    info "Fülle reguläre Tabelle..."
    run_sql "INSERT INTO perf_test.sales_regular (customer_id, product_id, sale_date, quantity, amount, region, store_id)
             SELECT 
                 (random() * 999 + 1)::integer as customer_id,
                 (random() * 499 + 1)::integer as product_id,
                 current_date - (random() * 365)::integer as sale_date,
                 (random() * 10 + 1)::integer as quantity,
                 (random() * 1000)::numeric(10,2) as amount,
                 CASE (i % 5)
                    WHEN 0 THEN 'Nord'
                    WHEN 1 THEN 'Süd'
                    WHEN 2 THEN 'West'
                    WHEN 3 THEN 'Ost'
                    ELSE 'Zentral'
                 END as region,
                 (random() * 50 + 1)::integer as store_id
             FROM generate_series(1, $size) i;"
    
    # Daten in Columnar-Tabelle kopieren
    info "Fülle spaltenorientierte Tabelle..."
    run_sql "INSERT INTO perf_test.sales_columnar 
             SELECT * FROM perf_test.sales_regular;"
    
    # Daten in TimescaleDB-Tabelle kopieren
    info "Fülle TimescaleDB-Tabelle..."
    run_sql "INSERT INTO perf_test.sales_timescale (customer_id, product_id, sale_date, quantity, amount, region, store_id)
             SELECT 
                 customer_id, 
                 product_id, 
                 sale_date::timestamptz, 
                 quantity, 
                 amount, 
                 region, 
                 store_id
             FROM perf_test.sales_regular;"
    
    # Indizes erstellen
    info "Erstelle Indizes für bessere Performance..."
    run_sql "CREATE INDEX idx_sales_regular_date ON perf_test.sales_regular(sale_date);
             CREATE INDEX idx_sales_regular_customer ON perf_test.sales_regular(customer_id);
             CREATE INDEX idx_sales_regular_product ON perf_test.sales_regular(product_id);
             CREATE INDEX idx_sales_regular_region ON perf_test.sales_regular(region);
             
             CREATE INDEX idx_sales_columnar_date ON perf_test.sales_columnar(sale_date);
             CREATE INDEX idx_sales_columnar_customer ON perf_test.sales_columnar(customer_id);
             CREATE INDEX idx_sales_columnar_product ON perf_test.sales_columnar(product_id);
             CREATE INDEX idx_sales_columnar_region ON perf_test.sales_columnar(region);
             
             -- TimescaleDB erstellt automatisch einen Index auf dem Zeitstempelfeld"
    
    # Statistiken aktualisieren
    info "Aktualisiere Statistiken für den Optimierer..."
    run_sql "ANALYZE perf_test.sales_regular;
             ANALYZE perf_test.sales_columnar;
             ANALYZE perf_test.sales_timescale;
             ANALYZE perf_test.customers;
             ANALYZE perf_test.products;"
    
    success "Testdaten erfolgreich erstellt. Anzahl der Verkaufseinträge: $size"
}

# Hauptfunktion für Leistungstests
function run_performance_tests() {
    header "Führe Leistungstests durch"
    
    # CSV-Datei für Ergebnisse vorbereiten
    echo "Abfrage,Zeit (ms)" > performance_results.csv
    
    # 1. Einfache Aggregation
    info "Test 1: Einfache Aggregation"
    
    # Reguläre Tabelle
    measure_query_time "
        SELECT 
            COUNT(*), 
            SUM(amount), 
            AVG(amount), 
            MIN(amount), 
            MAX(amount)
        FROM 
            perf_test.sales_regular;
    " "Aggregation (Regular)" $REPEAT_COUNT
    
    # Columnar-Tabelle
    measure_query_time "
        SELECT 
            COUNT(*), 
            SUM(amount), 
            AVG(amount), 
            MIN(amount), 
            MAX(amount)
        FROM 
            perf_test.sales_columnar;
    " "Aggregation (Columnar)" $REPEAT_COUNT
    
    # TimescaleDB-Tabelle
    measure_query_time "
        SELECT 
            COUNT(*), 
            SUM(amount), 
            AVG(amount), 
            MIN(amount), 
            MAX(amount)
        FROM 
            perf_test.sales_timescale;
    " "Aggregation (TimescaleDB)" $REPEAT_COUNT
    
    # 2. Gruppierung nach Dimension
    info "Test 2: Gruppierung nach Region"
    
    # Reguläre Tabelle
    measure_query_time "
        SELECT 
            region, 
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_regular
        GROUP BY 
            region
        ORDER BY 
            region;
    " "Gruppierung nach Region (Regular)" $REPEAT_COUNT
    
    # Columnar-Tabelle
    measure_query_time "
        SELECT 
            region, 
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_columnar
        GROUP BY 
            region
        ORDER BY 
            region;
    " "Gruppierung nach Region (Columnar)" $REPEAT_COUNT
    
    # TimescaleDB-Tabelle
    measure_query_time "
        SELECT 
            region, 
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_timescale
        GROUP BY 
            region
        ORDER BY 
            region;
    " "Gruppierung nach Region (TimescaleDB)" $REPEAT_COUNT
    
    # 3. Zeitreihenabfrage
    info "Test 3: Zeitreihenabfrage (monatliche Aggregation)"
    
    # Reguläre Tabelle
    measure_query_time "
        SELECT 
            DATE_TRUNC('month', sale_date) as month,
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_regular
        GROUP BY 
            month
        ORDER BY 
            month;
    " "Zeitreihe (Regular)" $REPEAT_COUNT
    
    # Columnar-Tabelle
    measure_query_time "
        SELECT 
            DATE_TRUNC('month', sale_date) as month,
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_columnar
        GROUP BY 
            month
        ORDER BY 
            month;
    " "Zeitreihe (Columnar)" $REPEAT_COUNT
    
    # TimescaleDB-Tabelle
    measure_query_time "
        SELECT 
            time_bucket('1 month', sale_date) as month,
            COUNT(*), 
            SUM(amount), 
            AVG(amount)
        FROM 
            perf_test.sales_timescale
        GROUP BY 
            month
        ORDER BY 
            month;
    " "Zeitreihe (TimescaleDB)" $REPEAT_COUNT
    
    # 4. Join-Abfrage
    info "Test 4: Join-Abfrage mit mehreren Tabellen"
    
    # Reguläre Tabelle
    measure_query_time "
        SELECT 
            c.country,
            p.category,
            COUNT(*) as sale_count,
            SUM(s.amount) as total_amount
        FROM 
            perf_test.sales_regular s
            JOIN perf_test.customers c ON s.customer_id = c.customer_id
            JOIN perf_test.products p ON s.product_id = p.product_id
        GROUP BY 
            c.country, p.category
        ORDER BY 
            c.country, p.category;
    " "Join-Abfrage (Regular)" $REPEAT_COUNT
    
    # Columnar-Tabelle
    measure_query_time "
        SELECT 
            c.country,
            p.category,
            COUNT(*) as sale_count,
            SUM(s.amount) as total_amount
        FROM 
            perf_test.sales_columnar s
            JOIN perf_test.customers c ON s.customer_id = c.customer_id
            JOIN perf_test.products p ON s.product_id = p.product_id
        GROUP BY 
            c.country, p.category
        ORDER BY 
            c.country, p.category;
    " "Join-Abfrage (Columnar)" $REPEAT_COUNT
    
    # TimescaleDB-Tabelle
    measure_query_time "
        SELECT 
            c.country,
            p.category,
            COUNT(*) as sale_count,
            SUM(s.amount) as total_amount
        FROM 
            perf_test.sales_timescale s
            JOIN perf_test.customers c ON s.customer_id = c.customer_id
            JOIN perf_test.products p ON s.product_id = p.product_id
        GROUP BY 
            c.country, p.category
        ORDER BY 
            c.country, p.category;
    " "Join-Abfrage (TimescaleDB)" $REPEAT_COUNT
    
    # 5. Filterung mit Bereichsabfragen
    info "Test 5: Filterung mit Bereichsabfragen"
    
    # Reguläre Tabelle
    measure_query_time "
        SELECT 
            region,
            COUNT(*) as sale_count,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM 
            perf_test.sales_regular
        WHERE 
            sale_date BETWEEN current_date - interval '3 months' AND current_date
            AND amount > 500
        GROUP BY 
            region
        ORDER BY 
            total_amount DESC;
    " "Bereichsfilter (Regular)" $REPEAT_COUNT
    
    # Columnar-Tabelle
    measure_query_time "
        SELECT 
            region,
            COUNT(*) as sale_count,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM 
            perf_test.sales_columnar
        WHERE 
            sale_date BETWEEN current_date - interval '3 months' AND current_date
            AND amount > 500
        GROUP BY 
            region
        ORDER BY 
            total_amount DESC;
    " "Bereichsfilter (Columnar)" $REPEAT_COUNT
    
    # TimescaleDB-Tabelle
    measure_query_time "
        SELECT 
            region,
            COUNT(*) as sale_count,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM 
            perf_test.sales_timescale
        WHERE 
            sale_date BETWEEN current_date - interval '3 months' AND current_date
            AND amount > 500
        GROUP BY 
            region
        ORDER BY 
            total_amount DESC;
    " "Bereichsfilter (TimescaleDB)" $REPEAT_COUNT
    
    success "Alle Leistungstests abgeschlossen. Ergebnisse wurden in performance_results.csv gespeichert."
}

# Ergebnisse anzeigen
function show_results() {
    header "Leistungstest-Ergebnisse"
    
    echo "Zusammenfassung der Leistungstests (Testgröße: $TEST_SIZE, $DATASET_SIZE Datensätze)"
    echo ""
    
    if [ -f performance_results.csv ]; then
        cat performance_results.csv | column -t -s ','
    else
        error "Ergebnisdatei nicht gefunden."
    fi
    
    echo ""
    echo "Die Spaltenorientierte Speicherung (Columnar) sollte bei analytischen Abfragen"
    echo "deutlich bessere Leistung zeigen als reguläre Tabellen, besonders bei:"
    echo "  - Aggregationen über große Datenmengen"
    echo "  - Abfragen, die nur wenige Spalten verwenden"
    echo "  - Zeitreihenanalysen mit Gruppierung"
    
    echo ""
    echo "TimescaleDB sollte bei Zeitreihenabfragen bessere Leistung zeigen,"
    echo "besonders bei Abfragen mit Zeitfiltern."
}

# Hauptskript
# Prüfe, ob Docker und der Koordinator laufen
if ! docker info &> /dev/null; then
    error "Docker läuft nicht oder hat keine Berechtigungen."
    exit 1
fi

if ! docker ps | grep -q "exapg-coordinator"; then
    error "ExaPG-Koordinator läuft nicht. Bitte starten Sie zuerst ExaPG."
    exit 1
fi

# Willkommensnachricht
header "ExaPG Performance-Tests"
info "Testgröße: $TEST_SIZE ($DATASET_SIZE Datensätze)"
info "Wiederholungen pro Test: $REPEAT_COUNT"

# Führe Tests durch
create_test_data $DATASET_SIZE
run_performance_tests
show_results

header "Tests abgeschlossen"
success "Performance-Tests wurden erfolgreich durchgeführt!" 