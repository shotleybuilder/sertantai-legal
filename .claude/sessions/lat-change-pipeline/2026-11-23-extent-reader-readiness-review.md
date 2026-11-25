---
session: 'Extent reader readiness review'
status: closed
opened: 2026-11-23
closed: 2026-11-25
outcome: success
summary: >
  The Commencement reader retrospective's questions asked of the Extent reader before its step. The reader's spec was written and accepted (EXTENT-READER.md), a gotchas file added, the main cost found (one stamp over the folder, catalogue and tools included, so all 2,601 readings and 768 builds are stale), and the feed measured as a yardstick (89% agreement where both speak).
  Decision 1: four changes as two pending sessions before the step (stamps, then step procedures). Decision 2: the feed first where it speaks (RULES `extent-feed-first-where-it-speaks`; Evidence #202). The Commencement docs were revised to the reader after its follow-on sessions.
decisions:
  - what: "Decision 1: stamps that follow what changed, the mixed modules split, the build's stamp to the lookup only, and the step's procedures as tasks; two sessions before the step"
    why: "any extent edit stales every reading and every build (both stamps glob extent/*.ex); the write takes lists by hand with no preview; the same pains in all three earlier steps"
    result: "2026-11-25-extent-reader-stamps.md and 2026-11-25-extent-reader-step-procedures.md (pending), placed in the round meta; no extra re-read cycle, since all 2,601 readings are stale already"
  - what: "Decision 2: the feed's effect extent first where it speaks, unless the law's words prove it wrong (Jason chose (b) over the recommended one-way yardstick)"
    why: "the Commencement reader's feed-coverage rule applied alike; the Reader's fixes limited to changes the feed doesn't cover"
    result: "RULES extent-feed-first-where-it-speaks; the build change raised with Evidence as #202 (reach 3,881 differing, 16,215 feed only); the label keeps the law's bound until it is built"
  - what: EXTENT-READER.md accepted as of 2026-11-25, revised after the two sessions
    why: its substeps, stamps and loops are what those sessions change
    result: indexed in the pipeline README; WORKFLOW §5 and the skill point to it
metrics:
  reader_size: { files: 44, lines: 7753, test_lines: 6170, largest_module_lines: 522 }
  stamps: { extent_read_files: 52, readings_on_old_versions: 2601, builds_extent_stale: 768 }
  feed_vs_law: { text_changes: 76007, feed_extent: 51537, law_bound: 41785, both: 35322, agree: 31441, law_wider: 3114, law_narrower: 706, disjoint: 61, feed_only: 16215, law_only: 6463, neither: 18007 }
  gates_today: { round_our_faults: 687, round_not_stored: 620, round_causes_not_named: 465, switched_failing_on_stale: 4 }
lessons:
  - title: The build calls the Extent reader's lookup, not only its stored rules
    detail: "readers/feed.ex asks each stored reading for the change's bound (Extent.of_change/3) and application; so the build's stamp can drop the sentence readers but must keep Lookup. The plan had assumed stored rules only."
    tag: tooling
  - title: The law's bound and the feed's effect extent answer different questions
    detail: "Most differences (3,114 of 3,881) are the law wider: the amending provision's own extent (often UK) against the extent of the provision amended. A raw disagreement count overstates misreads."
    tag: data
  - title: A read-only check is not seconds when its cache is cold
    detail: "lat.extent_check took 5 min for the round and 9 min for five families, because every reading is on an old version and ReadCache recomputes; the plan said seconds."
    tag: tooling
bugs: []
artifacts:
  - docs/lat-change-pipeline/EXTENT-READER.md
  - backend/lib/sertantai_legal/scraper/amending_law/extent/CLAUDE.md
  - backend/data/reports/extent-reader/readiness/
  - .claude/sessions/lat-change-pipeline/2026-11-25-extent-reader-stamps.md
  - .claude/sessions/lat-change-pipeline/2026-11-25-extent-reader-step-procedures.md
  - docs/lat-change-pipeline/COMMENCEMENT-READER.md
  - docs/lat-change-pipeline/RULES.md
depends_on:
  - 2026-11-23-commencement-reader-retrospective
  - 2026-11-23-commencement-reader-feed-differences-as-patterns
enables:
  - "Extent reader: stamps that follow what changed"
  - "Extent reader: step procedures"
  - "Waste, Water and Climate: Extent reader"
---

# Session: Extent reader readiness review (CLOSED)

## Problem

The Commencement reader retrospective found problems that probably affect the Extent reader too: the reader's aim and scope never written; substeps, inputs, outputs and staleness undocumented; one version stamp over the reader (`Extent.ReadVersion`, 95 files, including commencement modules); fetch needs found late; golden run late; heavy checks per fix. Jason (2026-11-23): run a similar retrospective before launching the Extent reader step.

## Todo

- ✅ 1. Measure: size, stamps, stale state, procedures, earlier steps, parked bugs (plan mode, 2026-11-25)
- ✅ 2. Find: the feed-coverage question in figures (where each change's territory comes from, per family)
- ✅ 3. `docs/lat-change-pipeline/EXTENT-READER.md`: aim, scope, boundary, substeps, loops, yardstick, open questions
- ✅ 4. `amending_law/extent/CLAUDE.md`: the gotchas file; WORKFLOW §5 and the skill point to it
- ✅ 5. Decision for Jason: what to change before the step (stamps, the build's fallback, procedures as tasks, mixed modules, the feed-coverage answer)
- ✅ 6. Docs: COMMENCEMENT-READER.md revised, COMMENCEMENT-GUIDE §2/§5, AMENDMENT-GUIDE "effects first", DATA-ARCHITECTURE `commencement_rules`; README index; the two 2026-10-28 extent sessions closed
- ✅ 7. Close: decided sessions as pending stubs in the round meta; rules in RULES; the report in the terminal

## Dependencies

- ✅ The Commencement reader's five follow-on sessions closed (the last, feed differences, 2026-11-25) (step procedures; staleness; decouple; order split; feed differences as patterns)

## 1. Measure (plan mode, 2026-11-25)

Plan: approved 2026-11-25 (no code change in this session; the decided changes are their own sessions). Read-only maps by three agents, the stamp and store claims checked by hand.

- **Size:** `amending_law/extent.ex` + `extent/`: 44 files, 7,753 lines; about 6,170 lines of tests. Largest: `Patterns` 522, `Unread` 375, `ListItems` 364; `Patterns.outcome` about 130 lines. Mixed pure and IO: `Powers` (placement, enabling cache, DB), `ReadCache` (reading with catalogue classes and the sweep), `Store`.
- **Stamps:** `Extent.ReadVersion` globs `extent/*.ex` (52 files), so the catalogue and tools (`Patterns`, `Credit`, `Sweep`, `ReadCache`, `Store`) and the stamp file itself are in it; its test starts from the stamp's own files. The build's `ChangeVocabulary.Version` globs `extent/*.ex` too, because the build reads an unstored law's extent from its text (`change_vocabulary/primary.ex:70`). The powers parser (`EnactedBy.EnablingProvisions`) is in no extent stamp.
- **Stale:** all 2,601 laws in `extent_rules` are on old versions (1,694 on 77f2279a1ce7, 905 on d7e273cc45de, 2 on e77f66b9d049; current 11cf0d2fc057): the 768 stale builds. `Extent.Store.write_read` already writes only what changed.
- **Procedures:** `lat.amending --extents` has no `--preview`, `--stale` or `--all`; `lat.reread` has no extents substep; `lat.stale`'s extent fix line names no laws; the skill names neither. No gotchas file, no reader spec.
- **Earlier steps:** Maritime Safety 0.5 day, Environmental Protection 2, Fire and OH&S 2; golden 27/27 each. Repeated: the real gate only after the first write; introductions fetched mid-step (17, 7, 3; `enabling-cache-empty-counts-held`, Sources); cold catalogues of 8–30 min; new modules missed from the Feed and Markup stamps; other families' stale builds.
- **Parked for the step:** 11 open bugs (step Extent reader), none on GitHub. Handed to the step's plan; built-before-extent-read (126 laws) and the fixture behind the store (1,568 laws) are settled by the stamp work and the step's first write.
- **Obsolete pending sessions:** "Extent reader: Census Mix Task" (delivered by `mix lat.extent_census`, 2026-11-07) and "Extent reader: Agreement with the Feed" (folded into todo 2).

## 2. Find: the feed-coverage question (2026-11-25)

Reports: `backend/data/reports/extent-reader/readiness/` (the five checks; `feed-vs-law.md`, the SQL). The checks read 9 min in all, not seconds: the reading cache is cold because every reading is on an old version.

**Today's gates** (read-only `lat.extent_check`, all FAIL):

| Family | Text changes | Bound by the law's text | Our faults | Causes not named |
|---|---|---|---|---|
| Waste, Water and Climate (round) | 26,493 | 43.3% | 687 (620 never stored, 67 stale) | 465 |
| Fire and OH&S | 5,118 | 76.3% | 3 stale | 1 |
| OH&S: Occupational | 5,044 | 74.9% | 0 | 1 |
| Environmental Protection | 8,025 | 72.8% | 3 stale | 3 |
| Maritime Safety | 3,141 | 95.1% | 1 stale | 0 |

The switched families' failures are stale readings (UK_nia_2011_23, UK_nisi_2006_3336, UK_uksi_2007_2194, UK_ukpga_2005_4), which the step's first write clears. The round's gate is the step's own work: its largest causes are introductions not held (SI 2019/583, 359 changes; SI 2018/374, 255) and provisions not named.

**The feed against the law's text** (every stored text change, all families; claims `feed effect_extent` and `law_text extent`):

| | Changes |
|---|---|
| Text changes | 76,007 |
| The feed states an extent | 51,537 (68%) |
| The law's text bounds it | 41,785 (55%) |
| Both | 35,322; agree 31,441 (89%) |
| Differ | 3,881: the law wider 3,114, narrower 706, neither 61 |
| The law only | 6,463 |
| The feed only | 16,215 |
| Neither | 18,007 |

- **Where the territory is taken from the feed or markup today:** 0% to 1.6% of a family's changes. Evidence takes the law's bound first (RULES §7).
- **The differences are mostly not contradictions.** The law's text is an upper bound: the amending provision's own extent clause, often the whole UK. The feed's effect extent is often narrower, the extent of the provision amended (for example, NI for a UK Act's change to an NI-only law: 934 changes). The Label fold already narrows the bound by the row's extent.
- **So the Commencement rule doesn't carry over as it stands.** A difference here is no evidence of a misread unless the law reads *narrower* than the feed (706) or disjoint from it (61). Those 767 are the yardstick's candidates. The decision is in todo 5.

## 3–4. The spec and the gotchas (2026-11-25)

- `docs/lat-change-pipeline/EXTENT-READER.md` (DRAFT): aim, scope, the boundary table (where against what/who, when, the Feed and Markup readers' territory, the row's own extent), substeps, six loops, the yardstick, open questions. Indexed in the pipeline README.
- **A finding the plan didn't have:** the build calls the reader's lookup itself (`Extent.of_change/3`, `application_at/2` from `readers/feed.ex:300`), not only stored rules. So the build's stamp must keep the lookup even without the fallback; option (b) below is restated to fit.
- `backend/lib/sertantai_legal/scraper/amending_law/extent/CLAUDE.md`: 13 gotchas (5 stamps and cycles, 6 running the step, 2 code), from WORKFLOW §5 and the three step sessions. WORKFLOW §5 and the skill point to it and to the spec.

## Decision 1 for Jason: what to change before the Extent reader step

- **Aim:** `binds-on-date` at a cost a step can carry (`fix-where-owned`). A fix should cost its tests and one bounded write, not every reading and every build.
- **(a) Stamps that follow what changed** (the Extent reader's code):
  - `Extent.ReadVersion` becomes the reading's own reach, listed by name, with no folder glob;
  - the catalogue and tools (`Patterns`, `Credit`, `Sweep`) get a catalogue stamp, and `ReadCache` is keyed on both;
  - the stamp test is made exact both ways;
  - the powers parser gets a stamp on the enabling cache, so a parser change stales the SIs it parsed.
  - **Expected effect:** a catalogue edit stales no reading; a reader edit stales the readings but not the catalogue's other inputs.
  - **Cost:** about half a day. No extra cycle, because all 2,601 readings are stale already and the step's first write re-reads them.
- **(b) The build's stamp holds only the lookup** (Store and build's code, so it needs your go):
  - drop the build's fallback that reads an unstored law's text (an unread law becomes a stale reason, filled by the step's write);
  - `ChangeVocabulary.Version` then lists `Extent.Lookup` and the struct by name, not `extent/*.ex`.
  - **Expected effect:** a sentence-reader fix stales the readings it changes, and builds only through them.
  - **Cost:** small. The fallback's reach is measured first.
- **(c) The step's procedures as tasks:**
  - `lat.amending --extents --preview` (rules by field, like `--read --preview --diff`) and `--stale` (every law whose reading is old);
  - an extents substep in `lat.reread`;
  - `lat.stale` naming the laws in its extent fix line;
  - the yardstick from (e) printed by `lat.extent_check` and recorded for Measures;
  - the skill and WORKFLOW §5 rewritten as the Commencement reader's were: write first at Measure, the fetch list from Find, golden at every Settle, no reader commit after the last write.
  - **Cost:** about half a day.
- **(d) Split the two mixed modules:** `Powers` (pure placement apart from the cache and DB) and `ReadCache` (the reading apart from the catalogue classes and the sweep). It goes with (a), because the split sets the stamps' lines.
- **Recommendation:** all four, as two managed sessions before the step:
  1. "Extent reader: stamps that follow what changed": (a) + (d), and (b) if you say go;
  2. "Extent reader: step procedures": (c).

## Decision 2 for Jason: does the feed-coverage rule apply to extent?

- **Aim:** `fix-where-owned`. Fix the reader where its words are wrong, never chase a source's different question.
- **The figures (todo 2):**
  - the law's text and the feed agree on 89% of the changes where both speak;
  - where they differ, the law is wider on 3,114, narrower on 706 and disjoint on 61.
  - The law's bound is an upper bound (the amending provision's extent). The feed's is often the extent of the provision amended, which the Label fold reaches anyway by narrowing to the row's extent.
- **Options:**
  - **(a) A one-way yardstick.** The law's text is primary and always judged. Only a law bound *narrower* than the feed or *disjoint* from it (767 changes) is a difference. Those are grouped and statused in the check (`fix:`, `known:`, or the feed proven wrong), like the commencement gate's groups. A wider bound is expected, not a difference. (RULES: a new rule.)
  - **(b) The Commencement rule as it stands.** Where the feed states an extent, it is used unless the law's words prove it wrong. The reader's work is limited to the laws without one. This needs a change to Evidence (feed before the law's text on covered changes) and drops the law's primary bound on 68% of changes.
  - **(c) No yardstick.** The gate stays as it is (no bound by cause).
- **Recommendation: (a).** It keeps the law's words primary (RULES §7) and makes the feed a check on the only direction that can show a misread. It costs one grouping in the check, built in session 2 of Decision 1.

**Decided (Jason 2026-11-25):**
- **Decision 1: all four, as two sessions** (recommended): "Extent reader: stamps that follow what changed" ((a) + (d) + (b); (b) is Store and build's code, done there on this go), then "Extent reader: step procedures" ((c)).
- **Decision 2: (b), the feed first where it speaks** (not the recommendation). RULES `extent-feed-first-where-it-speaks`. The build change is Evidence's, raised as #202 (`step:evidence`) with a design brief and the reach, as #200 was for Merge. Until it is built, the label takes the law's bound. For the Extent reader step, its fixes are limited to the changes with no feed extent; a misread found only where the feed speaks is a known limit. The check's grouping by coverage goes into the step procedures session.
- **The spec:** accepted as of 2026-11-25, revised after the two sessions.

## 6. Docs (2026-11-25)

- **COMMENCEMENT-READER.md** revised to the reader after its follow-on sessions:
  - §3 overlaps (the old dater fenced; shared helpers);
  - §4 substeps (per-path stamps 63/50/4 files, changed-only writes, the tasks);
  - §5 loops (what was fixed and what still loops);
  - §6 yardstick (Measures, feed coverage, #200);
  - §7 open questions.
- **COMMENCEMENT-GUIDE:** §2.1 and §2.4 now name both label paths, and the new path's order for an amending provision. §3.5 and §5 are marked as the old path's.
- **AMENDMENT-GUIDE:** "effects first" is marked as the old path, and the pipeline's text-first order is named with its two pending exceptions (#200, #202).
- **DATA-ARCHITECTURE:** the `commencement_rules` row (84,554 rules, 62,953 feed, 42 MB; its writers and stamps) and the diagram's count. The collector row's law start is now stored with the build.
- **RULES:** `extent-feed-first-where-it-speaks` (§3).
- **WORKFLOW §5, the skill and the README index** point to EXTENT-READER.md and the gotchas file.
- **Closed as superseded:** "Extent reader: Census Mix Task" (its 3 leftovers are in the step procedures stub) and "Extent reader: Agreement with the Feed" (measured in todo 2).

## Close (2026-11-25)

- **No step close:** this is a review, not a family step, like the Commencement retrospective. No code changed, and nothing was written to the DB.
- **Bugs:** none new, and none fixed. The 11 parked Extent reader bugs go to the step's plan. Two of them, built before extent read (126 laws) and the fixture behind the store (1,568 laws), are cleared by the step's first write and accept after the stamps session.
- **Parking:** none.

## Step report

Given in the terminal (2026-11-25).
