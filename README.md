# SaaS Feature Adoption and Churn Analysis

A data analysis portfolio project investigating the relationship between early feature adoption and 30-day user retention in a B2B SaaS product.

**Note:** This project uses synthetic data.

## Project Overview

**The Business Problem**

A high-growth B2B SaaS company faces a critical question: Why do users churn after 30 days? The hypothesis is straightforward: users who don't adopt core features leave first.

---

## Key Findings

| Finding | Insight | Data Impact |
|---------|---------|-------------|
| High adoption users churn at 16% | Users who adopt ≥4 distinct features within 14 days = strong retention signal | Feature adoption is a measurable predictor of 30-day retention |
| Tier 4 paradox: 7% low adoption churn, 0% high adoption churn, yet 27% report creation adoption overall | Enterprise contracts mask adoption risk: both segments show low 30-day churn, but early adoption still predicts outcome. Real risk likely appears in renewal or satisfaction metrics. | Adoption-churn link holds across all tiers, but 30-day churn may be too coarse a metric to detect Tier 4 adoption risk. |
| Cohort retention stability in high adoption group | High adopters churn slower than low adopters and the gap widens over time | Early feature adoption creates sustained retention |
| Feature breadth matters more than individual actions | Users who try multiple core features stay longer than single-feature users | Multiple feature adoption is a stronger signal than any single action |

---

## Dashboard Results

### 30-Day Churn Rate by Adoption Segment and Plan Tier

High adoption users show 16% churn and low adoption users show 87% churn. 

Tier 4 has the lowest overall churn (7% for low adoption users, 0% for high adoption users).

![30-Day Churn by Adoption & Plan Tier](./assets/30-Day_Churn_by_Adoption_Tier.png)

Data Source: [02_user_adoption_segments_churn.sql](./SQL/02_user_adoption_segments_churn.sql)

---

### Cohort Retention Heatmap

Retention rates (day 7→90) for high adoption vs. low adoption cohorts, segmented by signup week.

![Cohort Retention Heatmaps](./assets/Cohort_Retention_Heatmaps.png)

Data Source: [03_cohort_retention_matrix.sql](./SQL/03_cohort_retention_matrix.sql)

---

### Feature Adoption Rates from Baseline by Plan Tier

Counts and percentage of the total signup cohort that ever successfully activates each core feature within 30 days. 

Across all tiers, a maximum of 3.4% of cohorts engage with the team member invitation feature.

![Feature Activation Rates by Baseline and Tier](./assets/Feature_Activation_Rates.png)

Data Source: [04_feature_adoption_rates.sql](./SQL/04_feature_adoption_rates.sql)

---

## Technical Approach

### Data Foundation

Synthetic dataset built with [Mockaroo](https://www.mockaroo.com/) and Excel:

- **users table:** user_id, signup_date, churn_date, plan_tier (1–4), status (active/canceled)
- **user_events table:** event_id, user_id, event_date, event_type (updated_settings, created_report, ran_dashboard_export, imported_report, applied_filter, invited_team_member, viewed_help_docs)

### SQL (Postgres) Transformation

Built user adoption segments using CTEs and window functions to calculate two retention predictors:

**Key Metrics**

- **Time-to-Value (TTV):** Days from signup to first core action
- **Feature Breadth:** Count of distinct features used in first 14 days

**Segmentation Logic**
```
HIGH_ADOPTION = (TTV ≤ 7 days) AND (Feature_Breadth ≥ 4)
LOW_ADOPTION  = Everyone else
```

See [01_user_adoption_segments.sql](./SQL/01_user_adoption_segments.sql) for the full query.

---

# Design Rationale

## Why These Metrics Matter

Early feature adoption is a leading indicator of long-term retention in B2B SaaS. But "adoption" is vague. This project operationalizes the concept using two measurable signals that together identify genuinely engaged users:

### Time-to-Value (TTV): Days from signup to first core action

- Users who reach their first core action within 7 days demonstrate early engagement momentum
- Beyond 7 days, activation typically fades. This aligns with industry benchmarks for onboarding window length
- TTV alone doesn't guarantee sustained engagement, but it's a necessary first signal

### Feature Breadth: Count of distinct features used in first 14 days

- Single-feature users rarely stay (they solve one problem and leave)
- Three features signal genuine product exploration, not accidental discovery
- 14-day window chosen because behavioral patterns stabilize by this point - engagement becomes predictive of sustained platform usage

## Why Two Conditions Together (AND Logic)

Each metric alone is incomplete:

- TTV alone misses users who take one action and disappear
- Breadth alone could reflect accidental clicks rather than intentional exploration

Combined, they isolate users who actively engaged with the product across these two dimensions - not just users who happened to take one action.

## Design Choice: Synthetic Data

This project uses synthetic data. This choice enables demonstration of SQL transformation, window functions, and analytical storytelling without proprietary data constraints. The logic and insights generalize to real-world SaaS datasets.

---

## The Tier 4 Paradox: What the Data Reveals

**The Pattern**
- Tier 4 (enterprise) has the lowest churn rate at 0-7% (high and low adoption users)
- But only 27% of all Tier 4 users create a report - lower than all other tiers (40-43%)
- In Tiers 1–3, adoption and churn move together; in Tier 4, they diverge among low adoption users

**What This Suggests**

Selection effect and contract structure likely explain the divergence. Tier 4 buyers are vetted by sales and contractually committed, so early feature adoption is less predictive of their 30-day churn.
  
**What This Does NOT Tell Us**
- Whether Tier 4 customers are *satisfied* (we only see churn, not NPS or renewal intent)
- Why adoption is lower (could be onboarding, product fit, or just account maturity stage)
- Whether this is sustainable (renewal risk may appear later, after the 90-day window)

---

## Key Observations

**Observation 1: Early Feature Adoption Predicts 30-Day Retention**
- High adoption users: 16% churn
- Low adoption users: 87% churn
- The data shows a strong correlation between multi-feature engagement and staying past day 30

**Observation 2: The Tier 4 Paradox Suggests Contract Structure Matters**
- Enterprise customers don't churn even with low feature adoption.
- This suggests contract lock-in and sales vetting reduce churn pressure in the first 30 days, making early feature adoption a less reliable retention signal for Tier 4.

**Observation 3: The "Invited Team Member" Bottleneck is a Catastrophe**
- A healthy B2B collaboration platform typically looks for a 15% to 25% team adoption rate within 30 days. We see an absolute collapse in viral feature adoption: fewer than 4% of total users across all tiers ever successfully invite a teammate, indicating the platform is operating purely as a siloed, single-user tool.

---

## Questions for Further Analysis

- Does the Tier 4 churn rate hold after day 90? (Is the paradox short-term or sustained?)
- How do usage patterns differ between Tier 4 users who created reports (27%) and those who didn't (73%)?

---

## Repository Structure

The repository includes a synthetic dataset (users.csv, user_events.csv), four SQL (Postgres) queries that calculate adoption segments and retention metrics, and three Tableau visualizations exported as PNGs.
