# 🟦 HCPCS Taxonomy Mapping (Power BI Layer)
Model Tables: `HCPCS_BASE`, `HCPCS_SUPPLEMENTAL_MAP`, `HCPCS_SUPPLEMENTAL_MAP_ENRICHED`, `HCPCS_FULL_DIM`
Calculated Column: `HCPCS_DIM[HCPCS Category]`

---

## 🟦 1. Purpose
This document describes the logic used to classify every HCPCS code appearing in the fact table into a human-readable category, for use in category-level analytics and the Data Quality & Lineage dashboard page. Unlike the rest of the MODEL layer, this classification is built entirely in Power BI — there is no corresponding Snowflake SQL file, which is why it wasn't previously documented alongside the other MODEL tables.

---

## 🟦 2. Why This Lives in Power BI, Not Snowflake
The base classification (`HCPCS_BASE`) is a calculated column on `HCPCS_DIM`, and the supplemental layer (`HCPCS_SUPPLEMENTAL_MAP`) is a DAX calculated table. Both were built directly against the Power BI semantic model rather than upstream in Snowflake. Anyone extending this logic should do it in the PBIX, not by adding a Snowflake column, unless the taxonomy is deliberately moved upstream later.

---

## 🟦 3. Input Tables
- `HCPCS_DIM` — the standard registry dimension (see `20_model_data_dictionary.md`), source for `HCPCS_BASE`.
- `FACT_MEDICAID_PROVIDER_SPENDING[HCPCS_CODE]` — the set of codes actually appearing in claims, which is what `HCPCS_SUPPLEMENTAL_MAP` pattern-matches against. Not every code billed in claims exists in the official HCPCS Level II registry (`HCPCS_DIM`) — that gap is the reason this second layer exists.

---

## 🟦 4. Methodology — Two-Layer Classification

### 4.1 Layer 1 — Standard Registry Classification (`HCPCS_BASE`)
`HCPCS_BASE` is built with `SELECTCOLUMNS` over `HCPCS_DIM`, tagging every row `Code_System = "HCPCS Level II"` and `Is_Supplemental = "FALSE"`. Its `Category` column comes from the `HCPCS Category` calculated column on `HCPCS_DIM`, a `SWITCH(TRUE(), ...)` classifier evaluated in this order:

1. **Numeric-first codes → "CPT (Professional Services)".** Any code starting with a digit is treated as CPT, not HCPCS Level II.
2. **2-character non-numeric codes → "Modifier Code".** Checked immediately after the CPT check, before any letter-prefix category, so a genuine modifier (e.g. `QW`, `UK`) is never absorbed into a broader single-letter category by mistake. This ordering was a deliberate fix — modifiers were originally checked last, which meant `Q`- and `U`-prefixed modifiers were being misclassified into the Q and U categories below.
3. **First-letter prefix → the categories listed in Section 6.**
4. **Anything unmatched → "Other".**

### 4.2 Layer 2 — Supplemental Pattern-Matching (`HCPCS_SUPPLEMENTAL_MAP`)
A DAX calculated table that pattern-matches codes present in claims but not in `HCPCS_DIM` at all — i.e. codes billed under a different coding system entirely. Built as a `UNION` of seven `VAR` blocks, one per code system (see Section 7). `HCPCS_SUPPLEMENTAL_MAP_ENRICHED` reshapes this into the same column structure as `HCPCS_BASE` (tagging `Is_Supplemental = "TRUE"`) so the two layers can be combined.

`HCPCS_FULL_DIM` is `DISTINCT(UNION(HCPCS_BASE, HCPCS_SUPPLEMENTAL_MAP_ENRICHED))`, filtered to exclude placeholder codes (`"00000"`, `"0000000"`). This is the single dimension the report actually uses — it covers every code system present in the data, not just the official registry.

---

## 🟦 5. Output Table — `HCPCS_FULL_DIM`
Grain: one row per unique code, across every code system present in the data (standard HCPCS Level II plus every supplemental system).
Purpose: single lookup dimension for category-level analytics, combining registry codes and non-registry codes under one consistent set of columns (`Code`, `Code_System`, `Category`, `Subcategory`, `Short_Description`, `Long_Description`, `Effective_Date`, `Termination_Date`, `Status`, `Notes`, `Source_Table`, `Is_Supplemental`).

---

## 🟦 6. Category Reference — Standard Registry (`HCPCS_BASE`)
| Prefix / Pattern | Category |
| --- | --- |
| Numeric-first | CPT (Professional Services) |
| 2-character, non-numeric | Modifier Code |
| A | DME / Supplies |
| B | Enteral / Parenteral |
| C | OPPS / Temporary |
| D | Dental |
| E | DME |
| G | Professional Services |
| H | Behavioral Health |
| J | Drugs / Injectables |
| K | DME (Temporary) |
| L | Orthotics / Prosthetics |
| M | Medical Services |
| P | Pathology & Lab |
| Q | Temporary Codes |
| R | Radiology |
| S | Commercial Payer Codes |
| T | State Medicaid Codes |
| U | State Medicaid Codes |
| V | Vision / Hearing |
| W, X, Y, Z | Commercial Payer Codes |
| Everything else (incl. F, I, N, O) | Other |

Note: T/U both map to "State Medicaid Codes," and S/W/X/Y/Z all map to "Commercial Payer Codes" — these are intentionally grouped labels, not one category per letter. Letters F, I, N, O have no dedicated branch and fall through to "Other."

---

## 🟦 7. Category Reference — Supplemental Layer (`HCPCS_SUPPLEMENTAL_MAP`)
Pattern-matched against codes appearing in claims that aren't standard HCPCS Level II codes:
- CPT
- CPT Category II
- CPT Category III
- PLA (Proprietary Laboratory Analyses)
- ICD-10-PCS
- State/Local Medicaid Codes
- Invalid / Placeholder Codes

---

## 🟦 8. Relationship to `SERVICE_CATEGORY_DIM`
`SERVICE_CATEGORY_DIM` is a separate, simpler dimension (see `14_date_and_service_dimensions.md`) that groups HCPCS codes into just three categories — **OP** (Outpatient), **RX** (Pharmacy), **OTHER** — used on the Service Category Analytics dashboard page. It is unrelated to this taxonomy and should not be conflated with it; the two serve different pages and different purposes.

---

## 🟦 9. How It Integrates
This taxonomy powers:
- The HCPCS Taxonomy Mapping card on the Data Quality & Lineage dashboard page.
- Any category-level HCPCS analytics elsewhere in the report that need a single combined code dimension.

---

## 🟦 10. Housekeeping Note
An earlier version of the model included `HCPCS_SUPPLEMENTAL_DEDUPED`, a calculated table using `EXCEPT` to de-duplicate `HCPCS_SUPPLEMENTAL_MAP_ENRICHED` against `HCPCS_BASE`. It was never referenced by `HCPCS_FULL_DIM` or anywhere else in the model and has since been removed.

---

## 🟦 11. DAX Reference
All logic below lives in the Power BI semantic model; there is no corresponding SQL file.
- `HCPCS_DIM[HCPCS Category]` — calculated column, standard registry classifier (Section 6).
- `HCPCS_BASE` — calculated table, reshapes `HCPCS_DIM` into the shared column structure.
- `HCPCS_SUPPLEMENTAL_MAP` — calculated table, seven-category pattern classifier (Section 7).
- `HCPCS_SUPPLEMENTAL_MAP_ENRICHED` — calculated table, reshapes the supplemental layer to match `HCPCS_BASE`'s columns.
- `HCPCS_FULL_DIM` — calculated table, the combined dimension actually used in the report.
