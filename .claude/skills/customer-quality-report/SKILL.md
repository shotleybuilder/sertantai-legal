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

```sql
WITH enhesa AS (
  SELECT law_name, status as enhesa_status
  FROM org_applicabilities
  WHERE organization_id = '{org_id}'
),
assessed AS (
  SELECT u.name,
         CASE WHEN u.function ? 'Making' THEN 'Making'
              WHEN u.function ? 'Empowering' THEN 'Empowering'
              WHEN u.function ? 'Housekeeping' THEN 'Housekeeping'
              ELSE 'Not enriched' END as enrichment,
         CASE WHEN u.live LIKE '%Revoked%' OR u.live LIKE '%Repealed%' OR u.live LIKE '%Abolished%' THEN 'fully_revoked'
              WHEN u.live LIKE '%Part%' THEN 'part_revoked'
              ELSE 'in_force' END as live_status
  FROM uk_lrt u
)
SELECT
  COUNT(*) FILTER (WHERE e.enhesa_status = 'yes' AND a.enrichment = 'Making' AND a.live_status != 'fully_revoked') as true_positive,
  COUNT(*) FILTER (WHERE e.enhesa_status = 'yes' AND (a.live_status = 'fully_revoked' OR a.enrichment NOT IN ('Making'))) as false_positive,
  COUNT(*) FILTER (WHERE e.enhesa_status = 'no' AND (a.enrichment != 'Making' OR a.live_status = 'fully_revoked')) as true_negative,
  COUNT(*) FILTER (WHERE e.enhesa_status = 'no' AND a.enrichment = 'Making' AND a.live_status != 'fully_revoked') as false_negative,
  COUNT(*) as total
FROM enhesa e
JOIN assessed a ON a.name = e.law_name;
```

**Metrics to compute**:
- Precision: TP / (TP + FP) — "what % of vendor's Yes list is genuinely applicable"
- Recall: TP / (TP + FN) — "what % of applicable laws does the vendor capture"
- False Positive Rate: FP / (TP + FP) — "what % of Yes list is wasted effort"

## Step 2: False Positive Breakdown

Break FP into reasons so the customer understands *why* each law is questionable:

```sql
-- Group by reason
CASE
  WHEN live_status = 'fully_revoked' THEN 'Fully revoked (' || enrichment || ')'
  WHEN enrichment = 'Empowering' THEN 'Empowering (no duties, in force)'
  WHEN enrichment = 'Housekeeping' THEN 'Housekeeping (no duties, in force)'
  WHEN enrichment = 'Not enriched' THEN 'Not yet assessed (needs LAT parsing)'
END as fp_reason
```

**Presentation note**: Separate "definitively wrong" (revoked, no duties) from "pending assessment" (not enriched). The headline FP count should call out both.

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
