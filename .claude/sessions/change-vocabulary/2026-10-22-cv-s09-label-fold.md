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

### Decisions for batch 1 (Jason 2026-10-30)

- **`commenced_by` becomes a label of its own.** `changed_by` holds the laws that made the current text, and `commenced_by` the law that brought it into force: the commencing order, or [] when the law commenced itself. A commencement still opens a version (`in_force_from` its date). Golden is updated to match. This supersedes the 2026-10-21 D1 correction that put the commencing law in `changed_by`. Golden had applied it unevenly: HSWA s.78 had [] after SI 1974/1439, while 2021/30 s.8 credited SI 2022/48.
- **Batch 1 scope:** fold F1–F8, plus the small upstream fixes U1, U2, U3, U6, U7, U8, U11 and U13. U4, U5, U9, U10, U12 and U14 stay open, as classes for later batches.

### Fix batch 1 (55705654): golden from inputs 39/50

**Fold:**
- `Label` is split into `Label.Start`, `Label.Day` and `Label.Facts`, plus `ChangeVocabulary.Parts`.
- **Done:** F1 (starts at its insertion, C14), F2 (versions split on their own day; n-suffixed ids join their base), F3 (C13), F5, F6, F7 and F8 (parts named as our rows).
- **New:** the most specific commencement governs. An ancestor's commencement never reaches a provision commenced in its own right (2007/19 s.2(1)(d); this is U4 handled in the fold).
- **New:** `commenced_by` is its own label.

**Upstream done:** U2, U6, U7, U8 and U11; the first stage of a staged insertion now carries its qualification; the own-commencement read covers every row.

**Deferred:**
- **F4 (C8)** needs the Windsor Framework source, the same as the directives bug: which EU instruments still apply in NI. REACH Art 140 and CLP Art 2(17) fail until then.
- **U1** (revoked amender), **U3** (relative clause), **U13** (`uksi`/`wsi` naming of orders; the law-itself check is fixed in `Facts.same_law?`) and the new **U15** (an order's carve-out "except in relation to …", OSRPA s.76 and s.91) all need commencement-store or source work.

**Golden corrections, with evidence:**
- The `commenced_by` migration: HSWA s.78, TCPA s.78(4BA), 2006/16 s.73, 2007/19, 2018/16 s.6, 2021/30 s.8 and the CROW rows.
- SI 1977/500 reg.4A(1)(c) becomes E+W+S. The inserting SI 1992/2051 is a GB HSWA instrument, so C14 applies; the draft had followed the CLML.
- The feed-pattern catalogue accepts 44 examples: 39 first-stage qualification claims and 5 "abolition" effects.

**The 11 golden failures**, all upstream or deferred:

| class | provisions |
|---|---|
| C8 | REACH Art 140, CLP Art 2(17) |
| U12 | 1937/67, 1961/34, 1989/462 |
| U15 + U12 | OSRPA s.76, s.91 |
| U13 | CROW ×2 |
| U1 | SI 2013/1471 |
| U10 | SI 2015/51 |

Tests: 9,547 (1 fixed: `Version` now covers `label/*`).

## Round 2 (2026-10-30; seeds S 111, T 112, R 113)

- **Restore point:** `provision_changes` and `provision_change_claims`, tag `cv-s09-batch1`.
- **Rebuild:** OH&S rebuilt (`--build --family`); 145 laws, 26,475 changes, no errors.
- **Golden from the store: 36/50.** The extra failures (SI 2012/3038, SI 2016/1105, SI 2017/544) are laws outside the family whose stored changes date from 2026-10-22, so they are stale. Golden from inputs (39/50) is the authority.
- **Current status:**

  | status | rows |
  |---|---|
  | in force | 19,076 |
  | repealed and saved | 1,001 |
  | repealed | 286 |
  | partly in force | 8 |
  | prospective | 0 |

  All 730 rows prospective in round 1 were NISR made versions (U11).
- **Draws:** S 86 rows; T 148 rows, of which the agents check 4 per class (65); R 150 rows, all checked, by 16 agents.

### Round 2 agent check: FAIL

16 agents; per-batch notes in the scratchpad (`r2/findings.md`).

**R** (150 rows, seed 113):

| count | fold faults | 95% one-sided upper bound |
|---|---|---|
| excluding K8 and tiers | 3 / 150, 3 laws | about 5.1% |
| including deferred K8 | about 10 / 150 | — |

The three non-K8 fold faults are:
- HSWA s.28(3)(c)(i)[E+W]: the split date;
- SI 2008/1597 reg.16(11)(b)[NI]: the pre-split extent;
- HSWA s.25A(1): an undated ancestor insertion.

Upstream faults are about 17 of 150 rows, mostly U10 extent and U12 missing repeals. Round 1 was 6/50 excluding tiers, so the fold rate has dropped from 12% to 2%, but it is still over the 2% bound.

**S** (86 rows) and **T** (65 rows): every fold class found is either already in R or listed below.

**Tiers.** The agents differed: some counted the start period's null tiers as WRONG, others as the deferred todo. Every first period has null tiers, including those opened by an insertion, and synthetic "parts" commencements are tiered derived. This is to be fixed in batch 2; the counts above exclude tiers.

**Fold classes for batch 2:**

| # | class | evidence |
|---|---|---|
| G1 | versions: the pre-split extent and split date from the nearest versioned ancestor's versions (union of all; earliest sibling start), not the row's own id | SI 2008/1597 reg.16 [NI] children (sibling version a stub, up to about 730 [NI] rows); HSWA s.28 [E+W] 2023 against [S]/[NI] 2018 |
| G2 | an undated whole insertion on an ancestor: C10 start (in_force_from nil), changed_by the inserting law | HSWA s.25A(1) (CPA 1987) |
| G3 | a repealed row revived by a later whole substitution or insertion of it or an ancestor | SI 2022/1378 reg.9(3), reg.9(9) (omitted 2023, reg.9 substituted 2024) |
| G4 | an undated own substitution after an undated insertion is credited | CLP Art 25(7) |
| G5 | a nil extent never yields a remainder: take the law's root extent, else no territory left after a territorial repeal | SI 2008/2337, SI 1987/605 rows read "in force NI" |
| G6 | the most-specific rule ignores commencements dated before the row's start (a later-inserted row's law-start record) | CROW s.1A(a), s.1(6A)(b) and others; golden s.1A(b) |
| G7 | tiers: the start period's from the changes behind it; parts records from their children's; commenced_by tiered | all inserted starts; HSWA and OSRPA parts |

**Upstream classes found in round 2:**

| # | class | evidence |
|---|---|---|
| V1 | the feed's `staged_removal` gives no partial claim on its partial stages, so F7 reads them as words gone (regression risk) | HSWA s.47(5), s.47(1)(b) |
| V2 | a range expanded over rows inserted later than the range | SI 2009/1348 reg.19BB under "reg. 19A-19F" (2011) |
| V3 | the feed's InForce CommencingURI is not carried as commenced_by | HSWA s.51A(2)(b), SI 2006/378 |
| V4 | markup-only Addition words changes stored with no operation (83 in OH&S) | Factories 1961 s.125(6) |
| V5 | a words substitution that creates new sub-paragraphs is stored as substituted, not inserted | HSWA s.11(4)(ii); NISR 2010/160 reg.3(m) |
| V6 | nested Additions: the outer range ChangeId credited to a later insertion | CROW s.1(6AA) |
| V7 | commencement: "Except so far as … X shall not come into force until D" missed | HAA 1995 s.5(2) |
| V8 | an amending law's single whole-law clause date is not attached to its undated change | SI 1989/2367 on SI 1989/462 reg.7 (golden reg.7(2)) |
| V9 | a parent-level "in each place it occurs" words change is not placed on children | SI 1975/335 reg.5(1) |
| V10 | legacy free-text feed revocations ("rev. and replaced") are not placed at "*" | SI 1997/2505 |
| V11 | U2 may persist: CROW s.1 still holds the range insertion 24f25d | to check |

Still deferred: K8/C8 (Windsor), U1, U3, U5, U10, U12, U13, U14, U15.

**A ruling is needed:** do "in earlier amending provision" effects (an amendment to the amending law before it took effect) count in `changed_by` (C5)? REACH Art 127E: SI 2019/858 substituted SI 2019/758's Sch.2 text before it took effect.

### Decisions for batch 2 (Jason 2026-10-30)

- **Scope:** fold G1–G7, plus V1–V4 and the V11 check. V5–V10 and the U classes stay logged for a later reader batch.
- **Tiers count from round 3**, as the definition of good says: any field of any period. G7 fixes them.
- **C5, an earlier amendment:** a law that amended the amending law before it took effect also made the current text, so it is credited in `changed_by`, but only where the earlier amendment changed text that reaches the row (REACH Art 127E: [SI 2019/758, SI 2019/858]).

### Fix batch 2 (88b87d03): golden from inputs 39/50

**Fold:**
- G1–G7 are done.
- A markup-marked words change with no operation is now a version (V4, done in the fold so that the CV-S08 legacy-Addition ruling stands).
- C5 earlier amendments are credited.
- A whole-provision change reaches its descendants only when a source states its level. This replaces V11: U2's fix did hold; the s.1 copy came from the markup placing CROW's Addition on s.1, with an unstated level (10 such changes in OH&S).

**Readers:**
- V1: staged-removal partial stages are now marked partial.
- V2: a range is never placed on a row inserted after it (latest insertion).
- V3: the feed's CommencingURI becomes a derived `commenced_by`; the evidence table takes it after commencement.

**Catalogue:** 73 examples accepted, adding only `commenced_by`, `earlier_amendment` and the staged-removal `partial`.

**Golden:** TCPA s.284(3)(a) (SI 2009/400) and EUWA s.6 (SI 2023/1363) take the commencing orders the feed names. The 11 failures are the same deferred classes.

**Tests:** 9,555.

**For later:** `readers/feed.ex` is 605 lines (it was 573 before this session); decompose it in the reader batch.

## Round 3 (2026-10-30; seeds S 121, T 122, R 123)

- **Restore point:** tag `cv-s09-batch2`.
- **Rebuild:** OH&S rebuilt, 149 laws, no errors.
- **Golden from the store: 34/50.** The extra failures are laws outside the family with stale stored changes: SI 2012/3038, SI 2016/1105, SI 2017/544, and TCPA s.284(3)(a) and EUWA s.6, whose changes predate V3. Golden from inputs (39/50) stands.
- **Current status:**

  | status | rows |
  |---|---|
  | in force | 19,008 |
  | repealed and saved | 1,022 |
  | repealed | 335 |
  | partly in force | 6 |

- **Draws:** S 86 rows; T 145 rows (4 per class are checked); R 150 rows. 16 agents; tiers are judged from this round.

### Round 3 agent check: FAIL (close)

16 agents, with tiers judged; per-batch notes in the scratchpad (`r3/findings.md`).

**R** (150 rows, seed 123): 2 fold faults in 2 laws.
- HSWA s.34(6): an undated insertion by another law still takes the Act's own commencement.
- NISR 1997/248 reg.2(4)(b)(iv): a repeal keeps the previous `commenced_by` tier.

| round | R fold faults | one-sided 95% upper bound |
|---|---|---|
| round 2 (excl. K8, tiers) | 3/150 | — |
| round 3 (tiers counted) | 2/150 | about 4.1% |

Passing needs 0/150 (1.98%), so round 3 fails. There are no K8 rows in R this time. Upstream faults are about 20 of 150, mostly U10 extent and U12 missing repeals; some rows are U13, U14, U1 and the merge's duplicate commencement.

**S and T:** the fold faults are mostly tiers, plus K8 (6 rows, CLP and REACH), one start bug and one revive input.

**Fold classes for batch 3:**

| # | class | evidence |
|---|---|---|
| H1 | **bug:** `Start.start` takes the earliest later insertion among the row and its ancestors; it must be the latest (the nearest inserted ancestor) | HSWA s.51A(2E)(b), inserted 2005 inside the s.51A of 1998 |
| H2 | an undated whole insertion by another law: the law's own commencements don't reach the row; C14 territory | HSWA s.34(6), Gas Act 1986; about 287 such joins |
| H3 | an undated whole-provision repeal is dropped; it should read repealed (undated) | CLP Art 25(5), EU 286/2011 |
| H4 | tiers: a field is tiered only when its value changes or clears; an empty field has a nil tier; a markup split's territory is derived; a commencement claim "via feed" or "via note" is derived; a parts record is tiered from the stages on its own date | S2, S4, T1, R5, R9 |
| H5 | revive only when the text's valid day is on or after the reviving change (an unrevised body still shows text) | NISR 1993/37 reg.3(1)(d) |
| H6 | an earlier amendment (C5) reaches descendants whatever its level | REACH Art 127A(2) under pt.14A |

**Upstream classes newly evidenced:**
- **M1:** the merge doesn't join the feed's "commenced by the law itself" effect with the commencement reader's record. Tier only, but tiers count now. NISR 2003/34, NISR 1999/305, SI 1992/3004, SI 1997/1713.
- **SF:** "X(1A) substituted for X(1)" and "Art 45(4)-(6) substituted for Art 45(4)": the new numbers are insertions (REACH Art 15(1A), CLP Art 45(5)).
- **V10:** "rev. and replaced" is dropped (SI 1997/2505).
- **Doubtful:** an Act whose own commencement clause is repealed falls back to Royal Assent (1920/65).
- **Education Act 1996 s.583(3):** a carve-out in the Act's own clause.

**Open, doubtful:**
- Credit an undated words-level change on an undated start (REACH Art 118(2)(c))?
- Is NISR 1999/150 (a "Modifications" regulation that is a permanent renaming) rule 9 or a text change?
- The shared pre-split history filters out changes not overlapping the version's own territory.

### Decisions for batch 3 (Jason 2026-10-30)

- **Scope:** fold H1–H6, plus the M1 merge join (the law's own commencement joined with the feed's copy, since tiers count).
- **H7:** on an undated start (C10), an undated words-level change on the row is credited in `changed_by`. On a dated start it stays a gap.
- **NISR 1999/150** ("Modifications", a permanent renaming): rule 9, no version. It joins U14 for the reader batch.

### Fix batch 3 (8196eb87): golden from inputs 39/50

- **Done:** H1–H7 and M1 (the new module `Merge.OwnCommencement`, which joins a feed self-commencement with the reader's record of it).
- **Refactor:** `Label.Undated` is split out of `Label.Start` for module size.
- **Tests:** 9,563.
- **Golden:** 39/50, the same 11 deferred classes.

## Round 4 (2026-10-30; seeds S 131, T 132, R 133)

- **Restore point:** tag `cv-s09-batch3`.
- **Rebuild:** OH&S rebuilt, 149 laws, no errors.
- **Golden from the store: 34/50** (laws outside the family are stale); golden from inputs is 39/50.
- **Current status:**

  | status | rows |
  |---|---|
  | in force | 18,978 |
  | repealed and saved | 1,022 |
  | repealed | 365 |
  | partly in force | 6 |

- **Draws:** S 89 rows, T 150 (4 per class checked), R 150. 16 agents.

### Round 4 agent check: FAIL (close)

16 agents; per-batch notes in the scratchpad (`r4/findings.md`).

**R (150 rows, seed 133): 2 fold faults**, plus 1 K8 row (REACH Art 93(3), omitted for GB on 2020-12-31, in force in NI under C8):
- **I1, tier:** a same-day NI repeal of the whole law tiered the GB row's fields derived (SI 2008/1597 reg.12B(2)(c)).
- **I2, start:** the legacy guard blocked REACH Art 139A's dated 2020 insertion, because its key is M_F_.

Upstream faults are about 15 of 150, mostly U10 and U12, then U14, U1 and U5.

**S, T:** tiers (T-nowhere, C14 undated), version territory after a split under C14, the H2 risk, the same-day repeal/substitution tie, and an undated ancestor substitution.

**Fold classes for batch 4:**

| # | class | evidence |
|---|---|---|
| I1 | tier each field only from the changes that set it; leave out changes whose territory is disjoint from the row's | SI 2008/1597 reg.12A, reg.12B (2027) |
| I2 | narrow the legacy guard to `d…p…` keys (old Acts' pointers, U9), not M_F_ | REACH Art 139A |
| I3 | **H2 risk:** an undated insertion counts (a maker; drops the law's commencements) only when the law text or the feed states its operation, never the markup alone (legacy Additions mark substitutions) | HSWA s.15(1), s.43(6) (EPA 1975 "for subsection (1) substitute") |
| I4 | after a version's split, its territory is the version's own extent (replace, not intersect); C14 narrows only the shared history | HSWA s.28(9)[NI] |
| I5 | tiers: territory set without a stated territory ("nowhere", revival, C14 from an undated insertion) takes the operation tier of the changes setting it | NISR 2007/31 reg.25(3); SI 2022/1378 reg.9(3); HSWA s.15(1) |
| I6 | an undated whole substitution of an ancestor is credited on an undated start | REACH Art 40(1)(a) |
| I7 | a same-day whole repeal and whole substitution, where the revised text shows the substitution: the substitution governs (C5 both) | CLP Art 45(4) |
| I8 | an own-target repeal with an unstated level, on a row still showing text, is a words repeal | SI 2018/816 reg.23(1)(a)(ii) |

**Upstream, new:**
- the amending reader misses gerund verbs ("by substituting", "by deleting"; SI 2002/2174);
- the feed reader loses EU "para. N" and "BIS" (CLP Art 54, Directive 91/383 Art 10a);
- U5 is still live;
- the U9 OSRPA ss.4–16 legacy "insertions";
- a law held only as enacted should be flagged, not labelled in force.

### Decisions for batch 4 (Jason 2026-10-30)

- **Scope:** fold I1–I8, plus two small reader fixes: amending-reader gerunds, and the EU "para. N" / BIS forms in the feed reader.
- **C8:** hold a small Windsor Framework Annex 2 list, checked by Jason.

### Fix batch 4 (e1653920): golden from inputs 41/50

- **Fold:**
  - I1–I8 are done.
  - I3 is split: a markup-only insertion still credits its law (CV-S08 ruling, Forestry s.1(4)(a)), but only a stated insertion drops the law's own commencements (H2).
- **C8:**
  - The new module `ChangeVocabulary.Windsor` lists REACH and CLP with their Annex 2 citations.
  - CLP is at Annex 2, heading 23, indent 11 (a GOV.UK explanatory memorandum, COM(2025) 822). REACH is listed under heading 23, with no indent found yet.
  - Both are `checked: false` until Jason checks them.
  - The UK's changes from 2020-12-31 reach GB only; a GB-only text change narrows the row to E+W+S.
  - REACH Art 140 and CLP Art 2(17) now pass golden.
- **Readers:**
  - the amending reader's gerunds ("by substituting", "by deleting");
  - the feed reader gives the words level to an unheld finer part; "BIS" maps to "a".
- **Catalogues:** 15 feed examples and 3 amendment examples accepted.
- **Tests:** 9,573.
- **Golden 41/50:** the 9 failures are U12 (3), U15 (2), U13 (2), U1 and U10.
- **Note:** the amending-reader change stales `amendment_rules` (ReaderVersion). A rebuild reads stale amending laws from their text, so it is slower; one full `mix lat.amending --read` pass is per the reader-fix-loop rule.
