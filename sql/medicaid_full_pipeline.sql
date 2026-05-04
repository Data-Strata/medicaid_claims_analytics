
-- ============================================================
-- FULL MEDICAID PIPELINE (RAW → STAGE → FACT)
-- only works if you use SnowSQL !source commands.
-- ============================================================

!source medicaid_ingestion_raw.sql;
!source medicaid_clean_stage.sql;
!source medicaid_fact_table.sql;
!source medicaid_quality_checks.sql;
