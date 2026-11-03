---
session: 'CV-06: Switch-over and Measure'
status: closed
release: v0.1
opened: '2026-10-21'
started: '2026-10-31'
closed: '2026-11-03'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  OH&S: Occupational / Personal Safety switched to labels folded from merged changes: 149 laws written
  through LabelRefresh, none failed; 38,714 periods. Pass decided by code: golden 27/27, label rules
  passed, checked rows 696 match / 47 known / 1 upstream. Faults owned by earlier steps routed to CV-06b.

decisions:
  - what: Switch by family through one setting (label_families); the old path stays for v0.1
    why: other families have not passed steps 1-11
    result: OH&S only; every other law keeps the old labels
  - what: The pass decided by code (checked rows + LabelRules + golden), agents only to find new classes
    why: Jason 2026-11-01 "a pass that doesn't rely on agents"; agent rounds were slow and noisy
    result: lat.label_checked + lat.label_rules, both PASSED before and after the apply
  - what: Earlier steps' faults named and routed, not fixed in-step
    why: Jason 2026-11-02 "boiling the ocean"
    result: CV-06b pending (reader, commencement, fold faults; 47 known-limit rows)
  - what: Missing repeals (39) and named date gaps (7) keep the register's label; law start stays on lat_change_log for v0.1
    why: Jason 2026-11-02
    result: KnownLimits merged into the written timeline
  - what: Land CV-06 with FA 1961's 4 changed rows as known limits; skip the next-family skill
    why: Jason 2026-11-03 "finish sensibly so we can run the retrospective"; the process is about to change
    result: CV-06 closed; skill deferred to after CV-S12

metrics:
  causes_start: { rows: 20371, agree: 10479, differ_today: 5382, history_only: 4510 }
  agent_round_1: { own_fault: "53/390", upper_95: "16.8%", old_label_wrong: "365/390" }
  code_pass: { checked_rows: 744, match: 696, known: 47, upstream: 1, golden: "27/27", rules: passed }
  apply: { laws: 149, failed: 0, minutes: 7.6, periods: 38714, changed_by_all_set: 5831 }
  status_today_new: { in_force: 16998, partial: 1, prospective: 0, repealed: 513, repealed_saved: 925, unknown: 247 }
  elapsed: { opened: "2026-10-21", started: "2026-10-31", closed: "2026-11-03" }

lessons:
  - title: A switch-over step drifted into re-fixing earlier steps
    detail: >
      Rounds 2-5 fixed reader, commencement and fold code to make checked rows pass, where the step's
      purpose was to explain differences and switch. Jason stopped it ("boiling the ocean"). Ownership
      of each fault by workflow step must be decided before fixing, and routed when not the step's.
    tag: tooling
  - title: Agent sampling rounds gave way to a code-decided pass
    detail: >
      Agent rounds (13-14 agents x 30 rows) found classes but were slow and their bound hard to close.
      Hand-checked rows frozen in a fixture plus table rules, re-run in seconds, made the pass repeatable.
    tag: tooling
  - title: Writing labels through the real refresh re-collects inputs the shadow did not
    detail: >
      The apply re-read three laws' starts from their own clauses (FA 1961 Royal Assent -> 1962-04-01),
      which exposed a fold rule (undated legacy insertions as makers) and changed 4 checked rows.
      Shadow comparisons should use the same input collection as the writer.
    tag: data
  - title: Two numbering schemes (CV-NN sessions, CV-SNN steps) confused the person steering the work
    detail: CV-06 (step 12b) vs CV-S06 (step 6). For CV-S12 Retrospective.
    tag: tooling

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_switch.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/known_limits.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/build.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/primary.ex
  - backend/lib/sertantai_legal/scraper/label_refresh.ex
  - backend/lib/mix/tasks/lat.label_switch.ex
  - backend/lib/mix/tasks/lat.label_checked.ex
  - backend/lib/mix/tasks/lat.label_rules.ex
  - backend/priv/repo/migrations/20261102190600_label_timeline_changed_by_all.exs
  - backend/test/fixtures/change_vocabulary/switch_checked.json
  - backend/data/reports/change-vocabulary/cv-06-date-gaps.md
  - backend/data/reports/change-vocabulary/cv-06-dry-run.csv

depends_on:
  - 2026-10-21-cv-05-consumers.md
  - 2026-10-31-cv-06a-repeal-tables.md

enables:
  - change-vocabulary/2026-11-02-cv-06b-routed-fixes.md
  - change-vocabulary/2026-10-30-cv-s12-retrospective.md
---

# Session: CV-06: Switch-over and Measure (CLOSED)

## Problem

OH&S labels should come from the new method (merged changes folded by `ChangeVocabulary.Label`, built beside the old in CV-05). Before the switch, every difference from today's labels must be explained: 16,487 of 20,371 OH&S rows differ (CV-05). Old acceptance cases from the 2026-10-21 stub (SI 2010/404 reg.14, Forestry Act 1967, Coronavirus Act 2020 s.78, SI 2016/1105 reg.72(2)(b), TCPA 1990 s.78(4BA)) are among them or in golden.

**Scope (Jason 2026-10-31):**
- **OH&S only, by family.** One setting lists the switched families; every other law keeps the old labels until its family passes steps 1–11. So the old path, its tables and rules stay for v0.1; their removal waits until the last family switches.
- **Group, then sample.** Code sorts the differences into causes; an agent checks a seeded sample of each cause against the law; a cause is accepted when the new method holds within the 95% bound decided in advance; a cause where the old label is right is fixed in the new method.

Judged on the original 27 golden (Jason 2026-10-31).

## Todo

- ✅ Causes: `LabelShadow.cause/5` (tests), `mix lat.label_shadow --family F [--cause C --sample FILE --n N --seed S]`; OH&S counts below
- ✅ Pass rule (Jason 2026-10-31, "15 a cause + pooled bound"): 15 rows of each cause with 50+ rows, 30 from the small causes pooled; a cause passes with no sampled row new-wrong by its own fault; pooled 95% upper bound on own-fault rows under 2%; golden 27/27. The 39 known-limit rows keep their old label (Jason). Skill `switch-over-check`
- ✅ U12 first (Jason 2026-10-31): CV-06a closed — 113 of the 152 rows now hold their repeal; 39 a named known limit (`cv-06a-known-limits.md`): how the switch treats them is decided here
- ⏸️ (deferred to CV-06b — already in the written labels as known gaps) The CV-05 gaps, as causes or fixed first: rows left to orders we don't hold (J6), pending and unapplied changes (J4), no gap list, headings and signatures unfolded
- ✅ Rounds: fixes batched until the code pass holds (batches 2–5, below) — **the code pass holds on OH&S (2026-11-02)** (checked rows all match, rules 0 breaches, golden 27/27); agents only to find new classes (Jason 2026-11-01)
- ✅ The code pass: `switch_checked.json` + `mix lat.label_checked`; `LabelRules` + its check
- ✅ The writer: `LabelRefresh` takes `LabelSource.timeline/1` for the switched families (one setting); migration for `changed_by_all`, `commenced_by`; the law's start stays on `lat_change_log` for v0.1 (Jason 2026-11-02)
- ✅ Dry run on OH&S → Jason ("Apply", 2026-11-02) → restore point `cv06-switch-apply` (`lat_label_timeline`, `lat_change_log`, `provision_changes`) → write
- ⏸️ (deferred — written after CV-S12 changes the process; Jason 2026-11-03) Skill: the switch-over check for the next family (recipe step 12 in CV-00)

## Dependencies

- ✅ CV-S01–S11 passed (S11 closed 2026-10-31; S12 Retrospective comes after CV-06)
- ✅ CV-01 signed off by Jason
- ✅ CV-05 closed (2026-10-31): baseline, retirement list `backend/data/reports/change-vocabulary/cv-05-retirement-list.md`

## Decisions (2026-10-31)

- **Repeals as the table records them** (Jason: "keep the table's rule"): `in_force_from` the repeal's day, territory empty. The old timeline does so for every repealed_saved period (5,727 of 5,727) and most repealed ones.
- **changed_by** is the law that made the text, else the law that commenced it — the old labels' meaning (follows "add, don't replace"); the list and the commencer stay in `changed_by_all`, `commenced_by`.
- **A law with no start** (EU law, C10): no period from the fold's placeholder (1900-01-01): unknown before the first dated day, as the table has it.
- **Made, not yet in force** (LR-39; Jason: "add it"): `Label.Made`, from the law's making to its start, where its own law commences the provision. The old applied it only where no feed commencement existed, so it was uneven; the new applies it wherever the law commences the row itself. Golden doesn't pass `made`, so it is untouched.
- **U12 before the switch** (Jason: "fix U12 first").

## Causes on OH&S (2026-10-31, commit f2313200)

20,371 rows: agree 10,479; differ today 5,382; history only 4,510 (CV-05's raw count was 16,487). Largest causes:

| Rows | Cause |
|---|---|
| 3,477 | history: new prospective from the law's making |
| 2,040 | today: in_force_from new later (commenced [law]) |
| 751 | today: status prospective→in_force (commenced [law]) |
| 450 | history: territory |
| 407 | today: in_force_from old undated, new inserted [law] |
| 330 | today: old unknown, new in_force |
| 281 | today: status prospective→repealed_saved (repealed [law]) (NISR 1997/248) |
| 235 | today: in_force_from old undated, new substituted [law] |
| 208 / 172 | history: start later / earlier |
| 160 | today: territory Windsor E+W+S+NI→E+W+S |
| 152 | today: status repealed→in_force (no repeal held) — U12, old right |
| 132 | history: status |
| 121 | today: status repealed→in_force (repealed [law]) (EU law kept in NI) |

`[law]`: the change stands on the law (its text, its clause, an order read); `[lgu]`: legislation.gov.uk only.

## Round 1 (2026-10-31, seed 601, 13 agents × 30 rows)

Verdicts: `backend/data/reports/change-vocabulary/verdicts/cv06/ohs/round-1-seed-601-b*.json`; `mix lat.verdicts`: own 53/390 (95% upper 16.8%), groups 14/59; end to end 61/390; gaps 4; doubtful 4. **Old label: wrong 365/390, right 10, unsure 15.**

Own-fault classes (fix list; rows):

| # | Class | Rows | Where |
|---|---|---|---|
| R1 | A whole substitution's history reaches sub-provisions only a later text has (CLP Art 37(7),(9); SI 2008/1597 reg.12B(1)(b),(3)(b),(6)); rows the new text drops carry on (NISR 1997/248 reg.20(1)(a)); a substituted paragraph's children read as inserted, history dropped (NISR 1999/305 reg.11(2)); a repeal with the substitution ignored (SI 1999/3242 reg.22(2)) | 15 | fold (Label.Start/Day) and amending reader |
| R2 | Savings the amending law's text states not read: repealed, should be repealed_saved (SI 1992/3004 reg.27(2) for OSRPA; "except for the purposes of …" FA s.161, s.168) | 8 | amending reader (saved) |
| R3 | A staged commencement schedule not read (SI 1989/2169 Sch.1 Pt I: reg.26 from 1.7.1994, dated 1990 from lrt metadata) | 5 | commencement reader |
| R4 | A version split dated at the version's start, not when the texts diverge (HSWA s.16 2006 vs 2015) | 5 | fold (Label.Version) |
| R5 | Part/heading rows lose their own words changes (`Label.within` rewrites a Part row's own changes to "*"); an EU container loses dated history | 5 | fold (Label.within) |
| R6 | Territory of the amending provision: E+W-only Acts (SOCPA 2005, Building Act 1984) given E+W+S; "amendments extend as the amended provision" (P&JA 2006 s.54(5)) not read; a GB-only change applied to the NI version | 4 | extent reader / fold |
| R7 | Undated text changes dropped (EPA 1975 Sch.15 para.15(1); 1998 c.8 dated by its rule but not reaching) | 3 | merge/fold |
| R8 | A change stated by feed, markup and law text not reaching the row (NISR 2010/160 reg.28 by 2020/222); a parent's words change not reaching its child in history | 2 | merge |
| R9 | A feed effect misplaced ("word deleted reg. 5(3)" merged as reg.3 inserted, SI 1992/3004) | 2 | merge |
| R10 | Singles: unapplied prospective change blanks in_force_from; revoked-before-in-force amender (2018/1377, U1); words repeal read as whole (OSRPA s.52(5)); undated repeal at the law's start (HSWA s.70); a `#2` row reached by nothing | 5 | various |

Known (not counted): the cv-06a list (s.8, s.34), KC-order (1920 c.65 ×2); **HSWA s.30 rows** (repeal by EPA 1975 Sch.18 not read, markup wraps s.30 in an Addition) — not on the list: add. Upstream: s.48 feed "revoked in part" really an application.

Doubtful to decide: whole-section substitution and the history before it (HSWA s.11(1)); a commencement default to Royal Assent where the Act's own commencement section is repealed (1985 c.9).

**Decisions after round 1 (Jason 2026-10-31):** fix in batches, keep the 2% rule; batch 1 = R1–R5 (38 of 53). A whole substitution of a provision keeps the history before it: HSWA s.11(1) is in force from 1974 under its earlier wording, a new period from 2008 changed by the 2008 law ("In force from 1974").

**Decision (Jason 2026-10-31, reconciling the 2026-10-30 quote ruling with HSWA s.11(1)): "Evidence it existed."** A sub-provision existed before its parent was substituted only where a source shows it: a dated change to it (or under it) before then, or an earlier text holding it (the text held predating the substitution; an earlier quote; the as-enacted text). Otherwise it begins at the substitution that first makes it. The 2026-10-30 ruling stands wherever there is no such evidence.

## Fix batch 1 (2026-10-31, commit c8fbfe4e; golden 27/27)

- **R1** `Label.Existence`: a sub-provision begins at the latest whole substitution above it unless a source shows it was there (the text held predates it — the made text predates all; a change to it or under it before then; a repeal of it that day, unless it is inserted that day); a quote's insertion of a provision so shown is a substitution of its text; its own whole repeal outranks a same-day substitution above it. `Dropped`: a quoted provision listing no items, the quote reading items as deep elsewhere, drops its old items (NISR 2003/152 reg.20). Checked on CLP Art 37(9)(a), SI 2008/1597 reg.12B(1)(b), NISR 1999/305 reg.11(2)(a), HSWA s.11(1), SI 1999/3242 reg.22(2), NISR 1997/248 reg.20(1)(a).
- **R2** `Reader.Savings` → `amendment_rules.saved` (migration `20261031191507`) → a `:law_text` savings claim, ranked before the feed's.
- **R3** `LawStart.ScheduleClause`: a clause "in accordance with the provisions of Part I of Schedule 1" reads that Part's sentences (SI 1989/2169: reg.26 / Sch.6 fully in force 1994-07-01, partly 1991). No LAT law uses the form; amending laws re-read with `--read-amending`.
- **R4** `Label.Version.diverged/3`: a version split starts when a text change under it first reaches part of the union only.
- **R5** a Part row is never its own container.

Applied (Jason "all of it"): restore point `cv-06-before-batch1`; `lat.amending --read`; `lat.commencement --read-amending`; OH&S rebuild; round 2 draw seed 602.

## Round 2 (2026-10-31, seed 602, 14 agents × 30 rows; after batch 1)

`mix lat.verdicts` (verdicts/cv06/ohs/r2): own 58/405 (95% upper 17.5%), groups 12/60; end to end 64/405; gaps 7; doubtful 1. **Old label: wrong 387/405, right 5.** Round 1 was own 53/390 (13.6%): batch 1 fixed its classes on the rows it targeted (every R1/R3/R4/R5 example re-checked right), but the new draw found further classes, and batch 1's existence rule introduced two of them.

Own-fault classes (rows):

| # | Class | Rows |
|---|---|---|
| S1 | Existence too strict: a commencement naming the sub-provision (SI 1974/1439 "Section 10(1)", "Section 11(1) to (3)") or a dated change with no resolved operation is not counted as evidence; a `Dropped` repeal of a later-made row counts as its own evidence (SI 2009/1348 reg.19(1A), 20(5)) | 9 |
| S2 | Savings forms still unread: "The whole section except …" (fixed in 2dd26eb7, unapplied), "except in so far as …" (fixed, uncommitted), "except in relation to investigations …" | 9 |
| S3 | Territory: `Windsor.confine` lost when a parent's whole substitution passes down (REACH Art 51(3), 93(1)(a), 129(2)(a); CLP Art 45(5)(d)); an E+W+S amending law (SI 2026/484 reg.1(2), 2022 c.30 s.169(3)) applied UK-wide; a GB amendment credited on the NI version | 10 |
| S4 | No prospective period before a commencement by order (NISI 1997/1774, made 1997-07-22, by SR 1998/235) | 6 |
| S5 | Undated or misdated changes: an amending law's change placed at the amended law's commencement, before the amending law existed (EPA 1975 Sch.15; Building Act 1984 s.64, s.70); text changes missed (ERDRA 1998 "employment tribunal", NICA 1973, HCDA 1975, Water Act 1989) | 9 |
| S6 | A parent's change not reaching its children (REACH Art 3(36)(a)–(d) words insertion; NISR 1997/455 reg.3(1)(ii), reg.2(1)) — round 1's R8 | 5 |
| S7 | Insertions dated from the host's commencement (FA 1961 s.10A(3)(b), s.125(8); OLA (NI) 1957 s.1(4)) | 3 |
| S8 | Version history: HSWA s.43A[NI] gets the 1974 start; s.51A versions split late | 4 |
| S9 | Singles: commencement "so far as it relates to …" read as a range (OSRPA s.83); staged repeal by premises (PUWER 1992); feed effect on a stray marker; changed_by from a parent's change; revoked-before-in-force amender; unapplied prospective change | 6 |

## The pass, decided by code (Jason 2026-11-01: "a pass that doesn't rely on agents"; "rules + checked rows")

Agents find problems; code decides the pass:
1. **Checked rows** (`test/fixtures/change_vocabulary/switch_checked.json`): every row an agent judged in rounds 1–2. Judged right: its periods then are the accepted label. Judged wrong: to fix, its expected label written from the agent's sourced note when its fix lands. `mix lat.label_checked` compares the current labels with every accepted one: pass = all match, none left to fix (known limits apart).
2. **Rules** (`LabelRules`): each fault class a check over every row of the family (an amending law's change dated before that law was made; a period before the row's insertion; a UK change after 2020-12-31 to a Windsor Annex 2 law reaching NI; a law made before its start with no prospective period; a saved repeal not repealed_saved; …): pass = 0 breaches outside the named known limits.
3. Golden 27/27.

Replaces the per-cause agent sample and the pooled bound as the pass (decided 2026-10-31); `mix lat.verdicts` stays as a finding tool.

## Fix batch 2 against the rules (2026-11-01, commits c0066de5, 3cb1349c)

First rules run on OH&S (stored changes): 76 rows breach — before_amender 32, before_insertion 22, no_made_period 27 (overlapping).

- **before_amender** (32): an undated change by a later law sat at the row's start. Fix (Jason: "amending law's first start"): `Readers.AmenderStart` dates it at the amending law's earliest dated commencement rule (`commencement :via amender_first_start`). Needs the rebuild.
- **no_made_period** (27 → 0 on stored changes): a law brought in by orders, no start held. Fix: `Label.Made.by_order` — it begins at its making, prospective, when a dated commencement follows.
- **before_insertion** (22): rows only old-style markup (d29p… Additions) called inserted, which the fold ignores, because that markup also marks substitutions (OSRPA ss.4–16). Jason: "fetch as-enacted, then decide". The amending law's text now decides each:
  - FA 1961 s.10A (9 rows): EMASA 1972 s.3 "shall have effect as if the following section were inserted" — was read as a modification.
  - FA 1961 s.125(7)–(9): SI 1988/1655 reg.23 "shall be modified as follows—" read by its items; "add the following subsections" quotes.
  - FA 1961 s.182(9) (substituted, not inserted) and OSRPA s.4(4) (words substituted): SI 1974/1941, 1974/1943 Sch. 2 "MODIFICATIONS—THE … ACT" — a heading in capitals now names the law.
  - FA 1961 s.164(5),(7): a repeal with a saving, not an insertion — one table line's subsection clauses now each a line with its own saving.
  - HSWA s.5(5)–(7): EPA 1990 Sch.15 para.14 is repealed in the revised text: fetched as enacted (`Enacted.wanted` now takes repealed provisions too, 9 for EPA 1990, 1 for OSA 1992); "amended by the insertion— (b) …, of the following subsections" takes its parent's verb.
  - HSWA s.15(6)(e): OSA 1992 s.4 as enacted; "Part I of the … Act 1974 (“the 1974 Act”)" defines the Act.
  - A legacy Addition the law text also claims now moves the start (`Label.Start.legacy_only?`).
- Also: "except in so far as it extends to Northern Ireland" is no saving (FA 1961 s.77(2): where the repeal reaches; its territory not yet read — later).
- Regression preview: 99 of 367 laws gain rules (25,037 → 26,305). Most are container pointers ("In section 48(8)— (a) … (b) …") whose items are now read; samples from 5 laws checked against the text, all right.
- Found, not fixed (pre-existing): a container whose verb comes after its items ("In section 17— (a) … (d) …, shall cease to have effect": LGSA 1994 Sch.13 para.119(10)) is read as a whole repeal of s.17.

### Batch 2 applied (2026-11-01; restore point `cv06-batch2-apply`: amendment_rules, extent_rules, provision_changes)

- Read pass: 2,102 laws, 208 changed, rules 44,702 → 46,694; one law lost rules — SI 1974/1941's Sch.2 paras 12–13, credited before to EMASA 1972, now to FA 1961 (right: "In section 176(1) …" of the Factories Act).
- Golden first 25/27: AmenderStart dated a repeal the feed marks prospective (Planning (Wales) Act 2026 on TCPA s.78(4BA), s.284(3)(a)). Fixed (1c7363a4): never for a change marked prospective. Golden 27/27.
- Rules on OH&S: 76 → 6 rows breaching (before_amender 6). before_insertion 0; 34 rows listed apart as `legacy_unconfirmed` (4d8da976): only old markup says inserted, AmenderStart now dates them, the fold rightly doesn't move their start — most are EPA 1975 Sch.15 substitutions of HSWA (s.15(1), s.30, s.43(6), s.80(4)–(5)); a few look like real insertions with no law text read (HSWA s.28(10) 1988, APNI 1957 s.4(8) 2001, NISI 1997/1774 reg.7(3)(a),(aa) 2000).
- before_amender 6: an undated law-text change whose amending law's commencement rules aren't held (HSWA s.34(6) by the Gas Act 1986; s.51A(2) by PRA 2002; OSRPA s.90(2) by the Electricity Act 1989; SI 1989/462 regs 4, 7 by SI 1989/2367): credited from the row's start. To decide: date at the amending law's making as the lower bound, or a gap.
- Checked rows: 617 match, 5 changed → accepted (NISI 1997/1774: the made period added, as the round-2 note on reg.7 asks), 103 to fix, 5 to decide, 13 known, 1 upstream.
- before_amender 6 → named date gaps (Jason 2026-11-01: "Named gap"): `backend/data/reports/change-vocabulary/cv-06-date-gaps.md`, listed apart by `mix lat.label_rules`. **Rules on OH&S: PASSED** (0 breaching; legacy_unconfirmed 34 listed apart). How the writer labels a gap row is decided with the writer.
- Next: the 103 checked rows to fix.

## The 103 checked rows to fix (2026-11-01)

- Reviewed each row's current label against its checker's note: 60 now do what the note asks (batches 1–3) — accepted with `--accept`, which now keeps the checker's note beside the why (6ea54afd, plus 4).
- Batch 3 (87e3e60e): an order naming the row (it, or a range at its depth) is evidence it existed (HSWA s.10(2), s.11(2), s.11(4)); a quote's dropped rows are no evidence (SI 2009/1348 reg.19(1A)). Golden 27/27, rules PASSED, checked rows 682 match.
- **43 left**, by class:
  1. Commencement detail (7): HSWA s.10(1) two stages (Commission 1974, Executive 1975) shown partial only; s.24(2),(4) dated 1998-04-08, the order says 1998-08-01; s.28(5)(b)[E+W] Water Act 1989 date/territory; s.70, s.70(1) never in force before the 1984 repeal; OSRPA s.83 "so far as it relates to" read as a range; FA 1961 s.13 staged repeal (PUWER 1992).
  2. Version territory (12): HSWA s.13(3), s.16 ×4 (versions part 2006, split shown 2015), s.43A[NI] ×3, s.51A(2E)(g)[S]; OSRPA s.9(6); SI 2008/1597 reg.2(2)[NI]; CLP pt.V.ch.2.
  3. A never-applied prospective change blanking in_force_from (2): HSWA s.51A(2A), (2B).
  4. A parent's change not reaching its children (5): REACH Art 3(36)(a),(c),(d), Art 77(A3)(b)#2; APNI 1957 s.1(4).
  5. Changes missed (7): NISR 1993/20 reg.3(3)(a), 1997/455 reg.2(1), reg.3(1)(ii), 2010/160 reg.28; OSRPA s.52(5), s.91(3); HSWA s.84(1)(b).
  6. An amender that never took effect (2): NISR 1999/90 reg.2(1), 2003/34 reg.7(12).
  7. Misread or misplaced changes (4): REACH Art 3(A2)(c) changed_by; SI 1992/3004 reg.3(1) (SI 2002/2174 reg.6 read whole: its items' quotes taken as targets); SI 2002/2677 reg.7(9)(b) stray marker; SI 1999/3242 reg.22(2).
  8. Legacy markup (1): HSWA s.28(9)[S].
  9. Checker's note disputed by a source (2): SI 2009/1348 reg.20(5), (5)(b) — the feed records SI 2011/1885 revoking reg.20(5)(a),(b), so a made (5) existed: to decide.
- SI 2009/1348 reg.20(5), (5)(b): accepted (Jason: "Accept") — the feed shows the made reg.20(5).
- Batch 4 (3c611824, aa5d29ca): a versioned section's rows split when the section's texts first part (Jason: "when the section parts"; HSWA s.16 2006, s.14 2006, s.28 1988) — 20 accepted rows re-accepted with the earlier split, their notes kept; an undated change the feed holds prospective and unapplied is not credited (HSWA s.51A(2A),(2B)). 12 more rows fixed. Golden 27/27, rules PASSED, checked rows 694 match.
- **31 left**: commencement detail 8 (HSWA s.10(1), s.24(2),(4), s.28(5)(b)[E+W], s.70, s.70(1); OSRPA s.83; FA 1961 s.13); version/change territory 4 (HSWA s.13(3); OSRPA s.9(6); SI 2008/1597 reg.2(2)[NI]; CLP pt.V.ch.2); amending text not read 5 (REACH Art 3(36)(a),(c),(d) — SI 2019/758 Sch.1 para.4 has no rules; Art 77(A3)(b)#2 duplicate id upstream; APNI 1957 s.1(4)); changes missed 7; an amender that never took effect 2 (its own provision omitted or revoked before it took effect: needs the amending law's own changes read — cf. the GitHub issue on withdrawn SIs); misread or misplaced 4 (SI 2002/2174 reg.6 read whole with its items' quotes; REACH Art 3(A2)(c); SI 2002/2677 reg.7(9)(b); SI 1999/3242 reg.22(2)); legacy markup 1 (HSWA s.28(9)[S]).

## The code pass holds on OH&S (2026-11-02)

- Batch 5 (a9a287af, 53c07afc): a later Act's first start is its orders', not its Royal Assent (ERDRA 1998 on HSWA s.24); "Part I except section 4" excepts the section (order re-read: 133 orders, 6 s; restore point `cv06-orders-reread`); a Schedule's law named one hop back (SI 2019/758 on REACH: 98 → 402 rules); an EU Article's "paragraph 36" is its (36). Read pass (restore point `cv06-batch5-apply`): 13 laws changed, all EU-amending SIs, rules 46,694 → 47,019.
- Found and backed out: EU laws get no change from their amending SIs' text — the rules name "art.3(36)(a)", the rows "art.Article 3(36)(a)", so every rule drops as a misread. Respelling them surfaced a deeper misread (an SI's quoted Article read with its paragraphs as Articles: "For Article 22 substitute— Article 22 1. … 2. …" → art.1, art.2), which moved 4 accepted REACH rows wrongly. Its own session: the EU law-text path (named below).
- The 29 rows left: named known limits by class (Jason: "fix by class, then name the rest"), each keeping its checker's note — EU law text 5; upstream structure 4; an amending provision withdrawn before it took effect 2; a change no source we read holds 7; commencement detail 7; a change's own territory on an unversioned row 3; legacy markup 1.
- Rows to decide: s.11(1), SI 2002/2677 reg.7(7)(c), SI 2009/1348 reg.23(2) settled by Jason's rulings; OSRPA s.71(2) not a text change (Jason); HSWA s.79 a named date gap (Jason).
- **Pass:** golden 27/27; `mix lat.label_rules` PASSED (0 breaching; 32 legacy_unconfirmed and 7 date gaps listed apart); `mix lat.label_checked` PASSED (700 match, 43 known, 1 upstream).
- Next: the writer.

## Scope correction (Jason 2026-11-02: "boiling the ocean")

Much of rounds 2–5 fixed earlier steps' code to make checked rows pass, where CV-06's purpose is to explain the differences and switch. The fixes already made stay (tested, golden 27/27), recorded by owning step; from here CV-06 changes only its own code (the writer, the check tools), and faults owned by earlier steps are named and routed to **CV-06b** (`2026-11-02-cv-06b-routed-fixes.md`, pending; the open bugs moved there).

| Owning step | Fixes made in CV-06 |
|---|---|
| CV-S06 amendment reader | repeal tables (per table, header search, continuation, one-law form, ranges, savings); "as if … were inserted"; a capitals Schedule heading names its law; a pointer to a provision changing nothing reads its items; "add the following"; an item's verb from its parent's noun; "Part I of the … Act (“the 1974 Act”)"; repealed provisions fetched as enacted; one section's subsection clauses; the territorial "so far as it extends to"; a Schedule's law one hop back; EU "paragraph 36"; three read passes |
| CV-S04 commencement | ScheduleClause; "except section 4" in orders; a commencement naming the row (`:named`); the order re-read |
| CV-S09 label fold | evidence it existed (Existence); Dropped no evidence; version split at the section's divergence; a pending prospective change made nothing; Made (LR-39, by_order); AmenderStart and its first start |
| CV-06 own | LabelPeriods, LabelSource, LabelShadow, the code pass (LabelRules, Checked, `lat.label_rules`, `lat.label_checked`), known limits and date gaps |

## The writer (2026-11-02)

Jason 2026-11-02: the 39 missing-repeal rows (CV-06a) and the named date gaps keep the old label; every other row, the 43 named known limits included, takes the new one. The law's start stays read from the register for v0.1 (the refresh still writes `lat_change_log` for OH&S); retiring it goes with the old path.

- 736f86a9: the per-law build moved out of `mix lat.vocabulary` into `ChangeVocabulary.Build` + `ChangeVocabulary.Primary` — behaviour-preserving (`provision_changes` digest identical over OH&S's 149 laws).
- 1331b0cb: `LabelSwitch` (the `:label_families` setting, empty until a family is applied; `merge_kept/3`; `timeline/2` refuses rows breaking the table's rules), `KnownLimits` (the two lists), `LabelRefresh` builds and writes a switched law's timeline, migration `20261102190600` (`changed_by_all`, `commenced_by`, applied to dev), `mix lat.label_switch` (dry run; `--apply` through `LabelRefresh`), `LabelSwitchReport`.

### Dry run (OH&S: Occupational / Personal Safety)

149 laws folded, none failed; 18,684 rows, 9,903 differ from today's labels; periods 30,024 → 38,677 (history the register didn't hold).

| Today | old | new |
|---|---|---|
| in_force | 16,273 | 16,998 |
| in_force_partial | 6 | 1 |
| prospective | 1,116 | 0 |
| repealed | 461 | 513 |
| repealed_saved | 494 | 925 |
| unknown (no period) | 334 | 247 |

The 1,116 prospective rows today are the register's: the NISRs whose made version marks every row prospective (NISR 1997/248, 1999/305, 2003/35, …) were never moved to in force — the new method has them in force from their commencement (checked rows accepted). repealed_saved 494 → 925: the savings read from the amending laws' text (R2). Per law: `backend/data/reports/change-vocabulary/cv-06-dry-run.csv`.

### Applied (2026-11-02)

`label_families` set to OH&S: Occupational / Personal Safety (c8c643cd; none under test); `mix lat.label_switch --apply`: 149 laws written through `LabelRefresh`, none failed, 7 m 35 s. Today's status counts as the dry run's exactly; 38,714 periods; `changed_by_all` set on 5,831.

After it: golden 27/27; rules PASSED; checked rows 696 match, 4 changed (FA 1961 s.1(3)(b), s.5, s.6, s.60(1): in force 1962–1996 now "date unknown"). Cause: the refresh re-collected three laws' starts from their own commencement clause (FA 1961 1961-06-22 → 1962-04-01; UK_ukpga_1937_67 → 1938-07-01; UK_ukpga_1957_31 → 1958-01-01 — the register had held Royal Assent). With FA 1961's start now its commencement day, an undated legacy-markup insertion on the row (d29p…, no law named) counts as the text's maker at the start, so the date blanks — 50 FA 1961 periods. The start correction is right; the maker rule is the fold's (CV-S09) → CV-06b.

### Landed (2026-11-03)

Jason: "finish sensibly so we can run the retrospective". FA 1961 s.1(3)(b), s.5, s.6, s.60(1) made known limits (09ca8a1a); `mix lat.label_checked` PASSED (696 match, 47 known, 1 upstream). CV-05 gaps to CV-06b; the next-family skill waits for CV-S12. Closed.
