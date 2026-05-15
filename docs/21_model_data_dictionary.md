📘 MODEL Layer Data Dictionary
File: docs/21_model_data_dictionary.md  
Purpose: Central reference for all MODEL‑layer tables used in analytics, integrity scoring, and Power BI semantic modeling.

🟦 1. NPI_DIM(Provider Dimension) 

Grain: One row per unique NPI
Purpose: Provider master dimension used for enrichment, display names, geographic standardization, and integrity scoring.

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
| ``PROVIDER_DISPLAY_NAME``	| VARCHAR      | Final display name used in Power BI                      |
| ``PROVIDER_TYPE``        	| VARCHAR      | Business/individual type used for analytics              |
| ``DATA_QUALITY_FLAG``    	| VARCHAR      | Flag indicating NPI data quality status                  |
```

🟦 2. HCPCS_DIM (Procedure Dimension)
Grain: One row per HCPCS code
Purpose: Procedure metadata used for enrichment and classification.

```code
| Column 				| Type 	  | Description 		|
| --------------------- | ------- | ------------------- |
| ``HCPCS_CODE`` 		| VARCHAR | Procedure code (PK) |
| ``DESCRIPTION`` 		| VARCHAR | Long description 	|
| ``SHORT_DESCRIPTION`` | VARCHAR | Short description 	|
| ``CATEGORY`` 			| VARCHAR | HCPCS category 		|
| ``EFFECTIVE_DATE`` 	| DATE    | Code effective date |
| ``TERMINATION_DATE``  | DATE    | Code termination date |
```

🟦 3. FACT_MEDICAID_PROVIDER_SPENDING
Grain: One row per provider per claim month
Purpose: Core analytical fact table for Medicaid spending.

```code
| Column 					 | Type 	   | Description |
| -------------------------- | ----------- | ---------------- |
| ``CLAIM_MONTH`` 			 | DATE 	   | Month of service |
| ``BILLING_PROVIDER_NPI``   | VARCHAR(10) | FK → NPI_DIM |
| ``RENDERING_PROVIDER_NPI`` | VARCHAR(10) | FK → NPI_DIM |
| ``HCPCS_CODE`` 		     | VARCHAR 	   | FK → HCPCS_DIM |
| ``TOTAL_CLAIMS`` 			 | NUMBER  	   | Number of claims |
| ``TOTAL_PAID_AMOUNT`` 	 | NUMBER 	   | Total paid amount |
| ``AVG_PAID_AMOUNT`` 		 | NUMBER  	   | Average paid amount |
| ``STATE`` 				 | VARCHAR 	   | Medicaid state |
| ``PLACE_OF_SERVICE`` 		 | VARCHAR 	   | POS code |
| ``SPECIALTY`` 			 | VARCHAR     | Provider specialty |
```

🟦 4. DATE_DIM
Grain: One row per calendar date
Purpose: Supports time intelligence and Power BI modeling.

```code
| Column | Type | Description |
| --- | --- | --- |
| ``DATE_VALUE`` | DATE | Calendar date (PK) |
| ``YEAR`` | NUMBER | Year |
| ``MONTH`` | NUMBER | Month number |
| ``MONTH_NAME`` | VARCHAR | Month name |
| ``YEAR_MONTH`` | VARCHAR | YYYY‑MM |
| ``QUARTER`` | NUMBER | Quarter (1–4) |
| ``YEAR_QUARTER`` | VARCHAR | YYYY‑Q# |
```

🟦 5. SERVICE_CATEGORY_DIM
Grain: One row per service category
Purpose: Groups HCPCS codes into analytic service categories.

```code
| Column | Type | Description |
| --- | --- | --- |
| ``SERVICE_CATEGORY`` | VARCHAR | Category name (PK) |
| ``DESCRIPTION`` | VARCHAR | Category description |
| ``CATEGORY_GROUP`` | VARCHAR | Higher‑level grouping |
```

🟦 6. LEGACY_SERVICING_PROVIDER_DIM
Grain: One row per non‑NPI servicing identifier
Purpose: Classifies A‑prefix, M‑prefix, and other legacy Medicaid servicing IDs.

```
| Column | Type | Description |
| --- | --- | --- |
| ``SERVICING_PROVIDER_ID`` | VARCHAR | Legacy servicing ID (PK) |
| ``PROVIDER_CATEGORY`` | VARCHAR | Atypical, Agency, County, Managed Care, etc. |
| ``CLAIM_COUNT`` | NUMBER | Total claims associated with this ID |
| ``SERVICE_CATEGORY`` | VARCHAR | Most common service category |
| ``STATE`` | VARCHAR | State associated with the legacy ID |
```

🟦 7. DQ_INVALID_NPI_TREND
Grain: One row per month
Purpose: Tracks invalid NPI counts over time.

```
| Column | Type | Description |
| --- | --- | --- |
| ``CLAIM_MONTH`` | DATE | Month of service (PK) |
| ``INVALID_NPI_COUNT`` | NUMBER | Number of invalid NPIs |
| ``TOTAL_CLAIMS`` | NUMBER | Total claims |
| ``INVALID_NPI_RATE`` | FLOAT | Invalid NPI percentage |
```

🟦 8. DQ_INVALID_NPI_ANOMALIES
Grain: One row per detected anomaly
Purpose: Identifies spikes/drops using 3‑sigma anomaly detection.

```
| Column | Type | Description |
| --- | --- | --- |
| ``CLAIM_MONTH`` | DATE | Month of anomaly |
| ``INVALID_NPI_RATE`` | FLOAT | Observed invalid rate |
| ``MEAN_RATE`` | FLOAT | Historical mean |
| ``STDDEV_RATE`` | FLOAT | Standard deviation |
| ``Z_SCORE`` | FLOAT | Standardized deviation |
| ``ANOMALY_FLAG`` | BOOLEAN | TRUE = anomaly |
```

🟦 9. Notes & Maintenance
- FACT_MEDICAID must be refreshed when NPI_DIM changes.

- Integrity tables depend on FACT + DATE_DIM.

- All MODEL tables use clustering keys (see 07_data_modeling.md).

- Power BI semantic model consumes all MODEL tables.