---
session: 'LR-28: One LAT Parse Path'
status: closed
opened: 2026-10-14
closed: 2026-10-14
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  Every LAT parse now reaches legal_articles / amendment_annotations through LatStagedParser: StagedParser's copy (persist_body_lat) is gone and an architecture test enforces it.
  Five one-off in-place repairs were deleted after a fresh parse of all 1,066 laws showed each fix lives in the parser with a parser-level test (0 rows/notes differ), and the sort-key repair the parser needs moved into LatParser.SortKey.
  The same check found 162 laws behind the parser in label-input columns (logged in LR-25).

decisions:
  - what: "StagedParser's LAT sub-stage calls LatStagedParser (run_stages/5 with the body in hand; parse/1 when scoped)"
    why: "Jason: 'second parse path feels like poor code architecture'; the copy skipped LatCause, the no-body guard and note replacement, and LR-25's hook needs one place"
    result: "architecture test: only LatStagedParser calls LatPersister.persist / CommentaryPersister.persist"
  - what: "Delete lat.fix_section_ids, lat.repair_text (+LatRepair), lat.reorder_notes (+NoteReorder, text_pairs), lat.place_notes (+NotePlacement, fetch_notes)"
    why: "Jason asked whether the parser has the fixes; a fresh in-memory parse of 1,066 laws matched the DB on text, ids, sort keys, titles, note text and placement (0 differ), each fix with a parser-level regression test"
    result: "a fix to parse output lands by re-parse through the one path; suite 2,718 -> 2,691"
  - what: "SortKeyRewrite.monotonic/1 moved to LatParser.SortKey; SortKeyRewrite, its Store and mix lat.rewrite_sort_keys deleted"
    why: "the parser called a function inside a one-off repair module"
    result: "0 sort_key / position / text diff vs DB across 1,066 laws; suite 2,679"
  - what: "lat.backfill_titles kept for now, decided in LR-25 after its wave"
    why: "the only tool that sets one parser-derived column without a re-parse; the parse drift (excluded_extent 451 rows) may need it or a re-parse"
    result: "logged in LR-25"

metrics:
  verification: { laws: 1066, rows: 374866, notes: 89679, rows_differ_text_ids_sortkey_title: 0, notes_differ: 0 }
  parse_drift: { laws: 162, effect_ids_rows: 74151, territory_provenance_rows: 1204, excluded_extent_rows: 451, extent_code_rows: 0 }
  tests: { before: 2718, after: 2679 }

lessons:
  - title: "A wave proves DB = parser at that moment, not that later parser changes reached the DB"
    detail: "Parser code changed after wave 4 (revoked-in-part rule, LR-19 joins, LR-27 container refs) and only the register was rebuilt; 162 laws' stored effect_ids / territory columns fell behind. A staleness check on parse-vs-collect timestamps can't see it; the parse needs a code version (now an LR-25 requirement)."
    tag: data
  - title: "Before deleting a repair tool, prove the fix is in the parser, not just the data"
    detail: "Compare stored data against a fresh parse from the store (read-only) and find a parser-level regression test per bug; one tool (SortKeyRewrite) turned out to hold a function the parser itself calls."
    tag: tooling
  - title: "An architecture test (grep over lib/) is a cheap guard for 'only X may call Y'"
    detail: "lat_write_path_test.exs failed on the copy, passes after; the same pattern is planned for LR-25's note-read guard."
    tag: tooling

artifacts:
  - backend/test/sertantai_legal/architecture/lat_write_path_test.exs
  - backend/lib/sertantai_legal/scraper/staged_parser.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/sort_key.ex
  - backend/test/sertantai_legal/scraper/lat_parser/sort_key_test.exs
  - backend/lib/sertantai_legal/scraper/CLAUDE.md

depends_on:
  - 2026-10-09-lr-04-decomposition

enables:
  - LR-25 parse hook attached in one place
---

# Session: LR-28 One LAT Parse Path (CLOSED)

## Problem

A LAT parse is written to `legal_articles` along two routes:
- `LatStagedParser`, used for reparses, `mix lat.reparse`, `lat.scope`, the admin controller and scoped laws;
- a copy in `StagedParser.persist_body_lat` for unscoped making laws found by the LRT scrape. It runs `LatParser.parse` → `LatPersister.persist` → its own commentary sub-stage, and skips:
  - `LatCause`, so the parse's cause is never logged;
  - the no-body/PDF-backlog guard;
  - persisting an empty note list, so a re-scrape with no notes keeps the old ones as orphans.

Jason (2026-10-14): "second parse path feels like poor code architecture". LR-25's after-parse hook (collect + timeline) must attach in one place, so this comes first.

## Todo

- ✅ Tests first (red): an architecture test that only `LatStagedParser` calls `LatPersister.persist` and `CommentaryPersister.persist`
- ✅ `persist_body_lat` and `maybe_run_commentary_substage` replaced by `LatStagedParser.run_stages/5` (green); behaviour differences listed
- ✅ Other writers of `legal_articles` listed (targeted repair tools: `mix lat.repair_text`, `mix lat.fix_section_ids` #120) with a decision each: route through the same post-write step, or delete
- ✅ Gate: full suite 2,718 pass; credo unchanged on `staged_parser.ex`. `mix lat.parse_snapshot` not run: no parser module changed (only which caller persists), so it can't differ
- ✅ **Jason: D1** (2026-10-14): "Delete the 4. Log the other two in the correct session for sequencing and eventual fix". Deleted `lat.fix_section_ids`, `lat.repair_text` + `LatRepair`, `lat.reorder_notes` + `NoteReorder` + `CommentaryParser.text_pairs/1` / `legacy_commentary_text/1`, `lat.place_notes` + `NotePlacement` + `LatStagedParser.fetch_notes/2`, with their tests (suite 2,718 → 2,691 pass)
- ✅ `SortKeyRewrite.monotonic/1` into the parser's own modules (e.g. `LatParser.Transforms` or a `LatParser.SortKey`), its tests (`sort_key_rewrite_test.exs:87–141`) moved with it (TDD: red against the new name, then move); then delete `SortKeyRewrite` + `SortKeyRewrite.Store` (the one-off in-place sort-key repair, `Store.plan(:all)` = 0 rows). Zero diff: `mix lat.parse_snapshot`
- ⏸️ `lat.backfill_titles`: logged in LR-25 (decided after its wave)
- ✅ CLAUDE.md (scraper) updated: one parse path

## Dependencies

- ✅ LR-04 decomposition (LatParser orchestrator); `LatStagedParser.run_stages/5` already public (used by `PdfBacklog.Batch`)

## Build (2026-10-14)

**Red then green.** The test is `test/sertantai_legal/architecture/lat_write_path_test.exs`: only `LatStagedParser` (plus the persisters' own doc examples) may call `LatPersister.persist(` or `CommentaryPersister.persist(`. It failed on `staged_parser.ex`, as expected, and passes now.

**Change.** `StagedParser.run_lat/4` replaces `persist_body_lat`, `run_scoped_lat` and `maybe_run_commentary_substage`. A scoped law goes to `LatStagedParser.parse/1`, as before; any other law goes to `LatStagedParser.run_stages/5` with the body already fetched. Four aliases were dropped.

**Behaviour differences, all toward the main path:**

| Case | Old copy | Now |
|---|---|---|
| The parse's cause | never logged | `LatCause` logs it |
| A body that yields no rows | `LatPersister` refuses (existing LAT kept) | same refusal, and PDF alternatives are queued to the backlog |
| A re-scrape with no notes | old notes kept as orphans | the note set is replaced, i.e. emptied |
| Effects | `law_effects(law, [])` | the same call |

## Other writers of `legal_articles` / `amendment_annotations` (2026-10-14)

**Enrichment writers** (taxa, actors; they never touch parse content or labels): `actors.backfill_role`, `actors.rename_labels`, `drrp.remap`, `zenoh/provision_subscriber`. No action.

**Part of the one path:** `LatPersister.Carry` and `CommentaryPersister`. `LatStatus.Apply` goes in LR-25.

**`LatArchive`** discards a law's LAT on purpose (not Making). It stays. LR-25's hook must cover it as well: an archived law's register and timeline rows are deleted.

**One-off in-place repairs.** Each was written to patch stored rows without a re-parse, before wave 4 re-parsed every law from the store with the fixed parser:

| Task | Fixed | Last touched |
|---|---|---|
| `lat.fix_section_ids` | #120 doubled section ids | 2026-09-26 |
| `SortKeyRewrite.Store` | sort keys | 2026-09-27 |
| `lat.repair_text` | the old list-text bug | 2026-10-08 |
| `lat.reorder_notes` | note text order | 2026-10-08 |
| `lat.place_notes` | note placement | 2026-10-08 |
| `lat.backfill_titles` | titles, `excluded_extent` | 2026-10-08 |

Each writes parse content (text, ids, note placement, `excluded_extent`) outside the parse, and the register and timeline depend on that content.

## Decisions for Jason

**D1 — the one-off in-place repairs.**
- Recommend deleting all six, which git history keeps.
- From now on, a repair re-parses the affected laws through the one path (dry run → Jason → apply, as waves have done since wave 2). The parser carries enrichment over (`Carry`), and LR-25's hook then refreshes the register and timeline.
- The cost: a fix is a re-parse of the law, not a patch of its changed rows. This reverses the 2026-10-07 targeted-repair approach, which predates the store and carry-over.
- Alternative: keep them and route each through the same post-write step. That leaves six writers that can drift from the parser.

## Verification of the four deletions (2026-10-14)

Before deleting, an agent compared stored data against a fresh in-memory parse of all 1,066 laws from the store. Text, section ids, sort keys, titles, note text and note placement differ on 0 rows and 0 notes. Each fix sits in the parser with a parser-level regression test:
- #120 P2 wrappers: `lat_parser_test.exs:1918`;
- list text: `:977`;
- note order: `commentary_parser_test.exs:241`;
- note placement: `lat_parser_test.exs:2174`;
- titles: `:1981`.

So a re-parse can't bring any of these bugs back.

## Sort key moved (2026-10-14)

`LatParser.SortKey.monotonic/1` was moved verbatim, with its private helpers.
- **Red:** the 5 monotonic tests, moved unchanged to `test/sertantai_legal/scraper/lat_parser/sort_key_test.exs`, failed until the module existed.
- **Green:** they now pass.

Deleted:
- `Legal.Lat.SortKeyRewrite` (`rewrite/2`, the in-place key correction);
- `SortKeyRewrite.Store`;
- `mix lat.rewrite_sort_keys`;
- their tests.

The docs in `Transforms` and the scraper's CLAUDE.md now point to the new module. Suite 2,691 → 2,679 pass (12 rewrite/store tests gone, 5 monotonic tests moved).

**Gate.** `parse_snapshot` needs a baseline taken before the change, which we didn't have. The database already equals the old parser's output (0 rows differ, checked today), so the gate is a fresh parse of all 1,066 laws with the new module, compared against it: sort_key, position and text differ on **0** rows.
