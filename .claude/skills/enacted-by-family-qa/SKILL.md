---
name: Enacted By Family QA
description: AI-driven family classification QA using enacted_by graph relationships. Analyses a family population for suspect assignments, presents batch recommendations, applies confirmed changes, and rebuilds edges.
---

# Enacted By Family QA

## Overview

Uses the enacted_by relationship graph to QA family classification on uk_lrt.
The enacted_by graph shows which parent Act enables each child SI — when a child's
family doesn't fit the parent's enacted_families distribution, the family assignment
is suspect. This skill automates the investigation and presents findings for user review.

## Invocation

```
/enacted-by-family-qa [family name]
/enacted-by-family-qa 💙 OH&S: Occupational / Personal Safety
/enacted-by-family-qa all    # scan all families
```

## Workflow

### Step 1: Scope — identify the target family

If a family name is provided, use it. Otherwise ask the user.

Useful query to see family populations with enacted_by edges:

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.family, COUNT(*) as laws_with_edges
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
WHERE e.edge_type = 'enacted_by' AND u.family IS NOT NULL
GROUP BY u.family ORDER BY 2 DESC;
"
```

### Step 2: Analyse — run QA queries for the family

Run these queries to find suspect laws within the target family. Batch to ~30 laws max per review cycle.

#### 2a. Outliers — child's family is <5% of parent's enacted_families

These laws are assigned to the target family but are statistical outliers within
their parent's enacted_families distribution. May indicate wrong family or wrong
enacted_by link.

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.family,
  u.si_code->'values' as si_codes,
  e.target_law as parent, p.title_en as parent_title,
  (p.enacted_families->>u.family)::int as family_count,
  (SELECT sum(v::int) FROM jsonb_each_text(p.enacted_families) t(k,v)) as total_children,
  ROUND((p.enacted_families->>u.family)::numeric * 100.0 /
    NULLIF((SELECT sum(v::int) FROM jsonb_each_text(p.enacted_families) t(k,v)), 0), 1) as pct
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
JOIN uk_lrt p ON p.name = e.target_law
WHERE e.edge_type = 'enacted_by'
  AND u.family = '[TARGET_FAMILY]'
  AND p.enacted_families IS NOT NULL
  AND p.enacted_families ? u.family
  AND (p.enacted_families->>u.family)::numeric * 100.0 /
    NULLIF((SELECT sum(v::int) FROM jsonb_each_text(p.enacted_families) t(k,v)), 0) < 5.0
ORDER BY pct
LIMIT 30;
"
```

#### 2b. SI code mismatch — child's SI codes don't map to this family

The si_code_families table maps SI codes to compatible families. If a law's SI codes
have no mapping to its assigned family, it may be misclassified.

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.family,
  u.si_code->'values' as si_codes,
  (SELECT array_agg(DISTINCT scf.family) FROM si_code_families scf
   WHERE scf.si_code IN (SELECT val FROM jsonb_array_elements_text(u.si_code->'values') val)
  ) as si_code_suggests
FROM uk_lrt u
WHERE u.family = '[TARGET_FAMILY]'
  AND u.si_code IS NOT NULL AND u.si_code != 'null'::jsonb
  AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements_text(u.si_code->'values') val
    JOIN si_code_families scf ON scf.si_code = val AND scf.family = u.family
  )
LIMIT 30;
"
```

#### 2c. Title keyword mismatch — title doesn't confirm family

Laws where FamilyRules title keywords don't match. Less reliable (many valid laws
won't have keywords) but useful as a supplementary signal.

```sql
-- Run via Elixir to use FamilyRules.title_confirms_family?
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT name, title_en, family, si_code->'values' as si_codes
FROM uk_lrt
WHERE family = '[TARGET_FAMILY]'
  AND title_en IS NOT NULL
ORDER BY name
LIMIT 200;
"
-- Then filter in analysis: laws where title suggests a DIFFERENT family
```

### Step 3: Triage — AI analysis of each suspect law

For each suspect law from step 2, assess:

1. **Title semantics** — Does the title fit the assigned family? Read it as a human would.
   "Control of Asbestos Regulations" → clearly OH&S.
   "Data (Use and Access) Act" → clearly not OH&S.

2. **SI codes** — What families do si_code_families suggest for this law's SI codes?
   Cross-reference against the assigned family.

3. **Parent context** — What family is dominant in the parent's enacted_families?
   A law enacted under the Health and Safety at Work Act is probably OH&S.
   A law enacted under the European Communities Act could be anything.

4. **Suggest action**:
   - **keep** — assignment is correct despite being a statistical outlier
   - **reclassify to [family]** — assignment is wrong, suggest specific alternative
   - **review** — ambiguous, needs human judgment

5. **Confidence**: high (clear title + SI code agreement) / medium / low

### Step 4: Present — show batch summary

Present findings as a markdown table for the user to review:

```
## Family QA: 💙 OH&S: Occupational / Personal Safety

Found N suspect laws. Recommendations:

| # | Law | Title | SI Codes | Current | Suggested | Reason | Conf |
|---|-----|-------|----------|---------|-----------|--------|------|
| 1 | UK_uksi_2025_904 | Data (Use and Access) Act... | DATA, DATA PROTECTION | OH&S: Occup... | 💙 PUBLIC: Data | title + SI codes | high |
| 2 | UK_uksi_2008_1765 | Employers' Liability... | INSURANCE | OH&S: Occup... | keep | enacted by HSWA | high |
...

Approve all reclassifications? Or specify by number to approve/reject individually.
```

### Step 5: Confirm — user approves changes

Wait for user confirmation. Accept:
- "approve all" — apply all reclassifications
- "approve 1, 3, 5" — apply specific rows
- "reject 2" — skip specific rows
- "change 3 to [family]" — override suggestion

### Step 6: Update — apply confirmed changes

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
UPDATE uk_lrt SET family = '[NEW_FAMILY]' WHERE name = '[LAW_NAME]';
"
```

Report: "Updated N laws. Changes: [list]"

### Step 7: Rebuild — refresh edges and derived tables

Call the rebuild endpoint to propagate changes:

```bash
curl -X POST http://localhost:4003/api/graph/rebuild-edges
```

Or via the frontend: click "Rebuild edges" button on /admin/graph.

Report the rebuild result (edge count, duration).

## Key Tables

| Table | Purpose |
|---|---|
| `uk_lrt` | Source of truth for family, si_code, enacted_by |
| `law_edges` | Materialised enacted_by graph (rebuilt from uk_lrt) |
| `si_code_families` | Derived SI code → family compatibility map |

## Key Files

| File | Purpose |
|---|---|
| `backend/lib/sertantai_legal_web/controllers/graph_controller.ex` | Stats, QA signals, rebuild endpoint |
| `backend/lib/sertantai_legal/legal/family_rules.ex` | Title → family keyword matching |
| `backend/lib/sertantai_legal/scraper/models.ex` | SI code → family model (single source) |
| `backend/lib/mix/tasks/law_edges.rebuild.ex` | Edge rebuild + derived table population |

## Tips

- Start with well-understood families (OH&S, FIRE, FOOD) where you can judge accuracy
- Work outward to less familiar families after building confidence
- Each cycle improves si_code_families, which improves the next cycle's SI mismatch detection
- Batch size of 20-30 is ideal for review — larger batches lose focus
- After a batch, rebuild edges and re-run to see if new suspects surface
- The "No enacted fams" filter on /admin/graph shows parents where children lack family — fixing those fills in the enacted_families distribution
