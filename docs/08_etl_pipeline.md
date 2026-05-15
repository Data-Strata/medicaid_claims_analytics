# ETL Pipeline (Orchestration & Automation)

Pipeline Tier: Orchestration
Depends On: `04_ingestion_medicaid.md`, `05_ingestion_hcpcs.md`, `06_ingestion_providers.md`, `07_data_modeling.md`

---
## Snowflake Environment Setup

### Databases & Schemas

| Layer | Database.Schema            | Purpose                                      |
|-------|----------------------------|----------------------------------------------|
| RAW   | `RAW_MEDICAID.PUBLIC`      | Unmodified source files (all VARCHAR/STRING) |
| STAGE | `STAGE_MEDICAID.CLEAN`     | Cleaned, typed, standardized tables          |
| MODEL | `ANALYTICS_MEDICAID.MODEL` | Curated dimension + fact tables              |

### Warehouse
```code
Warehouse: COMPUTE_WH
Size: XSMALL
Purpose: Ingestion + transforms
Auto-suspend: 60 seconds
Auto-resume: Enabled
```

### Internal Stages
| Stage                | Purpose                            |
|----------------------|------------------------------------|
| MEDICAID_STAGE       | Landing zone for original ZIPs     |
| MEDICAID_EXTRACTED   | Ingestion-ready extracted CSVs     |
| NPI_EXTRACTED        | Ingestion-ready NPI Registry CSV   |

---

## 🟦 1. Purpose

This document describes how the three ingestion pipelines (Medicaid, HCPCS, Provider) are orchestrated end-to-end.
Each pipeline follows the same **RAW → STAGE → MODEL → SEMANTIC MODEL (Power BI)** pattern , with execution tailored to dataset size and complexity.

## 🟦 1.5 Source Datasets

### Medicaid Provider Spending (Primary Dataset)
- Source: HHS Open Data
- Delivered as 3.5 GB ZIP → 11 GB CSV (~238M rows)
- Contains billing NPI, servicing NPI, HCPCS, paid amounts, and claim counts

### HCPCS Level II Reference
- Procedure code metadata from CMS
- Used to enrich Medicaid claims with descriptions and categories

### NPI Registry (NPPES)
- 330-column provider master file
- Used to enrich billing and servicing NPIs
- Extracted into its own stage due to schema sensitivity

---

## 🟦 2. Pipeline Summary

| Pipeline | Source | Orchestration Method | Full Pipeline Script |
|----------|--------|----------------------|----------------------|
| **Medicaid** | HHS Open Data (11 GB CSV) | SnowSQL `!source` or sequential SQL | `sql/medicaid_full_pipeline.sql` |
| **HCPCS** | CMS HCPCS Level II reference | SnowSQL `!source` | `sql/hcpcs_full_pipeline.sql` |
| **Provider (NPI)** | CMS NPPES Registry (330 columns) |  SnowSQL `!source` | `sql/provider_full_pipeline.sql` |


## 🟦 2.5 Ingestion Architecture

All three pipelines follow the same pattern:
```code
RAW → STAGE → MODEL → SEMANTIC MODEL (Power BI)
```
### Medicaid Pipeline
```code
RAW_MEDICAID.PUBLIC → STAGE_MEDICAID.CLEAN → FACT_MEDICAID_PROVIDER_SPENDING
```
### NPI Pipeline
```code
NPI_RAW (330 cols) → NPI_CLEAN (22 cols) → NPI_DIM
```
### HCPCS Pipeline
```code
HCPCS_RAW_WIDE (48 cols) → HCPCS_CLEAN (6 cols) → HCPCS_DIM
```
### Why NPI Uses Its Own Stage
The NPI Registry is significantly larger and schema-sensitive.  
Keeping it isolated prevents schema inference conflicts with Medicaid and HCPCS.

---

## 🟦 3. HCPCS Pipeline

### Execution Flow
```code
    CMS HCPCS CSV → MEDICAID_EXTRACTED → RAW_WIDE → CLEAN → DIM_HCPCS
```
### SQL Files (Execution Order)

| Step | SQL File | Action |
|------|----------|--------|
| 1 | `sql/hcpcs_ingestion_raw.sql` | Create 48-column RAW table, COPY INTO |
| 2 | `sql/hcpcs_clean.sql` | Extract 6 analytics fields into HCPCS_CLEAN |
| 3 | `sql/hcpcs_dimension.sql` | Create DIM_HCPCS (deduplicated) |
| 4 | `sql/hcpcs_quality_checks.sql` | Row-count, null, duplicate, and orphan checks |

### Full Pipeline Script
SQL file: `sql/hcpcs_full_pipeline.sql`

    -- Run from SnowSQL
    !source hcpcs_ingestion_raw.sql;
    !source hcpcs_clean.sql;
    !source hcpcs_dimension.sql;
    !source hcpcs_quality_checks.sql;

### Prerequisites
- HCPCS CSV must be uploaded to `@MEDICAID_EXTRACTED` via SnowSQL PUT
- `MEDICAID_CSV_FORMAT` file format must exist
- See `docs/05_ingestion_medicaid.md` for the complete file preparation workflow

---

## 🟦 4. NPI(Providers) Pipeline

### Execution Flow
```code
    External NPI CSV → @NPI_EXTRACTED → NPI_RAW → NPI_CLEAN → NPI_DIM 
```
### SQL Files (Execution Order)

| Step| SQL File                              | Action                                               |
|-----|---------------------------------------|------------------------------------------------------|
| 1   | `sql/provider_ingestion_raw.sql`      | Create 330-column RAW table, COPY INTO |
| 2   | `sql/provider_clean.sql`              | Extract 19 analytics fields into NPI_CLEAN |
| 3   | `sql/provider_dimension.sql`          | Create NPI_DIM (deduplicated) |
| 4   | `sql/model/clean_provider_states.sql` | Standardizes PRACTICE_STATE and MAILING_STATE into U.S. states  
| 5   | `sql/provider_quality_checks.sql`     | Row-count, null, duplicate, and orphan checks |

### Prerequisites
- NPI CSV must be uploaded to `@NPI_EXTRACTED` via SnowSQL PUT
- `NPI_CSV_FORMAT` file format must exist
- See `docs/06_ingestion_hcpcs.md` for the complete file preparation workflow

 ```sql 
  -- Run from SnowSQL
    !source sql/provider_ingestion_raw.sql;
    !source sql/provider_clean.sql;
    !source sql/provider_dimension.sql;
    !source sql/model/clean_provider_states.sql
    !source sql/provider_quality_checks.sql;
```
---

## 🟦 5. Medicaid Pipeline


**Important:** The Medicaid pipeline must run **LAST** because `FACT_PROVIDER_SPENDING` joins against both `DIM_PROVIDER` and `DIM_HCPCS`. 
If the dimensions do not exist, the LEFT JOINs will produce NULL enrichment columns.

### Execution Flow
```code
    External ZIP → Local Extract → MEDICAID_EXTRACTED → RAW → STAGE → FACT
```
### SQL Files (Execution Order)

| Step | SQL File | Action |
|------|----------|--------|
| 1 | `sql/medicaid_ingestion_raw.sql` | Create file format, RAW table, COPY INTO |
| 2 | `sql/medicaid_clean_stage.sql` | Create MEDICAID_PROVIDER_SPENDING_STAGE (typed) |
| 3 | `sql/model/date_and_service_dimensions.sql` | Creates DATE_DIM & SERVICE_DIM dimesions
| 4 | `sql/medicaid_fact_table.sql` | Create FACT_PROVIDER_SPENDING (joined with DIMs) |
| 5 | `sql/medicaid_quality_checks.sql` | Row-count validation across all layers |

### Full Pipeline Script
SQL file: `sql/medicaid_full_pipeline.sql`

    -- Run from SnowSQL
    !source sql/medicaid_ingestion_raw.sql;
    !source sql/medicaid_clean_stage.sql;
    !source sql/model/date_and_service_dimensions.sql 
    !source sql/medicaid_fact_table.sql;
    !source sql/medicaid_quality_checks.sql;

### Prerequisites
- Medicaid CSV must be uploaded to `@MEDICAID_EXTRACTED` via SnowSQL PUT
- `MEDICAID_CSV_FORMAT` file format must exist
- See `docs/04_ingestion_medicaid.md` for the complete file preparation workflow

---

** 🟦 6. MODEL Layer Semantic Scripts (Power BI Modeling)

These scripts enrich the MODEL layer before FACT_MODEL is consumed by Power BI.

✅Execution Flow
```
provider_build_dim() 
    → clean_provider_states.sql 
    → date_and_service_dimensions.sql 
    → fact_build_model()
    → legacy_servicing_provider_dim.sql
    → dq_invalid_npi_trend.sql
    → dq_invalid_npi_anomalies.sql

```
SQL Files (Execution Order)
| Step | SQL File                                      | Action                                                                                                                       |
| ---  | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1    | ``sql/model/clean_provider_states.sql``       | Standardizes PRACTICE_STATE and MAILING_STATE into U.S. states (adds PRACTICE_STATE_US, MAILING_STATE_US, PROVIDER_STATE_US) |
| 2    | ``sql/model/date_and_service_dimensions.sql`` | Creates DATE_DIM and SERVICE_CATEGORY_DIM for Power BI modeling                                                              |
| 3    | `sql/model/legacy_servicing_provider_dim.sql` | Builds the Legacy Servicing Provider Dimension (A-/M-prefix and non‑NPI servicing IDs)                                       |
| 4    | `sql/model/dq_invalid_npi_trend.sql`          | Creates monthly invalid NPI trend table                                                                                      |
| 5    | `sql/model/dq_invalid_npi_anomalies.sql`      | Creates 3‑sigma anomaly detection table for invalid NPI spikes/drops                                                         |

### Prerequisites

- `provider_build_dim()` must be completed (PROVIDER_DIM must exist)
- `date_and_service_dimensions.sql` must be completed (DATE_DIM + SERVICE_CATEGORY_DIM must exist)
- `fact_build_model()` must be completed before running integrity scripts
- `legacy_servicing_provider_dim.sql` depends on FACT + SERVICE_CATEGORY_DIM
- `dq_invalid_npi_trend.sql` depends on FACT + DATE_DIM
- `dq_invalid_npi_anomalies.sql` depends on FACT + DATE_DIM
- These scripts run **after** core MODEL tables are built and **before** the BI semantic model is consumed
- They do not modify RAW or STAGE layers — only MODEL

---

## 🟦 7. Quality Checks

Each pipeline includes a dedicated quality check script that validates data integrity across all layers:

| Pipeline | Quality Check Script | Validations |
|----------|---------------------|-------------|
| Medicaid | `sql/medicaid_quality_checks.sql` | Row counts across RAW → STAGE → FACT |
| HCPCS    | `sql/hcpcs_quality_checks.sql`    | Row counts, null codes, duplicates, orphan codes in fact table |
| Provider | `sql/provider_quality_checks.sql` | Row counts, duplicate NPIs across layers |

👉 For a full forensic analysis of the 2018 column‑shift incident, see  
`docs/16_data_quality_incident.md`.

### Cross-Pipeline Validation
After all three pipelines complete, validate dimension join coverage:

    -- Provider coverage in fact table
    SELECT
        COUNT(*) AS TOTAL,
        COUNT(BILLING_PROVIDER_NAME) AS WITH_PROVIDER,
        ROUND(COUNT(BILLING_PROVIDER_NAME) / COUNT(*) * 100, 2) AS PCT
    FROM ANALYTICS_MEDICAID.MODEL.FACT_PROVIDER_SPENDING;

    -- HCPCS coverage in fact table
    SELECT
        COUNT(*) AS TOTAL,
        COUNT(HCPCS_DESCRIPTION) AS WITH_HCPCS,
        ROUND(COUNT(HCPCS_DESCRIPTION) / COUNT(*) * 100, 2) AS PCT
    FROM ANALYTICS_MEDICAID.MODEL.FACT_PROVIDER_SPENDING;

---

## ⭐ 8. Complete SQL File Inventory
```code
| #  | SQL File                           | Pipeline          | Layer      | Type          |
|----|------------------------------------|-------------------|------------|---------------|
| 1  | medicaid_ingestion_raw.sql         | Medicaid          | RAW        | Script        |
| 2  | medicaid_clean_stage.sql           | Medicaid          | STAGE      | Script        |
| 3  | medicaid_fact_table.sql            | Medicaid          | ANALYTICS  | Script        |
| 4  | medicaid_quality_checks.sql        | Medicaid          | QC         | Script        |
| 5  | medicaid_full_pipeline.sql         | Medicaid          | Orchestration | Script     |
| 6  | hcpcs_ingestion_raw.sql            | HCPCS             | RAW        | Script        |
| 7  | hcpcs_clean.sql                    | HCPCS             | STAGE      | Script        |
| 8  | hcpcs_dimension.sql                | HCPCS             | ANALYTICS  | Script        |
| 9  | hcpcs_quality_checks.sql           | HCPCS             | QC         | Script        |
| 10 | hcpcs_full_pipeline.sql            | HCPCS             | Orchestration | Script     |
| 11 | provider_ingestion_raw.sql         | Provider          | RAW        | Script        |
| 12 | provider_clean.sql                 | Provider          | STAGE      | Script        |
| 13 | provider_dimension.sql             | Provider          | ANALYTICS  | Script        |
| 14 | provider_quality_checks.sql        | Provider          | QC         | Script        |
| 15 | provider_full_pipeline.sql         | Provider          | Orchestration | Script     |
| 16 | clean_provider_states.sql          | MODEL (Semantic)  | ANALYTICS  | Geographic Standardization |
| 17 | date_and_service_dimensions.sql    | MODEL (Semantic)  | ANALYTICS  | DATE_DIM + SERVICE_CATEGORY_DIM |
| 18 | legacy_servicing_provider_dim.sql  | MODEL (Integrity) | MODEL      | Legacy Servicing DIM |
| 19 | dq_invalid_npi_trend.sql           | MODEL (Integrity) | MODEL      | Trend Table |
| 20 | dq_invalid_npi_anomalies.sql       | MODEL (Integrity) | MODEL      | Anomaly Detection |
```


---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
