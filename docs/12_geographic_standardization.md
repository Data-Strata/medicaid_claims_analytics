📄 13_geographic_standardization.md
## U.S. State Standardization for NPI_DIM (MODEL Layer)

## 🟦 Overview
The NPI Registry contains highly inconsistent geographic fields (PRACTICE_STATE, MAILING_STATE) including:
- Full addresses
- Countries and provinces
- APO/FPO military codes
- ZIP codes
- Misspellings
- Non‑U.S. regions
- Mixed formats (e.g., “CA”, “California”, “CA, 94566”, “ONTARIO”, “TOKYO”)

To support reliable geographic analytics in Power BI, the MODEL layer implements a standardized U.S. state extraction process.
This document describes:
- The problem
- The standardization approach
- The SQL logic
- The new fields created
- Validation steps
- Downstream usage

## 🚨 Problem Summary
The raw NPI fields contain thousands of unique values, many of which are not U.S. states.
Examples include:
“ABU DHABI”, “TOKYO”, “BRITISH COLUMBIA”
“APO AE”, “FPO AP”, “ARMED FORCES EUROPE”
“MIAMI, FLORIDA”, “CA, 94566”
“UNKNOWN”, “N/A”, “FOREIGN”

Power BI cannot geocode these values, causing:
- Maps to zoom out globally
- Incorrect shading
- Failed cross‑filtering
- Inconsistent provider location analytics

## 🎯 Standardization Approach
A three‑step process was implemented in the Snowflake MODEL layer:

1. Create a canonical U.S. state reference table (STATE_REF)
Contains all 50 state abbreviations.

2. Extract valid U.S. states using REGEXP + lookup matching
Logic matches:
- Exact abbreviations (e.g., “FL”)
- Tokens inside longer strings (e.g., “MIAMI, FLORIDA”)
- Full state names (e.g., “FLORIDA”)

3. Create three new standardized fields
| Field                 | Description 									   |
| --------------------- | ------------------------------------------------ |
| ``PRACTICE_STATE_US`` | Cleaned U.S. state extracted from PRACTICE_STATE |
| ``MAILING_STATE_US``  | Cleaned U.S. state extracted from MAILING_STATE  |
| ``PROVIDER_STATE_US`` | Unified state field used by Power BI             |

🧩 SQL Implementation
The full SQL script is stored in:
```sql
/sql/clean_provider_states.sql
```

This script:
- Creates `STATE_REF`
- Adds new columns to 'NPI_DIM`
- Performs JOIN‑based REGEXP extraction
- Populates unified `PROVIDER_STATE_US`
- Includes validation queries

🧪 Validation
After running the script:

✔ Check unmatched practice states
```sql
SELECT PRACTICE_STATE
FROM NPI_DIM
WHERE PRACTICE_STATE_US IS NULL;
```

✔ Check unmatched mailing states
```sql
SELECT MAILING_STATE
FROM NPI_DIM
WHERE MAILING_STATE_US IS NULL;
```

✔ Check final distribution
```sql
SELECT PROVIDER_STATE_US, COUNT(*)
FROM NPI_DIM
GROUP BY 1
ORDER BY 2 DESC;
```

📊 Downstream Usage (Power BI)
Power BI uses:
```code
NPI_DIM.PROVIDER_STATE_US
```
as the Location field for:
- Filled Map
- Tree Map
- State‑level rollups
- Provider distribution analytics

This ensures:
- Correct U.S. zoom level
- Accurate shading
- Clean cross‑filtering
- Reliable geographic insights

📌 Why This Matters
Standardizing provider geography is essential for Medicaid analytics:
- Enables state‑level spending analysis
- Supports provider distribution heatmaps
- Improves BI model reliability
- Eliminates global noise from foreign addresses
- Ensures reproducibility and auditability

This transformation elevates the MODEL layer to production‑grade quality and supports executive‑level reporting.

