---
session: Definition Backfill & QA
status: closed
opened: 2026-08-13
closed: 2026-08-17
outcome: partial

summary: >
  Bulk definition backfill completed (34K CSV + 34K parser = 68K total). Built mix
  definitions.backfill task, fixed 15+ parser edge cases across 3 deep-dive laws
  (RRFSO, WEEE, EP Regs), replaced root_definition_id FK with definition_links
  junction table. Outstanding data QA items carried to new session (2026-08-17).

decisions:
  - what: Junction table replacing single FK root_definition_id
    why: Gemini review flagged FK integrity concerns for customer-facing data — a term can have multiple root definitions (e.g. England vs Wales provisions)
    result: definition_links table with composite PK, CASCADE, 936 links migrated

  - what: Keep revoked law definitions
    why: Useful for term evolution over time; compliance frontend filters on live status
    result: Marked as abandoned rather than deleted

metrics:
  definitions: { csv_imported: 34483, parser_extracted: 33518, total: 68001 }
  backfill: { safety_families: 12416, environmental: 18000, errors: 0 }
  parser_fixes: { edge_cases: 15, laws_deep_dived: 3 }
  junction_table: { links_migrated: 936 }

lessons:
  - title: Fingerprint-based section_id lookup is fundamentally broken for multi-section definitions
    detail: >
      Definition lists outside the main Interpretation section (e.g. reg-67-4 in
      Environmental Permitting Regs) got wrong section_ids because find_section_id
      used Enum.find with text containment — first match wins, not closest ancestor.
      Deferred to parser refactor which fixed it via top-down P2/P1 walk.
    tag: data

  - title: EU directive definitions use curly single quotes, not double
    detail: >
      EU directives use Unicode curly single quotes (U+2018/U+2019) for term
      definitions, not the curly double quotes (U+201C/U+201D) used by UK domestic
      legislation. Parser needed separate patterns for both quote types.
    tag: data

  - title: Pronoun references need sibling context for resolution
    detail: >
      "that Act" in a definition can only be resolved by looking at sibling
      definitions in the same section that name the Act explicitly. Built a
      sibling_index keyed on (law_name, section_id) to enable this.
    tag: data

artifacts:
  - backend/lib/mix/tasks/definitions.backfill.ex
  - backend/lib/sertantai_legal/legal/definition_link.ex
  - backend/lib/sertantai_legal/scraper/root_resolver.ex
  - backend/lib/sertantai_legal/scraper/definition_parser.ex
  - backend/lib/sertantai_legal/scraper/definition_persister.ex

depends_on:
  - interpretation-definitions/2026-08-13-definition-schema-storage
  - interpretation-definitions/2026-08-13-definition-parser
  - interpretation-definitions/2026-08-13-definition-api

enables:
  - interpretation-definitions/2026-08-17-definition-data-qa
---

# Session: Definition Backfill & QA (CLOSED)

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
  - ⏸️ Update ElectricSQL shape to include definition_links (carried to 2026-08-17-definition-data-qa)
- ✅ **UK_uksi_2013_3113 (WEEE Regs): Amendment markup + EU directive references**
  - ✅ Parser: `xmerl_text` tree walk on `<Text>` elements instead of `xpath(.//Text/text())` — fixes `<Addition>`-wrapped definitions
  - ✅ Parser: widen citation pattern to catch `<name> directive` abbreviations (waste directive, habitats directive, etc.)
  - ✅ Resolver: `internal_ref?` now excludes definitions mentioning "Directive" (they're cross-law, not internal)
  - ✅ Resolver: abbreviation citation lookup — "the Waste Directive" → citation_index → full directive title
  - ✅ Re-parsed WEEE: 98→106 defs, 10/11 orphans now have `referenced_law_citation` (1 is genuinely internal)
- ✅ **Parser: curly single quotes (`\u2018`/`\u2019`) for EU directive definitions**
  - ✅ Fix: `@inline_def_pattern`, `@single_quote_term_pattern`, splitter, and `extract_single_term` all handle curly single quotes
  - ✅ Fix: Strategy 2 P1 fallback scan for directives with no P2 wrapper
  - ✅ Parsed EU Waste Directive 2008/98/EC: 0→26 definitions
  - ✅ Resolver: `extract_eu_law_name/1` converts EU citations to law_name format (e.g. `UK_eudr_2008_98`), wired into `resolve_to_root` as fallback. 9/10 WEEE orphans now linked to Waste Directive (1 term normalisation mismatch: reuse vs re-use)
- ⬜ **UK_uksi_2016_1154 (Environmental Permitting Regs)** — 3 patterns found
  - ✅ `regulatory provisions` — `@def_after_term_suffix` regex: `[^,]*` after "meaning" consumed law title with internal comma. Fixed to only consume qualifier words (given/assigned/specified + by/in/to/under)
  - ✅ `undertaking` — `@abbreviation_re` was too greedy, matched "same meaning as in the Waste Framework Directive" instead of just "Waste Framework Directive". Fixed to anchor on capitalised words (`[A-Z]\w*`). Now resolves to citation_only (parent law exists but term not defined there)
  - ✅ `local authority` self-ref linked: reg-2-1 → reg-6-1. Root cause: Strategy 3 dedup used `term` only. Fixed to `{term, section_id}`. Resolver now links internal refs to same-law root defs.
  - ✅ `emission`/`emission plan`/`transitional national plan` at reg-67-4: section_id fingerprint bug fixed by parser architecture refactor (2026-08-17). Re-parse needed to apply fix (carried to 2026-08-17-definition-data-qa).
  - 7 internal refs (`class`, `disposal`, `exempt groundwater activity`, etc.) — root defs not extracted from target regulation/schedule sections. Deeper parser gap for another session.
- ⏸️ Investigate 1,541 empty-definition parser records across 133 laws (carried to 2026-08-17-definition-data-qa)
- ⏸️ Fix 3 UTF-8 encoding errors in persister (carried to 2026-08-17-definition-data-qa)
- ⏸️ Run CSV scope backfill (carried to 2026-08-17-definition-data-qa)
- ⏸️ Update NAS snapshot (carried to 2026-08-17-definition-data-qa)

## Resume Notes

**Status (2026-08-17)**: Major session covering 3 laws (RRFSO, WEEE, EP Regs). All committed and pushed. 69 tests passing.

**What was done this session (2026-08-17)**:
- Junction table (`definition_links`) replacing single FK `root_definition_id` — Gemini-reviewed decision for customer-facing data integrity
- Parser: 3 new Strategy 3 patterns (P1 scan, parenthetical "referred to as", scope fix), `<Addition>`-wrapped text fix, curly single quotes for EU directives, P1 fallback in Strategy 2, citation pattern for `<name> directive`, comma-in-law-title fix, Strategy 3 skip for P2s with Definition lists, dedup fix `{term, section_id}`
- Resolver: pronoun "that Act" resolution, abbreviation citation lookup, `internal_ref?` excludes Directives, `extract_eu_law_name/1` for EU law matching, self-referential linking within same law
- Parsed EU Waste Directive 2008/98/EC (26 defs), WEEE→Waste Directive links working, Housing Act 2004 both England+Wales defs linked

**Blocked on**: `find_section_id` fingerprint bug — Definition lists outside reg-2 get wrong section_id. Deferred to parser refactor session (2026-08-16-definition-parser-refactor.md).

**Next steps**:
1. Parser refactor session (pending) — fix `find_section_id`, add `:source` provenance, single dedup function
2. After refactor: re-parse all laws to fix stale `references_other_law` flags and section_id misattributions
3. Then: investigate 1,541 empty-definition records, CSV scope backfill, NAS snapshot
4. GitHub issues raised: #145 (term normalisation re-use/reuse), #146 (broken cross-ref chain detection feature)

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
