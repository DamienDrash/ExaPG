-- ExaPG - ETL-Framework Hilfsfunktionen
-- SQL-Skript mit Hilfsfunktionen für das ETL-Framework

-- Funktion zum Erstellen einer optimierten Tabelle für ETL-Ziele
CREATE OR REPLACE FUNCTION etl_framework.create_target_table(
    p_job_id INTEGER,
    p_drop_if_exists BOOLEAN DEFAULT FALSE
) RETURNS BOOLEAN AS $$
DECLARE
    v_target_schema VARCHAR(100);
    v_target_table VARCHAR(100);
    v_columns TEXT := '';
    v_pk_columns TEXT := '';
    v_sql TEXT;
    v_mapping RECORD;
BEGIN
    -- Hole Zielschema und -tabelle
    SELECT target_schema, target_table INTO v_target_schema, v_target_table
    FROM etl_framework.etl_jobs
    WHERE job_id = p_job_id;
    
    IF v_target_schema IS NULL THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Erstelle das Schema, falls es nicht existiert
    EXECUTE 'CREATE SCHEMA IF NOT EXISTS ' || quote_ident(v_target_schema);
    
    -- Drop die Tabelle, falls angefordert und sie existiert
    IF p_drop_if_exists THEN
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table);
    END IF;
    
    -- Hole die Spaltendefinitionen aus dem Mapping
    FOR v_mapping IN
        SELECT 
            target_column, 
            data_type, 
            is_nullable, 
            default_value,
            is_primary_key
        FROM 
            etl_framework.column_mappings
        WHERE 
            job_id = p_job_id
        ORDER BY 
            mapping_id
    LOOP
        -- Füge Komma hinzu, wenn nicht die erste Spalte
        IF v_columns <> '' THEN
            v_columns := v_columns || ', ';
        END IF;
        
        -- Baue Spaltendefinition
        v_columns := v_columns || quote_ident(v_mapping.target_column) || ' ' || v_mapping.data_type;
        
        -- Füge NULL/NOT NULL hinzu
        IF NOT v_mapping.is_nullable THEN
            v_columns := v_columns || ' NOT NULL';
        END IF;
        
        -- Füge DEFAULT-Wert hinzu, falls vorhanden
        IF v_mapping.default_value IS NOT NULL THEN
            v_columns := v_columns || ' DEFAULT ' || v_mapping.default_value;
        END IF;
        
        -- Sammle Primärschlüsselspalten
        IF v_mapping.is_primary_key THEN
            IF v_pk_columns <> '' THEN
                v_pk_columns := v_pk_columns || ', ';
            END IF;
            v_pk_columns := v_pk_columns || quote_ident(v_mapping.target_column);
        END IF;
    END LOOP;
    
    -- Füge Primärschlüssel hinzu, falls vorhanden
    IF v_pk_columns <> '' THEN
        v_columns := v_columns || ', PRIMARY KEY (' || v_pk_columns || ')';
    END IF;
    
    -- Erstelle die Zieltabelle
    v_sql := 'CREATE TABLE IF NOT EXISTS ' || 
             quote_ident(v_target_schema) || '.' || quote_ident(v_target_table) || 
             '(' || v_columns || ')';
    
    EXECUTE v_sql;
    
    -- Erstelle notwendige Indizes basierend auf dem Job-Typ
    PERFORM etl_framework.create_target_indexes(p_job_id);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Erstellen optimaler Indizes für ETL-Zieltabellen
CREATE OR REPLACE FUNCTION etl_framework.create_target_indexes(
    p_job_id INTEGER
) RETURNS VOID AS $$
DECLARE
    v_target_schema VARCHAR(100);
    v_target_table VARCHAR(100);
    v_is_incremental BOOLEAN;
    v_incremental_column VARCHAR(100);
    v_idx_name VARCHAR(100);
    v_mapping RECORD;
BEGIN
    -- Hole Tabelleninformationen und Job-Konfiguration
    SELECT 
        target_schema, 
        target_table, 
        is_incremental,
        incremental_column
    INTO 
        v_target_schema, 
        v_target_table, 
        v_is_incremental,
        v_incremental_column
    FROM 
        etl_framework.etl_jobs
    WHERE 
        job_id = p_job_id;
    
    -- Erstelle Index für die Inkrementalspalte, falls vorhanden
    IF v_is_incremental AND v_incremental_column IS NOT NULL THEN
        v_idx_name := 'idx_' || v_target_table || '_' || v_incremental_column;
        
        EXECUTE 'CREATE INDEX IF NOT EXISTS ' || quote_ident(v_idx_name) || 
                ' ON ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table) || 
                '(' || quote_ident(v_incremental_column) || ')';
    END IF;
    
    -- Erstelle Indizes für Fremdschlüsselspalten
    FOR v_mapping IN
        SELECT 
            target_column, 
            source_column
        FROM 
            etl_framework.column_mappings
        WHERE 
            job_id = p_job_id AND
            (target_column LIKE '%\_id' OR target_column LIKE '%\_key' OR target_column LIKE 'id\_%' OR target_column LIKE 'key\_%')
    LOOP
        v_idx_name := 'idx_' || v_target_table || '_' || v_mapping.target_column;
        
        -- Erstelle keinen zusätzlichen Index für die Inkrementalspalte
        IF v_mapping.target_column <> v_incremental_column THEN
            EXECUTE 'CREATE INDEX IF NOT EXISTS ' || quote_ident(v_idx_name) || 
                    ' ON ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table) || 
                    '(' || quote_ident(v_mapping.target_column) || ')';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Optimierter COPY-Befehl für hohe Durchsatzraten
CREATE OR REPLACE FUNCTION etl_framework.optimized_copy(
    p_job_id INTEGER,
    p_file_path TEXT,
    p_format TEXT DEFAULT 'CSV',
    p_delimiter TEXT DEFAULT ',',
    p_null_string TEXT DEFAULT '',
    p_header BOOLEAN DEFAULT TRUE,
    p_encoding TEXT DEFAULT 'UTF8',
    p_quote TEXT DEFAULT '"',
    p_escape TEXT DEFAULT '"',
    p_truncate_before BOOLEAN DEFAULT FALSE
) RETURNS BIGINT AS $$
DECLARE
    v_target_schema VARCHAR(100);
    v_target_table VARCHAR(100);
    v_batch_size INTEGER;
    v_parallel_workers INTEGER;
    v_copy_options TEXT;
    v_sql TEXT;
    v_rows_loaded BIGINT;
BEGIN
    -- Hole Job-Informationen
    SELECT 
        target_schema, 
        target_table, 
        batch_size,
        parallel_workers
    INTO 
        v_target_schema, 
        v_target_table, 
        v_batch_size,
        v_parallel_workers
    FROM 
        etl_framework.etl_jobs
    WHERE 
        job_id = p_job_id;
    
    IF v_target_schema IS NULL THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Truncate die Zieltabelle, falls angefordert
    IF p_truncate_before THEN
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table);
    END IF;
    
    -- Baue COPY-Optionen
    v_copy_options := 
        FORMAT('%s DELIMITER %L NULL %L QUOTE %L ESCAPE %L ENCODING %L', 
               p_format, 
               p_delimiter, 
               p_null_string, 
               p_quote, 
               p_escape, 
               p_encoding);
    
    -- Füge HEADER-Option hinzu, falls erforderlich
    IF p_header THEN
        v_copy_options := v_copy_options || ' HEADER';
    END IF;
    
    -- Optimierung: Verwende alle verfügbaren Worker für paralleles Laden
    SET max_parallel_workers_per_gather = v_parallel_workers;
    SET work_mem = '256MB';  -- Erhöhe Arbeitsspeicher für COPY
    
    -- Führe optimierten COPY-Befehl aus
    v_sql := FORMAT('COPY %I.%I FROM %L WITH (%s)',
                   v_target_schema,
                   v_target_table,
                   p_file_path,
                   v_copy_options);
    
    EXECUTE v_sql;
    
    -- Hole die Anzahl der geladenen Zeilen
    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    
    -- Setze Parameter zurück
    RESET max_parallel_workers_per_gather;
    RESET work_mem;
    
    RETURN v_rows_loaded;
END;
$$ LANGUAGE plpgsql;

-- Funktion zur Batch-weisen Verarbeitung für bessere Performance bei großen Datensätzen
CREATE OR REPLACE FUNCTION etl_framework.batch_process_data(
    p_job_id INTEGER,
    p_truncate_target BOOLEAN DEFAULT FALSE
) RETURNS JSONB AS $$
DECLARE
    v_source_type VARCHAR(50);
    v_source_connection JSONB;
    v_target_schema VARCHAR(100);
    v_target_table VARCHAR(100);
    v_transformation_sql TEXT;
    v_batch_size INTEGER;
    v_is_incremental BOOLEAN;
    v_incremental_column VARCHAR(100);
    v_last_value TEXT;
    v_where_clause TEXT := '';
    v_order_by_clause TEXT := '';
    v_sql TEXT;
    v_run_id INTEGER;
    v_total_processed BIGINT := 0;
    v_total_loaded BIGINT := 0;
    v_total_rejected BIGINT := 0;
    v_start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
    v_batch_start TIMESTAMP WITH TIME ZONE;
    v_batch_end TIMESTAMP WITH TIME ZONE;
    v_batch_time INTERVAL;
    v_batch_count INTEGER := 0;
    v_last_processed_value TEXT;
    v_result JSONB;
BEGIN
    -- Hole Job-Informationen
    SELECT 
        source_type, 
        source_connection,
        target_schema,
        target_table,
        transformation_sql,
        batch_size,
        is_incremental,
        incremental_column,
        last_value
    INTO 
        v_source_type,
        v_source_connection,
        v_target_schema,
        v_target_table,
        v_transformation_sql,
        v_batch_size,
        v_is_incremental,
        v_incremental_column,
        v_last_value
    FROM 
        etl_framework.etl_jobs
    WHERE 
        job_id = p_job_id;
    
    IF v_source_type IS NULL THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Erstelle einen neuen Job-Run-Eintrag
    INSERT INTO etl_framework.etl_job_runs(job_id)
    VALUES (p_job_id)
    RETURNING run_id INTO v_run_id;
    
    -- Truncate die Zieltabelle, falls angefordert und nicht inkrementell
    IF p_truncate_target AND NOT v_is_incremental THEN
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table);
    END IF;
    
    -- Erstelle WHERE-Klausel für inkrementelle Ladungen
    IF v_is_incremental AND v_incremental_column IS NOT NULL AND v_last_value IS NOT NULL THEN
        v_where_clause := ' WHERE ' || quote_ident(v_incremental_column) || ' > ' || quote_literal(v_last_value);
        v_order_by_clause := ' ORDER BY ' || quote_ident(v_incremental_column);
    END IF;
    
    -- Setze Arbeitsspeicher für bessere Performance
    SET work_mem = '256MB';
    
    -- Iteriere durch Batches, bis keine Daten mehr vorhanden sind
    LOOP
        v_batch_start := clock_timestamp();
        
        -- Baue SQL für diesen Batch
        IF v_transformation_sql IS NOT NULL THEN
            v_sql := v_transformation_sql;
        ELSE
            -- Einfache 1:1-Kopie
            v_sql := 'INSERT INTO ' || quote_ident(v_target_schema) || '.' || quote_ident(v_target_table) || 
                    ' SELECT * FROM ' || v_source_connection->>'schema' || '.' || v_source_connection->>'table';
        END IF;
        
        -- Füge WHERE-Klausel hinzu für die Batch-Verarbeitung
        IF v_batch_count > 0 AND v_is_incremental AND v_incremental_column IS NOT NULL AND v_last_processed_value IS NOT NULL THEN
            IF v_where_clause = '' THEN
                v_where_clause := ' WHERE ' || quote_ident(v_incremental_column) || ' > ' || quote_literal(v_last_processed_value);
            ELSE
                v_where_clause := ' WHERE ' || quote_ident(v_incremental_column) || ' > ' || quote_literal(v_last_processed_value);
            END IF;
        END IF;
        
        -- Füge LIMIT und ORDER BY hinzu
        v_sql := v_sql || v_where_clause || v_order_by_clause || ' LIMIT ' || v_batch_size;
        
        -- Führe den Batch aus
        BEGIN
            EXECUTE v_sql;
            GET DIAGNOSTICS v_total_loaded = v_total_loaded + ROW_COUNT;
            v_total_processed := v_total_processed + ROW_COUNT;
            
            -- Wenn keine Zeilen geladen wurden, beende die Schleife
            EXIT WHEN ROW_COUNT = 0;
            
            -- Aktualisiere das Zuletzt-Verarbeitete für den nächsten Batch
            IF v_is_incremental AND v_incremental_column IS NOT NULL THEN
                EXECUTE 'SELECT MAX(' || quote_ident(v_incremental_column) || ')::TEXT FROM ' ||
                        quote_ident(v_target_schema) || '.' || quote_ident(v_target_table)
                INTO v_last_processed_value;
                
                -- Aktualisiere den last_value im Job
                UPDATE etl_framework.etl_jobs
                SET last_value = v_last_processed_value
                WHERE job_id = p_job_id;
            END IF;
            
            v_batch_count := v_batch_count + 1;
            v_batch_end := clock_timestamp();
            v_batch_time := v_batch_end - v_batch_start;
            
            -- Logging für diesen Batch
            RAISE NOTICE 'Batch % verarbeitet: % Zeilen in % Sekunden', 
                         v_batch_count, 
                         ROW_COUNT, 
                         EXTRACT(EPOCH FROM v_batch_time);
                        
        EXCEPTION WHEN OTHERS THEN
            -- Protokolliere Fehler und zähle abgelehnte Zeilen
            v_total_rejected := v_total_rejected + v_batch_size;
            
            RAISE WARNING 'Fehler beim Verarbeiten von Batch %: %', v_batch_count, SQLERRM;
            
            -- Aktualisiere den Job-Run mit Fehlerinformationen
            UPDATE etl_framework.etl_job_runs
            SET error_message = error_message || 
                                CASE WHEN error_message IS NULL THEN '' ELSE E'\n' END || 
                                'Batch ' || v_batch_count || ': ' || SQLERRM
            WHERE run_id = v_run_id;
            
            -- Fortsetzen mit dem nächsten Batch
            CONTINUE;
        END;
    END LOOP;
    
    -- Aktualisiere den Job-Run mit den Ergebnissen
    UPDATE etl_framework.etl_job_runs
    SET end_time = clock_timestamp(),
        status = CASE 
                    WHEN v_total_loaded > 0 THEN 'SUCCESS' 
                    ELSE 'FAILED' 
                 END,
        rows_processed = v_total_processed,
        rows_loaded = v_total_loaded,
        rows_rejected = v_total_rejected,
        execution_details = jsonb_build_object(
            'batches', v_batch_count,
            'avg_batch_time_ms', CASE 
                                    WHEN v_batch_count > 0 
                                    THEN EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000 / v_batch_count 
                                    ELSE 0 
                                  END,
            'last_processed_value', v_last_processed_value
        )
    WHERE run_id = v_run_id;
    
    -- Setze Arbeitsspeicher zurück
    RESET work_mem;
    
    -- Führe Datenqualitätsprüfungen durch
    PERFORM etl_framework.run_data_quality_checks(p_job_id, v_run_id);
    
    -- Erstelle Ergebnisobjekt
    v_result := jsonb_build_object(
        'run_id', v_run_id,
        'job_id', p_job_id,
        'rows_processed', v_total_processed,
        'rows_loaded', v_total_loaded,
        'rows_rejected', v_total_rejected,
        'execution_time_seconds', EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)),
        'batches', v_batch_count,
        'last_processed_value', v_last_processed_value
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Funktion zur Ausführung von Datenqualitätsprüfungen
CREATE OR REPLACE FUNCTION etl_framework.run_data_quality_checks(
    p_job_id INTEGER,
    p_run_id INTEGER
) RETURNS JSONB AS $$
DECLARE
    v_check RECORD;
    v_target_schema VARCHAR(100);
    v_target_table VARCHAR(100);
    v_sql TEXT;
    v_value_checked FLOAT;
    v_passed BOOLEAN;
    v_error_records JSONB;
    v_error_message TEXT;
    v_total_checks INTEGER := 0;
    v_passed_checks INTEGER := 0;
    v_failed_checks INTEGER := 0;
    v_results JSONB := '[]';
BEGIN
    -- Hole Zielschema und -tabelle
    SELECT target_schema, target_table
    INTO v_target_schema, v_target_table
    FROM etl_framework.etl_jobs
    WHERE job_id = p_job_id;
    
    -- Führe jede Datenqualitätsprüfung durch
    FOR v_check IN
        SELECT 
            check_id, 
            check_name, 
            check_type, 
            check_sql, 
            severity, 
            threshold
        FROM 
            etl_framework.data_quality_checks
        WHERE 
            job_id = p_job_id AND 
            enabled = TRUE
    LOOP
        v_total_checks := v_total_checks + 1;
        
        BEGIN
            -- Ersetze Platzhalter im SQL
            v_sql := replace(v_check.check_sql, '{target_schema}', quote_ident(v_target_schema));
            v_sql := replace(v_sql, '{target_table}', quote_ident(v_target_table));
            
            -- Führe die Prüfung aus
            EXECUTE v_sql INTO v_value_checked;
            
            -- Bestimme, ob die Prüfung bestanden wurde
            IF v_check.check_type IN ('null_check', 'unique_check', 'range_check', 'referential_check') AND v_check.threshold IS NOT NULL THEN
                v_passed := (v_value_checked <= v_check.threshold);
            ELSE
                v_passed := (v_value_checked > 0);
            END IF;
            
            -- Sammle fehlerhafte Datensätze, falls die Prüfung fehlgeschlagen ist
            IF NOT v_passed THEN
                -- SQL zur Identifizierung der fehlerhaften Datensätze (Stichprobe)
                v_sql := replace(v_check.check_sql, 'COUNT(*)', 'jsonb_agg(t.*) LIMIT 10');
                v_sql := 'WITH error_records AS (' || v_sql || ') SELECT * FROM error_records';
                
                BEGIN
                    EXECUTE v_sql INTO v_error_records;
                EXCEPTION WHEN OTHERS THEN
                    v_error_records := NULL;
                END;
                
                v_error_message := format('Datenqualitätsprüfung fehlgeschlagen: %s (erwartet: ≤ %s, tatsächlich: %s)', 
                                          v_check.check_name, 
                                          COALESCE(v_check.threshold::TEXT, 'N/A'), 
                                          v_value_checked::TEXT);
                
                v_failed_checks := v_failed_checks + 1;
            ELSE
                v_error_records := NULL;
                v_error_message := NULL;
                v_passed_checks := v_passed_checks + 1;
            END IF;
            
            -- Speichere das Ergebnis
            INSERT INTO etl_framework.data_quality_results(
                run_id,
                check_id,
                passed,
                value_checked,
                error_records,
                error_message
            ) VALUES (
                p_run_id,
                v_check.check_id,
                v_passed,
                v_value_checked,
                v_error_records,
                v_error_message
            );
            
            -- Füge das Ergebnis zum JSON-Array hinzu
            v_results := v_results || jsonb_build_object(
                'check_id', v_check.check_id,
                'check_name', v_check.check_name,
                'passed', v_passed,
                'value_checked', v_value_checked,
                'threshold', v_check.threshold,
                'severity', v_check.severity
            );
            
        EXCEPTION WHEN OTHERS THEN
            -- Protokolliere Fehler bei der Ausführung der Prüfung
            INSERT INTO etl_framework.data_quality_results(
                run_id,
                check_id,
                passed,
                error_message
            ) VALUES (
                p_run_id,
                v_check.check_id,
                FALSE,
                'Fehler bei der Ausführung der Prüfung: ' || SQLERRM
            );
            
            v_failed_checks := v_failed_checks + 1;
            
            -- Füge den Fehler zum JSON-Array hinzu
            v_results := v_results || jsonb_build_object(
                'check_id', v_check.check_id,
                'check_name', v_check.check_name,
                'passed', FALSE,
                'error', SQLERRM,
                'severity', v_check.severity
            );
        END;
    END LOOP;
    
    -- Aktualisiere den Job-Run mit den Qualitätsprüfungsergebnissen
    UPDATE etl_framework.etl_job_runs
    SET execution_details = COALESCE(execution_details, '{}'::JSONB) || jsonb_build_object(
        'data_quality', jsonb_build_object(
            'total_checks', v_total_checks,
            'passed_checks', v_passed_checks,
            'failed_checks', v_failed_checks,
            'quality_score', CASE 
                                WHEN v_total_checks > 0 
                                THEN (v_passed_checks::FLOAT / v_total_checks * 100) 
                                ELSE NULL 
                              END
        )
    )
    WHERE run_id = p_run_id;
    
    RETURN jsonb_build_object(
        'total_checks', v_total_checks,
        'passed_checks', v_passed_checks,
        'failed_checks', v_failed_checks,
        'check_results', v_results
    );
END;
$$ LANGUAGE plpgsql;

-- Hauptfunktion zum Ausführen eines ETL-Jobs
CREATE OR REPLACE FUNCTION etl_framework.run_etl_job(
    p_job_id INTEGER,
    p_truncate_target BOOLEAN DEFAULT FALSE
) RETURNS JSONB AS $$
DECLARE
    v_source_type VARCHAR(50);
    v_result JSONB;
BEGIN
    -- Hole den Job-Typ
    SELECT source_type INTO v_source_type
    FROM etl_framework.etl_jobs
    WHERE job_id = p_job_id;
    
    IF v_source_type IS NULL THEN
        RAISE EXCEPTION 'ETL-Job mit ID % existiert nicht', p_job_id;
    END IF;
    
    -- Führe die passende ETL-Methode basierend auf dem Quelltyp aus
    CASE v_source_type
        WHEN 'database' THEN
            v_result := etl_framework.batch_process_data(p_job_id, p_truncate_target);
        WHEN 'file' THEN
            -- Implementiere Datei-basiertes ETL
            RAISE EXCEPTION 'Datei-basiertes ETL ist noch nicht implementiert';
        WHEN 'api' THEN
            -- Implementiere API-basiertes ETL
            RAISE EXCEPTION 'API-basiertes ETL ist noch nicht implementiert';
        ELSE
            RAISE EXCEPTION 'Unbekannter Quelltyp: %', v_source_type;
    END CASE;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql; 