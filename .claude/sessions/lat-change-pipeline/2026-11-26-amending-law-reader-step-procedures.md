---
session: 'Amending-law reader: step procedures'
status: closed
opened: 2026-11-26
closed: 2026-11-26
outcome: success
summary: >
  The Amending-law reader step now runs from tasks: lat.amending --read --stale [--family F], an amendments substep
  first in lat.reread, lat.stale naming the amending laws behind :amending_reader, the gate split by coverage (an
  unreviewed D group is known: legislation-gov-uk-speaks) and a yardstick record for lat.measures. One definition of a
  law's text amenders (Amendment.TextAmenders) fixed 122 round pairs no read would clear; the round's figures agree
  three ways (873 amending laws, 327 builds), and the gate's unnamed groups fall 431 → 256 before any write.
decisions:
  - what: "One definition of a law's text amenders (rules' sources and the feed's text effects, TextEffect), taken by Store.Inputs, AmendingStale and ReadPass.feed_pointers"
    why: "Store.Inputs counted the feed's by on every change but a commencement, modifications included, while the read pass reads only for text effects: a read never cleared those pairs (the plan's todo 2 fixes a mismatch at its root)"
    result: "122 round pairs (636 store-wide) no read would clear → 0; :amending_reader 834 → 734 builds store-wide; the build's version gains text_amenders.ex and text_effect.ex"
  - what: "The gate's groups split by stratum; an unreviewed D group is known: legislation-gov-uk-speaks; a reviewed status wins; disagreements.json keys unchanged"
    why: "RULES amending-legislation-gov-uk-first-where-it-speaks (Jason, readiness review Decision 2): a misread only where legislation.gov.uk speaks is a known limit"
    result: "Round: 431 groups not named (1,300 changes) → 256 (737); 175 D groups (563 changes) known by coverage"
  - what: "The yardstick uses plain equality and leaves commencements out, as the readiness SQL meant to"
    why: "So it can be checked against that SQL; CheckStrata's agreement keeps the reader's own equivalences"
    result: "Round 26,548 text changes: 10,752 / 849 / 1,711 / 13,236; 3 changes apart from the corrected SQL (first against max where a source holds two values)"
metrics:
  round: { built_laws: 565, amending_reader_builds: 327, stale_amenders: 873, not_read: 598, old_code: 275, not_for_law: 0, uncleared_pairs_before: 122, uncleared_pairs_after: 0 }
  store_wide: { amending_reader_builds_before: 834, amending_reader_builds_after: 734, uncleared_pairs_before: 636, stale_amenders_not_read: 602, stale_amenders_old_code: 1222 }
  gate_round: { groups_not_named_old: 431, changes_not_named_old: 1300, groups_not_named_new: 256, changes_not_named_new: 737, d_groups_known_by_coverage: 175, strata_A: 10702, strata_D: 1026, strata_L: 1584 }
  yardstick_round: { text_changes: 26548, agree: 10752, differ: 849, law_only: 1711, gov_only: 13236, level_agree: 11566, level_differ: 232 }
  yardstick_corrected_all: { text_changes: 76119, gov_speaks: 70660, gov_only: 40028, was_text_changes: 104935 }
  timings_s: { lat_stale: 84, reread_print: 7, amending_check_strata_gate: 38 }
  tests: { suite: 12777, new: 13 }
lessons:
  - title: "A stale reason must be one a re-read can clear: measure the pairs before trusting the count"
    detail: "The build's :amending_reader counted every feed effect but a commencement, so 122 round pairs (modifications, 'applied') could never clear, however often the step read. Checking each stale pair's law against the read pass's pointing laws found it in seconds. A stale reason and the reader's choice of laws must share one definition."
    tag: tooling
  - title: "jsonb #>> '{}' returns the whole JSON text, so a comparison against a bare word never matches"
    detail: "The readiness review's yardstick compared value #>> '{}' with 'commenced'. Claims are stored as {\"t\":…,\"v\":…}, so the filter never held and commencements counted as text changes: 104,935 for 76,119, legislation.gov.uk 95% for 93%. The equalities between two such texts were still right, which hid it. Use value->>'v', and check a new SQL yardstick against the task's figures."
    tag: data
  - title: "A nil binding in an Elixir for-comprehension filters the element"
    detail: "The scratch measure wrote `i = idx[a]` in a for's generators; a nil index dropped the pair silently, so never-read laws vanished from the count (668 builds against lat.stale's 834). A tested module with Map.has_key? gave the true count."
    tag: tooling
  - title: "A closed map typespec rejects a caller's bigger map in Dialyzer"
    detail: "TextEffect.text_effect?/1's spec %{type: …} is a map with only :type; passing a feed effect failed Dialyzer. Pass %{type: type} rather than widen a spec in a stamped file."
    tag: tooling
bugs:
  - pattern: "The build's :amending_reader counted the feed's amending laws on every change but a commencement (modifications, 'applied'), which the read pass never reads for, so no read cleared them (e.g. UK_asp_2003_3 by SSI 2019/175)"
    category: amending-reason-counts-modifications
    module: change_vocabulary/store/inputs.ex
    affected: "122 round pairs, 636 store-wide (100 builds)"
    fix: "Amendment.TextAmenders: one definition (TextEffect) for the build, the stale list and the read pass"
    step: Store and build
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/text_amenders.ex
  - backend/lib/sertantai_legal/scraper/step_procedures/amending_stale.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/amending_yardstick.ex
  - backend/lib/sertantai_legal/scraper/amendment/disagreement.ex
  - backend/lib/mix/tasks/lat.amending.ex
  - backend/lib/mix/tasks/lat.reread.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/lib/mix/tasks/lat.amending_check.ex
  - backend/data/reports/amending-reader/yardstick/waste-water-and-climate.json
  - backend/data/reports/amending-reader/readiness/feed-vs-law.sql
  - .claude/skills/amending-reader-check/SKILL.md
depends_on:
  - 2026-11-26-amending-law-reader-stamps.md
  - 2026-11-26-amending-law-reader-readiness-review.md
enables:
  - "Waste, Water and Climate: Amending-law reader (write first with lat.reread --family F --run: 873 amending laws, 598 never read; review the L groups only)"
---

# Session: Amending-law reader: step procedures (CLOSED)

## Problem

The Amending-law reader step still runs partly by hand: `--read` takes no family (it reads every stale law store-wide, or a list), `lat.reread` has no amending substep, `lat.stale` names no amending reason, and the gate does not split by legislation.gov.uk's coverage, which the new rule needs. Decided: Amending-law reader readiness review, Decision 1 (c) and Decision 2 (Jason 2026-11-26).

## Todo

The plan was approved 2026-11-26 (`~/.claude/plans/gleaming-doodling-matsumoto.md`).

**Pass rule:** each task change exists with tests; everything new outside every stamp (`ReaderVersion` and `CatalogueVersion` unchanged; stamp tests green); the round's dry runs agree (`--read --stale --family` = `lat.stale`'s laws = `lat.reread`'s substep; the yardstick sums and matches the readiness SQL for the round: 36,362 text changes, 10,755 / 846 / 1,711 / 23,050); suite, Credo diff and Dialyzer green; the skill, WORKFLOW §6, AMENDING-LAW-READER §4–§5, §7 and `amendment/CLAUDE.md` revised. No write, rebuild or fetch.

**Parked for this step:** 30 open reader bugs, all reader behaviour: out of scope, to "Waste, Water and Climate: Amending-law reader". `shared-reader-version-cascade` stays open.

- ✅ Measure: the round's `:amending_reader` laws (not read, old code, not for the law), and the pairs a read would not clear
- ✅ One definition: `Amendment.TextAmenders.for_laws/1` shared by `Store.Inputs` and `StepProcedures.AmendingStale` (TDD)
- ✅ `lat.amending --read --stale [--family F]`
- ✅ `lat.reread`: an `:amendments` substep, first in the chain
- ✅ `lat.stale` names the `:amending_reader` laws; fix line
- ✅ The gate by coverage (D `known: legislation-gov-uk-speaks` unless reviewed) and `Measures.AmendingYardstick` (TDD)
- ✅ Settle and close: the round's dry runs, suite, Credo diff, Dialyzer, docs, commits

## Dependencies

- ✅ Amending-law reader: stamps that follow what changed (closed, pushed 9989852a)

## Results

**Measure (read-only).** The round's builds: 565 built laws, 327 with `:amending_reader`, behind them 873 amending laws (598 never read, 275 on old code or other text). Store-wide 734 builds (834 before the fix below).
- **Found: 122 of the round's stale pairs no read would clear** (636 store-wide, 334 amenders). `Store.Inputs` counted the feed's `by` on every change but a commencement, so modifications and "applied" effects (115 of the 122) made a build stale; the read pass reads for the laws its text effects point from (`TextEffect`). Fixed at the root: `Amendment.TextAmenders` is the one definition (rules' sources, the feed's text effects), taken by `Store.Inputs`, `StepProcedures.AmendingStale` and `ReadPass.feed_pointers/0`. After: 0 pairs a read would not clear. The build's version gains `text_amenders.ex` and `text_effect.ex` (`StageSplitTest`); every build was already stale on its code version.

**The tasks.**
- `lat.amending --read --stale [--family F]` (`StepProcedures.AmendingStale`: not read, old code, not for the law).
- `lat.reread`: an `:amendments` substep first (`lat.amending --read --amending …`); the restore point names `amendment_rules` and the index tar.
- `lat.stale`: the laws behind `:amending_reader` by cause (`--reasons`, store-wide line, `--list`); the fix line names `lat.reread` and `--read --stale`.
- The gate by coverage: groups keyed by cause, amending law and stratum; a D group unreviewed is `known: legislation-gov-uk-speaks` (`Disagreement.status/4`, also in the dump).
- `Measures.AmendingYardstick`: written by `--strata`, printed by `lat.measures`.

**Dry runs on the round (pass rule 3).**
| Figure | Result |
|---|---|
| `lat.stale --family --reasons` | 598 not read, 275 old code, 0 not for the law; 327 builds |
| `--read --stale --family --limit 0` | the same 873 |
| `lat.reread --family` (printed) | `amendments (873 laws)`, then build and stale (no stale commencement or extent reading on the round) |
| Yardstick | 26,548 text changes: agree 10,752, differ 849, law only 1,711, legislation.gov.uk only 13,236; level 11,566 / 232; strata A 10,702, D 1,026, L 1,584 |
| Gate | 431 groups not named (1,300 changes) under the old grouping → 256 (737) by coverage; 175 D groups (563 changes) known as legislation.gov.uk speaks |

**The readiness yardstick corrected.** Its SQL read claims as their whole JSON text, so `<> 'commenced'` never held: commencements counted as text changes (104,935 all, 36,362 the round; legislation.gov.uk "95%"). Corrected (`->>'v'`): 76,119 and 26,548; legislation.gov.uk 93% and 94%; legislation.gov.uk only 40,028 and 13,236. The agree, differ and law-only counts were right, so the rule stands. The SQL, its report, AMENDING-LAW-READER §6 and RULES carry the correction; the closed readiness session is left as written. The yardstick task and the SQL differ by 3 changes (a source holding two values: first against max).

**Docs:** the skill (phases: plan from the last close, write first, L-only review, fetch list, preview, one write after the last reader commit, golden at every Settle), WORKFLOW §6, AMENDING-LAW-READER §3–§7, `amendment/CLAUDE.md`, RULES (the rule's code and test; the example corrected).

**Checks.** Suite 12,777 passed; Credo diff clean (one new complexity split); Dialyzer passed; `ReaderVersion` 19c57362bb5d, `CatalogueVersion` 853ddd3bbc49 and the Extent `ReadVersion` unchanged (no changed file in them). Code `d047efca` (hooks passed).

**Which docs changed:** RULES (the rule's code and test; its example corrected), WORKFLOW §6, AMENDING-LAW-READER §3–§7, `amendment/CLAUDE.md`, the skill. No new term for GLOSSARY. The parking list is empty; `shared-reader-version-cascade` stays open as narrowed.

