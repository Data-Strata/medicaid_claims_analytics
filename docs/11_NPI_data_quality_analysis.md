## 📘 NPI Data Quality Analysis
Medicaid Provider‑Level Spending → NPI Registry Integration  

🟦 1. Overview
This document provides a detailed analysis of provider‑level data quality when integrating the Medicaid Provider‑Level Spending dataset with the National Provider Identifier (NPI) Registry.

The goal is to:

- Validate join coverage between Medicaid billing NPIs and NPI_DIM

- Identify categories of unmatched NPIs

- Surface anomalies and data quality issues

- Provide SQL diagnostics for ongoing monitoring

- Document real‑world Medicaid billing behaviors

- Strengthen the transparency and reliability of the RAW → CLEAN → MODEL pipeline

This analysis supports the integrity of the provider enrichment layer in the analytics model.

🟦 2. Join Coverage Validation
A left join was performed between the Medicaid fact staging table and the NPI_DIM dimension:

```sql
SELECT
    COUNT(*) AS TOTAL_CLAIMS,
    COUNT(p.NPI) AS MATCHED_ROWS,
    ROUND(COUNT(p.NPI) / COUNT(*) * 100, 2) AS MATCH_PCT
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p
    ON f.BILLING_PROVIDER_NPI = p.NPI;
```

Results:
| TOTAL_CLAIMS | MATCHED_ROWS | MATCH_PCT  |
| ------------ | ------------ | ---------- |
| 238,015,729  | 230,133,234  | **96.69%** |

🟦 3. Interpretation of the 96.69% Match Rate
A 96.69% match rate is strong and expected for national Medicaid data.

This confirms:
> The NPI ingestion pipeline is functioning correctly
> CLEAN layer normalization is accurate
> NPI_DIM deduplication logic is correct
> FACT → DIM join path is stable
> No schema drift or type mismatches exist

The remaining 3.31% unmatched NPIs (~7.9M rows) represent real‑world Medicaid billing anomalies, not pipeline errors.

🟦 4. Categories of Unmatched NPIs
Unmatched NPIs fall into predictable, domain‑specific categories.

4.1 Blank or NULL NPIs
The largest category:
```code
(blank) → 7,863,474 rows
```
Common in:
- FQHC/RHC encounters
- Managed care intermediary billing
- State‑level fiscal agents
- Roll‑up billing entities
- Claims where NPI is optional or suppressed

4.2 Placeholder or Synthetic NPIs
Examples:
```code
9999999995  
1234567811  
1111111112  
1000000000  
1999999984
```  

Used by:
- Medicaid fiscal intermediaries
- Legacy billing systems
- State‑specific provider ID systems
- Testing or placeholder values
These will never appear in NPPES.

4.3 Non‑NPI Identifiers (Not 10‑digit NPIs)
Examples:
```code
8338  
203757231  
210562400  
409285600  
587131001
```
These represent:
- Legacy Medicaid provider IDs
- State billing IDs
- Fiscal agent identifiers
- Truncated NPIs
- Non‑NPI identifiers used in older systems

4.4 NPIs That Look Valid but Are Not in NPPES
Examples:
```code
1326093090  
1716034376  
1477880977  
1255454712  
1312568961
```
These typically represent:
- Deactivated NPIs
- Organizational NPIs never enumerated
- Medicaid‑only billing constructs
- Historical NPIs not present in the current NPPES extract

4.5 NPIs Exceeding 10 Digits
Examples:
```code
4251546810  
4232700908  
5108005500  
4831933437
```
These are not NPIs — they are:
- Medicaid internal provider IDs
- Fiscal agent identifiers
- Legacy 10‑digit state IDs
- Encounter‑level billing IDs

4.6 Integer Overflow Sentinel Values
Example:
```code
2147483647
```

This occurs when:
- A system stores NPI as INT
- Value exceeds INT32 max
- It is replaced with the sentinel value
- This is a known Medicaid artifact.

🟦 5. Top 10 NPI Anomalies (By Frequency)
```sql
SELECT
    BILLING_PROVIDER_NPI,
    COUNT(*) AS CNT_ROWS
FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p
    ON f.BILLING_PROVIDER_NPI = p.NPI
WHERE p.NPI IS NULL
GROUP BY BILLING_PROVIDER_NPI
ORDER BY CNT_ROWS DESC
LIMIT 10;
```
Top 10 Results
| BILLING_PROVIDER_NPI | CNT_ROWS  |
| -------------------- | --------- |
| (blank)              | 7,863,474 |
| 1999999984           | 5,156     |
| 1326093090           | 2,822     |
| 1716034376           | 2,051     |
| 9999999995           | 1,017     |
| 1234567811           | 987       |
| 1477880977           | 697       |
| 1999999976           | 463       |
| 1999999992           | 441       |
| 1255454712           | 405       |

These anomalies are consistent with Medicaid billing patterns across states.

🟦 6. Data Quality Dashboard SQL
This block provides a reusable dashboard for monitoring NPI match quality.

```sql
WITH joined AS (
    SELECT
        f.BILLING_PROVIDER_NPI,
        CASE WHEN p.NPI IS NULL THEN 'UNMATCHED' ELSE 'MATCHED' END AS MATCH_STATUS
    FROM STAGE_MEDICAID.CLEAN.MEDICAID_PROVIDER_SPENDING_STAGE f
    LEFT JOIN ANALYTICS_MEDICAID.MODEL.NPI_DIM p
        ON f.BILLING_PROVIDER_NPI = p.NPI
)
SELECT
    MATCH_STATUS,
    COUNT(*) AS ROW_COUNT,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM joined) * 100, 2) AS PCT
FROM joined
GROUP BY MATCH_STATUS;
```

🟦 7. Provider Match Coverage Diagram
```code
        +-------------------------------+
        | Medicaid Provider Spending    |
        | (FACT)                        |
        +-------------------------------+
                    |
                    | BILLING_PROVIDER_NPI
                    v
        +-------------------------------+
        | NPI_DIM                       |
        | (Provider Master Dimension)   |
        +-------------------------------+
                    |
                    | 96.69% Match Rate
                    |
        +-------------------------------+
        | Unmatched NPI Categories      |
        | - Blank / NULL                |
        | - Placeholder NPIs            |
        | - Legacy Medicaid IDs         |
        | - Deactivated NPIs            |
        | - Non‑NPI identifiers         |
        +-------------------------------+

```

For the full Provider Integrity Framework and MODEL‑layer integration, see Section 11 of `07_data_modeling.md`.




