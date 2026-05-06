-- ============================================================
-- sql/provider_full_pipeline.sql
-- Full Provider (NPI Registry) (RAW → CLEAN → DIM) 
-- only works if you use SnowSQL !source commands.
-- ============================================================

-- RAW
!source provider_ingestion_raw.sql;

-- CLEAN
!source provider_clean.sql;

-- DIM
!source provider_dimension.sql;

-- STANDARIZE STATES
!source model/clean_provider_states.sql

-- VALIDATE
!source provider_quality_checks.sql;

