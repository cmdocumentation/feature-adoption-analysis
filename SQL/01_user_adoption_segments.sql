-- Query 1: User Adoption Segments (High/Low Cohorts)
-- Output: User signup, churn date, plan tier (1-4), status (active/cancelled), adoption segment (high/low), days active, and 30-day churn flags

WITH user_metrics AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.churn_date,
        u.plan_tier,
        u.status,
        
        -- Time-to-Value: Days from signup to first core action
		-- JULIANDAY() returns the Julian day number; subtracting two gives elapsed days
        CAST((
            JULIANDAY(
                MIN(CASE 
                    WHEN ue.event_type IN ('created_report', 'invited_team_member') 
                    THEN ue.event_date 
                END)
            ) - JULIANDAY(u.signup_date)
        ) AS INTEGER) AS time_to_value,
        
        -- Feature Breadth: Distinct features used in first 14 days
        COUNT(DISTINCT 
            CASE 
                WHEN ue.event_date <= DATE(u.signup_date, '+14 days')
                THEN ue.event_type 
                ELSE NULL 
            END
        ) AS feature_breadth,
        
        -- Documentation Interaction: Binary flag (viewed help docs in first 14 days?)
        MAX(CASE 
            WHEN ue.event_type = 'viewed_help_docs' 
             AND ue.event_date <= DATE(u.signup_date, '+14 days')
            THEN 1 
            ELSE 0 
        END) AS documentation_viewed
        
    FROM users u
    LEFT JOIN user_events ue ON u.user_id = ue.user_id
    GROUP BY u.user_id, u.signup_date, u.churn_date, u.plan_tier, u.status
)

SELECT 
    user_id,
    signup_date,
    churn_date,
    plan_tier,
    status,
    
    -- Adoption Segment Classification
	CASE 
		WHEN time_to_value <= 7 
		AND feature_breadth >= 3 
		AND documentation_viewed = 1 
		THEN 'High Adoption'
		ELSE 'Low Adoption'
    -- Note: Users with NULL time_to_value (no core actions) fall into Low Adoption
	END AS adoption_segment,
    
    -- 30-day retention flags
    CASE 
        WHEN churn_date IS NOT NULL 
         AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) <= 30
        THEN 1 
        ELSE 0 
    END AS churned_by_day_30,
    
    -- Days active (for analysis reference)
    CASE 
        WHEN churn_date IS NOT NULL 
        THEN CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER)
        ELSE CAST((JULIANDAY('2025-05-28') - JULIANDAY(signup_date)) AS INTEGER)
    END AS days_active,
    
    -- Raw metrics (for transparency)
    time_to_value,
    feature_breadth,
    documentation_viewed

FROM user_metrics
ORDER BY user_id;
