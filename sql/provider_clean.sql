-- ============================================================
-- PROVIDER CLEAN TABLE (STAGE LAYER)
-- Extracts key 19 fields from 330-column NPI_RAW
-- Standardizes names, taxonomy, and dates
-- ============================================================

USE DATABASE STAGE_MEDICAID;
USE SCHEMA CLEAN;

CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.NPI_CLEAN AS
SELECT
    -- Core identifiers
    LPAD(TRIM(NPI), 10, '0')                                                AS NPI,
    TRIM(ENTITY_TYPE_CODE)                                                  AS ENTITY_TYPE_CODE,
    TRIM(REPLACEMENT_NPI)                                                   AS REPLACEMENT_NPI,

    -- Organization / individual names
    TRIM(PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME)                    AS ORG_NAME,
    TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)                                     AS LAST_NAME,
    TRIM(PROVIDER_FIRST_NAME)                                               AS FIRST_NAME,
    TRIM(PROVIDER_MIDDLE_NAME)                                              AS MIDDLE_NAME,
    TRIM(PROVIDER_CREDENTIAL_TEXT)                                          AS CREDENTIALS,

    -- Full name (individuals only)
    TRIM(
        CONCAT_WS(' ',
            TRIM(PROVIDER_FIRST_NAME),
            TRIM(PROVIDER_MIDDLE_NAME),
            TRIM(PROVIDER_LAST_NAME_LEGAL_NAME)
        )
    )                                                                       AS FULL_NAME,

    -- Mailing address (ZIP normalized)
    TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME)                       AS MAILING_CITY,
    TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME)                      AS MAILING_STATE,
    CASE
        WHEN REGEXP_LIKE(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
            THEN SUBSTR(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, 1, 5)
        ELSE NULL
    END                                                                     AS MAILING_ZIP,

    -- Practice address (ZIP normalized)
    TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME)             AS PRACTICE_CITY,
    TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME)            AS PRACTICE_STATE,
    CASE
        WHEN REGEXP_LIKE(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
            THEN SUBSTR(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, 1, 5)
        ELSE NULL
    END                                                                     AS PRACTICE_ZIP,

    -- Dates
    TRY_TO_DATE(PROVIDER_ENUMERATION_DATE)                                  AS ENUMERATION_DATE,
    TRY_TO_DATE(LAST_UPDATE_DATE)                                           AS LAST_UPDATE_DATE,

    -- Gender
    TRIM(PROVIDER_SEX_CODE)                                                 AS GENDER,

    -- Primary taxonomy
    CASE
        WHEN HEALTHCARE_PROVIDER_PRIMARY_TAXONOMY_SWITCH_1 = 'Y'
            THEN TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
        ELSE TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1)
    END                                                                     AS PRIMARY_TAXONOMY_CODE

FROM RAW_MEDICAID.PUBLIC.NPI_RAW;


-- Validation
SELECT COUNT(*) AS CLEAN_ROW_COUNT FROM NPI_CLEAN;
