---
session: 'Environmental Protection: Evidence'
status: closed
opened: '2026-11-10'
closed: '2026-11-11'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'

summary: >
  Evidence passed for Environmental Protection on the code gate, with OH&S's parked 14 groups and Maritime's 3 new ones named alongside (59 statuses; all three gates PASS). The table's order was right on every group: 154 wrong chosen values are misread primary claims, parked with the Commencement and Amending-law readers as three new classes. The one agent pass (seed 62, 155,068 tokens) found one new class, the feed's "in accordance with" placeholder date on its law's made day, which was fixed in the table (Decision 4) and followed by one rebuild.

decisions:
  - what: "Decision 1: the 59 drafted statuses written as drafted, misreads known: with their reader's parked class"
    why: "the gate judges the table's order; a misread primary claim winning is the reader's (Maritime Safety: Evidence, Decision 1)"
    result: "EP 43, OH&S 14 and Maritime 3 groups named; all three gates PASS"
  - what: "Decision 2: a Welsh SI cited by its UK S.I. number is a named known form, no code"
    why: "the feed's name is already chosen and right; comparing uksi N with wsi N would match laws by year and number alone"
    result: "29 changes in 5 laws; RULES known-limits row"
  - what: "Decision 3: four new classes parked with sizes; this step's two parked bugs closed"
    why: "the misreads are the readers'; the feed Type error is 1 change and the moved-words form appears in no group"
    result: "Commencement reader 42/22/22, Amending-law reader 1; OH&S gate fixed; KF-type a known limit"
  - what: "Decision 4 (B): the feed's 'in accordance with' date on its law's made day is never a date, fixed in the table"
    why: "the agent pass: SI 2016/562's 12 changes dated six years early on a placeholder; 15 of 145 such records in the three families"
    result: "Readers.AffectingMade + Evidence :not_made_day; preview moved exactly those dates; one rebuild of three families"

metrics:
  strata_ep: { V: 471, D: 182, A: 5653 }
  gate: { ep_reviewed: 43, ohs_reviewed: 14, maritime_reviewed: 3, statuses_added: 59 }
  wrong_chosen: { commencement_reader: 153, amending_law_reader: 1, legislation_gov_uk_forms: 2 }
  agent_pass: { seed: 62, items: 50, ok: 36, gap: 12, wrong: 2, doubtful: 0, tokens: 155068 }
  gaps_ep: { commenced_by: 4128, no_rules: 199, date: 391, level: 24, by: 7 }
  regression: { ohs: "V 146 D 38", maritime: "V 195 D 13" }
  rebuild_s: { ep: 323, ohs: 93, maritime: 50 }
  golden: "27/27"
  mix_test: "10,667 pass"

lessons:
  - title: Build and check with the family's full name
    detail: "--family \"OH&S\" matches four OH&S families (189 laws), not the step's 'OH&S: Occupational / Personal Safety' (149). The baseline looked the same only because the other 40 laws held no stored changes; the rebuild then built them all (9,713 changes). Copy the family string from the last step's rebuild log."
    tag: tooling
  - title: Evaluate commencement in the build's own context
    detail: "Order.context/0 and the build's rules differ (feed_commencement and clause_staged are excluded, and Parts come from legal_articles), so a direct Evaluator call can show 'full' where the build reads 'partial'. Reproduce with OwnClause.context and the build's rule filter before naming a cause."
    tag: tooling
  - title: A date that equals its law's made day under 'in accordance with' is a pointer
    detail: "legislation.gov.uk's feed fills InForce Date with the made or Royal Assent day when it can only point to the law's clause. Comparing it with the made day, rather than distrusting 'in accordance with' as a whole, kept the other 130 dated records."
    tag: data

bugs:
  - pattern: "An order's 'in section N— (i) in subsection (2), paragraph (f) …' (or 'in Part 1(B) of Schedule 15 the entries relating to …') read as all of section N or the Schedule (SI 2004/2528 art.2(q) on Water Act 2003 s.86; SI 2007/709 on 2006 c.48 Sch.15)"
    category: order-in-list-read-whole
    module: commencement/ (order list reading)
    affected: "42 changes in 2 laws (Environmental Protection: 2003 c.37 40, 2006 c.48 2)"
    fix: "Read 'in section N—' and 'in Part X of Schedule N the entries relating to' as headings over their items, never as the whole provision"
    step: Commencement reader
    status: open
  - pattern: "An order item read as partial though it brings the provision wholly in: its bracketed heading taken as a territory or purpose ('(water and sewerage undertakers in England: …)', '(… for the purpose of access rights)'), or a Welsh order's W for a Welsh Act extending to England and Wales (SI 2022/48 on 2021 c.30 s.86; WSI 2023/1149 on asc 2023/2)"
    category: order-item-read-partial
    module: commencement/ (order list reading; territory)
    affected: "22 changes in 3 laws (asc 2023/2 17, 2021 c.30 4, asp 2026/6 1)"
    fix: "Drop bracketed headings before reading qualifiers; a Welsh order on a Welsh Act's provision is the whole in-force"
    step: Commencement reader
    status: open
  - pattern: "An amending law's own clause dates some provisions apart and they take the general date ('This Regulation and regulation 2 come into force on the 22nd day after … laid', 'except for the following provisions which come into force on 5th July 2018—', '(except regulation 4(2) and (5))' held as '(except regulation and )') (SI 2018/1202 reg.1(3); SI 2018/575, 2018/942, 2018/1227)"
    category: clause-exception-date-unread
    module: commencement/ (Commencement.Amending, own clause)
    affected: "22 changes in 4 laws (Maritime Safety 19: SI 2018/1202; Environmental Protection 3)"
    fix: "Read the clause's excepted or separately dated provisions as their own rules; keep cross-reference numbers in the clause text"
    step: Commencement reader
    status: open
  - pattern: "'X is omitted (as it applies in relation to England and as it applies in relation to Wales)' read as England only (SI 2019/458 reg.3(3)(a)(i) on EA 1995 s.41(1)(c))"
    category: as-it-applies-territory-read-short
    module: amendment/ (territory of an instruction)
    affected: "1 change"
    fix: "Read every 'as it applies in relation to' territory of the instruction"
    step: Amending-law reader
    status: open
  - pattern: "OH&S Evidence gate: 23 groups not named, as at 2026-11-08"
    category: ohs-gate-evidence
    module: test/fixtures/evidence/evidence.json
    affected: 23
    fix: "review each group known/fix/check"
    step: Evidence
    status: fixed
  - pattern: "Feed Type error wins where the law's text makes no claim (REACH Art 138(1): feed 'inserted', para 95(3)(d) substitutes); moved words carried as renumbered (SI 1999/3242 reg.3(3))"
    category: evidence table
    module: Evidence (KF-type, KMV)
    affected: 2
    fix: "a named known limit, 1 change"
    step: Evidence
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/affecting_made.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/evidence.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/primary.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/affecting_made_test.exs
  - backend/test/fixtures/evidence/evidence.json
  - backend/data/reports/evidence/environmental-protection-gate-review-1.md
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/evidence-check/SKILL.md

depends_on:
  - 2026-11-10-environmental-protection-merge

enables:
  - "Environmental Protection: Label fold"
---

# Session: Environmental Protection: Evidence (CLOSED)

## Problem

This is step 8 of the LAT Change Pipeline for Environmental Protection. Its aim is that each attribute of a merged change comes from the right source by the evidence table, and that every disagreement between the law and legislation.gov.uk is reported like for like. Under the standing rule, the bugs parked on Evidence are fixed here, whatever family found them, and anything left parked gets its size and reason. The plan is `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`, approved 2026-11-10.

## Todo

- ✅ Open the step session with the baselines (strata, gates and gaps of the three families) and the parked bugs
- ✅ Dump every unnamed group (EP 43, OH&S 14, Maritime 3), widest first; review each in the sources' records; name it in `evidence.json` (dry run first); reasons in `environmental-protection-gate-review-1.md`; check the two parked one-change forms
- ✅ Decisions for Jason: known limits, any `fix:` class, the parked bugs' outcomes
- ✅ The one agent pass (seed 62, 50 A changes, `cmp`-checked); record its tokens; its classes become gate groups or gap causes
- ✅ Fix the table's `fix:` classes over triage, test first; pre-flight, one approved restore point and rebuild round (skip if none)
- ✅ The gate PASS for all three families; the OH&S and Maritime regression check
- ✅ Golden 27/27; `mix test` 0 failures; Credo clean
- ✅ Pass and close: WORKFLOW note, RULES, the skill's history, parked bugs, the meta row, commits

## Dependencies

- ✅ Environmental Protection: Merge, closed and pushed (47544861); the three families rebuilt there
- ✅ `Gate.Evidence` and `evidence.json` (Maritime Safety: Evidence, 2026-11-06)

## Pass rule

Decision 1 of Maritime Safety: Evidence (2026-11-06), fixed with the plan:

1. `mix lat.evidence_check --family F --gate` prints PASS for Environmental Protection, OH&S and Maritime Safety. Every group is named in `evidence.json` and reviewed in the sources' own records. Operation and level conflicts of the law's text keep the Amending-law reader's status.
2. One agent pass: 50 EP changes from A, seed 62, drawn twice and compared with `cmp`. Its token cost is recorded, and its classes become code groups. There is no resample.
3. No regression: OH&S and Maritime V and D are no higher than the baseline.
4. Golden 27/27; `mix test` 0 failures; Credo clean.
5. The winners, the gaps and a quality statement are published.

**Triage:** a class of 10 or more changes, or one in 2 or more amending laws, is fixed if it is the evidence table's code. Smaller classes become named known limits. Another step's fault is parked with its size.

**Frozen:** `golden.exs`, `disagreements.json`, `merges.json`.

## Baseline (2026-11-10, after the Merge rebuild)

| Family | Changes | V | D | A | Gate |
|---|---|---|---|---|---|
| Environmental Protection | 44,683 | 471 | 182 | 5,653 | FAIL: 193 groups, 43 not named |
| OH&S | 26,204 | 146 | 38 | 3,003 | FAIL: 14 not named (parked at 23) |
| Maritime Safety | 29,931 | 195 | 13 | 3,176 | FAIL: 3 not named (it passed on 2026-11-06; the date groups are new since later rebuilds) |

**EP gaps** (a value no source claims; published, never failing):

| Attribute | Gaps | Of which the amending law has no commencement rules |
|---|---|---|
| commenced_by | 4,128 | 199 |
| date | 380 | |
| level | 24 | |
| by | 7 | |

Reports: `backend/data/reports/evidence/three-families-baseline-2026-11-10.txt`, `environmental-protection-gate-0.txt`, `ohs-gate-0-2026-11-10.txt`, `maritime-gate-3-2026-11-10.txt`.

## Parked bugs on this step

| Bug | Plan |
|---|---|
| OH&S Evidence gate: 23 groups not named (now 14) | Reviewed and named with EP's. |
| A feed Type error wins where the law's text makes no claim (REACH Art 138(1)); moved words carried as renumbered (SI 1999/3242 reg.3(3)); 2 changes | Checked in the records. Below triage: a named known limit unless a wider class turns up. |

## Review (todo 2)

All 60 unnamed groups (59 keys) were read in the sources' own records. The evidence table's order was right throughout: law text and commencement win where they speak, then markup, then feed. Every wrong chosen value is a misread primary claim winning, so it belongs to the reader that misread it. Full reasons: `backend/data/reports/evidence/environmental-protection-gate-review-1.md`. Draft statuses (dry run, not yet written): `evidence_statuses.json` in the scratchpad.

- **Wrong chosen values: 154 changes, all another step's** (Commencement reader 153, Amending-law reader 1). There are three new Commencement-reader classes:
  - an order's "in section 86— (i) …" read as the whole section: 42 changes;
  - an order item's heading or a Welsh order read as partial: 22;
  - an own clause's excepted provisions left on the general date: 22, of which 19 are Maritime's.
- **The law right, legislation.gov.uk off:** 38. Examples: SI 1992/3004's staged start (23), amendments made before the amended law's own start (11), a feed year slip.
- **By design:** the "as amended by" chain (105). Markup that wraps the provision whole is right (7). The feed's renumbered wins.
- **legislation.gov.uk forms, one change each:** the feed Type error on REACH Art 138(1) (the parked bug), and SI 2015/1637's "for X insert Y".
- **No false conflict, no missed one, and no table fix.** So no rebuild is needed.

## Decisions for Jason

**Decision 1. The statuses as drafted.**
- **Question:** may the 59 drafted statuses go into `evidence.json` as written? They name each misread with its reader's parked class, each legislation.gov.uk form, and each by-design group.
- **Aim:** `binds-on-date`. The wrong values are fixed where they are read, not here.
- **Options:**
  - A: write them as drafted;
  - B: hold the misread groups as `check:` until their reader's step fixes them, so the gate fails until then.
- **Recommendation: A.** The gate's job is to show the table chose by its order. A misread primary claim is `known:` with its parked bug, as at Maritime Safety (Decision 1, 2026-11-06).

**Decision 2. A Welsh SI cited by its UK S.I. number (29 changes, 5 laws).**
- **Question:** legislation.gov.uk's notes cite Welsh SIs as `uksi/2011/971` ("S.I. 2011/971") where the feed has `wsi/2011/971`. That is one law under two names, so `Conflicts` reports a `by` disagreement. Should it?
- **Aim:** `one-change-per-event`, through like-for-like reporting. The chosen value is already right (the feed's).
- **Options:**
  - A: a named known form, with no code;
  - B: treat a cited `uksi` with the same year and number as the feed's `wsi` as one law in the comparison. That is a rule matching laws by year and number alone, which the law-identity rule forbids.
- **Recommendation: A.** No value changes, and B weakens the identity rule for a reporting nicety.

**Decision 3. The parked bugs' outcomes.**
- **Question:** park the new classes with their sizes, close the step's own parked bugs, and add sizes to the existing ones?
- **Aim:** `binds-on-date`. Every misread is found again by the step that owns it.
- **Options:**
  - A: raise four new classes:
    - Commencement reader: order-in-list-read-whole (42), order-item-read-partial (22) and clause-exception-date-unread (22);
    - Amending-law reader: as-it-applies-territory-read-short (1).

    Add this step's sizes to the existing classes. Mark the OH&S Evidence gate bug fixed (14 → 0). Close the feed Type error and moved-words bug as a named known limit, sized at 1 change (REACH Art 138(1)); the moved-words form appears in no group of the three families.
  - B: keep the feed Type error open as an Evidence table rule: read the amending provision to overrule the feed's Type.
- **Recommendation: A.** One change. The fix belongs to the Amending-law reader (reading para 95(3)(d)), not to the table.

Decided 2026-11-11: Decision 1 A, Decision 2 A, Decision 3 A. The statuses are written (`evidence.json`, 59 keys added) and all three gates print PASS (`environmental-protection-gate-1.txt`, `ohs-gate-1-2026-11-11.txt`, `maritime-gate-4-2026-11-11.txt`).

## The agent pass (todo 4)

The sample: 50 Environmental Protection A changes, seed 62, drawn twice; `cmp` found the draws identical. The run took 155,068 tokens and ~8½ min. Verdicts: `a62-verdicts.json` in the scratchpad.

- **36 OK, 12 gaps, 2 wrong, 0 doubtful.** Of the 45 pairs, 34 are OK, 10 gaps and 1 wrong.
- **Gaps:** commenced_by only; every other value is right.
  - 9: the amending provision is not read (often in the amending law's Schedule), so the clause rule never attaches. This is the Amending-law reader's coverage.
  - 2: clause_staged is not attached to amending provisions, by design.
  - 1: a Schedule of the amended law (v0.1).
- **New class (2 wrong, one cause):** `feed-in-accordance-with-made-date`.
  - **Example:** SI 2016/562's feed effects record `InForce Date="2016-05-04" Qualification="coming into force in accordance with" OtherQualification="art. 1(2)-(5)"`. The Order was made that day. None of art.1(2)–(5) gives that date: Schedule 2 comes in on "the main commencement day", the Protocols' UK entry into force.
  - **Why it wins:** no rule reads the Order (the treaty day is a known limit), so the feed's date wins. The date is a pointer used as a fact.
  - **Measured in the three families' stored feeds:**
    - 145 dated records qualify their date "in accordance with";
    - 15 of them fall on the affecting law's own made or enactment day: SI 2016/562 (12; sure) and 2026 c.11 (3; uncertain, since an Act's own day may be its real start);
    - the other 130 carry other dates.

**Decision 4. The feed's "in accordance with" placeholder date (15 changes, 2 laws).**
- **Question:** fix it here in the evidence table, or park it with the Feed reader and count it in code?
- **Aim:** `binds-on-date`. A date that is only a pointer dates 12 changes 6 years early.
- **Options:**
  - A: raise and park it with the Feed reader: mark a stage as a pointer when its qualification is "in accordance with" and its date is the affecting law's made or enactment day, so it becomes a date gap. The evidence gate also counts, in code, the changes whose date comes from a feed stage qualified "in accordance with", by affecting law: a published figure, never failing. Neither needs a rebuild, because the gate is outside the versioned files.
  - B: fix it in the evidence table now. The table doesn't hold the affecting law's made date, so the build's inputs would change, then a restore point and a rebuild of three families.
- **Recommendation: A.** Whether the feed's date is a date at all is a fact of the feed's own record, so it belongs to the reader. The table's order is right. 15 changes in 2 laws, 12 of them sure.

Decided 2026-11-11: **B**, fix it in the table now.

## The fix and the write round (todos 5–7)

- **Code:**
  - `Readers.AffectingMade` claims `{:law, :made, date}`, the affecting law's made or enactment day from `legal_register`, read by `Primary` as `made:`. It does so only for a change whose feed stage is qualified "in accordance with".
  - `Evidence`'s date order now takes the feed's `date_first` and `date` only under `:not_made_day`.
  - Tests first: `affecting_made_test` (4).
  - RULES `feed-placeholder-date-is-no-date`.
- **Pre-flight:**
  - `MIX_ENV=dev mix compile --warnings-as-errors`;
  - the architecture tests and the change-vocabulary suite (3,474 tests);
  - Credo diff: no new issue;
  - the in-memory preview of SI 2006/2988, SI 1977/500 and SI 2002/761 moved exactly 12 dates to gaps; no key gone or added, no other value moved.
- **Write round (Jason's go):**
  - restore point `evidence-environmental-protection-before-build` (`provision_changes`, `provision_change_claims`, `lat_events`);
  - one rebuild of the three families: EP 323 s, OH&S 93 s, Maritime 50 s (`three-families-rebuild-2026-11-11.txt`).
  - Deviations:
    - The rebuild ran with `--family "OH&S"`, which matches four OH&S families (189 laws). It built 40 laws of Gas & Electrical, Mines & Quarries and Offshore for the first time (9,713 changes). Jason: keep them; their own steps review them.
    - The rebuild ran with MemoryMax 14G while a VM was up (12G is the rule); it finished without trouble.
- **After:**

| Family | V | D | A | Gate |
|---|---|---|---|---|
| Environmental Protection | 471 | 182 | 5,653 | PASS (date gaps 380 → 391: the placeholders) |
| OH&S: Occupational / Personal Safety (149 laws) | 146 | 38 | 3,003 | PASS |
| Maritime Safety | 195 | 13 | 3,176 | PASS |

  - SI 2016/562's 12 changes and Finance Act 2026's 3 are now undated: gaps, not wrong dates.
  - No regression: OH&S and Maritime V and D are as at the baseline.
  - Golden 27/27 (`environmental-protection-golden-2.txt`).
  - `mix test`: 10,667 pass, 0 failures.

## Winners and quality statement

- **Environmental Protection, 44,683 changes.** The winning source per attribute is in `environmental-protection-gate-2-2026-11-11.txt`. The commencement wins date, operation and level on most changes; the feed fills what the law doesn't say.
- **Gaps (published):**
  - commenced_by: 4,128, of which 199 are by amending laws with no commencement rules;
  - date: 391;
  - level: 24;
  - by: 7.
- **Quality:** the evidence table's order was right on every reviewed group, and the agent's sample found 36/50 right, 12 gaps and 2 wrong, the 2 now fixed. Wrong chosen values remain only where a reader misreads a primary claim (154 changes, parked with their readers' classes). They are fixed at those readers' steps, never by reordering the table.

## Parking list

- Commencement reader: order-in-list-read-whole (new): "in section 86— (i) …" read as the whole section, 42 changes in 2 laws.
- Commencement reader: order-item-read-partial (new): an item's heading or a Welsh order read as partial, 22 changes in 3 laws.
- Commencement reader: clause-exception-date-unread (new): an own clause's excepted provisions left on the general date, 22 changes in 4 laws (Maritime 19).
- Amending-law reader: as-it-applies-territory-read-short (new): "as it applies in relation to England and … Wales" read as England, 1 change.
- This step's sizes for existing Commencement-reader classes:
  - commencement orders held but not read (SI 2006/266): 30;
  - list-item-qualifier-scope: 13 in 3 laws;
  - a schedule not traced through its introducing regulation: 9 (SI 2018/369);
  - sibling list read short: 6 in 2 laws;
  - amending-law-start-misread: 5 (Sentencing Act 2020);
  - stale-order-rules-after-list-change: 4 (CROW 2000 by WSI 2005/423).
