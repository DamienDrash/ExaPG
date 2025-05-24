-- Test Suite für SQL Injection Prevention
-- Testet die gesicherte create_analytics_table Funktion

-- Test 1: Normale, gültige Verwendung sollte funktionieren
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        'test_schema', 
        'valid_table', 
        'id INTEGER, name TEXT, value NUMERIC'
    );
    RAISE NOTICE 'TEST 1 PASSED: Valid table creation works';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 1 FAILED: %, %', SQLSTATE, SQLERRM;
END $$;

-- Test 2: SQL Injection Versuch - DROP TABLE sollte verhindert werden
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        'test_schema', 
        'injection_test', 
        'id INTEGER); DROP TABLE test_schema.valid_table; --'
    );
    RAISE NOTICE 'TEST 2 FAILED: SQL injection was not prevented!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 2 PASSED: SQL injection prevented - %', SQLERRM;
END $$;

-- Test 3: Ungültiger Schema-Name
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        'bad-schema-name!', 
        'test_table', 
        'id INTEGER'
    );
    RAISE NOTICE 'TEST 3 FAILED: Invalid schema name was accepted!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 3 PASSED: Invalid schema name rejected - %', SQLERRM;
END $$;

-- Test 4: Ungültiger Tabellen-Name
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        'test_schema', 
        'table"with"quotes', 
        'id INTEGER'
    );
    RAISE NOTICE 'TEST 4 FAILED: Invalid table name was accepted!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 4 PASSED: Invalid table name rejected - %', SQLERRM;
END $$;

-- Test 5: SQL Injection via Schema-Name
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        '; DROP DATABASE postgres; --', 
        'test_table', 
        'id INTEGER'
    );
    RAISE NOTICE 'TEST 5 FAILED: Schema injection was not prevented!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 5 PASSED: Schema injection prevented - %', SQLERRM;
END $$;

-- Test 6: NULL-Parameter sollten abgelehnt werden
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        NULL, 
        'test_table', 
        'id INTEGER'
    );
    RAISE NOTICE 'TEST 6 FAILED: NULL parameter was accepted!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 6 PASSED: NULL parameter rejected - %', SQLERRM;
END $$;

-- Test 7: Zu lange Namen sollten abgelehnt werden
DO $$
BEGIN
    PERFORM public.create_analytics_table(
        'very_long_schema_name_that_exceeds_the_postgresql_limit_of_63_chars', 
        'test_table', 
        'id INTEGER'
    );
    RAISE NOTICE 'TEST 7 FAILED: Overlong name was accepted!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 7 PASSED: Overlong name rejected - %', SQLERRM;
END $$;

-- Cleanup: Entferne Test-Daten
DO $$
BEGIN
    DROP TABLE IF EXISTS test_schema.valid_table CASCADE;
    DROP SCHEMA IF EXISTS test_schema CASCADE;
    RAISE NOTICE 'Cleanup completed';
EXCEPTION 
    WHEN OTHERS THEN
        -- Cleanup Fehler ignorieren
        NULL;
END $$; 