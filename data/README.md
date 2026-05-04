# Data Folder

Raw data files are not stored in this repository due to size constraints and best practices for handling large public datasets.

This project uses three publicly available healthcare datasets:
1. Medicaid Provider Spending by HCPCS (HHS Open Data)
2. HCPCS Level II Reference File (CMS)
3. NPPES NPI Registry (CMS)

All ingestion, modeling, and transformation logic is documented in `/docs`.

## 🟦 1. Medicaid Provider Spending by HCPCS

*Source*: U.S. Department of Health & Human Services (HHS)

*Dataset*: Medicaid Provider Spending

*Format*: ZIP → CSV (≈3.5 GB)

*URL*:  
```code
https://opendata.hhs.gov/datasets/medicaid-provider-spending/
```

## Why it’s not included in the repo
- File size exceeds GitHub’s 100 MB limit
- Best practice: load directly into Snowflake
- Ingestion uses a streaming method (no local storage required)
   
## Streaming Load Method
```bash
curl -L "https://opendata.hhs.gov/api/download/v1/resources/medicaid-provider-spending?format=zip" \
  | snowsql -q "PUT file://stdin @RAW_MEDICAID.PUBLIC.MEDICAID_STAGE AUTO_COMPRESS=TRUE"
```

## 🟩 2. HCPCS Level II Reference File
*Source*: Centers for Medicare & Medicaid Services (CMS)

*Dataset*: HCPCS Level II Quarterly Update

*Format*: xlsx (48 columns)
Example file: HCPC2026_APR_ANWEB.xlsx

*URL*:  
```code
https://www.cms.gov/medicare/coding-billing/healthcare-common-procedure-system/quarterly-update
```
## Why it’s not included in the repo
- CMS publishes quarterly updates as large files
- GitHub is not intended for storing medical coding reference files
- The file is uploaded directly to Snowflake via internal stage after conversion to `CSV`

## How the HCPCS Data Is Loaded
1. Download the quarterly HCPCS xlsx from CMS
2. Convert to CSV UTF‑8 (Comma delimited)
3. Upload to Snowflake internal stage:
```bash
snowsql -q "PUT file://hcpcs_2024q1.csv @MEDICAID_EXTRACTED AUTO_COMPRESS=TRUE"
```
4.Load into RAW:
```sql
COPY INTO RAW_MEDICAID.PUBLIC.HCPCS_RAW_WIDE
 FROM @MEDICAID_EXTRACTED
FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT');
```

## 🟪 3. NPPES NPI Registry
*Source*: Centers for Medicare & Medicaid Services (CMS)

*Dataset*: NPI Registry (National Provider Identifier)

*Format*: CSV (330 columns)

*URL*:  
```code
https://download.cms.gov/nppes/NPI_Files.html
```
## Why it’s not included in the repo
- Full NPI registry is extremely large (multiple GBs)
- Contains 330 columns and requires schema inference
- Best practice: load directly into Snowflake RAW layer

## How the NPI Data Is Loaded
1. Download the weekly NPI CSV (e.g., npidata_pfile_20240408-20240414.csv)
2. Upload to Snowflake:
   ```bash
   snowsql -q "PUT file://npidata_pfile_20240408-20240414.csv @NPI_EXTRACTED AUTO_COMPRESS=TRUE"
   ```
3. Load into RAW:
   ```sql
    COPY INTO RAW_MEDICAID.PUBLIC.NPI_RAW
      FROM @NPI_EXTRACTED
    FILE_FORMAT = (FORMAT_NAME = 'NPI_CSV_FORMAT')
    ON_ERROR = 'CONTINUE';
   ```
   
## Notes
- All datasets used in this project are public, open, and de‑identified.
- No PHI or sensitive information is stored in this repository.
- All ingestion, cleaning, and modeling logic is documented in /docs.
- The Snowflake warehouse processes all large files directly from internal stages.
