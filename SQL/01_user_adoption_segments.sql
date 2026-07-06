-- Query 1: User Adoption Segments (High/Low Cohorts)
-- Output: User signup, churn date, plan tier (1-4), status (active/cancelled), adoption segment (high/low), days active, and 30-day churn flags

WITH first_core_action AS (
    -- Earliest date a user took a core product action
    SELECT 
        user_id,
        MIN(event_date::date) AS first_action_date
    FROM user_events
    WHERE event_type IN ('created_report', 'invited_team_member', 'ran_dashboard_export', 'imported_report')
    GROUP BY user_id
),
user_metrics AS (
    -- Feature adoption metrics within first 14 days
    SELECT 
        u.user_id,
        u.signup_date,
        u.churn_date,
        u.plan_tier,
        u.status,
        CASE 
            WHEN fca.first_action_date IS NOT NULL
            THEN fca.first_action_date - u.signup_date::date
            ELSE NULL
        END AS time_to_value,
        COUNT(DISTINCT CASE 
            WHEN ue.event_date::date <= u.signup_date::date + INTERVAL '14 days'
            THEN ue.event_type 
        END) AS feature_breadth,
        MAX(CASE 
            WHEN ue.event_type = 'viewed_help_docs' 
             AND ue.event_date::date <= u.signup_date::date + INTERVAL '14 days'
            THEN 1 
            ELSE 0 
        END) AS documentation_viewed
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    LEFT JOIN first_core_action fca ON u.user_id = fca.user_id
    GROUP BY u.user_id, u.signup_date, u.churn_date, u.plan_tier, u.status, fca.first_action_date
)
SELECT 
    user_id,
    signup_date,
    churn_date,
    plan_tier,
    status,
    CASE 
        WHEN time_to_value IS NOT NULL
         AND time_to_value <= 7 
         AND feature_breadth >= 4 
        THEN 'High Adoption'
        ELSE 'Low Adoption'
    END AS adoption_segment,
    CASE 
        WHEN churn_date IS NOT NULL 
         AND (churn_date::date - signup_date::date) <= 30
        THEN 1 
        ELSE 0 
    END AS churned_by_day_30,
    -- Days active: either days until churn, or days until observation date
    CASE 
        WHEN churn_date IS NOT NULL 
        THEN churn_date::date - signup_date::date
        ELSE '2025-05-28'::date - signup_date::date
    END AS days_active,
    time_to_value,
    feature_breadth,
    documentation_viewed
FROM user_metrics
ORDER BY user_id;

