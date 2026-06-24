## 📄 Medicaid Provider Spending — Power BI Dashboard Design & DAX Guidelines  

# 1. Overview
This document defines the Power BI dashboard architecture, semantic model, page layouts, and DAX standards for the Medicaid Provider Spending Analytics project.

The dashboard is aligned with the Snowflake **MODEL** layer and uses a clean, modern **star schema** centered on:

- `FACT_MEDICAID_PROVIDER_SPENDING`
- `PROVIDER_DIM`
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`

Monthly FACT tables are **no longer required**. All monthly aggregations are computed dynamically in Power BI.

Provider state cleanup is performed in Snowflake using:
`/sql/model/clean_provider_states.sql`

This script produces:
- `PRACTICE_STATE_US`
- `MAILING_STATE_US`
- `PROVIDER_STATE_US`

Power BI uses **PROVIDER_STATE_US** for all map visuals.

---

# 2. Power BI Semantic Model

## 2.1 Tables Imported (Import Mode)
From `ANALYTICS_MEDICAID.MODEL`:

- `FACT_MEDICAID_PROVIDER_SPENDING`
- `PROVIDER_DIM`  ← replaces NPI_DIM + SERVICING_PROVIDER_DIM
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`
- `PROVIDER_ROLE_PERCENTILE`

No monthly FACT table is imported.


---

## 2.2 Star Schema Diagram (Updated)

```code
                   ┌───────────────────────────┐
                   │         DATE_DIM          │
                   └──────────────┬────────────┘
                                  │ 1:* (single)
                                  ▼
                   ┌───────────────────────────┐
                   │ FACT_MEDICAID_PROVIDER_   │
                   │       SPENDING            │
                   └──────────────┬────────────┘
                                  │
       ┌──────────────────────────┼──────────────────────────┐
       │                          │                          │
       ▼                          ▼                          ▼

┌───────────────────────────┐   ┌───────────────────────────┐
│       PROVIDER_DIM        │   │        HCPCS_DIM          │
└───────────────────────────┘   └───────────────────────────┘

  │                                     │
  ▼                                     ▼

┌───────────────────────────┐     ┌───────────────────────────┐
│  PROVIDER_ROLE_PERCENTILE │     │  SERVICE_CATEGORY_DIM     │
└───────────────────────────┘     └───────────────────────────┘
```

# 2.3 Relationship Rules

| From Table                      | Column                 | To Table             | Column           | Type                |
| ------------------------------- | ---------------------- | -------------------- | ---------------- | ------------------- |
| FACT_MEDICAID_PROVIDER_SPENDING | CLAIM_MONTH            | DATE_DIM             | DATE_KEY         | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | BILLING_PROVIDER_NPI   | PROVIDER_DIM         | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICING_PROVIDER_NPI | PROVIDER_DIM         | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | HCPCS_CODE             | HCPCS_DIM            | HCPCS_CODE       | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICE_CATEGORY       | SERVICE_CATEGORY_DIM | SERVICE_CATEGORY | Many-to-One, Single |

| Table        | Column | Relationship |
| ------------ | ------ | ---------------------------------------- |
| PROVIDER_DIM | NPI    | 1-to-many → PROVIDER_ROLE_PERCENTILE.NPI |


# 2.4 Provider Dimension – Data Quality Notes
After NPI cleanup, only 23 NPIs remain with:

- ENTITY_TYPE_CODE = 2 (Organization)
- No ORG_NAME
- No individual name fields

These are legitimate CMS‑enumerated organizations.

They are assigned:
```code
Provider Display Name = "Unknown Organization"
Provider Type = "Organization"
```
This ensures:
- No blank labels
- Correct attribution
- Accurate Top‑N rankings

# 3. Measures Table Standards
3.1 Measures Table

```DAX
Measures = { "DAX Measures Table" }
```
All measures must be stored in this table.

3.2 Naming Conventions

| Category          | Convention                          | Example               |
| ----------------- | ----------------------------------- | --------------------- |
| Core measures     | ``<Metric>``                        | Total Claims |
| Time intelligence | ``<Metric> ``<Period>``             | Paid Amount Rolling 12M |
| Category measures | ``<Category> ``<Metric>``           | OP Claims |
| Provider analytics| ``<Metric> ``per ``Provider``       | Claims per Provider |
| HCPCS analytics   | ``<Metric> ``per ``HCPCS``          | Paid Amount per HCPCS |
| Top‑N             | ``Top ``<N> ``<Entity> ``<Metric>`` | Top 10 Providers Paid Amount |


3.3 DAX Style Guide
- Use CALCULATE for all filtered measures
- Use DIVIDE() instead of /
- Use VAR blocks for time intelligence
- Avoid implicit measures
- Document complex measures with comments

3.4 Provider Display Name Logic (Individuals & Organizations)

```DAX
Provider Display Name =
VAR Name =
    IF (
        NOT ISBLANK ( PROVIDER_DIM[FULL_NAME] ),
        PROVIDER_DIM[FULL_NAME],
        PROVIDER_DIM[ORG_NAME]
    )
RETURN
IF (
    ISBLANK(Name),
    "Unknown Organization",
    Name
)
```

# 4. Core DAX Measures

```DAX
Total Claims =
SUM ( FACT_MEDICAID_PROVIDER_SPENDING[TOTAL_CLAIM_LINES] )

Total Paid Amount =
SUM ( FACT_MEDICAID_PROVIDER_SPENDING[TOTAL_PAID] )

Total Patients =
SUM ( FACT_MEDICAID_PROVIDER_SPENDING[TOTAL_PATIENTS] )

Average Paid Amount =
DIVIDE ( [Total Paid Amount], [Total Claims] )
```

# 5. Service Category Measures

```DAX
OP Claims =
CALCULATE ( [Total Claims], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "OP" )

RX Claims =
CALCULATE ( [Total Claims], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "RX" )

Other Claims =
CALCULATE ( [Total Claims], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "OTHER" )

```
Paid amounts:
```DAX
OP Paid Amount =
CALCULATE(
    [Total Paid Amount],
    FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "OP"
)

RX Paid Amount =
CALCULATE(
    [Total Paid Amount],
    FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "RX"
)

Other Paid Amount =
CALCULATE(
    [Total Paid Amount],
    FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "OTHER"
)

```

# 6. Provider Analytics Measures
```DAX
Distinct Providers =
DISTINCTCOUNT ( PROVIDER_DIM[NPI] )

Paid Amount per Provider =
DIVIDE ( [Total Paid Amount], [Distinct Providers] )

Paid Amount Percentile Rank =
VAR Role = SELECTEDVALUE(ProviderRole[Role], "Billing")
RETURN
CALCULATE(
    SELECTEDVALUE(PROVIDER_ROLE_PERCENTILE.PAID_AMOUNT_PERCENTILE),
    PROVIDER_ROLE_PERCENTILE[PROVIDER_ROLE] = Role
)
```

# 7. HCPCS Analytics Measures
```DAX
Distinct HCPCS Codes =
DISTINCTCOUNT ( FACT_MEDICAID_PROVIDER_SPENDING[HCPCS_CODE] )

Paid Amount per HCPCS =
DIVIDE ( [Total Paid Amount], [Distinct HCPCS Codes] )
```

# 8. Time Intelligence Measures
Assumes DATE_DIM[DATE_KEY] is linked to FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH].

8.1 Month-over-Month

```DAX
Paid Amount MoM =
VAR PrevMonth =
    CALCULATE ( [Total Paid Amount], DATEADD ( DATE_DIM[DATE_KEY], -1, MONTH ) )
RETURN
    [Total Paid Amount] - PrevMonth
```

8.2 Rolling 12 Months
Asumes:
```DAX
DATE_DIM[DATE_KEY] → FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH]
```

8.3 🔎 Data Completeness Logic (Full‑Month Filtering)
Purpose:  
Ensure that trend visuals only display fully reported months, preventing misleading declines caused by partial provider submissions or incomplete ingestion cycles.

Background:  
The most recent month in FACT_MEDICAID_PROVIDER_SPENDING may contain significantly fewer rows (e.g., ~900K vs 2.3M–3.4M), indicating incomplete reporting.
To avoid distorting the Medicaid spend trend, incomplete months are automatically excluded.

DAX — Paid Amount (Full Months Only)
Used in the main trend visual to hide incomplete months.

```DAX
Paid Amount (Full Months Only) =
VAR LastFactDate =
    CALCULATE(
        MAX(FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH]),
        ALL(FACT_MEDICAID_PROVIDER_SPENDING)
    )

VAR LastFullMonth =
    EOMONTH(LastFactDate, -1)

VAR CurrentDate =
    MAX(DATE_DIM[DATE_KEY])

RETURN
IF(
    CurrentDate <= LastFullMonth,
    [Total Paid Amount]
)
```

DAX — Lowest Paid Amount (Full Months Only)
Ensures the low‑point marker aligns with full‑month data only.

```DAX
Lowest Paid Amount (Full Months Only) =
VAR LastFactDate =
    CALCULATE(
        MAX(FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH]),
        ALL(FACT_MEDICAID_PROVIDER_SPENDING)
    )

VAR LastFullMonth =
    EOMONTH(LastFactDate, -1)

VAR MinValue =
    MINX(
        FILTER(
            ALL(DATE_DIM),
            DATE_DIM[DATE_KEY] <= LastFullMonth
        ),
        [Total Paid Amount]
    )

RETURN
IF(
    [Total Paid Amount] = MinValue,
    [Total Paid Amount]
)
```

DAX — Data Completeness KPI
Displayed as a card on the Overview page.

```DAX
Data Completeness KPI =
VAR LastFactMonth =
    CALCULATE(
        MAX(FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH]),
        ALL(FACT_MEDICAID_PROVIDER_SPENDING)
    )

VAR RowCount =
    CALCULATE(
        COUNTROWS(FACT_MEDICAID_PROVIDER_SPENDING),
        FACT_MEDICAID_PROVIDER_SPENDING[CLAIM_MONTH] = LastFactMonth
    )

VAR Threshold = 2000000   -- Typical month: 2.3M–3.4M rows

RETURN
IF(
    RowCount < Threshold,
    "⚠️ Latest Month Incomplete",
    "✔ Latest Month Complete"
)
```
Usage Notes
- The trend visual uses Paid Amount (Full Months Only) to avoid showing incomplete months.
- Peak and low markers use the corresponding Full Months Only measures.
- The KPI card provides transparency to stakeholders regarding data freshness and completeness.
- This logic ensures the dashboard reflects true Medicaid spend trends, not ingestion artifacts.

# 9. Top‑N Measures

```DAX
Top 10 Providers Paid Amount =
IF (
    RANKX (
        ALL ( PROVIDER_DIM[NPI] ),
        [Total Paid Amount],
        ,
        DESC
    ) <= 10,
    [Total Paid Amount]
)
```

# 10. Continental U.S. State Filtering (Filled Map Configuration)
```code
Is_Continental_US =
IF (
    PROVIDER_DIM[PROVIDER_STATE_US] IN {
        "AL","AR","AZ","CA","CO","CT","DE","FL","GA","IA","ID","IL","IN","KS","KY",
        "LA","MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM",
        "NV","NY","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VA","VT","WA",
        "WI","WV","WY"
    },
    1,
    0
)
```
Purpose
- Flags each provider as continental (1) or non‑continental (0)
- Enables clean filtering of geographic visuals
- Ensures the Filled Map focuses on the 48 contiguous states
- Prevents Alaska/Hawaii distortion and territory mis‑geocoding

Map filter:
```code
Is_Continental_US = 1
```

# 11. 🟦 Power BI DAX Measure (Role‑Aware Percentile)
```dax
Paid Amount Percentile Rank =
VAR Role =
    SELECTEDVALUE(ProviderRole[Role], "Billing")
RETURN
CALCULATE(
    SELECTEDVALUE(PROVIDER_ROLE_PERCENTILE[PAID_AMOUNT_PERCENTILE]),
    PROVIDER_ROLE_PERCENTILE[PROVIDER_ROLE] = Role
)
``` 
Behavior:
- If user selects Billing, returns Billing percentile
- If user selects Servicing, returns Servicing percentile
- Works on drillthrough

---

# 12. Dashboard Pages (Updated)

The Medicaid Provider Spending dashboard is organized into **six pages**, each serving a distinct analytical purpose. 
The layout follows a logical narrative: executive overview → provider integrity → clinical utilization → category insights → data quality → documentation.

---

## 📘 12.1 Page 1 — Medicaid Spending Overview

⭐The Executive Overview page provides a high‑level assessment of Medicaid program performance, highlighting total spend, utilization volume, patient reach, and provider participation across the United States. The combination of KPIs, trend analysis, service category distribution, and geographic spend patterns enables leadership to quickly identify macro‑level shifts in Medicaid spending, emerging utilization trends, and state‑level variations. This page serves as the primary entry point for understanding where Medicaid dollars are flowing, how spending has evolved over time, and which provider groups drive the largest share of program costs.

**Purpose:** Executive‑level summary of Medicaid spend, utilization, and geographic distribution.

**Key Visuals**
- KPI Row: Total Paid Amount, Total Claims, Total Patients, Distinct Providers
- Spend Trend (Continuous Date Axis)
- Spend by Service Category (OP / RX / OTHER)
- Top Providers by Paid Amount (Billing vs Servicing toggle)
- Filled Map: Paid Amount by Provider State (filtered to continental U.S.)

This page provides the “big picture” view of Medicaid program performance.

⭐ Interaction Rules
The Executive Overview page is designed with intuitive, consistent interaction patterns that carry across the entire dashboard:

- Billing vs Servicing Toggle  
The provider role toggle applies at the model level and automatically filters all pages. Selecting Billing or Servicing on Page 1 updates every visual on Page 1 and persists when navigating to Pages 2–6.

- Cross‑Page Consistency  
Because the toggle filters the semantic model, all downstream pages (Provider Integrity, HCPCS Explorer, Category Analytics, etc.) inherit the same provider role context unless explicitly overridden.

- Visual Interactions
  > Selecting a state on the map filters the Top Providers visuals and the service category donut.
  > Selecting a provider in the Top 10 visuals filters the KPI row and category distribution.
  > Hover tooltips provide additional detail without altering page‑level filters.

- Full‑Month Filtering  
Trend visuals automatically exclude incomplete months using the Paid Amount (Full Months Only) measure, ensuring accurate interpretation of spend patterns.

These rules ensure a predictable, transparent user experience across the entire dashboard.

⭐ Executive Narrative 
The Executive Overview page tells a clear, data‑driven story of Medicaid spending. It begins with a KPI row that quantifies the scale of the program—total paid amount, claims volume, patient reach, and provider participation. The trend visual contextualizes how spending has evolved over time, highlighting peaks, troughs, and structural shifts in utilization. The service category donut breaks down spend across OP, RX, and OTHER categories, revealing where Medicaid dollars are concentrated. The geographic map surfaces state‑level variation in spending, while the Top 10 Providers visuals identify the largest organizational and individual contributors to Medicaid costs. Together, these elements provide leadership with a comprehensive, at‑a‑glance understanding of program performance and emerging patterns.

---

## 📘 12.2 Page 2 — Provider Integrity Scorecard (peer comparison)
**Purpose**   
Provide a fast, searchable, benchmarking‑oriented view of Medicaid providers using enriched attributes from PROVIDER_DIM and percentile‑based risk scoring from PROVIDER_ROLE_PERCENTILE.
This page enables users to quickly evaluate a provider’s behavior relative to peers in the same role (Billing or Servicing), without requiring drillthrough navigation.
Unlike the drillthrough page, this Scorecard focuses on provider‑level integrity indicators
It evaluates provider behavior relative to all other providers in the same role (Billing or Servicing).

This page highlights your provider‑level enrichment, risk scoring, and integrity analytics.
⭐ Why This Page Exists (and Why It’s Different From Drillthrough)

✔ Provider Integrity Scorecard (Page 2)
- Dimension‑level benchmarking
- Percentile rank, risk tier, provider attributes
- Searchable by NPI or name
- Designed for monitoring, triage, and integrity review
- Accessible directly from navigation
- Lightweight and optimized for large datasets
- No heavy distribution visuals (histograms removed for performance)

✔ Drillthrough Page (Page 3)
- Fact‑level deep dive
- Trends, categories, HCPCS, DQ flags
- Only accessible from Top 10 tables
- Investigative, diagnostic

⭐ Together:
- Scorecard = Who should we investigate?
- Drillthrough = What is happening with this provider?

> Key Visuals & Components
1. Provider Search (NPI / Name)
Users can directly search for any provider using:
- NPI
- Partial or full provider name
This replaces the need for drillthrough navigation and supports fast triage.

2. Provider Role Toggle (Billing / Servicing)
This toggle drives the entire page.
It determines:
- Which percentile distribution to use
- Which risk score to display
- Which peer group the provider is compared against


3. Provider Risk Score (High / Medium / Low)
Derived from:
- `PROVIDER_ROLE_PERCENTILE[PAID_AMOUNT_PERCENTILE]`
- Role‑aware percentile logic
- Thresholds defined in your documentation:

| Percentile | Risk Tier   |
| ---------- | ----------- |
| ≥ 90%      | High Risk   |
| 70–89%     | Medium Risk |
| < 70%      | Low Risk    |

3. Paid Amount Percentile Rank
Displays the provider’s position relative to peers.
Examples:
- “92nd Percentile (High Outlier)”
- “45th Percentile (Normal)”
Displayed prominently for integrity triage.


4. Paid Amount Percentile Rank
Shows the provider’s position relative to peers in the same role.

Examples:
“99.7th Percentile (High Outlier)”
“45th Percentile (Normal)”

This is the primary benchmarking metric.

5. Claims / Patients Summary
These are provider‑level metrics, not fact‑level totals.
They help identify:
- High‑volume providers
- Unusual patient panel sizes
- Potential outliers in utilization

They use:
```dax
Claims per Provider = DIVIDE([Total Claims], [Distinct Providers])
Patients per Provider = DIVIDE([Total Patients], [Distinct Providers])
```
These metrics show:
- Whether the provider handles unusually high volume
- Whether their patient panel size is typical
- Whether they are an outlier in utilization

6. Provider Profile Block
Includes:
- Provider name
- NPI
- Entity type
- Primary taxonomy
- State
- Ranking (e.g., “Top 10 Individual”)
- Data quality flags

This block consolidates provider identity and integrity indicators.

7. Provider Trends (2018–2025)
Three trend visuals:
- Paid Amount Trend
- Claims Trend
- Patients Trend

These provide temporal context for provider behavior.

8. HCPCS Category & Breakdown
Summaries of:
- HCPCS category distribution
- Paid amounts by category
- Useful for identifying unusual billing patterns.

9. Peer Comparison Summary
A lightweight, high‑performance alternative to histograms.

Peer Comparison Summary (Lightweight Benchmarking)
(Replaces the heavy percentile‑bin histograms)

This section provides a concise, fast‑loading benchmarking snapshot without requiring distribution visuals.

Peer Comparison Summary (Billing / Servicing)
| Metric | Provider Value | Peer Median | Peer 90th Percentile | Interpretation |
| --- | --- | --- | --- | --- |
| **Total Paid Amount** | $X | $Y | $Z | Provider is above/below peers |
| **Claims per Provider** | X | Y | Z | High/normal/low volume |
| **Patients per Provider** | X | Y | Z | Large/small patient panel |
| **Paid Amount Percentile** | 99.7% | — | — | High outlier |
| **Risk Tier** | High | — | — | Elevated integrity risk |

Purpose of this summary
- Gives users immediate peer context
- Avoids heavy DAX and large cardinality visuals
- Loads instantly even with 2M+ providers
- Provides actionable integrity insights

How it works
- Uses pre‑computed percentiles from PROVIDER_ROLE_PERCENTILE
- Uses role‑filtered peer medians and P90 values
- Requires no binning or histograms

---

📘 12.3 Page 3 — Provider Drillthrough (High‑Detail Provider Profile)
Purpose: Provide a deep‑dive diagnostic profile for a single provider selected from the Top 10 Organizations or Top 10 Individuals tables on the Executive Overview page.
This page is not a general provider browser. It is intentionally restricted to high‑impact providers surfaced by the executive‑level Top‑N visuals.

Access Rules
- This page is only accessible via drillthrough from:
- Top 10 Organizations (Page 1)
- Top 10 Individuals (Page 1)
- Users cannot manually navigate to this page to search for arbitrary NPIs.
- This design ensures the drillthrough is used for targeted investigation, while broader provider benchmarking is handled by the Provider Integrity Scorecard (Page 2).

⭐ Analytical Role of the Drillthrough Page
The drillthrough page answers:
- "What exactly is happening with THIS provider?”
It provides fact‑level, time‑series, and category‑level insights that cannot be shown on the Scorecard page.
It is used during investigations, audits, and program integrity reviews.

Key Visuals & Components
1. Provider Identity Block
Displays enriched provider attributes from PROVIDER_DIM:
- Provider Display Name
- NPI
- Entity Type (Individual / Organization)
- State (cleaned PROVIDER_STATE_US)
- Primary Taxonomy
- Risk Score (moved here from KPI row)

This block anchors the drillthrough context and ensures the user always knows which provider is being analyzed.

2. Provider Performance KPIs
Dynamic KPIs driven by FACT_MEDICAID_PROVIDER_SPENDING:
- Total Paid Amount
- Total Claims
- Total Patients
- Average Patients per Month
- Average Paid Amount per Claim
- Paid Amount Percentile Rank

All KPIs respect the Billing vs Servicing toggle, which activates the appropriate relationship via USERELATIONSHIP.

3. Trend Visuals (Time Series)
Three full‑width line charts showing multi‑year patterns:
- Paid Amount Trend
- Claims Trend
- Patients Trend

These visuals reveal utilization stability, seasonality, and anomalies.
They also inherit the Full‑Month Filtering logic to avoid misleading declines from incomplete months.

4. HCPCS & Category Mix Analysis
Breakdown of provider billing behavior:
- HCPCS Category Mix (donut or stacked bar)
- Top HCPCS Codes (ranked bar chart)
- Top HCPCS Code, Description, and Paid Amount (dynamic measures)

This section answers what the provider is billing for and whether their service mix is typical for their taxonomy.

5. Data Quality Indicators (DQ Zone)
A compact bottom row (~150px) highlighting data governance issues:
- Invalid NPI Flag
- Missing Taxonomy Flag
- Missing State Flag
- Missing HCPCS Category Flag

These indicators reinforce transparency and trust in the provider profile.

⭐ Why This Page Is Different from the Provider Integrity Scorecard
The Provider Integrity Scorecard (Page 2) is a benchmarking dashboard that evaluates provider performance relative to peers using PROVIDER_DIM.

The Provider Drillthrough Page (Page 3) is a diagnostic deep dive into a single provider’s fact‑level behavior.

Together:
- Scorecard = Who should we investigate?
- Drillthrough = What is happening with this provider?

This separation ensures a clean analytical workflow and prevents misuse of the drillthrough page as a general provider explorer.

| KPI | Formatting | Purpose |
| --- | --- | --- |
| **Paid Amount Percentile Rank** | Red/Orange/Green | Risk outlier detection |
| **Average Paid Amount per Claim** | Red/Orange/Green | Billing intensity anomalies |
| **Total Patients** | Red/Orange/Green | Volume anomalies |
| **Total Claims** | Red/Orange/Green | Low‑activity warnings |
| **Risk Score** | Red/Orange/Green | Integrity tier |

---
## 📘 12.4 Page 4 — HCPCS Explorer
**Purpose:** Drill into procedure‑level utilization and spend.

**Key Visuals**
- Distinct HCPCS Count
- Top HCPCS by Paid Amount
- HCPCS → Description → Paid Amount matrix
- Service Category slicer
- Paid Amount Trend by HCPCS Category

This page showcases the integration of `HCPCS_DIM` and supports clinical + financial analysis. It answers the questions: 
- What services are being billed?
- How much they cost?
- How they trend over time?
- Which categories dominate?
- Which HCPCS codes drive spend?

---

## 📘 12.5 Page 5 — Service Category Analytics
**Purpose:** Understand utilization and spend across OP / RX / OTHER categories.

**Key Visuals**
- Donut: OP vs RX vs OTHER
- Trend: Paid Amount by Category over Time
- Category Table: Claims, Paid Amount, Patients
- Category‑specific KPIs

This page highlights the derived `SERVICE_CATEGORY` logic and category‑level insights.

---

## 📘 12.6 Page 6 — Data Quality & Anomaly Detection
**Purpose:** Monitor data quality issues, anomalies, and pipeline health.

**Key Visuals**
- Invalid NPI Trend (`DQ_INVALID_NPI_TREND`)
- Anomaly Flags (`DQ_INVALID_NPI_ANOMALIES`)
- Quarantine Row Counts (from STAGE quarantine logic)
- Data Incident Timeline
- “Top Offenders” table (providers with repeated DQ issues)

This page demonstrates your data engineering rigor and DQ governance.

---

## 📘 12.7 Page 7 — Documentation & Lineage
**Purpose:** Provide transparency and reproducibility for stakeholders and portfolio reviewers.

**Content**
- Snowflake MODEL layer diagram
- Star schema diagram (FACT + PROVIDER_DIM)
- DAX conventions
- Data sources
- Versioning & Change Log
- S2T summary

This page reinforces the professionalism and completeness of the analytics solution.

---

## 📝 Provider Risk Score Measure
Risk Score is a provider integrity indicator derived from the PROVIDER_ROLE_PERCENTILE model.
It classifies Medicaid providers based on their total paid amount relative to all other providers in the same role (Billing or Servicing).

This is not a clinical risk score or CMS RAF score.
It is a financial and behavioral outlier score used for Medicaid program integrity.

How It Works
- Total paid amounts are aggregated separately for Billing and Servicing providers.
- Providers are ranked using a percentile distribution within each role.
- Percentile values are categorized into risk tiers:

| Percentile Range | Risk Tier            | Interpretation                                                                            |
| ---------------- | -------------------- | ----------------------------------------------------------------------------------------- |
| ≥ 90%            | **High Risk**        | Provider is a top outlier in Medicaid paid amounts; may warrant program integrity review. |
| 70–89%           | **Medium Risk**      | Provider bills above typical levels; monitor depending on service mix and growth trends.  |
| < 70%            | **Normal** (Low risk)| Provider billing patterns fall within normal Medicaid utilization.                        |


Purpose
- The Risk Score helps identify:
- High‑volume or atypical billing patterns
- Potential fraud, waste, or abuse indicators
- Providers requiring additional oversight or review
- Outlier behavior compared to peer groups

Usage in Power BI
- Risk Score is calculated using the percentile column from the PROVIDER_ROLE_PERCENTILE model.
- The Provider Role slicer (Billing/Servicing) determines which percentile is used.
- The score supports drillthrough pages, integrity dashboards, and provider‑level monitoring.


# 13. Versioning & Change Log
| Version | Date       | Author   | Description                              |
| ------- | ---------- | -------- | ---------------------------------------- |
| 1.0     | 2026‑04‑05 | Mairilyn | Initial dashboard design + DAX guidelines |
| 1.1     | 2026‑05‑19 | Mairilyn | Added Data Completeness KPI, Full‑Month Filtering logic, and updated Paid Amount Trend to exclude incomplete months |
| 1.2     | 2026‑05‑22 | Mairilyn | Added Provider_Role_Percentile and relationship to Provider_DIM|

---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
