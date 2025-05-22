CREATE OR REPLACE FUNCTION analytics.create_month_partition(p_table text, p_year int, p_month int) RETURNS void AS $$
DECLARE
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_name := p_table || '_y' || p_year || 'm' || LPAD(p_month::text, 2, '0');
    start_date := make_date(p_year, p_month, 1);
    
    IF p_month = 12 THEN
        end_date := make_date(p_year + 1, 1, 1);
    ELSE
        end_date := make_date(p_year, p_month + 1, 1);
    END IF;
    
    EXECUTE format('CREATE TABLE analytics.%I PARTITION OF analytics.%I FOR VALUES FROM (%L) TO (%L)',
        partition_name, p_table, start_date, end_date);
        
    RAISE NOTICE 'Created partition: %', partition_name;
END;
$$ LANGUAGE plpgsql; 