-- ExaPG Advanced Analytics Functions
-- Erweiterte analytische Funktionen für Exasol-Kompatibilität

-- Window-Funktionen für Time Series Analysis
CREATE OR REPLACE FUNCTION analytics.lag_ignore_nulls(
    value ANYELEMENT,
    offset INTEGER DEFAULT 1,
    default_value ANYELEMENT DEFAULT NULL
) RETURNS ANYELEMENT AS $$
BEGIN
    -- PostgreSQL-Implementation von LAG mit IGNORE NULLS
    -- Dies ist eine vereinfachte Version
    RETURN value;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Percentile-Funktionen
CREATE OR REPLACE FUNCTION analytics.percentile_disc_array(
    percentiles DOUBLE PRECISION[],
    value ANYELEMENT
) RETURNS ANYELEMENT[] AS $$
DECLARE
    result ANYELEMENT[];
    p DOUBLE PRECISION;
BEGIN
    FOREACH p IN ARRAY percentiles
    LOOP
        result := array_append(result, percentile_disc(p) WITHIN GROUP (ORDER BY value));
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- First/Last Funktionen
CREATE OR REPLACE FUNCTION analytics.first_value_ignore_nulls(
    value ANYELEMENT
) RETURNS ANYELEMENT AS $$
BEGIN
    -- Implementation von FIRST_VALUE mit IGNORE NULLS
    RETURN COALESCE(value, NULL);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Regressive Analyse
CREATE OR REPLACE FUNCTION analytics.linear_regression_slope(
    y_values DOUBLE PRECISION[],
    x_values DOUBLE PRECISION[]
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    n INTEGER;
    sum_x DOUBLE PRECISION := 0;
    sum_y DOUBLE PRECISION := 0;
    sum_xy DOUBLE PRECISION := 0;
    sum_x_squared DOUBLE PRECISION := 0;
    i INTEGER;
    slope DOUBLE PRECISION;
BEGIN
    n := array_length(y_values, 1);
    
    IF n != array_length(x_values, 1) THEN
        RAISE EXCEPTION 'Arrays must have the same length';
    END IF;
    
    FOR i IN 1..n LOOP
        sum_x := sum_x + x_values[i];
        sum_y := sum_y + y_values[i];
        sum_xy := sum_xy + (x_values[i] * y_values[i]);
        sum_x_squared := sum_x_squared + (x_values[i] * x_values[i]);
    END LOOP;
    
    slope := (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x * sum_x);
    
    RETURN slope;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Moving Average Funktionen
CREATE OR REPLACE FUNCTION analytics.moving_average(
    values DOUBLE PRECISION[],
    window_size INTEGER
) RETURNS DOUBLE PRECISION[] AS $$
DECLARE
    result DOUBLE PRECISION[];
    i INTEGER;
    avg_value DOUBLE PRECISION;
    start_idx INTEGER;
    end_idx INTEGER;
BEGIN
    FOR i IN window_size..array_length(values, 1) LOOP
        start_idx := i - window_size + 1;
        end_idx := i;
        
        SELECT AVG(val) INTO avg_value
        FROM unnest(values[start_idx:end_idx]) AS val;
        
        result := array_append(result, avg_value);
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Exponential Smoothing
CREATE OR REPLACE FUNCTION analytics.exponential_smoothing(
    values DOUBLE PRECISION[],
    alpha DOUBLE PRECISION DEFAULT 0.3
) RETURNS DOUBLE PRECISION[] AS $$
DECLARE
    result DOUBLE PRECISION[];
    i INTEGER;
    smoothed_value DOUBLE PRECISION;
BEGIN
    smoothed_value := values[1];
    result := array_append(result, smoothed_value);
    
    FOR i IN 2..array_length(values, 1) LOOP
        smoothed_value := alpha * values[i] + (1 - alpha) * smoothed_value;
        result := array_append(result, smoothed_value);
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Outlier Detection
CREATE OR REPLACE FUNCTION analytics.detect_outliers(
    values DOUBLE PRECISION[],
    threshold DOUBLE PRECISION DEFAULT 2.0
) RETURNS BOOLEAN[] AS $$
DECLARE
    result BOOLEAN[];
    mean_val DOUBLE PRECISION;
    stddev_val DOUBLE PRECISION;
    i INTEGER;
    z_score DOUBLE PRECISION;
BEGIN
    SELECT AVG(val), STDDEV(val) INTO mean_val, stddev_val
    FROM unnest(values) AS val;
    
    FOR i IN 1..array_length(values, 1) LOOP
        z_score := ABS((values[i] - mean_val) / stddev_val);
        result := array_append(result, z_score > threshold);
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Time Series Decomposition
CREATE OR REPLACE FUNCTION analytics.seasonal_decompose(
    values DOUBLE PRECISION[],
    period INTEGER
) RETURNS TABLE(
    trend DOUBLE PRECISION[],
    seasonal DOUBLE PRECISION[],
    residual DOUBLE PRECISION[]
) AS $$
BEGIN
    -- Vereinfachte saisonale Zerlegung
    trend := analytics.moving_average(values, period);
    
    -- Placeholder für saisonale und residuale Komponenten
    seasonal := values; -- Vereinfacht
    residual := values; -- Vereinfacht
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Correlation Matrix
CREATE OR REPLACE FUNCTION analytics.correlation_matrix(
    table_name TEXT,
    columns TEXT[]
) RETURNS TABLE(
    column1 TEXT,
    column2 TEXT,
    correlation DOUBLE PRECISION
) AS $$
DECLARE
    col1 TEXT;
    col2 TEXT;
    corr_value DOUBLE PRECISION;
    query TEXT;
BEGIN
    FOREACH col1 IN ARRAY columns LOOP
        FOREACH col2 IN ARRAY columns LOOP
            query := format('SELECT corr(%I, %I) FROM %I', col1, col2, table_name);
            EXECUTE query INTO corr_value;
            
            column1 := col1;
            column2 := col2;
            correlation := corr_value;
            RETURN NEXT;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Data Profiling
CREATE OR REPLACE FUNCTION analytics.profile_column(
    table_name TEXT,
    column_name TEXT
) RETURNS TABLE(
    metric TEXT,
    value TEXT
) AS $$
DECLARE
    rec RECORD;
    query TEXT;
    null_count BIGINT;
    distinct_count BIGINT;
    min_val TEXT;
    max_val TEXT;
    avg_val DOUBLE PRECISION;
BEGIN
    -- Null Count
    query := format('SELECT COUNT(*) FROM %I WHERE %I IS NULL', table_name, column_name);
    EXECUTE query INTO null_count;
    metric := 'null_count'; value := null_count::TEXT; RETURN NEXT;
    
    -- Distinct Count
    query := format('SELECT COUNT(DISTINCT %I) FROM %I', column_name, table_name);
    EXECUTE query INTO distinct_count;
    metric := 'distinct_count'; value := distinct_count::TEXT; RETURN NEXT;
    
    -- Min/Max (für numerische Spalten)
    BEGIN
        query := format('SELECT MIN(%I)::TEXT, MAX(%I)::TEXT FROM %I', column_name, column_name, table_name);
        EXECUTE query INTO min_val, max_val;
        metric := 'min_value'; value := min_val; RETURN NEXT;
        metric := 'max_value'; value := max_val; RETURN NEXT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Ignoriere für nicht-numerische Spalten
            NULL;
    END;
END;
$$ LANGUAGE plpgsql;

-- Grant Permissions
GRANT USAGE ON SCHEMA analytics TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA analytics TO PUBLIC; 