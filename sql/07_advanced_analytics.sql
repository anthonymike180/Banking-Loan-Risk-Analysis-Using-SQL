-- =============================================================================
-- FILE: 07_advanced_analytics.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Advanced SQL analytics — window functions, ranking, running
--              totals, and the final Risk Scoring Model.
-- SQL CONCEPTS: ROW_NUMBER, RANK, DENSE_RANK, NTILE, LAG, LEAD, running
--               totals, percentile functions, PIVOT-style queries.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — TOP 10 HIGHEST-VALUE LOANS
-- =============================================================================
-- Using ROW_NUMBER() to rank loans by value within each risk tier.

SELECT
    loan_id,
    loan_amount,
    income,
    credit_score,
    employment_type,
    loan_purpose,
    interest_rate * 100                             AS interest_rate_pct,
    default_status,
    -- Rank globally by loan amount
    ROW_NUMBER() OVER (ORDER BY loan_amount DESC)   AS global_rank,
    -- Rank within each employment type
    ROW_NUMBER() OVER (
        PARTITION BY employment_type
        ORDER BY loan_amount DESC
    )                                               AS rank_within_employment
FROM loans
ORDER BY loan_amount DESC
LIMIT 20;

-- SQL CONCEPT: Window Functions
-- ROW_NUMBER() OVER (ORDER BY ...) → assigns 1,2,3,4... across all rows
-- PARTITION BY splits the ranking into groups.
-- Unlike GROUP BY, window functions do NOT collapse rows.


-- =============================================================================
-- SECTION 2 — RANKING FUNCTIONS COMPARED
-- =============================================================================
-- Demonstrates the difference between ROW_NUMBER, RANK, and DENSE_RANK.

SELECT
    loan_id,
    credit_score,
    loan_amount,
    ROW_NUMBER() OVER (ORDER BY credit_score DESC)  AS row_number,
    -- RANK: same credit_score = same rank, next rank skips (1,1,3)
    RANK()       OVER (ORDER BY credit_score DESC)  AS rank_num,
    -- DENSE_RANK: same score = same rank, NO skip (1,1,2)
    DENSE_RANK() OVER (ORDER BY credit_score DESC)  AS dense_rank_num
FROM loans
ORDER BY credit_score DESC
LIMIT 20;

-- WHEN TO USE WHICH:
-- ROW_NUMBER  → unique numbering (e.g., pagination, deduplication)
-- RANK        → competition-style ranking (ties allowed, gaps after ties)
-- DENSE_RANK  → ranking without gaps (most intuitive for categories)


-- =============================================================================
-- SECTION 3 — NTILE: LOAN QUARTILES
-- =============================================================================
-- NTILE divides the dataset into N equal buckets.
-- Banks use this to identify the top quartile of high-value/high-risk loans.

SELECT
    loan_id,
    loan_amount,
    income,
    credit_score,
    default_status,
    -- Divide loans into 4 equal groups by loan amount
    NTILE(4) OVER (ORDER BY loan_amount DESC)       AS loan_amount_quartile,
    -- Divide into 10 equal groups (deciles)
    NTILE(10) OVER (ORDER BY loan_amount DESC)      AS loan_amount_decile
FROM loans
ORDER BY loan_amount DESC
LIMIT 30;


-- =============================================================================
-- SECTION 4 — RUNNING TOTALS (Cumulative Loan Issuance)
-- =============================================================================
-- Running totals show the cumulative portfolio build-up.
-- Used in time-series dashboards and quarterly reporting.

WITH loans_ordered AS (
    SELECT
        loan_id,
        loan_amount,
        income,
        credit_score,
        default_status,
        -- Running total of loan amounts (ordered by loan_id as proxy for time)
        SUM(loan_amount) OVER (
            ORDER BY loan_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                           AS running_total_exposure,
        -- Running count of defaults
        SUM(default_status) OVER (
            ORDER BY loan_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                           AS running_default_count,
        -- Running default rate
        ROUND(
            AVG(default_status::NUMERIC) OVER (
                ORDER BY loan_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100, 2
        )                                           AS running_default_rate_pct
    FROM loans
)
SELECT *
FROM loans_ordered
ORDER BY loan_id
LIMIT 50;

-- SQL CONCEPT: Window Frame Clause
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
-- → includes all rows from the start up to the current row
-- This is what makes it "running" (cumulative).


-- =============================================================================
-- SECTION 5 — MOVING AVERAGE (Smoothed Risk Trend)
-- =============================================================================
-- A moving average over the last 100 loans shows the rolling default rate.
-- This would normally use a date column; we use loan_id as a time proxy.

SELECT
    loan_id,
    default_status,
    loan_amount,
    -- 100-row moving average of default rate
    ROUND(
        AVG(default_status::NUMERIC) OVER (
            ORDER BY loan_id
            ROWS BETWEEN 99 PRECEDING AND CURRENT ROW
        ) * 100, 2
    )                                               AS moving_default_rate_pct,
    -- 100-row moving average of loan amount
    ROUND(
        AVG(loan_amount) OVER (
            ORDER BY loan_id
            ROWS BETWEEN 99 PRECEDING AND CURRENT ROW
        ), 2
    )                                               AS moving_avg_loan_amount
FROM loans
ORDER BY loan_id
LIMIT 200;


-- =============================================================================
-- SECTION 6 — TOP RISKY BORROWERS
-- =============================================================================
-- Identifies the borrowers who represent the highest dollar risk to the bank.
-- Uses the vw_borrower_risk view from 05_risk_segmentation.sql

SELECT
    loan_id,
    income,
    loan_amount,
    credit_score,
    ROUND(dti_ratio * 100, 1)                       AS dti_pct,
    employment_type,
    risk_score,
    risk_tier,
    default_status,
    -- Rank by risk score within each risk tier
    RANK() OVER (
        PARTITION BY risk_tier
        ORDER BY loan_amount DESC
    )                                               AS rank_within_tier,
    -- Percentile of this borrower's risk score in the full portfolio
    ROUND(
        PERCENT_RANK() OVER (ORDER BY risk_score) * 100, 1
    )                                               AS risk_percentile
FROM vw_borrower_risk
WHERE risk_tier IN ('High Risk', 'Very High Risk')
ORDER BY risk_score DESC, loan_amount DESC
LIMIT 50;

-- BUSINESS MEANING:
-- These are the accounts that need:
--   - Enhanced monitoring
--   - Early intervention calls
--   - Possible loan restructuring
--   - Provisioning (setting aside capital reserves)


-- =============================================================================
-- SECTION 7 — LAG/LEAD: LOAN AMOUNT COMPARISON TO PREVIOUS LOANS
-- =============================================================================
-- LAG looks at the previous row; LEAD looks at the next row.
-- Used for sequential comparisons.

SELECT
    loan_id,
    income,
    loan_amount,
    credit_score,
    default_status,
    -- How does this loan compare to the previous loan issued?
    LAG(loan_amount, 1) OVER (ORDER BY loan_id)     AS prev_loan_amount,
    loan_amount - LAG(loan_amount, 1) OVER
        (ORDER BY loan_id)                          AS change_from_prev,
    -- Next loan amount (look-ahead)
    LEAD(loan_amount, 1) OVER (ORDER BY loan_id)    AS next_loan_amount
FROM loans
ORDER BY loan_id
LIMIT 30;


-- =============================================================================
-- SECTION 8 — PERCENTILE ANALYSIS OF CREDIT SCORES
-- =============================================================================
-- Percentile analysis is key for setting approval thresholds.

SELECT
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY credit_score) AS p10_credit_score,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY credit_score) AS p25_credit_score,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY credit_score) AS median_credit_score,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY credit_score) AS p75_credit_score,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY credit_score) AS p90_credit_score,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY credit_score) AS p95_credit_score,
    MIN(credit_score)                               AS min_credit_score,
    MAX(credit_score)                               AS max_credit_score
FROM loans;

-- PERCENTILE_CONT = continuous percentile (interpolates between values)
-- p10 = the score below which 10% of borrowers fall (lowest quality)
-- p90 = the score below which 90% of borrowers fall (top 10% quality)


-- =============================================================================
-- SECTION 9 — COHORT COMPARISON: DEFAULTERS vs. PERFORMERS
-- =============================================================================
-- Side-by-side statistical comparison of the two populations.

SELECT
    metric,
    defaulters_avg,
    performers_avg,
    ROUND(defaulters_avg - performers_avg, 2)       AS difference,
    CASE
        WHEN defaulters_avg > performers_avg THEN 'Defaulters Higher ↑'
        WHEN defaulters_avg < performers_avg THEN 'Defaulters Lower ↓'
        ELSE 'Equal'
    END                                             AS direction
FROM (
    SELECT 'Average Income'          AS metric,
           ROUND(AVG(CASE WHEN default_status = 1 THEN income END), 2)        AS defaulters_avg,
           ROUND(AVG(CASE WHEN default_status = 0 THEN income END), 2)        AS performers_avg
    FROM loans
    UNION ALL
    SELECT 'Average Loan Amount',
           ROUND(AVG(CASE WHEN default_status = 1 THEN loan_amount END), 2),
           ROUND(AVG(CASE WHEN default_status = 0 THEN loan_amount END), 2)
    FROM loans
    UNION ALL
    SELECT 'Average Credit Score',
           ROUND(AVG(CASE WHEN default_status = 1 THEN credit_score END), 2),
           ROUND(AVG(CASE WHEN default_status = 0 THEN credit_score END), 2)
    FROM loans
    UNION ALL
    SELECT 'Average DTI Ratio (%)',
           ROUND(AVG(CASE WHEN default_status = 1 THEN dti_ratio END) * 100, 2),
           ROUND(AVG(CASE WHEN default_status = 0 THEN dti_ratio END) * 100, 2)
    FROM loans
    UNION ALL
    SELECT 'Average Age',
           ROUND(AVG(CASE WHEN default_status = 1 THEN age END), 1),
           ROUND(AVG(CASE WHEN default_status = 0 THEN age END), 1)
    FROM loans
    UNION ALL
    SELECT 'Average Months Employed',
           ROUND(AVG(CASE WHEN default_status = 1 THEN months_employed END), 1),
           ROUND(AVG(CASE WHEN default_status = 0 THEN months_employed END), 1)
    FROM loans
    UNION ALL
    SELECT 'Avg Loan-to-Income Ratio',
           ROUND(AVG(CASE WHEN default_status = 1 THEN loan_to_income END), 4),
           ROUND(AVG(CASE WHEN default_status = 0 THEN loan_to_income END), 4)
    FROM loans
) comparison
ORDER BY ABS(defaulters_avg - performers_avg) DESC;

-- This query tells us:
-- Which features are MOST DIFFERENT between defaulters and performers.
-- The bigger the difference, the more predictive that variable is.
-- This is the SQL equivalent of feature importance in machine learning.


-- =============================================================================
-- SECTION 10 — FINAL RISK SCORE LEADERBOARD
-- =============================================================================
-- The complete borrower risk ranking — ready for the bank's credit team.

SELECT
    RANK() OVER (ORDER BY risk_score DESC, loan_amount DESC) AS overall_risk_rank,
    loan_id,
    income,
    loan_amount,
    credit_score,
    ROUND(dti_ratio * 100, 1)                       AS dti_pct,
    employment_type,
    income_bracket,
    credit_tier,
    risk_score,
    risk_tier,
    default_status,
    CASE
        WHEN default_status = 1 AND risk_tier IN ('High Risk','Very High Risk')
            THEN 'True Positive — Model Correct'
        WHEN default_status = 0 AND risk_tier IN ('Low Risk','Medium Risk')
            THEN 'True Negative — Model Correct'
        WHEN default_status = 1 AND risk_tier IN ('Low Risk','Medium Risk')
            THEN 'False Negative — Model Missed Default!'
        WHEN default_status = 0 AND risk_tier IN ('High Risk','Very High Risk')
            THEN 'False Positive — Model Overcautious'
    END                                             AS model_accuracy_check
FROM vw_borrower_risk
ORDER BY overall_risk_rank
LIMIT 100;

-- MODEL PERFORMANCE SUMMARY (run separately):
SELECT
    model_accuracy_check,
    COUNT(*)                                        AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM (
    SELECT
        CASE
            WHEN default_status = 1 AND risk_score > 5 THEN 'True Positive'
            WHEN default_status = 0 AND risk_score <= 5 THEN 'True Negative'
            WHEN default_status = 1 AND risk_score <= 5 THEN 'False Negative'
            WHEN default_status = 0 AND risk_score > 5  THEN 'False Positive'
        END AS model_accuracy_check
    FROM vw_borrower_risk
) t
GROUP BY model_accuracy_check;
