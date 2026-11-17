---
session: 'Fire and OH&S: Store and build'
status: closed
opened: 2026-11-16
closed: 2026-11-17
outcome: success
family: 'Fire and OH&S (round)'
parent: lat-change-pipeline/2026-11-13-fire-and-ohs-meta.md

summary: >
  The change register is repeatable (544 digests identical across two builds), timed (544 laws in about 5½ min with
  3 workers) and current (0 of 544 stale), with golden 27/27 by design: TCPA 1990 s.78(4BA)'s pass had rested on a
  wrong W territory, and the reader now reads the Planning (Wales) Act 2015's own s.58(2)(b) (Royal Assent from the
  introduction, a Part written out as its sections, limited items partly in). The two parked bugs are fixed; the
  switched families' refold (2,239 rows) is held to Labels side by side; step close every gate and Checked rows PASS,
  Stale laws 139 (the round's old-path labels, for Switch-over).

decisions:
  - what: "Decision 1: the round's 139 old-path labels left to Switch-over, never relabelled by the old path"
    why: "RULES 16, one relabel per family written once after its pass; Switch-over writes them from the new path"
    result: "no old-path write; Stale laws 139 at the close, named"
  - what: "Decisions 2-3: TCPA s.78(4BA) made right by design, not parked and not by changing Evidence's stages-go-with-the-date"
    why: "Jason: golden confirmed 27/27 by the law's text (s.58(2)(b), Royal Assent 6 July 2015); the earlier pass was by accident"
    result: "three reader rules (RULES §2); golden 27/27 from the store and from inputs"
  - what: "Decision 4 (b): the limited-item regression fixed first; the switched families' refold held to Labels side by side"
    why: "the Part write-out let a misread purpose-limited item date whole Parts (NERC s.89A); a dozen of the refold's 2,239 rows' groups unexplained"
    result: "ListItems fix (2 rules); no label written in the step; --strict --switched deferred"

metrics:
  stale_before: { built: 544, stale: 377, reason: commencement_reader, extent_reader: 6, switched_labels_stale: 388 }
  rereads: { first: { laws: 1516, rules: 24301, minutes: 3.5 }, store_wide: { commenced_laws: 1957, readings: 50195, minutes: 21, extents_minutes: 14 } }
  royal_assent: { needs: 20, fetched: 20, dated: 19, absent_upstream: 1, not_stated: 1 }
  build: { laws: 544, a_seconds: 355, b_seconds: 315, round_seconds: 36, workers: 3, failed: 0 }
  repeatable: { built_laws: 544, identical: 544 }
  stale_after: { built: 544, stale: 0, switched_labels_stale: 388, round_old_path_labels: 139 }
  fix_reach: { laws: 11, changes: 204, regressions_found: 1, regressions_fixed: 1, parked_misreads: 1 }
  part_items: { items: 178, limited: 34, left_misread: 0 }
  switched_dry_run: { ep_rows: 1712, occupational_rows: 333, maritime_rows: 194, laws: 30, held: true }
  gates: { round: "all PASS", maritime: "all PASS", ep_failing: 3, occupational_failing: 2, parked: 5 }
  hand_check: { seed: 1117, items: 30, byte_identical: true, checked_by_sql: 3, ok: 3, agent_tokens: 0 }
  golden: "27/27 from the store and from inputs"
  tests: { mix_test: 11267, skipped: 2 }
  fixer_tokens: { calls: 3, total: 458000 }

lessons:
  - title: "A golden pass can rest on a wrong reading"
    detail: "TCPA s.78(4BA) passed only because the Welsh orders were misread as W, which made WSI 2017/546 date nothing and left the feed's stage standing. When the territory was read rightly, golden fell. Before treating a golden failure as a regression, check whether the earlier pass came from the law's own words."
    tag: data
  - title: "Read a fix's reach change by change, never by input"
    detail: "Classing the moved laws by 'each reads a source the fix changed' called all 11 explained. Comparing each law's stored changes with the restore point's found a regression: the Part write-out let a misread purpose-limited item (Agriculture Act 2020 s.57(1)(b)) date whole Parts on Royal Assent."
    tag: tooling
  - title: "Widening a rule's reach exposes the readings it now reaches"
    detail: "Writing Parts out as sections made 185 previously inert dated Part rules effective. A reach-widening fix needs a check over the readings it activates (the --part-items check), not only the cases it was written for."
    tag: data
  - title: "A reader file in law_start stales every reading and every build"
    detail: "law_start/*.ex is in the commencement, extent and build versions. Each of the three fixes needed a store-wide re-read (about 21 min, 14 of it extents) and a rebuild of all 544 laws (about 6 min). Batch reader fixes before the re-read."
    tag: tooling
  - title: "A switched family's stored labels carry every step since their last refresh"
    detail: "EP's, Occupational's and Maritime's labels were last written on 2026-11-12/13, so the refold's 2,239 rows mixed nine steps' fixes. Explaining them is the side-by-side comparison's job, done once, not a Store and build check."
    tag: data

bugs:
  - pattern: "--family matches by substring: --family \"OH&S\" built four OH&S families (189 laws, 40 extra) in the Evidence rebuild; --family FIRE took in both FIRE families"
    category: family-scope-substring
    module: change_vocabulary/rounds.ex (Rounds.resolve/2), amendment/pattern_source.ex (family_filter/2,3)
    affected: every --family task (one scope point)
    fix: "exact name, or the one family the name is part of; refused, naming the families, when in several or none (126ead5f)"
    step: Store and build
    status: fixed
  - pattern: "mix lat.vocabulary --build printed 'built 117 laws in 0.1 s' with every law FAILED ('no stored CLML body', files present) and exited 0"
    category: build-reports-success-on-all-failed
    module: mix lat.vocabulary (build_summary/4)
    affected: 1 build (Maritime, Amending-law reader write 3)
    fix: "the summary counts failures and the task exits non-zero on any (126ead5f); the cause of the missed body was not found (the store's paths are relative to the backend, like the whole CLML store) and is left named: a recurrence now stops the chain"
    step: Store and build
    status: fixed
  - pattern: "A list item limited by the Acts it amends or the section it repeals is read as the whole Schedule: GoWA 2006 s.161(3) 'the repeal by Schedule 12 of section 80 of the Government of Wales Act 1998 … and the amendments in the Local Government, Planning and Land Act 1980, the Local Government Finance Act 1988 and the Housing Act 1988 made by Schedule 10' is stored as scope sch.12, sch.10 whole, so TCPA 1990 s.321B(2), (5) (Sch.10 para.35) date 2007-04-01, not with the Act after the 2007 election"
    category: schedule-item-limited-by-named-acts-read-whole
    module: law_start/list_items.ex, commencement/own_clause.ex (OwnClause)
    affected: "2 TCPA changes seen (not switched; no label written); reach unknown"
    fix: "an item 'the amendments in <Acts> made by Schedule N' or 'the repeal by Schedule N of <provision>' scopes only those entries (or stays qualified), never the whole Schedule"
    step: Commencement reader
    status: open
  - pattern: "Part-scoped commencement rules written by orders are not written out as the Part's sections (PartScope runs only in AmendingRead): 63 rules in 19 laws"
    category: part-rule-misses-amending-section
    module: commencement/order.ex (orders' rules), commencement/part_scope.ex
    affected: 63 rules, 19 laws
    fix: "write out an order's Part refs for an amending law with no LAT rows, as AmendingRead does"
    step: Commencement reader
    status: open
  - pattern: "Two Royal-Assent-relative own clauses not read: 2011 c.19 s.38(1) (the day follows the qualifier: 'comes into force, for the purposes of …, on the day on which this Act is passed') and 2012 c.21 s.122(2) (the Act's own 'beginning with day on which', no 'the')"
    category: royal-assent-day-unread
    module: commencement/own_clause.ex
    affected: 2 laws
    fix: "one-law wordings below the triage size: known limits (RULES), unless the form recurs"
    step: Commencement reader
    status: open
  - pattern: "402 Acts in uk_lrt hold no made or enactment date (e.g. anaw 2015/4, whose current CLML body has none; its enacted version's ukm:EnactmentDate is 2015-07-06)"
    category: register-act-date-missing
    module: register (uk_lrt metadata scrape)
    affected: 402 Acts
    fix: "fill md_made_date (Royal Assent) for Acts from the enacted version's EnactmentDate or the introduction's DateOfEnactment"
    step: Register
    status: open
  - pattern: "asp 2002/5's introduction states no Royal Assent date (empty DateText, no EnactmentDate)"
    category: royal-assent-not-stated-upstream
    module: (legislation.gov.uk)
    affected: 1 law
    fix: "known limit"
    step: Sources
    status: open
  - pattern: "Environmental Protection's sources gate after this step's rebuilds: EU 2019/1010's Schedules not fetched (for EU Directive 2010/63), SI 2018/369's Schedules stale (for EA 1995): the backlog needs the rebuilt changes add"
    category: sources-fetch-failures-swept-each-step
    module: mix lat.sources --fetch
    affected: 2 documents
    fix: "the next step's first todo fetches them (RULES sources-fetch-failures-swept-each-step)"
    step: Sources
    status: open
  - pattern: "EP amending gate, 1 group not named after the rebuild: operation repealed/repealed_in_part @ 1999 c.28 (EA 1995 s.42(3)(b)(ii), Sch.6)"
    category: amending-gate-group-not-named
    module: amendment/ (disagreements.json naming)
    affected: 1 change
    fix: "read the instruction; name the group or fix the misread"
    step: Amending-law reader
    status: open
  - pattern: "Occupational extent gate, 1 cause not named after the rebuild: none:law_not_held @ SI 2006/475 (2 changes)"
    category: extent-cause-not-named
    module: amending_law/extent (withheld.json), or Sources (the law not held)
    affected: 2 changes
    fix: "hold SI 2006/475 (Sources) or name the cause"
    step: Extent reader
    status: open
  - pattern: "Occupational amending gate, 1 group not named after the rebuild: no operation from legislation.gov.uk: substituted words @ 1997 c.42 (HSWA s.52(1)(b), s.2)"
    category: amending-gate-group-not-named
    module: amendment/ (disagreements.json naming)
    affected: 1 change
    fix: "read the instruction; name the group or fix the misread"
    step: Amending-law reader
    status: open
  - pattern: "An amending law's purpose-limited first stage is held as a commencement rule but no partial commencement change is emitted for the provisions it inserts (MSA 1995 s.255N by 2011 c.8)"
    category: amending-law-staged-start-dropped
    module: commencement/amending.ex (Commencement.Amending)
    affected: 21 Maritime Safety text changes
    fix: "already carried in the changes (Readers.AmendingCommencement.stages, Label.Stages): s.255N reads partial from 2015-02-05 from the inputs; the stored labels follow at the switched refold (Labels side by side, Decision 4 b)"
    step: Commencement reader
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/rounds.ex
  - backend/lib/sertantai_legal/scraper/amendment/pattern_source.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/lib/sertantai_legal/scraper/commencement/part_scope.ex
  - backend/lib/sertantai_legal/scraper/commencement/amending_read.ex
  - backend/lib/sertantai_legal/scraper/law_start/date_of_enactment.ex
  - backend/lib/sertantai_legal/scraper/law_start/input.ex
  - backend/lib/sertantai_legal/scraper/law_start/list_items.ex
  - backend/lib/sertantai_legal/scraper/sources.ex
  - backend/lib/sertantai_legal/scraper/sources/held.ex
  - backend/lib/sertantai_legal/scraper/commencement/review/part_items.ex
  - backend/lib/mix/tasks/lat.commencement_check.ex
  - backend/data/reports/store-and-build/
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/store-build-check/SKILL.md

depends_on:
  - 2026-11-16-fire-and-ohs-measures.md

enables:
  - "Fire and OH&S: Labels side by side (the round, plus the switched families' held refold: 2,239 rows to explain)"
---


# Session: Fire and OH&S: Store and build (CLOSED)

## Problem

Step 11 of the LAT Change Pipeline for the Fire and OH&S round: the change register must be repeatable, timed and honest about staleness, and the three switched families, left one reading behind (Feed reader, Decision 5 b), are rebuilt once here. Today 377 of 544 built laws are stale on older Commencement reader readings (Occupational 122, EP 115, Maritime 117, 23 others; 6 also on the Extent reader), and the 388 switched laws' labels are stale. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`, approved by Jason on 2026-11-16.

## Todo

- ✅ Open the session and meta row; the two parked bugs test first (family scope exact or one family; build failures counted, non-zero exit); `mix test`; code commit
- ✅ Pre-flight (read-only): `lat.stale --list`; the stale builds' old-version sources by mode; the 6 extent-stale laws' amenders
- ✅ Restore point; the re-reads in their modes, `lat.stale` after each round, to 0 reader-stale (Jason's go)
- ✅ Build A of the stale built laws (changes only); `--check --family "Fire and OH&S"`; digest A (Jason's go): golden 26/27 → Decisions 2, 3; digest kept as `A0`
- ✅ (amended plan) The fix by design: a Part-scoped rule reaches an amending law's sections; an Act's Royal Assent from its own `DateOfEnactment`; Sources' introduction need (fixer, test first); `mix test`; code commit
- ✅ (amended plan) Fetch the introductions; store-wide re-read by mode; `lat.stale` 0 on a reader (Jason's go)
- ✅ (amended plan) Build A again; `--check`; golden 27/27; digest A against A0, every moved law classed (Jason's go)
- ✅ The switched labels' dry run: 2,239 rows, groups sampled (Decision 4)
- ✅ (Decision 4 b) The misread purpose-limited Part item fixed in the own-clause reader, test first; a code check of every Part rule's item words; re-read and rebuild
- ⏸️ The switched families' refold: held to Labels side by side (Decision 4 b)
- ✅ Build B and verify: digest B `cmp` A; `lat.stale`; the switched families' gates; golden from inputs; hand sample at seed 1117 twice, 3 items by SQL
- ✅ Step close: `mix lat.step_close --family "Fire and OH&S" --step "Store and build"` (Jason's go)
- ✅ Docs and close: skill history, WORKFLOW step 11, meta row, bugs; commits by path; no push unless asked

## Dependencies

- ✅ Fire and OH&S: Measures closed and pushed (4964d636)
- ✅ Environmental Protection: Store and build (the restore schema, the re-read-in-its-mode lesson)

## Decisions

### Decision 1: the round's 139 old-path labels (DECIDED: leave to Switch-over, Jason 2026-11-16)

- **Question.** The round's 139 laws are stale only on `labels_version`: labels written by older old-path code. Relabel them now, or leave them to Switch-over?
- **Aim.** `binds-on-date`; RULES 16 ("one relabel per family, written once after its pass").
- **Options.** (a) leave them to Switch-over, which writes them once from the new path; (b) relabel through the old path now, and so write them twice.
- **Decided: (a).** No old-path write in this step; the step close's Stale laws line names them as Switch-over's.

### Decision 2: golden 26/27 after the re-read (TCPA 1990 s.78(4BA))

- **What happened.** Build A's check (logs `fire-and-ohs-build-a-*.log`): 377 + 139 laws built, 0 failed (258 s and 33 s, 3 workers); all nine gates PASS; golden from the store **26/27**. TCPA 1990 s.78(4BA) (inserted by the Planning (Wales) Act 2015, anaw 2015/4 s.47(1)) expects partly in force from 2015-09-06 and fully from 2017-05-05 by WSI 2017/546. It now reads in force from 2017-05-05 only, with no partial period, and its "by" also names WSI 2017/548 and 2017/553.
- **Cause** (the restore point's dump against the store, read as text):
  1. The re-read wrote anaw 2015/4's order readings with no territory (they were W). That is the round's Commencement reader rule, deliberate: a Welsh order on a Senedd Act commences it wherever the Act extends (`Order.Territory.of_type/2`, a9af8e41).
  2. While WSI 2017/546 was read as W, it was "a one-territory order" and dated nothing, so the feed's staged date stood (inserted 2015-09-06, partial). Now the order dates the insertion fully from 2017-05-05 (date from the commencement), and the feed's earlier partial stage is dropped.
  3. That drop is the parked Commencement reader class `amending-law-staged-start-dropped` ("the chosen date is the later full stage and the partial period is lost"), which already names TCPA 1990 s.252(12). The territory fix has widened its reach to a golden provision.
- **Why it shows only now.** The round's Commencement reader re-read the round and its sources, not TCPA's sources. Golden from inputs used the stored, older readings, so it passed until today's re-read.
- **Live labels.** None move: Town and Country Planning is not switched.
- **Aim.** `binds-on-date`: the partial period 2015–2017 is a real answer the label loses.
- **Options.**
  - (a) Park: add the golden provision to the parked class's reach, and close this step with golden 26/27 named, fixed when the Commencement reader is next reached. Golden then fails at every step until that fix.
  - (b) Fix in-step on Jason's go for this bug: one lean fixer call on `amending-law-staged-start-dropped`, so a later order's full date keeps the feed's earlier partial stage. Test first; affected laws rebuilt; golden 27/27. About an hour more, plus a rebuild of the reach.
- **Decided: (b)** (Jason 2026-11-16). One lean fixer call (Fable), brief `scratchpad/fixer/evidence.md`.
- **Recommendation: (b).** Golden is the step's frozen truth, and the class is already known with a test case (MSA 1995 s.255N). Parking it would leave golden failing through Labels side by side and Switch-over, where 27/27 is part of the pass.

**The fixer's finding (117k tokens, no code changed; checked by me in SQL).** It is not the parked class: MSA 1995 s.255N already reads partial from 2015-02-05 from the inputs. TCPA s.78(4BA) fails through three links:
1. **Evidence, by decided rule:** `stages-go-with-the-date` (Evidence Decision 2 a) takes stages only from the date's source, so once WSI 2017/546 dates the insertion, the feed's 2015-09-06 stage goes.
2. **No Royal Assent date:** anaw 2015/4 s.58(2)(b) brings Parts 3–8 in "so far as is necessary for enabling the Welsh Ministers to make regulations or orders" two months after Royal Assent. The rule is held (`provision_qualified`, pt.3–pt.8), but its day is `unread`, because `uk_lrt` holds no made or enactment date for the Act and its CLML has no `ukm:EnactmentDate`. s.58(1) is `clause_unread` for the same reason.
3. **A Part-scoped rule never reaches a section of an amending law:** `Readers.AmendingCommencement` evaluates with `Order.context/0`, whose ancestors cover Schedule paragraphs only. s.47 sits in Part 7.

Reach: 234 Part-scoped rules in 119 amending laws (link 3); 17 unread own-clause rules counting from Royal Assent in 10 laws, 9 with no date in `uk_lrt` (link 2). So the old pass rested on a wrong reading: the W territory made the order date nothing.

### Decision 3: the TCPA golden provision, after the fixer's finding

- **Question.** The fix Decision 2 (b) asked for is not a small in-step class. What now?
- **Aim.** `binds-on-date` (the partial period 2015–2017), and `fix-where-owned` (RULES 15).
- **Options.**
  - (a) Park two named classes with the Commencement reader: `part-rule-misses-amending-section` (link 3, 119 laws) and `royal-assent-day-unread` (link 2, 10 laws, the missing dates to the Register). This step closes with golden 26/27, named. The Commencement reader's next session fixes both by the law's text, previewed over the 119 laws.
  - (b) Grow this step: a new plan for the law-text fix (a stored Part membership for amending laws, a Royal Assent source, `--read-amending` of the held amenders, a rebuild), approved again. That adds a day or more.
  - (c) Change Evidence's `stages-go-with-the-date` so that an earlier partial feed stage survives a later full date. That is quick, but it reverses a decided rule on feed evidence, against the law-text route.
- **Decided (Jason 2026-11-16): right by design**, neither park nor an Evidence change. Golden confirmed 27/27 as truth; amended plan approved (links 2 and 3 fixed in the Commencement reader, Sources' introduction need, store-wide re-read). Royal Assent 6 July 2015 (legislation.gov.uk enacted `ukm:EnactmentDate`; `DateOfEnactment` in the introduction).
- **Recommendation was (a)** (superseded). This is new reader work with 119 laws in reach, which the rules give to its owning step with its own plan. The golden failure is named, not hidden. No live label moves (Town and Country Planning is not switched).

- **Jason (2026-11-16):** "you think it's 27/27. That needs confirming. Then the fix … is to ensure it's right by design."
- **Golden confirmed right** (the law's text and the feed):
  - The stage: anaw 2015/4 s.58(2)(b) brings Parts 3–8 in "so far as is necessary for enabling the Welsh Ministers to exercise any function of making regulations or orders", at the end of two months from Royal Assent. s.47(1), which inserts s.78(4BA), is in Part 7.
  - The feed gives the same: inserted by s.47(1), 2015-09-06 "for specified purposes", then 2017-05-05 "in force in so far as not already in force". legislation.gov.uk's note says "in force for specified purposes at 6.9.2015, see s. 58(2)(b)".
  - The full date: WSI 2017/546 reg.3, 2017-05-05.
  - The extra "by" in today's label (WSI 2017/548 and 2017/553) are 2017-05-05 effects with no operation on s.78 (the parent) and s.79. They join only because the period now starts that day; this is to be confirmed after the fix.
- **Right by design:**
  - The Commencement reader reads s.58(2)(b) itself. It needs a Royal Assent day for the Act (link 2) and a Part-scoped rule that reaches the Part's sections in an amending law (link 3).
  - The 2015 stage and the 2017 date then share one source, the commencement, so Evidence's `stages-go-with-the-date` keeps both, unchanged.
  - This grows the scope, so the plan is to be approved again (amended plan).

## Pass rule (DECIDED: plan approved, Jason 2026-11-16)

1. **Repeatable:** digests after builds A and B identical (`cmp`), every built law.
2. **Timed:** each build's wall time, workers and failures (0); Jason accepts the time.
3. **Not stale:** 0 built laws stale in the change register; `--strict --switched` exit 0; the round's 139 old-path labels named for Switch-over.
4. **Switched labels explained:** every row `label_switch --stored` would move is explained by a named earlier step, or parked and brought to Jason before the write.
5. **Gates:** the round's every gate PASS; the switched families' gates PASS or already parked; a new failure parked with its owner.
6. **Golden** 27/27, from the store and from inputs.
7. **Hand check, no agent:** the stale sample at seed 1117 drawn twice, `cmp`; 3 items checked by SQL.
8. **No regression:** `mix test`; Credo ratchet; the two parked bugs fixed with tests.

## Parking list

## The two parked bugs (todo 1, commit 126ead5f)

- **The family scope:** `Rounds.resolve/2` takes a round's families, the family named exactly (marker dropped), or the one family the name is part of. A name in several families or none is refused, naming them. `PatternSource.family_filter/2,3` match the resolved names exactly. On the register: the round 139 laws, `FIRE` 26 (the substring took in 64), `OH&S: Occupational` 149 by its short name, `OH&S` refused (4 families).
- **The build summary:** "built N laws in T s (W workers), F failed", and a non-zero exit when F > 0. The missed body's cause was not found; a recurrence now stops the chain.
- Neither file is in a build, reader or fold version: `lat.stale` unchanged (377 of 544). Old-path `labels_version` covers `amendment/*.ex`, but every unswitched law (881) was already stale on it.
- `mix test` 11,242 passed, 2 skipped; Credo diff no new issues; hooks passed.

## Work log (detail: `backend/data/reports/store-and-build/fire-and-ohs-work-log.md`)

- **Pre-flight:** the 377 stale builds read 24,301 commencement readings on EP's 2026-11-11 reader version, in four modes, plus 8 amenders' extents.
- **Restore point** `2026-11-16-store-and-build-fire-and-ohs` (NAS): `commencement_rules`, `extent_rules`, `provision_changes`, `provision_change_claims`, `lat_events`, `lat_label_timeline`.
- **Re-read 1** (3½ min) and **build A** (516 laws, 0 failed; gates PASS): golden 26/27 → Decisions 2 and 3.
- **The fix by design** (d7f62c16, 7a5e4290):
  - a Part's rule written out as its sections (`PartScope`);
  - an Act's Royal Assent from its own introduction (`DateOfEnactment`, `Input.stated_made/1`);
  - Sources' `:royal_assent` need, 20 introductions fetched (19 dated).
- **Re-read 2**, store-wide (21 min), and **build A again** (544 laws in 342 s): golden 27/27.
- **The switched labels' dry run:** 2,239 rows → Decision 4.
- **The limited-item fix** (982af806): `ListItems` reads a relative-clause limit as partly in; the `--part-items` check covers 178 items, none left misread.
- **Re-read 3** and the rebuild (544 laws in 355 s): golden 27/27; NERC s.89A back to 2021-01-11.
- **The fix's reach**, read change by change: 204 changes in 11 laws, all named, one pre-existing misreading parked (GoWA 2006 s.161(3)).

### Decision 4: before any label write

- **Question.** The refold would write 2,239 switched rows, and several groups are unexplained. Link 3 also lets misread purpose-limited items (Agriculture Act 2020) date whole Parts. What now?
- **Aim.** `binds-on-date`: a wrong in-force date is the harm the time machine exists to prevent.
- **Options.**
  - (a) Fix the misread class in the own-clause reader, test first. A list item naming Parts with a limit ("which confers a power …", "so far as …") is qualified, never full. Add a catalogue check over every Part-scoped dated rule, its item words listed in code, so link 3 writes out only plain Parts. Re-read, rebuild, then explain each switched group in turn before the refold, parking any reader class found. About a day.
  - (b) As (a) for link 3, but hold the switched families' refold to Labels side by side (step 12), whose job is this comparison. They stay one reading behind, named (pass rule 3's `--strict --switched` deferred).
  - (c) Revert link 3 (keep link 2 and the Sources need): golden back to 26/27, the TCPA design gap parked.
- **Decided: (b)** (Jason 2026-11-16). The reader fix comes first, test first, with a code check over every Part rule's item words. The switched families' refold is held to Labels side by side (step 12), one reading behind and named; pass rule 3's `--strict --switched` is deferred to that step. No label is written in this step.
- **Recommendation was (b).** The reader fix is this step's own regression and must come first. The 2,239-row explanation is a side-by-side job, best done once with the round's labels at step 12, not row by row here.

## Build B and verify (Jason's go; `fire-and-ohs-build-b.log`, `-B.tsv`, `-gates-*.txt`)

- **Build B:** 544 laws in 315 s, 3 workers, 0 failed. **`cmp A.tsv B.tsv`: identical** (544 laws).
- **Timed:** all 544 in 315–355 s and the round's 139 in 36 s, with 3 workers (the VM down).
- **`lat.stale`:** change register 0 of 544 built laws stale. `--strict --switched` exits 1: the switched families' 388 labels, held to Labels side by side (Decision 4 b). The round shows 139 old-path labels (Decision 1).
- **Golden from inputs:** 27/27 (277 s).
- **The switched families' gates:**
  - Maritime: all nine PASS.
  - EP: Sources 2 (two Schedules to fetch) and Amending-law reader 1 (EA 1995 s.42(3)(b)(ii)).
  - Occupational: Extent reader 1 (SI 2006/475 not held) and Amending-law reader 1 (HSWA s.52(1)(b)).
  - Each is new after this step's re-read and rebuilds, and each is parked with its owner.
- **Hand sample** at seed 1117 (20 built, 10 unbuilt), drawn twice: byte-identical. All 30 verdicts are fresh, or `no_build` for the unbuilt.
  - Checked by SQL: NISR 1995/87 (244 changes = its event's, code 300bde4406cb, built 06:55 after its readings at 05:53); SI 2020/390 (15 = 15, the same); 1994 c.40 unbuilt (34 LAT rows, no changes, no build event). 3/3 OK.

## Step close (`backend/data/reports/store-and-build/fire-and-ohs-step-close-2026-11-17.txt`)

Every gate PASS (Sources, the five readers, Merge, Evidence, the Label fold) and Checked rows PASS. Stale laws FAIL, 139: the round's old-path labels (`labels_version`), with the change register at 0. They are named for Switch-over (Decision 1), as at every earlier close.

## Docs

- **RULES**, §2, three rules: `royal-assent-from-the-acts-own-introduction`, `a-part-reaches-its-sections`, `limited-items-are-partly-in`.
- **WORKFLOW** step 11: the Fire and OH&S note (a reader change re-reads every reading; a fix's reach is read change by change; the refold held).
- **The `store-build-check` skill:** history.
- **DATA-ARCHITECTURE:** no table or flow changed (a new Sources need on an existing path). **GLOSSARY:** no new term.
- **Parking list:** empty. Each finding is a bug entry with its step.
