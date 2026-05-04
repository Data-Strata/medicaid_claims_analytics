-- ============================================================
-- FULL HCPCS PIPELINE (RAW → CLEAN → DIM) 
-- only works if you use SnowSQL !source commands.
-- ============================================================

-- RAW
!source hcpcs_ingestion_raw.sql;

-- CLEAN
!source hcpcs_clean.sql;

-- DIM
!source hcpcs_dimension.sql;

-- QC
!source hcpcs_quality_checks.sql;
