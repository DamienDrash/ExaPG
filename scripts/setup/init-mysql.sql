-- MySQL Initialisierungsskript für ExaPG Virtual Schemas Demo

-- Erstelle und verwende Testdatenbank
USE testdb;

-- Erstelle Beispieltabellen
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status ENUM('active', 'inactive', 'banned') DEFAULT 'active',
    login_count INT DEFAULT 0,
    last_login DATETIME,
    UNIQUE KEY uq_username (username),
    UNIQUE KEY uq_email (email)
);

CREATE TABLE IF NOT EXISTS orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    shipping_address TEXT,
    tracking_number VARCHAR(100),
    KEY idx_user_id (user_id),
    KEY idx_order_date (order_date),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    category VARCHAR(100),
    sku VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_category (category),
    KEY idx_price (price)
);

CREATE TABLE IF NOT EXISTS order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_per_unit DECIMAL(10,2) NOT NULL,
    KEY idx_order_id (order_id),
    KEY idx_product_id (product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Erstelle Beispieldaten
INSERT INTO users (username, email, status, login_count, last_login)
VALUES 
('max_muster', 'max.muster@example.com', 'active', 27, NOW() - INTERVAL 2 DAY),
('anna_schmidt', 'anna.schmidt@example.com', 'active', 14, NOW() - INTERVAL 1 DAY),
('peter_müller', 'peter.mueller@example.com', 'inactive', 5, NOW() - INTERVAL 30 DAY),
('sarah_weber', 'sarah.weber@example.com', 'active', 42, NOW() - INTERVAL 1 HOUR),
('thomas_klein', 'thomas.klein@example.com', 'banned', 3, NOW() - INTERVAL 60 DAY);

INSERT INTO products (name, description, price, stock_quantity, category, sku)
VALUES 
('ExaPG T-Shirt', 'T-Shirt mit ExaPG Logo', 19.99, 100, 'Bekleidung', 'EXAPG-TS-001'),
('PostgreSQL Tasse', 'Kaffeetasse mit PostgreSQL Elefant', 9.99, 50, 'Geschenke', 'PG-MUG-002'),
('SQL Lehrbuch', 'SQL für Anfänger und Fortgeschrittene', 29.99, 25, 'Bücher', 'SQL-BOOK-003'),
('Datenbank-Poster', 'Großes Poster mit Datenbankarchitektur', 14.99, 30, 'Poster', 'DB-POST-004'),
('ExaPG Aufkleber Set', '10 Aufkleber mit ExaPG Logo', 4.99, 200, 'Geschenke', 'EXAPG-STK-005');

INSERT INTO orders (user_id, order_date, total_amount, status, shipping_address, tracking_number)
VALUES 
(1, NOW() - INTERVAL 10 DAY, 39.98, 'completed', 'Musterstraße 1, 12345 Berlin', 'TRK123456789'),
(2, NOW() - INTERVAL 5 DAY, 59.97, 'shipped', 'Schmidtweg 42, 23456 Hamburg', 'TRK987654321'),
(3, NOW() - INTERVAL 60 DAY, 9.99, 'completed', 'Müllerplatz 3, 34567 München', 'TRK456123789'),
(4, NOW() - INTERVAL 1 DAY, 14.99, 'processing', 'Weberstraße 7, 45678 Frankfurt', NULL),
(1, NOW(), 4.99, 'pending', 'Musterstraße 1, 12345 Berlin', NULL);

INSERT INTO order_items (order_id, product_id, quantity, price_per_unit)
VALUES 
(1, 1, 2, 19.99), -- 2 T-Shirts
(2, 3, 1, 29.99), -- 1 SQL Buch
(2, 2, 3, 9.99),  -- 3 Tassen
(3, 2, 1, 9.99),  -- 1 Tasse
(4, 4, 1, 14.99), -- 1 Poster
(5, 5, 1, 4.99);  -- 1 Aufkleber Set

-- Erstelle Ansicht für nützliche Abfragen
CREATE OR REPLACE VIEW order_summary AS
SELECT 
    o.id AS order_id,
    u.username,
    o.order_date,
    o.total_amount,
    o.status,
    COUNT(oi.id) AS num_items,
    GROUP_CONCAT(p.name SEPARATOR ', ') AS products
FROM 
    orders o
    JOIN users u ON o.user_id = u.id
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
GROUP BY 
    o.id, u.username, o.order_date, o.total_amount, o.status; 