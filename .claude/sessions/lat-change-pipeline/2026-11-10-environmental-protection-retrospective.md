---
session: 'Environmental Protection: Retrospective'
status: closed
opened: '2026-11-10'
closed: '2026-11-12'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'
parent: lat-change-pipeline/2026-11-08-environmental-protection-meta.md
summary: >
  Environmental Protection, the third family, took 5 days with every pass rule met and 0 plan changes; reviewed from its
  53 step lessons: checks in code caught all six over-reaching fixes, while cold runs, version cascades and gates drifting
  after their step cost the most. Bugs: 13 new closed, 41 new parked, 24 existing fixed, 79 existing parked (120 open,
  from 109). Decided: the review tooling next, then a few QQ register families one at a time fixing the backlog, then
  production hardening as one process, then the rest; a model-per-part pilot after the tooling.
decisions:
  - what: 'Next families: a few from the QQ legal register, one at a time, each step fixing its own parked bugs; then the rest of the register'
    why: 'the backlog grew 109 to 120 while finding outpaced fixing; reliability first (Jason, Decision 1, his own option; corpus-wide reader rounds not taken now)'
    result: WORKFLOW "The order after Environmental Protection"
  - what: 'Pilot one step of the next family as a scripted workflow with a model per part: Fable for code, Opus 5.5 for the session and pass/fail, smaller models for paperwork and report summaries'
    why: 'most of a step is runs and paperwork; judgement stays on the top model (Jason, Decision 2 A with the models named)'
    result: 'after the review tooling; measured against EP''s row for that step'
  - what: 'Order: review tooling, QQ families, production hardening, the remaining families'
    why: '"production hardening means running all steps as one process. We''re not good enough to do that yet" (Jason, Decision 3)'
    result: hardening session's dependencies and todos updated
  - what: 'The review''s proposed changes routed: pre-flight and step-close check tasks to the review tooling; dry runs that write and exact family names parked with their owners; sizing by reach in WORKFLOW'
    why: 'lessons that repeated inside one family (architecture tests first; gates re-run) must become code (Jason, yes to routing)'
    result: 2 tooling todos, 3 bugs parked, 1 WORKFLOW line
metrics:
  run: { days: 5, steps: 14, closed_same_day: 11, pass_rules_met: 14, plan_changes: 0, session_lines: 4126, commits: 37, agent_tokens: 1000702, laws_switched: 122 }
  bugs: { new_closed: 13, new_parked: 41, existing_fixed: 24, existing_parked: 79, moved: 6, open_before: 109, open_after: 120, commencement_reader_open: 29 }
  nas: { snapshot: '2026-11-12T16:01', tables: 41, verified: true }
lessons:
  - title: A retrospective drawn from memory repeats the last one; draw it from the step lessons
    detail: 'The first pass of this review was the measures table and two paragraphs in Maritime''s terms; Jason asked whether the retrospective had actually been run. The 53 lessons in the session index gave the real themes (cold runs, drift, dry runs that write, sizing by intent) with their evidence.'
    tag: tooling
  - title: A lesson repeated inside one family must become code
    detail: '"Run the architecture tests before applying" was learned in Making laws (11-08) and paid again in the Amending-law reader (11-10); gates drifting after their step was Maritime''s lesson and recurred. Both are now review tooling tasks (pre-flight, step-close check).'
    tag: tooling
  - title: Four-way bug status needs pattern or class matching across sessions
    detail: 'A fixed entry often rewords the original pattern; matching on the class slug as well found 24 existing fixed. 23 entries in two Amending-law reader sessions named no owning step, and are now owned.'
    tag: tooling
bugs:
  - pattern: "The commencement and order catalogues' dry runs write patterns, examples, laws and leftover groups whether or not --accept is given (only expected.json waits); a dry run must write nothing (Environmental Protection: Commencement reader lesson)"
    category: catalogue-dry-run-writes
    module: lib/mix/tasks/lat.commencement_patterns.ex, lat.order_patterns.ex
    affected: every catalogue dry run
    fix: "write only with --accept, or to --out by default"
    step: Commencement reader
    status: open
  - pattern: "The register stage's dry-run re-read of statistics (StagedParser :amended_by) refreshes the stored feeds and a re-scrape re-decides live status (persist_direct runs LiveStatus): two EP laws' stored changes went one feed behind, two SIs became revoked unasked (Environmental Protection: Sources lesson)"
    category: register-dry-run-writes
    module: register staged parser (StagedParser, persist_direct)
    affected: 2 laws behind, 2 re-decided (EP)
    fix: "a dry run reads feeds without storing them; live status printed before and after, re-decided only when asked"
    step: Register
    status: open
  - pattern: "--family matches by substring: --family \"OH&S\" built four OH&S families (189 laws, 40 extra, 9,713 changes) in the Evidence rebuild"
    category: family-name-substring
    module: the tasks' family lookup (amendment/pattern_source.ex LIKE '%' || $1 || '%', and the like)
    affected: 40 laws built unasked (EP Evidence)
    fix: "exact family name; refuse a name matching more than one family unless --prefix"
    step: Store and build
    status: open
artifacts:
  - backend/data/reports/retrospective/environmental-protection-bugs.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/sessions/lat-change-pipeline/2026-11-10-amending-law-reader-review-tooling.md
  - .claude/sessions/2026-11-07-production-hardening-and-integration.md
depends_on:
  - lat-change-pipeline/2026-11-12-environmental-protection-switch-over
  - lat-change-pipeline/2026-11-07-maritime-safety-retrospective
enables:
  - lat-change-pipeline/2026-11-10-amending-law-reader-review-tooling
  - 'a few QQ register families, one at a time'
  - 2026-11-07-production-hardening-and-integration
---

# Session: Environmental Protection: Retrospective (CLOSED)

## Problem

Jason (2026-11-10, after the Amending-law reader step and its parked bugs took a whole day): "we've spent all day on amending-law reader step for 1 Family. ~50 Families. About 10 steps." At a day per step, about 50 families × 10 steps is a year and a half. This retrospective runs when Environmental Protection is switched over, before the review tooling session. It decides how the pipeline runs for the families still to come. The meta session's step rows hold each step's figures.

## Todo

- ✅ Measure each step: EP against Maritime and OH&S, what worked, where it drifted (section 1)
- ✅ Bug status, four ways (new and closed, new and parked, existing and fixed, existing and parked), by owning step (section 2; full lists in `backend/data/reports/retrospective/environmental-protection-bugs.md`); 23 entries with no owning step given one
- ✅ Decisions 1–3 (Jason, 2026-11-12): a few QQ register families one at a time, fixing the backlog; the model-per-part pilot after tooling (Fable for code, Opus 5.5 for the session and pass/fail); hardening means one process, after the QQ families
- ✅ Record the decisions: RULES where a rule, WORKFLOW "Running a new family", the meta row (and close the meta), the tooling and hardening sessions reshaped, the pickup memory
- ⏸️ Housekeeping: ✅ full NAS snapshot 2026-11-12 16:01 (41 tables, `--verify-only` passed); ⏸️ (deferred — Jason runs it when not remote) drop the 8 `lat_reparse_*` tables in `public` (Jason said drop all 8; the DROP was refused by the permission prompt, so it waits for Jason)
- ✅ Close the session; session and docs commits with `--no-verify`, by path; no push unless asked

## Preliminary conclusions (from the Amending-law reader, 2026-11-10)

**Where the day went:**
1. **The fixes were general.** Every class fixed was general and reached every family's laws: an Order's articles, a Schedule's paragraphs, ranges, list items, repeals-table items, quotes numbered in titles. Each was found by reading one family's groups by hand.
2. **Version cascades.** Shared modules (`amending_law/text.ex`, `doc.ex`) sit in 5–8 reader versions. Each edit staled every amendment, commencement and extent rule, so a warning fix and an architecture-test fix forced four extra corpus re-reads (about 30 min each). Commencement re-reads then needed `--effects`, orders, title searches and fetches.
3. **Rebuilt tooling.** Group dumps, field diffs, naming and run chains were written again by hand, with fresh slips: a path error, a pgrep wait loop.
4. **Hand review of by-design groups.** Most of 280 groups were "legislation.gov.uk holds no record", by design.
5. **One run at a time.** Each write was its own question to Jason.

**Changes to decide:**
- **A. Readers fixed across the corpus, not per family.** Each reader's gate runs over every family's laws at once, reviewed by class with the widest first; a class found in one law is fixed for all. A family's step then becomes its gates plus naming the few new groups: about an hour, not a day. This turns about 500 family-step sessions into about 10 corpus-wide reader rounds plus a short gate per family.
- **B. By-design groups named by rule.** The tool applies the standard statuses. A human reads only the misread causes: operation and level conflicts, and quote-dropped repeals by law.
- **C. One approved round per step.** The fix batch is approved once, then one scripted round runs: restore point, reads, re-reads, rebuilds, golden, tests, overnight where needed.
- **D. Untangle the versions.** Split the shared amending-law document readers so an amendment-only reading change does not stale commencement and extent rules. Run `mix compile --warnings-as-errors` and the architecture tests before any read pass.
- **E. The review tooling** (`2026-11-10-amending-law-reader-review-tooling.md`) is built after this retrospective, shaped by A–D.

## Dependencies

- ✅ Environmental Protection switched over (2026-11-12, pushed 4e6f67bd..b4020da1)

## 1. The run measured

| | OH&S (first) | Maritime Safety (second) | Environmental Protection (third) |
|---|---|---|---|
| Calendar days | 14 | 4 | 5 (2026-11-08 to 11-12) |
| Laws switched | — | 117 | 122 |
| Steps closed on the day opened | — | 13 of 14 | 11 of 14 (Feed reader, Extent reader, Evidence took 2) |
| Session lines (steps and meta) | 10,863 | 3,748 | 4,126, the largest 372 (Label fold) |
| Commits | 623 | 55 | 37 (17 session) |
| Pass rule met | moved about four times | all 14 | all 14 |
| Plan changes | not tracked | 6 | 0 |
| Agent tokens | not recorded | 1.49M in 8 steps | about 1.0M in 5 steps (Label fold 428k); 0 in the last 4 |

Drawn from the 53 lessons the family's step sessions recorded (session index), not from memory of the run.

### What went well

- **The process held.**
  - All 14 pass rules were met, with 0 plan changes.
  - 11 of the 14 steps closed on the day they opened.
  - Every bug in another step's code was parked with its owner. None was chased out of place except with leave for that bug (the Switch-over's two).
- **The family taught what it was picked for.** Its new kinds of law came out as named classes, not as noise:
  - Welsh SIs under two names (3 bugs, 440 rows fixed);
  - commencements territory by territory (EPA 1990 Part IIA);
  - devolved laws' territory (7,736 rows, one rule);
  - Scottish insertions reaching the England and Wales version;
  - scanned-print laws named "no provisions upstream" rather than guessed.
- **Checks in code caught every over-reach before it was written.** Six fixes went too far at first. Each was caught by a check, not by a unit test:
  - the Merge's first two rules, by an in-memory build of 7 laws;
  - the Label fold's Decision 7 (an OH&S row wrongly repealed), by a per-row status diff at HEAD;
  - the Label fold's Decision 8 (+1,227 undated starts against a measured 157), by the gap figure's rise;
  - the Amending-law reader's F3 and F5, by the field diff;
  - the Switch-over's Decision 3, twice: by golden from inputs, then by the checked rows.
- **Explaining by rule before sampling.** The largest Switch-over class (7,736 territory rows) was one rule found by a law-level profile, in minutes, with no row sample.
- **Agent passes, used once on by-design groups, found real faults.** The Merge's 50-change pass found a fault reaching 63 changes, where the review by shape had found none in 636. The Label fold's pass found 2 fold classes. The last 4 steps used no agent.
- **Bugs closed: 37** (13 new, 24 existing). That includes OH&S's three gate backlogs (Merge 85, Evidence 23, Amending-law 91 groups, all to 0) and Maritime's parked forms.

### What went less well

1. **Cold runs and version cascades were the largest time sink, and the same lesson was learned twice.**
   - The markup catalogue ran cold twice, about 25 min each, for three reader fixes.
   - The extent accept ran cold (13 min) after a refactor that changed no behaviour.
   - The 798 amending laws were re-read twice, about 25 min each, for a compiler warning and an architecture-test fix. Both diffs were zero.
   - One edit to `amending_law/text.ex` cost a corpus read, four commencement passes, four title searches and 27 fetches.
   - "Run the architecture tests before applying" was a Making-laws lesson on 11-08, and was paid again in the Amending-law reader on 11-10.
   - **A lesson that repeats inside one family has to be code, not a note.**
2. **Gates and checks drifted after their step closed, again as on Maritime.**
   - Measures found 3 gates moved (Sources 69, Extent 2, Amending-law 4).
   - 22 OH&S checked rows had changed through the 11-10 commencement re-reads, and no step re-ran them.
   - 59 parser-stale laws showed up only after the apply.
   - Feeds go stale by age alone.
   - Maritime's lesson said the same, and nothing yet re-runs them on its own.
3. **Dry runs that write, and fixtures handled wrongly.**
   - The commencement and order catalogues' dry runs write their fixtures.
   - The register stage's dry run refreshed stored feeds, putting two laws one feed behind.
   - A register re-scrape re-decided live status (2 laws revoked, rightly, but unasked).
   - I wrote 18 held examples before asking, against the freeze. Jason caught it, and Gemini named the process fault.
   - A fixture re-encoded unsorted gave a 63,000-line diff for 28 changes.
   - A held move carried an operation change the decision didn't name.
4. **Sizing measured what a fix was meant for, not what it reaches.** Decision 3's scan counted 74 undated changes, but the claim reached every change commenced by territory. Decision 8's 157 rows became 1,227. The checks caught both, but each catch cost a rebuild round (11 min).
5. **Slips with hand tools.**
   - `--family "OH&S"` matched four families and built 40 extra laws (9,713 changes).
   - A hand-built amenders list took in 21 commencement orders.
   - A Maritime scratch folder was reused, mixing in old files.
   - A path error and a pgrep wait loop crept in.
   - The Credo hook's `/tmp` copies filled the 16 GB quota (14 GB) and failed with no clear message.
6. **Ratchet friction mid-step.** The Credo ratchet fails on a lowered score, or on an old issue whose number changed, so the Label fold and Markup reader steps split old functions in the middle of a step's fix.
7. **Agent cost per class found is high.**
   - About 1.0M tokens over 5 steps.
   - The Label fold's 428k found 2 classes, and the Feed reader's 86k found none new.
   - The cheap wins came from code (field diff, in-memory build, HEAD diff), each in minutes.
8. **The backlog grew: 109 → 120 open.** The family parked 41 new bugs and closed 37 in total. The Commencement reader alone took 13 new, and holds 29 open. Finding is outpacing fixing, which is what Decision 1 answers.

### What to change (routed by owner, Jason 2026-11-12: yes)

- **Pre-flight as a task** (review tooling): compile with warnings as errors, the architecture tests, golden from inputs and the checked rows, before any write or rebuild. One command, so lessons 1 and 4's catches come first, not after a cold run.
- **A step-close check task** (review tooling): re-run the gates the step depends on, `label_checked`, and `lat.stale --list` for the family. This is drift (2) caught at each close, not at Measures.
- **Dry runs write nothing** (owners: Commencement reader's catalogues, Register's stage): `--out` by default.
- **Sizing by reach** (a WORKFLOW line): size a fix by an in-memory diff of every change its claim reaches, never by a count of the cases it is meant for.
- **Family names exact** (Store and build, `--family`): refuse a name matching more than one family unless given `--prefix`.
- **The Credo `/tmp` copies** (Tooling, already parked): clean up in the hook.

## 2. Bug status

From the session index, rebuilt today. "EP" is the family's step sessions, its meta session and the Amending-law reader parked-bugs session (2026-11-10). "Existing" is a bug whose pattern or class was logged before EP. Full lists: `backend/data/reports/retrospective/environmental-protection-bugs.md`.

| | Total | By owning step |
|---|---|---|
| New and closed | 13 | Feed reader 4, Markup reader 3, Merge 2, Making laws 1, Commencement reader 1, Label fold 1, Amending-law reader 1 |
| New and parked | 41 | Commencement reader 13, Amending-law reader 6, Feed reader 5, Register 4, Sources 2, Tooling 2, LAT parser 2, Making laws 2, Label fold 2, Markup reader 1, Extent reader 1, Switch-over 1 |
| Existing and fixed | 24 | Amending-law reader 13 (OH&S and Maritime forms, the OH&S gate), Commencement reader 2, Evidence 2, Store and build 2, Feed, Sources, Markup, Merge, Measures 1 each |
| Existing and parked | 79 | Commencement reader 16, Amending-law reader 9, fractalaw 7, Extent reader 7, Register 6, Feed reader 6, Old label path 6, Definitions 5, LAT parser 5, Markup reader 4, Sources 4, others 4 |
| Moved | 6 | pointers to another entry |

- **Open: 120,** against 109 at Maritime's retrospective.  With the 3 this session parks: 123. The family closed 37 bugs (13 new, 24 existing) and parked 41 new ones.
- **The Commencement reader owns 29 open bugs,** a quarter of the backlog, and 13 of the 41 new ones. The readers together (Commencement, Amending-law, Feed, Markup, Extent) own 68 of the 120.
- **Production-facing among the new:** Welsh SIs (3 entries: two register records, held under UK names, the own clause, fixed), ad hoc tables in `public` (lat.reparse, making.resolve), gates not re-run after their step (3).
- **Bookkeeping:** 23 entries in the two Amending-law reader sessions named no owning step; they now name it (20 Amending-law reader, 1 Store and build, OH&S gate entries).

## Decisions for Jason

### 1. The way of working for the remaining families — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12), his own option:** "We run a small number of Families from the QQ legal register one at a time to fix the bug backlog and improve reliability. Then do remaining register families." Each of those families runs the steps one at a time, and each step fixes its own parked bugs from the backlog (memory: parked bugs per step). Corpus-wide reader rounds (A) are not taken now.


- **The question:** do the remaining ~47 families keep running all 14 steps each, or do the readers move to corpus-wide rounds (A–D above)?
- **The aim:** binds-on-date for every family, at a pace that reaches them (at a day a step, about 50 × 10 steps is a year and a half).
- **The evidence:** EP's fixes were general, reaching every family's laws. The new parked bugs are mostly reader classes (Commencement 13, Amending-law 6, Feed 5), which each family would find again.
- **Options:**
  - A: take A–D together: each reader fixed in corpus-wide rounds, widest class first; by-design groups named by rule; one approved scripted round per step; the shared reader modules split so one reading's change stales only its own rules. A family's run becomes its gates, naming its few new groups, and the fold to switch-over.
  - B: take C and D only (rounds and versions), keep readers per family.
  - C: as now.
- **Recommendation: A.** Per-family reader work is where the days went, and none of it was family-specific.

### 2. An agent that runs a step and picks the model for each part — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A, with the models named.** "Fable 5.2 for code, Opus 5.5 for session including pass/fail, other models for other parts." The pilot comes after the review tooling, on one step of the next family, and is measured against EP's row for that step. Code goes to Fable, the session and its pass/fail verdicts to Opus 5.5, and paperwork and report summaries to smaller models. (The model list here names Fable 5.1, `claude-fable-5-1`; the pilot uses the newest Fable available when it runs.)


- **The question:** should an orchestrating agent run each step, choosing the model per sub-step?
- **The aim:** the same pace and quality at less cost (Jason: "we burned 400k tokens last step").
- **How a step's work splits:**
  - runs and gates: mix tasks, no model;
  - paperwork (session doc, meta row, bug-raise, commits): mechanical, a small model;
  - reading a report and naming its groups: a middle model;
  - finding why a reader misreads and fixing it: the top model, with the code's context;
  - decisions and every write: Jason.
- **For it:**
  - most turns in a step are runs and paperwork;
  - a model per part puts the cost where the judgement is;
  - the Workflow tool can script a step as phases, with a model per phase and approvals between.
- **Against, today:**
  - EP's 1.0M agent tokens were all judgement (agent checks finding classes), the part a cheaper model does worst: the 2026-11-05 sample-fix-resample regression came from exactly that work;
  - an orchestrator carries its own context, and hands context between models at each part;
  - runs go one worker at a time while the VM is up, so parallel agents gain nothing;
  - every write and decision still stops for Jason, so it saves tokens, not his time.
- **Options:**
  - A: after the review tooling, pilot one scripted Workflow on one mechanical step of the next family (Sources or Feed reader): small model for paperwork, middle for the report, top only for a new class; measured against EP's row for that step (tokens, time, anything missed);
  - B: build the orchestrator for all steps now;
  - C: no orchestrator; one model throughout, agent passes only on Jason's word.
- **Recommendation: A.** Decision 1 removes most of the judgement from a family's run, which is when a cheap orchestrator pays. Measure it on one step before it runs any.

### 3. Production hardening, and the order of the work — DECIDED 2026-11-12

**Decided (Jason, 2026-11-12): A, but** "production hardening means running all steps as one process. We're not good enough to do that yet." The order, confirmed:
1. the review tooling;
2. a few QQ register families, one at a time, each step fixing its parked bugs from the backlog;
3. production hardening, once all the steps run as one process;
4. the rest of the register's families.


- **The question:** what comes after this retrospective, and in what order: the review tooling, production hardening, Family 4?
- **The aim:** labels that bind on the date the user picks, in sertantai-compliance, kept current.
- **Production hardening holds** (`2026-11-07-production-hardening-and-integration.md`, PENDING): the label contract to compliance and fractalaw; compliance reading the switched labels; Welsh SI duplicates (#178); the partition migration (#133) and prod sync (#27); backup retention; v0.1 sign-off.
- **EP adds four:**
  - **Welsh SIs:** three entries now, two parked (two register records; held under UK names). This is #178, with real labels behind it.
  - **Gates that drift:** a scheduled run of the switched families' checks (`lat.stale --strict --switched`, golden, the checked rows) so a later change is caught the day it lands, not at the next Measures.
  - **No ad hoc tables:** the tasks still writing copies to `public` (lat.reparse, making.resolve) use the restore schema.
  - **Freshness:** legislation.gov.uk publishes new effects daily. Production needs an incremental refresh of the laws that changed (fetch, read, build, refold, switch), not a family run.
- **Options:**
  - A: review tooling, then production hardening (three switched families, 388 laws, into compliance), then Family 4 under the new way;
  - B: review tooling, Family 4, then hardening;
  - C: hardening first, tooling after.
- **Recommendation: A.** Three families already give compliance real labels. The refresh loop that hardening needs is the same machinery as corpus-wide reader rounds (Decision 1). The tooling comes first because both use it.
