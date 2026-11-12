---
name: Switch-over Check
description: The switch-over's acceptance check for one family, decided by code. Every provision whose new label (from the merged changes) differs from today's stored label is sorted into a cause; the rules run over every row; the checked rows and golden are compared; then a dry run, Jason's go, a restore point and the apply. Use it before a family's labels switch to the new method.
---

> **LAT Change Pipeline — step: Switch-over.** Where it sits, its inputs, outputs and pass rule: `docs/lat-change-pipeline/WORKFLOW.md`. Terms: `docs/lat-change-pipeline/GLOSSARY.md`.
>
> **Process (retrospective, 2026-11-03):**
> - Plan the step in plan mode first, with its pass rule fixed and golden frozen (`session-start`, step session).
> - The pass is decided by code: causes, the rules over every row, the checked rows, golden and the dry run.
> - An agent pass is used only where a large cause names no evidence for its new value, at most 2 batches, with its tokens recorded. One pass at most, never sample → fix → resample.
> - Bugs in another step's code are raised with `bug-raise` and parked, unless Jason gives leave for that bug.

# Switch-over Check (per family)

## Purpose

Before a family's labels come from the change vocabulary (`LabelSource.timeline/1`, the fold in the timeline's shape, `LabelPeriods`) instead of the old register, every difference from today's stored label (`lat_label_timeline`) is explained. The family's timeline is then written by `LabelRefresh`.

## Steps

All are read-only until the apply. Ask Jason before the long runs, which take about 12 minutes each on Maritime Safety.

1. **Causes:** `mix lat.label_shadow --family "F"`. This gives the rows that agree, differ today and differ in history only, and the rows per cause (the first field that differs, with the new side's deciding evidence). Save the output to `backend/data/reports/switch-over/<family>-shadow.txt`.
2. **Look at the causes that name no evidence.** A cause like "in force later (none dated)" has no change behind its new value.
   - Draw 12 rows of it: `--cause "<cause>" --sample FILE --n 12 --seed N`.
   - Read them by hand: the changes reaching each row, the stored changes, then the feed or text they came from.
   - A class over the plan's size (100 rows) goes to Jason as a decision.
   - Maritime Safety's was the feed reader taking "s. 130A-130E (Pt. 6) (Ch. 1A)" as the whole of Part VI. It was fixed with leave (Decision 2, B).
3. **Checked rows early:** run `mix lat.label_checked --list` before any fix too. A changed row from an earlier step's regression (for example, commencement re-reads) is then known before this step's fixes run (Environmental Protection, 2026-11-12: 22 rows from the 2026-11-10 re-reads).
   **Rules:** `mix lat.label_rules --family "F"`, then `--list RULE` for each rule breached. Every breach is fixed by its owning step, or, when its class is below the triage size, named as a known limit.
   - Known limits are table files read by `KnownLimits` (section_id first). For Maritime Safety: `backend/data/reports/switch-over/maritime-safety-known-limits.md`.
   - A known-limit row keeps its old label at the switch.
   - `known_limits.ex` is in the build's version, so adding a file needs a staleness rebuild.
4. **Checked rows:** `mix lat.label_checked --list`. Every row should match, apart from known and upstream rows.
   - A row changed by a decided rule is accepted with the rule as the why: `--accept "LAW|SID,…" --why "…"`. Review the fixture's diff.
   - A row changed by another step's fault is parked with that step and left as changed.
   - To see what changed in each row, diff its periods field by field.
5. **Golden:** `mix lat.vocabulary --golden`, 27/27, after any rebuild.
6. **Dry run:** `mix lat.label_switch --family "F"`. Every law should fold, with none breaking the table's rules.
   - It writes its per-law lines to `data/reports/change-vocabulary/cv-06-dry-run.csv`, which is OH&S's file. Move the family's copy to `switch-over/` and restore OH&S's from git.
7. **Jason's go**, then:
   - a restore point: `./scripts/nas/nas-backup.sh --tables lat_label_timeline,lat_change_log,provision_changes,provision_change_claims,lat_events --tag <tag>`;
   - the family added to `config :sertantai_legal, :label_families`, by its exact name without the `💙 ` marker (`LabelSwitch.family_in?/2`);
   - `mix lat.label_switch --family "F" --apply`.
8. **After the apply:** `mix lat.label_switch --family "F" --stored` compares the stored timeline with the switch's, law by law, on every field the switch writes (`changed_by_all` and `commenced_by` too). Every law written should show 0 rows differing. `--strata` can't show this, because it compares the fold's own periods: a repeal's day and empty territory, the commencer as `changed_by`, and no unknown EU period always differ from them. Also run `mix lat.stale --strict --switched` (0) and look for laws the apply failed: a failed law keeps its old labels. A family switched for the first time can show parser-stale laws that weren't counted before. Text-diff them offline and re-parse them from the store (RULES `family-re-parses-its-parser-stale-laws`).

**Pass:**
- causes saved;
- the rules show 0 breaches outside the named known limits;
- the checked rows match (known, upstream, and other families' parked regressions apart);
- golden 27/27;
- the dry run folds every law with 0 rule breaks;
- after the apply, the stored timeline equals the switch's, every law it wrote.

## Conventions the new labels follow

- A repeal as the table records it: `in_force_from` its day, territory empty (nowhere).
- `changed_by` is the law that made the current text, else the law that commenced it. Where several made it, it is the principal maker, then the latest made (RULES `changed-by-one-law-for-compliance`). `changed_by_all` holds every maker, and `commenced_by` the commencing law.
- A law with no start (EU law): no period before the first dated day (unknown).
- A law made, not yet in force: prospective from its making to its start, where its own law commences the provision.

## History

- **OH&S** (first family, 2026-10-31 to 11-02): per-cause agent samples and a pooled bound, replaced on 2026-11-01 by the code-decided pass. 696 checked rows, 47 known, 1 upstream. Session: `.claude/sessions/change-vocabulary/2026-10-21-cv-06-switch-over.md`.
- **Maritime Safety** (2026-11-06/07): no agent pass. A hand look at two causes found the feed reader's Part VI fault (773 rows), fixed with leave. 8 rows were named as known limits. The OH&S checked rows found 51 `changed_by` rows that followed Decision 1, and a parked repeals-table regression (Mines Regulations 2014 on HSWA). Session: `.claude/sessions/lat-change-pipeline/2026-11-06-maritime-safety-switch-over.md`.
- **Environmental Protection** (2026-11-12): no agent pass.
  - **The territory class.** 7,736 rows differ on territory alone, all explained by one rule (`devolved-law-applies-in-its-territory`).
  - **Fixed in-step with leave:**
    - Welsh SIs under their UK names (`no_made_period`, 440 rows; Label fold);
    - an amending provision commenced territory by territory (EPA 1990 Part IIA in force from 1995; Amending-law reader, Decision 3 B).
  - **Two regressions the fix had, both caught by the checks:**
    - golden caught a one-territory order dating a Welsh Act's change;
    - the checked rows caught the stage outranking the feed's dates.
  - **Known limits:** 15 rows.
  - **Parked:** 22 checked rows from earlier steps.
  - **The apply:** 122 of 122 written; `--stored` shows 0 differing.
  - **After it:** 59 parser-stale laws re-parsed, with 0 rows changed.
  - Session: `.claude/sessions/lat-change-pipeline/2026-11-12-environmental-protection-switch-over.md`.
