# Project Notes

**Project:** E-Commerce Customer Retention & Delivery Performance Analytics
**Dataset:** Olist Brazilian E-Commerce (Kaggle)
**Tools:** MySQL, Python, Power BI, Tableau

> Items marked **[RUN: ...]** need a number from your own query. Replace them before treating the notes as final.

---

## Progress

|Phase|Status|
|-|-|
|1. Setup and load data|Done|
|2. Understand the data|Done except the data dictionary and the [RUN] items below|
|3. SQL analysis and views|Done|
|4. Python cleaning and EDA|Done|
|5. RFM segmentation|Done|
|6. Cohort retention|Not started|
|7. Hypothesis testing|Not started|
|8. Power BI dashboard|Not started|
|9. Tableau dashboard|Not started|
|10. Report, PPT, final README|Not started|

---

## Analysis rules

* **Orders included:** `order_status = 'delivered'` only. Other statuses (canceled, unavailable, shipped, etc.) are not completed sales.
* **Revenue:** `SUM(price)` from `order_items`, excluding freight. Freight is analysed separately.
* **Customer identity:** `customer_unique_id`, because `customer_id` is generated per order.
* **Late delivery:** `order_delivered_customer_date > order_estimated_delivery_date`. The 8 delivered orders with no delivery date cannot be classified, so they are excluded from late-delivery and delivery-time calculations.
* **Analysis window:** January 2017 to August 2018 (inclusive).

  * Dec 2016 has only 1 order, while Jan 2017 has 800 and grows steadily.
  * Sep 2018 and Oct 2018 have only 16 and 4 orders, and none were delivered.
  * Sparse months would create fake spikes and drops in trends.
* **Join rule:** never join `order_items`, `order_payments` and `order_reviews` to `orders` all at once. Aggregate each to one row per order first.
* **Reviews:** keep one review per order (the latest by `review_answer_timestamp`).

## Known data quality issues

* `order_reviews` CSV uses Windows line endings (`\r\n`), which caused a harmless load warning. All 99,223 rows have valid creation and answer dates.
* `review_id` is not unique (99,223 rows, 98,409 distinct). 547 orders have more than one review.
* 8 delivered orders have no delivery date.
* 644 delivered orders in the analysis window have no review.
* 610 products have no category name (empty strings). They are labelled "unknown" in category analysis.
* 2 categories have no English translation (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`). They are handled with `COALESCE`.
* 3 payments have type `not_defined` and value 0.00. They are excluded from payment-method analysis.
* 383 order items have zero freight.
* Orders without any items: **[RUN: count by order_status using the LEFT JOIN check]**
* The `product_category_translation` CSV has Windows line endings, so `product_category_name_english` carried a hidden `\r`. Found in the Chart 3 labels and fixed with an UPDATE (`sql/05_data_fixes.sql`).

---

## Phase 1: Setup

* **Date started:** 22 Oct 2026
* **Folder structure created:** yes
* **GitHub repo created:** yes

### Row counts after loading

|Table|Expected|My count|
|-|-|-|
|customers|99,441|99,441|
|orders|99,441|99,441|
|order_items|112,650|112,650|
|order_payments|103,886|103,886|
|order_reviews|~99,224|99,223|
|products|32,951|32,951|
|sellers|3,095|3,095|
|geolocation|~1,000,163|1,000,163|
|product_category_translation|71|71|

### Problems faced and how I fixed them

1. Load failed with "file not found" because the placeholder path was still in the script. I replaced it with my real path using Find and Replace, then reran.
2. My edits were in the wrong tab (an unconnected one). Lesson: edit and run in the same connected tab.
3. The reviews load showed a `\r` delimiter warning. Cause: Windows line endings. I verified with a COUNT query that all dates loaded, so no reload was needed.

---

## Phase 2: Understanding the data

### What one row represents in each table

|Table|One row is|
|-|-|
|customers|one `customer_id` (created per order), linked to a `customer_unique_id` (the real person)|
|orders|one order|
|order_items|one item within an order (`order_item_id` = 1, 2, 3...)|
|order_payments|one payment record for an order (`payment_sequential`)|
|order_reviews|one review, usually one per order (but not always)|
|products|one product|
|sellers|one seller|
|geolocation|one lat/lng point; many rows share the same zip prefix|
|product_category_translation|one Portuguese category and its English name|

### Q1: customer_id vs customer_unique_id

* **Query:**

```sql
SELECT COUNT(DISTINCT customer_id) AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS real_customers
FROM customers;
```

* **Result:** customer_ids = 99,441; real_customers = **[RUN: your number]**
* **Conclusion:** `customer_id` changes with every order, so the same person can appear under several IDs. To count real customers, repeat buyers and retention, I must use `customer_unique_id`.

### Q2: Rows per order in items, payments and reviews

* **Query:** grouped counts per `order_id` for each table (see `sql/02_data_exploration.sql`).
* **Result:**

  * Items per order: **[RUN: how many orders have 1, 2, 3+ items]**
  * Payment rows per order: **[RUN: distribution]**
  * Reviews per order: mostly 1; 547 orders have more than one
* **Why joining everything at once duplicates revenue:** if an order has 2 items and 2 payment rows, the join produces 2 x 2 = 4 rows for that order, so its price is counted 4 times instead of 2.
* **Demonstration:** `SUM(price)` from `order_items` alone = **[RUN]**; after joining to `order_payments` = **[RUN: larger number]**.
* **How I avoid it:** aggregate each child table to one row per order (`GROUP BY order_id`) first, then join those results to `orders`.

### Q3: Order status

* **Query:**

```sql
SELECT order_status, COUNT(*) AS orders
FROM orders GROUP BY order_status ORDER BY orders DESC;
```

* **Result:** **[RUN: each status and its count]**. The foundation check found 96,478 delivered orders with items.
* **Statuses excluded and why:** everything except delivered, because they are not completed sales and have missing delivery dates.

### Q4: Date range and completeness

* **Query:** MIN/MAX of `order_purchase_timestamp`, and orders per month using `DATE_FORMAT`.
* **Result:** first order **[RUN]**, last order **[RUN]**. Dec 2016 has 1 order; Jan 2017 has 800; Sep 2018 has 16; Oct 2018 has 4. Orders before Dec 2016: **[RUN]**.
* **My analysis window and why:** Jan 2017 to Aug 2018, because the months outside it have too few orders (see Analysis rules).

### Q5: Missing values

* **Query:** counted NULLs in the approval, carrier and customer delivery date columns; grouped missing delivery dates by `order_status`; counted delivered orders with no delivery date; counted products with no category name.
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

* **Query:** compared `COUNT(*)` with `COUNT(DISTINCT ...)` for `order_id` in orders and `review_id` in order_reviews; counted orders with more than one review; LEFT JOINed products to the translation table.
* **Result:**

  * orders: 99,441 rows and 99,441 distinct `order_id`, so `order_id` is unique
  * order_reviews: 99,223 rows but only 98,409 distinct `review_id`, so `review_id` is not unique (814 rows share a `review_id` with another row)
  * orders with more than one review: 547
  * categories with no translation: 2 (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`)
* **Notes:** `order_id` can be trusted as the key for orders, but `review_id` cannot. I reduce reviews to one per order so the 547 orders with several reviews are not counted more than once. The 2 untranslated categories keep their Portuguese name via `COALESCE`.

### Q7: Basic business sanity (price, freight, payment types)

* **Result:**

|Measure|Min|Max|Average|Other|
|-|-|-|-|-|
|price|0.85|6,735.00|120.65|0 non-positive prices|
|freight_value|0.00|409.68|19.99|383 items with zero freight|

|Payment type|Payments|Value|
|-|-|-|
|credit_card|76,795|12,542,084.19|
|boleto|19,784|2,869,361.27|
|voucher|5,775|379,436.87|
|debit_card|1,529|217,989.79|
|not_defined|3|0.00|

Orders paid with more than one payment type: 2,246.

* **Notes:** price needs no cleaning, but a few very high prices (max 6,735 vs avg 120.65) can skew averages, so I check outliers. Freight is analysed separately. The 3 `not_defined` payments are excluded. Orders with several payment types need care so they are not counted twice. Revenue stays `SUM(price)` from delivered orders, not payment totals.

---

## Phase 3: SQL analysis

Files: `sql/03_analysis.sql` (queries and results summary) and `sql/04_views.sql` (the three views).

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
|vw_orders_master: rows vs distinct orders|96,211 = 96,211|
|vw_orders_master revenue|13,181,027.13|
|vw_monthly_kpis (20 months, 96,211 orders)|13,181,027.13|
|vw_customer_summary (93,104 customers, 96,211 orders)|13,181,027.13|
|Category total (no LIMIT)|13,181,027.13|
|State total (no LIMIT)|13,181,027.13|
|Running total at 2018-08|13,181,027.13|

### Key findings

#### Revenue and growth

* 2017-01 had 750 orders (111,798.36). Feb 2017 grew +109.51% and Mar 2017 +53.36%. This reflects the marketplace ramping up, not steady growth.
* Nov 2017 had 7,289 orders and 987,765.37 revenue (+52.37%), the highest month in the first 11 months of the window.
* Average order value from Jan to Nov 2017 stays between about 124 and 149.
* 2018 months and the highest revenue month overall: **[RUN: check the rest of the monthly query]**

#### Products

|Rank|Category|Revenue|Orders|
|-|-|-|-|
|1|health_beauty|1,229,557.50|8,610|
|2|watches_gifts|1,163,465.91|5,491|
|3|bed_bath_table|1,022,955.77|9,267|
|4|sports_leisure|952,840.40|7,513|
|5|computers_accessories|888,055.59|6,518|
|6|furniture_decor|706,237.17|6,258|
|7|housewares|614,341.62|5,734|
|8|cool_stuff|609,158.00|3,552|
|9|auto|577,838.39|3,802|
|10|garden_tools|469,135.40|3,443|

* watches_gifts earns more than bed_bath_table with 5,491 orders vs 9,267, so it has a much higher revenue per order.
* Top 5 in 2017: bed_bath_table, watches_gifts, health_beauty, sports_leisure, computers_accessories.
* Top 5 in 2018 (Jan to Aug): health_beauty, watches_gifts, bed_bath_table, sports_leisure, computers_accessories. health_beauty rose from #3 to #1 and bed_bath_table fell from #1 to #3. 2018 covers 8 months, so compare ranks, not raw revenue.

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
|credit_card|74,095|12,063,100.59|78.45%|3.50|
|boleto|19,140|2,762,300.80|17.97%|1.00|
|voucher|3,670|342,294.66|2.23%|1.00|
|debit_card|1,483|208,179.39|1.35%|1.00|

* Orders per type add up to more than 96,211 because some orders use more than one payment type.

### Data notes

* `vw_orders_master`: 644 orders have no review; 8 have no delivery date or late flag.
* `returning_order_pct` in `vw_monthly_kpis` undercounts returning customers because it only sees orders inside the window.

---

## Phase 4: Python cleaning and EDA

Files: `notebooks/01_cleaning_eda.ipynb` (analysis), `reports/figures/` (saved charts), `sql/05_data_fixes.sql` (data fix).

### Setup and reconciliation

Loaded `vw_orders_master` from MySQL with SQLAlchemy and PyMySQL. The password is typed into a hidden prompt, so it is never stored in the notebook.

Checks against the SQL results:

|Check|Python|SQL|
|-|-|-|
|Rows and columns|96,211 x 11|96,211 orders|
|Revenue|13,181,027.13|13,181,027.13|
|Duplicate order IDs|0|0|
|Average delivery time|12.5 days|12.5 days|
|Late orders|8.13%|8.13%|
|Review score, on time / late|4.29 / 2.57|4.29 / 2.57|

### Missing values

|Column|Missing|Meaning|
|-|-|-|
|delivery_days|8|Delivered orders with no delivery date|
|is_late|8|Same 8 orders, so they cannot be classified|
|review_score|644|Delivered orders with no review (about 0.7%)|

### Cleaning decisions

* Converted `order_purchase_timestamp` to datetime and revenue and freight to float. `is_late` and `review_score` became nullable integers so missing values stay missing.
* The 8 orders with no delivery date stay missing and are excluded from delivery-time and late-delivery calculations, as in SQL.
* The 644 orders with no review stay missing. They are not filled with 0 or the mean, because that would distort the review analysis.
* Delivery time has a long right tail: median 10 days, 90th percentile 23, 95th 29, 99th 46, maximum 210. 4,247 orders took more than 30 days and 295 took more than 60. I kept them because they are real deliveries and many are exactly the late orders being studied. I report the median alongside the mean.
* Order revenue is skewed (mean 137.00, median 86.50, maximum 13,440), so I use medians where it matters.
* Features added: purchase weekday, purchase hour, delivery-time bucket (0-7, 8-14, 15-21, 22+ days) and revenue per item.

### Data fix: hidden character in category names

* **Problem:** the category labels in Chart 3 showed small boxes and a "Glyph 13 missing" warning, and the category names in the data ended with `\r`.
* **Cause:** the translation CSV uses Windows line endings (`\r\n`), but the load script splits lines on `\n`, so a `\r` stayed attached to `product_category_name_english`. The reviews file had the same line endings, but its last column was a date, so it raised a warning at load time.
* **Fix:** `UPDATE product_category_translation SET product_category_name_english = TRIM(TRAILING CHAR(13) FROM product_category_name_english)`, saved in `sql/05_data_fixes.sql`. A check query now returns 0 rows with a hidden character.
* Revenue and joins were never affected, because the join uses the first column, but dashboards would have shown the hidden character.

### Charts and what they show

|#|Chart|Main finding|
|-|-|-|
|1|Monthly revenue|About 112K in Jan 2017 up to a peak of about 988K in Nov 2017, then flat between roughly 0.83M and 0.98M in 2018|
|2|Orders and average order value|Orders rose from 750 to 7,289; average order value stayed between about 124 and 149, so growth came from volume|
|3|Top 10 categories|health_beauty, watches_gifts and bed_bath_table lead; watches_gifts has a much higher revenue per order|
|4|Revenue by state|SP is 38.4% of revenue; SP, RJ and MG together are 63.4%|
|5|Orders by weekday and hour|Orders peak early in the week and are lowest on Saturday; activity is lowest between 3 and 5 am and high from about 10 am to 10 pm|
|6|Delivery time|Median 10 days, mean 12.5, long right tail (axis limited to 60 days for readability)|
|7|Late % by state|AL 24.0%, MA 19.6%, PI 16.0% are worst; RJ is 13.5% across 12,310 orders; SP is 5.9%|
|8|Review scores|59.2% of reviews are 5 stars; late orders average 2.57 against 4.29 for on-time orders|
|9|Orders per customer|97.0% of customers ordered once (log scale used)|
|10|Payment types|Credit card 78.45%, boleto 17.97% of payment value|
|11|Review score by delivery time|4.41 (0-7 days), 4.30 (8-14), 4.12 (15-21), 3.05 (22+)|

### Key insights

* About 97% of customers (90,315 of 93,104) ordered only once, so growth depends on acquiring new customers, not on retention.
* Late delivery is linked to much lower satisfaction (2.57 vs 4.29). Scores stay above 4.1 up to 21 days and fall to 3.05 beyond that, which affects about 12% of reviewed orders (11,354 of 95,559).
* Delivery performance is uneven: the highest late rates are in AL, MA and PI, and RJ matters most by volume.
* Revenue is concentrated in the south-east (SP, RJ and MG: 63.4%).
* Growth came from order volume and flattened after Nov 2017.
* Credit card dominates payments (78.45% of value).

### Limitations

* The late and review findings show association, not proven cause. Phase 7 tests the difference formally.
* Customers who bought late in the window had little time to return, so the 3% repeat rate may be slightly understated.
* Chart 8 counts only orders that have a review (7,658 late, 87,901 on time), so those counts are lower than the SQL counts. The averages match.
* Payment value includes freight, so it is not item revenue.

---

## Phase 5: RFM segmentation

Files: `notebooks/02_rfm_segmentation.ipynb`, `reports/figures/12_rfm_segments.png` and `13_rfm_avg_spend.png`.

### Setup and reconciliation

Loaded `vw_customer_summary` from MySQL. Checks: 93,104 customers, 96,211 orders and revenue 13,181,027.13, all matching the SQL reference totals.

### Design decisions

* **Snapshot date:** 2018-08-30, the day after the last order. Recency is the days between a customer's last order and this date.
* **Recency (R) and Monetary (M):** quintile scores from 1 to 5, using `rank(method="first")` before `qcut` so ties are split evenly (about 18,620 customers per score).
* **Frequency (F):** fixed rules, not quintiles: 1 order = 1, 2 orders = 2, 3 or more = 3. About 97% of customers ordered once, so quintiles would put almost everyone in one group. Result: F=1: 90,315, F=2: 2,562, F=3: 227.
* R = 5 means the last order was within about 92 days of the snapshot; R = 1 means about 381 days or more. "Lapsed" means R of 1 to 3 (177+ days).
* Spend is skewed (mean 141.57, median 89.70, max 13,440), so quintiles are used instead of raw values.
* One-time buyers are split by recency and spend, because those are the only measures that vary among them.

### Segment results

|Segment|Rule|Customers|% customers|Revenue|% revenue|Avg spend|
|-|-|-|-|-|-|-|
|Lapsed High-Value|1 order, R 1-3, M 4-5|20,674|22.2|5,529,702.29|42.0|267.47|
|New High-Value|1 order, R 4-5, M 4-5|14,443|15.5|3,857,426.55|29.3|267.08|
|Lapsed Low-Value|1 order, R 1-3, M 1-3|33,596|36.1|1,869,281.13|14.2|55.64|
|Recent One-Timers|1 order, R 4-5, M 1-3|21,602|23.2|1,199,262.12|9.1|55.52|
|Loyal Repeat|2+ orders, R 3-5|1,798|1.9|478,126.48|3.6|265.92|
|At-Risk Repeat|2+ orders, R 1-2|991|1.1|247,228.56|1.9|249.47|
|**Total**||**93,104**|**100**|**13,181,027.13**|**100**||

Checks: repeat segments total 2,789 (matches SQL); one-time segments total 90,315; no customer is unassigned.

### Key insights

* High spenders carry the revenue: New High-Value and Lapsed High-Value are 37.7% of customers but hold 71.3% of revenue.
* Lapsed High-Value is the largest revenue segment (42.0% of revenue from 22.2% of customers) and has the highest average spend (267.47).
* The Lapsed segments hold 58.3% of customers (54,270) and 56.2% of revenue.
* Repeat customers are rare: 2,789 of 93,104 (3.0%), holding 5.5% of revenue. Their average spend (249 to 266) is about the same as high-value one-time buyers.
* Spend level separates segments more than recency does: about 267 in high-value segments against about 55 in low-value ones.

### Limitations

* Recency is measured inside a 20-month window. "Lapsed" means no order in about 6 months or more, not confirmed churn.
* Frequency is almost constant (97% ordered once), so the segmentation depends mostly on recency and spend.
* The cut-offs (R 4-5 as recent, M 4-5 as high-value) are a design choice.

### Outputs

* Table `rfm_segments` in `olist_db` (93,104 rows, for Power BI in Phase 8).
* `data/processed/rfm_segments.csv` and `rfm_segment_summary.csv` (not tracked by Git, read locally by Tableau in Phase 9).

---

## Decisions log

|Date|Decision|Reason|
|-|-|-|
|28 Oct|Use `customer_unique_id` as the customer key|`customer_id` is created per order|
|28 Oct|Revenue from delivered orders only|Other statuses are not completed sales|
|28 Oct|Revenue = `SUM(price)`, freight excluded|Freight is a pass-through cost, analysed separately|
|28 Oct|Aggregate child tables before joining|Avoids duplicated revenue|
|29 Oct|Analysis window Jan 2017 to Aug 2018|Dec 2016 has 1 order; Sep and Oct 2018 have 16 and 4 with none delivered|
|29 Oct|Keep the latest review per order|547 orders have more than one review|
|29 Oct|Exclude 8 delivered orders with no delivery date from delivery metrics|Cannot be classified as late or on time|
|29 Oct|Show late % only for states with 100+ orders|Avoids small states topping the list on a handful of orders|
|29 Oct|Reference revenue = 13,181,027.13|Every view and query reconciles to it|
|1 Nov|Keep long deliveries (up to 210 days) in the data|They are real orders, and many are the late orders being studied; use the median alongside the mean|
|1 Nov|Leave the 644 missing review scores as missing|Filling with 0 or the mean would distort the review analysis|
|1 Nov|Show late % only for states with 100+ orders in Chart 7|Avoids small states topping the list on a handful of orders|
|2 Nov|Snapshot date 2018-08-30 for RFM|The day after the last order in the window|
|2 Nov|Frequency scored with fixed rules (1, 2, 3+), not quintiles|97% of customers ordered once, so quintiles fail|
|2 Nov|Split one-time buyers by recency and spend|Those are the only measures that vary among them|

## Problems and fixes

|Problem|Fix|
|-|-|
|Load failed with "file not found" because the placeholder path was still in the script|Replaced the placeholder with my real path using Find and Replace, then reran the script|
|`order_reviews` load showed a warning about a `\r` delimiter|CSV uses Windows line endings. Checked that all 99,223 rows have valid dates, so the warning is harmless|
|Chart 3 labels showed boxes and a "Glyph 13 missing" warning|The translation CSV has Windows line endings, so category names ended with `\r`. Fixed with an UPDATE and a check query in `05_data_fixes.sql`|
|Notebook 02 raised PermissionError on `../reports/figures`|The notebook was created in `C:\Users\HP`, so the relative path pointed outside the project. Used absolute paths (PROJECT, FIG_DIR, PROC_DIR) and moved the notebook into the repo's notebooks folder|

## Ideas / to-do

* Write `reports/data_dictionary.md`
