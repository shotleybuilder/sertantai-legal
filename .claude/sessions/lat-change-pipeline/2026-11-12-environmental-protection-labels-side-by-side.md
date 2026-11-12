---
session: "Environmental Protection: Labels side by side"
status: closed
opened: 2026-11-12
closed: 2026-11-12
outcome: success

summary: >
  Step 12 for 💚 ENVIRONMENTAL PROTECTION passed on every rule, with no code changes and no agent pass. The fold's 69,136 periods for 122 laws and 35,766 rows break none of the table's rules. Against today's old-path timeline, 13,229 rows agree, 17,872 differ today, 2,366 differ only in history and 2,299 have no stored timeline. That is the Switch-over's baseline, and territory alone (7,736 rows) is its largest class.

decisions:
  - what: "Golden not re-run: Store and build's 27/27 from inputs stands"
    why: "no code changed since db2e9869, so a re-run would read the same inputs with the same code (no needless corpus runs)"
    result: "golden 27/27 cited"

metrics:
  side_by_side: { laws: 122, rows: 35766, periods: 69136, breaks: 0, agree: 13229, differ_today: 17872, history_only: 2366, no_today: 2299 }
  differences: { territory_only: 7736, territory_any: 10014, in_force_from_only: 2747, changed_by_only: 2594, status_any: 2143 }
  gaps: { undated_change: 6961, undated_start: 1952 }
  timings: { strata_cold_s: 473, strata_warm_s: 8, workers: 1 }
  repeatable: "two runs identical, log lines filtered out"
  tokens: { agent: 0 }

lessons:
  - title: "The gate's fold cache did not serve --strata the next day"
    detail: "Store and build's Label fold gate folded EP's 122 laws, yet --strata's first run the next day folded cold (7 min 53 s with 1 worker; Maritime's was about 90 s with workers). The second run took 8 s. Expect a cold first run after any build. Time it before calling the run seconds-long."
    tag: tooling

artifacts:
  - backend/data/reports/labels-side-by-side/environmental-protection-strata.txt (gitignored)
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-11-environmental-protection-store-and-build.md

enables:
  - "Environmental Protection: Switch-over"
---

# Session: Environmental Protection: Labels side by side (CLOSED)

## Problem

Step 12 for "💚 ENVIRONMENTAL PROTECTION", which is not yet switched: build the new labels beside today's old-path timeline without writing anything, and count every difference as the Switch-over's baseline. No bugs are parked on this step, and there is no agent pass (none by design). Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session; `--strata`, saved to `backend/data/reports/labels-side-by-side/environmental-protection-strata.txt`
- ✅ Second `--strata` and diff; pass rule (0 breaks, totals add up, gaps by shape); profile against Maritime and OH&S, surprises parked
- ✅ Golden: Store and build's 27/27 from inputs stands (no code changed), or a fresh run plus `mix test` if code changes
- ✅ Docs and close: WORKFLOW step 12 line, meta row, session close, `--no-verify` commit by path

## Pass rule (fixed)

1. 0 periods break the table's rules.
2. The four side-by-side totals are printed and add up to the rows folded.
3. The gaps are printed by shape.
4. A second run's output is identical, log lines filtered out.
5. Golden 27/27.

## Dependencies

- ✅ Environmental Protection: Store and build (closed 2026-11-11, db2e9869): 0 stale, Label fold gate PASS

## Side by side

The baseline is saved at `backend/data/reports/labels-side-by-side/environmental-protection-strata.txt`, which is gitignored, like Maritime's.

- **Runs.** The cold run took 7 min 53 s, with 1 worker while the VM ran; the fold cache from Store and build's gate didn't serve it. The warm run took 8 s. With log lines filtered out, the two outputs are identical.
- **122 laws folded, 35,766 rows, none unfolded.**
- **Timeline rows:** 69,136 periods, 0 breaking the table's rules.
- **Side by side:** 35,766 = 13,229 agree + 17,872 differ today + 2,366 differ only in history + 2,299 no stored timeline. The four totals add up.
- **Gaps by shape:** undated_change 6,961 and undated_start 1,952, matching the Label fold gate.

**How EP compares** (the Switch-over's work begins here):

| Family | Rows | Agree | Differ today | History only | No stored timeline |
|---|---|---|---|---|---|
| Environmental Protection | 35,766 | 37% | 50% | 7% | 6% |
| Maritime Safety (2026-11-06) | 24,434 | 77% | 10% | 4% | 9% |
| OH&S (2026-10-31) | 20,371 | — | 81% (with history) | | |

- **Territory is the largest difference class:** 7,736 rows differ on territory alone, and territory appears in 10,014 rows in all. Behind it, EP has more rows than Maritime in these shapes: `applied` 5,725, `territory_narrowed` 1,708, `version` 1,709 and `in_force_for` 838. Many EP laws extend to part of the UK, or have territorial versions. This is the Switch-over's first class to explain, and no fault is shown yet.
- **The next classes:** in_force_from alone 2,747, changed_by alone 2,594, both 1,422. Status differs in 2,143 rows.

## Golden

No code changed in this step, so Store and build's run from inputs stands: 27/27 (2026-11-11, at db2e9869). `mix test` likewise needs no re-run.

## Parking list

- Switch-over: the territory-only differences (7,736 rows), the largest class to explain first. This is the baseline's profile, not a bug.
