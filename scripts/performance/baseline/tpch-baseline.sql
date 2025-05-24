-- ===================================================================
-- ExaPG TPC-H Performance Baseline Queries
-- ===================================================================
-- PERFORMANCE FIX: PERF-002 - TPC-H Standard Benchmark Queries
-- Date: 2024-05-24
-- ===================================================================

-- ===================================================================
-- SETUP AND INITIALIZATION
-- ===================================================================

\set ECHO all
\timing on

-- Drop existing baseline schema and recreate
DROP SCHEMA IF EXISTS tpch_baseline CASCADE;
CREATE SCHEMA tpch_baseline;

-- Set search path
SET search_path TO tpch_baseline, public;

-- ===================================================================
-- TPC-H SAMPLE DATA CREATION (Simplified for baseline)
-- ===================================================================

-- Nation table
CREATE TABLE nation (
    n_nationkey     INTEGER PRIMARY KEY,
    n_name          CHAR(25) NOT NULL,
    n_regionkey     INTEGER NOT NULL,
    n_comment       VARCHAR(152)
);

-- Region table
CREATE TABLE region (
    r_regionkey     INTEGER PRIMARY KEY,
    r_name          CHAR(25) NOT NULL,
    r_comment       VARCHAR(152)
);

-- Supplier table
CREATE TABLE supplier (
    s_suppkey       INTEGER PRIMARY KEY,
    s_name          CHAR(25) NOT NULL,
    s_address       VARCHAR(40) NOT NULL,
    s_nationkey     INTEGER NOT NULL,
    s_phone         CHAR(15) NOT NULL,
    s_acctbal       DECIMAL(15,2) NOT NULL,
    s_comment       VARCHAR(101) NOT NULL
);

-- Customer table  
CREATE TABLE customer (
    c_custkey       INTEGER PRIMARY KEY,
    c_name          VARCHAR(25) NOT NULL,
    c_address       VARCHAR(40) NOT NULL,
    c_nationkey     INTEGER NOT NULL,
    c_phone         CHAR(15) NOT NULL,
    c_acctbal       DECIMAL(15,2) NOT NULL,
    c_mktsegment    CHAR(10) NOT NULL,
    c_comment       VARCHAR(117) NOT NULL
);

-- Part table
CREATE TABLE part (
    p_partkey       INTEGER PRIMARY KEY,
    p_name          VARCHAR(55) NOT NULL,
    p_mfgr          CHAR(25) NOT NULL,
    p_brand         CHAR(10) NOT NULL,
    p_type          VARCHAR(25) NOT NULL,
    p_size          INTEGER NOT NULL,
    p_container     CHAR(10) NOT NULL,
    p_retailprice   DECIMAL(15,2) NOT NULL,
    p_comment       VARCHAR(23) NOT NULL
);

-- Partsupp table
CREATE TABLE partsupp (
    ps_partkey      INTEGER NOT NULL,
    ps_suppkey      INTEGER NOT NULL,
    ps_availqty     INTEGER NOT NULL,
    ps_supplycost   DECIMAL(15,2) NOT NULL,
    ps_comment      VARCHAR(199) NOT NULL,
    PRIMARY KEY (ps_partkey, ps_suppkey)
);

-- Orders table
CREATE TABLE orders (
    o_orderkey      INTEGER PRIMARY KEY,
    o_custkey       INTEGER NOT NULL,
    o_orderstatus   CHAR(1) NOT NULL,
    o_totalprice    DECIMAL(15,2) NOT NULL,
    o_orderdate     DATE NOT NULL,
    o_orderpriority CHAR(15) NOT NULL,
    o_clerk         CHAR(15) NOT NULL,
    o_shippriority  INTEGER NOT NULL,
    o_comment       VARCHAR(79) NOT NULL
);

-- Lineitem table (largest table)
CREATE TABLE lineitem (
    l_orderkey      INTEGER NOT NULL,
    l_partkey       INTEGER NOT NULL,
    l_suppkey       INTEGER NOT NULL,
    l_linenumber    INTEGER NOT NULL,
    l_quantity      DECIMAL(15,2) NOT NULL,
    l_extendedprice DECIMAL(15,2) NOT NULL,
    l_discount      DECIMAL(15,2) NOT NULL,
    l_tax           DECIMAL(15,2) NOT NULL,
    l_returnflag    CHAR(1) NOT NULL,
    l_linestatus    CHAR(1) NOT NULL,
    l_shipdate      DATE NOT NULL,
    l_commitdate    DATE NOT NULL,
    l_receiptdate   DATE NOT NULL,
    l_shipinstruct  CHAR(25) NOT NULL,
    l_shipmode      CHAR(10) NOT NULL,
    l_comment       VARCHAR(44) NOT NULL,
    PRIMARY KEY (l_orderkey, l_linenumber)
);

-- ===================================================================
-- GENERATE SAMPLE DATA (Small dataset for baseline)
-- ===================================================================

-- Insert sample regions
INSERT INTO region VALUES 
(0, 'AFRICA', 'lar deposits. blithely final packages cajole. regular waters are final requests. regular accounts are according to'),
(1, 'AMERICA', 'hs use ironic, even requests. s'),
(2, 'ASIA', 'ges. thinly even pinto beans ca'),
(3, 'EUROPE', 'ly final courts cajole furiously final excuse'),
(4, 'MIDDLE EAST', 'uickly special accounts cajole carefully blithely close requests. carefully final asymptotes haggle furiousl');

-- Insert sample nations
INSERT INTO nation VALUES 
(0, 'ALGERIA', 0, ' haggle. carefully final deposits detect slyly agai'),
(1, 'ARGENTINA', 1, 'al foxes promise slyly according to the regular accounts. bold requests alon'),
(2, 'BRAZIL', 1, 'y alongside of the pending deposits. carefully special packages are about the ironic forges. slyly special'),
(3, 'CANADA', 1, 'eas hang ironic, silent packages. slyly regular packages are furiously over the tithes. fluffily bold'),
(4, 'EGYPT', 4, 'y above the carefully unusual theodolites. final dugouts are quickly across the furiously regular d');

-- Generate sample data with procedural function
DO $$
DECLARE
    i INTEGER;
    j INTEGER;
BEGIN
    -- Generate customers (10,000 records)
    FOR i IN 1..10000 LOOP
        INSERT INTO customer VALUES (
            i,
            'Customer#' || LPAD(i::text, 9, '0'),
            'Address' || i,
            i % 5,
            '123-456-' || LPAD((i % 10000)::text, 4, '0'),
            (random() * 10000)::decimal(15,2),
            CASE (i % 5) 
                WHEN 0 THEN 'BUILDING'
                WHEN 1 THEN 'AUTOMOBILE'
                WHEN 2 THEN 'MACHINERY'
                WHEN 3 THEN 'HOUSEHOLD'
                ELSE 'FURNITURE'
            END,
            'Customer comment ' || i
        );
    END LOOP;

    -- Generate suppliers (1,000 records)
    FOR i IN 1..1000 LOOP
        INSERT INTO supplier VALUES (
            i,
            'Supplier#' || LPAD(i::text, 9, '0'),
            'Supplier Address' || i,
            i % 5,
            '987-654-' || LPAD((i % 10000)::text, 4, '0'),
            (random() * 10000)::decimal(15,2),
            'Supplier comment ' || i
        );
    END LOOP;

    -- Generate parts (20,000 records)
    FOR i IN 1..20000 LOOP
        INSERT INTO part VALUES (
            i,
            'Part Name ' || i,
            'Manufacturer#' || (i % 5 + 1),
            'Brand#' || (i % 50 + 1),
            'Type' || (i % 150 + 1),
            i % 50 + 1,
            'Container' || (i % 40 + 1),
            (random() * 2000 + 100)::decimal(15,2),
            'Part comment ' || i
        );
    END LOOP;

    -- Generate orders (150,000 records)
    FOR i IN 1..150000 LOOP
        INSERT INTO orders VALUES (
            i,
            (i % 10000) + 1,
            CASE (i % 3) WHEN 0 THEN 'O' WHEN 1 THEN 'F' ELSE 'P' END,
            (random() * 500000)::decimal(15,2),
            '1992-01-01'::date + (i % 2557) * INTERVAL '1 day',
            CASE (i % 5) 
                WHEN 0 THEN '1-URGENT'
                WHEN 1 THEN '2-HIGH'
                WHEN 2 THEN '3-MEDIUM'
                WHEN 3 THEN '4-NOT SPECIFIED'
                ELSE '5-LOW'
            END,
            'Clerk#' || LPAD((i % 1000)::text, 9, '0'),
            i % 3,
            'Order comment ' || i
        );
    END LOOP;

    -- Generate lineitems (600,000 records)
    FOR i IN 1..150000 LOOP
        FOR j IN 1..(i % 4 + 1) LOOP
            INSERT INTO lineitem VALUES (
                i,
                (i * j) % 20000 + 1,
                ((i * j) % 1000) + 1,
                j,
                (random() * 50 + 1)::decimal(15,2),
                (random() * 100000)::decimal(15,2),
                (random() * 0.1)::decimal(15,2),
                (random() * 0.08)::decimal(15,2),
                CASE (i % 3) WHEN 0 THEN 'A' WHEN 1 THEN 'R' ELSE 'N' END,
                CASE (i % 2) WHEN 0 THEN 'O' ELSE 'F' END,
                '1992-01-01'::date + (i % 2557) * INTERVAL '1 day',
                '1992-01-01'::date + (i % 2557) * INTERVAL '1 day' + INTERVAL '30 days',
                '1992-01-01'::date + (i % 2557) * INTERVAL '1 day' + INTERVAL '60 days',
                CASE (j % 4) 
                    WHEN 0 THEN 'DELIVER IN PERSON'
                    WHEN 1 THEN 'COLLECT COD'
                    WHEN 2 THEN 'NONE'
                    ELSE 'TAKE BACK RETURN'
                END,
                CASE (j % 7)
                    WHEN 0 THEN 'TRUCK'
                    WHEN 1 THEN 'MAIL'
                    WHEN 2 THEN 'REG AIR'
                    WHEN 3 THEN 'AIR'
                    WHEN 4 THEN 'RAIL'
                    WHEN 5 THEN 'SHIP'
                    ELSE 'FOB'
                END,
                'Lineitem comment ' || i || '-' || j
            );
        END LOOP;
    END LOOP;
END $$;

-- ===================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ===================================================================

-- Customer indexes
CREATE INDEX idx_customer_nationkey ON customer (c_nationkey);
CREATE INDEX idx_customer_mktsegment ON customer (c_mktsegment);

-- Supplier indexes
CREATE INDEX idx_supplier_nationkey ON supplier (s_nationkey);

-- Part indexes
CREATE INDEX idx_part_size ON part (p_size);
CREATE INDEX idx_part_type ON part (p_type);

-- Orders indexes
CREATE INDEX idx_orders_custkey ON orders (o_custkey);
CREATE INDEX idx_orders_orderdate ON orders (o_orderdate);
CREATE INDEX idx_orders_orderpriority ON orders (o_orderpriority);

-- Lineitem indexes (most important for performance)
CREATE INDEX idx_lineitem_orderkey ON lineitem (l_orderkey);
CREATE INDEX idx_lineitem_partkey ON lineitem (l_partkey);
CREATE INDEX idx_lineitem_suppkey ON lineitem (l_suppkey);
CREATE INDEX idx_lineitem_shipdate ON lineitem (l_shipdate);
CREATE INDEX idx_lineitem_returnflag_linestatus ON lineitem (l_returnflag, l_linestatus);

-- Partsupp indexes
CREATE INDEX idx_partsupp_partkey ON partsupp (ps_partkey);
CREATE INDEX idx_partsupp_suppkey ON partsupp (ps_suppkey);

-- Generate partsupp data based on existing parts and suppliers
INSERT INTO partsupp 
SELECT 
    p.p_partkey,
    s.s_suppkey,
    (random() * 9999 + 1)::integer,
    (random() * 1000)::decimal(15,2),
    'PartSupp comment for part ' || p.p_partkey || ' supplier ' || s.s_suppkey
FROM part p
CROSS JOIN supplier s
WHERE p.p_partkey <= 1000 AND s.s_suppkey <= 100;  -- Limit to avoid too much data

-- Update statistics
ANALYZE;

-- ===================================================================
-- TPC-H BENCHMARK QUERIES
-- ===================================================================

\echo 'Starting TPC-H Baseline Queries...'

-- Query 1: Pricing Summary Report
\echo 'TPC-H Q1: Pricing Summary Report'
\timing on
SELECT
    l_returnflag,
    l_linestatus,
    sum(l_quantity) as sum_qty,
    sum(l_extendedprice) as sum_base_price,
    sum(l_extendedprice * (1 - l_discount)) as sum_disc_price,
    sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) as sum_charge,
    avg(l_quantity) as avg_qty,
    avg(l_extendedprice) as avg_price,
    avg(l_discount) as avg_disc,
    count(*) as count_order
FROM lineitem
WHERE l_shipdate <= date '1998-12-01' - interval '90 day'
GROUP BY l_returnflag, l_linestatus
ORDER BY l_returnflag, l_linestatus;

-- Query 2: Minimum Cost Supplier
\echo 'TPC-H Q2: Minimum Cost Supplier'
SELECT
    s_acctbal,
    s_name,
    n_name,
    p_partkey,
    p_mfgr,
    s_address,
    s_phone,
    s_comment
FROM part, supplier, partsupp, nation, region
WHERE p_partkey = ps_partkey
    AND s_suppkey = ps_suppkey
    AND p_size = 15
    AND p_type LIKE '%BRASS'
    AND s_nationkey = n_nationkey
    AND n_regionkey = r_regionkey
    AND r_name = 'EUROPE'
    AND ps_supplycost = (
        SELECT min(ps_supplycost)
        FROM partsupp, supplier, nation, region
        WHERE p_partkey = ps_partkey
            AND s_suppkey = ps_suppkey
            AND s_nationkey = n_nationkey
            AND n_regionkey = r_regionkey
            AND r_name = 'EUROPE'
    )
ORDER BY s_acctbal DESC, n_name, s_name, p_partkey
LIMIT 100;

-- Query 3: Shipping Priority
\echo 'TPC-H Q3: Shipping Priority'
SELECT
    l_orderkey,
    sum(l_extendedprice * (1 - l_discount)) as revenue,
    o_orderdate,
    o_shippriority
FROM customer, orders, lineitem
WHERE c_mktsegment = 'BUILDING'
    AND c_custkey = o_custkey
    AND l_orderkey = o_orderkey
    AND o_orderdate < date '1995-03-15'
    AND l_shipdate > date '1995-03-15'
GROUP BY l_orderkey, o_orderdate, o_shippriority
ORDER BY revenue DESC, o_orderdate
LIMIT 10;

-- Query 4: Order Priority Checking
\echo 'TPC-H Q4: Order Priority Checking'
SELECT
    o_orderpriority,
    count(*) as order_count
FROM orders
WHERE o_orderdate >= date '1993-07-01'
    AND o_orderdate < date '1993-07-01' + interval '3 month'
    AND EXISTS (
        SELECT *
        FROM lineitem
        WHERE l_orderkey = o_orderkey
            AND l_commitdate < l_receiptdate
    )
GROUP BY o_orderpriority
ORDER BY o_orderpriority;

-- Query 5: Local Supplier Volume
\echo 'TPC-H Q5: Local Supplier Volume'
SELECT
    n_name,
    sum(l_extendedprice * (1 - l_discount)) as revenue
FROM customer, orders, lineitem, supplier, nation, region
WHERE c_custkey = o_custkey
    AND l_orderkey = o_orderkey
    AND l_suppkey = s_suppkey
    AND c_nationkey = s_nationkey
    AND s_nationkey = n_nationkey
    AND n_regionkey = r_regionkey
    AND r_name = 'ASIA'
    AND o_orderdate >= date '1994-01-01'
    AND o_orderdate < date '1994-01-01' + interval '1 year'
GROUP BY n_name
ORDER BY revenue DESC;

-- Query 6: Forecasting Revenue Change
\echo 'TPC-H Q6: Forecasting Revenue Change'
SELECT
    sum(l_extendedprice * l_discount) as revenue
FROM lineitem
WHERE l_shipdate >= date '1994-01-01'
    AND l_shipdate < date '1994-01-01' + interval '1 year'
    AND l_discount BETWEEN 0.06 - 0.01 AND 0.06 + 0.01
    AND l_quantity < 24;

\echo 'TPC-H Baseline Queries completed!'

-- ===================================================================
-- PERFORMANCE SUMMARY
-- ===================================================================

\echo '=================================='
\echo 'TPC-H Baseline Performance Summary'
\echo '=================================='
\echo 'Data Set Size:'
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_stat_get_tuples_returned(c.oid) as tuples
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE schemaname = 'tpch_baseline'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

\echo 'Baseline schema created and tested successfully!'
\echo 'Use this schema for performance regression testing.' 