# Project Notes

Project: E-Commerce Customer Retention \& Delivery Performance Analytics
Dataset: Olist Brazilian E-Commerce (Kaggle)
Tools: MySQL, Python, Power BI, Tableau

\---

## Analysis rules (fill these in during Phase 2)

* Revenue definition (which column, with or without freight):
* Orders included (which order\_status):
* Customer identity column:
* Late delivery definition:
* Analysis date window and why:

## Known data quality issues

* order\_reviews CSV uses Windows line endings (\\r\\n), which caused a harmless load warning. Verified all 99,223 rows have valid creation and answer dates.





## Phase 1: Setup

* Date started:
* Folder structure created: yes / no
* GitHub repo created: yes / no
* Row counts after loading:

|Table|Expected|My count|
|-|-|-|
|customers|99,441|99,441     |
|orders|99,441|99,441 |
|order\_items|112,650|112,650 |
|order\_payments|103,886|103,886 |
|order\_reviews|\~99,224|99,223 |
|products|32,951|32,951 |
|sellers|3,095|3,095 |
|geolocation|\~1,000,163|1,000,163|
|product\_category\_translation|71|71|

* Problems faced and how I fixed them:

\---

## Phase 2: Understanding the data

### What one row represents in each table

* customers:
* orders:
* order\_items:
* order\_payments:
* order\_reviews:
* products:
* sellers:
* geolocation:
* product\_category\_translation:

### Q1: customer\_id vs customer\_unique\_id

* Query:
* Result:
* What I concluded (own words):

### Q2: Rows per order in items, payments and reviews

* Query:
* Result:
* Why joining everything at once can duplicate revenue:
* How I will avoid it:

### Q3: Order status

* Query:
* Result:
* Statuses I will exclude and why:

### Q4: Date range and completeness

* Query:
* Result (first date, last date, sparse months):
* My analysis window and why:

### Q5: Missing values

* Query:
* Result:
* What the NULLs mean:

### Q6: Duplicates and keys

* Query:
* Result:
* Notes:

### Q7: Basic business sanity (price, freight, payment types)

* Query:
* Result:
* Notes:

\---

## Decisions log

|Date|Decision|Reason|
|-|-|-|
||||

## Problems and fixes

|Problem|Fix|
|-|-|
|Load failed with “file not found” because the placeholder path was still in the script<br /><br /><br />order\_reviews load showed a warning about a \\r delimiter|<br />Replaced the placeholder with my real path using Find and Replace, then reran the script<br /><br /><br />CSV uses Windows line endings (\\r\\n). Checked that all 99,223 rows have valid creation and answer dates, so the warning is harmless<br />|

## Ideas / to-do

* 

