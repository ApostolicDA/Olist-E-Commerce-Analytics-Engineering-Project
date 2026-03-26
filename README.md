# 🛒 Olist E-Commerce Analytics — End-to-End Data Pipeline & Executive Dashboard

![Dashboard](dashboard.png)

---

## 💼 Executive Summary

This project simulates the full analytics workflow of a mid-level Data/BI Analyst embedded in an e-commerce business — from raw, messy data to a boardroom-ready dashboard with every metric independently validated.

**The business problem:** Olist, a Brazilian e-commerce platform, operates across 9 data systems with no unified view of revenue, customers, or delivery performance. This project builds that unified view — answering the questions an executive team actually asks.

| Business Question | Answer |
|---|---|
| Which product categories drive the most revenue? | Home & Living (R$ 3.33M) and Electronics (R$ 2.65M) lead |
| How do customers prefer to pay? | Credit card accounts for ~70% of all revenue (~R$ 15.4M) |
| Does product presentation affect sales? | Yes — products with longer, more detailed names generate the highest revenue |
| How reliable is our delivery? | Delivery performance is measurably linked to review scores |
| Can we trust our dashboard numbers? | Yes — all 8 KPIs independently validated via SQL (8/8 passed) |

---

## 🛠️ Technical Skills Demonstrated

| Skill | Where Applied |
|---|---|
| **Python / pandas** | Data cleaning across 9 relational tables — nulls, duplicates, typos, encoding |
| **PostgreSQL** | Star schema design, CTEs, LEFT JOIN logic, aggregations |
| **Data Modelling** | Master fact table at order-item grain from 9 source tables |
| **Feature Engineering** | Bucketing, delivery KPIs, geolocation deduplication |
| **Power BI** | Executive dashboard — KPI cards, bar charts, treemap, time-series |
| **KPI Validation** | SQL cross-verification of every dashboard metric — 8/8 passed |

---

## 🏗️ Pipeline Architecture

```
Raw CSVs (9 tables, ~100K orders)
        │
        ▼
🐍 Python — Data Cleaning
  └── Jupyter notebook cleaning all 9 tables independently
      Handles: nulls, duplicates, city name typos, category
      standardisation, Portuguese encoding fixes
        │
        ▼
🐘 PostgreSQL — Modelling & Feature Engineering
  └── Single SQL script covering:
      ├── Category dimension: 40+ raw names → 11 business groups
      ├── Geolocation deduplication (1 row per ZIP prefix)
      ├── Master fact table — star schema via LEFT JOINs (9 tables)
      ├── Feature engineering — name length buckets, photo buckets,
      │   delivery days, delay flags
      └── olist_analytics view — clean layer for Power BI
        │
        ▼
📊 Power BI — Executive Dashboard
  └── Connected live to PostgreSQL via olist_analytics view
        │
        ▼
✅ KPI Validation
  └── Every dashboard metric re-calculated in SQL
      and matched against Power BI — 8/8 checks passed
```

---

## 📊 Dashboard & Key Business Findings

![Dashboard](dashboard.png)

### KPI Summary

| Metric | Value |
|---|---|
| 👥 Total Customers | 122.35K |
| 💰 Total Revenue | R$ 22.14M |
| 🚚 Total Shipping Cost | R$ 2.43M |
| 🎁 Total Product Value | R$ 17.12M |

### Business Insights

**💳 Payment behaviour is heavily concentrated**
Credit card accounts for ~R$ 15.4M (~70%) of all revenue. Boleto (R$ 2.9M), voucher (R$ 0.4M), and debit card (R$ 0.2M) are significantly smaller. This has direct implications for checkout optimisation and payment partner strategy.

**🏠 Home & Living and Electronics dominate revenue**
The top two categories together account for over 27% of total revenue. These are the highest-priority categories for inventory investment, marketing spend, and seller acquisition efforts.

**📝 Product detail drives revenue**
Products with the longest, most descriptive names (56+ characters) generate the highest revenue — a strong signal that listing quality directly impacts sales. Actionable for seller onboarding and content guidelines.

**📦 Delivery performance affects customer satisfaction**
SQL analysis confirms a clear relationship between delivery delay and review score. Reducing `delay_days` is a measurable lever for improving customer experience at scale.

**📅 Revenue is seasonal**
Clear peaks in the time-series align with Brazilian retail calendar events — supporting demand forecasting and campaign planning decisions.

---

## 🗂️ Data Model

**Grain:** 1 row = 1 order item

```
                    ┌──────────────────────┐
                    │     master_olist      │  ← Fact table
                    │──────────────────────│
                    │ order_id             │
                    │ customer_id          │
                    │ product_id           │
                    │ seller_id            │
                    │ item_price           │
                    │ freight_cost         │
                    │ payment_type         │
                    │ review_score         │
                    │ delivery_days        │
                    │ delay_days           │
                    │ name_length_bucket   │
                    │ photos_qty_bucket    │
                    │ clean_category       │
                    └──────────────────────┘
                      │         │        │
           ┌──────────┘    ┌────┘   ┌────┘
           ▼               ▼        ▼
     Customers         Products   Payments
     Geolocation       Category   Reviews
```

**Key design decisions:**
- LEFT JOINs on all dimension tables — no orders lost due to missing dimension data
- Payment and review tables pre-aggregated via CTEs before joining — prevents row fan-out
- Geolocation deduplicated to 1 row per ZIP prefix before joining — prevents lat/lng fan-out

---

## 📂 Repository Structure

```
olist-ecommerce-analytics/
│
├── data/
│   └── Olist_complete_script.sql          # Full PostgreSQL pipeline (5 stages)
│
├── python_data_cleaning_script/
│   └── Python_Cleaning_Script.ipynb       # Pandas cleaning for all 9 tables
│
├── Olist_KPI_Validation_Report.docx       # 8/8 KPI checks — SQL vs Power BI
├── olist_dashboard.pbix                   # Power BI dashboard file
├── dashboard.png                          # Executive dashboard screenshot
└── README.md
```

---

## ✅ KPI Validation — 8/8 Passed

Every metric on the dashboard was independently re-calculated in PostgreSQL and matched against Power BI. This is what separates a trustworthy dashboard from one that just looks good.

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

> Cross-check: Revenue (22.14M) = Product Value (17.12M) + Shipping (2.43M) + other fees ✅

📁 Full methodology: `Olist_KPI_Validation_Report.docx`

---

## 🚀 How to Reproduce

**Prerequisites:** Python 3.9+, PostgreSQL 14+, Power BI Desktop
**Libraries:** `pandas`, `numpy`, `psycopg2`, `sqlalchemy`, `jupyter`

```bash
# 1. Clone the repo
git clone https://github.com/ApostolicDA/Olist-E-Commerce-Analytics-Engineering-Project.git

# 2. Install dependencies
pip install pandas numpy psycopg2-binary sqlalchemy jupyter

# 3. Get the raw data
# https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
# (9 CSV files — ~100K orders, 2016–2018)

# 4. Clean the data
jupyter notebook python_data_cleaning_script/Python_Cleaning_Script.ipynb

# 5. Run the full SQL pipeline
psql -U your_user -d your_database -f data/Olist_complete_script.sql

# 6. Open Power BI → connect to PostgreSQL → select olist_analytics view
```

---

## 📦 Data Source

**Brazilian E-Commerce Public Dataset by Olist**
🔗 https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

~100K orders · 9 relational tables · 2016–2018 · Multiple Brazilian marketplaces

---

## 👤 Author

**Proud Ndlovu** — Data & BI Analyst
📧 fanisaproud@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/proud-ndlovu)
🐙 [GitHub](https://github.com/ApostolicDA)

---

## 📄 License

MIT License
