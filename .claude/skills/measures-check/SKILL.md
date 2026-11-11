---
name: Measures Check
description: The LAT Change Pipeline's measures for one family. It prints every published figure from code (coverage, dating, who states a change, the pass bounds from agent verdict files), proves the samples and printed figures replicable (draw twice, compare), and holds the register defining each figure. Use it when a step closes, for a quality statement, and for each new family.
---

> **LAT Change Pipeline — step: Measures.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms and former codes (CV-…): `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The check is code first: table rules, checked-row fixtures, pattern catalogues, golden from inputs.
> - The agent check below is used only to find NEW classes, on a small sample, and its token cost is recorded in the session. It is not a repeated pass gate.
> - **One agent pass at most, never sample → fix → resample** (Jason 2026-11-05, Maritime Safety: two rounds, 274k tokens, whack-a-mole). The forms it finds become a code check that finds the rest of their class over the corpus: as the commencement catalogues' leftovers (words of a statement no reading uses, ranked by reach: WORKFLOW.md step 4). Where a step has such a check, run it first and label its groups; the agent only labels what it can't.
> - Bugs in another step's code are raised with `bug-raise` and parked, never fixed here.

# Measures Check (CV-S10, per family)

## Purpose

Every figure a step publishes (in a quality statement, a pass rule or a session's closing metrics) is:
1. **defined** in the register below: one name, one meaning;
2. **computed by code**, never by hand;
3. **tested** on hand-built data;
4. **replicable**: the same store and seed give the same sample and the same figures.

All steps here are read-only.

## Commands

| Figure | Command |
|---|---|
| Pass bounds, end to end, gaps, doubtful | `mix lat.verdicts --dir DIR [--limit 0.02 --group-limit 0.05]` |
| Who states a text change; law-text coverage; dating | `mix lat.measures --family "F"` or `--golden [--extended]` |
| Territory coverage | `mix lat.extent_check --family "F"` ("territory from", grouped by `Measures.Coverage.territory_groups/1`) |
| Strata, agreement, join rate | each step's `lat.*_check --strata` |
| Golden | `mix lat.vocabulary --golden` |

## Verdict files

Each check skill's agent prompt ends with a VERDICTS block: one JSON object per agent batch. Save each block as:

    backend/data/reports/change-vocabulary/verdicts/<step>/<family-slug>/round-<N>-<stratum>-seed-<S>[-b<k>].json

The directory is NAS-backed and not in git, since items may carry effect ids. Save the block when the agent hands back, in the same step: Maritime Safety's passes saved none, and five were recovered later from the agents' hand-back messages; the rest are hand tallies, report only. Then pool the files since the step's last fix batch with `mix lat.verdicts --dir <that directory>`. Pass only the files since the last fix; an item checked twice counts once, the later round standing.

- **Counted against the bound:** wrong items whose fault is `own`. A group (law or pair) is wrong when any of its items counts.
- **End to end:** every wrong item, whoever's fault.
- **Gaps and doubtful items** are listed, never counted.

The bound is the exact one-sided 95% Clopper–Pearson upper bound (`Measures.Bound`). Under 2% needs at least 149 clean items.

## Replicability

Draw every check's sample twice with one seed and compare, using `draws.sh` (below). Samples must be byte-identical (`cmp`). Printed figures must be identical once log lines, compile lines and output paths are filtered out.

Every check's draw lives in `Measures.Draw`, with its seed tuple and algorithm unchanged since the round it was first used, so a recorded seed still draws its sample. A change to a draw invalidates every recorded seed for that step. Don't make one without Jason.

```bash
#!/bin/bash
# draws.sh OUTDIR FAMILY SEED: every check's figures, strata, gate and sample at SEED, with run times
O=$1; F=$2; SEED=${3:-902}; mkdir -p $O; cd backend
run() { name=$1; shift; s=$(date +%s); mix "$@" > $O/$name.out 2> $O/$name.err; echo "$name exit=$? $(( $(date +%s) - s ))s" >> $O/times.txt; }
run making lat.making_laws --family "$F" --out $O/making.csv
run sources lat.sources --family "$F"
run feed lat.feed_check --family "$F" --all --sample $O/feed.json --n 50 --seed $SEED
run markup lat.markup_check --family "$F" --sample $O/markup.json --n 50 --seed $SEED
run commencement lat.commencement_check --family "$F" --sample $O/commencement.json --n 50 --seed $SEED
run extent lat.extent_check --family "$F" --sample $O/extent.json --n 50 --seed $SEED
run amending lat.amending_check --family "$F" --strata --gate --sample $O/amending.json --n 50 --seed $SEED --stratum A
run merge lat.merge_check --family "$F" --strata --gate --stratum J --sample $O/merge.json --n 50 --seed $SEED
run evidence_a lat.evidence_check --family "$F" --strata --gate --stratum A --sample $O/evidence_a.json --n 50 --seed $SEED
run evidence_d lat.evidence_check --family "$F" --stratum D --sample $O/evidence_d.json --per 10 --seed $SEED
run label lat.label_check --family "$F" --strata --gate --stratum SR --sample $O/label.json --per 2 --n 23 --seed $SEED
run measures lat.measures --family "$F" --sample $O/hand.json --n 50 --seed $SEED
```

Every check's gate runs too, so a pass is also the re-run of every step's gate: a rebuild after a step closes can move an earlier step's gate (Maritime Safety, 2026-11-06: Sources, Extent and Amending had passed and failed here). Compare two passes with `cmp` on the samples and `diff` on the `.out` files with log lines (`[info]`, `[warning]`, `[debug]`, `Compiling`) and paths filtered.

On Maritime Safety (2026-11-06) a pass takes about 14 min: the label fold 12½ min, the rest 4–50 s each. On OH&S (2026-10-30, the older script) about 8 min.



## Register

Each published figure: its name, what it counts, the command printing it and the code computing it. **T** = printed by a task, **V** = pooled from verdict files by `mix lat.verdicts`. Figures that move with the store are quoted with their run (date, code commit), never as constants.

**One name, one meaning:**
- `stated_by_law_and_derived`: the change's *operation* is claimed by the law's text and by legislation.gov.uk. This is S06's "both" and CV-07's "both sources". A gap the law fills on another attribute doesn't count.
- `joined_any_two`: S07's J, stated by any two sources (markup and feed with no law text included). It is never called "both".
- `lawtext_disagreeing` (S06's D: a conflict on operation, level or by, or unjoined) is distinct from `evidence_value_conflict` (S08's V: a conflict on any attribute).
- `agreement_with_lgu` (S06): a law-text value matches any feed or markup value over the changes both state. It uses its own like-for-like list, simpler than `Conflicts`' like?/5, so it is not the conflict count's complement.
- `text_changes`: merged changes whose chosen operation is inserted, substituted, repealed, repealed_in_part or renumbered (`Measures.Coverage.text?/1`). The extent check's population is its own: text changes with an amending law to read.

| Step | Name | Counts | Source | Code (test) |
|---|---|---|---|---|
| Step 0 | making_verdicts | live laws by verdict: making, not making (changes only), no verdict by why; disagreeing with the stored `is_making` | T `lat.making_laws` | `MakingLaws` (making_laws_test) |
| S01 | sources_needed / sources_failures | documents a family needs, by category; needed and not held, without reason | T `lat.sources` ("needed, all categories"; "failures") | `Sources.report/3` (sources_test) |
| S02 | feed_effects_placement / feed_our_faults / feed_tell_tales | feed effects by placement outcome; fault outcomes; finer forms not held | T `lat.feed_check` | `Placement.fault?` (placement_test) |
| S03 | markup_changes_placement / markup_note_placements / markup_our_faults / markup_keys_vs_feed | markup changes by outcome; effects placed by their note ref alone, by the same outcomes (Environmental Protection, 2026-11-09); faults in either; keys in the feed, not in it, legacy | T `lat.markup_check` | `MarkupPlacement` (markup_placement_test) |
| S03 | legacy_pointer_share | legacy markup changes whose note gives a cited law (and amending provisions) | T `lat.markup_patterns` ("pointers (changes)") | `MarkupPatterns.pointers` |
| S02–S06 | <step>_catalogue | a corpus catalogue's run: items read (effects, changes, sentences, order units, provisions), laws, patterns, examples, unclassified (0), too large or not alone. Held in the fixture's `totals` by the run that wrote it, so they stay quotable without the (up to 25 min) re-run | T `lat.feed_patterns`, `lat.markup_patterns`, `lat.commencement_patterns`, `lat.order_patterns`, `lat.extent_patterns`, `lat.amendment_patterns` (writing `test/fixtures/<catalogue>/patterns.json` `totals`) | each catalogue's module (`*_patterns_test`: the held examples against `expected.json`) |
| S04 | commencement_rows_outcome / commencement_left_to_orders / commencement_gaps | rows by own-commencement outcome; by_order + by_order_partly; undated changes by class | T `lat.commencement_check` | `OwnCommencement` (own_commencement_test), `NoteDate.why/2` |
| S04 | order_statements_read | order statements read into rules, of all | T `lat.order_patterns` ("read into rules") | `Commencement.Order` |
| S05 | extent_territory_groups | text changes by where their territory comes from (law text, follows the enactment, feed/markup, law type not read, no powers, unread statement, competence only, no amending law, no extent clause (`no_clause`, Maritime Safety 2026-11-06; was other), other) | T `lat.extent_check` ("grouped") | `Coverage.territory_groups/1` (coverage_test) |
| S06 | lawtext_stated / lawtext_strata_ADL / agreement_with_lgu | changes the law's text states (both / alone); A, D, L; agreement per attribute | T `lat.amending_check --strata` | `CheckSample.stated_by`, `CheckStrata` (check_strata_test) |
| S06 | lawtext_coverage | text changes: stated_by_law_and_derived, law only; derived only, read with no rule (Schedule or annex / EU article / body), not read, other. Read = a pointer whose provision, or one containing it, is in the amending law's stored text (`Source.read_pointers/2`; before 2026-11-06 every pointer counted, held or not) | T `lat.measures` | `Coverage.law_text_coverage/2`, `Source.read_pointers/2` (coverage_test, source_test) |
| S07 | merge_strata_JUC / join_rate_{law_text,markup} / overjoin_spread_keys | J (joined_any_two), U, C; a source's text changes a feed effect states too; keys under more than 3 top provisions | T `lat.merge_check --strata` | `MergeStrata` (merge_strata_test) |
| S08 | evidence_strata_VDA / evidence_winners | V, D, A; the winning source per attribute | T `lat.evidence_check --strata` | `EvidenceStrata` (evidence_strata_test) |
| S08 | dating | text changes: undated, dated with no commenced_by, commenced_by named | T `lat.measures` | `Coverage.dating/1` (coverage_test) |
| S09 | label_strata | S shapes, T classes | T `lat.label_check --strata` | `LabelStrata` (label_strata_test) |
| S04–S09 | <step>_gate | a step's code gate: groups by cause (and law), by reviewed status (`known:`, `fix:`, `check:`, none); PASS when every group is `known:` | T commencement_check (leftovers), extent_check (withheld), `amending_check --gate`, `merge_check --gate`, `evidence_check --gate`, `label_check --gate` | `Leftovers.gate/1` (Withheld, Disagreement; family_leftovers_test, withheld_test, disagreement_test), `MergeGate.gate/1` (Gate.Evidence, Gate.Label; merge_gate_test, gate/evidence_test, gate/label_test) |
| S05 | extent_bound_by_law | text changes whose territory is the amending law's extent at the amending provisions: the `bound:law` outcome alone (the law_text group adds `territory:law`) | T `lat.extent_check` ("territory from") | `Extent.Check` (extent/check_test) |
| S08 | evidence_gaps | changes with an operation where no source claims an attribute: by (attribute, sources held), and totals by attribute with those whose amending law has no commencement rules | T `lat.evidence_check --gate` ("gaps by attribute") | `Gate.Evidence.gaps/2`, `gap_totals/1` (gate/evidence_test) |
| S09 | label_statuses / label_gaps | rows by current status; periods and table breaks; rows with an undated start or an undated change | T `lat.label_check --strata --gate` | `LabelStrata`, `Gate.Label.gaps/1` (label_strata_test, gate/label_test) |
| CV-07 | stated_by_split | text changes by `stated_by` (family or golden laws) | T `lat.measures [--golden]` | `Coverage.stated_by/1` (coverage_test) |
| all | golden_from_inputs / golden_extended | golden provisions passing from inputs | T `lat.vocabulary --golden [--extended]` | |
| S02–S09 | <step>_pooled (items, groups) / end_to_end | wrong items with the step's own fault and wrong groups since the last fix, with 95% upper bounds; every wrong item | V `lat.verdicts` | `Measures.Bound`, `Measures.Verdicts` (bound_test, verdicts_test) |
| S11 | build_repeatable | laws whose stored changes differ between two builds from the same inputs (digest: key, target, aliases, claims in order, resolved values as stored; not the tiers and conflicts derived on read) | T `lat.changes_digest --built`, compared with `cmp` | `ChangeDigest` (change_digest_test) |
| S11 | gates_all | every step's gate re-run after the build: PASS/FAIL per step, with its failing count | T `lat.gates` (`lat.vocabulary --check --family`) | `Gate.Step` (gate/step_test) |
| S11 | staleness_hand_check | the staleness sample's verdicts (seed tuple `{s, 11, 11}`) | V `verdicts/s11/<family>/`; sample `lat.stale --sample` | `Measures.StaleSample` (stale_sample_test) |
| S11 | build_time | the build's wall time | T `lat.vocabulary --build` ("built N laws in") | |
| S11 | changes_stale | built laws stale by reason; laws holding LAT with no build | T `lat.stale` ("change register") | `ChangeStaleness`, `Store.Inputs` (change_staleness_test, store_inputs_db_test) |
| S10 | measures_hand_check | text changes whose measure classes an agent found wrong (rule: none); the sample's items carry the classes | T `lat.measures --sample` (draw, seed tuple `{s,10,10}`); V `lat.verdicts` (ignore its 2% PASS line) | `Measures.HandSample` (hand_sample_test) |

**Derived statements** (arithmetic on V; state the inputs beside them): S05's "at least 98% of changes" is 1 − the changes bound. S06's overall ≈1.7% is A's bound × |A| / |law-text changes|.

**Published values before CV-S10** were worked out by hand from earlier stores. Where they differ from today's, the store moved. The 2026-10-30 comparison is in the CV-S10 session ("Measures in code"). S01's 1,253 doesn't sum: its table gives 1,203.

## Pass (Jason 2026-10-30)

- Every published figure is in the register, printed by code, with a test.
- Samples and printed figures replicate (draw twice, compare).
- The hand check finds no item classed wrong.

## History

- OH&S (first family, 2026-10-30), session `.claude/sessions/change-vocabulary/2026-10-22-cv-s10-measures.md`.
- Maritime Safety (2026-11-06), session `.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-measures.md`.
  - The audit found three gates that had passed and now fail (Sources, Extent, Amending), all moved by later rebuilds, plus one figure summed by hand and wrong (Evidence's gaps).
  - The hand check found three measure faults: the read set counted text not held, an order's art./reg. spelling, and a territory group unnamed.
  - The first family whose gates `draws.sh` re-runs.
- Environmental Protection (2026-11-11), session `.claude/sessions/lat-change-pipeline/2026-11-11-environmental-protection-measures.md`.
  - **No agent pass** (Jason: the Label fold's pass had cost 427,919 tokens). The hand sample is drawn twice and compared with `cmp`, Maritime's three measure-fault classes stay tested, and three items were read by hand. All were classed right.
  - **The audit found four gates or verdicts that had passed and fail today** (Sources 69, of which 47 are feeds stale by age alone; Extent 2 causes; Amending 4 groups; one Making laws verdict), all moved by later writes. The same pattern as Maritime.
  - **One pass takes about 10 min:** the label fold reads from the fold cache in 16 s.
  - **The register gained** `markup_note_placements` and `<step>_catalogue` (a catalogue's run figures, held in its fixture's `totals`).
