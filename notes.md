# Project Notes

**Project:** E-Commerce Customer Retention \& Delivery Performance Analytics
**Dataset:** Olist Brazilian E-Commerce (Kaggle)
**Tools:** MySQL, Python, Power BI, Tableau

> Items marked \\\*\\\*\\\[RUN: ...]\\\*\\\* need a number from your own query. Replace them before treating the notes as final.

\---

## Progress

|Phase|Status|
|-|-|
|1. Setup and load data|Done|
|2. Understand the data|Done except the data dictionary and the \[RUN] items below|
|3. SQL analysis and views|Done|
|4. Python cleaning and EDA|Not started|
|5. RFM segmentation|Not started|
|6. Cohort retention|Not started|
|7. Hypothesis testing|Not started|
|8. Power BI dashboard|Not started|
|9. Tableau dashboard|Not started|
|10. Report, PPT, final README|Not started|

\---

## Analysis rules

* **Orders included:** `order\\\_status = 'delivered'` only. Other statuses (canceled, unavailable, shipped, etc.) are not completed sales.
* **Revenue:** `SUM(price)` from `order\\\_items`, excluding freight. Freight is analysed separately.
* **Customer identity:** `customer\\\_unique\\\_id`, because `customer\\\_id` is generated per order.
* **Late delivery:** `order\\\_delivered\\\_customer\\\_date > order\\\_estimated\\\_delivery\\\_date`. The 8 delivered orders with no delivery date cannot be classified, so they are excluded from late-delivery and delivery-time calculations.
* **Analysis window:** January 2017 to August 2018 (inclusive).

  * Dec 2016 has only 1 order, while Jan 2017 has 800 and grows steadily.
  * Sep 2018 and Oct 2018 have only 16 and 4 orders, and none were delivered.
  * Sparse months would create fake spikes and drops in trends.
* **Join rule:** never join `order\\\_items`, `order\\\_payments` and `order\\\_reviews` to `orders` all at once. Aggregate each to one row per order first.
* **Reviews:** keep one review per order (the latest by `review\\\_answer\\\_timestamp`).

## Known data quality issues

* `order\\\_reviews` CSV uses Windows line endings (`\\\\r\\\\n`), which caused a harmless load warning. All 99,223 rows have valid creation and answer dates.
* `review\\\_id` is not unique (99,223 rows, 98,409 distinct). 547 orders have more than one review.
* 8 delivered orders have no delivery date.
* 644 delivered orders in the analysis window have no review.
* 610 products have no category name (empty strings). They are labelled "unknown" in category analysis.
* 2 categories have no English translation (`pc\\\_gamer`, `portateis\\\_cozinha\\\_e\\\_preparadores\\\_de\\\_alimentos`). They are handled with `COALESCE`.
* 3 payments have type `not\\\_defined` and value 0.00. They are excluded from payment-method analysis.
* 383 order items have zero freight.
* Orders without any items: **\[RUN: count by order\_status using the LEFT JOIN check]**

\---

## Phase 1: Setup

* **Date started:** 22 Oct 2026
* **Folder structure created:** yes
* **GitHub repo created:** yes

### Row counts after loading

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

### Problems faced and how I fixed them

1. Load failed with "file not found" because the placeholder path was still in the script. I replaced it with my real path using Find and Replace, then reran.
2. My edits were in the wrong tab (an unconnected one). Lesson: edit and run in the same connected tab.
3. The reviews load showed a `\\\\r` delimiter warning. Cause: Windows line endings. I verified with a COUNT query that all dates loaded, so no reload was needed.

\---

## Phase 2: Understanding the data

### What one row represents in each table

|Table|One row is|
|-|-|
|customers|one `customer\\\_id` (created per order), linked to a `customer\\\_unique\\\_id` (the real person)|
|orders|one order|
|order\_items|one item within an order (`order\\\_item\\\_id` = 1, 2, 3...)|
|order\_payments|one payment record for an order (`payment\\\_sequential`)|
|order\_reviews|one review, usually one per order (but not always)|
|products|one product|
|sellers|one seller|
|geolocation|one lat/lng point; many rows share the same zip prefix|
|product\_category\_translation|one Portuguese category and its English name|

### Q1: customer\_id vs customer\_unique\_id

* **Query:**

```sql
  SELECT COUNT(DISTINCT customer\\\_id) AS customer\\\_ids,
         COUNT(DISTINCT customer\\\_unique\\\_id) AS real\\\_customers
  FROM customers;
  ```

* **Result:** customer\_ids = 99,441; real\_customers = **\[RUN: your number]**
* **Conclusion:** `customer\\\_id` changes with every order, so the same person can appear under several IDs. To count real customers, repeat buyers and retention, I must use `customer\\\_unique\\\_id`.

### Q2: Rows per order in items, payments and reviews

* **Query:** grouped counts per `order\\\_id` for each table (see `sql/02\\\_data\\\_exploration.sql`).
* **Result:**

  * Items per order: **\[RUN: how many orders have 1, 2, 3+ items]**
  * Payment rows per order: **\[RUN: distribution]**
  * Reviews per order: mostly 1; 547 orders have more than one
* **Why joining everything at once duplicates revenue:** if an order has 2 items and 2 payment rows, the join produces 2 x 2 = 4 rows for that order, so its price is counted 4 times instead of 2.
* **Demonstration:** `SUM(price)` from `order\\\_items` alone = **\[RUN]**; after joining to `order\\\_payments` = **\[RUN: larger number]**.
* **How I avoid it:** aggregate each child table to one row per order (`GROUP BY order\\\_id`) first, then join those results to `orders`.

### Q3: Order status

* **Query:**

```sql
  SELECT order\\\_status, COUNT(\\\*) AS orders
  FROM orders GROUP BY order\\\_status ORDER BY orders DESC;
  ```

* **Result:** **\[RUN: each status and its count]**. The foundation check found 96,478 delivered orders with items.
* **Statuses excluded and why:** everything except delivered, because they are not completed sales and have missing delivery dates.

### Q4: Date range and completeness

* **Query:** MIN/MAX of `order\\\_purchase\\\_timestamp`, and orders per month using `DATE\\\_FORMAT`.
* **Result:** first order **\[RUN]**, last order **\[RUN]**. Dec 2016 has 1 order; Jan 2017 has 800; Sep 2018 has 16; Oct 2018 has 4. Orders before Dec 2016: **\[RUN]**.
* **My analysis window and why:** Jan 2017 to Aug 2018, because the months outside it have too few orders (see Analysis rules).

### Q5: Missing values

* **Query:** counted NULLs in the approval, carrier and customer delivery date columns; grouped missing delivery dates by `order\\\_status`; counted delivered orders with no delivery date; counted products with no category name.
* **Result:**

|Check|Count|
|-|-|
|Total orders|99,441|
|Missing approval date|160|
|Missing carrier date|1,783|
|Missing customer delivery date|2,965|
|Delivered orders with no delivery date|8|
|Products with no category name|610 (about 2% of 32,951)|

Missing delivery date by status: shipped 1,107, canceled 619, unavailable 609, invoiced 314, processing 301, delivered 8, created 5, approved 2.

* **What the NULLs mean:** 2,957 of the 2,965 missing delivery dates belong to orders that were never delivered, which is expected. The remaining 8 are marked delivered but have no delivery date, which is a data quality issue, so I exclude them from delivery-time and late-delivery calculations. The 610 products with no category are labelled "unknown" so their sales are still counted.

### Q6: Duplicates and keys

* **Query:** compared `COUNT(\\\*)` with `COUNT(DISTINCT ...)` for `order\\\_id` in orders and `review\\\_id` in order\_reviews; counted orders with more than one review; LEFT JOINed products to the translation table.
* **Result:**

  * orders: 99,441 rows and 99,441 distinct `order\\\_id`, so `order\\\_id` is unique
  * order\_reviews: 99,223 rows but only 98,409 distinct `review\\\_id`, so `review\\\_id` is not unique (814 rows share a `review\\\_id` with another row)
  * orders with more than one review: 547
  * categories with no translation: 2 (`pc\\\_gamer`, `portateis\\\_cozinha\\\_e\\\_preparadores\\\_de\\\_alimentos`)
* **Notes:** `order\\\_id` can be trusted as the key for orders, but `review\\\_id` cannot. I reduce reviews to one per order so the 547 orders with several reviews are not counted more than once. The 2 untranslated categories keep their Portuguese name via `COALESCE`.

### Q7: Basic business sanity (price, freight, payment types)

* **Result:**

|Measure|Min|Max|Average|Other|
|-|-|-|-|-|
|price|0.85|6,735.00|120.65|0 non-positive prices|
|freight\_value|0.00|409.68|19.99|383 items with zero freight|

|Payment type|Payments|Value|
|-|-|-|
|credit\_card|76,795|12,542,084.19|
|boleto|19,784|2,869,361.27|
|voucher|5,775|379,436.87|
|debit\_card|1,529|217,989.79|
|not\_defined|3|0.00|

Orders paid with more than one payment type: 2,246.

* **Notes:** price needs no cleaning, but a few very high prices (max 6,735 vs avg 120.65) can skew averages, so I check outliers. Freight is analysed separately. The 3 `not\\\_defined` payments are excluded. Orders with several payment types need care so they are not counted twice. Revenue stays `SUM(price)` from delivered orders, not payment totals.

\---

## Phase 3: SQL analysis

Files: `sql/03\\\_analysis.sql` (queries and results summary) and `sql/04\\\_views.sql` (the three views).

### Reference numbers

|Measure|Value|
|-|-|
|Window revenue (Jan 2017 to Aug 2018, delivered, freight excluded)|13,181,027.13|
|Window orders|96,211|
|Customers in window|93,104|
|All months, all delivered orders (revenue / orders)|13,221,498.11 / 96,478|
|Months in window|20|
|Categories|74 (71 translated + 2 untranslated + unknown)|
|States|27|
|Items without a product|0|

### Reconciliation checks (all equal 13,181,027.13)

|Check|Result|
|-|-|
|CTE method vs direct method (all months)|Match: 13,221,498.11|
|vw\_orders\_master: rows vs distinct orders|96,211 = 96,211|
|vw\_orders\_master revenue|13,181,027.13|
|vw\_monthly\_kpis (20 months, 96,211 orders)|13,181,027.13|
|vw\_customer\_summary (93,104 customers, 96,211 orders)|13,181,027.13|
|Category total (no LIMIT)|13,181,027.13|
|State total (no LIMIT)|13,181,027.13|
|Running total at 2018-08|13,181,027.13|

### Key findings

#### Revenue and growth

* 2017-01 had 750 orders (111,798.36). Feb 2017 grew +109.51% and Mar 2017 +53.36%. This reflects the marketplace ramping up, not steady growth.
* Nov 2017 had 7,289 orders and 987,765.37 revenue (+52.37%), the highest month in the first 11 months of the window.
* Average order value from Jan to Nov 2017 stays between about 124 and 149.
* 2018 months and the highest revenue month overall: **\[RUN: check the rest of the monthly query]**

#### Products

|Rank|Category|Revenue|Orders|
|-|-|-|-|
|1|health\_beauty|1,229,557.50|8,610|
|2|watches\_gifts|1,163,465.91|5,491|
|3|bed\_bath\_table|1,022,955.77|9,267|
|4|sports\_leisure|952,840.40|7,513|
|5|computers\_accessories|888,055.59|6,518|
|6|furniture\_decor|706,237.17|6,258|
|7|housewares|614,341.62|5,734|
|8|cool\_stuff|609,158.00|3,552|
|9|auto|577,838.39|3,802|
|10|garden\_tools|469,135.40|3,443|

* watches\_gifts earns more than bed\_bath\_table with 5,491 orders vs 9,267, so it has a much higher revenue per order.
* Top 5 in 2017: bed\_bath\_table, watches\_gifts, health\_beauty, sports\_leisure, computers\_accessories.
* Top 5 in 2018 (Jan to Aug): health\_beauty, watches\_gifts, bed\_bath\_table, sports\_leisure, computers\_accessories. health\_beauty rose from #3 to #1 and bed\_bath\_table fell from #1 to #3. 2018 covers 8 months, so compare ranks, not raw revenue.

#### Sellers (top 10 by revenue, IDs shortened)

|Seller|Revenue|Orders|Avg review|
|-|-|-|-|
|4869f7a5|226,987.93|1,124|4.15|
|53243585|217,940.44|348|4.19|
|4a3ca931|196,882.12|1,772|3.85|
|fa1c13f2|190,917.14|578|4.37|
|7c67e144|186,570.05|973|3.50|
|7e93a43e|164,582.49|318|4.36|
|da8622b1|159,816.87|1,311|4.18|
|7a67c85e|139,658.69|1,145|4.28|
|1025f0e2|138,208.56|910|4.01|
|955fee92|131,836.71|1,261|4.20|

#### Customers

* 2,789 of 93,104 customers (3.00%) ordered more than once, so about 97% bought only once.
* Caution: customers who bought late in the window have had little time to return.

|Orders per customer|Customers|
|-|-|
|1|90,315|
|2|2,562|
|3|180|
|4|28|
|5|9|
|6|5|
|7|3|
|9|1|
|15|1|

#### Top 10 states by revenue

|State|Revenue|Orders|Customers|
|-|-|-|-|
|SP|5,055,587.13|40,406|39,065|
|RJ|1,751,433.85|12,310|11,879|
|MG|1,548,206.88|11,319|10,969|
|RS|726,373.92|5,328|5,151|
|PR|664,048.00|4,903|4,750|
|SC|504,774.07|3,537|3,441|
|BA|493,339.26|3,253|3,155|
|DF|295,454.64|2,074|2,013|
|GO|281,932.21|1,950|1,889|
|ES|267,783.66|1,992|1,925|

* SP is about 38.4% of revenue; SP + RJ + MG together are about 63.4%.

#### Delivery

* Average delivery time is 12.5 days and 8.13% of orders are late (7,822 late, 88,381 on time, 8 not classifiable).
* States with 100 or more orders and the highest late rates:

|State|Orders|Avg delivery days|Late %|
|-|-|-|-|
|AL|396|24.5|23.99|
|MA|713|21.5|19.64|
|PI|475|19.4|16.00|
|CE|1,273|21.2|15.40|
|SE|332|21.4|15.36|
|BA|3,253|19.3|14.05|
|RJ|12,310|15.2|13.52|
|SP|40,406|8.7|5.90|

* RJ matters most by volume: 13.52% late across 12,310 orders. SP is fast (8.7 days) and 5.90% late.

|Delivery status|Orders|Avg review score|
|-|-|-|
|On time|88,381|4.29|
|Late|7,822|2.57|

* Late orders score about 1.7 points lower. This is an association, which Phase 7 tests formally.

#### Payments (payment value includes freight, so it differs from item revenue)

|Payment type|Orders|Payment value|Share|Avg installments|
|-|-|-|-|-|
|credit\_card|74,095|12,063,100.59|78.45%|3.50|
|boleto|19,140|2,762,300.80|17.97%|1.00|
|voucher|3,670|342,294.66|2.23%|1.00|
|debit\_card|1,483|208,179.39|1.35%|1.00|

* Orders per type add up to more than 96,211 because some orders use more than one payment type.

### Data notes

* `vw\\\_orders\\\_master`: 644 orders have no review; 8 have no delivery date or late flag.
* `returning\\\_order\\\_pct` in `vw\\\_monthly\\\_kpis` undercounts returning customers because it only sees orders inside the window.

\---

## Decisions log

|Date|Decision|Reason|
|-|-|-|
|28 Oct|Use `customer\\\_unique\\\_id` as the customer key|`customer\\\_id` is created per order|
|28 Oct|Revenue from delivered orders only|Other statuses are not completed sales|
|28 Oct|Revenue = `SUM(price)`, freight excluded|Freight is a pass-through cost, analysed separately|
|28 Oct|Aggregate child tables before joining|Avoids duplicated revenue|
|29 Oct|Analysis window Jan 2017 to Aug 2018|Dec 2016 has 1 order; Sep and Oct 2018 have 16 and 4 with none delivered|
|29 Oct|Keep the latest review per order|547 orders have more than one review|
|29 Oct|Exclude 8 delivered orders with no delivery date from delivery metrics|Cannot be classified as late or on time|
|29 Oct|Show late % only for states with 100+ orders|Avoids small states topping the list on a handful of orders|
|29 Oct|Reference revenue = 13,181,027.13|Every view and query reconciles to it|

## Problems and fixes

|Problem|Fix|
|-|-|
|Load failed with "file not found" because the placeholder path was still in the script|Replaced the placeholder with my real path using Find and Replace, then reran the script|
|`order\\\_reviews` load showed a warning about a `\\\\r` delimiter|CSV uses Windows line endings. Checked that all 99,223 rows have valid dates, so the warning is harmless|

## Ideas / to-do

* Phase 4: handle the 644 missing review scores and the 8 missing delivery values as NaN, not zero
* Check whether late delivery is concentrated in certain states (RJ, BA and the north-east look worst)
* Compare review score by delivery delay bucket (0 to 3 days, 4 to 7 days, 8+ days)
* Decide how to handle one-time buyers in RFM frequency scoring (97% of customers ordered once)
* Write `reports/data\\\_dictionary.md`



