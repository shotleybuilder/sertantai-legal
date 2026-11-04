---
session: 'Maritime Safety: Markup reader'
status: closed
opened: '2026-11-04'
closed: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
step: Markup reader
outcome: success
summary: >
  The markup reader passes for Maritime Safety: our faults 5 → 0 (an EU footnote's change now has its own change's
  key, so the check, the catalogue and the reader agree), catalogue regenerated over 3,726 laws with 0 held readings
  moved and 70 new patterns checked and accepted, seed 43 repeatable, golden 27/27, agent sample 50/50 placement and
  no WRONG. Same day, first plan.
decisions:
  - what: Fix the key, not the check — `Markup.key/1` maps "O…M…-fNNNNN" to "O…M…"
    why: the reader already folded an EU footnote's change into its own change (Directive 92/85 Art 13a(4) rule); the check and catalogue listed it under the raw id and found no reading
    result: 5 faults → 0; changes 1,477 → 1,472; domestic footnote ids untouched
  - what: Park the catalogue's example rotation instead of a fix and a third 16-min run
    why: all 122 rotated-out examples still read as held (no reading changed); it is fixture coverage, not a pass-rule item
    result: parked as catalogue-examples-rotate, to fix before the next family's catalogue run
metrics:
  placement: { changes: 1472, laws: 73, placed: 1469, placed_ancestor: 2, whole_law: 1, faults_before: 5, faults_after: 0 }
  notes: { placements: 1923, placed: 1917, outside_provisions: 4, placed_ancestor: 2, faults: 0 }
  keys: { in_feed: 1299, legacy: 138, not_in_feed: 35 }
  catalogue: { laws: 3726, changes: 176158, patterns: 807, new: 70, gone: 8, examples: 1148, unclassified: 0, held_moved: 0, rotated_out: 122 }
  agent: { seed: 43, placement_ok: 50, facts_ok: 48, doubtful: 2, wrong: 0, tokens: 138275 }
  checks: { repeatable: true, golden: "27/27", tests: 9884, failures: 0 }
  cost: { days: 1, plan_changes: 0, agent_tokens: 138275 }
lessons:
  - title: A check that lists changes by a different key than the reader reports reader faults that aren't
    detail: the reader merged an EU footnote's change into its own change; the check listed it by the raw ChangeId and counted an empty placement. One key function shared by reader, check and catalogue keeps them in step.
    tag: tooling
  - title: The catalogue's held examples rotate on regeneration
    detail: examples are picked first-come in law order; new laws displace held ones, and an example that now reads differently alone leaves its pattern empty. Check dropped examples against their held readings (all 122 matched) before trusting a regeneration.
    tag: tooling
  - title: The agent check cost more than estimated
    detail: 138,275 tokens against an 80–100k estimate (50 changes, many in long Acts such as MSA 1995). Budget about 140k for a markup sample.
    tag: tooling
bugs:
  - pattern: "The markup catalogue's regeneration gives a held example no priority when picking examples again, so held examples rotate out and patterns lose all coverage (2026-11-04: 122 held examples dropped, all still read as held; patterns with no held example 150 → 201; 24 lost every example, e.g. note refs only | part-N → split: h.N, pt.N, s.N)"
    category: catalogue-examples-rotate
    module: lib/mix/tasks/lat.markup_patterns.ex
    affected: 24 patterns
    fix: "Take a held example first for its patterns (when it is still generated and still reads alone as in its law), then fill with new ones"
    step: Markup reader
    status: open
  - pattern: "Markup check listed an EU footnote's change under its raw ChangeId (\"O003001M004-f00011\") while the reader folds it into its own change: counted as id not converted (Regulation 391/2009, 392/2009, 788/2014)"
    category: eu-footnote-key
    module: readers/markup.ex
    affected: 5 changes
    fix: "Markup.key/1 gives the footnote's change its own change's key"
    step: Markup reader
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_reader_test.exs
  - backend/test/fixtures/markup_patterns/ (regenerated, 70 accepted)
  - backend/data/reports/markup-reader/maritime-safety-0.txt … -2b.txt, -catalogue*.txt, -golden.txt, -agent-seed43.txt
depends_on:
  - 2026-11-04-maritime-safety-feed-reader.md
  - 2026-11-04-maritime-safety-meta.md
enables:
  - "Maritime Safety: Commencement reader"
---

# Session: Maritime Safety: Markup reader (CLOSED)

## Problem

Each change element in the family's revised text (Addition, Substitution or Repeal with a ChangeId) must become one change on the provision where it sits, carrying what the markup states. Baseline: 1,477 changes in 73 laws, our faults 5 (all EU footnote changes listed under their own id, "O003001M004-f00011", which the reader folds into the parent change).

- **Plan (approved 2026-11-04):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `one-record-per-change`; principle `coverage-from-lgu`.
- **Time box:** one day.
- **Meta session:** `2026-11-04-maritime-safety-meta.md`. Skill: `markup-reader-check`.

## Todo

- ✅ Session and baseline: our faults 5 (id not converted, 3 EU Regulations' footnotes); notes 0 faults; keys 1,299 in feed, 143 legacy, 35 not in feed (`backend/data/reports/markup-reader/maritime-safety-0.txt`)
- ✅ The footnote key (TDD): `Markup.key/1` gives an EU footnote's change its own change's key ("O003001M004-f00011" → "O003001M004"); domestic footnote ids untouched; check our faults 5 → 0, changes 1,477 → 1,472 (`-1.txt`)
- ✅ Pattern catalogue: 3,726 laws, 807 patterns; 0 unclassified; 0 held readings moved; 70 new patterns checked and accepted (`--accept`: 0 expectations changed, 122 rotated out, all still reading as held); `markup_patterns_test.exs` 1,155 pass
- ✅ Repeatability: seed 43 twice, samples identical under `cmp`, reports identical but for the sample file name (`-2a.txt`, `-2b.txt`)
- ✅ Golden 27/27 (one worker, a VM running; `-golden.txt`)
- ✅ Agent check, seed 43 (138,275 tokens): placement 50/50 OK, facts 48 OK, 2 doubtful, 0 wrong; both doubtful are held readings (a heading row inserted with its provision is heading + words; a number wrap with kept children is words), not NEW (`reports/markup-reader/maritime-safety-agent-seed43.txt`)
- ✅ Pass: all 6 rules met; `mix test` 9,884 pass, 0 failures; final check `-1.txt` (code unchanged since); no new rule for RULES.md (the footnote rule was already the reader's)
- ✅ Close; meta status row

## Pass rule (fixed)

1. Our faults 0 for changes and note placements (`mix lat.markup_check --family "TRANSPORT: Maritime Safety" --all`).
2. Catalogue regenerated, `unclassified` 0, new patterns accepted, fixed or pending; `markup_patterns_test.exs` passes; no held expectation changes without Jason.
3. Seed 43 run twice: samples identical under `cmp`, reports identical.
4. Golden 27/27.
5. Agent: nothing wrong outside the known patterns.
6. `mix test` 0 failures.

## Known patterns (for the agent)

- Schedules and EU annexes not parsed; legislation.gov.uk structure faults; territorial versions all targeted (narrowing is the label fold's); M1–M3 and P1 from the OH&S Markup reader session.
- Parked Markup reader bugs (from `2026-11-03-parked-bugs`):
  - markup inside unnumbered EU list items placed on the Article, not its point (Directive 98/24 art.2(b)(i));
  - ChangeIds at schedule-part wrapper ids carry no markup claim (SI 2008/1597 sch.2.pt.9).

## Dependencies

- ✅ Feed reader step closed (2026-11-04)

## Parking list

- Markup reader (check tool): catalogue-examples-rotate — held examples get no priority on regeneration; 24 patterns now hold no example (all 122 dropped still read as held). Fix before the next family's catalogue run.

## Pattern catalogue (2026-11-04)

- Run over 3,726 stored law texts (was 3,487 on 2026-10-28): 176,158 changes, 807 patterns, 1,148 examples; unclassified 0; **examples reading differently from expected: 0** (no held expectation moved).
- 70 new patterns, 8 no longer seen. The catalogue was last regenerated 2026-10-28, before the later steps' reader fixes (CV-S07–S09) and the new families' laws, so most new shapes come from those:
  - changes in id-less definition lists placed on the item rows (`regulation-N → reg.N(+1)`, `article-N → art.Article N(+1)`, NI `article-N → reg.N(+1)`);
  - new Acts' inserted runs (Communications Act 2003 s.368Z…, s.105Z…);
  - this step's own key shape: `key: ONMN + ONMN-fN` (an EU change and its footnote's, one change) replaces `key: ONMN-fN`.
- Every new pattern's held example was read and checked by hand (`scratchpad newpat-readings.txt`): targets and claims right. Two separate ChangeIds of one effect on one row give two records (the established rule), as in s.368Z14(11)(a).
- `part-N → pt....` / `pt....#N`: the parked LAT parser bug (SI 2003/3049 Part rows unnumbered); the reader names rows as held.
