📄 15 — DATE_DIM & SERVICE_CATEGORY_DIM (MODEL Layer)
## Medicaid Claims Analytics — Snowflake Data Warehouse

This document describes the two semantic dimensions created in the MODEL layer to support Power BI analytics:

- DATE_DIM — a full calendar dimension for time intelligence
- SERVICE_CATEGORY_DIM — a clinical grouping dimension for HCPCS codes

Both dimensions are generated programmatically and do not originate from a source dataset. They are essential for BI modeling, filtering, drill‑downs, and semantic clarity.

# 🗓️ 1. DATE_DIM — Date Dimension
Purpose
The Medicaid dataset includes service dates but does not provide a dedicated date dimension.
DATE_DIM enables:
- Time intelligence (YTD, MTD, rolling 12 months)
- Calendar hierarchies (Year → Quarter → Month → Day)
- Consistent reporting across FACT tables
- Power BI relationships and slicers

Grain:
1 row per calendar date

Source:
Generated programmatically using a date range derived from the FACT table (CLAIM_MONTH).

| Column | Type | Description |
| --- | --- | --- |
| ``DATE_KEY`` | NUMBER | Surrogate key in YYYYMMDD format |
| ``DATE`` | DATE | Actual calendar date |
| ``YEAR`` | NUMBER | Calendar year |
| ``QUARTER`` | NUMBER | Calendar quarter (1–4) |
| ``MONTH`` | NUMBER | Calendar month (1–12) |
| ``MONTH_NAME`` | VARCHAR | Full month name (e.g., “January”) |
| ``YEAR_MONTH`` | VARCHAR | BI-friendly label (YYYY‑MM) |
| ``DAY_OF_MONTH`` | NUMBER | Day of month (1–31) |
| ``DAY_NAME`` | VARCHAR | Day of week name |
| ``IS_WEEKEND`` | BOOLEAN | Weekend indicator |

Transformation Logic:
DATE_DIM is generated using a date series:
```sql
SELECT 
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD')) AS DATE_KEY,
    d AS DATE,
    YEAR(d) AS YEAR,
    QUARTER(d) AS QUARTER,
    MONTH(d) AS MONTH,
    TO_CHAR(d, 'Month') AS MONTH_NAME,
    TO_CHAR(d, 'YYYY-MM') AS YEAR_MONTH,
    DAY(d) AS DAY_OF_MONTH,
    TO_CHAR(d, 'Day') AS DAY_NAME,
    CASE WHEN DAYOFWEEK(d) IN (6,7) THEN TRUE ELSE FALSE END AS IS_WEEKEND
FROM TABLE(GENERATOR(ROWCOUNT => 20000))  -- ~55 years of dates
QUALIFY d BETWEEN '2000-01-01' AND CURRENT_DATE();
```

🏥 2. SERVICE_CATEGORY_DIM — Clinical Service Grouping
Purpose
HCPCS codes are highly granular.
SERVICE_CATEGORY_DIM groups them into high‑level clinical categories for:
- Slicers and filters
- Provider performance comparisons
- Trend analysis
- Executive dashboards

Grain
1 row per service category

Source
Derived from HCPCS patterns and Medicaid business rules.

SERVICE_CATEGORY_DIM Schema
| Column | Type | Description |
| --- | --- | --- |
| ``SERVICE_CATEGORY`` | VARCHAR | Category label (RX, ED, IP, OP, OTHER) |
| ``DESCRIPTION`` | VARCHAR | Human-readable description |
| ``LOGIC`` | VARCHAR | Pattern or rule used to classify |

Transformation Logic
CASE Logic (Model Layer)
```sql
CASE 
    WHEN HCPCS_CODE LIKE 'J%' THEN 'RX'          -- Injectable drugs
    WHEN HCPCS_CODE LIKE '99%' THEN 'ED'         -- Emergency department
    WHEN HCPCS_CODE LIKE '1%' THEN 'IP'          -- Inpatient
    WHEN HCPCS_CODE LIKE '2%' THEN 'OP'          -- Outpatient
    ELSE 'OTHER'
END
```

Descriptions
| Category | Description |
| --- | --- |
| RX | Drug-related services (J-codes) |
| ED | Emergency department services |
| IP | Inpatient hospital services |
| OP | Outpatient hospital services |
| OTHER | All other HCPCS categories |

🔗 3. Integration With FACT Table
FACT_MEDICAID_PROVIDER_SPENDING
Uses:
- CLAIM_MONTH → joins to DATE_DIM.DATE
- HCPCS_CODE → maps to SERVICE_CATEGORY_DIM.SERVICE_CATEGORY

This enables:
- Monthly trend charts
- Service category breakdowns
- Provider performance by clinical grouping
- Time‑series forecasting

📁 4. SQL Reference
The full implementation is stored in:
```sql
/sql/model/date_and_service_dimensions.sql
```

This script:
- Generates DATE_DIM
- Generates SERVICE_CATEGORY_DIM
- Applies surrogate keys
- Ensures BI‑ready formatting

📊 5. Why These Dimensions Matter
DATE_DIM
- Enables time intelligence
- Supports Power BI hierarchies
- Standardizes date logic across the warehouse

SERVICE_CATEGORY_DIM
- Simplifies HCPCS complexity
- Enables clinical rollups
- Supports executive dashboards
- Improves interpretability of Medicaid spending

🧭 6. Future Enhancements
- Add fiscal year support (FY2024, FY2025…)
- Add holiday indicators (CMS, federal, state)
- Add Medicaid‑specific service groupings (e.g., LTSS, behavioral health)
- Add DRG‑based categories for inpatient claims