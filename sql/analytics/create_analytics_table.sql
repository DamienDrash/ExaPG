-- Sichere Funktion zum Erstellen von analytischen Tabellen mit optimaler Kompression
-- SECURITY FIX: Ersetzt unsichere Dynamic SQL mit sicherer Implementation
CREATE OR REPLACE FUNCTION public.create_analytics_table(
    schema_name text,
    table_name text,
    column_definitions text
) 
RETURNS void AS $$
DECLARE
    full_table_name text;
    safe_column_definitions text;
BEGIN
    -- SECURITY: Strikte Input-Validierung
    IF schema_name IS NULL OR table_name IS NULL OR column_definitions IS NULL THEN
        RAISE EXCEPTION 'All parameters must be non-null';
    END IF;
    
    -- SECURITY: Validiere Schema-Name (nur alphanumerisch + Underscore)
    IF schema_name !~ '^[a-zA-Z_][a-zA-Z0-9_]*$' THEN
        RAISE EXCEPTION 'Invalid schema name: %. Must match pattern: ^[a-zA-Z_][a-zA-Z0-9_]*$', schema_name;
    END IF;
    
    -- SECURITY: Validiere Tabellen-Name (nur alphanumerisch + Underscore)
    IF table_name !~ '^[a-zA-Z_][a-zA-Z0-9_]*$' THEN
        RAISE EXCEPTION 'Invalid table name: %. Must match pattern: ^[a-zA-Z_][a-zA-Z0-9_]*$', table_name;
    END IF;
    
    -- SECURITY: Längen-Limits
    IF length(schema_name) > 63 OR length(table_name) > 63 THEN
        RAISE EXCEPTION 'Schema and table names must not exceed 63 characters';
    END IF;
    
    -- SECURITY: Validiere Column-Definitions (basic SQL syntax check)
    -- Erlaubte Zeichen: a-z, A-Z, 0-9, space, comma, parentheses, underscore
    IF column_definitions !~ '^[a-zA-Z0-9\s,()_]+$' THEN
        RAISE EXCEPTION 'Invalid characters in column definitions. Only alphanumeric, spaces, commas, parentheses, and underscores allowed';
    END IF;
    
    -- SECURITY: Prüfe auf SQL-Injection Patterns
    IF column_definitions ~* '(drop|delete|update|insert|exec|execute|;|\-\-|\/\*|\*\/|xp_|sp_)' THEN
        RAISE EXCEPTION 'Potentially dangerous SQL patterns detected in column definitions';
    END IF;
    
    -- SECURITY: Sichere Identifier-Quotierung mit format()
    full_table_name := format('%I.%I', schema_name, table_name);
    
    -- SECURITY: Sanitize column definitions (remove extra spaces, normalize)
    safe_column_definitions := regexp_replace(column_definitions, '\s+', ' ', 'g');
    safe_column_definitions := trim(safe_column_definitions);
    
    -- Schema existiert prüfen und ggf. erstellen
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = create_analytics_table.schema_name) THEN
        EXECUTE format('CREATE SCHEMA %I', schema_name);
        RAISE NOTICE 'Schema % created', schema_name;
    END IF;
    
    -- Tabelle existiert bereits prüfen
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = create_analytics_table.schema_name 
        AND table_name = create_analytics_table.table_name
    ) THEN
        RAISE EXCEPTION 'Table %.% already exists', schema_name, table_name;
    END IF;
    
    -- Setze optimale Kompressionswerte
    EXECUTE 'SET columnar.compression TO ''zstd''';
    EXECUTE 'SET columnar.compression_level TO 3';
    EXECUTE 'SET columnar.stripe_row_count TO 150000';
    
    -- SECURITY: Sichere Tabellenerstellung mit format() und %I für Identifier
    EXECUTE format('CREATE TABLE %I.%I (%s) USING columnar', 
                   schema_name, 
                   table_name, 
                   safe_column_definitions);
    
    -- Statistiken aktivieren
    EXECUTE format('ALTER TABLE %I.%I SET (autovacuum_enabled = false)', schema_name, table_name);
    EXECUTE format('ALTER TABLE %I.%I SET (toast.autovacuum_enabled = false)', schema_name, table_name);
    
    RAISE NOTICE 'Secure analytics table %.% created with optimized compression (ZSTD level 3)', 
                 schema_name, table_name;
    
EXCEPTION
    WHEN OTHERS THEN
        -- SECURITY: Sichere Fehlerbehandlung ohne sensitive Daten
        RAISE EXCEPTION 'Failed to create analytics table: %', SQLERRM
        USING HINT = 'Check table name, schema name, and column definitions for validity';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp; 