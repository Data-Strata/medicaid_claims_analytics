📘 Medicaid Data Glossary (Core Entities + Reporting Concepts)

## 🏥 Service Categories (ED, IP, OP, RX)

*#* ED — Emergency Department
Unscheduled, urgent care visits.
Often used for:
- ED visit rates
- Avoidable ED analysis
- ED visits per 1,000 members

*#* IP — Inpatient
Hospital stays requiring admission.
Used for:
- Admission rates
- Length of stay
- Readmissions (30‑day)
- Cost per stay

*#* OP — Outpatient
Scheduled or non‑admission services (clinics, imaging, procedures).
Used for:
- Ambulatory care analysis
- Preventive care tracking
- Utilization trends

*#* RX — Pharmacy
Prescription drug claims.
Used for:
- Drug utilization
- High‑cost drug analysis
- Medication adherence

## 🧾 Payment Models

*#* FFS — Fee‑For‑Service
The state pays providers per claim for each service delivered.
Characteristics:
- Direct claims
- No capitation
- Easier to trace service → payment

*#* Managed Care
The state contracts with MCOs to manage care.
Characteristics:
- State pays capitation (fixed monthly rate per member)
- MCOs pay providers
- State receives encounter data instead of claims

*#* Capitation
A fixed monthly payment per enrolled member paid to MCOs, regardless of how many services the member uses.
Used for:
- PMPM calculations
- MCO performance evaluation

## 🧾 Claims vs Encounters

*#* Claim
A bill submitted by a provider for payment (FFS).
Contains:
- Procedure codes
- Diagnosis codes
- Paid amount
- Service dates

*#* Encounter
A record of a service delivered to an MCO member.
Key difference:
- Not a payment request
- Submitted by MCOs to the state for reporting
- Often lower quality → requires validation

🧩 Medicaid Program Concepts

*#* Waiver
A special program allowing states to “waive” certain federal Medicaid rules.
Examples:
- 1115 Waivers (innovation)
- 1915(c) HCBS Waivers (home & community‑based services)

Used for:
- Program enrollment
- Cost reporting
- Quality measures

*#* PMPM — Per Member Per Month
A cost/utilization metric normalized by enrollment.
Formula:
PMPM = Total cost ÷ Member months  

Used for:
- Budget forecasting
- MCO comparisons
- Trend analysis

*#* MCO — Managed Care Organization
A health plan contracted by the state to manage Medicaid members.
Responsible for:
- Paying providers
- Managing utilization
- Reporting encounter data
- Meeting quality metrics

## 🧑‍⚕️ Core Medicaid Data Entities

*#* Member
A Medicaid beneficiary.
Key fields:
- Member ID
- Eligibility spans
- Program (e.g., TANF, ABD, CHIP)
- MCO assignment
- Demographics

*#* Provider
A clinician, facility, or organization delivering services.
Key fields:
- NPI
- Taxonomy
- Specialty
- Address
- Enrollment status

*#* Claim/Encounter
A record of a service delivered.
Key fields:
- Service dates
- Procedure codes (HCPCS/CPT)
- Diagnosis codes (ICD‑10)
- Paid amount (claims only)
- MCO ID (encounters)

*#*  Program
The Medicaid category under which a member is eligible.
Examples:
- TANF
- ABD
- CHIP
- Waiver programs

*#* Service Category
A grouping of services (ED, IP, OP, RX, LTSS, BH).

*#* MCO Assignment
Which MCO the member is enrolled with during a given month.

## 🧮 Medicaid Reporting Tools (State + Federal)

# T‑MSIS — Transformed Medicaid Statistical Information System
CMS’s national database of Medicaid & CHIP data.
States submit:
- Eligibility
- Claims/encounters
- Provider
- Managed care
- Financial data

Used for:
- Federal oversight
- Data quality scoring
- National research

# CMS‑64
Quarterly financial report submitted by states to CMS.
Includes:
- Total Medicaid expenditures
- Federal match calculations
- Program category breakdowns

My analytics work supports CMS‑64 by:
- Reconciling claims/encounters to expenditures
- Ensuring data quality

# MARS (Medicaid Analytics & Reporting System)
CMS or state‑specific reporting environments used for:
- Program monitoring
- Quality measures
- Trend analysis

# CMS Reporting Portals
Used for:
- Quality measures (e.g., Adult Core Set)
- Managed care oversight
- Waiver reporting

# 🧠 Other Important Medicaid Terms

*#* Eligibility Span
Continuous period during which a member is eligible for Medicaid.
Used for:
- Enrollment counts
- PMPM
- Cohort creation

*#* Service Date vs Paid Date
- Service date: When care occurred
- Paid date: When claim was paid
Used for:
	- Lag analysis
	- Trend accuracy

*#* Diagnosis Codes (ICD‑10)
Describe the reason for the visit.

*#* Procedure Codes (HCPCS/CPT)
Describe what service was performed.

*#* Rate Cells
Capitation rate categories (age, gender, region, program).

*#* Quality Measures
Examples:
- 30‑day readmissions
- ED utilization
- Preventive care rates