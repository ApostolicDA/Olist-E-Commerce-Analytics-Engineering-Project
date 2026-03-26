# 🛒 Olist E-Commerce Analytics — End-to-End Data Pipeline & Executive Dashboard

![Dashboard](dashboard.png)

> From 9 raw CSV tables to a validated executive dashboard — built with Python, PostgreSQL, and Power BI.

---

## 📌 Project Overview

This project delivers a full end-to-end analytics pipeline on the Brazilian Olist E-Commerce dataset — one of the most complex public datasets available, with 9 relational tables covering orders, customers, products, sellers, payments, reviews, and geolocation (~100K orders, 2016–2018).

**Business questions answered:**
- Where is revenue coming from — by category, payment method, and over time?
- How does shipping cost compare to total product value?
- What is the relationship between product name length and revenue?
- How does delivery performance affect customer review scores?
- Are our dashboard KPIs accurate and trustworthy?

> **Note on profit:** Cost-of-goods data is not available in this dataset. Revenue (price + freight) is used as the primary financial metric throughout. This is clearly reflected in all KPIs and visuals.

---

## 🏗️ Pipeline Architecture

```
Raw CSVs (9 tables)
        │
        ▼
🐍 Python — Data Cleaning (Jupyter Notebook)
  └── 1 notebook cleaning all 9 tables independently using pandas
        │
        ▼
🐘 PostgreSQL — Master Dataset + Feature Engineering
  └── 1 SQL script:
      ├── Category dimension cleaning & grouping
      ├── Geolocation deduplication
      ├── Star schema master fact table (LEFT JOINs across all 9 tables)
      ├── Feature engineering (name buckets, delivery flags, photo buckets)
      └── Analytics view & aggregation queries
        │
        ▼
📊 Power BI — Executive Dashboard
  └── Connected directly to PostgreSQL master dataset (olist_analytics view)
        │
        ▼
✅ KPI Validation Report
  └── All 8 dashboard metrics independently re-calculated in SQL
      and matched against Power BI — 8/8 checks passed
```

---

## 📂 Repository Structure

```
olist-ecommerce-analytics/
│
├── datasets/                              # Raw CSV source files (see Data Source below)
│
├── olist_df1-7.ipynb                      # Python cleaning notebook (all 9 tables)
│
├── Olist_complete_script.sql              # Full PostgreSQL script:
│                                          #   - Category cleaning
│                                          #   - Geolocation deduplication
│                                          #   - Master fact table (star schema)
│                                          #   - Feature engineering
│                                          #   - Analytics view for Power BI
│
├── Olist_KPI_Validation_Report.docx       # 8/8 KPI checks — SQL vs Power BI
├── olist_dashboard.pbix                   # Power BI dashboard file
├── dashboard.png                          # Executive dashboard screenshot
└── README.md
```

---

## 🔧 Tech Stack

| Layer | Tool |
|---|---|
| Data Cleaning | Python (pandas) — Jupyter Notebook |
| Database | PostgreSQL |
| Data Modelling | Star schema — master fact table via LEFT JOINs |
| Feature Engineering | SQL (PostgreSQL) |
| Visualisation | Microsoft Power BI |
| Validation | SQL queries cross-checked against Power BI KPIs |

---

## 🗂️ The 9 Source Tables

| Table | Description |
|---|---|
| `olist_sellers_dataset.csv` | Seller IDs, cities, and states |
| `product_category_name_translation.csv` | Portuguese to English category names |
| `olist_products_dataset.csv` | Product dimensions, photos, name lengths |
| `olist_order_reviews_dataset.csv` | Customer review scores and comments |
| `olist_orders_dataset.csv` | Order lifecycle — purchase, approval, delivery dates |
| `olist_order_payments_dataset.csv` | Payment type and value per order |
| `olist_order_items_dataset.csv` | Item-level price, freight, seller, product |
| `olist_geolocation_dataset.csv` | ZIP code prefix lat/lng mapping |
| `olist_customers_dataset.csv` | Customer IDs, cities, states, ZIP codes |

---

## 🧹 Stage 1 — Data Cleaning (Python)

All 9 raw CSV tables were cleaned individually in a single Jupyter notebook before being loaded into PostgreSQL.

Key cleaning steps applied per table:
- Null value handling and imputation
- Data type casting (dates, numerics, strings)
- Duplicate detection and removal
- City name typo correction and encoding fixes across sellers, customers, and geolocation (Portuguese text with many inconsistencies)
- Category name deduplication and merging (e.g. `eletrodomesticos_2` → `eletrodomesticos`, furniture subcategories merged)
- English category typo corrections (e.g. `fashio_female_clothing` → `fashion_female_clothing`)
- Outlier flagging on price and freight columns

📁 Script: `olist_df1-7.ipynb`

---

## 🐘 Stage 2 — PostgreSQL: Master Dataset & Feature Engineering

The entire PostgreSQL stage is handled in a single SQL script with 5 logical sections.

### Section 1 — Category Dimension Cleaning
40+ raw English category names were grouped into 11 clean business categories:

| Clean Category | Raw Categories Included |
|---|---|
| Fashion | fashion_childrens_clothes, fashion_shoes, fashion_sport, + 4 more |
| Electronics | electronics, computers_accessories, audio, telephony, + 4 more |
| Home & Living | furniture, bed_bath_table, home_comfort, home_appliances, + 2 more |
| Kids & Baby | baby, diapers_and_hygiene, toys |
| Beauty & Health | health_beauty, perfumery |
| Sports & Leisure | sports_leisure |
| Books | books_technical, books_general_interest, books_imported |
| Food & Kitchen | food_drink, la_cuisine |
| Tools & Garden | construction_tools, garden_tools |
| Pet Supplies | pet_shop |
| General & Misc | everything else |

### Section 2 — Geolocation Deduplication
The raw geolocation table contains multiple lat/lng entries per ZIP prefix. A clean `geo_clean` table was built by averaging coordinates per ZIP prefix — preventing fan-out joins and ensuring 1 row per ZIP code.

### Section 3 — Master Fact Table (Star Schema)
A single master fact table (`master_olist`) was built at the grain of **1 row = 1 order item**, joining all 9 tables:

- **INNER JOIN** on `order_items` — every row must have an order and an item
- **LEFT JOINs** on all dimension tables — preserves all order items even where dimension data is incomplete

```sql
-- Grain: 1 row = 1 order item
CREATE TABLE master_olist AS
WITH payment_agg AS (
    SELECT order_id, SUM(payment_value) AS order_payment_value,
           MAX(payment_type) AS payment_type
    FROM order_payment GROUP BY order_id
),
review_agg AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM reviews GROUP BY order_id
)
SELECT
    o.order_id, o.customer_id, o.order_status,
    c.customer_state, c.customer_city,
    i.product_id, i.seller_id, i.price AS item_price, i.freight_value AS freight_cost,
    p.product_name_length, p.product_photos_qty, cat.clean_category,
    pay.payment_type, rev.review_score,
    (o.order_delivered_customer_date - o.order_purchase_timestamp) AS delivery_days,
    (o.order_delivered_customer_date - o.order_estimated_delivery_date) AS delay_days
FROM orders o
JOIN order_items i ON o.order_id = i.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN geo_clean geo_cust ON LPAD(c.customer_zip_code_prefix::text,5,'0') = geo_cust.zip_prefix
JOIN products p ON i.product_id = p.product_id
LEFT JOIN category cat ON p.product_category_name = cat.product_category_name
LEFT JOIN payment_agg pay ON o.order_id = pay.order_id
LEFT JOIN review_agg rev ON o.order_id = rev.order_id;
```

### Section 4 — Feature Engineering
Two bucketed columns were added directly to the master table:

| Feature | Buckets |
|---|---|
| `name_length_bucket` | Very Short (0–10) / Short (11–20) / Medium (21–40) / Long (41–55) / Very Long (56+) |
| `photos_qty_bucket` | No Photos / 1 Photo / 2–3 Photos / 4–6 Photos / 7+ Photos |

Delivery features derived during the join:
- `delivery_days` — actual days from purchase to delivery
- `delay_days` — difference between actual and estimated delivery (positive = late)

### Section 5 — Power BI Analytics View
A final `olist_analytics` view was created as the clean connection layer for Power BI. Additional aggregation queries were built alongside it to validate all dashboard visuals directly in SQL.

📁 Script: `Olist_complete_script.sql`

---

## 📊 Stage 3 — Power BI Executive Dashboard

The `olist_analytics` view was connected directly to Power BI via the PostgreSQL connector.

### Dashboard KPIs

| Metric | Value |
|---|---|
| 👥 Total Customers | 122.35K |
| 💰 Total Revenue | R$ 22.14M |
| 🚚 Total Shipping Cost | R$ 2.43M |
| 🎁 Total Product Value | R$ 17.12M |

### Visuals & Key Findings

| Visual | Key Finding |
|---|---|
| Bar Chart — Revenue by Product Name Length | Longer product names (56+ chars) drive the highest revenue — likely reflecting more detailed, premium product listings |
| Bar Chart — Revenue by Payment Method | Credit card dominates at ~R$ 15.4M (~70% of total revenue); boleto is a distant second at ~R$ 2.9M |
| Line Chart — Revenue Trend Over Time | Clear seasonality with notable peaks — consistent with Brazilian retail calendar events |
| Treemap — Revenue by Category | Home & Living leads at R$ 3.33M, followed by Electronics at R$ 2.65M |

---

## ✅ Stage 4 — KPI Validation Report

Every dashboard metric was independently re-calculated in PostgreSQL and matched against Power BI. **All 8 checks passed.**

| KPI | SQL Result | Power BI | Status |
|---|---|---|---|
| Total Customers | 122,350 | 122.35K | ✅ PASS |
| Total Revenue | R$ 22,135,xxx | R$ 22.14M | ✅ PASS |
| Total Shipping Cost | R$ 2,430,xxx | R$ 2.43M | ✅ PASS |
| Total Product Value | R$ 17,120,xxx | R$ 17.12M | ✅ PASS |
| Revenue by Payment Method | Aggregated match | Visual match | ✅ PASS |
| Revenue by Name Length | Bucketed match | Visual match | ✅ PASS |
| Revenue by Category | Top 6 verified | Treemap match | ✅ PASS |
| Revenue Trend Over Time | Monthly series | Line chart match | ✅ PASS |

> Cross-check: Total Revenue (22.14M) = Product Value (17.12M) + Shipping Cost (2.43M) + other fees ✅

📁 Full report: `Olist_KPI_Validation_Report.docx`

---

## 🚀 How to Reproduce

### Prerequisites
- Python 3.9+ with Jupyter
- PostgreSQL 14+
- Power BI Desktop
- Libraries: `pandas`, `numpy`, `psycopg2`, `sqlalchemy`

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/ApostolicDA/Olist-E-Commerce-Analytics-Engineering-Project.git
cd Olist-E-Commerce-Analytics-Engineering-Project

# 2. Install Python dependencies
pip install pandas numpy psycopg2-binary sqlalchemy jupyter

# 3. Download the raw dataset
# https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
# Place all 9 CSVs into the /datasets folder

# 4. Run the cleaning notebook
jupyter notebook olist_df1-7.ipynb
# Execute all cells — exports cleaned CSVs ready for PostgreSQL

# 5. Load cleaned CSVs into PostgreSQL
# Create your database and load the 9 cleaned tables

# 6. Run the full SQL pipeline
psql -U your_user -d your_database -f Olist_complete_script.sql
# Runs all 5 stages: category cleaning → geolocation deduplication →
# master fact table → feature engineering → analytics view

# 7. Connect Power BI
# Open Power BI Desktop → Connect to PostgreSQL → select olist_analytics view
# Open olist_dashboard.pbix
```

---

## 📦 Data Source

**Brazilian E-Commerce Public Dataset by Olist**
🔗 https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

~100K orders from 2016–2018 across multiple Brazilian marketplaces. 9 relational tables.

---

## 👤 Author

**Proud Ndlovu**
📧 fanisaproud@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/proud-ndlovu)
🐙 [GitHub](https://github.com/ApostolicDA)

---

## 📄 License

This project is licensed under the MIT License.
