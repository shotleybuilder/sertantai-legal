---
session: 'Tooling: round scope'
status: closed
opened: 2026-11-13
closed: 2026-11-13
step: Tooling
outcome: success

summary: >
  A round of families now runs each step once: --family takes a round's name (ChangeVocabulary.Rounds,
  "Fire and OH&S" = five families by exact name), and Amendment.PatternSource is the one family scope
  (family_laws/1, family_filter/2), with an architecture test holding it. The round gives 100 laws with
  rows and 219 live UK laws; Environmental Protection's scope is unchanged (122).

decisions:
  - what: The round passes through the existing --family flag, scoped in PatternSource alone
    why: every pipeline task already scopes through PatternSource.family_laws/1 except three inline queries; a new flag would have touched about 24 tasks
    result: one pure module, one helper, three queries moved; no task's options changed
  - what: A round matches its families exactly (display marker dropped); a plain family stays a substring
    why: the substring OH&S takes in the switched Occupational family; earlier families' runs must not move
    result: rule a-round-is-its-exact-families (RULES section 0); EP 122 laws before and after

metrics:
  scope: { round_laws_with_rows: 100, round_live_uk: 219, round_not_uk: 80, ep_laws_with_rows: 122 }
  checks: { new_tests: 5, architecture_tests: 22, credo_new_issues: 0 }
  cost: { days: 0.5, plan_changes: 0, agent_tokens: 0 }

lessons:
  - title: Count with the function the steps will use, not an ad hoc query
    detail: the plan's 99 laws with rows came from legal_register filtered by live; family_laws reads uk_lrt and does not filter by live, so the round's scope is 100. The pass-rule count was corrected before the check ran.
    tag: tooling

bugs: []

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/rounds.ex
  - backend/lib/sertantai_legal/scraper/amendment/pattern_source.ex
  - backend/lib/mix/tasks/lat.making_laws.ex
  - backend/lib/mix/tasks/lat.feed_check.ex
  - backend/lib/mix/tasks/lat.extent_sweep.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/rounds_test.exs
  - backend/test/sertantai_legal/architecture/family_scope_test.exs
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md

depends_on:
  - 2026-11-13-claude-model-plan.md

enables:
  - "Fire and OH&S: Making laws, and every later step of the round, run once with --family \"Fire and OH&S\""
---

# Session: Tooling: round scope (CLOSED)

## Problem

The Fire and OH&S round takes five families together, but every pipeline task takes one `--family`, matched as a substring of the register's family name. `"FIRE"` happens to cover both Fire families, while `"OH&S"` would also take in the switched OH&S: Occupational / Personal Safety. Jason chose to add a round scope first, so each step runs once over exactly the five families (plan approved 2026-11-13).

## Todo

- ✅ Open this session and the round's meta session; the round decision into WORKFLOW and RULES
- ✅ `ChangeVocabulary.Rounds` (pure), with tests
- ✅ `PatternSource.family_laws/1` and `family_filter/2` go through it; the three inline `family LIKE` queries move onto the helper
- ✅ Architecture test "one family scope"
- ✅ Read-only counts; close; commit by path

## Pass rule (fixed)

1. `Rounds` is tested: its names, `families/1`, an unknown name giving nil, and exactly five families with no Occupational.
2. The architecture test fails on any `family LIKE` or `family ILIKE` in `lib/mix/tasks/lat.*` or `change_vocabulary/` outside `PatternSource`.
3. `MIX_ENV=dev mix compile --warnings-as-errors`, the architecture tests and the Credo ratchet are all clean.
4. Read-only counts:
   - `family_laws("Fire and OH&S")` gives 100 laws with rows. The plan said 99: that figure was the live laws with rows, while `family_laws` doesn't filter by live.
   - `family_laws("ENVIRONMENTAL PROTECTION")` gives 122, as before the change.
   - `lat.making_laws --family "Fire and OH&S"` reads 219 live UK laws.

## Dependencies

- ✅ The plan, approved 2026-11-13

## Results

- **Counts** (read-only):
  - `family_laws("Fire and OH&S")` gives 100 laws (FIRE 24, Dangerous and Explosive Substances 36, Gas & Electrical 12, Mines & Quarries 12, Offshore 16);
  - `"ENVIRONMENTAL PROTECTION"` gives 122, as before;
  - `"FIRE"` gives 60.
- **`lat.making_laws --family "Fire and OH&S"`:** 219 live laws, 80 not UK law. The CSV went to the scratchpad.
- **Checks:** compile with warnings as errors, 27 tests (architecture and rounds) and `credo diff` all pass with no new issue.
- **Docs changed:**
  - WORKFLOW ("The first QQ round");
  - RULES section 0, the new rule `a-round-is-its-exact-families`.
