-- ============================================================
-- HCPCS DIMENSION TABLE (ANALYTICS LAYER)
-- Deduplicates by HCPCS_CODE using EFFECTIVE_DATE
-- ============================================================

USE DATABASE ANALYTICS_MEDICAID;
USE SCHEMA MODEL;

CREATE OR REPLACE TABLE HCPCS_DIM AS
SELECT
    HCPCS_CODE,
    DESCRIPTION,
    SHORT_DESCRIPTION,
    STATUS,
    EFFECTIVE_DATE,
    TERMINATION_DATE
FROM STAGE_MEDICAID.CLEAN.HCPCS_CLEAN
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY HCPCS_CODE
    ORDER BY EFFECTIVE_DATE DESC NULLS LAST
) = 1;

-- Dimension validation
SELECT COUNT(*) AS DIM_ROW_COUNT FROM HCPCS_DIM;

-- ============================================================
-- CLUSTERING: HCPCS_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.HCPCS_DIM
  CLUSTER BY (HCPCS_CODE);

-- ============================================================
-- PRIMARY KEY: HCPCS_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.HCPCS_DIM
  ADD CONSTRAINT PK_HCPCS_DIM PRIMARY KEY (HCPCS_CODE);

-- ============================================================
-- FOREIGN KEYS (DOCUMENTATION ONLY)
-- ============================================================
-- None here; FACT table references HCPCS_DIM.


-- Quality Check
SELECT COUNT(*) AS TOTAL_ROWS,
       COUNT(DISTINCT HCPCS_CODE) AS UNIQUE_CODES
FROM ANALYTICS_MEDICAID.MODEL.HCPCS_DIM;
