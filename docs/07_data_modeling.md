# Data Modeling (Star Schema)

Pipeline Tier: STAGE → ANALYTICS
Depends On: `04_ingestion_medicaid.md`, `05_ingestion_hcpcs.md`, `06_ingestion_providers.md`

---

## 🟦 1. Purpose

This document describes the star schema data model used in the ANALYTICS layer.
The model connects Medicaid claims data with two enrichment dimensions — HCPCS procedure codes and NPI provider records — to support Power BI reporting and ad hoc analysis.

---

## 🟦 2. Three‑Layer Architecture

| Layer | Database | Schema | Purpose |
|-------|----------|--------|---------|
| RAW | `RAW_MEDICAID` | `PUBLIC` | Unmodified source files (all VARCHAR) |
| STAGE | `STAGE_MEDICAID` | `CLEAN` | Cleaned, typed, standardized tables |
| ANALYTICS | `ANALYTICS_MEDICAID` | `MODEL` | Curated star schema (FACT + DIM tables) |

Data flows **RAW → STAGE → ANALYTICS**. Each layer adds structure and business logic.

---

## 🟦 3. Star Schema Overview
                   ┌───────────────────────────┐
                   │        DATE_DIM           │
                   │───────────────────────────│
                   │ DATE_KEY (PK)             │
                   │ DATE                      │
                   │ YEAR, QUARTER, MONTH      │
                   │ YEAR_MONTH, MONTH_NAME    │
                   └──────────────┬────────────┘
                                  │
                                  │
        ┌─────────────────────────┴─────────────────────────┐
        │                                                   │
        ▼                                                   ▼

┌───────────────────────────┐                 ┌───────────────────────────┐
│         NPI_DIM           │                 │       HCPCS_DIM           │
│───────────────────────────│                 │───────────────────────────│
│ NPI (PK)                  │                 │ HCPCS_CODE (PK)           │
│ FULL_NAME                 │                 │ DESCRIPTION               │
│ MAILING_STATE_US          │                 │ CATEGORY                  │
│ PRACTICE_STATE_US         │                 │ EFFECTIVE_DATE            │
│ PROVIDER_STATE_US         │                 │ TERMINATION_DATE          │
└──────────────┬────────────┘                 └──────────────┬────────────┘
               │                                             │
               │                                             │
               ▼                                             ▼

                   ┌──────────────────────────────────────────────┐
                   │   FACT_MEDICAID_PROVIDER_SPENDING            │
                   │──────────────────────────────────────────────│
                   │ CLAIM_MONTH (FK → DATE_DIM.DATE)             │
                   │ BILLING_PROVIDER_NPI (FK → NPI_DIM)          │
                   │ RENDERING_PROVIDER_NPI (FK → NPI_DIM)        │
                   │ HCPCS_CODE (FK → HCPCS_DIM)                  │
                   │ SERVICE_CATEGORY (FK → SERVICE_CATEGORY_DIM) │
                   │ TOTAL_CLAIMS                                 │
                   │ TOTAL_PAID_AMOUNT                            │
                   │ AVG_PAID_AMOUNT                              │
                   └──────────────┬───────────────────────────────┘
                                  │
                                  ▼

                   ┌───────────────────────────┐
                   │  SERVICE_CATEGORY_DIM     │
                   │───────────────────────────│
                   │ SERVICE_CATEGORY (PK)     │
                   │ DESCRIPTION               │
                   │ LOGIC (CASE rules)        │
                   └───────────────────────────┘

---

## 🟦 4. STAGE Tables (Typed + Standardized)

### 4.1 MEDICAID_PROVIDER_SPENDING_STAGE
SQL file: `sql/medicaid_clean_stage.sql`

Transforms the all-VARCHAR RAW table into typed columns:

    CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE AS
    SELECT
        TRY_TO_NUMBER(BILLING_PROVIDER_NPI_NUM)        AS BILLING_PROVIDER_NPI,
        TRY_TO_NUMBER(SERVICING_PROVIDER_NPI_NUM)      AS SERVICING_PROVIDER_NPI,
        UPPER(TRIM(HCPCS_CODE))                        AS HCPCS_CODE,
        TRY_TO_DATE(CLAIM_FROM_MONTH || '-01')         AS CLAIM_MONTH,
        TRY_TO_NUMBER(TOTAL_PATIENTS)                  AS TOTAL_PATIENTS,
        TRY_TO_NUMBER(TOTAL_CLAIM_LINES)               AS TOTAL_CLAIM_LINES,
        TRY_TO_NUMBER(TOTAL_PAID)                      AS TOTAL_PAID
    FROM RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW;

**Transformations applied:**
- Numeric fields cast safely using `TRY_TO_NUMBER`
- `CLAIM_FROM_MONTH` (YYYYMM) converted to date (YYYY-MM-01)
- HCPCS codes standardized to uppercase

### 4.2 PROVIDER_CLEAN
SQL file: `sql/provider_clean.sql`

Extracts 19 analytics fields from the 330-column NPI_RAW table:

    CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.PROVIDER_CLEAN AS
    SELECT
        TRY_TO_NUMBER(NPI)                                                  AS NPI,
        TRIM(ENTITY_TYPE_CODE)                                              AS ENTITY_TYPE_CODE,
        TRIM(REPLACEMENT_NPI)                                               AS REPLACEMENT_NPI,
        TRIM(PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME)                AS ORG_NAME,
        TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)                                 AS LAST_NAME,
        TRIM(PROVIDER_FIRST_NAME)                                           AS FIRST_NAME,
        TRIM(PROVIDER_MIDDLE_NAME)                                          AS MIDDLE_NAME,
        TRIM(PROVIDER_CREDENTIAL_TEXT)                                      AS CREDENTIALS,
        TRIM(
        CONCAT_WS(' ',
            TRIM(PROVIDER_FIRST_NAME),
            TRIM(PROVIDER_MIDDLE_NAME),
            TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)
            )
        )                                                                   AS FULL_NAME,
        TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME)                   AS MAILING_CITY,
        TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME)                  AS MAILING_STATE,
        CASE
            WHEN REGEXP_LIKE(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
                THEN SUBSTR(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, 1, 5)
            ELSE NULL
        END                                                                 AS MAILING_ZIP,
        TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME)         AS PRACTICE_CITY,
        TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME)        AS PRACTICE_STATE,
        CASE
            WHEN REGEXP_LIKE(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
                THEN SUBSTR(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, 1, 5)
            ELSE NULL
        END                                                                 AS PRACTICE_ZIP,
        TRY_TO_DATE(PROVIDER_ENUMERATION_DATE)                              AS ENUMERATION_DATE,
        TRY_TO_DATE(LAST_UPDATE_DATE)                                       AS LAST_UPDATE_DATE,
        TRIM(PROVIDER_SEX_CODE)                                             AS GENDER,
        CASE
           WHEN HEALTHCARE_PROVIDER_PRIMARY_TAXONOMY_SWITCH_1 = 'Y'
                THEN TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
           ELSE TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
        END                                                                 AS PRIMARY_TAXONOMY_CODE
    FROM RAW_MEDICAID.PUBLIC.NPI_RAW;

**Transformations applied:**
- TRY_TO_NUMBER for NPI
- TRIM for all string fields
- TRY_TO_DATE for enumeration date
- REGEXP_REPLACE + TRY_TO_TIMESTAMP_LTZ to sanitize LAST_UPDATE_DATE
(removes non-numeric characters before casting)

### 4.3 HCPCS_CLEAN
SQL file: `sql/hcpcs_clean.sql`

Extracts 6 analytics fields from the 48-column HCPCS_RAW_WIDE table:

    CREATE OR REPLACE TABLE HCPCS_CLEAN AS
    SELECT
        UPPER(TRIM(HCPC))              AS HCPCS_CODE,
        TRIM(LONG_DESCRIPTION)         AS DESCRIPTION,
        TRIM(SHORT_DESCRIPTION)        AS SHORT_DESCRIPTION,
        TRIM(ACTION_CD)                AS STATUS,
        TRY_TO_DATE(ACT_EFF_DT)       AS EFFECTIVE_DATE,
        TRY_TO_DATE(TERM_DT)          AS TERMINATION_DATE
    FROM HCPCS_RAW_WIDE
    WHERE HCPC IS NOT NULL;

**Transformations applied:**
- TRIM for all string fields
- HCPCS codes standardized to uppercase

---

## 🟦 5. Dimension Tables (ANALYTICS Layer)

### 5.1 DIM_PROVIDER
SQL file: `sql/provider_dimension.sql`

```sql   
   CREATE OR REPLACE TABLE NPI_DIM AS
    WITH ranked AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY NPI
                ORDER BY 
                    LAST_UPDATE_DATE DESC NULLS LAST,
                    ENUMERATION_DATE DESC NULLS LAST,
                    NPI DESC
            ) AS rn
        FROM STAGE_MEDICAID.CLEAN.NPI
    )
    SELECT
        NPI,
        ENTITY_TYPE_CODE,
        REPLACEMENT_NPI,
        ORG_NAME,
        LAST_NAME,
        FIRST_NAME,
        MIDDLE_NAME,
        CREDENTIALS,
        FULL_NAME,
        MAILING_CITY,
        MAILING_STATE,
        MAILING_ZIP,
        PRACTICE_CITY,
        PRACTICE_STATE,
        PRACTICE_ZIP,
        ENUMERATION_DATE,
        LAST_UPDATE_DATE,
        GENDER,
        PRIMARY_TAXONOMY_CODE
    FROM ranked
    WHERE rn = 1;
 ```   
**Key design decisions:**
- One row per NPI guaranteed

### 5.2 DIM_HCPCS
SQL file: `sql/hcpcs_dimension.sql`

    CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.DIM_HCPCS AS
    SELECT
        HCPCS_CODE,
        DESCRIPTION,
        SHORT_DESCRIPTION,
        STATUS,
        EFFECTIVE_DATE,
        TERMINATION_DATE
    FROM HCPCS_CLEAN
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY HCPCS_CODE
        ORDER BY EFFECTIVE_DATE DESC NULLS LAST
    ) = 1;

**Key design decisions:**
- One row per HCPCS code (deduplicated by effective date)
- Enriches Medicaid claims with human-readable procedure descriptions

---

## 🟦 6. Fact Table

### FACT_PROVIDER_SPENDING
SQL file: `sql/medicaid_fact_table.sql`

```sql
    CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING AS
    SELECT
        s.*,

        -- Derived service category (HCPCS-based)
        CASE
            WHEN s.HCPCS_CODE LIKE 'J%' THEN 'RX'
            WHEN s.HCPCS_CODE LIKE 'A0%' THEN 'OP'
            WHEN s.HCPCS_CODE LIKE 'G0%' THEN 'OP'
            WHEN s.HCPCS_CODE LIKE 'H0%' THEN 'OP'
            WHEN s.HCPCS_CODE LIKE 'T%' THEN 'OP'
            ELSE 'OTHER'
        END AS SERVICE_CATEGORY,

    -- Provider dimension joins
    p1.PRACTICE_STATE AS BILLING_PROVIDER_STATE,
    p2.PRACTICE_STATE AS SERVICING_PROVIDER_STATE,

    -- HCPCS dimension join
    h.DESCRIPTION AS HCPCS_DESCRIPTION,
    h.SHORT_DESCRIPTION AS HCPCS_SHORT_DESCRIPTION,
    h.STATUS AS HCPCS_STATUS

FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE s
LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p1
    ON s.BILLING_PROVIDER_NPI = p1.NPI
LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p2
    ON s.SERVICING_PROVIDER_NPI = p2.NPI
LEFT JOIN ANALYTICS_MEDICAID.MODEL.HCPCS_DIM h
    ON s.HCPCS_CODE = h.HCPCS_CODE;
```

**Key design decisions:**
- `LEFT JOIN` preserves all claims even when dimension records are missing
- Denormalized provider name and HCPCS description for direct Power BI consumption
- Row count: **238,015,729 rows**

SERVICE_CATEGORY is derived using HCPCS patterns because the Medicaid Provider
Spending dataset does not include Place of Service (POS). The classification
follows CMS conventions:
- J‑codes → RX (injectables, pharmacy)
- A0/G0/H0/T‑codes → OP (outpatient/community)
- All others → OTHER (E&M, radiology, lab, dental, etc.)

This field is used for:
- Service category analytics (OP/RX/OTHER)
- Power BI slicers and grouping
- Joining to SERVICE_CATEGORY_DIM
---

## 🟦 7. Join Validation

Validate dimension coverage before building dashboards:

    -- Provider join coverage
    SELECT
        COUNT(*) AS TOTAL_ROWS,
        COUNT(p.NPI) AS MATCHED_ROWS,
        ROUND(COUNT(p.NPI) / COUNT(*) * 100, 2) AS MATCH_PCT
    FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
    LEFT JOIN ANALYTICS_MEDICAID.MODEL.DIM_PROVIDER p
        ON f.BILLING_PROVIDER_NPI = p.NPI;

    -- HCPCS join coverage
    SELECT
        COUNT(*) AS TOTAL_ROWS,
        COUNT(h.HCPCS_CODE) AS MATCHED_ROWS,
        ROUND(COUNT(h.HCPCS_CODE) / COUNT(*) * 100, 2) AS MATCH_PCT
    FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
    LEFT JOIN ANALYTICS_MEDICAID.MODEL.DIM_HCPCS h
        ON f.HCPCS_CODE = h.HCPCS_CODE;
    
---

## 📘 8. Additional Dimensions (DATE_DIM & SERVICE_CATEGORY_DIM)
To support time‑series analytics and service classification in Power BI, two new dimensions were added to the MODEL layer. These dimensions are generated programmatically and do not originate from any source dataset.

# DATE_DIM
A generated date dimension used for:
- Year/Quarter/Month filtering
- Time intelligence (MoM, YoY, YTD, rolling 12 months)
- Trend analysis
- Power BI hierarchies

Grain: 1 row per calendar date
Join: `FACT_MEDICAID_PROVIDER_SPENDING.CLAIM_MONTH` → `DATE_DIM.DATE`

Created using:
```Code
sql/date_and_service_dimensions.sql
```

Key Fields:
| Column               | Description |
| -------------------- | -------------------------- |
| DATE_KEY             | Surrogate key (YYYYMMDD)   |
| DATE                 | Actual date                |
| YEAR, QUARTER, MONTH | Calendar components        |
| MONTH_NAME           | Full month name            |
| YEAR_MONTH           | BI‑friendly label (YYYY‑MM) |

# 🏥 SERVICE_CATEGORY_DIM
A reference dimension defining Medicaid service categories based on HCPCS patterns.

Categories:
ED — Emergency Department
IP — Inpatient
OP — Outpatient
RX — Pharmacy / J‑codes
OTHER — All remaining HCPCS codes

Used for:
- Service category breakdowns
- Utilization analysis
- Power BI slicers and grouping
- Clinical rollups

Created using:
```Code
sql/date_and_service_dimensions.sql
```

Key Fields:
| Column           | Description                            |
| ---------------- | -------------------------------------- |
| SERVICE_CATEGORY | Category label (RX, ED, IP, OP, OTHER) |
| DESCRIPTION      | Human‑readable description             |
| LOGIC            | CASE logic used for classification     |


## 📘 Geographic Data Standardization (Provider Location Cleanup - U.S. State Extraction)

The raw NPI_DIM fields PRACTICE_STATE and MAILING_STATE contained global location values (countries, provinces, APO/FPO codes, cities, ZIP codes, and inconsistent formats).
To support geographic analytics in Power BI, a standardized U.S. state extraction process was implemented in the MODEL layer.

Approach
- Created a canonical `STATE_REF` table containing all 50 U.S. state abbreviations.
- Used `REGEXP_LIKE` pattern matching to extract valid U.S. states from messy text fields.
- Added three new standardized fields:
    + `PRACTICE_STATE_US`
    + `MAILING_STATE_US`
    + `PROVIDER_STATE_US` (coalesced best-available state)

SQL Implementation
Stored in:
```Code
/sql/clean_provider_states.sql
```
This script:
- Builds the reference table
- Adds new columns
- Populates cleaned state fields
- Validates unmatched values

Downstream Usage
Power BI uses:
```Code
NPI_DIM.PROVIDER_STATE_US
```
as the *Location* field for all geographic visuals:
- Filled Map 
- Tree Map
- State‑level rollups
- Provider distribution analysis

---
## 🟦 9. SQL File Reference

| Layer | Table | SQL File |
|-------|-------|----------|
| RAW | `MEDICAID_PROVIDER_SPENDING_RAW` | `sql/medicaid_ingestion_raw.sql` |
| RAW | `HCPCS_RAW_WIDE` | `sql/hcpcs_ingestion_raw.sql` |
| RAW | `NPI_RAW` | `sql/provider_ingestion_raw.sql` |
| STAGE | `MEDICAID_PROVIDER_SPENDING_STAGE` | `sql/medicaid_clean_stage.sql` |
| STAGE | `HCPCS_CLEAN` | `sql/hcpcs_clean.sql` |
| STAGE | `PROVIDER_CLEAN` | `sql/provider_clean.sql` |
| ANALYTICS | `DIM_HCPCS` | `sql/hcpcs_dimension.sql` |
| ANALYTICS | `DIM_PROVIDER` | `sql/provider_dimension.sql` |
| ANALYTICS | `FACT_PROVIDER_SPENDING` | `sql/medicaid_fact_table.sql` |

