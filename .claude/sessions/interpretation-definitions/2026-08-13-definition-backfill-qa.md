---
session: Definition Backfill & QA
status: active
opened: 2026-08-13
---

# Session: Definition Backfill & QA (ACTIVE)

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
- ✅ Backfill 💚 environmental families + all remaining making laws (0 errors)
- ✅ Fix parser: `<Abbreviation>` elements causing 472 empty-term records
- ✅ Re-parse 472 affected laws, delete orphaned empty-term records
- ✅ Add `--file` flag to backfill task for batch re-parsing
- ✅ Fix parser: strip all quote types (curly, straight, backtick) from terms
- ✅ Fix parser: multiple `<Term>` elements in one ListItem (paired terms via `<Term>`)
- ✅ Fix parser: `<Acronym>` child elements inside `<Term>` (xmerl tree walker)
- ✅ Fix parser: strip `...` and `…` amendment markers from terms
- ✅ Add `citation` boolean column — flags law title abbreviations (e.g. "1961 act")
- ✅ Backfill citation flag (3,691 records) + parser now sets it automatically
- ✅ Fix parser: delegated definitions — preamble text as definition for "meanings given by..." lists
- ✅ Re-parsed 100 laws to restore empty-def records for investigation
- ✅ **Self-referential linking: UK_uksi_2005_1541 (Fire Safety Order)** — 10 orphan delegated defs
  - ✅ `responsible person` — P1-level Term scan (fix 2)
  - ✅ `general fire precautions` — P1-level Term scan (fix 2)
  - ✅ `enforcing authority` — scope fix: "For the purposes of this Order" → `:law` (fix 1)
  - ✅ `alterations notice` — parenthetical "referred to as" pattern (fix 3)
  - ✅ `enforcement notice` — parenthetical pattern (fix 3)
  - ✅ `prohibition notice` — parenthetical pattern (fix 3)
  - ✅ `licensing authority` — already worked (Strategy 3 P3 pattern)
  - ✅ `higher-risk building` — "that Act" pronoun resolver (inherits "Building Safety Act 2022" from sibling)
  - ✅ `residential unit` — same pronoun resolver fix
  - ✅ `local housing authority` — widened unique index, re-parsed Housing Act 2004 (143→180 defs), junction table links to both England (s.261-2) and Wales (s.261-4)
- ✅ **Replace root_definition_id with definition_links junction table** — Gemini review recommends FK integrity for customer-facing legal data
  - ✅ Create `definition_links(child_definition_id, root_definition_id)` with composite PK + CASCADE
  - ✅ Migrate existing 936 root_definition_id links into junction table
  - ✅ Drop root_definition_id column from legislative_definitions
  - ✅ Deleted the uuid[] migration (20260816121000) — never ran, superseded by junction table
  - ✅ Update Ash resource (many_to_many via DefinitionLink, registered in domain)
  - ✅ Update RootResolver to write to junction table (def_index stores lists, apply_updates writes to definition_links)
  - ✅ Controller/API — no references to old column, clean
  - ⬜ Update ElectricSQL shape to include definition_links
- ⬜ Investigate 1,086 empty-definition parser records across 89 laws (non-citation, real parser bugs)
- ⬜ Fix 7 UTF-8 encoding errors in persister (truncated multi-byte sequences)
- ⬜ Run CSV scope backfill (`--scope csv` for scope improvement on legacy data)
- ⬜ Update NAS snapshot after backfill

## Resume Notes

**Status (2026-08-15)**: All making laws backfilled (66K+ definitions). Parser fixes committed but not pushed. 1,086 empty-definition records remain across 89 laws — these are **parser bugs to investigate**, not deletable noise.

**Uncommitted changes**: Parser fixes + citation column. Run `git status` to see, then commit and push.

**Next step: investigate empty-definition parser bugs**

1. legislation.gov.uk was down (504) when we suspended. Wait for it to come back.
2. Query the empty-def records: `SELECT term, law_name FROM legislative_definitions WHERE (definition IS NULL OR trim(definition) = '') AND source = 'parser' AND citation = false ORDER BY law_name;`
3. Pick a law (e.g. `UK_uksi_1975_2116` — has "best practicable means" with empty def), fetch its body XML, and examine what the Definition list looks like.
4. The pattern is: parser extracts the term from the ListItem but fails to extract the definition text. TDD: write a test with the failing XML, fix the parser, re-parse affected laws.
5. After fixing, delete any remaining genuinely empty records.

**After empty-def fix**:
- Run CSV scope backfill: `mix definitions.backfill --scope csv`
- NAS snapshot: `./scripts/nas/nas-backup.sh --db-only`

**DB stats (2026-08-15)**:
- Total definitions: ~65K (after 1,160 empty deletions + re-parse)
- Parser-extracted: ~55K, CSV legacy: ~11K
- Citation flagged: 3,691
- Empty definitions: 1,086 (bug — to fix)
- Null scope: ~41%

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
