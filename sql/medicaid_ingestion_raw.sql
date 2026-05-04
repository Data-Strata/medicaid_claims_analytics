-- ============================================================
-- MEDICAID INGESTION: RAW LAYER
-- Source: medicaid-provider-spending.csv (11 GB)
-- ============================================================

USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;

-- File format (shared with HCPCS)
CREATE OR REPLACE FILE FORMAT MEDICAID_CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null');

-- RAW table (all VARCHAR to preserve fidelity)
CREATE OR REPLACE TABLE MEDICAID_PROVIDER_SPENDING_RAW (
    BILLING_PROVIDER_NPI_NUM        VARCHAR,
    SERVICING_PROVIDER_NPI_NUM      VARCHAR,
    HCPCS_CODE                      VARCHAR,
    CLAIM_FROM_MONTH                VARCHAR,
    TOTAL_PATIENTS                  VARCHAR,
    TOTAL_CLAIM_LINES               VARCHAR,
    TOTAL_PAID                      VARCHAR
);

-- Load the CSV from MEDICAID_EXTRACTED
COPY INTO MEDICAID_PROVIDER_SPENDING_RAW
FROM @MEDICAID_EXTRACTED
FILE_FORMAT = (FORMAT_NAME = 'MEDICAID_CSV_FORMAT')
ON_ERROR = 'CONTINUE';

-- Row count validation
SELECT COUNT(*) AS RAW_ROW_COUNT
FROM MEDICAID_PROVIDER_SPENDING_RAW;
