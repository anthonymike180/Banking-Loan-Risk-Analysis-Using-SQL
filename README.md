# 🏦 Banking Loan Risk Analysis Using SQL

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.2-blue?style=flat&logo=postgresql)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange?style=flat)
![Status](https://img.shields.io/badge/Status-Complete-success?style=flat)

> **A complete, industry-level SQL portfolio project analyzing loan default risk in a banking dataset.**  
> Built with PostgreSQL 18.2 | Advanced SQL | Real-World Banking Analytics

---

## 📌 Project Overview

Banks issue thousands of loans every year. Some borrowers fail to repay — this is called a **loan default**, and it causes significant financial loss. This project uses **pure SQL** to analyze a loan dataset, identify high-risk borrowers, segment the portfolio by risk level, and generate actionable business insights.

This project mirrors the **real-world workflow of a Bank Data Analyst or Credit Risk Analyst**.

---

## 🎯 Business Problem

The bank's analytics team needs to:

- Identify **high-risk borrowers** before approving loans
- Understand **default patterns** across income, credit, and employment segments  
- Analyze **loan portfolio health** and financial exposure  
- Build a **SQL-based risk scoring model** to classify borrowers  
- Generate insights that help the bank **reduce default losses**

---

## 📊 Dataset

| Property | Details |
|----------|---------|
| **Source** | [Kaggle — Loan Default Dataset](https://www.kaggle.com/datasets/nikhil1e9/loan-default) |
| **Format** | CSV |
| **Records** | ~255,000 loans |
| **Target Variable** | `default_status` (1 = defaulted, 0 = performing) |

### Key Columns

| Column | Description |
|--------|-------------|
| `age` | Borrower's age |
| `income` | Annual income (USD) |
| `loan_amount` | Loan size (USD) |
| `credit_score` | FICO credit score (300–850) |
| `dti_ratio` | Debt-to-income ratio |
| `employment_type` | Full-Time, Part-Time, Self-Employed, Unemployed |
| `loan_purpose` | Auto, Home, Business, Personal, Education, Other |
| `interest_rate` | Annual interest rate |
| `has_cosigner` | Co-signer present? |
| `default_status` | **Target: 1 = defaulted, 0 = performing** |

---

## 🛠 Tools & Technologies

| Tool | Purpose |
|------|---------|
| **PostgreSQL 18.2** | Database engine |
| **pgAdmin 4** | SQL client / query runner |
| **SQL only** | All analysis — no Python, no R |

---

## 📁 Project Structure

```
loan-risk-sql-analysis/
│
├── data/
│   └── loan_default.csv              ← Download from Kaggle
│
├── sql/
│   ├── 01_database_setup.sql         ← Create DB, table, import CSV
│   ├── 02_data_cleaning.sql          ← Handle NULLs, duplicates, validation
│   ├── 03_exploratory_analysis.sql   ← EDA — distributions and summaries
│   ├── 04_default_analysis.sql       ← Default patterns and borrower profiles
│   ├── 05_risk_segmentation.sql      ← Risk tiers + borrower VIEW
│   ├── 06_portfolio_analysis.sql     ← Financial P&L and portfolio health
│   └── 07_advanced_analytics.sql     ← Window functions, rankings, scoring
│
└── README.md
```

---

## 🧠 SQL Skills Demonstrated

| Skill | Where Used |
|-------|-----------|
| `CREATE TABLE` / `COPY` | `01_database_setup.sql` |
| `UPDATE` / `ALTER TABLE` | `02_data_cleaning.sql` |
| `CASE` statements | All files |
| `GROUP BY` + Aggregations | All files |
| `CTEs` (Common Table Expressions) | `04`, `05`, `06`, `07` |
| `UNION ALL` | `04_default_analysis.sql`, `07` |
| `Window Functions` | `03`, `07` |
| `ROW_NUMBER`, `RANK`, `DENSE_RANK` | `07_advanced_analytics.sql` |
| `NTILE`, `PERCENT_RANK` | `07_advanced_analytics.sql` |
| `LAG` / `LEAD` | `07_advanced_analytics.sql` |
| `PERCENTILE_CONT` | `07_advanced_analytics.sql` |
| `PARTITION BY` | `03`, `06`, `07` |
| Running Totals | `07_advanced_analytics.sql` |
| Moving Averages | `07_advanced_analytics.sql` |
| `CREATE VIEW` | `05_risk_segmentation.sql` |
| Weighted Scoring Logic | `05`, `07` |

---

## 🔍 Key Analyses

### ✅ 1. Portfolio Snapshot
Total loans, portfolio value, average loan size, overall default rate — the executive summary.

### ✅ 2. Default Analysis by Segment
Default rates broken down by income bracket, employment type, credit tier, DTI ratio, and loan purpose. Identifies which segments carry the most risk.

### ✅ 3. Borrower Risk Segmentation
A multi-factor weighted risk scoring model built in pure SQL using `CASE` statements across 6 dimensions:
- Credit score
- Income level
- DTI ratio
- Employment stability
- Loan-to-income ratio
- Cosigner presence

Borrowers classified into: **Low Risk → Medium Risk → High Risk → Very High Risk**

### ✅ 4. Portfolio Financial Health
Estimates interest revenue, default losses, recovery amounts, and net profit by segment. Identifies which loan categories are profit centers vs. loss centers.

### ✅ 5. Advanced Risk Analytics
- Top risky borrowers by risk score
- Running cumulative exposure
- Moving average default rate
- Cohort comparison: Defaulters vs. Performers
- Risk model accuracy (True Positive / False Negative analysis)

---

## 💡 Key Business Insights

1. **Low-income borrowers (< $30K/year)** show significantly higher default rates — stricter income verification is recommended for this segment.

2. **Self-employed and unemployed borrowers** default at higher rates than full-time employees due to income volatility.

3. **Borrowers with poor credit scores (< 580)** represent a disproportionate share of default losses despite lower loan volumes.

4. **High DTI (> 50%)** is the single strongest predictor of default — consider hard caps at 43% for new loan approvals.

5. **Loans without a cosigner** in the high-risk income bracket have the highest default dollar exposure.

6. **Personal and Other purpose loans** carry the highest default rates; Auto and Home loans show lower risk (collateral-backed).

7. The **risk scoring model** correctly identifies High Risk / Very High Risk borrowers, validating the multi-factor approach over single-score approval processes.

---

## 🚀 How to Run This Project

### Step 1 — Get the Data
Download the dataset from [Kaggle](https://www.kaggle.com/datasets/nikhil1e9/loan-default) and save it as `data/loan_default.csv`.

### Step 2 — Set Up PostgreSQL
Install PostgreSQL 18.2 and pgAdmin, or use any PostgreSQL client.

### Step 3 — Run SQL Files in Order

```sql
-- In psql or pgAdmin, run in this exact order:

\i sql/01_database_setup.sql     -- Creates DB and table, imports CSV
\i sql/02_data_cleaning.sql      -- Cleans and prepares data
\i sql/03_exploratory_analysis.sql
\i sql/04_default_analysis.sql
\i sql/05_risk_segmentation.sql  -- Creates vw_borrower_risk VIEW
\i sql/06_portfolio_analysis.sql
\i sql/07_advanced_analytics.sql -- Requires the VIEW from step 5
```

> ⚠️ **Important:** Update the file path in `01_database_setup.sql` (`COPY` command) to match your local CSV location.

---

## 📈 What I Learned

- How to structure a complete **end-to-end SQL analytics project**
- How banks perform **credit risk analysis** using SQL
- How to build a **rule-based risk scoring model** in SQL using CASE statements
- **Advanced window functions**: ROW_NUMBER, RANK, NTILE, LAG, LEAD, running totals
- How to create **reusable SQL VIEWs** for modular analysis
- How to calculate **financial metrics**: interest revenue, default exposure, recovery estimates
- How to write **clean, production-ready SQL** with proper commenting

---

## 👤 Author

**Anthony Michael**  
[LinkedIn](https://linkedin.com/in/anthony-michael-b36382259) | [GitHub](https://github.com/anthonymike180)

---

