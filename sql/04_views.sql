-- Views for Power BI and the Python notebooks.
-- Run after 01_create_tables_and_load.sql. Window: Jan 2017 to Aug 2018, delivered orders only.
-- Run in this order: vw_orders_master first, because the other two views read from it.
USE olist_db;

-- ------------------------------------------------------------
-- 1. vw_orders_master: one row per delivered order in the window
--    Revenue and reviews are reduced to one row per order before joining,
--    so revenue is never duplicated. The latest review is kept for orders with several.
--    is_late is NULL for the 8 delivered orders with no delivery date.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_orders_master AS
WITH order_revenue AS (
    SELECT order_id, SUM(price) AS revenue, SUM(freight_value) AS freight, COUNT(*) AS items
    FROM order_items
    GROUP BY order_id
),
latest_review AS (
    SELECT order_id, review_score
    FROM (SELECT order_id, review_score,
                 ROW_NUMBER() OVER (PARTITION BY order_id
                                    ORDER BY review_answer_timestamp DESC) AS rn
          FROM order_reviews) x
    WHERE rn = 1
)
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_purchase_timestamp,
       DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
       r.revenue, r.freight, r.items,
       DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0 END AS is_late,
       lr.review_score
FROM orders o
JOIN customers c      ON c.customer_id = o.customer_id
JOIN order_revenue r  ON r.order_id = o.order_id
LEFT JOIN latest_review lr ON lr.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';

-- ------------------------------------------------------------
-- 2. vw_monthly_kpis: one row per month
--    returning_order_pct only sees orders inside the window, so it undercounts
--    returning customers, especially in the first months.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_kpis AS
WITH seq AS (
    SELECT m.*,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY order_purchase_timestamp, order_id) AS order_seq
    FROM vw_orders_master m
)
SELECT order_month,
       COUNT(*)                                AS orders,
       ROUND(SUM(revenue), 2)                  AS revenue,
       ROUND(SUM(revenue) / COUNT(*), 2)       AS avg_order_value,
       ROUND(100 * AVG(order_seq > 1), 2)      AS returning_order_pct,
       ROUND(100 * (1 - AVG(is_late)), 2)      AS on_time_pct,
       ROUND(AVG(review_score), 2)             AS avg_review_score
FROM seq
GROUP BY order_month;

-- ------------------------------------------------------------
-- 3. vw_customer_summary: one row per real customer (customer_unique_id)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT customer_unique_id,
       MIN(order_purchase_timestamp) AS first_order_date,
       MAX(order_purchase_timestamp) AS last_order_date,
       COUNT(*)                      AS orders,
       ROUND(SUM(revenue), 2)        AS total_spend
FROM vw_orders_master
GROUP BY customer_unique_id;

-- ------------------------------------------------------------
-- Reconciliation checks (run after creating the views)
-- Expected: 96,211 orders | revenue 13,181,027.13 | 93,104 customers | 20 months
-- ------------------------------------------------------------
-- SELECT COUNT(*) AS rows_, COUNT(DISTINCT order_id) AS distinct_orders,
--        ROUND(SUM(revenue), 2) AS total_revenue FROM vw_orders_master;
-- SELECT COUNT(*) AS months, SUM(orders) AS orders, ROUND(SUM(revenue), 2) AS revenue
--   FROM vw_monthly_kpis;
-- SELECT COUNT(*) AS customers, SUM(orders) AS orders, ROUND(SUM(total_spend), 2) AS total_spend
--   FROM vw_customer_summary;
