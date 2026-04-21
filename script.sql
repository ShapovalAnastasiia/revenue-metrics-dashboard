WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', gp.payment_date)::date AS payment_month,
        gp.user_id,
        gp.game_name,
        SUM(gp.revenue_amount_usd) AS total_revenue
    FROM project.games_payments gp
    GROUP BY 1, 2, 3
),
settlement_months AS (
    SELECT
        mr.*,
        LAG(payment_month) OVER (PARTITION BY user_id, game_name ORDER BY payment_month) AS previous_paid_month,
        LEAD(payment_month) OVER (PARTITION BY user_id, game_name ORDER BY payment_month) AS next_paid_month,
        LAG(total_revenue) OVER (PARTITION BY user_id, game_name ORDER BY payment_month) AS previous_paid_month_revenue,
        (payment_month - INTERVAL '1 month')::date AS previous_calendar_month,
        (payment_month + INTERVAL '1 month')::date AS next_calendar_month
    FROM monthly_revenue mr
)
SELECT
    s.*,
    u.age,
    u.language,
    -- New MRR / New Paid Users
    CASE WHEN previous_paid_month IS NULL THEN total_revenue END AS new_mrr,
    CASE WHEN previous_paid_month IS NULL THEN 1 ELSE 0 END AS is_new_user,
    
    -- Back from Churn (Reactivation)
    CASE WHEN previous_paid_month IS NOT NULL AND previous_paid_month != previous_calendar_month 
         THEN total_revenue END AS back_from_churn_mrr,

    -- Churned Revenue / Users
    CASE WHEN next_paid_month IS NULL OR next_paid_month != next_calendar_month 
         THEN total_revenue END AS churned_revenue,
    CASE WHEN next_paid_month IS NULL OR next_paid_month != next_calendar_month 
         THEN 1 ELSE 0 END AS is_churned_user,
         
    -- Expansion / Contraction
    CASE WHEN previous_paid_month = previous_calendar_month AND total_revenue > previous_paid_month_revenue 
         THEN total_revenue - previous_paid_month_revenue END AS expansion_mrr,
    CASE WHEN previous_paid_month = previous_calendar_month AND total_revenue < previous_paid_month_revenue 
         THEN total_revenue - previous_paid_month_revenue END AS contraction_mrr
FROM settlement_months s
LEFT JOIN project.games_paid_users u 
    ON s.user_id = u.user_id AND s.game_name = u.game_name;