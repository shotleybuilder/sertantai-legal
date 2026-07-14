---
name: LAT QA
description: Automated sense checks and quality tests for parsed LAT data from a session. Runs SQL checks against legal_articles and reports pass/fail/warn for each law in the session.
---

# LAT QA — Automated Post-Parse Checks

## Overview

After a LAT parse session completes, run automated QA to catch parser regressions, data corruption, and structural issues before promoting to enrichment or production.

**When to use**: After any LAT parse or re-parse session, before fractalaw enrichment.

## Usage

```bash
# QA a specific session
mix lat.qa lat-reparse-shallow-2026-07-13

# QA a single law (outside a session)
mix lat.qa --law UK_ssi_2009_140

# Verbose — show all checks, not just failures
mix lat.qa lat-reparse-shallow-2026-07-13 --verbose
```

## Checks

The QA script runs these checks for each law in the session:

### 1. Row Count (WARN)
- Laws with 0 LAT rows — parse may have failed
- Laws with only 1-2 rows — likely only got title/signed, body not parsed
- Laws with >1000 rows — spot-check flag (not an error, large laws exist)

### 2. Section Type Distribution (WARN)
- No `paragraph` rows — shallow parse, P3/P4 not captured (Issue #120)
- No `article`/`section` rows — structural root missing
- Only structural types (part/chapter/heading) with no provision content

### 3. Section ID Uniqueness (FAIL)
- Duplicate section_ids within a law — PK violation risk
- Disambiguated IDs (`#position` suffix) — parser had to resolve collisions, worth reviewing

### 4. Doubled Section IDs (FAIL)
- The `X(X)` pattern: `reg.30(30)`, `s.3(3)` where provision == sub
- Only flags genuinely doubled (no sibling with different sub-number)
- This is the Issue #120 bug — should be zero after parser fix

### 5. Prefix Convention (FAIL)
- `art.` on domestic instruments (uksi, ssi, nisr, wsi, etc.) — should be `reg.`
- `reg.` on EU retained law (eudr, eur) — should be `art.`
- `s.` on SIs or `reg.` on Acts — wrong provision mode

### 6. Hierarchy Integrity (WARN)
- Provisions without a parent part/heading
- Sub-articles/sub-sections without a parent provision
- Schedule content without a schedule parent

### 7. Sort Key Ordering (WARN)
- Position vs sort_key monotonicity — position should increase with sort_key
- Breaks indicate parser traversal order issues

### 8. Annotation Sanity (WARN)
- Amendment count > 0 but no amendment_annotations for the law
- Laws with very high amendment counts (>50) — worth reviewing

## Output Format

```
── lat-reparse-shallow-2026-07-13 (172 laws) ──

✓ UK_apni_1969_6         42 rows  [all checks pass]
✓ UK_apni_1970_10        38 rows  [all checks pass]
⚠ UK_asp_2009_12         156 rows [WARN: 2 disambiguated IDs]
✗ UK_ssi_2009_140        365 rows [FAIL: 270 doubled section_ids]

── Summary ──
  Pass: 168  Warn: 3  Fail: 1
  Checks: 8 × 172 = 1,376 total
```

## Scripts

- `scripts/lat-qa.sql` — the SQL queries for each check (runnable standalone)
- `mix lat.qa` — the Elixir mix task that orchestrates the checks

## Integration

This skill is Stage 4 in the `lat-parse-session` workflow. After the human completes parsing, invoke this skill before proceeding to fractalaw enrichment (Stage 5).

The existing Stage 4 checks in `lat-parse-session` are manual SQL queries. This skill automates them.
