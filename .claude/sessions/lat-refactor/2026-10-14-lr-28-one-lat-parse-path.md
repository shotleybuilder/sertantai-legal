---
session: 'LR-28: One LAT Parse Path'
status: active
opened: 2026-10-14
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-28 One LAT Parse Path (ACTIVE)

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
- ⬜ **Jason: D1** (one-off in-place writers)
- ⬜ CLAUDE.md (scraper) updated: one parse path

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
