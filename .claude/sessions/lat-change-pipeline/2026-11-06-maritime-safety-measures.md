---
session: 'Maritime Safety: Measures'
status: closed
opened: '2026-11-06'
closed: '2026-11-06'
outcome: success
family: '💙 TRANSPORT: Maritime Safety'
parent: lat-change-pipeline/2026-11-04-maritime-safety-meta.md

summary: >
  Every figure the Maritime Safety steps published was checked against today's store. The checks of every step,
  gates included, were run twice at seed 902 and replicate. One agent pass hand-checked 60 classified items and found
  three faults in the measures themselves, fixed by TDD (4229a5f3). The audit found three gates that had passed and
  now fail after later rebuilds, and one hand-summed figure that was wrong; the gates are parked with their steps.

decisions:
  - what: Pass rule — OH&S's (register, code, tests, replicable, hand check) fitted to one agent pass; scope is the data figures in the closing metrics
    why: the 2026-11-05 rule (one agent pass, never sample → fix → resample); before/after history can't be re-printed
    result: an audit table of 22 figure kinds, every one same, moved with its commit named, or a finding
  - what: draws.sh runs every check with its strata, gate and sample, and takes FAMILY and SEED
    why: a gate passed at its step's close is not re-run by anything after a later rebuild (the OH&S S01 lesson)
    result: one 14-minute pass re-runs all ten checks; three failing gates found
  - what: The territory group checked on 10 items from the extent check's own sample, not on the hand items
    why: the group needs the extent check's full run (amending-law reads); lat.measures can't compute it per change
    result: 10/10 once no_clause was named
  - what: A gate that fails today is parked with its step, never named here
    why: the gate files belong to their steps (plan, out of scope)
    result: Sources (11 to fetch), Extent (4 causes), Amending (1 group) parked

metrics:
  audit: { figure_kinds: 22, same: 15, moved_explained: 2, gates_failing_now: 3, hand_summed_wrong: 1, names_clarified: 2 }
  replicability: { checks: 12, passes: 2, samples_identical: 11, printed_identical_after_filter: 12, hand_sample_byte_stable_after_fix: true, pass_minutes: 14 }
  hand_check: { items: 60, seed: 902, own_faults: 3, fixed: 3, upstream_wrong: 7, by_definition: 1, tokens: 288287 }
  maritime_coverage_after: { text_changes: 3150, law_and_derived: 1439, law_only: 170, read_no_rule_schedule: 174, read_no_rule_eu_article: 273, read_no_rule_body: 787, not_read: 287, other: 20 }
  maritime_dating: { undated: 49, dated_no_commenced_by: 2142, commenced_by_named: 959 }
  ohs_coverage_moved: { read_no_rule_schedule: "867 → 869", read_no_rule_body: "898 → 917", not_read: "454 → 433" }
  verdict_files_recovered: { markup: 1, evidence: 1, label: 3, none_saved: 4 }
  regression: { golden: "27/27", mix_test: 10172 }

lessons:
  - title: Three gates that passed failed eight steps later, and only re-running them showed it
    detail: Sources (0 → 11 not fetched), Extent (0 → 4 causes) and Amending (0 → 1 group) passed at their close; the Amending-law reader's read pass and Merge's rebuild moved them. The OH&S lesson of 2026-10-30 recurred because nothing automatic re-runs gates; draws.sh now does, and Store and build owns making the build's check do it.
    tag: data
  - title: A figure summed by hand from printed groups was wrong by 30
    detail: Evidence published commenced_by gaps 2,221; the code's own groups that day sum to 2,191. Any total a session quotes must be a printed line, not arithmetic on one.
    tag: data
  - title: '"Read" meant "pointed to", not "held and read"'
    detail: The coverage measure's read set was the index's pointers. 12% of them name provisions whose text isn't stored (Schedules fetched body-only), so "read, no rule" held changes never read. The agents found it on 3 of 25 items; a batch-2 agent passed two more of the same, so one agent's OK is not proof.
    tag: data
  - title: An atom-keyed map is not byte-stable JSON across builds
    detail: The hand sample was equal as JSON but not byte-identical across two builds; Jason encodes small atom-keyed maps in atom-table order. String keys fix it; samples meant to replicate encode string keys.
    tag: tooling
  - title: Save VERDICTS when the agent hands back
    detail: No Maritime agent pass saved its verdict file; five blocks were recovered from the agents' hand-back messages, four passes are hand tallies only. The skill now says to save in the same step.
    tag: tooling

bugs:
  - pattern: "The Sources gate fails today for Maritime Safety: 11 needed documents not fetched (10 backlog Schedules, e.g. UK_uksi_1998_929 for UK_uksi_1975_2220; 1 territory body, UK_ukpga_1992_52 for UK_ukpga_1970_36). It passed with 0 on 2026-11-04; later steps' reads added the needs (682 → 673 needed, 11 not held)"
    category: sources-gate-not-rerun
    module: mix lat.sources (--fetch, ask Jason)
    affected: 11
    fix: "Fetched (Jason 2026-11-06): 9, then the 2 that had returned HTTP 500 on a retry; 10 are absent (legislation.gov.uk has no Schedules for them). Gate PASS, 0 failures"
    step: Sources
    status: fixed
  - pattern: "The extent gate fails today: 4 no-bound causes not named (7 text changes), new since the step passed (9a9d0e26) — the Amending-law reader's read pass moved the store (e.g. UK_ukpga_2009_25 unread_statement ×3; UK_uksi_2006_2190 same_or_not_named ×2 and UK_ukpga_1992_52 law_no_clause ×1 rest on documents not fetched)"
    category: extent-gate-not-rerun
    module: test/fixtures/extent_patterns/withheld.json
    affected: 7
    fix: "After the fetch (2026-11-06): UK_ukpga_1992_52's body is held, so its stored extent_rules are stale (our faults 1) and its cause reads unread_statement; re-read its extent (mix lat.amending --extents, a store write), then name the 4 causes in withheld.json"
    step: Extent reader
    status: open
  - pattern: "The amending gate fails today: 1 group not named — MSA 1995 s.173(7)(a)(i), inserted by SI 2006/1265 (no operation from legislation.gov.uk: inserted provision), appeared with Merge's rebuild (93599e6d) after the step passed (f18affb2)"
    category: amending-gate-not-rerun
    module: test/fixtures/amendment_patterns/disagreements.json
    affected: 1
    fix: "Name the group in disagreements.json"
    step: Amending-law reader
    status: open
  - pattern: "A rebuild after a step closes moves the earlier steps' gates and nothing re-runs them: three Maritime gates passed and fail today (Sources 11, Extent 4 causes, Amending 1 group); the OH&S lesson of 2026-10-30 (S01) recurs"
    category: gates-not-rerun-after-rebuild
    module: mix lat.vocabulary --check (re-runs only the sources gate)
    affected: 3
    fix: "The build's check re-runs every step's gate (feed, markup, commencement, extent, amending, merge, evidence, label) and fails on any; Measures' draws.sh does so meanwhile"
    step: Store and build
    status: open
  - pattern: "measures/*.ex is in ChangeVocabulary.Version's globs, though no build reads the measures: a new measures module (Measures.HandSample) marks every built law stale (the class of the parked label-in-build-version)"
    category: measures-in-build-version
    module: ChangeVocabulary.Version (patterns)
    affected: all built laws
    fix: "Drop measures/*.ex from the patterns if VersionCoverageTest agrees nothing in the build reaches it"
    step: Store and build
    status: open
  - pattern: "The family scope query is copied in four check tasks (commencement_check, extent_check, sources, vocabulary)"
    category: duplicated-scope-query
    module: lat.* check tasks
    affected: 6 (feed_check and markup_check held it too)
    fix: "One call, Measures.Source.family_laws/1"
    step: Measures
    status: fixed
  - pattern: "The Evidence step's published gap totals (commenced_by 2,221, no rules 1,478, date 50) were summed by hand from the printed groups, and wrong: the code's groups sum to 2,191 / 1,477 / 49"
    category: hand-summed-figure
    module: lat.evidence_check (gaps)
    affected: 3
    fix: "Gate.Evidence.gap_totals/1 printed by lat.evidence_check"
    step: Measures
    status: fixed
  - pattern: "A purpose-limited commencement date is taken as the change's whole start: SI 2006/1244 reg.1(4) brings MSA 1995's amendments in on 2006-07-15 only so far as needed for s.164(1A) certificates; their general start is reg.1(2), the Bunkers Convention's entry into force, 2008-11-21 (the feed's date). E.g. MSA 1995 s.152(2), s.165(1), s.170(1) (the hand check, items 14, 31, 37, 39)"
    category: purpose-limited-start-taken-whole
    module: commencement/ (Commencement.Amending, the amending law's own clause)
    affected: 93
    fix: "Read a 'so far as necessary for' start as partial (in_force_partial), the general clause as the full start"
    step: Commencement reader
    status: open
  - pattern: "One event split across two changes where legislation.gov.uk's markup ChangeId differs from the feed's EffectId: SI 1993/3138 reg.28, 1999/3206 reg.4(e) adds 'or (iii)' (markup key at reg.28; feed key, with law text, at reg.28(1)(b)(iii)); the merge strata's candidate test pairs only two lone one-source changes, so it doesn't flag this one"
    category: markup-feed-ids-split
    module: merge (Merge, MergeStrata candidates)
    affected: 1 (hand check item 50; reach unknown)
    fix: "Count lone markup changes beside a two-source twin on the same provision or one above, by the same law"
    step: Merge
    status: open
  - pattern: "Law-text coverage counted a pointer as read when the amending law's text holding it isn't stored (a Schedule fetched body-only): 'read, no rule' held changes never read (e.g. MSA 1991 c.52 s.41(3), FA 1995 Sch.29); and an order's 'art.' pointer missed the feed's 'reg.' name (MSA 1995 Sch.5 para.4(c))"
    category: read-set-not-held
    module: Measures.Source.pointers/1
    affected: 150 Maritime text changes moved; OH&S 21
    fix: "Measures.Source.read_pointers/2: a pointer is read where its provision, or one containing it, is in the text; art. read as reg. too"
    step: Measures
    status: fixed
  - pattern: "The territory table put 'an Act with no extent clause' (none:law_no_clause) in other"
    category: territory-group-unnamed
    module: Measures.Coverage.territory_groups/1
    affected: 13 Maritime text changes; OH&S 4
    fix: "Its own group, no_clause; the group list moved to Coverage (Extent.Check.groups/0 reads it)"
    step: Measures
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/hand_sample.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/source.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/coverage.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/evidence.ex
  - backend/data/reports/measures/maritime-audit.md
  - backend/data/reports/measures/maritime-hand-b1-report.md
  - backend/data/reports/measures/maritime-hand-b2-report.md
  - backend/data/reports/change-vocabulary/verdicts/{markup,evidence,label,measures}/maritime-safety/
  - .claude/skills/measures-check/SKILL.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-06-maritime-safety-label-fold.md

enables:
  - "Maritime Safety: Store and build (parked: gates re-run by the build's check; measures/*.ex in the version)"
---

# Session: Maritime Safety: Measures (CLOSED)

## Problem

Step 10 of the LAT Change Pipeline for TRANSPORT: Maritime Safety. Every figure the family's steps publish must be believable: one name and one meaning, printed by tested code, replicable. Since OH&S's Measures (2026-10-30), six steps added code gates whose figures aren't in the register, the agent passes saved no verdict files, and the hand-check sample was drawn by a scratchpad script. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-06).

## Todo

- ✅ Open the session; draws pass 1 at seed 902 (Maritime) and OH&S `lat.measures` as the baseline
- ✅ Audit: every in-scope figure in the Maritime closing metrics against the register, task, code, test; today's value against the published
- ✅ Shared scope (TDD): six tasks call `Measures.Source.family_laws/1`; parked bug marked fixed
- ✅ Hand sample (TDD): `lat.measures --sample`, its draw test, the territory group per item; drawn twice, `cmp`; first item read by me
- ✅ One hand-check agent pass (2 × 25), VERDICTS saved; measure faults fixed by TDD, upstream parked
- ✅ Verdict files: the 5 held VERDICTS blocks recovered and pooled; the rest marked "hand tally, report only"
- ✅ Verify: draws pass 2 against pass 1; OH&S `lat.measures` unchanged; golden 27/27; `mix test`
- ✅ Docs and close: register, `draws.sh` (family, seed), history, WORKFLOW.md step 10, meta row

## Dependencies

- ✅ Label fold closed and pushed (0f63c4f0)
- ✅ OH&S Measures (`archive/change-vocabulary/2026-10-22-cv-s10-measures.md`): the register, `lat.verdicts`, `lat.measures`, `Measures.Draw`

## Decision 1: the pass rule — DECIDED (plan approved, Jason 2026-11-06)

OH&S's rule (2026-10-30), fitted to the one-agent-pass process:

1. **Register complete:** every data figure in the Maritime closing `metrics:` (today's store; not before/after history whose run is gone, not days/commits/tokens) has a register entry, a printing task and a test, or is marked "hand tally, report only".
2. **Replicable:** two draws passes at seed 902 give byte-identical samples and identical printed figures (gates included).
3. **Hand check:** one agent pass over 50 Maritime text changes; no item classed wrong by a measure.
4. **No regression:** `mix test`; golden 27/27; OH&S `lat.measures` unchanged unless a measure fix explains it.

## Parking list

- Sources: sources-gate-not-rerun — 11 documents not fetched since the step passed (fetch: ask Jason)
- Extent reader: extent-gate-not-rerun — 4 causes to name in withheld.json (2 wait on the fetch)
- Amending-law reader: amending-gate-not-rerun — 1 group to name (MSA 1995 s.173(7)(a)(i))
- Store and build: gates-not-rerun-after-rebuild — the build's check re-runs every gate
- Store and build: measures-in-build-version — measures/*.ex in the Version globs
- Commencement reader: purpose-limited-start-taken-whole — SI 2006/1244 reg.1(4)'s date on 93 MSA 1995 changes
- Merge: markup-feed-ids-split — one event as two changes when the markup and feed ids differ (1 seen)

## Draws pass 1 (before any code change)

Seed 902, `draws.sh` with family and seed (scratchpad `measures/p1/`; times: label 738 s, every other check 4–49 s; Making laws and Sources added to the script, both read-only). OH&S `lat.measures` baseline: 5,081 text changes.

## Audit (report `backend/data/reports/measures/maritime-audit.md`)

Every published Maritime figure against today's store:
- **Same:** Making laws, Feed reader, Markup reader, commencement rows, amending strata and agreement, Merge, Evidence strata, label strata and statuses, and the commencement, merge, evidence and label gates.
- **Moved, explained by a later commit:**
  - commencement gaps 1,215 → 1,151 (the read pass f18affb2, Merge's rebuild 93599e6d);
  - extent text changes 3,154 → 3,150 (the read pass).
- **Three gates that passed fail today** (raised and parked by owner):
  - Sources: 11 not fetched;
  - Extent: 4 causes not named;
  - Amending: 1 group not named.

  Nothing re-ran them after the later rebuilds (raised against Store and build).
- **Hand-summed and wrong:** Evidence's gap totals (2,221 / 1,478 / 50; the code's groups give 2,191 / 1,477 / 49). Now printed by code (`Gate.Evidence.gap_totals/1`, tested).
- **Names:**
  - "bound by the law's text" (2,923) is the `bound:law` outcome, not the law_text group, which adds `territory:law`;
  - the label gate's published "7 groups" counted `labels.json`'s entries, including the `legacy_unconfirmed` class listed apart; the gate's groups are 6.

## Shared scope

The six tasks call `Measures.Source.family_laws/1` (`Scope`), and the six inline copies are gone (−48 lines). Compile and Credo are clean. Nothing in the query changed, so a unit test would only test the delegate. Behaviour preservation is proven by draws pass 2 printing pass 1's figures (todo 7).

## Hand sample

- **In code:** `Measures.HandSample` (pure, 3 tests) and `mix lat.measures --sample FILE --n N --seed S`.
- **Port proven:** on today's store, OH&S seed 911 draws the same 50 items as CV-S10's scratchpad script, equal as JSON (only the key order inside each item's sources map differs).
- **Maritime, seed 902:** 50 of 3,150 text changes, drawn twice and byte-identical, with the printed figures unchanged. I read item 1 (MSA regs 1998/1011 reg.1(2), a feed-only revocation, read with no rule; dated, no order named): classed right.
- **Territory group:** it is computed only by the extent check's full run (amending-law reads), so it isn't on the hand items. The hand check adds 10 items from the extent check's seed-902 sample instead, one per outcome round-robin. A small change to Design 3, same agent pass.

## Verdict files

The 5 VERDICTS blocks were found in the agents' hand-back messages and saved verbatim under `verdicts/{markup,evidence,label}/maritime-safety/`. `lat.verdicts` reprints the published tallies:
- markup: 0/50 wrong, 2 doubtful;
- evidence: 0/49 own, end to end 1/49, 20 gaps (one item of 50 counted once);
- label: 31/43 own wrong, end to end 35/43. All 31 were fixed in-step: the made-period tiers in `Label.Made`, 33920924.

Their "NOT PASSED" lines apply the old 2% pooled bound, which the one-agent-pass process doesn't use. The agent passes find classes; they are not the gate.

Feed reader (seed 41), Commencement reader (47, 53) and Merge (51) saved no block: hand tally, report only.

## Hand check (one agent pass, 288,287 tokens)

The pass covered 50 hand items and 10 territory items in 2 batches. Reports: `backend/data/reports/measures/maritime-hand-b{1,2}-report.md`. Verdicts: `verdicts/measures/maritime-safety/round-1-hand-seed-902-b{1,2}.json`. It cost 288k tokens against the planned ~150k.

**Measures' own faults, found and fixed:**

1. **Law-text coverage counted unread text as read** (items 2, 16, 24; also 33 and 47, which batch 2 passed). The read set was the index's pointers, even where the amending law's text isn't stored (Schedules fetched body-only): about 1,130 of 9,426 pointers. Now `Measures.Source.read_pointers/2` counts a pointer only where its provision, or one containing it, is in the text (3 tests). All 5 items checked: their Schedules aren't held.
2. **An order's "art." pointer missed the feed's "reg." name** (item 21). It is now read in both spellings.
3. **`none:law_no_clause` fell in "other"** (T2). It is now its own group, `no_clause`. The group list moved to `Coverage.territory_group_names/0`, and `Extent.Check.groups/0` reads it.

Effect, by `lat.measures`:

| Family | read, no rule: Schedule | read, no rule: body | not read | Territory |
|---|---|---|---|---|
| Maritime Safety | 172 → 174 | 922 → 787 | 154 → 287 | 13 out of other |
| OH&S | 867 → 869 | 898 → 917 | 454 → 433 | 4 out of other |

The hand sample redraws the same 50 items. Its classes move only on items 2, 16, 21, 24, 33 and 47.

**By definition, not a fault** (item 7): "read" is the provision the feed names, here the gateway s.1(6) ("Schedule 2 shall have effect"). The read set doesn't follow it into Sch.2.

**Upstream, raised and parked:**

| Items | Fault | Owner | Reach |
|---|---|---|---|
| 14, 31, 37, 39 | SI 2006/1244 reg.1(4)'s purpose-limited date taken as the whole start | Commencement reader | 93 changes |
| 40 | SI 2011/2616's own clause unread | already parked: amending-law-own-clause-unread | |
| 46 | AJA 1999 Sch.13 dated by Royal Assent | already parked: amending-law start misread | |
| 50 | one event split across two changes (markup and feed ids differ) | Merge | |

**Result:** no item is classed wrong by a measure once the three faults are fixed. stated_by 50/50, dating 50/50 and merge stratum 50/50 are right as measures; the territory items are 10/10 once `no_clause` is named.

## Verify

- **Draws pass 2** (after the fixes) against pass 1: 11 samples are byte-identical (all but the hand sample, which pass 1 did not draw).
- **Printed figures:** identical after filtering, except the step's own changes:
  - Evidence's new gap totals line;
  - Extent's `no_clause` group, and its machine-state line;
  - `lat.measures`' coverage.
- **The hand sample** was equal as JSON but not byte-identical across two builds: atom-keyed `sources` map order. Fixed with string keys (tested); redrawn twice, byte-identical.
- **Regression:**
  - golden 27/27 (984 s);
  - `mix test` 10,172 passed, 2 skipped;
  - Credo diff clean;
  - OH&S `lat.measures` moved only by the read-set fix (above).

## After close: the Sources fetch (Jason, 2026-11-06)

Run with `mix lat.sources --family F --fetch`:
- 9 of the 11 fetched; 2 returned HTTP 500 from legislation.gov.uk and fetched on a retry;
- 10 of the 11 are absent: legislation.gov.uk holds no Schedules for them;
- the gate re-run: PASS, 0 failures of 673.

The extent check after the fetch:
- still 4 causes not named;
- now 1 "our fault": UK_ukpga_1992_52's body is held, so its stored extent rules are stale.

Both are the Extent reader's, parked: re-read its extent, then name the causes.
