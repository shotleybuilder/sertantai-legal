---
session: 'LAT Change Pipeline: Code Reduction'
status: pending
release: v0.1
opened: '2026-11-03'
parent: archive/change-vocabulary/2026-10-30-cv-s12-retrospective.md
---

# Session: LAT Change Pipeline: Code Reduction (PENDING)

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

- ⬜ Plan in plan mode: choose the cuts, the proof for each, a time box
- ⬜ Mix tasks: delete those no live workflow uses; merge the check tasks' shared tallies into tested modules; split `mix lat.vocabulary`
- ⬜ Tests: fold the per-round extent test files into class tests; drop provision-only duplicates the catalogues cover
- ⬜ Fixtures: prune the catalogue fixtures to what each class needs (catalogue tests still pass)
- ⬜ Long files: split the worst offenders where they mix concerns (`commencement/order.ex`, `readers/feed.ex`, `readers/markup.ex`)
- ⬜ Database (Jason's go): drop the snapshot tables after a NAS backup, plus `rp9` and the orphans
- ⬜ The old label path: written plan only. It retires family by family as families switch, never in this session

## Dependencies

- ✅ `docs/lat-change-pipeline/` written (DATA-ARCHITECTURE, TESTING, WORKFLOW): the targets are judged against them
