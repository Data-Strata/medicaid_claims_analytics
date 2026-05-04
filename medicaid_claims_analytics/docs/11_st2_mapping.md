## 📄 11 — Source‑to‑Target Mapping (S2T)
Medicaid Claims Analytics — Snowflake Data Warehouse

This document defines the Source‑to‑Target (S2T) mapping for the Medicaid Claims Analytics project.
It describes how fields flow from:

RAW → STAGE → MODEL (DIM + FACT)

across the three datasets used in this project:

- Medicaid Provider Spending (HHS Open Data)
- HCPCS Level II Reference (CMS)
- NPI Registry (NPPES, CMS)

The S2T mapping is the contract between ingestion and analytics.
It documents lineage, transformations, business rules, and grain definitions.

## 🧱 1. Architecture Reference
As described in the project README:

“The pipeline ingests three source datasets into Snowflake and transforms them through a three-layer architecture (RAW → STAGE → MODEL).”

RAW Layer
Unmodified source files (all STRING/VARCHAR).

STAGE Layer
Cleaned, typed, standardized tables using:
- TRY_TO_NUMBER
- TRY_TO_DATE
- trimmed strings
- normalized codes

MODEL Layer
Curated DIM and FACT tables used for analytics and Power BI.


## 🧩 2. Grain Definitions
NPI_DIM
- Grain: 1 row per unique NPI
- Purpose: Provider master dimension

HCPCS_DIM
- Grain: 1 row per HCPCS code
- Purpose: Procedure metadata

FACT_MEDICAID_PROVIDER_SPENDING
- Grain: 1 row per billing NPI + servicing NPI + HCPCS + month
- Purpose: Core analytical fact table

## 📘 3. S2T Mapping — NPI_DIM

| Target Column | Source Column | Transformation Logic |
| --- | --- | --- |
| NPI | NPI | Direct load |
| ENTITY_TYPE_CODE | ENTITY_TYPE_CODE | Direct load |
| REPLACEMENT_NPI | REPLACEMENT_NPI | Direct load |
| ORG_NAME | ORG_NAME | Direct load |
| LAST_NAME | LAST_NAME | Direct load |
| FIRST_NAME | FIRST_NAME | Direct load |
| MIDDLE_NAME | MIDDLE_NAME | Direct load |
| CREDENTIALS | CREDENTIALS | Direct load |
| FULL_NAME | FIRST_NAME, LAST_NAME | ``CONCAT_WS(' ``', ``FIRST_NAME, ``LAST_NAME)`` |
| MAILING_CITY | MAILING_CITY | Direct load |
| MAILING_STATE | MAILING_STATE | Direct load |
| MAILING_ZIP | MAILING_ZIP | ``LEFT(MAILING_ZIP, ``5)`` |
| PRACTICE_CITY | PRACTICE_CITY | Direct load |
| PRACTICE_STATE | PRACTICE_STATE | Direct load |
| PRACTICE_ZIP | PRACTICE_ZIP | ``LEFT(PRACTICE_ZIP, ``5)`` |
| ENUMERATION_DATE | ENUMERATION_DATE | ``TRY_TO_DATE()`` |
| LAST_UPDATE_DATE | LAST_UPDATE_DATE | ``TRY_TO_DATE()`` |
| GENDER | GENDER | Direct load |
| PRIMARY_TAXONOMY_CODE | PRIMARY_TAXONOMY_CODE | Direct load |

## 📘 3.1 Derived Fields — Geographic Standardization (MODEL Layer)
The raw NPI Registry fields `PRACTICE_STATE` and `MAILING_STATE` contain global location values (countries, provinces, APO/FPO codes, ZIP codes, mixed formats).
To support reliable U.S. state–level analytics, the MODEL layer applies a standardization process that extracts valid U.S. state abbreviations using a lookup table (`STATE_REF`) and REGEXP‑based matching.

Three new fields are created in `NPI_DIM`:
- `PRACTICE_STATE_US`
- `MAILING_STATE_US`
- `PROVIDER_STATE_US` (unified best‑available state)

🧬 Source → Target Mapping (Geographic Fields)

| Target Column 		| Source Column		 | Transformation Logic 																| Notes 													|
| --------------------- | ------------------ | ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| ``PRACTICE_STATE_US`` | ``PRACTICE_STATE`` | Extract U.S. state abbreviation using ``STATE_REF`` lookup + ``REGEXP_LIKE`` pattern | Standardizes practice location to valid U.S. states only. |
|						|					 | matching for abbreviations and full state names. 									|															|
| --------------------- | ------------------ | ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| ``MAILING_STATE_US``  | ``MAILING_STATE``  | Same extraction logic as above using ``STATE_REF`` lookup + REGEXP matching. 		| Standardizes mailing location to valid U.S. states only. 	|
| --------------------- | ------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------- |
| ``PROVIDER_STATE_US`` | ``PRACTICE_STATE_US``, ``MAILING_STATE_US`` | ``COALESCE(PRACTICE_STATE_US, ``MAILING_STATE_US)`` 		| Unified state field used by Power BI for geographic visuals. |

🧠 Transformation Logic Summary
- A canonical lookup table (`STATE_REF`) containing all 50 U.S. state abbreviations is created in the MODEL layer.
- REGEXP‑based matching identifies valid U.S. states from inconsistent raw values (e.g., “FL”, “FLORIDA”, “MIAMI, FLORIDA”, “CA, 94566”).
- Non‑U.S. values (e.g., “ONTARIO”, “TOKYO”, “ABU DHABI”, “UNKNOWN”, “APO AE”) are ignored.
- Cleaned fields (`PRACTICE_STATE_US`, `MAILING_STATE_US`) are populated via JOIN‑based updates.
- `PROVIDER_STATE_US` provides a single, analytics‑ready state field.

📌 Why This Matters
Standardizing provider geography is essential for Medicaid analytics:
- Ensures accurate state‑level rollups
- Enables Filled Map visuals in Power BI
- Removes global noise from foreign addresses
- Improves BI model reliability and reproducibility
- Supports executive‑level reporting and geographic insights

📁 SQL Reference
Full implementation script:
```sql
/sql/model/clean_provider_states.sql
```
This script includes:
- STATE_REF creation
- JOIN‑based REGEXP extraction
- Column creation + updates
- Validation queries


## 📘 4. S2T Mapping — HCPCS_DIM

| Target Column | Source Column | Transformation Logic |
| --- | --- | --- |
| HCPCS_CODE | HCPCS_CODE | Direct load |
| DESCRIPTION | DESCRIPTION | Direct load |
| SHORT_DESCRIPTION | SHORT_DESCRIPTION | Direct load |
| CATEGORY | CATEGORY | Direct load |
| EFFECTIVE_DATE | EFFECTIVE_DATE | ``TRY_TO_DATE()`` |
| TERMINATION_DATE | TERMINATION_DATE | ``TRY_TO_DATE()`` |

## 📘 5. S2T Mapping — FACT_MEDICAID_PROVIDER_SPENDING

| Target Column          | Source Column          | Transformation Logic |
| ---------------------- | -----------------------| ------------------------------------------ |
| CLAIM_MONTH            | DATE_OF_SERVICE        | ``DATE_TRUNC('month', ``DATE_OF_SERVICE)`` |
| BILLING_PROVIDER_NPI   | BILLING_PROVIDER_NPI   | Direct load |
| RENDERING_PROVIDER_NPI | SERVICING_PROVIDER_NPI | Direct load |
| HCPCS_CODE             | HCPCS_CODE             | Direct load |
| TOTAL_CLAIMS           | CLAIM_COUNT            | ``TRY_TO_NUMBER()`` |
| TOTAL_PAID_AMOUNT      | PAID_AMOUNT            | ``TRY_TO_NUMBER()`` |
| AVG_PAID_AMOUNT        | PAID_AMOUNT            | ``TOTAL_PAID_AMOUNT ``/ ``TOTAL_CLAIMS`` |
| STATE                  | STATE                  | Direct load |
| PLACE_OF_SERVICE       | PLACE_OF_SERVICE       | Direct load |
| SPECIALTY              | SPECIALTY              | Direct load |
| SERVICE_CATEGORY       | HCPCS_CODE             | CASE WHEN HCPCS_CODE LIKE 'J%' THEN 'RX' …|
| LOAD_TIMESTAMP         | System                 | ``CURRENT_TIMESTAMP()`` |

## 📘 5.1 S2T Mapping — DATE_DIM and SERVICE_CATEGORY_DIM
Overview
Although the Medicaid dataset does not include a dedicated date dimension or service category dimension, both are essential for BI modeling, time‑series analysis, and semantic clarity.
These dimensions are created in the MODEL layer using deterministic logic and derived fields.

🗓️ DATE_DIM (Model Layer)
Grain: 1 row per calendar date
Purpose: Supports time intelligence, trending, and Power BI relationships.

🧬 Source → Target Mapping
| Target Column | Source Column 	 | Transformation Logic 					  | Notes 		  |
| ------------- | ------------------ | ------------------------------------------ | ------------- |
| ``DATE_KEY``  | CLAIM_MONTH (FACT) | `TO_NUMBER(TO_CHAR(DATE,'YYYYMMDD'))` 	  | Surrogate key |
| ``DATE`` 		| CLAIM_MONTH 		 | Direct load 							 	  | Base date 	  |
| ``YEAR`` 		| CLAIM_MONTH 		 | ``YEAR(DATE)`` 							  | Calendar year |
| ``MONTH`` 	| CLAIM_MONTH 		 | ``MONTH(DATE)`` 							  | Calendar month |
| ``MONTH_NAME``| CLAIM_MONTH 		 | ``TO_CHAR(DATE, 'Month')`` 				  | Full month name |
| ``YEAR_MONTH``| CLAIM_MONTH 		 | ``TO_CHAR(DATE, `'YYYY-MM')`` 			  | BI-friendly label |
| ``QUARTER`` 	| CLAIM_MONTH 		 | ``QUARTER(DATE)`` 						  | Calendar quarter |

🧠 Transformation Logic Summary
- DATE_DIM is generated programmatically (no source table).
- FACT table joins on CLAIM_MONTH.
- Supports Power BI time intelligence (YTD, MTD, rolling 12 months).

🏥 SERVICE_CATEGORY_DIM (Model Layer)
Grain: 1 row per service category
Purpose: Groups HCPCS codes into high‑level clinical categories.

🧬 Source → Target Mapping
| Target Column 	   | Source Column | Transformation Logic   | Notes |
| -------------------- | ------------- | ---------------------- | -------------- |
| ``SERVICE_CATEGORY`` | HCPCS_CODE    | CASE logic 		    | RX, ED, IP, OP, Other |
| ``DESCRIPTION`` 	   | Derived       | Hardcoded descriptions | BI-friendly labels |

Example CASE Logic
```sql
CASE 
    WHEN HCPCS_CODE LIKE 'J%' THEN 'RX'
    WHEN HCPCS_CODE LIKE '99%' THEN 'ED'
    WHEN HCPCS_CODE LIKE '1%' THEN 'IP'
    WHEN HCPCS_CODE LIKE '2%' THEN 'OP'
    ELSE 'OTHER'
END
```

Transformation Logic Summary
- Categorizes HCPCS codes into clinically meaningful groups.
- Used for slicers, filters, and drilldowns in Power BI.
- Stored as a small static dimension in the MODEL layer.

📁 SQL Reference
```code
/sql/model/date_and_service_dimensions.sql
```

This script:
- Generates DATE_DIM
- Generates SERVICE_CATEGORY_DIM
- Applies surrogate keys
- Ensures BI‑ready formatting


## 🔗 6. Join Logic

| Fact Column | References | Purpose |
| --- | --- | --- |
| BILLING_PROVIDER_NPI | NPI_DIM(NPI) | Provider enrichment |
| RENDERING_PROVIDER_NPI | NPI_DIM(NPI) | Rendering provider details |
| HCPCS_CODE | HCPCS_DIM(HCPCS_CODE) | Procedure metadata |

## 🧮 7. Transformation Logic Summary

Direct Loads
- NPI → NPI_DIM
- HCPCS → HCPCS_DIM
- Claims → FACT

Type Casting
- TRY_TO_NUMBER()
- TRY_TO_DATE()
- LEFT(zip, 5)

Derived Fields
- CLAIM_MONTH = DATE_TRUNC('month', DATE_OF_SERVICE)
- AVG_PAID_AMOUNT = TOTAL_PAID_AMOUNT / TOTAL_CLAIMS
- FULL_NAME = CONCAT_WS(' ', FIRST_NAME, LAST_NAME)

Business Rules
- Deduplication in NPI_DIM
- HCPCS field reduction (48 → 6 fields)
- Provider-level aggregation in FACT


## 📊 8. Notes for Power BI Modeling
- FACT table is the center of the star schema
- NPI_DIM and HCPCS_DIM are lookup dimensions
- CLAIM_MONTH should join to a DATE_DIM (future enhancement)
- SERVICE_CATEGORY_DIM can be added later (ED/IP/OP/RX logic)

## 🧭 How to Use These Files
Engineers
- Implement SQL transformations based on the documented lineage
- Validate that RAW → STAGE → MODEL transformations match the mapping
- Ensure consistency and reproducibility across layers
- Support debugging and data quality checks using S2T as the reference

Analysts / BI Developers
- Understand metric definitions and how fields are derived
- Build accurate Power BI semantic models
- Trace fields back to source systems for validation
- Communicate logic clearly to stakeholders

Reviewers / Hiring Managers
- Evaluate data engineering discipline and documentation quality
- Confirm EDS‑style modeling practices
- Assess understanding of Medicaid data structures and lineage
- Validate that the project follows enterprise data governance standards

## 🧩 Why S2T Matters in Medicaid / EDS Work
State Medicaid programs rely on:
- Traceability — every field must be traceable back to source
- Auditability — transformations must be documented for compliance
- Repeatability — pipelines must produce consistent results
- Data lineage — required for CMS reporting, audits, and oversight
- Standardized definitions — ensures alignment across agencies and vendors

S2T mapping is the core artifact that ensures:
- Every metric is reproducible
- Every field is traceable
- Every transformation is documented
- Every dimension/fact relationship is intentional
- Every stakeholder understands the logic behind the data
This is why S2T documentation is a non‑negotiable requirement in EDS, Medicaid, and state government analytics environments.	

## 🗂️ Versioning & Change Log
This section tracks updates to the S2T mapping as the project evolves.
| Version | Date      | Author                | Description |
| ------- | --------- | -------------- | ---------------------------------------------------------------------------------------- |
| **1.0** | 2026‑05‑03 | Mairilyn Yera | Initial S2T mapping created for NPI_DIM, HCPCS_DIM, and FACT_MEDICAID_PROVIDER_SPENDING.|
| **1.1** | 2026‑05‑03 | Mairilyn Yera | Add DATE_DIM and SERVICE_CATEGORY_DIM mappings. |
| **1.2** | *TBD*      | *TBD* 	   	    | Add additional facts (provider utilization, HCPCS utilization). |
| **1.3** | *TBD*      | *TBD* 			| Add Power BI semantic model mapping. |

Note: All changes should follow semantic versioning and include a brief description of modifications.

## ✍️ Author
Mairilyn Yera Galindo  
Data‑Strata Analytics Portfolio
Healthcare Data Analytics | Snowflake | SQL | Power BI
Boca Raton, Florida
GitHub: https://github.com/Data-Strata   
LinkedIn: www.linkedin.com/in/mairilyn-yera-galindo-07a93932