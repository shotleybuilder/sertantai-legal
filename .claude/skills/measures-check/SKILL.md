---
name: Measures Check
description: The change vocabulary's measures (CV-S10) for one family. It prints every published figure from code (coverage, dating, who states a change, the pass bounds from agent verdict files), proves the samples and printed figures replicable (draw twice, compare), and holds the register defining each figure. Use it when a step closes, for a quality statement, and for each new family.
---

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

The directory is NAS-backed and not in git, since items may carry effect ids. Then pool the files since the step's last fix batch with `mix lat.verdicts --dir <that directory>`. Pass only the files since the last fix; an item checked twice counts once, the later round standing.

- **Counted against the bound:** wrong items whose fault is `own`. A group (law or pair) is wrong when any of its items counts.
- **End to end:** every wrong item, whoever's fault.
- **Gaps and doubtful items** are listed, never counted.

The bound is the exact one-sided 95% Clopper–Pearson upper bound (`Measures.Bound`). Under 2% needs at least 149 clean items.

## Replicability

Draw every check's sample twice with one seed and compare, using `draws.sh` (below). Samples must be byte-identical (`cmp`). Printed figures must be identical once log lines, compile lines and output paths are filtered out.

Every check's draw lives in `Measures.Draw`, with its seed tuple and algorithm unchanged since the round it was first used, so a recorded seed still draws its sample. A change to a draw invalidates every recorded seed for that step. Don't make one without Jason.

```bash
#!/bin/bash
# draws.sh OUTDIR: every check's sample at seed 901, with its printed figures and run time
O=$1; mkdir -p $O; cd backend; F="OH&S: Occupational"
run() { name=$1; shift; s=$(date +%s); mix "$@" > $O/$name.out 2> $O/$name.err; echo "$name exit=$? $(( $(date +%s) - s ))s" >> $O/times.txt; }
run feed lat.feed_check --family "$F" --sample $O/feed.json --n 50 --seed 901
run markup lat.markup_check --family "$F" --sample $O/markup.json --n 50 --seed 901
run commencement lat.commencement_check --family "$F" --sample $O/commencement.json --n 50 --seed 901
run extent lat.extent_check --family "$F" --sample $O/extent.json --n 50 --seed 901
run amending lat.amending_check --family "$F" --sample $O/amending.json --n 50 --seed 901 --stratum A
run merge lat.merge_check --family "$F" --stratum J --sample $O/merge.json --n 50 --seed 901
run evidence_a lat.evidence_check --family "$F" --stratum A --sample $O/evidence_a.json --n 50 --seed 901
run evidence_d lat.evidence_check --family "$F" --stratum D --sample $O/evidence_d.json --per 10 --seed 901
run label_r lat.label_check --family "$F" --stratum R --sample $O/label_r.json --n 30 --seed 901
run label_s lat.label_check --family "$F" --stratum S --sample $O/label_s.json --per 10 --seed 901
```

On OH&S (2026-10-30) a pass takes about 8 min: label about 3 min each, the rest 4–25 s each.

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
| S01 | sources_needed / sources_failures | documents a family needs, by category; needed and not held, without reason | T `lat.sources` ("needed, all categories"; "failures") | `Sources.report/3` (sources_test) |
| S02 | feed_effects_placement / feed_our_faults / feed_tell_tales | feed effects by placement outcome; fault outcomes; finer forms not held | T `lat.feed_check` | `Placement.fault?` (placement_test) |
| S03 | markup_changes_placement / markup_our_faults / markup_keys_vs_feed | markup changes by outcome; faults; keys in the feed, not in it, legacy | T `lat.markup_check` | `MarkupPlacement` (markup_placement_test) |
| S03 | legacy_pointer_share | legacy markup changes whose note gives a cited law (and amending provisions) | T `lat.markup_patterns` ("pointers (changes)") | `MarkupPatterns.pointers` |
| S04 | commencement_rows_outcome / commencement_left_to_orders / commencement_gaps | rows by own-commencement outcome; by_order + by_order_partly; undated changes by class | T `lat.commencement_check` | `OwnCommencement` (own_commencement_test), `NoteDate.why/2` |
| S04 | order_statements_read | order statements read into rules, of all | T `lat.order_patterns` ("read into rules") | `Commencement.Order` |
| S05 | extent_territory_groups | text changes by where their territory comes from (law text, follows the enactment, feed/markup, law type not read, no powers, unread statement, competence only, no amending law, other) | T `lat.extent_check` ("grouped") | `Coverage.territory_groups/1` (coverage_test) |
| S06 | lawtext_stated / lawtext_strata_ADL / agreement_with_lgu | changes the law's text states (both / alone); A, D, L; agreement per attribute | T `lat.amending_check --strata` | `CheckSample.stated_by`, `CheckStrata` (check_strata_test) |
| S06 | lawtext_coverage | text changes: stated_by_law_and_derived, law only; derived only, read with no rule (Schedule or annex / EU article / body), not read, other | T `lat.measures` | `Coverage.law_text_coverage/2` (coverage_test) |
| S07 | merge_strata_JUC / join_rate_{law_text,markup} / overjoin_spread_keys | J (joined_any_two), U, C; a source's text changes a feed effect states too; keys under more than 3 top provisions | T `lat.merge_check --strata` | `MergeStrata` (merge_strata_test) |
| S08 | evidence_strata_VDA / evidence_winners | V, D, A; the winning source per attribute | T `lat.evidence_check --strata` | `EvidenceStrata` (evidence_strata_test) |
| S08 | dating | text changes: undated, dated with no commenced_by, commenced_by named | T `lat.measures` | `Coverage.dating/1` (coverage_test) |
| S09 | label_strata | S shapes, T classes | T `lat.label_check --strata` | `LabelStrata` (label_strata_test) |
| CV-07 | stated_by_split | text changes by `stated_by` (family or golden laws) | T `lat.measures [--golden]` | `Coverage.stated_by/1` (coverage_test) |
| all | golden_from_inputs / golden_extended | golden provisions passing from inputs | T `lat.vocabulary --golden [--extended]` | |
| S02–S09 | <step>_pooled (items, groups) / end_to_end | wrong items with the step's own fault and wrong groups since the last fix, with 95% upper bounds; every wrong item | V `lat.verdicts` | `Measures.Bound`, `Measures.Verdicts` (bound_test, verdicts_test) |
| S11 | build_repeatable | laws whose stored changes differ between two builds from the same inputs (digest: key, target, aliases, claims in order, resolved values) | T `lat.changes_digest`, compared with `cmp` | `ChangeDigest` (change_digest_test) |
| S11 | build_time | the build's wall time | T `lat.vocabulary --build` ("built N laws in") | |
| S11 | changes_stale | built laws stale by reason; laws holding LAT with no build | T `lat.stale` ("change register") | `ChangeStaleness`, `Store.Inputs` (change_staleness_test, store_inputs_db_test) |
| S10 | measures_hand_check | text changes whose measure classes an agent found wrong (rule: none) | V `lat.verdicts` (ignore its 2% PASS line) | — |

**Derived statements** (arithmetic on V; state the inputs beside them): S05's "at least 98% of changes" is 1 − the changes bound. S06's overall ≈1.7% is A's bound × |A| / |law-text changes|.

**Published values before CV-S10** were worked out by hand from earlier stores. Where they differ from today's, the store moved. The 2026-10-30 comparison is in the CV-S10 session ("Measures in code"). S01's 1,253 doesn't sum: its table gives 1,203.

## Pass (Jason 2026-10-30)

- Every published figure is in the register, printed by code, with a test.
- Samples and printed figures replicate (draw twice, compare).
- The hand check finds no item classed wrong.

## History

- OH&S (first family, 2026-10-30), session `.claude/sessions/change-vocabulary/2026-10-22-cv-s10-measures.md`.
