-- SQL-Kompatibilitätslayer für Exasol-Funktionen in ExaPG
-- Diese Datei implementiert Exasol-kompatible Funktionen für PostgreSQL.

-- Erstelle Schema für Kompatibilitätsfunktionen
CREATE SCHEMA IF NOT EXISTS compat;

-- Allgemeine Hilfsfunktion zum Protokollieren von Aufrufen (für Debugging)
CREATE OR REPLACE FUNCTION compat.log_function_call(func_name text, args text[]) RETURNS void AS $$
BEGIN
    -- Logik zum Protokollieren von Funktionsaufrufen hier einfügen
    -- (auskommentiert für Produktionsumgebungen)
    -- INSERT INTO compat.function_calls (function_name, arguments, call_time)
    -- VALUES (func_name, args, now());
END;
$$ LANGUAGE plpgsql;

-- Datum und Zeit

-- ADD_DAYS - Fügt Tage zu einem Datum hinzu
CREATE OR REPLACE FUNCTION compat.add_days(datum date, tage integer) RETURNS date AS $$
BEGIN
    PERFORM compat.log_function_call('ADD_DAYS', ARRAY[datum::text, tage::text]);
    RETURN datum + tage * INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ADD_MONTHS - Fügt Monate zu einem Datum hinzu
CREATE OR REPLACE FUNCTION compat.add_months(datum date, monate integer) RETURNS date AS $$
BEGIN
    PERFORM compat.log_function_call('ADD_MONTHS', ARRAY[datum::text, monate::text]);
    RETURN datum + monate * INTERVAL '1 month';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ADD_YEARS - Fügt Jahre zu einem Datum hinzu
CREATE OR REPLACE FUNCTION compat.add_years(datum date, jahre integer) RETURNS date AS $$
BEGIN
    PERFORM compat.log_function_call('ADD_YEARS', ARRAY[datum::text, jahre::text]);
    RETURN datum + jahre * INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- DAYS_BETWEEN - Anzahl der Tage zwischen zwei Daten
CREATE OR REPLACE FUNCTION compat.days_between(datum1 date, datum2 date) RETURNS integer AS $$
BEGIN
    PERFORM compat.log_function_call('DAYS_BETWEEN', ARRAY[datum1::text, datum2::text]);
    RETURN datum2 - datum1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- SECONDS_BETWEEN - Anzahl der Sekunden zwischen zwei Zeitpunkten
CREATE OR REPLACE FUNCTION compat.seconds_between(ts1 timestamp, ts2 timestamp) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('SECONDS_BETWEEN', ARRAY[ts1::text, ts2::text]);
    RETURN EXTRACT(EPOCH FROM (ts2 - ts1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- MONTHS_BETWEEN - Anzahl der Monate zwischen zwei Daten
CREATE OR REPLACE FUNCTION compat.months_between(datum1 date, datum2 date) RETURNS numeric AS $$
DECLARE
    diff_years integer;
    diff_months integer;
BEGIN
    PERFORM compat.log_function_call('MONTHS_BETWEEN', ARRAY[datum1::text, datum2::text]);
    diff_years := EXTRACT(YEAR FROM datum2) - EXTRACT(YEAR FROM datum1);
    diff_months := EXTRACT(MONTH FROM datum2) - EXTRACT(MONTH FROM datum1);
    RETURN diff_years * 12 + diff_months + 
           (EXTRACT(DAY FROM datum2) - EXTRACT(DAY FROM datum1)) / 31.0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Zeichenketten-Funktionen

-- DECODE - Ähnlich wie CASE WHEN in Exasol
CREATE OR REPLACE FUNCTION compat.decode(expr anyelement, VARIADIC comp_vals anyarray) RETURNS anyelement AS $$
DECLARE
    i INTEGER;
BEGIN
    -- Performance-Log auskommentiert für Produktion
    -- PERFORM compat.log_function_call('DECODE', ARRAY[expr::text] || comp_vals::text[]);
    
    IF array_length(comp_vals, 1) < 2 THEN
        RETURN NULL;
    END IF;

    FOR i IN 1..array_upper(comp_vals, 1) BY 2 LOOP
        IF expr = comp_vals[i] OR (expr IS NULL AND comp_vals[i] IS NULL) THEN
            -- Wenn ein Paar gefunden wurde, den entsprechenden Wert zurückgeben
            IF i + 1 <= array_upper(comp_vals, 1) THEN
                RETURN comp_vals[i + 1];
            ELSE
                RETURN NULL; -- Unvollständiges Paar
            END IF;
        END IF;
    END LOOP;

    -- Wenn nichts übereinstimmt und ein else-Wert existiert (ungerade Anzahl an Argumenten)
    IF array_length(comp_vals, 1) % 2 = 1 THEN
        RETURN comp_vals[array_upper(comp_vals, 1)];
    END IF;

    -- Kein Match und kein Else-Wert
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- EDIT_DISTANCE - Levenshtein-Distanz zwischen zwei Strings
CREATE OR REPLACE FUNCTION compat.edit_distance(str1 text, str2 text) RETURNS integer AS $$
BEGIN
    PERFORM compat.log_function_call('EDIT_DISTANCE', ARRAY[str1, str2]);
    RETURN levenshtein(str1, str2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- INSTR - Position eines Teilstrings in einem String
CREATE OR REPLACE FUNCTION compat.instr(str text, substr text, start_pos integer DEFAULT 1, occurrence integer DEFAULT 1) RETURNS integer AS $$
DECLARE
    pos integer;
    found_pos integer;
    curr_pos integer;
    remaining_occurrences integer;
BEGIN
    PERFORM compat.log_function_call('INSTR', ARRAY[str, substr, start_pos::text, occurrence::text]);
    
    IF start_pos < 1 THEN
        RETURN 0; -- Bei ungültiger Startposition 0 zurückgeben
    END IF;
    
    -- Position anpassen auf 1-basiert (wie in Exasol)
    curr_pos := start_pos;
    remaining_occurrences := occurrence;
    
    WHILE remaining_occurrences > 0 LOOP
        pos := position(substr in substring(str from curr_pos));
        
        IF pos = 0 THEN
            RETURN 0; -- Teilstring nicht gefunden
        END IF;
        
        found_pos := curr_pos + pos - 1;
        remaining_occurrences := remaining_occurrences - 1;
        
        IF remaining_occurrences = 0 THEN
            RETURN found_pos; -- Das n-te Vorkommen wurde gefunden
        END IF;
        
        curr_pos := found_pos + 1; -- Nach dem aktuellen Vorkommen suchen
    END LOOP;
    
    RETURN 0; -- Sollte nie erreicht werden
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- NULL-Behandlung

-- NVL - Gibt den ersten nicht-NULL-Wert zurück
CREATE OR REPLACE FUNCTION compat.nvl(val1 anyelement, val2 anyelement) RETURNS anyelement AS $$
BEGIN
    PERFORM compat.log_function_call('NVL', ARRAY[val1::text, val2::text]);
    RETURN COALESCE(val1, val2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- NULLIFZERO - Gibt NULL zurück, wenn der Wert 0 ist
CREATE OR REPLACE FUNCTION compat.nullifzero(num numeric) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('NULLIFZERO', ARRAY[num::text]);
    RETURN NULLIF(num, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ZEROIFNULL - Gibt 0 zurück, wenn der Wert NULL ist
CREATE OR REPLACE FUNCTION compat.zeroifnull(num numeric) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('ZEROIFNULL', ARRAY[num::text]);
    RETURN COALESCE(num, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Analytische Funktionen

-- RATIO_TO_REPORT - Verhältnis eines Wertes zur Summe aller Werte
CREATE OR REPLACE FUNCTION compat.ratio_to_report(val numeric, VARIADIC vals numeric[]) RETURNS numeric AS $$
DECLARE
    total numeric := 0;
BEGIN
    PERFORM compat.log_function_call('RATIO_TO_REPORT', ARRAY[val::text] || vals::text[]);
    
    -- Summe aller Werte berechnen
    total := val;
    FOR i IN 1..array_length(vals, 1) LOOP
        total := total + vals[i];
    END LOOP;
    
    -- Verhältnis berechnen
    IF total = 0 THEN
        RETURN 0;
    ELSE
        RETURN val / total;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mathematische Funktionen

-- ROUND - Mit speziellem Verhalten für negative Stellen
CREATE OR REPLACE FUNCTION compat.round(num numeric, places integer DEFAULT 0) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('ROUND', ARRAY[num::text, places::text]);
    
    IF places >= 0 THEN
        -- Normal runden
        RETURN round(num, places);
    ELSE
        -- Negative Stellen (z.B. -1 für 10er, -2 für 100er)
        RETURN round(num / power(10, abs(places))) * power(10, abs(places));
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- DIV - Ganzzahlige Division ohne Rest
CREATE OR REPLACE FUNCTION compat.div(dividend numeric, divisor numeric) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('DIV', ARRAY[dividend::text, divisor::text]);
    RETURN floor(dividend / divisor);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- MOD - Modulo-Funktion mit speziellem Exasol-Verhalten
CREATE OR REPLACE FUNCTION compat.mod(dividend numeric, divisor numeric) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('MOD', ARRAY[dividend::text, divisor::text]);
    RETURN dividend - floor(dividend / divisor) * divisor;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- HASH_SHA1 - SHA1-Hash als HEX-String
CREATE OR REPLACE FUNCTION compat.hash_sha1(input text) RETURNS text AS $$
BEGIN
    PERFORM compat.log_function_call('HASH_SHA1', ARRAY[input]);
    RETURN encode(sha1(input::bytea), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- HASH_MD5 - MD5-Hash als HEX-String
CREATE OR REPLACE FUNCTION compat.hash_md5(input text) RETURNS text AS $$
BEGIN
    PERFORM compat.log_function_call('HASH_MD5', ARRAY[input]);
    RETURN md5(input);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- TO_NUMBER-Funktion mit speziellem Exasol-Verhalten
CREATE OR REPLACE FUNCTION compat.to_number(str text, format text DEFAULT NULL) RETURNS numeric AS $$
BEGIN
    PERFORM compat.log_function_call('TO_NUMBER', ARRAY[str, format]);
    
    IF format IS NULL THEN
        -- Einfache Konvertierung ohne Format
        RETURN str::numeric;
    ELSE
        -- Mit Format konvertieren
        RETURN to_number(str, format);
    END IF;
EXCEPTION
    WHEN others THEN
        -- Bei Fehlern NULL zurückgeben (wie in Exasol)
        RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Register all functions into public schema with aliases
DO $$
DECLARE
    func record;
BEGIN
    FOR func IN
        SELECT p.proname as name, 
               pg_catalog.pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'compat'
    LOOP
        BEGIN
            EXECUTE format('CREATE OR REPLACE FUNCTION public.%I(%s) RETURNS %s AS
                            $FUNC$
                                SELECT compat.%I(%s);
                            $FUNC$ LANGUAGE SQL;',
                            func.name,
                            func.args,
                            pg_typeof(func.name),
                            func.name,
                            regexp_replace(func.args, '([a-zA-Z0-9_]+)(\s+[a-zA-Z0-9_]+)(\s*=\s*.+)?', '\1\3'));
        EXCEPTION WHEN others THEN
            RAISE NOTICE 'Fehler beim Erstellen der Funktion %(%): %', func.name, func.args, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- Tabelle und View für die Kompatibilitätsfunktionen
CREATE TABLE IF NOT EXISTS compat.function_info (
    function_name text PRIMARY KEY,
    exasol_syntax text,
    postgres_syntax text,
    description text,
    category text
);

-- Funktionen eintragen
INSERT INTO compat.function_info VALUES
    ('ADD_DAYS', 'ADD_DAYS(date, days)', 'date + days * INTERVAL ''1 day''', 'Fügt Tage zu einem Datum hinzu', 'Datum'),
    ('ADD_MONTHS', 'ADD_MONTHS(date, months)', 'date + months * INTERVAL ''1 month''', 'Fügt Monate zu einem Datum hinzu', 'Datum'),
    ('ADD_YEARS', 'ADD_YEARS(date, years)', 'date + years * INTERVAL ''1 year''', 'Fügt Jahre zu einem Datum hinzu', 'Datum'),
    ('DAYS_BETWEEN', 'DAYS_BETWEEN(date1, date2)', 'date2 - date1', 'Anzahl der Tage zwischen zwei Daten', 'Datum'),
    ('SECONDS_BETWEEN', 'SECONDS_BETWEEN(ts1, ts2)', 'EXTRACT(EPOCH FROM (ts2 - ts1))', 'Anzahl der Sekunden zwischen zwei Zeitpunkten', 'Datum'),
    ('MONTHS_BETWEEN', 'MONTHS_BETWEEN(date1, date2)', 'Komplexe Berechnung', 'Anzahl der Monate zwischen zwei Daten', 'Datum'),
    ('DECODE', 'DECODE(expr, val1, res1, val2, res2, ...)', 'CASE expr WHEN val1 THEN res1 WHEN val2 THEN res2 ... END', 'Vergleicht einen Ausdruck mit mehreren Werten', 'Logik'),
    ('EDIT_DISTANCE', 'EDIT_DISTANCE(str1, str2)', 'levenshtein(str1, str2)', 'Levenshtein-Distanz zwischen zwei Strings', 'String'),
    ('INSTR', 'INSTR(str, substr[, start[, occurrence]])', 'position(substr in str)', 'Position eines Teilstrings im String', 'String'),
    ('NVL', 'NVL(val1, val2)', 'COALESCE(val1, val2)', 'Gibt den ersten nicht-NULL-Wert zurück', 'NULL'),
    ('NULLIFZERO', 'NULLIFZERO(num)', 'NULLIF(num, 0)', 'Gibt NULL zurück, wenn der Wert 0 ist', 'NULL'),
    ('ZEROIFNULL', 'ZEROIFNULL(num)', 'COALESCE(num, 0)', 'Gibt 0 zurück, wenn der Wert NULL ist', 'NULL'),
    ('RATIO_TO_REPORT', 'RATIO_TO_REPORT(val) OVER (...)', 'val / SUM(val) OVER (...)', 'Verhältnis eines Wertes zur Summe aller Werte', 'Analytisch'),
    ('ROUND', 'ROUND(num, places)', 'round(num, places)', 'Rundet einen Wert mit angegebener Genauigkeit', 'Mathe'),
    ('DIV', 'DIV(dividend, divisor)', 'floor(dividend / divisor)', 'Ganzzahlige Division ohne Rest', 'Mathe'),
    ('MOD', 'MOD(dividend, divisor)', 'dividend - floor(dividend / divisor) * divisor', 'Modulo-Funktion', 'Mathe'),
    ('HASH_SHA1', 'HASH_SHA1(input)', 'encode(sha1(input::bytea), ''hex'')', 'SHA1-Hash als HEX-String', 'Hash'),
    ('HASH_MD5', 'HASH_MD5(input)', 'md5(input)', 'MD5-Hash als HEX-String', 'Hash'),
    ('TO_NUMBER', 'TO_NUMBER(str, format)', 'to_number(str, format)', 'Konvertiert einen String in eine Zahl', 'Konversion')
ON CONFLICT (function_name) DO UPDATE SET
    exasol_syntax = EXCLUDED.exasol_syntax,
    postgres_syntax = EXCLUDED.postgres_syntax,
    description = EXCLUDED.description,
    category = EXCLUDED.category;

-- View für eine benutzerfreundliche Ausgabe
CREATE OR REPLACE VIEW compat.function_reference AS
SELECT
    function_name,
    exasol_syntax,
    postgres_syntax,
    description,
    category
FROM
    compat.function_info
ORDER BY
    category, function_name;

-- View für öffentlichen Zugriff
CREATE OR REPLACE VIEW public.exapg_compat_functions AS
SELECT * FROM compat.function_reference;

-- Extension-Ersteller für einfache Installation
CREATE OR REPLACE FUNCTION compat.create_extension_script() RETURNS text AS $$
DECLARE
    sql_script text := '';
    func record;
BEGIN
    sql_script := sql_script || E'-- ExaPG Kompatibilitätsschicht für Exasol\n';
    sql_script := sql_script || E'-- Installationsscript\n\n';
    
    -- Schema erstellen
    sql_script := sql_script || E'CREATE SCHEMA IF NOT EXISTS compat;\n\n';
    
    -- Logger-Funktion erstellen
    sql_script := sql_script || E'-- Logging-Funktion\n';
    sql_script := sql_script || E'CREATE OR REPLACE FUNCTION compat.log_function_call(func_name text, args text[]) RETURNS void AS $F$\n';
    sql_script := sql_script || E'BEGIN\n    -- Logik zum Protokollieren von Funktionsaufrufen hier einfügen\nEND;\n';
    sql_script := sql_script || E'$F$ LANGUAGE plpgsql;\n\n';
    
    -- Funktionen erstellen
    FOR func IN
        SELECT p.proname as name, 
               pg_catalog.pg_get_function_definition(p.oid) as def
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'compat'
          AND p.proname != 'log_function_call'
          AND p.proname != 'create_extension_script'
        ORDER BY p.proname
    LOOP
        sql_script := sql_script || E'-- ' || func.name || E'\n';
        sql_script := sql_script || func.def || E';\n\n';
    END LOOP;
    
    -- Funktionsinfo-Tabelle erstellen
    sql_script := sql_script || E'-- Funktionsreferenz\n';
    sql_script := sql_script || E'CREATE TABLE IF NOT EXISTS compat.function_info (\n';
    sql_script := sql_script || E'    function_name text PRIMARY KEY,\n';
    sql_script := sql_script || E'    exasol_syntax text,\n';
    sql_script := sql_script || E'    postgres_syntax text,\n';
    sql_script := sql_script || E'    description text,\n';
    sql_script := sql_script || E'    category text\n);\n\n';
    
    -- Daten einfügen
    sql_script := sql_script || E'-- Funktionsdaten einfügen\n';
    sql_script := sql_script || E'INSERT INTO compat.function_info VALUES\n';
    
    FOR func IN
        SELECT function_name, exasol_syntax, postgres_syntax, description, category
        FROM compat.function_info
        ORDER BY function_name
    LOOP
        sql_script := sql_script || format(
            E'    (''%s'', ''%s'', ''%s'', ''%s'', ''%s'')%s\n',
            func.function_name,
            func.exasol_syntax,
            func.postgres_syntax,
            func.description,
            func.category,
            CASE WHEN func.function_name = (SELECT MAX(function_name) FROM compat.function_info) THEN ';' ELSE ',' END
        );
    END LOOP;
    
    sql_script := sql_script || E'\n-- Views erstellen\n';
    sql_script := sql_script || E'CREATE OR REPLACE VIEW compat.function_reference AS\n';
    sql_script := sql_script || E'SELECT function_name, exasol_syntax, postgres_syntax, description, category\n';
    sql_script := sql_script || E'FROM compat.function_info ORDER BY category, function_name;\n\n';
    
    sql_script := sql_script || E'CREATE OR REPLACE VIEW public.exapg_compat_functions AS\n';
    sql_script := sql_script || E'SELECT * FROM compat.function_reference;\n\n';
    
    sql_script := sql_script || E'-- Extension erstellt\n';
    RETURN sql_script;
END;
$$ LANGUAGE plpgsql; 