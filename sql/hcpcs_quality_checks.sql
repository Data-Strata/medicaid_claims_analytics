-- ============================================================
-- HCPCS QUALITY CHECKS
-- ============================================================

USE DATABASE RAW_MEDICAID;
USE SCHEMA PUBLIC;

-- Validate the RAW → CLEAN → DIM row counts are consistent
SELECT COUNT(*) FROM HCPCS_RAW_WIDE;

-- No rows were lost during transformation
SELECT COUNT(*) FROM HCPCS_CLEAN;

-- The dimension contains one row per HCPCS code
SELECT COUNT(*) FROM HCPCS_DIM;

-- Null codes
SELECT COUNT(*) AS NULL_CODES
FROM HCPCS_CLEAN
WHERE HCPCS_CODE IS NULL;

-- Duplicate codes before DIM
SELECT HCPCS_CODE, COUNT(*) AS ROWS
FROM HCPCS_CLEAN
GROUP BY HCPCS_CODE
HAVING COUNT(*) > 1;

-- Orphan codes in Medicaid fact table
SELECT DISTINCT s.HCPCS_CODE
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE s
WHERE s.HCPCS_CODE NOT IN (
    SELECT HCPCS_CODE FROM ANALYTICS_MEDICAID.MODEL.HCPCS_DIM
);
