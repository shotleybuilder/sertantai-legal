---
session: 'CV-05: Consumers'
status: closed
release: v0.1
opened: '2026-10-21'
started: '2026-10-31'
closed: '2026-10-31'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  The label timeline can now be built from the merged changes beside the old register path:
  LabelSource.timeline/1 folds a law's stored changes into the timeline's row shape (LabelPeriods),
  checked against the table's rules. Pass: golden 27/27, OH&S 28,307 new periods with 0 rule breaks,
  and new-vs-old differences counted (16,487 of 20,371 rows) as CV-06's baseline; the retirement list maps 61 old rules.

decisions:
  - what: Scope restated for today's code; judged on the original 27 golden, the extended 50 no gate
    why: The 2026-10-21 stub predates S01-S11; Jason 2026-10-31 "stick with the passing 27 golden"
    result: CV-00 amended
  - what: changed_by stays one law (the last the fold lists); changed_by_all and commenced_by added beside it
    why: Jason 2026-10-31 "add, don't replace" — compliance keeps reading one law
    result: LabelPeriods carries all three; the columns' migration lands with the writer in CV-06
  - what: Computed, not written; the writer and the source setting move to CV-06
    why: Any edit to the write path (LabelRefresh, LabelTimeline, LabelProjection) stales LabelVersion for every law; CV-06 switches consumers one at a time anyway
    result: old path untouched, LabelVersion unchanged
  - what: The parse's territory columns need no new build
    why: The fold takes territory from the merged changes and never reads excluded_extent or territory_provenance
    result: they stay for the LAT pull (fractalaw), retire from labels with the old path
  - what: No agent hand check
    why: The conversion is a fixed mapping under unit tests; the fold passed its hand check in CV-S09 (R 0/150)
    result: Jason "Go"

metrics:
  golden: { pass: 27, of: 27 }
  ohs_timeline: { periods: 28307, rule_breaks: 0, rows: 20371 }
  ohs_t_differences: { rows_differing: 16487, history_only: 8192, no_today: 2200, current_fields: 6095 }
  retirement_list: { rows: 61, keep: 33, retire: 24, gap: 4 }
  run_time: { label_check_strata: "3m12s", golden: "2m41s" }

lessons:
  - title: The delta sync carries no labels; compliance reads none today
    detail: I told Jason "the existing sync sends it" without checking; Sync.Delta.Config has no lat_label_timeline and compliance's code never reads it. It is V1-00's D2. Check the hand-off path before describing it.
    tag: sync
  - title: A pending stub's scope can be a plan from before the work it depends on
    detail: CV-05's 2026-10-21 todo listed rules CV-S09 had already replaced; restating it against the code first shrank the step to one module and a check.
    tag: tooling

bugs:
  - pattern: "LabelSource.start/1 took any law-level commencement record (no provision_% filter, no order): a provision_unread record could give no start (1900 fallback)"
    category: law start
    module: ChangeVocabulary.LabelSource
    affected: 39
    fix: "Filter effect_type NOT LIKE 'provision\\_%' as LabelTimeline.law_start/1 does (0 OH&S laws affected)"
    status: fixed
  - pattern: "Rows left to a commencement order we don't hold (J6, provision_by_order) fold as in force from the law's start, no gap"
    category: label gap
    module: ChangeVocabulary.Label.Start
    affected: 55
    fix: "CV-06: read the by-order records into the fold (or a gap), measured against the old J6 rows (28,122 rows in 55 laws)"
    status: moved
  - pattern: "Pending and unapplied changes (J4, LR-36) are read by the feed reader but used by no evidence rule or the fold"
    category: label gap
    module: ChangeVocabulary.Label
    affected:
    fix: "CV-06: classify in the shadow diff; a fold rule if the old J4 is right"
    status: moved
  - pattern: "The new source emits no gap list (old: no_start, undated_change, commenced_by_order, pending_change …)"
    category: label gap
    module: ChangeVocabulary.LabelSource
    affected:
    fix: "CV-06: derive gaps from the fold's tiers and undated changes before switching"
    status: moved

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_periods.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/label_source.ex
  - backend/lib/mix/tasks/lat.label_check.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/label_periods_test.exs
  - backend/data/reports/change-vocabulary/cv-05-retirement-list.md

depends_on:
  - change-vocabulary/2026-10-22-cv-s09-label-fold
  - change-vocabulary/2026-10-22-cv-s11-store-build

enables:
  - CV-06 switch-over (writer, setting, shadow diff from the T baseline)
---

# Session: CV-05: Consumers (CLOSED)

## Problem

Compliance reads provision labels (status, in force from, territory, changed by) built the old way: `LabelRefresh` → `ChangeCollector` → `LabelProjection` over `lat_change_log`, with the reconciling rules CV-01 lists. The new way (merged changes in `provision_changes`, folded by `ChangeVocabulary.Label`, CV-S09) passes its checks, but nothing uses it. This step builds the labels the new way, alongside the old, so CV-06 can compare and switch.

Scope restated 2026-10-31 (the 2026-10-21 stub predates S01–S11). Judged on the original 27 golden (Jason 2026-10-31: "stick with the passing 27 golden").

## Todo

- ✅ Map: what the timeline table holds per period, what the fold gives, the gaps between them
- ✅ A new label source beside the old: `LabelSource.timeline/1` → `LabelPeriods` (the timeline's row shape, the table's rules checked); computed, not written. The writer and the setting that picks the source move to CV-06 (its "consumers switched one at a time")
- ✅ The parse's territory brackets and excluded_extent: nothing to build — the new labels take territory from the fold and never read them; they retire with the old path (CV-06)
- ✅ Retirement list: 61 rows, KEEP 33 / RETIRE 24 / GAP 4 (`backend/data/reports/change-vocabulary/cv-05-retirement-list.md`, NAS-backed); nothing deleted until CV-06
- ✅ Check (below): PASS — golden 27/27; OH&S 28,307 new periods, 0 rule breaks; 16,487 of 20,371 rows differ (CV-06's baseline)

## Dependencies

- ✅ CV-S01–S11 passed (S11 closed 2026-10-31)
- ✅ CV-01 signed off by Jason (2026-10-21: "start small, prove, iterate and grow")

## Map (2026-10-31)

| Timeline column | Old (`LabelProjection.Period`) | New (fold → `LabelPeriods`) |
|---|---|---|
| status | five strings | the same five, as atoms → strings |
| in_force_from | date | date |
| changed_by | one law | a list (C5); one law kept for compliance (the last listed), the list in `changed_by_all` |
| — | — | `commenced_by` (the commencing order, CV-S09) |
| territory | extent code; empty + repealed = nowhere | "nowhere" → empty on a repeal; kept otherwise |
| change_ids | lat_change_log evidence | keys of the reaching changes dated on the period's first day |

- **Rows:** the fold covers provision rows only. Headings and signature blocks have old periods and no new ones (1999/3242: 214 of 215; HSWA 1974: 1,028 of 1,035).
- **Decision (Jason 2026-10-31, "add, don't replace"):** compliance keeps one `changed_by`; `changed_by_all` and `commenced_by` are new columns. The migration lands with the writer in CV-06: nothing writes them before then.
- **Correction (2026-10-31):** the delta sync doesn't carry `lat_label_timeline`, and compliance reads no labels today. Carrying them is V1-00's D2.
- **The new path still reads an old table:** the law's start comes from `lat_change_log`'s law-level commencement record (`LabelSource.start/1`). The retirement list tracks it.
- **Store version:** `label_periods.ex` and `label_source.ex` are under `ChangeVocabulary.Version`'s globs, so the stored changes show `code_version` stale until the next build; their content is unchanged (the fold reads them, the build doesn't call these modules).

## Check (defined 2026-10-31, Jason "Go")

Pass:
1. golden 27/27 from inputs (`mix lat.vocabulary --golden`);
2. every OH&S provision's new periods fit the table's rules: 0 violations (`mix lat.label_check --family F --strata`, "timeline rows");
3. new-vs-old differences counted (T classes, same run): the baseline CV-06 explains.

No agent hand check: the conversion is a fixed mapping under unit tests (`label_periods_test`); the fold passed its own in CV-S09 (R 0/150).

## Result (2026-10-31, commit 21af9f4e): PASS

- **Golden:** 27 / 27 from inputs (2m41s).
- **Timeline rows:** OH&S 20,371 provision rows, 28,307 periods, 0 breaking the table's rules (3m12s).
- **New against old (T, rows):** 8,192 differ only in history; 2,200 have no old period; 6,095 differ today in status, in_force_from, changed_by or territory (in_force_from alone 2,136). The baseline CV-06 classifies.
- **Retirement list** (agent draft, code-verified): KEEP 33 (the parse's rule points and reconcilers, still served to fractalaw by the LAT pull; the amending-law and law-level commencement collectors), RETIRE 24 (16 of 19 label rules, the feed and markup collectors, the compensators), GAP 4 (logged as bugs above, for CV-06).
- **The new path still reads old tables:** the law's start (`lat_change_log` law-level record); `mix lat.commencement --orders` picks the Acts whose orders it reads from `lat_change_log` amending-law rows. Both must move before `ChangeCollector` retires.

