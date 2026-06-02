---
name: Customer Onboarding Applicability QA
description: QA legacy vendor applicability data (Enhesa Yes/No) against SertantAI L2. Per-family analysis comparing vendor selections to LRT making laws, identifying revoked errors, coverage gaps, and Making classification issues. Produces actionable findings and patterns for automated screening.
---

# Customer Onboarding Applicability QA

## Overview

After importing a customer's legacy compliance register (via `customer-onboarding-import` skill)
and seeding applicability records (`mix sync.seed_applicability`), this skill QAs the vendor's
applicability decisions against SertantAI's L2 making-law dataset.

The goal is NOT to replicate the vendor's list — it's to expose:
- **Errors**: revoked laws marked as applicable
- **Coverage gaps**: making laws the vendor missed entirely
- **False positives**: laws marked applicable that shouldn't be (wrong sector, etc.)
- **Making classification issues**: amendment SIs incorrectly flagged as Making

## Prerequisites

- Customer import completed (`import-{customer}-{site}` session exists)
- `org_applicabilities` seeded from matched.json (`mix sync.seed_applicability`)
- Taxa (DRRP roles) enriched for the target family (from fractalaw)
- Fitness fields populated where available

## Invocation

```
/customer-onboarding-applicability-qa <family> <org_id>
/customer-onboarding-applicability-qa "💙 OH&S: Occupational / Personal Safety" 550e8400-...
```

## Workflow

### Step 1: Scope the family

Query L2 making laws for the target family, LEFT JOIN against org_applicabilities for the org:

```sql
SELECT l.name, l.title_en, l.year, l.live, l.has_fitness,
  l.role, l.fitness_person, l.fitness_sector, l.fitness_place,
  l.function, l.type_code, l.geo_extent,
  a.status as vendor_status
FROM uk_lrt l
LEFT JOIN org_applicabilities a ON a.law_name = l.name
  AND a.organization_id = '<org_id>'
WHERE l.family = '<family>'
  AND l.function->>'Making' = 'true'
```

Partition into:
- **Vendor Yes** (a.status = 'yes')
- **Vendor No** (a.status = 'no')
- **Not in vendor** (a.status IS NULL)

Report counts for each, split by live status (in force / part-revoked / revoked).

### Step 2: Check for errors in vendor Yes set

**2a. Revoked laws marked Yes**
Flag any `vendor_status = 'yes'` where `live` = '❌ Revoked'. These are always errors.
Part-revoked is valid (still partially in force).

**2b. Geographic mismatches**
If the customer site is in England, flag Yes laws with `geo_extent` limited to Scotland/NI only.

### Step 3: Analyse the coverage gap (Not in vendor)

**3a. Geographic filter**
Separate NI-only laws (nisr, nisi, apni type codes) from GB/England laws.
For an England site, NI laws are expected exclusions, not gaps.

**3b. Amendment SIs**
Laws with title containing "Amendment" or "Amending" AND function.Making = true.
These may be Making false-positives — check if function.Amending is also true.
If they only amend an existing Yes law, they're not gaps.

**3c. Fees / Procedural SIs**
Laws with title containing "Fees" or "Procedure" or "Hearings".
These are administrative, expected omissions from L3.

**3d. Specialist / niche laws**
Remaining laws after filtering 3a-3c. These are genuine candidates for review.
Check:
- `fitness_sector` — does it match the org's sector?
- `fitness_person` — does it include "employer"/"employee" (broadly applicable)?
- `role` — does it include "Org: Employer" + "Ind: Employee"?
- Title keywords — does it suggest a specific sector (healthcare, maritime, agriculture)?

### Step 4: Check vendor No laws

Usually a small set. Verify the No decisions are reasonable:
- Sector-specific laws for a different sector → No is correct
- Broadly applicable laws → potential false negative

### Step 5: Present findings

Format as a markdown table per category:

```
## Errors (action required)
| Law | Title | Issue |
|-----|-------|-------|

## Coverage Gaps (review needed)
| Law | Title | Category | Signal |
|-----|-------|----------|--------|

## Expected Omissions (no action)
| Law | Title | Reason |
|-----|-------|--------|

## Making Classification Review
| Law | Title | Has Amending flag | Suggestion |
|-----|-------|--------------------|------------|
```

### Step 6: Save findings

Write findings to `backend/data/imports/{customer}/{site}/applicability-qa-{family-slug}.md`

### Step 7: Apply corrections (with user confirmation)

- Update org_applicabilities status for confirmed errors (revoked → excluded)
- Optionally add new applicability records for confirmed gaps (status: unreviewed, source: manual)

## QA Patterns (codified from OH&S analysis)

These patterns should be checked for every family:

| # | Pattern | Signal | Action |
|---|---------|--------|--------|
| 1 | Revoked + Yes | Error | Flag, set status → excluded |
| 2 | NI law + England site | Expected exclusion | Filter from gap analysis |
| 3 | Title "Amendment" + Making | Possible Making misclassification | Review function flags |
| 4 | Title "Fees" + Making | Administrative/procedural | Expected omission |
| 5 | fitness_sector doesn't match org | Not applicable | Candidate for No |
| 6 | fitness_person includes employer/employee | Broadly applicable | Candidate for Yes |
| 7 | role includes Org: Employer + Ind: Employee | General workplace law | Candidate for Yes |
| 8 | Specialist title keywords (healthcare, maritime, agriculture) | Sector-specific | Match against org profile |

## DRAFT STATUS

This skill is a draft. Known gaps:
- No org profile model yet (sector, activities) to automate pattern 5/8
- Fitness coverage is low outside safety families — patterns 5-6 only work where enriched
- Making classification review (pattern 3) needs a separate fix workflow
- No bulk update action yet — corrections are manual
