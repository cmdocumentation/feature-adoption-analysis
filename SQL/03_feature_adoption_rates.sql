
-- Query 3: Feature Adoption Rates 
-- Measures adoption rates for all 7 product features within a user's first 30 days, broken down by plan tier (1-4), relative to the signed-up baseline.

WITH user_milestones AS (
  -- Step 1: For each user + tier, flag whether they hit each milestone within 30 days of signup
  SELECT
    u.plan_tier,
    u.user_id,
    MAX(CASE WHEN ue.event_type = 'imported_report'       THEN 1 ELSE 0 END) AS did_import,
    MAX(CASE WHEN ue.event_type = 'created_report'        THEN 1 ELSE 0 END) AS did_create,
    MAX(CASE WHEN ue.event_type = 'applied_filter'        THEN 1 ELSE 0 END) AS did_filter,
    MAX(CASE WHEN ue.event_type = 'updated_settings'      THEN 1 ELSE 0 END) AS did_settings,
    MAX(CASE WHEN ue.event_type = 'ran_dashboard_export'  THEN 1 ELSE 0 END) AS did_export,
    MAX(CASE WHEN ue.event_type = 'invited_team_member'   THEN 1 ELSE 0 END) AS did_invite,
    MAX(CASE WHEN ue.event_type = 'shared_report'         THEN 1 ELSE 0 END) AS did_share
  FROM users u
  LEFT JOIN user_events ue
    ON ue.user_id = u.user_id
   AND ue.event_date <= (u.signup_date + INTERVAL '30 days')
  GROUP BY u.plan_tier, u.user_id
),

funnel_tallies AS (
  -- Step 2: Count distinct users who completed each milestone, ordered by maturation arc
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
    'Imported Report' AS step_name,
    2 AS step_order,
    COUNT(DISTINCT CASE WHEN did_import = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Created Report' AS step_name,
    3 AS step_order,
    COUNT(DISTINCT CASE WHEN did_create = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Applied Filter' AS step_name,
    4 AS step_order,
    COUNT(DISTINCT CASE WHEN did_filter = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Updated Settings' AS step_name,
    5 AS step_order,
    COUNT(DISTINCT CASE WHEN did_settings = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Ran Dashboard Export' AS step_name,
    6 AS step_order,
    COUNT(DISTINCT CASE WHEN did_export = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Invited Team Member' AS step_name,
    7 AS step_order,
    COUNT(DISTINCT CASE WHEN did_invite = 1 THEN user_id END) AS count
  FROM user_milestones
  GROUP BY plan_tier

  UNION ALL

  SELECT
    plan_tier,
    'Shared Report' AS step_name,
    8 AS step_order,
    COUNT(DISTINCT CASE WHEN did_share = 1 THEN user_id END) AS count
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
    FIRST_VALUE(count) OVER (
      PARTITION BY plan_tier
      ORDER BY step_order
    ) AS signup_baseline
  FROM funnel_tallies
)

-- Step 4: Adoption rate (% of signups) with categorization
SELECT
  plan_tier,
  step_name,
  count,
  step_order,
  CASE
    WHEN step_order = 1 THEN 100.0
    ELSE ROUND(100.0 * count / NULLIF(signup_baseline, 0), 1)
  END AS adoption_rate_pct
FROM baseline_counts
ORDER BY plan_tier, step_order;


