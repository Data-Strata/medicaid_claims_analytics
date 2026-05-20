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

No monthly FACT tables are imported.

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

                                  │
                                  ▼

                   ┌───────────────────────────┐
                   │  SERVICE_CATEGORY_DIM     │
                   └───────────────────────────┘
```

# 2.3 Relationship Rules

| From Table                      | Column                 | To Table             | Column           | Type                |
| ------------------------------- | ---------------------- | -------------------- | ---------------- | ------------------- |
| FACT_MEDICAID_PROVIDER_SPENDING | CLAIM_MONTH            | DATE_DIM             | DATE_KEY         | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | BILLING_PROVIDER_NPI   | PROVIDER_DIM         | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICING_PROVIDER_NPI | PROVIDER_DIM         | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | HCPCS_CODE             | HCPCS_DIM            | HCPCS_CODE       | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICE_CATEGORY       | SERVICE_CATEGORY_DIM | SERVICE_CATEGORY | Many-to-One, Single |


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
---

# 11. Dashboard Pages (Updated)

The Medicaid Provider Spending dashboard is organized into **six pages**, each serving a distinct analytical purpose. 
The layout follows a logical narrative: executive overview → provider integrity → clinical utilization → category insights → data quality → documentation.

---

## 📘 11.1 Page 1 — Medicaid Spending Overview

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

## 📘 11.2 Page 2 — Provider Integrity Scorecard
**Purpose:** Evaluate provider performance, risk, and utilization patterns using the cleaned `PROVIDER_DIM`.

**Key Visuals**
- Provider Risk Score (High / Medium / Low)
- Paid Amount Percentile Rank
- Claims per Provider / Patients per Provider
- Provider Details Table (with conditional formatting)
- Billing vs Servicing Provider toggle

This page highlights your provider‑level enrichment, risk scoring, and integrity analytics.

---

## 📘 11.3 Page 3 — HCPCS Explorer
**Purpose:** Drill into procedure‑level utilization and spend.

**Key Visuals**
- Distinct HCPCS Count
- Top HCPCS by Paid Amount
- HCPCS → Description → Paid Amount matrix
- Service Category slicer
- Paid Amount Trend by HCPCS Category

This page showcases the integration of `HCPCS_DIM` and supports clinical + financial analysis.

---

## 📘 11.4 Page 4 — Service Category Analytics
**Purpose:** Understand utilization and spend across OP / RX / OTHER categories.

**Key Visuals**
- Donut: OP vs RX vs OTHER
- Trend: Paid Amount by Category over Time
- Category Table: Claims, Paid Amount, Patients
- Category‑specific KPIs

This page highlights the derived `SERVICE_CATEGORY` logic and category‑level insights.

---

## 📘 11.5 Page 5 — Data Quality & Anomaly Detection
**Purpose:** Monitor data quality issues, anomalies, and pipeline health.

**Key Visuals**
- Invalid NPI Trend (`DQ_INVALID_NPI_TREND`)
- Anomaly Flags (`DQ_INVALID_NPI_ANOMALIES`)
- Quarantine Row Counts (from STAGE quarantine logic)
- Data Incident Timeline
- “Top Offenders” table (providers with repeated DQ issues)

This page demonstrates your data engineering rigor and DQ governance.

---

## 📘 11.6 Page 6 — Documentation & Lineage
**Purpose:** Provide transparency and reproducibility for stakeholders and portfolio reviewers.

**Content**
- Snowflake MODEL layer diagram
- Star schema diagram (FACT + PROVIDER_DIM)
- DAX conventions
- Data sources
- Versioning & Change Log
- S2T summary

This page reinforces the professionalism and completeness of the analytics solution.


# 11. Versioning & Change Log
| Version | Date       | Author   | Description                              |
| ------- | ---------- | -------- | ---------------------------------------- |
| 1.0     | 2026‑04‑05 | Mairilyn | Initial dashboard design + DAX guidelines |
| 1.1     | 2026‑05‑19 | Mairilyn | Added Data Completeness KPI, Full‑Month Filtering logic, and updated Paid Amount Trend to exclude incomplete months |


---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
