# 07 — Data Modeling (MODEL Layer)

The MODEL layer transforms CLEAN tables into analytics‑ready dimensional structures used by FACT tables and Power BI.  
This layer follows a dimensional modeling approach (Kimball‑style) and includes:

- Provider Dimension (`PROVIDER_DIM`)
- HCPCS Dimension (`HCPCS_DIM`)
- Date Dimension (`DATE_DIM`)
- Service Category Dimension (`SERVICE_CATEGORY_DIM`)
- Medicaid Spending Fact Table (`FACT_PROVIDER_SPENDING`)
- Geographic Standardization (PRACTICE_STATE_US, MAILING_STATE_US, PROVIDER_STATE_US)

All MODEL objects are built in a strict dependency order to ensure correct joins, complete enrichment, and BI‑ready semantics.

---

## 🟦 1. MODEL Layer Architecture

The MODEL layer sits between CLEAN and the Power BI semantic model:
```code
RAW → CLEAN → MODEL → SEMANTIC MODEL (Power BI)
```
The MODEL layer provides:
- Deduplicated, analytics‑ready dimensions  
- Standardized geographic fields  
- Calendar and service category dimensions  
- A fully enriched fact table ready for BI consumption
- Provider integrity monitoring tables
- Legacy servicing provider classification

This layer is read‑only relative to RAW/STAGE and optimized for BI consumption.  

---

## 🟦 2. MODEL Layer Inventory

🟦 2.1. Core Dimensions
> PROVIDER_DIM
Rows: ~9.5M
Size: ~427MB
Purpose:  
The authoritative provider dimension used for both billing and servicing providers.
Replaces the deprecated NPI_DIM.

Contains:
- NPI
- Provider Type (Individual / Organization)
- Full Name / Org Name
- Unified Provider Display Name
- PRACTICE_STATE_US / MAILING_STATE_US / PROVIDER_STATE_US
- Taxonomy
- Enumeration dates
- Data quality flags

> HCPCS_DIM
Rows: ~9.1K
Purpose:  
Procedure metadata used for clinical and utilization analytics.

> DATE_DIM
Rows: ~3.7K
Purpose:  
Calendar dimension used for all time intelligence.

> SERVICE_CATEGORY_DIM
Rows: 5
Purpose:  
Maps HCPCS patterns into OP / RX / OTHER categories.

> STATE_REF
Rows: 59
Purpose:  
Lookup table used by clean_provider_states.sql to standardize provider geography.

🟦 2.2 Fact Table
> FACT_MEDICAID_PROVIDER_SPENDING
Rows: ~238M
Size: ~3.2GB
Purpose:  
Primary analytics fact table.

🟦 2.3 Provider Integrity Tables
> UNKNOWN_PROVIDER_DIM
Rows: ~2.6K
Purpose:  
Captures malformed or non‑enumerated provider identifiers.
Used for integrity scoring and DQ dashboards.

> LEGACY_SERVICING_PROVIDER_DIM
(Not shown in screenshot but part of MODEL)  
Purpose:  
Classifies non‑NPI servicing IDs (A‑prefix, M‑prefix, alphanumeric).

🟦 2.4 Data Quality Monitoring Tables
> DQ_INVALID_NPI_TREND
Purpose:  
Monthly invalid NPI counts.

> DQ_INVALID_NPI_ANOMALIES
Purpose:  
3‑sigma anomaly detection for invalid NPI spikes/drops.

---

## 🟦 3. MODEL Execution Order (Summary)

The MODEL layer must be executed in a strict dependency order to ensure data integrity and correct Power BI behavior:

1. provider_build_dim()  
→ Builds PROVIDER_DIM (replaces NPI_DIM)

2. clean_provider_states.sql  
→ Standardizes PRACTICE_STATE_US, MAILING_STATE_US, PROVIDER_STATE_US

3. date_and_service_dimensions.sql  
→ Builds DATE_DIM + SERVICE_CATEGORY_DIM

4. fact_build_model()  
→ Builds FACT_MEDICAID_PROVIDER_SPENDING

5. Integrity Layer
- legacy_servicing_provider_dim.sql
- dq_invalid_npi_trend.sql
- dq_invalid_npi_anomalies.sql

6. Power BI Semantic Model  
→ Consumes FACT + DIMs + DQ tables

This ensures:
- All dimensions exist before FACT
- Integrity tables have access to FACT + DATE_DIM
- Power BI receives a complete, enriched MODEL layer 

## 🚀 ## 🚀 Dependency Diagram — Correct Refresh Order (Updated)

The MODEL layer follows a strict dependency chain to ensure that all dimensions, fact tables, and integrity monitoring tables are built in the correct order. This guarantees referential integrity, complete enrichment, and a BI‑ready semantic model.

The updated dependency flow is:

RAW → CLEAN → MODEL → SEMANTIC MODEL (Power BI)

```code
                ┌────────────────────────────────┐
                │   RAW_MEDICAID.NPI_RAW         │
                └──────────────┬─────────────────┘
                               │
                               ▼
                ┌────────────────────────────────┐
                │ STAGE.CLEAN.NPI_CLEAN          │
                │ (Name Cleaning + DQ Flags)     │
                └──────────────┬─────────────────┘
                               │
                               ▼
                ┌────────────────────────────────┐
                │  MODEL.PROVIDER_DIM            │
                │  (Authoritative Provider DIM)  │
                └──────────────┬─────────────────┘
                               │
                               ▼
                ┌────────────────────────────────┐
                │ MODEL.clean_provider_states    │
                │ (PRACTICE_STATE_US, etc.)      │
                └──────────────┬─────────────────┘
                               │
                               ▼
                ┌────────────────────────────────┐
                │ MODEL.DATE_DIM                 │
                │ MODEL.SERVICE_CATEGORY_DIM     │
                └──────────────┬─────────────────┘
                               │
                               ▼
                ┌────────────────────────────────┐
                │ MODEL.FACT_MEDICAID_PROVIDER_  │
                │          SPENDING              │
                │ (Joins to PROVIDER_DIM,        │
                │  HCPCS_DIM, DATE_DIM,          │
                │  SERVICE_CATEGORY_DIM)         │
                └──────────────┬─────────────────┘
                               │
                               ▼
        ┌──────────────────────────────┬──────────────────────────────┐
        │                              │                              │
        ▼                              ▼                              ▼

┌───────────────────────────┐   ┌───────────────────────────┐   ┌───────────────────────────┐
│ LEGACY_SERVICING_PROVIDER │   │ DQ_INVALID_NPI_TREND      │   │ DQ_INVALID_NPI_ANOMALIES   │
│ (Non‑NPI Servicing IDs)   │   │ (Monthly Invalid NPI)      │   │ (3‑Sigma Anomaly Flags)    │
└──────────────┬────────────┘   └──────────────┬────────────┘   └──────────────┬────────────┘
               │                               │                               │
               └───────────────────────────────┴───────────────────────────────┘
                                               │
                                               ▼
                ┌──────────────────────────────────────────────┐
                │        Power BI Semantic Model               │
                │  (FACT + DIMs + Integrity Tables)            │
                └──────────────────────────────────────────────┘

```

---

## 🟦 4. Star Schema Overview
---

## 📌 Primary & Foreign Key Relationships (Star Schema)
Although Snowflake does not enforce constraints, the MODEL layer defines them for lineage, BI modeling, and documentation clarity.

Primary Keys
| Table | Primary Key | Description |
| --- | --- | --- |
| ``PROVIDER_DIM`` | ``NPI`` | Authoritative provider identifier |
| ``HCPCS_DIM`` | ``HCPCS_CODE`` | Procedure code |
| ``DATE_DIM`` | ``DATE_KEY`` | Calendar key |
| ``SERVICE_CATEGORY_DIM`` | ``SERVICE_CATEGORY`` | OP/RX/OTHER |

FACT Grain
One row per:
- CLAIM_MONTH
- BILLING_PROVIDER_NPI
- SERVICING_PROVIDER_NPI
- HCPCS_CODE
- SERVICE_CATEGORY

Foreign Keys
| Fact Column | References | Purpose |
| --- | --- | --- |
| BILLING_PROVIDER_NPI | PROVIDER_DIM(NPI) | Billing provider enrichment |
| SERVICING_PROVIDER_NPI | PROVIDER_DIM(NPI) | Servicing provider enrichment |
| HCPCS_CODE | HCPCS_DIM(HCPCS_CODE) | Procedure metadata |
| CLAIM_MONTH | DATE_DIM(DATE_KEY) | Time intelligence |
| SERVICE_CATEGORY | SERVICE_CATEGORY_DIM | Category metadata |


```code
                   ┌───────────────────────────┐
                   │         DATE_DIM          │
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
│       PROVIDER_DIM        │                 │        HCPCS_DIM          │
│───────────────────────────│                 │───────────────────────────│
│ NPI (PK)                  │                 │ HCPCS_CODE (PK)           │
│ FULL_NAME                 │                 │ DESCRIPTION               │
│ ORG_NAME                  │                 │ SHORT_DESCRIPTION         │
│ PROVIDER_TYPE             │                 │ STATUS                    │
│ PRACTICE_STATE_US         │                 │                           │
│ MAILING_STATE_US          │                 │                           │
│ PROVIDER_STATE_US         │                 │                           │
│ (standardized via         │                 │                           │
│ clean_provider_states.sql)│                 │                           │
└──────────────┬────────────┘                 └──────────────┬────────────┘
               │                                             │
               │                                             │
               ▼                                             ▼

                   ┌──────────────────────────────────────────────┐
                   │   FACT_MEDICAID_PROVIDER_SPENDING            │
                   │──────────────────────────────────────────────│
                   │ CLAIM_MONTH (FK → DATE_DIM.DATE_KEY)         │
                   │ BILLING_PROVIDER_NPI (FK → PROVIDER_DIM)     │
                   │ SERVICING_PROVIDER_NPI (FK → PROVIDER_DIM)   │
                   │ HCPCS_CODE (FK → HCPCS_DIM)                  │
                   │ SERVICE_CATEGORY (FK → SERVICE_CATEGORY_DIM) │
                   │ TOTAL_CLAIM_LINES                            │
                   │ TOTAL_PAID                                   │
                   │ TOTAL_PATIENTS                               │
                   └──────────────┬───────────────────────────────┘
                                  │
                                  ▼

                   ┌───────────────────────────┐
                   │   SERVICE_CATEGORY_DIM    │
                   │───────────────────────────│
                   │ SERVICE_CATEGORY (PK)     │
                   │ DESCRIPTION               │
                   │ LOGIC (derived in MODEL   │
                   │ layer via HCPCS patterns) │
                   └───────────────────────────┘

```
---

## 🟦 5. Provider Dimension (PROVIDER_DIM)
PROVIDER_DIM is the authoritative provider dimension for all analytics.

It includes:
- NPI
- Provider Type (Individual / Organization)
- Full Name / Org Name
- Unified Provider Display Name
- PRACTICE_STATE_US / MAILING_STATE_US / PROVIDER_STATE_US
- Taxonomy
- Enumeration dates
- Data quality flags
   
This dimension replaces NPI_DIM entirely.

---

## 🟦 6. Geographic Standardization

Performed by:
```code
sql/model/clean_provider_states.sql
```
Outputs:
| Column                | Type    | Description                                              |
| --------------------- | ------- | -------------------------------------------------------- |
| ``PRACTICE_STATE_US`` | VARCHAR | Cleaned U.S. state extracted from PRACTICE_STATE         |
| ``MAILING_STATE_US``  | VARCHAR | Cleaned U.S. state extracted from MAILING_STATE          |
| ``PROVIDER_STATE_US`` | VARCHAR | Unified state field used for Power BI geographic visuals | (COALESCE of the two)

Used for:
- Power BI map visuals
- Provider integrity scoring
- Geographic drilldowns

---

## 🟦 7. HCPCS Dimension (HCPCS_DIM)

Created by:
```code
sql/hcpcs_dimension.sql
```
Includes:
- HCPCS_CODE
- DESCRIPTION
- SHORT_DESCRIPTION
- STATUS

---

## 🟦 8. Date & Service Category Dimensions

Created by:
```code
sql/model/date_and_service_dimensions.sql
```
DATE_DIM
Includes:
- DATE_KEY
- DATE
- YEAR / QUARTER / MONTH
- YEAR_MONTH

Sort fields for Power BI

SERVICE_CATEGORY_DIM
Maps HCPCS patterns into:
- OP
- RX
- OTHER

Used for slicers and category analytics.

---

## 🟦 9. Medicaid Spending Fact Table (FACT_PROVIDER_SPENDING)

Created by:
```code
sql/medicaid_fact_table.sql
```
Includes:
- Total Paid
- Total Claims
- Total Patients
- Derived service category
- Provider attributes (via PROVIDER_DIM)
- HCPCS attributes

This is the single source of truth for all Medicaid spend analytics.

## 9.1 🧊 When to Refresh FACT_MEDICAID
`FACT_MEDICAID` must be refreshed whenever changes are made to the provider dimension (NPI_DIM) that affect:
- provider names
- organization names
- FULL_NAME logic
- Provider_Display_Name
- Provider_Type
- Data_Quality_Flag
any other provider attributes used in analytics

📌 Why this matters
If `FACT_MEDICAID` is not refreshed after NPI updates, the semantic model will show:
- stale provider names
- mismatched display names
- incorrect data quality flags
- inconsistent joins
- mixed old/new provider attributes

Refreshing FACT ensures full alignment between fact and dimension tables.

👉For full column-level definitions, see `docs/21_model_data_dictionary.md`.

---

## 🧊 10. Clustering Strategy

Clustering keys are applied to all MODEL-layer tables to improve micro‑partition pruning, reduce scan cost, and optimize query performance across the Medicaid dataset.

| Table                             | Clustering Key                                   | Rationale |
|-----------------------------------|--------------------------------------------------|------------------------------------------------|
| `PROVIDER_DIM`                    | `CLUSTER BY (NPI)`                               | High-cardinality PK used in all provider joins |
| `HCPCS_DIM`                       | `CLUSTER BY (HCPCS_CODE)`                        | Fast lookups for procedure metadata |
| `FACT_MEDICAID_PROVIDER_SPENDING` | `CLUSTER BY (CLAIM_MONTH, BILLING_PROVIDER_NPI)` | Time-series filtering + provider-level rollups |

This strategy balances performance, cost, and maintainability for a 238M-row fact table and its supporting dimensions.

📌Clustering Strategy Details

PROVIDER_DIM
Cluster Key: NPI
Rationale:
- Primary join key for all provider enrichment in FACT
- Small, stable dimension (low churn, minimal reclustering cost)
- High‑cardinality warning is expected and harmless
   > Snowflake warns on high‑cardinality keys
   > But PROVIDER_DIM is small enough that clustering overhead is negligible
- Ensures fast provider lookups for both billing and servicing provider joins

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


---
## 🟦 11. Legacy Servicing Provider Dimension

`LEGACY_SERVICING_PROVIDER_DIM` classifies non‑NPI servicing provider identifiers found in Medicaid claims.  
These identifiers are valid within Medicaid systems but do not conform to the 10‑digit NPI format.

### Why this dimension exists

Many Medicaid servicing providers are **atypical** and are not required to obtain NPIs.  
These include:

- Transportation vendors  
- Behavioral health agencies  
- Case management providers  
- County social service departments  
- Home‑ and community‑based service providers  

These entities frequently use **state‑assigned identifiers**, such as:

- `A`‑prefix IDs (agency or atypical provider)  
- `M`‑prefix IDs (managed care, county, or municipal providers)  
- Short alphanumeric identifiers  
- Legacy state provider IDs  

These appear as “invalid NPIs” in raw claims but are legitimate Medicaid identifiers.

### How the dimension is built

Created by:

```code
sql/model/legacy_servicing_provider_dim.sql
```
This script:
- Extracts all servicing identifiers that are not valid NPIs
- Classifies them into provider categories
- Computes claim volume
- Captures sample service categories for context

Key Fields
+ `LEGACY_ID`
+ `PROVIDER_CATEGORY`
+ `CLAIM_VOLUME`
+ `SAMPLE_SERVICE_CATEGORY`

👉 Downstream Usage
This dimension supports:
- Provider Integrity Scorecard
- Legacy Servicing Provider Registry
- Program Integrity investigations
- Power BI drilldowns for atypical providers


## 🟦 12. Data Quality Trend Tables

The MODEL layer includes two data quality monitoring tables that track invalid NPIs over time and detect anomalies in provider identifier behavior.

These tables support the Provider Integrity Framework and Power BI DQ dashboards.

---

### 12.1 DQ_INVALID_NPI_TREND

This table tracks the **monthly count of invalid NPIs** across the Medicaid dataset.

Created by:

```code
sql/model/dq_invalid_npi_trend.sql
```
Purpose:
- Monitor long‑term improvements in NPI compliance
- Identify operational changes (e.g., COVID‑19 utilization collapse)
- Provide historical context for provider integrity

Key Fields:
+ `CLAIM_MONTH`
+ `INVALID_CLAIMS`

### 12.2 DQ_INVALID_NPI_ANOMALIES
A lightweight anomaly detector that flags spikes or drops in invalid NPIs using a 3‑sigma statistical threshold.

Created by:
```sql
sql/model/dq_invalid_npi_anomalies.sql
```
Purpose:
- Detect sudden increases in malformed identifiers
- Identify upstream ingestion or provider submission issues
- Support automated monitoring and alerting

Key Fields:
+ `CLAIM_MONTH`
+ `INVALID_CLAIMS`
+ `ANOMALY_STATUS (SPIKE, DROP, NORMAL)`

Why these tables matter
These trend and anomaly tables provide:
- Early detection of data quality issues
- Historical validation of provider identifier behavior
- Inputs for Power BI DQ dashboards
- Inputs for the Provider Integrity Scorecard

They ensure the MODEL layer remains trustworthy, explainable, and BI‑ready.

## 🟦 13. Provider Integrity Framework — Narrative Summary
The Provider Integrity Framework evaluates the quality, validity, and historical behavior of provider identifiers across the Medicaid dataset. It explains why invalid NPIs appear, how they affect claims, and how the MODEL layer resolves them through unified dimensions, legacy‑ID classification, and automated monitoring.

### 1. Overview
Medicaid claims contain both valid NPIs and legacy servicing identifiers.  
While billing NPIs are strictly validated by clearinghouses, servicing NPIs often represent atypical providers who are **not required** to have NPIs. These include:

- Transportation vendors  
- Behavioral health agencies  
- Case management providers  
- County social service departments  
- Home‑ and community‑based service providers  

These entities frequently use **state‑assigned identifiers** (A‑prefix, M‑prefix, alphanumeric IDs), which appear as “invalid NPIs” in raw claims.

### 2. Key Findings
- **Invalid NPI claims:** 0.03% of all claims (extremely low)  
- **Distinct invalid NPIs:** 2,592  
- **Invalid servicing IDs:** 1.28M claims (expected for atypical providers)  
- **Invalid billing IDs:** 76,186 claims (0.03%)  

### 3. Why Invalid Servicing IDs Exist
Atypical providers are not required to obtain NPIs.  
As a result, Medicaid systems allow:

- A‑prefix identifiers  
- M‑prefix identifiers  
- Short alphanumeric IDs  
- Legacy state provider IDs  

These identifiers are **valid within Medicaid**, but **not valid NPIs**.

### 4. Historical Trend (2018–2024)
- **2018–2019:** High malformed servicing IDs (≈40k/month)  
- **2020:** Sharp decline due to COVID utilization collapse  
- **2021–2024:** Modernized NPI compliance (≈250–400 invalid claims/month)  

This trend reflects real operational changes in Medicaid provider enumeration and service delivery.

### 5. How the MODEL Layer Resolves This
The MODEL layer integrates provider integrity through:

- **PROVIDER_DIM**  
  Unifies valid NPIs and invalid/legacy identifiers.

- **UNKNOWN_PROVIDER_DIM**  
  Isolates malformed or non‑enumerated identifiers.

- **LEGACY_SERVICING_PROVIDER_DIM**  
  Classifies A‑prefix, M‑prefix, and other legacy IDs into provider categories.

- **DQ_INVALID_NPI_TREND**  
  Tracks invalid NPIs over time.

- **DQ_INVALID_NPI_ANOMALIES**  
  Flags spikes or drops using statistical thresholds.

👉 6. Downstream Usage
Power BI uses these MODEL objects to deliver:
- Provider Integrity Scorecard  
- Legacy Servicing Provider Registry  
- Invalid NPI trend analysis  
- Anomaly detection  
- Provider data quality exploration  

This framework ensures Medicaid provider data is **accurate, explainable, and BI‑ready**, supporting both operational analytics and program integrity initiatives.


## 🟦 14. Power BI Semantic Model (Updated)

The Power BI semantic model consumes all MODEL‑layer dimensional objects and fact tables, including the new Provider Integrity components.  
This ensures that provider‑level analytics, data quality monitoring, and program integrity insights are fully integrated into the BI layer.

### 14.1 Required Tables

Power BI connects to the following MODEL objects:

- `FACT_MEDICAID_PROVIDER_SPENDING`
- `PROVIDER_DIM`
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`
- `LEGACY_SERVICING_PROVIDER_DIM` (New)
- `DQ_INVALID_NPI_TREND` (New)
- `DQ_INVALID_NPI_ANOMALIES` (New)

These tables support:

- Provider drilldowns  
- Geographic analysis  
- Service category exploration  
- Provider integrity scoring  
- Invalid NPI trend analysis  
- Anomaly detection  

---

### 14.2 Relationships

The semantic model includes the following relationships:

- `FACT_MEDICAID_PROVIDER_SPENDING.BILLING_PROVIDER_NPI` → `PROVIDER_DIM.NPI`
- `FACT_MEDICAID_PROVIDER_SPENDING.SERVICING_PROVIDER_NPI` → `PROVIDER_DIM.NPI`
- `FACT_MEDICAID_PROVIDER_SPENDING.SERVICING_PROVIDER_NPI` → `LEGACY_SERVICING_PROVIDER_DIM.LEGACY_ID` (New)
- `FACT_MEDICAID_PROVIDER_SPENDING.HCPCS_CODE` → `HCPCS_DIM.HCPCS_CODE`
- `FACT_MEDICAID_PROVIDER_SPENDING.CLAIM_MONTH` → `DATE_DIM.DATE`
- `DQ_INVALID_NPI_TREND.CLAIM_MONTH` → `DATE_DIM.DATE` (New)
- `DQ_INVALID_NPI_ANOMALIES.CLAIM_MONTH` → `DATE_DIM.DATE` (New)

This structure enables unified provider analytics across both valid NPIs and legacy servicing identifiers.

---

### 14.3 Measures (Updated)

The semantic model includes new measures to support provider integrity analysis:

- **Invalid NPI Rate**  
- **Billing Invalid Rate**  
- **Servicing Invalid Rate**  
- **Legacy ID Claim Volume**  
- **Provider Integrity Score**  
- **Invalid NPI Trend (Monthly)**  
- **Anomaly Status (Spike / Drop / Normal)**  

These measures power the Provider Integrity Scorecard and DQ dashboards.

---

### 14.4 Power BI Pages (Updated)

The dashboard includes the following pages:

1. **Provider Integrity Scorecard** (New)  
   - Invalid NPI rate  
   - Billing vs servicing invalids  
   - Provider Integrity Score  

2. **Legacy Servicing Provider Registry** (New)  
   - A‑prefix / M‑prefix identifiers  
   - Claim volume  
   - Service category patterns  

3. **DQ Trend & Anomalies** (New)  
   - Monthly invalid NPI trend  
   - Anomaly detection  
   - Year‑over‑year comparison  

4. **Provider Data Quality Explorer** (New)  
   - Drilldown by provider  
   - Drilldown by service category  
   - Drilldown by geography  

5. **Medicaid Spending Overview**  
   - Total paid  
   - Service category distribution  
   - Provider distribution  

6. **HCPCS Explorer**  
   - Code‑level drilldowns  
   - Service category mapping  

---

### 14.5 Why This Matters

Integrating Provider Integrity into the semantic model ensures:

- Full visibility into provider identifier quality  
- Accurate interpretation of atypical servicing providers  
- Early detection of data quality issues  
- Executive‑ready insights for program integrity  
- A unified, trustworthy BI experience  

The semantic model now reflects the complete lifecycle of provider data.

---
© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
