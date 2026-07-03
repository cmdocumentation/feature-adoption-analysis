-- Query 4: Feature Adoption Rates
-- Purpose: Measures adoption rates for key product features within a user's first 30 days, broken down by plan tier (1-4) and calculated relative to the total signup baseline

WITH user_milestones AS (
    -- Step 1: Flag the first time a user completes each step within 30 days
    SELECT 
        u.plan_tier,
        u.user_id,
        MAX(CASE WHEN ue.event_type = 'created_report' THEN 1 ELSE 0 END) AS did_report,
        MAX(CASE WHEN ue.event_type = 'ran_dashboard_export' THEN 1 ELSE 0 END) AS did_export,
        MAX(CASE WHEN ue.event_type = 'invited_team_member' THEN 1 ELSE 0 END) AS did_invite,
        MAX(CASE WHEN ue.event_type = 'viewed_help_docs' THEN 1 ELSE 0 END) AS did_docs
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
        AND ue.event_date <= DATE(u.signup_date, '+30 days')
    GROUP BY u.plan_tier, u.user_id
),
funnel_tallies AS (
    -- Step 2: Total up the raw counts for each milestone
    SELECT plan_tier, 'Signed Up' AS step_name, 1 AS step_order, COUNT(DISTINCT user_id) AS count FROM user_milestones GROUP BY plan_tier
    UNION ALL
    SELECT plan_tier, 'Created Report', 2, COUNT(DISTINCT CASE WHEN did_report = 1 THEN user_id END) FROM user_milestones GROUP BY plan_tier
    UNION ALL
    SELECT plan_tier, 'Exported Report', 3, COUNT(DISTINCT CASE WHEN did_export = 1 THEN user_id END) FROM user_milestones GROUP BY plan_tier
    UNION ALL
    SELECT plan_tier, 'Invited Team Member', 4, COUNT(DISTINCT CASE WHEN did_invite = 1 THEN user_id END) FROM user_milestones GROUP BY plan_tier
    UNION ALL
    SELECT plan_tier, 'Viewed Help Docs', 5, COUNT(DISTINCT CASE WHEN did_docs = 1 THEN user_id END) FROM user_milestones GROUP BY plan_tier
),
baseline_counts AS (
    -- Step 3: Use FIRST_VALUE to grab the 'Signed Up' count (step_order = 1) for each tier
    SELECT 
        plan_tier,
        step_name,
        count,
        step_order,
        FIRST_VALUE(count) OVER (PARTITION BY plan_tier ORDER BY step_order) AS signup_baseline
    FROM funnel_tallies
)
-- Step 4: Calculate the feature adoption rate relative to total signups
SELECT 
    plan_tier,
    step_name,
    count,
    step_order,
    CASE 
        WHEN step_order = 1 THEN 100.0 -- The baseline is always 100%
        ELSE ROUND(100.0 * count / signup_baseline, 1)
    END AS pure_adoption_rate_pct
FROM baseline_counts
ORDER BY plan_tier, step_order;
