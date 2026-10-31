---
session: 'CV-06: Switch-over and Measure'
status: active
release: v0.1
opened: '2026-10-21'
started: '2026-10-31'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
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
- ⬜ Pass rule per cause (bound, sample sizes), agreed with Jason before the first draw
- ✅ U12 first (Jason 2026-10-31): CV-06a closed — 113 of the 152 rows now hold their repeal; 39 a named known limit (`cv-06a-known-limits.md`): how the switch treats them is decided here
- ⬜ The CV-05 gaps, as causes or fixed first: rows left to orders we don't hold (J6), pending and unapplied changes (J4), no gap list, headings and signatures unfolded
- ⬜ Rounds: per cause a seeded sample, agent verdicts pooled (`mix lat.verdicts`), fixes batched, until every cause passes
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

