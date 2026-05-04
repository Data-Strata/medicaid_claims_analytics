# Data Folder

Raw data files are not stored in this repository due to size constraints 
and best practices for handling large public datasets.

This project uses the publicly available **Medicaid Provider Spending by HCPCS** 
dataset published by the U.S. Department of Health & Human Services (HHS).

Dataset Source:
https://opendata.hhs.gov/datasets/medicaid-provider-spending/

## Why the data is not included here
- The dataset is approximately 3.5 GB. 
- GitHub has a 100 MB file limit.
- Large datasets are best stored and processed directly in Snowflake.
- This project uses a streaming ingestion method that avoids local downloads.

## How the Data Is Loaded (Streaming Method)
1. Install SnowSQL.

2. Authenticate with your Snowflake account.

3. Stream the dataset ZIP directly into the internal stage:
`bash
curl -L "https://opendata.hhs.gov/api/download/v1/resources/medicaid-provider-spending?format=zip" \
  | snowsql -q "PUT file://stdin @RAW_MEDICAID.PUBLIC.MEDICAID_STAGE AUTO_COMPRESS=TRUE"
`

4. Verify the uploaded files using:
```sql
LIST @MEDICAID_STAGE;
```
5. Load the data into the RAW layer using:
```sql
COPY INTO RAW_MEDICAID.PUBLIC.MEDICAID_CLAIMS_RAW
FROM @MEDICAID_STAGE
FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT');
```
## Notes
This dataset is fully de-identified and safe for public use.
All ingestion, modeling, and transformation logic is documented in /docs.
