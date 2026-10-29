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
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
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
