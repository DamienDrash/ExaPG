-- ===================================================================
-- ExaPG OLTP Performance Baseline Queries  
-- ===================================================================
-- PERFORMANCE FIX: PERF-002 - OLTP Workload Baseline Queries
-- Date: 2024-05-24
-- ===================================================================

-- ===================================================================
-- SETUP AND INITIALIZATION
-- ===================================================================

\set ECHO all
\timing on

-- Drop existing baseline schema and recreate
DROP SCHEMA IF EXISTS oltp_baseline CASCADE;
CREATE SCHEMA oltp_baseline;

-- Set search path
SET search_path TO oltp_baseline, public;

-- ===================================================================
-- OLTP SAMPLE DATA CREATION
-- ===================================================================

-- Users table
CREATE TABLE users (
    user_id         SERIAL PRIMARY KEY,
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active       BOOLEAN DEFAULT TRUE,
    last_login      TIMESTAMP
);

-- Accounts table
CREATE TABLE accounts (
    account_id      SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(user_id),
    account_number  VARCHAR(20) UNIQUE NOT NULL,
    account_type    VARCHAR(20) NOT NULL CHECK (account_type IN ('checking', 'savings', 'credit')),
    balance         DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency        VARCHAR(3) DEFAULT 'USD',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active       BOOLEAN DEFAULT TRUE
);

-- Transactions table
CREATE TABLE transactions (
    transaction_id  SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id   INTEGER REFERENCES accounts(account_id),
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('transfer', 'deposit', 'withdrawal', 'payment')),
    amount          DECIMAL(15,2) NOT NULL,
    currency        VARCHAR(3) DEFAULT 'USD',
    description     TEXT,
    reference_number VARCHAR(50) UNIQUE,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at    TIMESTAMP,
    fee_amount      DECIMAL(15,2) DEFAULT 0.00
);

-- Products table
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    product_code    VARCHAR(50) UNIQUE NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category        VARCHAR(50) NOT NULL,
    price           DECIMAL(10,2) NOT NULL,
    cost            DECIMAL(10,2) NOT NULL,
    quantity_in_stock INTEGER NOT NULL DEFAULT 0,
    reorder_level   INTEGER DEFAULT 10,
    supplier_id     INTEGER,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active       BOOLEAN DEFAULT TRUE
);

-- Orders table
CREATE TABLE orders (
    order_id        SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(user_id),
    order_number    VARCHAR(50) UNIQUE NOT NULL,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    total_amount    DECIMAL(15,2) NOT NULL,
    tax_amount      DECIMAL(15,2) DEFAULT 0.00,
    shipping_amount DECIMAL(15,2) DEFAULT 0.00,
    discount_amount DECIMAL(15,2) DEFAULT 0.00,
    payment_method  VARCHAR(20),
    shipping_address TEXT,
    billing_address TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    shipped_at      TIMESTAMP,
    delivered_at    TIMESTAMP
);

-- Order items table
CREATE TABLE order_items (
    order_item_id   SERIAL PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES orders(order_id),
    product_id      INTEGER NOT NULL REFERENCES products(product_id),
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    total_price     DECIMAL(15,2) NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log table
CREATE TABLE audit_log (
    log_id          SERIAL PRIMARY KEY,
    table_name      VARCHAR(50) NOT NULL,
    record_id       INTEGER NOT NULL,
    action          VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values      JSONB,
    new_values      JSONB,
    changed_by      INTEGER,
    changed_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===================================================================
-- CREATE INDEXES FOR OLTP PERFORMANCE
-- ===================================================================

-- Users indexes
CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_active ON users (is_active);
CREATE INDEX idx_users_last_login ON users (last_login);

-- Accounts indexes
CREATE INDEX idx_accounts_user_id ON accounts (user_id);
CREATE INDEX idx_accounts_number ON accounts (account_number);
CREATE INDEX idx_accounts_type ON accounts (account_type);
CREATE INDEX idx_accounts_active ON accounts (is_active);

-- Transactions indexes
CREATE INDEX idx_transactions_from_account ON transactions (from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions (to_account_id);
CREATE INDEX idx_transactions_type ON transactions (transaction_type);
CREATE INDEX idx_transactions_status ON transactions (status);
CREATE INDEX idx_transactions_created_at ON transactions (created_at);
CREATE INDEX idx_transactions_reference ON transactions (reference_number);

-- Products indexes
CREATE INDEX idx_products_code ON products (product_code);
CREATE INDEX idx_products_category ON products (category);
CREATE INDEX idx_products_active ON products (is_active);
CREATE INDEX idx_products_stock ON products (quantity_in_stock);

-- Orders indexes
CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_number ON orders (order_number);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_created_at ON orders (created_at);

-- Order items indexes
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- Audit log indexes
CREATE INDEX idx_audit_log_table_record ON audit_log (table_name, record_id);
CREATE INDEX idx_audit_log_changed_at ON audit_log (changed_at);
CREATE INDEX idx_audit_log_changed_by ON audit_log (changed_by);

-- ===================================================================
-- GENERATE SAMPLE DATA
-- ===================================================================

-- Generate users (50,000 records)
INSERT INTO users (username, email, password_hash, first_name, last_name, last_login)
SELECT 
    'user' || i,
    'user' || i || '@example.com',
    MD5('password' || i),
    'FirstName' || i,
    'LastName' || i,
    CURRENT_TIMESTAMP - (random() * INTERVAL '365 days')
FROM generate_series(1, 50000) i;

-- Generate accounts (100,000 records - 2 per user on average)
INSERT INTO accounts (user_id, account_number, account_type, balance)
SELECT 
    (i % 50000) + 1,
    'ACC' || LPAD(i::text, 10, '0'),
    CASE (i % 3) 
        WHEN 0 THEN 'checking'
        WHEN 1 THEN 'savings'
        ELSE 'credit'
    END,
    (random() * 50000)::decimal(15,2)
FROM generate_series(1, 100000) i;

-- Generate products (10,000 records)
INSERT INTO products (product_code, name, description, category, price, cost, quantity_in_stock, supplier_id)
SELECT 
    'PROD' || LPAD(i::text, 6, '0'),
    'Product Name ' || i,
    'Description for product ' || i,
    CASE (i % 10)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Home & Garden'
        WHEN 4 THEN 'Sports'
        WHEN 5 THEN 'Toys'
        WHEN 6 THEN 'Automotive'
        WHEN 7 THEN 'Health'
        WHEN 8 THEN 'Beauty'
        ELSE 'Others'
    END,
    (random() * 1000 + 10)::decimal(10,2),
    (random() * 500 + 5)::decimal(10,2),
    (random() * 1000)::integer,
    (i % 1000) + 1
FROM generate_series(1, 10000) i;

-- Generate orders (200,000 records)
INSERT INTO orders (user_id, order_number, status, total_amount, tax_amount, shipping_amount, payment_method, created_at)
SELECT 
    (i % 50000) + 1,
    'ORD' || LPAD(i::text, 10, '0'),
    CASE (i % 5)
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'processing'
        WHEN 2 THEN 'shipped'
        WHEN 3 THEN 'delivered'
        ELSE 'cancelled'
    END,
    (random() * 1000 + 50)::decimal(15,2),
    (random() * 100)::decimal(15,2),
    (random() * 50)::decimal(15,2),
    CASE (i % 4)
        WHEN 0 THEN 'credit_card'
        WHEN 1 THEN 'debit_card'
        WHEN 2 THEN 'paypal'
        ELSE 'bank_transfer'
    END,
    CURRENT_TIMESTAMP - (random() * INTERVAL '365 days')
FROM generate_series(1, 200000) i;

-- Generate order items (500,000 records)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT 
    (i % 200000) + 1,
    (random() * 9999 + 1)::integer,
    (random() * 5 + 1)::integer,
    (random() * 100 + 10)::decimal(10,2),
    ((random() * 5 + 1) * (random() * 100 + 10))::decimal(15,2)
FROM generate_series(1, 500000) i;

-- Generate transactions (1,000,000 records)
INSERT INTO transactions (from_account_id, to_account_id, transaction_type, amount, description, reference_number, status, created_at)
SELECT 
    (random() * 99999 + 1)::integer,
    CASE WHEN random() > 0.3 THEN (random() * 99999 + 1)::integer ELSE NULL END,
    CASE (i % 4)
        WHEN 0 THEN 'transfer'
        WHEN 1 THEN 'deposit'
        WHEN 2 THEN 'withdrawal'
        ELSE 'payment'
    END,
    (random() * 10000 + 1)::decimal(15,2),
    'Transaction description ' || i,
    'TXN' || LPAD(i::text, 12, '0'),
    CASE (i % 10)
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'failed'
        ELSE 'completed'
    END,
    CURRENT_TIMESTAMP - (random() * INTERVAL '90 days')
FROM generate_series(1, 1000000) i;

-- Update statistics
ANALYZE;

-- ===================================================================
-- OLTP BENCHMARK QUERIES
-- ===================================================================

\echo 'Starting OLTP Baseline Queries...'

-- Query 1: User Authentication (High Frequency)
\echo 'OLTP Q1: User Authentication'
SELECT user_id, username, password_hash, is_active, last_login
FROM users 
WHERE username = 'user12345' AND is_active = true;

-- Query 2: Account Balance Lookup (High Frequency)
\echo 'OLTP Q2: Account Balance Lookup'
SELECT account_id, account_number, balance, account_type, currency
FROM accounts 
WHERE account_number = 'ACC0001234567' AND is_active = true;

-- Query 3: Recent Transactions (High Frequency)
\echo 'OLTP Q3: Recent Transactions for Account'
SELECT transaction_id, transaction_type, amount, description, status, created_at
FROM transactions 
WHERE from_account_id = 12345 OR to_account_id = 12345
ORDER BY created_at DESC 
LIMIT 10;

-- Query 4: Product Catalog Search (High Frequency)
\echo 'OLTP Q4: Product Search by Category'
SELECT product_id, product_code, name, price, quantity_in_stock
FROM products 
WHERE category = 'Electronics' AND is_active = true AND quantity_in_stock > 0
ORDER BY name
LIMIT 20;

-- Query 5: Order Details Lookup (High Frequency)
\echo 'OLTP Q5: Order Details with Items'
SELECT 
    o.order_id, o.order_number, o.status, o.total_amount, o.created_at,
    oi.product_id, oi.quantity, oi.unit_price, oi.total_price,
    p.name as product_name
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_number = 'ORD0001234567';

-- Query 6: User's Active Orders (Medium Frequency)
\echo 'OLTP Q6: User Active Orders'
SELECT order_id, order_number, status, total_amount, created_at
FROM orders 
WHERE user_id = 12345 AND status IN ('pending', 'processing', 'shipped')
ORDER BY created_at DESC;

-- Query 7: Account Transaction Summary (Medium Frequency)
\echo 'OLTP Q7: Account Transaction Summary'
SELECT 
    transaction_type,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount
FROM transactions 
WHERE (from_account_id = 12345 OR to_account_id = 12345)
    AND created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND status = 'completed'
GROUP BY transaction_type;

-- Query 8: Daily Sales Summary (Medium Frequency)
\echo 'OLTP Q8: Daily Sales Summary'
SELECT 
    DATE(created_at) as sale_date,
    COUNT(*) as order_count,
    SUM(total_amount) as total_sales,
    AVG(total_amount) as avg_order_value
FROM orders 
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    AND status IN ('delivered', 'shipped')
GROUP BY DATE(created_at)
ORDER BY sale_date DESC;

-- Query 9: Low Stock Products (Low Frequency)
\echo 'OLTP Q9: Low Stock Alert'
SELECT product_id, product_code, name, quantity_in_stock, reorder_level
FROM products 
WHERE quantity_in_stock <= reorder_level AND is_active = true
ORDER BY quantity_in_stock ASC;

-- Query 10: Top Customers by Revenue (Low Frequency)
\echo 'OLTP Q10: Top Customers by Revenue'
SELECT 
    u.user_id, u.username, u.first_name, u.last_name,
    COUNT(o.order_id) as order_count,
    SUM(o.total_amount) as total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.status = 'delivered'
    AND o.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY u.user_id, u.username, u.first_name, u.last_name
HAVING SUM(o.total_amount) > 1000
ORDER BY total_spent DESC
LIMIT 10;

-- Query 11: Concurrent Transaction Simulation (Critical for OLTP)
\echo 'OLTP Q11: Concurrent Account Update Simulation'
BEGIN;
SELECT balance FROM accounts WHERE account_id = 12345 FOR UPDATE;
UPDATE accounts SET balance = balance - 100.00 WHERE account_id = 12345;
UPDATE accounts SET balance = balance + 100.00 WHERE account_id = 12346;
INSERT INTO transactions (from_account_id, to_account_id, transaction_type, amount, description, reference_number, status)
VALUES (12345, 12346, 'transfer', 100.00, 'Test transfer', 'TXN_TEST_' || extract(epoch from now()), 'completed');
COMMIT;

-- Query 12: Performance Stress Test (Point Lookups)
\echo 'OLTP Q12: Random Point Lookups (Stress Test)'
SELECT COUNT(*) as lookup_count FROM (
    SELECT user_id FROM users WHERE user_id = 1234
    UNION ALL
    SELECT user_id FROM users WHERE user_id = 5678
    UNION ALL
    SELECT user_id FROM users WHERE user_id = 9012
    UNION ALL
    SELECT user_id FROM users WHERE user_id = 3456
    UNION ALL
    SELECT user_id FROM users WHERE user_id = 7890
) lookups;

\echo 'OLTP Baseline Queries completed!'

-- ===================================================================
-- PERFORMANCE METRICS COLLECTION
-- ===================================================================

\echo '=================================='
\echo 'OLTP Baseline Performance Summary'
\echo '=================================='

-- Table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    n_tup_ins + n_tup_upd + n_tup_del as total_modifications
FROM pg_tables t
LEFT JOIN pg_stat_user_tables s ON t.tablename = s.relname AND t.schemaname = s.schemaname
WHERE t.schemaname = 'oltp_baseline'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'oltp_baseline'
ORDER BY idx_scan DESC;

\echo 'OLTP Baseline schema created and tested successfully!'
\echo 'Use this schema for OLTP performance regression testing.' 