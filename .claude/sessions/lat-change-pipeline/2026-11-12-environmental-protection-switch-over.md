---
session: "Environmental Protection: Switch-over"
status: closed
opened: 2026-11-12
closed: 2026-11-12
outcome: success

summary: >
  Step 13 for 💚 ENVIRONMENTAL PROTECTION: every difference was explained, and the family switched. All 122 laws now have their lat_label_timeline written from the merged changes, and the stored timeline equals the switch's (0 rows differ, checked by the new mix lat.label_switch --stored). Two faults were fixed in-step with Jason's leave: Welsh SIs held under their UK names (440 rows) and an amending provision commenced territory by territory (EPA 1990 Part IIA, no longer in force from 1995). Golden and the checked rows caught the second fix's two over-reaches before the apply.

decisions:
  - what: "Decision 1, A: Label.Made takes a Welsh SI's own commencement under either name (Facts.same_law?)"
    why: "three Welsh SIs held under UK SI names lost their prospective period from making (no_made_period 440 rows); a one-line fix in a rule already decided, far over the triage size"
    result: "no_made_period 440 → 0; fold version only, no rebuild"
  - what: "Decision 2, A: size the EPA 1990 Part IIA class, then fix it with leave"
    why: "552 rows would have read in force from 1995 (EA 1995's making); the store held s.57's commencement orders (E 2000, S 2000, W 2001), which the evaluator never joins into a full date"
    result: "scan: 74 undated changes in 7 laws dated only by territory (EP 54)"
  - what: "Decision 3, B: date such a change from its first territorial stage, partly in force; A (each stage its own change) parked with the Amending-law reader"
    why: "B is one function and removes the false 1995 date; A is new structure across three steps' code"
    result: "Part IIA in force in part from 2000-04-01; narrowed twice to its stated intent: more than one territory (golden: TCPA s.78(4BA)), and ranked after the feed's date with no order named (checked rows: HSWA by the Railways Act 2005); RULES territorial-stages-date-only-the-undated"
  - what: "Name the 15 remaining rule rows as known limits (2 classes)"
    why: "under 10 rows each, below the triage size; the switch keeps their old label"
    result: "label_rules PASSED, 0 breaches outside the known limits"
  - what: "Apply; then text-diff the 59 laws newly counted as parser-stale, and re-parse them from the store"
    why: "a family switched for the first time shows parser-stale laws --switched did not count before; the text diff showed 0 rows would move"
    result: "122 of 122 written, --stored 0 differ; re-parse 0 rows changed; lat.stale --strict --switched 0 of 388"

metrics:
  shadow_first: { rows: 35766, agree: 16423, differ_today: 16484, history_only: 2859 }
  shadow_after: { agree: 16430, differ_today: 16506, history_only: 2830 }
  rules: { breaches_first: 447, no_made_period: 440, before_amender: 7, before_insertion_after_fix: 8, known_limits: 15, breaches_after: 0, legacy_unconfirmed_apart: 18 }
  territory: { territory_only: 7736, e_w_to_w: 5138, unknown_to_e_ni: 1138, e_w_to_e: 845 }
  causes_no_evidence: { part_iia_before: 608, part_iia_after: 69 }
  sizing: { territorial_only: 74, full: 19, partial_only: 35, undated: 413, no_rules: 16 }
  checked_rows: { total: 744, match: 674, known: 47, upstream: 1, changed_parked: 22 }
  dry_run: { laws: 122, not_folded: 0, rows: 35251, differ: 19727, periods_old: 63345, periods_new: 69521 }
  apply: { written: 122, failed: 0, stored_differ: 0, maritime_stored_differ: 0 }
  reparse: { laws: 59, rows_changed: 0 }
  timings: { shadow_warm_s: 8, rebuild_1_s: 666, rebuild_2_s: 704, rebuild_3_s: 658, golden_s: 235, shadow_cold_s: 493 }
  tests: { golden: "27/27", mix_test: "10704 passed, 2 skipped" }
  tokens: { agent: 0 }

lessons:
  - title: "A sizing scan must cover what the fix reaches, not only what it is meant for"
    detail: "Decision 3's scan counted undated changes (74). The fix's claim reached every change whose amending provision was commenced by territory, feed-dated ones too, and re-dated HSWA's 2006 changes. A fallback claim ranked last in the evidence table, not a date claim, is what 'date only the undated' means in code."
    tag: data
  - title: "Golden and the checked rows each caught an over-reach the unit tests did not"
    detail: "Golden (from inputs, before the rebuild) caught a one-territory order dating a Welsh Act's change; the checked rows (after it) caught the stage outranking the feed. Run golden from inputs before every rebuild: it costs 4 min against 11."
    tag: tooling
  - title: "Run the checked rows in every step that changes readings"
    detail: "22 OH&S checked rows had changed since 2026-11-07, through the 2026-11-10 commencement re-reads, and no EP step re-ran label_checked. Run it at the start of the Switch-over too, so another step's regression is known before this step's fixes."
    tag: data
  - title: "A first switch shows parser-stale laws the unswitched family hid"
    detail: "lat.stale --strict --switched counts only switched families. EP's Making laws step left 59 laws parser-stale (RULES family-re-parses-its-parser-stale-laws), and they showed only after the apply. Check `lat.stale --list` for the family before the apply."
    tag: tooling
  - title: "Explain the largest class by its rule before sampling it"
    detail: "The 7,736 territory-only rows were one rule in Fold.own_territory/3 (type or title place), with no RULES entry. A law-level profile of each class (laws, titles) found it in minutes; no row sample was needed."
    tag: data

bugs:
  - pattern: "A Welsh SI held under its UK SI name gets no prospective period from its making: its own commencement is recorded by the feed under its Welsh name, which Label.Made's own-clause test doesn't take as the law itself (SI 2020/206 reg.1: made 2020-03-02, first period in force from 2020-03-27, commenced by UK_wsi_2020_206)"
    category: welsh-si-own-clause-alias
    module: ChangeVocabulary.Label.Made (own_clause?/2)
    affected: "440 rows in 3 EP laws (SI 2020/206 381, SI 2009/995 34, SI 2005/1806 25)"
    fix: "own_clause?/2 compares by Label.Facts.same_law?/2 (one instrument under its Welsh and UK SI names), as Facts already does for changed_by"
    step: Label fold
    status: fixed
    fixed_in: "this session, Decision 1 (Jason's leave), d986d976"
  - pattern: "One Welsh SI held twice in the register, under uksi and wsi names (UK_uksi_2009_995 and UK_wsi_2009_995 both in Environmental Protection, each with 254 LAT rows; SI 2020/206, SI 2005/1806, SI 2017/544 likewise, the wsi record in another family)"
    category: welsh-si-two-register-records
    module: Register (uk_lrt identity)
    affected: "4 laws, 2 pairs with LAT rows under both names"
    fix: "one record per instrument under legislation.gov.uk's own name (the CLML DocumentURI, wsi/…); the other retired with its LAT rows"
    step: Register
    status: open
  - pattern: "An amending provision commenced territory by territory, never in full, gave its changes no date, so the fold put them in force from the amending law's making (EA 1995 s.57 → EPA 1990 Part IIA in force from 1995-07-19; its orders date England 2000-04-01, Scotland 2000-07-14, Wales 2001)"
    category: territorial-stages-undated
    module: ChangeVocabulary.Readers.AmendingCommencement (claims/3)
    affected: "74 changes in 7 laws (EP 54); 552 EPA 1990 rows"
    fix: "dated from the first territorial stage, partial (Decision 3, B; fixed in this step with Jason's leave)"
    step: Amending-law reader
    status: fixed
  - pattern: "A territorial staged commencement of an amending provision is carried as one partial date, not as stages: the later territories' days are not held (EPA 1990 Part IIA: Scotland 2000-07-14, Wales 2001)"
    category: territorial-stages-as-stages
    module: ChangeVocabulary.Readers.AmendingLaw / AmendingCommencement, Label.Facts.territory_only/1, Merge
    affected: "74 changes in 7 laws"
    fix: "each later stage its own commenced change keyed id@date with the territory it is for, as the feed's staged insertions (Decision 3, A)"
    step: Amending-law reader
    status: open
  - pattern: "The shadow names a cause's evidence only from changes on the row itself, so a row dated or repealed by its container's change reads '(none dated)' (SSI 1999/1 reg.47(8)(a), repealed with Part II by SSI 2011/139)"
    category: shadow-cause-misses-container
    module: ChangeVocabulary.LabelShadow (cause/5)
    affected: "at least 332 rows of EP's causes (SSI 1999/1 266; EPA 1990 66)"
    fix: "the cause's evidence looks to the changes reaching the row through its containers, as the fold does"
    step: Switch-over
    status: open
  - pattern: "A change on HSWA 1974 by the Railways Act 2005 is dated 2005-07-24 by SI 2005/1909, whose rules for the Act are mostly partial ('for specified purposes', 'in relation to'), where it came in on 2006-04-01 (HSWA s.11(1), s.14, s.16, s.18(5)(b), s.43A(2)(a) and others)"
    category: partial-order-dates-in-full
    module: Commencement (evaluator over the 2026-11-10 order re-reads, ReadVersion de2446699978)
    affected: "20 OH&S checked rows (HSWA 1974); not yet counted elsewhere. Present before this step: rules read 2026-11-10, a path this step's code doesn't reach. OH&S's stored timeline already carries it (switched laws refold at each build)"
    fix: "find which rule gives the full date for the Railways Act 2005 provision; a rule 'in relation to' or for purposes dates only in part"
    step: Commencement reader
    status: open
  - pattern: "CLP (EU) 2008/1272 Arts 53a and 53b: expected in force in NI only from 2022-11-01 (omitted for GB by SI 2022/1037, kept in NI by the Windsor rule), now E+W+S+NI from 2019-06-20, then a period from 2022-11-01"
    category: windsor-ni-insertion-undated
    module: "unknown: Label fold (Windsor rule) or the feed reader's undated insertion"
    affected: "2 OH&S checked rows; present before this step (no change of this step reaches them)"
    fix: "trace the 2019-06-20 period's source; owner to be confirmed"
    step: Label fold
    status: open
  - pattern: "A Scottish SI's insertion reaches the England and Wales version of a provision, whose period starts before it (EPA 1990 s.78G(7)(a)[E+W] inserted 2006-04-01 by SSI 2005/658, period from 2000-04-01)"
    category: devolved-insertion-reaches-other-version
    module: "ChangeVocabulary.Label (versions, for_version?)"
    affected: "8 rows (EPA 1990 s.78G(7), s.78N(5), s.79(1B)); named known limits"
    fix: "a devolved law's insertion reaches only the version for its own territory"
    step: Label fold
    status: open
  - pattern: "A change by an amending law dated by the commencement source before that law was made (SI 2001/4027 reg.5 by the 2023 c.30 Act, 2022-06-06; made 2023-07-11)"
    category: commencement-before-made
    module: Commencement (date resolution for amending-law changes)
    affected: "7 EP rows; named known limits (Maritime's 2 likewise)"
    fix: "a commencement date before the amending law was made is not that law's; find which order or clause gave it"
    step: Commencement reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label/made.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/amending_commencement.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/evidence.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/known_limits.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_switch_report.ex
  - backend/lib/mix/tasks/lat.label_switch.ex
  - backend/config/config.exs
  - backend/data/reports/switch-over/environmental-protection-known-limits.md
  - backend/data/reports/switch-over/ (shadow, rules, samples, dry run, stored, text diff; gitignored)
  - docs/lat-change-pipeline/RULES.md
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/switch-over-check/SKILL.md

depends_on:
  - 2026-11-12-environmental-protection-labels-side-by-side.md

enables:
  - "Environmental Protection: Retrospective"
---

# Session: Environmental Protection: Switch-over (CLOSED)

## Problem

Step 13 for "💚 ENVIRONMENTAL PROTECTION". Every difference between the new and old labels is explained. Then the family's `lat_label_timeline` is written from its merged changes (AIMS `binds-on-date`).

- **The baseline** (Labels side by side): 122 laws, 35,766 rows. 13,229 agree, 17,872 differ today, 2,366 differ only in history, and 2,299 have no stored timeline. Territory alone accounts for 7,736 rows.
- **No bugs are parked on this step.**
- **Plan:** `~/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Open the session; `label_shadow` and `label_rules` for EP, saved to `switch-over/`
- ✅ Causes: a hand look at 12 seeded rows of each cause naming no evidence; the territory class profiled; classes over 100 rows as decisions for Jason
- ✅ Rules: `--list` each breach; own faults fixed, others parked; small classes named in `environmental-protection-known-limits.md`
- ✅ Checks: `label_checked --list` (accepts only by a decided rule); golden cited or re-run
- ✅ The after-apply comparison as a task (TDD): `mix lat.label_switch --family F --stored`, proved on a switched Maritime law
- ✅ Dry run saved → Jason → restore point `ep-switch-over-apply` → EP in `:label_families` → `--apply`
- ✅ After the apply: `--stored` 0 rows differing per law written; `mix lat.stale` 0; `mix test`; Credo
- ✅ Docs and close: WORKFLOW step 13, the skill, the meta row; commits by path, no push

## Pass rule (fixed at plan)

1. `label_shadow` sorts every differing row by cause, and the report is saved.
2. Each cause that names no evidence gets a hand look at 12 seeded rows. A class over 100 rows goes to Jason as a decision.
3. `label_rules` finds 0 breaches outside the named known limits.
4. `label_checked` matches every row, apart from known rows, upstream rows and other families' parked regressions.
5. Golden scores 27/27. This is Store and build's result, and it stands unless reader, merge or fold code changes.
6. The dry run folds all 122 laws, with 0 rule breaks.
7. After the apply, `--stored` shows 0 rows differing in each law written, with no law failed. Then `mix lat.stale` shows 0, and `mix test` and Credo are clean.

**The stop:** more than 5 new classes, or a class over 100 rows with no evidence, goes to Jason before any fix.

## Causes and rules (first run)

Saved in `backend/data/reports/switch-over/`: `environmental-protection-shadow.txt` and `-rules*.txt`. The samples are in `environmental-protection-samples/` (seed 1311). With the fold cache warm, each run took about 8 s.

- **Shadow:** 35,766 rows. 16,423 agree, 16,484 differ today and 2,859 differ only in history. The shadow counts a row with no stored timeline under its first difference, so these totals don't match the side-by-side view's four.
- **Rules:** 447 rows breach, with 19 legacy rows listed apart.
  - `no_made_period`: 440 rows (Decision 1).
  - `before_amender`: 7 rows. SI 2001/4027 reg.5 by the 2023 c.30 Act has a period from 2022-06-06, but the Act was made 2023-07-11. This is the parked Commencement reader class `commencement-before-made`, and the rows are to be named as known limits.

**Territory: explained by one rule** (7,736 rows differ on territory alone). `Fold.own_territory/3` applies a devolved law's own provisions where its type puts them (wsi, anaw, asc → W; ssi, asp → S; NI types → NI), or else where its title puts them ("(Wales)", "(England)", "(England and Northern Ireland)", "(Scotland)"). The old path took the extent. Each large class traces to it:

| Class | Rows | Laws, all with a place in their type or title |
|---|---|---|
| E+W → W | 5,138 | 24 Welsh laws: WSI 2026/103 1,004, anaw 2016/3 663, SI 2005/1806 498 … |
| old unknown → E+NI | 1,138 | SI 2025/67 (England and Northern Ireland) |
| E+W → E | 845 | 8 (England) SIs: SI 2020/971 157, SI 2024/1216 141 … |
| E+W+S+NI → E | 386 | SI 2015/810 and SI 2010/1157, both (England) |
| old unknown → W, S | 373, 115 | (Wales) and (Scotland) SIs |

The rule is in code with its example (SI 2017/544), but it has no RULES entry. One to look at: SI 2021/1309's place is read from the title of the law it cites ("Environmental Authorisations (Scotland) Regulations 2018 (…) Order", 28 rows).

**Causes that name no evidence: the hand look** (12 rows each, seed 1311):

| Cause | Rows | Finding |
|---|---|---|
| status in force → repealed (none dated) | 269 | SSI 1999/1, 266 rows. The rows are repealed by SSI 2011/139's repeal of Part II and Schedules 1 and 6A, a change at the container. The label is right; the shadow names only changes on the row itself. |
| in_force_from new undated (in force) | 608 | **Decision 2.** EPA 1990 Part IIA, 552 rows. |
| repealed → in force (no repeal held) | 79 | EA 1995 s.41, 54 rows: the old path has them repealed by SSI 2025/165, but the feed shows that SSI inserting s.41(2)(h)–(j) and repealing nothing in s.41. The old path is wrong and the new label is right. |
| in force → in force partial (none dated) | 68 | EPA 1990, all 68 rows, from its partial commencements of 1994. Still to read. |
| in_force_from old undated, new none dated | 66 | The new date comes from a container's commencement (pt.II, 1991-04-01). This is the same shadow gap as SSI 1999/1. |
| repealed (saved) → in force (no repeal held) | 58 | EPA 1990 s.92(3)(b) and others. The old path has repealed (saved) from 2017; the new label is in force in S, from a repeal for E+W only. Plausible. |
| prospective → in force (none dated) | 48 | 2021 c.30, 38 rows. Still to read. |
| changed_by old none | 519 | The commencer is taken as `changed_by` where no law made the text. This is the convention. |

## Decisions for Jason

### Decision 1: the Welsh SIs held under their UK names (`no_made_period`, 440 rows)

- **The question:** three Welsh SIs are held under their UK SI names: SI 2020/206, SI 2009/995 and SI 2005/1806. legislation.gov.uk's feed records each one's own commencement under its Welsh name (`UK_wsi_2020_206`). `Label.Made` doesn't take that as the law itself, so these rows get no prospective period from the law's making to its start. That is 25 days for two of the laws and 1 day for the third.
  - The fold already knows these are one instrument: `Facts.same_law?/2` and `NotePointer.same_law?/2`. That is a name pair, not a match by year and number alone.
  - The register also holds each of these laws twice, under both names. This is parked with Register.
- **The aim:** `binds-on-date` (a law made but not yet in force is prospective) and `fix-where-owned`.
- **The options:**
  - **A.** Fix it in the Label fold with your leave: `own_clause?/2` uses `Facts.same_law?/2`, test first. The fold's version moves, so the fold cache refolds and golden is re-run (about 4 min). The build's version doesn't move, so no rebuild.
  - **B.** Name the 440 rows as known limits. They keep their old labels, losing their territory and other gains.
  - **C.** Leave it parked and switch with the breach. This breaks pass rule 3.
- **Recommendation: A.** It is a one-line fix in a rule already decided, and class B is far over the triage size.
- **Decided: A** (Jason, 2026-11-12).

### Decision 2: EPA 1990 Part IIA in force from 1995 (608 rows, 552 of them in Part IIA)

- **The question:**
  - **What happens.** EA 1995 s.57 inserted Part IIA (contaminated land, s.78A–78YC) into EPA 1990. The stored change has no date: the feed marks it prospective, and the law text gives none.
  - **The new label.** The fold puts Part IIA in force from EA 1995's making (1995-07-19), with no in-force date.
  - **The old label.** In force from 2000-07-14 and 2001-09-15, depending on territory.
  - **The store.** It holds EA 1995 s.57's commencement rules: SI 2000/340 for England from 2000-04-01, SSI 2000/180 and SI 2000/1986 for Scotland from 2000-07-14, and WSI 2001/2351 and SI 2001/3211 for Wales from 2001-07-01 and 2001-09-15. So the date is known, but nothing dates the insertion by its inserting provision's commencement.
  - **The rest of the cause.** EA 1995 has 14 rows, SI 2004/1490 29, and WSI 2019/414 and SSI 2025/165 a few each.
- **The aim:** `binds-on-date`. Part IIA didn't bind anyone in 1995, so the new label would answer that question wrongly. `unknown-over-guess` also applies.
- **The options:**
  - **A.** Fix it in its owning step with your leave: an amending-law change with no date takes its inserting provision's commencement, by territory. First a store scan to size the class across families, then test first. The build's version moves, so all built laws are rebuilt (about 6 min for EP's 122; the other families' too), followed by golden.
  - **B.** Name the cause's rows as known limits, keeping their old labels (which have the right dates), and park the class with its owner. This is far over the triage size, but it writes no wrong label.
  - **C.** Pause the switch-over and open the owning step's session now, then come back.
- **Recommendation: A, after the sizing scan.** This is Maritime's precedent: the Part VI fault, 773 rows, was fixed in-step with leave. If the scan shows the dating rule reaches well beyond these laws, take C instead.
- **Decided: A, after the sizing scan** (Jason, 2026-11-12).
- **The sizing scan:** every undated amending-law change in the store, by what its amending provision's commencement rules say (a scratch script, `size.exs`, read-only):

  | What the rules give | Changes | Laws |
  |---|---|---|
  | **Dated only by territory, never fully** | **74** | **7** (EP 54, Pollution 12, Town & Country Planning 6, 2 others) |
  | A date in full (the change should already carry it) | 19 | 15 |
  | Dated only partly | 35 | 4 |
  | No dated rule | 413 | 23 |
  | No rules held | 16 | 2 |

  The territorial class is narrow: EA 1995 s.57 accounts for 26 of its changes (Part IIA, by range), EA 1995 Schedules 22 and 24 for most of the rest (Scotland only), then 1994 c.39 Sch.14 and 2004 c.5 Sch.9. **The cause:** `Commencement.Evaluator` gives s.57 no `full_from`. Its orders are for England (2000-04-01), Scotland (2000-07-14) and Wales (2001-07-01 and 2001-09-15), and nothing joins them into one date. So `AmendingCommencement.claims/3` dates nothing. The other undated classes are not this fault, and they stay with their owners.

### Decision 3: how a territory-by-territory commencement dates an amending-law change

- **The question:** each territory's order gives a date for its own territory, but an amending-law change holds one date. What should the change carry?
- **The aim:** `binds-on-date` (Part IIA binds in England from 2000-04-01, and in Wales only from 2001), and `unknown-over-guess`.
- **The options:**
  - **A. Stages, as the feed's staged insertions already do.** The change is dated from the first territorial stage, partial, and each later stage is its own commenced change with the territory it is for. The fold then reads Part IIA as in force in England from 2000-04-01, in Scotland from 2000-07-14, and in Wales from 2001.
    - This needs new records from the amending-law reader, `Facts.territory_only/1` to take the commencement's territory as well as the feed's, and Merge to keep the new keys apart.
    - It touches the Amending-law reader, the Label fold and Merge: about half a day, then a rebuild of all built laws and golden.
  - **B. The first stage, partial.** The change is dated from the earliest territorial stage, partly in force (`partial: true`), and nothing more. Part IIA reads as in force in part from 2000-04-01: true, but it doesn't say where.
    - This is one function in `AmendingCommencement`, using the `{:commencement, :partial}` claim the evidence table already has.
    - It needs a rebuild and golden.
  - **C. Known limits.** The cause's rows keep their old labels, and the class is parked with the Amending-law reader for option A in its own session.
- **Recommendation: B now, and A parked with the Amending-law reader.** B removes the false "in force from 1995" with a small change. A is new structure across three steps' code, and it belongs in the owner's session, not in the Switch-over.
- **Decided: B** (Jason, 2026-11-12). A is parked with the Amending-law reader.

## Fixes (Decisions 1 and 3)

- **Decision 1, `Label.Made`:** `own_clause?/2` now compares by `Facts.same_law?/2`. The test is `label_made_test` "a Welsh SI held under its UK SI name", red first. This moves the fold's version only.
- **Decision 3, `AmendingCommencement.claims/3`:** with no full date, the earliest territorial stage dates the change, `partial: true`, `commenced_by` its order. Three tests in `amending_commencement_test` (the first red first). A purposes-only stage still dates nothing.
- **Checks:** `change_vocabulary/` 3,475 tests pass; `compile --warnings-as-errors` clean; Credo adds no issues; architecture 22 pass.
- **The rebuild:** the fix moves the build's version, so all 445 built laws went stale. With the restore point `ep-switch-over-territorial-stages` (provision_changes, provision_change_claims, lat_events) taken, `--build --stale` (Jason: "Go") built 445 laws in 666 s with 1 worker. The 266 switched laws were refolded in 232 s, 0 failed, and `lat.stale --strict --switched` showed 0. The 964 old-path laws are stale on the old label version, as they were before: `LabelVersion` covers none of these files.
- **Golden caught a regression: 26/27.** TCPA 1990 s.78(4BA), inserted by a Welsh Act (anaw 2015/4) and commenced only for Wales (WSI 2017/546), took the order's 2017 date as partial and lost the feed's stages (2015 partial, 2017 full).
  - **The fix:** Decision 3's dating now applies only where the stages name more than one territory, which is what the decision describes (EA 1995 s.57: E, S, W). An order for one territory alone is a devolved Act's whole reach, so the feed's stages stand. Test first: "an order for one territory alone dates nothing". Golden from inputs is **27/27** again.
  - **The second rebuild** (Jason: "Go"), restore point `ep-switch-over-territorial-stages-2` (with lat_label_timeline): 445 laws in 704 s; 3 switched laws refolded, 0 failed.
- **After it:** rules showed 15 breaches (`no_made_period` 0, down from 440). Shadow: Part IIA's 552 rows are now in force in part from 2000-04-01, and the cause "in force from, new undated" is down from 608 to 69. Known limits: 15 rows in 2 classes, under 10 rows each (`environmental-protection-known-limits.md`, read by `KnownLimits`). Then **rules PASSED** (0 breaches; 18 legacy rows listed apart).
- **The checked rows caught a second regression: 22 of OH&S's 744 changed.**
  - 20 are HSWA rows whose changes by the Railways Act 2005 moved from 2006-04-01 to 2005-07-24; 2 are CLP rows.
  - **The cause:** the first-stage date was a `:commencement :date` claim, which outranks the feed's. So it re-dated changes that the feed had already dated correctly.
  - **My sizing scan missed this:** it counted only undated changes.
  - **The fix, as Decision 3 B means it** (date only what nothing else dates): the stage is a fallback claim, `{:commencement, :date_staged}` with `:partial_staged`, ranked last in the evidence table, after the feed's date. It names no commencing order, because a stage's order beside the feed's later date would name the wrong law. That makes a one-line ranking change in `Evidence`, the Evidence step's table, made under this decision's leave.
  - **Tests:** two evidence tests (alone, and beside the feed's date) and the reader's tests updated; 3,479 tests pass. Golden from inputs is 27/27.
- **The third rebuild** (Jason: "Go"), restore point `ep-switch-over-territorial-stages-3`: 445 laws in 658 s; 266 switched laws refolded, 0 failed.
  - **Rules: PASSED**, 0 breaches outside the known limits.
  - **Shadow:** 16,430 agree, 16,506 differ today, 2,830 differ only in history.
  - **Checked rows:** 674 match, 47 known, 1 upstream, **22 changed**. The same 22 as before the third rebuild, and **not this step's**:
    - 20 HSWA rows are dated 2005-07-24 by a full commencement rule of SI 2005/1909, read 2026-11-10 (ReadVersion de2446699978). Neither of this step's code paths reaches that date: the staged claim ranks last, and `Made` only touches making periods.
    - The last clean run was 696 match on 2026-11-07. EP's Commencement steps didn't re-run the checked rows.
    - 2 CLP rows (Arts 53a and 53b) have a territory and a period from 2019.
    - Both are parked with their owners. Pass rule 4 allows them as other families' parked regressions, and they stay changed in the fixture (not accepted).
  - **Lesson:** run `label_checked` in every step that changes commencement readings. Maritime's lesson said this, and the EP Commencement steps skipped it.

## The after-apply comparison (`--stored`)

`mix lat.label_switch --family F --stored` runs the dry run against the stored timeline (`LabelSwitch.stored/1`) instead of the old register. It compares every field the switch writes, `changed_by_all` and `commenced_by` included (`LabelSwitchReport.law/5`, `:written`). The csv is `dry-run-<family>-stored.csv`. One test in `label_switch_test` (red first) and 7 related tests pass. It replaces Maritime's scratch script. **Proved on Maritime:** 117 laws folded, 24,285 rows, **0 differ** (`maritime-safety-stored.txt`).

## Dry run

`environmental-protection-dry-run.txt` and `.csv`:
- **Folded:** 122 laws, 0 not, none breaking the table's rules.
- **Rows:** 35,251, of which 19,727 differ from the old register.
- **Periods:** 63,345 → 69,521.

Today's status, old → new:

| Status | Old | New |
|---|---|---|
| in force | 29,916 | 29,195 |
| in force in part | 843 | 2,508 |
| prospective | 2,041 | 1,709 |
| repealed | 431 | 741 |
| repealed (saved) | 664 | 649 |

The code is committed: d986d976, hooks passed.

## The apply

(Jason: "Apply")
- **Before:** restore point `ep-switch-over-apply` (lat_label_timeline, lat_change_log, provision_changes, provision_change_claims, lat_events). "ENVIRONMENTAL PROTECTION" added to `:label_families`, its exact name with the marker dropped.
- **`--apply`:** **122 laws written, 0 failed.**
- **`--stored`:** 122 laws folded, 34,802 rows, **0 differ**; periods 69,521 → 69,521.
- **`lat.stale --strict --switched` exits 1.** The change register is clean: 0 of 445 built laws stale. But **59 of 388 switched laws are stale on parser_version**: EP laws whose LAT was parsed by an older parser.
  - This predates the step. `--switched` counts only switched families, so these weren't counted while EP was unswitched.
  - Their labels are the switch's (0 differing); what's out of date is the LAT parse stamp.

## After the apply

- **The 59 parser-stale laws** (Jason: "Text diff first"): the offline `lat.text_diff --store only` gave 0 rows changed. Then (Jason: "Go"), restore point `ep-switch-over-reparse`, `lat.reparse --store only`: 59 laws, 0 changed, 0 dropped, 0 failed.
  - The re-parse left its snapshot tables `lat_reparse_ep_switch_over` (+ `_cm`) in `public`. This is the parked LAT parser bug; drop them when convenient.
- **Then:**
  - `--stored`: 122 laws, **0 differ**;
  - `lat.stale --strict --switched`: **0 of 388**, exit 0;
  - `mix test`: 10,704 passed, 2 skipped.
- **Commits:** d986d976 (code, hooks) and ba267099 (config, hooks).

## Parking list

- Register: `welsh-si-two-register-records`. Four Welsh SIs are held under both their uksi and wsi names, two of them with LAT rows under both.
- Amending-law reader: `territorial-stages-as-stages`. Decision 3 A: each later stage as its own change.
- Switch-over: `shadow-cause-misses-container`. The shadow names only the row's own changes as evidence (at least 332 rows).
- Commencement reader: `partial-order-dates-in-full` (22 OH&S checked rows) and `commencement-before-made` (7 EP rows).
- Label fold: `devolved-insertion-reaches-other-version` (8 rows) and `windsor-ni-insertion-undated` (2 OH&S checked rows).
- Label fold, observed: Part IIA's partial periods now have no `changed_by` (EA 1995 before). This is worth a look when option A is taken.
- Territory: SI 2021/1309 takes "(Scotland)" from the title of the law it cites (28 rows).

## Dependencies

- ✅ Environmental Protection: Labels side by side (closed 2026-11-12, 4e6f67bd): the baseline
