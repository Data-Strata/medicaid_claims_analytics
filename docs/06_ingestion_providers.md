# Provider (NPI Registry) Ingestion Pipeline

Pipeline Tier: Ingestion → Raw → Clean → Dimension
Depends On: `03_snowflake_setup.md`

## 🟦 1. Purpose
This document describes the ingestion workflow for the NPI Registry dataset, which enriches Medicaid claims with provider metadata such as:
- Provider names
- Organization names
- Credentials
- Taxonomy (specialty)
- Address (state, city, ZIP)  
- Enumeration + update dates  

The NPI Registry is required to build the **DIM_PROVIDER** dimension used by the Medicaid fact table.

## 🟦 2. Architecture Overview
All three pipelines follow the same pattern: manual `CREATE TABLE` (all STRING) → `COPY INTO` → typed CLEAN → deduplicated DIM/FACT.
Medicaid and HCPCS use `@MEDICAID_EXTRACTED`; NPI uses its own dedicated `@NPI_EXTRACTED` stage.

External NPI CSV → @NPI_EXTRACTED → NPI_RAW (330 cols, all STRING)
↓
NPI_CLEAN (11 analytics fields, typed)
↓
NPI_DIM (1 row per NPI, deduplicated)


## 🟦 3. Dataset Description
The NPI Registry file contains **330 columns**, including:
- Provider identity  
- Organization identity  
- Mailing + practice addresses  
- Contact information  
- Up to 15 taxonomy codes  
- Up to 50 other identifiers  
- Enumeration + update dates 

Only a subset (19 columns) is required for analytics.


## 🟦 4. File Preparation

4.1 Download NPI Registry File
Download from CMS:  https://download.cms.gov/nppes/NPI_Files.html
Example file:
`npidata_pfile_20050523-20260412.csv` 

4.2 Upload to NPI Ingestion Stage
Upload the CSV from SnowSQL to the dedicated NPI stage:

```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;
PUT file://C:\temp\npidata_pfile.csv @NPI_EXTRACTED AUTO_COMPRESS=TRUE;
```
Validate on Snowsight:
```sql
LIST @NPI_EXTRACTED;
```

## 🟦 5. File Format
The file is comma-delimited with quoted text fields and 330 columns.

```sql
CREATE OR REPLACE FILE FORMAT RAW_MEDICAID.PUBLIC.NPI_CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
ESCAPE = '\\'
ESCAPE_UNENCLOSED_FIELD = '\\'
NULL_IF = ('', 'NULL', 'null')
TRIM_SPACE = TRUE;
```

## 🟦 6. RAW Table 
SQL file: `sql/provider_ingestion_raw.sql`

The RAW table is created manually with all 330 columns typed as STRING.
Column names are cleaned from the original header row (parentheses removed,
spaces converted to underscores).

Excerpt (showing key columns):
```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE RAW_MEDICAID.PUBLIC.NPI_RAW (
    NPI STRING,
    ENTITY_TYPE_CODE STRING,
    REPLACEMENT_NPI STRING,
    EMPLOYER_IDENTIFICATION_NUMBER_EIN STRING,
    PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME STRING,
    PROVIDER_LAST_NAME_LEGAL_NAME STRING,
    PROVIDER_FIRST_NAME STRING,
    PROVIDER_MIDDLE_NAME STRING,
     ...
    
    PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME STRING,
    PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME STRING,
    PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE STRING,
    CERTIFICATION_DATE STRING
);

```

## 🟦 7. Load Into RAW
SQL file: `sql/provider_ingestion_raw.sql`

```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;

COPY INTO RAW_MEDICAID.PUBLIC.NPI_RAW
FROM @NPI_EXTRACTED
FILE_FORMAT = (FORMAT_NAME = 'RAW_MEDICAID.PUBLIC.NPI_CSV_FORMAT')
ON_ERROR = 'CONTINUE';
```
Validate row count:
```sql
SELECT COUNT(*) FROM RAW_MEDICAID.PUBLIC.NPI_RAW;
```
Result: ~17.6 Million rows


## 🟦 8. CLEAN Table (Staging Layer)
SQL file: `sql/provider_clean.sql`

Extracts 19 analytics fields from the 330-column RAW table.
Key transformations:
- LPAD(TRIM(NPI), 10, '0') for NPI to ensure is a 10-digit identifier
- TRIM for all string fields
- TRY_TO_DATE for enumeration date
- REGEXP_REPLACE + TRY_TO_TIMESTAMP_LTZ to sanitize LAST_UPDATE_DATE
(removes non-numeric characters before casting)

```sql
CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.NPI_CLEAN AS
SELECT
    -- Core identifiers
    LPAD(TRIM(NPI), 10, '0')                                                AS NPI,
    TRIM(ENTITY_TYPE_CODE)                                                  AS ENTITY_TYPE_CODE,
    TRIM(REPLACEMENT_NPI)                                                   AS REPLACEMENT_NPI,

    -- Organization / individual names
    TRIM(PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME)                    AS ORG_NAME,
    TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)                                     AS LAST_NAME,
    TRIM(PROVIDER_FIRST_NAME)                                               AS FIRST_NAME,
    TRIM(PROVIDER_MIDDLE_NAME)                                              AS MIDDLE_NAME,
    TRIM(PROVIDER_CREDENTIAL_TEXT)                                          AS CREDENTIALS,

    -- Full name (individuals only)
    TRIM(
        CONCAT_WS(' ',
            TRIM(PROVIDER_FIRST_NAME),
            TRIM(PROVIDER_MIDDLE_NAME),
            TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)
        )
    )                                                                       AS FULL_NAME,

    -- Mailing address (ZIP normalized)
    TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME)                       AS MAILING_CITY,
    TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME)                      AS MAILING_STATE,
    CASE
        WHEN REGEXP_LIKE(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
            THEN SUBSTR(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, 1, 5)
        ELSE NULL
    END                                                                     AS MAILING_ZIP,

    -- Practice address (ZIP normalized)
    TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME)             AS PRACTICE_CITY,
    TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME)            AS PRACTICE_STATE,
    CASE
        WHEN REGEXP_LIKE(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
            THEN SUBSTR(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, 1, 5)
        ELSE NULL
    END                                                                     AS PRACTICE_ZIP,

    -- Dates
    TRY_TO_DATE(PROVIDER_ENUMERATION_DATE)                                  AS ENUMERATION_DATE,
    TRY_TO_DATE(LAST_UPDATE_DATE)                                           AS LAST_UPDATE_DATE,

    -- Gender
    TRIM(PROVIDER_SEX_CODE)                                                 AS GENDER,

    -- Primary taxonomy
    CASE
        WHEN HEALTHCARE_PROVIDER_PRIMARY_TAXONOMY_SWITCH_1 = 'Y'
            THEN TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
        ELSE TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
    END                                                                     AS PRIMARY_TAXONOMY_CODE

FROM RAW_MEDICAID.PUBLIC.NPI_RAW;
```

Quality check:
```sql
SELECT COUNT(*) AS TOTAL_ROWS, COUNT(DISTINCT NPI) AS UNIQUE_NPIS
FROM STAGE_MEDICAID.CLEAN.NPI_CLEAN;
```

## 🟦 9. Create DIM_PROVIDER (Analytics Layer)
SQL file: `sql/provider_dimension.sql`

## Deduplication Logic
The NPI Registry can contain multiple records per NPI (e.g., address changes,
taxonomy updates). The dimension table must guarantee one row per NPI,
keeping the most recently updated record.

-Approach: MAX() + JOIN
  1. Compute the latest `LAST_UPDATE_DATE` per NPI using `MAX()`
  2. Join back to NPI_CLEAN to retrieve the full record for that date

Excerpt:
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
    FROM STAGE_MEDICAID.CLEAN.NPI_CLEAN
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
    ...
    PRIMARY_TAXONOMY_CODE
FROM ranked
WHERE rn = 1;

-- ============================================================
-- CLUSTERING: NPI_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
  CLUSTER BY (NPI);

-- ============================================================
-- PRIMARY KEY: NPI_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
  ADD CONSTRAINT PK_NPI_DIM PRIMARY KEY (NPI);
```
Quality Check:
```sql
SELECT COUNT(*) AS TOTAL_ROWS, COUNT(DISTINCT NPI) AS UNIQUE_NPIS
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM;
```

## 9.1 Standardizes PRACTICE_STATE and MAILING_STATE into U.S. states:
SQL file: `sql/clean_provider_states.sql`

The raw NPI Registry fields `PRACTICE_STATE` and `MAILING_STATE` contain global location values (countries, provinces, APO/FPO codes, ZIP codes, mixed formats).
To support reliable U.S. state–level analytics, the MODEL layer applies a standardization process that extracts valid U.S. state abbreviations using a lookup table (`STATE_REF`) and REGEXP‑based matching.

Three new fields are created in `NPI_DIM`:
- `PRACTICE_STATE_US`
- `MAILING_STATE_US`
- `PROVIDER_STATE_US` (unified best‑available state)


## 🟦 10. Provider Match Coverage (NPI Integration Validation)
To validate the integration between the Medicaid Provider‑Level Spending Fact Table and the NPI_DIM dimension, a left join was performed on the billing provider NPI:
```sql
SELECT
    COUNT(*) AS TOTAL_CLAIMS,
    COUNT(p.NPI) AS MATCHED_ROWS,
    ROUND(COUNT(p.NPI) / COUNT(*) * 100, 2) AS MATCH_PCT
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p
    ON f.BILLING_PROVIDER_NPI = p.NPI;
```
Results:
| TOTAL_CLAIMS | MATCHED_ROWS | MATCH_PCT  |
| ------------ | ------------ | ---------- |
| 238,015,729  | 230,133,234  | **96.69%** |

⭐ Interpretation of the 96.69% Match Rate
A 96.69% provider match rate is strong and expected for a national Medicaid dataset. This level of match coverage is consistent with real‑world Medicaid provider data, where a portion of NPIs will not appear in the NPPES registry.

See Full technical appendix 👉 docs\09_NPI_data_quality_analysis.md (Includes unmatched NPI categories, anomaly tables, SQL diagnostics, and a full narrative.)

## 🟦 11. Data Quality Checks
SQL file: sql/provider_quality_checks.sql

Excerpt:
```sql
-- Row counts across layers
SELECT 'NPI_RAW' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM RAW_MEDICAID.PUBLIC.NPI_RAW
UNION ALL
SELECT 'NPI_CLEAN', COUNT(*) FROM STAGE_MEDICAID.CLEAN.NPI_CLEAN
UNION ALL
SELECT 'NPI_DIM', COUNT(*) FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM;

-- Duplicate NPIs in DIM (should return 0)
SELECT NPI, COUNT(*) AS CNT
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
GROUP BY NPI
HAVING CNT > 1;
```

### 🟦 12. Troubleshooting
- Null NPIs → check for header mismatches or encoding issues
- Duplicate NPIs in DIM → verify LAST_UPDATE_DATE logic
- Join failures in Medicaid fact → check NPI formatting (leading zeros)


---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
