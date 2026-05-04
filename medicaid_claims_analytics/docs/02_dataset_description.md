# Dataset Description

This project uses the publicly available **Medicaid Provider Spending** dataset 
published by the U.S. Department of Health & Human Services (HHS).

Official dataset link:
https://opendata.hhs.gov/datasets/medicaid-provider-spending/

## Dataset Summary
The dataset contains provider-level Medicaid spending aggregated by:
- Billing provider
- Servicing provider
- HCPCS procedure code
- Month and year
- State and geographic region

## Key Metrics
- Total paid amount
- Number of beneficiaries
- Number of claim lines
- Number of services

## Time Coverage
January 2018 – December 2024

## File Format
- ZIP archive (~3.5 GB)
- 1 CSV file inside

## Usage in This Project
The dataset is loaded directly into Snowflake using:
- Internal stages
- COPY INTO commands
- RAW → STAGE → ANALYTICS modeling pipeline
