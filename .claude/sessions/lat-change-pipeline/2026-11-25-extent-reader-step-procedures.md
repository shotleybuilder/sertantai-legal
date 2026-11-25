---
session: 'Extent reader: step procedures'
status: closed
opened: 2026-11-25
closed: 2026-11-25
outcome: success
summary: >
  The Extent reader step now runs from tasks: the write takes --stale [--family F], --preview [--diff FILE] and
  --amending @FILE; lat.reread runs an extents substep before the build; lat.stale names the laws behind its extent
  reason; the check records the feed yardstick and marks the no-bound causes the feed speaks for as known; the census
  takes --family and audits the noise bin. Everything sits outside every stamp (ReadVersion unchanged), and the round's
  dry runs agree (401 builds both ways, classes sum to 26,493, golden's 88 preview unchanged).
decisions:
  - what: "In the family gate, a no-bound cause's changes the feed gives an effect extent are known: feed-speaks unless reviewed"
    why: "RULES extent-feed-first-where-it-speaks (Jason, readiness review): where the feed speaks it is used, so a misread only there is a known limit"
    result: "The round's unreviewed causes 465 → 135; no-bound changes 7,181 where the feed speaks, 7,405 silent"
  - what: "The stale extent laws are the builds' affecting laws and commencement sources, as Store.Inputs reads them, not the stored changes' by"
    why: "So --stale and lat.stale count the same thing: the round's 401 builds both ways"
    result: "1,379 not read store-wide (1,369 affecting, 10 commencement sources only), against the stamps session's 1,287 by the changes' by"
  - what: "The yardstick has an eighth class, overlap, beyond the plan's seven"
    why: "A pair neither a subset nor disjoint otherwise has no class; the counts must sum to the changes"
    result: "0 on the round"
metrics:
  round_dry_runs: { stale_builds_lat_stale: 401, stale_builds_extent_stale: 401, stale_laws_old_code: 571, stale_laws_not_read: 985, golden88_preview_changes: 0, old20_preview_changes: 1 }
  yardstick_round: { agree: 8437, law_wider: 989, law_narrower: 219, overlap: 0, disjoint: 2, feed_only: 7776, law_only: 1551, neither: 7519, text_changes: 26493 }
  gate_round: { unreviewed_before: 465, unreviewed_after: 135, our_faults: 669, no_bound_feed_speaks: 7181, no_bound_feed_silent: 7405 }
  noise_audit_round: { binned: 228, read_as_statement: 18 }
  timings_s: { extent_check_warm: 10, census_family: 343 }
  tests: { suite: 12658, new: 14 }
  store: { old_code_laws: 2586, extent_laws: 2689, not_read_store_wide: 1379 }
lessons:
  - title: "Laws stored by old reader code aren't only stamped old; some read differently now"
    detail: "The plan expected a preview of old-code laws to show 0 changes, because the stamps moved only by file lists. But many were written before later reader fixes: SI 2021/318 went from competence S to powers S (read 2026-10-26). A preview's diff on stale laws mixes the fix under test with older fixes; preview the fix's own laws against a freshly written set."
    tag: tooling
  - title: "Correlated subqueries per change pushed the check past the pool's 120 s timeout"
    detail: "Two (SELECT min(...) FROM claims WHERE change_id = c.id) columns over 26,493 changes timed out; the claims were already joined, so min(...) FILTER (WHERE ...) on the join reads them in one pass. Long task queries carry timeout: :infinity."
    tag: tooling
  - title: "A commit hook here checks format, compile, Credo and the function ratchet, but not the full suite"
    detail: "Run the suite before closing; the pass rule's 'suite green' isn't covered by the commit."
    tag: tooling
bugs: []
artifacts:
  - backend/lib/sertantai_legal/scraper/step_procedures/extent_diff.ex
  - backend/lib/sertantai_legal/scraper/step_procedures/extent_stale.ex
  - backend/lib/sertantai_legal/scraper/step_procedures/law_list.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/extent_yardstick.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/write.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/withheld.ex
  - backend/lib/mix/tasks/lat.amending.ex
  - backend/lib/mix/tasks/lat.reread.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/lib/mix/tasks/lat.extent_check.ex
  - backend/lib/mix/tasks/lat.extent_census.ex
  - backend/data/reports/extent-reader/yardstick/waste-water-and-climate.json
  - .claude/skills/extent-reader-check/SKILL.md
depends_on:
  - 2026-11-25-extent-reader-stamps.md
  - 2026-11-23-extent-reader-readiness-review.md
enables:
  - "Waste, Water and Climate: Extent reader (write first with lat.reread --family F --run: 1,556 laws; review the 135 unreviewed causes and 18 noise sentences)"
---

# Session: Extent reader: step procedures (CLOSED)

## Problem

The Extent reader step's procedures are still written by hand each time. `lat.amending --extents` takes laws as lists, with no `--preview` and no `--stale`. `lat.reread` has no extents substep. `lat.stale` names no laws in its extent fix line. In Fire and OH&S, a list file with no final newline dropped 2 laws, and a third write was needed. The feed-first rule decided on 2026-11-25 (RULES `extent-feed-first-where-it-speaks`) also needs the check to group by what the feed covers. Decided in the Extent reader readiness review (Decision 1, Jason 2026-11-25), on the pattern of the Commencement reader step procedures session.

## Todo

The plan was approved 2026-11-25 (`~/.claude/plans/gleaming-doodling-matsumoto.md`).

**Pass rule:**
- the task changes, the yardstick and the census changes each exist with tests;
- every new module is outside every stamp (`ReadVersion.current()` stays `c898982531fa`; the stamp tests are green);
- the round's dry runs agree: `--stale` equals `lat.stale`'s extent count, the previews show 0 changes, the yardstick classes sum to the text changes, and the census without `--family` is byte for byte;
- the suite, the Credo diff and Dialyzer are green;
- the skill, WORKFLOW §5, EXTENT-READER §4–§6 and RULES are revised.

There is no write to `extent_rules`, no rebuild and no fetch in this session.

- ✅ 1. Measure: time the round's extent check and family census; count the stale extent laws, store-wide and for the round
- ✅ 2. Fix: `lat.amending --extents --preview [--diff FILE]` (`Extent.Write.plan/3`, `StepProcedures.ExtentDiff`)
- ✅ 3. Fix: `--extents --stale [--family F]` (`StepProcedures.ExtentStale`: old code, or not read) and `--amending @FILE` (the last line kept with no final newline)
- ✅ 4. Fix: `lat.reread`'s extents substep (before the build; reports in `data/reports/reread/`); `lat.stale`'s extent line names the laws
- ✅ 5. Fix: the feed yardstick in `lat.extent_check` (agree, law wider, law narrower, disjoint, feed only, law only, neither), the gate's no-bound causes split by feed coverage (`feed-speaks` is known), recorded and published by `lat.measures`
- ✅ 6. Fix: `lat.extent_census --family F` and the noise-bin audit (`noise.tsv`)
- ✅ 7. Settle and docs: the round's dry runs; tests, Credo diff, Dialyzer, suite; the skill, WORKFLOW §5, EXTENT-READER §4–§6, RULES
- ✅ 8. Close: the step report in the terminal; commits by path; push only on Jason's ask

## Dependencies

- ✅ `2026-11-25-extent-reader-stamps.md` (closed 2026-11-25, 11fcc956; the substeps' stamps decide what `--stale` lists)
- ✅ Extent reader readiness review (closed 2026-11-25)

## Results (2026-11-25)

- **Measure:** 2,586 of 2,689 laws in `extent_rules` are on old reader code (the stamps moved).
  - Store-wide, 1,379 affecting laws are not read, with their text held: 1,369 affecting laws and 10 commencement sources only. The stamps session's 1,287 counted only the `by` of stored changes, but a build's affecting list is wider, and `Store.Inputs` and `ExtentStale` use the build's.
- **Tasks** (all in `scraper/step_procedures/` or `measures/`, outside every stamp; `ReadVersion.current()` stays `c898982531fa`):
  - `lat.amending --extents`:
    - `--preview [--diff FILE]` (`Extent.Write.plan/3`, `ExtentDiff`);
    - `--stale [--family F]` (`ExtentStale`);
    - `--amending @FILE` (`LawList`; also for `--read --amending`).
  - `lat.reread`: an `extents` substep after the commencement ones, before the build; reports in `data/reports/reread/`; long lists printed as their first three.
  - `lat.stale`: under `extent_reader`, the amending laws behind it (old code, not read), each with `--list`; with `--family F --reasons`, the family's.
  - `lat.extent_check`: the feed yardstick (`Measures.ExtentYardstick`), recorded and published by `lat.measures --family F`. In the gate, a cause's changes the feed gives an extent are `known: feed-speaks` unless reviewed (`Withheld.items/3`).
    - **Deviation:** I added an eighth class, `overlap` (neither a subset nor disjoint), so every change falls in some class.
  - `lat.extent_census`: `--family F`, and the noise-bin audit (`noise.tsv`; its counts are printed, not put in `stats.json`, so the run-07 parity holds).
- **Dry runs on the round:**
  - `lat.stale --family WWC --reasons`: extent_reader 401 builds. The builds reading a law in `ExtentStale.laws(WWC)`: also 401. ✅
    - The laws behind it: 571 on old code and 985 not read, 1,556 in all, which is the `extents` substep `lat.reread --family WWC` prints.
  - `--preview` on golden's 88 laws (written by this code): 88 read, 0 would change ✅.
  - `--preview` on 20 laws stored by old code: 1 would change (SI 2021/318, competence S → powers S; read 2026-10-26). **My plan was wrong to expect 0 here:** laws stored by old code include fixes made since their write. That change is real, and it is the step's first write's to apply.
- **Checks:** 6,061 targeted tests pass; the Credo diff is clean (one nesting issue I added was fixed); Dialyzer passes (23 skips, none new).
- **Docs:** the `extent-reader-check` skill (steps by phase), WORKFLOW §5 (extents, the gate, the census), EXTENT-READER §4–§6 (loop 6 fixed), RULES `extent-feed-first-where-it-speaks` (Code and Test filled for the check), and the gotchas file.
- **The round's check** (10 s warm; the first try timed out, because my two new correlated subqueries pushed the text-change query past the pool's 120 s, so both extents are now read from the claims join with `FILTER`, `timeout: :infinity`):
  - **the yardstick:** agree 8,437, the law wider 989, narrower 219, overlap 0, disjoint 2, the feed only 7,776, the law only 1,551, neither 7,519. **They sum to the 26,493 text changes** ✅. No bound from the law: 7,181 where the feed speaks, 7,405 where it is silent.
  - **the gate:** unreviewed causes 465 at the readiness run, 135 now, the rest `feed-speaks`. Our faults are 669 (687 then; golden's 88 have been written since). FAIL is expected before the step's first write.
- **The round's census** (`--family`, 5m43s): the noise-bin audit reads 18 of 228 noise sentences as statements (other 14/96, procedure 2/26, cases 1/9, outside_uk 1/27; commencement, instruction and modification 0). These are the Extent reader step's to review at Measure. The bench is skipped on a family dump: its laws aren't the round's.

## Docs changed

The `extent-reader-check` skill, WORKFLOW §5, EXTENT-READER §4–§6, RULES `extent-feed-first-where-it-speaks` (its Code and Test for the check), and the gotchas file. DATA-ARCHITECTURE: no table changed. GLOSSARY: `feed-speaks` is a status, defined in RULES.

## Step report

Given in the terminal (2026-11-25).
