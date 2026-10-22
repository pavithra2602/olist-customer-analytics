-- ============================================================
-- Olist E-Commerce Analytics | Step 1: Create database, tables, load data
-- Run in MySQL Workbench. Edit @path below to YOUR folder (use forward slashes).
-- ============================================================

CREATE DATABASE IF NOT EXISTS olist_db;
USE olist_db;

-- Needed for LOAD DATA LOCAL INFILE.
-- Also in Workbench: Edit Connection > Advanced > Others, add:  OPT_LOCAL_INFILE=1
SET GLOBAL local_infile = 1;

-- ---------- TABLES ----------
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
    customers, products, sellers, geolocation, product_category_translation;

CREATE TABLE customers (
    customer_id               VARCHAR(50) PRIMARY KEY,
    customer_unique_id        VARCHAR(50),
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             VARCHAR(100),
    customer_state            CHAR(2)
);

CREATE TABLE sellers (
    seller_id               VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            CHAR(2)
);

CREATE TABLE products (
    product_id                    VARCHAR(50) PRIMARY KEY,
    product_category_name         VARCHAR(100),
    product_name_lenght           INT,
    product_description_lenght    INT,
    product_photos_qty            INT,
    product_weight_g              INT,
    product_length_cm             INT,
    product_height_cm             INT,
    product_width_cm              INT
);

CREATE TABLE product_category_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100)
);

CREATE TABLE orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        DATETIME,
    order_approved_at               DATETIME,
    order_delivered_carrier_date    DATETIME,
    order_delivered_customer_date   DATETIME,
    order_estimated_delivery_date   DATETIME,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id             VARCHAR(50),
    order_item_id        INT,
    product_id           VARCHAR(50),
    seller_id            VARCHAR(50),
    shipping_limit_date  DATETIME,
    price                DECIMAL(10,2),
    freight_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id               VARCHAR(50),
    payment_sequential     INT,
    payment_type           VARCHAR(30),
    payment_installments   INT,
    payment_value          DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- review_id is NOT unique in this dataset, so no primary key on it
CREATE TABLE order_reviews (
    review_id                VARCHAR(50),
    order_id                 VARCHAR(50),
    review_score             INT,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     DATETIME,
    review_answer_timestamp  DATETIME
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix  VARCHAR(10),
    geolocation_lat              DOUBLE,
    geolocation_lng              DOUBLE,
    geolocation_city             VARCHAR(100),
    geolocation_state            CHAR(2)
);

-- ---------- LOAD DATA ----------
-- CHANGE THIS PATH to where your CSVs are. Example: C:/Users/you/olist-customer-analytics/data/raw/
-- (MySQL doesn't support variables in LOAD DATA paths, so find/replace the path below.)

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(product_id, product_category_name, @a, @b, @c, @d, @e, @f, @g)
SET product_name_lenght       = NULLIF(@a,''),
    product_description_lenght= NULLIF(@b,''),
    product_photos_qty        = NULLIF(@c,''),
    product_weight_g          = NULLIF(@d,''),
    product_length_cm         = NULLIF(@e,''),
    product_height_cm         = NULLIF(@f,''),
    product_width_cm          = NULLIF(@g,'');

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/product_category_name_translation.csv'
INTO TABLE product_category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(order_id, customer_id, order_status, @p, @a, @c, @d, @e)
SET order_purchase_timestamp      = NULLIF(@p,''),
    order_approved_at             = NULLIF(@a,''),
    order_delivered_carrier_date  = NULLIF(@c,''),
    order_delivered_customer_date = NULLIF(@d,''),
    order_estimated_delivery_date = NULLIF(@e,'');

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(review_id, order_id, review_score, @t, @m, @c, @a)
SET review_comment_title    = NULLIF(@t,''),
    review_comment_message  = NULLIF(@m,''),
    review_creation_date    = NULLIF(@c,''),
    review_answer_timestamp = NULLIF(@a,'');

LOAD DATA LOCAL INFILE 'C:/PATH/TO/data/raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- ---------- VERIFY ROW COUNTS ----------
-- Expected approx: customers 99441, orders 99441, order_items 112650,
-- payments 103886, reviews 99224, products 32951, sellers 3095,
-- geolocation 1000163, translation 71
SELECT 'customers' AS tbl, COUNT(*) AS n FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'translation', COUNT(*) FROM product_category_translation;
