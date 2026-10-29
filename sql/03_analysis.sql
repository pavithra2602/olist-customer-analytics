-- Phase 3 analysis. Each query was run and checked, then commented out.
-- The three views are in 04_views.sql. The results summary is at the end of this file.
USE olist_db;
-- Total A: revenue built the safe way (one row per order first)
-- WITH order_revenue AS (
--     SELECT order_id, SUM(price) AS revenue
--     FROM order_items
--     GROUP BY order_id
-- )
-- SELECT ROUND(SUM(r.revenue), 2) AS total_revenue_cte,
--        COUNT(*)                 AS delivered_orders_with_items
-- FROM orders o
-- JOIN order_revenue r ON r.order_id = o.order_id
-- WHERE o.order_status = 'delivered';

-- -- Total B: the same figure calculated directly
-- SELECT ROUND(SUM(oi.price), 2) AS total_revenue_direct
-- FROM order_items oi
-- JOIN orders o ON o.order_id = oi.order_id
-- WHERE o.order_status = 'delivered';

-- Choose your analysis window 
-- SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
--        COUNT(*) AS orders,
--        SUM(order_status = 'delivered') AS delivered_orders
-- FROM orders
-- GROUP BY order_month
-- ORDER BY order_month;

-- Reference total for the window

-- WITH order_revenue AS (
--     SELECT order_id, SUM(price) AS revenue
--     FROM order_items
--     GROUP BY order_id
-- )
-- SELECT ROUND(SUM(r.revenue), 2) AS window_revenue,
--        COUNT(*)                 AS window_orders
-- FROM orders o
-- JOIN order_revenue r ON r.order_id = o.order_id
-- WHERE o.order_status = 'delivered'
--   AND o.order_purchase_timestamp >= '2017-01-01'   -- first day of your first month
--   AND o.order_purchase_timestamp <  '2018-09-01';  -- first day of the month AFTER your last month

-- Create vw_orders_master
-- CREATE OR REPLACE VIEW vw_orders_master AS
-- WITH order_revenue AS (
--     SELECT order_id, SUM(price) AS revenue, SUM(freight_value) AS freight, COUNT(*) AS items
--     FROM order_items
--     GROUP BY order_id
-- ),
-- latest_review AS (
--     SELECT order_id, review_score
--     FROM (SELECT order_id, review_score,
--                  ROW_NUMBER() OVER (PARTITION BY order_id
--                                     ORDER BY review_answer_timestamp DESC) AS rn
--           FROM order_reviews) x
--     WHERE rn = 1
-- )
-- SELECT o.order_id,
--        c.customer_unique_id,
--        c.customer_state,
--        o.order_purchase_timestamp,
--        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
--        r.revenue, r.freight, r.items,
--        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
--        CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
--             WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
--             ELSE 0 END AS is_late,
--        lr.review_score
-- FROM orders o
-- JOIN customers c      ON c.customer_id = o.customer_id
-- JOIN order_revenue r  ON r.order_id = o.order_id
-- LEFT JOIN latest_review lr ON lr.order_id = o.order_id
-- WHERE o.order_status = 'delivered'
--   AND o.order_purchase_timestamp >= '2017-01-01'
--   AND o.order_purchase_timestamp <  '2018-09-01';


-- SELECT COUNT(*) AS rows_, COUNT(DISTINCT order_id) AS distinct_orders,
--        ROUND(SUM(revenue), 2) AS total_revenue
-- FROM vw_orders_master;

-- Revenue and growth queries (4 metrics in one query)
-- WITH monthly AS (
--     SELECT order_month, COUNT(*) AS orders, SUM(revenue) AS revenue
--     FROM vw_orders_master
--     GROUP BY order_month
-- )
-- SELECT order_month,
--        orders,
--        ROUND(revenue, 2)                                  AS revenue,
--        ROUND(revenue / orders, 2)                         AS avg_order_value,
--        ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
--                  / LAG(revenue) OVER (ORDER BY order_month), 2) AS mom_growth_pct,
--        ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS running_revenue
-- FROM monthly
-- ORDER BY order_month; 

-- Products and sellers (3 queries)
-- SELECT COALESCE(t.product_category_name_english,
--                 NULLIF(p.product_category_name, ''), 'unknown') AS category,
--        ROUND(SUM(oi.price), 2)          AS revenue,
--        COUNT(DISTINCT oi.order_id)      AS orders
-- FROM order_items oi
-- JOIN vw_orders_master m ON m.order_id = oi.order_id
-- JOIN products p         ON p.product_id = oi.product_id
-- LEFT JOIN product_category_translation t ON t.product_category_name = p.product_category_name
-- GROUP BY category
-- ORDER BY revenue DESC
-- LIMIT 10;

-- Category rank within each year
-- WITH cat_year AS (
--     SELECT YEAR(m.order_purchase_timestamp) AS yr,
--            COALESCE(t.product_category_name_english,
--                     NULLIF(p.product_category_name, ''), 'unknown') AS category,
--            SUM(oi.price) AS revenue
--     FROM order_items oi
--     JOIN vw_orders_master m ON m.order_id = oi.order_id
--     JOIN products p         ON p.product_id = oi.product_id
--     LEFT JOIN product_category_translation t ON t.product_category_name = p.product_category_name
--     GROUP BY yr, category
-- )
-- SELECT *
-- FROM (SELECT yr, category, ROUND(revenue, 2) AS revenue,
--              RANK() OVER (PARTITION BY yr ORDER BY revenue DESC) AS rnk
--       FROM cat_year) ranked
-- WHERE rnk <= 5
-- ORDER BY yr, rnk;

-- Top 10 sellers with their average review score
-- WITH seller_orders AS (
--     SELECT oi.seller_id, oi.order_id,
--            SUM(oi.price)       AS revenue,
--            MAX(m.review_score) AS review_score
--     FROM order_items oi
--     JOIN vw_orders_master m ON m.order_id = oi.order_id
--     GROUP BY oi.seller_id, oi.order_id
-- )
-- SELECT seller_id,
--        ROUND(SUM(revenue), 2)       AS revenue,
--        COUNT(*)                     AS orders,
--        ROUND(AVG(review_score), 2)  AS avg_review_score
-- FROM seller_orders
-- GROUP BY seller_id
-- ORDER BY revenue DESC
-- LIMIT 10;

-- Customer queries (3)
-- WITH cust AS (
--     SELECT customer_unique_id, COUNT(*) AS orders
--     FROM vw_orders_master
--     GROUP BY customer_unique_id
-- )
-- SELECT COUNT(*) AS customers,
--        SUM(orders > 1) AS repeat_customers,
--        ROUND(100 * SUM(orders > 1) / COUNT(*), 2) AS repeat_pct
-- FROM cust;

-- -- distribution (reuse the same CTE)
-- WITH cust AS (
--     SELECT customer_unique_id, COUNT(*) AS orders
--     FROM vw_orders_master
--     GROUP BY customer_unique_id
-- )
-- SELECT orders AS orders_per_customer, COUNT(*) AS customers
-- FROM cust
-- GROUP BY orders
-- ORDER BY orders;

-- Top 10 states by revenue and customers
-- SELECT customer_state,
--        ROUND(SUM(revenue), 2)             AS revenue,
--        COUNT(*)                           AS orders,
--        COUNT(DISTINCT customer_unique_id) AS customers
-- FROM vw_orders_master
-- GROUP BY customer_state
-- ORDER BY revenue DESC
-- LIMIT 10; 

-- Delivery queries (3)
-- overall
-- SELECT ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
--        ROUND(100 * AVG(is_late), 2) AS late_pct
-- FROM vw_orders_master;

-- by state
-- SELECT customer_state,
--        COUNT(*) AS orders,
--        ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
--        ROUND(100 * AVG(is_late), 2) AS late_pct
-- FROM vw_orders_master
-- GROUP BY customer_state
-- HAVING COUNT(*) >= 100
-- ORDER BY late_pct DESC;

-- review score: late vs on time
-- SELECT CASE WHEN is_late = 1 THEN 'late' ELSE 'on_time' END AS delivery_status,
--        COUNT(*) AS orders,
--        ROUND(AVG(review_score), 2) AS avg_review_score
-- FROM vw_orders_master
-- WHERE is_late IS NOT NULL
-- GROUP BY delivery_status;

-- Payment queries (2)
-- value share by payment type
-- SELECT p.payment_type,
--        COUNT(DISTINCT p.order_id) AS orders,
--        ROUND(SUM(p.payment_value), 2) AS payment_value,
--        ROUND(100 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 2) AS share_pct
-- FROM order_payments p
-- JOIN vw_orders_master m ON m.order_id = p.order_id
-- WHERE p.payment_type <> 'not_defined'
-- GROUP BY p.payment_type
-- ORDER BY payment_value DESC;

-- average installments by payment type
-- SELECT p.payment_type,
--        ROUND(AVG(p.payment_installments), 2) AS avg_installments
-- FROM order_payments p
-- JOIN vw_orders_master m ON m.order_id = p.order_id
-- WHERE p.payment_type <> 'not_defined'
-- GROUP BY p.payment_type
-- ORDER BY avg_installments DESC;

-- The other two views (now in 04_views.sql)
-- CREATE OR REPLACE VIEW vw_monthly_kpis AS
-- WITH seq AS (
--     SELECT m.*,
--            ROW_NUMBER() OVER (PARTITION BY customer_unique_id
--                               ORDER BY order_purchase_timestamp, order_id) AS order_seq
--     FROM vw_orders_master m
-- )
-- SELECT order_month,
--        COUNT(*)                                AS orders,
--        ROUND(SUM(revenue), 2)                  AS revenue,
--        ROUND(SUM(revenue) / COUNT(*), 2)       AS avg_order_value,
--        ROUND(100 * AVG(order_seq > 1), 2)      AS returning_order_pct,
--        ROUND(100 * (1 - AVG(is_late)), 2)      AS on_time_pct,
--        ROUND(AVG(review_score), 2)             AS avg_review_score
-- FROM seq
-- GROUP BY order_month;

-- CREATE OR REPLACE VIEW vw_customer_summary AS
-- SELECT customer_unique_id,
--        MIN(order_purchase_timestamp) AS first_order_date,
--        MAX(order_purchase_timestamp) AS last_order_date,
--        COUNT(*)                      AS orders,
--        ROUND(SUM(revenue), 2)        AS total_spend
-- FROM vw_orders_master
-- GROUP BY customer_unique_id;


-- vw_customer_summary
-- SELECT COUNT(*) AS customers, SUM(orders) AS orders, ROUND(SUM(total_spend), 2) AS total_spend
-- FROM vw_customer_summary;

-- vw_monthly_kpis
-- SELECT COUNT(*) AS months, SUM(orders) AS orders, ROUND(SUM(revenue), 2) AS revenue
-- FROM vw_monthly_kpis;

-- SELECT * FROM vw_monthly_kpis ORDER BY order_month;


SELECT COUNT(*) AS orders,
       SUM(review_score IS NULL) AS no_review,
       SUM(is_late IS NULL)      AS no_late_flag,
       SUM(delivery_days IS NULL) AS no_delivery_days
FROM vw_orders_master;

/* ============================================================
   RESULTS SUMMARY (Phase 3). Window: Jan 2017 to Aug 2018, delivered orders only.
   Revenue = SUM(price), freight excluded.

   REFERENCE TOTALS
   - Window revenue: 13,181,027.13 | window orders: 96,211 | customers: 93,104
   - All months, all delivered orders: 13,221,498.11 (96,478 orders)
   - Reconciled to 13,181,027.13: vw_orders_master, vw_monthly_kpis,
     vw_customer_summary, category total (74 categories), state total (27 states),
     running total at 2018-08
   - items without a product: 0

   REVENUE AND GROWTH (monthly query)
   - 2017-01: 750 orders, 111,798.36 | 2017-02: 1,653 orders, 234,223.40 (+109.51%)
   - 2017-11: 7,289 orders, 987,765.37 (+52.37%)
   - AOV from Jan to Nov 2017 stays between about 124 and 149
   - Early 2017 growth reflects the marketplace ramping up, not steady growth

   PRODUCTS
   - Top 10 categories by revenue: health_beauty 1,229,557.50 | watches_gifts 1,163,465.91 |
     bed_bath_table 1,022,955.77 | sports_leisure 952,840.40 | computers_accessories 888,055.59 |
     furniture_decor 706,237.17 | housewares 614,341.62 | cool_stuff 609,158.00 |
     auto 577,838.39 | garden_tools 469,135.40
   - Top 5 in 2017: bed_bath_table, watches_gifts, health_beauty, sports_leisure,
     computers_accessories
   - Top 5 in 2018 (Jan to Aug): health_beauty, watches_gifts, bed_bath_table,
     sports_leisure, computers_accessories

   SELLERS (top 10 by revenue; seller IDs shortened to the first 8 characters)
   - 4869f7a5: 226,987.93 | 1,124 orders | avg review 4.15
   - 53243585: 217,940.44 | 348 orders   | avg review 4.19
   - 4a3ca931: 196,882.12 | 1,772 orders | avg review 3.85
   - fa1c13f2: 190,917.14 | 578 orders   | avg review 4.37
   - 7c67e144: 186,570.05 | 973 orders   | avg review 3.50
   - 7e93a43e: 164,582.49 | 318 orders   | avg review 4.36
   - da8622b1: 159,816.87 | 1,311 orders | avg review 4.18
   - 7a67c85e: 139,658.69 | 1,145 orders | avg review 4.28
   - 1025f0e2: 138,208.56 | 910 orders   | avg review 4.01
   - 955fee92: 131,836.71 | 1,261 orders | avg review 4.20

   CUSTOMERS
   - Repeat customers: 2,789 of 93,104 (3.00%)
   - Orders per customer: 1 order 90,315 | 2 orders 2,562 | 3 orders 180 | 4 orders 28 |
     5 orders 9 | 6 orders 5 | 7 orders 3 | 9 orders 1 | 15 orders 1
   - Top states by revenue: SP 5,055,587.13 | RJ 1,751,433.85 | MG 1,548,206.88 |
     RS 726,373.92 | PR 664,048.00 | SC 504,774.07 | BA 493,339.26 | DF 295,454.64 |
     GO 281,932.21 | ES 267,783.66
   - SP is about 38% of revenue; SP + RJ + MG about 63% (calculated)

   DELIVERY
   - Average delivery 12.5 days; late 8.13%
   - Late by state (states with 100+ orders): AL 23.99% | MA 19.64% | PI 16.00% | CE 15.40% |
     SE 15.36% | BA 14.05% | RJ 13.52% | SP 5.90%
   - Review score: on time 88,381 orders avg 4.29 | late 7,822 orders avg 2.57
   - 8 delivered orders have no delivery date, so they are not classified as late or on time

   PAYMENTS (payment value includes freight, so it differs from item revenue)
   - credit_card 74,095 orders, 12,063,100.59 (78.45%) | boleto 19,140, 2,762,300.80 (17.97%)
   - voucher 3,670, 342,294.66 (2.23%) | debit_card 1,483, 208,179.39 (1.35%)
   - Average installments: credit_card 3.50 | boleto, voucher, debit_card 1.00
   - not_defined excluded (3 payments, value 0.00)

   DATA NOTES
   - vw_orders_master: 644 orders have no review, 8 have no delivery date or late flag
   - returning_order_pct in vw_monthly_kpis undercounts returning customers because it
     only sees orders inside the window
   ============================================================ */
   
   
   