-- =====================================================================
-- Medicaid Claims Analytics — Dimension Tables
-- DATE_DIM and SERVICE_CATEGORY_DIM
-- Layer: ANALYTICS_MEDICAID.MODEL
-- Author: Mairilyn Yera Galindo
-- =====================================================================

USE DATABASE ANALYTICS_MEDICAID;
USE SCHEMA MODEL;

-- ============================================================
-- 1. DATE_DIM
-- ============================================================

CREATE OR REPLACE TABLE DATE_DIM AS
WITH dates AS (
    SELECT 
        DATEADD(day, seq4(), '2018-01-01') AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 3650))  -- 10 years of dates
)
SELECT
    full_date AS DATE_KEY,
    YEAR(full_date) AS YEAR,
    MONTH(full_date) AS MONTH,
    DAY(full_date) AS DAY,
    TO_VARCHAR(full_date, 'YYYY-MM') AS YEAR_MONTH,
    QUARTER(full_date) AS QUARTER,
    DAYOFWEEK(full_date) AS DAY_OF_WEEK,
    WEEKOFYEAR(full_date) AS WEEK_OF_YEAR,
    CASE WHEN DAYOFWEEK(full_date) IN (6,7) THEN 'Weekend' ELSE 'Weekday' END AS WEEKDAY_FLAG
FROM dates
ORDER BY full_date;

-- ============================================================
-- 2. SERVICE_CATEGORY_DIM
-- ============================================================

CREATE OR REPLACE TABLE SERVICE_CATEGORY_DIM AS
SELECT 
    CATEGORY_KEY,
    SERVICE_CATEGORY,
    DESCRIPTION
FROM VALUES
    (1, 'ED', 'Emergency Department'),
    (2, 'IP', 'Inpatient'),
    (3, 'OP', 'Outpatient'),
    (4, 'RX', 'Pharmacy')
    AS t(CATEGORY_KEY, SERVICE_CATEGORY, DESCRIPTION);

-- ============================================================
-- End of File
-- ============================================================
