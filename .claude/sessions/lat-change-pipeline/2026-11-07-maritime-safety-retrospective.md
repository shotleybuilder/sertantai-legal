---
session: 'Maritime Safety: Retrospective'
status: closed
opened: '2026-11-07'
closed: '2026-11-07'
outcome: success
parent: lat-change-pipeline/2026-11-04-maritime-safety-meta.md
summary: 'Maritime Safety, the second family, took 4 days against OH&S''s 14, under the process the 2026-11-03 retrospective
  set; every step met its fixed pass rule and the drift (agent rounds, gates on stale code, rebuild tax) was corrected in-run.
  Housekeeping done: a full NAS snapshot, the October restore points pruned, every open bug owned, three superseded meta sessions
  closed. Next: the Mines Regulations → HSWA fault, #192, #191, then Family 3, Environmental Protection.'
decisions:
- what: Close the three old meta sessions as superseded, carrying their live items to a pending hardening session
  why: the LAT Change Pipeline replaced their plans on 2026-11-03; stale ACTIVE metas mislead (Jason, Decision 1 A)
  result: 2026-11-07-production-hardening-and-integration.md (pending)
- what: Delete the October NAS restore points
  why: today's verified full snapshot holds a later state (Jason, Decision 2 B)
  result: 109 → 21 restore points, 2.3G → 760M
- what: 'Before Family 3: the Mines Regulations 2014 → HSWA repeals-table fault, then #192, then #191; Family 3 is ENVIRONMENTAL
    PROTECTION'
  why: the fault blocks any OH&S relabel; the third run is the last before hardening, so it should test a different kind of
    law (Jason, Decision 3 A)
  result: order in memory and the meta session
metrics:
  comparison:
    ohs_days: 14
    maritime_days: 4
    ohs_sessions: 33
    maritime_sessions: 18
    ohs_session_lines: 10863
    maritime_session_lines: 3748
    ohs_commits: 623
    maritime_commits: 55
  bugs:
    open_before: 109
    without_step_before: 25
    without_step_after: 0
    recovered_from_bad_yaml: 10
  nas:
    snapshot_tables: 41
    snapshot_rows: 2963975
    restore_points_before: 109
    restore_points_after: 21
lessons:
- title: A session whose frontmatter isn't valid YAML drops its bugs from the index silently
  detail: 'Two closed sessions (Maritime Extent reader, commencement reader-misses) held unquoted values with '': '' and 10
    bugs were missing from open_bugs; the indexer only warned on stderr. session-close now says read the output and confirm
    the bugs were indexed.'
  tag: tooling
- title: 'The process reset worked: plan first, checks in code, bugs parked by step'
  detail: 13 of 14 steps closed the day they opened; agent tokens fell to 0 in the last three steps; no step's scope grew
    without approval.
  tag: tooling
- title: The full NAS snapshot was two weeks stale through two switch-overs
  detail: Restore points covered each apply, but the full snapshot dated 2026-10-24. WORKFLOW's new-family item 14 now takes
    a full snapshot at each retrospective.
  tag: infrastructure
artifacts:
- .claude/sessions/2026-11-07-production-hardening-and-integration.md
- .claude/commands/session-close.md
- docs/lat-change-pipeline/WORKFLOW.md
depends_on:
- lat-change-pipeline/2026-11-04-maritime-safety-meta
- archive/change-vocabulary/2026-10-30-cv-s12-retrospective
enables:
- 'OH&S: Amending-law reader repair (Mines Regulations 2014 → HSWA)'
- 'GitHub #192, #191'
- 'Family 3: ENVIRONMENTAL PROTECTION'
- 2026-11-07-production-hardening-and-integration
---

# Session: Maritime Safety: Retrospective (CLOSED)

## Problem

Maritime Safety, the second family, went through all 14 steps in 4 days (2026-11-04 to 11-07), against OH&S's two weeks. It was the first run under the process the 2026-11-03 retrospective set. Jason (2026-11-07): "much smoother than the first. We learned the lessons and implemented well. Some drift but course corrected. Issues arising are bugs here or raised." This session records what worked and where the drift was. It also does the housekeeping the run left, NAS backups first, and settles the work list before Family 3. Production hardening and integration with sertantai-compliance and fractalaw come after the third family, so here they get only a pointer.

## Todo

- ✅ Compare Maritime with OH&S from the meta session's step-status table: days, sessions, session lines, commits, agent tokens, plan changes, bugs parked. Note what worked, where it drifted and how it was corrected
- ✅ Bugs audit: 2 sessions' YAML fixed (10 bugs back in the index); 25 open bugs with no step given an owner; 109 open, all owned; session-close now stops on a YAML warning
- ✅ NAS: a full snapshot (2026-11-07, `--archive`, checksums verified: 41 tables, 2.96M rows); the 88 October restore points deleted (Decision 2), leaving 21 (760M)
- ✅ Sessions: the three stale meta sessions closed as superseded (Decision 1), their live items carried to item 7; the Maritime meta session closed
- ✅ Docs and memory: WORKFLOW (new-family item 14, retrospective and housekeeping; gates run on the final code), `session-close` (read the index output), the pickup memory
- ✅ Before Family 3 (Decision 3): the Mines Regulations 2014 → HSWA fault first, then #192, then #191; Family 3 is ENVIRONMENTAL PROTECTION
- ✅ After Family 3: `.claude/sessions/2026-11-07-production-hardening-and-integration.md` (PENDING), holding the old metas' live items
- ✅ Close: session and meta commits (no push unless asked)

## Dependencies

- ✅ Maritime Safety switched over (2026-11-07, ecc3eaf8 pushed)
- ✅ OH&S retrospective as the baseline: `archive/change-vocabulary/2026-10-30-cv-s12-retrospective.md`

## Facts at opening (2026-11-07)

- **The run:** 15 Maritime session files and 3,165 session lines; 55 commits since 2026-11-04, against 747 for the change-vocabulary period (2026-10-17 to 11-03).
- **Open bugs by step:** Amending-law reader 21, Commencement reader 15, Label fold 7, Feed reader 6, Store and build 5, Extent reader 5, Merge 4, LAT parser 4, Register 3, Markup reader 3, Sources 2, Old label path 2, Measures 1, Evidence 1, and 25 with no step.
- **NAS:** `snapshots/latest` is dated 2026-10-24. There are 109 restore points (2.3G), and `archive/` was last written 2026-11-03.

## 1. Maritime compared with OH&S

| | OH&S (first family) | Maritime Safety (second) |
|---|---|---|
| Calendar days | 14 | 4 (2026-11-04 to 11-07) |
| Sessions | 33 | 18 (14 steps, the meta, 3 commencement-leftover sessions) |
| Session lines | 10,863, several over 1,000 | 3,748, the largest 318 (Switch-over) |
| Commits | 623 | 55 (36 code or docs, 19 session) |
| Pass rule met | rules moved about four times | all 14 steps, as planned |
| Plan changes | not tracked | 6 over 14 steps, each approved |
| Agent tokens | not recorded (about 120 runs in the label fold alone) | 1.49M in 8 steps; 0 in the last 3 (Gemini 9,097) |
| Bugs | chased across steps | 31 fixed in their own step, 34 parked by step, 2 moved |

**What worked:**
- **A step is a session, planned first.** Each step was planned in plan mode with a fixed pass rule, and 13 of the 14 closed the day they opened. No step's scope grew without a new approval.
- **Checks in code.** From the Extent reader on, each gate was code. Agent use shrank to one costed pass, and the last three steps needed none.
- **Bugs parked by step.** Faults in other steps' code were raised and parked, not chased. The two fixed in another step (the feed locator and the start stored with the build) were fixed only with Jason's leave for that bug.
- **Decisions in plain words.** Each was written in the session with its aim and options. Gemini was used once for a second view (Switch-over, Decision 2).
- **Checked rows carry over.** OH&S's checked rows caught a regression from another step during Maritime's switch-over (the Mines Regulations 2014 repeals table on HSWA).

**Where it drifted, and how it was corrected:**
- **Agent rounds in the Commencement reader.** Sample, then fix, then resample ran twice before Decision 2 stopped it. It became a code check over every statement, in three side sessions on 11-05. That set the rule of one agent pass at most, never sample → fix → resample (memory: checks in code).
- **Gates passed on code that later changed.** Measures found 3 gates, passed eight steps earlier, failing on today's code. Now the gates run on the final code (Store and build lesson), and the not-re-run gates are parked with Store and build.
- **The rebuild tax.** Any edit under `change_vocabulary/` or `law_start/` stales all 285 built laws, so each fix cost a 13-minute rebuild. Four steps hit this. It is parked with Store and build, and its run time is #191.
- **Checks that repeat the same fold.** Each label tool folds the family again, one law at a time, about 12 minutes each. Switch-over ran six of them. This is #191.
- **Proof by the wrong tool.** `--strata` can't show a switched family agreeing, so the after-apply check was a scratch script. A task for it is parked.
- **Bugs lost from the index.** Two closed sessions had frontmatter that wasn't valid YAML, so 10 bugs were missing from the index. Found today and fixed: see item 2.

## 2. Bugs audit

- **The cause:** the indexer skips a session whose frontmatter isn't valid YAML, and warns only on stderr, which nobody read at close. The Maritime Extent reader (`module:` holding `--family "OH&S: …"`) and the commencement reader-misses session (`stay fix:`) were missing, with 5 bugs each. Both values are quoted now. `session-close` step 8 now says to read the output, fix any YAML warning and confirm the bugs were indexed.
- **25 open bugs had no step.** They were outside the pipeline or from before steps existed. Each now names its owner (bug-raise's area names): fractalaw 7, Definitions 6, Old label path 4 more, Register 3 more, Markup reader 2 (#187, #188), LAT parser 1, sertantai-compliance 1 and Docs 1.
- **Now:** 109 open bugs, every one owned. The largest owners are the Amending-law reader (22), Commencement reader (17), fractalaw (7) and Label fold (7).

## Decisions for Jason

### 1. The three old meta sessions still ACTIVE — DECIDED 2026-11-07

**Decided (Jason, 2026-11-07): A.** All three closed as superseded; their live items are in `2026-11-07-production-hardening-and-integration.md`.

- **The question:** what happens to LAT hand-off (2026-10-08), LAT parser refactor (10-09) and Pipeline to v0.1 (10-21)? The LAT Change Pipeline replaced their plans on 2026-11-03, but they are still ACTIVE.
- **The aim:** sessions are the record a fresh reader acts on; stale ACTIVE ones mislead.
- **What they still hold that is live:**
  - Welsh SI duplicates (#178);
  - the contract to fractalaw and the delta sync carrying `lat_label_timeline` in place of `lat.status`, `effective_from` and `changed_by`;
  - production: the partition migration (#133) and the prod data sync (#27);
  - v0.1 sign-off.

  The rest (QA runs, guides, timeline gap classes) is done another way by the pipeline.
- **Options:**
  - A: close all three as superseded, with their live items carried into the production-hardening PENDING stub (item 7);
  - B: suspend them, leaving them as they are;
  - C: leave them ACTIVE.
- **Recommendation: A.** Their live items are exactly the integration work for after Family 3, so they should sit in one place.

### 2. The NAS restore points — DECIDED 2026-11-07

**Decided (Jason, 2026-11-07): B.** The 88 October restore points were deleted after today's full snapshot was verified; the 21 from November are kept (760M).

- **The question:** should the 109 restore points (2.3G: 88 from October, 21 from November) be pruned?
- **The aim:** every apply can be rolled back (memory: backup finesse).
- **The facts:** the NAS is 2% full (111G of 5.5T). Today's full snapshot covers everything since 2026-10-24, and the old `latest` moved to `archive/` (37 snapshots there, 4.1G).
- **Options:**
  - A: keep them all, and set a retention rule at production hardening;
  - B: delete the October restore points, since today's full snapshot holds a later state;
  - C: keep each family's switch apply and delete the rest older than 30 days.
- **Recommendation: A.** Space isn't short, and a deleted restore point can't come back. A retention rule belongs with production hardening, where backups become an operations matter.

### 3. The work before Family 3, and which family is third — DECIDED 2026-11-07

**Decided (Jason, 2026-11-07): A, ENVIRONMENTAL PROTECTION,** and the order as recommended.

- **The question:** what order does the work before Family 3 go in, and which family is third?
- **The aim:** binds-on-date (the family's labels), plus a workflow fast enough to run on every family.
- **The order (recommendation):**
  1. **The Mines Regulations 2014 repeals-table fault** (Amending-law reader, urgent). A rebuild today would wrongly repeal 6 HSWA rows, which blocks any relabel of 11 OH&S laws. Family 3's checked rows would flag it again. It is small, a one-step session: "OH&S: Amending-law reader repair".
  2. **#192, the Python checks moved to Elixir** (store scan, shape mining, census), with Flow where a whole-store scan fits.
  3. **#191, check run time:** profile with Benchee, fold once per family run, bounded parallel folds. It comes after #192 so that the checks it speeds up are the Elixir ones.
- **Which family (laws with LAT rows today; Making laws will add more, as Maritime grew from 16 to 117):**
  - A: **ENVIRONMENTAL PROTECTION** (415 live laws, 58 with rows), the first 💚 family. It brings new shapes (Welsh and Scottish law, EU retained environmental law) before the workflow is hardened.
  - B: **FIRE: Dangerous and Explosive Substances** (124 live laws, 36 with rows), close to OH&S. It shares the HSWA amenders, so it is the smaller and safer run.
  - C: **PUBLIC: Building Safety** (155 live laws, 44 with rows).
- **Recommendation: A.** The third run is the last before hardening, so it should test the workflow on a different kind of law. A third family close to OH&S would teach the least.
