-- Erweiterte Partitionierungsstrategien für ExaPG
-- Dieses Skript implementiert verschiedene Partitionierungsstrategien für große Tabellen

-- 1. Zeitbereichspartitionierung (tägliche, monatliche, jährliche Partitionen)
CREATE OR REPLACE FUNCTION analytics.create_time_partition(
    p_schema text,
    p_table text, 
    p_date_column text,
    p_interval text,  -- 'daily', 'monthly', 'yearly'
    p_start_date date,
    p_end_date date
) 
RETURNS void AS $$
DECLARE
    partition_name text;
    current_dt date := p_start_date;
    next_dt date;
    date_format text;
    interval_sql text;
BEGIN
    -- Formatierung basierend auf Intervall
    IF p_interval = 'daily' THEN
        date_format := 'y%Ym%md%d';
        interval_sql := '1 day';
    ELSIF p_interval = 'monthly' THEN
        date_format := 'y%Ym%m';
        interval_sql := '1 month';
    ELSIF p_interval = 'yearly' THEN
        date_format := 'y%Y';
        interval_sql := '1 year';
    ELSE
        RAISE EXCEPTION 'Unbekanntes Intervall: %. Unterstützt werden: daily, monthly, yearly', p_interval;
    END IF;
    
    -- Berechne nächstes Datum für erstes Intervall
    next_dt := current_dt + (interval_sql)::interval;
    
    -- Partitionen erstellen
    WHILE current_dt < p_end_date LOOP
        -- Partitionsnamen generieren
        partition_name := p_table || '_' || to_char(current_dt, date_format);
        
        -- Partition erstellen
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)',
            p_schema, partition_name, p_schema, p_table, current_dt, next_dt);
            
        RAISE NOTICE 'Partition erstellt: %.% (von % bis %)', 
                     p_schema, partition_name, current_dt, next_dt;
        
        -- Zum nächsten Intervall
        current_dt := next_dt;
        next_dt := current_dt + (interval_sql)::interval;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 2. Listenpartitionierung (z.B. nach Region, Kategorie, usw.)
CREATE OR REPLACE FUNCTION analytics.create_list_partitions(
    p_schema text,
    p_table text,
    p_column text,
    p_values text[]
) 
RETURNS void AS $$
DECLARE
    i int;
    partition_name text;
    value_list text;
BEGIN
    -- Für jede Werteliste eine Partition erstellen
    FOR i IN 1..array_length(p_values, 1) LOOP
        -- Partition benennen
        partition_name := p_table || '_' || p_column || '_' || i;
        
        -- Liste der Werte formatieren
        EXECUTE format('SELECT array_to_string(ARRAY[%s], '', '')', quote_literal(p_values[i])) INTO value_list;
        
        -- Partition erstellen
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %I.%I FOR VALUES IN (%s)',
            p_schema, partition_name, p_schema, p_table, value_list);
            
        RAISE NOTICE 'List-Partition erstellt: %.% (für Werte: %)', 
                     p_schema, partition_name, p_values[i];
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Hash-Partitionierung (für gleichmäßige Verteilung ohne natürliche Partitionierungsschlüssel)
CREATE OR REPLACE FUNCTION analytics.create_hash_partitions(
    p_schema text,
    p_table text,
    p_column text,
    p_modulus int
) 
RETURNS void AS $$
DECLARE
    i int;
    partition_name text;
BEGIN
    -- Hash-Partitionen erstellen
    FOR i IN 0..(p_modulus-1) LOOP
        -- Partition benennen
        partition_name := p_table || '_' || p_column || '_hash_' || i;
        
        -- Partition erstellen
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %I.%I FOR VALUES WITH (MODULUS %s, REMAINDER %s)',
            p_schema, partition_name, p_schema, p_table, p_modulus, i);
            
        RAISE NOTICE 'Hash-Partition erstellt: %.% (Modulus %, Remainder %)', 
                     p_schema, partition_name, p_modulus, i;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Automatische Partition-Vorausplanung
CREATE OR REPLACE FUNCTION analytics.auto_create_future_partitions(
    p_schema text,
    p_table text,
    p_date_column text,
    p_interval text,  -- 'daily', 'monthly', 'yearly'
    p_months_ahead int DEFAULT 3
) 
RETURNS void AS $$
DECLARE
    start_date date := current_date;
    end_date date;
BEGIN
    IF p_interval = 'daily' THEN
        end_date := start_date + (p_months_ahead * 30 || ' days')::interval;
    ELSIF p_interval = 'monthly' THEN
        end_date := start_date + (p_months_ahead || ' months')::interval;
    ELSIF p_interval = 'yearly' THEN
        end_date := start_date + (p_months_ahead / 12 + 1 || ' years')::interval;
    ELSE
        RAISE EXCEPTION 'Unbekanntes Intervall: %. Unterstützt werden: daily, monthly, yearly', p_interval;
    END IF;
    
    PERFORM analytics.create_time_partition(p_schema, p_table, p_date_column, p_interval, start_date, end_date);
    
    RAISE NOTICE 'Zukünftige Partitionen für %.% wurden für % Monate im Voraus erstellt',
                 p_schema, p_table, p_months_ahead;
END;
$$ LANGUAGE plpgsql;

-- 5. Automatische Partition-Bereinigung (Archivierung/Löschung alter Partitionen)
CREATE OR REPLACE FUNCTION analytics.manage_old_partitions(
    p_schema text,
    p_table text,
    p_date_column text,
    p_keep_months int DEFAULT 24,     -- Monate, die behalten werden sollen
    p_archive_months int DEFAULT 12,  -- Monate, die archiviert werden sollen (vor dem Löschen)
    p_archive_schema text DEFAULT 'archive'  -- Schema für archivierte Daten
) 
RETURNS void AS $$
DECLARE
    partition_record record;
    archive_date date := current_date - (p_keep_months || ' months')::interval;
    delete_date date := current_date - ((p_keep_months + p_archive_months) || ' months')::interval;
    partition_values text;
    archive_table_name text;
BEGIN
    -- Erstelle Archiv-Schema, falls es nicht existiert
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', p_archive_schema);
    
    -- Finde Partitionen, die archiviert werden sollen
    FOR partition_record IN 
        EXECUTE format(
            'SELECT child.relname AS partition_name, 
                    pg_get_expr(child.relpartbound, child.oid) AS partition_values
             FROM pg_inherits
             JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
             JOIN pg_class child ON pg_inherits.inhrelid = child.oid
             JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
             JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
             WHERE parent.relname = %L 
                AND nmsp_parent.nspname = %L
                AND pg_get_expr(child.relpartbound, child.oid) NOT LIKE ''%%DEFAULT%%''',
            p_table, p_schema)
    LOOP
        -- Extrahiere Datumsgrenzen aus Partitionsdefinition (Format: FOR VALUES FROM ('2023-01-01') TO ('2023-02-01'))
        IF partition_record.partition_values ~ 'FROM \(''([0-9-]+)''\) TO \(''([0-9-]+)''\)' THEN
            DECLARE
                partition_start_date date;
                partition_end_date date;
            BEGIN
                partition_start_date := substring(partition_record.partition_values 
                                               from 'FROM \(''([0-9-]+)''\)' for '#1')::date;
                
                -- Archivieren von Partitionen, die älter als p_keep_months sind
                IF partition_start_date < archive_date AND partition_start_date >= delete_date THEN
                    -- Name für Archivtabelle
                    archive_table_name := p_table || '_archive_' || to_char(partition_start_date, 'YYYYMM');
                    
                    -- Erstelle Archivtabelle und kopiere Daten
                    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I (LIKE %I.%I INCLUDING ALL)',
                                  p_archive_schema, archive_table_name, p_schema, partition_record.partition_name);
                    
                    EXECUTE format('INSERT INTO %I.%I SELECT * FROM %I.%I',
                                  p_archive_schema, archive_table_name, p_schema, partition_record.partition_name);
                    
                    RAISE NOTICE 'Partition %.% wurde nach %.% archiviert',
                                p_schema, partition_record.partition_name, 
                                p_archive_schema, archive_table_name;
                
                -- Löschen von Partitionen, die älter als p_keep_months + p_archive_months sind
                ELSIF partition_start_date < delete_date THEN
                    -- Lösche Partition (sicherer: erst detachen, dann löschen)
                    BEGIN
                        EXECUTE format('ALTER TABLE %I.%I DETACH PARTITION %I.%I',
                                      p_schema, p_table, p_schema, partition_record.partition_name);
                                      
                        EXECUTE format('DROP TABLE IF EXISTS %I.%I',
                                      p_schema, partition_record.partition_name);
                                      
                        RAISE NOTICE 'Alte Partition %.% wurde gelöscht',
                                    p_schema, partition_record.partition_name;
                    EXCEPTION WHEN OTHERS THEN
                        RAISE WARNING 'Fehler beim Löschen der Partition %.%: %',
                                     p_schema, partition_record.partition_name, SQLERRM;
                    END;
                END IF;
            END;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Beispiel für einen CRON-Job zur automatischen Partitionsverwaltung
-- Diese Funktion sollte regelmäßig (z.B. wöchentlich) ausgeführt werden
CREATE OR REPLACE FUNCTION analytics.maintain_all_partitioned_tables() 
RETURNS void AS $$
BEGIN
    -- Beispielanwendung für eine Verkaufstabelle
    -- Neue Partitionen erstellen
    PERFORM analytics.auto_create_future_partitions('analytics', 'sales_data', 'transaction_date', 'monthly', 6);
    
    -- Alte Partitionen verwalten
    PERFORM analytics.manage_old_partitions('analytics', 'sales_data', 'transaction_date', 24, 12);
    
    -- Hier können weitere Tabellen hinzugefügt werden
    
    RAISE NOTICE 'Partitionsverwaltung für alle Tabellen abgeschlossen';
END;
$$ LANGUAGE plpgsql;

-- Dokumentation und Beispiele:
COMMENT ON FUNCTION analytics.create_time_partition IS 
'Erstellt Zeitbereichspartitionen für eine Tabelle. 
Beispiel: SELECT analytics.create_time_partition(''analytics'', ''sales_data'', ''transaction_date'', ''monthly'', ''2023-01-01''::date, ''2023-12-31''::date);';

COMMENT ON FUNCTION analytics.create_list_partitions IS 
'Erstellt Listenpartitionen für eine Tabelle.
Beispiel: SELECT analytics.create_list_partitions(''analytics'', ''customers'', ''region'', ARRAY[''Europe'', ''North America'', ''Asia'', ''Other'']);';

COMMENT ON FUNCTION analytics.create_hash_partitions IS 
'Erstellt Hash-Partitionen für eine Tabelle.
Beispiel: SELECT analytics.create_hash_partitions(''analytics'', ''transactions'', ''id'', 8);';

COMMENT ON FUNCTION analytics.auto_create_future_partitions IS 
'Erstellt automatisch zukünftige Partitionen.
Beispiel: SELECT analytics.auto_create_future_partitions(''analytics'', ''sales_data'', ''transaction_date'', ''monthly'', 6);';

COMMENT ON FUNCTION analytics.manage_old_partitions IS 
'Verwaltet alte Partitionen (archivieren/löschen).
Beispiel: SELECT analytics.manage_old_partitions(''analytics'', ''sales_data'', ''transaction_date'', 24, 12);';

COMMENT ON FUNCTION analytics.maintain_all_partitioned_tables IS 
'Führt die Partitionsverwaltung für alle konfigurierten Tabellen durch.
Beispiel: SELECT analytics.maintain_all_partitioned_tables();'; 