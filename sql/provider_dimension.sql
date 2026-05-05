-- ============================================================
-- PROVIDER DIMENSION TABLE (ANALYTICS LAYER)
-- Deduplicates by NPI using LAST_UPDATE_DATE
-- ============================================================

USE DATABASE ANALYTICS_MEDICAID;
USE SCHEMA MODEL;

CREATE OR REPLACE TABLE NPI_DIM AS
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY NPI
            ORDER BY 
                LAST_UPDATE_DATE DESC NULLS LAST,
                ENUMERATION_DATE DESC NULLS LAST,
                NPI DESC
        ) AS rn
    FROM STAGE_MEDICAID.CLEAN.NPI_CLEAN
)
SELECT
    NPI,
    ENTITY_TYPE_CODE,
    REPLACEMENT_NPI,
    ORG_NAME,
    LAST_NAME,
    FIRST_NAME,
    MIDDLE_NAME,
    CREDENTIALS,
    FULL_NAME,
    MAILING_CITY,
    MAILING_STATE,
    MAILING_ZIP,
    PRACTICE_CITY,
    PRACTICE_STATE,
    PRACTICE_ZIP,
    ENUMERATION_DATE,
    LAST_UPDATE_DATE,
    GENDER,
    PRIMARY_TAXONOMY_CODE
FROM ranked
WHERE rn = 1;

-- Validation
SELECT COUNT(*) AS DIM_ROW_COUNT FROM NPI_DIM;

-- ============================================================
-- CLUSTERING: NPI_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
  CLUSTER BY (NPI);

-- ============================================================
-- PRIMARY KEY: NPI_DIM
-- ============================================================
ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
  ADD CONSTRAINT PK_NPI_DIM PRIMARY KEY (NPI);

-- ============================================================
-- FOREIGN KEYS (DOCUMENTATION ONLY)
-- ============================================================
-- None here; FACT table references NPI_DIM, not vice‑versa.


-- Quality Check:
SELECT COUNT(*) AS TOTAL_ROWS,
       COUNT(DISTINCT NPI) AS UNIQUE_NPIS
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM;

