# 🟦 3‑Sigma Anomaly Detection for Invalid NPI Spikes & Drops
Location: docs/20_dq_anomaly_detection.md  
Model Table: `ANALYTICS_MEDICAID.MODEL.DQ_INVALID_NPI_ANOMALIES`

---

## 🟦 1. Purpose
This document describes the anomaly‑detection logic used to identify statistically significant spikes or drops in invalid NPIs across Medicaid claims.
The goal is to surface unexpected changes in provider data quality that may indicate:
- Upstream ingestion issues
- Schema drift in NPI Registry
- Sudden increases in missing/invalid NPIs
- Provider billing anomalies
- Data corruption or file‑shift patterns

This table powers the DQ Integrity Scorecard, DQ Dashboard, and Provider Integrity Framework.

---
## 🟦 2. Input Dataset
The anomaly detector consumes the monthly trend table:
```code
MODEL.DQ_INVALID_NPI_TREND
```
Which contains:
- CLAIM_MONTH
- INVALID_NPI_COUNT
- TOTAL_CLAIMS
- INVALID_NPI_RATE

This trend table is the baseline for statistical analysis.

---

## 🟦 3. Methodology — 3‑Sigma Rule
The anomaly detector uses a Z‑score based on the classical 3‑sigma rule:

 Step 1 — Compute Historical Mean
	`MEAN_RATE = AVG (INVALID_NPI_RATE)`

Step 2 — Compute Standard Deviation
	`STDDEV_RATE = STDDEV (INVALID_NPI_RATE)`

Step 3 — Compute Z‑Score for Each Month
	`Z_SCORE = (INVALID_NPI_RATE−MEAN_RATE)/STDDEV_RATE`

Step 4 — Flag Anomalies
A month is flagged as an anomaly when:`∣Z_SCORE∣ ≥ 3`

This identifies extreme deviations from historical patterns.

---

## 🟦 4. Output Table — DQ_INVALID_NPI_ANOMALIES
Grain: One row per detected anomaly
Purpose: Identify statistically significant spikes/drops in invalid NPIs.

```code
| Column | Type | Description |
| --- | --- | --- |
| ``CLAIM_MONTH`` | DATE | Month of anomaly |
| ``INVALID_NPI_RATE`` | FLOAT | Observed invalid rate |
| ``MEAN_RATE`` | FLOAT | Historical mean rate |
| ``STDDEV_RATE`` | FLOAT | Standard deviation |
| ``Z_SCORE`` | FLOAT | Standardized deviation |
| ``ANOMALY_FLAG`` | BOOLEAN | TRUE = anomaly ( | Z | ≥ 3) |
```

🟦 5. Interpretation
A flagged anomaly indicates:
- A spike in invalid NPIs (possible ingestion or provider‑behavior issue)
- A drop in invalid NPIs (possible upstream cleanup or schema change)
- A structural break in the NPI Registry or Medicaid file
- A data quality incident requiring investigation

Typical root causes:
- PI Registry schema changes
- Missing or truncated NPI fields
- File‑shift corruption
- Provider billing system changes
- Upstream ETL failures
- Incorrect ZIP → CSV extraction

---

🟦 6. How It Integrates With the Integrity Framework
This anomaly table feeds:
- DQ Dashboard (spike/drop visualization)
- Provider Integrity Scorecard
- DQ Incident Documentation
- FACT_MEDICAID refresh logic
- Executive‑level DQ reporting

It acts as an early warning system for provider data quality issues.

🟦 7. Refresh Logic
This table must be refreshed when:
- DQ_INVALID_NPI_TREND is rebuilt
- NPI validation rules change
- NPI_DIM is rebuilt
- Medicaid ingestion logic changes
- New months of data arrive

It does not need refresh when:
- HCPCS_DIM changes
- DATE_DIM changes
- Non‑provider dimensions change

🟦 8. SQL Reference
The underlying SQL is located at:
```code
sql/model/dq_invalid_npi_anomalies.sql
```