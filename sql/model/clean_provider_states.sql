-- clean_provider_states.sql
------------------------------------------------------------
-- 1. CREATE U.S. STATE REFERENCE TABLE
------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.STATE_REF AS
SELECT *
FROM VALUES
    ('AL'),('AK'),('AZ'),('AR'),('CA'),('CO'),('CT'),('DE'),('FL'),('GA'),
    ('HI'),('ID'),('IL'),('IN'),('IA'),('KS'),('KY'),('LA'),('ME'),('MD'),
    ('MA'),('MI'),('MN'),('MS'),('MO'),('MT'),('NE'),('NV'),('NH'),('NJ'),
    ('NM'),('NY'),('NC'),('ND'),('OH'),('OK'),('OR'),('PA'),('RI'),('SC'),
    ('SD'),('TN'),('TX'),('UT'),('VT'),('VA'),('WA'),('WV'),('WI'),('WY')
AS STATE_REF(STATE_ABBR);

------------------------------------------------------------
-- 2. ADD CLEANED STATE COLUMNS TO NPI_DIM
------------------------------------------------------------
ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
ADD COLUMN PRACTICE_STATE_US VARCHAR;

ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
ADD COLUMN MAILING_STATE_US VARCHAR;

ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
ADD COLUMN PROVIDER_STATE_US VARCHAR;

------------------------------------------------------------
-- 3. POPULATE PRACTICE_STATE_US USING JOIN-BASED UPDATE
------------------------------------------------------------
UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM n
SET PRACTICE_STATE_US = m.STATE_ABBR
FROM (
    SELECT 
        npi.NPI,
        s.STATE_ABBR
    FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM npi
    JOIN ANALYTICS_MEDICAID.MODEL.STATE_REF s
        ON 
            UPPER(npi.PRACTICE_STATE) = s.STATE_ABBR
            OR REGEXP_LIKE(UPPER(npi.PRACTICE_STATE), '\\b' || s.STATE_ABBR || '\\b')
            OR REGEXP_LIKE(UPPER(npi.PRACTICE_STATE),
                CASE 
                    WHEN s.STATE_ABBR = 'AL' THEN 'ALABAMA'
                    WHEN s.STATE_ABBR = 'AK' THEN 'ALASKA'
                    WHEN s.STATE_ABBR = 'AZ' THEN 'ARIZONA'
                    WHEN s.STATE_ABBR = 'AR' THEN 'ARKANSAS'
                    WHEN s.STATE_ABBR = 'CA' THEN 'CALIFORNIA'
                    WHEN s.STATE_ABBR = 'CO' THEN 'COLORADO'
                    WHEN s.STATE_ABBR = 'CT' THEN 'CONNECTICUT'
                    WHEN s.STATE_ABBR = 'DE' THEN 'DELAWARE'
                    WHEN s.STATE_ABBR = 'FL' THEN 'FLORIDA'
                    WHEN s.STATE_ABBR = 'GA' THEN 'GEORGIA'
                    WHEN s.STATE_ABBR = 'HI' THEN 'HAWAII'
                    WHEN s.STATE_ABBR = 'ID' THEN 'IDAHO'
                    WHEN s.STATE_ABBR = 'IL' THEN 'ILLINOIS'
                    WHEN s.STATE_ABBR = 'IN' THEN 'INDIANA'
                    WHEN s.STATE_ABBR = 'IA' THEN 'IOWA'
                    WHEN s.STATE_ABBR = 'KS' THEN 'KANSAS'
                    WHEN s.STATE_ABBR = 'KY' THEN 'KENTUCKY'
                    WHEN s.STATE_ABBR = 'LA' THEN 'LOUISIANA'
                    WHEN s.STATE_ABBR = 'ME' THEN 'MAINE'
                    WHEN s.STATE_ABBR = 'MD' THEN 'MARYLAND'
                    WHEN s.STATE_ABBR = 'MA' THEN 'MASSACHUSETTS'
                    WHEN s.STATE_ABBR = 'MI' THEN 'MICHIGAN'
                    WHEN s.STATE_ABBR = 'MN' THEN 'MINNESOTA'
                    WHEN s.STATE_ABBR = 'MS' THEN 'MISSISSIPPI'
                    WHEN s.STATE_ABBR = 'MO' THEN 'MISSOURI'
                    WHEN s.STATE_ABBR = 'MT' THEN 'MONTANA'
                    WHEN s.STATE_ABBR = 'NE' THEN 'NEBRASKA'
                    WHEN s.STATE_ABBR = 'NV' THEN 'NEVADA'
                    WHEN s.STATE_ABBR = 'NH' THEN 'NEW HAMPSHIRE'
                    WHEN s.STATE_ABBR = 'NJ' THEN 'NEW JERSEY'
                    WHEN s.STATE_ABBR = 'NM' THEN 'NEW MEXICO'
                    WHEN s.STATE_ABBR = 'NY' THEN 'NEW YORK'
                    WHEN s.STATE_ABBR = 'NC' THEN 'NORTH CAROLINA'
                    WHEN s.STATE_ABBR = 'ND' THEN 'NORTH DAKOTA'
                    WHEN s.STATE_ABBR = 'OH' THEN 'OHIO'
                    WHEN s.STATE_ABBR = 'OK' THEN 'OKLAHOMA'
                    WHEN s.STATE_ABBR = 'OR' THEN 'OREGON'
                    WHEN s.STATE_ABBR = 'PA' THEN 'PENNSYLVANIA'
                    WHEN s.STATE_ABBR = 'RI' THEN 'RHODE ISLAND'
                    WHEN s.STATE_ABBR = 'SC' THEN 'SOUTH CAROLINA'
                    WHEN s.STATE_ABBR = 'SD' THEN 'SOUTH DAKOTA'
                    WHEN s.STATE_ABBR = 'TN' THEN 'TENNESSEE'
                    WHEN s.STATE_ABBR = 'TX' THEN 'TEXAS'
                    WHEN s.STATE_ABBR = 'UT' THEN 'UTAH'
                    WHEN s.STATE_ABBR = 'VT' THEN 'VERMONT'
                    WHEN s.STATE_ABBR = 'VA' THEN 'VIRGINIA'
                    WHEN s.STATE_ABBR = 'WA' THEN 'WASHINGTON'
                    WHEN s.STATE_ABBR = 'WV' THEN 'WEST VIRGINIA'
                    WHEN s.STATE_ABBR = 'WI' THEN 'WISCONSIN'
                    WHEN s.STATE_ABBR = 'WY' THEN 'WYOMING'
                END
            )
) m
WHERE n.NPI = m.NPI;

------------------------------------------------------------
-- 4. POPULATE MAILING_STATE_US USING JOIN-BASED UPDATE
------------------------------------------------------------
UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM n
SET MAILING_STATE_US = m.STATE_ABBR
FROM (
    SELECT 
        npi.NPI,
        s.STATE_ABBR
    FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM npi
    JOIN ANALYTICS_MEDICAID.MODEL.STATE_REF s
        ON 
            UPPER(npi.MAILING_STATE) = s.STATE_ABBR
            OR REGEXP_LIKE(UPPER(npi.MAILING_STATE), '\\b' || s.STATE_ABBR || '\\b')
            OR REGEXP_LIKE(UPPER(npi.MAILING_STATE),
                CASE 
                    WHEN s.STATE_ABBR = 'AL' THEN 'ALABAMA'
                    WHEN s.STATE_ABBR = 'AK' THEN 'ALASKA'
                    WHEN s.STATE_ABBR = 'AZ' THEN 'ARIZONA'
                    WHEN s.STATE_ABBR = 'AR' THEN 'ARKANSAS'
                    WHEN s.STATE_ABBR = 'CA' THEN 'CALIFORNIA'
                    WHEN s.STATE_ABBR = 'CO' THEN 'COLORADO'
                    WHEN s.STATE_ABBR = 'CT' THEN 'CONNECTICUT'
                    WHEN s.STATE_ABBR = 'DE' THEN 'DELAWARE'
                    WHEN s.STATE_ABBR = 'FL' THEN 'FLORIDA'
                    WHEN s.STATE_ABBR = 'GA' THEN 'GEORGIA'
                    WHEN s.STATE_ABBR = 'HI' THEN 'HAWAII'
                    WHEN s.STATE_ABBR = 'ID' THEN 'IDAHO'
                    WHEN s.STATE_ABBR = 'IL' THEN 'ILLINOIS'
                    WHEN s.STATE_ABBR = 'IN' THEN 'INDIANA'
                    WHEN s.STATE_ABBR = 'IA' THEN 'IOWA'
                    WHEN s.STATE_ABBR = 'KS' THEN 'KANSAS'
                    WHEN s.STATE_ABBR = 'KY' THEN 'KENTUCKY'
                    WHEN s.STATE_ABBR = 'LA' THEN 'LOUISIANA'
                    WHEN s.STATE_ABBR = 'ME' THEN 'MAINE'
                    WHEN s.STATE_ABBR = 'MD' THEN 'MARYLAND'
                    WHEN s.STATE_ABBR = 'MA' THEN 'MASSACHUSETTS'
                    WHEN s.STATE_ABBR = 'MI' THEN 'MICHIGAN'
                    WHEN s.STATE_ABBR = 'MN' THEN 'MINNESOTA'
                    WHEN s.STATE_ABBR = 'MS' THEN 'MISSISSIPPI'
                    WHEN s.STATE_ABBR = 'MO' THEN 'MISSOURI'
                    WHEN s.STATE_ABBR = 'MT' THEN 'MONTANA'
                    WHEN s.STATE_ABBR = 'NE' THEN 'NEBRASKA'
                    WHEN s.STATE_ABBR = 'NV' THEN 'NEVADA'
                    WHEN s.STATE_ABBR = 'NH' THEN 'NEW HAMPSHIRE'
                    WHEN s.STATE_ABBR = 'NJ' THEN 'NEW JERSEY'
                    WHEN s.STATE_ABBR = 'NM' THEN 'NEW MEXICO'
                    WHEN s.STATE_ABBR = 'NY' THEN 'NEW YORK'
                    WHEN s.STATE_ABBR = 'NC' THEN 'NORTH CAROLINA'
                    WHEN s.STATE_ABBR = 'ND' THEN 'NORTH DAKOTA'
                    WHEN s.STATE_ABBR = 'OH' THEN 'OHIO'
                    WHEN s.STATE_ABBR = 'OK' THEN 'OKLAHOMA'
                    WHEN s.STATE_ABBR = 'OR' THEN 'OREGON'
                    WHEN s.STATE_ABBR = 'PA' THEN 'PENNSYLVANIA'
                    WHEN s.STATE_ABBR = 'RI' THEN 'RHODE ISLAND'
                    WHEN s.STATE_ABBR = 'SC' THEN 'SOUTH CAROLINA'
                    WHEN s.STATE_ABBR = 'SD' THEN 'SOUTH DAKOTA'
                    WHEN s.STATE_ABBR = 'TN' THEN 'TENNESSEE'
                    WHEN s.STATE_ABBR = 'TX' THEN 'TEXAS'
                    WHEN s.STATE_ABBR = 'UT' THEN 'UTAH'
                    WHEN s.STATE_ABBR = 'VT' THEN 'VERMONT'
                    WHEN s.STATE_ABBR = 'VA' THEN 'VIRGINIA'
                    WHEN s.STATE_ABBR = 'WA' THEN 'WASHINGTON'
                    WHEN s.STATE_ABBR = 'WV' THEN 'WEST VIRGINIA'
                    WHEN s.STATE_ABBR = 'WI' THEN 'WISCONSIN'
                    WHEN s.STATE_ABBR = 'WY' THEN 'WYOMING'
                END
            )
) m
WHERE n.NPI = m.NPI;

------------------------------------------------------------
-- 5. POPULATE UNIFIED PROVIDER_STATE_US
------------------------------------------------------------
UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM
SET PROVIDER_STATE_US = COALESCE(PRACTICE_STATE_US, MAILING_STATE_US);

------------------------------------------------------------
-- 6. VALIDATION QUERIES
------------------------------------------------------------

-- Unmatched practice states
SELECT PRACTICE_STATE
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
WHERE PRACTICE_STATE_US IS NULL
LIMIT 200;

-- Unmatched mailing states
SELECT MAILING_STATE
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
WHERE MAILING_STATE_US IS NULL
LIMIT 200;

-- Final distribution
SELECT PROVIDER_STATE_US, COUNT(*)
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
GROUP BY 1
ORDER BY 2 DESC;
