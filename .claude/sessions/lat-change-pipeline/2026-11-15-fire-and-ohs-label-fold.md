---
session: 'Fire and OH&S: Label fold'
status: closed
opened: '2026-11-15'
closed: '2026-11-16'
outcome: success
family: 'Fire and OH&S (round)'

summary: >
  The Label fold passed for the Fire and OH&S round and the three switched families: the round's one unnamed group (asp 2012/8's made period, 9 rows) was named a known limit, and all four gates PASS. Five of the seven parked bugs were fixed: Evidence's chosen stages now fold (Label.Stages, 442 changes; EPA Part IIA's 673 rows reach in force), the whole law revoked provision by provision reaches its sub-rows (Label.WholeLaw, SI 2008/2337), and 31 checked rows were accepted with their rules, so the checked rows PASS. Golden 27/27; mix test 11,234; step close every gate PASS, Stale laws 139 (labels, Store and build).

decisions:
  - what: "Decision 1 (a): no_made_period @ asp 2012/8 named a known limit"
    why: "9 rows in 1 law, below the triage size; the periods after the made day are right"
    result: "labels.json +1; round gate PASS"
  - what: "Decision 2 (a): the chosen stages unfold into the commencements the fold reads"
    why: "a staged change's partial period was lost (HSWA s.13(6A) partly 2014-03-10, fully 2014-04-01); 442 changes over triage in every scope"
    result: "Label.Stages; EP partly in force 2,130 -> 1,456; round statuses unchanged; golden 27/27"
  - what: "Decision 3 (a): an unstated-level provision repeal reaches the rows under it when one law on one day repeals every top-level provision"
    why: "the fold holds the law's rows; a whole-law record legislation.gov.uk does not hold would be invented (option b)"
    result: "SI 2008/2337's 14 sub-rows repealed and saved; no other row moved; never on a scoped LAT (the session's guard)"
  - what: "Decisions 4 (a) and 6 (a): 31 checked rows accepted with their rules"
    why: "HSWA s.64's order is not held (unknown over guess); CLP 53a/53b's UK-wide years are right; SI 1992/3004's 1993 stage was noted missing by its checkers; a staged words change dates from its first stage, golden's one convention"
    result: "checked rows 744: 696 match, 47 known, 1 upstream, PASSED"

metrics:
  gate_round: { laws: 139, rows: 27206, periods_before: 50100, periods_after: 50151, groups: 7, not_named_before: 1, not_named_after: 0 }
  status_round: { in_force: 25605, prospective: 738, repealed: 391, repealed_saved: 362, in_force_partial: 110 }
  gaps_round: { undated_start: 2447, undated_change: 311 }
  switched: { ep_partial: "2130 -> 1456", ep_repealed: "723 -> 725", occupational_repealed_saved: "1169 -> 1183", maritime: unchanged }
  stages: { round: 136, ep: 163, occupational: 115, maritime: 28 }
  checked_rows: { changed_before: 3, accepted: 31, match_after: 696 }
  golden: "27/27"
  mix_test: 11234
  fixer_tokens: { stages: "about 228k (call and 3 follow-ups)", whole_law: "about 95k" }

lessons:
  - title: Diff the checked rows after a fold fix, not only the gates
    detail: "The gates and golden passed after the stages fix, but the checked rows went from 3 changed to 31. Each needed reading: 22 were gains the checkers had noted missing, and 6 were a convention change (a staged words change dated from its first stage). Run mix lat.label_checked --list before calling a fold fix done."
    tag: data
  - title: A status diff per scope finds a fix's regressions the tests miss
    detail: "The fixer's tests passed. The status counts against gate-0 still showed the round's partly-in-force rows rise by 2 (Petroleum Act 1998 s.17A: a territorial staged removal leaving NI partly in force) and EP's repealed rise by 2. Fold the affected laws at HEAD and now (copy the working files, check out HEAD, fold, restore) to name each move."
    tag: tooling
  - title: A whole-law rule needs every row of the law
    detail: "'Every top-level provision' was judged on a scoped LAT's 4 rows (FPA 1971), which would have marked a partial revocation as the whole law. Rules that reason over the whole law run only where the fold holds all of it (LabelSource scoped?/1)."
    tag: data
  - title: Unfolding a removal reaches more than its own provision
    detail: "A staged removal unfolded past a later re-insertion gave a new provision (EPA s.75(2)(a)[S], made again in 2011) a history from 2003. Guard every unfold against a re-making of the same target."
    tag: data

bugs:
  - pattern: "A commencement stage qualified 'in relation to' (for S) is carried as not partial, so the stages fold reads it as the full stage for that territory (MSA 1995 s.136A; EA 1995 s.5(5)(i)n1, 2015-04-01 by SSI 2015/74)"
    category: in-relation-to-stage-read-full
    module: readers/amending_commencement.ex (stages/1, stage/2)
    affected: "2 rows seen (MSA 1995 s.136A, EA 1995 s.5(5)(i)n1); full reach unknown"
    fix: "a stage whose qualification limits it ('in relation to', 'for the purposes of') is partial, whatever its date against full_from"
    step: Commencement reader
    status: open
  - pattern: "The Label fold does not read feed.stages, so each territory's own date and order is not folded; Label.Facts.full?/1 reads 'complete + territory' as full (EP 74 effects; MSA 1995 s.85(8); HSWA s.23(4))"
    category: stages-not-folded
    module: Label.Stages
    affected: "6,413 effects carry stages; 442 changes with chosen stages in four families"
    fix: "fixed: the chosen stages unfold into commencements (Decision 2 a; RULES stages-fold-as-commencements, staged-removal-in-part-then-repealed); 442 changes"
    step: Label fold
    status: fixed
  - pattern: "A purpose-limited first stage is carried on the amending law's claim (commencement.stages) but the fold does not read it, so the partial period is lost (MSA 1995 s.255N by 2011 c.8)"
    category: label-reads-commencement-stages
    module: Label.Stages
    affected: "36 round changes, 60 Maritime"
    fix: "fixed with stages-not-folded (Decision 2 a): MSA 1995 Part 9A rows show their partial period; six no longer start in 1995"
    step: Label fold
    status: fixed
  - pattern: "A whole law revoked provision by provision with no level stated keeps its sub-rows in force: the refreshed feed lists SI 2009/716's revocation of SI 2008/2337 as reg.1–7 (was one whole-law effect), so 14 sub-paragraphs (reg.1(1), reg.2(a) …) of a revoked law read in force (labels written, Decision 3 (c))"
    category: revocation-listed-per-provision
    module: Label.WholeLaw
    affected: "1 law, 14 rows"
    fix: "fixed (Decision 3 a; RULES whole-law-revoked-provision-by-provision): all 21 rows of SI 2008/2337 repealed and saved"
    step: Label fold
    status: fixed
  - pattern: "HSWA 1974 s.64's checked label has in_force_from 1974-07-31, but the Act is all by order and none of its six held orders (nor SI 1974/1439) names s.64, so the label now has none (left-to-an-order-date-unknown)"
    category: checked-row-by-order-no-order
    module: test/fixtures/change_vocabulary/switch_checked.json
    affected: "1 checked row"
    fix: "fixed: the current label accepted with left-to-an-order-date-unknown as the why (Decision 4 a)"
    step: Label fold
    status: fixed
  - pattern: "CLP (EU) 2008/1272 Arts 53a and 53b: expected in force in NI only from 2022-11-01 (omitted for GB by SI 2022/1037, kept in NI by the Windsor rule), now E+W+S+NI from 2019-06-20, then a period from 2022-11-01"
    category: windsor-ni-insertion-undated
    module: test/fixtures/change_vocabulary/switch_checked.json
    affected: "2 checked rows"
    fix: "fixed: the fold's label accepted (Decision 4 a): UK-wide from EU 2019/1243's making (never-before-its-maker; entry into force KEU-eif), NI only from 2022-11-01"
    step: Label fold
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/stages.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/whole_law.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_stages_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_whole_law_test.exs
  - backend/test/fixtures/label/labels.json
  - backend/test/fixtures/change_vocabulary/switch_checked.json
  - backend/data/reports/label/fire-and-ohs-label-review-1.md
  - backend/data/reports/label/fire-and-ohs-step-close-2026-11-16.txt

depends_on:
  - 2026-11-15-fire-and-ohs-evidence

enables:
  - 'Fire and OH&S: Measures'
---

# Session: Fire and OH&S: Label fold (CLOSED)

## Problem

This is step 9 of the LAT Change Pipeline for the Fire and OH&S round. Its aim is that each provision's resolved changes fold into the right label periods (status, territory, in force from, changed by, commenced by, and a tier per field).
- **Why now:** Evidence now gives each change its chosen stages (`Resolved.stages`, rule `stages-go-with-the-date`), which unblocks the fold's two parked stages bugs.
- **Parked bugs:** the 7 bugs parked on the Label fold are taken here, whatever family found them.
- **Plan:** `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`, approved 2026-11-15.

## Todo

- ✅ Open the step session and meta row; pre-flight the round's name in `lat.label_check`; baseline (`--gate --all --strata`) for the round and the three switched families; the 7 parked bugs
- ✅ Review every unnamed group; measure each parked bug's reach (stages by source and rows moved); trace the 3 checked rows; `fire-and-ohs-label-review-1.md` (dry run)
- ✅ Decisions for Jason: names and known limits, the stages fold's rule, the revocation level, HSWA s.64 and CLP Arts 53a/53b, faults to park
- ✅ Fix the decided fold classes, test first (fixer); `--laws` pre-flight; the four gates again
- ✅ Write the names to `labels.json` (sorted); four gates PASS; statuses against the baseline, every move explained
- ✅ Pass: golden 27/27, checked rows, `mix test` and the hooks' checks clean; shapes, gaps, statuses, quality statement
- ✅ Step close: `mix lat.step_close --family "Fire and OH&S" --step "Label fold"`
- ✅ Close: WORKFLOW step 9, RULES, the skill's history, parked bugs, meta row, commits (no push unless asked)

## Dependencies

- ✅ Fire and OH&S: Evidence closed and pushed (35f6bac7): `Resolved.stages`
- ✅ Environmental Protection: Label fold (2026-11-11), the method and the gate checks

## Pass rule

The plan fixes it: the round's gate PASS; the switched families' gates PASS, with their statuses unchanged except by an explained fix; golden 27/27; the 3 checked rows fixed or accepted with a rule; `mix test` and the hooks' checks clean; shapes, gaps, statuses and a quality statement published; the step close recorded. **Triage size:** 10 rows, or 2 or more laws. **Frozen:** `golden.exs`, `evidence.json`, `merges.json`, `disagreements.json`, and the checked-row fixtures.

## Parked bugs on this step

| Bug | Size | Plan |
|---|---|---|
| `stages-not-folded` (MSA 1995 s.85(8), HSWA s.23(4)) | 6,413 effects carry stages | Measure on `resolved.stages`; fix over triage |
| `label-reads-commencement-stages` (MSA 1995 s.255N) | 36 round changes, 60 Maritime | Together with the bug above |
| `revocation-listed-per-provision` (SI 2008/2337) | 1 law, 14 rows | Find the owner; fix if the fold's and over triage |
| `checked-row-by-order-no-order` (HSWA s.64) | 1 checked row | Jason: accept with the rule, or find the order |
| `windsor-ni-insertion-undated` (CLP Arts 53a, 53b) | 2 checked rows | Trace the 2019-06-20 period |
| `devolved-insertion-reaches-other-version` (EPA 1990) | 8 rows, 1 law | Known limits; measure in the round |
| EU directives after IP completion day | 15 OH&S directives | Stays parked: needs the Windsor source |

## Baseline (2026-11-15, the stored changes as rebuilt at Evidence)

| Scope | Laws | Rows | Periods | Gate |
|---|---|---|---|---|
| The round | 139 | 27,206 | 50,100 | FAIL: 1 group not named (no_made_period @ asp 2012/8, 9 rows) |
| Environmental Protection | 122 | 35,766 | 69,427 | PASS |
| Occupational | 149 | 20,371 | 38,735 | PASS |
| Maritime Safety | 117 | 24,434 | 47,497 | PASS |

- **Round status:** in force 25,605; prospective 738; repealed 391; repealed and saved 362; partly in force 110.
- **Gaps:** undated start 2,447; undated change 311.
- **Table breaks:** 0 in every scope.
- **Reports:** `backend/data/reports/label/fire-and-ohs-gate-0.txt`, `fire-and-ohs-switched-*-gate-0.txt`.
- **Review:** `fire-and-ohs-label-review-1.md`.

## Decisions for Jason

**Aim for all of them:** `binds-on-date`, so that a label says from when, where and how fully a provision binds.

1. **no_made_period @ asp 2012/8 (9 rows).** The made period (7 to 8 Aug 2012) is dropped because SSI 2013/51's later full commencement counts as "dated otherwise". The periods after it are right.
   - (a) `known:` (below the triage size);
   - (b) fix: an order after the row's start never denies the making.

   **Recommend (a).**
2. **Stages:** 442 changes across the four scopes. The partial period before the full date is lost (2013 c.32 on s.61(7A): partly 10 Mar 2014, fully 1 Apr 2014).
   - (a) fix in the fold: the chosen stages unfold into the commencements the fold already reads. The change opens at its first stage, partly in force, and each later stage is a commencement with its own date, order, territory and whether it is partial. One fixer call.
   - (b) a known limit.

   **Recommend (a).** The switched families' statuses will move where stages reach them. Each move is counted and explained.
3. **Revocation listed per provision** (SI 2008/2337, 14 rows).
   - (a) fix in the fold: a provision repeal of unstated level reaches the rows under it when the same law, on the same day, repeals every top-level provision of the law;
   - (b) move it to the Feed reader (read the listing as the whole law, `*`);
   - (c) a known limit.

   **Recommend (a).** The fold holds the law's rows, while (b) would make a whole-law record legislation.gov.uk does not hold.
4. **The 3 checked rows** (HSWA s.64; CLP Arts 53a and 53b).
   - (a) accept the current labels with their rules: s.64's commencing order is not held, so its date is unknown (`left-to-an-order-date-unknown`). CLP shows its UK-wide years from 2019/1243's making, `never-before-its-maker`; the entry-into-force date is the Feed reader's known `KEU-eif`;
   - (b) keep them failing and parked.

   **Recommend (a),** run after the fixes, so the accepted periods are the final ones.
5. **Parked as they are:** `devolved-insertion-reaches-other-version` (known limits, 8 rows, no round reach) and the EU directives (15, which need the Windsor source). No other step's fault was found.

**Decided (Jason 2026-11-15):** 1 (a) known limit; 2 (a) fix the stages in the fold; 3 (a) fix the revocation reach in the fold; 4 (a) accept the 3 checked rows after the fixes.

## Fixes (todo 4)

**Fixer call 1: the stages** (Decision 2 a). It took about 228k tokens over the call and two follow-ups, over the 150k cap. `Label.Stages.unfold/1` is applied at the top of `Label.fold/3`, and `LabelRules.before_insertion` reads an insertion at its first stage. 17 tests are in `label_stages_test.exs`.
- **A whole insertion:** the change opens at its first stage, partly in force, and each later stage is a commencement (its date, order, territory, and whether partial).
- **A words change or substitution:** one version from the first stage. A same-day stage credits both orders; a later stage opens nothing. Golden's TCPA 1990 s.284(3)(a) and RULES `text-change-carries-its-stages` hold this.
- **A whole removal,** as `Readers.Feed.staged_removal/2`: a removal in part at each partial stage, then the repeal at the full stage. A partial stage for one territory alone is the repeal there (`one-territory-repeal-narrows`). A removal resolved as whole, with only partial stages read, keeps its repeal.
- **Never past a re-making:** a removal is not unfolded where a whole insertion or substitution of the same target is dated after its first stage. This came from EPA s.75(2)(a)–(c)[S], a regression of the first cut, now back as it was.

**Reach** (in memory, against the HEAD fold):

| Law | Rows changed | Periods | Current-label moves |
|---|---|---|---|
| EPA 1990 | 713 | 9,274 → 10,006 | status 673 (partly in force → in force), territory 1, in force from 675, changed by 673, commenced by 623 |
| EA 1995 | 8 | 4,634 → 4,636 | status 1, territory 1, in force from 2, changed by 2, commenced by 3 |
| HSWA 1974 | 93 | 2,437 → 2,494 | in force from 34, changed by 4, commenced by 2 |
| Fire Safety Order 2005 | 7 | 1,167 → 1,170 | commenced by 3 (SI 2023/362 and WSI 2023/914 both) |
| Merchant Shipping Act 1995 | 170 | 6,490 → 6,641 | changed by 5, territory 1, in force from 1 |
| Fire Precautions Act 1971 | 0 | | none |

**Moves explained:**
- **EPA Part IIA:** 673 rows go from partly in force for good to in force from 2001-07-01, once E, S and W are each commenced.
- **HSWA:** 34 rows' current text is now dated from its partial stage (2014-03-10, not 2014-04-01), by the convention. s.3(2) and s.82(3)(b) are dated from the Act's own regulation-making stage, 2015-03-26, and SI 2015/1732 drops from their label.
- **MSA 1995:** in four Part 9A rows, a words change during the partial period (SI 2015/664) replaces the inserter in changed by. Six Part 9A rows no longer start in 1995.
- **EPA s.75(8A)n1[E+W]:** the repeal now runs E on 2022-01-24, then W on 2022-03-07.

**Upstream, parked:** MSA s.136A and EA 1995 s.5(5)(i)n1 carry a stage qualified "in relation to" but marked not partial, so each row widens to E+W+S+NI. This is the Commencement reader's `in-relation-to-stage-read-full`.

**Checks:** golden 27/27; label tests 157 pass; Credo diff clean; the pre-flight gates (HSWA, MSA, EPA and EA 1995, FPA 1971 and FSO 2005) PASS.

**Fixer call 2: the revocation listed per provision** (Decision 3 a). About 95k tokens.
- **The fix:** `Label.WholeLaw` (new) marks an unstated-level provision repeal as reaching the rows under it, when one law on one day repeals every top-level provision. Part and Chapter rows don't count, since they follow their children. The level stays unstated (a `sources.reach` mark), so the repeal's own row reads as before.
- **Where it applies:** only where the fold holds every row (`all_rows`, from `LabelSource`), never golden's few rows. The session added a guard: never on a scoped LAT (`lat_scope` fragments), where "every top-level provision" can't be judged. FPA 1971, with 4 scoped rows, was the case.
- **Reach:**
  - the rule fires on 5 laws in the four scopes;
  - rows move only in SI 2008/2337: 14 sub-rows go from in force to repealed and saved by SI 2009/716, and all 21 rows now read repealed and saved;
  - no other period moved.
- **Tests:** 9 in `label_whole_law_test.exs`, seen failing first.
- **Checks:** the change-vocabulary tests, 3,673 passed. The test helper `rules/3`'s unused default was dropped, which cleared a test warning. Golden 27/27; Credo diff clean; the pre-flight gates PASS.

**Session follow-up: a removal for a territory.** The four gates after the fixes (`*-gate-1.txt`) showed Petroleum Act 1998 ss.17A and 17B left partly in force in NI. 2004 c.20 repeals them for E+W+S in stages: partly 2004-09-01, then wholly 2004-10-05.
- **The fix:** where a removal has a territory of its own, its in-part stages are dropped, and only the stages for one territory alone and the full stage fold. Test first (`label_stages_test.exs`, 18 tests).
- **Gates after it (`*-gate-2.txt`):** the round's statuses are back to the baseline, and the EP, Occupational and Maritime gates PASS. Gaps are unchanged everywhere, and there are 0 table breaks.
- **Status moves against the baseline, all explained:**

  | Scope | Moves |
  |---|---|
  | EP | 674 partly in force → in force (EPA Part IIA 673, EA 1995 s.108(16)[E+W] 1); 2 in force → repealed (SSI 2018/219 reg.3(3)(a), (b): SSI 2025/165's new reg.3(3) no longer makes them, `quote-dropped-numbers-are-repealed`, now on its full day) |
  | Occupational | 14 in force → repealed and saved (SI 2008/2337) |
  | Maritime | none |

- **Gate:** `no_made_period @ UK_asp_2012_8` is named in `labels.json` (Decision 1 a). The round re-gated on asp 2012/8: PASS.

## Decisions for Jason (2)

6. **The checked rows the stages fix moved:** 28 rows. Changed checked rows went from 3 to 31.
   - **SI 1992/3004's 1993 stage (22 rows,** Factories Act 1961 and OSRPA 1963). The Workplace Regulations repeal these provisions for new workplaces from 1993-01-01, and wholly from 1996-01-01. The fold now shows them partly in force from 1993 to 1996. The checkers' own notes say "1993 stage not shown" and "staged 1993 repeal for new workplaces not shown". This is a gain.
   - **HSWA words changes by 2013 c.32 (6 rows:** s.11(4)(a), s.11(4)(ii), s.18(7), s.27(1)(b), s.28(4)[S], s.44(7)(b)). The current text is now dated from its partial stage (2014-03-10, by SI 2014/251 "in relation to" purposes), not the full day 2014-04-01. That is the one convention for a staged text change. Golden TCPA 1990 s.284(3)(a) holds it (a Welsh staged substitution dated from its first stage), as does RULES `text-change-carries-its-stages`. Before, a commencement-dated words change used the full day and a feed-dated one the first stage. The cost: a words change's later stages are not shown. s.11(4)(ii), an insertion, now shows its partial period properly.
   - **Options:**
     - (a) accept the 28 with these reasons, plus the 3 of Decision 4;
     - (b) accept the 22 and keep the 6 HSWA rows failing, parked with the Label fold (a rule for the stages of a commencement-dated words change, against golden's convention).

   **Recommend (a):** one convention, held by golden. Record the cost as a known limit ("a staged words change dates from its first stage; later stages are not shown").

**Decided (Jason 2026-11-16):** 6 (a): all 31 checked rows accepted with their reasons (`mix lat.label_checked --accept`): the 22 SI 1992/3004 rows, the 6 HSWA words rows, HSWA s.64 and CLP Arts 53a and 53b. Checked rows: 744 = 696 match, 47 known, 1 upstream. **PASSED.**

## Pass (todo 6)

1. **Round gate PASS:** 7 groups, all named; 6 are legacy markup, listed apart by design (`fire-and-ohs-gate-2.txt` and the asp 2012/8 re-gate).
2. **Switched families PASS:** EP, Occupational and Maritime (`*-gate-2.txt`). Every status move is explained above.
3. **Golden 27/27** (`fire-and-ohs-golden-2026-11-16.txt`).
4. **Checked rows PASSED:** 696 match, 47 known, 1 upstream.
5. **Checks:**
   - `mix test`: 11,234 passed, 0 failures (`fire-and-ohs-mix-test-2026-11-16.txt`);
   - the change-vocabulary tests, with warnings as errors, are clean;
   - the Credo diff adds no issues.
6. **Published, for the round:**
   - **Shapes:** prospective 19,755; text change 4,936; ancestor 3,477; undated start 2,447; partial 1,155 (was 1,104: the stages); territory narrowed 1,091; version 1,027; repealed 757; in force for 663; undated change 311; applied 237; several laws 198; renumbered 14.
   - **Statuses:** in force 25,605; prospective 738; repealed 391; repealed and saved 362; partly in force 110.
   - **Periods:** 50,100 → 50,151.
   - **Gaps:** undated start 2,447; undated change 311.

**Quality statement:** the fold's rules held on every reviewed group. The round needed one name, a known limit of 9 rows.
- **The two parked stages bugs are fixed:** 442 changes now fold their chosen stages.
  - A staged insertion shows its partial period.
  - A staged removal is removed in part, then repealed, or repealed territory by territory.
  - A staged text change dates from its first stage.
- **The whole-law revocation listed per provision is fixed** (14 rows).
- **The 31 checked rows the step touched are accepted** with their rules.
- **Upstream:** 1 class, parked with the Commencement reader (2 rows).
- **Known limits:** asp 2012/8's made period (9 rows), and a staged words change's later stages not shown.

## Step close (todo 7)

`mix lat.step_close --family "Fire and OH&S" --step "Label fold"` (`fire-and-ohs-step-close-2026-11-16.txt`): Sources, Feed reader, Markup reader, Commencement reader, Extent reader, Amending-law reader, Merge, Evidence, **Label fold** and **Checked rows** all PASS. Stale laws FAIL: 139, all labels (the change register 0). It stays parked with Store and build, as at every earlier close.

## Close (todo 8)

- **Docs changed:**
  - RULES: `stages-fold-as-commencements`, `staged-removal-in-part-then-repealed`, `whole-law-revoked-provision-by-provision`, and a Known limits row (asp 2012/8's made period; a staged words change's later stages);
  - WORKFLOW step 9 (the round's paragraph);
  - the `label-check` skill's history.
- **Parked bugs:** 5 fixed (stages ×2, revocation, the 3 checked rows). 2 left:
  - `devolved-insertion-reaches-other-version`: 8 EPA rows, named known limits, no round reach;
  - the EU directives: 15, which need the Windsor source.

  1 raised with the Commencement reader.

## Parking list

- Commencement reader: in-relation-to-stage-read-full: a stage qualified "in relation to" carried as not partial (MSA 1995 s.136A, EA 1995 s.5(5)(i)n1)
