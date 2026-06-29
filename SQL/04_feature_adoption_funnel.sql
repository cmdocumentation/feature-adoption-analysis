-- Query 4: Feature Adoption Funnel (30-Day Window)
-- Output: Step-by-step user counts and conversion % by plan tier (signup → created report → exported report → invited team member → viewed help docs)

WITH funnel_steps AS (
    SELECT 
        u.plan_tier,
        CASE ue.event_type
            WHEN 'created_report' THEN 'Created Report'
            WHEN 'ran_dashboard_export' THEN 'Exported Report'
            WHEN 'invited_team_member' THEN 'Invited Team Member'
            WHEN 'viewed_help_docs' THEN 'Viewed Help Docs'
        END AS step_name,
        CASE ue.event_type
            WHEN 'created_report' THEN 2
            WHEN 'ran_dashboard_export' THEN 3
            WHEN 'invited_team_member' THEN 4
            WHEN 'viewed_help_docs' THEN 5
        END AS step_order,
        COUNT(DISTINCT u.user_id) AS count
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
        AND ue.event_date <= DATE(u.signup_date, '+30 days')
        AND ue.event_type IN ('created_report', 'ran_dashboard_export', 'invited_team_member', 'viewed_help_docs')
    GROUP BY u.plan_tier, ue.event_type

    UNION ALL

    SELECT 
        u.plan_tier,
        'Signed Up' AS step_name,
        1 AS step_order,
        COUNT(DISTINCT u.user_id) AS count
    FROM users u
    GROUP BY u.plan_tier
)

SELECT 
    plan_tier,
    step_name,
    count,
    step_order,
    ROUND(100.0 * count / LAG(count) OVER (PARTITION BY plan_tier ORDER BY step_order), 1) AS pct_of_prev_step
FROM funnel_steps
WHERE step_name IS NOT NULL
ORDER BY plan_tier, step_order;
