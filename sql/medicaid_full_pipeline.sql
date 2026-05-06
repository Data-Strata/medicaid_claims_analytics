
-- ============================================================
-- FULL MEDICAID PIPELINE (RAW → STAGE → FACT)
-- only works if you use SnowSQL !source commands.
-- ============================================================

-- RAW
!source medicaid_ingestion_raw.sql;

-- CLEAN
!source medicaid_clean_stage.sql;

-- Creates DATE_DIM and SERVICE_CATEGORY_DIM for Power BI modeling  
!source date_and_service_dimensions.sql 

-- CREATE FACT TABLE THAT CONNECTS TO MODEL DIMENSION TABLES 
!source medicaid_fact_table.sql;

-- VALIDATE
!source medicaid_quality_checks.sql;
