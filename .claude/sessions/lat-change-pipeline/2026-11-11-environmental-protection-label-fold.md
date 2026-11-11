---
session: 'Environmental Protection: Label fold'
status: closed
opened: '2026-11-11'
closed: '2026-11-11'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'

summary: >
  The label fold passed for Environmental Protection on the code gate, with OH&S's parked group and Maritime kept passing: EP 13 groups → 0 not named. Nine decisions fixed the fold where it credited or began text before its maker existed, dropped made periods, ignored versions, containers and early own commencements, and asserted dates no source gives; the Windsor list was checked. The one agent pass (seed 211, 41 rows, 427,919 tokens) found two fold classes, both made gate checks and fixed by reach, and eleven upstream rows, parked with their owners.

decisions:
  - what: "Decisions 1 and 7: an undated insertion or repeal by a later law begins at that law's first dated record on the row or above, else its making; an undated maker made after a period's start is not credited"
    why: "EPA Part IIA by EA 1995 was labelled from 1990, credited to a 1995 law (674 rows); the feed holds dated records of the inserting law"
    result: "EP 692 rows, OH&S 6; RULES never-before-its-maker"
  - what: "Decision 2: the feed's record of the law's own commencement counts as its own clause for the made period"
    why: "Made.own_clause? knew only the own-clause key; 232 rows in 4 laws lost their prospective period"
    result: "fixed; RULES made-before-start-is-prospective (own clause)"
  - what: "Decision 3: Welsh SIs held under UK SI names parked with the Register"
    why: "fixing it in the fold would match laws by year and number alone"
    result: "440 rows named known with the parked bug"
  - what: "Decisions 4 and 5: a version begins with its sibling's insertion; a container's later heading never restarts a row"
    why: "EPA s.106(4A)[E+W] from 1990 (65 rows); EA 1995 ss.11–16A restarted in 2013 (17 rows)"
    result: "fixed; RULES version-begins-with-its-sibling, heading-insertion-never-restarts"
  - what: "Decision 6: the Windsor list's REACH and CLP entries checked; listed?/1 requires the flag (open decision 11 closed)"
    why: "160 OH&S rows relied on an unchecked list"
    result: "no label moved"
  - what: "Decision 8: a row left to an order we don't hold reads in force from the start, its in-force date unknown"
    why: "the parked J6: 157 rows asserted the law's start as their in-force date"
    result: "undated starts +111 (EP 22, OH&S 12, Maritime 77); RULES left-to-an-order-date-unknown"
  - what: "Decision 9: pending and unapplied changes by design"
    why: "the fold skips the 186 undated; the 54 dated apply on the feed's date"
    result: "the parked J4 closed; RULES feed-pending-dated-applies"

metrics:
  ep_strata: { laws: 122, rows: 35766, periods: 69135, table_breaks: 0, in_force: 32591, in_force_partial: 1458, repealed: 747, repealed_saved: 649, prospective: 321, gap_undated_start: 1952, gap_undated_change: 6964 }
  gate: { ep_start_not_named: 13, ep_end_groups: 8, ep_end_known: 8, statuses_added: 6 }
  agent_pass: { seed: 211, rows: 41, ok: 24, wrong_fold: 2, wrong_upstream: 11, gap: 3, doubtful: 1, tokens: 427919 }
  agent_classes_measured: { early_own_commencement: 1720, ancestor_insertion_territory: 10 }
  regression: { ohs: "PASS, statuses as baseline but REACH Pt XI", maritime: "PASS, statuses as baseline" }
  golden: "27/27"
  mix_test: "10,683 pass"

lessons:
  - title: Diff the statuses at HEAD and now before trusting a fold fix
    detail: "Decision 7's first cut dated undated repeals regardless of whether the text still shows, and repealed one OH&S row. Only a per-row status diff of the family at HEAD against now (git stash of the fold files, the fold cache off) named the row; the tests and the gate were silent."
    tag: tooling
  - title: Compare a gap figure's rise with the measure that sized the fix
    detail: "Decision 8 was measured at 157 rows, but undated starts rose 1,227 on the first cut: the flag blanked starts an insertion or a start-day commencement dates. The mismatch, not a test, showed the over-reach."
    tag: data
  - title: Golden's provisions start at the row, the family fold at the law
    detail: "The early-start rule moved a row's own later start back to its law's earlier commencement in golden only (Forestry Act 1967 s.1(4)(a)). A rule keyed on the law's start must check start_from_law."
    tag: data
  - title: A gate check needs its own false-positive test
    detail: "Both new checks fired wrongly on first runs (the territory check counted a later insertion of the row itself; before_insertion counted another version's insertion). Each fix came with a test of the case it must not flag."
    tag: tooling
  - title: The Credo ratchet lists an old issue whose number changed
    detail: "Label.fold (13) and Start.period (29) were over the limit before the step; any edit changes the number and the hook fails. The module rule (fix a module's issues when it is worked on) then means splitting them below 9; a pinning test run at HEAD and after caught a reordered status branch."
    tag: tooling

bugs:
  - pattern: "A Welsh SI held under a UK SI name (UK_uksi_2009_995 for wsi/2009/995): the feed's record of its own commencement names the wsi law, so no made period is shown, and changed_by can credit the law twice (SI 2020/206, 2009/995, 2005/1806, 2006/2988)"
    category: welsh-si-held-under-uk-name
    module: legal_register names (the Register)
    affected: "440 rows in 3 Environmental Protection laws (no made period); changed_by duplicated on SI 2005/1806 rows"
    fix: "Hold Welsh SIs under their wsi name (legislation.gov.uk's own); every table keyed by the name moves with it"
    step: Register
    status: open
  - pattern: "An amending law's insertion or repeal holds no date though its law's orders are read (EA 1995 s.57 inserting EPA Part IIA; EA 1995 Sch.24 repeals of EPA ss.30-50, s.143)"
    category: undated-insertion-commencement-unjoined
    module: commencement/ (amending-law commencement joined to its changes)
    affected: "Environmental Protection: 692 rows bounded by the fold's Decisions 1 and 7, their in-force dates still gaps"
    fix: "Join the amending provision's commencement (SI 1996/186, SI 2000/340 for EA 1995 s.57) to the change it makes"
    step: Commencement reader
    status: open
  - pattern: "An Act's territorial by-order clause read as a partial commencement at Royal Assent (CNEA 2005 s.108(1)(a): 'in relation to England, in accordance with provision made by order')"
    category: territorial-by-order-read-qualified
    module: commencement/ (own clause reading)
    affected: "553 changes (CNEA 2005, s.108(2) provisions)"
    fix: "A by-order clause qualified only by a territory is provision_by_order for that territory"
    step: Commencement reader
    status: open
  - pattern: "'Part IV (drainage works) of the 1999 Regulations is revoked' stored as a repeal of the whole law (SSI 2017/114 reg.50(1) on SSI 1999/1)"
    category: part-revoked-read-whole-law
    module: amendment/ (revocation by name)
    affected: "1 law (the label right by the feed's pt.IV record)"
    fix: "A revocation naming a Part revokes that Part, never the whole law"
    step: Amending-law reader
    status: open
  - pattern: "A dated stage's 'Other' qualification 'for S. for the repeal of ss. 1-19, 22-28' not read as its territory (PPCA 1999 Sch.3's repeal of EPA ss.1-28, by SSI 2015/74)"
    category: other-qualification-territory
    module: change_vocabulary/qualification.ex, readers/feed.ex
    affected: "about 28 EPA sections and their rows read repealed everywhere from 2015-04-01"
    fix: "A place opening OtherQualification is the stage's territory; the undated Prospective stage stays open elsewhere"
    step: Feed reader
    status: open
  - pattern: "A 'reg. N Title' effect read as a whole-provision substitution (SI 2012/630 reg.19(2)(a) on SI 2009/995 reg.10, Welsh text only)"
    category: title-locator-read-whole
    module: change_vocabulary/readers/feed.ex (@words_part)
    affected: "rows under reg.10 of SI 2009/995 begin at 2012; every provision with a 'Title' effect likewise"
    fix: "Read a trailing 'Title' as the provision's heading, at words level"
    step: Feed reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/start.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/made.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/undated.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_source.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_rules.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/label.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/windsor.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/fold_version.ex
  - backend/test/fixtures/label/labels.json
  - backend/data/reports/label/environmental-protection-label-review-1.md
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/label-check/SKILL.md

depends_on:
  - 2026-11-10-environmental-protection-evidence

enables:
  - "Environmental Protection: Measures"
---

# Session: Environmental Protection: Label fold (CLOSED)

## Problem

This is step 9 of the LAT Change Pipeline for Environmental Protection. Its aim is that each provision's resolved changes fold into the right label periods under the agreed conventions: status, territory, in force from, changed by, commenced by, and a tier per field. Under the standing rule, the 8 bugs parked on the Label fold are fixed here, whatever family found them, and anything left parked gets its size and reason. The plan is `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`, approved 2026-11-11.

## Todo

- ✅ Open the step session; baseline (strata, gate, shapes, gaps) for the three families; the parked bugs
- ✅ Review every unnamed group in the rows' changes and sources; draft statuses (dry run); measure each parked bug's reach; reasons in `environmental-protection-label-review-1.md`
- ✅ Decisions for Jason: statuses, fold fixes over triage, Windsor open decision 11 and the EU directives, the parked bugs' outcomes
- ✅ The one agent pass (seed 211, ~45 rows, `cmp`-checked, 3 batches); record its tokens; its classes become gate checks
- ✅ Fix the fold's classes over triage, test first; pre-flight with `--laws`
- ✅ The gates PASS for all three families; the OH&S and Maritime regression check
- ✅ Golden 27/27; `mix test` 0 failures; Credo clean
- ✅ Pass and close: WORKFLOW note, RULES, the skill's history, parked bugs, the meta row, the pickup memory, commits

## Dependencies

- ✅ Environmental Protection: Evidence, closed (49f56b18, b4906bdb; not pushed); the three families rebuilt there on 2026-11-11
- ✅ `Gate.Label` and `labels.json` (Maritime Safety: Label fold, 2026-11-06)

## Pass rule

This is Decision 1 of Maritime Safety: Label fold (2026-11-06), fixed with the plan:

1. `mix lat.label_check --family F --gate` prints PASS for Environmental Protection, OH&S: Occupational / Personal Safety and TRANSPORT: Maritime Safety. Every group is named in `labels.json`, reviewed in the row's own changes and sources.
2. One agent pass: about 45 EP rows (`--stratum SR --per 2 --n 23 --seed 211`), drawn twice and compared with `cmp`, in 3 batches.
   - Its tokens are recorded.
   - A fold class becomes a gate check; an upstream class is parked.
   - There is no resample.
3. No regression: OH&S and Maritime keep their gates PASS and current statuses.
4. Golden 27/27; `mix test` 0 failures; Credo clean.
5. The shapes, the gaps, the statuses and a quality statement are published.

A wrong label from a wrong stored change is upstream: it is named `known:` with its parked bug.

**Triage:** a class reaching 10 rows, or found in 2 or more laws, is fixed if it is the fold's code; smaller classes are named known limits.

**Frozen:** `golden.exs`, `evidence.json`, `merges.json`, `disagreements.json`.

The fold sits outside `ChangeVocabulary.Version` (it has its own `FoldVersion`), so a fold fix needs no rebuild.

## Parked bugs on this step

| Bug | Size | Plan |
|---|---|---|
| OH&S gate: before_amender @ HSWA 1974 s.28(10) | 6 rows | Review and name |
| Rows left to an order we don't hold fold as in force from the law's start (`Label.Start`) | 55 laws (old J6) | Measure; fix as a gap if over triage |
| An undated change by a later law folded as the maker from an earlier period | 5 Maritime rows, plus OH&S's date gaps | Measure; fix by its rule if over triage |
| A row with no made period, its first period a later repeal (SI 1998/1258 reg.7(b)) | 1 row | Find the cause |
| Pending and unapplied changes used by no rule | unknown | Measure; Jason's rule if they move labels |
| HSWA s.78 NI territory, s.52(1)(b) territory, "to confirm" | 3 | Check against golden and the sources |
| The Windsor Framework list `checked: false` but used | 160 rows | Jason: open decision 11 |
| EU directives after IP completion day | 15 OH&S directives | Jason: a Windsor source per directive |

## Baseline (2026-11-11, stored changes as rebuilt at Evidence)

| Family | Laws | Rows | Periods | Table breaks | Gate |
|---|---|---|---|---|---|
| Environmental Protection | 122 | 35,766 | 68,074 | 0 | FAIL: 15 groups, 13 not named (1,440 rows) |
| OH&S: Occupational / Personal Safety | 149 | | | 0 | FAIL: 1 not named (its parked HSWA s.28(10), 6 rows) |
| TRANSPORT: Maritime Safety | 117 | 24,434 | 47,509 | 0 | PASS |

- **EP current status:** in force 32,588; partial 1,466; repealed 747; repealed and saved 644; prospective 321.
- **EP gaps:** undated change 6,964; undated start 1,882.
- **The family folds took** EP 5½ min, OH&S 1¼ and Maritime 2 (the fold cache).

Reports: `backend/data/reports/label/environmental-protection-label-gate-0.txt`, `ohs-label-gate-0-2026-11-11.txt`, `maritime-label-gate-0-2026-11-11.txt`.

## Review (todo 2): EP's 13 groups and OH&S's 1

Each group was read in its rows' folded periods and reaching changes (`rowfold.exs` and `made.exs` in the scratchpad), and the stored changes and rules behind them. Five classes:

| Class | Groups (rows) | Owner | Reading |
|---|---|---|---|
| **An undated whole insertion by a later law credited from the law's start** | before_amender @ EPA 1990 (674), SI 2001/4027 (7), EA 1995 (5); OH&S's HSWA s.28(10) (6) | the fold (`Label.Undated`, `Label.Start`), from an upstream date gap | EA 1995 s.57 inserts EPA Part IIA, but the insertion holds no date. The feed's dated records of it are separate changes: partial starts on 1996-02-01 and 1996-04-01 by SI 1996/186. So the row is labelled from EPA's start in 1990, credited to a law of 1995. 624 of the 674 rows are an ancestor's undated insertion (Part IIA); the rest are the row's own undated insertion, substitution or repeal. This is the parked "undated change by a later law" bug. |
| **The feed's record of the law's own commencement blocks the made period** | no_made_period @ WSI 2010/1821 (105), SI 2025/1218 (123), SSI 2025/165 (3), SI 2017/1312 (1) | the fold (`Label.Made.own_clause?/2`) | The feed's "coming into force" effect is by the law itself, not an order. `own_clause?` knows only the law's own-clause key, so it reads as another commencement and the prospective period from the making is dropped. |
| **A Welsh SI held under a UK SI name** | no_made_period @ SI 2020/206 (381), SI 2009/995 (34), SI 2005/1806 (25) | Register (law names) | The register holds `UK_uksi_2009_995`; the feed names `wsi/2009/995` for its own commencement. Matching the two would mean matching laws by year and number, which is forbidden. SI 2006/2988 is the same (the Evidence agent saw it). |
| **A territorial version's start ignores its sibling's insertion** | before_insertion @ EPA 1990 (54), EA 1995 (11) | the fold (`Label.Start`, versions) | EPA s.106(4A)[E+W] is labelled from 1990: only its S version holds a dated insertion (SSI 2002/541, 2002-12-05), and the E+W version's own record has no operation. EA 1995 s.108(16)[S] is the same, with an E+W insertion of 2004. |
| **A container's later insertion restarts its rows** | start: a container's insertion after its own @ EA 1995 (17) | the fold (`Label.containers/2`) | WSI 2013/755 inserts the Chapter 1A heading around ss.11–16A, which have existed since 1996 or 2002, and their start moves to 2013. |

## Decisions for Jason

**Decision 1. An undated whole insertion by a later law (692 rows: EP 686, OH&S 6).**
- **Question:** where does such a row begin, and who made its text?
- **Aim:** `binds-on-date` and `unknown-over-guess`: the label must never say a provision existed in 1992 when it was inserted by a law of 1995.
- **Options:**
  - A: the row begins at the earliest dated change its inserting law makes to it or its ancestor (the feed's first stage: Part IIA from 1996-02-01, partial). With none, it begins on the inserting law's made day, with in_force_from unknown (a counted gap). An undated substitution or repeal dates nothing: the period before keeps its own maker, and the change is a gap.
  - B: always the inserting law's made day, in_force_from unknown.
  - C: leave the fold as it is, and name the groups known limits until the upstream date gap is fixed.
- **Recommendation: A.** It uses evidence the fold already holds, and never dates before the inserter existed. The upstream gap (an insertion's commencement not joined to it) is parked with the Commencement reader and Merge, with its size.

**Decision 2. The made period dropped by the feed's own commencement record (232 rows, 4 laws).**
- **Question:** fix `Made.own_clause?/2` to count a feed commencement record whose law is the law itself (commenced_by none or itself)?
- **Aim:** `binds-on-date`. A law made but not yet in force shows as prospective from its making (LR-39).
- **Options:**
  - A: fix it, test first;
  - B: name the groups known limits.
- **Recommendation: A.** It is the fold's own code, over triage, and an order is still told apart (its commenced_by is another law).

**Decision 3. A Welsh SI held under a UK SI name (440 rows, 3 laws, and more in the register).**
- **Options:**
  - A: park with the Register (correct the law names; every table keyed by them moves) and name the groups `known:` with that bug;
  - B: match uksi N with wsi N in the fold. This matches laws by year and number, which the identity rule forbids.
- **Recommendation: A.**

**Decision 4. A territorial version's start ignores its sibling's insertion (65 rows, 2 laws).**
- **Options:**
  - A: a version with no insertion of its own begins no earlier than its sibling's dated insertion of the same number, with in_force_from unknown;
  - B: name the groups known limits, and park the version's missing insertion with the Feed reader (the record with no operation).
- **Recommendation: A.** The number did not exist in any version before its first insertion, and the in-force date stays an honest gap.

**Decision 5. A container's later insertion restarts its rows (17 rows, 1 law).**
- **Options:**
  - A: fix it: a container's insertion later than the row's own dated evidence (its commencement or its own insertion) never moves its start;
  - B: a known limit.
- **Recommendation: A.** It is the fold's own, and over triage.

**Decision 6. The Windsor list (open decision 11; 160 OH&S rows rely on it).**
- **Question:** may REACH and CLP be marked `checked: true` from their cited Annex 2 sources, so the code honours the flag? And should EP's retained EU instruments be added?
- **Options:**
  - A: Jason confirms the two entries; `listed?/1` then requires `checked: true`; EP's EU instruments are not added in this step, but parked with a count of their UK changes after 2020-12-31;
  - B: leave the list as it is.
- **Recommendation: A.**

**Decided 2026-11-11:** Decision 1 A, Decisions 2 and 5 fixed, Decision 3 A (Register), Decision 4 A, Decision 6 A.

The remaining parked bugs are measured after the fixes, on the corrected folds:
- rows left to an order we don't hold;
- pending and unapplied changes;
- HSWA s.78;
- SI 1998/1258 reg.7(b);
- EU directives (no Windsor source per directive: parked again with that reason).

## Fixes (todo 5) and the gates after (todo 6)

- **Code (tests first, `label_fold_test`, `label_made_test`, `label_rules_test`):**
  - `Label.Start.inserter_born/5` (Decision 1): an undated insertion by a later law begins at that law's first dated record on the row or anything holding it, else its making (`made_of`, from `LabelSource`). An undated maker made after the start dates nothing (`made_after?/3`).
  - `Label.Made.own_clause?/2` (Decision 2): the feed's record by the law itself counts as its own clause.
  - `Label.Start.sibling_born/5` (Decision 4): a version with no insertion of its own begins at its sibling's insertion of the number or one holding it; its in-force date is unknown (`:start_undated`).
  - `Label.Start.start/2` (Decision 5): a container's insertion on `*` later than the row's own dated record never moves it.
  - `Windsor.listed?/1` now requires `checked: true`, and both entries are checked (Decision 6, Jason 2026-11-11).
  - The gate rule `before_insertion` gives no breach where an insertion of the same provision began the row: a later insertion belongs to another version (EPA s.33(10)(a)[S]: a false positive).
- **Credo:** `Label.fold` was at 13 and `Start.period` at 29 at HEAD. They are split into named functions (`born_of`; `start_facts`, `status`, `insertion_status`, `commencement_status`, `makers`, `credits`). A pinning test was run at HEAD and after the split, and one status branch reordered in the split was caught and restored.
- **The gates after** (`*-label-gate-1*.txt`):
  - OH&S PASS: its parked HSWA s.28(10) group is gone.
  - Maritime PASS.
  - EP 13 → 5 groups.
  - No regression: OH&S and Maritime keep their current statuses exactly; periods +14 and +9 (made periods), Maritime's undated starts +3.

| EP group left | Rows | Reading |
|---|---|---|
| no_made_period @ SI 2020/206, SI 2009/995, SI 2005/1806 | 440 | Welsh SIs held under UK SI names: the Register's (Decision 3) |
| before_amender @ SI 2001/4027 | 7 | The 2023 Act's change dated 2022-06-06, before the Act was made: the Commencement reader's parked `commencement-before-made` |
| before_amender @ EPA 1990 (s.31, s.41, s.43(2), s.50, s.143 …) | 18 | An undated whole repeal by EA 1995: repealed from EPA's start in 1990 (`Undated.repealed_at_start`). Decision 7. |

**Decision 7. An undated whole repeal by a later law (18 rows, EPA by EA 1995).**
- **Question:** a provision repealed by a law that no source dates, its text gone, reads repealed from its own law's start, before the repealer existed. When should it read repealed?
- **Aim:** `binds-on-date`. EPA ss.30–50 were repealed on 1 Apr 1996 (SI 1996/186), not in 1990.
- **Options:**
  - A: as in Decision 1, repealed from the repealer's first dated record on the row or anything holding it, else its making. It stays in force from its own start until then.
  - B: a named known limit, with the upstream gap parked (EA 1995 Sch.24's repeal holds no commencement).
- **Recommendation: A.** The same rule as Decision 1, and the row is in force where it was. The date stays a lower bound, which is honest as a period start, and the upstream gap is parked either way.

Decided 2026-11-11: **A**. The fix is in `Undated.date_late_repeals/2`, only where the text no longer shows, as `repeals/3` already required. A first cut without that guard repealed one OH&S row, caught by the status diff. REACH Pt XI, whose Title CLP deleted, now reads repealed, and today's stored label agrees.

## The agent pass (todo 4)

The sample: seed 211, 41 rows (18 S by shape, 23 R), drawn twice and compared with `cmp` (identical), in 3 batches. Tokens: 188,016 + 133,397 + 106,506 = **427,919**. Prompt: `label-agent-prompt.txt` in the scratchpad (the skill's, plus this session's rules and classes).

- **24 OK, 2 wrong (fold), 11 wrong (upstream), 3 gaps, 1 doubtful.** By law: 2 of 25 wrong in the fold.
- **The fold's two classes became gate checks (`Gate.Label`), were measured, and were fixed by reach:**
  - `start: an own commencement before the law's start dropped`: 1,720 rows in 4 laws (WSI 2026/103 Part 7 the day after making; SSI 2025/165 reg.1(3); SI 2025/67; SI 2025/1218). Fix: `Start.early_own/2`, the row begins at its own law's earliest clause commencement once made.
  - `territory: an ancestor insertion's territory lost`: 10 rows in 4 laws (EP 9, OH&S 1). Fix: `Start.insertion_territory/4` takes the nearest insertion holding it that names a territory. The check's first cut counted a later insertion of the row itself, and was corrected (EPA s.153(1)(aa)).
- **Upstream classes (parked, the parking list):**
  - Commencement reader: an Act's territorial by-order clause read as a partial commencement at Royal Assent (CNEA 2005 s.108(1)(a), 553 changes); a sub-Part of a Schedule read as the whole Schedule (SI 2007/709, the `order-in-list-read-whole` class from Evidence).
  - Amending-law reader: "Part IV … is revoked" stored as a repeal of the whole law (SSI 2017/114 reg.50(1)).
  - Feed reader: a dated stage's "Other" qualification "for S. …" not read as its territory (PPCA 1999's repeal of EPA ss.1–28, about 28 sections); "reg. N Title" read as a whole substitution (SI 2009/995 reg.10, Welsh text only).
  - Register: a Welsh SI under a UK name also credits changed_by twice (SI 2005/1806).
  - The KC-order and Parts classes (existing).
- **Doubtful:** SI 2025/1218. Its clause, "18 months after the day on which they are made", gives 2027-05-18; legislation.gov.uk's own record gives 2027-05-19.

## The gates after the agent classes (`*-label-gate-2*.txt`, then pre-flights)

- OH&S PASS, Maritime PASS.
- Statuses: Maritime unchanged; OH&S one row (REACH Pt XI, above); EP unchanged in its counts.
- EP periods: 68,074 → 69,135 (the made periods and the early starts).
- EP groups left, all named by decision or below triage:

| Group | Rows | Status |
|---|---|---|
| no_made_period @ SI 2020/206, 2009/995, 2005/1806 | 440 | Register (Decision 3) |
| before_amender @ SI 2001/4027 | 7 | Commencement reader, `commencement-before-made` |
| start: an own commencement before the law's start dropped @ SI 2025/1218 | 14 | Known limit: one law, one day. The clause's 18 May against legislation.gov.uk's own record of 19 May, the later record keeping the row prospective for the day |
| … @ SSI 2025/165 | 1 | Known limit, one row (reg.9, "subject to paragraph (5)") |

## Decisions for Jason (2)

**Decision 8. Rows left to an order we don't hold, read as in force from the law's start (the parked J6 bug).** Measured in the three families' folds: **157 rows** (EP 68, OH&S 12, Maritime 77) whose own law leaves them to an order (`OwnCommencement` `:by_order`) read in force from the law's start, with that day as in_force_from.
- **Aim:** `unknown-over-guess`, `binds-on-date`.
- **Options:**
  - A: in force from the law's start, in_force_from unknown (a counted gap), like C10;
  - B: prospective until an order is held;
  - C: keep, parked again with its size.
- **Recommendation: A.** No date is asserted that no source gives. B would call provisions not in force that may well be, which is the worse error for compliance.

**Decided 2026-11-11:** Decision 8 A (`LabelSource` marks the rows `OwnCommencement` leaves `:by_order`; `Start.start_known?/2`; `FoldVersion` now covers the commencement files the labels stage reads), Decision 9 A.

**Decision 9. Pending and unapplied changes (the parked J4 bug).** Measured: **240 changes** in the three families (prospective and not yet applied in the feed).
- The fold already skips the 186 undated ones (`Undated.pending?`).
- The 54 dated ones apply on their date: legislation.gov.uk's backlog, a law in force but not yet applied to the text.
- **Options:**
  - A: by design: record the measure and close the bug;
  - B: hold the dated ones back until applied.
- **Recommendation: A** (`source-authority`: the feed's date stands where the text lags).

Other parked bugs, measured:
- **HSWA s.78 NI territory (3 seen):** golden passes on its C11 extent, E+W+S. In the family fold the row's stored extent is E+W+S+NI, so NI is left in force after the 2006 repeals. This is the row's extent, below triage: a named known limit.
- **EU directives after IP completion day (15 OH&S directives):** parked again, with its reason. No Windsor Framework source per directive is held, and Decision 6 added none.
- **SI 1998/1258 reg.7(b):** already named in `labels.json` (C10: no source dates the start); the bug is closed with that pointer.

## Final (todos 6–8)

- **Gates PASS** for all three families (`*-label-gate-6*.txt`). EP: 8 groups, all named (labels.json, 6 statuses added). OH&S and Maritime: PASS.
- **Current statuses:**
  - EP: in force 32,591; partial 1,458; repealed 747; repealed and saved 649; prospective 321 (as the baseline).
  - OH&S: as the baseline but REACH Pt XI, now repealed, as today's label has it.
  - Maritime: as the baseline.
- **Periods:** EP 68,074 → 69,135; OH&S 38,728 → 38,749; Maritime 47,509 → 47,519. Table breaks 0.
- **Gaps (published):** undated starts EP 1,882 → 1,952, OH&S 2,309 → 2,326, Maritime 407 → 487 (Decision 8); undated changes EP 6,964.
- **Golden 27/27**, after one catch: the early-start rule had moved Forestry Act 1967 s.1(4)(a)'s own 1999 start back to 1967. The rule now applies only where a row's start is its law's.
- **`mix test`:** 10,683 pass. Credo: no new issue.
- **Quality:** the fold's order of rules held on every reviewed group. Every class the review or the agent found is fixed in code with a gate check, or is upstream and parked with its owner, or is a named known limit (16 rows). The agent's random rows: 24 of 41 OK, no fold fault left unfixed.
- **Switched labels go stale:** the fold's code moved (`FoldVersion`, now also covering the commencement files it reads). The switched families' stored timelines (OH&S, Maritime) are refreshed at their next Labels side by side and Switch-over, not here.

## Parking list

- Register: welsh-si-held-under-uk-name — Welsh SIs held as `UK_uksi_…` (SI 2020/206, 2009/995, 2005/1806, 2006/2988): no made period (440 rows) and changed_by credited twice.
- Commencement reader: undated-insertion-commencement-unjoined — an amending law's insertion or repeal holds no date though its law's orders are read (EA 1995 s.57 inserting EPA Part IIA; Sch.24 repeals): the fold now bounds these by the law's first record (Decisions 1 and 7), and the date gap remains (EP 692 rows before the fix).
- Commencement reader: territorial-by-order-read-qualified — CNEA 2005 s.108(1)(a) "in relation to England, in accordance with provision made by order" read as a partial commencement at Royal Assent (553 changes).
- Commencement reader: order-in-list-read-whole (from Evidence) — also SI 2007/709 "Part 1(A) of Schedule 15", "in Part 1(B) … the entries" read as all of Sch.15.
- Commencement reader: commencement-before-made (existing) — SI 2001/4027 by the Energy Act 2023 (7 rows).
- Amending-law reader: part-revoked-read-whole-law — "Part IV (drainage works) of the 1999 Regulations is revoked" stored as a repeal of `*` (SSI 2017/114 reg.50(1)).
- Feed reader: other-qualification-territory — "Other" / "for S. for the repeal of ss. 1-19, 22-28" not read as the stage's territory (PPCA 1999 on EPA ss.1–28).
- Feed reader: title-locator-read-whole — "reg. 10 Title" (Welsh text only) read as a whole substitution of reg.10 (SI 2012/630 on SI 2009/995).
