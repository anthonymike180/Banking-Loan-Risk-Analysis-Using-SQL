-- =============================================================================
-- FILE: 01_database_setup.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- AUTHOR: Anthony Michael
-- DESCRIPTION: Creates the database, table schema, and imports loan data.
-- DATABASE: PostgreSQL 18.2
-- =============================================================================


-- =============================================================================
-- STEP 1 — CREATE THE DATABASE
-- =============================================================================
-- Run this command in your PostgreSQL terminal (psql) as a superuser.
-- We create a dedicated database to keep this project isolated.

-- In psql terminal, run:
-- CREATE DATABASE loan_risk_analysis;
-- \c loan_risk_analysis   ← connects you to the new database


-- =============================================================================
-- STEP 2 — CREATE THE LOANS TABLE
-- =============================================================================
-- This table mirrors the columns in the Kaggle dataset:
-- https://www.kaggle.com/datasets/nikhil1e9/loan-default
--
-- DATA DICTIONARY:
-- ┌─────────────────────┬──────────────┬────────────────────────────────────────────┐
-- │ Column Name         │ Data Type    │ Description                                │
-- ├─────────────────────┼──────────────┼────────────────────────────────────────────┤
-- │ loan_id             │ SERIAL PK    │ Unique identifier for each loan            │
-- │ age                 │ INTEGER      │ Borrower's age in years                    │
-- │ income              │ NUMERIC      │ Annual income of the borrower (USD)        │
-- │ loan_amount         │ NUMERIC      │ Total loan amount requested (USD)          │
-- │ credit_score        │ INTEGER      │ Credit score (300–850 scale)               │
-- │ months_employed     │ INTEGER      │ Number of months at current job            │
-- │ num_credit_lines    │ INTEGER      │ Number of open credit lines                │
-- │ interest_rate       │ NUMERIC      │ Annual interest rate on the loan (%)       │
-- │ loan_term           │ INTEGER      │ Loan duration in months                    │
-- │ dti_ratio           │ NUMERIC      │ Debt-to-income ratio (0.0 – 1.0)          │
-- │ education           │ VARCHAR      │ Highest education level of borrower        │
-- │ employment_type     │ VARCHAR      │ Employment status (Full-time, Part-time…)  │
-- │ marital_status      │ VARCHAR      │ Marital status                             │
-- │ has_mortgage        │ BOOLEAN      │ Whether borrower has an active mortgage    │
-- │ has_dependents      │ BOOLEAN      │ Whether borrower has dependents            │
-- │ loan_purpose        │ VARCHAR      │ Reason for the loan (Auto, Home, etc.)     │
-- │ has_cosigner        │ BOOLEAN      │ Whether a co-signer exists on the loan     │
-- │ default_status      │ INTEGER      │ 1 = defaulted, 0 = performing (TARGET)     │
-- └─────────────────────┴──────────────┴────────────────────────────────────────────┘

DROP TABLE IF EXISTS loans;

CREATE TABLE loans (
    loan_id            VARCHAR(20)         PRIMARY KEY,
    age                INTEGER,
    income             NUMERIC(15, 2),
    loan_amount        NUMERIC(15, 2),
    credit_score       INTEGER,
    months_employed    INTEGER,
    num_credit_lines   INTEGER,
    interest_rate      NUMERIC(6, 4),
    loan_term          INTEGER,
    dti_ratio          NUMERIC(6, 4),
    education          VARCHAR(50),
    employment_type    VARCHAR(50),
    marital_status     VARCHAR(30),
    has_mortgage       BOOLEAN,
    has_dependents     BOOLEAN,
    loan_purpose       VARCHAR(50),
    has_cosigner       BOOLEAN,
    default_status     SMALLINT       CHECK (default_status IN (0, 1))
);

-- WHY THESE TYPES?
-- NUMERIC(15,2)  → precise money values (never use FLOAT for currency)
-- NUMERIC(6,4)   → rates like 0.1523 need 4 decimal places
-- SMALLINT CHECK → enforces data integrity; only 0 or 1 allowed
-- VARCHAR        → flexible text lengths for categorical fields

-- =============================================================================
-- STEP 3 — VERIFY THE IMPORT
-- =============================================================================

-- 3a. Check total row count — should match your CSV file
SELECT COUNT(*) AS total_loans
FROM loans;

-- 3b. Preview the first 10 rows
SELECT *
FROM loans
LIMIT 10;

-- 3c. Check for any NULL values in key columns
SELECT
    COUNT(*)                                    AS total_rows,
    COUNT(*) FILTER (WHERE income IS NULL)      AS null_income,
    COUNT(*) FILTER (WHERE loan_amount IS NULL) AS null_loan_amount,
    COUNT(*) FILTER (WHERE credit_score IS NULL)AS null_credit_score,
    COUNT(*) FILTER (WHERE default_status IS NULL) AS null_default
FROM loans;

-- 3d. Check distinct values for categorical columns
SELECT DISTINCT employment_type  FROM loans ORDER BY 1;
SELECT DISTINCT education        FROM loans ORDER BY 1;
SELECT DISTINCT loan_purpose     FROM loans ORDER BY 1;
SELECT DISTINCT marital_status   FROM loans ORDER BY 1;
