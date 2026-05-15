# 📘 Medicaid Claims Analytics
Snowflake + Power BI | 238M‑row Healthcare Analytics Pipeline

## 📊 Data Sources

[![Medicaid Provider Spending](https://img.shields.io/badge/HHS%20Open%20Data-Medicaid%20Provider%20Spending-blue)](https://opendata.hhs.gov/datasets/medicaid-provider-spending/)
[![HCPCS Level II](https://img.shields.io/badge/CMS-HCPCS%20Level%20II-purple)](https://www.cms.gov/medicare/coding/hcpcs-release-code-sets)
[![NPI Registry](https://img.shields.io/badge/CMS-NPI%20Registry-green)](https://download.cms.gov/nppes/NPI_Files.html)

## 📘 Project Overview
Medicaid Claims Analytics is a full end‑to‑end healthcare analytics project that ingests, cleans, models, and visualizes large‑scale public healthcare datasets.
The solution integrates three federal sources:
- Medicaid Provider Spending (238M rows)
- HCPCS Level II (procedure metadata)
- NPPES NPI Registry (330‑column provider master file)

All data flows through a clean RAW → STAGE → MODEL → INTEGRITY → BI architecture built in Snowflake and visualized in Power BI.

## 🚀 Project Status
```markup
| Phase                         | Status          |
| ----------------------------- | --------------- |
| RAW ingestion (3 datasets)    | ✅ Complete    |
| STAGE layer (cleaned + typed) | ✅ Complete |
| MODEL layer (DIM + FACT)      | ✅ Complete |
| Provider Integrity Framework  | ✅ Complete |
| BI semantic model             | 🟨 In Progress |
| Power BI dashboard            | 🟨 In Progress |
| Analytics & insights          | 🔲 Planned |
```

## 📁 Project Structure & Documentation Index

The repository is organized into a clean, reproducible analytics workspace with all SQL, documentation, and modeling assets grouped by pipeline layer.


```code
medicaid_claims_analytics/
│
├── README.md
├── docs/
│   ├── 01_project_overview.md                    # Environment, repo, folder structure
│   ├── 02_dataset_description.md                 # Dataset fields, schema, metadata
│   ├── 03_snowflake_setup.md                     # Warehouses, DBs, schemas, roles
│   ├── 04_ingestion_medicaid.md                  # Medicaid ingestion pipeline (ZIP → RAW)
│   ├── 05_ingestion_hcpcs.md                     # HCPCS reference ingestion pipeline
│   ├── 06_ingestion_providers.md                 # NPI Registry ingestion pipeline
│   ├── 07_data_modeling.md                       # Star schema + DIM/FACT design + clustering
│   ├── 08_etl_pipeline.md                        # Pipeline orchestration + execution order
│   ├── 09_powerbi_dashboard.md                   # Dashboard design + DAX 
│   ├── 10_results_and_insights.md                # Findings + analytics summary
│   ├── 11_s2t_mapping.md                         # Source‑to‑Target lineage (updated with geographic standardization)
│   ├── 12_NPI_data_quality_analysis.md           # Technical appendix on unmatched NPI categories & anomaly tables|
│   ├── 13_geographic_standardization.md          # PRACTICE_STATE/MAILING_STATE cleanup + STATE_REF logic  
│   ├── 14_Medicaid_data_glossary.md              # Medicaid data glossary
│   ├── 15_date_and_service_dimensions.md         # DATE_DIM + SERVICE_CATEGORY_DIM documentation   
│   ├── 16_data_quality_incident.md               # data incident & integrity documentation 
│   ├── 17_provider_integrity_scorecard.md        # Executive-ready scorecard summarizing invalid NPI rates, legacy IDs, and provider integrity KPIs 
│   ├── 18_legacy_servicing_provider_registry.md  # Registry of A-/M-prefix and non‑NPI servicing IDs with categories and claim volume
│   ├── 19_dq_dashboard_spec                      # Power BI specification for DQ trend, anomaly detection, and provider integrity visuals
│   ├── 20_dq_anomaly_detection.md                # Documentation of 3‑sigma anomaly logic for invalid NPI spikes/drops
│   └── 21_model_data_dictionary.md               # Full data dictionary for all MODEL-layer tables
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
│   ├── provider_clean.sql                  # CLEAN table (22 analytics fields)
│   ├── provider_dimension.sql              # DIM_PROVIDER (deduplicated by NPI)
│   ├── provider_quality_checks.sql         # Row-count + duplicate validations
│   ├── provider_full_pipeline.sql          # End-to-end orchestration 
│   │
│   ├── ── Model ───────────────────   
│   ├── date_and_service_dimensions.sql     # Creates DATE_DIM and SERVICE_DIM for BI semantic modeling
│   ├── clean_provider_states.sql           # Standardizes PRACTICE_STATE and MAILING_STATE into U.S. state abbreviations (MODEL layer)
│   ├── legacy_servicing_provider_dim.sql   # MODEL table classifying non‑NPI servicing IDs into provider categories
│   ├── dq_invalid_npi_trend.sql            # Monthly trend table counting invalid NPIs across the dataset
│   ├── dq_invalid_npi_anomalies.sql        # Statistical anomaly detector identifying spikes/drops in invalid NPIs
│   │   
│   │   
│   ├── ── Data_Incident ───────────────────   
│   ├── isolatingoutliersfact_table.sql     # Isolating outliers from fact_table (STAGE layer)
│   └── removeoutliersfact_table.sql        # Remove outliers from fact_table (STAGE layer)
│
├── data/
│   └── README.md   # Dataset overview + source link
│
├── powerbi/
│   └── dashboard.pbix                 
│
└── assets/
    ├── architecture_diagram.png
    ├── ingestion_diagram.png
    ├── data_model.png
    └── dashboard_screenshots/            
```

## 🔗 Quick Links to Key Documentation

- **Data Modeling (Star Schema + Integrity Layer)**  
  `docs/07_data_modeling.md`

- **NPI Data Quality Analysis (Technical Appendix)**  
  `docs/12_NPI_data_quality_analysis.md`

- **Power BI Dashboard Specification**  
  `docs/09_powerbi_dashboard.md`

- **Source-to-Target Mapping**  
  `docs/11_s2t_mapping.md`

- **Provider Integrity Framework (Scorecard + Registry + Anomalies)**  
  `docs/17_provider_integrity_scorecard.md`  
  `docs/18_legacy_servicing_provider_registry.md`  
  `docs/21_dq_anomaly_detection.md`


## 🧭 Architecture Overview
A unified medallion‑style warehouse:
```code
RAW → STAGE → MODEL → INTEGRITY → POWER BI
```
RAW
- All source files stored as STRING
- Medicaid (11GB CSV), HCPCS, NPI Registry

STAGE
- Typed, cleaned, standardized tables
- Medicaid: 10 analytics fields
- NPI: 22 curated fields
- HCPCS: 6 analytics fields

MODEL
Star schema with:
- `FACT_MEDICAID_PROVIDER_SPENDING`
- `NPI_DIM`
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`
- Geographic standardization

INTEGRITY
- Provider Integrity Framework:
- Legacy Servicing Provider Dimension
- Invalid NPI Trend Table
- Anomaly Detector
- Scorecard inputs

BI
Power BI semantic model + dashboard pages.

## 🧰 Tech Stack & Tools

<p align="left">
  <img src="https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white" />
  <img src="https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" />
  <img src="https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" />
</p>

## 🧱 Pipeline Summary
Medicaid Pipeline
```code
RAW_MEDICAID.PUBLIC → STAGE_MEDICAID.CLEAN → ANALYTICS_MEDICAID.MODEL
```

NPI Pipeline
```code
NPI_RAW (330 cols) → NPI_CLEAN (22 cols) → NPI_DIM (1 row per NPI)
```

HCPCS Pipeline
```code
HCPCS_RAW_WIDE (48 cols) → HCPCS_CLEAN (6 cols) → HCPCS_DIM
```

All pipelines follow the same pattern:
`CREATE TABLE` (all STRING) → `COPY INTO` → `CLEAN` → `DIM/FACT`

For full ingestion and ETL details, see docs/08_etl_pipeline.md.


## 🟦 Provider Integrity Framework
A dedicated integrity layer that evaluates provider identifier quality across Medicaid claims.

Why it exists
Medicaid servicing providers often use non‑NPI identifiers:
- A‑prefix IDs
- M‑prefix IDs
- Legacy state provider IDs
- Fiscal agent identifiers
- Atypical providers (transportation, BH, HCBS)

These are valid in Medicaid but not valid NPIs.

Components
1. Legacy Servicing Provider Dimension
Classifies non‑NPI servicing identifiers into:
- Agency / Atypical
- County / Managed Care
- Other legacy IDs

Includes claim volume + service category patterns.

2. Invalid NPI Trend Table
Tracks invalid NPIs monthly (2018–2024).
Reveals:
- High malformed IDs in 2018–2019
- COVID utilization collapse in 2020
- Modernized NPI compliance from 2021 onward

3. Anomaly Detector
Flags spikes/drops using 3‑sigma thresholds.

4. Scorecard Inputs
Used to compute:
- Invalid NPI rate
- Billing vs servicing invalids
- Provider Integrity Score

5. Power BI Integration
Drives:
- Provider Integrity Scorecard
- Legacy ID Registry
- DQ Trend & Anomaly pages
- Provider Data Quality Explorer

## 🛡 Data Quality & Incident History
A historical data quality incident (2018 Medicaid file) is fully documented in  
`docs/16_data_quality_incident.md`.

Summary:
- Root cause: column‑shift corruption in the raw 2018 Medicaid file  
- Impact: misaligned NPIs, NULL HCPCS codes, trillion‑dollar TOTAL_PAID values  
- Affected layers: STAGE, FACT_MEDICAID, FACT_PROVIDER_MONTHLY, FACT_HCPCS_MONTHLY  
- Resolution: surgical cleanup + full rebuild of all 2018 fact tables  
- Preventive controls added: column alignment validation, NPI/HCPCS validation, reasonability checks, quarantine zone  

This incident is preserved as part of the project’s data quality governance and serves as a reference for future QA improvements.

## 🧱 MODEL Layer Summary
```code
| Table                               | Grain                                                 | Purpose                   |
| ----------------------------------- | ----------------------------------------------------- | ------------------------- |
| ``NPI_DIM``                         | 1 row per NPI                                         | Provider master dimension |
| ``HCPCS_DIM``                       | 1 row per HCPCS code                                  | Procedure metadata        |
| ``DATE_DIM``                        | 1 row per date                                        | Time intelligence         |
| ``SERVICE_CATEGORY_DIM``            | 1 row per category                                    | Clinical grouping         |
| ``FACT_MEDICAID_PROVIDER_SPENDING`` | 1 row per billing NPI + servicing NPI + HCPCS + month | Core fact table           |
```

### Geographic Standardization
NPI_DIM includes:
- PRACTICE_STATE_US
- MAILING_STATE_US
- PROVIDER_STATE_US (used in Power BI maps)

### 🔁 Dependency Diagram — Correct Refresh Order
```code
RAW → NPI_CLEAN → NPI_DIM → FACT_MEDICAID → Power BI
```
If NPI logic changes (names, DQ flags, display names, state cleanup),
FACT must be refreshed to avoid stale attributes.

## 🧊 Clustering Strategy (MODEL Layer)
```code
| Table                              | Cluster Key                                       | Rationale                      |
| ---------------------------------- | ------------------------------------------------- | ------------------------------ |
| ``NPI_DIM``                        | NPI                                               | High‑cardinality PK            |
| ``HCPCS_DIM``                      | HCPCS_CODE                                        | Fast lookups                   |
| ``FACT_MEDICAID_PROVIDER_SPENDING``| (CLAIM_MONTH, BILLING_PROVIDER_NPI)               | Time + provider pruning        |
```

## 🧠 BI Semantic Model (In Progress)
Relationships
> FACT → NPI_DIM (billing + servicing)
> FACT → HCPCS_DIM
> FACT → DATE_DIM
> FACT → SERVICE_CATEGORY_DIM
> FACT → LEGACY_SERVICING_PROVIDER_DIM (NEW)
> DATE_DIM → DQ Trend + Anomalies

Measures
+ Total Paid
+ Total Claims
+ Avg Paid per Claim
+ Invalid NPI Rate
+ Provider Integrity Score

Dashboard Pages
- Medicaid Spending Overview
- Provider Integrity Scorecard
- Legacy Servicing Provider Registry
- DQ Trend & Anomalies
- HCPCS Explorer
- Provider Detail

## 🛠️ Technologies Used

- **Snowflake** — Warehouse, Stages, Clustering, SQL
- **SnowSQL CLI** — COPY INTO and Orchestration
- **Power BI** — Semantic model + Dashboard
- **PowerShell / curl.exe**(file ingestion)
- **GitHub** — Version control & documentation

## 🎯 What This Project Demonstrates
- Real‑world ingestion of multi‑GB healthcare datasets
- Medallion architecture (RAW → STAGE → MODEL → INTEGRITY → BI)
- Provider enrichment using NPI Registry
- Clustering for performance at scale (238M rows)
- Data quality diagnostics + anomaly detection
- Executive‑ready analytics in Power BI
- Documentation‑driven engineering

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
