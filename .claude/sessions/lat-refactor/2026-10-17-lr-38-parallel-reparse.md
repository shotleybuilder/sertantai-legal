---
session: 'LR-38: Parallel Re-parse'
status: closed
opened: '2026-10-17'
closed: '2026-10-17'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: mix lat.reparse runs laws 5 at once from the store (LawRunner), keeping its stop-on-first-failure contract; a whole-corpus re-parse went from 59 to 22 min with labels and rows byte-identical to
  the sequential result.
decisions:
- what: Stop flag, not ordering, keeps the contract
  why: laws are independent (LR-31); the contract is 'no new law after a failure', which a shared flag gives
  result: in-flight laws finish, the rest are listed not started
- what: 5 workers only with --store only
  why: Client's legislation.gov.uk rate limit is a per-process sleep; parallel live fetches would multiply the request rate
  result: live re-parses stay sequential by default
metrics:
  gate_2026_10_17:
    laws: 1066
    errors: 0
    minutes: 22
    sequential_minutes: 59
    labels_compared: 356540
    rows_compared: 374866
    differences: 0
    stale_after: 0
lessons:
- title: A per-process rate limit doesn't survive parallelism
  detail: The legislation.gov.uk client throttles with Process.sleep in the calling process; any worker pool multiplies the request rate unless the pool is offline-only or the limiter is shared.
  tag: infrastructure
artifacts:
- backend/lib/sertantai_legal/scraper/lat_reparse.ex
- backend/lib/mix/tasks/lat.reparse.ex
- backend/test/sertantai_legal/scraper/lat_reparse_test.exs
- backend/data/reports/lat-reparse/lr38_gate.csv
depends_on:
- 2026-10-15-lr-31-pipeline-performance
- 2026-10-16-lr-37-orphan-join-range-effects
enables:
- A8 waves in ~22 min
---

# Session: LR-38 Parallel Re-parse (CLOSED)

## Problem

LR-31 made `mix lat.relabel` and `mix lat.wave_preview` run 5 laws at once (`LawRunner`) but left `mix lat.reparse` sequential: `LatReparse.run` stops at the first error or failed enrichment gate. A whole-corpus wave still takes about an hour (LR-35 61 min, LR-37 59 min) against 18 min for a parallel relabel preview. Jason (2026-10-17): "Reparse timing? Are we using the enhanced workflow" — agreed to parallelise after LR-37.

## Todo

- ✅ `LatReparse.run/2` `workers` option: laws in parallel; on the first error or failed gate no new law starts, laws in flight finish, the rest are reported skipped; PDF-only laws carry on as now (tests first)
- ✅ `mix lat.reparse --workers N` (default 5 with `--store only`, else 1: the client's rate limit is a per-process delay)
- ✅ Gate: a parallel re-parse of every law equals the stored state (0 rows / enrichment / label changes; the corpus was just re-parsed sequentially by the same code) → timing
- ✅ CLAUDE.md / session notes

## Dependencies

- ✅ LR-31 `LawRunner` and the isolation check (a parse writes only its own law's rows)
- ✅ LR-37 applied (stored state = current code's output)

## Result (2026-10-17)

- `LatReparse.run/2` `workers`: `LawRunner` with a shared stop flag; a worker rescues its own law's exception (it's that law's error and stops the run). Reports in input order; `skipped` lists laws never started. 3 tests (parallel order, stop-on-first-failure with at most the in-flight laws finishing, a raising law). `workers: 1` keeps the sequential path.
- **Live fetching stays sequential by default:** `Client`'s rate limit is a per-process `Process.sleep`, so N workers would multiply the request rate to legislation.gov.uk; the task defaults to 5 only with `--store only`.
- **Gate:** NAS backup; labels and rows dumped; `mix lat.reparse --laws <all> --store only --tag lr38_gate`: 1,066 laws, 0 errors, rows 374,866 and enrichment 287,676 carried, 0 changed or dropped; today's labels (356,540) and rows (text hash, effect_ids, excluded_extent, markup_status) **byte-identical** before and after; 0 stale. **Time: 22 min** (08:52–09:14) against 59 sequential (LR-37 wave).
- Full suite passes.
