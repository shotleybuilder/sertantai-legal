---
session: 'CV-S09: Label Fold'
status: active
release: v0.1
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
- ⬜ The golden set is big enough to trust: 27 provisions today; grow to about 50, at least one per S shape, OH&S first; agents draft them, Gemini reviews, Jason signs off
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
