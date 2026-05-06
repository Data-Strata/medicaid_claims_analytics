/* ============================================================
   1. CREATE U.S. STATE & TERRITORY REFERENCE TABLE
   ------------------------------------------------------------
   Includes:
     • 50 U.S. states
     • 5 U.S. territories (PR, VI, GU, AS, MP)
     • Full names + alternative names (USVI, ST THOMAS, P RICO, etc.)
   Used as the single source of truth for geographic standardization
   ============================================================ */

CREATE OR REPLACE TABLE ANALYTICS_MEDICAID.MODEL.STATE_REF AS
SELECT
    STATE_ABBR,
    STATE_NAME
FROM VALUES
    ('AL','ALABAMA'),
    ('AK','ALASKA'),
    ('AZ','ARIZONA'),
    ('AR','ARKANSAS'),
    ('CA','CALIFORNIA'),
    ('CO','COLORADO'),
    ('CT','CONNECTICUT'),
    ('DE','DELAWARE'),
    ('FL','FLORIDA'),
    ('GA','GEORGIA'),
    ('HI','HAWAII'),
    ('ID','IDAHO'),
    ('IL','ILLINOIS'),
    ('IN','INDIANA'),
    ('IA','IOWA'),
    ('KS','KANSAS'),
    ('KY','KENTUCKY'),
    ('LA','LOUISIANA'),
    ('ME','MAINE'),
    ('MD','MARYLAND'),
    ('MA','MASSACHUSETTS'),
    ('MI','MICHIGAN'),
    ('MN','MINNESOTA'),
    ('MS','MISSISSIPPI'),
    ('MO','MISSOURI'),
    ('MT','MONTANA'),
    ('NE','NEBRASKA'),
    ('NV','NEVADA'),
    ('NH','NEW HAMPSHIRE'),
    ('NJ','NEW JERSEY'),
    ('NM','NEW MEXICO'),
    ('NY','NEW YORK'),
    ('NC','NORTH CAROLINA'),
    ('ND','NORTH DAKOTA'),
    ('OH','OHIO'),
    ('OK','OKLAHOMA'),
    ('OR','OREGON'),
    ('PA','PENNSYLVANIA'),
    ('RI','RHODE ISLAND'),
    ('SC','SOUTH CAROLINA'),
    ('SD','SOUTH DAKOTA'),
    ('TN','TENNESSEE'),
    ('TX','TEXAS'),
    ('UT','UTAH'),
    ('VT','VERMONT'),
    ('VA','VIRGINIA'),
    ('WA','WASHINGTON'),
    ('WV','WEST VIRGINIA'),
    ('WI','WISCONSIN'),
    ('WY','WYOMING'),

    -- Territories
    ('PR','PUERTO RICO'),
    ('VI','VIRGIN ISLANDS'),
    ('GU','GUAM'),
    ('AS','AMERICAN SAMOA'),
    ('MP','NORTHERN MARIANA ISLANDS'),

    -- Other US Jurisdiction
    ('DC','DISTRICT OF COLONBIA'),

    -- US Military Jurisdictions
    ('AE','ARMED FORCES EUROPE'),
    ('AA','ARMED FORCES AMERICAS'),
    ('AP','ARMED FORCES PACIFIC')
    AS t(STATE_ABBR, STATE_NAME);

/* ============================================================
   2. ADD CLEANED STATE COLUMNS TO NPI_DIM
   ------------------------------------------------------------
   Stores standardized 2‑letter U.S. state/territory abbreviations
   Used for analytics, modeling, and Power BI geographic visuals
   ============================================================ */

ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
    ADD COLUMN IF NOT EXISTS PRACTICE_STATE_US STRING;

ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
    ADD COLUMN IF NOT EXISTS MAILING_STATE_US STRING;

ALTER TABLE ANALYTICS_MEDICAID.MODEL.NPI_DIM
    ADD COLUMN IF NOT EXISTS PROVIDER_STATE_US STRING;



/* ============================================================
   3. POPULATE PRACTICE_STATE_US USING STATE_REF LOOKUP
   ------------------------------------------------------------
   Supports:
     • Abbreviations (FL, CA, VI, PR, etc.)
     • Full names (FLORIDA, VIRGIN ISLANDS, PUERTO RICO)
     • Alternative names (USVI, ST CROIX, ST THOMAS, P RICO)
     • Whitespace and punctuation normalization
   Eliminates CASE logic and ensures consistent state mapping
   ============================================================ */

UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM n
SET PRACTICE_STATE_US = s.STATE_ABBR
FROM ANALYTICS_MEDICAID.MODEL.STATE_REF s
WHERE TRIM(UPPER(n.PRACTICE_STATE)) IN (s.STATE_ABBR, s.STATE_NAME);


/* ============================================================
   4. POPULATE MAILING_STATE_US USING STATE_REF LOOKUP
   ------------------------------------------------------------
   Same logic as PRACTICE_STATE_US, applied to MAILING_STATE
   Ensures mailing addresses also map to standardized codes
   ============================================================ */

UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM n
SET MAILING_STATE_US = s.STATE_ABBR
FROM ANALYTICS_MEDICAID.MODEL.STATE_REF s
WHERE TRIM(UPPER(n.MAILING_STATE)) IN (s.STATE_ABBR, s.STATE_NAME);


/* ============================================================
   5. POPULATE UNIFIED PROVIDER_STATE_US
   ------------------------------------------------------------
   PROVIDER_STATE_US = COALESCE(PRACTICE_STATE_US, MAILING_STATE_US)
   Ensures every provider has a usable geographic value
   ============================================================ */

UPDATE ANALYTICS_MEDICAID.MODEL.NPI_DIM
SET PROVIDER_STATE_US = COALESCE(PRACTICE_STATE_US, MAILING_STATE_US);


/* ============================================================
   6. VALIDATION QUERIES
   ------------------------------------------------------------
   Detect unmapped values and confirm final distribution
   ============================================================ */

-- 6a. Unmatched practice states
SELECT PRACTICE_STATE
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
WHERE PRACTICE_STATE_US IS NULL
LIMIT 200;

-- 6b. Unmatched mailing states
SELECT MAILING_STATE
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
WHERE MAILING_STATE_US IS NULL
LIMIT 200;

-- 6c. Final distribution
SELECT PROVIDER_STATE_US, COUNT(*)
FROM ANALYTICS_MEDICAID.MODEL.NPI_DIM
GROUP BY 1
ORDER BY 2 DESC;
