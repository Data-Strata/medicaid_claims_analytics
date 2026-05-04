-- ============================================================
-- HCPCS CLEAN TABLE (STAGING LAYER)
-- Extracts only the fields needed for analytics
-- ============================================================

USE DATABASE STAGE_MEDICAID;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE HCPCS_CLEAN AS
SELECT
    UPPER(TRIM(HCPC))              AS HCPCS_CODE,
    TRIM(LONG_DESCRIPTION)         AS DESCRIPTION,
    TRIM(SHORT_DESCRIPTION)        AS SHORT_DESCRIPTION,
    TRIM(ACTION_CD)                AS STATUS,
    TRY_TO_DATE(ACT_EFF_DT)        AS EFFECTIVE_DATE,
    TRY_TO_DATE(TERM_DT)           AS TERMINATION_DATE
FROM HCPCS_RAW_WIDE
WHERE HCPC IS NOT NULL;

-- Quality checks
SELECT 
    COUNT(*) AS CLEAN_ROW_COUNT,
    COUNT(DISTINCT HCPCS_CODE) AS DISTINCT_CODES
FROM HCPCS_CLEAN;
