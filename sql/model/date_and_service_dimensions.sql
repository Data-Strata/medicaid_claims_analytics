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

CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.DATE_DIM AS
WITH RECURSIVE dates AS (
    SELECT DATE('2018-01-01') AS dt
    UNION ALL
    SELECT DATEADD(day, 1, dt)
    FROM dates
    WHERE dt < DATE('2027-12-31')
)
SELECT
    /* -------------------------
       Core Date Fields
    ------------------------- */
    dt AS DATE_KEY,                         -- Must be DATE (not TIMESTAMP)
    YEAR(dt) AS YEAR,
    MONTH(dt) AS MONTH,
    DAY(dt) AS DAY,

    /* -------------------------
       Year-Month (sortable)
    ------------------------- */
    TO_VARCHAR(dt, 'YYYYMM') AS YEAR_MONTH, -- Used for axis labels

    /* -------------------------
       Calendar Attributes
    ------------------------- */
    DAYOFWEEK(dt) AS DAY_OF_WEEK,
    WEEKOFYEAR(dt) AS WEEK_OF_YEAR,
    QUARTER(dt) AS QUARTER,

    /* -------------------------
       Additional Useful Fields
    ------------------------- */
    TO_VARCHAR(dt, 'YYYY-MM-DD') AS DATE_TEXT,
    TO_VARCHAR(dt, 'Mon YYYY') AS MONTH_NAME_YEAR,
    TO_VARCHAR(dt, 'YYYY') || '-' || LPAD(MONTH(dt), 2, '0') AS YEAR_MONTH_TEXT

FROM dates
ORDER BY dt;


-- ============================================================
-- 2. SERVICE_CATEGORY_DIM
-- ============================================================

CREATE OR REPLACE TABLE SERVICE_CATEGORY_DIM (
    CATEGORY_KEY      INTEGER,
    SERVICE_CATEGORY  VARCHAR(10),
    DESCRIPTION       VARCHAR(50)
);

INSERT INTO SERVICE_CATEGORY_DIM (CATEGORY_KEY, SERVICE_CATEGORY, DESCRIPTION)
VALUES
    (1, 'ED',    'Emergency Department'),
    (2, 'IP',    'Inpatient'),
    (3, 'OP',    'Outpatient'),
    (4, 'RX',    'Pharmacy'),
    (5, 'OTHER', 'Uncategorized');


-- ============================================================
-- End of File
-- ============================================================
