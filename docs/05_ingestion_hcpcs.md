### *HCPCS Reference Ingestion Pipeline*
Pipeline Tier: Ingestion → Raw → Clean → Dimension
Dataset: HCPCS Level II Codes (CMS)


## 🟦 1. Purpose
This document describes the ingestion workflow for HCPCS codes used to enrich Medicaid claims.
This pipeline follows the same ingestion architecture used for the main Medicaid dataset.

## 🟦 2. Architecture Overview
This pipeline follows the same ingestion architecture used for Medicaid and NPI.

External Excel → Local CSV Conversion → MEDICAID_EXTRACTED → HCPCS_RAW_WIDE
↓
HCPCS_CLEAN (standardized staging)
↓
HCPCS_DIM (analytics dimension)

## 🟦 3. Dataset Description
The April 2026 HCPCS file used in this project:
- **Source:** CMS HCPCS Quarterly Update  
- **File:** `HCPC2026_APR_ANWEB.xlsx`  
- **Shape:** Wide layout, **48 columns**  
- **Type:** HCPCS Level II reference data  

Key columns (from the header):

| Column            | Description                   |
| ----------------- | ------------------------------|
| HCPCS_CODE        | 5-character alphanumeric code |
| LONG_DESCRIPTION  | Long description              |
| SHORT_DESCRIPTION | Short description             |
| EFFECTIVE_DATE    | Action effective date         |
| TERMINATION_DATE  | Termination date              | 
| ACTION CD         | Action/status code            |

Only `HCPCS_CODE` appears in the Medicaid fact table, but the dimension includes additional metadata.

## 🟦 4. File Preparation

4.1 Download HCPCS Reference File
Download from CMS:
https://www.cms.gov/medicare/coding-billing/healthcare-common-procedure-system/quarterly-update

Example file: HCPC2026_APR_ANWEB.xlsx

4.2 Convert Excel → CSV (Required)
Snowflake cannot ingest `.xlsx`.

Steps:
1. Open the Excel file  
2. Save As → **CSV UTF‑8 (Comma delimited)**  
3. Name it: `hcpcs_reference.csv`

4.3 Upload CSV to Ingestion Stage
Run from SnowSQL:
```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;
PUT file://C:\temp\hcpcs_reference.csv @MEDICAID_EXTRACTED AUTO_COMPRESS=TRUE;
```
Validate on Snowsight:
```sql
LIST @MEDICAID_EXTRACTED;
```

## 🟦 5. File Format
HCPCS uses the same CSV format as Medicaid:
```sql
CREATE OR REPLACE FILE FORMAT MEDICAID_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null');
```

## 🟦 6. Create RAW Table (Wide Layout)
SQL file: sql/hcpcs_ingestion_raw.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE HCPCS_RAW_WIDE (
    HCPC STRING,
    SEQNUM STRING,
    RECID STRING,
    LONG_DESCRIPTION STRING,
    SHORT_DESCRIPTION STRING,
    PRICE1 STRING,
    PRICE2 STRING,
    ...
    ACT_EFF_DT STRING,
    TERM_DT STRING,
    ACTION_CD STRING
);
```
This table mirrors the full 48‑column CMS layout.

## 🟦 7. Load Into RAW
SQL file: sql/hcpcs_ingestion_raw.sql

Excerpt:
```sql
COPY INTO HCPCS_RAW_WIDE
FROM @MEDICAID_EXTRACTED
FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT')
ON_ERROR = 'CONTINUE';
```
Validate row count:
```sql
SELECT COUNT(*) FROM HCPCS_RAW_WIDE;
```

## 🟦 8. CLEAN Table (Staging Layer)
SQL file: sql/hcpcs_clean.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE HCPCS_CLEAN AS
SELECT
    UPPER(TRIM(HCPC)) AS HCPCS_CODE,
    TRIM(LONG_DESCRIPTION) AS DESCRIPTION,
    TRIM(SHORT_DESCRIPTION) AS SHORT_DESCRIPTION,
    TRIM(ACTION_CD) AS STATUS,
    TRY_TO_DATE(ACT_EFF_DT) AS EFFECTIVE_DATE,
    TRY_TO_DATE(TERM_DT) AS TERMINATION_DATE
FROM HCPCS_RAW_WIDE
WHERE HCPC IS NOT NULL;
```

Quality check:
```sql
SELECT COUNT(*) AS ROWS_TOTAL,
       COUNT(DISTINCT HCPCS_CODE) AS DISTINCT_CODES
FROM HCPCS_CLEAN;
```

## 🟦 9. DIM Table (Analytics Layer)
SQL file: sql/hcpcs_dimension.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE HCPCS_DIM AS
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
```
This ensures one row per HCPCS code, selecting the most recent record.

## 🟦 10. Integration With Medicaid Fact Table
Validate join coverage:
```sql
SELECT
    f.HCPCS_CODE,
    d.DESCRIPTION,
    COUNT(*) AS ROWS
FROM MEDICAID_PROVIDER_SPENDING_RAW f
LEFT JOIN HCPCS_DIM d
    ON f.HCPCS_CODE = d.HCPCS_CODE
GROUP BY 1,2
ORDER BY ROWS DESC;
```

## 🟦 11. Data Quality Checks
SQL file: sql/hcpcs_quality_checks.sql

Excerpt:
```sql
SELECT COUNT(*) FROM HCPCS_RAW_WIDE;
SELECT COUNT(*) FROM HCPCS_CLEAN;
SELECT COUNT(*) FROM HCPCS_DIM;
```

## 🟦 12. Full Pipeline Script
SQL file: sql/hcpcs_full_pipeline.sql

Excerpt:

```sql
CALL HCPCS_LOAD_RAW();
CALL HCPCS_BUILD_CLEAN();
CALL HCPCS_BUILD_DIM();
```

## 🟦 13. Troubleshooting
- Excel file not recognized → convert to CSV UTF‑8
- Column mismatch errors → ensure CSV matches RAW table layout
- NULL values appearing as text → ensure NULL_IF is included
- Missing HCPCS codes in Medicaid → check for leading zeros or trimming issues