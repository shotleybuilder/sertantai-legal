---
session: 'Environmental Protection: Markup reader'
status: closed
opened: '2026-11-09'
closed: '2026-11-09'
family: '💚 ENVIRONMENTAL PROTECTION'
step: Markup reader
outcome: success
summary: >
  The markup reader passes for Environmental Protection: 3,251 changes in 72 laws and 2,676 note placements, our faults 0
  (from 134), seed 61 repeatable, golden 27/27, agent placement 50/50 and facts 49/50 with its one new class fixed. A scoped
  law is read for its scope (Decision 1); a substitution's new words share the Repeal's key; the catalogue keeps held examples;
  a number inside quoted text is not the provision's own (Decision 3); catalogue 853 patterns, 55 new accepted.
decisions:
  - what: A scoped law's changes beyond its LAT fragments are outside_lat_scope, not row faults (Decision 1, a)
    why: "Jason: we were back-to-front; go from our LAT rows (our scope) to the law. The Act is in the LAT only for s.64, its commencement power"
    result: 131 → outside_lat_scope; note faults 0; rule read-a-law-for-our-scope
  - what: One key for a paired substitution, the reader's SubstitutionRef fold (Markup.substitutions/1), used by the check and the catalogue
    why: the check listed the new words under their own key when it differed from the Repeal's, finding no reading (Maritime's footnote-key lesson again)
    result: 3 faults → 0; reader output unchanged; OH&S and Maritime checks identical
  - what: Accept the regenerated catalogue (Decision 2, a)
    why: 0 held readings moved; the 16 held examples dropped all held the paired-key bug's empty reading
    result: 55 patterns and 48 examples added, 9 and 16 removed, 0 changed
  - what: Fix the quoted number in-step (Decision 3, a), and move the two held readings in full (Decision 4, 4b)
    why: the agent's one new class; a code check found 312 changes across the store, above the triage size, in this step's own code
    result: rule quoted-number-is-not-own; 2 held readings moved (level, and for a legacy Addition its operation, by legacy-markup-fills-never-contradicts); golden 27/27
  - what: Park the catalogue's slow cold run against Tooling (#198)
    why: per-law and 400-law timings match #195's code within 10%; the gap shows only in the full run with the cache
    result: issue 198 with measurements and the next test
metrics:
  check: { changes: 3251, laws: 72, placed: 2701, placed_versions: 547, whole_law: 2, outside_lat_scope: 1, faults_before: 4, faults_after: 0 }
  notes: { placements: 2676, placed: 2481, placed_versions: 65, outside_lat_scope: 130, faults_before: 130, faults_after: 0 }
  keys: { in_feed: 2375, legacy: 825, not_in_feed: 51 }
  catalogue: { laws: 4185, changes: 192981, patterns: 853, new: 55, gone: 9, examples: 1180, unclassified: 0, held_dropped_rotation: 8, held_moved_decided: 2, cold_minutes: [24, 27] }
  agent: { seed: 61, placement_ok: 50, facts_ok: 49, wrong: 1, new_classes: 1, tokens: 152593 }
  checks: { repeatable: true, golden: "27/27", tests: 10458, failures: 0, ohs_maritime_unchanged: true }
  cost: { days: 1, plan_changes: 0, agent_tokens: 152593, cold_catalogue_runs: 2 }
lessons:
  - title: Read a law from our rows, not our rows from the law
    detail: fetching a scoped law's body (Feed reader, Decision 1) made the markup check read all its sections and call 131 out-of-scope commencements our faults. The fix is the direction of reading (Jason), not a list of exceptions.
    tag: data
  - title: Every reader fix after the catalogue costs another cold run
    detail: the catalogue cache is keyed on the catalogue's code, which includes the reader. This step's three fixes gave two cold runs of about 25 min each. Batch the step's own fixes before the first run, and expect an agent-found fix to cost a second.
    tag: tooling
  - title: A held expectation's move can carry more than the decision named
    detail: Decision 4 named level only; writing it showed PACE s.114(2)(b)(i) losing its operation too, by an existing rule. Diff the reader's full outcome against the held one before writing, and put the whole move to Jason.
    tag: tooling
  - title: The Credo ratchet counts a lowered score as a new issue
    detail: occurrences/4 went from complexity 21 to 20 and still failed the hook; a function the step touches must go under the limit (split into named parts), as CLAUDE.md says.
    tag: tooling
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_placement.ex (outside_lat_scope)
  - backend/lib/mix/tasks/lat.markup_check.ex (scope ids; PASS counts note faults)
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex (substitutions/1; quoted numbers; the walker split)
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_patterns.ex, markup_patterns/law_scan.ex, law_read.ex, lib/mix/tasks/lat.markup_patterns.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_paired_key_test.exs, catalogue/markup_held_examples_test.exs, markup_placement_test.exs, markup_level_test.exs
  - backend/test/fixtures/markup_patterns/ (regenerated)
  - backend/data/reports/markup-reader/environmental-protection-*.txt, -catalogue*.log, -agent-seed61.txt, -sample-seed61.json
  - docs/lat-change-pipeline/RULES.md, WORKFLOW.md; .claude/skills/markup-reader-check/SKILL.md
depends_on:
  - 2026-11-08-environmental-protection-feed-reader.md
  - 2026-11-08-environmental-protection-meta.md
enables:
  - "Environmental Protection: Commencement reader"
bugs:
  - pattern: "The markup check and catalogue list a substitution's new words (the Addition a Repeal's SubstitutionRef names) under the Addition's own key, while the reader folds them into the Repeal's change: where the keys differ (legacy ids, or a key-… Repeal naming a legacy Addition) the Addition has no reading (EPA 1990 h.62 d29p10005, s.6(6A) d29p866; Environment Act 1995 s.42(3)(b))"
    category: paired-substitution-key
    module: readers/markup.ex, markup_patterns.ex
    affected: "3 changes (family); 59 SubstitutionRefs in 14 stored laws"
    fix: "one key function: the reader's SubstitutionRef fold, used by the check and catalogue"
    step: Markup reader
    status: fixed
  - pattern: "A scoped law's changes beyond its LAT fragments counted as row faults once its body was stored (Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024: 131 commencements of ss.1–63; LAT holds s.64)"
    category: scoped-law-read-whole
    module: markup_placement.ex, lat.markup_check
    affected: "131 (1 change, 130 notes)"
    fix: "outside_lat_scope outcome, not a fault (Decision 1)"
    step: Markup reader
    status: fixed
  - pattern: "A number inside quoted text (a BlockAmendment) read as the provision's own number, so an insertion of quoted paragraphs read provision level, not words (SI 2006/2988 reg.5(6), Addition of (aa), (ab))"
    category: quoted-number-as-own-number
    module: readers/markup.ex (occurrences/4), readers/markup/level.ex
    affected: "312 ChangeIds (8 in 3 family laws; 304 in 60 other laws)"
    fix: "a number inside a BlockAmendment is quoted until a row id of its own (Decision 3)"
    step: Markup reader
    status: fixed
  - pattern: "The markup catalogue's regeneration gives a held example no priority when picking examples again, so held examples rotate out and patterns lose all coverage (2026-11-04: 122 held examples dropped, all still read as held; patterns with no held example 150 → 201; 24 lost every example, e.g. note refs only | part-N → split: h.N, pt.N, s.N)"
    category: catalogue-examples-rotate
    module: lib/mix/tasks/lat.markup_patterns.ex, markup_patterns/law_scan.ex
    affected: 24 patterns
    fix: "held examples reserve their slots until their law is passed (LawScan.new_acc/1, held_for/2)"
    step: Markup reader
    status: fixed
  - pattern: "The markup catalogue's full cold run took about 24–27 min (4,185 laws, 4 workers) where its per-law rate gives about 9 (400 laws: 50 s at #195's code, 55 s now); #195 measured 329 s"
    category: catalogue-full-cold-run-slow
    module: CatalogueCache.fetch/6 or the task's serial merge over LawRunner.ordered/3
    affected: every cold catalogue run
    fix: "time a full cold run --no-cache against one with the cache on, to split the cache from the merge"
    step: Tooling
    status: open
    issue: 198
---

# Session: Environmental Protection: Markup reader (CLOSED)

## Problem

This is step 3 for Family 3. Each change element in the family's revised text (an Addition, Substitution or Repeal with a ChangeId) must become one change on the provision where it sits, carrying what the markup states.

The baseline has 134 faults:
- 131 in one scoped law read whole;
- 3 where a paired substitution is listed under two keys.

- **Plan (approved 2026-11-09):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `one-record-per-change`; principle `coverage-from-lgu`.
- **Time box:** one day.
- **Meta session:** `2026-11-08-environmental-protection-meta.md`. **Skill:** `markup-reader-check`.

## Todo

- ✅ Open the step session; baseline (`backend/data/reports/markup-reader/environmental-protection-0.txt`); Decision 1 written
- ✅ Decision 1 (a): `outside_lat_scope` (test first): 131 → outside scope; note faults 0 (`-1.txt`); the check's PASS now counts note faults too
- ✅ The paired-substitution key (test first): `Markup.substitutions/1`, used by the reader, the check and the catalogue. Family PASS, our faults 0; changes 3,254 → 3,251, legacy 828 → 825 (`-2.txt`). OH&S and Maritime identical to their last runs (`ohs-after-ep.txt`, `maritime-safety-after-ep.txt`); change vocabulary tests 3,405 pass; a6548921
- ✅ The catalogue keeps held examples first (test first, `markup_held_examples_test.exs`; the replay is still the serial run); a9dc9fba
- ✅ Catalogue regenerated: dry run, 0 held readings moved, 55 new patterns read by hand, Decision 2 (a) `--accept`; catalogue test 1,187 pass; a1d78c4b
- ✅ Repeatability: seed 61 twice, samples identical under `cmp`, reports identical but for the sample file name (`-3a.txt`, `-3b.txt`); golden 27/27 (`-golden.txt`)
- ✅ Agent check, seed 61 (152,593 tokens): placement 50/50, facts 49/50; the new class (a quoted number read as the provision's own) fixed by Decision 3 after a code check over the store (312 changes); 5bad677b
- ✅ Pass and close: all 7 rules met (the final checks `-4.txt`, `*-after-ep-2.txt`; golden 27/27 after the fix; `mix test` 10,458 pass, 0 failures); RULES `read-a-law-for-our-scope`, `quoted-number-is-not-own`; WORKFLOW; the skill's history; meta row; the slowdown raised as #198

## Pass rule (fixed)

1. `mix lat.markup_check --family "ENVIRONMENTAL PROTECTION" --all`: sources held; our faults 0 for changes and for note placements.
2. The catalogue is regenerated with `unclassified` 0, and each new pattern is accepted, fixed or pending. `markup_patterns_test.exs` passes. No held expectation moves without Jason: a dry run first, then `--accept`.
3. Seed 61 twice: the samples are identical under `cmp`, and the reports are identical.
4. Golden 27/27.
5. One agent pass on 50 changes finds nothing wrong outside the known patterns, with no re-sample.
6. `mix test` 0 failures; the Credo ratchet clean; hooks pass.
7. OH&S and Maritime Safety markup checks are unchanged, or change only by the fixed class.

Frozen: `golden.exs` and the held expectations in `test/fixtures/markup_patterns/expected.json`.

## Dependencies

- ✅ Environmental Protection: Feed reader closed (2026-11-09)

## Parking list

- Feed reader (check tool): the feed catalogue picks examples with the same rule (`feed_patterns/law_scan.ex` `take?/3`), so its held examples may rotate too; check its next regeneration's dropped examples.
- Markup reader (check tool): catalogue-pattern-z-numbers. The pattern namer keeps inserted Z-numbers ("s.554Z10") where it abstracts other numbers to N, so one law's Part 7A makes about 32 patterns (ITEPA 2003). Renaming would move accepted pattern names: do it at a catalogue run with Jason's go.
- Store and build: the stored changes are one reading behind for laws holding a quoted-number change (8 in 3 family laws; 304 in 60 other laws) until the build or a refresh.
- Tooling: catalogue-full-cold-run-slow (#198).

## Baseline (2026-11-09)

| | Count | Placed | In versions | Whole law | Our faults |
|---|---|---|---|---|---|
| Changes (72 laws) | 3,254 | 2,701 | 547 | 2 | 4 (1 row missing, 3 group row missing) |
| Note placements (81 laws) | 2,676 | 2,481 | 65 | | 130 (row missing) |

The markup's keys against the feed: 2,375 in the feed, 828 legacy, 51 not in the feed.

- **A scoped law read whole (131):**
  - The Aggregates Tax (Scotland) Act 2024's LAT scope is s.64 only, 7 rows.
  - Its body has been stored since the Feed reader's Decision 1, so the check reads every section, and each change outside s.64 finds no row.
- **A paired substitution under two keys (3):**
  - The reader folds the new words into the Repeal's change.
  - The check lists the Addition under its own key, which has no reading.
  - The cases are EPA 1990 h.62 and s.6(6A), and the Environment Act 1995 s.42(3)(b).
  - The reader's readings of the Repeals are right (h.62 substituted; s.42(3)(b) substituted).
- **Parked bugs measured in the family:**
  - The effect id held only in CommentaryRef (#188): 1 effect in EPA 1990, below the triage size, so it stays parked.
  - A child CommentaryRef: 0.

### Decision 1. How should the check count a scoped law's changes outside its LAT scope? — DECIDED (a), `outside_lat_scope`, 2026-11-09

- **The picture** (asked for by Jason):
  - The Act is the Aggregates Tax and Devolved Taxes Administration (Scotland) Act 2024, in the family but not a making law.
  - Its LAT holds only s.64, its commencement power (scope purpose `enabling_extent`, 2026-09-29). Two family commencement SSIs are made under it: SSI 2025/79 and 2025/243.
  - The 131 are "coming into force" effects on ss.1–63, which we don't hold: 130 notes and 1 change element.
  - They showed only once the body was fetched (Feed reader, Decision 1).
- **Question.** The Aggregates Tax (Scotland) Act 2024 has 131 changes and notes outside s.64, its only scope. What should the check call them?
- **Aim:** `coverage-from-lgu`. Every change on a provision we hold is read, and a change we don't hold is accounted for with a reason.
- **Options:**
  - **(a) A new outcome, `outside_scope`, not a fault**, as `schedule_not_parsed` is. The check reads the law's scope fragments (`section/64` → `s.64`), and a target neither held nor under a scope ref is outside scope. Pure and unit-tested, for changes and notes alike.
  - **(b) Explain them as a known limit** in an explained list, as Sources' `explained.json` does. That needs a new fixture and a reader for it in the check.
  - **(c) Widen the law's scope to the whole Act.** That is LAT parser and Making laws work, a re-parse, out of this step, and the Act is in the family only for its s.64.
- **Recommendation:** (a). It names what is true, holds for every scoped law (82 in the register), and needs no list kept by hand.
- **Decided (Jason, 2026-11-09):** (a), named `outside_lat_scope`.
  - *"Arises because we are 'back-to-front': we take a law and want to apply it to our LAT rows, when we should go from our LAT rows (our scope) to the law. This law should be processed for what we need it for, recognising it's not in LAT."*
  - The principle goes into RULES.md.
  - The Sources bug already parked (`scoped-law-body-not-needed`) is the same direction, at the fetch.

## Pattern catalogue (2026-11-09, dry run)

The run read 4,185 stored law texts cold, under the 14G memory cap (`environmental-protection-catalogue.log`).

| Measure | Result |
|---|---|
| Changes | 192,981 |
| Unclassified | 0 |
| Patterns | 853 |
| Examples | 1,180 (368 too large to hold) |
| **Examples reading differently from expected** | **0**: no held reading moved |
| Held examples dropped from surviving patterns | 8, against 122 at Maritime: the rotation fix holds |

Patterns with no held example stay at 199. The fix stops the loss; it doesn't restore what was lost.

- **16 held examples, and 9 patterns, are no longer generated.** All 16 are the bug fixed here.
  - Each was a substitution's new words, listed under its own key and held as "no reading" (`[]`).
  - Each is now listed with its Repeal, so the 9 "→ nowhere" shapes they made are gone. One example is EPA 1990 s.6(6A), `d29p866`.
- **55 new patterns, 91 changes.** Each example was read by hand (`environmental-protection-catalogue-new-patterns.txt`):
  - **The paired key (4):** `key: dNpN + key-HEX-N`, `key: V_SNI_U-H + key-HEX-N`, and two extent shapes. A Repeal and its new words now form one change.
    - Where the two sit in different elements, the reader gives two claim sets on one row: substituted, retained, plus inserted.
    - This is the reader's reading as before; only the listing moved. Merge decides it (`operation-order`: the feed's operation first).
  - **The Income Tax (Earnings and Pensions) Act 2003 (ITEPA): about 32 patterns.**
    - It is in the store (no family, no rows), with an inserted Part 7A, s.554Z1–Z21.
    - The pattern namer keeps "554Z10" where it abstracts other numbers to N, so each section is its own pattern. This is parked.
    - The readings are right, for example s.554Z10(3) substituted words, and s.554Z9(1A) inserted.
    - `s.554Z8(d)` comes from legislation.gov.uk's own id `section-554Z8-d`: a structure fault, already a known pattern.
  - **Rows named with an `n1` suffix (6):** for example s.107(1)(bn1n2n1), s.74n1, s.32(3n1). These are the parser's names for repeated ids, and the reader names them as held.
  - **New items:** s.276(c)(iiia) and s.183(3)(b)(viia) inserted; Welsh SI 2019/245 note placements split across reg.2's and reg.3's paragraphs.
  - **13 patterns hold no example** (too large to hold): accepted on count, as before.

### Decision 2. Accept the regenerated catalogue? — DECIDED (a), 2026-11-09

- **Question.** `--accept` would add the 55 new patterns as the reader reads them, and drop the 16 held examples and 9 patterns no longer generated. Should it run?
- **Aim:** `one-record-per-change`. A substitution's old and new words are one change.
- **Options:**
  - **(a) Accept.** The task writes the files, with sorted keys. Then run `markup_patterns_test.exs`.
  - **(b) Hold back the 16:** keep them as `pending`. But they hold the bug's reading, a change with no reading, which no longer exists.
- **Recommendation:** (a). No held reading moves; the 16 removed held only the bug.
- **Decided (Jason, 2026-11-09):** (a). `--accept`: 4,171 cache hits, 14 read. Expectations: 0 changed; 9 patterns and 16 examples removed; 55 patterns and 48 examples added. `markup_patterns_test.exs` 1,187 pass; a1d78c4b.

## Agent check (seed 61, 2026-11-09)

The agent used 152,593 tokens; the verdicts are in `backend/data/reports/markup-reader/environmental-protection-agent-seed61.txt`.

- **Placement:** 50 of 50 OK.
- **Facts:** 49 OK, 1 wrong, a new class.
- **Not faults:** 2 legacy Additions inside text carry no operation, by design. Twice, one effect has two ChangeIds on one row, giving two records: the established rule, and Merge's to collapse.
- **The new class, `quoted-number-as-own-number`:**
  - The case is SI 2006/2988 (Welsh) reg.5(6): "For subsection (7), substitute—", then the quoted subsection.
  - A later Addition (…56993e) inserts paragraphs (aa) and (ab) inside the quoted block. It wraps their numbers, which have no ids.
  - The reader takes those numbers for reg.5(6)'s own and reads "provision" level. The note says "Words in reg. 5(6) inserted", so it should be "words".
  - **Cause:** the occurrence walker (`Readers.Markup`, `occurrences/4`: any `Pnumber` sets `:number`) does not tell a number inside a BlockAmendment from the provision's own. `Level.sure_whole?/3` then counts it.
- **The code check over the store:** ChangeIds whose only number wraps are inside quoted text. 8 in 3 family laws (for example the Environment Act 1995), and 304 in 60 other laws: 312 in all, above the triage size.

### Decision 3. Fix the quoted number in-step? — DECIDED (a), 2026-11-09

- **Question.** Should a number inside quoted text (a BlockAmendment) stop counting as the provision's own number, fixed now?
- **Aim:** `one-record-per-change`. A change carries what the markup states, and level is a stated fact (`level-order`).
- **Options:**
  - **(a) Fix now, test first.**
    - The walker flags a number inside a BlockAmendment as quoted, and `sure_whole?` counts only the provision's own.
    - Then a catalogue dry run (cold again, about 40 min, since the reader's code version moves), then golden, and the OH&S and Maritime checks.
    - Any held reading that moves comes back to Jason before `--accept`.
    - The stored changes go one reading behind until the build (Store and build parking list).
  - **(b) Park it** against the Markup reader, to fix at the next family's step. 8 changes in this family stay at "provision", not "words".
- **Recommendation:** (a). It is the reader's own rule in a single flag, it reaches 312 changes across the store, and this step owns it. One more catalogue run is the cost.
- **Decided (Jason, 2026-11-09):** (a).
  - **The fix:** in the walker, a number inside a BlockAmendment is quoted until a row id of its own (`Markup.quoted/3`). The test is `markup_level_test` "a number inside quoted text …".
  - **Checks:** the three markup checks are unchanged and pass (`-4.txt`, `*-after-ep-2.txt`).
  - **Two held catalogue readings move** from provision to words, both this class, checked by hand:
    - SI 2019/775 reg.153(6): "After paragraph (6) insert—", the quoted 6A and 6B wrapped;
    - PACE 1984 s.114(2)(b)(i): a legacy insertion inside the quoted s.14A–14B.
  - **Next:** the second catalogue dry run (`-catalogue-2.log`).

### Decision 4. Move the two held readings to "words"?

- **The dry run** (`-catalogue-2.log`, cold, about 27 min) had 0 new patterns, 0 gone and 0 unclassified. Exactly 2 examples read differently from expected, the 2 above.
- **Question.** Change those two held expectations from `markup.level: provision` to `words`, as the fixed reader reads them?
- **Aim:** `one-record-per-change`. Level is what the markup states, and neither change touches its provision's own number or all of its text.
- **Options:**
  - **(a) Move both.** A script changes only `markup.level` in the two entries and writes sorted keys. The diff is checked to be those 2 lines, then the catalogue test runs.
  - **(b) Keep them**, mark the patterns `pending` and undo the fix. Then 312 changes stay at "provision".
- **Recommendation:** (a). Both are the fixed class, checked by hand against the markup.
- **Decided (Jason, 2026-11-09): (a), level only.**
  - Writing it showed one more fact moving. For PACE 1984 s.114(2)(b)(i), the legacy Addition (`d29p15317`) also loses `markup.operation: inserted`.
  - This follows `legacy-markup-fills-never-contradicts`: a legacy Addition claims "inserted" only when it wraps the provision's number, and it no longer does.
  - reg.153(6) moves level only.
  - The file was put back to HEAD, unwritten, pending Jason (Decision 4b).
- **Decided 4b (Jason, 2026-11-09): move in full.**
  - Both examples are written as the fixed reader reads them, with sorted keys, and the diff is those two examples only. Tests 3,443 pass.
  - The Credo ratchet flagged `occurrences/4` (complexity 21 → 20 still counts as a change). The walker was split into named parts (`element_flags/4`, `refs/3`, `change/5`, `in_children/5`) and is now under 9, with every test unchanged.
  - Committed as 5bad677b.

## The catalogue's cold run time (Jason asked, 2026-11-09)

- **The ask.** #195 measured markup cold at 329 s (3,727 laws, 4 workers). Today's two cold runs took about 24 and 27 min (4,185 laws, 4 workers, the same cgroup cap).
- **Per-law code** (a worktree at 7d81e1e2, read-only): EPA 1990 12.4 s then and 12.9 s now; ITEPA 2003 20.9 then and 24.9 now. A random 60 laws average 191 then and 199 ms now.
- **The task on the same 400 random laws**, cold (`--no-cache`), 4 workers: 50 s at #195's code and 55 s at today's.
- **The 12 largest laws** take 12–39 s each, so no long tail.
- **Reading.** The code is within about 10% of #195's, and a 400-law rate gives about 9 min for the whole store. The gap appears only in the full run with the cache on: the cache write path, or the serial merge throttling the workers as the catalogue grows (`LawRunner.ordered` is pull-based). Neither is this step's code.
- **My share.** This step ran the catalogue cold twice, because each reader fix moves the catalogue's code version. Batching code fixes before one catalogue run would halve it, but the agent check comes after the catalogue by design, so a fix it finds always costs a second cold run.
