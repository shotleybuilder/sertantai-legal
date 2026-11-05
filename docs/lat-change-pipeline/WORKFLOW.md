# LAT Change Pipeline: Workflow

The pipeline has 14 steps, numbered from 0: Making laws (added 2026-11-04, before the second family) comes before Sources, so the later steps keep their numbers. Each step has one job and a check that says whether the job is done well enough to move on. A family of laws goes through the steps in order; a step trusts the steps before it. What the pipeline is for, and three changes traced end to end, are in the [README](README.md). Terms are in the [Glossary](GLOSSARY.md).

All commands run from `backend/`. `F` is the family name as the register spells it, e.g. `"OH&S: Occupational / Personal Safety"`.

**Pass rules below are as last used, on OH&S (October–November 2026).** Several moved during that run: from "a clean agent sample", to "no new defect", to a statistical bound, and finally (at the switch-over) to a pass decided by code. Under the new process (see [How a step is run](#how-a-step-is-run)), each step's pass rule is fixed in its plan before work starts, and checked in code first.

## The steps at a glance

| # | Step | Writes | Check skill |
|---|---|---|---|
| 0 | Making laws | the making text verdict in `legal_register` (through `Making.record`); LAT rows for the laws decided making (a parse, with Jason's go) | none (`mix lat.making_laws`) |
| 1 | Sources | the CLML store (fetch, with Jason's go) | none (`mix lat.sources`) |
| 2 | Feed reader | feed claims (via the build) | `feed-reader-check` |
| 3 | Markup reader | markup claims (via the build) | `markup-reader-check` |
| 4 | Commencement reader | `commencement_rules`; commencement claims | none (recipe below) |
| 5 | Extent reader | `extent_rules`; law-text territory claims | `extent-reader-check` |
| 6 | Amending-law reader | `amendment_rules`; law-text claims | `amending-reader-check` |
| 7 | Merge | `provision_changes`, `provision_change_claims` (via the build) | `merge-check` |
| 8 | Evidence | chosen values in `provision_changes` (via the build) | `evidence-check` |
| 9 | Label fold | nothing (pure; read by steps 12–13) | `label-check` |
| 10 | Measures | verdict files; nothing in the database | `measures-check` |
| 11 | Store and build | `provision_changes`, `provision_change_claims`, `lat_events` | `store-build-check` |
| 12 | Labels side by side | nothing (computed beside the old labels) | none (`mix lat.label_check --strata`) |
| 13 | Switch-over | `lat_label_timeline` (through `LabelRefresh`) | `switch-over-check` |

Steps 2–8 all land in the change register through one build (`mix lat.vocabulary --check --family F`), so "writes" there means what the step contributes to it.

---

## 0. Making laws

**Aim.** Every live law in the family (in force or part revoked) is decided making or not from its own text, and each making law has LAT rows. LAT holds rows only for in-force making laws, and every later step places changes on those rows; a making law without rows drops out of every step and gets no labels.

**Why a step.** For a law without rows, `is_making` is an estimate: the metadata detector, legacy duty types, or a value set before the resolver. Fractalaw's DRRP reading is finer but slow to arrive. On Maritime Safety, 158 of 174 live laws had no rows and none of their estimates had been read from the text.

**Inputs.** The register (`legal_register`: family, live, the making fields), the CLML store (each law's body) and `legal_articles` (which laws have rows).

**Outputs.** A verdict per law (`making`, `not_making`, or none with a reason) in `making_text_verdict` and `making_text_reason`, recorded through `Making.record`. The resolver's `law_text` tier ranks below a human review and fractalaw's enrichment, and above every estimate. A report, `backend/data/reports/making-laws/<family>.csv`. Then LAT rows for the laws newly decided making.

**The rule.** A law is read provision by provision, outside quoted inserted text:
- **not making:** every operative provision is an amending instruction, a revocation, a commencement, or standard wording (citation, interpretation, extent, application, review, transitional);
- **making:** at least one own provision states a requirement ("shall" or "must") outside quoted text and outside a modification ("shall have effect as if");
- **no verdict, to Jason's list:** powers only ("may"), no XML upstream, or text not read.

**Check.** `mix lat.making_laws --family F` (read-only; `--fetch` fetches missing bodies, `--apply` records the verdicts; ask Jason first for both). The checked laws (human review and fractalaw verdicts in the family) are a fixture test.

**Pass rule (Maritime Safety, first use).** The rule is unit-tested by kind; the classifier agrees with every checked law, or each disagreement is decided by Jason; every live law has a verdict or is on the list, and the list is at most 10% of the family; two runs give the same report; every law decided making has LAT rows after the parse, or is named with a reason.

**Skill.** None.

## 1. Sources

**Aim.** Every document the later steps need for the family is held locally, or known to be absent upstream.

**Inputs.** The register (`uk_lrt`: each law's change statistics and validity date), the CLML store (`backend/data/cache/clml/`), and the stored changes (`provision_changes`), whose gaps say which further documents are needed.

**Outputs.** A report of needed against held, by need: own text, own feed, territory (each amending law's body; for an SI with no extent, its introduction and its enabling Acts), dates where the feed gives none, and the backlog the feed doesn't record. With `--fetch`, the missing documents.

**Check today.** `mix lat.sources --family F` (read-only). `--fetch` fetches; ask Jason first. The same gate re-runs at the end of every `mix lat.vocabulary --check`.

**Pass rule as last used.**
- Every needed document is held, or missing with a reason (no XML upstream, 404, fetch failed, out of scope).
- A held copy older than legislation.gov.uk's latest fails until refetched or explained.
- Each law's stored feed matches the register's change statistics, or the difference is explained.
- The counting rules are unit-tested; two runs give the same report.

On OH&S it passed on 2026-10-22. When later steps added needs, the gate failed again at Store and build (565 failures, deferred to the next pass): a passed step is not re-checked unless something re-runs its gate.

**Run the gate after one build (from Maritime Safety, 2026-11-04).** The territory, dates and backlog needs come from the stored changes, so a family with none built shows only own text and feeds. The order is:
1. fetch the feeds;
2. build the family's changes once (`mix lat.vocabulary --build --family F`, after a restore point of `provision_changes,provision_change_claims,lat_events`);
3. gate, and fetch what fails;
4. one more round for needs the fetch itself adds (an introduction naming enabling Acts).

On Maritime Safety, the build took the needs from 235 to 682, and three fetch rounds held them all. A feed whose register statistics are newer than it needs refetching and its law rebuilding; that added 4 needs.

**Skill.** None. The `nas-data-sync` skill covers the store itself.

## 2. Feed reader

**Aim.** Each changes-feed effect becomes changes on the right provisions, carrying the effect's facts exactly as the feed gives them. Whether the feed is right is the Evidence step's question.

**Inputs.** The stored feed pages (`clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz`) and the family's LAT rows (`legal_articles`).

**Outputs.** Feed claims per effect and target: operation, level, date or dated stages (keyed `effect id@date`), `by`, effect extent, territorial application, savings, `commenced_by`, and the affecting provision as a pointer.

**Check today.**
1. Pattern catalogue: `mix lat.feed_patterns` over every stored feed (about 8 min); each new pattern accepted, fixed, or marked pending until `feed_patterns_test.exs` passes.
2. Gate and placement: `mix lat.feed_check --family F`; our faults must be 0.
3. Repeatability: the same seed twice into two sample files, compared with `cmp`.
4. Golden: `mix lat.vocabulary --golden`.
5. An agent judges 50 sampled effects against the feed and the law text.
6. Tell-tales (finer forms the feed names that we don't hold) are raised against the LAT parser.

**Pass rule as last used.** Sources held; our faults 0; repeatable; golden all-pass; the catalogue test passes; the agent finds nothing wrong outside the known patterns.

**Skill.** `feed-reader-check`.

## 3. Markup reader

**Aim.** Each change element in the revised text becomes one change on the provision where it sits, carrying what the markup states.

**Inputs.** The stored law text (`clml/{type}/{year}/{number}/body/data.xml.gz`), the feed (to compare keys) and the LAT rows.

**Outputs.** Markup claims: operation, level, retained text, territory (`Extent`), and, for a legacy ChangeId, the note's cited law and amending provisions as identity pointers.

**Check today.**
1. Pattern catalogue: `mix lat.markup_patterns` (about 16 min); new patterns decided until `markup_patterns_test.exs` passes.
2. Gate and placement: `mix lat.markup_check --family F --all`; our faults 0. It also counts the markup's keys against the feed (in the feed, not in it, legacy), for the Merge step.
3. Repeatability, golden and an agent on 50 sampled changes, as for the feed.

**Pass rule as last used.** Sources held; our faults 0; repeatable; golden all-pass; the agent finds nothing wrong outside the known patterns.

**Skill.** `markup-reader-check`.

## 4. Commencement reader

**Aim.** The law's own commencement clause and the orders made under it give each provision dated `commenced` changes (staged when it came in partly first), and give an otherwise undated change the date its amending provision came into force.

**Inputs.** The law's text, the commencement orders held, the amending laws' commencement provisions, and pointers (feed affecting provisions, notes) to the amending provision.

**Outputs.** `commencement_rules`; commencement claims (`date`, `partial`, `commenced_by`, and `via` when a pointer led to the date).

**Check today.**
1. Both catalogues: `mix lat.commencement_patterns` (own commencement sentences, about 12 min) and `mix lat.order_patterns` (orders, about 30 s), until `CommencementPatternsTest` and `OrderPatternsTest` pass. Each also reports its **leftovers** (`Commencement.Leftovers`): the words of a statement that bear on a date (a date, a provision, an exception, a qualifier, a relative day) that no rule read from it uses, grouped and ranked by the rows they reach, every group reviewed in `leftovers.json` (`LeftoversReviewTest`). This replaces agent rounds as the way to find a family's new forms (2026-11-05).
2. The readers' re-read (ask first): `mix lat.commencement`, then the rebuild.
3. `mix lat.commencement_check --family F`: every row dated, left to an order, or undated with a reason; our faults 0. Its **leftovers gate** lists every leftover reaching the family (its laws' own clauses, the orders held for them, its held amending laws), each with its group's status; PASS needs every one `known:`.
4. Golden. At most one agent pass, and only to label leftover groups; never sample, fix, resample (Jason 2026-11-05).
5. Repeatable: two `--sample` runs on one seed, identical.

**Pass rule** (Decision 1 (c), Jason 2026-11-05). `lat.commencement_check --family F` prints PASS: our faults 0 and every leftover reaching the family named (`known:`); every leftover group reviewed (`LeftoversReviewTest`); the catalogue tests pass; repeatable; golden all-pass. No agent rounds. (Before: the stopping rule of 2026-10-24, on an agent sample.)

**Skill.** `commencement-reader-check`. Background: [COMMENCEMENT-GUIDE.md](COMMENCEMENT-GUIDE.md).

## 5. Extent reader

**Aim.** Where each amending law's changes apply is read from its own words; a statement that can't be read fully gives no territory, never a default.

**Inputs.** The amending laws' text (body and schedules), SIs' introductions and enabling Acts.

**Outputs.** `extent_rules` per amending law; law-text territory and extent claims on each change.

**Check today.**
1. Recall sweep: `mix lat.extent_sweep --family F` finds sentences the catalogue doesn't class.
2. Catalogue: `mix lat.extent_patterns --accept`, then review the fixture diff.
3. Extents: `mix lat.amending --extents --amending <laws> --cached` (writes `extent_rules`).
4. Rebuild and golden: `mix lat.vocabulary --check --family F`.
5. `mix lat.extent_check --family F`: our faults 0, and no uncaught sentence in a readable form.
6. Repeatable sample, and an agent on 50 amending laws and 50 text changes per seed.

**Pass rule as last used** (statistical, 2026-10-28). Pool the seeds since the last fix batch, with every new defect fixed. The 95% upper bound of changes with a wrong territory must be under 2%, and of amending laws under 5%. Also: the census classes at zero apart from logged residuals; the check at our faults 0; golden all-pass. Publish the coverage table and a quality statement.

**Skill.** `extent-reader-check`.

## 6. Amending-law reader

**Aim.** Each amending provision's own words give the right amended law, target provisions, operation and level. The law's text wins where it speaks, so a misread here overrides a correct legislation.gov.uk record: precision is what matters.

**Inputs.** The amending laws' text, the amended law's rows, and the pointers (notes, feed) saying which amending provisions to read.

**Outputs.** `amendment_rules`; law-text claims (operation, level, `by`).

**Check today.**
1. Catalogue: `mix lat.amendment_patterns --family F --accept`, every changed reading reviewed.
2. Pre-flight for a fix: `mix lat.amending --read --preview --regression`.
3. Read pass (writes `amendment_rules`; one law at a time): `mix lat.amending --read`.
4. Rebuild, then golden from inputs: `mix lat.vocabulary --golden` (never only `--check`, which scores golden laws outside the family from stale stored changes).
5. Census of disagreements: `mix lat.vocabulary --conflicts --family F --all`.
6. Strata: `mix lat.amending_check --family F --strata` gives A (agreeing with legislation.gov.uk), D (disagreeing) and L (law text only), and the agreement rates.
7. D and L checked in full; A by agent samples of 50 on new seeds.

**Pass rule as last used** (2026-10-28). D and L: no misread left unfixed or unclassed. A: pooled samples under 2% wrong changes and under 5% wrong (amended law, amending law) pairs at the 95% upper bound. Golden from inputs, bar logged limits.

**Skill.** `amending-reader-check`. Background: [AMENDMENT-GUIDE.md](AMENDMENT-GUIDE.md).

## 7. Merge

**Aim.** One change per real event, whichever sources state it.

**Inputs.** The claims from steps 2–6.

**Outputs.** Change records in `provision_changes` with their claims in `provision_change_claims`, each with its key and the aliases merged into it.

**Check today.** `mix lat.merge_check --family F --strata` gives J (joined: two or more sources; over-join risk), U (law text alone beside legislation.gov.uk's likely same event; split risk) and C (single-source changes beside another source's; split risk), the join rate, and the spread tell-tale (keys under more than three top provisions). U and C are checked in full by agents; J in samples of 50 on new seeds.

**Pass rule as last used** (decided before round 1, 2026-10-28). U and C: no wrong merge left unfixed or unclassed. J: pooled under 2% wrong changes and under 5% wrong pairs at the 95% upper bound (at least 149 clean items). Golden from inputs 27/27. Publish the join rate and a quality statement.

**Skill.** `merge-check`. Design: [CHANGE-IDENTITY-DESIGN.md](CHANGE-IDENTITY-DESIGN.md).

## 8. Evidence

**Aim.** Each attribute of a merged change comes from the right source by the evidence table, and every disagreement between the law and legislation.gov.uk is reported like for like.

**Inputs.** Merged changes and their claims.

**Outputs.** The chosen value and winning source per attribute (stored on `provision_changes`); tiers and the conflict report are worked out on read.

**Check today.** `mix lat.evidence_check --family F --strata` gives V (value conflicts: the law against legislation.gov.uk), D (markup against feed with no primary claim, by pattern) and A (several sources agreeing), and the winning source per attribute. V in full; D up to 10 per pattern (`--per 10`); A in samples on new seeds.

**Pass rule as last used** (2026-10-29). V and D: no wrong winner, false conflict or wrong pattern left unfixed or unclassed. A: pooled under 2% wrong changes and 5% wrong pairs at the 95% upper bound. Golden from inputs 27/27. A value no source claims is a gap, published by cause, not a fault.

**Skill.** `evidence-check`.

## 9. Label fold

**Aim.** A provision's resolved changes fold into the right label periods under the agreed conventions.

**Inputs.** The stored changes (`provision_changes`), the LAT rows and their extents, and the law's start (still read from `lat_change_log`).

**Outputs.** Label periods (status, territory, in force from, changed by, commenced by, a tier per field). Pure: nothing is written at this step.

**Check today.** `mix lat.label_check --family F --strata` gives S (rows each fold rule acts on, by shape), T (rows whose fold differs from today's label, by class) and R (random rows). G is golden from inputs on `golden.exs`. S and T are judged by shape and class (`--per 10`); R in 5 × 30 rows on a new seed.

**Pass rule as last used** (2026-10-29; golden revised 2026-10-30). G: the 27 golden provisions all pass from inputs. S and T: no fold fault left unfixed or unclassed. R: pooled under 2% wrong rows and 5% wrong laws at the 95% upper bound, counting fold faults only. Upstream faults are logged with their owning step and published as the end-to-end figure. Golden is never grown during a pass: new provisions go to `golden_extended.exs` for the next pass.

**Skill.** `label-check`.

## 10. Measures

**Aim.** Every figure a step publishes can be believed: one name and one meaning, computed by code, tested, and replicable.

**Inputs.** The stored changes and the agent verdict files (`backend/data/reports/change-vocabulary/verdicts/<step>/<family>/`).

**Outputs.** Printed figures; the register of figures in the `measures-check` skill.

**Check today.** `mix lat.measures --family F` (coverage and dating), `mix lat.verdicts --dir DIR` (pass bounds, end to end, gaps), each step's `--strata`. Replicability: draw every sample twice on one seed and compare (`draws.sh` in the skill). An agent hand-checks a seeded sample of each classifying measure.

**Pass rule as last used** (2026-10-30). Every published figure is in the register, printed by code and tested; samples and figures replicate byte for byte; the hand check finds nothing classed wrong.

**Skill.** `measures-check`.

## 11. Store and build

**Aim.** The change register is repeatable, fast enough for a fix round, and shows which built laws are stale and why.

**Inputs.** Everything the build reads: LAT rows, law text, feed, and the three rules stores.

**Outputs.** `provision_changes`, `provision_change_claims`, and a `changes_built` event per law in `lat_events` with the code version and its inputs' fingerprints.

**Check today.**
1. Restore point: `./scripts/nas/nas-backup.sh --tables provision_changes,provision_change_claims,lat_events --tag <tag>`.
2. Build A: `mix lat.vocabulary --check --laws <family and golden laws>`.
3. `mix lat.changes_digest`; build B; digest again; `cmp`.
4. `mix lat.stale`: 0 built laws stale.
5. Golden from inputs, and an agent hand check of a seeded sample of staleness verdicts.

**Pass rule as last used** (2026-10-31). Digests identical; build time accepted by Jason (the OH&S family builds in about 51 s); 0 stale after the build; the hand check finds no verdict wrong; golden all-pass.

**Skill.** `store-build-check`.

## 12. Labels side by side

**Aim.** The new labels are built in the timeline's shape beside the old ones, without writing, so every difference can be counted and later explained.

**Inputs.** The fold's periods (`LabelSource.timeline/1`) and today's `lat_label_timeline`.

**Outputs.** Nothing written. A count of rows that agree, differ today, or differ only in history: the baseline for the switch-over. A retirement list for the old path (`backend/data/reports/change-vocabulary/cv-05-retirement-list.md`).

**Check today.** `mix lat.label_check --family F --strata` ("timeline rows" and the T classes) and golden from inputs. No agent check: the conversion is a fixed mapping under unit tests (`label_periods_test`).

**Pass rule as last used** (2026-10-31). Golden 27/27; 0 periods breaking the timeline table's rules (one period per row on any date, each non-empty, five statuses); differences counted. On OH&S: 28,307 periods, 0 breaks; 16,487 of 20,371 rows differed from today's labels.

**Skill.** None.

## 13. Switch-over

**Aim.** Every difference between the new and old labels is explained, and the family's timeline is then written from the merged changes.

**Inputs.** The new and old labels; the checked rows; the known-limit lists.

**Outputs.** `lat_label_timeline` for the family, written by `LabelRefresh` (with `changed_by_all` and `commenced_by`); the family added to `config :sertantai_legal, :label_families`.

**Check today.**
1. Causes: `mix lat.label_shadow --family F` sorts every differing row by its first difference and the evidence behind the new value.
2. Checked rows: `mix lat.label_checked` compares current labels with every row an agent has judged (`test/fixtures/change_vocabulary/switch_checked.json`).
3. Rules: `mix lat.label_rules` runs each fault class as a check over every row of the family (for example, a change dated before its amending law was made; a period before the row's insertion).
4. Golden from inputs.
5. Dry run: `mix lat.label_switch` (no write) → Jason → restore point (`lat_label_timeline`, `lat_change_log`, `provision_changes`) → the family added to `:label_families` → `mix lat.label_switch --apply`.

**Pass rule as last used** (decided by code, 2026-11-01). Checked rows all match, none left to fix (named known limits apart); the rules show 0 breaches outside the named known limits; golden 27/27. Rows on the known-limit lists (missing repeals, named date gaps) keep their old label. Agents were used only to find new classes. On OH&S: 696 checked rows match, 47 known, 1 upstream.

**Skill.** `switch-over-check`. It still describes the earlier per-cause agent sample and pooled bound; the code-decided pass above replaced it on 2026-11-01, and the next-family version of the skill is still to be written.

---

## How a step is run

This is the process drawn up in the retrospective after OH&S (2026-11-03). The `session-start` command (step session) and each check skill carry it.

**1. Plan mode first.** Before any work, the step is planned in plan mode and Jason approves the plan. The plan states:
- the **aim**, in one sentence tied to [AIMS.md](AIMS.md);
- the **inputs and outputs** (tables and files);
- the **pass rule**, fixed now;
- the **golden set and fixtures**, frozen for the step;
- what is **out of scope** (above all, other steps' code);
- a **time box**;
- **at most 8 todos**.

Changing the pass rule, golden or scope means a new plan, approved again, not an edit in the log.

**2. Checks in code first.** The pass is decided by code wherever possible:
- **table rules**: each fault class written as a check over every row of the family;
- **checked-row fixtures**: rows already judged, with their accepted labels;
- **pattern catalogues**: every form in the whole store, classed, with fixtures;
- **golden from inputs**: the golden set rebuilt from the sources, never only from the store.

**3. Agents only to find new classes.** An agent check is small, on a seeded sample, used to find classes the code doesn't yet know, and its token cost is recorded in the session. It is not a repeated pass gate. One pass at most, never sample → fix → resample (2026-11-05, Maritime Safety's Commencement reader: two rounds, 274k tokens, each finding a few one-law forms). What an agent finds becomes a code check that finds the rest of its class over the corpus, as the commencement catalogues' **leftovers** do (step 4: every word of a statement that bears on a date and that no rule uses, ranked by reach). A plan never says "a fix is followed by a fresh sample".

**4. Bugs are parked by owning step.** A bug in another step's code is raised with the `bug-raise` skill (with a `step:` tag naming the owning step, a class slug, the rows affected) and parked. It is never fixed in the current step unless Jason says so for that bug. Each step's backlog is worked when that step is formally reopened. Single-law wordings and legislation.gov.uk's own data errors below the plan's triage size become named known limits, not fixes.

**5. New work goes to a parking list.** Work found mid-step goes to a `## Parking list` in the session, one line each with its owning step, never to the todos. Per-round logs go to report files; the session keeps decisions, results and pointers.

**6. Ask Jason before long runs.** Rebuilds, read passes, re-parses, fetches and full chains are asked for first, saying the purpose, the time and what they write. Prove a change alters a run before running it.

**7. Restore point before writes.** Before any run that writes, take a restore point of the tables it writes: `./scripts/nas/nas-backup.sh --tables <tables> --tag <tag>` (seconds). Then dry run → Jason → apply.

**8. Questions to Jason in plain words.** Written in the session doc first: the question, the aim it bears on, the options, a recommendation.

Session files: `.claude/sessions/lat-change-pipeline/<date>-<family>-<step-name>.md`, titled "<Family>: <Step name>".

## Running a new family

1. **Prerequisites.** The golden set for the pass is frozen.
2. **Making laws**: every live law decided from its text; the making laws parsed into LAT (fetch and parse with Jason's go).
3. **Sources** until the gate passes (fetches only with Jason's go).
4. **Feed reader**, then **Markup reader**: catalogues first, then the gates, then a small agent sample for new classes.
5. **Commencement reader**: both catalogues, the re-read, the check.
6. **Extent reader**: sweep and catalogue, the extents written, the check.
7. **Amending-law reader**: catalogue, pre-flight, one read pass, rebuild, golden from inputs, strata.
8. **Merge**, then **Evidence**: strata and their checks after a rebuild.
9. **Label fold**: golden from inputs, then S, T and R.
10. **Measures**: every figure the family's steps publish, printed by code and replicated.
11. **Store and build**: two builds, digests compared, staleness, the sources gate re-run.
12. **Labels side by side**: the new timeline beside the old, 0 rule breaks, differences counted.
13. **Switch-over**: causes, checked rows, rules, golden; dry run → Jason → restore point → add the family to `:label_families` → `mix lat.label_switch --apply`.

After a reader fix, rebuild (`mix lat.vocabulary --check --family F`, then `--golden`) so the change register reflects it before the next step looks at it. Each family's new forms extend the catalogues. Steps are batched across families only once families stop surfacing new defects.

A second pass over the steps for OH&S, on the extended golden set (`golden_extended.exs`, 23 more provisions), is still to run.
