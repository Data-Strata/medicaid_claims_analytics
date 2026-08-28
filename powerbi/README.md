# 📘 Power BI Dashboard Documentation
This folder contains all documentation, specifications, and visual assets for the Medicaid Claims Analytics Power BI Dashboard.
The full .pbix file is not included due to GitHub’s file size limitations, but all materials required to understand or rebuild the dashboard are provided here.

## 📁 PBIX File Availability
The production Power BI dashboard (dashboard.pbix) is not stored in this repository because the file size exceeds GitHub’s upload limits.

PBIX size: ~3.9 GB

GitHub max file size: 2 GB

The PBIX is large due to:
- A 238M‑row Medicaid fact table
- Multiple enriched dimensions (NPI, HCPCS, DATE, SERVICE_CATEGORY)
- High‑cardinality provider attributes (330‑column NPI source)
- Role‑playing relationships (Billing vs Servicing Provider)
- Embedded lineage diagrams and DQ visuals
- A full semantic model with dozens of DAX measures

GitHub is not designed for multi‑GB BI artifacts, so the PBIX cannot be uploaded directly.

## 📊 Included Dashboard Assets
To ensure transparency, reproducibility, and portfolio‑readiness, this folder includes:

✔ High‑resolution screenshots of all dashboard pages
- Executive Overview
- Provider Integrity Scorecard
- Provider Drillthrough
- HCPCS Explorer
- Service Category Analytics
- Data Quality & Lineage

✔ Visual specifications
- Page layouts
- Fields used in each visual
- Filters and slicers
- Navigation rules
- Drillthrough configuration

✔ Semantic model documentation
- FACT + DIM relationships
- Role‑playing provider dimensions
- HCPCS taxonomy mapping
- Date intelligence logic

✔ DAX measure definitions
- Integrity metrics
- Provider percentile ranks
- Invalid NPI rate
- Category‑level aggregations
- DQ Severity Score
- Anomaly detection logic

✔ Lineage & DQ documentation
- STAGE → MODEL → STAR flow
- NPI validation rules
- Anomaly detection thresholds
- Provider integrity framework
- S2T mapping references

These assets allow reviewers to fully understand the dashboard design without needing the PBIX file.

## 🔧 Rebuilding the Dashboard
The dashboard can be fully rebuilt using the Snowflake MODEL layer and the documentation in this repository.

### Required Inputs
Snowflake MODEL tables

docs/09_powerbi_dashboard.md (full visual specification)

docs/07_data_modeling.md (star schema design)

docs/12_NPI_data_quality_analysis.md (DQ logic)

docs/17_provider_integrity_scorecard.md (integrity framework)

docs/11_s2t_mapping.md (source‑to‑target lineage)

### Steps
- Connect Power BI to Snowflake
- Import FACT + DIM tables
- Recreate semantic model relationships
- Add DAX measures (provided in documentation)
- Rebuild visuals using the screenshot references
- Apply formatting, bookmarks, and drillthrough rules

Everything required to reproduce the dashboard is included in this repo.

## 🖼 Dashboard Screenshots
Below are the screenshots included in this folder:

1. Executive Overview
assets/dashboard_screenshots/01_ExecutiveDashboard.png
<img src="assets/dashboard_screenshots/01_ExecutiveDashboard.png" width="850">
<img src="assets/dashboard_screenshots/01_ExecutiveDrillMap2.png" width="850">
<img src="assets/dashboard_screenshots/01_ExecutiveDrillMap3.png" width="850">


2. Provider Integrity Scorecard
assets/dashboard_screenshots/02_ProviderScorecard.png
<img src="assets/dashboard_screenshots/02_ProviderScorecard.png" width="850">

3. Provider Drillthrough
assets/dashboard_screenshots/03_ProviderIntegrity.png
<img src="assets/dashboard_screenshots/03_ProviderIntegrity.png" width="850">

4. HCPCS Explorer
assets/dashboard_screenshots/04_HCPCS_Explorer.png
<img src="assets/dashboard_screenshots/04_HCPCS_Explorer.png" width="850">

5. Service Category Analytics
assets/dashboard_screenshots/05_ServiceCategoryAnalytics.png
<img src="assets/dashboard_screenshots/05_ServiceCategoryAnalytics.png" width="850">

6. Data Quality & Lineage
assets/dashboard_screenshots/06_DQ&Lineage.png
<img src="assets/dashboard_screenshots/06_DQ&Lineage.png" width="850">

## 📬 Contact
For questions or collaboration, feel free to open an issue or reach out.
