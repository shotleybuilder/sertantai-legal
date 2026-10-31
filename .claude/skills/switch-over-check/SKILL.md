---
name: Switch-over Check
description: The switch-over's acceptance check (CV-06) for one family. It sorts every provision whose new label (from the merged changes) differs from today's stored label into a cause, draws a seeded sample per cause, and has agents judge each against the law, pooled into a pass bound. Use it before a family's labels switch to the new method.
---

# Switch-over Check (CV-06, per family)

## Purpose

Before a family's labels come from the change vocabulary (`LabelSource.timeline/1`, the fold `ChangeVocabulary.Label` in the timeline's shape `LabelPeriods`) instead of the old register (`LabelProjection` over `lat_change_log`), every difference from today's stored label (`lat_label_timeline`) is explained:

1. sorted into a **cause** by code (`LabelShadow.cause/5`): the first field that differs today (status, in_force_from, territory, changed_by) with the new side's deciding evidence, else the first period that differs in history;
2. **sampled** per cause and judged by an agent against the law;
3. **pooled** into a 95% bound (`mix lat.verdicts`).

All steps are read-only. Ask Jason before the draws (each about 3 min) and before the agents run.

## Steps

1. **Causes:** `mix lat.label_shadow --family "F"` (about 3 min): rows that agree, differ today, differ in history only; the rows per cause.
2. **Draw** (replicable): `mix lat.label_shadow --family "F" --strata --sample DIR --seed N`, twice with one seed into two directories; `diff -r` must show nothing. A new seed per round.
3. **Agents:** one per batch file (`DIR/bK.json`, about 30 rows), with the prompt below. Save each VERDICTS block as `backend/data/reports/change-vocabulary/verdicts/cv06/<family-slug>/round-<R>-seed-<N>-b<K>.json`.
4. **Pool:** `mix lat.verdicts --dir <that directory>` over the files since the last fix.
5. **Fix:** each new-wrong item with fault `own` opens a fix for its cause (batched: one rebuild per round); that cause is drawn again on a new seed.

**Pass (Jason 2026-10-31):** no sampled row of a cause has the new label wrong by its own fault; the pooled 95% upper bound on own-fault rows is under 2%; golden 27/27. Rows on the named known-limit list keep their old label at the switch (Jason: "keep their old label").

**Sample (Jason 2026-10-31):** `--per 15` rows of each cause with at least `--min 50` rows, `--small 30` from the smaller causes pooled.

## Conventions the new labels follow (decided in CV-06)

- A repeal as the table records it: `in_force_from` its day, territory empty (nowhere).
- `changed_by` the law that made the current text, else the law that commenced it; `changed_by_all` every maker, `commenced_by` the commencing law apart.
- A law with no start (EU law, C10): no period before the first dated day (unknown).
- A law made, not yet in force (LR-39): prospective from its making to its start, where its own law commences the provision.

## Agent prompt

Fill in FILE, FAMILY, ROUND, SEED and K.

```
You are checking a legal-data service's switch of provision labels from an old method to a new one (CV-06
acceptance check, family FAMILY). READ-ONLY: do not edit any file, do not fetch from the internet, do not write to
the database, do not run mix tasks. You may read files, run read-only psql SELECTs and decompress local stored XML.
Use /usr/bin/python3 for parsing.

Input: FILE — rows whose new label differs from the old. Each: law, section_id, extent, law_start, cause (the code's
classification of the first difference), old (the stored periods: valid_from, valid_to exclusive, status,
in_force_from, changed_by, territory), new (the new periods, same fields plus changed_by_all and commenced_by) and
changes (the merged changes reaching the row: target, operation, level, date, by, commenced_by, territory, sources).

A label period: status in_force | in_force_partial | prospective | repealed | repealed_saved; in_force_from = when
the current text took effect (empty while prospective or partly in force; on a repeal, the repeal's day); changed_by
= the law that made the current text, else the law that commenced it; territory = where it applies ("E+W"); empty
with a repeal means nowhere. No period = unknown. A law made but not yet in force: prospective from its making to its
start. EU law with no known start: unknown before its first dated change. Today = 2026-10-31.

Sources (the law's text is primary; notes are pointers only, never facts):
- the amended law: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_ukpga_1974_37 → ukpga/1974/37)
  — its text, its commencement clause, extent markup, and its notes (pointers to look further);
- the amending law: the same path for the law in `by` (its body and schedules/data.xml.gz; a repeals Schedule as
  enacted under enacted/schedule/N/);
- the changes feed: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz;
- DB: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc "..." — legal_articles
  (section_id, text, extent_code, markup_status), amendment_annotations (notes), uk_lrt (md_made_date,
  md_enactment_date), commencement_rules, amendment_rules.
- Known limits: backend/data/reports/change-vocabulary/cv-06a-known-limits.md (rows whose repeal is not read: the
  old label stays for them).

For each row: decide what the label should be today and over its history, from the sources. Then judge the NEW
label: ok (right, or right as far as the sources go), wrong, doubtful (you cannot decide: say why), or gap (no
source gives the value). Also say whether the OLD label is right, wrong or unsure. For a wrong new label give the
fault: own (the new method misreads or misses something the sources state), upstream (the sources themselves are
wrong, e.g. legislation.gov.uk's own error), known (a row on the known-limit list, or a limit already logged: name
it). Be rigorous and skeptical: WRONG needs evidence (quote the text or the record); say doubtful rather than guess.

Output: a table, one row per item: n, law, row, cause (short), new ok/wrong/doubtful/gap, old right/wrong/unsure,
note (one line when not ok: the evidence). Then the wrong items grouped by what went wrong. Under 900 words.

Then, after the report (not counted in the word limit), a line VERDICTS and on the lines after it one JSON object:
{"step": "switch", "family": "FAMILY", "stratum": "cause", "seed": SEED, "round": ROUND, "batch": K, "items": [
 {"id": "<law>|<section_id>", "group": "<law>", "verdict": "ok|wrong|doubtful|gap", "fault": "own|upstream|known|null",
  "pattern": "<the row's cause>", "old": "right|wrong|unsure", "note": "<one line>"}]}
One entry per item, in the file's order.
```

## History

- OH&S (first family, 2026-10-31), session `.claude/sessions/change-vocabulary/2026-10-21-cv-06-switch-over.md`. Before the first round: U12 fixed in CV-06a (113 of 152 missing repeals read; 39 a known limit).
