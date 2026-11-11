---
session: 'Environmental Protection: Measures'
status: closed
opened: '2026-11-11'
closed: '2026-11-11'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'
parent: lat-change-pipeline/2026-11-08-environmental-protection-meta.md

summary: >
  Every figure the ten Environmental Protection step sessions published was checked against today's store. Each was
  the same, moved by a named later commit, or a finding; four gates or verdicts that passed at their step fail today
  and are parked with their steps. Every check, gates included, ran twice at seed 1011 and replicates byte for byte;
  the parked inline reads of lat.sources and lat.vocabulary moved into tested modules; no agent pass.

decisions:
  - what: The pass rule, Maritime's fitted to no agent pass
    why: Jason, 2026-11-11 (the Label fold's agent pass cost 427,919 tokens)
    result: the hand sample replicates, Maritime's measure-fault classes stay tested, three items read by hand and classed right
  - what: A gate that fails today is parked with its step, never named here
    why: the gate files belong to their steps (the plan's scope)
    result: Sources (69), Extent (2 causes), Amending (4 groups), Making laws (1 verdict) parked
  - what: The --show reads reuse Build.rows/1 and LabelSwitch.stored/1; the new modules sit outside both version file lists
    why: no new queries where one exists; a measures-only change must not stale any build
    result: two inline queries gone; no build stale

metrics:
  audit: { steps: 10, same_steps: 5, moved_explained: 4, gates_failing_now: 3, verdicts_moved: 1, register_rows_added: 2 }
  replicability: { checks: 12, passes: 2, samples_identical: 10, printed_identical: 14, pass_minutes: 10, seed: 1011 }
  ep_today: { text_changes: 8134, law_and_derived: 3545, law_only: 472, derived_only: 4117, undated: 378, commenced_by_named: 4031 }
  hand_check: { items_read: 3, wrong: 0, agent_tokens: 0 }
  refactor: { lat_sources_lines: "331 → 185", new_tests: 7, show_identical_lines: 230 }
  regression: { golden: "27/27", mix_test: 10692, ohs_measures: unchanged, maritime_measures: unchanged }

lessons:
  - title: Feeds go stale by age alone, so a Sources gate passed once fails a month later with nothing changed
    detail: 47 of the 69 Sources failures are feeds with no validity date to compare, fetched more than 30 days ago (Sources.stale?/4). Any step re-running the Sources gate weeks after the fetch will see this; the fetch before Store and build should expect it.
    tag: data
  - title: Re-running every gate found three moved gates again, as on Maritime
    detail: Extent, Amending and Sources had passed at their close and fail after the Amending-law reader's parked-bugs write (7bcccc3a) and the Evidence rebuild. draws.sh remains the only thing re-running them until Store and build's check does (parked there since Maritime).
    tag: data
  - title: A scratchpad output folder from an earlier family's run mixed old files into a new pass
    detail: The first pass 1 started in measures/p1, which held Maritime's 2026-11-06 files and appended to its times.txt. Stopped and re-run in a fresh ep-p1. Name each pass's folder by family.
    tag: tooling
  - title: An inspected atom-keyed map prints in a different key order per VM run
    detail: --show before and after differed only in each change's `sources` map order; equal once keys were sorted. Compare debug output with keys normalised (the Maritime hand-sample lesson, in printed form).
    tag: tooling

bugs:
  - pattern: "UK_asp_2024_14 (Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024) read no verdict ('changes and powers') at the step; today it reads making (28 own requirements, first s.17(1)) against a stored is_making false, with no LAT rows: its stored text grew after the Sources re-scrape"
    category: making-verdict-moved-after-close
    module: mix lat.making_laws (apply), then the LAT parse
    affected: 1
    fix: "Read the law's verdict for Jason (making: apply and parse it; or review it not making)"
    step: Making laws
    status: open
  - pattern: "The Sources gate fails today for EP: 69 failures (47 feeds stale by age alone, fetched over 30 days ago; 4 backlog documents stale; 18 backlog Schedules needed since the read pass and the Evidence rebuild, not fetched, e.g. UK_nisr_2020_304 for UK_nisr_2011_239). It passed with 0 on 2026-11-08"
    category: sources-gate-not-rerun
    module: mix lat.sources --family F --fetch (ask Jason)
    affected: 69
    fix: "Fetch the failures (ask Jason first), re-run the gate"
    step: Sources
    status: open
  - pattern: "The extent gate fails today for EP: 2 no-bound causes not named, new since the step closed (21517e4a): none:same_or_not_named @ UK_ukpga_1990_43 (EPA 1990 s.77, s.127 application statements) and @ UK_ukpga_2018_12, one change each"
    category: extent-gate-not-rerun
    module: test/fixtures/extent_patterns/withheld.json
    affected: 2
    fix: "Review and name the two causes in withheld.json"
    step: Extent reader
    status: open
  - pattern: "The amending gate fails today for EP: 4 groups not named, new since the step closed: SSI 2005/658 'law text only: substituted words' x37 and 'no operation: substituted words' x1 (EPA 1990 s.78A, s.78J); SSI 2009/319 unjoined x1 (EPA 1990 s.84); EPA 1990 'law text only: repealed words' x1 (s.79(10))"
    category: amending-gate-not-rerun
    module: test/fixtures/amendment_patterns/disagreements.json (or the reading of SSI 2005/658 reg.2(2))
    affected: 40
    fix: "Review the four groups: name them, or fix the reading if SSI 2005/658's 37 are a misread"
    step: Amending-law reader
    status: open
  - pattern: "mix lat.sources and mix lat.vocabulary still hold their own reads inline (feed statuses and amending facts; the debug view), untested"
    category: logic-in-task
    module: lat.sources, lat.vocabulary
    affected: 2
    fix: "Sources.Held reads the store and register; Sources gains feed_status/3, commencing_orders/2, clause?/2, register_stats/1 (pure); ChangeVocabulary.Show holds the --show reads; Golden.older/3 the golden staleness; 7 tests"
    step: Measures
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/sources/held.ex
  - backend/lib/sertantai_legal/scraper/sources.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/show.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/golden.ex
  - backend/lib/mix/tasks/lat.sources.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/test/sertantai_legal/scraper/sources/held_db_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/show_test.exs
  - backend/data/reports/measures/ep-audit.md
  - .claude/skills/measures-check/SKILL.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-11-environmental-protection-label-fold.md

enables:
  - "Environmental Protection: Store and build (the four parked gates first: Sources fetch, Extent, Amending, Making laws)"
---

# Session: Environmental Protection: Measures (CLOSED)

## Problem

Step 10 of the LAT Change Pipeline for 💚 ENVIRONMENTAL PROTECTION. Every figure the family's ten step sessions published must be believable: one name and one meaning, printed by tested code, replicable. Later rebuilds have moved the store since those figures were published: Evidence rebuilt three families, and the Label fold changed the fold's version. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`, approved by Jason on 2026-11-11.

## Todo

- ✅ Open the session; draws pass 1 at seed 1011 (EP); OH&S and Maritime `lat.measures` baselines
- ✅ Audit: every in-scope EP figure against the register, its task, code, test and today's value (`backend/data/reports/measures/ep-audit.md`); failing gates parked with their steps
- ✅ Register gaps: an entry, a print line with a test, or "hand tally, report only"
- ✅ Parked bug (TDD): the reads inside `lat.sources` and `lat.vocabulary` moved into modules with tests; the original entry marked fixed
- ✅ Hand sample drawn twice and compared with `cmp`; Maritime's measure-fault tests; 3 items read by me (no agent pass)
- ✅ Verify: draws pass 2 against pass 1; OH&S and Maritime `lat.measures` unchanged; golden 27/27; `mix test`; compile, architecture tests, Credo diff
- ✅ Docs and close: the register, the skill's history, the WORKFLOW step 10 note, the meta row, commits

## Dependencies

- ✅ Environmental Protection: Label fold closed and pushed (39c2f7d9)
- ✅ Maritime Safety: Measures (`draws.sh`, `lat.measures --sample`, `Measures.Source.read_pointers/2`)

## Decision 1: the pass rule (DECIDED: plan approved, Jason 2026-11-11)

1. **Register complete.** Every data figure in the closing `metrics:` of the ten EP step sessions has a register entry, a task that prints it and a test, or is marked "hand tally, report only". Before/after history whose run is gone, days, commits, tokens and agent tallies are out of scope.
2. **Audit.** Each figure is the same as published, moved by a named later commit, or a finding. A gate that fails today is parked with its own step.
3. **Replicable.** Two draws passes at seed 1011 give byte-identical samples and identical printed figures once logs are filtered out.
4. **Hand check replaced: no agent pass** (Jason: the Label fold's pass cost 427,919 tokens). Instead:
   - the hand sample is drawn twice and compared byte for byte;
   - Maritime's three measure-fault classes are already tested;
   - I read 3 items as a spot check.
5. **No regression.** `mix test`; golden 27/27; OH&S and Maritime `lat.measures` unchanged unless a measure fix explains the change.

## Parking list

- Making laws: making-verdict-moved-after-close — UK_asp_2024_14 now reads making, stored false
- Sources: sources-gate-not-rerun — 69 failures (47 feeds stale by age, 18 Schedules not fetched; a fetch: ask Jason)
- Extent reader: extent-gate-not-rerun — 2 causes to name (EPA 1990, UK_ukpga_2018_12)
- Amending-law reader: amending-gate-not-rerun — 4 groups to name or fix (SSI 2005/658 ×38)

## Draws pass 1 (before any code change)

Seed 1011, `draws.sh` (scratchpad `measures/ep-p1/`), about 10 min. Times: commencement 154 s, Sources 94 s, Making laws 90 s, the rest 6–68 s. The label fold took 16 s from the fold cache. Baselines from `lat.measures`: OH&S 5,066 text changes, Maritime 3,144.

## Audit (report `backend/data/reports/measures/ep-audit.md`)

- **The same as published:** Feed reader, Markup reader, Merge, Evidence and the Label fold, gates included; Commencement reader's rows, faults and leftovers; every catalogue's patterns and examples against its fixture.
- **Moved, the later commit named:**
  - Making laws: live 395 → 393, making 116 → 114. Sources' register re-scrape revoked two making SIs.
  - Commencement reader: dated 27,880 → 27,872, left to orders 4,595 → 4,603 (7bcccc3a).
  - Extent reader: text changes 8,243 → 8,134 (the read pass and the Evidence rebuild).
  - Amending-law reader: stated 3,974 → 4,042; A/D/L 3,192/391/391 → 3,169/409/464 (7bcccc3a).
- **Four gates or verdicts that passed and fail today**, parked with their steps (above): Sources, Extent, Amending, and one Making laws verdict.
- **Names agree:** `lat.measures`' law only (472) is the amending check's law text only (497) less its 25 applied provisions.
- **Register gaps:** each catalogue's run figures (laws and items read) and the markup check's note placements line (to todo 3).

## Register gaps

- `markup_note_placements`: the markup check's second line, by the same outcomes. It is one row with the markup check's own figures.
- `<step>_catalogue`: each corpus catalogue's run figures, held in its fixture's `totals` by the run that wrote it. Every EP figure matches today's fixtures. The feed catalogue's law count (1,423) is printed by the run only: report only.
- Tallies from agent or hand review (Evidence's wrong values by owner) and the label fold's agent classes (now gate checks): report only.

## Parked bug: the reads inside two tasks

- **Red, then green:** 7 new tests, failing before any code moved.
- **`lat.sources`** (331 → 185 lines):
  - its store and register reads moved to `Sources.Held` (`law/1`, `amending/2`, `valid_dates/1`, `register/1`, `status/2`);
  - their pure parts are now in `Sources`: `feed_status/3`, `commencing_orders/2`, `clause?/2`, `register_stats/1`.
- **`lat.vocabulary`:**
  - the `--show` reads moved to `ChangeVocabulary.Show`. It now reuses `Build.rows/1` and `LabelSwitch.stored/1` instead of its own queries.
  - the golden staleness check is now `Golden.older/3`, with `Golden.stored_versions/1` doing the read.
- **No build goes stale:** none of these files is in the build's or the fold's version file lists.
- **`--show` before and after:** identical on the Forestry Act 1967 s.1 and s.1(4)(a) (230 lines), once the inspected `sources` map's keys are sorted (atom-table order varies per VM run).
- **Checks:** compile with warnings as errors is clean, the architecture tests pass, and the Credo diff adds no issues. The Sources output is compared in draws pass 2.

## Hand check, replaced (no agent pass)

- **Maritime's measure-fault classes still tested:** `measures/` passes, 62 tests.
  - `source_test`: a pointer counts as read only where its text is held; art. is read as reg.
  - `coverage_test`: `no_clause`.
- **Three seed-1011 items, read by me. All are classed right:**
  1. Environment Act 1995 s.108(15), inserted by Environment Act 2021 Sch.10 para.5(6)(c):
     - stated by the law and legislation.gov.uk;
     - merge stratum J;
     - dated 2022-01-09 by the 2021 Act's own commencement (commenced_by named).
  2. Environmental Protection Act 1990 Sch.1 Pt.2 para.8, inserted by Environment Act 1995 Sch.22 para.93(5):
     - the feed alone (derived only);
     - "read, no rule: Schedule", which is right because EA 1995's Schedules are held;
     - commenced by SI 1996/186 (the 1995 Act's fifth commencement order) on 1996-04-01.
  3. SI 2017/1200 reg.37(15), inserted by SI 2020/1620 reg.6(3):
     - law and derived;
     - dated 2020-12-31 by the feed, with no commenced_by: the SI commences itself.
- **The hand sample replicating:** checked in draws pass 2 (`hand.json`, `cmp`).

## Verify

- **Draws pass 2** (after the refactor) against pass 1:
  - all 10 samples are byte-identical (`cmp`), the hand sample included;
  - all 14 printed outputs are identical once log, compile and path lines are filtered out. That includes Sources, which proves the move of its reads.
- **OH&S and Maritime `lat.measures`:** unchanged (5,066 and 3,144 text changes).
- **Golden:** 27/27 (233 s).
- **`mix test`:** 10,692 passed, 2 skipped.
- **Compile and Credo:** compile with warnings as errors is clean, the architecture tests pass, and the Credo diff adds no issues.

## Pass rule

1. Register complete: met (two rows added; the rest report only, named).
2. Audit: met (`ep-audit.md`; four parked with their steps).
3. Replicable: met.
4. Hand check replaced: met.
5. No regression: met.
