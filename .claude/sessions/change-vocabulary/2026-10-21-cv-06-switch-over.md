---
session: 'CV-06: Switch-over and Measure'
status: active
release: v0.1
opened: '2026-10-21'
started: '2026-10-31'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
bugs:
  - pattern: "A container whose verb follows its items (\"In section 17— (a) … (d) …, shall cease to have effect\") read as a whole repeal of the section"
    category: amendment reader
    module: Amendment.Reader / AmendingLaw.Text
    affected: 1 known (LGSA 1994 Sch.13 para.119(10) on Water Act 1980 s.17)
    fix: "a container with its own items and a trailing verb: read each item with the verb; never the container whole"
    status: open
  - pattern: "\"except in so far as it extends to Northern Ireland\" on a repeal: its territory not read (repeal labelled everywhere)"
    category: amendment reader
    module: Amendment.Reader.RepealTable
    affected: 1 known (SI 1974/1941 on FA 1961 s.77(2))
    fix: "read the line's territorial limit as the rule's territory (GB)"
    status: open
---

# Session: CV-06: Switch-over and Measure (ACTIVE)

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
- ⬜ The CV-05 gaps, as causes or fixed first: rows left to orders we don't hold (J6), pending and unapplied changes (J4), no gap list, headings and signatures unfolded
- ⬜ Rounds: fixes batched until the code pass holds (batch 2 against the rules, below) (checked rows all match, rules 0 breaches, golden 27/27); agents only to find new classes (Jason 2026-11-01)
- ⬜ The code pass: `switch_checked.json` + `mix lat.label_checked`; `LabelRules` + its check
- ⬜ The writer: `LabelRefresh` takes `LabelSource.timeline/1` for the switched families (one setting); migration for `changed_by_all`, `commenced_by`; the law's start off `lat_change_log`
- ⬜ Dry run on OH&S → Jason → restore point (`lat_label_timeline`) → write; the other families' labels unchanged (diff 0)
- ⬜ Skill: the switch-over check for the next family (recipe step 12 in CV-00)

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
