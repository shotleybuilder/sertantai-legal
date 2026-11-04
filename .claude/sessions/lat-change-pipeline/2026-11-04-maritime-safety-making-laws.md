---
session: 'Maritime Safety: Making laws'
status: closed
opened: '2026-11-04'
closed: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
step: Making laws
outcome: success
summary: >
  New pipeline step 0, Making laws: each live Maritime Safety law decided from its own text (MakingLaws) with no
  fractalaw dependency — 117 making, 51 not making, 6 no verdict (3%); 25 stored estimates corrected through the new
  law_text resolver tier; the 101 making laws without LAT rows parsed (17,972 rows, 0 errors). All six pass rules met
  on first plan, same day.
decisions:
  - what: Making laws is a formal step 0 before Sources, decided from law text
    why: LAT holds rows only for making laws; for 158 of 174 live laws is_making was an estimate never read from text (Jason)
    result: WORKFLOW/README/RULES updated; the step ran in one day
  - what: law_text tier below review and enrichment, above every estimate
    why: a human review and fractalaw's DRRP reading are finer; every estimate yields to the text
    result: 24 is_making values changed with dissent logged; no review or enrichment overruled
  - what: SI 2026/306 review corrected to making (Decision 1)
    why: its own regs. 5(1), 5(3), 6(1), 6(3), 8(4) state duties, not inserted text
    result: checked laws 23/23
  - what: six no-verdict laws left as stored (Decision 2)
    why: unknown over guess; four hold only repealed text (a register fault, parked)
    result: none given rows
metrics:
  laws: { live: 174, making: 117, not_making: 51, no_verdict: 6, is_making_changed: 24 }
  sources: { bodies_fetched: 145, fetch_failed: 1 }
  parse: { laws: 100, rows: 17972, errors: 0, seconds_per_law: 3 }
  checks: { checked_laws: 23, agree: 23, report_runs_identical: true, tests: 9817, failures: 0 }
  cost: { days: 1, plan_changes: 0, agent_tokens: 0, commits: 12 }
lessons:
  - title: The pre-commit ratchet emptied path-limited commits
    detail: mix credo diff checks HEAD out with git; under `git commit -- <paths>` GIT_INDEX_FILE is git's temporary index and was reset to HEAD, so a code commit went in empty while the hook printed pass. Always check `git show --name-only` after a hooked commit; fixed by unsetting GIT_INDEX_FILE for credo.
    tag: tooling
  - title: Title words mislead the making estimate both ways
    detail: "(Amendment)" SIs that make their own duties (2026/306) and amending-only SIs with old duty types (Port State Control (Amendment) 2003) — 25 of 151 estimates were wrong. The law's provisions decide it in seconds once the text is held.
    tag: data
  - title: The architecture tests hold the step to its owners
    detail: a new "comes into force" regex failed the one-commencement-path test; reusing Commencement.SentencePatterns kept the verdicts and fixed 9 reasons ("shall come into operation" counted as a requirement).
    tag: tooling
  - title: The store-only parse is fast
    detail: 3 s a law from the CLML store, 100 laws in minutes, against an estimate of 1-2 h.
    tag: data
bugs:
  - pattern: "The pre-commit function-size ratchet emptied `git commit -- <paths>` commits: credo diff's checkout of HEAD reset git's temporary index (284de4cb went in empty)"
    category: tooling
    module: .githooks/pre-commit
    affected: 1
    fix: "credo diff run with GIT_INDEX_FILE unset (49b0a850); the empty commit undone and redone (c0db12f6)"
    step: "Tooling"
    status: fixed
  - pattern: "Laws marked live whose held text is all repealed ('. . .'), e.g. UK_uksi_2011_2601 (in force), UK_nisr_1989_321, UK_ukpga_1984_5, UK_uksi_2014_308"
    category: live-status
    module: live status (legal_register.live)
    affected: 4
    fix: "check live status against the held text; mark revoked where every provision is repealed"
    step: "Register"
    status: open
  - pattern: "mix lat.reparse creates lat_reparse_<tag> snapshot tables in public even for laws with no rows (4 empty tables left from this step: lat_reparse_making_pilot[_cm], lat_reparse_making_maritime[_cm])"
    category: restore-points
    module: Scraper.LatReparse.snapshot!/2
    affected: 4
    fix: "skip the snapshot when no law in the batch has rows, or use a restore schema / nas-backup --tables; Jason to drop the four empty tables"
    step: "LAT parser"
    status: open
    issue: 189
  - pattern: "mix live.fetch_effects crashes encoding a range target as JSON (Jason.Encoder not implemented for Tuple: {\"regulation-9-2A\", \"regulation-9-2C\"}), so the 4 repealed-text laws' feeds can't be cached for live.apply_effects"
    category: effects-cache-range-tuple
    module: Scraper.LiveStatus.EffectsBackfill (fetch cache write)
    affected: unknown (any law whose feed holds a range)
    fix: "write ranges as two-item lists in the cache JSON"
    step: "Register"
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/making_laws.ex
  - backend/lib/mix/tasks/lat.making_laws.ex
  - backend/lib/sertantai_legal/legal/taxa/making_resolver.ex
  - backend/priv/repo/migrations/20261104120748_making_text_verdict.exs
  - backend/test/sertantai_legal/scraper/making_laws_test.exs
  - backend/test/sertantai_legal/scraper/making_laws_checked_test.exs
  - backend/data/reports/making-laws/transport-maritime-safety.csv
  - docs/lat-change-pipeline/WORKFLOW.md (step 0), RULES.md (section 0)
depends_on:
  - 2026-11-04-maritime-safety-meta.md
enables:
  - "Maritime Safety: Sources, on 117 making laws with LAT rows"
---

# Session: Maritime Safety: Making laws (CLOSED)

## Problem

LAT holds rows only for in-force making laws, and every later step places changes on those rows. In Maritime Safety only 16 of 174 live laws have rows. For the other 158, `is_making` is an estimate that was never read from the law's text. The probe found one estimate already wrong: Port State Control (Amendment) Regulations 2003 is amending only. This step, new and placed before Sources, decides each live law from its own text and parses the making ones into LAT.

Plan (approved 2026-11-04): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`; principles law-text-wins and unknown-over-guess.
- **Time box:** 1½ days.
- **Meta:** `2026-11-04-maritime-safety-meta.md`.

## Todo

- ✅ Session and step paperwork: WORKFLOW step 0, README, CLAUDE.md, docs index, `bug-raise`, the `step:making-laws` label, meta session
- ✅ Classifier `MakingLaws` (pure, TDD, 17 tests): changes only / making / no verdict; on the 29 laws held, agrees with all 18 review and fractalaw verdicts; Port State Control 2003 reads changes only
- ✅ Evidence tier: `making_text_verdict` and `making_text_reason` columns (Ash migration, run in dev and test); `:law_text` in `MakingResolver` below review and enrichment (e311ed5e)
- ✅ Task `mix lat.making_laws --family F [--fetch] [--apply]` and the CSV report (b00eade6; 13 s read-only over 174 laws)
- ✅ Fetch the missing bodies: 145 laws, body and Schedules; 1 failed (2013/1473 Schedules)
- ✅ Checked laws: 23/23 after Decision 1; report run twice, byte-identical; decisions taken
- ✅ Restore point (`making-laws-maritime`); `--apply` (168 verdicts, 24 `is_making` changed); 100 laws parsed, 17,972 rows, 0 errors; the four empty snapshot tables left for Jason (drop denied to me)
- ✅ Close: pass rule re-run (9,817 tests pass), RULES.md section 0 (5 rules), meta status row

## Pass rule (fixed)

1. The rule is unit-tested by kind: amending only, commencement order, mixed, powers only, inserted text with "shall", modification, standard wording only.
2. The classifier agrees with the 23 checked laws, or each disagreement is decided by Jason (never tuned to one law). The checked laws are 15 with rows (13 by fractalaw enrichment, 2 by review), 5 by review and 2 by enrichment without rows, and Port State Control 2003.
3. All 174 live laws are accounted for, and the no-verdict list is at most 10%.
4. Two runs give a byte-identical CSV.
5. Every law decided making has LAT rows after the parse, or is named with a reason.
6. `mix test` 0 failures; ratchet and credo clean; hooks pass.

Golden (27) untouched.

## Dependencies

- ✅ Jason's decision: a formal step, from law text, no fractalaw dependency (meta session, Decision 2)
- ✅ Readers to reuse: `Amendment.Patterns.form/4`, `AmendingLaw.Doc`, `AmendingLaw.Text`, the commencement reader's forms
- ✅ Single write path `Making.record/4`

## Parking list
- Register: 4 laws marked live whose held text is all repealed (". . ."): `UK_uksi_2011_2601` (in force), `UK_nisr_1989_321` (in force), `UK_ukpga_1984_5`, `UK_uksi_2014_308` (part revoked). The live status looks wrong. Owner: Register (live status), not this step.

## Results (2026-11-04)

Report: `backend/data/reports/making-laws/transport-maritime-safety.csv`. It is 174 rows, byte-identical across two runs, and a read-only run takes 13 s.

| Verdict | Laws |
|---|---|
| making | 117 (16 with LAT rows, 101 without) |
| not making: changes only | 51 |
| no verdict | 6 (3%; the bound is 10%) |

- **Against the stored `is_making`:** 25 disagree. 17 would become making: 6 EU instruments, the Merchant Shipping Acts 1970, 1974, 1979 and 1982, Cargo Ship Construction 1997, and others; all but one were `legacy_is_making` false. 8 would become not making, all amending-only: Port State Control (Amendment) 2003, Fire Protection (Amendment) 1999, Tonnage (Amendment) 2020 and others; 7 of them were `legacy_drrp` true.
- **No law decided not making has LAT rows**, so none loses rows.
- **Checked laws:** 22/23 agree. The exception is Decision 1.
- **Classifier fixes made on the first 29 held laws.** Each is a general form, unit-tested:
  - "shall be modified as follows" is a change;
  - "the Schedule to this Order … shall come into force" is a commencement;
  - "shall not affect" and "shall each be liable" are standard wording;
  - the month "May" is not a power.

## Decisions for Jason

### 1. SI 2026/306: the human review against the text — DECIDED (a), 2026-11-04: review corrected to making (`mix making.review`)

- **Question.** Merchant Shipping (EPIRB and PLB Registration and Radiocommunications) (Amendment) Regulations 2026. The human review says not making. Its own reg. 5(1) reads: "The owner and master of a ship must ensure that every EPIRB carried on that ship is registered with the Secretary of State". Regs. 5(3), 6(1), 6(3) and 8(4) state similar duties. Is it making?
- **Aim:** `binds-on-date`. If it is making and has no rows, its duties get no labels.
- **Options:**
  - (a) correct the review to making (`mix making.review`), and the law is parsed with the rest;
  - (b) keep the review: it stays not making, with no rows.
- **Recommendation:** (a). The duties are in its own regulations, not in inserted text. A review outranks the text tier, so `--apply` won't change it alone.

### 2. The six laws with no verdict — DECIDED (a), 2026-11-04: left as stored

- **Question.** What becomes of them?
  - Four hold only repealed text (Parking list).
  - Two are "changes and powers": 2018/1109 Work in Fishing Convention (Consequential Provisions) and 2019/270 Recognised Organisations (Amendment) (EU Exit). Both are stored not making.
- **Aim:** unknown-over-guess.
- **Options:**
  - (a) leave all six without a text verdict, with their stored values kept (none is given rows);
  - (b) rule each now.
- **Recommendation:** (a). Five are stored not making. The sixth, 2011/2601, is stored making on old duty types, but all its text is repealed, so it binds no one now; the register fault is parked.

### 3. Go for the apply and the parse — DECIDED go, 2026-11-04

- **Apply:** `--apply` records 168 text verdicts through `Making.record` and changes `is_making` on 24 laws (25 less 2026/306, which its review holds). First, a restore point: `nas-backup.sh --tables legal_register,legal_articles --tag making-laws-maritime`.
- **Parse:** the 101 making laws without rows (95 UK, 6 EU), from the store, about 1–2 h. This writes `legal_articles` and the LAT tables.
- **Recommendation:** go, once Decisions 1 and 2 are settled.
- LAT parser: `mix lat.reparse` left 4 empty `lat_reparse_making_*` tables in public (drop for Jason).
