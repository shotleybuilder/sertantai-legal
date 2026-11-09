---
name: Commencement Reader Check
description: The LAT Change Pipeline's commencement-reader acceptance check for one family of laws — the two commencement catalogues with their leftovers (every statement's words bearing on a date that no rule uses, ranked by reach and reviewed), the family's re-read and rebuild, and the commencement check with its leftovers gate (every row dated or with a reason, every leftover reaching the family named). Use for every family after the markup reader passes; no agent rounds.
---

> **LAT Change Pipeline — step: Commencement reader.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md` step 4. Background: `docs/lat-change-pipeline/COMMENCEMENT-GUIDE.md`.
>
> **Process (retrospective 2026-11-03; Jason 2026-11-05):**
> - Plan the step in plan mode first, its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code over every statement, not a sample. **No agent rounds.** On Maritime Safety two agent rounds (274k tokens) were whack-a-mole: each found a few one-law forms. The leftovers check finds those forms and the rest of their class, ranked by reach.
> - At most one agent pass, only to label a leftover group the code can't; never sample → fix → resample.
> - Bugs in another step's code are raised with `bug-raise` and parked.

# Commencement Reader Check (per family)

## Purpose

Prove the commencement readers — the own-clause reader (`LawStart.Provisions`, `Commencement.OwnClause`), the order reader (`Commencement.Order`) and the gap-filler (`Readers.NoteDate`) — date a family's provisions from the laws' own words:
- every row is dated, left to an order, or undated with a reason;
- every word of the family's commencement statements that bears on a date is used by a rule, or sits in a named group.

## Steps

Ask Jason before the long runs; say what each writes.

1. **Catalogues** (read-only over the corpus; writes their fixtures and reports):
   - `mix lat.commencement_patterns` (own-clause sentences, about 10 min, one law at a time while a VM runs) and `mix lat.order_patterns` (about 30 s).
   - Each prints its patterns against `expected.json` (new patterns: accept, fix or `pending:`; held expectations never move without Jason) and its **leftovers by shape**, ranked by reach. The report goes to `backend/data/reports/commencement-reader/leftovers[-orders]-<date>.txt`.
   - Review every leftover group with no status into `leftovers.json`: `fix:` (a reader miss), `known:` (a named limit, also in `RULES.md` known limits) or `check:` (the check's own error: fix it in `Commencement.Leftovers` with a test). `LeftoversReviewTest` fails on a group with no status. A statement under a decided limit in a group with real misses is named apart: `"<shape> @ <row>": "known: …"` (a laid-relative day, limit C); its group stays `fix:`.
   - **Freeze code while a catalogue runs**: it loads modules lazily, so an edit mid-run gives a mixed run.
   - **Dry-run into a scratch copy:** `--out DIR` after copying the fixtures there. A run writes the generated fixture files even without `--accept`. To tell this step's changes from laws the store has gained, run once more at the last commit's code (stash the reader files) into another scratch copy, and compare the leftover statements (Environmental Protection, 2026-11-09: three regressions found this way).
   - **Held moves:** `--accept` keeps held readings as held. Write each agreed move from the reader with the task's encoder, then run the tests with `--include pending`.
2. **Fixes** (TDD, in the readers): a failing unit test per form first; `--fresh` shows the effect without writes (`mix lat.commencement_check --family F --fresh`).
3. **Re-read and rebuild** (ask first; restore point of `commencement_rules`, `provision_changes`, `provision_change_claims`, `lat_events`):
   - `mix lat.commencement --read --law <family's laws>`;
   - `mix lat.commencement --read-orders --law <family's laws>` — **this searches legislation.gov.uk's title search for a law with no cached order list**: name it in the plan;
   - the orders it lists as not held (`data/reports/commencement-rules/orders_missing.txt`): `mix clml.fetch --whole --laws …` — an order is held with its schedules, its table (WORKFLOW.md step 1); a fetch, ask first;
   - `mix lat.commencement --read-amending --law <held amenders> --workers 1` — amending laws only, never the commencement orders (the family gate leaves them out too);
   - `mix lat.vocabulary --build --family F`.
4. **The check and its gate:** `mix lat.commencement_check --family F [--all]`:
   - rows: our faults (not reached, no rules) 0;
   - gaps: every undated change with a reason;
   - the feed yardstick (agree / differ), never a source;
   - **leftovers reaching the family**: the family's own clauses, the orders held for its laws and its held amending laws, each leftover with its group's status. Report `gate-<family>-<date>.txt`.
   - PASS only when our faults are 0 and every leftover reaching the family is `known:`.
5. **Repeatability:** `--sample FILE --n 50 --seed N` twice; `cmp` the samples.
6. **Golden:** `mix lat.vocabulary --golden` (`--workers 1` while a VM runs) all-pass.

**Pass:** the check prints PASS (rows' faults 0, leftovers not named 0); every leftover group reviewed; catalogue tests pass; repeatable; golden all-pass; `mix test`.

## History

- OH&S (2026-10-23/24): the sentence and order catalogues; four agent rounds; the stopping rule. `.claude/sessions/archive/change-vocabulary/2026-10-22-cv-s04-commencement-reader.md`.
- Maritime Safety (2026-11-05): two agent rounds found 10 one-law forms — the regression that led to the leftovers. `.claude/sessions/lat-change-pipeline/2026-11-05-maritime-safety-commencement-reader.md`.
- The leftovers check (2026-11-05): `2026-11-05-commencement-catalogue-leftovers.md`; the family gate: `2026-11-05-commencement-leftovers-family-gate.md`.
- Environmental Protection (2026-11-09): no agent pass. Rows' faults 0 on stored rules, 23 leftovers to 0 (5 named known), golden 27/27. Two catalogue dry runs into a scratch `--out`, one at the last commit's code, found three regressions before the accept. The stored check found an order-list overlap the fresh read cannot see. `.claude/sessions/lat-change-pipeline/2026-11-09-environmental-protection-commencement-reader.md`.
