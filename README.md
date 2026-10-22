# E-Commerce Customer Retention & Delivery Performance Analytics

**Tools:** MySQL, Python (Pandas, NumPy, Matplotlib, Seaborn, SciPy), Power BI, Tableau
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, CC BY-NC-SA 4.0)

---

## 1. Business Problem

Olist is a Brazilian marketplace connecting small sellers to customers. Order volume grew from 2016 to 2018, but growth alone does not mean a healthy business. This project investigates:

1. How is revenue trending, and which categories and regions drive it?
2. How many customers come back after their first order, and who are the most valuable customers?
3. Does late delivery hurt customer satisfaction?
4. What should the business do to improve retention and delivery performance?

## 2. Objectives

- Build a clean analytical view from 9 relational tables using SQL
- Measure core KPIs: Revenue, Orders, AOV, Repeat Customer Rate, On-Time Delivery %, Average Review Score
- Segment customers using RFM analysis
- Measure retention using cohort analysis
- Test statistically whether late deliveries lower review scores
- Present findings in Power BI and Tableau dashboards with actionable recommendations

## 3. Dataset Overview

| Table | Description |
|---|---|
| olist_orders_dataset | Order status and timestamps |
| olist_order_items_dataset | Items per order, price, freight, seller |
| olist_order_payments_dataset | Payment type and value |
| olist_order_reviews_dataset | Review score and comments |
| olist_customers_dataset | Customer location and unique ID |
| olist_products_dataset | Product category and dimensions |
| olist_sellers_dataset | Seller location |
| olist_geolocation_dataset | Zip code to lat/lng |
| product_category_name_translation | Portuguese to English category names |

**Note:** `customer_id` is unique per order. Use `customer_unique_id` to identify a real customer across orders.

## 4. Project Structure

```
olist-customer-analytics/
├── data/raw/          # original CSVs (not pushed to GitHub if large)
├── data/processed/    # cleaned files exported from Python/SQL
├── sql/               # all SQL scripts
├── notebooks/         # Jupyter notebooks
├── dashboards/        # .pbix, .twbx and screenshots
├── reports/           # final report and presentation
└── README.md
```

## 5. Methodology

1. **SQL analysis:** database setup, joins, CTEs, window functions for KPIs and business questions
2. **Data cleaning (Python):** missing values, data types, duplicates, master table creation
3. **EDA:** trends, category performance, geography, payments
4. **RFM segmentation:** Recency, Frequency, Monetary scoring
5. **Cohort retention analysis:** monthly cohorts by first purchase
6. **Hypothesis testing:** late vs. on-time delivery and review score
7. **Dashboards:** Power BI (executive KPIs) and Tableau (customer segments)

## 6. Key Findings

> Fill these in with your own calculated numbers after the analysis. Do not publish placeholders.

- Total revenue: **[X]** across **[X]** delivered orders
- Repeat customer rate: **[X]%** (most customers buy only once)
- Late deliveries: **[X]%** of orders, with average review score **[X]** vs. **[Y]** for on-time orders (p-value: **[X]**)
- Top categories by revenue: **[1, 2, 3]**
- Top RFM segment: **[name]**, contributing **[X]%** of revenue
- Month-1 cohort retention: **[X]%**

## 7. Recommendations

> Write after findings. Examples of the form they should take:

1. Improve delivery estimates in states with the highest delay rate: **[states]**
2. Launch a post-purchase re-engagement campaign for first-time buyers within **[X]** days
3. Prioritize retention offers for the **[segment]** RFM group

## 8. Dashboards

- Power BI: `dashboards/olist_powerbi.pbix` (screenshots in `dashboards/`)
- Tableau: `dashboards/olist_tableau.twbx` (or Tableau Public link)

## 9. How to Run

1. Download the dataset from Kaggle and place the CSVs in `data/raw/`
2. Run `sql/01_create_tables_and_load.sql` in MySQL Workbench (edit the file path first)
3. Run the remaining SQL scripts in order
4. Open the notebooks in `notebooks/` in order (01 to 04)

## 10. Limitations

- Data covers 2016 to 2018 only; the dataset is anonymised and no longer updated
- Customer identity relies on `customer_unique_id`; some customers may be missed
- Observational data: findings show association, not proven causation

## 11. Author

**[Your Name]** | [LinkedIn] | [GitHub] | [Email]

*Dataset credit: Olist and André Sionek, via Kaggle.*
