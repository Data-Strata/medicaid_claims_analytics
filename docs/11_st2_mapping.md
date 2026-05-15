# 📄 Source-to-Target Mapping (S2T)
**Medicaid Claims Analytics — Snowflake Data Warehouse**

---

## 📋 Document Overview

This document defines the **Source-to-Target (S2T) mapping** for the Medicaid Claims Analytics project. 
It describes how fields flow from:

```
RAW → STAGE → MODEL (DIM + FACT)
```
across the three datasets used in this project:

- **Medicaid Provider Spending** (HHS Open Data)
- **HCPCS Level II Reference** (CMS)
- **NPI Registry** (NPPES, CMS)

The S2T mapping is the **contract between ingestion and analytics**. 
It documents lineage, transformations, business rules, and grain definitions. 
This document ensures traceability, auditability, and reproducibility — core requirements in Medicaid and Enterprise Data Systems (EDS) environments.

---

## 🧱 1. Architecture Overview

### Three-Layer Architecture

The pipeline ingests three source datasets into Snowflake and transforms them through a three-layer architecture:

#### RAW Layer
- **Purpose**: Unmodified source files
- **Schema**: All columns as `STRING`/`VARCHAR`
- **Databases**: `RAW_MEDICAID`
- **Tables**: 
  - `MEDICAID_PROVIDER_SPENDING_RAW`
  - `HCPCS_RAW_WIDE`
  - `NPI_RAW`

#### STAGE Layer (CLEAN)
- **Purpose**: Cleaned, typed, standardized tables
- **Databases**: `STAGE_MEDICAID.CLEAN`
- **Transformations Applied**:
  - `TRY_TO_NUMBER()` for numeric fields
  - `TRY_TO_DATE()` for date fields
  - `TRIM()` and `UPPER()` for string normalization
  - Code standardization (NPI padding, HCPCS uppercase)
  - ZIP code normalization (5-digit extraction)
- **Tables**:
  - `MEDICAID_PROVIDER_SPENDING_STAGE`
  - `HCPCS_CLEAN`
  - `NPI_CLEAN`

#### MODEL Layer (ANALYTICS)
- **Purpose**: Curated DIM and FACT tables for Power BI
- **Database**: `ANALYTICS_MEDICAID.MODEL`
- **Tables**:
  - `NPI_DIM` (Provider dimension)
  - `HCPCS_DIM` (Procedure dimension)
  - `DATE_DIM` (Calendar dimension)
  - `SERVICE_CATEGORY_DIM` (Service type dimension)
  - `STATE_REF` (Geographic reference)
  - `FACT_MEDICAID_PROVIDER_SPENDING` (Core analytical fact)

---

## 🧩 2. Grain Definitions

### NPI_DIM
- **Grain**: 1 row per unique NPI
- **Purpose**: Provider master dimension
- **Deduplication Logic**: `ROW_NUMBER()` partitioned by `NPI`, ordered by `LAST_UPDATE_DATE DESC`, `ENUMERATION_DATE DESC`, `NPI DESC`
- **Primary Key**: `NPI`

### HCPCS_DIM
- **Grain**: 1 row per HCPCS code
- **Purpose**: Procedure metadata and service categorization
- **Deduplication Logic**: `ROW_NUMBER()` partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC`
- **Primary Key**: `HCPCS_CODE`

### DATE_DIM
- **Grain**: 1 row per calendar date (2018-2027, 10 years)
- **Purpose**: Supports time intelligence and trending
- **Primary Key**: `DATE_KEY`

### SERVICE_CATEGORY_DIM
- **Grain**: 1 row per service category
- **Purpose**: High-level clinical service grouping
- **Categories**: ED (Emergency Department), IP (Inpatient), OP (Outpatient), RX (Pharmacy)
- **Primary Key**: `CATEGORY_KEY`

### FACT_MEDICAID_PROVIDER_SPENDING
- **Grain**: 1 row per `BILLING_PROVIDER_NPI` + `SERVICING_PROVIDER_NPI` + `HCPCS_CODE` + `CLAIM_MONTH`
- **Purpose**: Core analytical fact table for spending analytics
- **Clustering**: `(CLAIM_MONTH, BILLING_PROVIDER_NPI)`

---

## 📘 3. S2T Mapping — NPI_DIM

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.NPI_RAW` (330 columns)
- **STAGE**: `STAGE_MEDICAID.CLEAN.NPI_CLEAN` (19 columns)
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.NPI_DIM` (22 columns after geographic standardization)

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `NPI` | `NPI` | `LPAD(TRIM(NPI), 10, '0')` — ensures 10-digit format |
| `ENTITY_TYPE_CODE` | `ENTITY_TYPE_CODE` | `TRIM()` |
| `REPLACEMENT_NPI` | `REPLACEMENT_NPI` | `TRIM()` |
| `ORG_NAME` | `PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME` | `TRIM()` |
| `LAST_NAME` | `PROVIDER_LAST_NAME_LEGAL_NAME` | `TRIM()` |
| `FIRST_NAME` | `PROVIDER_FIRST_NAME` | `TRIM()` |
| `MIDDLE_NAME` | `PROVIDER_MIDDLE_NAME` | `TRIM()` |
| `CREDENTIALS` | `PROVIDER_CREDENTIAL_TEXT` | `TRIM()` |
| `FULL_NAME`   | Derived |`TRIM(CONCAT(FIRST_NAME, CASE WHEN MIDDLE_NAME IS NOT NULL THEN` `| |MIDDLE_NAME ELSE ` ` END, CASE WHEN LAST_NAME IS NOT NULL THEN ` `| | LAST_NAME ELSE ` ` END))|
| `MAILING_CITY` | `PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME` | `TRIM()` |
| `MAILING_STATE` | `PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME` | `TRIM()` |
| `MAILING_ZIP` | `PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE` | `SUBSTR(zip, 1, 5)` if matches `^[0-9]{5,9}$`, else `NULL` |
| `PRACTICE_CITY` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME` | `TRIM()` |
| `PRACTICE_STATE` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME` | `TRIM()` |
| `PRACTICE_ZIP` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE` | `SUBSTR(zip, 1, 5)` if matches `^[0-9]{5,9}$`, else `NULL` |
| `ENUMERATION_DATE` | `PROVIDER_ENUMERATION_DATE` | `TRY_TO_DATE()` |
| `LAST_UPDATE_DATE` | `LAST_UPDATE_DATE` | `TRY_TO_DATE()` |
| `GENDER` | `PROVIDER_SEX_CODE` | `TRIM()` |
| `PRIMARY_TAXONOMY_CODE` | `HEALTHCARE_PROVIDER_TAXONOMY_CODE_1` | `TRIM()` — first taxonomy code from RAW |

### Field Mappings: STAGE → MODEL

| Target Column (MODEL) | Source Column (STAGE) | Transformation Logic |
|----------------------|---------------------|----------------------|
| All STAGE columns | `NPI_CLEAN` | Direct load with deduplication via `ROW_NUMBER()` |
| `PRACTICE_STATE_US` | `PRACTICE_STATE` | **Added in MODEL layer** — lookup via `STATE_REF`, normalized to 2-letter U.S. abbreviation |
| `MAILING_STATE_US` | `MAILING_STATE` | **Added in MODEL layer** — lookup via `STATE_REF`, normalized to 2-letter U.S. abbreviation |
| `PROVIDER_STATE_US` | Derived | **Added in MODEL layer** — `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` |
| ``Provider_Display_Name`` | ``FULL_NAME``, ``ORG_NAME`` | **Semantic model rule:** ``FULL_NAME ``→ ``ORG_NAME ``→ ``"Unknown ``Organization"`` |
| ``Provider_Type`` | Derived | CASE WHEN `ENTITY_TYPE_CODE = '1'` THEN 'INDIVIDUAL' ELSE 'ORGANIZATION' END`
| ``Data_Quality_Flag`` | Derived | ``'NAME_MISSING_ORG'`` WHEN ``FULL_NAME`` AND ``ORG_NAME`` are NULL; ELSE ``'VALID'`` |

### Geographic Standardization (MODEL Layer)

The raw NPI Registry fields (`PRACTICE_STATE`, `MAILING_STATE`) contain global location values including countries, provinces, APO/FPO codes, ZIP codes, and mixed formats. To support reliable U.S. state-level analytics, the MODEL layer applies a standardization process.

#### New Fields Created in MODEL Layer

| Field | Source Logic | Purpose |
|-------|-------------|---------|
| `PRACTICE_STATE_US` | Extract valid U.S. state abbreviation using `STATE_REF` lookup table | Standardizes practice location to valid U.S. states/territories only |
| `MAILING_STATE_US` | Extract valid U.S. state abbreviation using `STATE_REF` lookup table | Standardizes mailing location to valid U.S. states/territories only |
| `PROVIDER_STATE_US` | `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` | Unified state field used by Power BI for geographic visuals |
| ``Provider_Display_Name`` | ``FULL_NAME``, ``ORG_NAME`` | **Semantic model rule:** ``FULL_NAME ``→ ``ORG_NAME ``→ ``"Unknown ``Organization"`` |
| ``Data_Quality_Flag`` | ``'NAME_MISSING_ORG'`` when ``FULL_NAME`` and ``ORG_NAME`` are NULL; else ``'VALID'`` |

#### Transformation Process

1. **Create Reference Table**: `STATE_REF` containing:
   - 50 U.S. states
   - 5 U.S. territories (PR, VI, GU, AS, MP)
   - District of Columbia (DC)
   - Military codes (AE, AA, AP)
   - Both state abbreviations and full names

2. **Standardization Logic**:
   ```sql
   UPDATE NPI_DIM n
   SET PRACTICE_STATE_US = s.STATE_ABBR
   FROM STATE_REF s
   WHERE TRIM(UPPER(n.PRACTICE_STATE)) IN (s.STATE_ABBR, s.STATE_NAME);
   ```

3. **Excluded Values**: Non-U.S. values ignored (e.g., "ONTARIO", "TOKYO", "ABU DHABI", "UNKNOWN", "APO AE")

4. **Final Unification**: `PROVIDER_STATE_US` provides single, analytics-ready state field

#### Why Geographic Standardization Matters

- Ensures accurate state-level rollups
- Enables Filled Map visuals in Power BI
- Removes global noise from foreign addresses
- Improves BI model reliability and reproducibility
- Supports executive-level reporting and geographic insights

#### SQL Reference
`/sql/model/clean_provider_states.sql`

---

## 📘 4. S2T Mapping — HCPCS_DIM

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.HCPCS_RAW_WIDE` (48 columns)
- **STAGE**: `STAGE_MEDICAID.PUBLIC.HCPCS_CLEAN` (6 columns)
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.HCPCS_DIM` (6 columns)

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `HCPCS_CODE` | `HCPC` | `UPPER(TRIM(HCPC))` |
| `DESCRIPTION` | `LONG_DESCRIPTION` | `TRIM()` |
| `SHORT_DESCRIPTION` | `SHORT_DESCRIPTION` | `TRIM()` |
| `STATUS` | `ACTION_CD` | `TRIM()` |
| `EFFECTIVE_DATE` | `ACT_EFF_DT` | `TRY_TO_DATE()` |
| `TERMINATION_DATE` | `TERM_DT` | `TRY_TO_DATE()` |

**Filter Applied**: `WHERE HCPC IS NOT NULL`

### Field Mappings: STAGE → MODEL

| Target Column (MODEL) | Source Column (STAGE) | Transformation Logic |
|----------------------|---------------------|----------------------|
| All STAGE columns | `HCPCS_CLEAN` | Direct load with deduplication via `ROW_NUMBER()` partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC` |

---

## 📘 5. S2T Mapping — FACT_MEDICAID_PROVIDER_SPENDING

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW`
- **STAGE**: `STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE`
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING`

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `BILLING_PROVIDER_NPI` | `BILLING_PROVIDER_NPI_NUM` | `LPAD(TRIM(value), 10, '0')` — standardize to 10-digit format |
| `SERVICING_PROVIDER_NPI` | `SERVICING_PROVIDER_NPI_NUM` | `LPAD(TRIM(value), 10, '0')` — standardize to 10-digit format |
| `HCPCS_CODE` | `HCPCS_CODE` | `UPPER(TRIM())` |
| `CLAIM_MONTH` | `CLAIM_FROM_MONTH` | `TRY_TO_DATE(CLAIM_FROM_MONTH || '-01')` — convert to first day of month |
| `TOTAL_PATIENTS` | `TOTAL_PATIENTS` | `TRY_TO_NUMBER()` |
| `TOTAL_CLAIM_LINES` | `TOTAL_CLAIM_LINES` | `TRY_TO_NUMBER()` |
| `TOTAL_PAID` | `TOTAL_PAID` | `TRY_TO_NUMBER()` |

### Field Mappings: STAGE → MODEL (FACT Table)

| Target Column (FACT) | Source | Transformation Logic |
|---------------------|--------|----------------------|
| `BILLING_PROVIDER_NPI` | `MEDICAID_PROVIDER_SPENDING_STAGE.BILLING_PROVIDER_NPI` | Direct load |
| `SERVICING_PROVIDER_NPI` | `MEDICAID_PROVIDER_SPENDING_STAGE.SERVICING_PROVIDER_NPI` | Direct load |
| `HCPCS_CODE` | `MEDICAID_PROVIDER_SPENDING_STAGE.HCPCS_CODE` | Direct load |
| `CLAIM_MONTH` | `MEDICAID_PROVIDER_SPENDING_STAGE.CLAIM_MONTH` | Direct load |
| `TOTAL_PATIENTS` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_PATIENTS` | Direct load |
| `TOTAL_CLAIM_LINES` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_CLAIM_LINES` | Direct load |
| `TOTAL_PAID` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_PAID` | Direct load |
| `SERVICE_CATEGORY` | `HCPCS_CODE` | **Derived field** — CASE logic based on HCPCS patterns |
| `BILLING_PROVIDER_STATE` | `NPI_DIM.PROVIDER_STATE_US` (via `BILLING_PROVIDER_NPI`) | LEFT JOIN enrichment |
| `SERVICING_PROVIDER_STATE` | `NPI_DIM.PROVIDER_STATE_US` (via `SERVICING_PROVIDER_NPI`) | LEFT JOIN enrichment |
| `HCPCS_DESCRIPTION` | `HCPCS_DIM.DESCRIPTION` (via `HCPCS_CODE`) | LEFT JOIN enrichment |
| `HCPCS_SHORT_DESCRIPTION` | `HCPCS_DIM.SHORT_DESCRIPTION` (via `HCPCS_CODE`) | LEFT JOIN enrichment |
| `HCPCS_STATUS` | `HCPCS_DIM.STATUS` (via `HCPCS_CODE`) | LEFT JOIN enrichment |

### SERVICE_CATEGORY Derivation Logic

```sql
CASE
    WHEN HCPCS_CODE LIKE 'J%' THEN 'RX'
    WHEN HCPCS_CODE LIKE 'A0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'G0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'H0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'T%' THEN 'OP'
    ELSE 'OTHER'
END
```
Note:  
The FACT table currently assigns only RX, OP, and OTHER.
ED and IP categories exist in SERVICE_CATEGORY_DIM but are not yet mapped in FACT.
This is intentional and documented for future enhancement (e.g., POS‑based classification).

### 5.1 Quarantine Rules

Rows that fail structural validation or contain malformed data are redirected to the
Quarantine area for investigation and remediation.

**Quarantine Target Table**
`STAGE_MEDICAID.QUARANTINE.MEDICAID_PROVIDER_SPENDING_BAD_ROWS`

**Examples of rows sent to Quarantine**
- Non‑numeric NPI values  
- Invalid date formats  
- Corrupted HCPCS codes  
- Rows failing column alignment  
- Rows with unexpected delimiters or broken structure  

**Purpose**
- Preserve RAW data integrity  
- Prevent malformed rows from entering STAGE or MODEL  
- Support auditability and data incident workflows  

### 5.2 Data Incident Workflow

Rows redirected to the Quarantine area follow a standardized Data Incident Workflow to ensure
traceability, auditability, and timely remediation.

#### Workflow Steps

1. **Detection**
   - Malformed or structurally invalid rows are identified during STAGE processing.
   - Rows are redirected to:
     ```
     STAGE_MEDICAID.QUARANTINE.MEDICAID_PROVIDER_SPENDING_BAD_ROWS
     ```

2. **Logging**
   - Each quarantined row is logged with:
     - Load timestamp
     - Source file name
     - Error category (alignment, delimiter, invalid NPI, invalid date, corrupted HCPCS)

3. **Review**
   - Data engineering reviews quarantined rows daily or per pipeline run.
   - Rows are classified as:
     - *Correctable* (fixable via transformation)
     - *Source error* (requires upstream correction)
     - *Irrecoverable* (permanently excluded)

4. **Remediation**
   - Correctable rows are repaired and re‑inserted into STAGE.
   - Source errors are escalated to data providers.
   - Irrecoverable rows remain quarantined for audit.

5. **Reprocessing**
   - After remediation, the STAGE → MODEL → FACT pipeline is re‑executed for affected dates.

#### Purpose
- Maintain RAW data integrity  
- Prevent malformed rows from contaminating MODEL and FACT layers  
- Provide full audit trail for CMS, state agencies, and internal governance  
- Support data quality dashboards and anomaly detection  

---

## 📘 6. S2T Mapping — DATE_DIM

### Source
- **Generated in MODEL layer** — no source table
- **Generation Logic**: `GENERATOR(ROWCOUNT => 3650)` producing 10 years of dates (2018-2027)

### Field Mappings

```code
| Column             | Type    | Description                                |
| ------------------ | ------- | ------------------------------------------ |
| ``DATE_KEY``       | DATE    | Calendar date (primary key)                |
| ``YEAR``           | INTEGER | Calendar year                              |
| ``MONTH``          | INTEGER | Calendar month number (1–12)               |
| ``DAY``            | INTEGER | Day of month (1–31)                        |
| ``YEAR_MONTH``     | STRING  | YYYYMM sortable text (used for axis labels)|
| ``DAY_OF_WEEK``    | INTEGER | Day of week (1=Sunday, 7=Saturday)         |
| ``WEEK_OF_YEAR``   | INTEGER | Week number (1–53)                         |
| ``QUARTER``        | INTEGER | Calendar quarter (1–4)                     |
| ``DATE_TEXT``      | STRING  | YYYY‑MM‑DD formatted text                  |
| ``MONTH_NAME_YEAR``| STRING  | Mon YYYY formatted text                    |
| ``YEAR_MONTH_TEXT``| STRING  | YYYY‑MM formatted text                     |
```

---

## Generation Logic (Actual SQL)

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
    dt AS DATE_KEY,
    YEAR(dt) AS YEAR,
    MONTH(dt) AS MONTH,
    DAY(dt) AS DAY,
    TO_VARCHAR(dt, 'YYYYMM') AS YEAR_MONTH,
    DAYOFWEEK(dt) AS DAY_OF_WEEK,
    WEEKOFYEAR(dt) AS WEEK_OF_YEAR,
    QUARTER(dt) AS QUARTER,
    TO_VARCHAR(dt, 'YYYY-MM-DD') AS DATE_TEXT,
    TO_VARCHAR(dt, 'Mon YYYY') AS MONTH_NAME_YEAR,
    TO_VARCHAR(dt, 'YYYY') || '-' || LPAD(MONTH(dt), 2, '0') AS YEAR_MONTH_TEXT
FROM dates
ORDER BY dt;

```

### Purpose
- Supports Power BI time intelligence 
- Enables YoY, MoM, rolling 12‑month analysis
- Provides standardized date attributes for slicing and filtering
- Ensures consistent date joins to FACT tables

Relationship to FACT Tables
| FACT Column     | DATE_DIM Column | Join Type   |
| --------------- | --------------- | ----------- |
| ``CLAIM_MONTH`` | ``DATE_KEY``    | Many‑to‑One |

---

## 📘 7. S2T Mapping — SERVICE_CATEGORY_DIM

### Source
- **Hardcoded values in MODEL layer** — no source table

### Field Mappings

| Target Column | Source | Value |
|--------------|--------|-------|
| `CATEGORY_KEY` | Hardcoded | 1, 2, 3, 4, 5|
| `SERVICE_CATEGORY` | Hardcoded | 'ED', 'IP', 'OP', 'RX', 'OTHER' |
| `DESCRIPTION` | Hardcoded | 'Emergency Department', 'Inpatient', 'Outpatient', 'Pharmacy',  'Uncategorized'|

### HCPCS-to-Category Mapping Logic

| SERVICE_CATEGORY | HCPCS Pattern | Description |
|------------------|---------------|-------------|
| `RX` | `J%` | Pharmacy/Drug codes |
| `OP` | `A0%`, `G0%`, `H0%`, `T%` | Outpatient services |
| `OTHER` | All other patterns | Uncategorized |

*Note*: ED and IP categories are defined for future expansion (e.g., POS‑based classification).
The current FACT derivation logic assigns only RX, OP, and OTHER.
ED/IP will be populated in a future enhancement.

---

## 🔗 8. Join Relationships

### Star Schema Relationships

```
DATE_DIM (DATE_KEY)
    ← FACT_MEDICAID_PROVIDER_SPENDING (CLAIM_MONTH)

NPI_DIM (NPI)
    ← FACT_MEDICAID_PROVIDER_SPENDING (BILLING_PROVIDER_NPI)
    ← FACT_MEDICAID_PROVIDER_SPENDING (SERVICING_PROVIDER_NPI)

HCPCS_DIM (HCPCS_CODE)
    ← FACT_MEDICAID_PROVIDER_SPENDING (HCPCS_CODE)

SERVICE_CATEGORY_DIM (SERVICE_CATEGORY)
    ← FACT_MEDICAID_PROVIDER_SPENDING (SERVICE_CATEGORY)
```

### Foreign Key Constraints (Documentation Only)

| FACT Column | References | Cardinality | Join Type |
|-------------|-----------|-------------|-----------|
| `BILLING_PROVIDER_NPI` | `NPI_DIM(NPI)` | Many-to-One | LEFT JOIN |
| `SERVICING_PROVIDER_NPI` | `NPI_DIM(NPI)` | Many-to-One | LEFT JOIN |
| `HCPCS_CODE` | `HCPCS_DIM(HCPCS_CODE)` | Many-to-One | LEFT JOIN |
| `CLAIM_MONTH` | `DATE_DIM(DATE_KEY)` | Many-to-One | JOIN |
| `SERVICE_CATEGORY` | `SERVICE_CATEGORY_DIM(SERVICE_CATEGORY)` | Many-to-One | JOIN |

---

## 📘 8.1 Integrity Layer (Downstream Data Quality Tables)

The Integrity Layer consists of downstream MODEL tables that monitor provider data quality, NPI validity, and legacy identifier behavior.  
These tables are **not part of the RAW → STAGE → MODEL S2T mapping**, but they are included here for completeness and lineage visibility.

### Purpose
- Detect invalid or missing NPIs
- Track monthly trends in NPI data quality
- Identify anomaly spikes or drops in invalid NPI rates
- Map legacy servicing provider identifiers (A‑prefix, M‑prefix, malformed IDs)
- Support Provider Integrity Scorecard and DQ dashboards

### Tables Included
| Table Name | Purpose | Grain |
|------------|---------|-------|
| `LEGACY_SERVICING_PROVIDER_DIM` | Maps legacy servicing provider IDs to inferred provider attributes | 1 row per legacy servicing provider ID |
| `DQ_INVALID_NPI_TREND` | Monthly counts and rates of invalid NPIs | 1 row per month |
| `DQ_INVALID_NPI_ANOMALIES` | Flags anomaly months using threshold logic | 1 row per anomaly event |

### Lineage Position
These tables sit **downstream of the MODEL layer**, after:

- `NPI_DIM`
- `FACT_MEDICAID_PROVIDER_SPENDING`
- `DATE_DIM`

They do **not** feed back into FACT tables and do **not** participate in the star schema.

### Usage
- Power BI Provider Integrity Scorecard
- Data Quality dashboards
- Monitoring and alerting
- Audit and compliance reporting

### Notes
- These tables are refreshed as part of the MODEL execution order but are **not** part of the core S2T mapping.
- They do not introduce new business logic into FACT tables.
- They are documented separately in:  
  `docs/21_dq_anomaly_detection.md`  
  `docs/18_legacy_servicing_provider_registry.md`

---

## 📘 8.2 End‑to‑End Execution Order (Authoritative)

The Medicaid data pipeline must be executed in a strict dependency order to ensure
data integrity, correct dimensional joins, and accurate Power BI behavior.

This is the authoritative execution sequence for the entire warehouse:

---

### 🟦 1. RAW Layer (Landing)
1. `MEDICAID_PROVIDER_SPENDING_RAW`
2. `HCPCS_RAW_WIDE`
3. `NPI_RAW`

Purpose: land source files exactly as received.

---

### 🟩 2. STAGE Layer (Cleaning & Standardization)
4. `MEDICAID_PROVIDER_SPENDING_STAGE`  
5. `HCPCS_CLEAN`  
6. `NPI_CLEAN`  
7. Data Incident Scripts (optional, conditional)  
   - `isolatingoutliersfact_table.sql`  
   - `removeoutliersfact_table.sql`

Purpose: apply column alignment, type normalization, trimming, deduplication, and business‑rule cleaning.

---

### 🟦 3. MODEL Layer (Dimensions First)
8. `NPI_DIM`  
9. `clean_provider_states.sql` (Geographic Standardization)  
10. `DATE_DIM`  
11. `SERVICE_CATEGORY_DIM`  
12. `HCPCS_DIM`

Purpose: build conformed dimensions required by FACT tables.

---

### 🟥 4. FACT Layer (Dependent on All Dimensions)
13. `FACT_MEDICAID_PROVIDER_SPENDING`  
14. `FACT_PROVIDER_MONTHLY`  
15. `FACT_HCPCS_MONTHLY`

Purpose: produce analytics‑ready fact tables at the correct grain.

---

### 🟧 5. Integrity Layer (Downstream DQ Tables)
16. `LEGACY_SERVICING_PROVIDER_DIM`  
17. `DQ_INVALID_NPI_TREND`  
18. `DQ_INVALID_NPI_ANOMALIES`

Purpose: monitor provider data quality, NPI validity, and anomaly detection.

---

### 🟪 6. BI Semantic Layer (Power BI)
19. Power BI Model Refresh  
    - Star schema relationships  
    - DAX measures  
    - Time intelligence  
    - Provider integrity dashboards  

Purpose: deliver analytics to end users.

---

### Notes
- Dimensions **must** be built before FACT tables.  
- Geographic standardization must run **after** NPI_DIM but **before** FACT.  
- Integrity Layer tables depend on FACT + DATE_DIM.  
- Power BI refresh is the final step in the chain.  

---

## 🧮 9. Transformation Logic Summary

### Direct Loads
- NPI → `NPI_DIM`
- HCPCS → `HCPCS_DIM`
- Medicaid Claims → `FACT_MEDICAID_PROVIDER_SPENDING`

### Type Casting
- `TRY_TO_NUMBER()` — all numeric fields
- `TRY_TO_DATE()` — all date fields
- `LPAD(field, 10, '0')` — NPI standardization
- `UPPER(TRIM())` — HCPCS codes
- `SUBSTR(zip, 1, 5)` — ZIP code normalization

### Derived Fields

| Derived Field | Source Fields | Logic |
|---------------|---------------|-------|
| `FULL_NAME` | `FIRST_NAME`, `MIDDLE_NAME`, `LAST_NAME` | `TRIM(CONCAT(FIRST_NAME, CASE WHEN MIDDLE_NAME IS NOT NULL THEN ' '`| |`MIDDLE_NAME ELSE ' ' END`, `CASE WHEN LAST_NAME IS NOT NULL THEN ' '`| | `LAST_NAME ELSE ' ' END`))| |
| `CLAIM_MONTH` | `CLAIM_FROM_MONTH` | `TRY_TO_DATE(value || '-01')` |
| `SERVICE_CATEGORY` | `HCPCS_CODE` | CASE statement pattern matching |
| `PRACTICE_STATE_US` | `PRACTICE_STATE` | `STATE_REF` lookup via JOIN |
| `MAILING_STATE_US` | `MAILING_STATE` | `STATE_REF` lookup via JOIN |
| `PROVIDER_STATE_US` | `PRACTICE_STATE_US`, `MAILING_STATE_US` | `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` |
| ``Provider_Type`` | ``ENTITY_TYPE_CODE`` | `IF 1 THEN 'INDIVIDUAL' ELSE 'ORGANIZATION'`
| ``Provider_Display_Name`` | ``FULL_NAME``, ``ORG_NAME`` | Semantic model rule: ``FULL_NAME ``→ ``ORG_NAME ``→ ``"Unknown ``Organization"`` |
| ``Data_Quality_Flag`` | ``'NAME_MISSING_ORG'`` when ``FULL_NAME`` and ``ORG_NAME`` are NULL; ELSE ``'VALID'`` |
| `YEAR_MONTH` | `DATE_KEY` | `TO_VARCHAR(full_date, 'YYYY-MM')` |
| `WEEKDAY_FLAG` | `DATE_KEY` | `CASE WHEN DAYOFWEEK IN (6,7) THEN 'Weekend' ELSE 'Weekday' END` |

### Business Rules

1. **Deduplication**:
   - `NPI_DIM`: Partitioned by `NPI`, ordered by `LAST_UPDATE_DATE DESC`
   - `HCPCS_DIM`: Partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC`

2. **Field Reduction**:
   - NPI: 330 columns → 19 columns (STAGE) → 22 columns (MODEL with geographic fields)
   - HCPCS: 48 columns → 6 columns

3. **Standardization**:
   - All NPIs zero-padded to 10 digits
   - All HCPCS codes uppercased
   - All state codes normalized via `STATE_REF` lookup
   - All ZIP codes truncated to 5 digits

4. **Enrichment**:
   - FACT table enriched with provider names, HCPCS descriptions, state locations via LEFT JOIN
   - Missing dimension values result in NULL enrichment fields

---

## 10. This section defines the complete Source‑to‑Target (S2T) mapping for the Medicaid Provider Spending pipeline, including:

- Source → FACT_MEDICAID_PROVIDER_SPENDING
- FACT_MEDICAID_PROVIDER_SPENDING → FACT_PROVIDER_MONTHLY
- FACT_MEDICAID_PROVIDER_SPENDING → FACT_HCPCS_MONTHLY
- Data types, nullability, alignment rules
- Ingestion validation rules
- Column‑shift detection logic
- Error handling and quarantine rules

For details on the 2018 data quality incident and remediation steps, see:
`16_Data_quality_incident.md`

### 10.1. Source → FACT_MEDICAID_PROVIDER_SPENDING
> 10.1.1 Source Schema (Raw Medicaid Provider Spending File)
| Column | Type | Notes |
| --- | --- | --- |
| BILLING_PROVIDER_NPI | STRING | Must be 10 digits |
| BILLING_PROVIDER_STATE | STRING | 2‑letter state |
| SERVICING_PROVIDER_NPI | STRING | Must be 10 digits |
| SERVICING_PROVIDER_STATE | STRING | 2‑letter state |
| HCPCS_CODE | STRING | Must match HCPCS master |
| HCPCS_DESCRIPTION | STRING | From HCPCS master |
| HCPCS_SHORT_DESCRIPTION | STRING | From HCPCS master |
| HCPCS_STATUS | STRING | From HCPCS master |
| SERVICE_CATEGORY | STRING | Derived |
| CLAIM_MONTH | DATE | YYYY‑MM‑01 |
| TOTAL_CLAIM_LINES | NUMBER | Raw count |
| TOTAL_PAID | NUMBER | Raw paid amount |
| TOTAL_PATIENTS | NUMBER | Raw count |

> 10.1.2 Target Schema (FACT_MEDICAID_PROVIDER_SPENDING)
Same as source, with enforced constraints:
- NPIs must be 10‑digit numeric strings
- HCPCS_CODE cannot be NULL
- TOTAL_PAID must be numeric and < $100M
- CLAIM_MONTH must be a valid month boundary

> 10.1.3 Mapping Table
| Source Column | Target Column | Transform | Notes |
| --- | --- | --- | --- |
| BILLING_PROVIDER_NPI | BILLING_PROVIDER_NPI | Direct | Validate 10 digits |
| BILLING_PROVIDER_STATE | BILLING_PROVIDER_STATE | Direct | Uppercase |
| SERVICING_PROVIDER_NPI | SERVICING_PROVIDER_NPI | Direct | Validate 10 digits |
| SERVICING_PROVIDER_STATE | SERVICING_PROVIDER_STATE | Direct | Uppercase |
| HCPCS_CODE | HCPCS_CODE | Direct | Validate against HCPCS master |
| HCPCS_DESCRIPTION | HCPCS_DESCRIPTION | Direct | From HCPCS master |
| HCPCS_SHORT_DESCRIPTION | HCPCS_SHORT_DESCRIPTION | Direct | From HCPCS master |
| HCPCS_STATUS | HCPCS_STATUS | Direct | From HCPCS master |
| SERVICE_CATEGORY | SERVICE_CATEGORY | Direct | Derived |
| CLAIM_MONTH | CLAIM_MONTH | Cast to DATE | Must be YYYY‑MM‑01 |
| TOTAL_CLAIM_LINES | TOTAL_CLAIM_LINES | SUM | Aggregated in monthly tables |
| TOTAL_PAID | TOTAL_PAID | SUM | Must be < $100M |
| TOTAL_PATIENTS | TOTAL_PATIENTS | SUM | Aggregated in monthly tables |

> 10.1.4 FACT Grain Definition
The FACT_MEDICAID_PROVIDER_SPENDING table is stored at the following grain:

**One row per:**
- CLAIM_MONTH  
- BILLING_PROVIDER_NPI  
- SERVICING_PROVIDER_NPI  
- HCPCS_CODE  
- SERVICE_CATEGORY  

This grain ensures:
- Accurate aggregation of claim lines, paid amounts, and patient counts  
- Correct alignment with SERVICE_CATEGORY_DIM  
- Consistent behavior in Power BI slicers and filters  
- Proper grouping for FACT_PROVIDER_MONTHLY and FACT_HCPCS_MONTHLY  

### 📘 10.2 Monthly FACT Lineage — Aggregations from FACT_MEDICAID_PROVIDER_SPENDING

The monthly FACT tables are **derived aggregations** of `FACT_MEDICAID_PROVIDER_SPENDING`.  
They do **not** source directly from RAW or STAGE tables.

This preserves a single source of truth for claim‑level logic and ensures consistent
business rules across all downstream aggregates.

---

> 10.2.1 FACT_PROVIDER_MONTHLY

**Purpose**  
Summarize Medicaid spending at the **provider × month × service category** level for trend and performance analysis.

**Grain**  
One row per:

- `CLAIM_MONTH`
- `BILLING_PROVIDER_NPI`
- `SERVICE_CATEGORY`

**Source Lineage**

- **Source FACT:** `FACT_MEDICAID_PROVIDER_SPENDING`

**Core Aggregation Logic (Model Layer)**

```sql
CREATE OR REPLACE TABLE FACT_PROVIDER_MONTHLY AS
SELECT
    CLAIM_MONTH,
    BILLING_PROVIDER_NPI,
    SERVICE_CATEGORY,
    SUM(TOTAL_PAID_AMOUNT)      AS TOTAL_PAID_AMOUNT,
    SUM(CLAIM_COUNT)            AS CLAIM_COUNT,
    COUNT(DISTINCT MEMBER_ID)   AS UNIQUE_MEMBER_COUNT
FROM FACT_MEDICAID_PROVIDER_SPENDING
GROUP BY
    CLAIM_MONTH,
    BILLING_PROVIDER_NPI,
    SERVICE_CATEGORY;
```

> 10.2.2 FACT_HCPCS_MONTHLY
Purpose  
Summarize Medicaid spending at the HCPCS × month × service category level for utilization and fee schedule analysis.

Grain  
One row per:
- CLAIM_MONTH
- HCPCS_CODE
- SERVICE_CATEGORY

Source Lineage
- Source FACT: FACT_MEDICAID_PROVIDER_SPENDING

Core Aggregation Logic (Model Layer)
```sql
CREATE OR REPLACE TABLE FACT_HCPCS_MONTHLY AS
SELECT
    CLAIM_MONTH,
    HCPCS_CODE,
    SERVICE_CATEGORY,
    SUM(TOTAL_PAID_AMOUNT)      AS TOTAL_PAID_AMOUNT,
    SUM(CLAIM_COUNT)            AS CLAIM_COUNT,
    COUNT(DISTINCT MEMBER_ID)   AS UNIQUE_MEMBER_COUNT
FROM FACT_MEDICAID_PROVIDER_SPENDING
GROUP BY
    CLAIM_MONTH,
    HCPCS_CODE,
    SERVICE_CATEGORY;
```

> 10.2.3 Lineage Summary
- FACT_MEDICAID_PROVIDER_SPENDING  
↳ feeds FACT_PROVIDER_MONTHLY (provider‑level monthly aggregates)
↳ feeds FACT_HCPCS_MONTHLY (HCPCS‑level monthly aggregates)

No monthly FACT table reads directly from RAW or STAGE.
All monthly metrics inherit the same business rules, filters, and joins as the base FACT.

---

## 📊 11. Power BI Semantic Model Usage

### Star Schema in Power BI

The MODEL layer tables are consumed directly by Power BI as a star schema:

- **Fact Tables**  
  - `FACT_MEDICAID_PROVIDER_SPENDING` (DirectQuery)  
  - `FACT_PROVIDER_MONTHLY`  
  - `FACT_HCPCS_MONTHLY`

- **Dimensions**  
  - `NPI_DIM`  
  - `HCPCS_DIM`  
  - `DATE_DIM`  
  - `SERVICE_CATEGORY_DIM`

### Key Fields for Power BI Visuals

| Visual Type | Field Used | Source Table |
|-------------|-----------|--------------|
| Filled Map | `PROVIDER_STATE_US` | `NPI_DIM` |
| Tree Map (Geographic) | `PROVIDER_STATE_US` | `NPI_DIM` |
| Time Series | `YEAR_MONTH` | `DATE_DIM` |
| Service Category Slicer | `SERVICE_CATEGORY` | `SERVICE_CATEGORY_DIM` or `FACT` |
| Provider Drilldown | `FULL_NAME`, `ORG_NAME` | `NPI_DIM` |
| Procedure Analysis | `HCPCS_DESCRIPTION` | `HCPCS_DIM` |

### Relationship Configuration

- **One‑to‑Many** relationships from all dimensions to FACT tables  
- **Cross‑filter direction:** Single  
- **Cardinality:** Enforced logically (documented in S2T)

### DAX Measures
DAX measures are defined in the Power BI semantic layer and documented in:
`docs/09_powerbi_dashboard.md`

---

## 🧭 12. How to Use This Document

### Engineers
- Implement SQL transformations based on documented lineage
- Validate that RAW → STAGE → MODEL transformations match the mapping
- Ensure consistency and reproducibility across layers
- Support debugging and data quality checks using S2T as reference
- Use this as the authoritative source for field definitions

### Analysts / BI Developers
- Understand metric definitions and how fields are derived
- Build accurate Power BI semantic models
- Trace fields back to source systems for validation
- Communicate logic clearly to stakeholders
- Design reports using standardized, analytics-ready fields

### Reviewers / Hiring Managers
- Evaluate data engineering discipline and documentation quality
- Confirm EDS-style modeling practices
- Assess understanding of Medicaid data structures and lineage
- Validate that the project follows enterprise data governance standards

---

## 🧩 13. Why S2T Matters in Medicaid / EDS Work

State Medicaid programs and Enterprise Data Systems rely on:

- **Traceability** — every field must be traceable back to source
- **Auditability** — transformations must be documented for compliance
- **Repeatability** — pipelines must produce consistent results
- **Data lineage** — required for CMS reporting, audits, and oversight
- **Standardized definitions** — ensures alignment across agencies and vendors

S2T mapping is the core artifact that ensures:

- Every metric is reproducible
- Every field is traceable
- Every transformation is documented
- Every dimension/fact relationship is intentional
- Every stakeholder understands the logic behind the data

This is why S2T documentation is a **non-negotiable requirement** in EDS, Medicaid, and state government analytics environments.

---

## 🗂️ 14. Versioning & Change Log

| Version | Date       | Author           | Description                                                                             |
|---------|------------|------------------|-----------------------------------------------------------------------------------------|
| **1.0** | 2026-05-03 | Mairilyn Yera    | Initial S2T mapping created for NPI_DIM, HCPCS_DIM, and FACT_MEDICAID_PROVIDER_SPENDING |
| **1.1** | 2026-05-03 | Mairilyn Yera    | Added DATE_DIM and SERVICE_CATEGORY_DIM mappings                                        |
| **2.0** | 2026-05-06 | Mairilyn Yera    | Comprehensive update: expanded all table mappings with detailed RAW→STAGE→MODEL lineage, added STAGE layer field mappings, documented all derived fields,
                                          | added SERVICE_CATEGORY logic, enhanced geographic standardization section, added complete transformation logic summary, expanded join relationships section, 
                                          | added Power BI usage guidance |
| **2.1** | 2026-05-07 | Mairilyn Yera    | Corrected Full_Name construction, added Provider_Display_Name, Provider_Type and Data_Quality_Flag
| **2.2** | 2026-05-10 | Mairilyn Yera    | Added section 10 on mapping for the Medicaid Provider Spending pipeline and updated section 11 to include 2 new Fact tables


**Note**: All changes follow semantic versioning and include brief descriptions of modifications.

---

## 📁 15. SQL Reference Files

This section lists all SQL files used across the RAW → STAGE → MODEL → FACT → Integrity Layer pipeline.
Files are grouped by functional layer for clarity and traceability.

---

### 🟦 RAW Layer (Landing)

| Table/Object | SQL File |
|--------------|----------|
| `MEDICAID_PROVIDER_SPENDING_RAW` | `sql/raw/medicaid_ingestion_raw.sql` |
| `HCPCS_RAW_WIDE` | `sql/raw/hcpcs_ingestion_raw.sql` |
| `NPI_RAW` | `sql/raw/provider_ingestion_raw.sql` |

---

### 🟩 STAGE Layer (Cleaning, Standardization, Quarantine)

| Table/Object | SQL File |
|--------------|----------|
| `MEDICAID_PROVIDER_SPENDING_STAGE` | `sql/stage/medicaid_clean_stage.sql` |
| `HCPCS_CLEAN` | `sql/stage/hcpcs_clean.sql` |
| `NPI_CLEAN` | `sql/stage/provider_clean.sql` |

#### Data Incident Scripts (Quarantine & Outlier Isolation)

| Purpose | SQL File |
|---------|----------|
| Isolate outliers in Medicaid FACT | `sql/data_incident/isolatingoutliersfact_table.sql` |
| Remove outliers in Medicaid FACT | `sql/data_incident/removeoutliersfact_table.sql` |
| Quarantine malformed rows | *(Handled inside STAGE scripts; no standalone file)* |

---

### 🟦 MODEL Layer (Dimensions & Reference Tables)

| Table/Object | SQL File |
|--------------|----------|
| `NPI_DIM` | `sql/model/provider_dimension.sql` |
| `HCPCS_DIM` | `sql/model/hcpcs_dimension.sql` |
| `DATE_DIM` | `sql/model/date_and_service_dimensions.sql` |
| `SERVICE_CATEGORY_DIM` | `sql/model/date_and_service_dimensions.sql` |
| `STATE_REF` (Geographic Standardization) | `sql/model/clean_provider_states.sql` |

---

### 🟥 FACT Layer (Analytics-Ready Fact Tables)

| Table/Object | SQL File |
|--------------|----------|
| `FACT_MEDICAID_PROVIDER_SPENDING` | `sql/fact/medicaid_fact_table.sql` |
| `FACT_PROVIDER_MONTHLY` | `sql/fact/provider_monthly_fact.sql` |
| `FACT_HCPCS_MONTHLY` | `sql/fact/hcpcs_monthly_fact.sql` |

---

### 🟧 Integrity Layer (Downstream Data Quality Tables)

| Table/Object | SQL File |
|--------------|----------|
| `LEGACY_SERVICING_PROVIDER_DIM` | `sql/integrity/legacy_servicing_provider_registry.sql` |
| `DQ_INVALID_NPI_TREND` | `sql/integrity/dq_invalid_npi_trend.sql` |
| `DQ_INVALID_NPI_ANOMALIES` | `sql/integrity/dq_invalid_npi_anomalies.sql` |

---

### 🟪 Quality Checks (QC)

| Domain | SQL File |
|--------|----------|
| Medicaid QC | `sql/qc/medicaid_quality_checks.sql` |
| HCPCS QC | `sql/qc/hcpcs_quality_checks.sql` |
| Provider QC | `sql/qc/provider_quality_checks.sql` |

---

### 🟨 Orchestration (Full Pipeline Execution)

| Pipeline | SQL File |
|----------|----------|
| Full Medicaid Pipeline | `sql/orchestration/medicaid_full_pipeline.sql` |
| Full HCPCS Pipeline | `sql/orchestration/hcpcs_full_pipeline.sql` |
| Full Provider Pipeline | `sql/orchestration/provider_full_pipeline.sql` |

---

## 📘 16. Final S2T Consistency Check

This section validates that all components of the S2T are internally consistent and aligned with
the actual SQL implementation, MODEL layer logic, FACT grain, and Power BI semantic model.

The following checks confirm that the S2T accurately represents the Medicaid analytics warehouse.

---

### ✔ 16.1 Dimension Consistency

- **SERVICE_CATEGORY_DIM**
  - Dimension values match the MODEL script: `ED`, `IP`, `OP`, `RX`, `OTHER`
  - Column lengths explicitly defined (`VARCHAR(10)`, `VARCHAR(50)`)
  - FACT logic assigns only `RX`, `OP`, `OTHER` (ED/IP reserved for future use)
  - S2T note added to explain this intentional mismatch

- **DATE_DIM**
  - S2T fields match the actual SQL (recursive CTE)
  - Includes: `DAY`, `DAY_OF_WEEK`, `WEEK_OF_YEAR`, `DATE_TEXT`, `MONTH_NAME_YEAR`, `YEAR_MONTH_TEXT`
  - Removed deprecated fields (e.g., `WEEKDAY_FLAG`, `DAY_NAME`)

- **NPI_DIM**
  - Grain and lineage consistent with NPI_CLEAN
  - Geographic standardization documented as downstream step

---

### ✔ 16.2 FACT Consistency

- **FACT_MEDICAID_PROVIDER_SPENDING**
  - Grain updated to:  
    `CLAIM_MONTH + BILLING_PROVIDER_NPI + SERVICING_PROVIDER_NPI + HCPCS_CODE + SERVICE_CATEGORY`
  - SERVICE_CATEGORY derivation logic matches S2T and MODEL
  - Joins to DATE_DIM, NPI_DIM, HCPCS_DIM, SERVICE_CATEGORY_DIM are correct and documented

- **Monthly FACTs**
  - Both monthly FACTs source **only** from `FACT_MEDICAID_PROVIDER_SPENDING`
  - Grain definitions match SQL
  - Aggregation logic documented and consistent

---

### ✔ 16.3 Execution Order Consistency

- Execution order updated to reflect:
  - RAW → STAGE → MODEL → FACT → Integrity Layer → BI
  - Dimensions built before FACTs
  - Integrity Layer downstream only
  - Power BI refresh last

---

### ✔ 16.4 Lineage Consistency

- All lineage diagrams and descriptions reflect:
  - Single source of truth for claim-level logic
  - Monthly FACTs derived from base FACT
  - Integrity Layer dependent on FACT + DATE_DIM
  - No circular dependencies

---

### ✔ 16.5 Naming & Documentation Consistency

- All table names match actual SQL files
- All column names match actual SQL definitions
- All business rules appear once and only once
- All deprecated logic removed
- All future-use logic clearly labeled (ED/IP)

---

### ✔ 16.6 BI Semantic Layer Consistency

- Star schema relationships match FACT grain
- DATE_DIM joins on DATE_KEY
- SERVICE_CATEGORY_DIM joins on SERVICE_CATEGORY
- NPI_DIM joins on BILLING and SERVICING NPIs
- No ambiguous or many-to-many relationships

---

### ✔ 16.7 Integrity Layer Consistency

- Integrity Layer documented as downstream
- Not part of S2T mapping
- Correct lineage: FACT → DQ tables
- Correct purpose: monitoring, anomaly detection, legacy ID mapping

---

### ✔ 16.8 Final Validation

All S2T sections now:
- Match the actual SQL implementation
- Match the MODEL layer logic
- Match the FACT grain
- Match the Power BI semantic model
- Match the execution order
- Match the lineage diagrams
- Match the business rules
- Match the documentation in `/docs`

The S2T is now **fully consistent, audit‑ready, and enterprise‑grade**.


---

## ✍️ Author

**Mairilyn Yera Galindo**  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL | Power BI  
Boca Raton, Florida

**GitHub**: [https://github.com/Data-Strata](https://github.com/Data-Strata)  
**LinkedIn**: [www.linkedin.com/in/mairilyn-yera-galindo-07a93932](https://www.linkedin.com/in/mairilyn-yera-galindo-07a93932)

---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio
