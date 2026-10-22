# Project Notes

Project: E-Commerce Customer Retention & Delivery Performance Analytics
Dataset: Olist Brazilian E-Commerce (Kaggle)
Tools: MySQL, Python, Power BI, Tableau

---

## Analysis rules (fill these in during Phase 2)
- Revenue definition (which column, with or without freight):
- Orders included (which order_status):
- Customer identity column:
- Late delivery definition:
- Analysis date window and why:

## Known data quality issues
-

---

## Phase 1: Setup
- Date started:
- Folder structure created: yes / no
- GitHub repo created: yes / no
- Row counts after loading:

| Table | Expected | My count |
|---|---|---|
| customers | 99,441 | |
| orders | 99,441 | |
| order_items | 112,650 | |
| order_payments | 103,886 | |
| order_reviews | ~99,224 | |
| products | 32,951 | |
| sellers | 3,095 | |
| geolocation | ~1,000,163 | |
| product_category_translation | 71 | |

- Problems faced and how I fixed them:

---

## Phase 2: Understanding the data

### What one row represents in each table
- customers:
- orders:
- order_items:
- order_payments:
- order_reviews:
- products:
- sellers:
- geolocation:
- product_category_translation:

### Q1: customer_id vs customer_unique_id
- Query:
- Result:
- What I concluded (own words):

### Q2: Rows per order in items, payments and reviews
- Query:
- Result:
- Why joining everything at once can duplicate revenue:
- How I will avoid it:

### Q3: Order status
- Query:
- Result:
- Statuses I will exclude and why:

### Q4: Date range and completeness
- Query:
- Result (first date, last date, sparse months):
- My analysis window and why:

### Q5: Missing values
- Query:
- Result:
- What the NULLs mean:

### Q6: Duplicates and keys
- Query:
- Result:
- Notes:

### Q7: Basic business sanity (price, freight, payment types)
- Query:
- Result:
- Notes:

---

## Decisions log

| Date | Decision | Reason |
|---|---|---|
| | | |

## Problems and fixes

| Problem | Fix |
|---|---|
| | |

## Ideas / to-do
-
