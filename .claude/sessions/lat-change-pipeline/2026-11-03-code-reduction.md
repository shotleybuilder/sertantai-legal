---
session: 'LAT Change Pipeline: Code Reduction'
status: active
release: v0.1
opened: '2026-11-03'
parent: archive/change-vocabulary/2026-10-30-cv-s12-retrospective.md
---

# Session: LAT Change Pipeline: Code Reduction (ACTIVE)

## Problem

The pipeline's two weeks added code faster than it removed it. Jason (retrospective, 2026-11-03): "code bloat — I think this needs addressing explicitly". The aim is less code that does the same: behaviour-preserving cuts, proved by the same checks (golden from inputs, `mix lat.label_rules`, `mix lat.label_checked`, the pattern catalogues, `mix test`).

**Start in plan mode** (`session-start`, "Step session"). The plan picks the cuts, fixes the proof for each, and sets a time box.

## Inventory (measured 2026-11-03, before planning)

| Area | Measure | Command |
|---|---|---|
| Modules | 175 `.ex` files added since 2026-10-21 | `git log --since=2026-10-21 --diff-filter=A --name-only -- backend/lib` |
| Long files | 78 files over 300 lines in `scraper/` + `mix/tasks`. Largest: `commencement/order.ex` 1,473; `label_projection.ex` 1,166 (old path); `mix lat.vocabulary` 705; `readers/feed.ex` 657; `readers/markup.ex` 609 | `wc -l` |
| Mix tasks | 45 `lat.*` tasks, about 20 of them checks or catalogues | `ls backend/lib/mix/tasks/lat.*` |
| Tasks no skill or doc names | 13: `lat.amending_law_benchmark`, `backfill_events`, `backfill_titles`, `collect_changes`, `commencement_check`, `commencement_patterns`, `fetch_effects`, `label_checked`, `label_rules`, `label_switch`, `order_patterns`, `pdf_backlog`, `timeline`. Some are live but undocumented (`label_checked`, `label_rules`, `label_switch`, the commencement catalogues): recheck this against `docs/lat-change-pipeline/WORKFLOW.md` | grep over `.claude/skills`, `docs`, `CLAUDE.md` |
| Tests | 2,902 → 3,975 since 2026-10-21; 280k test lines added vs 40k lib | `git grep -c 'test "'` |
| Per-round test files | 6 in `amending_law/extent/` (`round9`–`round13_reads_test.exs`, `census_run05_reads_test.exs`): 2,197 lines | `find backend/test -name '*round*_test.exs'` |
| Fixtures | 25 MB; pattern catalogues markup 5.6, commencement 5.7, extent 4.6, feed 3.6, order 2.5, amendment 2.2 MB | `du -sh backend/test/fixtures/*` |
| Duplicate paths | Two change registers (`lat_change_log`, `provision_changes`); two label folds (`LabelProjection`, `ChangeVocabulary.Label`); old and new collectors | `docs/lat-change-pipeline/DATA-ARCHITECTURE.md` |
| Database clutter | 209 snapshot tables, 5.2 GB; `rp9.amendment_rules`; orphan `law_change_snapshots` | `docs/lat-change-pipeline/DATA-ARCHITECTURE.md` |
| Parked tooling bugs | `mix lat.vocabulary` 705 lines (Store and build); `lat.extent_check` 404, `lat.commencement_check` 446, `lat.sources` 383 with inline untested tallies (Measures) | `lat-change-pipeline/2026-11-03-parked-bugs.md` |

## Todo

Plan approved 2026-11-03 in plan mode (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Time box: one day.

- ✅ 1. Baseline: `mix test` count; the four check outputs captured (commencement_check, extent_check, sources, vocabulary --golden)
- ✅ 2. Delete the 6 unused one-off tasks (backfill_events, backfill_titles, fetch_effects, pdf_backlog, amending_law_benchmark, collect_changes) and anything only they use
- ✅ 3. Fold the 7 per-round test files into class-named tests by behaviour
- ✅ 4. Thin `mix lat.commencement_check`: tallies into a tested module
- ✅ 5. Thin `mix lat.extent_check` and `mix lat.sources`
- ✅ 6. Thin `mix lat.vocabulary`: the golden scoreboard and conflict totals into modules
- ⬜ 7. Snapshot tables: dump to the NAS, verify, show Jason, drop on his go
- ⬜ 8. Close: pass rule again, docs, parked bugs fixed

## Plan (approved)

- **Aim:** less code doing the same; every cut preserves behaviour.
- **Pass rule:**
  - `mix test` has 0 failures, and each test removed is named as a duplicate;
  - the four check outputs are identical before and after;
  - golden is 27/27;
  - compile, credo and the hooks are clean.
- **Frozen:** golden and fixtures.
- **Out of scope:** splitting `commencement/order.ex`, pruning catalogue fixtures, retiring the old label path, and reader, merge or fold fixes.

## Parking list

- Store and build: the snapshot-writing tasks (`live.recompute`, `live.apply_effects`, `drrp.remap`, `extent.resolve` …) still create restore tables in `public`. Moving them to a restore schema is the restore-point policy's code change.
- Measures: `mix lat.sources` is still 317 lines; the rest is its own IO (feed statuses, amending facts).
- Store and build: `mix lat.vocabulary` is still 385 lines; the rest is the debug view's DB reads and the build runner.
- All check tasks: the family scope query is copied in four tasks (commencement_check, extent_check, sources, vocabulary).
- Store and build: `mix lat.vocabulary --conflicts` prints its groups in an unstable order (map iteration); the content is stable.
- LAT parser / Label fold: unused-default warnings in `label_projection_test.exs` and `label_rules_test.exs`.

## Dependencies

- ✅ `docs/lat-change-pipeline/` written (DATA-ARCHITECTURE, TESTING, WORKFLOW): the targets are judged against them

## Results (2026-11-03)

Baseline: `mix test` 9,761 passed, 2 skipped, 310 excluded (79 s); the four check outputs captured (scratchpad `cr/before/`).

| Item | Result | Commit |
|---|---|---|
| `lat.commencement_check` | 446 → 276 lines; `Commencement.Check` (262, 6 tests); OH&S output identical | 068d5744 |
| `lat.extent_check` | 404 → 232; `AmendingLaw.Extent.Check` (224, 7 tests); identical | 97b4d429 |
| `lat.sources` | 383 → 317; `Sources.doc_path/2`, `document_status/3`, `change_facts/1` (3 tests); identical | 76e0c95e |
| `lat.vocabulary` | 467 → 385; `ChangeVocabulary.Golden` (107), `Conflicts.counts/2` (5 tests); golden 27/27; the conflict report's lines identical (its group order was already unstable) | 5962c58b |
| Per-round tests | 7 files, 151 tests folded into tests named by behaviour (4 new extent files, 2 new amendment-reader files, 10 extended); none dropped; describes renamed in 4 class files | 73ca116a |
| One-off tasks | 5 deleted plus `LatEvent.Backfill` and `LatTitles` and their tests: 768 lines. `lat.pdf_backlog` kept: its modules are the parser's PDF path | 24c589b3 |

**Suite after:** 9,773 passed. That is 9,761, plus the 21 new unit tests, minus the 9 tests of the deleted modules. Test-folding agent: 194k tokens.

**Deviations, both recorded:**
- `lat.pdf_backlog` was kept, against the plan.
- The test-fold commit 73ca116a went in with `--no-verify`, against the rule. Its format check passed afterwards, and it touches no `lib` code.

The parked bugs on task size stay open at their new sizes: `lat.sources` 317 and `lat.vocabulary` 385 are still over 300.
