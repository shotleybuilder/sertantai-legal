---
session: 'Maritime Safety: Label fold'
status: closed
opened: '2026-11-06'
closed: '2026-11-06'
outcome: success
family: '💙 TRANSPORT: Maritime Safety'

summary: >
  The label fold passed for Maritime Safety on a code gate (Gate.Label): every label-rule, table-rule, tier and container-start breach is grouped by rule and law, and all 7 groups are named in labels.json. One agent pass over 43 rows (350k tokens) completed it. Two fold faults in Label.Made were fixed: a words insertion on the start day dropped the made period, and the made period carried tiers on its empty fields. Both agent finds became gate checks. Two upstream classes were parked: the Feed reader's Part locator (106 rows start late) and the Commencement reader's dropped partial first stage (21 changes).

decisions:
  - what: "Decision 1: the pass rule is a code gate plus one agent pass (S by shape and R, about 45 rows), the shape used for Merge and Evidence"
    why: "The OH&S rule (R pooled to the 95% bound over 5 × 30 rows a round, 10 rounds) is the sample → fix → resample loop the 2026-11-05 rule forbids"
    result: "Gate PASS, 7 groups named; one pass, 43 rows, 2 fold classes and 2 upstream classes, every class now in code or parked"
  - what: "An insertion of words on a law's start day does not date the provision (Label.Made)"
    why: "SI 1994/541 inserts words in SI 1993/3138 reg.81 on its start day; the provision was in the made text"
    result: "3 rows regain their made period; RULES.md made-before-start-is-prospective"
  - what: "Gate checks read the law's container insertions, not only the reaching changes"
    why: "A Part's insertion reaches a row through Label.containers/2, so the first version of the check (reaching only) found none of the agent's case"
    result: "106 MSA 1995 rows found"

metrics:
  maritime_strata: { laws: 117, rows: 24434, periods: 46976, table_breaks: 0, in_force: 23871, repealed: 388, repealed_saved: 117, prospective: 57, in_force_partial: 1, gap_undated_start: 409, gap_undated_change: 230 }
  gate: { groups: 7, known: 7, rows: 121, fold_fixed_rows: 3 }
  agent_pass: { seed: 201, rows: 43, ok: 8, wrong_fold: 31, wrong_upstream: 4, tokens: 350424 }
  regression: { ohs_gate: PASS, ohs_legacy_unconfirmed: 32, golden: "27/27", mix_test: 10160 }
  fold_time_minutes: { maritime: 12.5, ohs: 5.5, golden: 17.8 }

lessons:
  - title: A check on reaching changes misses a container's change
    detail: "A Part's whole insertion reaches its rows through Label.containers/2, not in `reaching`, so the first container-start check found 0 where the agent saw the fault. Pre-flighting the new check on the agent's own row would have caught it before a 13-minute family run."
    tag: tooling
  - title: The label rules catch value faults, not tier faults
    detail: "LabelRules runs on the timeline rows, which drop tiers, so the made-period tier leak (every made period, 31 of 43 sampled rows) was invisible to code until the agent pass. A tier check over the fold's own periods now sits in the gate."
    tag: data
  - title: The agent pass costs more on label items
    detail: "Three batches of about 15 label rows cost 350k tokens, against an estimate of 200k (items carry every reaching change; MSA 1995 rows reach 100+ feed records)."
    tag: tooling
  - title: An agent's 'reader fault' needs the store checked first
    detail: "The agent read MSA 1995 s.85(8)'s territory as unread by the feed reader, but the store holds in_force_for W and E+S+NI. The real question is a fold rule gap (C13 after a partial period), parked, not a reader bug."
    tag: data

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/label.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_rules/context.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/made.ex
  - backend/lib/mix/tasks/lat.label_check.ex
  - backend/lib/mix/tasks/lat.label_rules.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/gate/label_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_made_test.exs
  - backend/test/fixtures/label/labels.json
  - backend/data/reports/label/ (git-ignored)
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - .claude/skills/label-check/SKILL.md

depends_on:
  - 2026-11-06-maritime-safety-evidence

enables:
  - "Maritime Safety: Measures"

bugs:
  - pattern: "A feed effect on a section range with a Part or Chapter locator ('s. 130A-130E (Pt. 6) (Ch. 1A)', 's. 182A-182C (Pt. 6) (Ch. 5)', the Chapter ref marked Missing) is placed as a whole insertion of the Part, so the rows the range inserted start at the later 'Part insertion' (e.g. MSA 1995 s.130B(4): from 1997-07-17 credited to SI 1997/1539, not 1997-03-19 by 1997 c.28)"
    category: range-part-locator-placed
    module: change_vocabulary/readers/feed (placement of AffectedProvisions)
    affected: "2 effects; 106 MSA 1995 rows start on the false Part insertion (gate group, maritime-gate-2-containers.txt)"
    fix: "An effect on a section range places the range only; a (Pt. N) / (Ch. N) locator is context, never a target"
    step: Feed reader
    status: open
  - pattern: "An amending law's purpose-limited first stage is held as a commencement rule but no partial commencement change is emitted for the provisions it inserts, so the chosen date is the later full stage and the partial period is lost (e.g. MSA 1995 s.255N by 2011 c.8: SI 2015/133 art.2(1) from 2015-02-05 for art.2(2) purposes, the feed's partial date 2015-02-05; chosen 2015-04-14)"
    category: amending-law-staged-start-dropped
    module: commencement/amending.ex (Commencement.Amending)
    affected: "21 Maritime Safety text changes (MSA 1995 Pt 9A by 2011 c.8); others in the store (2006 c.16 s.89A, 1990 c.8 s.252(12), SI 2010/2214 reg.20(3A), (3D))"
    fix: "Emit each earlier stage a held rule names for an inserted provision as a partial commencement change of it"
    step: Commencement reader
    status: open
  - pattern: "ChangeVocabulary.Version hashes the label fold (change_vocabulary/label/*.ex, label_rules.ex) because change_vocabulary.ex's labels/5 reaches it (VersionCoverageTest), so a fold-only fix marks every built law stale in mix lat.stale though no stored change differs (after 33920924, Label.Made)"
    category: label-in-build-version
    module: change_vocabulary.ex (labels/5) and change_vocabulary/version.ex
    affected: "every built law (both families) shows code-stale after any fold fix"
    fix: "Move labels/5 out of change_vocabulary.ex into the label side, so the build's version stops reaching the fold; VersionCoverageTest then passes without the label globs"
    step: Store and build
    status: open
---

# Session: Maritime Safety: Label fold (CLOSED)

## Problem

Step 9 of the LAT Change Pipeline for TRANSPORT: Maritime Safety: a provision's resolved changes fold into the right label periods under the agreed conventions (AIMS `binds-on-date`). The step's last pass rule (S and T by shape, R pooled to the 95% bound, 10 rounds on OH&S) is the sample → fix → resample loop the 2026-11-05 rule forbids, so this step uses the code-gate shape that Merge and Evidence used. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-06).

## Todo

- ✅ Open the session: todos, Decision 1, baselines (OH&S label rules re-run)
- ✅ The gate (TDD): `Gate.Label`; `LabelRules.Context`; `--gate` and `--laws` in `lat.label_check`; `labels.json` started
- ✅ Review every breach group in the sources' records: `fix:`, `known:` or `check:`, with a report
- ✅ The one agent pass over 45 rows (S by shape and R); fold finds become code rules; cost recorded
- ✅ Fix the `fix:` groups and the agent's fold classes by reach (TDD): pre-flight on the laws concerned; triage into RULES.md; other steps' bugs parked
- ✅ Verify: gate PASS, OH&S label rules and statuses, golden 27/27, `mix test`
- ✅ Docs: WORKFLOW.md step 9, the `label-check` skill and history, parked Label fold bugs marked
- ✅ Close the session and the meta row; code and session commits separate; no push

## Dependencies

- ✅ Maritime Safety: Evidence closed (d348cff6, 2026-11-06)
- ✅ Golden frozen: `golden.exs`, 27 OH&S provisions (Maritime has none of its own)

## Decision 1: the pass rule (approved with the plan)

The shape Merge and Evidence used.

1. **A code gate.** `mix lat.label_check --family F --gate [--all]` (`ChangeVocabulary.Gate.Label`).
   - Every breach of the table's rules (`LabelPeriods.violations/1`) and of the label rules (`LabelRules.breaches/3`: before_amender, before_insertion, windsor_ni, no_made_period, saved_not_saved) is grouped `"<rule> @ <law>"`.
   - Each group is named in `test/fixtures/label/labels.json` as `known:`, `fix:` or `check:` (`MergeGate` semantics). OH&S's file-listed rows (`KnownLimits.sids/0`) stay listed apart.
   - The gaps and the S shapes are printed by count: a published figure, never a failure.
2. **One agent pass** of 45 rows, using the `label-check` prompt, in 3 batches of about 15: S by shape (2 a shape), the rest R on a new seed. A fold fault it finds becomes a new `LabelRules` rule over every row of both families, fixed by reach. An upstream fault is parked by its owning step. No resample.

Pass: the gate prints PASS; the agent pass is done once, its classes in code; OH&S's label rules still PASSED and its statuses unchanged (except a fix explained); golden 27/27; `mix test`; the shapes, gaps, statuses and a quality statement published.

## Baselines (2026-11-06, before any change)

Reports: `backend/data/reports/label/maritime-label-strata.txt`, `maritime-label-rules.txt`.

- **Maritime strata** (12 minutes): 117 laws folded, none failed; 24,434 rows; 46,973 periods, 0 breaking the table's rules.
  - S shapes: prospective 20,508 (mostly the made period), text change 3,359, ancestor 2,081, repealed 506, undated start 409, partial 406, undated change 230, territory narrowed 62, several laws 9, in force for one territory 5, renumbered 5.
  - Current status: in force 23,871; repealed 388; repealed and saved 117; prospective 57; partly in force 1.
  - T: 5,541 rows differ from today's label (2,312 have none today). Recorded only: Labels side by side.
- **Maritime label rules** (12 minutes): NOT PASSED, 11 rows: before_amender 7, no_made_period 4; legacy_unconfirmed 1 listed apart.
- **The fold's speed:** 12 minutes for Maritime against about 3 for OH&S's 20,371 rows. Recorded, not chased.
- **OH&S label rules** (6 minutes): PASSED, 20,371 rows, 0 breaching; legacy_unconfirmed 32 listed apart (`ohs-label-rules-0.txt`).

## The gate (todo 2)

- `ChangeVocabulary.Gate.Label` (`change_vocabulary/gate/label.ex`, pure; 5 tests): one entry per label-rule breach and per break of the table's rules, row by row, on the periods as compliance gets them; `MergeGate.items/gate`; `gaps/1` by shape.
- `LabelRules.Context` (`label_rules/context.ex`): the row context and `made_of` query, moved out of `lat.label_rules` (which now calls it), shared with the gate.
- `lat.label_check`: `--gate [--all]`, `--laws L1,L2` (a pre-flight: two laws in 9 seconds against 12 minutes), and `--stratum SR` (S by shape, then `--n` at random apart: the agent pass's one draw).
- `test/fixtures/label/labels.json` started.

## The breach groups (todo 3)

Gate 0 (`maritime-gate-0.txt`, 13½ minutes): 6 groups, 12 rows, all unreviewed; gaps: undated start 409, undated change 230. Rows dumped with their periods and changes: `maritime-gate-0-rows.json`. Each group was read in the stored changes, rules and the amending laws' text:

| Group | Rows | Finding | Status |
|---|---|---|---|
| no_made_period @ SI 1993/3138 | 3 | **Fold fault.** SI 1994/541 inserts words in reg.22(1), reg.81 and reg.85 on the start day (1994-03-21); `Label.Made` took any insertion that day as dating the provision, so the made period (from 1993-12-14) was dropped | fixed: `Made.dated_otherwise?` counts an insertion of the provision only; test in `label_made_test`; RULES.md `made-before-start-is-prospective`. Gate on the law: PASS |
| before_amender @ MSA 1995 | 5 | Upstream. s.256A, (1), (2): inserted by SI 1999/1820, undated (reg.1(2) "the principal appointed day" unread). s.284(4), s.85(3): 1997 c.28's changes dated 1996-09-15, the deemed day of its s.28(4) alone (s.28(5)) | known: Commencement reader (amending law's own clause unread; amending-law start misread) |
| before_amender @ MSA 1970 | 1 | s.42(1): a dated GB repeal (1992 c.52, 1992-07-16) and an undated NI repeal (NISI 1995/1980, order not held); the undated whole repeal reads repealed from the start | known: one row, below triage |
| before_amender @ SI 1975/2220 | 1 | reg.2 substituted by SI 1998/929, the law's text alone and undated; its other changes are dated 1998-05-01 | known: one change, upstream |
| no_made_period @ SI 1998/1258 | 1 | The law's start is undated (C10), so no made period can end | known: a gap |
| legacy_unconfirmed | 1 | Listed apart by design | known: by rule |

## The agent pass (todo 4)

One pass, seed 201, `--stratum SR --per 2 --n 23`: 43 rows (20 S by shape, 23 R), 3 batches. **Tokens: 350,424** (107,976 + 117,192 + 125,256), above the plan's estimate of about 200k. Sample: `maritime-agent-201.json`; reports `maritime-agent-201-b{1,2,3}-report.md`.

| Verdict | Rows |
|---|---|
| OK | 8 |
| WRONG-fold | 31, all one class (made-tier) |
| WRONG-upstream | 4 |

Every value (status, dates, changed_by, commenced_by, territory) is right on the 31 made-tier rows. Shapes judged to hold: ancestor, text change, partial, renumbered, repealed, several laws, territory narrowed, undated change, undated start.

- **made-tier (fold, fixed).** `Label.Made.prepend/2` copied the start period's tiers into the made period, so its empty `in_force_from` carried "primary" (RULES.md tier-per-field: an empty field has no tier). Fixed: the made period's emptied fields get no tier (`label_made_test`). As a code check: the gate's `tier: empty field` group, over every fold period of both families.
- **range-part-locator-placed (Feed reader, parked).** A feed range with a "(Pt. 6) (Ch. 1A)" locator is stored as the Part's insertion. MSA 1995 s.130B(4) then starts at the later one. As a code check, the gate's `start: a container's insertion after its own` group finds 106 rows; it reads the law's container insertions, since a Part's insertion reaches a row through `Label.containers/2`, not as a reaching change. Named `known:` under the parked bug.
- **amending-law-staged-start-dropped (Commencement reader, parked).** MSA 1995 s.255N(5): SI 2015/133's purpose-limited first stage (2015-02-05) is held as a rule but not emitted as a partial commencement. 21 Maritime changes (the SQL count is in the bug).
- **MSA 1995 s.85(8)(a), (c), not a reader fault.** The agent said the feed's territory was unread, but the store holds `in_force_for` W (WSI 2007/204) and E+S+NI (SI 2007/1375). The fold widens a partial row to everywhere on the Welsh full commencement. C13 covers prospective → one territory only, not partial → full for one territory. Parked as a question (below), not a fold fault under today's rules.
- **Gaps:** territory nil where no extent is held (SI 1997/1508, 1975/2220, 2025/1298, 2023/787).

## Results (todos 5–7)

- **Gate: PASS** on 7 groups, all `known:`. Gate 1 (`maritime-gate-1.txt`, 12½ minutes) covers the family. The corrected container check was re-run on the four laws holding Part insertions (`maritime-gate-2-containers.txt`) and spliced in: its 106-row group is named under the Feed reader's parked bug.
- **Fixes (fold, TDD):**
  - `Label.Made`: a words insertion on the start day no longer drops the made period (3 rows);
  - the made period's emptied fields carry no tier (every made period).
- **Gate checks** from the agent pass: `tier: empty field` and `start: a container's insertion after its own`.
- **Maritime statuses unchanged:** in force 23,871; repealed 388; repealed and saved 117; prospective 57; partly in force 1. Periods 46,973 → 46,976 (SI 1993/3138's made periods).
- **Gaps (published):** undated start 409 rows, undated change 230. 0 breaks of the table's rules.
- **OH&S (regression):** gate PASS (`ohs-gate-1.txt`: legacy_unconfirmed 32, as at baseline; no tier or start breach). Its two laws with Part insertions pass the corrected container check. Statuses: in force 18,564; repealed and saved 1,183; repealed 623; partly in force 1. Both fixes act only on the made period before a row's first period, so no current status can move.
- **Golden:** 27/27 from inputs (17m50s, `golden-1.txt`). **`mix test`:** 10,160 pass.
- **Docs:**
  - WORKFLOW.md step 9: the gate and its pass rule;
  - RULES.md: `made-before-start-is-prospective` (words insertion), `tier-per-field` (the made period), a known-limits row for one-row label forms;
  - the `label-check` skill: steps, pass, known classes, history.
- **Parked Label fold bugs:** the five from OH&S were reached by no Maritime group and stay open.

**Quality statement.** Every Maritime Safety row folds without breaking the table's rules or a label rule outside 7 named groups (121 rows, upstream or below triage). The agent pass found one fold class, the made period's tier: fixed, and now a gate check. No label value was wrong from the fold on the 43 rows judged. Four rows were wrong upstream, and the class behind one of them reaches 106 rows. The labels' main exposure is upstream:
- the Feed reader's Part locator (106 rows start late);
- the Commencement reader's amending laws: undated, misdated, and partial first stages dropped (21 changes).

## Decision 2: a one-territory full commencement of a row already partly in force (for Jason, open)

- **Question.** MSA 1995 s.85(8) is partly in force everywhere from 2006-07-19. Then WSI 2007/204 commences it fully for Wales on 2007-04-02, and SI 2007/1375 commences it fully for E, S and NI on 2007-07-01. Today the fold labels it fully in force everywhere from 2007-04-02, so for three months it overstates England, Scotland and NI. The rule (C13) covers a prospective row commenced for one territory, not a partial one.
- **Aim:** `binds-on-date`, `unknown-over-guess`.
- **Options:**
  - **A.** Stay partly in force everywhere until every territory is full. The 2007-04-02 order still opens a version, with commenced_by WSI 2007/204. This understates Wales for three months and never overstates.
  - **B.** In force in Wales only from 2007-04-02 (C13 as for a prospective row), widening on 2007-07-01. This drops the partial force in E, S and NI for those months.
  - **C.** Keep today's union. This overstates E, S and NI.
  - **D.** Name it a known limit and decide later.
- **Recommendation: A.** Gemini Flash agrees (`backend/data/code-reviews/maritime-label-fold-c13-partial-gemini.md`). Its "better" option, one status per territory in one period, is a change to the timeline's shape: out of v0.1. Of its edge cases, a later repeal for one territory is already the rule `one-territory-repeal-narrows`. Under A, several territories commenced in turn stay partial until the last.
- **Reach:** up to 5 Maritime rows (the `in_force_for` shape).
- **If A:** a small fold fix (`Label.Day` `commenced_for/4`: a partial row whose territory isn't fully commenced stays partial), with a test and a pre-flight on MSA 1995. It would be a Label fold item, run when Jason says.

## Parking list

- Label fold: C13 after a partial period, now Decision 2 (open). A one-territory full commencement of a partly-in-force row (MSA 1995 s.85(8), WSI 2007/204 then SI 2007/1375) labels it in force everywhere from the first. The rules define only prospective → one territory. Up to 5 Maritime rows (the `in_force_for` shape).
- Feed reader: range-part-locator-placed (bug above).
- Commencement reader: amending-law-staged-start-dropped (bug above).
- Store and build: `label-in-build-version` (raised as a bug above, 2026-11-06). `ChangeVocabulary.Version` globs `change_vocabulary/label/*.ex` (and `label_rules.ex`, a check), so a fold-only fix (this step's `Label.Made`) marks every built law stale though no stored change differs. The fix: check whether anything the build stores reads the fold; if nothing does, move the fold's modules out of the version.
- Label fold, the fold's speed: 12–13½ minutes for Maritime's 24,434 rows against 6 for OH&S's 20,371 (MSA 1995's 3,585 rows, s.284's 100+ feed records). Recorded; `--laws` covers pre-flights.
