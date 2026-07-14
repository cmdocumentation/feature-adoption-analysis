-- Query 1: User Adoption Segments with 30/60/90-Day Churn Rates
-- Output: Churn rates by plan tier (1-4), adoption segment (high vs. low), and time period (30/60/90 days)

WITH first_core_action AS (
    SELECT 
        u.user_id,
        MIN(ue.event_date) AS first_action_date
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    WHERE ue.event_type IN ('created_report', 'invited_team_member', 'ran_dashboard_export', 'imported_report')
    GROUP BY u.user_id
),
user_activity_profile AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.churn_date,
        u.plan_tier,
        u.status,
        CAST(fca.first_action_date - u.signup_date AS INTEGER) AS time_to_value,
        COUNT(DISTINCT CASE WHEN ue.event_date <= u.signup_date + INTERVAL '14 days' THEN ue.event_type END) AS feature_breadth
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    LEFT JOIN first_core_action fca ON u.user_id = fca.user_id
    GROUP BY u.user_id, u.signup_date, u.churn_date, u.plan_tier, u.status, fca.first_action_date
),
adoption_segments AS (
    SELECT 
        user_id,
        signup_date,
        churn_date,
        plan_tier,
        CASE WHEN time_to_value <= 7 AND feature_breadth >= 4 THEN 'High Adoption' ELSE 'Low Adoption' END AS adoption_segment,
        CASE WHEN churn_date IS NOT NULL AND CAST(churn_date - signup_date AS INTEGER) <= 30 THEN 1 ELSE 0 END AS churned_30,
        CASE WHEN churn_date IS NOT NULL AND CAST(churn_date - signup_date AS INTEGER) > 30 AND CAST(churn_date - signup_date AS INTEGER) <= 60 THEN 1 ELSE 0 END AS churned_60,
        CASE WHEN churn_date IS NOT NULL AND CAST(churn_date - signup_date AS INTEGER) > 60 AND CAST(churn_date - signup_date AS INTEGER) <= 90 THEN 1 ELSE 0 END AS churned_90
    FROM user_activity_profile
)
SELECT 
    adoption_segment,
    plan_tier,
    COUNT(*) AS total_users,
    SUM(CASE WHEN churn_date IS NOT NULL THEN 1 ELSE 0 END) AS total_churned,
    ROUND(100.0 * SUM(CASE WHEN churn_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS overall_churn_rate,
    SUM(churned_30) AS churned_by_day_30,
    ROUND(100.0 * SUM(churned_30) / COUNT(*), 1) AS churn_rate_30,
    SUM(churned_60) AS churned_day_31_60,
    ROUND(100.0 * SUM(churned_60) / COUNT(*), 1) AS churn_rate_60,
    SUM(churned_90) AS churned_day_61_90,
    ROUND(100.0 * SUM(churned_90) / COUNT(*), 1) AS churn_rate_90
FROM adoption_segments
GROUP BY adoption_segment, plan_tier
ORDER BY adoption_segment, plan_tier;
