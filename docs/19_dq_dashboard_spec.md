# Power BI — Provider Integrity & Data Quality Dashboard

## Pages
1. **Provider Integrity Scorecard**
   - Invalid NPI Rate
   - Billing vs Servicing Invalids
   - Provider Integrity Score

2. **Legacy Servicing Provider Registry**
   - Table of A‑prefix / M‑prefix IDs
   - Claim volume
   - Service category patterns

3. **DQ Trend & Anomalies**
   - Monthly invalid NPI trend
   - Anomaly flags
   - Year‑over‑year comparison

👉 Historical data quality incidents are documented in `docs/16_data_quality_incident.md`.

4. **Provider Data Quality Explorer**
   - Drilldown by provider
   - Drilldown by service category
   - Drilldown by geography

## Required Tables
- FACT_MEDICAID_PROVIDER_SPENDING  
- PROVIDER_DIM  
- LEGACY_SERVICING_PROVIDER_DIM  
- DQ_INVALID_NPI_TREND  
- DQ_INVALID_NPI_ANOMALIES  
- DATE_DIM  

## Measures
- Invalid NPI Rate  
- Billing Invalid Rate  
- Servicing Invalid Rate  
- Legacy ID Claim Volume  
- Provider Integrity Score  
