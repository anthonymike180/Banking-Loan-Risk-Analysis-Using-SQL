-- =============================================================================
-- FILE: 02_data_cleaning.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Cleans and standardizes the raw loan dataset.
-- WHY IT MATTERS: Dirty data = wrong analysis = bad lending decisions.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — AUDIT: HOW DIRTY IS OUR DATA?
-- =============================================================================
-- Before cleaning, always audit to understand the scope of issues.
-- This is exactly what a data analyst does on Day 1 of any project.

SELECT
    COUNT(*)                                             AS total_rows,
    SUM(CASE WHEN age             IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN income          IS NULL THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN loan_amount     IS NULL THEN 1 ELSE 0 END) AS null_loan_amount,
    SUM(CASE WHEN credit_score    IS NULL THEN 1 ELSE 0 END) AS null_credit_score,
    SUM(CASE WHEN months_employed IS NULL THEN 1 ELSE 0 END) AS null_months_employed,
    SUM(CASE WHEN interest_rate   IS NULL THEN 1 ELSE 0 END) AS null_interest_rate,
    SUM(CASE WHEN dti_ratio       IS NULL THEN 1 ELSE 0 END) AS null_dti_ratio,
    SUM(CASE WHEN employment_type IS NULL THEN 1 ELSE 0 END) AS null_employment_type,
    SUM(CASE WHEN education       IS NULL THEN 1 ELSE 0 END) AS null_education,
    SUM(CASE WHEN loan_purpose    IS NULL THEN 1 ELSE 0 END) AS null_loan_purpose,
    SUM(CASE WHEN default_status  IS NULL THEN 1 ELSE 0 END) AS null_default_status
FROM loans;


-- =============================================================================
-- SECTION 2 — CHECK FOR DUPLICATE RECORDS
-- =============================================================================
-- Duplicates inflate counts and distort default rates.
-- We detect them by comparing key fields that should be unique together.

SELECT
    age,
    income,
    loan_amount,
    credit_score,
    employment_type,
    default_status,
    COUNT(*) AS duplicate_count
FROM loans
GROUP BY
    age,
    income,
    loan_amount,
    credit_score,
    employment_type,
    default_status
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- HOW TO REMOVE TRUE DUPLICATES (run only if duplicates are confirmed):
-- We keep the row with the lowest loan_id (earliest inserted).
DELETE FROM loans
WHERE loan_id NOT IN (
    SELECT MIN(loan_id)
    FROM loans
    GROUP BY age, income, loan_amount, credit_score, employment_type, default_status
);


-- =============================================================================
-- SECTION 3 — HANDLE NULL VALUES
-- =============================================================================

-- 3a. Replace NULL income with the median income
--     Why median? It's resistant to outliers (unlike average).
UPDATE loans
SET income = (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY income)
    FROM loans
    WHERE income IS NOT NULL
)
WHERE income IS NULL;

-- 3b. Replace NULL credit_score with the median credit score
UPDATE loans
SET credit_score = (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY credit_score)
    FROM loans
    WHERE credit_score IS NOT NULL
)::INTEGER
WHERE credit_score IS NULL;

-- 3c. Replace NULL interest_rate with the average rate for that employment type
--     Why group by employment type? Risk profiles differ — a more targeted fill.
UPDATE loans l
SET interest_rate = (
    SELECT ROUND(AVG(interest_rate), 4)
    FROM loans
    WHERE employment_type = l.employment_type
      AND interest_rate IS NOT NULL
)
WHERE l.interest_rate IS NULL;

-- 3d. Replace NULL months_employed with 0 (assume unemployed/unknown)
UPDATE loans
SET months_employed = 0
WHERE months_employed IS NULL;

-- 3e. Default NULL boolean flags to FALSE
UPDATE loans SET has_mortgage   = FALSE WHERE has_mortgage   IS NULL;
UPDATE loans SET has_dependents = FALSE WHERE has_dependents IS NULL;
UPDATE loans SET has_cosigner   = FALSE WHERE has_cosigner   IS NULL;


-- =============================================================================
-- SECTION 4 — STANDARDIZE TEXT COLUMNS
-- =============================================================================
-- Inconsistent casing causes GROUP BY errors. "full-time" ≠ "Full-Time" ≠ "FULL TIME"

-- 4a. Normalize employment_type
UPDATE loans
SET employment_type = INITCAP(TRIM(employment_type));

-- 4b. Normalize education
UPDATE loans
SET education = INITCAP(TRIM(education));

-- 4c. Normalize loan_purpose
UPDATE loans
SET loan_purpose = INITCAP(TRIM(loan_purpose));

-- 4d. Normalize marital_status
UPDATE loans
SET marital_status = INITCAP(TRIM(marital_status));

-- INITCAP() = Title Case (first letter uppercase, rest lowercase)
-- TRIM()    = removes leading/trailing whitespace


-- =============================================================================
-- SECTION 5 — VALIDATE NUMERIC RANGES
-- =============================================================================
-- Business rules define valid ranges. Violations = data entry errors or fraud.

-- 5a. Find invalid ages (banks lend to adults 18–100)
SELECT COUNT(*) AS invalid_age_count
FROM loans
WHERE age < 18 OR age > 100;

-- Fix: cap or null out extreme ages
UPDATE loans
SET age = NULL
WHERE age < 18 OR age > 100;

-- 5b. Find impossible income values (negative or zero)
SELECT COUNT(*) AS invalid_income_count
FROM loans
WHERE income <= 0;

UPDATE loans
SET income = NULL
WHERE income <= 0;

-- 5c. Find invalid credit scores (FICO scale: 300–850)
SELECT COUNT(*) AS invalid_credit_score_count
FROM loans
WHERE credit_score < 300 OR credit_score > 850;

UPDATE loans
SET credit_score = NULL
WHERE credit_score < 300 OR credit_score > 850;

-- 5d. Find invalid loan amounts (must be > 0)
SELECT COUNT(*) AS invalid_loan_count
FROM loans
WHERE loan_amount <= 0;

-- 5e. Find invalid DTI ratios (should be between 0 and 1)
SELECT COUNT(*) AS invalid_dti_count
FROM loans
WHERE dti_ratio < 0 OR dti_ratio > 1;


-- =============================================================================
-- SECTION 6 — ADD HELPER COLUMNS FOR ANALYSIS
-- =============================================================================
-- These derived columns speed up analysis queries significantly.

-- 6a. Add income bracket column
ALTER TABLE loans ADD COLUMN IF NOT EXISTS income_bracket VARCHAR(20);

UPDATE loans
SET income_bracket = CASE
    WHEN income < 30000              THEN 'Low Income'
    WHEN income BETWEEN 30000 AND 59999 THEN 'Lower Middle'
    WHEN income BETWEEN 60000 AND 99999 THEN 'Middle Income'
    WHEN income BETWEEN 100000 AND 149999 THEN 'Upper Middle'
    WHEN income >= 150000            THEN 'High Income'
    ELSE 'Unknown'
END;

-- 6b. Add credit score tier column
ALTER TABLE loans ADD COLUMN IF NOT EXISTS credit_tier VARCHAR(20);

UPDATE loans
SET credit_tier = CASE
    WHEN credit_score >= 800 THEN 'Exceptional'
    WHEN credit_score >= 740 THEN 'Very Good'
    WHEN credit_score >= 670 THEN 'Good'
    WHEN credit_score >= 580 THEN 'Fair'
    WHEN credit_score  < 580 THEN 'Poor'
    ELSE 'Unknown'
END;

-- 6c. Add loan_to_income ratio (a key underwriting metric)
ALTER TABLE loans ADD COLUMN IF NOT EXISTS loan_to_income NUMERIC(8, 4);

UPDATE loans
SET loan_to_income = ROUND(loan_amount / NULLIF(income, 0), 4);

-- NULLIF(income, 0) prevents division-by-zero errors


-- =============================================================================
-- SECTION 7 — POST-CLEANING VERIFICATION
-- =============================================================================

-- 7a. Confirm no more NULLs in critical columns
SELECT
    SUM(CASE WHEN income IS NULL THEN 1 ELSE 0 END)        AS remaining_null_income,
    SUM(CASE WHEN credit_score IS NULL THEN 1 ELSE 0 END)  AS remaining_null_credit,
    SUM(CASE WHEN default_status IS NULL THEN 1 ELSE 0 END)AS remaining_null_default
FROM loans;

-- 7b. Confirm value distributions look reasonable
SELECT
    income_bracket,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score
FROM loans
GROUP BY income_bracket
ORDER BY avg_loan DESC;

-- 7c. Final row count after cleaning
SELECT COUNT(*) AS clean_row_count FROM loans;
