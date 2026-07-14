-- Query 2: Cohort Retention Matrix  
-- Output: Retention % by signup week, adoption segment (high/low), and day (7, 30, 60, 90)

WITH user_metrics AS (
  SELECT
    u.user_id,
    u.signup_date,
    u.churn_date,
    u.plan_tier,
    u.status,

    MIN(CASE
      WHEN ue.event_type IN ('created_report', 'invited_team_member',
                              'ran_dashboard_export', 'imported_report')
      THEN ue.event_date
    END) AS first_core_action,

    COUNT(DISTINCT CASE
      WHEN ue.event_date <= u.signup_date + INTERVAL '14 days'
      THEN ue.event_type
    END) AS feature_breadth
  FROM users u
  LEFT JOIN user_events ue
    ON ue.user_id = u.user_id
  GROUP BY u.user_id, u.signup_date, u.churn_date, u.plan_tier, u.status
),
first_action_ttv AS (
  SELECT
    user_id,
    signup_date,
    churn_date,
    feature_breadth,

    CAST(
      (CAST(first_core_action AS DATE) - CAST(signup_date AS DATE))
      AS INTEGER
    ) AS time_to_value
  FROM user_metrics
),
user_cohorts AS (
  SELECT
    signup_date,
    CAST(DATE_TRUNC('week', signup_date) AS DATE) AS week_start_date,

    CASE
      WHEN time_to_value <= 7 AND feature_breadth >= 4
      THEN 'High Adoption'
      ELSE 'Low Adoption'
    END AS adoption_segment,

    CAST(COALESCE(churn_date, DATE '2025-05-28') - signup_date AS INTEGER) AS days_active
  FROM first_action_ttv
),
cohort_retention AS (
  SELECT
    week_start_date,
    adoption_segment,
    COUNT(*) AS cohort_size,
    SUM(CASE WHEN days_active >= 7  THEN 1 ELSE 0 END) AS day_7_retained,
    SUM(CASE WHEN days_active >= 30 THEN 1 ELSE 0 END) AS day_30_retained,
    SUM(CASE WHEN days_active >= 60 THEN 1 ELSE 0 END) AS day_60_retained,
    SUM(CASE WHEN days_active >= 90 THEN 1 ELSE 0 END) AS day_90_retained
  FROM user_cohorts
  GROUP BY week_start_date, adoption_segment
)
SELECT
  t.signup_week,
  t.adoption_segment,
  t.day_label,
  t.sort_order,
  t.retention_pct
FROM (
  SELECT
    week_start_date AS signup_week,
    adoption_segment,
    'Day 7' AS day_label,
    1 AS sort_order,
    ROUND(100.0 * day_7_retained / NULLIF(cohort_size, 0), 1) AS retention_pct,
    CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END AS adoption_rank
  FROM cohort_retention

  UNION ALL
  SELECT
    week_start_date,
    adoption_segment,
    'Day 30',
    2,
    ROUND(100.0 * day_30_retained / NULLIF(cohort_size, 0), 1),
    CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
  FROM cohort_retention

  UNION ALL
  SELECT
    week_start_date,
    adoption_segment,
    'Day 60',
    3,
    ROUND(100.0 * day_60_retained / NULLIF(cohort_size, 0), 1),
    CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
  FROM cohort_retention

  UNION ALL
  SELECT
    week_start_date,
    adoption_segment,
    'Day 90',
    4,
    ROUND(100.0 * day_90_retained / NULLIF(cohort_size, 0), 1),
    CASE WHEN adoption_segment = 'High Adoption' THEN 1 ELSE 2 END
  FROM cohort_retention
) t
ORDER BY t.signup_week, t.adoption_rank, t.sort_order;
