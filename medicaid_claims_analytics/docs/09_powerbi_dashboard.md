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

# 3. Measures Table Standards
3.1 Measures Table Creation
Create a dedicated table:
```DAX
Measures = { "DAX Measures Table" }
```
All measures must be stored in this table.

3.2 Naming Conventions

| Category          | Convention | Example |
| ----------------- | --- | --- |
| Core measures     | ``<Metric>`` | Total Claims |
| Time intelligence | ``<Metric> ``<Period>`` | Paid Amount Rolling 12M |
| Category measures | ``<Category> ``<Metric>`` | OP Claims |
| Provider analytics| ``<Metric> ``per ``Provider`` | Claims per Provider |
| HCPCS analytics   | ``<Metric> ``per ``HCPCS`` | Paid Amount per HCPCS |
| Top‑N             | ``Top ``<N> ``<Entity> ``<Metric>`` | Top 10 Providers Paid Amount |


3.3 DAX Style Guide
- Use CALCULATE for all filtered measures
- Use DIVIDE() instead of /
- Use VAR blocks for time intelligence
- Avoid implicit measures
- Avoid column references without aggregation
- Document complex measures with comments

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

# 10. Dashboard Pages
10.1 Page 1 — Provider Analytics
Purpose: Provider-level cost & utilization insights
Visuals:
- KPI cards: Total Paid, Total Claims, Distinct Providers
- Bar chart: Top Providers by Paid Amount
- Map: Provider distribution by state
- Table: Provider → Paid Amount, Claims, Patients
- Slicer: Billing vs Servicing Provider

10.2 Page 2 — HCPCS Analytics
Purpose: Procedure-level cost & utilization
Visuals:
- KPI cards: Distinct HCPCS, Paid per HCPCS
- Bar chart: Top HCPCS by Paid Amount
- Matrix: HCPCS → Description → Paid Amount
- Slicer: Service Category

10.3 Page 3 — Service Category (OP/RX/OTHER)
Purpose: Category-level utilization
Visuals:
- Donut: OP vs RX vs OTHER
- Trend: Paid Amount by Category over Time
- Table: Category → Claims → Paid Amount

10.4 Page 4 — Trends (MoM, YoY, Rolling)
Purpose: Time intelligence
Visuals:
- Line chart: Paid Amount Rolling 12M
- Line chart: Paid Amount YoY
- Bar chart: Paid Amount MoM

10.5 Page 5 — Documentation
Purpose: Transparency & reproducibility
Content:
- Data sources
- Snowflake MODEL layer diagram
- DAX conventions
- Versioning & Change Log

# 11. Versioning & Change Log
| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | YYYY‑MM‑DD | Mairilyn | Initial dashboard design + DAX guidelines |

