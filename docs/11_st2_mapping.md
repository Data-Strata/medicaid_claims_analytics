# 📄 Source-to-Target Mapping (S2T)
**Medicaid Claims Analytics — Snowflake Data Warehouse**

---

## 📋 Document Overview

This document defines the **Source-to-Target (S2T) mapping** for the Medicaid Claims Analytics project. 
It describes how fields flow from:

```
RAW → STAGE → MODEL (DIM + FACT)
```
across the three datasets used in this project:

- **Medicaid Provider Spending** (HHS Open Data)
- **HCPCS Level II Reference** (CMS)
- **NPI Registry** (NPPES, CMS)

The S2T mapping is the **contract between ingestion and analytics**. 
It documents lineage, transformations, business rules, and grain definitions. 
This document ensures traceability, auditability, and reproducibility — core requirements in Medicaid and Enterprise Data Systems (EDS) environments.

---

## 🧱 1. Architecture Overview

### Three-Layer Architecture

The pipeline ingests three source datasets into Snowflake and transforms them through a three-layer architecture:

#### RAW Layer
- **Purpose**: Unmodified source files
- **Schema**: All columns as `STRING`/`VARCHAR`
- **Databases**: `RAW_MEDICAID`
- **Tables**: 
  - `MEDICAID_PROVIDER_SPENDING_RAW`
  - `HCPCS_RAW_WIDE`
  - `NPI_RAW`

#### STAGE Layer (CLEAN)
- **Purpose**: Cleaned, typed, standardized tables
- **Databases**: `STAGE_MEDICAID.CLEAN`
- **Transformations Applied**:
  - `TRY_TO_NUMBER()` for numeric fields
  - `TRY_TO_DATE()` for date fields
  - `TRIM()` and `UPPER()` for string normalization
  - Code standardization (NPI padding, HCPCS uppercase)
  - ZIP code normalization (5-digit extraction)
- **Tables**:
  - `MEDICAID_PROVIDER_SPENDING_STAGE`
  - `HCPCS_CLEAN`
  - `NPI_CLEAN`

#### MODEL Layer (ANALYTICS)
- **Purpose**: Curated DIM and FACT tables for Power BI
- **Database**: `ANALYTICS_MEDICAID.MODEL`
- **Tables**:
  - `NPI_DIM` (Provider dimension)
  - `HCPCS_DIM` (Procedure dimension)
  - `DATE_DIM` (Calendar dimension)
  - `SERVICE_CATEGORY_DIM` (Service type dimension)
  - `STATE_REF` (Geographic reference)
  - `FACT_MEDICAID_PROVIDER_SPENDING` (Core analytical fact)

---

## 🧩 2. Grain Definitions

### NPI_DIM
- **Grain**: 1 row per unique NPI
- **Purpose**: Provider master dimension
- **Deduplication Logic**: `ROW_NUMBER()` partitioned by `NPI`, ordered by `LAST_UPDATE_DATE DESC`, `ENUMERATION_DATE DESC`, `NPI DESC`
- **Primary Key**: `NPI`

### HCPCS_DIM
- **Grain**: 1 row per HCPCS code
- **Purpose**: Procedure metadata and service categorization
- **Deduplication Logic**: `ROW_NUMBER()` partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC`
- **Primary Key**: `HCPCS_CODE`

### DATE_DIM
- **Grain**: 1 row per calendar date (2018-2027, 10 years)
- **Purpose**: Supports time intelligence and trending
- **Primary Key**: `DATE_KEY`

### SERVICE_CATEGORY_DIM
- **Grain**: 1 row per service category
- **Purpose**: High-level clinical service grouping
- **Categories**: ED (Emergency Department), IP (Inpatient), OP (Outpatient), RX (Pharmacy)
- **Primary Key**: `CATEGORY_KEY`

### FACT_MEDICAID_PROVIDER_SPENDING
- **Grain**: 1 row per `BILLING_PROVIDER_NPI` + `SERVICING_PROVIDER_NPI` + `HCPCS_CODE` + `CLAIM_MONTH`
- **Purpose**: Core analytical fact table for spending analytics
- **Clustering**: `(CLAIM_MONTH, BILLING_PROVIDER_NPI)`

---

## 📘 3. S2T Mapping — NPI_DIM

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.NPI_RAW` (330 columns)
- **STAGE**: `STAGE_MEDICAID.CLEAN.NPI_CLEAN` (19 columns)
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.NPI_DIM` (22 columns after geographic standardization)

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `NPI` | `NPI` | `LPAD(TRIM(NPI), 10, '0')` — ensures 10-digit format |
| `ENTITY_TYPE_CODE` | `ENTITY_TYPE_CODE` | `TRIM()` |
| `REPLACEMENT_NPI` | `REPLACEMENT_NPI` | `TRIM()` |
| `ORG_NAME` | `PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME` | `TRIM()` |
| `LAST_NAME` | `PROVIDER_LAST_NAME_LEGAL_NAME` | `TRIM()` |
| `FIRST_NAME` | `PROVIDER_FIRST_NAME` | `TRIM()` |
| `MIDDLE_NAME` | `PROVIDER_MIDDLE_NAME` | `TRIM()` |
| `CREDENTIALS` | `PROVIDER_CREDENTIAL_TEXT` | `TRIM()` |
| ``FULL_NAME`` | `Derived |`TRIM(CONCAT(FIRST_NAME, CASE WHEN MIDDLE_NAME IS NOT NULL THEN` `| |MIDDLE_NAME ELSE ` ` END, CASE WHEN LAST_NAME IS NOT NULL THEN ` `| | LAST_NAME ELSE ` ` END))|
| `MAILING_CITY` | `PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME` | `TRIM()` |
| `MAILING_STATE` | `PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME` | `TRIM()` |
| `MAILING_ZIP` | `PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE` | `SUBSTR(zip, 1, 5)` if matches `^[0-9]{5,9}$`, else `NULL` |
| `PRACTICE_CITY` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME` | `TRIM()` |
| `PRACTICE_STATE` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME` | `TRIM()` |
| `PRACTICE_ZIP` | `PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE` | `SUBSTR(zip, 1, 5)` if matches `^[0-9]{5,9}$`, else `NULL` |
| `ENUMERATION_DATE` | `PROVIDER_ENUMERATION_DATE` | `TRY_TO_DATE()` |
| `LAST_UPDATE_DATE` | `LAST_UPDATE_DATE` | `TRY_TO_DATE()` |
| `GENDER` | `PROVIDER_SEX_CODE` | `TRIM()` |
| `PRIMARY_TAXONOMY_CODE` | `HEALTHCARE_PROVIDER_TAXONOMY_CODE_1` | `TRIM()` — first taxonomy code from RAW |

### Field Mappings: STAGE → MODEL

| Target Column (MODEL) | Source Column (STAGE) | Transformation Logic |
|----------------------|---------------------|----------------------|
| All STAGE columns | `NPI_CLEAN` | Direct load with deduplication via `ROW_NUMBER()` |
| `PRACTICE_STATE_US` | `PRACTICE_STATE` | **Added in MODEL layer** — lookup via `STATE_REF`, normalized to 2-letter U.S. abbreviation |
| `MAILING_STATE_US` | `MAILING_STATE` | **Added in MODEL layer** — lookup via `STATE_REF`, normalized to 2-letter U.S. abbreviation |
| `PROVIDER_STATE_US` | Derived | **Added in MODEL layer** — `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` |
| ``Provider_Display_Name`` | ``FULL_NAME``, ``ORG_NAME`` | **Semantic model rule:** ``FULL_NAME ``→ ``ORG_NAME ``→ ``"Unknown ``Organization"`` |
| ``Data_Quality_Flag`` | Derived | ``'NAME_MISSING_ORG'`` when ``FULL_NAME`` and ``ORG_NAME`` are NULL; else ``'VALID'`` |

### Geographic Standardization (MODEL Layer)

The raw NPI Registry fields (`PRACTICE_STATE`, `MAILING_STATE`) contain global location values including countries, provinces, APO/FPO codes, ZIP codes, and mixed formats. To support reliable U.S. state-level analytics, the MODEL layer applies a standardization process.

#### New Fields Created in MODEL Layer

| Field | Source Logic | Purpose |
|-------|-------------|---------|
| `PRACTICE_STATE_US` | Extract valid U.S. state abbreviation using `STATE_REF` lookup table | Standardizes practice location to valid U.S. states/territories only |
| `MAILING_STATE_US` | Extract valid U.S. state abbreviation using `STATE_REF` lookup table | Standardizes mailing location to valid U.S. states/territories only |
| `PROVIDER_STATE_US` | `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` | Unified state field used by Power BI for geographic visuals |

#### Transformation Process

1. **Create Reference Table**: `STATE_REF` containing:
   - 50 U.S. states
   - 5 U.S. territories (PR, VI, GU, AS, MP)
   - District of Columbia (DC)
   - Military codes (AE, AA, AP)
   - Both state abbreviations and full names

2. **Standardization Logic**:
   ```sql
   UPDATE NPI_DIM n
   SET PRACTICE_STATE_US = s.STATE_ABBR
   FROM STATE_REF s
   WHERE TRIM(UPPER(n.PRACTICE_STATE)) IN (s.STATE_ABBR, s.STATE_NAME);
   ```

3. **Excluded Values**: Non-U.S. values ignored (e.g., "ONTARIO", "TOKYO", "ABU DHABI", "UNKNOWN", "APO AE")

4. **Final Unification**: `PROVIDER_STATE_US` provides single, analytics-ready state field

#### Why Geographic Standardization Matters

- Ensures accurate state-level rollups
- Enables Filled Map visuals in Power BI
- Removes global noise from foreign addresses
- Improves BI model reliability and reproducibility
- Supports executive-level reporting and geographic insights

#### SQL Reference
`/sql/model/clean_provider_states.sql`

---

## 📘 4. S2T Mapping — HCPCS_DIM

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.HCPCS_RAW_WIDE` (48 columns)
- **STAGE**: `STAGE_MEDICAID.PUBLIC.HCPCS_CLEAN` (6 columns)
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.HCPCS_DIM` (6 columns)

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `HCPCS_CODE` | `HCPC` | `UPPER(TRIM(HCPC))` |
| `DESCRIPTION` | `LONG_DESCRIPTION` | `TRIM()` |
| `SHORT_DESCRIPTION` | `SHORT_DESCRIPTION` | `TRIM()` |
| `STATUS` | `ACTION_CD` | `TRIM()` |
| `EFFECTIVE_DATE` | `ACT_EFF_DT` | `TRY_TO_DATE()` |
| `TERMINATION_DATE` | `TERM_DT` | `TRY_TO_DATE()` |

**Filter Applied**: `WHERE HCPC IS NOT NULL`

### Field Mappings: STAGE → MODEL

| Target Column (MODEL) | Source Column (STAGE) | Transformation Logic |
|----------------------|---------------------|----------------------|
| All STAGE columns | `HCPCS_CLEAN` | Direct load with deduplication via `ROW_NUMBER()` partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC` |

---

## 📘 5. S2T Mapping — FACT_MEDICAID_PROVIDER_SPENDING

### Source Tables
- **RAW**: `RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW`
- **STAGE**: `STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE`
- **MODEL**: `ANALYTICS_MEDICAID.MODEL.FACT_MEDICAID_PROVIDER_SPENDING`

### Field Mappings: RAW → STAGE

| Target Column (STAGE) | Source Column (RAW) | Transformation Logic |
|----------------------|---------------------|----------------------|
| `BILLING_PROVIDER_NPI` | `BILLING_PROVIDER_NPI_NUM` | `LPAD(TRIM(value), 10, '0')` — standardize to 10-digit format |
| `SERVICING_PROVIDER_NPI` | `SERVICING_PROVIDER_NPI_NUM` | `LPAD(TRIM(value), 10, '0')` — standardize to 10-digit format |
| `HCPCS_CODE` | `HCPCS_CODE` | `UPPER(TRIM())` |
| `CLAIM_MONTH` | `CLAIM_FROM_MONTH` | `TRY_TO_DATE(CLAIM_FROM_MONTH || '-01')` — convert to first day of month |
| `TOTAL_PATIENTS` | `TOTAL_PATIENTS` | `TRY_TO_NUMBER()` |
| `TOTAL_CLAIM_LINES` | `TOTAL_CLAIM_LINES` | `TRY_TO_NUMBER()` |
| `TOTAL_PAID` | `TOTAL_PAID` | `TRY_TO_NUMBER()` |

### Field Mappings: STAGE → MODEL (FACT Table)

| Target Column (FACT) | Source | Transformation Logic |
|---------------------|--------|----------------------|
| `BILLING_PROVIDER_NPI` | `MEDICAID_PROVIDER_SPENDING_STAGE.BILLING_PROVIDER_NPI` | Direct load |
| `SERVICING_PROVIDER_NPI` | `MEDICAID_PROVIDER_SPENDING_STAGE.SERVICING_PROVIDER_NPI` | Direct load |
| `HCPCS_CODE` | `MEDICAID_PROVIDER_SPENDING_STAGE.HCPCS_CODE` | Direct load |
| `CLAIM_MONTH` | `MEDICAID_PROVIDER_SPENDING_STAGE.CLAIM_MONTH` | Direct load |
| `TOTAL_PATIENTS` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_PATIENTS` | Direct load |
| `TOTAL_CLAIM_LINES` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_CLAIM_LINES` | Direct load |
| `TOTAL_PAID` | `MEDICAID_PROVIDER_SPENDING_STAGE.TOTAL_PAID` | Direct load |
| `SERVICE_CATEGORY` | `HCPCS_CODE` | **Derived field** — CASE logic based on HCPCS patterns |
| `BILLING_PROVIDER_STATE` | `NPI_DIM.PRACTICE_STATE` (via `BILLING_PROVIDER_NPI`) | LEFT JOIN enrichment |
| `SERVICING_PROVIDER_STATE` | `NPI_DIM.PRACTICE_STATE` (via `SERVICING_PROVIDER_NPI`) | LEFT JOIN enrichment |
| `HCPCS_DESCRIPTION` | `HCPCS_DIM.DESCRIPTION` (via `HCPCS_CODE`) | LEFT JOIN enrichment |
| `HCPCS_SHORT_DESCRIPTION` | `HCPCS_DIM.SHORT_DESCRIPTION` (via `HCPCS_CODE`) | LEFT JOIN enrichment |
| `HCPCS_STATUS` | `HCPCS_DIM.STATUS` (via `HCPCS_CODE`) | LEFT JOIN enrichment |

### SERVICE_CATEGORY Derivation Logic

```sql
CASE
    WHEN HCPCS_CODE LIKE 'J%' THEN 'RX'
    WHEN HCPCS_CODE LIKE 'A0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'G0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'H0%' THEN 'OP'
    WHEN HCPCS_CODE LIKE 'T%' THEN 'OP'
    ELSE 'OTHER'
END
```

---

## 📘 6. S2T Mapping — DATE_DIM

### Source
- **Generated in MODEL layer** — no source table
- **Generation Logic**: `GENERATOR(ROWCOUNT => 3650)` producing 10 years of dates (2018-2027)

### Field Mappings

| Target Column | Source | Transformation Logic |
|--------------|--------|----------------------|
| `DATE_KEY` | Generated date | `full_date` — serves as both surrogate key and natural key |
| `YEAR` | Generated date | `YEAR(full_date)` |
| `MONTH` | Generated date | `MONTH(full_date)` |
| `DAY` | Generated date | `DAY(full_date)` |
| `YEAR_MONTH` | Generated date | `TO_VARCHAR(full_date, 'YYYY-MM')` — BI-friendly format |
| `QUARTER` | Generated date | `QUARTER(full_date)` |
| `DAY_OF_WEEK` | Generated date | `DAYOFWEEK(full_date)` |
| `WEEK_OF_YEAR` | Generated date | `WEEKOFYEAR(full_date)` |
| `WEEKDAY_FLAG` | Generated date | `CASE WHEN DAYOFWEEK(full_date) IN (6,7) THEN 'Weekend' ELSE 'Weekday' END` |

### Purpose
- Supports Power BI time intelligence (YTD, MTD, rolling 12 months)
- Enables year-over-year comparisons
- Provides calendar attributes for filtering and grouping

---

## 📘 7. S2T Mapping — SERVICE_CATEGORY_DIM

### Source
- **Hardcoded values in MODEL layer** — no source table

### Field Mappings

| Target Column | Source | Value |
|--------------|--------|-------|
| `CATEGORY_KEY` | Hardcoded | 1, 2, 3, 4 |
| `SERVICE_CATEGORY` | Hardcoded | 'ED', 'IP', 'OP', 'RX' |
| `DESCRIPTION` | Hardcoded | 'Emergency Department', 'Inpatient', 'Outpatient', 'Pharmacy' |

### HCPCS-to-Category Mapping Logic

| SERVICE_CATEGORY | HCPCS Pattern | Description |
|------------------|---------------|-------------|
| `RX` | `J%` | Pharmacy/Drug codes |
| `OP` | `A0%`, `G0%`, `H0%`, `T%` | Outpatient services |
| `OTHER` | All other patterns | Uncategorized |

**Note**: ED and IP categories are defined in dimension but not currently mapped in FACT table SERVICE_CATEGORY derivation logic.

---

## 🔗 8. Join Relationships

### Star Schema Relationships

```
DATE_DIM (DATE_KEY)
    ← FACT_MEDICAID_PROVIDER_SPENDING (CLAIM_MONTH)

NPI_DIM (NPI)
    ← FACT_MEDICAID_PROVIDER_SPENDING (BILLING_PROVIDER_NPI)
    ← FACT_MEDICAID_PROVIDER_SPENDING (SERVICING_PROVIDER_NPI)

HCPCS_DIM (HCPCS_CODE)
    ← FACT_MEDICAID_PROVIDER_SPENDING (HCPCS_CODE)

SERVICE_CATEGORY_DIM (SERVICE_CATEGORY)
    ← FACT_MEDICAID_PROVIDER_SPENDING (SERVICE_CATEGORY)
```

### Foreign Key Constraints (Documentation Only)

| FACT Column | References | Cardinality | Join Type |
|-------------|-----------|-------------|-----------|
| `BILLING_PROVIDER_NPI` | `NPI_DIM(NPI)` | Many-to-One | LEFT JOIN |
| `SERVICING_PROVIDER_NPI` | `NPI_DIM(NPI)` | Many-to-One | LEFT JOIN |
| `HCPCS_CODE` | `HCPCS_DIM(HCPCS_CODE)` | Many-to-One | LEFT JOIN |
| `CLAIM_MONTH` | `DATE_DIM(DATE_KEY)` | Many-to-One | JOIN |
| `SERVICE_CATEGORY` | `SERVICE_CATEGORY_DIM(SERVICE_CATEGORY)` | Many-to-One | JOIN |

---

## 🧮 9. Transformation Logic Summary

### Direct Loads
- NPI → `NPI_DIM`
- HCPCS → `HCPCS_DIM`
- Medicaid Claims → `FACT_MEDICAID_PROVIDER_SPENDING`

### Type Casting
- `TRY_TO_NUMBER()` — all numeric fields
- `TRY_TO_DATE()` — all date fields
- `LPAD(field, 10, '0')` — NPI standardization
- `UPPER(TRIM())` — HCPCS codes
- `SUBSTR(zip, 1, 5)` — ZIP code normalization

### Derived Fields

| Derived Field | Source Fields | Logic |
|---------------|---------------|-------|
| `FULL_NAME` | `FIRST_NAME`, `MIDDLE_NAME`, `LAST_NAME` | `CONCAT_WS(' ', FIRST_NAME, MIDDLE_NAME, LAST_NAME)` |
| `CLAIM_MONTH` | `CLAIM_FROM_MONTH` | `TRY_TO_DATE(value || '-01')` |
| `SERVICE_CATEGORY` | `HCPCS_CODE` | CASE statement pattern matching |
| `PRACTICE_STATE_US` | `PRACTICE_STATE` | `STATE_REF` lookup via JOIN |
| `MAILING_STATE_US` | `MAILING_STATE` | `STATE_REF` lookup via JOIN |
| `PROVIDER_STATE_US` | `PRACTICE_STATE_US`, `MAILING_STATE_US` | `COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)` |
| `YEAR_MONTH` | `DATE_KEY` | `TO_VARCHAR(full_date, 'YYYY-MM')` |
| `WEEKDAY_FLAG` | `DATE_KEY` | `CASE WHEN DAYOFWEEK IN (6,7) THEN 'Weekend' ELSE 'Weekday' END` |

### Business Rules

1. **Deduplication**:
   - `NPI_DIM`: Partitioned by `NPI`, ordered by `LAST_UPDATE_DATE DESC`
   - `HCPCS_DIM`: Partitioned by `HCPCS_CODE`, ordered by `EFFECTIVE_DATE DESC`

2. **Field Reduction**:
   - NPI: 330 columns → 19 columns (STAGE) → 22 columns (MODEL with geographic fields)
   - HCPCS: 48 columns → 6 columns

3. **Standardization**:
   - All NPIs zero-padded to 10 digits
   - All HCPCS codes uppercased
   - All state codes normalized via `STATE_REF` lookup
   - All ZIP codes truncated to 5 digits

4. **Enrichment**:
   - FACT table enriched with provider names, HCPCS descriptions, state locations via LEFT JOIN
   - Missing dimension values result in NULL enrichment fields

---

## 📊 10. Power BI Semantic Model Usage

### Star Schema in Power BI

The MODEL layer tables are consumed directly by Power BI as a star schema:

- **Fact Table**: `FACT_MEDICAID_PROVIDER_SPENDING`
- **Dimensions**: `NPI_DIM`, `HCPCS_DIM`, `DATE_DIM`, `SERVICE_CATEGORY_DIM`

### Key Fields for Power BI Visuals

| Visual Type | Field Used | Source Table |
|-------------|-----------|--------------|
| Filled Map | `PROVIDER_STATE_US` | `NPI_DIM` |
| Tree Map (Geographic) | `PROVIDER_STATE_US` | `NPI_DIM` |
| Time Series | `YEAR_MONTH` | `DATE_DIM` |
| Service Category Slicer | `SERVICE_CATEGORY` | `SERVICE_CATEGORY_DIM` or `FACT` |
| Provider Drilldown | `FULL_NAME`, `ORG_NAME` | `NPI_DIM` |
| Procedure Analysis | `HCPCS_DESCRIPTION` | `HCPCS_DIM` |

### Relationship Configuration

- **One-to-Many** relationships from all dimensions to FACT table
- **Cross-filter direction**: Single (dimensions filter FACT, not vice versa)
- **Cardinality**: Enforced via primary/foreign key constraints (documentation only in Snowflake)

### DAX Measures
DAX measures are defined in the Power BI semantic layer and documented separately. 
See `docs/09_powerbi_dashboard.md` for:
- Core measures (Total Claims, Total Paid Amount, etc.)
- Time intelligence (Rolling 12M, MoM, YoY)
- Service category analytics
- Top-N rankings
- Full DAX measure catalog

---

## 🧭 11. How to Use This Document

### Engineers
- Implement SQL transformations based on documented lineage
- Validate that RAW → STAGE → MODEL transformations match the mapping
- Ensure consistency and reproducibility across layers
- Support debugging and data quality checks using S2T as reference
- Use this as the authoritative source for field definitions

### Analysts / BI Developers
- Understand metric definitions and how fields are derived
- Build accurate Power BI semantic models
- Trace fields back to source systems for validation
- Communicate logic clearly to stakeholders
- Design reports using standardized, analytics-ready fields

### Reviewers / Hiring Managers
- Evaluate data engineering discipline and documentation quality
- Confirm EDS-style modeling practices
- Assess understanding of Medicaid data structures and lineage
- Validate that the project follows enterprise data governance standards

---

## 🧩 12. Why S2T Matters in Medicaid / EDS Work

State Medicaid programs and Enterprise Data Systems rely on:

- **Traceability** — every field must be traceable back to source
- **Auditability** — transformations must be documented for compliance
- **Repeatability** — pipelines must produce consistent results
- **Data lineage** — required for CMS reporting, audits, and oversight
- **Standardized definitions** — ensures alignment across agencies and vendors

S2T mapping is the core artifact that ensures:

- Every metric is reproducible
- Every field is traceable
- Every transformation is documented
- Every dimension/fact relationship is intentional
- Every stakeholder understands the logic behind the data

This is why S2T documentation is a **non-negotiable requirement** in EDS, Medicaid, and state government analytics environments.

---

## 🗂️ 13. Versioning & Change Log

| Version | Date       | Author           | Description                                                                             |
|---------|------------|------------------|-----------------------------------------------------------------------------------------|
| **1.0** | 2026-05-03 | Mairilyn Yera    | Initial S2T mapping created for NPI_DIM, HCPCS_DIM, and FACT_MEDICAID_PROVIDER_SPENDING |
| **1.1** | 2026-05-03 | Mairilyn Yera    | Added DATE_DIM and SERVICE_CATEGORY_DIM mappings                                        |
| **2.0** | 2026-05-06 | Mairilyn Yera    | Comprehensive update: expanded all table mappings with detailed RAW→STAGE→MODEL lineage, added STAGE layer field mappings, documented all derived fields,
                                          | added SERVICE_CATEGORY logic, enhanced geographic standardization section, added complete transformation logic summary, expanded join relationships section, 
                                          | added Power BI usage guidance |
| **2.1** | 2026-05-07 | Mairilyn Yera    | Corrected Full_Name construction, added Provider_Display_Name and Data_Quality_Flag

**Note**: All changes follow semantic versioning and include brief descriptions of modifications.

---

## 📁 14. SQL Reference Files

| Layer | Table/Object | SQL File |
|-------|-------------|----------|
| **RAW** | `MEDICAID_PROVIDER_SPENDING_RAW` | `sql/medicaid_ingestion_raw.sql` |
| **RAW** | `HCPCS_RAW_WIDE` | `sql/hcpcs_ingestion_raw.sql` |
| **RAW** | `NPI_RAW` | `sql/provider_ingestion_raw.sql` |
| **STAGE** | `MEDICAID_PROVIDER_SPENDING_STAGE` | `sql/medicaid_clean_stage.sql` |
| **STAGE** | `HCPCS_CLEAN` | `sql/hcpcs_clean.sql` |
| **STAGE** | `NPI_CLEAN` | `sql/provider_clean.sql` |
| **MODEL** | `NPI_DIM` | `sql/provider_dimension.sql` |
| **MODEL** | `HCPCS_DIM` | `sql/hcpcs_dimension.sql` |
| **MODEL** | `DATE_DIM` | `sql/model/date_and_service_dimensions.sql` |
| **MODEL** | `SERVICE_CATEGORY_DIM` | `sql/model/date_and_service_dimensions.sql` |
| **MODEL** | `STATE_REF` + Geographic Cleanup | `sql/model/clean_provider_states.sql` |
| **MODEL** | `FACT_MEDICAID_PROVIDER_SPENDING` | `sql/medicaid_fact_table.sql` |
| **QC** | Medicaid Quality Checks | `sql/medicaid_quality_checks.sql` |
| **QC** | HCPCS Quality Checks | `sql/hcpcs_quality_checks.sql` |
| **QC** | Provider Quality Checks | `sql/provider_quality_checks.sql` |
| **Orchestration** | Full Medicaid Pipeline | `sql/medicaid_full_pipeline.sql` |
| **Orchestration** | Full HCPCS Pipeline | `sql/hcpcs_full_pipeline.sql` |
| **Orchestration** | Full Provider Pipeline | `sql/provider_full_pipeline.sql` |

---

## ✍️ Author

**Mairilyn Yera Galindo**  
Data-Strata Analytics Portfolio  
Healthcare Data Analytics | Snowflake | SQL | Power BI  
Boca Raton, Florida

**GitHub**: [https://github.com/Data-Strata](https://github.com/Data-Strata)  
**LinkedIn**: [www.linkedin.com/in/mairilyn-yera-galindo-07a93932](https://www.linkedin.com/in/mairilyn-yera-galindo-07a93932)

---

© 2026 Mairilyn Yera Galindo  
Data-Strata Analytics Portfolio
