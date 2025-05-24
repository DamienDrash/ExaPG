-- ===================================================================
-- ExaPG Analytics Performance Baseline Queries
-- ===================================================================
-- PERFORMANCE FIX: PERF-002 - Analytics Workload Baseline Queries
-- Date: 2024-05-24
-- ===================================================================

-- ===================================================================
-- SETUP AND INITIALIZATION
-- ===================================================================

\set ECHO all
\timing on

-- Drop existing baseline schema and recreate
DROP SCHEMA IF EXISTS analytics_baseline CASCADE;
CREATE SCHEMA analytics_baseline;

-- Set search path
SET search_path TO analytics_baseline, public;

-- Enable JIT for analytics queries
SET jit = on;
SET jit_above_cost = 100000;
SET jit_inline_above_cost = 500000;
SET jit_optimize_above_cost = 500000;

-- ===================================================================
-- ANALYTICS DATA MODEL (Star Schema)
-- ===================================================================

-- Date dimension
CREATE TABLE dim_date (
    date_key        INTEGER PRIMARY KEY,
    date_actual     DATE NOT NULL,
    year            INTEGER NOT NULL,
    quarter         INTEGER NOT NULL,
    month           INTEGER NOT NULL,
    week            INTEGER NOT NULL,
    day_of_year     INTEGER NOT NULL,
    day_of_month    INTEGER NOT NULL,
    day_of_week     INTEGER NOT NULL,
    weekday_name    VARCHAR(20) NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    is_weekend      BOOLEAN NOT NULL,
    is_holiday      BOOLEAN DEFAULT FALSE
);

-- Customer dimension
CREATE TABLE dim_customer (
    customer_key    SERIAL PRIMARY KEY,
    customer_id     VARCHAR(50) NOT NULL,
    customer_name   VARCHAR(200) NOT NULL,
    customer_type   VARCHAR(50) NOT NULL,
    industry        VARCHAR(100),
    country         VARCHAR(100) NOT NULL,
    region          VARCHAR(100) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    registration_date DATE NOT NULL,
    tier            VARCHAR(20) NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE
);

-- Product dimension
CREATE TABLE dim_product (
    product_key     SERIAL PRIMARY KEY,
    product_id      VARCHAR(50) NOT NULL,
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(100) NOT NULL,
    subcategory     VARCHAR(100) NOT NULL,
    brand           VARCHAR(100) NOT NULL,
    unit_cost       DECIMAL(10,2) NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    margin_percent  DECIMAL(5,2) NOT NULL,
    launch_date     DATE,
    is_active       BOOLEAN DEFAULT TRUE
);

-- Geography dimension
CREATE TABLE dim_geography (
    geography_key   SERIAL PRIMARY KEY,
    country_code    VARCHAR(3) NOT NULL,
    country_name    VARCHAR(100) NOT NULL,
    region_code     VARCHAR(10) NOT NULL,
    region_name     VARCHAR(100) NOT NULL,
    timezone        VARCHAR(50) NOT NULL,
    currency_code   VARCHAR(3) NOT NULL
);

-- Sales channel dimension
CREATE TABLE dim_channel (
    channel_key     SERIAL PRIMARY KEY,
    channel_id      VARCHAR(50) NOT NULL,
    channel_name    VARCHAR(100) NOT NULL,
    channel_type    VARCHAR(50) NOT NULL,
    is_online       BOOLEAN NOT NULL,
    commission_rate DECIMAL(5,2) DEFAULT 0.00
);

-- Sales fact table (partitioned by date)
CREATE TABLE fact_sales (
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key    INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    product_key     INTEGER NOT NULL REFERENCES dim_product(product_key),
    geography_key   INTEGER NOT NULL REFERENCES dim_geography(geography_key),
    channel_key     INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    order_id        VARCHAR(50) NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    gross_sales     DECIMAL(15,2) NOT NULL,
    discount_amount DECIMAL(15,2) DEFAULT 0.00,
    net_sales       DECIMAL(15,2) NOT NULL,
    cost_of_goods   DECIMAL(15,2) NOT NULL,
    gross_profit    DECIMAL(15,2) NOT NULL,
    transaction_timestamp TIMESTAMP NOT NULL
) PARTITION BY RANGE (date_key);

-- Create partitions for sales fact table (2022-2024)
CREATE TABLE fact_sales_2022 PARTITION OF fact_sales FOR VALUES FROM (20220101) TO (20230101);
CREATE TABLE fact_sales_2023 PARTITION OF fact_sales FOR VALUES FROM (20230101) TO (20240101);
CREATE TABLE fact_sales_2024 PARTITION OF fact_sales FOR VALUES FROM (20240101) TO (20250101);

-- Marketing spend fact table
CREATE TABLE fact_marketing (
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    channel_key     INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    geography_key   INTEGER NOT NULL REFERENCES dim_geography(geography_key),
    campaign_id     VARCHAR(100) NOT NULL,
    campaign_name   VARCHAR(200) NOT NULL,
    spend_amount    DECIMAL(15,2) NOT NULL,
    impressions     BIGINT DEFAULT 0,
    clicks          INTEGER DEFAULT 0,
    conversions     INTEGER DEFAULT 0
);

-- Customer activity fact table
CREATE TABLE fact_customer_activity (
    date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    customer_key    INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    activity_type   VARCHAR(50) NOT NULL,
    activity_count  INTEGER NOT NULL,
    activity_value  DECIMAL(15,2) DEFAULT 0.00
);

-- ===================================================================
-- CREATE INDEXES FOR ANALYTICS PERFORMANCE
-- ===================================================================

-- Date dimension indexes
CREATE INDEX idx_dim_date_actual ON dim_date (date_actual);
CREATE INDEX idx_dim_date_year_month ON dim_date (year, month);
CREATE INDEX idx_dim_date_quarter ON dim_date (quarter);

-- Customer dimension indexes
CREATE INDEX idx_dim_customer_type ON dim_customer (customer_type);
CREATE INDEX idx_dim_customer_country ON dim_customer (country);
CREATE INDEX idx_dim_customer_tier ON dim_customer (tier);
CREATE INDEX idx_dim_customer_active ON dim_customer (is_active);

-- Product dimension indexes
CREATE INDEX idx_dim_product_category ON dim_product (category);
CREATE INDEX idx_dim_product_brand ON dim_product (brand);
CREATE INDEX idx_dim_product_active ON dim_product (is_active);

-- Geography dimension indexes
CREATE INDEX idx_dim_geography_country ON dim_geography (country_code);
CREATE INDEX idx_dim_geography_region ON dim_geography (region_code);

-- Channel dimension indexes
CREATE INDEX idx_dim_channel_type ON dim_channel (channel_type);
CREATE INDEX idx_dim_channel_online ON dim_channel (is_online);

-- Fact table indexes (across all partitions)
CREATE INDEX idx_fact_sales_date ON fact_sales (date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales (customer_key);
CREATE INDEX idx_fact_sales_product ON fact_sales (product_key);
CREATE INDEX idx_fact_sales_geography ON fact_sales (geography_key);
CREATE INDEX idx_fact_sales_channel ON fact_sales (channel_key);
CREATE INDEX idx_fact_sales_order ON fact_sales (order_id);

-- Multi-column indexes for common analytics queries
CREATE INDEX idx_fact_sales_date_customer ON fact_sales (date_key, customer_key);
CREATE INDEX idx_fact_sales_date_product ON fact_sales (date_key, product_key);
CREATE INDEX idx_fact_sales_product_geography ON fact_sales (product_key, geography_key);

-- Marketing fact indexes
CREATE INDEX idx_fact_marketing_date ON fact_marketing (date_key);
CREATE INDEX idx_fact_marketing_channel ON fact_marketing (channel_key);
CREATE INDEX idx_fact_marketing_campaign ON fact_marketing (campaign_id);

-- Customer activity indexes
CREATE INDEX idx_fact_activity_date ON fact_customer_activity (date_key);
CREATE INDEX idx_fact_activity_customer ON fact_customer_activity (customer_key);
CREATE INDEX idx_fact_activity_type ON fact_customer_activity (activity_type);

-- ===================================================================
-- GENERATE SAMPLE DATA
-- ===================================================================

-- Generate date dimension (3 years: 2022-2024)
INSERT INTO dim_date (date_key, date_actual, year, quarter, month, week, day_of_year, day_of_month, day_of_week, weekday_name, month_name, is_weekend)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d,
    EXTRACT(YEAR FROM d)::INTEGER,
    EXTRACT(QUARTER FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    EXTRACT(WEEK FROM d)::INTEGER,
    EXTRACT(DOY FROM d)::INTEGER,
    EXTRACT(DAY FROM d)::INTEGER,
    EXTRACT(DOW FROM d)::INTEGER,
    TO_CHAR(d, 'Day'),
    TO_CHAR(d, 'Month'),
    EXTRACT(DOW FROM d) IN (0, 6)
FROM generate_series('2022-01-01'::DATE, '2024-12-31'::DATE, '1 day'::INTERVAL) d;

-- Generate geography dimension
INSERT INTO dim_geography (country_code, country_name, region_code, region_name, timezone, currency_code)
VALUES 
('USA', 'United States', 'NAM', 'North America', 'America/New_York', 'USD'),
('CAN', 'Canada', 'NAM', 'North America', 'America/Toronto', 'CAD'),
('GBR', 'United Kingdom', 'EUR', 'Europe', 'Europe/London', 'GBP'),
('DEU', 'Germany', 'EUR', 'Europe', 'Europe/Berlin', 'EUR'),
('FRA', 'France', 'EUR', 'Europe', 'Europe/Paris', 'EUR'),
('JPN', 'Japan', 'APAC', 'Asia Pacific', 'Asia/Tokyo', 'JPY'),
('AUS', 'Australia', 'APAC', 'Asia Pacific', 'Australia/Sydney', 'AUD'),
('BRA', 'Brazil', 'SAM', 'South America', 'America/Sao_Paulo', 'BRL'),
('IND', 'India', 'APAC', 'Asia Pacific', 'Asia/Kolkata', 'INR'),
('CHN', 'China', 'APAC', 'Asia Pacific', 'Asia/Shanghai', 'CNY');

-- Generate channel dimension
INSERT INTO dim_channel (channel_id, channel_name, channel_type, is_online, commission_rate)
VALUES 
('WEB', 'Website Direct', 'Direct', TRUE, 0.00),
('MOB', 'Mobile App', 'Direct', TRUE, 0.00),
('RET', 'Retail Stores', 'Retail', FALSE, 0.00),
('MAR', 'Marketplace', 'Partner', TRUE, 0.15),
('WHO', 'Wholesale', 'B2B', FALSE, 0.05),
('AFF', 'Affiliate', 'Partner', TRUE, 0.10),
('SOC', 'Social Media', 'Direct', TRUE, 0.00),
('EMA', 'Email Marketing', 'Direct', TRUE, 0.00);

-- Generate customer dimension (100,000 customers)
INSERT INTO dim_customer (customer_id, customer_name, customer_type, industry, country, region, city, registration_date, tier)
SELECT 
    'CUST' || LPAD(i::text, 8, '0'),
    'Customer ' || i,
    CASE (i % 4) 
        WHEN 0 THEN 'Individual'
        WHEN 1 THEN 'Small Business'
        WHEN 2 THEN 'Enterprise'
        ELSE 'Government'
    END,
    CASE (i % 8)
        WHEN 0 THEN 'Technology'
        WHEN 1 THEN 'Healthcare'
        WHEN 2 THEN 'Finance'
        WHEN 3 THEN 'Manufacturing'
        WHEN 4 THEN 'Retail'
        WHEN 5 THEN 'Education'
        WHEN 6 THEN 'Government'
        ELSE 'Others'
    END,
    CASE (i % 10)
        WHEN 0 THEN 'United States'
        WHEN 1 THEN 'Canada'
        WHEN 2 THEN 'United Kingdom'
        WHEN 3 THEN 'Germany'
        WHEN 4 THEN 'France'
        WHEN 5 THEN 'Japan'
        WHEN 6 THEN 'Australia'
        WHEN 7 THEN 'Brazil'
        WHEN 8 THEN 'India'
        ELSE 'China'
    END,
    CASE (i % 4)
        WHEN 0 THEN 'North America'
        WHEN 1 THEN 'Europe'
        WHEN 2 THEN 'Asia Pacific'
        ELSE 'South America'
    END,
    'City ' || (i % 1000),
    '2020-01-01'::DATE + (random() * 1460)::INTEGER,
    CASE (i % 5)
        WHEN 0 THEN 'Bronze'
        WHEN 1 THEN 'Silver'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Platinum'
        ELSE 'Diamond'
    END
FROM generate_series(1, 100000) i;

-- Generate product dimension (5,000 products)
INSERT INTO dim_product (product_id, product_name, category, subcategory, brand, unit_cost, unit_price, margin_percent, launch_date)
SELECT 
    'PROD' || LPAD(i::text, 6, '0'),
    'Product ' || i,
    CASE (i % 10)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Home & Garden'
        WHEN 3 THEN 'Sports & Outdoors'
        WHEN 4 THEN 'Books & Media'
        WHEN 5 THEN 'Health & Beauty'
        WHEN 6 THEN 'Automotive'
        WHEN 7 THEN 'Toys & Games'
        WHEN 8 THEN 'Food & Beverages'
        ELSE 'Office Supplies'
    END,
    'Subcategory ' || (i % 50),
    'Brand ' || (i % 100),
    (random() * 500 + 10)::decimal(10,2),
    (random() * 1000 + 50)::decimal(10,2),
    ((random() * 500 + 50) / (random() * 500 + 10) * 100)::decimal(5,2),
    '2020-01-01'::DATE + (random() * 1460)::INTEGER
FROM generate_series(1, 5000) i;

-- Generate sales fact data (10 million records across 3 years)
-- This will take a while, so we'll generate in batches
DO $$
DECLARE
    batch_size INTEGER := 100000;
    total_records INTEGER := 10000000;
    current_batch INTEGER := 1;
    max_batches INTEGER := total_records / batch_size;
BEGIN
    WHILE current_batch <= max_batches LOOP
        INSERT INTO fact_sales (
            date_key, customer_key, product_key, geography_key, channel_key,
            order_id, quantity, unit_price, gross_sales, discount_amount, 
            net_sales, cost_of_goods, gross_profit, transaction_timestamp
        )
        SELECT 
            d.date_key,
            (random() * 99999 + 1)::INTEGER,
            (random() * 4999 + 1)::INTEGER,
            (random() * 9 + 1)::INTEGER,
            (random() * 7 + 1)::INTEGER,
            'ORD' || LPAD(((current_batch - 1) * batch_size + i)::text, 12, '0'),
            (random() * 10 + 1)::INTEGER,
            (random() * 1000 + 10)::decimal(10,2),
            (random() * 10 + 1) * (random() * 1000 + 10),
            (random() * 100)::decimal(15,2),
            ((random() * 10 + 1) * (random() * 1000 + 10)) - (random() * 100),
            (random() * 5 + 1) * (random() * 500 + 5),
            ((random() * 10 + 1) * (random() * 1000 + 10)) - ((random() * 5 + 1) * (random() * 500 + 5)),
            d.date_actual + (random() * INTERVAL '24 hours')
        FROM generate_series(1, batch_size) i
        CROSS JOIN (
            SELECT date_key, date_actual 
            FROM dim_date 
            WHERE date_actual >= '2022-01-01' 
            ORDER BY random() 
            LIMIT 1
        ) d;
        
        current_batch := current_batch + 1;
        
        -- Commit every batch and log progress
        COMMIT;
        RAISE NOTICE 'Completed batch % of % (% records)', current_batch - 1, max_batches, (current_batch - 1) * batch_size;
    END LOOP;
END $$;

-- Generate marketing data (1 million records)
INSERT INTO fact_marketing (date_key, channel_key, geography_key, campaign_id, campaign_name, spend_amount, impressions, clicks, conversions)
SELECT 
    d.date_key,
    (random() * 7 + 1)::INTEGER,
    (random() * 9 + 1)::INTEGER,
    'CAMP' || LPAD(i::text, 8, '0'),
    'Campaign ' || i,
    (random() * 10000 + 100)::decimal(15,2),
    (random() * 1000000 + 1000)::BIGINT,
    (random() * 10000 + 10)::INTEGER,
    (random() * 1000 + 1)::INTEGER
FROM generate_series(1, 1000000) i
CROSS JOIN (
    SELECT date_key 
    FROM dim_date 
    WHERE date_actual >= '2022-01-01' 
    ORDER BY random() 
    LIMIT 1
) d;

-- Generate customer activity data (5 million records)
INSERT INTO fact_customer_activity (date_key, customer_key, activity_type, activity_count, activity_value)
SELECT 
    d.date_key,
    (random() * 99999 + 1)::INTEGER,
    CASE (i % 5)
        WHEN 0 THEN 'page_view'
        WHEN 1 THEN 'product_view'
        WHEN 2 THEN 'cart_add'
        WHEN 3 THEN 'purchase'
        ELSE 'support_contact'
    END,
    (random() * 50 + 1)::INTEGER,
    (random() * 1000)::decimal(15,2)
FROM generate_series(1, 5000000) i
CROSS JOIN (
    SELECT date_key 
    FROM dim_date 
    WHERE date_actual >= '2022-01-01' 
    ORDER BY random() 
    LIMIT 1
) d;

-- Update statistics after data load
ANALYZE;

-- ===================================================================
-- ANALYTICS BENCHMARK QUERIES
-- ===================================================================

\echo 'Starting Analytics Baseline Queries...'

-- Query 1: Monthly Sales Trend Analysis
\echo 'Analytics Q1: Monthly Sales Trend'
SELECT 
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) as total_orders,
    SUM(f.net_sales) as total_sales,
    SUM(f.gross_profit) as total_profit,
    AVG(f.net_sales) as avg_order_value,
    SUM(f.gross_profit) / NULLIF(SUM(f.net_sales), 0) * 100 as profit_margin_pct
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year >= 2023
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- Query 2: Product Category Performance Analysis
\echo 'Analytics Q2: Product Category Performance'
SELECT 
    p.category,
    COUNT(DISTINCT f.order_id) as order_count,
    SUM(f.quantity) as units_sold,
    SUM(f.net_sales) as revenue,
    SUM(f.gross_profit) as profit,
    AVG(f.unit_price) as avg_unit_price,
    SUM(f.gross_profit) / NULLIF(SUM(f.net_sales), 0) * 100 as profit_margin
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2024
GROUP BY p.category
ORDER BY revenue DESC;

-- Query 3: Geographic Sales Analysis
\echo 'Analytics Q3: Geographic Sales Analysis'
SELECT 
    g.region_name,
    g.country_name,
    COUNT(DISTINCT f.customer_key) as unique_customers,
    COUNT(DISTINCT f.order_id) as total_orders,
    SUM(f.net_sales) as revenue,
    AVG(f.net_sales) as avg_order_value,
    SUM(f.net_sales) / COUNT(DISTINCT f.customer_key) as revenue_per_customer
FROM fact_sales f
JOIN dim_geography g ON f.geography_key = g.geography_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2024
GROUP BY g.region_name, g.country_name
ORDER BY revenue DESC;

-- Query 4: Channel Performance Analysis
\echo 'Analytics Q4: Channel Performance Analysis'
SELECT 
    ch.channel_name,
    ch.channel_type,
    COUNT(DISTINCT f.order_id) as order_count,
    SUM(f.net_sales) as revenue,
    SUM(f.gross_profit) as profit,
    AVG(f.net_sales) as avg_order_value,
    SUM(f.net_sales) / SUM(SUM(f.net_sales)) OVER () * 100 as revenue_share_pct
FROM fact_sales f
JOIN dim_channel ch ON f.channel_key = ch.channel_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2024 AND d.quarter IN (3, 4)
GROUP BY ch.channel_name, ch.channel_type
ORDER BY revenue DESC;

-- Query 5: Customer Cohort Analysis
\echo 'Analytics Q5: Customer Cohort Analysis'
WITH customer_first_purchase AS (
    SELECT 
        f.customer_key,
        MIN(d.date_actual) as first_purchase_date,
        DATE_TRUNC('month', MIN(d.date_actual)) as cohort_month
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY f.customer_key
),
monthly_activity AS (
    SELECT 
        cfp.cohort_month,
        DATE_TRUNC('month', d.date_actual) as activity_month,
        COUNT(DISTINCT f.customer_key) as active_customers
    FROM customer_first_purchase cfp
    JOIN fact_sales f ON cfp.customer_key = f.customer_key
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY cfp.cohort_month, DATE_TRUNC('month', d.date_actual)
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(*) as cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
)
SELECT 
    cs.cohort_month,
    cs.cohort_size,
    ma.activity_month,
    ma.active_customers,
    ROUND(ma.active_customers::DECIMAL / cs.cohort_size * 100, 2) as retention_rate,
    EXTRACT(MONTH FROM AGE(ma.activity_month, cs.cohort_month)) as months_since_first_purchase
FROM cohort_sizes cs
JOIN monthly_activity ma ON cs.cohort_month = ma.cohort_month
WHERE cs.cohort_month >= '2023-01-01'
ORDER BY cs.cohort_month, ma.activity_month;

-- Query 6: Seasonal Sales Patterns
\echo 'Analytics Q6: Seasonal Sales Patterns'
SELECT 
    d.month,
    d.month_name,
    d.is_weekend,
    AVG(daily_sales.total_sales) as avg_daily_sales,
    STDDEV(daily_sales.total_sales) as sales_volatility,
    MAX(daily_sales.total_sales) as peak_daily_sales,
    MIN(daily_sales.total_sales) as min_daily_sales
FROM (
    SELECT 
        f.date_key,
        SUM(f.net_sales) as total_sales
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year = 2024
    GROUP BY f.date_key
) daily_sales
JOIN dim_date d ON daily_sales.date_key = d.date_key
GROUP BY d.month, d.month_name, d.is_weekend
ORDER BY d.month, d.is_weekend;

-- Query 7: Product Performance with Rolling Averages
\echo 'Analytics Q7: Product Performance with Rolling Averages'
WITH daily_product_sales AS (
    SELECT 
        f.product_key,
        d.date_actual,
        SUM(f.net_sales) as daily_sales,
        SUM(f.quantity) as daily_quantity
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year = 2024 AND d.month >= 10
    GROUP BY f.product_key, d.date_actual
)
SELECT 
    p.product_name,
    p.category,
    dps.date_actual,
    dps.daily_sales,
    AVG(dps.daily_sales) OVER (
        PARTITION BY dps.product_key 
        ORDER BY dps.date_actual 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as sales_7day_avg,
    AVG(dps.daily_sales) OVER (
        PARTITION BY dps.product_key 
        ORDER BY dps.date_actual 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) as sales_30day_avg
FROM daily_product_sales dps
JOIN dim_product p ON dps.product_key = p.product_key
WHERE p.category IN ('Electronics', 'Clothing', 'Home & Garden')
ORDER BY p.category, p.product_name, dps.date_actual;

-- Query 8: Customer Lifetime Value Analysis
\echo 'Analytics Q8: Customer Lifetime Value Analysis'
WITH customer_metrics AS (
    SELECT 
        f.customer_key,
        c.customer_type,
        c.tier,
        c.country,
        MIN(d.date_actual) as first_purchase,
        MAX(d.date_actual) as last_purchase,
        COUNT(DISTINCT f.order_id) as total_orders,
        SUM(f.net_sales) as total_spent,
        AVG(f.net_sales) as avg_order_value,
        EXTRACT(DAYS FROM MAX(d.date_actual) - MIN(d.date_actual)) + 1 as customer_lifespan_days
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_key = c.customer_key
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY f.customer_key, c.customer_type, c.tier, c.country
)
SELECT 
    customer_type,
    tier,
    COUNT(*) as customer_count,
    AVG(total_spent) as avg_lifetime_value,
    AVG(total_orders) as avg_orders_per_customer,
    AVG(avg_order_value) as avg_order_value,
    AVG(customer_lifespan_days) as avg_lifespan_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_spent) as median_lifetime_value,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_spent) as top_10pct_lifetime_value
FROM customer_metrics
WHERE total_orders >= 2
GROUP BY customer_type, tier
ORDER BY avg_lifetime_value DESC;

-- Query 9: Marketing ROI Analysis
\echo 'Analytics Q9: Marketing ROI Analysis'
WITH marketing_performance AS (
    SELECT 
        m.campaign_id,
        m.campaign_name,
        ch.channel_name,
        g.country_name,
        SUM(m.spend_amount) as total_spend,
        SUM(m.impressions) as total_impressions,
        SUM(m.clicks) as total_clicks,
        SUM(m.conversions) as total_conversions,
        CASE WHEN SUM(m.clicks) > 0 THEN SUM(m.conversions)::DECIMAL / SUM(m.clicks) * 100 ELSE 0 END as conversion_rate
    FROM fact_marketing m
    JOIN dim_channel ch ON m.channel_key = ch.channel_key
    JOIN dim_geography g ON m.geography_key = g.geography_key
    JOIN dim_date d ON m.date_key = d.date_key
    WHERE d.year = 2024
    GROUP BY m.campaign_id, m.campaign_name, ch.channel_name, g.country_name
),
campaign_sales AS (
    SELECT 
        -- Approximate attribution based on channel and geography
        ch.channel_name,
        g.country_name,
        SUM(f.net_sales) as attributed_sales
    FROM fact_sales f
    JOIN dim_channel ch ON f.channel_key = ch.channel_key
    JOIN dim_geography g ON f.geography_key = g.geography_key
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year = 2024
    GROUP BY ch.channel_name, g.country_name
)
SELECT 
    mp.campaign_name,
    mp.channel_name,
    mp.country_name,
    mp.total_spend,
    mp.total_conversions,
    mp.conversion_rate,
    cs.attributed_sales,
    CASE WHEN mp.total_spend > 0 THEN cs.attributed_sales / mp.total_spend ELSE 0 END as roas_ratio,
    CASE WHEN mp.total_spend > 0 THEN (cs.attributed_sales - mp.total_spend) / mp.total_spend * 100 ELSE 0 END as roi_percentage
FROM marketing_performance mp
LEFT JOIN campaign_sales cs ON mp.channel_name = cs.channel_name AND mp.country_name = cs.country_name
WHERE mp.total_spend > 1000
ORDER BY roas_ratio DESC;

-- Query 10: Advanced Time Series Analysis
\echo 'Analytics Q10: Advanced Time Series Analysis'
WITH weekly_sales AS (
    SELECT 
        DATE_TRUNC('week', d.date_actual) as week_start,
        SUM(f.net_sales) as weekly_sales,
        COUNT(DISTINCT f.order_id) as weekly_orders,
        COUNT(DISTINCT f.customer_key) as weekly_customers
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE d.year >= 2023
    GROUP BY DATE_TRUNC('week', d.date_actual)
),
sales_with_trends AS (
    SELECT 
        week_start,
        weekly_sales,
        weekly_orders,
        weekly_customers,
        LAG(weekly_sales, 1) OVER (ORDER BY week_start) as prev_week_sales,
        LAG(weekly_sales, 52) OVER (ORDER BY week_start) as yoy_sales,
        AVG(weekly_sales) OVER (ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) as sales_3week_avg
    FROM weekly_sales
)
SELECT 
    week_start,
    weekly_sales,
    weekly_orders,
    weekly_customers,
    CASE WHEN prev_week_sales > 0 THEN (weekly_sales - prev_week_sales) / prev_week_sales * 100 ELSE 0 END as week_over_week_growth,
    CASE WHEN yoy_sales > 0 THEN (weekly_sales - yoy_sales) / yoy_sales * 100 ELSE 0 END as year_over_year_growth,
    CASE WHEN sales_3week_avg > 0 THEN (weekly_sales - sales_3week_avg) / sales_3week_avg * 100 ELSE 0 END as vs_3week_avg_pct
FROM sales_with_trends
WHERE week_start >= '2024-01-01'
ORDER BY week_start;

\echo 'Analytics Baseline Queries completed!'

-- ===================================================================
-- PERFORMANCE SUMMARY
-- ===================================================================

\echo '=================================='
\echo 'Analytics Baseline Performance Summary'
\echo '=================================='

-- Data warehouse size summary
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    CASE 
        WHEN tablename LIKE 'fact_%' THEN 'Fact Table'
        WHEN tablename LIKE 'dim_%' THEN 'Dimension Table'
        ELSE 'Other'
    END as table_type
FROM pg_tables 
WHERE schemaname = 'analytics_baseline'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Query performance statistics
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins,
    n_tup_upd,
    n_tup_del
FROM pg_stat_user_tables 
WHERE schemaname = 'analytics_baseline'
ORDER BY seq_tup_read + idx_tup_fetch DESC;

\echo 'Analytics Baseline schema created and tested successfully!'
\echo 'Use this schema for analytics performance regression testing.' 