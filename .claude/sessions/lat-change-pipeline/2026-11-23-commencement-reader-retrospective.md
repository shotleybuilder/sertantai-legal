---
session: 'Waste, Water and Climate: Commencement reader retrospective'
status: closed
opened: '2026-11-23'
closed: '2026-11-23'
outcome: success
family: Waste, Water and Climate (round)
step: Commencement reader
summary: >
  A retrospective of the four-day Waste, Water and Climate Commencement reader step on Jason's six points. The reader's spec was written and accepted (COMMENCEMENT-READER.md: aim, scope, the boundary with the Amending-law reader, substeps, staleness and loops), the complexity measured, and Claude's eleven takeaways set down.
  Decision 1: all six changes built as managed sessions in order (step procedures and workflow rules; staleness that follows what changed; decouple the new path from the old dater; split the order reader), then an Extent reader readiness review, all before the Extent reader.
decisions:
  - what: "Decision 1: build all six changes, each as a managed session, all before the Extent reader"
    why: "Jason: properly managed within our session approach; the problems probably affect the Extent reader too"
    result: five pending sessions sequenced in the round meta; the staleness fix first of the three code sessions because it makes the others' re-reads cheap
  - what: The old dater (Commencement.Amending) is decoupled, not deleted
    why: the old label path still serves every unswitched family; DATA-ARCHITECTURE deletes it only when every family has switched
    result: the decouple session moves the new path's picks off lat_change_log and fences the dater out of its version stamps
  - what: COMMENCEMENT-READER.md accepted as of 2026-11-23, revised after all the follow-on sessions
    why: the substeps, stamps and loops it describes are what the sessions change
    result: the revision is a todo in the Extent reader readiness review, with the stale parts of COMMENCEMENT-GUIDE, AMENDMENT-GUIDE and DATA-ARCHITECTURE
metrics:
  reader_size: { modules: 70, lines: 14382, test_files: 98, credo_issues: 20 }
  largest: { order_lines: 2188, order_functions: 169, order_patterns: 58, order_commits: 51 }
  step_churn: { reader_commits: 55, lines_added: 6110, lines_deleted: 1334, days: 4 }
  version_stamps_files: { change_vocabulary: 198, extent_read: 95, commencement_read: 63, shared_with_change_vocabulary: 54, shared_with_amendment_reader: 7 }
  commencement_rules: { rows: 72043, feed_commencement: 51549 }
lessons:
  - title: One version stamp over a whole reader makes every fix a round re-read
    detail: "Commencement.ReadVersion covers 63 files and shares 54 with the build's stamp; Store.write deletes and re-inserts, so even an identical re-read stales every build that reads those rules. Two late fixes cost about an hour and 1,088 laws."
    tag: tooling
  - title: A pass condition added mid-step is a new phase
    detail: "The two-way feed gate (Decision 5) was the step's best tool but drove Decisions 7-19 with no time box; plan it as a phase."
    tag: tooling
  - title: The reader's boundary was right in code but never written down
    detail: "The build has one owner per question (what and who: the Amending-law reader; when: the Commencement reader; where: the Extent reader); the step felt like amending-law work because the feed gate checks inserted rows' timing. The written spec answers it."
    tag: data
  - title: A map of the code by one read-only agent, spot-checked, replaced reading 14k lines in-session
    detail: "Two of its claims (read_at always moves; 51,549 feed rules) were checked by hand before they went into the spec."
    tag: tooling
bugs: []
artifacts:
  - docs/lat-change-pipeline/COMMENCEMENT-READER.md
  - .claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-step-procedures.md
  - .claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-staleness.md
  - .claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-old-path-decouple.md
  - .claude/sessions/lat-change-pipeline/2026-11-23-commencement-reader-order-split.md
  - .claude/sessions/lat-change-pipeline/2026-11-23-extent-reader-readiness-review.md
depends_on:
  - 2026-11-20-waste-water-and-climate-commencement-reader
enables:
  - "Commencement reader: step procedures, feed figures and workflow rules"
---

# Session: Waste, Water and Climate: Commencement reader retrospective (CLOSED)

## Problem

The Commencement reader step for the Waste, Water and Climate round ran four days (2026-11-20 to 23), with a day's suspension for a code review, 21 decisions, 20 Fable fixer calls (about 1.9M tokens) and three round re-reads and rebuilds. It closed (`2026-11-20-waste-water-and-climate-commencement-reader.md`), but it took so long that it needs a dedicated review before the next step. Jason has points to raise.

## Todo

- ✅ 1. A design spec for the Commencement reader: its aims, what is in scope and what is out
- ✅ 2. A substeps document: each substep's input sources, the data it changes, its output, what goes stale and why; the architecture and the workflow rules that force the substeps to loop
- ✅ 3. The boundary with the Amending-law reader made explicit: which reader dates what, and why the Commencement reader is not doing the Amending-law reader's work
- ✅ 4. Complexity: the code is now so complex that changes are hard to track — measure it and propose solutions
- ✅ 5. The feed as a yardstick: standard stats driven from the comparison; the rules for taking the feed or the reader refined, in their owning step (not this one)
- ✅ 6. Claude's takeaways from the step's session docs and log
- ✅ 7. Changes decided and written where they belong (WORKFLOW, RULES, skills, memory); close

## Jason's points (2026-11-23)

1. "Commencement Reader needs a 'what it is doing' spec [design spec?]. Ie a clear aims - what's in scope and what's out of scope."
2. "A document that describes the substeps with extra detail - eg what are the input data sources, what data does it change, what its output, what goes stale and why - that sort of thing - explains the architecture and big workflow rules that mean having to loop the substeps."
3. "Related to those two - I'm not clear how Commencement Reader isn't doing part of the work of the Amending Law Reader. I want that explicit."
4. "Complexity - it's clear the code is now so complex that changes are getting harder to track - solutions?"
5. "Feed as a yardstick. This is working well. We need to drive standard stats from the comparison. The rules for deciding which to take Feed or Reader may need refining - and that shouldn't be in this step anyway."
6. "Your takeaways from reviewing the session docs for Commencement Reader."

## Dependencies

- ✅ Waste, Water and Climate: Commencement reader closed (2026-11-23, cd038fde)
- ✅ Earlier retrospectives for comparison: Maritime Safety (2026-11-07), Environmental Protection (2026-11-10), the review against the aims (2026-11-12), Fire and OH&S (2026-11-17)

## Starting material

- The step's session: its frontmatter (decisions, metrics, lessons) and the round's meta row (`2026-11-17-second-qq-round-meta.md`).
- The step's log: `backend/data/reports/commencement-reader/wwc-commencement-reader-log.md`.
- The code review that set the new loop: `backend/data/code-reviews/commencement-reader-code-review.md`; WORKFLOW "How the step runs".
- Late finds from the close: golden moved by a correct fix that unmasked an older fault (Decision 21); every reader commit stales the whole round's rules, so the close needed one more re-read and rebuild; the Sources gate's calendar rule decided on 2026-11-19 is still not built.

## 4. Complexity, measured (2026-11-23)

- **Size:** `commencement/` and `law_start*` are 70 modules, 14,382 lines, with 98 test files.
- **The largest:**

  | Module | Lines | Functions | Regexes | Commits |
  |---|---|---|---|---|
  | `Commencement.Order` | 2,188 | 169 | 58 | 51 |
  | `LawStart.Provisions` | 1,823 | 132 | 48 | 26 |
  | `LawStart.Clause` | 1,021 | 63 | 16 | 22 |

- **Churn in this step (4 days):** 55 commits to the reader's code, 6,110 lines added and 1,334 deleted. 118 commits in all name the Commencement reader (47 of them session commits).
- **Credo:** 20 issues held by the ratchet (13 nested too deep, 7 too complex); `LawStart.Clause` 5, `SentencePatterns` 4, `Order` 4.
- **Reports:** 385 files and 25 MB under `backend/data/reports/commencement-reader/`. The session reached 1,014 lines and the log 510.

## 6. Claude's takeaways (2026-11-23)

1. **The feed gate became a second step inside the step.** Decision 5 (21 November) made the comparison with the feed a pass condition mid-step. It was the step's best tool, but Decisions 7 to 19 are nearly all its groups: inserted rows, orders never searched, proven feed errors, statuses. It was never planned as a phase, so it had no time box.
2. **The reader is dating amending laws.** Decisions 7 (C), 8, 13, 16 and 19 all decide *when an amendment took effect*: inserted provisions, amending laws' own clauses, their orders. That is the boundary Jason asks about (point 3). It is the largest share of the work that was not "when did this law's own provisions come in".
3. **Every reader commit stales everything.** The reader's version hashes all its code. Any fix stales 1,000+ laws' stored rules, and clearing that is a re-read and rebuild of about an hour. It ran three times, the last for two fixes on the final day. No rule says "no reader commit after the last re-read", so late fixes cost a whole cycle.
4. **Fetch needs surfaced late.** Orders never searched, unstored Schedules, and redirected Welsh documents were found in Fix and Settle, not in Find. Sources-type work happened at step 4; the fetch list should come out of Find.
5. **Heavy checks per fix before the code review:** about 40 family checks, 9 suites, 8 catalogues and 20 Fable calls (about 1.9M tokens). The new loop (find once, decide, batch) fixed this for the resume.
6. **Golden ran late.** Golden ran at Check, so its two moves (Decisions 20, 21) came on the last day. One of them needed a bisect: a correct fix had exposed an older fault. Golden from inputs is code, about 10 minutes, and could run at every Settle.
7. **The one-law tail and the go/write cycle.** Decisions 10, 11 and 17, NISR 2007/194, and the held moves each needed a dry run, Jason's go and a write. About ten such round trips, each one stopping the work.
8. **Decisions are numbered, not named.** 21 numbered decisions, and the step report had to re-explain them. Jason's 19 November feedback ("decisions I don't understand") still applies.
9. **The tooling lives in the scratchpad.** `held-write.exs`, `new-patterns.exs`, `reread2.sh`, the round's stale-by-reason count and the reach scripts were written per need and reused. They are the step's real procedures, but they are not tasks.
10. **A decided rule went unbuilt.** The Sources calendar rule (19 November) is still open, so the gate failed again by the calendar. A decision whose build is another step's needs a tracked owner and date.
11. **What worked:**
    - the feed gate found real misreads and 690 proven feed errors;
    - after the code review, the cheap checks per fix and the heavy ones per batch;
    - the step report;
    - the bisect that cleared golden at the end.

## 1–3. The spec, the substeps and the boundary: drafted (2026-11-23)

`docs/lat-change-pipeline/COMMENCEMENT-READER.md` (DRAFT): aim, scope in and out, the boundary table with the Amending-law reader, the substeps (reads, writes, stale when), the six loops, the feed as a yardstick, and open questions. The facts come from a read-only map of the code (an agent, checked by hand: `Store.write` deletes and re-inserts, so `read_at` always moves; 51,549 of the 72,043 rules are feed rules).

- **The boundary:**
  - the Commencement reader owns *when* for every provision, amending provisions included;
  - the Amending-law reader owns *what* and *who*;
  - the Extent reader owns *where*.
  - No question has two owners in the build. Three overlaps remain:
    - the old label path's second dater (`Commencement.Amending`, effects first);
    - one amending law parsed by four passes;
    - seven files shared by both readers' version stamps.
- **Out of date:** COMMENCEMENT-GUIDE §2 and §5 (they describe the old path), AMENDMENT-GUIDE's "effects first", DATA-ARCHITECTURE's commencement_rules row (45,030 rows; it is now 72,043; its writers are wrong), the code review's figures.

## Decision 1 for Jason: what to change

- **The aim:** `binds-on-date`, at a cost a step can carry. A fix should cost its own tests and one bounded re-read, not the whole round.
- **(a) Staleness that follows what changed** (the Commencement reader's code, its own step):
  - rules re-written only when their content changes, so an identical re-read moves nothing;
  - one version per substep (own clause, orders, amending laws), not one for the whole reader;
  - `ChangeVocabulary.Version` and `Extent.ReadVersion` leave out the reader's modules, which they reach only through stored rules.
  - Expected effect: today's two late fixes would have staled the laws they changed, not 1,088.
- **(b) Retire the old path's dater and inputs:**
  - `Commencement.Amending`, and the `lat_change_log` picks for `--effects` and `--read-orders`;
  - decide whether `--effects` (51,549 rules, used only in the build's last gap) stays.
  - This belongs to Store and build's retirement plan (DATA-ARCHITECTURE G1).
- **(c) Split `Commencement.Order`** by the family of form it reads (tables, inline lists, appointed days, schedules), test first, with the catalogue identical before and after.
- **(d) The step's procedures become tasks:**
  - the held write (`held-write.exs`, `new-patterns.exs`);
  - the round's re-read chain (`reread*.sh`);
  - the round's stale reasons;
  - a fix's reach.
- **(e) Standard feed figures in Measures.** Each run prints agree, differ, feed only, feed partly only, ours only and neither, per family and round, plus the feed errors proven and the groups by owner. Which source wins stays with Evidence and the Label fold.
- **(f) In WORKFLOW for every step:**
  - the fetch list comes out of Find;
  - golden runs at every Settle;
  - no reader commit after the last re-read unless the step re-runs it;
  - decisions named, not numbered;
  - a mid-step pass condition (like the feed gate) is a new phase with its own time box.
- **Recommendation:** all six.
  - (a) first, as its own session before the next Commencement reader step: it removes the largest cost.
  - (b) with Store and build.
  - (c) as a refactor session.
  - (d), (e) and (f) now, in this retrospective's close or a small session after it.

**Decision 1, decided (Jason 2026-11-23): build all six, each managed as a session; (a)–(f) done before the Extent reader; then a retrospective of the Extent reader step's likely problems before it is launched.**

The sequence, and why:
1. **(d), (e), (f): one session after this one closes** (Jason). Its re-read task is written as a chain of substeps, so (a) can give each its own version without rewriting it.
2. **(a) Staleness that follows what changed: dedicated, first of the three.**
   - It makes the other two cheap: once rules are rewritten only when their content changes, a re-read after (b) or (c) that changes nothing stales no build.
   - Its own cost is one round re-read, where identical rules write nothing.
3. **(b) Decouple the new path from the old dater: dedicated, second.**
   - `Commencement.Amending` cannot be deleted yet. The old label path still serves every unswitched family, and DATA-ARCHITECTURE deletes it "when every family has switched".
   - So (b) is: the new path's picks move off `lat_change_log` (`--effects`, the no-flag `--read-orders`); the fate of `--effects` decided; the old dater fenced out of the new path's version.
   - After (a), only the substeps it touches go stale.
4. **(c) Split `Commencement.Order`: one or more dedicated sessions, last.**
   - It is a pure refactor, test first, with the orders catalogue identical before and after.
   - After (a), an identical split re-writes no rule, which also proves (a).
   - Its plan sizes it: one session, or one per family of form.
5. **The Extent reader readiness review:** this retrospective's questions asked of the Extent reader, before its step's plan.

## Close (2026-11-23)

- **Docs changed:** `COMMENCEMENT-READER.md` (new, accepted; to be revised after the follow-on sessions); the pipeline README's docs index. RULES is unchanged: no rule was decided, and the workflow rules go in with (f).
- **Bugs:** none new. The overlaps found (the second dater, four parses of one amending law, shared stamp files) are the follow-on sessions' work.
- **Parking:** none.
