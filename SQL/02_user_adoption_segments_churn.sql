-- Query 2: User Adoption Segments with 30/60/90-Day Churn Rates
-- Output: Churn rates by plan tier (1-4), adoption segment (high vs. low), and time period (30/60/90 days)

-- CTE 1: Build user activity profile with adoption indicators
WITH user_activity_profile AS (
    SELECT 
        u.user_id,
        u.signup_date,
        u.churn_date,
        u.plan_tier,
        u.status,
        
        -- TIME-TO-VALUE: Days until user takes first core action
        -- (creating a report or inviting a team member)
        CAST((
            JULIANDAY(
                MIN(CASE 
                    WHEN ue.event_type IN ('created_report', 'invited_team_member') 
                    THEN ue.event_date 
                END)
            ) - JULIANDAY(u.signup_date)
        ) AS INTEGER) AS time_to_value,
        
        -- FEATURE BREADTH: Count of distinct features used in first 14 days
        -- High breadth (3+ features) indicates the user explored the product
        COUNT(DISTINCT 
            CASE 
                WHEN ue.event_date <= DATE(u.signup_date, '+14 days')
                THEN ue.event_type 
                ELSE NULL 
            END
        ) AS feature_breadth,
        
        -- DOCUMENTATION INTERACTION: Binary flag for first 14 days
        -- 1 = viewed help docs in first 14 days, 0 = did not
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

-- CTE 2: Classify users into adoption segments and churn time windows
adoption_segments AS (
    SELECT 
        user_id,
        signup_date,
        churn_date,
        plan_tier,
        
        -- ADOPTION SEGMENT CLASSIFICATION
        -- "High Adoption" users show strong early engagement patterns
        CASE 
            WHEN time_to_value <= 7 
             AND feature_breadth >= 3 
             AND documentation_viewed = 1 
            THEN 'High Adoption'
            ELSE 'Low Adoption'
        END AS adoption_segment,
        
        -- EARLY CHURN FLAG (0-30 days)
        CASE 
            WHEN churn_date IS NOT NULL 
             AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) <= 30
            THEN 1 
            ELSE 0 
        END AS churned_30,
        
        -- MID-TERM CHURN FLAG (31-60 days)
        CASE 
            WHEN churn_date IS NOT NULL 
             AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) > 30
             AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) <= 60
            THEN 1 
            ELSE 0 
        END AS churned_60,
        
        -- LATE CHURN FLAG (61-90 days)
        CASE 
            WHEN churn_date IS NOT NULL 
             AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) > 60
             AND CAST((JULIANDAY(churn_date) - JULIANDAY(signup_date)) AS INTEGER) <= 90
            THEN 1 
            ELSE 0 
        END AS churned_90
    FROM user_activity_profile
)

-- FINAL AGGREGATION: Roll up metrics by adoption segment and plan tier
SELECT 
    adoption_segment,
    plan_tier,
    
    -- TOTAL USERS: Count of all users in this segment
    COUNT(*) AS total_users,
    
    -- CHURN COUNTS AND RATES: Overall and by time window
    SUM(CASE WHEN churn_date IS NOT NULL THEN 1 ELSE 0 END) AS total_churned,
    ROUND(100.0 * SUM(CASE WHEN churn_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) 
        AS overall_churn_rate,
    
    -- EARLY CHURN (Days 0-30): High early churn suggests onboarding gaps
    SUM(churned_30) AS churned_by_day_30,
    ROUND(100.0 * SUM(churned_30) / COUNT(*), 1) AS churn_rate_30,
    
    -- MID-TERM CHURN (Days 31-60): May indicate feature gaps or support issues
    SUM(churned_60) AS churned_day_31_60,
    ROUND(100.0 * SUM(churned_60) / COUNT(*), 1) AS churn_rate_60,
    
    -- LATE CHURN (Days 61-90): Users who stayed >2 months before leaving
    SUM(churned_90) AS churned_day_61_90,
    ROUND(100.0 * SUM(churned_90) / COUNT(*), 1) AS churn_rate_90
    
FROM adoption_segments
GROUP BY adoption_segment, plan_tier
ORDER BY adoption_segment, plan_tier;
