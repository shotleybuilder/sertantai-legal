---
session: 'CV-S09: Label Fold'
status: active
release: v0.1
bugs:
  - pattern: "EU directives (eudr) after IP completion day: no rule fits all. A directive's end depends on whether the Windsor Framework keeps it in NI (Jason 2026-10-30). Needs that source; golden Directive 90/269 Art 8b(1) is held out"
    category: label
    module: ChangeVocabulary.Label (and a Windsor Framework source)
    affected: 15 OH&S directives
    fix: "Hold the Windsor Framework source (which directives continue in NI); the rule per directive to agree with Jason"
    status: open
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S09: Label Fold (ACTIVE)

## Problem

Step 9 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Correct label periods per D1, D3 and C1–C12.

The session does not close until its results pass.

## Todo

- ⬜ Provision facts: exists_from/to — when a provision itself exists (deferred from CV-S07, Jason 2026-10-29; carried from CV-04)
- ✅ Define what good looks like (agreed 2026-10-29: strata G/S/T/R, fold-fault bound, golden ~50) (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ✅ Build the strata and samples: `mix lat.label_check` (ff1f97c7)
- ✅ The `label-check` skill: check prompt, golden-drafting prompt, known classes, seed history
- ⬜ Round 1 (ask Jason before any long run)
- ✅ The golden set is big enough to trust: grown to 50 (39 laws) on 2026-10-30. Drafted blind, reviewed by Gemini, rulings by Jason. Directive 90/269 Art 8b(1) is held out until the Windsor Framework source exists
- ⬜ Golden expected tiers per period, and the start's tier from its source (deferred in CV-04)
- ⬜ A row commenced only through some of its children reads in force, not in force partly (open bug, V1-01)
- ⬜ A commencement for one territory ("for E.W.S.", "for N.I."): the feed reader carries it as `in_force_for` (CV-S02 D5). The fold should read it as in force there, not "partly in force" everywhere (2 effects in the OH&S family)
- ⬜ A change placed on territorial versions (`placed_versions`: the bare `s.51A(2E)(a)` held as [E+W] and [S]) changes only the versions its extent reaches (HSWA s.51A(2E)(a): effect extent E+W+N.I., markup only in [E+W]; SI 2008/1597 reg.12(1)(b)(iv)): confirm the fold narrows by the carried extent (CV-S02 final check)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order: CV-S01–S08 closed PASS; CV-S08 2026-10-29)

## What good looks like

AGREED by Jason, 2026-10-29, before round 1:
- fold faults count against the R bound, and upstream faults are fixed and published as the end-to-end figure;
- golden grows to about 50 before round 1;
- stratum T is drawn by class with `--per 10`.

**The unit.** A row is one LAT provision with all its label periods. Each period has `valid_from`/`valid_to`, `status`, `territory`, `in_force_from`, `changed_by` and tiers. A row is wrong if any field of any period is wrong.

**What is checked.** The fold (`ChangeVocabulary.Label`, and the orchestration in `ChangeVocabulary.labels/5`) builds periods from the row's resolved changes under D1, D3 and C1–C12. Faults:
- **fold fault:** a period is wrong given the resolved changes. Either a convention was applied wrongly or not at all (C9: a child's change on its parent; C5: one law where two changed the text that day; C2: no "nowhere"), or the periods are wrongly bounded, or the start is wrong.
- **upstream fault:** a period is wrong because a resolved change is wrong. This is the reader's, the merge's or the evidence table's fault, so it is noted with its step, and the fix goes in that step's batch.
- **gap:** a value no source gives, for example C10, a start commenced by an order we don't hold. A gap is not WRONG; it is counted with its reason.

**Population.** OH&S core family: 149 laws, 20,556 LAT rows. Changes are stored for 145 laws (26,475). Today's labels cover 18,350 rows.

**Strata.** A new `mix lat.label_check`, read-only, which folds the stored changes (`--stored`):
- **G, golden (in full):** `mix lat.vocabulary --golden` from inputs. It is 27/27 today, and grows before round 1 (todo 3).
- **S, shapes (by pattern, `--per 10`):** rows where a named fold rule acts. The rules: prospective; partly in force; repealed or "nowhere"; one territory repealed and the row retained (C1, C12); territorial versions (C3); an application clause narrowing territory (C6); renumbering (C4); a parent commenced through its parts; several laws on one day (C5); a commencement for one territory (`in_force_for`); a change placed on versions; a gap. Each rule is applied the same way to all its rows, so a shape is judged as a whole.
- **T, today differs (by class, `--per 10`):** rows where the fold's periods differ from `lat_label_timeline`, classed by the field that differs (status, territory, `in_force_from`, `changed_by`, period bounds). This stratum only draws rows to check. Classing every difference is CV-06's shadow run.
- **R, random (5 × 30 rows):** drawn on a fresh seed. A row whose periods haven't changed since it was checked carries over.

**The agent check.** Each row is judged against the law's sources: its CLML text and markup, the feed's records, and the amending laws' text and commencement. Every period and field gets OK, WRONG (fold or upstream, with evidence) or gap. The prompt goes in a new `label-check` skill.

**Pass rule** (agreed 2026-10-29, before round 1):
- **G:** from inputs, all pass, at the grown size.
- **S and T:** no shape or class with a fold fault left unfixed or unclassed.
- **R:** the pooled rows since the last fix under 2% wrong rows and under 5% wrong laws, at the 95% Clopper–Pearson upper bound.
- **Upstream faults** are fixed in batches like fold faults. Their rate is published in the quality statement as the end-to-end figure.

**Measures** (CV-S10 owns the full set; this step publishes the label shares, each tested):
- share of rows with a dated `in_force_from` today;
- share prospective, partly in force and repealed today;
- share with a gap, by reason;
- share whose current period rests on derived evidence.

## The strata (2026-10-29, ff1f97c7)

`mix lat.label_check --family "OH&S: Occupational" --strata` folds every provision row of the family from its stored changes, the way `--golden --stored` does, in about 2m45s (not seconds: each law's CLML is parsed for the markup's facts). The modules:
- `LabelSource`: database reads and the fold;
- `LabelStrata`: shapes, differences and the draw (pure, 15 tests);
- `LabelSample`: the agent's item.

A row's provisions are `legal_articles` rows other than signatures, headings and tables.

149 laws are folded, 20,371 rows, none failed. Current status:

| status | rows |
|---|---|
| in force | 18,485 |
| repealed and saved | 833 |
| prospective | 730 |
| repealed | 288 |
| partly in force | 35 |

**S shapes** (a row can have several):

| shape | rows |
|---|---|
| prospective | 4,708 |
| text change | 3,484 |
| ancestor's text change or repeal | 3,381 |
| undated start (C10) | 2,988 |
| undated change | 2,048 |
| repealed | 1,121 |
| version (C3) | 787 |
| territory narrowed (C1, C12) | 540 |
| several laws in a day (C5) | 127 |
| partly in force | 64 |
| `in_force_for` | 13 |
| parts | 6 |
| renumbered (C4) | 1 |

Application (C6) has no rows. `ancestor` first counted every commencement on an ancestor (15,783 rows, which says nothing), so it was narrowed to text changes and repeals. An S probe (seed 90, `--per 10`) drew 88 rows; no full effect id is in the file.

**T classes** (today's label differs):

| class | rows |
|---|---|
| history only | 9,154 |
| no label today | 2,200 |
| `in_force_from` | 2,129 |
| `in_force_from` + territory | 874 |
| `in_force_from` + `changed_by` | 860 |
| territory | 355 |
| status + `changed_by` + territory | 295 |
| status + `in_force_from` | 242 |
| other classes | about 410 |

**Pointers to check in round 1** (not findings yet):
- The undated start covers 20 laws. LawStart leaves them undated: 15 EU directives, plus REACH and CLP (`eu_publication_relative`), and `by_order` / `no_clause`.
- 2,048 rows are reached by a change no source dates. The fold leaves these out (`Label.fold`, which takes dated changes only), so the gap is not visible on the label.

## Growing the golden set (2026-10-29)

24 candidates were chosen from the probe draws (S seed 90, R seed 91, T seed 92). These probe seeds are never used for R. Each S shape has at least one candidate, as do two plain random rows and two T classes. Agents drafted them blind, from the sources only, never seeing the fold or today's label (`label-check` skill, golden-drafting prompt), in four batches:
- **A:** SI 1999/3242 reg.3(3) (C4) and reg.12(2) (C5); 1963/41 s.76 and s.91 (parts); 1984/3 s.1A(b) and s.1(6B) (`in_force_for`).
- **B:** SI 2013/1471 reg.15(5)(b); CLP Art 2(17); SI 2008/2337 reg.5 (C1/C12); SI 2008/1597 reg.19(1)(b)(ii)[NI] (C3); NISR 2007/31 reg.3(6) (D3); REACH Art 140.
- **C:** NISR 1997/248 reg.11(9); SI 1989/462 reg.7(2); 2007/19 s.2(1)(d); SI 2009/1348 reg.19B(5)(b); SI 1977/500 reg.4A(1)(c); SI 1981/917 reg.8(2).
- **D:** SI 2015/51 reg.33; 1937/67 s.108(1)(a); Directive 90/269 Art 8b(1); 1961/34 s.127(3); SI 1974/2068 reg.12; SI 2008/1597 reg.7(5)(b)[NI].

**Pointers from the probes** (to judge in round 1, not findings yet):
- Territorial versions carry the wrong territory: SI 2008/1597 reg.7(5)(b)[NI] and reg.13(2)[NI] show E+W+S, and HSWA s.51A(2C)[E+W] shows E+W+S. This is the open todo on versions.
- Some rows have no territory at all: 1937/67, SI 2025/661 and SI 2004/1309.

### Review and sign-off (2026-10-30)

Gemini 2.5 Pro reviewed all 24 drafts against C1–C12 (`backend/data/code-reviews/2026-10-30-cv-s09-golden-gemini.md`). It approved 15, amended 8 and found 1 undecidable.

**Taken:**
- s.76's `changed_by` is the EPA 1990 alone, because the 1976 repeal was of its children (C9).
- CLP Art 2(17) is E+W+S from 2020-12-31: C8 applies to any GB-only text change, not only omissions.
- C14: inserted text takes the inserting law's narrower extent (SI 2013/1471 reg.15(5)(b)).
- C6 covers instrument-wide application clauses (SI 2015/51 reg.33).
- A repeal by consolidation (Factories Act 1937 → 1961) is labelled as drafted.

**Contested:**
- **The commencement AMENDs** to 1984/3 s.1A(b), s.1(6B) and 2007/19 s.2(1)(d). Gemini keeps `in_force_from` at the first commencement and credits the inserting law. That contradicts D1 as Jason corrected it on 2026-10-21: a commencement is a version, with its own date and its own law.

**Jason's rulings (2026-10-30):**
- **C13:** a commencement for one territory is in force there, and each commencement is a version (D1). So a later territory's commencement widens the territory and opens a version.
- **D3 stands:** repealed_saved applies when the feed or the law names a saving. Whether the saving reaches the row is not judged. Gemini's AMEND to SI 2008/2337 reg.5 and its "undecidable" for NISR 1997/248 reg.11(9) are not taken.
- **Rule 9 covers** a modification drafted as a substitution ("shall be modified as follows … for regulation 8 substitute"). It is not a version (SI 1981/917 reg.8(2)).
- **EU directives after 2020-12-31:** "None of the 3 is right for Windsor and right for everything else." A directive's end depends on whether the Windsor Framework keeps it in NI. Directive 90/269 Art 8b(1) is held out of golden until that source is held (open bug below).

**Pointers for round 1** (from the drafts, not findings yet):
- **The law's start for the Factories Act 1937 is 1937-07-30** (Royal Assent), but its s.160(2) commences it on 1938-07-01. This is upstream, in LawStart.
- **A parent repealed through its children** (OSRPA s.76: (1)–(2) in 1977, (3) in 1991). Under C9 the children's repeals open nothing on the parent, so the fold may never repeal s.76. This is the repeal twin of "commenced through its parts".
- **No row extent** for the 1937/67, 1989/462, 1974/2068 and 2008/2337 rows: `legal_articles` has none. The Act's extent clause or the application clause gives one. This is upstream, in the extent reader.

## Round 1 (2026-10-30; seeds S 101, T 102, R 103)

Draws (`mix lat.label_check`, run in parallel with golden):
- **S:** 84 rows (`--per 10`);
- **T:** 144 rows (`--per 10`). The agents check the first 4 per class (64);
- **R:** 150 rows. The agents check the first 50; the rest are kept for the pooled rounds after the fixes.

**G, golden from inputs: 35/50.** All 27 original provisions pass; 15 of the 23 new ones fail.

| class | provisions | where |
|---|---|---|
| K8: C8 not applied (GB omission reads repealed nowhere; GB substitution keeps NI) | REACH Art 140, CLP Art 2(17) | fold |
| KV: version split on its start not made, and the other version's one-territory repeal narrows this one | SI 2008/1597 reg.19(1)(b)(ii)[NI], reg.7(5)(b)[NI] | fold |
| K13: one-territory commencement | 1984/3 s.1A(b), s.1(6B); 2007/19 s.2(1)(d) | fold, and s.1A(b) reads prospective then partial |
| KP: commenced through its parts not read | OSRPA 1963 s.76, s.91 | upstream (SI 1964/191's rules?) |
| KU-missing: a change the law states, no stored change | 1937/67 (1961 consolidation repeal), 1961/34 s.127(3) (1975 words repeal), 1989/462 reg.7(2) (1990 substitution, feed undated) | upstream |
| KU-ext: territory from C6/C14 not applied | SI 2015/51 reg.33 (GB), SI 2013/1471 reg.15(5)(b) (C14) | upstream |
| changed_by credits a revoked inserter | SI 2013/1471 reg.15(5)(b) (SI 2017/238) | upstream (evidence/merge) |
| KU-start: the made version's Status="Prospective" read as the row prospective | NISR 1997/248 reg.11(9) | markup reader |

### Round 1 agent check: FAIL

There were 10 agents (the per-batch notes are kept in the scratchpad as `r1/findings.md`).

| stratum | rows | OK | WRONG-fold | WRONG-upstream | gap | doubtful |
|---|---|---|---|---|---|---|
| S | 84 | 18 | 44 | 13 | 7 | 2 |
| T (4 per class) | 64 | 19 | 23 | 14 | 8 | 0 |
| R (first 50 of 150) | 50 | 27 | 6 | 9 | 8 | 0 |

R has 6 of 50 rows wrong in the fold (12%), across 6 laws. That is far over the 2% bound, so round 1 fails. Golden is 35/50.

**Fold classes** (each one rule; they are batch 1's fold fixes):

| # | class | evidence | rule |
|---|---|---|---|
| F1 | KI-insert: a row inserted after the law's start is labelled from the law's start; this is a regression, since today's labels start them right | about 60 rows across S, T and R; all 23 of 23 inserted rows in R. Golden missed it because each case gives its own `start` | the row starts at the provision-level insertion (on itself or its nearest inserted ancestor), with the inserting law's territory (C14); an undated insertion gives an undated start (C10); the law's own commencement never reaches an inserted row (the commencement reader also writes `LAW:commencement:<row>@start` for them) |
| F2 | KV: versions not split at their start (RestrictStartDate), and the other version's one-territory repeal narrows this one; n-suffixed version ids (section-28n2-7-a) are left out of the base's union | about 20 rows: SI 2008/1597, HSWA s.51A, s.28, s.23, s.16, s.14, s.43A | split at the version's start (C3); a repeal reaches only the versions its territory overlaps; gather every version of the base |
| F3 | K13: a one-territory commencement | 1984/3 s.1 rows; 2007/19 s.2(1)(d) | in force there, each commencement a version (C13) |
| F4 | K8: C8 for GB-only changes to EU law | REACH and CLP rows | a GB-only change (insert, substitute, omit) on 2020-12-31 or later leaves NI with the EU text |
| F5 | NEW-A: a whole substitution, fully commenced (on the row or an ancestor), doesn't end in_force_partial, and every later version is swallowed | HSWA s.10, s.11, s.11(6)(b) (SI 2008/960) | it opens a version: in_force, its date and its law |
| F6 | NEW-B: a partial commencement on the start day reads prospective | SI 1992/3004, SI 2005/1643, NISR 2006/1 | commencements on the start day apply before "a later commencement reaches it" |
| F7 | NEW-C: repealed_in_part read as C7 when the words are gone (not retained) | Factories 1961 s.125(2)(j), s.127(2)(j), s.127(5); 129 changes in 17 laws | C7 only when the text is retained or the removal is for one purpose; otherwise it is a words repeal, a version |
| F8 | KP: commenced through its parts, read wrong | OSRPA s.76 | partial from the first part's commencement |

**Upstream classes** (fixed in the owning step's code, in batch 1 where small):

| # | class | step | evidence |
|---|---|---|---|
| U1 | an amending law revoked before its change took effect is still credited (C5) | evidence/merge | SI 2018/1377 (revoked by NISR 2020/330 reg.13), SI 2017/238 |
| U2 | a range insertion is also stored on its common parent | feed/merge | key …24f25d "s.1(6A)-(6C)" also on s.1; about 6 parents |
| U3 | "to which section 51 … relates" read as commencing s.51 | commencement reader | SI 1964/191 art.2 |
| U4 | a general commencement excepting a child is stored as full on its ancestors | commencement | SI 2008/401 / 2007/19 s.2(1)(d) |
| U5 | a second commencement rule for a subsection scope is not stored as a change | commencement → changes | HSWA s.10(1), s.10(6), s.11(6) on 1975-01-01; OSRPA s.91(4) on 1990 |
| U6 | an order's commencing law is not carried as commenced_by (98 of 99 order-schedule commencements) | commencement | SI 1974/1439 on HSWA |
| U7 | level defaults to provision with no source, so a "word deleted" becomes a whole repeal | evidence | SI 1992/3004 reg.5(3)(a) |
| U8 | feed Type "abolition" is not mapped (25 EU effects) | feed reader | CLP Art 25(5) |
| U9 | a legacy Addition round original text "repealed … with saving" is read as an insertion | evidence (legacy rule) | OSRPA ss.4–16 (d30p…) |
| U10 | extent: a conditional NI clause; rows with no extent; C6/C11/C14 not applied | extent reader | Employment Act 1989 s.30(6); 1937/67; 1957/31; SI 2025/1110; SI 2015/51 |
| U11 | KU-start: a made version's Status="Prospective" taken as the row prospective | markup reader | NISR 1997/248, 1999/304, 1999/305, 1999/13 |
| U12 | KU-missing: a repeal in a schedule table or by consolidation is not stored | amending reader (KS) | SI 1974/1943 Sch.1, SI 1975/1011, the 1961 consolidation |
| U13 | law identity: UK_uksi_2005_423 for UK_wsi_2005_423 | commencement | CROW Wales order |
| U14 | KF-type: a feed "words substituted" or "revoked in part" wins for a modification or a misplaced effect | evidence | NISR 1999/150 on NISR 1995/491; SI 1996/1513 on HSWA s.48 |
