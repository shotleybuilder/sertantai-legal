---
name: Markup Reader Check
description: The LAT Change Pipeline's markup-reader acceptance check for one family of laws — the pattern catalogue, the sources gate, placement (our faults 0), keys against the feed, repeatability, golden, and a Claude agent checking a random sample of 50 changes against the law text. Use for every new family after the feed reader check; only defects with no known pattern go to Jason.
---

> **LAT Change Pipeline — step: Markup reader.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - The agent check below is used only to find NEW classes, on a small sample, and its token cost is recorded in the session. It is not a repeated pass gate.
> - **One agent pass at most, never sample → fix → resample** (Jason 2026-11-05, Maritime Safety: two rounds, 274k tokens, whack-a-mole). The forms it finds become a code check that finds the rest of their class over the corpus: as the commencement catalogues' leftovers (words of a statement no reading uses, ranked by reach: WORKFLOW.md step 4). Where a step has such a check, run it first and label its groups; the agent only labels what it can't.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.

# Markup Reader Check (CV-S03, per family)

## Purpose

Prove the markup reader (`ChangeVocabulary.Readers.Markup`) reads one family's revised-text change markup faithfully:
- each change (an Addition, Substitution or Repeal with a ChangeId) becomes one change on the provision where it sits;
- it carries what the markup states.

Whether legislation.gov.uk's markup is right is CV-S08's job; what it means for a label is CV-S09's.

**When to use:** for each family in the change-vocabulary workflow (CV-00, "Families after OH&S"), after the feed reader check passes for that family.

## Steps

Everything is read-only except step 0, which writes the catalogue fixtures. Ask Jason before running, and say how long each step takes.

0. **Pattern catalogue.** `mix lat.markup_patterns` takes ~16 min over every stored law text and writes only `backend/test/fixtures/markup_patterns/`. It prints:
   - the new patterns;
   - the examples that read differently from expected;
   - `unclassified` (must be 0).

   Take new patterns to Jason as measured patterns. Then either accept (`--accept`, review the diff), fix the reader, or mark the pattern `pending: <why>`.

   Pass: `mix test test/sertantai_legal/scraper/change_vocabulary/markup_patterns_test.exs`.
1. **Sources held (the gate)** and **2. placement:** `mix lat.markup_check --family "F" --all` (seconds per family).
   - It fails if a law with LAT rows lacks its stored law text or feed.
   - Our faults (`id_not_converted`, `row_missing`, `group_row_missing`) must be 0 for changes and for note placements.
   - It also prints the markup's keys against the feed (in feed / not in feed / legacy), a count for CV-S07.
3. **Repeatability:** run twice with a new seed, `--sample $S/a.json --n 50 --seed N` and `--sample $S/b.json …`.
   - `cmp` the samples: they must be identical.
   - Diff the reports: they must be identical.
   - Record the seed.
4. **Golden:** `mix lat.vocabulary --golden` (~5 min) stays all-pass.
5. **Agent check:** a general-purpose agent with the prompt below, on `$S/a.json`.

**Pass:** sources held; our faults 0; repeatable; golden all-pass; the agent finds no WRONG outside the known patterns. Record the results in the family's step session. Only NEW defects go to Jason, one at a time, with the markup and the reader's reading.

## Agent prompt

Use the round-2 prompt in `.claude/sessions/change-vocabulary/2026-10-22-cv-s03-markup-reader.md` ("Agent prompt"). Fill in FILE and the family, and add any known patterns found since. It covers:
- **Rules:** keys, the paired substitution, placement (row ids only, heading groups via `heading_of`, whole only when the change touches the provision's own number, heading or text or covers all its text, else per child; groups split, repeated ids by Pnumber), names, operation, level, retained, territory, and `cited`/`affecting` from the note's Operative `CitationSubRef`s.
- **Known patterns:** K1, K3, K9, M1–M3, P1.
- **Output:** a table with placement and facts per item, counts, and NEW defects with evidence. Under 900 words.
- **Verdicts (CV-S10):** append to the prompt the VERDICTS block from `feed-reader-check` (step "markup"; id "<law>|<key last 6>"; group the law), so `mix lat.verdicts` can pool the round.

## History

- OH&S (first family, 2026-10-23), session `.claude/sessions/change-vocabulary/2026-10-22-cv-s03-markup-reader.md`:
  - **Catalogue:** fixes A–E. **Seed 1:** F (EU Sections), G (structured pointers), H (per-child placement), I (repeated ids by Pnumber).
  - **Seed 2:** placement 50/50, facts 46/50; the 4 were schedule pointer naming, fixed.
- Environmental Protection (2026-11-09), `.claude/sessions/lat-change-pipeline/2026-11-09-environmental-protection-markup-reader.md`:
  - **Check:** a scoped law's changes beyond its fragments are `outside_lat_scope`; the check's PASS counts note faults too.
  - **Catalogue:** the paired-substitution key is shared (`Markup.substitutions/1`), and held examples come first on regeneration.
  - **Seed 61** (152,593 tokens): placement 50/50, facts 49/50. A number inside quoted text was read as the provision's own; fixed.
  - **Known patterns to add to the prompt:**
    - `outside_lat_scope`;
    - a paired substitution in two elements gives two claim sets on one row;
    - L1 (#188);
    - L2 (EU unnumbered list items);
    - L3 (heading and kept-children readings).
  - **Budget:** about 150k tokens.
