## Medicaid Claims Analytics

## 📊 Data Sources

[![Medicaid Provider Spending](https://img.shields.io/badge/HHS%20Open%20Data-Medicaid%20Provider%20Spending-blue)](https://opendata.hhs.gov/datasets/medicaid-provider-spending/)
[![HCPCS Level II](https://img.shields.io/badge/CMS-HCPCS%20Level%20II-purple)](https://www.cms.gov/medicare/coding/hcpcs-release-code-sets)
[![NPI Registry](https://img.shields.io/badge/CMS-NPI%20Registry-green)](https://download.cms.gov/nppes/NPI_Files.html)

## 📘 Project Overview
Medicaid Claims Analytics is a full end‑to‑end healthcare analytics project built on Snowflake and Power BI, designed to process, model, and visualize large‑scale public healthcare datasets.
The project integrates three federal data sources — Medicaid Provider Spending, HCPCS Level II, and the NPPES NPI Registry — into a unified analytics environment using a clean RAW → STAGE → MODEL warehouse architecture.

The pipeline includes:
- Automated ingestion of multi‑GB public datasets using Snowflake internal stages
- RAW layer storage of Medicaid, HCPCS, and NPI data
- STAGE layer cleaning, typing, and analytics‑ready transformations
- MODEL layer star schema with:
- FACT_PROVIDER_SPENDING
- DIM_PROVIDER
- DIM_HCPCS
- DATE_DIM
- SERVICE_CATEGORY_DIM
- Geographic standardization (U.S. state extraction from messy NPI fields)
- Power BI dashboard for provider performance, utilization, cost trends, and geographic insights

This repository includes all documentation, SQL scripts, data modeling logic, and architecture diagrams needed to reproduce the full solution.

## 🚀 Project Status

| Phase           | Status |
| --------------- | ------ |
| RAW ingestion (3 source datasets) | ✅ Complete |
| STAGE layer (cleaned + typed) | ✅ Complete |
| Dimension tables (NPI_DIM, HCPCS_DIM) | ✅ Complete |
| Fact table (FACT_MEDICAID_PROVIDER_SPENDING) | ✅ Complete |
| Clustering keys applied | ✅ Complete |
| BI semantic model | 🟨 In Progress |
| Power BI dashboard | 🟨 In Progress |
| Analytics & insights | 🔲 Planned |

## Objectives
- Build a Snowflake data warehouse (RAW → STAGE → ANALYTICS)
- Ingest and clean three real-world healthcare datasets
- Build dimension tables with deduplication logic
- Build a fact table with clustering for query performance
- Build a Power BI dashboard for provider performance analytics
- Document every step for portfolio reproducibility

## 🧰 Tech Stack & Tools

<p align="left">
  <img src="https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white" />
  <img src="https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" />
  <img src="https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" />
</p>

## Snowflake Environment

### Databases & Schemas

| Layer | Database.Schema            | Purpose                                      |
|-------|----------------------------|----------------------------------------------|
| RAW   | `RAW_MEDICAID.PUBLIC`      | Unmodified source files (all VARCHAR/STRING) |
| STAGE | `STAGE_MEDICAID.CLEAN`     | Cleaned, typed, standardized tables          |
| MODEL | `ANALYTICS_MEDICAID.MODEL` | Curated dimension + fact tables              |

### Warehouse
```code
Warehouse: WH_MEDICAID_ETL
Size: XSMALL
Purpose: Ingestion + transforms
Auto-suspend: 60 seconds
Auto-resume: Enabled
```
## Dataset

**Medicaid Provider Spending by HCPCS**
Source: https://opendata.hhs.gov/datasets/medicaid-provider-spending/

The primary dataset is delivered as a **3.5 GB ZIP** containing a single **11 GB CSV** (~238M rows).

Two additional reference datasets enrich the claims data:
- **HCPCS Level II** — procedure code descriptions (from CMS)
- **NPI Registry (NPPES)** — provider demographics (330 columns, from CMS)

### Internal Stages

| Stage                | Purpose                            |
|----------------------|------------------------------------|
| `MEDICAID_STAGE`     | Landing zone for original ZIPs     |
| `MEDICAID_EXTRACTED` | Ingestion-ready extracted CSVs     |
| `NPI_EXTRACTED`      | Ingestion-ready CSV (NPI Registry) |


## Pipeline Overview
```code
RAW_MEDICAID.PUBLIC          STAGE_MEDICAID.CLEAN              ANALYTICS_MEDICAID.MODEL
─────────────────────        ────────────────────────          ────────────────────────────
MEDICAID_PROVIDER_       →   MEDICAID_PROVIDER_            →   FACT_MEDICAID_PROVIDER_
SPENDING_RAW                 SPENDING_STAGE                    SPENDING

NPI_RAW (330 cols)       →   NPI_CLEAN (11 cols)           →   NPI_DIM (1 row per NPI)

HCPCS_RAW_WIDE (48 cols) →   HCPCS_CLEAN (6 cols)          →   HCPCS_DIM (1 row per code)
```

All three pipelines follow the same pattern: manual `CREATE TABLE` (all STRING) → `COPY INTO` → typed CLEAN → deduplicated DIM/FACT.

Medicaid and HCPCS use `@MEDICAID_EXTRACTED`; NPI uses its own dedicated `@NPI_EXTRACTED` stage.

The NPI Registry is extracted into its own stage (`NPI_EXTRACTED`) because the NPPES file is significantly larger and far more schema‑sensitive than the Medicaid and HCPCS datasets. 

Keeping NPI isolated prevents schema inference conflicts during ingestion, while Medicaid and HCPCS safely share `MEDICAID_EXTRACTED` due to their smaller, stable, and compatible file structures.

## Project Structure
```code
medicaid_claims_analytics/
│
├── README.md
├── docs/
│   ├── 01_project_overview.md            # Environment, repo, folder structure
│   ├── 02_dataset_description.md         # Dataset fields, schema, metadata
│   ├── 03_snowflake_setup.md             # Warehouses, DBs, schemas, roles
│   ├── 04_ingestion_medicaid.md          # Medicaid ingestion pipeline (ZIP → RAW)
│   ├── 05_ingestion_hcpcs.md             # HCPCS reference ingestion pipeline
│   ├── 06_ingestion_providers.md         # NPI Registry ingestion pipeline
│   ├── 07_data_modeling.md               # Star schema + DIM/FACT design + clustering
│   ├── 08_etl_pipeline.md                # Pipeline orchestration + execution order
│   ├── 09_powerbi_dashboard.md           # Dashboard design + DAX 
│   ├── 10_results_and_insights.md        # Findings + analytics summary
│   ├── 11_s2t_mapping.md                 # Source‑to‑Target lineage (updated with geographic standardization)
│   ├── 12_NPI_data_quality_analysis.md   # Technical appendix on unmatched NPI categories & anomaly tables|
│   ├── 13_geographic_standardization.md  # PRACTICE_STATE/MAILING_STATE cleanup + STATE_REF logic  
│   └── 14_Medicaid_data_glossary.md      # Medicaid data glossary
│
├── sql/
│   ├── ── Medicaid Pipeline ──────────────────────────
│   ├── medicaid_ingestion_raw.sql          # RAW table + COPY INTO
│   ├── medicaid_clean_stage.sql            # STAGE layer (typed + standardized)
│   ├── medicaid_fact_table.sql             # FACT_PROVIDER_SPENDING (analytics)
│   ├── medicaid_quality_checks.sql         # Row-count + orphan validations
│   ├── medicaid_full_pipeline.sql          # End-to-end orchestration script
│   │
│   ├── ── HCPCS Pipeline ────────────────────────────
│   ├── hcpcs_ingestion_raw.sql             # RAW table (48-column wide) + COPY INTO
│   ├── hcpcs_clean.sql                     # CLEAN table (6 analytics fields)
│   ├── hcpcs_dimension.sql                 # DIM_HCPCS (analytics layer)
│   ├── hcpcs_quality_checks.sql            # Row-count + orphan validations
│   ├── hcpcs_full_pipeline.sql             # End-to-end orchestration (!source)
│   │
│   ├── ── Provider (NPI) Pipeline ───────────────────
│   ├── provider_ingestion_raw.sql          # RAW table (INFER_SCHEMA) + COPY INTO
│   ├── provider_clean.sql                  # CLEAN table (11 analytics fields) -------------------check
│   ├── provider_dimension.sql              # DIM_PROVIDER (deduplicated by NPI)
│   ├── provider_quality_checks.sql         # Row-count + duplicate validations
│   ├── provider_full_pipeline.sql          # End-to-end orchestration 
│   │
│   ├── ── Model ───────────────────   
│   ├── date_and_service_dimensions.sql     # Creates DATE_DIM and SERVICE_DIM for BI semantic modeling
│   └── clean_provider_states.sql           # Standardizes PRACTICE_STATE and MAILING_STATE into U.S. state abbreviations (MODEL layer)
│
├── data/
│   └── README.md   # Dataset overview + source link
│
├── powerbi/
│   └── dashboard.pbix                 # (planned)
│
└── assets/
    ├── architecture_diagram.png
    ├── ingestion_diagram.png
    ├── data_model.png
    └── dashboard_screenshots/            # (planned)
```
---

## 🧪 SQL Scripts

### Medicaid Pipeline
| Script | Purpose |
|--------|---------|
| `medicaid_ingestion_raw.sql` | File format, RAW table (all VARCHAR), COPY INTO |
| `medicaid_clean_stage.sql` | MEDICAID_PROVIDER_SPENDING_STAGE with typed columns |
| `medicaid_fact_table.sql` | FACT_MEDICAID_PROVIDER_SPENDING + LOAD_TIMESTAMP + clustering |
| `medicaid_quality_checks.sql` | Row-count validation across layers |
| `medicaid_full_pipeline.sql` | End-to-end orchestration script |

### HCPCS Pipeline
| Script | Purpose |
|--------|---------|
| `hcpcs_ingestion_raw.sql` | 48-column RAW table + COPY INTO |
| `hcpcs_clean.sql` | HCPCS_CLEAN (6 analytics fields) |
| `hcpcs_dimension.sql` | HCPCS_DIM + clustering |
| `hcpcs_quality_checks.sql` | Row-count, null, duplicate, orphan checks |
| `hcpcs_full_pipeline.sql` | End-to-end orchestration |

### Provider (NPI) Pipeline
| Script                       | Purpose                                       |
|------------------------------|-----------------------------------------------|
| `provider_ingestion_raw.sql` | NPI_RAW (330 columns, all STRING) + COPY INTO |
| `provider_clean.sql`         | NPI_CLEAN (11 fields from 330-column RAW) |
| `provider_dimension.sql`     | NPI_DIM (deduplicated: MAX + JOIN, 1 row per NPI) + clustering |
| `provider_quality_checks.sql`| Row-count + duplicate NPI validations |
| `provider_full_pipeline.sql` | End-to-end orchestration |

### Model 
| Script                              | Purpose                                                        |
| ---------------------------------   | -------------------------------------------------------------- |
| ``clean_provider_states.sql``       | Standardizes PRACTICE_STATE and MAILING_STATE into U.S. states |
| ``date_and_service_dimensions.sql`` | Creates DATE_DIM and SERVICE_DIM for BI semantic modeling      |

# 🟦 Provider Data Quality Analysis (NPI Integration)

A detailed technical appendix analyzing the 96.69% NPI match rate, unmatched provider categories, anomaly patterns, and Medicaid‑specific billing behaviors is available in the documentation folder:

👉 docs\09_NPI_data_quality_analysis.md (Includes unmatched NPI categories, anomaly tables, SQL diagnostics, and a full narrative.)

## 🧱 MODEL Layer Summary
```code
| Table                             | Grain                                                 | Source                                  |
|-----------------------------------|-------------------------------------------------------|-----------------------------------------|
| `NPI_DIM`                         | 1 row per NPI                                         | NPI_CLEAN (deduplicated via MAX + JOIN) |
| `HCPCS_DIM`                       | 1 row per HCPCS code                                  | HCPCS_CLEAN                             |
| `FACT_MEDICAID_PROVIDER_SPENDING` | 1 row per billing NPI + servicing NPI + HCPCS + month | MEDICAID_PROVIDER_SPENDING_STAGE        |
| ``DATE_DIM``                      | 1 row per date                                        | Supports time intelligence              |
| ``SERVICE_CATEGORY_DIM``          | 1 row per category                                    | Groups HCPCS codes into clinical categories |
```
## 🧊 Clustering Strategy (MODEL Layer)
Clustering keys are applied to all MODEL-layer tables for query performance and reduce scan cost:
```code
| Table                             | Clustering Key                                   |
|-----------------------------------|--------------------------------------------------|
| `NPI_DIM`                         | `CLUSTER BY (NPI)`                               |
| `HCPCS_DIM`                       | `CLUSTER BY (HCPCS_CODE)`                        |
| `FACT_MEDICAID_PROVIDER_SPENDING` | `CLUSTER BY (CLAIM_MONTH, BILLING_PROVIDER_NPI)` |
```

📌Clustering Strategy (MODEL Layer)

The analytics layer uses targeted clustering keys to optimize pruning and reduce scan cost across large Medicaid datasets.

NPI_DIM
Cluster Key: NPI
Rationale:
- Primary join key for provider enrichment
- Small, stable dimension
- High cardinality warning is expected and harmless

HCPCS_DIM
Cluster Key: HCPCS_CODE
Rationale:
- Lookup dimension
- Frequently joined to FACT tables
- Minimal reclustering overhead

FACT_MEDICAID_PROVIDER_SPENDING
Cluster Key: (CLAIM_MONTH, BILLING_PROVIDER_NPI)
Rationale:
- Time‑series analytics on CLAIM_MONTH
- Provider‑level rollups and joins on NPI
- Significant micro‑partition pruning
- Best practice for large fact tables

This clustering strategy balances performance, cost, and maintainability, following Snowflake medallion architecture principles.

📌 NPI_DIM — New Standardized Fields

| Column                | Type    | Description                                              |
| --------------------- | ------- | -------------------------------------------------------- |
| ``PRACTICE_STATE_US`` | VARCHAR | Cleaned U.S. state extracted from PRACTICE_STATE         |
| ``MAILING_STATE_US``  | VARCHAR | Cleaned U.S. state extracted from MAILING_STATE          |
| ``PROVIDER_STATE_US`` | VARCHAR | Unified state field used for Power BI geographic visuals |

## 📌 Primary & Foreign Key Relationships (Star Schema)
Although Snowflake does not enforce constraints, the MODEL layer defines them for lineage, BI modeling, and documentation clarity.

Primary Keys
| Table | Primary Key | Description |
| --- | --- | --- |
| ``NPI_DIM`` | ``NPI`` | Unique provider identifier |
| ``HCPCS_DIM`` | ``HCPCS_CODE`` | Unique procedure code |
| ``FACT_MEDICAID_PROVIDER_SPENDING`` | Composite (implicit) | Grain: one row per provider per claim month |

Foreign Keys
| Fact Column | References | Purpose |
| --- | --- | --- |
| ``BILLING_PROVIDER_NPI`` | ``NPI_DIM(NPI)`` | Provider enrichment |
| ``RENDERING_PROVIDER_NPI`` | ``NPI_DIM(NPI)`` | Rendering provider details |
| ``HCPCS_CODE`` | ``HCPCS_DIM(HCPCS_CODE)`` | Procedure metadata |

This creates a clean, well‑defined star schema optimized for analytics.


🟦 BI Semantic Model (In Progress)
- Relationships defined between FACT and DIM tables
- Measures created (Total Paid, Total Claims, Avg Paid per Claim)
- Top 10 Providers visual implemented
- U.S. Filled Map implemented using PROVIDER_STATE_US
- Additional pages planned (HCPCS, Provider Detail, Trends)


### What is NOT in this project (yet)
- No SCD (Slowly Changing Dimension) logic
- No GEOGRAPHY_DIM (state cleanup handled in MODEL layer instead)
- Power BI dashboard in progress (Page 1 complete; additional pages planned)
- BI semantic model in progress (relationships + measures being built)
- DATE_DIM and SERVICE_CATEGORY_DIM implemented, but not yet integrated into Power BI model


## 📚 Documentation

| Doc                                        | Description                         |
|--------------------------------------------|-------------------------------------|
| `docs/01_project_overview.md`              | Environment, repo, folder structure |
| `docs/02_dataset_description.md`           | Dataset fields, schema, metadata |
| `docs/03_snowflake_setup.md`               | Warehouses, DBs, schemas, stages |
| `docs/04_ingestion_medicaid.md`            | Medicaid ingestion pipeline (ZIP → RAW) |
| `docs/05_ingestion_hcpcs.md`               | HCPCS reference ingestion pipeline |
| `docs/06_ingestion_providers.md`           | NPI Registry ingestion pipeline |
| `docs/07_data_modeling.md`                 | Star schema + DIM/FACT design + clustering |
| `docs/08_etl_pipeline.md`                  | Pipeline orchestration + execution order |
| `docs/09_powerbi_dashboard.md`             | Dashboard design + DAX (planned) |
| `docs/10_results_and_insights.md`          | Findings + analytics summary (planned) |
| `docs/11_s2t_mapping.md`                   | Source to Target mapping |
| `docs/12_NPI_data_quality_analysis.md`     | Technical appendix on unmatched NPI categories & anomaly tables|
| `docs/13_geographic_standardization.md`    | PRACTICE_STATE/MAILING_STATE cleanup + STATE_REF logic  
| `docs/14_Medicaid_data_glossary.md`        | Medicaid data glossary
| `docs/15_date_and_service_dimensions.md`   | DATE_DIM + SERVICE_CATEGORY_DIM documentation

## 🛠️ Technologies Used

- **Snowflake** — Warehouse, Stages, COPY INTO, Clustering, SQL
- **SnowSQL CLI** — File uploads and `!source` orchestration
- **PowerShell / curl.exe** — Windows-based file downloads
- **Power BI** — Dashboard and analytics (planned)
- **GitHub** — Version control and documentation

## 🎯 What This Project Demonstrates

- Real-world ingestion of large healthcare datasets (ZIP, CSV, multi-source)
- Three-layer warehouse architecture (RAW → STAGE → MODEL)
- NPI deduplication using sanitized timestamps and MAX() + JOIN
- Clustering keys for query performance at scale (~238M rows)
- Documentation-driven engineering
- Healthcare analytics readiness

---

📘 DATA DICTIONARY — MODEL LAYER

📌 NPI_DIM

Grain: One row per unique NPI

Purpose: Provider master dimension for enrichment and analytics
```code
| Column                    | Type         | Description         |
| ------------------------- | ------------ | --------------------------------- |
| ``NPI``                   | VARCHAR(10)  | National Provider Identifier (PK) |
| ``ENTITY_TYPE_CODE``      | VARCHAR      | 1 = Individual, 2 = Organization |
| ``REPLACEMENT_NPI``       | VARCHAR      | Successor NPI if applicable |
| ``ORG_NAME``              | VARCHAR      | Legal business name (organizations) |
| ``LAST_NAME``             | VARCHAR      | Provider last name |
| ``FIRST_NAME``            | VARCHAR      | Provider first name |
| ``MIDDLE_NAME``           | VARCHAR      | Provider middle name |
| ``CREDENTIALS``           | VARCHAR      | Provider credentials (MD, DO, etc.) |
| ``FULL_NAME``             | VARCHAR      | Concatenated full name |
| ``MAILING_CITY``          | VARCHAR      | Mailing city |
| ``MAILING_STATE``         | VARCHAR      | Mailing state |
| ``MAILING_ZIP``           | VARCHAR      | 5‑digit ZIP |
| ``PRACTICE_CITY``         | VARCHAR      | Practice city |
| ``PRACTICE_STATE``        | VARCHAR      | Practice state |
| ``PRACTICE_ZIP``          | VARCHAR      | 5‑digit ZIP |
| ``ENUMERATION_DATE``      | DATE         | NPI enumeration date |
| ``LAST_UPDATE_DATE``      | DATE         | Last update to NPI record |
| ``GENDER``                | VARCHAR      | Provider gender |
| ``PRIMARY_TAXONOMY_CODE`` | VARCHAR      | Primary taxonomy code |
| ``PRACTICE_STATE_US``     | VARCHAR      | Cleaned U.S. state extracted from PRACTICE_STATE         |
| ``MAILING_STATE_US``      | VARCHAR      | Cleaned U.S. state extracted from MAILING_STATE          |
| ``PROVIDER_STATE_US``     | VARCHAR      | Unified state field used for Power BI geographic visuals |
```

📌 HCPCS_DIM

Grain: One row per HCPCS code

Purpose: Procedure metadata dimension
```code
| Column               | Type    | Description         |
| ---------------------| ------- | ------------------- |
| ``HCPCS_CODE``       | VARCHAR | Procedure code (PK) |
| ``DESCRIPTION``      | VARCHAR | Long description    |
| ``SHORT_DESCRIPTION``| VARCHAR | Short description   |
| ``CATEGORY``         | VARCHAR | HCPCS category      |
| ``EFFECTIVE_DATE``   | DATE    | Code effective date |
| ``TERMINATION_DATE`` | DATE    | Code termination date|
```

📌 FACT_MEDICAID_PROVIDER_SPENDING

Grain: One row per provider per claim month

Purpose: Core analytical fact table for Medicaid spending
```code
| Column                    | Type       | Description         |
| ------------------------- | -----------| ------------------- |
| ``CLAIM_MONTH``           | DATE       | Month of service    |
| ``BILLING_PROVIDER_NPI``  | VARCHAR(10)| FK → NPI_DIM        |
| ``RENDERING_PROVIDER_NPI``| VARCHAR(10)| FK → NPI_DIM        |
| ``HCPCS_CODE``            | VARCHAR    | FK → HCPCS_DIM      |
| ``TOTAL_CLAIMS``          | NUMBER     | Number of claims    |
| ``TOTAL_PAID_AMOUNT``     | NUMBER     | Total paid amount   |
| ``AVG_PAID_AMOUNT``       | NUMBER     | Average paid amount |
| ``STATE``                 | VARCHAR    | Medicaid state      |
| ``PLACE_OF_SERVICE``      | VARCHAR    | POS code            |
| ``SPECIALTY``             | VARCHAR    | Provider specialty  |
```
---

## 🧾 License

This project is licensed under the [MIT License](LICENSE).

---
  
## 📬 Contact

For questions or collaboration, feel free to open an issue or reach out.

---

## ✍️ Author
© 2026 Mairilyn Yera Galindo | *Data-Strata Analytics Portfolio*
Healthcare Data Analytics | Snowflake + SQL Server + Power BI + Excel
🏖️ Boca Raton, FL
🌐 https://github.com/Data-Strata
📧 mairilynyera@gmail.com
💼 LinkedIn: www.linkedin.com/in/mairilyn-yera-galindo-07a93932
