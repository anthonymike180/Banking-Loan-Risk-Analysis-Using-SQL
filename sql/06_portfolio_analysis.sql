-- =============================================================================
-- FILE: 06_portfolio_analysis.sql
-- PROJECT: Banking Loan Risk Analysis Using SQL
-- DESCRIPTION: Loan portfolio performance and financial health analysis.
-- GOAL: Show what the bank earns, what it loses, and where concentration
--       risk exists — the key inputs for executive-level reporting.
-- =============================================================================


-- =============================================================================
-- QUERY 1 — FULL PORTFOLIO FINANCIAL SUMMARY
-- =============================================================================
-- The bank's P&L (Profit & Loss) view of its loan book.
-- This is the most important dashboard query.

SELECT
    -- Volume metrics
    COUNT(*)                                        AS total_loans,
    SUM(loan_amount)                                AS gross_portfolio_value,

    -- Revenue (performing loans generating interest)
    ROUND(
        SUM(CASE WHEN default_status = 0
            THEN loan_amount * interest_rate * (loan_term / 12.0)
            ELSE 0
        END), 2
    )                                               AS estimated_interest_revenue,

    -- Loss metrics
    ROUND(
        SUM(CASE WHEN default_status = 1
            THEN loan_amount
            ELSE 0
        END), 2
    )                                               AS gross_default_exposure,

    -- Assuming 40% recovery rate on defaulted loans (industry average)
    ROUND(
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.40
            ELSE 0
        END), 2
    )                                               AS estimated_recovery,

    ROUND(
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.60   -- 60% is the net loss after recovery
            ELSE 0
        END), 2
    )                                               AS estimated_net_loss,

    -- Net portfolio performance
    ROUND(
        SUM(CASE WHEN default_status = 0
            THEN loan_amount * interest_rate * (loan_term / 12.0)
            ELSE 0
        END)
        -
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.60
            ELSE 0
        END), 2
    )                                               AS estimated_net_profit,

    -- Risk ratios
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    ROUND(
        SUM(CASE WHEN default_status = 1 THEN loan_amount ELSE 0 END) * 100.0
        / SUM(loan_amount), 2
    )                                               AS loss_rate_pct

FROM loans;


-- =============================================================================
-- QUERY 2 — PORTFOLIO PERFORMANCE BY LOAN PURPOSE
-- =============================================================================
-- Which loan categories are profit centers vs. loss centers?

SELECT
    loan_purpose,
    COUNT(*)                                        AS loan_count,
    ROUND(SUM(loan_amount), 2)                      AS total_exposure,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_interest_rate_pct,
    ROUND(
        SUM(CASE WHEN default_status = 0
            THEN loan_amount * interest_rate * (loan_term / 12.0)
            ELSE 0
        END), 2
    )                                               AS est_interest_revenue,
    ROUND(
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.60
            ELSE 0
        END), 2
    )                                               AS est_net_loss,
    SUM(default_status)                             AS defaults,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    -- Net contribution per loan category
    ROUND(
        SUM(CASE WHEN default_status = 0
            THEN loan_amount * interest_rate * (loan_term / 12.0)
            ELSE 0
        END)
        -
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.60
            ELSE 0
        END), 2
    )                                               AS net_contribution
FROM loans
GROUP BY loan_purpose
ORDER BY net_contribution DESC;


-- =============================================================================
-- QUERY 3 — PORTFOLIO CONCENTRATION RISK
-- =============================================================================
-- Concentration risk = too much exposure in one segment.
-- Regulators require banks to diversify to prevent systemic risk.

WITH exposure_by_segment AS (
    SELECT
        income_bracket                              AS segment,
        'Income Bracket'                            AS segment_type,
        COUNT(*)                                    AS loan_count,
        SUM(loan_amount)                            AS total_exposure
    FROM loans
    GROUP BY income_bracket

    UNION ALL

    SELECT
        employment_type,
        'Employment Type',
        COUNT(*),
        SUM(loan_amount)
    FROM loans
    GROUP BY employment_type

    UNION ALL

    SELECT
        loan_purpose,
        'Loan Purpose',
        COUNT(*),
        SUM(loan_amount)
    FROM loans
    GROUP BY loan_purpose
)
SELECT
    segment_type,
    segment,
    loan_count,
    ROUND(total_exposure, 2)                        AS total_exposure,
    ROUND(
        total_exposure * 100.0
        / SUM(total_exposure) OVER (PARTITION BY segment_type), 2
    )                                               AS pct_of_segment_total
FROM exposure_by_segment
ORDER BY segment_type, total_exposure DESC;

-- SQL CONCEPT: Window function with PARTITION BY
-- PARTITION BY segment_type means the percentage is calculated
-- WITHIN each segment type (not across all rows).
-- This lets us see concentration within income brackets vs. employment types separately.


-- =============================================================================
-- QUERY 4 — LOAN TERM PROFITABILITY ANALYSIS
-- =============================================================================
-- Longer terms earn more interest but expose the bank to risk for longer.

SELECT
    loan_term                                       AS term_months,
    COUNT(*)                                        AS loan_count,
    ROUND(AVG(loan_amount), 2)                      AS avg_loan_amount,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_interest_rate_pct,
    -- Simple interest calculation over the loan term
    ROUND(AVG(loan_amount * interest_rate * (loan_term / 12.0)), 2)
                                                    AS avg_est_interest_per_loan,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,
    -- Net Revenue: interest earned minus expected losses
    ROUND(
        SUM(CASE WHEN default_status = 0
            THEN loan_amount * interest_rate * (loan_term / 12.0)
            ELSE 0
        END)
        -
        SUM(CASE WHEN default_status = 1
            THEN loan_amount * 0.60
            ELSE 0
        END), 2
    )                                               AS total_net_revenue
FROM loans
GROUP BY loan_term
ORDER BY loan_term;


-- =============================================================================
-- QUERY 5 — RISK-ADJUSTED RETURN BY INCOME BRACKET
-- =============================================================================
-- Banks want high returns relative to the risk taken.
-- This query calculates a simple Risk-Adjusted Return metric.

SELECT
    income_bracket,
    COUNT(*)                                        AS loan_count,
    ROUND(SUM(loan_amount), 2)                      AS total_exposure,
    ROUND(AVG(interest_rate) * 100, 2)              AS avg_rate_pct,
    ROUND(AVG(default_status) * 100, 2)             AS default_rate_pct,

    -- Risk-Adjusted Return = (Interest Rate % - Default Rate %)
    -- A positive value means the interest earned exceeds expected losses.
    ROUND(
        AVG(interest_rate) * 100 - AVG(default_status) * 100, 2
    )                                               AS risk_adj_return_pct,

    CASE
        WHEN AVG(interest_rate) * 100 - AVG(default_status) * 100 >= 5
            THEN 'Highly Profitable'
        WHEN AVG(interest_rate) * 100 - AVG(default_status) * 100 >= 0
            THEN 'Marginally Profitable'
        ELSE
            'Loss-Making Segment'
    END                                             AS profitability_status

FROM loans
GROUP BY income_bracket
ORDER BY risk_adj_return_pct DESC;
