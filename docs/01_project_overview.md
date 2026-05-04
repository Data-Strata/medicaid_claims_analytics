
## Project Overview

This project analyzes provider-level Medicaid claims using the 
Medicaid Provider Spending by HCPCS dataset (2018–2024). The goal is to 
build a scalable Snowflake data pipeline and produce actionable insights 
on provider utilization, spending patterns, and HCPCS-level trends.

## 1. Overview
This document defines the Snowflake environment, role hierarchy, warehouse configuration, and database/schema layout used for the Medicaid Analytics Platform.

## 2. Snowflake Roles
ACCOUNTADMIN – initial setup only

SYSADMIN – object creation

DEVELOPER – day‑to‑day development

ANALYST – read‑only access to MODEL layer

## 3. Warehouses
WH_MEDICAID_ETL (Medium) – ingestion + transformations

WH_MEDICAID_ANALYTICS (Small) – BI workloads

## 4. Databases & Schemas
```code
RAW_MEDICAID
    └── PUBLIC

STAGE_MEDICAID
    └── CLEAN

ANALYTICS_MEDICAID
    └── MODEL

```

## 5. Storage Strategy
RAW: immutable, file‑level lineage

STAGE: typed, cleaned, 1:1 row preservation

MODEL: dimensional model (facts + dims)