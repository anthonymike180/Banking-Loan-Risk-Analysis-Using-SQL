-- =============================================================================
-- FILE: 04_default_analysis.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Deep-dive analysis of loan default patterns.
-- GOAL: Identify WHO defaults, WHEN they default, and WHY — so the bank
--       can improve its lending criteria and reduce credit losses.
-- =============================================================================


-- =============================================================================
-- QUERY 1 — OVERALL DEFAULT SUMMARY
-- =============================================================================

SELECT
    COUNT(*)                                        AS total_loans,
    SUM(CASE WHEN default_status = 1 THEN 1 ELSE 0 END) AS total_defaults,
    SUM(CASE WHEN default_status = 0 THEN 1 ELSE 0 END) AS total_performing,
    ROUND(AVG(default_status) * 100, 2)             AS overall_default_rate_pct,
    SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END) AS total_default_exposure,
    ROUND(
        SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END) * 100.0
        / SUM(loan_amount), 2
    )                                               AS pct_portfolio_at_risk
FROM loans;

-- BUSINESS MEANING:
-- pct_portfolio_at_risk = What % of total money lent is in defaulted loans.
-- This is the key number for the Chief Risk Officer (CRO).


-- =============================================================================
-- QUERY 2 — DEFAULT RATE BY INCOME BRACKET
-- =============================================================================
-- Lower-income borrowers historically default more due to smaller financial buffers.

SELECT
    income_bracket,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END), 2)
                                                    AS default_dollar_exposure
FROM loans
GROUP BY income_bracket
ORDER BY default_rate_pct DESC;


-- =============================================================================
-- QUERY 3 — DEFAULT RATE BY EMPLOYMENT TYPE
-- =============================================================================

SELECT
    employment_type,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(income), 2)                           AS avg_income
FROM loans
GROUP BY employment_type
ORDER BY default_rate_pct DESC;


-- =============================================================================
-- QUERY 4 — DEFAULT RATE BY CREDIT TIER
-- =============================================================================
-- This validates whether credit scores are actually predictive in this dataset.
-- A well-functioning portfolio should show Poor credit = high defaults.

SELECT
    credit_tier,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount
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


-- =============================================================================
-- QUERY 5 — DEFAULT RATE BY LOAN PURPOSE
-- =============================================================================
-- Some loan types are inherently riskier (e.g., personal/unsecured loans
-- vs. auto loans where the asset can be repossessed).

SELECT
    loan_purpose,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END), 2)
                                                    AS defaulted_dollar_amount
FROM loans
GROUP BY loan_purpose
ORDER BY default_rate_pct DESC;


-- =============================================================================
-- QUERY 6 — DEFAULT RATE BY DTI BUCKET
-- =============================================================================
-- DTI is one of the strongest predictors of default.
-- High DTI → borrower is already stretched thin financially.

SELECT
    CASE
        WHEN dti_ratio < 0.20               THEN '1. Very Low (< 20%)'
        WHEN dti_ratio BETWEEN 0.20 AND 0.35 THEN '2. Low (20–35%)'
        WHEN dti_ratio BETWEEN 0.35 AND 0.43 THEN '3. Moderate (35–43%)'
        WHEN dti_ratio BETWEEN 0.43 AND 0.50 THEN '4. High (43–50%)'
        WHEN dti_ratio > 0.50               THEN '5. Very High (> 50%)'
    END                                             AS dti_bucket,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct
FROM loans
GROUP BY dti_bucket
ORDER BY dti_bucket;


-- =============================================================================
-- QUERY 7 — DEFAULT ANALYSIS: COSIGNER IMPACT
-- =============================================================================
-- Cosigners reduce risk by providing a secondary repayment source.

SELECT
    has_cosigner,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score
FROM loans
GROUP BY has_cosigner
ORDER BY has_cosigner;


-- =============================================================================
-- QUERY 8 — DEFAULT ANALYSIS: MORTGAGE AND DEPENDENTS
-- =============================================================================
-- Multiple financial obligations can strain repayment capacity.

SELECT
    has_mortgage,
    has_dependents,
    COUNT(*)                                        AS total_loans,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(AVG(income), 2)                           AS avg_income
FROM loans
GROUP BY has_mortgage, has_dependents
ORDER BY default_rate_pct DESC;


-- =============================================================================
-- QUERY 9 — HIGH-RISK BORROWER PROFILE (CTE Pattern)
-- =============================================================================
-- Using a CTE to build a step-by-step analysis.
-- First identify high-risk borrowers, then analyze their characteristics.

WITH high_risk_borrowers AS (
    SELECT *
    FROM loans
    WHERE default_status = 1
),
low_risk_borrowers AS (
    SELECT *
    FROM loans
    WHERE default_status = 0
)

SELECT
    'Defaulted'                                     AS group_label,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(age), 1)                              AS avg_age,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score,
    ROUND(AVG(dti_ratio) * 100, 2)                  AS avg_dti_pct,
    ROUND(AVG(months_employed), 1)                  AS avg_months_employed,
    ROUND(AVG(loan_to_income), 4)                   AS avg_loan_to_income
FROM high_risk_borrowers

UNION ALL

SELECT
    'Performing',
    COUNT(*),
    ROUND(AVG(age), 1),
    ROUND(AVG(income), 2),
    ROUND(AVG(loan_amount), 2),
    ROUND(AVG(credit_score), 0),
    ROUND(AVG(dti_ratio) * 100, 2),
    ROUND(AVG(months_employed), 1),
    ROUND(AVG(loan_to_income), 4)
FROM low_risk_borrowers;

-- SQL CONCEPT: CTE (Common Table Expression) + UNION ALL
-- CTEs make complex queries readable by breaking them into named steps.
-- UNION ALL stacks two result sets — perfect for side-by-side comparisons.


-- =============================================================================
-- QUERY 10 — DEFAULT RATE HEATMAP: CREDIT TIER × INCOME BRACKET
-- =============================================================================
-- This is the core risk matrix used in bank credit policies.
-- Shows exactly which borrower segments have the highest default risk.

SELECT
    credit_tier,
    income_bracket,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    -- Visual heatmap using CASE (no chart tool needed!)
    REPEAT('█', CAST(ROUND(AVG(default_status) * 10) AS INTEGER))
                                                    AS risk_bar
FROM loans
GROUP BY credit_tier, income_bracket
HAVING COUNT(*) >= 20  -- statistically meaningful only
ORDER BY default_rate_pct DESC
LIMIT 20;

-- The risk_bar column creates a simple text-based bar chart in your SQL client.
-- This is great for quick visual interpretation.
