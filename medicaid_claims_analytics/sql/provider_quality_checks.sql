-- sql/provider_quality_checks.sql
-- Provider (NPI Registry) Quality Checks
-- Validates RAW → CLEAN → DIM row consistency and referential integrity.

------------------------------------------------------------
-- 1. Row Count Checks
------------------------------------------------------------
SELECT COUNT(*) AS RAW_COUNT
FROM NPI_RAW;

SELECT COUNT(*) AS CLEAN_COUNT
FROM PROVIDER_CLEAN;

SELECT COUNT(*) AS DIM_COUNT
FROM DIM_PROVIDER;

------------------------------------------------------------
-- 2. Duplicate NPI Checks (Before DIM)
------------------------------------------------------------
SELECT NPI, COUNT(*) AS DUP_COUNT
FROM PROVIDER_CLEAN
GROUP BY NPI
HAVING COUNT(*) > 1;

------------------------------------------------------------
-- 3. Null or Malformed NPI Checks
------------------------------------------------------------
SELECT COUNT(*) AS NULL_NPI_COUNT
FROM PROVIDER_CLEAN
WHERE NPI IS NULL;

------------------------------------------------------------
-- 4. Orphan NPIs in Medicaid Fact Table
-- (Providers appearing in Medicaid but missing in DIM_PROVIDER)
------------------------------------------------------------
SELECT DISTINCT s.BILLING_PROVIDER_NPI_NUM AS ORPHAN_NPI
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE s
WHERE s.BILLING_PROVIDER_NPI_NUM NOT IN (
    SELECT NPI FROM DIM_PROVIDER
);
