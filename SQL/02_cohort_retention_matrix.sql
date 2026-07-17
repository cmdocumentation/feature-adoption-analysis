-- Query 2: Cohort Retention Matrix
-- Output: Retention rates by signup cohort (week), adoption segment, and observation windows (7/14/30/60/90 days)

WITH first_core_action AS (
    SELECT 
        u.user_id,
        MIN(ue.event_date) AS first_action_date
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    WHERE ue.event_type IN ('created_report', 'imported_report')
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
        COUNT(DISTINCT CASE 
            WHEN ue.event_date <= u.signup_date + INTERVAL '14 days' 
            AND ue.event_type IN ('updated_settings', 'created_report', 'imported_report', 'ran_dashboard_export', 'applied_filter', 'shared_report', 'invited_team_member')
            THEN ue.event_type 
        END) AS feature_breadth
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
        DATE_TRUNC('week', signup_date) AS signup_week,
        CASE WHEN time_to_value <= 7 AND feature_breadth >= 4 THEN 'High Adoption' ELSE 'Low Adoption' END AS adoption_segment
    FROM user_activity_profile
),
retention_windows AS (
    SELECT 
        adoption_segment,
        signup_week,
        COUNT(*) AS cohort_size,
        SUM(CASE WHEN churn_date IS NULL OR CAST(churn_date - signup_date AS INTEGER) > 7 THEN 1 ELSE 0 END) AS retained_day_7,
        SUM(CASE WHEN churn_date IS NULL OR CAST(churn_date - signup_date AS INTEGER) > 14 THEN 1 ELSE 0 END) AS retained_day_14,
        SUM(CASE WHEN churn_date IS NULL OR CAST(churn_date - signup_date AS INTEGER) > 30 THEN 1 ELSE 0 END) AS retained_day_30,
        SUM(CASE WHEN churn_date IS NULL OR CAST(churn_date - signup_date AS INTEGER) > 60 THEN 1 ELSE 0 END) AS retained_day_60,
        SUM(CASE WHEN churn_date IS NULL OR CAST(churn_date - signup_date AS INTEGER) > 90 THEN 1 ELSE 0 END) AS retained_day_90
    FROM adoption_segments
    GROUP BY adoption_segment, signup_week
)
SELECT 
    signup_week,
    adoption_segment,
    day_label,
    sort_order,
    retention_pct
FROM (
    SELECT 
        signup_week,
        adoption_segment,
        'Day 7' AS day_label,
        1 AS sort_order,
        ROUND(100.0 * retained_day_7 / NULLIF(cohort_size, 0), 1) AS retention_pct,
        CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END AS adoption_rank
    FROM retention_windows

    UNION ALL
    SELECT 
        signup_week,
        adoption_segment,
        'Day 14' AS day_label,
        2 AS sort_order,
        ROUND(100.0 * retained_day_14 / NULLIF(cohort_size, 0), 1),
        CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
    FROM retention_windows

    UNION ALL
    SELECT 
        signup_week,
        adoption_segment,
        'Day 30' AS day_label,
        3 AS sort_order,
        ROUND(100.0 * retained_day_30 / NULLIF(cohort_size, 0), 1),
        CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
    FROM retention_windows

    UNION ALL
    SELECT 
        signup_week,
        adoption_segment,
        'Day 60' AS day_label,
        4 AS sort_order,
        ROUND(100.0 * retained_day_60 / NULLIF(cohort_size, 0), 1),
        CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
    FROM retention_windows

    UNION ALL
    SELECT 
        signup_week,
        adoption_segment,
        'Day 90' AS day_label,
        5 AS sort_order,
        ROUND(100.0 * retained_day_90 / NULLIF(cohort_size, 0), 1),
        CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
    FROM retention_windows
) t
ORDER BY t.signup_week, t.adoption_rank, t.sort_order;
