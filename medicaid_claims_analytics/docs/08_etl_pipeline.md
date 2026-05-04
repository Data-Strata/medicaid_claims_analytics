# ETL Pipeline (Orchestration & Automation)

Pipeline Tier: Orchestration
Depends On: `04_ingestion_medicaid.md`, `05_ingestion_hcpcs.md`, `06_ingestion_providers.md`, `07_data_modeling.md`

---

## 🟦 1. Purpose

This document describes how the three ingestion pipelines (Medicaid, HCPCS, Provider) are orchestrated end-to-end.
Each pipeline follows the same **RAW → STAGE → MODEL → SEMANTIC MODEL (Power BI)** pattern but uses a different execution mechanism appropriate to its complexity.

---

## 🟦 2. Pipeline Summary

| Pipeline | Source | Orchestration Method | Full Pipeline Script |
|----------|--------|----------------------|----------------------|
| **Medicaid** | HHS Open Data (11 GB CSV) | SnowSQL `!source` or sequential SQL | `sql/medicaid_full_pipeline.sql` |
| **HCPCS** | CMS HCPCS Level II reference | SnowSQL `!source` | `sql/hcpcs_full_pipeline.sql` |
| **Provider (NPI)** | CMS NPPES Registry (330 columns) |  SnowSQL `!source` | `sql/provider_full_pipeline.sql` |

---

## 🟦 3. Medicaid Pipeline


**Important:** The Medicaid pipeline must run **last** because `FACT_PROVIDER_SPENDING` joins against both `DIM_PROVIDER` and `DIM_HCPCS`. If the dimensions do not exist, the LEFT JOINs will produce NULL enrichment columns.

### Execution Flow

    External ZIP → Local Extract → MEDICAID_EXTRACTED → RAW → STAGE → FACT

### SQL Files (Execution Order)

| Step | SQL File | Action |
|------|----------|--------|
| 1 | `sql/medicaid_ingestion_raw.sql` | Create file format, RAW table, COPY INTO |
| 2 | `sql/medicaid_clean_stage.sql` | Create MEDICAID_PROVIDER_SPENDING_STAGE (typed) |
| 3 | `sql/medicaid_fact_table.sql` | Create FACT_PROVIDER_SPENDING (joined with DIMs) |
| 4 | `sql/medicaid_quality_checks.sql` | Row-count validation across all layers |

### Full Pipeline Script
SQL file: `sql/medicaid_full_pipeline.sql`

    -- Run from SnowSQL
    !source medicaid_ingestion_raw.sql;
    !source medicaid_clean_stage.sql;
    !source medicaid_fact_table.sql;
    !source medicaid_quality_checks.sql;

### Prerequisites
- Medicaid CSV must be uploaded to `@MEDICAID_EXTRACTED` via SnowSQL PUT
- `MEDICAID_CSV_FORMAT` file format must exist
- See `docs/04_ingestion_medicaid.md` for the complete file preparation workflow

---

## 🟦 4. HCPCS Pipeline

### Execution Flow

    CMS HCPCS CSV → MEDICAID_EXTRACTED → RAW_WIDE → CLEAN → DIM_HCPCS

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

## 🟦 5. NPI(Providers) Pipeline

### Execution Flow

    External NPI CSV → @NPI_EXTRACTED → NPI_RAW → NPI_CLEAN → NPI_DIM 

### SQL Files (Execution Order)

| Step | SQL File | Action |
|------|----------|--------|
| 1 | `sql/provider_ingestion_raw.sql` | Create 330-column RAW table, COPY INTO |
| 2 | `sql/provider_clean.sql` | Extract 19 analytics fields into NPI_CLEAN |
| 3 | `sql/provider_dimension.sql` | Create NPI_DIM (deduplicated) |
| 4 | `sql/provider_quality_checks.sql` | Row-count, null, duplicate, and orphan checks |

### Prerequisites
- NPI CSV must be uploaded to `@NPI_EXTRACTED` via SnowSQL PUT
- `NPI_CSV_FORMAT` file format must exist
- See `docs/06_ingestion_hcpcs.md` for the complete file preparation workflow

 ```sql 
  -- Run from SnowSQL
    !source provider_ingestion_raw.sql;
    !source provider_clean.sql;
    !source provider_dimension.sql;
    !source provider_quality_checks.sql;
```
---

🟦 6. MODEL Layer Semantic Scripts (Power BI Modeling)
These scripts are not part of the ingestion pipelines.
They run after all three pipelines complete, because they depend on:
- NPI_DIM
- HCPCS_DIM
- FACT_MEDICAID_PROVIDER_SPENDING

They enrich the MODEL layer for BI and semantic modeling.

Execution Flow
```sql
NPI_DIM → Geographic Standardization → Updated NPI_DIM
FACT_MEDICAID_PROVIDER_SPENDING → DATE_DIM + SERVICE_CATEGORY_DIM → BI Semantic Model
```
SQL Files (Execution Order)
| Step | SQL File                               | Action                                                                                                                       |
| ---- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1    | ``sql/clean_provider_states.sql``      | Standardizes PRACTICE_STATE and MAILING_STATE into U.S. states (adds PRACTICE_STATE_US, MAILING_STATE_US, PROVIDER_STATE_US) |
| 2    | ``sql/date_and_service_dimensions.sql``| Creates DATE_DIM and SERVICE_CATEGORY_DIM for Power BI modeling |

Prerequisites
- All three ingestion pipelines must be completed
- NPI_DIM, HCPCS_DIM, and FACT_MEDICAID_PROVIDER_SPENDING must exist
- These scripts do not modify RAW or STAGE layers — only MODEL

Execution Notes
- These scripts are typically run:
- Once during initial warehouse build
- Whenever the MODEL layer is refreshed
- Before exporting to Power BI

---

## 🟦 7. Quality Checks

Each pipeline includes a dedicated quality check script that validates data integrity across all layers:

| Pipeline | Quality Check Script | Validations |
|----------|---------------------|-------------|
| Medicaid | `sql/medicaid_quality_checks.sql` | Row counts across RAW → STAGE → FACT |
| HCPCS    | `sql/hcpcs_quality_checks.sql`    | Row counts, null codes, duplicates, orphan codes in fact table |
| Provider | `sql/provider_quality_checks.sql` | Row counts, duplicate NPIs across layers |

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

⭐ UPDATED: 8. Complete SQL File Inventory
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
```


---

## ✍️ Author
© 2026 Mairilyn Yera Galindo | *Data-Strata Analytics Portfolio*
Healthcare Data Analytics | Snowflake + SQL Server + Power BI + Excel
🏖️ Boca Raton, FL
🌐 https://github.com/Data-Strata
📧 mairilynyera@gmail.com
💼 LinkedIn: www.linkedin.com/in/mairilyn-yera-galindo-07a93932
