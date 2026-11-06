---
session: "Maritime Safety: Labels side by side"
status: closed
opened: 2026-11-06
closed: 2026-11-06
outcome: success

summary: >
  Step 12 for TRANSPORT: Maritime Safety: the new labels built beside the old for 24,434 rows, with 46,976 periods and 0 breaking the table's rules. 18,898 rows agree, 2,350 differ today, 874 differ only in history and 2,312 have no stored timeline; that is the switch-over's baseline. Both of the step's parked bugs are fixed: the gaps are printed by shape, and the single changed_by now names the principal maker, then the latest made (Decision 1, A).

decisions:
  - what: "Decision 1, A: the single changed_by is the principal maker (never an earlier-amendment credit unless only credits made the text), then the latest made by year and number"
    why: "327 of the 375 multi-maker periods are exit-day chains where every maker's change takes effect on 2020-12-31, so 'the latest dated change' could not choose; the name sort favoured the amender of the amender (REACH Art 127E: SI 2020/1577 over the exit SI 2019/758), compared numbers as strings, and let the series prefix decide. Gemini (Flash) concurred with A."
    result: "LabelPeriods.one_law/2; RULES changed-by-one-law-for-compliance rewritten, open decision 1 closed; no fold change, changed_by_all and golden untouched"

metrics:
  side_by_side: { laws: 117, rows: 24434, periods: 46976, breaks: 0, agree: 18898, differ_today: 2350, history_only: 874, no_today: 2312 }
  gaps: { undated_start: 409, undated_change: 230 }
  timings: { strata_s: 720, golden_s: 595, mix_test_s: 87 }
  tests: { golden: "27/27", mix_test: "10188 passed", credo: clean }
  tokens: { agent: 0, gemini: 3726 }

lessons:
  - title: "Check that a proposed rule's key separates the cases before deciding it"
    detail: "RULES' own recommendation was 'the maker of the latest dated change', but a read-only query of the stored timeline showed that 327 of the 375 cases share one day (2020-12-31), so it would have chosen nothing. The re-framed options were put to Gemini and to Jason before any code."
    tag: data
  - title: "A labels-only change still marks every built law stale"
    detail: "label_periods.ex is inside ChangeVocabulary.Version's globs though no build reads it, so a change to how one column is chosen marks all 285 built laws stale; this is the parked label-fold-in-build-version bug (Store and build)."
    tag: tooling

bugs:
  - pattern: 'The new source emits no gap list (old: no_start, undated_change, commenced_by_order, pending_change …)'
    category: label gap
    module: ChangeVocabulary.LabelSource
    fix: "lat.label_check --strata prints the gaps by shape (Gate.Label.gaps/1) beside the side-by-side totals; the old list's only readers are the old path's tools"
    step: Labels side by side
    status: fixed
  - pattern: 'The single changed_by picks the alphabetically last law where several made the text (REACH Art 127E: SI 2019/858, the amender of the amender)'
    category: changed-by-alphabetical
    module: ChangeVocabulary.LabelPeriods
    affected: 375 periods in the stored timeline (327 on exit day)
    fix: "Decision 1 (A): the principal maker, then the latest made (LabelPeriods.one_law/2); RULES open decision 1 closed"
    step: Labels side by side
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_strata.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_periods.ex
  - backend/lib/mix/tasks/lat.label_check.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_strata_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_periods_test.exs
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - backend/data/code-reviews/2026-11-06-maritime-labels-side-by-side-decision-1-brief.md
  - backend/data/code-reviews/2026-11-06-maritime-labels-side-by-side-decision-1-gemini.md
  - backend/data/reports/labels-side-by-side/maritime-safety-strata.txt

depends_on:
  - 2026-11-06-maritime-safety-store-and-build

enables:
  - "Maritime Safety: Switch-over"
---

# Session: Maritime Safety: Labels side by side (CLOSED)

## Problem

WORKFLOW.md step 12 for TRANSPORT: Maritime Safety: the new labels are built in the timeline's shape beside the old ones, written nowhere, so every difference is counted as the switch-over's baseline (AIMS `binds-on-date`). Two bugs are parked with this step: the new source's missing gap list, and `changed_by` choosing the alphabetically last maker. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session, with these todos and Decision 1
- ✅ The difference totals in `--strata` (TDD): a pure tally of `LabelStrata.difference/2` classes, printed with the rows folded
- ✅ The gap list: `--strata` prints `Gate.Label.gaps/1` by shape; mark the bug fixed
- ✅ Decision 1: with A, the latest-dated maker (TDD) and RULES updated; with B, a known difference and the bug moved
- ✅ Run `--strata` for Maritime; save it to `backend/data/reports/labels-side-by-side/maritime-safety-strata.txt`
- ✅ Golden from inputs: 27/27
- ✅ Docs and close: WORKFLOW step 12, `mix test`, Credo, the session and the meta row; code and session commits, no push

## Dependencies

- ✅ Maritime Safety: Store and build (closed 2026-11-06, e00206aa): 285 laws built, 0 stale

## Pass rule (fixed at plan)

1. Golden 27/27 from inputs.
2. 0 timeline periods break the table's rules.
3. `--strata` prints, in code, the rows that agree, differ today (by field), differ only in history, and have no stored timeline. The four add up to the rows folded.
4. `--strata` prints the gaps by shape; the gap-list bug is fixed.
5. `changed_by` as Decision 1 rules.
6. `mix test` passes; Credo is clean.

## Decision 1: which law the single `changed_by` names where several made the text

- **The question:** where several laws made a provision's current text, which one goes in the one `changed_by` that compliance reads? Today the code takes the last by name, so REACH Art 127E gets SI 2019/858, the amender of the amender. Across the whole table, 375 of 656,605 periods have more than one maker.
- **The aim:** `binds-on-date`.
- **What the data shows** (found while briefing Gemini): "the latest dated change" can't tell the makers apart, because they take effect on the same day.
  - **Exit-day chains, 327 of the 375 periods,** start on 2020-12-31 (REACH 230, CLP 47). REACH Article 127E(10) holds SI 2019/758, the exit SI that made the text, and SI 2019/858 and SI 2020/1577, which amended 2019/758 before it took effect (earlier-amendment credits). Today the single value is 2020/1577.
  - **The rest are parallel changes on one day,** such as SSI 2006/457 with SI 2005/1541 on SI 1999/3242 reg.10(1)(c). Today the UK SI wins on its name.
  - The name sort is close to latest-made only by accident: it compares strings (2019_858 sorts after 2019_1144), and the series prefix decides between series.
- **Options** (re-framed from the plan's A and B):
  - **A.** The principal maker, then the latest made. Drop the earlier-amendment credits, then take the latest made of the rest (by year, then number as an integer). If only credits are left, take the latest made of those. REACH Article 127E(10) → SI 2019/758.
  - **B.** The latest made of all makers. REACH Article 127E(10) → SI 2020/1577, as today; only the string and series accidents are fixed.
  - **C.** Keep alphabetical: a known difference, and the bug moves to the Switch-over.
  - **D.** Leave the single value empty where several laws made the text; compliance reads `changed_by_all`.
  - Under A, B and D the fold's code changes, so they need Jason's leave for this bug. `changed_by_all` and golden are untouched, and a repealed period still names the repealer.
- **Recommendation:** A. It follows both rulings ("the law that made the text"; "never an earlier-amendment credit").
- **Gemini** (Flash, 3,726 tokens; `backend/data/code-reviews/2026-11-06-maritime-labels-side-by-side-decision-1-gemini.md`):
  - A, "the only sensible choice". The exit SI is the law a compliance user looks up, and latest-made is a neutral tie-break.
  - Choosing by the row's territory version would add weighting without a clear gain.
  - Neither risk asked about holds: a revoked principal starts a new period, and a period with only credits falls back.
- **Decided:** A (Jason, 2026-11-06), with leave to change the Label fold's code for this bug.

## Code (todos 2–4)

- `LabelStrata.totals/1`: every row's difference class, added up. `--strata` prints "side by side (rows): N = agree + differ today + differ only in history + no stored timeline", then the gaps by shape (`Gate.Label.gaps/1`, as the label gate counts them).
- `LabelPeriods.one_law/2` (Decision 1, A): drop the makers whose every reaching change is an earlier-amendment credit, then take the latest made (year, then number as an integer). If only credits are left, take the latest of those. No change to the fold: `changed_by_all` and golden are untouched.
- Tests: `label_strata_test` (totals) and `label_periods_test` (exit-day chain, number and series order, credits only), 27 pass. RULES `changed-by-one-law-for-compliance` rewritten; open decision 1 marked decided.

## Side by side (todo 5)

`mix lat.label_check --family "TRANSPORT: Maritime Safety" --strata` took 12 minutes; the report is `backend/data/reports/labels-side-by-side/maritime-safety-strata.txt`.

- **Folded:** 117 laws, 24,434 rows, none failed.
- **Timeline rows:** 46,976 periods, **0 breaking the table's rules**.
- **Side by side:** 24,434 = 18,898 agree (77%) + 2,350 differ today + 874 differ only in history + 2,312 with no stored timeline.
- **Differ today, by field:**
  - `in_force_from`+`changed_by` 969;
  - `in_force_from` 809;
  - `changed_by`+`territory` 166;
  - all four fields 118;
  - `changed_by` 68;
  - the rest under 70 each.

  `status` is in 258 of them. These are counted here and explained at the switch-over.
- **Gaps:** undated start 409 rows, undated change 230.

This is the switch-over's baseline. (OH&S, 2026-10-31: 16,487 of 20,371 rows differed.)

## Parking list

- Store and build: label-fold-in-build-version. `label_periods.ex` is in `ChangeVocabulary.Version`'s globs though no build reads it, so this step's change makes all 285 built laws stale on code version. This is the sibling of the bug already parked in Store and build; a rebuild clears it, and it is asked of Jason.
