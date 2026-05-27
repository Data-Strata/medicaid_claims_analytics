# Snowflake Environment Setup (RAW → STAGE → ANALYTICS)

This document defines the Snowflake environment used for the Medicaid Provider Spending analytics pipeline.
It reflects the updated ingestion workflow (ZIP landing → local extraction → CSV ingestion) and the three-layer architecture.

🟦 1. Databases
The project uses a three‑layer warehouse architecture:

| Layer     | Database               | Purpose |
| --------- | ---------------------- | ------------------------------------------------------ |
| RAW       | ``RAW_MEDICAID``       | Stores unmodified source files and raw ingested tables |
| STAGE     | ``STAGE_MEDICAID``     | Cleaned, typed, standardized tables |
| ANALYTICS | ``ANALYTICS_MEDICAID`` | Curated dimension + fact tables|


🟦 2. Schemas

| Database             | Schema   | Full Path                  | Contents                                                                          |
|----------------------|----------|----------------------------|-----------------------------------------------------------------------------------|
| `RAW_MEDICAID`       | `PUBLIC` | `RAW_MEDICAID.PUBLIC`      | All RAW tables (NPI_RAW, MEDICAID_PROVIDER_SPENDING_RAW, HCPCS_RAW_WIDE)          |
| `STAGE_MEDICAID`     | `CLEAN`  | `STAGE_MEDICAID.CLEAN`     | All CLEAN/STAGE tables (NPI_CLEAN, MEDICAID_PROVIDER_SPENDING_STAGE, HCPCS_CLEAN) |
| `ANALYTICS_MEDICAID` | `MODEL`  | `ANALYTICS_MEDICAID.MODEL` | All DIM + FACT tables                                                             |

🟦 3. Warehouse
```Code
Warehouse: WH_MEDICAID_ETL
Size: XSMALL
Purpose: Ingestion + transforms
Auto-suspend: 60 seconds
Auto-resume: Enabled
```
This warehouse is sufficient for loading and transforming the 11-GB Medicaid dataset
and all reference datasets.

🟦 4. Table Inventory

### RAW Layer — `RAW_MEDICAID.PUBLIC`

| Table                            | Source                    | Columns          | Notes                               |
|----------------------------------|---------------------------|------------------|-------------------------------------|
| `MEDICAID_PROVIDER_SPENDING_RAW` | HHS Open Data (11 GB CSV) | 7 (all VARCHAR)  | ~238M rows                          |
| `NPI_RAW`                        | CMS NPPES Registry        | 330 (all STRING) | Manual CREATE TABLE from header row |
| `HCPCS_RAW_WIDE`                 | CMS HCPCS Level II        | 48 (all STRING)  | Wide format with all HCPCS fields   |


### STAGE Layer — `STAGE_MEDICAID.CLEAN`

| Table                              | Source                          | Columns                          | Notes                      |
|------------------------------------|---------------------------------|----------------------------------|----------------------------|
| `MEDICAID_PROVIDER_SPENDING_STAGE` | MEDICAID_PROVIDER_SPENDING_RAW  | 7 (typed)                        | TRY_TO_NUMBER, TRY_TO_DATE |
| `NPI_CLEAN`                        | NPI_RAW | 11 (analytics fields) | Sanitized dates, trimmed strings |
| `HCPCS_CLEAN`                      | HCPCS_RAW_WIDE                  | 6 (analytics fields)             | Extracted key fields only  |


### MODEL Layer — `ANALYTICS_MEDICAID.MODEL`

| Table                             | Type      | Grain                                                 | Clustering Key                                   |
|-----------------------------------|-----------|-------------------------------------------------------|--------------------------------------------------|
| `NPI_DIM`                         | Dimension | 1 row per NPI                                         | `CLUSTER BY (NPI)`                               |
| `HCPCS_DIM`                       | Dimension | 1 row per HCPCS code                                  | `CLUSTER BY (HCPCS_CODE)`                        |
| `FACT_MEDICAID_PROVIDER_SPENDING` | Fact      | 1 row per billing NPI + servicing NPI + HCPCS + month | `CLUSTER BY (CLAIM_MONTH, BILLING_PROVIDER_NPI)` |

---

## 🟦 5. Internal Stages

Two internal stages are used:
 
### 5.1 Landing Stage (ZIP file)
Stores the original ZIP exactly as downloaded.

```sql
USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;

CREATE OR REPLACE STAGE MEDICAID_STAGE;
```
### 5.2  Medicaid + HCPCS Ingestion Stage
Stores extracted CSVs for the Medicaid claims and HCPCS reference datasets.

```sql
CREATE OR REPLACE STAGE MEDICAID_EXTRACTED
  FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT');
```

### 5.3 NPI Ingestion Stage
Dedicated stage for the NPI Registry CSV (330 columns).
```sql
CREATE OR REPLACE STAGE NPI_EXTRACTED
  FILE_FORMAT = (FORMAT_NAME = 'NPI_CSV_FORMAT');
```

🟦 6. File Formats

6.1 MEDICAID_CSV_FORMAT
Used for: Medicaid claims CSV and HCPCS reference CSV
```sql
CREATE OR REPLACE FILE FORMAT MEDICAID_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null');
```

6.2 NPI_CSV_FORMAT
Used for: NPI Registry CSV (330 columns)
```sql
CREATE OR REPLACE FILE FORMAT RAW_MEDICAID.PUBLIC.NPI_CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
TRIM_SPACE = TRUE
NULL_IF = ('', 'NULL', 'null');
```

🟦 7. Clustering Strategy
Clustering keys are applied to all MODEL-layer tables for query performance
on a dataset of ~238M rows:

| Table                               | Clustering Key                                           | Rationale                         |
| ----------------------------------- | -------------------------------------------------------- | --------------------------------- |
| ``NPI_DIM``                         | ``CLUSTER ``BY ``(NPI)``                                 | Primary join key to fact table    |
| ``HCPCS_DIM``                       | ``CLUSTER ``BY ``(HCPCS_CODE)``                          | Primary join key to fact table    |
| ``FACT_MEDICAID_PROVIDER_SPENDING`` | ``CLUSTER ``BY ``(CLAIM_MONTH, ``BILLING_PROVIDER_NPI)`` | Most common filter + join pattern |

🟦 8. Notes on ZIP Extraction (2026 Update)
The dataset ZIP contains one single 11-GB CSV.
Snowflake's Python runtime cannot extract ZIPs of this size due to /tmp disk limits.

Therefore:
- ZIP extraction must be done locally (PowerShell or command line)
- Only the extracted CSV is uploaded to Snowflake
- Medicaid and HCPCS files are uploaded to @MEDICAID_EXTRACTED
- NPI Registry files are uploaded to @NPI_EXTRACTED

This is the supported and scalable ingestion pattern.

🟦 9. Troubleshooting: Power BI ↔ Snowflake (Key‑Pair Authentication)
This section documents common issues encountered when connecting Power BI Desktop to Snowflake using RSA key‑pair authentication, along with verified fixes.
It is designed for reuse across client implementations and internal onboarding.

9.1 Common Connection Errors
| **Error / Symptom**                     | **Cause**                          | **Resolution** |
| --------------------------------------- | ---------------------------------- | -------------------------------------------- |
| SSL peer certificate or                 | Incorrect **Snowflake server URL** | Use the exact account URL:                   |
  SSH remote key was not OK               | (using org name or browser URL     | ``<ACCOUNT_LOCATOR>.snowflakecomputing.com`` |
  (code=60)                               | instead of account locator)        |                                              |
| ____________________________________    | _________________________________  |  __________________________________________  |     
| Power BI shows only Username /          | Wrong connector (OAuth popup       |  Use **Get Data → Snowflake** (native        |
| Password (no Key‑Pair option)           | instead of native connector)       |  connector), not the browser login           |
|                                         |                                    |                                              |
| ____________________________________    | _________________________________  |  __________________________________________  |   
| openssl: command not found              | OpenSSL not installed or PATH not  |  Install **Win64 OpenSSL v3.x Light** and add|
|                                         | updated                            |  C:\\ProgramFiles\\OpenSSL-Win64\\bin to PATH|
| ____________________________________    | _________________________________  |  __________________________________________  |   
| Key‑pair authentication fails           | Public key not registered or       | Re‑run ALTER USER ... SET                    |
| immediately                             | mismatched                         | RSA_PUBLIC_KEY = '<public ``key>'            |
| ____________________________________    | _________________________________  |  __________________________________________  |   
| Power BI rejects pasted private key     | Missing header/footer line breaks  | Ensure full block is included: -----BEGIN    | 
|                                         |                                    | PRIVATE KEY----- … -----END PRIVATE KEY----- |
| ____________________________________    | _________________________________  |  __________________________________________  |   
| Power BI cannot find the private key    | File generated in unexpected       |  Search with:                                |
| file                                    |  directory                         |  Get-ChildItem "-Path C:\\"-Filter rsa_key.p8|
|                                         |                                    |  -Recurse                                    |


9.2 Verifying the Correct Snowflake Server URL
Power BI must use the organization URL.

9.3 OpenSSL Installation Issues
Symptom
```code
openssl : The term 'openssl' is not recognized...
```

Fix
- Install Win64 OpenSSL v3.x Light (not v4.x experimental).
- Add to PATH: `C:\Program Files\OpenSSL-Win64\bin`
- Restart PowerShell.
- Verify:
```powershell
openssl version
```

9.4 Public vs Private Key Confusion
| **Key**     | **File**        | **Used By** | **Notes**                                               |
| ----------  | --------------- | ----------- | ------------------------------------------------------- |
| Public Key  | ``rsa_key.pub`` | Snowflake   | Added via ``ALTER ``USER ``... ``SET ``RSA_PUBLIC_KEY`` |
| Private Key | ``rsa_key.p8``  | Power BI    | Never shared; selected or pasted during authentication  |

*Important*:  
Power BI uses the private key.
Snowflake stores the public key.

9.5 Connector UI Differences
Power BI has two Snowflake authentication UIs:

A. Native Power BI Desktop Connector (recommended)
- Accessed via Get Data → Snowflake
- Supports file picker for rsa_key.p8
- Most stable for enterprise deployments

B. Browser‑style OAuth Popup
- Appears when Power BI triggers OAuth flow
- Shows a textbox for private key instead of file picker
- Requires pasting the full private key text

Use the native connector whenever possible.

🟦 10. Step‑by‑Step Guide: Power BI ↔ Snowflake (Key‑Pair Authentication)
This guide provides a repeatable, client‑ready workflow for secure Power BI connectivity.

10.1 Generate RSA Key Pair (Client Machine)
```powershell
# Private key (PKCS#8)
openssl genrsa -out rsa_key.p8 2048

# Public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```
Files created:
> rsa_key.p8 → private key (Power BI)
> rsa_key.pub → public key (Snowflake)

10.2 Register Public Key in Snowflake
```sql
alter user PBI_USER
  set rsa_public_key = '-----BEGIN PUBLIC KEY-----
<contents of rsa_key.pub>
-----END PUBLIC KEY-----';
```
Verify:
```sql
describe user PBI_USER;
```

10.3 Determine Correct Server URL
On your snowflake account details, copy Account/Server URL.

10.4 Connect from Power BI Desktop
Step 1 — Get Data → Snowflake
Step 2 — Enter connection details
```sql
Server: "<your-organization-name>"-"<your-account-name>".snowflakecomputing.com
Warehouse:"<your-warehouse-name>"
```

Step 3 — Authentication
Choose:
```code
Key-pair
```

Step 4 — Provide credentials
- Username: `PBI_USER`

- Private Key:
Use Browse… to select rsa_key.p8
OR paste the full private key block (browser-style UI)

- Passphrase: leave blank (unless encrypted)

Step 5 — Connect
Power BI will display the Snowflake Navigator with:
```code
ANALYTICS_MEDICAID.MODEL
STAGE_MEDICAID.CLEAN
RAW_MEDICAID.PUBLIC
```
