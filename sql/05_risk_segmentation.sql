-- =============================================================================
-- FILE: 05_risk_segmentation.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Segments borrowers into risk categories for targeted action.
-- GOAL: Classify every borrower into Low / Medium / High risk tiers so
--       the bank can apply appropriate pricing, limits, and monitoring.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — SIMPLE RISK SEGMENTATION (Single-Factor)
-- =============================================================================
-- Start with credit score alone — the baseline risk signal.

SELECT
    loan_id,
    credit_score,
    CASE
        WHEN credit_score >= 740 THEN 'Low Risk'
        WHEN credit_score BETWEEN 580 AND 739 THEN 'Medium Risk'
        WHEN credit_score  < 580 THEN 'High Risk'
        ELSE 'Unclassified'
    END                                             AS credit_risk_tier,
    loan_amount,
    income,
    default_status
FROM loans
LIMIT 20;


-- =============================================================================
-- SECTION 2 — MULTI-FACTOR RISK SEGMENTATION
-- =============================================================================
-- Real credit risk models use multiple factors simultaneously.
-- This query uses CASE logic across 4 risk dimensions.

SELECT
    loan_id,
    income,
    loan_amount,
    credit_score,
    dti_ratio,
    employment_type,
    default_status,

    -- RISK DIMENSION 1: Credit Score Risk
    CASE
        WHEN credit_score >= 740 THEN 'Credit: Low'
        WHEN credit_score >= 580 THEN 'Credit: Medium'
        ELSE                          'Credit: High'
    END                                             AS credit_risk,

    -- RISK DIMENSION 2: Income Risk
    CASE
        WHEN income >= 100000 THEN 'Income: Low'
        WHEN income >=  50000 THEN 'Income: Medium'
        ELSE                       'Income: High'
    END                                             AS income_risk,

    -- RISK DIMENSION 3: Debt Burden Risk
    CASE
        WHEN dti_ratio < 0.30 THEN 'DTI: Low'
        WHEN dti_ratio < 0.50 THEN 'DTI: Medium'
        ELSE                       'DTI: High'
    END                                             AS dti_risk,

    -- RISK DIMENSION 4: Employment Stability Risk
    CASE
        WHEN employment_type = 'Full-Time'  THEN 'Employment: Low'
        WHEN employment_type = 'Part-Time'  THEN 'Employment: Medium'
        WHEN employment_type = 'Self-Employed' THEN 'Employment: High'
        ELSE                                   'Employment: Unknown'
    END                                             AS employment_risk

FROM loans
LIMIT 20;


-- =============================================================================
-- SECTION 3 — COMPOSITE RISK SCORE + FINAL RISK TIER (CTE Pattern)
-- =============================================================================
-- This is the heart of risk segmentation: a weighted scoring model.
-- Each factor contributes a risk point. Higher score = higher risk.
--
-- SCORING LOGIC:
-- ┌──────────────────────────┬──────────────────────────────────────┐
-- │ Condition                │ Risk Points                          │
-- ├──────────────────────────┼──────────────────────────────────────┤
-- │ Credit Score < 580       │ +3 points (critical signal)          │
-- │ Credit Score 580–739     │ +1 point                             │
-- │ Income < $30,000         │ +2 points                            │
-- │ Income $30K–$60K         │ +1 point                             │
-- │ DTI ratio > 0.50         │ +3 points (critically over-leveraged)│
-- │ DTI ratio 0.35–0.50      │ +1 point                             │
-- │ Employment = Self-Emp.   │ +2 points                            │
-- │ Employment = Unemployed  │ +3 points                            │
-- │ Loan-to-Income > 5x      │ +2 points                            │
-- │ Loan-to-Income 3x–5x     │ +1 point                             │
-- │ No cosigner              │ +1 point                             │
-- └──────────────────────────┴──────────────────────────────────────┘

WITH risk_scores AS (
    SELECT
        loan_id,
        age,
        income,
        loan_amount,
        credit_score,
        dti_ratio,
        employment_type,
        has_cosigner,
        loan_to_income,
        default_status,
        income_bracket,
        credit_tier,

        -- Calculate raw risk score
        (
            -- Credit score component (max 3 pts)
            CASE
                WHEN credit_score  < 580 THEN 3
                WHEN credit_score >= 580 AND credit_score < 740 THEN 1
                ELSE 0
            END

            -- Income component (max 2 pts)
          + CASE
                WHEN income < 30000  THEN 2
                WHEN income < 60000  THEN 1
                ELSE 0
            END

            -- DTI ratio component (max 3 pts)
          + CASE
                WHEN dti_ratio > 0.50 THEN 3
                WHEN dti_ratio > 0.35 THEN 1
                ELSE 0
            END

            -- Employment stability component (max 3 pts)
          + CASE
                WHEN employment_type = 'Unemployed'    THEN 3
                WHEN employment_type = 'Self-Employed' THEN 2
                WHEN employment_type = 'Part-Time'     THEN 1
                ELSE 0
            END

            -- Loan-to-income component (max 2 pts)
          + CASE
                WHEN loan_to_income > 5 THEN 2
                WHEN loan_to_income > 3 THEN 1
                ELSE 0
            END

            -- Cosigner component (max 1 pt)
          + CASE
                WHEN has_cosigner = FALSE THEN 1
                ELSE 0
            END
        )                                               AS risk_score

    FROM loans
),

risk_classified AS (
    SELECT
        *,
        -- Classify into tiers based on total score (max possible = 14)
        CASE
            WHEN risk_score <= 2  THEN 'Low Risk'
            WHEN risk_score <= 5  THEN 'Medium Risk'
            WHEN risk_score <= 8  THEN 'High Risk'
            ELSE                       'Very High Risk'
        END                                             AS risk_tier
    FROM risk_scores
)

SELECT
    loan_id,
    income,
    loan_amount,
    credit_score,
    ROUND(dti_ratio * 100, 1)                       AS dti_pct,
    employment_type,
    has_cosigner,
    ROUND(loan_to_income, 2)                        AS loan_to_income_ratio,
    risk_score,
    risk_tier,
    default_status
FROM risk_classified
ORDER BY risk_score DESC, loan_amount DESC;


-- =============================================================================
-- SECTION 4 — RISK TIER SUMMARY TABLE
-- =============================================================================
-- After classifying every borrower, summarize each tier's characteristics.
-- This validates whether the scoring model actually predicts defaults.

WITH risk_scores AS (
    SELECT
        loan_id,
        income,
        loan_amount,
        credit_score,
        dti_ratio,
        employment_type,
        has_cosigner,
        loan_to_income,
        default_status,
        (
            CASE WHEN credit_score  < 580 THEN 3 WHEN credit_score < 740 THEN 1 ELSE 0 END
          + CASE WHEN income < 30000 THEN 2 WHEN income < 60000 THEN 1 ELSE 0 END
          + CASE WHEN dti_ratio > 0.50 THEN 3 WHEN dti_ratio > 0.35 THEN 1 ELSE 0 END
          + CASE WHEN employment_type = 'Unemployed' THEN 3
                 WHEN employment_type = 'Self-Employed' THEN 2
                 WHEN employment_type = 'Part-Time' THEN 1 ELSE 0 END
          + CASE WHEN loan_to_income > 5 THEN 2 WHEN loan_to_income > 3 THEN 1 ELSE 0 END
          + CASE WHEN has_cosigner = FALSE THEN 1 ELSE 0 END
        ) AS risk_score
    FROM loans
),
risk_classified AS (
    SELECT *,
        CASE
            WHEN risk_score <= 2  THEN 'Low Risk'
            WHEN risk_score <= 5  THEN 'Medium Risk'
            WHEN risk_score <= 8  THEN 'High Risk'
            ELSE                       'Very High Risk'
        END AS risk_tier
    FROM risk_scores
)
SELECT
    risk_tier,
    COUNT(*)                                        AS total_borrowers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_portfolio,
    ROUND(AVG(credit_score), 0)                     AS avg_credit_score,
    ROUND(AVG(income), 2)                           AS avg_income,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(dti_ratio) * 100, 2)                  AS avg_dti_pct,
    ROUND(AVG(default_status) * 100, 2)             AS actual_default_rate_pct,
    SUM(default_status)                             AS total_defaults,
    ROUND(SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END), 2)
                                                    AS defaulted_exposure
FROM risk_classified
GROUP BY risk_tier
ORDER BY
    CASE risk_tier
        WHEN 'Low Risk'       THEN 1
        WHEN 'Medium Risk'    THEN 2
        WHEN 'High Risk'      THEN 3
        WHEN 'Very High Risk' THEN 4
    END;

-- MODEL VALIDATION:
-- If the model is working well, we expect:
-- Low Risk     → default rate < 5%
-- Medium Risk  → default rate 5–15%
-- High Risk    → default rate 15–30%
-- Very High Risk → default rate > 30%


-- =============================================================================
-- SECTION 5 — SAVE RISK SCORES AS A VIEW (for reuse in other queries)
-- =============================================================================
-- Creating a VIEW lets other queries reference risk tiers without repeating logic.

CREATE OR REPLACE VIEW vw_borrower_risk AS
SELECT
    loan_id,
    age,
    income,
    loan_amount,
    credit_score,
    dti_ratio,
    employment_type,
    has_cosigner,
    loan_to_income,
    income_bracket,
    credit_tier,
    default_status,
    (
        CASE WHEN credit_score  < 580 THEN 3 WHEN credit_score < 740 THEN 1 ELSE 0 END
      + CASE WHEN income < 30000 THEN 2 WHEN income < 60000 THEN 1 ELSE 0 END
      + CASE WHEN dti_ratio > 0.50 THEN 3 WHEN dti_ratio > 0.35 THEN 1 ELSE 0 END
      + CASE WHEN employment_type = 'Unemployed' THEN 3
             WHEN employment_type = 'Self-Employed' THEN 2
             WHEN employment_type = 'Part-Time' THEN 1 ELSE 0 END
      + CASE WHEN loan_to_income > 5 THEN 2 WHEN loan_to_income > 3 THEN 1 ELSE 0 END
      + CASE WHEN has_cosigner = FALSE THEN 1 ELSE 0 END
    )                                               AS risk_score,
    CASE
        WHEN (
            CASE WHEN credit_score  < 580 THEN 3 WHEN credit_score < 740 THEN 1 ELSE 0 END
          + CASE WHEN income < 30000 THEN 2 WHEN income < 60000 THEN 1 ELSE 0 END
          + CASE WHEN dti_ratio > 0.50 THEN 3 WHEN dti_ratio > 0.35 THEN 1 ELSE 0 END
          + CASE WHEN employment_type = 'Unemployed' THEN 3
                 WHEN employment_type = 'Self-Employed' THEN 2
                 WHEN employment_type = 'Part-Time' THEN 1 ELSE 0 END
          + CASE WHEN loan_to_income > 5 THEN 2 WHEN loan_to_income > 3 THEN 1 ELSE 0 END
          + CASE WHEN has_cosigner = FALSE THEN 1 ELSE 0 END
        ) <= 2 THEN 'Low Risk'
        WHEN (
            CASE WHEN credit_score  < 580 THEN 3 WHEN credit_score < 740 THEN 1 ELSE 0 END
          + CASE WHEN income < 30000 THEN 2 WHEN income < 60000 THEN 1 ELSE 0 END
          + CASE WHEN dti_ratio > 0.50 THEN 3 WHEN dti_ratio > 0.35 THEN 1 ELSE 0 END
          + CASE WHEN employment_type = 'Unemployed' THEN 3
                 WHEN employment_type = 'Self-Employed' THEN 2
                 WHEN employment_type = 'Part-Time' THEN 1 ELSE 0 END
          + CASE WHEN loan_to_income > 5 THEN 2 WHEN loan_to_income > 3 THEN 1 ELSE 0 END
          + CASE WHEN has_cosigner = FALSE THEN 1 ELSE 0 END
        ) <= 5 THEN 'Medium Risk'
        WHEN (
            CASE WHEN credit_score  < 580 THEN 3 WHEN credit_score < 740 THEN 1 ELSE 0 END
          + CASE WHEN income < 30000 THEN 2 WHEN income < 60000 THEN 1 ELSE 0 END
          + CASE WHEN dti_ratio > 0.50 THEN 3 WHEN dti_ratio > 0.35 THEN 1 ELSE 0 END
          + CASE WHEN employment_type = 'Unemployed' THEN 3
                 WHEN employment_type = 'Self-Employed' THEN 2
                 WHEN employment_type = 'Part-Time' THEN 1 ELSE 0 END
          + CASE WHEN loan_to_income > 5 THEN 2 WHEN loan_to_income > 3 THEN 1 ELSE 0 END
          + CASE WHEN has_cosigner = FALSE THEN 1 ELSE 0 END
        ) <= 8 THEN 'High Risk'
        ELSE 'Very High Risk'
    END                                             AS risk_tier
FROM loans;

-- Verify the view:
SELECT risk_tier, COUNT(*), ROUND(AVG(default_status)*100,2) AS default_rate_pct
FROM vw_borrower_risk
GROUP BY risk_tier
ORDER BY default_rate_pct;
