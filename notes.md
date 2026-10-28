# Project Notes

Project: E-Commerce Customer Retention \& Delivery Performance Analytics
Dataset: Olist Brazilian E-Commerce (Kaggle)
Tools: MySQL, Python, Power BI, Tableau

\---

## Analysis rules

* Orders included: order\_status = 'delivered' only. Other statuses (canceled, unavailable, shipped, etc.) are not completed sales.
* Revenue: SUM(price) from order\_items, excluding freight. Freight is analysed separately.
* Customer identity: customer\_unique\_id, because customer\_id is generated per order.
* Late delivery: order\_delivered\_customer\_date > order\_estimated\_delivery\_date.
* Analysis window: January 2017 to August 2018. Months outside this range have very few orders and would create fake spikes or drops.
* Join rule: never join order\_items, order\_payments and order\_reviews to orders all at once. Aggregate each to one row per order first.



## Known data quality issues

* order\_reviews CSV uses Windows line endings (\\r\\n), which caused a harmless load warning. Verified all 99,223 rows have valid creation and answer dates.
* review\_id is not unique, and some orders have more than one review. Reduce to one review per order before analysing scores.
* A few delivered orders have no delivery date (count: ≈ \[your number]).
* ≈ \[your number] products have no category name (stored as empty strings).
* Some categories are missing from the translation table (list: \[your result]). Handle with COALESCE later.
* Orders without any items exist (≈ \[your number]); mostly canceled or unavailable.



## Phase 1: Setup

* Date started:22 Oct 2026
* Folder structure created: yes 
* GitHub repo created: yes
* Row counts after loading:

|Table|Expected|My count|
|-|-|-|
|customers|99,441|99,441|
|orders|99,441|99,441|
|order\_items|112,650|112,650|
|order\_payments|103,886|103,886|
|order\_reviews|\~99,224|99,223|
|products|32,951|32,951|
|sellers|3,095|3,095|
|geolocation|\~1,000,163|1,000,163|
|product\_category\_translation|71|71|

* Problems faced and how I fixed them:



1. Load failed with "file not found" because the placeholder path was still in the script. Replaced it with my real path using Find and Replace, then reran.
2. Found my edits in the wrong tab (an unconnected one). Lesson: edit and run in the same connected tab.
3. reviews load showed a "\\r delimiter" warning. Cause: Windows line endings. Verified with a COUNT query that all dates loaded, so no reload was needed.

\---

## Phase 2: Understanding the data

### What one row represents in each table

* customers:one customer\_id (created per order), linked to a customer\_unique\_id (the real person)
* orders:one order
* order\_items:one item within an order(order\_item\_id=1,2,3...)
* order\_payments:one payment record for an order(payment sequential)
* order\_reviews:one review,usually one per order(but not always)
* products:one product
* sellers:one sellers
* geolocation:one lat/lonbt point:many rows share the same zip prefix
* product\_category\_translation:one portugese category and its English name.

### Q1: customer\_id vs customer\_unique\_id

* Query:SELECT COUNT(DISTINCT customer\_id) AS customer\_ids,

&#x20;      COUNT(DISTINCT customer\_unique\_id) AS real\_customers

&#x20;      FROM customers;

* Result:customer\_ids = 99,441; 

&#x20;         real\_customers ≈ 96,096

* What I concluded (own words):customer\_id changes with every order, so the same person can appear under several IDs. To count real customers, repeat buyers and retention, I must use customer\_unique\_id.

### Q2: Rows per order in items, payments and reviews

* Query:(grouped counts per order\_id for each table; see sql/02\_data\_exploration.sql)



* Result:
1. Items per order: mostly 1, with about 10% of orders having 2 or more
2. payment rows per order: mostly 1, some orders have several
3. reviews per order: mostly 1, a small number have 2 or more



* Why joining everything at once can duplicate revenue:if an order has 2 items and 2 payment rows, the join produces 2 x 2 = 4 rows for that order, so its price is counted 4 times instead of 2.



* Demonstration: SUM(price) from order\_items alone = \[your number]; after joining to order\_payments = \[your larger number].



* How I will avoid it:aggregate each child table to one row per order (GROUP BY order\_id) first, then join those results to orders.

### Q3: Order status

* Query:

&#x20;  SELECT order\_status, COUNT(\*) AS orders

&#x20;  FROM orders GROUP BY order\_status ORDER BY orders DESC;



* Result:delivered ≈ 96,478 (about 97%); the rest are shipped, canceled, unavailable, invoiced, processing, created, approved.



* Statuses I will exclude and why:everything except delivered, because they are not completed sales and have missing delivery dates.
* 

### Q4: Date range and completeness

* Query:MIN/MAX of order\_purchase\_timestamp, and orders per month using DATE\_FORMAT.



* Result (first date, last date, sparse months):first order ≈ Sep 2016, last order ≈ Oct 2018. 2016 and the last two months of 2018 have very few orders. January 2017 to August 2018 is steady.



* My analysis window and why:Jan 2017 to Aug 2018. Sparse months would produce misleading growth rates.
* 

### Q5: Missing values

* Query:counted NULLs in the approval, carrier and customer delivery date columns of orders;  grouped the missing delivery dates by order\_status; counted delivered orders with no delivery date; counted products with no category name.
* Result:
1. &#x20;- Total orders: 99,441
2. &#x20; - Missing approval date: 160
3. &#x20; - Missing carrier date: 1,783
4. &#x20; - Missing customer delivery date: 2,965
5. &#x20; - Missing delivery date by status: shipped 1,107, canceled 619, unavailable 609,
    invoiced 314, processing 301, delivered 8, created 5, approved 2
6. &#x20; - Delivered orders with no delivery date: 8
7. &#x20; - Products with no category name: 610 (about 2% of 32,951)



* What the NULLs mean:
* 2,957 of the 2,965 missing delivery dates belong to orders that were never delivered (shipped, canceled, unavailable, invoiced, processing, created, approved). That is expected, because those orders have no delivery date yet or ever. The remaining 8 orders are marked delivered but have no delivery date, which is a data quality issue. I will exclude those 8 from delivery-time and late-delivery calculations. The 610 products with no category will be labelled "unknown" in category analysis so their sales are still counted.

### Q6: Duplicates and keys

* Query: compared COUNT(\*) with COUNT(DISTINCT ...) for order\_id in orders and review\_id in order\_reviews; counted orders with more than one review; LEFT JOINed products to the translation table to find categories with no translation.



* Result:  
1. orders: 99,441 rows and 99,441 distinct order\_id, so order\_id is unique
2. order\_reviews: 99,223 rows but only 98,409 distinct review\_id, so review\_id is not  unique(814 rows share a review\_id with another row)
3. orders with more than one review: 547
4. product categories with no translation: 2 (pc\_gamer,portateis\_cozinha\_e\_preparadores\_de\_alimentos)



* Notes:order\_id can be trusted as the key for orders, but review\_id cannot. When analysing review scores I will reduce reviews to one per order (for example the latest by review\_answer\_timestamp), so the 547 orders with several reviews are not counted more than once. The 2 untranslated categories will keep their Portuguese name via COALESCE, so their sales are not lost.

### Q7: Basic business sanity (price, freight, payment types)

* Query:MIN/MAX/AVG of price and freight\_value, count of non-positive prices, payment type counts.



* Result: price ranges from under 1 to ≈ 6,735 (average ≈ 120). Payment types: credit\_card (most), boleto, voucher, debit\_card, and a tiny not\_defined group.
* 
* Notes:Price needs no cleaning, but a few very high prices (max 6,735 vs avg 120.65) can skew averages, so I will check outliers. Freight is analysed separately from price. The 3 not\_defined payments have zero value and will be excluded from payment-method analysis. Orders with several payment types need care so they are not counted twice. Revenue stays SUM(price) from delivered orders, not payment totals.

\---

## Decisions log

|Date|Decision|Reason|
|-|-|-|
|28 Oct|Use customer\_unique\_id as the customer key|customer\_id is created per order|
|28 Oct|Revenue from delivered orders only|Other statuses are not completed sales|
|28 Oct|Revenue= SUM(price),freight excluded|Freight is pass-through cost,analysed separately.|
|28 Oct|Analysis window Jan 2017 to Aug 2018|Other months are too sparse|
|28 Oct|Aggregate child tables before joining.|Avoids duplicated revenue|

## Problems and fixes

|Problem|Fix|
|-|-|
|Load failed with “file not found” because the placeholder path was still in the script<br /><br /><br />order\_reviews load showed a warning about a \\r delimiter|<br />Replaced the placeholder with my real path using Find and Replace, then reran the script<br /><br /><br />CSV uses Windows line endings (\\r\\n). Checked that all 99,223 rows have valid creation and answer dates, so the warning is harmless<br />|

## Ideas / to-do

* Check whether late delivery is concentrated in certain states
* Compare review score by delivery delay bucket (0 to 3 days, 4 to 7 days, 8+ days)
* Decide how to handle one-time buyers in RFM frequency scoring

