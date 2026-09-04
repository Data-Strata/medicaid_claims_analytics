# Provider Integrity Scorecard  
Medicaid Claims Analytics — Data Quality & Provider Integrity

## 1. Executive Summary
This scorecard evaluates the integrity of provider identifiers across the Medicaid dataset.  
It measures NPI validity, servicing vs billing discrepancies, malformed identifiers, and historical trends.

## 2. Key Metrics (Latest Full Refresh)
- **Total Claims:** 238,015,720  
- **Invalid NPI Claims:** 76,186 (0.03%)  
- **Distinct Invalid NPIs:** 2,592  
- **Billing Invalid Rate:** 0.03%  
- **Servicing Invalid Rate:** 1.28M claims (expected for atypical providers)

## 3. Invalid NPI Categories
| Category | Count |
|---------|-------|
| Malformed (non‑10‑digit) | 2,192 |
| Other Invalid | 398 |
| All Zeros | 1 |
| Sequential Placeholder | 1 |

## 4. Top Invalid Servicing Identifiers
These are state‑assigned legacy servicing provider IDs (A‑prefix, M‑prefix):
- A565813600 — 282,457 claims  
- A304140100 — 177,896 claims  
- A585713900 — 131,758 claims  
(Full list in Legacy Servicing Provider Registry)

## 5. Historical Trend (2018–2024)
- 2018–2019: High malformed servicing IDs (≈40k/month)  
- 2020: Sharp decline due to COVID utilization collapse  
- 2021–2024: Modernized NPI compliance (≈250–400 invalid claims/month)

## 6. Provider Integrity Score
**Score: 98.7 / 100**  
Based on:
- Invalid NPI rate  
- Servicing vs billing discrepancy  
- Trend stability  
- Malformed identifier prevalence  

## 7. Recommendations
- Maintain monitoring of servicing provider IDs  
- Validate legacy IDs with service category patterns  
- Continue anomaly detection for spikes  
