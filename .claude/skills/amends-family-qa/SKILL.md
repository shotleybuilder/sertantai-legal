---
name: Amends Family QA
description: AI-driven family classification QA using amends graph relationships. Analyses laws where amendment targets disagree on family, presents batch recommendations, applies confirmed changes, and rebuilds edges.
---

# Amends Family QA

## Overview

Uses the amends relationship graph to QA family classification on uk_lrt.
When a law amends targets that mostly belong to a different family, the amending law's
family assignment may be wrong. A law that amends 10 AGRICULTURE regulations but is
classified as OH&S is suspicious.

The Amends tab on /admin/graph shows these cross-family amendment mismatches with a
consensus percentage — the higher the consensus among targets, the stronger the signal.

## Invocation

```
/amends-family-qa [family name]
/amends-family-qa 💚 AGRICULTURE
/amends-family-qa all    # scan all families
```

## Workflow

### Step 1: Scope — identify the target family

If a family name is provided, use it. Otherwise ask the user.

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.family, COUNT(DISTINCT e.source_law) as laws_with_amends_mismatches
FROM law_edges e
JOIN uk_lrt u ON u.name = e.source_law
JOIN uk_lrt t ON t.name = e.target_law
WHERE e.edge_type = 'amends'
  AND u.family IS NOT NULL AND t.family IS NOT NULL
  AND u.family != t.family
  AND split_part(u.family, ':', 1) != split_part(t.family, ':', 1)
GROUP BY u.family ORDER BY 2 DESC;
"
```

### Step 2: Analyse — find laws with high consensus against their assigned family

#### 2a. High consensus mismatches — targets strongly agree on a different family

Laws in the target family where >60% of their amendment targets belong to a different
family. The higher the consensus, the more likely the law is misclassified.

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
WITH amend_targets AS (
  SELECT e.source_law, u.family as assigned, u.title_en,
    u.si_code->'values' as si_codes,
    t.family as target_family, COUNT(*) as cnt
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt t ON t.name = e.target_law
  WHERE e.edge_type = 'amends'
    AND u.family = '[TARGET_FAMILY]'
    AND t.family IS NOT NULL
  GROUP BY e.source_law, u.family, u.title_en, u.si_code, t.family
),
consensus AS (
  SELECT source_law, assigned, title_en, si_codes,
    target_family as top_target,
    cnt as top_count,
    SUM(cnt) OVER (PARTITION BY source_law) as total,
    ROUND(cnt::numeric * 100.0 / SUM(cnt) OVER (PARTITION BY source_law), 0) as pct,
    ROW_NUMBER() OVER (PARTITION BY source_law ORDER BY cnt DESC) as rn
  FROM amend_targets
)
SELECT source_law, title_en, assigned, si_codes, top_target, top_count, total, pct
FROM consensus
WHERE rn = 1
  AND top_target != assigned
  AND split_part(top_target, ':', 1) != split_part(assigned, ':', 1)
  AND pct >= 60
ORDER BY pct DESC
LIMIT 30;
"
```

#### 2b. SI code cross-check — same as enacted-by-family-qa step 2b

```sql
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.family,
  u.si_code->'values' as si_codes,
  (SELECT array_agg(DISTINCT scf.family ORDER BY scf.family) FROM si_code_families scf
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

#### 2c. Title keyword cross-check — same as enacted-by-family-qa step 2c

Run via Elixir to use FamilyRules:

```elixir
cd backend && mix run -e '
alias SertantaiLegal.Legal.FamilyRules

target = "[TARGET_FAMILY]"
all_keywords = FamilyRules.title_keywords()

{:ok, %{rows: rows}} = SertantaiLegal.Repo.query(
  "SELECT name, title_en, si_code->$$values$$ as si_codes FROM uk_lrt WHERE family = \$1 AND title_en IS NOT NULL ORDER BY name",
  [target]
)

for [name, title, si_codes] <- rows do
  confirms_assigned = FamilyRules.title_confirms_family?(title, target)
  other_matches =
    all_keywords
    |> Enum.filter(fn {fam, _} -> fam != target end)
    |> Enum.filter(fn {fam, _} -> FamilyRules.title_confirms_family?(title, fam) end)
    |> Enum.map(fn {fam, _} -> fam end)

  if !confirms_assigned and other_matches != [] do
    IO.puts("#{name} | #{title} | SI: #{inspect(si_codes)} | suggests: #{Enum.join(other_matches, ", ")}")
  end
end
'
```

### Step 3: Triage — AI analysis

Same as enacted-by-family-qa Step 3. For each suspect law assess:

1. **Title semantics** — does the title fit the assigned family?
2. **SI codes** — what do si_code_families suggest?
3. **Amendment target consensus** — what family do most targets belong to?
4. **Dual classification** — consider family (general) + family_ii (specific)

**Flow: Family = general → Family II = more specific.**

### Step 4: Present — batch summary

Same format as enacted-by-family-qa. Only show reclassifications, not keeps.

```
## Amends QA: [family name]

Analysed N suspects. M confirmed correct (keep). K recommended for reclassification:

| # | Law | Title | Family → | Family II → | Consensus | Reason | Conf |
|---|-----|-------|----------|-------------|-----------|--------|------|
...

Approve all? Or specify by number.
```

**Presentation rules:**
- Title column is MANDATORY
- Include consensus % — it's the primary signal for this tab
- "Reason" should be concise
- Only show reclassifications, summarise keeps as a count

### Step 5–7: Confirm, Update, Rebuild

Same as enacted-by-family-qa Steps 5–7.

## Key difference from enacted-by-family-qa

- **Enacted By** uses parent→child relationship (vertical: who enables whom)
- **Amends** uses peer→peer relationship (horizontal: what does this law change)
- A high amendment consensus (>80%) is a very strong signal — if a law amends 20 AGRICULTURE
  regulations and is classified as OH&S, it's almost certainly wrong
- Lower consensus (60-80%) needs more judgment — some laws genuinely amend across families

## Key Tables & Files

Same as enacted-by-family-qa — see that skill for the full reference.
