-- ============================================================
-- PROVIDER CLEAN TABLE (STAGE LAYER)
-- Extracts key 19 fields from 330-column NPI_RAW
-- Standardizes names, taxonomy, and dates
-- ============================================================

USE DATABASE STAGE_MEDICAID;
USE SCHEMA CLEAN;

CREATE OR REPLACE TABLE STAGE_MEDICAID.CLEAN.NPI_CLEAN AS
WITH CLEANED AS (
    SELECT
        /* ---------------------------------------------------------
           Core Identifiers
        --------------------------------------------------------- */
        LPAD(TRIM(NPI), 10, '0')                                                            AS NPI,
        NULLIF(TRIM(ENTITY_TYPE_CODE), '')                                                  AS ENTITY_TYPE_CODE,
        NULLIF(TRIM(REPLACEMENT_NPI), '')                                                   AS REPLACEMENT_NPI,

/* ---------------------------------------------------------
           Name Cleaning Rules
           - Strip leading punctuation
           - Remove pure punctuation/digit names
           - Collapse repeated punctuation
           - Remove credentials after commas
           - Normalize whitespace
        --------------------------------------------------------- */

        /* FIRST NAME */
         CASE
            WHEN REGEXP_LIKE(PROVIDER_FIRST_NAME, '^[0-9[:punct:]]+$') THEN NULL
            ELSE NULLIF(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            TRIM(PROVIDER_FIRST_NAME),
                            '^[[:punct:]]+', ''        -- leading punctuation
                        ),
                        '[[:punct:]]{2,}', ' '        -- repeated punctuation
                    ),
                    ',.*$', ''                        -- remove credentials after comma
                ),
            '')
        END AS FIRST_NAME,

        /* MIDDLE NAME */
        CASE
            WHEN REGEXP_LIKE(PROVIDER_MIDDLE_NAME, '^[0-9[:punct:]]+$') THEN NULL
            ELSE NULLIF(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            TRIM(PROVIDER_MIDDLE_NAME),
                            '^[[:punct:]]+', ''
                        ),
                        '[[:punct:]]{2,}', ' '
                    ),
                    ',.*$', ''
                ),
            '')
        END AS MIDDLE_NAME,

        /* LAST NAME */
        CASE
            WHEN REGEXP_LIKE(PROVIDER_LAST_NAME_LEGAL_NAME, '^[0-9[:punct:]]+$') THEN NULL
            ELSE NULLIF(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            TRIM(PROVIDER_LAST_NAME_LEGAL_NAME),
                            '^[[:punct:]]+', ''
                        ),
                        '[[:punct:]]{2,}', ' '
                    ),
                    ',.*$', ''
                ),
            '')
        END AS LAST_NAME,
        /* ORGANIZATION NAME */
        CASE
         WHEN REGEXP_LIKE(PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME, '^[0-9[:punct:]]+$') THEN NULL
            ELSE NULLIF(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                     REGEXP_REPLACE(
                           REGEXP_REPLACE(
                              TRIM(PROVIDER_ORGANIZATION_NAME_LEGAL_BUSINESS_NAME),
                             '^0+([A-Za-z])', '\\1'   -- remove leading zeros before letters
                         ),
                            '^[[:punct:]]+', ''        -- leading punctuation
                       ),
                        '[[:punct:]]{2,}', ' '        -- repeated punctuation
                 ),
                 ',.*$', ''                        -- remove credentials after comma
               ),
         '')
        END AS ORG_NAME,

        /* ---------------------------------------------------------
           Credentials
        --------------------------------------------------------- */
        NULLIF(TRIM(PROVIDER_CREDENTIAL_TEXT), '')                                          AS CREDENTIALS,

        /* ---------------------------------------------------------
           Mailing Address (ZIP normalized)
        --------------------------------------------------------- */
        NULLIF(TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_CITY_NAME), '')                       AS MAILING_CITY,
        NULLIF(TRIM(PROVIDER_BUSINESS_MAILING_ADDRESS_STATE_NAME), '')                      AS MAILING_STATE,
        CASE
            WHEN REGEXP_LIKE(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
                THEN SUBSTR(PROVIDER_BUSINESS_MAILING_ADDRESS_POSTAL_CODE, 1, 5)
            ELSE NULL
        END                                                                                 AS MAILING_ZIP,

        /* ---------------------------------------------------------
           Practice Address (ZIP normalized)
        --------------------------------------------------------- */
        NULLIF(TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_CITY_NAME), '')             AS PRACTICE_CITY,
        NULLIF(TRIM(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_STATE_NAME), '')            AS PRACTICE_STATE,
        CASE
            WHEN REGEXP_LIKE(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, '^[0-9]{5,9}$')
                THEN SUBSTR(PROVIDER_BUSINESS_PRACTICE_LOCATION_ADDRESS_POSTAL_CODE, 1, 5)
            ELSE NULL
        END                                                                                 AS PRACTICE_ZIP,

        /* ---------------------------------------------------------
           Dates
        --------------------------------------------------------- */
        TRY_TO_DATE(PROVIDER_ENUMERATION_DATE)                                              AS ENUMERATION_DATE,
        TRY_TO_DATE(LAST_UPDATE_DATE)                                                       AS LAST_UPDATE_DATE,

        /* ---------------------------------------------------------
           Gender
        --------------------------------------------------------- */
        NULLIF(TRIM(PROVIDER_SEX_CODE), '')                                                 AS GENDER,

        /* ---------------------------------------------------------
           Primary Taxonomy
        --------------------------------------------------------- */
        CASE
            WHEN HEALTHCARE_PROVIDER_PRIMARY_TAXONOMY_SWITCH_1 = 'Y'
                THEN NULLIF(TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1), '')
            ELSE NULLIF(TRIM(HEALTHCARE_PROVIDER_TAXONOMY_CODE_1), '')
        END                                                                                 AS PRIMARY_TAXONOMY_CODE

    FROM RAW_MEDICAID.PUBLIC.NPI_RAW
),

/* ---------------------------------------------------------
   Build FULL_NAME and Derived Fields
--------------------------------------------------------- */
FINAL AS (
    SELECT
        *,
        
        /* -----------------------------------------------------
           FULL_NAME 
        ----------------------------------------------------- */
        TRIM(
            CONCAT(
                FIRST_NAME,
                CASE WHEN MIDDLE_NAME IS NOT NULL THEN ' ' || MIDDLE_NAME ELSE '' END,
                CASE WHEN LAST_NAME IS NOT NULL THEN ' ' || LAST_NAME ELSE '' END
            )
        ) AS FULL_NAME,

        /* -----------------------------------------------------
           Provider_Type (Individual vs Organization)
        ----------------------------------------------------- */
        CASE
            WHEN ENTITY_TYPE_CODE = '1' THEN 'Individual'
            WHEN ENTITY_TYPE_CODE = '2' THEN 'Organization'
            ELSE NULL
        END AS PROVIDER_TYPE,

        /* -----------------------------------------------------
           Provider_Display_Name
           Priority: FULL_NAME → ORG_NAME → "Unknown Organization"
        ----------------------------------------------------- */
        CASE
            WHEN FULL_NAME IS NOT NULL THEN FULL_NAME
            WHEN ORG_NAME IS NOT NULL THEN ORG_NAME
            ELSE 'Unknown Organization'
        END AS PROVIDER_DISPLAY_NAME,

        /* -----------------------------------------------------
           Data_Quality_Flag
           Flag missing names for organizations
        ----------------------------------------------------- */
        CASE
            WHEN FULL_NAME IS NULL AND ORG_NAME IS NULL
                THEN 'NAME_MISSING_ORG'
            ELSE 'VALID'
        END AS DATA_QUALITY_FLAG

    FROM CLEANED
)


/* ---------------------------------------------------------
   Remove rows where ALL identifying fields are NULL
--------------------------------------------------------- */
SELECT *
FROM FINAL
WHERE COALESCE(
        FIRST_NAME,
        LAST_NAME,
        ORG_NAME,
        ENTITY_TYPE_CODE
    ) IS NOT NULL;



-- Validation
SELECT COUNT(*) AS CLEAN_ROW_COUNT FROM NPI_CLEAN;
