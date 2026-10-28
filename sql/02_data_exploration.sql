USE olist_db;

-- run these for each of the 9 tables (change the table name).
-- Tables: customers, orders, order_items, order_payments, order_reviews, products, sellers, geolocation, product_category_translation.

-- SELECT * FROM customers LIMIT 10;
-- DESCRIBE customers;
-- ---------------------------------------------------- 
-- who is a “customer”?
-- SELECT COUNT(DISTINCT customer_id) AS customer_ids,
--        COUNT(DISTINCT customer_unique_id) AS real_customers
--        From customers;

-- Expect: about 99,441 vs about 96,096.
-- Why it matters: customer_id is generated per order,
--  so a person who orders twice has two.
--  Repeat rate, RFM and cohorts all need customer_unique_id.

----------------------------------------------------------
-- which orders count?

-- SELECT order_status,
--        COUNT(*) AS orders,
--        ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
-- FROM orders
-- GROUP BY order_status
-- ORDER BY orders DESC;

-- Expect: delivered is about 97% (about 96,478).
--  The rest are shipped, canceled, unavailable, invoiced, processing, created and approved.

-- Decision: revenue analysis uses delivered only, 
-- since the others aren’t completed sales.

-- --------------------------------------------------------------
-- which orders count?
-- SELECT order_status,
--        COUNT(*) AS orders,
--        ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
-- FROM orders
-- GROUP BY order_status
-- ORDER BY orders DESC;

-- Expect: delivered is about 97% (about 96,478).
--  The rest are shipped, canceled, unavailable, invoiced, processing, created and approved.

-- -- Decision: revenue analysis uses delivered only, since the others aren’t completed sales.

-- -- ------------------------------------------------------------------------------
-- -- the duplication trap (most important)
-- A. How many rows can one order have in each child table?
-- items per order
-- SELECT items_per_order, COUNT(*) AS orders
-- FROM (SELECT order_id, COUNT(*) AS items_per_order
--       FROM order_items GROUP BY order_id) t
-- GROUP BY items_per_order ORDER BY items_per_order;

-- payment rows per order
-- SELECT payments_per_order, COUNT(*) AS orders
-- FROM (SELECT order_id, COUNT(*) AS payments_per_order
--       FROM order_payments GROUP BY order_id) t
-- GROUP BY payments_per_order ORDER BY payments_per_order;

-- reviews per order
-- SELECT reviews_per_order, COUNT(*) AS orders
-- FROM (SELECT order_id, COUNT(*) AS reviews_per_order
--       FROM order_reviews GROUP BY order_id) t
-- GROUP BY reviews_per_order ORDER BY reviews_per_order;

-- -- Expect: most orders have 1 of each, but a real minority 
-- -- have 2 or more (about 10% of orders have multiple items, 
-- -- and some have several payment rows).

-- B. See the inflation with your own eyes 
-- SELECT
--   (SELECT SUM(price) FROM order_items) AS correct_item_total,
--   (SELECT SUM(oi.price)
--    FROM order_items oi
--    JOIN order_payments p ON oi.order_id = p.order_id) AS inflated_total;
   
-- -- The second number is larger. Same data, wrong join, inflated revenue.
-- --  That’s the trap.
-- -- The rule to write in notes.md: never join items, payments and reviews to orders all at once. Aggregate each child table to one row per order first (GROUP BY order_id), then join the results.

-- -- --------------------------------------------------------------------------------- 
-- Do all orders have items?
-- SELECT COUNT(*) AS orders_without_items
-- FROM orders o
-- LEFT JOIN order_items oi ON o.order_id = oi.order_id
-- WHERE oi.order_id IS NULL;

-- -- Expect: a small number (about 775), mostly canceled or unavailable orders. 
-- -- This is another reason to filter to delivered. 
-- -- -----------------------------------------------------------------------------------------

-- date range and completeness
-- SELECT MIN(order_purchase_timestamp) AS first_order,
--        MAX(order_purchase_timestamp) AS last_order
-- FROM orders;

-- SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS year_month_,
--        COUNT(*) AS orders
-- FROM orders
-- GROUP BY year_month_
-- ORDER BY year_month_;

-- -- Expect: data from September 2016 to October 2018. The 2016 months and the last two months of 2018 have very few orders 
-- -- (some months have only a handful, or none), while January 2017 to August 2018 is steady and growing.

-- -- Decision to write down: analysis window is January 2017 to August 2018,
-- --  because the months outside it are too sparse and would create fake growth or drops in trends.  

-- -- ----------------------------------------------------------------------------------------------------------------------------------
-- missing values
-- SELECT COUNT(*) AS total_orders,
--        SUM(order_approved_at IS NULL)             AS no_approval_date,
--        SUM(order_delivered_carrier_date IS NULL)  AS no_carrier_date,
--        SUM(order_delivered_customer_date IS NULL) AS no_delivery_date
-- FROM orders;

-- are the missing delivery dates just non-delivered orders?
-- SELECT order_status, COUNT(*) AS missing_delivery_date
-- FROM orders
-- WHERE order_delivered_customer_date IS NULL
-- GROUP BY order_status
-- ORDER BY missing_delivery_date DESC;

-- data quality: delivered but no delivery date
-- SELECT COUNT(*) AS delivered_without_date
-- FROM orders
-- WHERE order_status = 'delivered'
--   AND order_delivered_customer_date IS NULL;

-- products without a category
-- SELECT COUNT(*) AS products_without_category
-- FROM products
-- WHERE product_category_name IS NULL OR product_category_name = '';

-- -- -----------------------------------------------------------------------------------------

-- -- duplicates and keys
-- -- is order_id unique in orders? (the two numbers should match)
-- SELECT COUNT(*) AS rows_, COUNT(DISTINCT order_id) AS distinct_orders FROM orders;

-- -- is review_id unique in reviews?
-- SELECT COUNT(*) AS rows_, COUNT(DISTINCT review_id) AS distinct_reviews FROM order_reviews;

-- orders with more than one review
-- SELECT COUNT(*) AS orders_with_multiple_reviews
-- FROM (SELECT order_id FROM order_reviews
--       GROUP BY order_id HAVING COUNT(*) > 1) t;

-- product categories missing from the translation table
-- SELECT DISTINCT p.product_category_name
-- FROM products p
-- LEFT JOIN product_category_translation t
--        ON p.product_category_name = t.product_category_name
-- WHERE t.product_category_name IS NULL
--   AND p.product_category_name <> '';
--   
-- -- -------------------------------------------------------------------------------------------------
-- sanity checks
-- SELECT MIN(price) AS min_price, MAX(price) AS max_price, ROUND(AVG(price),2) AS avg_price,
--        MIN(freight_value) AS min_freight, MAX(freight_value) AS max_freight,
--        ROUND(AVG(freight_value),2) AS avg_freight,
--        SUM(price <= 0)         AS non_positive_prices,
--        SUM(freight_value = 0)  AS zero_freight
-- FROM order_items;

-- SELECT payment_type, COUNT(*) AS payments, ROUND(SUM(payment_value),2) AS total_value
-- FROM order_payments
-- GROUP BY payment_type
-- ORDER BY payments DESC;

-- orders paid with more than one payment type
-- SELECT COUNT(*) AS multi_type_orders
-- FROM (SELECT order_id FROM order_payments
--       GROUP BY order_id HAVING COUNT(DISTINCT payment_type) > 1) t;
--       
-- -- -------------------------------------------------------------------------------------- 

