-- ============================================================
-- MEDICAID CLEAN TABLE (STAGE LAYER)
-- Standardizes types and prepares for analytics modeling
-- ============================================================

USE DATABASE STAGE_MEDICAID;
USE SCHEMA CLEAN;

-- ============================================================
-- Ensure Quarantine Schema & Table Exist
-- ============================================================

CREATE SCHEMA IF NOT EXISTS STAGE_MEDICAID.QUARANTINE;

CREATE TABLE IF NOT EXISTS STAGE_MEDICAID.QUARANTINE.MEDICAID_PROVIDER_SPENDING_BAD_ROWS (
    LOAD_TIMESTAMP      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    SOURCE_FILE_NAME    STRING,
    ERROR_CATEGORY      STRING,
    RAW_ROW_CONTENT     STRING
);


-- ============================================================
-- Identify malformed rows BEFORE loading into STAGE
-- ============================================================

WITH bad_rows AS (
    SELECT
        METADATA$FILENAME AS SOURCE_FILE_NAME,
        'STRUCTURAL_ERROR' AS ERROR_CATEGORY,
        TO_VARIANT(OBJECT_CONSTRUCT(*)) AS RAW_ROW_CONTENT
    FROM RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW
    WHERE TRY_TO_NUMBER(BILLING_PROVIDER_NPI_NUM) IS NULL
       OR TRY_TO_NUMBER(SERVICING_PROVIDER_NPI_NUM) IS NULL
       OR TRY_TO_DATE(CLAIM_FROM_MONTH || '-01') IS NULL
       OR HCPCS_CODE IS NULL
       OR LENGTH(TRIM(HCPCS_CODE)) = 0
)

INSERT INTO STAGE_MEDICAID.QUARANTINE.MEDICAID_PROVIDER_SPENDING_BAD_ROWS
SELECT CURRENT_TIMESTAMP, SOURCE_FILE_NAME, ERROR_CATEGORY, RAW_ROW_CONTENT
FROM bad_rows;

-- ============================================================
-- Load only valid rows into STAGE
-- ============================================================

CREATE OR REPLACE TABLE MEDICAID_PROVIDER_SPENDING_STAGE AS
SELECT
    LPAD(TRIM(BILLING_PROVIDER_NPI_NUM), 10, '0')   AS BILLING_PROVIDER_NPI,
    LPAD(TRIM(SERVICING_PROVIDER_NPI_NUM), 10, '0') AS SERVICING_PROVIDER_NPI,
    UPPER(TRIM(HCPCS_CODE))                         AS HCPCS_CODE,
    TRY_TO_DATE(CLAIM_FROM_MONTH || '-01')          AS CLAIM_MONTH,
    TRY_TO_NUMBER(TOTAL_PATIENTS)                   AS TOTAL_PATIENTS,
    TRY_TO_NUMBER(TOTAL_CLAIM_LINES)                AS TOTAL_CLAIM_LINES,
    TRY_TO_NUMBER(TOTAL_PAID)                       AS TOTAL_PAID
FROM RAW_MEDICAID.PUBLIC.MEDICAID_PROVIDER_SPENDING_RAW
WHERE TRY_TO_NUMBER(BILLING_PROVIDER_NPI_NUM) IS NOT NULL
  AND TRY_TO_NUMBER(SERVICING_PROVIDER_NPI_NUM) IS NOT NULL
  AND TRY_TO_DATE(CLAIM_FROM_MONTH || '-01') IS NOT NULL
  AND HCPCS_CODE IS NOT NULL
  AND LENGTH(TRIM(HCPCS_CODE)) > 0;

-- ============================================================
-- Validation
-- ============================================================

SELECT COUNT(*) AS STAGE_ROW_COUNT
FROM MEDICAID_PROVIDER_SPENDING_STAGE;
