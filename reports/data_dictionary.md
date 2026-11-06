# Data Dictionary

**Project:** E-Commerce Customer Retention & Delivery Performance Analytics
**Dataset:** Olist Brazilian E-Commerce (Kaggle), loaded into MySQL database `olist_db`

Meanings come from the Kaggle dataset page. Notes come from my own checks (see `notes.md`). "Analysis window" means January 2017 to August 2018, and "delivered orders" means `order_status = 'delivered'`.

Row counts are for the loaded tables. Types are given as general kinds (text, integer, decimal, datetime).

---

## Source tables

### customers

**Grain:** one row per `customer_id`, which is created per order (99,441 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`customer_id`|Key linking an order to a customer record|text (ID)|Created per order, so the same person can have several. Unique in this table (99,441 distinct)|
|`customer_unique_id`|Identifier of the real person|text (ID)|Not unique in this table. Used to count customers, repeat buyers, RFM and retention. See Q1 in `notes.md`|
|`customer_zip_code_prefix`|First digits of the customer's zip code|text/integer|Links to `geolocation`. Not used in the analysis|
|`customer_city`|Customer city|text|Not used in the analysis|
|`customer_state`|Two-letter Brazilian state code|text|27 states. Used for state analysis and the dashboards|

### orders

**Grain:** one row per order (99,441 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`order_id`|Unique order identifier|text (ID)|Unique: 99,441 rows and 99,441 distinct values|
|`customer_id`|Customer record for this order|text (ID)|Links to `customers`|
|`order_status`|Order status (delivered, shipped, canceled, unavailable, invoiced, processing, created, approved)|text|Only `delivered` is analysed. The other statuses are not completed sales|
|`order_purchase_timestamp`|When the order was placed|datetime|Basis for the analysis window and the monthly trends|
|`order_approved_at`|When payment was approved|datetime|160 missing|
|`order_delivered_carrier_date`|When the order was handed to the carrier|datetime|1,783 missing|
|`order_delivered_customer_date`|When the customer received the order|datetime|2,965 missing: 2,957 are orders never delivered, and 8 are marked delivered with no date. Those 8 are excluded from delivery metrics|
|`order_estimated_delivery_date`|Delivery date promised to the customer|datetime|Late means `order_delivered_customer_date` is later than this date|

### order_items

**Grain:** one row per item within an order (112,650 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`order_id`|Order the item belongs to|text (ID)|Repeats for orders with several items|
|`order_item_id`|Sequence number of the item within the order (1, 2, 3...)|integer|Not a global ID|
|`product_id`|Product sold|text (ID)|Links to `products`. No items without a product|
|`seller_id`|Seller who sold the item|text (ID)|Links to `sellers`|
|`shipping_limit_date`|Seller's deadline to hand the item to the carrier|datetime|Not used in the analysis|
|`price`|Item price, without freight|decimal|Range 0.85 to 6,735.00, average 120.65, no non-positive prices. Revenue is `SUM(price)` and excludes freight|
|`freight_value`|Shipping cost for the item|decimal|383 items have zero freight. Analysed separately from revenue|

### order_payments

**Grain:** one row per payment record for an order (103,886 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`order_id`|Order being paid|text (ID)|Repeats when an order has several payment records|
|`payment_sequential`|Sequence number of the payment for the order|integer|Joining this table to `order_items` multiplies rows, so it is aggregated first|
|`payment_type`|Payment method (credit_card, boleto, voucher, debit_card, not_defined)|text|3 payments are `not_defined` with value 0.00 and are excluded. 2,246 orders use more than one payment type|
|`payment_installments`|Number of installments chosen|integer|Credit card average is about 3.5|
|`payment_value`|Amount paid|decimal|Includes freight, so it does not equal item revenue|

### order_reviews

**Grain:** one row per review, usually one per order (99,223 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`review_id`|Review identifier|text (ID)|Not unique: 99,223 rows but 98,409 distinct values|
|`order_id`|Order being reviewed|text (ID)|547 orders have more than one review. The latest per order is kept|
|`review_score`|Customer satisfaction score from 1 to 5|integer|644 delivered orders in the analysis window have no review and stay missing|
|`review_comment_title`|Optional comment title|text|Not used in the analysis|
|`review_comment_message`|Optional comment text|text|Not used in the analysis|
|`review_creation_date`|When the satisfaction survey was sent|datetime|All rows have valid dates|
|`review_answer_timestamp`|When the customer answered|datetime|Used to choose the latest review per order. The file has Windows line endings (`\r\n`), which caused a harmless load warning|

### products

**Grain:** one row per product (32,951 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`product_id`|Unique product identifier|text (ID)|Links to `order_items`|
|`product_category_name`|Category name in Portuguese|text|610 products (about 2%) have no category and are labelled "unknown"|
|`product_name_lenght`|Number of characters in the product name|integer|Spelling comes from the Kaggle source. Check the exact name in your table. Not used|
|`product_description_lenght`|Number of characters in the description|integer|Same spelling note. Not used|
|`product_photos_qty`|Number of product photos|integer|Not used|
|`product_weight_g`|Product weight in grams|integer|Not used|
|`product_length_cm`|Package length in centimetres|integer|Not used|
|`product_height_cm`|Package height in centimetres|integer|Not used|
|`product_width_cm`|Package width in centimetres|integer|Not used|

### sellers

**Grain:** one row per seller (3,095 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`seller_id`|Unique seller identifier|text (ID)|Shortened to the first 8 characters in the notes|
|`seller_zip_code_prefix`|First digits of the seller's zip code|text/integer|Not used in the analysis|
|`seller_city`|Seller city|text|Not used in the analysis|
|`seller_state`|Two-letter state code|text|Not used in the dashboards|

### geolocation

**Grain:** one row per latitude and longitude point (1,000,163 rows). Many rows share the same zip prefix.

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`geolocation_zip_code_prefix`|First digits of the zip code|text/integer|Not unique, so it cannot be used as a key. Table not used in the analysis|
|`geolocation_lat`|Latitude|decimal|Not used|
|`geolocation_lng`|Longitude|decimal|Not used|
|`geolocation_city`|City name|text|Not used|
|`geolocation_state`|State code|text|Not used|

### product_category_translation

**Grain:** one row per Portuguese category and its English name (71 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`product_category_name`|Category name in Portuguese|text|Join key to `products`|
|`product_category_name_english`|Category name in English|text|Carried a hidden `\r` from the Windows line endings. Fixed with an UPDATE (`sql/05_data_fixes.sql`). 2 categories have no translation (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) and keep their Portuguese name through `COALESCE`|

---

## Derived tables and views

### vw_orders_master

**Grain:** one row per delivered order in the analysis window (96,211 rows). Aggregates items and reviews to one row per order before joining, to avoid duplicated revenue.

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`order_id`|Order identifier|text (ID)|Unique in this view|
|`customer_unique_id`|Real customer|text (ID)|Used for customer-level analysis|
|`customer_state`|Customer state|text|27 states|
|`order_purchase_timestamp`|Purchase date and time|datetime|Within January 2017 to August 2018|
|`order_month`|Purchase month as text (yyyy-mm)|text|Sorts in date order|
|`revenue`|Sum of item prices for the order|decimal|Freight excluded. Total 13,181,027.13|
|`freight`|Sum of freight for the order|decimal|Analysed separately|
|`items`|Number of items in the order|integer||
|`delivery_days`|Days from purchase to delivery|integer|Missing for the 8 delivered orders with no delivery date|
|`is_late`|1 if delivered after the estimated date, 0 if not|integer|Missing for the same 8 orders. 8.13% of orders are late|
|`review_score`|Review score for the order (latest review)|integer|Missing for 644 orders with no review|

### vw_customer_summary

**Grain:** one row per real customer, `customer_unique_id` (93,104 rows).

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`customer_unique_id`|Real customer|text (ID)|Unique in this view|
|`first_order_date`|Date of the first order in the window|datetime|Used for cohorts|
|`last_order_date`|Date of the last order in the window|datetime|Used for RFM recency|
|`orders`|Number of orders|integer|2,789 customers (3.0%) have more than one|
|`total_spend`|Total spend across the customer's orders|decimal|Freight excluded. Total 13,181,027.13|

### rfm_segments

**Grain:** one row per real customer (93,104 rows). Created in `notebooks/02_rfm_segmentation.ipynb` and written to MySQL for the dashboard.

|Column|Meaning|Type|Notes|
|-|-|-|-|
|`customer_unique_id`|Real customer|text (ID)|Unique|
|`recency_days`|Days from the last order to the snapshot date (2018-08-30)|integer|Minimum 1, maximum 602|
|`frequency`|Number of orders|integer|Same as `orders`|
|`monetary`|Total spend|decimal|Skewed: mean 141.57, median 89.70|
|`R`|Recency score, 1 to 5|integer|5 means ordered within about 92 days. Quintiles with ties broken by row order|
|`F`|Frequency score, 1 to 3|integer|1 order = 1, 2 orders = 2, 3 or more = 3. Fixed rules, because 97% ordered once|
|`M`|Monetary score, 1 to 5|integer|Quintiles with ties broken by row order|
|`segment`|Customer segment|text|Loyal Repeat, At-Risk Repeat, New High-Value, Recent One-Timers, Lapsed High-Value, Lapsed Low-Value|
