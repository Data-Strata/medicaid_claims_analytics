
### *Medicaid Provider Spending Ingestion Pipeline*
Pipeline Tier: Ingestion → Raw → Clean → Stage → Fact
Dataset: Medicaid Provider Spending by HCPCS (HHS Open Data)

---
## 🟦 1. Overview
This document describes the end‑to‑end ingestion workflow for the Medicaid Provider Spending dataset.
The dataset is delivered as a **3.5 GB ZIP** containing a single **11‑GB CSV**.  
Due to Snowflake sandbox limits, ZIP extraction must be performed locally.

This pipeline loads the dataset into:
- `RAW_MEDICAID.PUBLIC` (raw fidelity)
- `STAGE_MEDICAID.CLEAN` (typed + standardized)
- `ANALYTICS_MEDICAID.MODEL` (fact table)

## 🟦 2. Architecture Overview
The ingestion pipeline follows the same pattern as HCPCS and NPI:
```code
External ZIP
↓
MEDICAID_STAGE (landing zone)
↓
Local extraction (required)
↓
MEDICAID_EXTRACTED (CSV ingestion zone)
↓
RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW
↓
STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE
↓
ANALYTICS_MEDICAID.MODEL.FACT_PROVIDER_SPENDING
```

## 🟦 3. Dataset Description

Medicaid Provider Spending dataset contains:
- Billing provider NPI
- Servicing provider NPI
- HCPCS code
- Claim month
- Total patients
- Total claim lines
- Total paid

Row count after ingestion: **238,015,729 rows**

## 🟦 4. File Preparation (Windows Workflow)

4.1 Download the Medicaid ZIP File
Use the verified Azure Blob Storage URL:
```powershell
Invoke-WebRequest -Uri "https://stopendataprod.blob.core.windows.net/datasets/medicaid-provider-spending/2026-02-09/dataset/medicaid-provider-spending.csv.zip" -OutFile "C:\temp\medicaid.zip"
```
Expected size ≈ 3.5 GB, if the file is only KB, the wrong file was downloaded.

4.2 Upload ZIP to MEDICAID_STAGE
Open SnowSQL from terminal:
```powershell
snowsql -a <your_account> -u <your_username>
```
Enter your password when prompted.

4.3 Extract ZIP locally (required)
Produces:
```code
medicaid-provider-spending.csv (~11 GB)
```

4.4 Upload extracted CSV to MEDICAID_EXTRACTED 
This is the file Snowflake will ingest. 
Run on Snowsql on terminal:
```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;
PUT file://C:\temp\medicaid\medicaid-provider-spending.csv @MEDICAID_EXTRACTED
    AUTO_COMPRESS=TRUE
    OVERWRITE=TRUE;
```
Verify upload - in a Snowflake worksheet on Snowsight run:
```sql
LIST @MEDICAID_EXTRACTED;
```
Expected: medicaid-provider-spending.csv.gz   (2–3 GB compressed)


## 🟦 5. File Format
Run on Snowsight:
```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;
CREATE OR REPLACE FILE FORMAT MEDICAID_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null');
```

## 🟦 6. Create RAW table:
SQL file: sql/medicaid_ingestion_raw.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW (
    BILLING_PROVIDER_NPI_NUM VARCHAR,
    SERVICING_PROVIDER_NPI_NUM VARCHAR,
    HCPCS_CODE VARCHAR,
    CLAIM_FROM_MONTH VARCHAR,
    TOTAL_PATIENTS VARCHAR,
    TOTAL_CLAIM_LINES VARCHAR,
    TOTAL_PAID VARCHAR
);
```

## 🟦 7. Load CSV into RAW
SQL file: sql/medicaid_ingestion_raw.sql

```sql
COPY INTO RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW
FROM @MEDICAID_EXTRACTED
FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT')
ON_ERROR = 'CONTINUE';
```

## 🟦 8. CLEAN Stage Table
SQL file: sql/medicaid_clean_stage.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE AS
SELECT
    TRY_TO_NUMBER(TOTAL_PAID) AS TOTAL_PAID,
    TRY_TO_NUMBER(TOTAL_PATIENTS) AS TOTAL_PATIENTS,
    ...
FROM RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW;
```
## 🟦 9. Create DATE_DIM and SERVICE_CATEGORY_DIM for Power BI modeling
SQL file: sql/model/date_and_service_dimensions.sql

Purpose:
To enrich the MODEL layer and the Power BI modeling. It creates DATE_DIM table and SERVICE_CATEGORY_DIM table that will be joined to the FACT Table  
These dimensions are generated programmatically and do not originate from any source dataset.

`DATE_DIM` - Grain: 1 row per calendar date

Join: `FACT_MEDICAID_PROVIDER_SPENDING.CLAIM_MONTH` → `DATE_DIM.DATE`

`SERVICE_CATEGORY_DIM` - A reference dimension defining Medicaid service categories based on HCPCS patterns.

## 🟦 10. FACT Table
SQL file: sql/medicaid_fact_table.sql

Excerpt:
```sql
CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.FACT_PROVIDER_SPENDING AS
SELECT
    s.*,
    p.PROVIDER_NAME AS BILLING_PROVIDER_NAME,
    h.DESCRIPTION AS HCPCS_DESCRIPTION
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE s
LEFT JOIN ANALYTICS_MEDICAID.MODEL.DIM_PROVIDER p
    ON s.BILLING_PROVIDER_NPI_NUM = p.NPI
LEFT JOIN ANALYTICS_MEDICAID.MODEL.HCPCS_DIM h
    ON s.HCPCS_CODE = h.HCPCS_CODE;
```
9.1 FACT_MEDICAID_PROVIDER_SPENDING — Cluster + Foreign Keys

📌 Cluster Key: (CLAIM_MONTH, BILLING_PROVIDER_NPI)
```sql
-- ============================================================
-- CLUSTERING: FACT_MEDICAID_PROVIDER_SPENDING
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING
  CLUSTER BY (CLAIM_MONTH, BILLING_PROVIDER_NPI);
```

📌 Foreign Keys (documented, not enforced)
```sql
-- ============================================================
-- FOREIGN KEYS: FACT_MEDICAID_PROVIDER_SPENDING
-- ============================================================

-- Billing provider → NPI_DIM
ALTER TABLE ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING
  ADD CONSTRAINT FK_FACT_BILLING_NPI
  FOREIGN KEY (BILLING_PROVIDER_NPI)
  REFERENCES ANALYTICS_MEDICAID.MODEL.NPI_DIM (NPI);

-- Rendering provider → NPI_DIM
ALTER TABLE ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING
  ADD CONSTRAINT FK_FACT_RENDERING_NPI
  FOREIGN KEY (RENDERING_PROVIDER_NPI)
  REFERENCES ANALYTICS_MEDICAID.MODEL.NPI_DIM (NPI);

-- HCPCS → HCPCS_DIM
ALTER TABLE ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING
  ADD CONSTRAINT FK_FACT_HCPCS
  FOREIGN KEY (HCPCS_CODE)
  REFERENCES ANALYTICS_MEDICAID.MODEL.HCPCS_DIM (HCPCS_CODE);

-- Quality check
SELECT COUNT(*) AS TOTAL_ROWS,
       COUNT(DISTINCT BILLING_PROVIDER_NPI) AS UNIQUE_BILLING_NPIS,
       COUNT(DISTINCT HCPCS_CODE) AS UNIQUE_HCPCS
FROM ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING;  
```
Rationale:
- CLAIM_MONTH supports time‑series pruning
- BILLING_PROVIDER_NPI supports provider‑level rollups
- Composite clustering dramatically reduces scan cost on large fact tables


## 🟦 10. Quality Checks
SQL file: sql/medicaid_quality_checks.sql

Excerpt:
```sql
SELECT COUNT(*) FROM RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW;
SELECT COUNT(*) FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE;
SELECT COUNT(*) FROM ANALYTICS_MEDICAID.MODEL.FACT_PROVIDER_SPENDING;
```

## 🟦 11. Full Pipeline Script
SQL file: sql/medicaid_full_pipeline.sql

Excerpt:
```sql
!source medicaid_ingestion_raw.sql;
!source medicaid_clean_stage.sql;
!source medicaid_fact_table.sql;
!source medicaid_quality_checks.sql;
```

🟦 12. Troubleshooting
- ZIP file too small → downloaded HTML wrapper
- CSV not visible → wrong stage/schema
- Extraction fails → Snowflake /tmp limit → extract locally


---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI

