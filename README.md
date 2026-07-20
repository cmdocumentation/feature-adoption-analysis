# SaaS Feature Adoption and Churn Analysis

A data analysis portfolio project investigating how early feature adoption predicts 30-day churn across user tiers in a hypothetical B2B SaaS platform built around report creation, sharing, and collaboration.

**Note:** This project uses synthetic data.

## The Business Problem

A high-growth B2B SaaS analytics company faces a critical question: Why do users churn within 30 days? The hypothesis is straightforward: users who don't adopt core features leave first.

---

## Key Findings

| Finding | Insight | Data Impact |
|---------|---------|-------------|
| High adoption users churn at 13% (first core action ≤7 days and ≥4 features within 14 days) | Users who engage early and broadly = strong retention signal | Feature adoption is a measurable predictor of 30-day retention |
| Tier 4 users have 7% churn in the low adoption segment and 0% churn in the high adoption segment. Yet only 27% ever created a report in their first 30 days (compared to 37-40% for Tiers 1–3). | Enterprise contracts (Tier 4) mask adoption risk: adoption still predicts churn, but contractual commitment suppresses 30-day signals. | Longer measurement windows (day 90+) are needed to detect Tier 4 retention risk, but the adoption-churn link still holds across all tiers. |
| Cohort retention stability in high adoption group | High adopters churn slower than low adopters and the gap widens over time | Early feature adoption creates sustained retention |
| Feature breadth matters more than individual actions | Users who try multiple core features stay longer than single-feature users | Multiple feature adoption is a stronger signal than any single action |

---

## Dashboard Results

### 30-Day Churn Rate by Adoption Segment and Plan Tier

High adoption users show 13% churn and low adoption users show 87% churn. 

Tier 4 has the lowest overall churn (7% for low adoption users, 0% for high adoption users).

![30-Day Churn by Adoption & Plan Tier](./assets/30-Day_Churn_by_Adoption_Tier.png)

Data Source: [01_user_adoption_segments_churn.sql](./SQL/01_user_adoption_segments_churn.sql)

---

### Cohort Retention Heatmap

Retention rates (day 7→90) for high adoption vs. low adoption cohorts, segmented by signup week. 

High adopters churn slower than low adopters and the gap widens over time.

![Cohort Retention Heatmaps](./assets/Cohort_Retention_Heatmaps.png)

Data Source: [02_cohort_retention_matrix.sql](./SQL/02_cohort_retention_matrix.sql)

---

### Feature Adoption Rates from Baseline by Plan Tier

Counts and percentage of the total signup cohort that ever successfully activates each feature within 30 days. 

Across all tiers, a maximum of 3% of users invite teammates - a critical gap. Industry benchmarks for B2B collaboration platforms range from 15–25% within 30 days. This suggests the team invitation feature either lacks discovery, doesn't align with user workflows, or users collaborate outside the platform.

![Feature Activation Rates by Baseline and Tier](./assets/Feature_Activation_Rates.png)

Data Source: [03_feature_adoption_rates.sql](./SQL/03_feature_adoption_rates.sql)

---

## Technical Approach

### Data Foundation

Synthetic dataset built with [Mockaroo](https://www.mockaroo.com/) and Excel, with all analyses reflecting data through May 28, 2025:

- **users table:** `user_id`, `signup_date`, `churn_date`, `plan_tier` (1–4), `status` (active/canceled)
- **user_events table:** `event_id`, `user_id`, `event_date`, `event_type` (`created_report`, `imported_report`, `applied_filter`, `updated_settings`, `ran_dashboard_export`, `invited_team_member`, `shared_report`)

### Defining the Metrics

Early feature adoption predicts long-term retention in B2B SaaS, but "adoption" is vague without operational definition. This project isolates genuinely engaged users through two signals measured together:

#### Time-to-Value (TTV): Days from Signup to First Core Action

- Users who reach their first core action within 7 days demonstrate early engagement momentum
- Beyond 7 days, activation momentum typically diminishes. This aligns with industry benchmarks for onboarding window length.
- Time-to-Value alone doesn't guarantee sustained engagement, but it's a necessary first signal

#### Feature Breadth: Count of Distinct Features Used in First 14 Days

- Single-feature users rarely stay (they solve one problem and leave)
- Four features signal genuine product exploration, not accidental discovery
- 14-day window chosen because behavioral patterns stabilize by this point - engagement becomes predictive of sustained platform usage

#### Why Two Conditions Together (AND Logic)

Each metric alone is incomplete:

- TTV alone misses users who take one action and disappear
- Breadth alone could reflect accidental clicks rather than intentional exploration

Combined, they isolate users who actively engaged with the product across these two dimensions - not just users who happened to take one action.

### Measurement Framework

- **Time-to-Value (TTV):** Days from signup to first core action (`created_report` or `imported_report`)
- **Feature Breadth:** Count of distinct features used in first 14 days

**Segmentation Logic**
```
High Adoption = (TTV ≤ 7 days) AND (Feature Breadth ≥ 4 within 14 days)
Low Adoption = Everyone else
```

### Feature Categories

| Feature Category | Actions | Value |
|---|---|---|
| Ingestion & Core Value | `created_report`, `imported_report` | User gets data in and generates first insights |
| Deep Engagement | `applied_filter`, `updated_settings`, `ran_dashboard_export` | User explores, customizes, and extracts value |
| Collaboration & Amplification | `invited_team_member`, `shared_report` | User multiplies impact by bringing others in |

### Design Choice: Synthetic Data

This project uses synthetic data. However, the adoption-churn relationship and tier-based retention patterns reflect patterns observed in real B2B SaaS platforms. The logic and insights generalize to real-world SaaS datasets, enabling demonstration of SQL transformation, window functions, and analytical storytelling without proprietary data constraints.

### SQL Techniques

- **CTEs with JOINs:** Connect user events to signup/churn data for Time-to-Value and feature breadth calculations
- **Temporal Filtering (JOIN conditions and CASE logic):** Event data constrained to 7-day, 14-day, and 30-day windows post-signup to isolate early engagement signals and measure Time-to-Value and retention patterns
- **Window Function (FIRST_VALUE):** Establish the signup baseline per tier for adoption rate calculations

---

## Key Observations

**Observation 1: Early Feature Adoption Predicts 30-Day Retention**
- High adoption users: 13% churn
- Low adoption users: 87% churn
- The data shows a strong correlation between multi-feature engagement and staying past day 30

**Observation 2: Contract Structure and Sales Vetting Shape Early Retention**
- Tier 4 shows 0–7% churn regardless of adoption levels, versus lower tiers where adoption is predictive
- Sales vetting and contractual commitment reduce churn pressure in the first 30 days
- Only 27% of Tier 4 users create a report in the first 30 days - lower than Tiers 1–3 (37–43%)
- Tier 4 users show the highest proportion of imported report actions (20%), suggesting a different but valid onboarding signal
- What this doesn't tell us: Whether satisfaction is genuine, why adoption patterns differ, or if renewal risk emerges after 90 days

**Observation 3: Team Adoption Represents a Critical Engagement Gap**
- A healthy B2B collaboration platform typically achieves 15–25% team adoption within 30 days. This dataset shows minimal viral feature adoption: fewer than 4% of total users across all tiers invite a teammate, suggesting the platform functions primarily as a single-user tool despite higher report-sharing rates (20-27%).

---

## Questions for Further Analysis

- Does the Tier 4 churn rate hold after day 90? (Is the paradox short-term or sustained?)
- Enterprise (Tier 4) users create and share reports at healthy rates (27% and 24%), and fewer than 4% invite teammates despite their team structures. This pattern suggests either: (a) team collaboration happens in upstream tools (Slack, email, shared drives) before the platform, or (b) Tier 4 onboarding prioritizes individual power users over cross-functional adoption. Which assumption drives the renewal strategy?

---

## Implications for Product Teams

- For Tier 1–3 users: Feature discovery and breadth are retention levers. Onboarding should surface core features (report creation and filtering) within the first 7 days. 
- For Tier 4 users: Early adoption signals are muted by contractual commitment, making renewal risk invisible in 30-day windows. The real question isn't 30-day churn - it's whether adoption depth predicts 90-day renewal. 
- For all tiers: Team features underperform benchmarks. Either the feature is undiscovered, or users have established collaboration workflows outside the platform. This is a discovery problem, not (yet) a feature problem.
  
---

## Repository Structure

The repository includes a synthetic dataset (`users.csv`, `user_events.csv`), three SQL (Postgres) queries that calculate adoption segments and retention metrics, and three Tableau visualizations exported as PNGs.
