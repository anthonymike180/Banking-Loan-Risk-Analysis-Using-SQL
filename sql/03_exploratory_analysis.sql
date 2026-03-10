-- =============================================================================
-- FILE: 03_exploratory_analysis.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Exploratory Data Analysis (EDA) of the loan portfolio.
-- GOAL: Understand the shape, distribution, and characteristics of our data
--       before drawing any risk conclusions.
-- =============================================================================


-- =============================================================================
-- QUERY 1 — PORTFOLIO SNAPSHOT (Executive Summary Numbers)
-- =============================================================================
-- This is the first query a banking analyst runs — a single high-level view
-- of the entire loan portfolio. CEOs and CFOs ask for numbers like these.

SELECT
    COUNT(*)                                    AS total_loans,
    COUNT(DISTINCT loan_id)                     AS unique_loans,

    -- Loan value metrics
    SUM(loan_amount)                            AS total_portfolio_value,
    ROUND(AVG(loan_amount), 2)                  AS avg_loan_amount,
    MIN(loan_amount)                            AS smallest_loan,
    MAX(loan_amount)                            AS largest_loan,
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY loan_amount)                  AS median_loan_amount,

    -- Interest rate metrics
    ROUND(AVG(interest_rate) * 100, 2)          AS avg_interest_rate_pct,
    MIN(interest_rate) * 100                    AS min_interest_rate_pct,
    MAX(interest_rate) * 100                    AS max_interest_rate_pct,

    -- Borrower profile metrics
    ROUND(AVG(age), 1)                          AS avg_borrower_age,
    ROUND(AVG(income), 2)                       AS avg_annual_income,
    ROUND(AVG(credit_score), 0)                 AS avg_credit_score,

    -- Default overview
    SUM(default_status)                         AS total_defaults,
    ROUND(AVG(default_status) * 100, 2)         AS overall_default_rate_pct

FROM loans;

-- BUSINESS MEANING:
-- total_portfolio_value → total financial exposure of the bank
-- avg_interest_rate     → how much revenue the bank earns on average
-- overall_default_rate  → the key risk KPI — lower is better
-- avg_credit_score      → quality of borrowers in the portfolio


-- =============================================================================
-- QUERY 2 — LOAN DISTRIBUTION BY INCOME BRACKET
-- =============================================================================
-- Income is the #1 predictor of loan repayment ability.
-- This query shows how loans are spread across income segments.

SELECT
    income_bracket,
    COUNT(*)                                        AS loan_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_portfolio,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(AVG(loan_to_income), 4)                   AS avg_loan_to_income_ratio,
    SUM(default_status)                             AS total_defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY income_bracket
ORDER BY avg_income;

-- SQL CONCEPTS USED:
-- SUM(COUNT(*)) OVER() → window function for portfolio percentage
--                         without this, you'd need a subquery


-- =============================================================================
-- QUERY 3 — LOAN DISTRIBUTION BY EMPLOYMENT TYPE
-- =============================================================================
-- Employment stability directly impacts repayment capacity.

SELECT
    employment_type,
    COUNT(*)                                        AS loan_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_portfolio,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY employment_type
ORDER BY default_rate_pct DESC;

-- BUSINESS MEANING:
-- Self-employed borrowers often show higher default rates due to income volatility.
-- Full-time employees tend to be the lowest risk segment.


-- =============================================================================
-- QUERY 4 — LOAN DISTRIBUTION BY PURPOSE
-- =============================================================================
-- Loan purpose reveals risk exposure by product category.

SELECT
    loan_purpose,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(SUM(loan_amount), 2)                      AS total_exposure,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_interest_rate_pct,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY loan_purpose
ORDER BY total_exposure DESC;

-- BUSINESS MEANING:
-- Total exposure shows where the bank's money is concentrated.
-- High-default loan purposes may need tighter underwriting rules.


-- =============================================================================
-- QUERY 5 — CREDIT SCORE DISTRIBUTION
-- =============================================================================
-- The FICO credit score is the primary creditworthiness signal in banking.

SELECT
    credit_tier,
    COUNT(*)                                        AS borrower_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_borrowers,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_interest_rate_pct,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY credit_tier
ORDER BY
    CASE credit_tier
        WHEN 'Exceptional' THEN 1
        WHEN 'Very Good'   THEN 2
        WHEN 'Good'        THEN 3
        WHEN 'Fair'        THEN 4
        WHEN 'Poor'        THEN 5
        ELSE 6
    END;

-- SQL CONCEPT: Custom ORDER BY using CASE
-- Standard alphabetical sorting would be wrong here.
-- CASE lets us define logical sort order for non-numeric categories.


-- =============================================================================
-- QUERY 6 — AGE GROUP ANALYSIS
-- =============================================================================
-- Age correlates with financial stability and debt experience.

SELECT
    CASE
        WHEN age < 25              THEN '18–24 (Young Adults)'
        WHEN age BETWEEN 25 AND 34 THEN '25–34 (Early Career)'
        WHEN age BETWEEN 35 AND 44 THEN '35–44 (Mid Career)'
        WHEN age BETWEEN 45 AND 54 THEN '45–54 (Peak Earners)'
        WHEN age BETWEEN 55 AND 64 THEN '55–64 (Pre-Retirement)'
        WHEN age >= 65             THEN '65+ (Retirement Age)'
    END                                             AS age_group,
    COUNT(*)                                        AS borrower_count,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY age_group
ORDER BY age_group;


-- =============================================================================
-- QUERY 7 — LOAN TERM DISTRIBUTION
-- =============================================================================

SELECT
    loan_term                                       AS loan_term_months,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_interest_rate_pct,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY loan_term
ORDER BY loan_term;

-- BUSINESS MEANING:
-- Longer loan terms = more interest revenue but also more default risk exposure.


-- =============================================================================
-- QUERY 8 — DTI RATIO BUCKETS
-- =============================================================================
-- DTI (Debt-to-Income) ratio is a critical underwriting metric.
-- Most banks cap DTI at 43% for mortgage approval (Qualified Mortgage rule).

SELECT
    CASE
        WHEN dti_ratio < 0.20               THEN 'Very Low DTI  (< 20%)'
        WHEN dti_ratio BETWEEN 0.20 AND 0.35 THEN 'Low DTI       (20–35%)'
        WHEN dti_ratio BETWEEN 0.35 AND 0.43 THEN 'Moderate DTI  (35–43%)'
        WHEN dti_ratio BETWEEN 0.43 AND 0.50 THEN 'High DTI      (43–50%)'
        WHEN dti_ratio > 0.50               THEN 'Very High DTI (> 50%)'
    END                                             AS dti_bucket,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY dti_bucket
ORDER BY default_rate_pct DESC;


-- =============================================================================
-- QUERY 9 — MULTI-DIMENSIONAL CROSS-TAB: INCOME × EMPLOYMENT TYPE
-- =============================================================================
-- Real-world analysis often needs 2-dimensional breakdowns.
-- This shows default rates across the income-employment matrix.

SELECT
    income_bracket,
    employment_type,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount
FROM loans
GROUP BY income_bracket, employment_type
HAVING COUNT(*) >= 10          -- exclude tiny groups (statistically unreliable)
ORDER BY default_rate_pct DESC
LIMIT 20;

-- BUSINESS INSIGHT:
-- The combination of low income + self-employed typically shows
-- the highest default rates in banking datasets.
