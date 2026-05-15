# 07 — Data Modeling (MODEL Layer)

The MODEL layer transforms CLEAN tables into analytics‑ready dimensional structures used by FACT tables and Power BI.  
This layer follows a dimensional modeling approach (Kimball‑style) and includes:

- Provider Dimension (`NPI_DIM`)
- HCPCS Dimension (`HCPCS_DIM`)
- Date Dimension (`DATE_DIM`)
- Service Category Dimension (`SERVICE_CATEGORY_DIM`)
- Medicaid Spending Fact Table (`FACT_PROVIDER_SPENDING`)
- Geographic Standardization (PRACTICE_STATE_US, MAILING_STATE_US, PROVIDER_STATE_US)

All MODEL objects are built in a strict dependency order to ensure correct joins and complete enrichment.

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

---

## 🟦 2. MODEL Execution Order (Summary)

The MODEL layer must be executed in a strict dependency order to ensure data integrity and correct Power BI behavior:

1. **NPI_DIM**  
2. **Geographic Standardization** (`clean_provider_states.sql`)  
3. **DATE_DIM + SERVICE_CATEGORY_DIM**  
4. **FACT_PROVIDER_SPENDING**  
5. **Integrity Layer**  
   - `legacy_servicing_provider_dim.sql`  
   - `dq_invalid_npi_trend.sql`  
   - `dq_invalid_npi_anomalies.sql`  
6. **Power BI Semantic Model**

This sequence ensures:
- All dimensions exist before the fact table  
- All integrity tables have access to FACT + DATE_DIM  
- Power BI receives a complete, enriched MODEL layer  

## 🚀 Dependency Diagram — Correct Refresh Order
Below is a clear, architecture‑accurate dependency diagram showing how the NPI pipelines flow into FACT_MEDICAID.
```code
                ┌──────────────────────────┐
                │   RAW_MEDICAID.NPI_RAW   │
                └──────────────┬───────────┘
                               │
                               ▼
                ┌──────────────────────────┐
                │   STAGE.CLEAN.NPI_CLEAN  │
                │  (Name Sanitization +    │
                │   Display Name + DQ Flag)│
                └──────────────┬───────────┘
                               │
                               ▼
                ┌──────────────────────────┐
                │     ANALYTICS.NPI_DIM    │
                │ (Provider Dimension)     │
                └──────────────┬───────────┘
                               │
                               ▼
                ┌──────────────────────────┐
                │   ANALYTICS.FACT_MEDICAID│
                │ (Joins to NPI_DIM via    │
                │  Billing/Servicing NPI)  │
                └──────────────┬───────────┘
                               │
                               ▼
                ┌──────────────────────────┐
                │ Power BI Semantic Model  │
                │  (Provider_Display_Name, │
                │   Provider_Type, DQ Flag)│
                └──────────────────────────┘

```

---


## 🟦 3. Star Schema Overview
---

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

```code
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
│ (standardized via         │                 │                           │
│clean_provider_states.sql) │                 │                           │
│                           │                 │                           │                    
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
                   │ LOGIC (derived in MODEL   │
                   │ layer via service category│ 
                   │ mapping rules)            │
                   │                           │ 
                   └───────────────────────────┘
```
---

## 🟦 4. Provider Dimension (NPI_DIM)

`NPI_DIM` is created by:
```code
sql/provider_dimension.sql
```
This dimension:

- Deduplicates NPI records  
- Extracts 22 analytics‑ready fields  
- Provides provider‑level attributes used across the fact table  

### Key Fields

- `NPI`
- `PROVIDER_NAME`
- `PROVIDER_TYPE`
- `PRACTICE_STATE`
- `MAILING_STATE`
- `PRIMARY_SPECIALTY`
- `ORGANIZATION_NAME`

---

## 🟦 5. Geographic Standardization

After `NPI_DIM` is built, geographic cleanup is performed by:
```code
sql/model/clean_provider_states.sql
```
This script:

- Creates a `STATE_REF` lookup table (50 states + 5 territories + DC + military codes)
- Normalizes PRACTICE_STATE and MAILING_STATE using `TRIM(UPPER(...))`
- Maps values to standardized 2‑letter codes
- Produces:

| Column                | Type    | Description                                              |
| --------------------- | ------- | -------------------------------------------------------- |
| ``PRACTICE_STATE_US`` | VARCHAR | Cleaned U.S. state extracted from PRACTICE_STATE         |
| ``MAILING_STATE_US``  | VARCHAR | Cleaned U.S. state extracted from MAILING_STATE          |
| ``PROVIDER_STATE_US`` | VARCHAR | Unified state field used for Power BI geographic visuals | (COALESCE of the two)

### Why this step exists

Power BI geographic visuals require:

- Clean, standardized state codes  
- No NULLs  
- No ambiguous values (e.g., “ST THOMAS VI”, “P RICO”, “USVI”)  

This step ensures all provider locations are BI‑ready.

---

## 🟦 6. HCPCS Dimension (HCPCS_DIM)

Created by:
```code
sql/hcpcs_dimension.sql
```

This dimension:

- Deduplicates HCPCS codes  
- Provides descriptions and service categories  
- Supports fact table enrichment  

### Key Fields

- `HCPCS_CODE`
- `HCPCS_DESCRIPTION`
- `SERVICE_CATEGORY`

---

## 🟦 7. Date & Service Category Dimensions (Updated)

Created by:
```code
sql/model/date_and_service_dimensions.sql
```

These dimensions are part of the MODEL layer and must exist **before** the fact table is built.

### DATE_DIM

A full calendar dimension including:

- `DATE_KEY`
- `DATE`
- `YEAR`
- `MONTH`
- `QUARTER`
- `DAY_OF_WEEK`
- `IS_WEEKEND`

### SERVICE_CATEGORY_DIM

Maps HCPCS codes into high‑level service groups used for:

- Power BI slicers  
- Aggregations  
- Clinical category analysis  

---

## 🟦 8. Medicaid Spending Fact Table (FACT_PROVIDER_SPENDING)

Created by:
```code
sql/medicaid_fact_table.sql
```

This fact table joins to:

- `NPI_DIM`
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`

### Key Measures

- `TOTAL_PAYMENT`
- `SERVICE_COUNT`
- `AVERAGE_PAYMENT`
- `BENEFICIARY_COUNT`

### Why it must run last

FACT_MODEL depends on:

- Clean provider states  
- Date dimension  
- Service category dimension  
- Provider dimension  
- HCPCS dimension  

Running it earlier would produce NULL enrichment fields.

## 8.1 🧊 When to Refresh FACT_MEDICAID
`FACT_MEDICAID` must be refreshed whenever changes are made to the provider dimension (NPI_DIM) that affect:
- provider names
- organization names
- FULL_NAME logic
- Provider_Display_Name
- Provider_Type
- Data_Quality_Flag
any other provider attributes used in analytics

Although `FACT_MEDICAID` stores only foreign keys to `NPI_DIM` (e.g., `BILLING_PROVIDER_NPI`, `SERVICING_PROVIDER_NPI`), the meaning of those keys depends entirely on the dimension.

You must refresh `FACT_MEDICAID` when:
- NPI_CLEAN logic changes
- Name cleaning rules are updated
- Provider_Display_Name logic changes
- Provider_Type logic changes
- Data_Quality_Flag is added or modified
- NPI_DIM is rebuilt

You do NOT need to refresh `FACT_MEDICAID` when:
- RAW Medicaid claims are unchanged
- HCPCS or other unrelated dimensions are updated
- Only ZIP or address cleaning changes in `NPI_CLEAN` (unless used in FACT)

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

## 🧊 9. Clustering Strategy

Clustering keys are applied to all MODEL-layer tables to improve micro‑partition pruning, reduce scan cost, and optimize query performance across the Medicaid dataset.

| Table                             | Clustering Key                                   | Rationale |
|-----------------------------------|--------------------------------------------------|-----------|
| `NPI_DIM`                         | `CLUSTER BY (NPI)`                               | High-cardinality PK used in all provider joins |
| `HCPCS_DIM`                       | `CLUSTER BY (HCPCS_CODE)`                        | Fast lookups for procedure metadata |
| `FACT_MEDICAID_PROVIDER_SPENDING` | `CLUSTER BY (CLAIM_MONTH, BILLING_PROVIDER_NPI)` | Time-series filtering + provider-level rollups |

This strategy balances performance, cost, and maintainability for a 238M-row fact table and its supporting dimensions.

📌Clustering Strategy Details

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


---
## 🟦 10. Legacy Servicing Provider Dimension

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


## 🟦 11. Data Quality Trend Tables

The MODEL layer includes two data quality monitoring tables that track invalid NPIs over time and detect anomalies in provider identifier behavior.

These tables support the Provider Integrity Framework and Power BI DQ dashboards.

---

### 11.1 DQ_INVALID_NPI_TREND

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

### 11.2 DQ_INVALID_NPI_ANOMALIES
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

## 🟦 12. Provider Integrity Framework — Narrative Summary
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


## 🟦 13. Power BI Semantic Model (Updated)

The Power BI semantic model consumes all MODEL‑layer dimensional objects and fact tables, including the new Provider Integrity components.  
This ensures that provider‑level analytics, data quality monitoring, and program integrity insights are fully integrated into the BI layer.

### 13.1 Required Tables

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

### 13.2 Relationships

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

### 13.3 Measures (Updated)

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

### 13.4 Power BI Pages (Updated)

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

### 13.5 Why This Matters

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
