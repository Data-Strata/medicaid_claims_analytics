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

## 🟦 2. MODEL Layer Execution Order (Authoritative)

The MODEL layer must be executed in the following order:
 1. provider_build_dim()              → builds NPI_DIM
 2. clean_provider_states.sql         → geographic standardization
 3. date_and_service_dimensions.sql   → builds DATE_DIM + SERVICE_CATEGORY_DIM
 4. fact_build_model()                → builds FACT_PROVIDER_SPENDING


### Why this order matters

- **NPI_DIM must exist** before geographic cleanup can run  
- **Geographic cleanup must run** before FACT_MODEL uses PROVIDER_STATE_US  
- **DATE_DIM and SERVICE_CATEGORY_DIM must exist** before FACT_MODEL joins to them  
- **FACT_MODEL must run last** because it depends on all dimensions  

---


## 🟦 3. Star Schema Overview
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
- Extracts 19 analytics‑ready fields  
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

## 🟦 4. Geographic Standardization (Updated)

After `NPI_DIM` is built, geographic cleanup is performed by:
```code
sql/model/clean_provider_states.sql
```
This script:

- Creates a `STATE_REF` lookup table (50 states + 5 territories + DC + military codes)
- Normalizes PRACTICE_STATE and MAILING_STATE using `TRIM(UPPER(...))`
- Maps values to standardized 2‑letter codes
- Produces:

  - `PRACTICE_STATE_US`
  - `MAILING_STATE_US`
  - `PROVIDER_STATE_US` (COALESCE of the two)

### Why this step exists

Power BI geographic visuals require:

- Clean, standardized state codes  
- No NULLs  
- No ambiguous values (e.g., “ST THOMAS VI”, “P RICO”, “USVI”)  

This step ensures all provider locations are BI‑ready.

---

## 🟦 5. HCPCS Dimension (HCPCS_DIM)

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

## 🟦 6. Date & Service Category Dimensions (Updated)

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

## 🟦 7. Medicaid Spending Fact Table (FACT_PROVIDER_SPENDING)

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

---

## 🟦 8. Power BI Semantic Model

After the MODEL layer is complete, Power BI connects to:

- `FACT_PROVIDER_SPENDING`
- `NPI_DIM`
- `HCPCS_DIM`
- `DATE_DIM`
- `SERVICE_CATEGORY_DIM`

This enables:

- Geographic visuals  
- Provider‑level drilldowns  
- Service category analysis  
- Time‑series reporting  

---

## 🟦 9. Summary

The MODEL layer is the backbone of the analytics pipeline.  
It ensures:

- Clean, standardized provider data  
- Complete dimensional enrichment  
- Accurate fact table joins  
- BI‑ready structures  

Correct execution order is essential for data integrity and Power BI performance.

NPI_DIM
→ Geographic Standardization
→ DATE_DIM + SERVICE_CATEGORY_DIM
→ FACT_PROVIDER_SPENDING
→ Power BI

## Downstream Usage
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

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL Server | Power BI
