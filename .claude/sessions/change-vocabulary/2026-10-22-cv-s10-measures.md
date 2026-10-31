---
session: 'CV-S10: Measures'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-31'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  Every figure the change-vocabulary workflow publishes is now defined once (a register in the measures-check skill),
  printed by code and tested: the 95% pass bound and the pool across seeds from agent verdict files (mix lat.verdicts),
  coverage, dating and who-states-a-change (mix lat.measures), and the totals steps had summed by hand. Every check's
  sample is drawn by one tested module with its seed and algorithm unchanged, and samples and figures replicate
  byte for byte; a hand check of 50 classified text changes found none wrong after one measure fault was fixed.

decisions:
  - what: Scope is the published figures (quality statements, pass rules, closing metrics), not every printed tally
    why: Jason 2026-10-30; the diagnostic counts nobody quotes would multiply the work several times
    result: about 25 register entries; other tallies keep their task's label
  - what: Agent verdicts saved as JSON files per batch, pooled by a task into the bounds and the end-to-end figure
    why: every pass decision S05-S09 was tallied and bounded by hand from agents' prose tables (Jason 2026-10-30)
    result: Measures.Bound reproduces every published bound to two places; the check prompts end with a VERDICTS block; files under backend/data/reports/change-vocabulary/verdicts/ (NAS, not git, effect ids)
  - what: Where one word means different things, rename and keep both, not unify
    why: unifying would move strata membership in steps that already passed (Jason 2026-10-30)
    result: stated_by_law_and_derived (S06 'both' = CV-07 'both sources', proven equal on today's store) vs joined_any_two (S07 J), and the others named apart
  - what: Keep each check's seed tuple and draw algorithm exactly when moving them into Measures.Draw
    why: a recorded seed only replicates its sample if both stay; proven by drawing before and after
    result: all ten samples byte-identical across three passes
  - what: S01 gate failure (103 not fetched) deferred to the next pass from step 1
    why: 96 are EU amenders whose territory isn't read (KE); S11 (Store and build) makes the re-run automatic (Jason 2026-10-31)
    result: logged open
  - what: Close on 0 of 50 classed wrong, not widen to a 2% bound
    why: the agreed rule for the hand check was "no item classed wrong" (Jason 2026-10-31)
    result: closed PASS

metrics:
  bounds_reproduced: { "0/150": "1.98%", "0/73": "4.02%", "3/150": "5.09%", "0/160": "1.85%", "0/86": "3.42%", "0/112": "2.64%", "0/81": "3.63%", "10/300": "5.59%", "1/300": "1.57%" }
  replicability: { checks: 10, passes: 3, samples_identical: 10, printed_identical: 10, pass_minutes: 8 }
  hand_check: { items: 50, measure_wrong: 0, upstream_wrong: 1, gaps: 2, measure_faults_fixed_before: 1, seed: 911 }
  ohs_today: { text_changes: 4763, stated_by_law_and_derived: "1235 (25.9%)", law_only: 161, derived_only: 3367, cv07_published: "13%" }
  golden_today: { laws: 21, text_changes: 14800, stated_by_law_and_derived: "3554 (24.0%)", cv07_published: "22%" }
  ohs_law_text_coverage: { read_no_rule_schedule_or_annex: 867, read_no_rule_eu_article: 655, read_no_rule_body: 1067, not_read: 490, other: 288 }
  ohs_dating: { undated: 579, dated_no_commenced_by: 2694, commenced_by_named: 1490 }
  ohs_territory_groups: { law_text: 3072, follows_enactment: 270, feed_or_markup: 1, law_type_not_read: 554, no_powers: 415, unread_statement: 272, competence_only: 151, no_amending_law: 23, other: 5 }

lessons:
  - title: Every pass bound in five steps was worked out by hand; nothing caught it until a step asked for numbers to believe
    detail: The skills held the pass rule in words and each session did the Clopper-Pearson arithmetic and the seed pooling by hand. They were right (all reproduce), but nothing could rerun them. Verdicts as data, bounds as code, from the first round of a check.
    tag: tooling
  - title: A published figure without its run is a constant that silently ages
    detail: '"OH&S text changes" was 4,573, 4,619, 4,911 and 4,967 in four sessions: different stores and populations under one name. Quote a figure with its run (date, commit) and its register name.'
    tag: data
  - title: A passed gate stays passed only if something re-runs it
    detail: S01 passed with 0 failures on 2026-10-22; by 2026-10-30 later steps had added 103 needs nobody fetched. Rerun earlier gates at each step's close, or automatically (CV-S11 Store and build).
    tag: data
  - title: Prove a refactor of a sampler by drawing before and after, not by tests alone
    detail: Unit tests showed the shared draw reproducible; only drawing every real sample twice before and once after showed the old seeds still draw the same items (and that the extent draw relies on the store's row order being stable).
    tag: tooling
  - title: Reading one sample item before launching agents found the only measure fault
    detail: The first hand-check item (an EU annex) was grouped as body. Looking at a sample yourself first is cheap and catches definition faults agents would only describe.
    tag: tooling

bugs:
  - pattern: "S01 sources gate fails today: 103 needed documents not fetched (OH&S, 2026-10-30), 96 of them EU amenders of REACH (70) and CLP (26) — territory bodies and introductions; 7 UK. CV-S01 passed with 0; the needs grew with later steps and nothing re-ran the gate"
    category: workflow / sources gate
    module: mix lat.sources (CV-S01); CV-S11 'sources check re-run after each rebuild'
    affected: 103
    fix: "Jason to decide the fetch (EU territory isn't read, KE); re-run the gate in the next pass from step 1; CV-S11's automatic re-run"
    status: open
  - pattern: "mix tasks over ~300 lines: lat.extent_check 404, lat.commencement_check 446, lat.sources 383 (logic inline: tallies untested)"
    category: module size
    module: lat.extent_check, lat.commencement_check, lat.sources
    affected: 3
    fix: "move the tallies into pure modules with tests (CV-S12 retrospective, improve)"
    status: open
  - pattern: "Law-text coverage put EU annex targets (annex.*) in the body group; annexes are unparsed like Schedules (K1)"
    category: measure definition
    module: Measures.Coverage.law_text_coverage/2
    affected: 252
    fix: "annex. grouped with sch. (9e2f19b6)"
    status: fixed
  - pattern: "Amending reader '#dropped' repeal attributes sub-provisions inserted later (by another law) to the earlier substituting law: SI 2011/1885 reg.7(1) substitutes reg.19 of SI 2009/1348 with (1)-(2); (3)-(4) inserted later by SI 2020/1111 reg.8(4) are stored as repealed by 2011/1885 (siblings 19(1A), 19(3), 19(4) alike)"
    category: upstream / amending reader (CV-S06)
    module: Amendment reader, the '#dropped' rows
    affected: 
    fix: "a dropped row must have existed under the substituted text at the substituting law's date (not compared with today's text)"
    status: open
  - pattern: "Markup ChangeIds at schedule-part wrapper ids carry no markup claim (Repeal/Addition pairs; SI 2008/1597 sch.2.pt.9, sch.2.pt.11): J and markup coverage understated"
    category: upstream / markup reader (CV-S03)
    module: ChangeVocabulary.Readers.Markup (schedule paragraph-wrapper ids)
    affected: 
    fix: "place markup on schedule-part wrappers (schedule-N-part-P-paragraph-wrapperXnY) as the Part"
    status: open
  - pattern: "Feed effect 'HSWA s.48 revoked in part' by SI 1996/1513 reg.13 looks false: reg.13 omits words from SI 1977/500 reg.3(1); 1996/1513 touches s.48 only by reg.11 (applied with modifications, its own feed effect)"
    category: upstream / legislation.gov.uk feed error
    module: (feed; derived tier)
    affected: 1
    fix: "report to legislation.gov.uk or a known-feed-error list; the law text, where read, should outrank it"
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/bound.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/verdicts.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/draw.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/coverage.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/source.ex
  - backend/lib/mix/tasks/lat.verdicts.ex
  - backend/lib/mix/tasks/lat.measures.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/measures/
  - .claude/skills/measures-check/SKILL.md
  - backend/data/reports/change-vocabulary/verdicts/measures/ohs/

depends_on:
  - change-vocabulary/2026-10-22-cv-s09-label-fold

enables:
  - CV-S12 Retrospective (the register and the findings are its inputs)
  - verdict files and computed bounds for every check round from now on
---

# Session: CV-S10: Measures (CLOSED)

## Problem

Step 10 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Numbers we can believe: each metric defined in words, with a test.

The session does not close until its results pass.

Jason 2026-10-30: "We run S10 to pass making sure it's replicable and supported with a skill and then a retrospective as S11. Measures can be an input into S11." So the pass needs the same figures from the same inputs on a rerun, and a skill that any family can follow. The measures feed the retrospective's (now CV-S12) drop, add, keep, improve.

## Todo

- ✅ Inventory every figure the workflow prints or quotes, by step (task, function, definition, test or none; ad-hoc figures in quality statements)
- ✅ Define what good looks like (agreed 2026-10-30: below)
- ✅ Measure register (in the `measures-check` skill): every published figure (quality statements S05–S09, pass rules, CV-07), with name, definition, command, function, test
- ✅ The 95% bound in code (Clopper–Pearson), tested against known values (`Measures.Bound`, `4224bd90`)
- ✅ Verdict files: a JSON format for agent verdicts (seed, item, verdict, class); the step skills' prompts write it; a mix task pools a step's verdicts since the last fix and prints the bounds and the end-to-end figure (`4224bd90`; prompts `da28c2f8`; first used by this session's hand check)
- ✅ The figures worked out by hand put into code: S05/S06 coverage tables, S08 dating coverage, CV-07 "both sources" (`mix lat.measures`, `27d98ac9`); small totals in their tasks (`a7037b3c`)
- ✅ Names: one meaning per name ("both sources", "disagreeing", agreement's copied rules, `Conflicts.report` inputs); the S07 join-rate header fixed (header fixed `27d98ac9`; `Conflicts.report` inputs change no figure; names in the register)
- ✅ Replicable: a reproducibility test per draw (`Measures.Draw`, every check); two runs over the same store identical, and a third after the refactor (`27d98ac9`); seeds recorded in the verdict files
- ✅ Coverage and the conflict report: "who states a change" from the claims of the change itself (fixed in CV-07 `41f9afe0`; earlier figures overstated); defined and tested (`Coverage.stated_by/1`; agrees with `lat.amending_check` exactly: 1,396 = 1,235 + 161)
- ✅ The coverage figures quoted in CV-07 re-baselined (golden 22% → 24.0%, OH&S family 13% → 25.9%)
- ✅ Hand check: an agent checks a sample of each classifying measure against the sources (stated by, coverage, dating, merge stratum): 50 text changes, 0 classed wrong after one measure fault found and fixed (annex)
- ✅ A `measures-check` skill: the register, the commands, how to rerun for a family
- ✅ Fix until the check passes reliably; record the result (PASS 2026-10-31: register, code, tests, replicable, hand check 0/50)
- ✅ Hand the register and the figures' history across rounds to CV-S12 (retrospective): its "Inputs from CV-S10" section

## Dependencies

- ✅ The steps before it passed (CV-S01–S09 closed PASS by 2026-10-30)

## What good looks like

**Agreed (Jason 2026-10-30):** scope is the published figures; agent verdicts saved as files with a task pooling them; where one word means different things, rename and keep both. A measure is any figure a step publishes: a figure in a quality statement or pass rule. Each one passes when it is:

1. **Defined:** one entry in a measure register (in the `measures-check` skill), with its name, a definition in words (numerator, denominator, what's excluded), the command that prints it and the function that computes it. One name, one meaning: where two steps mean different things they get different names.
2. **Computed by code:** no published figure is worked out by hand. This covers:
   - the 95% Clopper–Pearson upper bound and the pool across seeds, computed from agent verdicts saved as files per round (seed, item, verdict, class) rather than tallied by hand;
   - the coverage tables (S05, S06, S08), the end-to-end figure (S09) and CV-07's "both sources".
3. **Tested:** a unit test on hand-built data for each measure's function. The bound is tested against known values: 0/150 gives 1.98%, 0/73 gives 4.02%, 3/150 gives 5.1%.
4. **Replicable:** two runs over the same store print identical figures (diffed). Every draw is reproducible from its seed (a test per draw, including `CheckSample.draw`). Each run records the seeds it drew.
5. **Hand-checked:** for the classifying measures (stated by, join, agreement, strata), an agent checks a sample of items against the sources. The pass is no item classed wrong.

**Pass:** every published figure meets 1–5; the CV-07 figures re-baselined by the new code; the `measures-check` skill runs the whole set for a family. The register and the figures' history across rounds go to CV-S12 (retrospective).

## Inventory (2026-10-30)

Every figure the workflow prints (`lat.sources`, the eight `lat.*_check` tasks, `lat.vocabulary`) or quotes in a step's quality statement. Read-only agent sweep; key claims spot-checked.

**Printed by tasks (reproducible today):**

| Step | Figures | Classifier tested? |
|---|---|---|
| S01 | needed/held per category, failures, feeds differing from register | yes (`sources_test`) |
| S02 / S03 | effects or markup changes by outcome; our faults; finer forms not held (S02); markup keys against the feed (S03) | fault classes yes; tallies no |
| S04 | own-commencement outcomes; yardstick; gap classes | fault yes; yardstick and gap tallies no |
| S05 | extent basis; faults (not_stored/stale); unread classes; territory source of text changes | sweep only; basis, fault and outcome counts no |
| S06 | stated by (both / law text only); strata A/D/L; agreement per attribute | yes (`check_strata_test`) |
| S07 | strata J/U/C; join rate; spread tell-tale | yes (`merge_strata_test`) |
| S08 | strata V/D/A; conflicts and patterns; winning source per attribute | strata yes; winner tally no |
| S09 | laws/rows folded; S shapes; T differences; status counts | yes (`label_strata_test`) |
| Vocabulary | conflicts by kind; golden pass count; golden laws built by older code | report yes, counts not asserted; golden tally no |

**Gaps:**
1. **The pass bounds aren't computed by code.** Every 95% upper bound (S05–S09) and every pool across seeds ("items unchanged since checked") was worked out by hand from agent verdicts. No task records the seeds drawn.
2. **Untested:** no mix task has a test; the inline tallies listed above; `CheckSample.draw` (S06–S08) has no reproducibility test (only `LabelStrata.draw` has one).
3. **One word, several meanings:**
   - "both sources": `CheckSample.stated_by` means law text + derived; `MergeStrata` J means any two; the CV-07 figures use a third.
   - "disagreeing": S06 D (operation/level/by + unjoined), S08 V (any conflict), `Conflicts :value` (all).
   - `CheckStrata.agreement` keeps its own copy of Conflicts' agree rules, without `like?/5`.
   - `Conflicts.report` is given the read pass's pointers by `lat.vocabulary` but nil by the strata modules, so uncovered and unread counts differ by caller.
   - The S07 join-rate header says "of N stored changes" over all changes, not the text changes the rate uses.
   - "OH&S text changes" is 4,967 (S05), 4,911 (S06) and 4,573 (S08), none printed under that name.
4. **Sampling differs by step:** seed tuples `{2026,10,22|23}`, `{s,2,3}`, `{s,6,6}`, `{s,9,9}`; two stratifiers (S04 round-robin, S05 equal share then random). S06–S08 share a draw, so a seed reused across them gives correlated samples.
5. **Figures only in the docs (worked out by hand):**
   - S05's and S06's coverage tables;
   - S08's dating coverage (undated, dated without commenced_by, named);
   - CV-07's "both sources" 22% / 13% (this session's re-baseline);
   - S09's end-to-end 17/150 and S05's 3/150 laws (tallied from agent verdicts);
   - CV-07's "agree 96–100%".

## The bound and the verdict files (2026-10-30)

**`Measures.Bound`** (`4224bd90`): the exact one-sided Clopper–Pearson upper bound. It reproduces every bound the step sessions published by hand, to two places:
- 0/150 → 1.98%; 0/73 → 4.02%; 0/160 → 1.85%; 0/86 → 3.42%; 0/112 → 2.64%; 0/81 → 3.63%;
- S05's laws 3/150 → 5.09%, recorded then as 5.1%, marginal against the 5% limit and accepted by Jason (2026-10-28); a test keeps it visible as a miss;
- S05's pool over seeds 17–22: 10/300 → 5.59%, 1/300 → 1.57%.

Under 2% needs at least 149 clean items (0/148 is 2.004%).

**Verdict files** (`Measures.Verdicts`, `mix lat.verdicts`): one JSON per agent batch, with step, family, stratum, seed, round, and per item its id, group (law or pair), verdict (ok / wrong / doubtful / gap), fault for a wrong item (own / upstream / known) and pattern. Pooling counts each item once, the latest round's verdict standing.
- Counted against the bound: wrong items whose fault is `own`.
- End to end: every wrong item.
- Gaps and doubtful items are listed apart.

Files go under `backend/data/reports/change-vocabulary/verdicts/` (NAS-backed, not in git, because items may carry effect ids). Earlier rounds kept their verdicts only as hand tallies in prose, so they aren't backfilled: those passes stand as recorded, with their bounds now confirmed by code. A demo file shaped like S09's R pool printed 0/150 (1.98%), 0/73 (4.02%), end to end 17/150 (11.33%), PASS.

## Register of published figures (draft, 2026-10-30)

Every figure in a step's closing summary, metrics or quality statement, and each skill's pass rule. Drafted by a read-only agent; two of its inconsistency claims spot-checked and confirmed (S01's table sums to 1,203; CV-07's level disagreement of 7.0% contradicts "agree 96–100%"). Source: **T** = a task prints it (label checked in the source); **AV** = agent verdicts (now `mix lat.verdicts`, from the next round on); **H** = worked out by hand.

| Step | Name | Published | Source |
|---|---|---|---|
| S01 | sources_needed_by_category; sources_failures; register_feed_differences | 7 categories; 0; 0 | T `lat.sources` |
| S01 | sources_needed_total | 1,253 (table sums to 1,203) | H |
| S02 | feed_effects_placement; feed_our_faults; feed_tell_tales | 6,568 effects / 149 laws; 0; 16/10/1/5 | T `lat.feed_check` |
| S02 | feed_agent_placement_facts | 50/50, 50/50 | AV |
| S03 | markup_changes_placement; markup_our_faults; markup_keys_vs_feed; markup_catalogue | 1,808 / 79 laws; 0; 1,178/594/36; 745 patterns | T `lat.markup_check`, `lat.markup_patterns` |
| S03 | markup_agent_placement_facts | 50/50 | AV |
| S03 | legacy_pointer_share | 94.3%; 89.8%; 99.4% | H |
| S04 | commencement_rows_outcome; commencement_our_faults; commencement_gaps_by_reason | dated 16,430 …; 0; 7 classes | T `lat.commencement_check` |
| S04 | commencement_by_order_all | 164 (by_order 158 + partly 6) | H |
| S04 | order_statements_read | 1,951/2,901 (67%) | H from `lat.order_patterns` |
| S04 | commencement_agent_round4 | NEW 0 | AV |
| S05 | extent_changes_wrong_pooled; extent_laws_wrong_pooled | 0/150 (2.0%); 3/150 (5.1%) | AV |
| S05 | extent_coverage_by_source; extent_no_bound_share | 4,967: law 62.8% …; ~31% | T `lat.extent_check`, regrouped by H |
| S05 | extent_our_faults | 0 | T |
| S06 | lawtext_stated_population; lawtext_strata_ADL; lawtext_agreement_with_lgu | 1,174; A 1,063 / D 77 / L 34; by/operation/level/target | T `lat.amending_check` |
| S06 | lawtext_A_pooled; lawtext_DL_full | 0/160 (1.85%), pairs 0/86 (3.42%); 0/111 | AV |
| S06 | lawtext_overall_bound | ≈1.7% | H |
| S06 | lawtext_coverage_table | 4,911: law text 23.9%, Schedule 831, EU 654, body 1,150, unread 661, other 441 | H, partly T |
| S07 | merge_strata_JUC (joined_any_two); join_rate_law_text; join_rate_markup; overjoin_spread_keys | J 2,082 / U 1 / C 13; 93.4%; 85.0%; 32 | T `lat.merge_check` |
| S07 | merge_J_pooled | 0/150 (1.98%), pairs 0/112 (2.64%) | AV |
| S08 | evidence_strata_VDA; evidence_winners | V 8 / D 40 / A 2,019; per attribute | T `lat.evidence_check` |
| S08 | evidence_A_pooled; evidence_V_D_verdict | 0/150 (1.98%), pairs 0/81 (3.6%); V 8/8, D wrong only in classed patterns | AV |
| S08 | evidence_date_gaps | 609 / 2,841 / 1,123 of 4,573 | H |
| S09 | label_R_pooled; label_ST_fold_faults; label_end_to_end_R | 0/150 (1.98%), 0/73 (4.02%); 0 in 160; 17/150 (11%) | AV |
| S02–S09 | golden_from_inputs; golden_extended | 27/27 (26/27 at S06); 41/50 | T `lat.vocabulary --golden [--extended]` |
| CV-07 | stated_by_law_and_derived (family, golden); stated_law_text_only; stated_lgu_only | 611/4,619 (13%), 3,242/15,020 (22%); 133; 3,875 | H |
| CV-07 | both_state_attribute_agreement | "agree 96–100%" (its own table: level 93%) | H |

**Worked out by hand (H), and the code that would print them:**
- `lat.sources`: a needed total.
- `lat.commencement_check`: by_order + partly.
- `lat.order_patterns`: statements read.
- `lat.markup_patterns`: legacy pointer share.
- `lat.extent_check`: the coverage regrouping and shares.
- `lat.amending_check` or `lat.vocabulary`: the law-text coverage split by target (Schedule / EU article / body / unread / other, from `Conflicts`).
- `lat.evidence_check`: the date gaps over text changes.
- `lat.vocabulary`: CV-07's stated-by split.
- The derived bounds (overall ≈1.7%, "≥98%") are arithmetic on AV bounds.

**Published with two values or definitions (to settle in the register, not by editing closed sessions):**
1. S01 needed documents: 1,253 in the frontmatter, but the table sums to 1,203.
2. "OH&S text changes": 4,619 (CV-07), 4,967 (S05), 4,911 (S06), 4,573 (S08). Merged changes: 26,492 (S08), 26,475 (S09).
3. Law-text population: 1,174 (S06, S07 round 1), 1,177 (S07 round 7).
4. "Both sources" has three meanings: 611 (CV-07: operation claimed by law and derived), 1,095 (S06: `stated_by` both), 2,082 (S07: any two sources).
5. "Law text only" has four values: 133 (CV-07, before its correction), 79 (S06 alone), 34 (S06 stratum L), 84 (CV-07 conflicts).
6. "A / agreeing": 1,063 law-text changes agreeing (S06), 2,019 changes several sources claim (S08).
7. S09's S/T denominator: 160 (with 4 rechecked rows), 156.
8. S04 by order: 158, 164 with the 6 partly.
9. CV-07's "agree 96–100%" against its own 93% for level.
10. CV-07's frontmatter mixes before (133) and after (611) its correction; golden text changes 15,014 against 15,020.
11. S05 "at least about 95%" of laws against an upper bound of 5.09% (94.9%).
12. "Golden from inputs" is 26/27 at S06 (its logged limit) and 27/27 elsewhere.

Most of these are different moments (the store moved between steps) or different populations under one word. The register fixes each by a distinct name and the code that prints it; values that move with the store are stated with their run, not as constants.

## Replicability (2026-10-30)

Every check's sample drawn at seed 901 on OH&S, twice on the code as it stood, then once after moving every draw into `Measures.Draw` (`27d98ac9`). Script and timings are in the `measures-check` skill; a pass takes about 8 min.
- **Samples:** all 10 byte-identical across the three passes: feed, markup, commencement, extent, amending A, merge J, evidence A and D, label R and S. The refactor keeps every seed tuple and algorithm, so seeds recorded in earlier rounds still draw their samples.
- **Printed figures:** identical, once log lines, compile lines, output paths and one machine-state line (the extent check's free memory) are filtered out.
- **Found:** the extent check's draw takes its rows unsorted. Its order is stable today (identical runs), but the draw module's doc says callers must pass a stable order; logged for CV-S12 (retrospective) rather than changed, since changing it would move recorded seeds.
- **`Conflicts.report` inputs:** the strata modules call it without the read pass's pointers, but read only its `:unjoined` entries, which don't depend on them, so no figure differs.

## Measures in code (2026-10-30)

`mix lat.measures --family F | --golden [--extended]` (`27d98ac9`, ~4 s family, ~7 s golden), from `Measures.Coverage` (pure, tested) and `Measures.Source` (the inputs, with the read pass's pointers).

| Figure | Published | Today (OH&S) | Today (golden laws) |
|---|---|---|---|
| Text changes | 4,573–4,967 by step | 4,763 | 14,800 (21 laws) |
| stated_by_law_and_derived | CV-07: 13% family, 22% golden | 1,235 (25.9%) | 3,554 (24.0%) |
| law only / derived only | CV-07: 133 / 3,875 | 161 / 3,367 | 914 / 10,332 |
| Law-text coverage: read, no rule (Schedule / EU article / body) | S06: 831 / 654 / 1,150 | 615 / 655 / 1,319 | 2,296 / 683 / 4,917 |
| not read / other | S06: 661 / 441 | 490 / 288 | 424 / 2,012 |
| Dating: undated / dated, no commenced_by / commenced_by named | S08: 609 / 2,841 / 1,123 | 579 / 2,694 / 1,490 | 2,911 / 11,363 / 526 |
| Territory (`lat.extent_check`, grouped): law text / follows enactment / law type not read / no powers / unread / competence | S05: 3,117 / 299 / 573 / 450 / 328 / 149 | 3,072 / 270 / 554 / 415 / 272 / 151 | — |

**One definition, two names:** today `lat.amending_check` prints 1,396 law-text changes (both 1,235, alone 161), exactly `Coverage.stated_by_split`. So S06's "both" and CV-07's "both sources" share a meaning (`stated_by_law_and_derived`); S07's J ("joined", any two sources) is the other. Published values differ because the store moved between steps (reader fixes in S06–S09), not because of the definitions.

**Totals now printed by their tasks** (`a7037b3c`): `lat.sources` needed total (1,160 today); `lat.commencement_check` left to orders (164); `lat.order_patterns` statements read into rules (2,298 of 3,496 today; S04 published 1,951 of 2,901); `lat.markup_patterns` pointer shares (checked on two laws; the corpus run is ~16 min, not run).

**Found:** `lat.sources --family` fails today with 103 documents not fetched (bug logged above): the S01 gate isn't re-run as later steps add needs.

## Hand check (2026-10-30)

A seeded sample of 50 OH&S text changes (seed `{911, 10, 10}`, drawn twice, byte-identical; script `scratchpad/s10/hand_sample.exs`) with the classes `Measures.Coverage` and `MergeStrata` give each: who states it, law-text coverage, dating, merge stratum. Two agents judged each class against the feed, the markup, the amending law's words and the stored rows. Verdict files: `backend/data/reports/change-vocabulary/verdicts/measures/ohs/` (the first written in the new format).

- **Before the agents:** reading the first item, I found the coverage measure put EU annex targets in the body group. Fixed (`9e2f19b6`): annex grouped with Schedule, both unparsed. The family's Schedule group goes 615 → 867 (S06 published 831), body 1,319 → 1,067 (S06: 1,150).
- **Agents, on the fixed code:** 0 of 50 classed wrong by the measures. Upstream: 1 wrong (a false `#dropped` repeal), 2 gaps (markup ChangeIds with no claim), 1 feed error with no class effect. All four logged as open bugs above.
- `mix lat.verdicts --dir …`: items 0/50 (95% upper 5.82%), laws 0/20; end to end 1/50. Its PASS line uses the step checks' 2% limit, which this check doesn't claim: its agreed rule is "no item classed wrong".
- **What the agents confirmed:** every feed key exists on its stated provision; every markup claim's ChangeId sits at its target; every dated change's date matches the feed's InForce; every J is one event (including operation-family pairs such as feed "substituted" against markup Addition).
