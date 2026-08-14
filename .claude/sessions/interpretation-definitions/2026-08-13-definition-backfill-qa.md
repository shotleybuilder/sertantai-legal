---
session: Definition Backfill & QA
status: suspended
opened: 2026-08-13
---

# Session: Definition Backfill & QA (SUSPENDED)

## Problem

34K definitions imported from the legl CSV are in the DB and the parser is wired into the scrape pipeline — but 47% of definitions (16,348 rows across 1,469 laws) have null scope. The parser extracts scope from the XML preamble text, so re-parsing from body XML can fill these gaps. We also need to validate the legacy CSV data against fresh parser output and build the `mix definitions.backfill` task so definitions can be re-extracted at scale.

## Current State

| Metric | Value |
|--------|-------|
| Total definitions | 34,483 |
| Null scope | 16,348 (47%) |
| Has scope | 18,135 (53%) |
| Unique laws | 1,987 |
| Laws with null scope defs | 1,469 |
| Laws with LAT data (overlap) | 366 |
| Empty definitions | 0 |
| Duplicates | 0 |
| Orphan law references | 0 |

## Todo

- ✅ Random sample validation: 20 laws, fetch body XML, compare CSV vs parser
- ✅ Report: document discrepancies, parser gaps, and data quality metrics
- ✅ Fix parser edge cases: inline definition fallback + Term element text extraction fix
- ❌ Clean revoked — keeping revoked law definitions (useful for term evolution over time, compliance to filter on live status)
- ✅ Add `source` column to `legislative_definitions` — "csv_import" for legacy, "parser" for sertantai-extracted (backfilled 34K rows)
- ✅ Add `definitions_parsed_at` column to `legal_register` — set by StagedParser after parsing (even if no definitions found)
- ✅ Create `mix definitions.backfill` task — fetch body XML, parse, upsert with dedup
- ✅ Prove approach: 20-law batch, 0 errors, 437 definitions upserted
- ✅ Backfill all 💙 safety families (747 laws, 0 errors, 12,416 defs upserted)
- ⬜ Backfill 💚 environmental families (~2,500 remaining unparsed laws)
- ⬜ Run CSV scope backfill (`--scope csv` for scope improvement on legacy data)
- ⬜ Update NAS snapshot after backfill

## Resume Notes

**To continue backfilling environmental families**, run these commands one at a time:

```bash
cd backend
mix definitions.backfill --family "AGRICULTURE"
mix definitions.backfill --family "FISHERIES"
mix definitions.backfill --family "WILDLIFE"
mix definitions.backfill --family "ENERGY"
mix definitions.backfill --family "Harbours"
mix definitions.backfill --family "ANIMALS"
mix definitions.backfill --family "WATER"
mix definitions.backfill --family "ENVIRONMENTAL PROTECTION"
mix definitions.backfill --family "WASTE"
mix definitions.backfill --family "TOWN & COUNTRY"
mix definitions.backfill --family "PLANNING & INFRASTRUCTURE"
mix definitions.backfill --family "CLIMATE"
mix definitions.backfill --family "PLANT HEALTH"
mix definitions.backfill --family "MARINE"
mix definitions.backfill --family "Roads & Vehicles"
mix definitions.backfill --family "Railways"
mix definitions.backfill --family "NUCLEAR"
mix definitions.backfill --family "POLLUTION"
mix definitions.backfill --family "Employment"
```

Check remaining with: `mix definitions.backfill --dry-run`

After all families done, run CSV scope backfill: `mix definitions.backfill --scope csv`

Then NAS snapshot: `./scripts/nas/nas-backup.sh --db-only`

## Dependencies

- ✅ Definition Schema & Storage (table + 34K rows)
- ✅ Definition Parser (XPath + regex, pipeline integration)
- ✅ Definition API (delta sync, REST, Zenoh)

## Architecture Notes

The backfill task needs to fetch `/body/data.xml` from legislation.gov.uk for each law — this is the same XML the scrape pipeline fetches. The parser runs on the raw XML, not on LAT data. Rate limiting applies (2s between requests), so 1,469 laws = ~49 minutes minimum.

## Acceptance Criteria

Scope null rate reduced significantly (target: <15%). Random sample of 20 laws shows ≥90% term accuracy between CSV and parser. Backfill task is reusable for future re-extraction. NAS snapshot updated.

---

## Validation Report: 20-law random sample

### Summary

| Metric | Value |
|--------|-------|
| Exact matches (all terms agree) | 3 / 20 (15%) |
| Fetch failures | 0 / 20 |
| CSV total terms | 413 |
| Parser total terms | 346 |
| Common terms (intersection) | 318 (77% of CSV) |
| Scope: null before | 228 |
| Scope: with scope after parse | 284 |

### Gap categories

**1. No `Class="Definition"` list in XML (parser finds 0)** — 3 laws

Some laws define terms inline in running `<Text>` elements without structured `<UnorderedList Class="Definition">` markup. The parser only finds the structured lists. Examples:
- `UK_ssi_2003_235` — 31 CSV terms, 0 parsed (Scottish SI, no curly quotes at all)
- `UK_nisr_2010_160` — 5 CSV terms, 0 parsed (NI rule, has curly quotes but no Definition class)
- `UK_nisr_2009_378` — 1 CSV term "coarse fish", 0 parsed (inline definition in Text element)

**2. CSV has terms the parser doesn't find** — common patterns:
- Terms from schedules or later sections not in Definition lists
- Terms that legl extracted from running text or amendment context
- Older/non-standard formatting without curly quotes

**3. Parser finds terms the CSV doesn't have** — some laws have definitions the CSV missed:
- `UK_uksi_2023_680` — parser found 4 extra terms
- `UK_uksi_2011_2305` — parser found 6 extra terms (CSV missed some)

**4. Scope improvement** — re-parsing fills scope gaps:
- `UK_uksi_2010_104` — 2 null scope → 42 with scope after parse
- `UK_uksi_2011_2305` — 2 null scope → 27 with scope
- `UK_wsi_2006_3245` — 26 null scope → 0 with scope (all filled!)

### Parser edge cases to fix

1. **Inline definitions without `Class="Definition"` markup** — the main gap. Some laws (especially Scottish SIs, NI rules, and older legislation) define terms in running text without structured lists. Would require a fallback regex scan of all `<Text>` elements for `\u201cterm\u201d means...` patterns.

2. **Term name differences** — minor normalisation mismatches between CSV and parser:
   - `"directive2002/70/ec"` (CSV, no space) vs `"directive 2002/70/ec"` (parser, with space)
   - Long descriptive terms from schedules that the parser correctly ignores

3. **Scottish SIs without curly quotes** — `UK_ssi_2003_235` has no curly quotes at all in its XML. Definitions may use straight quotes or a different format entirely.
