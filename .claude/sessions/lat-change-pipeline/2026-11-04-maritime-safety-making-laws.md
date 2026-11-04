---
session: 'Maritime Safety: Making laws'
status: active
opened: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
step: Making laws
---

# Session: Maritime Safety: Making laws (ACTIVE)

## Problem

LAT holds rows only for in-force making laws, and every later step places changes on those rows. In Maritime Safety only 16 of 174 live laws have rows. For the other 158, `is_making` is an estimate that was never read from the law's text. The probe found one estimate already wrong: Port State Control (Amendment) Regulations 2003 is amending only. This step, new and placed before Sources, decides each live law from its own text and parses the making ones into LAT.

Plan (approved 2026-11-04): `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`; principles law-text-wins and unknown-over-guess.
- **Time box:** 1½ days.
- **Meta:** `2026-11-04-maritime-safety-meta.md`.

## Todo

- ✅ Session and step paperwork: WORKFLOW step 0, README, CLAUDE.md, docs index, `bug-raise`, the `step:making-laws` label, meta session
- ⬜ Classifier `MakingLaws` (pure, TDD): changes only / making / no verdict
- ⬜ Evidence tier: `making_text_verdict` and `making_text_reason` columns (Ash migration); `:law_text` in `MakingResolver` below review and enrichment
- ⬜ Task `mix lat.making_laws --family F [--fetch] [--apply]` and the CSV report
- ⬜ Fetch the missing bodies (count reported first)
- ⬜ Checked laws (23) fixture test; the family report run twice; disagreements and the no-verdict list to Jason
- ⬜ Restore point; `--apply`; parse the newly decided making laws; drop the empty reparse snapshot tables
- ⬜ Close: pass rule re-run, RULES.md (Making laws), meta status row

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
