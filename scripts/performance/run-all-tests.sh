#!/bin/bash
# ExaPG Haupt-Testskript
# Dieses Skript führt alle Tests für ExaPG aus und fasst die Ergebnisse zusammen

# Farbkodierung für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen für Ausgabeformatierung
function header() {
    echo -e "\n${BLUE}###################################################${NC}"
    echo -e "${BLUE}#${NC} ${YELLOW}$1${NC}"
    echo -e "${BLUE}###################################################${NC}"
}

function subheader() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
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

# Protokollierung
LOG_FILE="exapg-tests.log"
> $LOG_FILE

# Globale Variablen für Erfolgsraten
TOTAL_TEST_SUITES=0
FAILED_TEST_SUITES=0
FAILED_TESTS=0

# Aktuelles Verzeichnis ermitteln
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Prüfen, ob die erforderlichen Test-Skripte existieren
for script in "test-exapg.sh" "test-fdw.sh" "test-etl.sh" "test-performance.sh"; do
    if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
        error "Testskript ${script} nicht gefunden in ${SCRIPT_DIR}"
        exit 1
    fi
done

# Willkommensnachricht
header "ExaPG - Umfassende Testsuite"
echo "Dieses Skript führt eine vollständige Testreihe für ExaPG durch,"
echo "um sicherzustellen, dass alle Komponenten wie erwartet funktionieren."
echo ""
echo "Die folgenden Testbereiche werden geprüft:"
echo "  1. Grundfunktionalität (PostgreSQL, Erweiterungen)"
echo "  2. Foreign Data Wrapper (FDW)"
echo "  3. ETL-Prozesse"
echo "  4. Leistungstests für analytische Workloads"
echo ""

# Testparameter
TEST_SIZE=${1:-small}  # small, medium, large

# Führe eine Testsuite aus und aktualisiere die Erfolgsrate
function run_test_suite() {
    local test_script="$1"
    local description="$2"
    
    echo -e "\n###################################################" | tee -a $LOG_FILE
    echo "# $description" | tee -a $LOG_FILE
    echo "###################################################" | tee -a $LOG_FILE
    
    echo "  Führe $test_script aus..." | tee -a $LOG_FILE
    
    # Führe das Testskript aus und fange den Exit-Code ab
    bash "$test_script" $TEST_SIZE 2>&1 | tee -a $LOG_FILE
    local exit_code=${PIPESTATUS[0]}
    
    TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))
    
    if [ $exit_code -ne 0 ]; then
        FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
        echo -e "${RED}✗ $description sind fehlgeschlagen (Exit-Code: $exit_code)${NC}" | tee -a $LOG_FILE
        warning "Fehlgeschlagene Tests werden im Gesamtergebnis berücksichtigt, aber die Ausführung wird fortgesetzt" | tee -a $LOG_FILE
        return 1
    else
        echo -e "${GREEN}✓ $description erfolgreich abgeschlossen${NC}" | tee -a $LOG_FILE
        return 0
    fi
}

# Führe die Tests aus
# 1. Basis-Tests
run_test_suite "${SCRIPT_DIR}/test-exapg.sh" "Test der Grundfunktionalität"

# 2. FDW-Tests
run_test_suite "${SCRIPT_DIR}/test-fdw.sh" "Test der Foreign Data Wrapper"

# 3. ETL-Tests
run_test_suite "${SCRIPT_DIR}/test-etl.sh" "Test der ETL-Prozesse"

# 4. Performance-Tests
run_test_suite "${SCRIPT_DIR}/test-performance.sh" "Leistungstests für analytische Workloads"

# Zusammenfassung
header "Zusammenfassung der Tests"
echo "Ausgeführte Test-Suites: $TOTAL_TEST_SUITES"
echo "Fehlgeschlagene Test-Suites: $FAILED_TEST_SUITES"

if [ $TOTAL_TEST_SUITES -eq 0 ]; then
    error "Keine Tests wurden ausgeführt!"
    exit 1
fi

SUCCESS_RATE=$(( (TOTAL_TEST_SUITES - FAILED_TEST_SUITES) * 100 / TOTAL_TEST_SUITES ))
echo "Erfolgsrate: ${SUCCESS_RATE}%"

if [ $FAILED_TEST_SUITES -eq 0 ]; then
    success "Alle Tests wurden erfolgreich abgeschlossen!"
    echo ""
    echo "ExaPG ist korrekt konfiguriert und funktioniert wie erwartet."
    echo "Das System ist bereit für den produktiven Einsatz."
    exit 0
else
    error "Es sind Fehler aufgetreten. Bitte überprüfen Sie die Fehlerprotokolle."
    echo ""
    echo "Bitte prüfen Sie die Fehlermeldungen und beheben Sie die identifizierten Probleme,"
    echo "bevor Sie ExaPG in Produktion einsetzen."
    
    # Details zu den fehlgeschlagenen Tests
    echo ""
    echo "Fehlgeschlagene Tests:"
    grep -A 3 -B 1 "✗" $LOG_FILE || true
    
    exit 1
fi 