-- Funktion zum Erstellen von analytischen Tabellen mit optimaler Kompression
CREATE OR REPLACE FUNCTION public.create_analytics_table(
    schema_name text,
    table_name text,
    column_definitions text
) 
RETURNS void AS $$
BEGIN
    -- Setze optimale Kompressionswerte
    EXECUTE 'SET columnar.compression TO ''zstd''';
    EXECUTE 'SET columnar.compression_level TO 3';
    
    -- Erstelle die Tabelle mit Columnar-Speicherung
    EXECUTE 'CREATE TABLE ' || quote_ident(schema_name) || '.' || quote_ident(table_name) || 
            ' (' || column_definitions || ') USING columnar';
    
    RAISE NOTICE 'Analytische Tabelle %.% mit optimierter Kompression erstellt', 
                 schema_name, table_name;
END;
$$ LANGUAGE plpgsql; 