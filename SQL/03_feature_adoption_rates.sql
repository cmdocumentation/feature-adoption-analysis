-- Query 4: Feature Adoption Rates
-- Measures adoption rates for key product features within a user's first 30 days, broken down by plan tier (1-4), relative to the signed-up baseline.

WITH user_milestones AS (
  -- Step 1: For each user + tier, flag whether they hit each milestone within 30 days of signup
  SELECT
    u.plan_tier,
    u.user_id,

    MAX(CASE WHEN ue.event_type = 'created_report'        THEN 1 ELSE 0 END) AS did_report,
    MAX(CASE WHEN ue.event_type = 'ran_dashboard_export'  THEN 1 ELSE 0 END) AS did_export,
    MAX(CASE WHEN ue.event_type = 'invited_team_member'  THEN 1 ELSE 0 END) AS did_invite,
    MAX(CASE WHEN ue.event_type = 'viewed_help_docs'      THEN 1 ELSE 0 END) AS did_docs
  FROM users u
  LEFT JOIN user_events ue
    ON ue.user_id = u.user_id
   AND ue.event_date <= (u.signup_date + INTERVAL '30 days')
  GROUP BY u.plan_tier, u.user_id
),

funnel_tallies AS (
  -- Step 2: Count distinct users who completed each milestone
  SELECT
    plan_tier,
    'Signed Up' AS step_name,
    1 AS step_order,
    COUNT(DISTINCT user_id) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Created Report' AS step_name,
    2 AS step_order,
    COUNT(DISTINCT CASE WHEN did_report = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Exported Report' AS step_name,
    3 AS step_order,
    COUNT(DISTINCT CASE WHEN did_export = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Invited Team Member' AS step_name,
    4 AS step_order,
    COUNT(DISTINCT CASE WHEN did_invite = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Viewed Help Docs' AS step_name,
    5 AS step_order,
    COUNT(DISTINCT CASE WHEN did_docs = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier
),

baseline_counts AS (
  -- Step 3: Add the signed-up baseline per tier using FIRST_VALUE
  SELECT
    plan_tier,
    step_name,
    count,
    step_order,
    FIRST_VALUE(count) OVER (PARTITION BY plan_tier ORDER BY step_order) AS signup_baseline
  FROM funnel_tallies
)

-- Step 4: Adoption rate (% of signups)
SELECT
  plan_tier,
  step_name,
  count,
  step_order,
  CASE
    WHEN step_order = 1 THEN 100.0
    ELSE ROUND(100.0 * count / NULLIF(signup_baseline, 0), 1)
  END AS pure_adoption_rate_pct
FROM baseline_counts
ORDER BY plan_tier, step_order;
