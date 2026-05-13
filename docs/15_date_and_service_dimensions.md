📄 15 — DATE_DIM & SERVICE_CATEGORY_DIM (MODEL Layer)
## Medicaid Claims Analytics — Snowflake Data Warehouse

This document describes the two semantic dimensions created in the MODEL layer to support Power BI analytics:

- DATE_DIM — a full calendar dimension for time intelligence
- SERVICE_CATEGORY_DIM — a clinical grouping dimension for HCPCS codes

Both dimensions are generated programmatically and do not originate from a source dataset. They are essential for BI modeling, filtering, drill‑downs, and semantic clarity.

# 🗓️ 1. DATE_DIM — Date Dimension
Purpose
The Medicaid dataset includes service dates but does not provide a dedicated date dimension.
DATE_DIM provides:
- Time intelligence (YTD, MTD, rolling 12M)
- Calendar hierarchies (Year → Quarter → Month → Day)
- Consistent reporting across FACT tables
- A clean relationship to FACT.CLAIM_MONTH
- Power BI‑ready fields (DATE_KEY, YEAR_MONTH, MONTH_NAME)

Grain
1 row per calendar date
(2018‑01‑01 → 2027‑12‑31)

Source
Generated programmatically in the MODEL layer.
Not sourced from RAW or STAGE.

🧱 DATE_DIM Schema (Updated)
| Column              | Type     | Description |
| ------------------- | -------- | ------------------------------------------------------- |
| ``DATE_KEY``        | **DATE** | Primary key used for FACT joins (must match CLAIM_MONTH) |
| ``YEAR``            | NUMBER   | Calendar year |
| ``QUARTER``         | NUMBER   | Calendar quarter (1–4) |
| ``MONTH``           | NUMBER   | Calendar month (1–12) |
| ``MONTH_NAME``      | VARCHAR  | Full month name |
| ``YEAR_MONTH``      | VARCHAR  | BI-friendly label (YYYYMM) |
| ``DAY_OF_MONTH``    | NUMBER   | Day of month |
| ``DAY_NAME``        | VARCHAR  | Day of week name |
| ``DAY_OF_WEEK``     | NUMBER   | Numeric day of week |
| ``WEEK_OF_YEAR``    | NUMBER   | Week number |
| ``DATE_TEXT``       | VARCHAR  | YYYY‑MM‑DD text format |
| ``MONTH_NAME_YEAR`` | VARCHAR  | “Mon YYYY” |
| ``YEAR_MONTH_TEXT`` | VARCHAR  | “YYYY‑MM” |

🛠️ Transformation Logic (Updated SQL)

```sql
CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.DATE_DIM AS
WITH RECURSIVE dates AS (
    SELECT DATE('2018-01-01') AS dt
    UNION ALL
    SELECT DATEADD(day, 1, dt)
    FROM dates
    WHERE dt < DATE('2027-12-31')
)
SELECT
    dt AS DATE_KEY,                         -- Must be DATE (not TIMESTAMP)
    YEAR(dt) AS YEAR,
    QUARTER(dt) AS QUARTER,
    MONTH(dt) AS MONTH,
    TO_CHAR(dt, 'Month') AS MONTH_NAME,
    TO_CHAR(dt, 'YYYYMM') AS YEAR_MONTH,
    DAY(dt) AS DAY_OF_MONTH,
    TO_CHAR(dt, 'Day') AS DAY_NAME,
    DAYOFWEEK(dt) AS DAY_OF_WEEK,
    WEEKOFYEAR(dt) AS WEEK_OF_YEAR,
    TO_VARCHAR(dt, 'YYYY-MM-DD') AS DATE_TEXT,
    TO_VARCHAR(dt, 'Mon YYYY') AS MONTH_NAME_YEAR,
    TO_VARCHAR(dt, 'YYYY') || '-' || LPAD(MONTH(dt), 2, '0') AS YEAR_MONTH_TEXT
FROM dates
ORDER BY dt;
```

🔗 Integration With FACT Table (Updated)
FACT_MEDICAID_PROVIDER_SPENDING uses:
```code
| FACT Column     | DATE_DIM Column | Notes |
| --------------- | --------------- | ------- |
| ``CLAIM_MONTH`` | ``DATE_KEY``    | Both must be **DATE** datatype |
| ``CLAIM_MONTH`` always uses the **first day of the month** | DATE_DIM contains all days | Relationship works because DATE_KEY is DATE |
```

Relationship Rules
 - FACT → DATE_DIM
 - CLAIM_MONTH → DATE_KEY
 - Many‑to‑One
 - Single direction
 - Active

Power BI Sorting
YEAR_MONTH → Sort by → DATE_KEY

Axis for trend charts → DATE_KEY (continuous)


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
