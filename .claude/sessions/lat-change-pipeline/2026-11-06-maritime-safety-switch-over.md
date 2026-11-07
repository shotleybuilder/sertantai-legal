---
session: "Maritime Safety: Switch-over"
status: closed
opened: 2026-11-06
closed: 2026-11-07
outcome: success

summary: >
  Step 13 for TRANSPORT: Maritime Safety: every difference was explained and the family switched. All 117 laws have their lat_label_timeline written from the merged changes, equal row for row to the switch's, and 8 rows named as known limits. Three faults were fixed in-step: the family switch by display name, the feed reader reading a bracketed Part as the whole Part (MSA 1995 Part VI, 773 rows; Decision 2, B), and the start read from the old register, which had failed the Merchant Shipping Act 1979 at the first apply.

decisions:
  - what: "Decision 1: an agent pass only if the causes point that way (at most 2 batches); in the event none, 0 tokens"
    why: "Every large cause named its evidence once the Part VI fault was fixed; a hand look at 12 rows each of the two unclear causes found the one class"
    result: "no Maritime row judged by an agent; the pass rests on rules, golden, OH&S's 744 checked rows and the dry run"
  - what: "Decision 2, B: fix the feed reader in-step: a Part, Chapter or Title in brackets beside a provision or range is a locator, not a target"
    why: "By AIMS fix-where-owned, a 773-row class from one reader rule is above the triage size, so it is fixed at its source, not named; Gemini (Flash, 5,371 tokens) picked B too"
    result: "the 421 'in force later, no change dated' rows gone; RULES bracketed-part-is-a-locator; the store scan found 310 such effects in 50 laws, 18 moving a label"
  - what: "Name the 8 remaining rule breaches as Maritime known limits (3 classes, 1 to 5 rows each), parked with the Label fold and the Commencement reader"
    why: "below the triage size; the switch keeps their old label"
    result: "label_rules 0 breaches outside the known limits: PASSED"
  - what: "Accept the 51 OH&S checked rows whose changed_by moved by Decision 1 (A) of Labels side by side; leave 6 HSWA rows changed by a parked repeals-table fault"
    why: "the 51 follow a decided rule; the 6 come from another step's fault that reaches no Maritime law"
    result: "the fixture diff is the 51 values and notes; the Amending-law reader bug is parked and blocks any OH&S relabel of 11 laws"
  - what: "Fix the start-from-old-register bug in-step (Jason: 'Fix the bug as held by this step')"
    why: "the first apply failed the Merchant Shipping Act 1979 on the old register's fidelity gate, which LabelRefresh still ran for switched laws"
    result: "the start is stored with the build (equal to the old register's for 285 of 285 laws); a switched refresh never touches lat_change_log; re-apply 117 of 117"

metrics:
  causes: { rows: 24434, agree_before: 19088, differ_today_before: 4450, history_before: 896, agree_after_fix: 19543, differ_today_after_fix: 4029, history_after_fix: 862 }
  rules: { breaches_before: 8, known_limits: 8, breaches_after: 0, legacy_unconfirmed_apart: 1 }
  checked_rows: { total: 744, match: 639, accepted_changed_by: 51, known: 47, upstream: 1, changed_parked: 6 }
  dry_run: { laws: 117, not_folded: 0, rows: 24613, differ: 5213, periods_old: 43083, periods_new: 47501 }
  apply: { first: "116 of 117", after_fix: "117 of 117", stored_vs_switch_rows_differing: 0 }
  start: { built_laws: 285, equal_to_old_register: 285 }
  feed_scan: { effects: 261557, bracketed: 310, laws: 50, label_moving: 18 }
  tests: { golden: "27/27", mix_test: "10199 passed", credo: "no new issues" }
  timings: { shadow_s: 733, rules_s: 715, rebuild_s: 803, golden_s: 596, apply_s: 834, compare_s: 690 }
  tokens: { agent: 0, gemini: 5371 }

lessons:
  - title: "--strata can't show a switched family agreeing: compare the stored timeline with the switch's directly"
    detail: "After the apply, --strata still showed 560 rows differing today. It compares the fold's own periods, and the timeline's conventions (a repeal's day and empty territory, the commencer as changed_by, no unknown EU period) always differ from them. A direct comparison of lat_label_timeline with LabelSource.timeline/1 showed 0 rows differing."
    tag: tooling
  - title: "A hand look at a cause that names no evidence found a 773-row reader fault"
    detail: "Of all the shadow's causes, only 'in force later (none dated)' had no change behind its new value. 12 rows by hand (0 tokens) traced it to one feed effect form; the store scan then sized the class across all families."
    tag: data
  - title: "The checked rows of a switched family catch other steps' regressions"
    detail: "OH&S's 744 checked rows, re-run in Maritime's switch-over, found 51 rows moved by a decided rule (Decision 1) that the previous step hadn't re-checked, and a repeals-table fault (Mines Regulations 2014 → HSWA) from an earlier read. Run label_checked in every step that changes the fold or the readers."
    tag: data
  - title: "Every edit under change_vocabulary/ makes all built laws stale"
    detail: "label_switch.ex, known_limits.ex and feed.ex each marked all 285 built laws stale on code version: four staleness rebuilds in one step (about 14 min each). This is Store and build's parked label-fold-in-build-version bug, widened; batch edits before a rebuild."
    tag: tooling
  - title: "The label tools fold sequentially and repeat the same fold"
    detail: "Each shadow, rules, --list, strata and dry run re-folded 117 laws on one core (about 12 min each, load around 1.3 of 6 cores). Raised as GitHub #191 (fold once, bounded parallel folds, the biggest laws first), with #192 (the pipeline's Python checks moved to Elixir), both before the next family."
    tag: tooling

bugs:
  - pattern: 'The family switch matches the display family name by substring (''💙 OH&S: Occupational / Personal Safety'' contains the setting); switched laws are stamped with the old path''s code version'
    category: family-switch-by-display-name
    module: ChangeVocabulary.LabelSwitch.switched?/1
    affected: 377 family laws
    fix: "LabelSwitch.family_in?/2: the exact family name, the display marker dropped (switched?/1 and the --apply check); LabelRefresh.code_version/1 stamps a switched law with ChangeVocabulary.Version"
    step: Switch-over
    status: fixed
  - pattern: 'A feed effect naming a section range with its Part and a missing Chapter for context is read as the whole Part inserted (MSA 1995 "s. 130A-130E (Pt. 6) (Ch. 1A) added" and "s. 182A-182C (Pt. 6) (Ch. 5) added" by the 1997 Act → pt.VI inserted 1997-03-19 and 1997-07-17)'
    category: feed-range-read-as-context-part
    module: ChangeVocabulary.Readers.Feed (targets)
    affected: "2 effects; 773 rows under MSA 1995 Part VI, 529 of them with periods before 1997 that the new labels drop"
    fix: "Readers.Feed.located/3: a Part, Chapter or Title in brackets beside a provision or range is a locator (RULES bracketed-part-is-a-locator); fixed in this step with Jason's leave (Decision 2, B)"
    step: Feed reader
    status: fixed
  - pattern: 'An undated change by a later law (law text or feed) is folded as the text''s maker from an earlier period, the law''s start or an earlier change (MSA 1995 s.256A by SI 1999/1820: period from 1996-01-01)'
    category: undated-maker-from-start
    module: ChangeVocabulary.Label (Undated)
    affected: "5 Maritime rows (s.256A, s.256A(1), s.256A(2); EPA 1970 s.42(1); SI 1975/2220 reg.2); OH&S's named date gaps are the same class"
    fix: "an undated change dates nothing: the period before it keeps its own maker, and the change is a gap (unknown-over-guess)"
    step: Label fold
    status: open
  - pattern: 'A change by an amending law dated by the commencement source before that law was made (MSA 1995 s.284(4), s.85(3): the 1997 Act''s change dated 1996-09-15; the Act was made 1997-03-19)'
    category: commencement-before-made
    module: Commencement (date resolution for amending-law changes)
    affected: 2 rows
    fix: "a commencement date before the amending law was made is not that law's; find which order or clause gave it"
    step: Commencement reader
    status: open
  - pattern: 'A row with no period from its law''s making: its first period is a later repeal (SI 1998/1258 reg.7(b), made 1998-05-19, first period repealed from 2004-05-13)'
    category: no-made-period
    module: ChangeVocabulary.Label
    affected: 1 row
    fix: "find why the start period is missing for this row (inserted? start read?)"
    step: Label fold
    status: open
  - pattern: 'A repeals table''s rows given to the wrong enactment: Mines Regulations 2014 Sch.3 Pt.1 repeals Mines and Quarries Act 1954 ss.19, 28, 30, 36-37 … "In full", read as whole-section repeals of HSWA 1974 (the table''s later entry) from 2015-04-06 E+W+S'
    category: repeal-table-wrong-enactment
    module: Amendment.Reader.RepealTable (AmendingLaw)
    affected: "39 changes in 11 OH&S laws (17 on HSWA 1974: s.1, s.10, s.19, s.28 …); 6 OH&S checked rows changed; no Maritime law. Present before this step (restore point maritime-switch-over-feed-locator)"
    fix: "a repeals table's rows belong to the enactment named above them until the next enactment line; a law we don't hold takes its rows with it, never to the next law"
    step: Amending-law reader
    status: fixed
    fixed_in: lat-change-pipeline/2026-11-07-ohs-amending-law-reader-repair (law lines in RepealTable.rows/2; SI 2014/3248 now 0 HSWA whole-section repeals; checked rows 696 match)
  - pattern: "The new label path reads the law's start from the old register (lat_change_log) by a query with no ORDER BY (LabelSource.start/1); LabelRefresh still runs ChangeCollector and LabelTimeline.build for switched laws"
    category: start-from-old-register
    module: ChangeVocabulary.LabelSource / LabelRefresh
    affected: "every switched law; on Maritime's apply it failed the Merchant Shipping Act 1979 (old register's fidelity gate, 2 diffs)"
    fix: "LawStart.Input (moved out of ChangeCollector) read by Build.start/1; the start stored on the changes_built event (Store.write/4, Store.start/1) and read by LabelSource and golden; LabelRefresh's switched path builds and writes from the merged changes only, the known limits keeping their stored periods (LabelSwitch.stored/1)"
    step: Switch-over
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_switch.ex
  - backend/lib/sertantai_legal/scraper/label_refresh.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/known_limits.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/build.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_source.ex
  - backend/lib/sertantai_legal/scraper/law_start/input.ex
  - backend/lib/sertantai_legal/scraper/change_collector.ex
  - backend/lib/mix/tasks/lat.label_switch.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/config/config.exs
  - backend/test/fixtures/change_vocabulary/switch_checked.json
  - backend/test/fixtures/feed_patterns/expected.json
  - backend/data/reports/switch-over/maritime-safety-known-limits.md
  - backend/data/reports/switch-over/
  - backend/data/code-reviews/2026-11-06-maritime-switch-over-decision-2-brief.md
  - backend/data/code-reviews/2026-11-06-maritime-switch-over-decision-2-gemini.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/README.md
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md
  - .claude/skills/switch-over-check/SKILL.md

depends_on:
  - 2026-11-06-maritime-safety-labels-side-by-side

enables:
  - "Maritime Safety: Retrospective"
  - "Tooling before the next family (GitHub #191, #192)"
---

# Session: Maritime Safety: Switch-over (CLOSED)

## Problem

WORKFLOW.md step 13 for TRANSPORT: Maritime Safety. Every difference between the new and old labels is explained. Then the family's `lat_label_timeline` is written from its merged changes (AIMS `binds-on-date`). The baseline, from Labels side by side, is 24,434 rows in 117 laws: 18,898 agree, 2,350 differ today, 874 differ only in history, and 2,312 have no stored timeline. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session with these todos
- ✅ The family-switch bug (TDD): exact family match, switched laws stamped with the change vocabulary's version; the start bug's Maritime count recorded
- ✅ Causes and rules: `label_shadow` and `label_rules` for Maritime, saved to reports
- ❌ One agent pass (none needed, Decision 1; 0 tokens): a seeded `label_shadow --strata` sample (at most 5 batches), verdicts to a report, tokens recorded; right rows accepted, wrong classes to rules or known limits, parked by owning step
- ✅ The checks: `label_rules` 0 outside known limits, `label_checked` all matching, golden 27/27
- ✅ Dry run → Jason → restore point → family added to `:label_families` → `--apply`
- ✅ After the apply: the stored timeline equals the switch's, 117 of 117 (checked directly, not by `--strata`); `mix lat.stale` 0; `mix test`; Credo
- ✅ Docs and close: WORKFLOW step 13, the `switch-over-check` skill, the session and meta row; code and session commits, no push

## Dependencies

- ✅ Maritime Safety: Labels side by side (closed 2026-11-06, 0fd1c681): the baseline; all 285 built laws rebuilt, 0 stale

## Pass rule (fixed at plan)

1. `label_shadow` sorts every differing row by cause (report saved).
2. `label_rules` shows 0 breaches outside the named known limits.
3. `label_checked` shows every row matching, none to fix (known limits and upstream apart). This covers OH&S's 744 rows and Maritime's new ones.
4. Golden 27/27 from inputs.
5. The dry run folds every law, with 0 rule breaks.
6. After the apply, `--strata` shows every row agreeing today, except the known-limit rows, which keep their old label.
7. `mix test` passes; Credo is clean.

The stop: more than 5 new classes, or one class over 100 rows, goes to Jason as a decision.

## The parked bugs (todo 2)

- **Family switch by display name (fixed).**
  - `LabelSwitch.family_in?/2` matches the exact family, with the register's `💙 ` marker dropped, both in `switched?/1` and in `--apply`'s check. A setting "OH&S: Occupational" no longer switches "OH&S: Occupational / Personal Safety".
  - `LabelRefresh.code_version/1` stamps a switched law's timeline with `ChangeVocabulary.Version`, and every other law's with the git sha, as before.
  - Tests: `label_switch_test`, `label_refresh_test`.
- **Start from the old register.** `LabelSource.start/1` read the law's start with no ORDER BY, and 0 of Maritime's 117 laws had more than one law-level start. At the plan it stayed parked. After the first apply it was fixed in this step (Jason: "Fix the bug as held by this step"); see "The apply and the start-from-old-register fix".

## Decision 1: the agent sample

- **Question:** is the plan's agent pass (up to 5 batches, about 300k tokens) needed?
- **Aim:** `binds-on-date`. It is the only check that can find a Maritime-only fault class the rules don't know.
- **Decided** (Jason, 2026-11-06): "Small only if the data points that way when the run is done".
  - If every big cause has clear evidence behind its new value, there is no agent pass. The pass then rests on the rules, golden, the OH&S checked rows and the dry run, and the session records that no Maritime row was judged.
  - Otherwise, at most 2 batches, on the unclear or new causes only.
- This narrows the plan's todo 4.

## Results so far (todo 3)

- **Causes** (`backend/data/reports/switch-over/maritime-safety-shadow.txt`, 12 min):
  - 24,434 rows as at 2026-11-06: 19,088 agree, 4,450 differ today, 896 differ only in history;
  - 2,163 of the 4,450 have no old label;
  - the largest causes: no old label, new in force (2,108); prospective from the law's making (545); in force later, by a commencement (503); in force later, no change dated (421).

  These figures are not the side-by-side baseline's, because the shadow sorts rows by first cause and counts rows with no old label as differing.
- **Rules** (`maritime-safety-rules.txt`, 12 min): 8 breaches (NOT PASSED):
  - 7 a change dated before its amending law was made;
  - 1 with no period from the law's making (SI 1998/1258 reg.7(b): made 1998-05-19, its first period a repeal from 2004);
  - 1 more, legacy unconfirmed, listed apart.
- **Looked at by hand** (no agent, 0 tokens): 12 rows each of the two causes whose evidence was unclear.
  - **No old label, new in force:** every row is backed, by an insertion (feed, law text, markup) or by the law's start.
  - **In force later, no change dated:** all 12 are MSA 1995 Part VI rows. Their new label starts on 1997-07-17, "by" the 1997 Act, and the period in force from 1996 is gone. The cause is the feed-range bug above, the stop rule's "class over 100 rows".

## Decision 2: MSA 1995 Part VI, read as inserted in 1997

- **The question:** the feed reader reads two of the 1997 Act's insertions, five sections into Part VI Chapter 1A and three into Chapter 5, as the whole of Part VI inserted. On the new labels, 529 Part VI rows lose their periods before 1997, and their in-force date moves to 1997. How should the switch treat them?
- **The aim:** `binds-on-date`. Between 1996 and 1997, those rows would read as not yet in force when they were.
- **Options:**
  - **A. Park and keep.** The bug is parked with the Feed reader. Part VI's rows go on a Maritime known-limits list (`KnownLimits`), so they keep their old label at the switch, as OH&S's missing repeals did. The rest of the family switches. No earlier step's code is changed. The rows switch when the Feed reader is reopened and fixed.
  - **B. Fix the reader now** (your leave for this bug). The fix is that a range is the target, and the Part and Chapter beside it are context. It would go through the reader's own method:
    - `lat.feed_check` with a regression run;
    - a whole-store scan for the same form;
    - a rebuild of the laws it changes;
    - the shadow and rules re-run (about 1–2 hours).

    Part VI then switches with correct labels.
  - **C. Hold the whole switch** until the Feed reader is reopened.
- **Recommendation:** A. It is the switch-over's own mechanism for exactly this, it keeps the step in scope, and the rows keep the labels production has today. B is right if you want Part VI on the new labels now.
- **Jason** (2026-11-06): "I'm leaning B, but share with Gemini and decide best option aligned with AIMS.md".
- **Gemini** (Flash, 5,371 tokens, cut off in its last point; `backend/data/code-reviews/2026-11-06-maritime-switch-over-decision-2-{brief,gemini}.md`):
  - It picks B. The family is then proven whole, not "partially proven with caveats".
  - It finds the locator rule right and safe. The one risk it names is a real whole-Part insertion written with the Part in brackets beside sections, which the store scan will show.
  - **Contested:** it says under A the 529 rows "continue to display incorrect" dates. They don't: their current labels are in force from 1996, which is right. A's cost is a 500-row known-limits list, not wrong labels.
- **Decided: B.** By AIMS:
  - `fix-where-owned` keeps known limits for one-law wordings and legislation.gov.uk errors below a step's threshold. A class of 773 rows from one reader rule is above it, so it is fixed at its source, by class, not named.
  - `binds-on-date` is served by both options for these rows today, so it doesn't decide against B.
  - B also fixes the form in every other family the store scan finds.
- **The B steps** (a scope change, so put to Jason before they run):
  1. A store scan: every feed effect whose text gives a Part, Chapter or Title in brackets beside a provision or range, and what it targets today.
  2. The reader fix (TDD) in `Readers.Feed.refs/4`: such a bracketed container is a locator, not a target.
  3. `lat.feed_check` for Maritime (placement, our faults 0), and the whole-store scan re-run to 0.
  4. A rebuild of the laws whose stored changes move (`lat.vocabulary --check`), then golden.
  5. The shadow and rules re-run.
- **The agent sample (Decision 1)** waits on this decision.
- **Go-ahead** (Jason, 2026-11-06): "B to go ahead".

## The feed reader fix (Decision 2, B)

- **Store scan** (read-only, every feed page held: 261,557 effects):
  - 310 effects in 50 laws give a Part, Chapter or Title in brackets beside a provision or range, in all families. Only 18 of them can move a label: added, repealed, revoked or substituted, in 14 laws, two of them MSA 1995's.
  - 15 more name a container without brackets ("Pt. 13 Subpart C", "s. 13 Pt. 4"). The rule leaves these as they are.
- **The fix** (`Readers.Feed.located/3`, called from `refs/4`): when every container the effect's text names is in brackets, and the effect also names a provision or a range, its Part, Chapter and Title refs are dropped as locators. Tests in `feed_targets_test`:
  - MSA 1995 ss.130A–130E;
  - "s. 41-57 (Pt. 1 Ch. 3)";
  - "s. 27 28 (Pt. 3) 29 (Pt. 3)";
  - "Pt. 4 heading" and "s. 13 Pt. 4", which keep their Part.
- **Regression:** two catalogue examples (`feed_patterns/expected.json`) held the bracketed Part as a target, and both now read as their sections only, as the rule intends. Neither is a label effect: "s. 29-45 (Pt. 4)", power to transfer functions; "s. 55-106 (Pt. 3) s. 119-246 (Pt. 5-IX)", modified. Their expected outcomes lose the one Part entry each. 1,703 catalogue tests and 3,326 change-vocabulary tests pass; Credo adds no issues.
- **`lat.feed_check`** for Maritime: 4,786 effects in 117 laws, our faults 0, no tell-tales: PASS.
- **Rebuild:** restore point `maritime-switch-over-feed-locator` (`provision_changes`, `provision_change_claims`, `lat_events`), then all 285 built laws. All were stale on code version from this step's two edits. The hand look found the one unclear class, and the 7 + 1 rule breaches are listed next.

- **After the rebuild** (285 laws in 15 min, 0 stale; golden 27/27):
  - **Causes** (`maritime-safety-shadow-after-fix.txt`): 24,434 rows as at 2026-11-07. 19,543 agree, 4,029 differ today, 862 differ only in history. The 421 "in force later, no change dated" rows are gone, and "start later" in history fell from 224 to 180.
  - **Rules** (`maritime-safety-rules-after-fix.txt`): still 8 breaches, none of them Part VI. They are 7 changes dated before their amending law was made and 1 row with no period from its making; 1 legacy-unconfirmed row is listed apart.

## Known limits (todo 5)

The 8 breaching rows are three classes of 1–5 rows each, below the triage size. By `fix-where-owned` they are named, not fixed. They are listed with class and owning step in `backend/data/reports/switch-over/maritime-safety-known-limits.md`, which `KnownLimits` now reads, so they keep their old label at the switch. The bugs are parked above.
- **Date gap** (Label fold, 5 rows): an undated change by a later law, folded as the maker from an earlier period. It is OH&S's named date-gap class.
- **Commencement before made** (Commencement reader, 2 rows): MSA 1995 s.284(4) and s.85(3).
- **No made period** (Label fold, 1 row): SI 1998/1258 reg.7(b).

`known_limits.ex` is in the build's version, so a staleness rebuild follows, with restore point `maritime-switch-over-known-limits`.

## The agent sample (Decision 1, applied)

**No agent pass, 0 tokens.** After the fix, every large cause names its evidence: an insertion, repeal, substitution or commencement by a named law, the law's start, or the made-to-start convention. The one cause with no evidence ("in force later, no change dated", 421) was the Part VI fault and is gone. The hand look at 12 rows of "no old label, new in force" (2,108) found each backed. So no Maritime row was judged by an agent. The pass rests on the rules, golden, OH&S's 744 checked rows and the dry run.

## Checks and dry run (todos 5–6)

After the known limits, a staleness rebuild (285 laws, 13 min, 0 stale; restore point `maritime-switch-over-known-limits`):
- **Rules** (`maritime-safety-rules-known-limits.txt`): 24,434 rows, **0 breaches** outside the known limits, with 1 legacy-unconfirmed row listed apart: **PASSED**.
- **Checked rows** (OH&S's 744): 639 match, 47 known, 1 upstream, **57 changed**.
  - **51 changed only `changed_by`**, to the principal maker: SI 2019/758 over SI 2019/858 and SI 2020/1577 on REACH; SI 2019/720 over SI 2020/1567 on CLP; SSI 2006/457 on SI 1999/3242 reg.1(2). This is Decision 1 (A) of Labels side by side, which did not run the checked rows. They are accepted (`--accept`, with the rule as the why); the fixture diff is those 51 values and their notes.
  - **6 HSWA 1974 rows gained a 2015-04-06 period**: s.10(2), s.10(4)(a), s.19(3), s.28(3)(f)(ii)[E+W], s.28(4)[S] and s.28(9A)(b)[S].
    - The Mines Regulations 2014 (SI 2014/3248) Sch. 3 repeals table lists Mines and Quarries Act 1954 sections "In full", then a HSWA entry. The reader gives the 1954 Act's sections to HSWA: 17 false whole-section repeals of HSWA (s.1, s.10, s.19, s.28 …), and 39 in 11 OH&S laws. No Maritime law is reached.
    - The fault was present before this step (it is in the restore point taken before the first rebuild), so it came from an earlier step's read.
    - OH&S's stored timeline (built 2026-11-02) is clean: HSWA s.1 is in force. A relabel of those OH&S laws would write the false repeals.
    - The bug is parked with the Amending-law reader (above). These rows are left as "changed": they are a regression in another family, not a Maritime row.
- **Dry run** (`maritime-safety-dry-run.txt`, per law `switch-over/maritime-safety-dry-run.csv`, 12 min): **117 laws folded, 0 not, none breaking the table's rules**. 24,613 rows, 5,213 differ; periods 43,083 → 47,501.
  - Today, old: in force 22,063, prospective 59, repealed 324, repealed_saved 5.
  - Today, new: in force 23,722, in force partial 1, prospective 57, repealed 387, repealed_saved 117.

## The apply (todo 6) and the start-from-old-register fix

- **The apply** (Jason: "Apply (Recommended)"): restore point `maritime-switch-over-apply`; "TRANSPORT: Maritime Safety" added to `:label_families`; `--apply` wrote 116 of 117 laws in 15 min. The Merchant Shipping Act 1979 failed the old register's fidelity gate (2 diffs), which `LabelRefresh` still ran for switched laws, and kept its old labels.
- **Checked after the apply:**
  - The stored timeline equals the switch's (`LabelSource.timeline/1`), row for row, for all 116 laws written, known limits apart. Only the 1979 Act's h.21 and h.22 differ.
  - `--strata` (`maritime-safety-strata-after-apply.txt`) shows 560 rows differing today, 134 only in history and 149 with no timeline. These are the timeline's conventions, not real differences: `--strata` compares the fold's own periods, so a repeal's day and empty territory, the commencer as `changed_by`, and the dropped unknown period before an EU law's first dated day always differ (a 26-row sample, seed 71). The plan's pass rule 6 was therefore checked by the direct comparison.
- **The bug, fixed** (Jason: "Fix the bug as held by this step"):
  - **The start.** `LawStart.Input` is moved out of `ChangeCollector`, which delegates to it. `Build.start/1` resolves the start; `Store.write/4` stores it on the `changes_built` event; `Store.start/1` reads the latest. `LabelSource` reads that (a law built before is `:start_not_built`), and golden resolves it from inputs. Proof before any switch: `Build.start/1` equals the old register's start for all 285 built laws, with 0 differing and no law holding two starts.
  - **The refresh.** A switched law's refresh builds and writes from its merged changes only. Its known-limit rows keep their stored periods (`LabelSwitch.stored/1`), and the old collector and `LabelTimeline.build` aren't run.
  - Tests: `law_start/input_test`, `store_db_test`, `label_switch_db_test`; 3,383 related tests pass; Credo adds no issues.
  - Then a rebuild of all 285 laws (restore point `maritime-switch-over-start-stored`), the stored starts checked against the old register, golden, the Maritime re-apply, the comparison again, and `lat.stale`.

- **After the fix** (restore point `maritime-switch-over-start-stored`):
  - rebuild of 285 laws, 13 min;
  - stored start equal to the old register's for **285 of 285**;
  - golden **27/27**;
  - Maritime re-applied: **117 of 117 written, 0 failed**, the 1979 Act included (14 min);
  - stored timeline against the switch's: **0 rows differ in 117 laws**;
  - `mix lat.stale`: 0 of 285 built laws stale;
  - `mix test`: 10,199 passed; Credo adds no issues.

## Parking list

- Store and build: label-fold-in-build-version. `label_switch.ex` is in `ChangeVocabulary.Version`'s globs though no build reads it, so this step's fix marks the built laws stale on code version. The `--apply` rebuilds the 117 family laws; the other built laws need a rebuild, which will be asked of Jason with the apply.
- Feed reader: feed-range-read-as-context-part. A range with its Part and a missing Chapter for context is read as the whole Part (2 effects, MSA 1995 Part VI, 773 rows). See Decision 2.
- Label fold: undated-maker-from-start. An undated change by a later law is folded as the maker from an earlier period (5 Maritime rows, and OH&S's date gaps). Named known limits.
- Commencement reader: commencement-before-made. A 1997 Act change on MSA 1995 is dated 1996-09-15 (2 rows). Named known limits.
- Label fold: no-made-period. SI 1998/1258 reg.7(b) has no period from its making (1 row). A named known limit.
- Dry run: `lat.label_switch` writes its per-law lines to OH&S's `cv-06-dry-run.csv`. Maritime's copy is moved to `switch-over/`, and OH&S's is restored from git. Switch-over's own tool: a `--csv` path per family is a small fix for the next family.
- Amending-law reader: repeal-table-wrong-enactment. The Mines Regulations 2014 repeals table gives the Mines and Quarries Act 1954's sections to HSWA 1974 (39 changes, 11 OH&S laws, 6 checked rows). This blocks any relabel of those OH&S laws until it is fixed.
- Store and build / Switch-over: check-run-time (GitHub #191). The label tools fold sequentially (about 12 min each, one core of 6) and each re-folds the family; the build has a long pole (UK_ukpga_1990_8, 417–532 s of 905 s). The proposal: profile first, fold once, bounded parallel folds, the biggest laws first. Where it slots in the workflow is open.
- The pipeline's Python checks moved to Elixir (GitHub #192): the census, shape mining and store scans; Flow for whole-store scans, Task.async_stream for per-law folds (#191).
- When (Jason, 2026-11-07): #191 and #192 are taken up after Maritime Safety is completed and before the next family. The other Python (QQ/BMS, Gemini, session maintenance) is dev tooling, not core logic.
