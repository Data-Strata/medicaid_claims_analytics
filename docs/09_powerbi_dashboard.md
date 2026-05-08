## 📄 Medicaid Provider Spending — Power BI Dashboard Design & DAX Guidelines  

# 1. Overview
This document defines the Power BI dashboard architecture, page layouts, semantic model design, and DAX measure standards for the Medicaid Provider Spending Analytics project.

The goal is to ensure:
- Consistent, reproducible Power BI development
- A clean star schema aligned with the Snowflake MODEL layer
- A single enterprise‑grade Measures table
- Professional dashboard pages suitable for portfolio and stakeholder review

*Note* Provider State Cleanup (Snowflake MODEL Layer)
The dashboard relies on a cleaned U.S. state field created in Snowflake.
The raw PRACTICE_STATE and MAILING_STATE fields contained global values and inconsistent formats.
A transformation script (/sql/clean_provider_states.sql) generates:
- PRACTICE_STATE_US
- MAILING_STATE_US
- PROVIDER_STATE_US
Power BI uses PROVIDER_STATE_US for all map visuals.

# 2. Power BI Semantic Model

2.1 Tables Imported (Import Mode)
From ANALYTICS_MEDICAID.MODEL:
- FACT_MEDICAID_PROVIDER_SPENDING
- NPI_DIM
- SERVICING_PROVIDER_DIM (duplicate of NPI_DIM)
- HCPCS_DIM
- DATE_DIM
- SERVICE_CATEGORY_DIM

2.2 Star Schema Diagram
```code
                   ┌───────────────────────────┐
                   │        DATE_DIM           │
                   └──────────────┬────────────┘
                                  │ 1:* (single direction)
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
│         NPI_DIM           │   │       HCPCS_DIM           │
└───────────────────────────┘   └───────────────────────────┘

                                  │
                                  ▼

                   ┌───────────────────────────┐
                   │  SERVICE_CATEGORY_DIM     │
                   └───────────────────────────┘

```

# 2.3 Relationship Rules

| From Table                      | Column                 | To Table               | Column           | Type                |
| ------------------------------- | ---------------------- | ---------------------- | ---------------- | ------------------- |
| FACT_MEDICAID_PROVIDER_SPENDING | CLAIM_MONTH            | DATE_DIM               | DATE_KEY         | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | BILLING_PROVIDER_NPI   | NPI_DIM                | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICING_PROVIDER_NPI | SERVICING_PROVIDER_DIM | NPI              | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | HCPCS_CODE             | HCPCS_DIM              | HCPCS_CODE       | Many-to-One, Single |
| FACT_MEDICAID_PROVIDER_SPENDING | SERVICE_CATEGORY       | SERVICE_CATEGORY_DIM   | SERVICE_CATEGORY | Many-to-One, Single |


# 2.4 Provider Dimension – Data Quality Notes (NPI Registry)
Nameless Organizations (23 Records)
After applying the corrected NPI ingestion and cleaning logic, only 23 NPIs remain where:

+ ENTITY_TYPE_CODE = 2 (Organization)
+ ORG_NAME is NULL
+ FIRST_NAME, MIDDLE_NAME, LAST_NAME are NULL
+ FULL_NAME is NULL
+ Taxonomy, addresses, and enumeration dates are present

These represent legitimate organizations that have been enumerated by CMS but have not yet provided a legal business name.
They appear in claims and must remain in the model for referential integrity.

How They Are Handled in the Semantic Model
These NPIs are assigned:
```code
Provider Display Name = "Unknown Organization"
Provider Type = "Organization"
```
This prevents blank labels in visuals and ensures spend/claims remain attributed correctly.

# 3. Measures Table Standards
3.1 Measures Table Creation
Create a dedicated table:
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
- Avoid column references without aggregation
- Document complex measures with comments

3.4 Provider Display Name Logic (Individuals & Organizations)
The NPI Registry stores names differently depending on provider type:

```code
| Provider Type     | entity_type_code | Name Fields                                    |
| ----------------- | ---------------- | ---------------------------------------------- |
| **Individual**    | 1                | FIRST_NAME, MIDDLE_NAME, LAST_NAME → FULL_NAME |
| **Organization**  | 2                | ORG_NAME                                       |
```
To ensure consistent labeling across all visuals, a unified display name is created.

Dax Logic
```code
Provider Display Name =
VAR Name =
    IF (
        NOT ISBLANK ( NPI_DIM[FULL_NAME] ),
        NPI_DIM[FULL_NAME],
        NPI_DIM[ORG_NAME]
    )
RETURN
IF (
    ISBLANK(Name),
    "Unknown Organization",
    Name
)
```
Behavior
- Individuals → “FIRST LAST” or “FIRST MIDDLE LAST”
- Organizations → ORG_NAME
- Nameless organizations (23 rows) → “Unknown Organization”

This ensures:
- No blank labels
- Correct billing entity representation
- Accurate Top‑N provider rankings
- Consistent naming across all visuals

# 4. Core DAX Measures
4.1 Claims, Paid Amount, Patients
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

4.2 Distinct Entities
```DAX
Distinct Providers =
DISTINCTCOUNT ( FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI] )

Distinct HCPCS Codes =
DISTINCTCOUNT ( FACT_MEDICAID_PROVIDER_SPENDING[HCPCS_CODE] )
```DAX
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
CALCULATE ( [Total Paid Amount], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "OP" )

RX Claims Paid Amount =
CALCULATE ( [Total Paid Amount], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "RX" )

Other Claims Paid Amount =
CALCULATE ( [Total Paid Amount], FACT_MEDICAID_PROVIDER_SPENDING[SERVICE_CATEGORY] = "Other" )
```

# 6. Provider Analytics Measures
```DAX
Paid Amount per Provider =
DIVIDE ( [Total Paid Amount], [Distinct Providers] )

Claims per Provider =
DIVIDE ( [Total Claims], [Distinct Providers] )
```

# 7. HCPCS Analytics Measures
```DAX
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
```DAX
Paid Amount Rolling 12M =
CALCULATE (
    [Total Paid Amount],
    DATESINPERIOD ( DATE_DIM[DATE_KEY], MAX ( DATE_DIM[DATE_KEY] ), -12, MONTH )
)
```

# 9. Top‑N Measures

```DAX
Top 10 Providers Paid Amount =
IF (
    RANKX (
        ALL ( FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI] ),
        [Total Paid Amount],
        ,
        DESC
    ) <= 10,
    [Total Paid Amount]
)
```

# 10. Continental U.S. State Filtering (Filled Map Configuration)
To ensure the Filled Map visual displays only the continental United States, a dedicated calculated column was added to the NPI_DIM table. This avoids rendering Alaska, Hawaii, and U.S. territories, which distort the map scale and reduce geographic clarity for Medicaid provider analytics.

Calculated Column: Is_Continental_US
A new column was created in NPI_DIM:
```code
Is_Continental_US =
IF (
    NPI_DIM[PROVIDER_STATE_US] IN {
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

How It Is Used in the Dashboard
Filled Map Filter - Apply the following filter to the map visual:
```code
Is_Continental_US = 1
```
This restricts the map to:
- The 48 contiguous U.S. states
- All providers whose practice or mailing state falls within that region

Benefits
- Cleaner geographic storytelling
- Accurate density shading
- Better alignment with Medicaid provider distribution
- Improved readability for executive dashboards

---
# 11. Dashboard Pages

Page 1 — Provider Analytics

Page 2 — Outlier Detection

Page 3 — HCPCS Analytics

Page 4 — Service Category Analytics

Page 5 — Trends (MoM, YoY, Rolling)

Page 6 - Documentation


📘 11.1 Page 1 — Provider Analytics
This page provides a high-level overview of provider performance, spend distribution, and geographic patterns across Medicaid claims.

Purpose: Provider-level cost & utilization insights

Details
1. KPI Row
Measures Used
- `Total Paid Amount`
- `Total Claims`
- `Distinct Providers`
- `Average Paid per Claim`

Purpose
Provides an executive snapshot of overall program spend and utilization.

2. Slicer Bar (Horizontal)
Slicers
- `Provider Role` (Billing vs Servicing)
- `Service Category` (OP, RX, OTHER)
- `Year` / `Month`

Purpose
Controls all visuals on the page and enables multi-dimensional filtering.

# Why it matters 

Billing vs Servicing Provider (Medicaid Claims Context)

Medicaid claims contain two different provider NPIs, each representing a different role:
 - Billing Provider NPI -> The entity that submits the claim and receives payment. Often a clinic, hospital, group practice, or billing organization.
 - Servicing Provider NPI -> The clinician who performed the service (rendering provider). Represents the individual tied to the HCPCS/procedure.

These roles are not interchangeable.

A single billing entity may represent hundreds of servicing providers, and a servicing provider may appear under multiple billing entities.

The dashboard includes a toggle to allow users to analyze spend and utilization from either perspective.

3. Spend Trend (Line Chart)
Axis: Date (`YearMonth`)
Values: `Total Paid Amount`
Purpose
Shows spend patterns over time and highlights seasonal or policy-driven shifts.

4. Spend by Service Category (Bar Chart)
Axis: `Service Category`
Values: `Total Paid Amount`
Purpose
Breaks down spend by OP, RX, and OTHER categories.

5. Top Providers by Paid Amount (Dynamic Bar Chart)
Axis: Selected Provider NPI
Values: `Paid Amount – Selected Provider`
Title: Dynamic (Billing vs Servicing)

Key Measures
```code
Selected Provider NPI = ...
Paid Amount – Selected Provider = ...
Title – Provider View = ...
```
Purpose
Highlights the highest-spend providers based on the selected provider role.

🟦 Top Providers by Paid Amount (Updated Logic)
The original visual filtered out blank full_name values, which unintentionally removed all organization NPIs (entity_type_code = 2).
This caused the bar chart to show only individual clinicians, not billing entities — resulting in incorrect top‑provider rankings.

The updated logic uses the unified Provider Display Name column and removes the [full_name] <> BLANK() filter entirely.

Visual Configuration
Axis
`NPI_DIM[Provider Display Name]`
Values
`Paid Amount – Selected Provider`
Sort
`Paid Amount – Selected Provider (Descending)`
Title
`Title – Provider View`

Key Measures
Selected Provider NPI
```code
Selected Provider NPI =
SWITCH(
    SELECTEDVALUE(ProviderRole_Slicer[ProviderRole]),
    "Billing", SELECTEDVALUE(FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI]),
    "Servicing", SELECTEDVALUE(FACT_MEDICAID_PROVIDER_SPENDING[SERVICING_PROVIDER_NPI]),
    SELECTEDVALUE(FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI])
)
```

Paid Amount – Selected Provider
```code
Paid Amount – Selected Provider =
CALCULATE(
    [Total Paid Amount],
    KEEPFILTERS(
        FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI] =
            IF(
                SELECTEDVALUE(ProviderRole_Slicer[ProviderRole]) = "Billing",
                FACT_MEDICAID_PROVIDER_SPENDING[BILLING_PROVIDER_NPI],
                FACT_MEDICAID_PROVIDER_SPENDING[SERVICING_PROVIDER_NPI]
            )
    )
)
```

Dynamic Title
```code
Title – Provider View =
VAR SelectedRole =
    SELECTEDVALUE(ProviderRole_Slicer[ProviderRole], "Billing")
RETURN
"Top Providers by Paid Amount (" & SelectedRole & " Provider)"
```

🟦 Why This Update Matters
- Ensures organizations (billing entities) appear correctly
- Removes bias toward individual clinicians
- Prevents blank labels
- Aligns with Medicaid claim structure
- Produces accurate top‑provider rankings
- Makes the Billing vs Servicing toggle meaningful
- Supports downstream analytics (map, table, outlier detection)



6. Paid Amount by Provider State (Filled Map)
Location: `Provider State`
Values: `Total Paid Amount`
Filter: `Is_Continental_US = 1`
Purpose
Shows geographic distribution of spend across the continental U.S.

7. Provider Details Table
Columns
- NPI
- Provider Name
- Practice State
- Paid Amount
- Claims
- Total Patients
- Paid Amount per Provider
- Claims per Provider
- Percentile Rank
- Risk Score

Enhancements
7.1 Conditional Formatting – Paid Amount (Blue Gradient)
The Paid Amount column uses a blue gradient background scale to highlight relative spend levels while maintaining a clean, professional aesthetic consistent with the dashboard’s theme.
```code
| Value Range | Color | Meaning |
| --- | --- | --- |
| Low Paid Amount | ``#D6EAF8`` (light blue) | Lower spend relative to peers |
| High Paid Amount | ``#1B4F72`` (dark navy) | Higher spend relative to peers |
```

Purpose:
- Quickly identify high‑spend providers
- Maintain readability in large tables
- Align with the map and KPI color palette
- Provide subtle but meaningful visual cues

7.2 Tooltip: Paid Amount Percentile Rank
A custom tooltip displays each provider’s percentile rank based on Paid Amount, enabling users to understand where a provider sits in the overall distribution.
```code
Paid Amount Percentile =
VAR CurrentPaid =
    SELECTEDVALUE(FACT_MEDICAID_PROVIDER_SPENDING[PAID_AMOUNT])
VAR Percentile =
    PERCENTILEX.INC(
        ALL(FACT_MEDICAID_PROVIDER_SPENDING),
        FACT_MEDICAID_PROVIDER_SPENDING[PAID_AMOUNT],
        CurrentPaid
    )
RETURN
FORMAT(Percentile, "0%")
```
Usage
- Add this measure to the Tooltips field of:
- Provider Details table
- Top Providers bar chart
- Paid Amount map

Interpretation Examples:
92% → Provider is in the top 8% of spend
50% → Median spend
10% → Low spend

7.3 Paid Amount Risk Score (Low / Medium / High)
A percentile‑based risk score classifies providers into Low, Medium, or High spend categories. This supports outlier detection, audit workflows, and executive prioritization.

DAX Column
```code
Paid Amount Risk Score =
VAR Paid = FACT_MEDICAID_PROVIDER_SPENDING[PAID_AMOUNT]
VAR P90 =
    CALCULATE(
        PERCENTILEX.INC(
            ALL(FACT_MEDICAID_PROVIDER_SPENDING),
            FACT_MEDICAID_PROVIDER_SPENDING[PAID_AMOUNT],
            0.90
        )
    )
VAR P50 =
    CALCULATE(
        PERCENTILEX.INC(
            ALL(FACT_MEDICAID_PROVIDER_SPENDING),
            FACT_MEDICAID_PROVIDER_SPENDING[PAID_AMOUNT],
            0.50
        )
    )
RETURN
SWITCH(
    TRUE(),
    Paid >= P90, "High",
    Paid >= P50, "Medium",
    "Low"
)
```

Risk Score Definitions
| Score      | Meaning |
| ---------- | -------------------------------- |
| **High**   | Provider is in the top 10% of spend |
| **Medium** | Provider is between the 50th–90th percentile |
| **Low**    | Provider is below the median |


Recommended Uses
- Add to Provider Details table
- Use as a filter for outlier analysis
- Add to tooltips for context
- Pair with conditional formatting for categorical highlighting

---

📘 11.2 Page 2 — HCPCS Analytics
Purpose: Procedure-level cost & utilization
Visuals:
- KPI cards: Distinct HCPCS, Paid per HCPCS
- Bar chart: Top HCPCS by Paid Amount
- Matrix: HCPCS → Description → Paid Amount
- Slicer: Service Category

📘 11.3 Page 3 — Service Category (OP/RX/OTHER)
Purpose: Category-level utilization
Visuals:
- Donut: OP vs RX vs OTHER
- Trend: Paid Amount by Category over Time
- Table: Category → Claims → Paid Amount

📘 11.4 Page 4 — Trends (MoM, YoY, Rolling)
Purpose: Time intelligence
Visuals:
- Line chart: Paid Amount Rolling 12M
- Line chart: Paid Amount YoY
- Bar chart: Paid Amount MoM

📘 11.5 Page 5 — Documentation
Purpose: Transparency & reproducibility
Content:
- Data sources
- Snowflake MODEL layer diagram
- DAX conventions
- Versioning & Change Log


# 11. Versioning & Change Log
| Version | Date       | Author   | Description                              |
| ------- | ---------- | -------- | ---------------------------------------- |
| 1.0     | 2026‑04‑05 | Mairilyn | Initial dashboard design + DAX guidelines|
| 1.1     | 2026‑05‑01 | Mairilyn | Dashboard Page 1 and DAX measure updates |


---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
