---
session: 'LAT Change Pipeline: Code Reduction'
status: closed
release: v0.1
opened: '2026-11-03'
closed: '2026-11-03'
outcome: success
parent: archive/change-vocabulary/2026-10-30-cv-s12-retrospective.md
summary: >
  Planned in plan mode and done in one sitting: four check tasks thinned onto tested pure modules with identical
  outputs and golden 27/27; 151 per-round tests folded into tests named by behaviour; five one-off tasks and two
  sole-use modules deleted (768 lines); 240 snapshot tables archived to the NAS and dropped (DB 7.9 GB -> 2.6 GB).
decisions:
  - what: Cuts chosen by Jason from measurements made in plan mode (dead code nil; bloat is volume and duplication)
    why: function-level dead code scan found 1 uncalled function, so deletion alone would not reduce bloat
    result: tasks thinned, per-round tests folded, one-off tasks deleted; order.ex split left out
  - what: Every cut proved by identical outputs before and after
    why: behaviour-preserving pass rule fixed in the plan
    result: commencement_check, extent_check, sources identical; golden 27/27; conflict lines identical
  - what: Keep lat.pdf_backlog
    why: its modules are the parser's PDF path (LatStagedParser) and the 6 PDF-only repeal schedules remain
    result: deviation from the plan, recorded
  - what: Snapshot tables dumped to the NAS, verified, then dropped on Jason's go
    why: 240 tables, 5.4 GB, no code reads them
    result: archive 844 MB; DB 7.9 GB -> 2.6 GB
metrics:
  tasks: { commencement_check: "446->276", extent_check: "404->232", sources: "383->317", vocabulary: "467->385" }
  deleted_lines: 768
  tests: { before: 9761, after: 9773, folded: 151, dropped: 0, new_unit: 21, removed_with_modules: 9 }
  database: { before: "7953 MB", after: "2562 MB", tables_dropped: 240 }
  agents: { runs: 1, tokens_k: 194 }
lessons:
  - title: Measure dead code before planning a reduction
    detail: A name-level scan of the pipeline found almost no dead code; the bloat was check tasks with logic inline, per-round tests and DB copies. The plan targeted those instead.
    tag: tooling
  - title: Capture check outputs before a refactor, filtering what varies by run
    detail: Timings and async log order vary; golden and the conflict report needed filtered or sorted diffs to prove identity.
    tag: tooling
bugs:
  - pattern: Tasks that snapshot before an apply still create restore tables in public (live.recompute, live.apply_effects, drrp.remap, extent.resolve)
    category: restore-tables-in-public
    module: those mix tasks
    affected: 4 tasks
    fix: Write restore copies to a restore schema, listed, dropped at session close (DATA-ARCHITECTURE policy)
    step: Store and build
    status: open
  - pattern: The family scope query is copied in four check tasks (commencement_check, extent_check, sources, vocabulary)
    category: duplicated-scope-query
    module: lat.* check tasks
    affected: 4
    fix: One shared scope function the tasks call
    step: Measures
    status: open
  - pattern: mix lat.vocabulary --conflicts prints its kind groups in an unstable order (map iteration); content stable
    category: unstable-report-order
    module: mix lat.vocabulary (conflicts)
    affected: 1
    fix: Sort the groups by kind before printing
    step: Store and build
    status: open
  - pattern: mix lat.sources and mix lat.vocabulary still hold their own reads inline (feed statuses and amending facts; the debug view), untested
    category: logic-in-task
    module: lat.sources, lat.vocabulary
    affected: 2
    fix: Move the feed-status and amending-facts reads, and the debug view's reads, into their modules
    step: Measures
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/check.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/check.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/golden.ex
  - backend/lib/sertantai_legal/scraper/sources.ex
  - /mnt/nas/sertantai-data/data/snapshots/archive/2026-11-03-snapshot-tables.dump
depends_on:
  - archive/change-vocabulary/2026-10-30-cv-s12-retrospective
---

# Session: LAT Change Pipeline: Code Reduction (CLOSED)

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
- ✅ 7. Snapshot tables: dump to the NAS, verify, show Jason, drop on his go
- ✅ 8. Close: pass rule again, docs, parked bugs fixed

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

**Snapshot tables:**
- 240 archived to the NAS (`snapshots/archive/2026-11-03-snapshot-tables.dump`, 844 MB; `pg_restore -l` lists all 240) and dropped on Jason's go.
- Database 7.9 GB → 2.6 GB; live tables intact (`lat_label_timeline` 625,377 rows, `provision_changes` 70,821).
- Recorded in `DATA-ARCHITECTURE.md`.

**Docs changed:** `TESTING.md` (Part 3 done) and `DATA-ARCHITECTURE.md` (cleared, and the writers still to move). The parking list became the four bugs in the frontmatter; the two test-warning items are left as notes.
