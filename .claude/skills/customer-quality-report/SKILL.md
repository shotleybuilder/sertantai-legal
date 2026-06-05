---
name: Customer Legal Register Quality Report
description: Generate a data quality report comparing a customer's legacy vendor register (Enhesa, Nimonik, etc.) against SertantAI's enriched legal database. Produces confusion matrix, revoked law analysis, coverage gaps, duty density, and family distribution. Outputs .md report + .csv appendices. Designed for customer senior management.
---

# Customer Legal Register Quality Report

## Overview

Compares a customer's legacy vendor applicability data (Enhesa Yes/No) against SertantAI's enriched legal database to produce a business-readable quality report. The report highlights false positives (wasted effort), false negatives (compliance gaps), and duty density (where to focus).

**Audience**: Customer senior management — non-technical, business-focused.
**Output**: Markdown report + CSV appendices in `data/reports/{customer}/`.
**Reusable**: Same queries power the customer-facing report page in the app.

## Prerequisites

- Customer CSV imported via `customer-onboarding-import` skill
- Applicability seeded via `mix sync.seed_applicability` (all sites, union semantics)
- LAT parsed and enriched for as many laws as possible (more enrichment = fewer "pending" items)
- Organization ID known

## Parameters

| Parameter | Example | How to find |
|-----------|---------|-------------|
| `{customer}` | `qq` | Customer slug from import |
| `{org_id}` | `c075d56b-8420-4408-b695-ccfbc1ba15ec` | `SELECT DISTINCT organization_id FROM org_applicabilities LIMIT 1` |
| `{output_dir}` | `data/reports/qq/` | Relative to `backend/` |
| `{division}` | (optional) | If customer has multiple divisions, filter by session_id pattern |

## Report Artifacts

| # | Artifact | Summary | Appendix CSV |
|---|----------|---------|-------------|
| 1 | Confusion Matrix | TP/FP/TN/FN grid with headline precision/recall | `applicability-detail.csv` |
| 2 | False Positive Breakdown | Revoked laws + no-duty laws in the "Yes" set | `false-positives.csv` |
| 3 | False Negatives | Active duty-creating laws Enhesa marks "No" | `false-negatives.csv` |
| 4 | Revoked Law Report | Fully revoked vs part-revoked in "Yes" set | (in applicability-detail) |
| 5 | Family Distribution | Law count + duty count by domain | (in report) |
| 6 | Duty Density | Top 15 laws by duty count | (in report) |
| 7 | EU vs UK Split | Retained EU law proportion | (in report) |

## Confusion Matrix Definitions

|  | SertantAI: Applicable | SertantAI: Not Applicable |
|--|----------------------|--------------------------|
| **Vendor: Yes** | **TP** — Making + not fully revoked | **FP** — Fully revoked OR not Making |
| **Vendor: No** | **FN** — Making + not fully revoked | **TN** — Not Making OR fully revoked |

**Key distinctions**:
- **Part-revoked** laws count as **applicable** (they still have active provisions)
- **Not enriched** laws count as **False Positive** (pending — conservative until assessed)
- **Empowering** (powers only, no duties) counts as **not applicable** for business purposes
- **Housekeeping** (no DRRP at all) counts as **not applicable**

## Step 1: Pull Confusion Matrix

**IMPORTANT**: Use a single `sertantai` classification column (`applicable` / `not_applicable`)
derived in one place. Do NOT compute enrichment and live_status separately and combine them
in FILTER clauses — this caused count mismatches when the FP breakdown query grouped differently
from the matrix query.

```sql
-- Single-classification approach: each law gets exactly one label
WITH classified AS (
  SELECT oa.law_name, oa.status as enhesa,
         CASE
           WHEN u.function ? 'Making'
                AND NOT (u.live LIKE '%Revoked%' OR u.live LIKE '%Repealed%' OR u.live LIKE '%Abolished%')
           THEN 'applicable'
           ELSE 'not_applicable'
         END as sertantai
  FROM org_applicabilities oa
  JOIN uk_lrt u ON u.name = oa.law_name
  WHERE oa.organization_id = '{org_id}'
)
SELECT
  COUNT(*) FILTER (WHERE enhesa = 'yes' AND sertantai = 'applicable') as TP,
  COUNT(*) FILTER (WHERE enhesa = 'yes' AND sertantai = 'not_applicable') as FP,
  COUNT(*) FILTER (WHERE enhesa = 'no' AND sertantai = 'not_applicable') as TN,
  COUNT(*) FILTER (WHERE enhesa = 'no' AND sertantai = 'applicable') as FN,
  COUNT(*) as total
FROM classified;
```

**Key**: Part-revoked laws (`⭕ Part Revocation / Repeal`) are treated as applicable —
they still have active provisions. Only `❌ Revoked / Repealed / Abolished` is fully revoked.
The LIKE patterns must match the exact emoji-prefixed strings stored in `uk_lrt.live`.

**Metrics to compute**:
- Precision: TP / (TP + FP) — "what % of vendor's Yes list is genuinely applicable"
- Recall: TP / (TP + FN) — "what % of applicable laws does the vendor capture"
- False Positive Rate: FP / (TP + FP) — "what % of Yes list is wasted effort"

## Step 2: False Positive Breakdown

Break FP into reasons so the customer understands *why* each law is questionable.

**IMPORTANT**: This query MUST produce counts that sum to the FP total from Step 1.
Use the same classification logic — a law is FP if `enhesa = 'yes'` AND it's not
(`Making` AND not fully revoked). Then sub-classify the reason:

```sql
WITH fp_laws AS (
  SELECT u.name,
         CASE WHEN u.function ? 'Making' THEN 'Making'
              WHEN u.function ? 'Empowering' THEN 'Empowering'
              WHEN u.function ? 'Housekeeping' THEN 'Housekeeping'
              ELSE 'Not enriched' END as enrichment,
         CASE WHEN u.live LIKE '%Revoked%' OR u.live LIKE '%Repealed%' OR u.live LIKE '%Abolished%' THEN 'fully_revoked'
              ELSE 'active' END as live_status,
         u.lat_count
  FROM org_applicabilities oa
  JOIN uk_lrt u ON u.name = oa.law_name
  WHERE oa.organization_id = '{org_id}'
    AND oa.status = 'yes'
    AND NOT (
      u.function ? 'Making'
      AND NOT (u.live LIKE '%Revoked%' OR u.live LIKE '%Repealed%' OR u.live LIKE '%Abolished%')
    )
)
SELECT
  CASE
    WHEN live_status = 'fully_revoked' THEN 'Fully revoked (' || enrichment || ')'
    WHEN enrichment = 'Empowering' THEN 'Empowering (no duties)'
    WHEN enrichment = 'Housekeeping' THEN 'Housekeeping (no duties)'
    WHEN enrichment = 'Not enriched' AND lat_count > 0 THEN 'Parsed but not enriched'
    WHEN enrichment = 'Not enriched' AND lat_count = 0 THEN 'No parseable body'
  END as reason, COUNT(*)
FROM fp_laws GROUP BY reason ORDER BY count DESC;
```

**Presentation note**: Separate "definitively wrong" (revoked, no duties) from edge cases (no body text). Ideally all laws should be fully parsed and enriched before generating the final report — run LAT parse sessions for any "Not enriched" items first.

## Step 3: False Negatives

Laws the vendor says "No" but SertantAI finds active duties. These are potential compliance gaps.

Order by duty count descending — the most duty-heavy gaps are the highest priority.

## Step 4: Revoked Law Report

Separate fully revoked (remove from register) from part-revoked (still has active provisions):

```sql
CASE
  WHEN u.live LIKE '%Revoked%' OR u.live LIKE '%Repealed%' OR u.live LIKE '%Abolished%' THEN 'fully_revoked'
  WHEN u.live LIKE '%Part%' THEN 'part_revoked'
  ELSE 'in_force'
END
```

**Business message**: Part-revoked laws are correctly tracked. Fully revoked laws should be removed.

## Step 5: Family Distribution

Group by family, show law count + making count + total duties. Order by law count descending. This shows where the compliance register concentrates.

## Step 6: Duty Density

Top 15 laws by duty entry count. These are where the compliance burden sits — focused review of these delivers the most assurance per unit effort.

## Step 7: EU vs UK Split

Group by jurisdiction (EU Retained vs UK Domestic). Show law count, making count, duty count. Business context: post-Brexit regulatory divergence risk for EU retained laws.

## Step 8: Export CSVs

Three CSV exports:

### applicability-detail.csv
Every law in the corpus with: name, title, type_code, family, year, enhesa_answer, live status, enrichment, duty_count, jurisdiction, classification (TP/FP/TN/FN).

### false-positives.csv
Subset: Enhesa Yes laws that are FP, with fp_reason column.

### false-negatives.csv
Subset: Enhesa No laws that are FN, with duty_count for prioritisation.

## Step 9: Generate Report

Write `enhesa-quality-report.md` with:
1. Executive Summary — headline numbers (precision, recall, FP rate)
2. Confusion Matrix — table with definitions
3. False Positive Breakdown — by reason, with counts
4. False Negatives — compliance gap count
5. Revoked Law Report — fully vs part revoked
6. Family Distribution — top families by law count + duties
7. Duty Density — top 15 laws
8. EU vs UK Split — jurisdiction breakdown
9. Data Quality Notes — caveats (pending enrichment, part-revoked treatment)
10. Appendices — links to CSV files

## Step 10: Identify Next Actions

After generating the report, identify follow-up work:

1. **LAT parse pending laws** — the "Not enriched" FP items need parsing to resolve
2. **Remove fully revoked** — recommend customer removes these from active register
3. **Review false negatives** — customer should assess the 23 laws SertantAI flagged
4. **Re-run after next division** — report improves with more site data (union semantics)

## Multi-Division / Multi-Jurisdiction Notes

- **Multiple divisions**: Run the same report per org_id, or union all divisions first
- **Australia**: Replace `uk_lrt` with AU equivalent, adjust live status patterns
- **Other jurisdictions**: Same structure, different legal register table and status codes
- **Comparison across divisions**: Run per-division, then diff the FP/FN sets

## Example Output

See `backend/data/reports/qq/` for the first QQ report (2026-06-05).

## Related Skills

- [Customer Onboarding Import](../customer-onboarding-import/) — import CSV, match, scrape
- [Customer Onboarding Applicability QA](../customer-onboarding-applicability-qa/) — per-family deep dive
- [LAT Parse Session](../lat-parse-session/) — parse + enrich the pending laws
