-- Query 3: Cohort Retention Matrix  
-- Output: Retention % by signup week, adoption segment (high/low), and day (7, 30, 60, 90)

WITH user_metrics AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.churn_date,
        u.plan_tier,
        u.status,
        
        CAST((
            JULIANDAY(
                MIN(CASE 
                    WHEN ue.event_type IN ('created_report', 'invited_team_member') 
                    THEN ue.event_date 
                END)
            ) - JULIANDAY(u.signup_date)
        ) AS INTEGER) AS time_to_value,
        
        COUNT(DISTINCT 
            CASE 
                WHEN ue.event_date <= DATE(u.signup_date, '+14 days')
                THEN ue.event_type 
                ELSE NULL 
            END
        ) AS feature_breadth,
        
        MAX(CASE 
            WHEN ue.event_type = 'viewed_help_docs' 
             AND ue.event_date <= DATE(u.signup_date, '+14 days')
            THEN 1 
            ELSE 0 
        END) AS documentation_viewed
        
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    GROUP BY u.user_id, u.signup_date, u.churn_date, u.plan_tier, u.status
),

user_cohorts AS (
    SELECT 
        user_id,
        signup_date,
        DATE(signup_date, 'weekday 0', '-6 days') AS week_start_date,
        
        CASE 
            WHEN time_to_value <= 7 
             AND feature_breadth >= 3 
             AND documentation_viewed = 1 
            THEN 'High Adoption'
            ELSE 'Low Adoption'
        END AS adoption_segment,
        
        CAST((JULIANDAY(COALESCE(churn_date, '2025-05-28')) - JULIANDAY(signup_date)) AS INTEGER) 
            AS days_active
            
    FROM user_metrics
),

cohort_retention AS (
    SELECT 
        week_start_date,
        adoption_segment,
        COUNT(*) AS cohort_size,
        SUM(CASE WHEN days_active >= 7 THEN 1 ELSE 0 END) AS day_7_retained,
        SUM(CASE WHEN days_active >= 30 THEN 1 ELSE 0 END) AS day_30_retained,
        SUM(CASE WHEN days_active >= 60 THEN 1 ELSE 0 END) AS day_60_retained,
        SUM(CASE WHEN days_active >= 90 THEN 1 ELSE 0 END) AS day_90_retained
        
    FROM user_cohorts
    GROUP BY week_start_date, adoption_segment
)

SELECT 
    week_start_date AS signup_week,
    adoption_segment,
    'Day 7' AS day_label,
    1 AS sort_order,
    ROUND(100.0 * day_7_retained / cohort_size, 1) AS retention_pct
FROM cohort_retention

UNION ALL

SELECT 
    week_start_date AS signup_week,
    adoption_segment,
    'Day 30' AS day_label,
    2 AS sort_order,
    ROUND(100.0 * day_30_retained / cohort_size, 1) AS retention_pct
FROM cohort_retention

UNION ALL

SELECT 
    week_start_date AS signup_week,
    adoption_segment,
    'Day 60' AS day_label,
    3 AS sort_order,
    ROUND(100.0 * day_60_retained / cohort_size, 1) AS retention_pct
FROM cohort_retention

UNION ALL

SELECT 
    week_start_date AS signup_week,
    adoption_segment,
    'Day 90' AS day_label,
    4 AS sort_order,
    ROUND(100.0 * day_90_retained / cohort_size, 1) AS retention_pct
FROM cohort_retention

ORDER BY signup_week, adoption_segment, sort_order;

