# LAT Change Pipeline: data architecture

Status: DRAFT, 2026-11-03. Facts measured on the dev database (`sertantai_legal_dev`, port 5436) and the working tree on that date. Anything marked **PROPOSED** is not agreed and not built.

The pipeline turns what legislation.gov.uk says about changes to a law into a label for each provision of that law: its status, when its current text came into force, who changed it, and where it applies. It reads three kinds of source:

- the **changes feed** (legislation.gov.uk's list of effects on a law);
- the **CLML change markup** (the brackets and notes in the revised law text);
- the **legal text** of the laws that make the changes: amending laws, commencement orders, and extent and application clauses.

Two paths produce labels today. The **old path** (the "change log" path) labels every family except one. The **new path** (the "change vocabulary" path) labels the OH&S family only. Both write the same label table.

How the numbers were taken:

```bash
PSQL='psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc'   # PGPASSWORD=postgres
$PSQL "SELECT count(*), count(DISTINCT law_name) FROM <table>"
$PSQL "SELECT pg_size_pretty(pg_total_relation_size('<table>'))"
grep -rlE "(INSERT INTO|UPDATE|DELETE FROM) +<table>\b" backend/lib     # writers
grep -rlw "<table>" backend/lib                                          # readers
du -sh backend/data/*   backend/test/fixtures/*
```

---

## (a) The flow

```
 legislation.gov.uk (fetched once, then read offline)
 ├─ changes feed          /changes/affected/<type>/<year>/<num>/data.feed?page=N
 ├─ law text (CLML)       /<type>/<year>/<num>/{body,schedules,section/…}/data.xml
 └─ amending laws, commencement orders (CLML, same layout)
        │  LegislationGovUk.Client → ClmlStore.put/3
        ▼
 FILES  backend/data/cache/clml/                     (193 MB, gitignored, NAS copy)
        ├─ <type>/<year>/<num>/body/data.xml.gz       + data.xml.gz.meta.json (fetched_at, dct_valid, status)
        ├─ <type>/<year>/<num>/schedules/data.xml.gz  + .meta.json
        └─ changes/affected/<type>/<year>/<num>/data.feed.page-N (+ .meta.json)
        │
        ├──────────── the LAT parse (LatStagedParser, the one parse path) ─────────────┐
        │                                                                               ▼
        │                                         legal_articles (376,957 rows, 1,066 laws)
        │                                         amendment_annotations (89,679 notes)
        │
        ├── readers of legal text (mix tasks, one law at a time) ─────────────┐
        │   mix lat.amending --read        → Amendment.ReadPass                ▼
        │   mix lat.commencement --read …  → Commencement.Store     RULE TABLES
        │                                                           amendment_rules     47,019
        │                                                           commencement_rules  45,030
        │                                                           extent_rules         8,789
        │
        ▼
 NEW PATH (one family: config :label_families)          OLD PATH (every other family)
 ChangeVocabulary.Build.law/1                           ChangeCollector.collect/write
   readers (Feed, Markup, AmendingLaw, Own/Amending       collectors (Feed, Markup,
   Commencement, NoteDate, Application, Expiry …)         amending_law, commencement)
   → Merge (by identity) → Evidence (which source wins)    → Compact → fidelity gate
   → ChangeVocabulary.Store.write/3                       → lat_change_log (138,502; 1,066 laws)
   → provision_changes (70,821; 164 laws)                 → LabelTimeline.build
     provision_change_claims (597,791)                       (LabelProjection.timeline/4)
   → LabelSource.timeline → LabelPeriods                         │
   → LabelSwitch.timeline (known limits keep old periods)        │
        │                                                        │
        └──────────── LabelRefresh.run/2 (the one write path) ───┘
                                │  LabelTimeline.write/3, one transaction per law
                                ▼
                lat_label_timeline (625,377 periods, 1,044 laws)
                lat_events: labels_refreshed / labels_failed / changes_built
                                │
                                ▼
                lat_labels_today (view: the period in force on the UK date; 363,747 rows)
                                │
        ┌───────────────────────┼─────────────────────────────┐
        ▼                       ▼                             ▼
 Zenoh LAT pull           mix tasks                     sertantai-compliance
 (Zenoh.DataServer via    lat.timeline, lat.qa_sample,  shares the dev DB, but its code
  LabelsToday: status,    lat.wave_preview,             reads legal_articles, not the
  effective_from,         lat.label_switch,             labels (grep of its backend: no
  changed_by → fractalaw) lat.label_checked …           lat_label*/provision_changes).
                                                        Delta sync to prod carries no labels.
```

Notes on the flow:

- `LabelRefresh.run/2` (`backend/lib/sertantai_legal/scraper/label_refresh.ex`) runs after every parse. For **every** law, including switched ones, it first runs the old path (`ChangeCollector.collect` → `fidelity` → `write`, then `LabelTimeline.build`). Only then, for a switched family, does it call `Build.law/1` and `LabelSwitch.timeline/2`. The new path rides on top of the old one.
- Family membership is a substring match on `uk_lrt.family` (`LabelSwitch.switched?/1`). The stored family name is `💙 OH&S: Occupational / Personal Safety`; the setting is `"OH&S: Occupational / Personal Safety"` (`backend/config/config.exs:20`). 377 laws are in the family; 143 hold labels written by the switch (`code_version = 'c8c643cd'`).

---

## (b) The tables

Row counts and sizes from the commands above (2026-11-03). "Sole writer" is the only file in `backend/lib` with an `INSERT`/`UPDATE`/`DELETE` on the table (or `Repo.insert_all`).

### Rule tables and parse tables (shared by both paths)

| Table | Purpose | Sole writer | Main readers | Key columns | Rows | Size | Ash / SQL | Path |
|---|---|---|---|---|---|---|---|---|
| `legal_articles` (partitioned: `legal_articles_uk` 667 MB) | LAT rows: the text of each provision, its extent, markup status | `LatPersister` (+ `LatPersister.Carry`) via `LatStagedParser`; Zenoh taxa subscribers write taxa columns | Everything: fold (`extent_code`, `position`, `section_type`), `Store.Inputs` fingerprint, Zenoh LAT pull, compliance | `law_name`, `section_id`, `extent_code`, `markup_status`, `excluded_extent` | 376,957 (1,066 laws) | 667 MB | Ash resource exists; pipeline uses raw SQL | Both |
| `amendment_annotations` | Notes (F1, C2 …) from the CLML, with cited law and effect ids | `CommentaryPersister`, `LatPersister.Carry`, `LatArchive` | `ChangeCollector`, new build (`citation_law`, `changed_by` choose which laws' rules to load), delta sync, Zenoh | `law_name`, `code`, `citation_law`, `changed_by`, `effect_ids` | 89,679 | 89 MB | Ash resource; raw SQL in pipeline | Both |
| `amendment_rules` | What each amending provision does: target, operation, level | `Amendment.Store` (from `Amendment.ReadPass`, `mix lat.amending --read`) | `Readers.AmendingLaw`, `Amendment.Collect` (old), `Store.Inputs`, `ChangeStaleness` | `amends`, `targets`, `operation`, `source_law`, `source_ref`, `read_at` | 47,019 | 21 MB | Ash resource (schema only); raw SQL | Both |
| `commencement_rules` | When provisions come into force, from own clauses and orders | `Commencement.Store` (from `mix lat.commencement --read / --orders / --read-orders / --read-amending`) | `Readers.OwnCommencement`, `Readers.AmendingCommencement`, `Store.Inputs` | `commences`, `scope_kind`, `scope`, `when_kind`, `when_date`, `source_law`, `read_at` | 45,030 | 22 MB | Ash resource (schema only); raw SQL | Both |
| `extent_rules` | Where an amending law's changes extend or apply | `AmendingLaw.Extent.Store` (from `Amendment.ReadPass` and `mix lat.amending`) | `ChangeVocabulary.Primary`, `Store.Inputs`, `mix lat.extent_check` | `kind`, `place`, `items`, `source_law`, `source_ref`, `amends`, `read_at` | 8,789 | 3 MB | Ash resource (schema only); raw SQL | New |

### Change records

| Table | Purpose | Sole writer | Main readers | Key columns | Rows | Size | Ash / SQL | Path |
|---|---|---|---|---|---|---|---|---|
| `lat_change_log` | The old "change register": one record per change per run of rows, by collector | `ChangeCollector.write` (only from `LabelRefresh`) | `LabelTimeline`, `LawStart` reports, **`LabelSource.start/1` (new path)**, **`mix lat.commencement` (chooses its Acts)**, `mix lat.vocabulary` (golden) | `law_name`, `section_id`, `collector`, `effect_type`, `effective_from`, `affecting_law` | 138,502 (1,066 laws): feed 120,753 / markup 8,515 / amending_law 6,303 / commencement 2,931 | 106 MB | Ash resource (schema only); raw SQL | Old (new borrows it) |
| `lat_change_log_rows` (view) | Expands compact records to one per row | — | `LabelTimeline` | as above | — | — | SQL view | Old |
| `provision_changes` | The new "change register": one merged change event per provision | `ChangeVocabulary.Store.write/3` (from `Build.law/1`, `mix lat.vocabulary --build`) | `LabelSource`, `Evidence`, `mix lat.stale`, `lat.extent_check`, `lat.commencement_check` | `law_name`, `key`, `target`, `operation`, `date`, `by`, `commenced_by`, `territory`, `sources`, `code_version` | 70,821 (164 laws) | 74 MB | Ash resource (schema only); raw SQL | New |
| `provision_change_claims` | Each source's claim behind a merged change (the evidence) | `ChangeVocabulary.Store` (`Repo.insert_all`) | `Store`, `mix lat.extent_check` | `change_id`, `source`, `attribute`, `value`, `ref` | 597,791 | 209 MB | Ash resource (schema only); raw SQL | New |

### Labels and events

| Table | Purpose | Sole writer | Main readers | Key columns | Rows | Size | Ash / SQL | Path |
|---|---|---|---|---|---|---|---|---|
| `lat_label_timeline` | Label periods per provision: `valid_from`..`valid_to` with status, in force from, changed by, territory | `LabelTimeline.write/3` (only from `LabelRefresh`; enforced by `lat_write_path_test.exs`) | `LabelsToday`, `LabelSource` (stratum T), `LabelShadow`, `LabelSwitch`, `mix lat.timeline` | `law_name`, `section_id`, `valid_from`, `valid_to`, `status`, `in_force_from`, `changed_by`, `commenced_by`, `changed_by_all`, `code_version` | 625,377 (1,044 laws) | 452 MB | Ash resource (schema only); raw SQL | Both (one table) |
| `lat_labels_today` (view) | The period in force on today's UK date | — | `LabelsToday` → Zenoh LAT pull; `mix lat.qa_sample`, `lat.wave_preview`, `LatHash.Query` | `law_name`, `section_id`, `status`, `in_force_from`, `changed_by`, `territory` | 363,747 | — | SQL view | Both |
| `lat_events` | Per-law event log: `parsed`, `labels_refreshed`, `labels_failed`, `changes_built`, `enriched`, `discarded` | `LabelRefresh`, `ChangeVocabulary.Store`, `LatCause.Apply`, `LatEvent.Backfill` | `LabelStaleness`, `ChangeStaleness` (via `Store.builds/0`), `mix lat.stale`, Zenoh | `law_name`, `event`, `at`, `provenance` (jsonb: versions, fingerprints), `parser_version` | 55,217 (labels_refreshed 19,602; changes_built 15,800; parsed 14,439) | 34 MB | Ash resource; raw SQL | Both |
| `lat_changes` | How **our copy** of a law's LAT changed between parses (text changed, inserted, renamed), with cause. Not a legal change | `LatCause.Apply` | `Zenoh.LatChanges` (fractalaw's provision versions), `LatParseLog` | `law_name`, `op_key`, `section_id`, `change`, `cause`, `change_ids` | 133,328 | 30 MB | Ash resource; raw SQL | Neither (parse audit) |

---

## (c) File stores

Sizes from `du -sh` (2026-11-03). `backend/data/` is gitignored (`.gitignore:38 data/`); a few files are force-added. `scripts/nas/nas-backup.sh` copies all of `backend/data/` to the NAS at `project-data/backend-data/` (rsync, incremental).

| Store | Path | Size | What it holds | Git or NAS |
|---|---|---|---|---|
| CLML store | `backend/data/cache/clml/` | 193 MB (12,604 files: 6,224 `.gz`, 6,380 `.meta.json`) | Law text and feed pages by type/year/number (layout in (a)); `ukpga` 78 MB, `uksi` 48 MB, `changes/` 42 MB | NAS only |
| Other caches | `backend/data/cache/{changes-feed, changes-feed-inforce, amendment-index, extent_reads, feed_effects, enabling}` + `amendment-index-2026-10-25.tar.gz` | 216 MB (52 + 52 + 61 + 14 + 13 + 11 + 13) | Older feed caches and read caches (`Extent.ReadCache`, amendment index) | NAS only |
| Reports | `backend/data/reports/` | 958 MB (801 MB of it `lat-refactor/`) | Dry runs, censuses, inventories, retirement list | NAS only, except 11 force-added files (`git ls-files backend/data/reports`) |
| Verdicts | `backend/data/reports/change-vocabulary/verdicts/` | 476 KB | Agent check verdict files (cv06, measures, s11) that `mix lat.verdicts` / `lat.measures` read | NAS only |
| Golden working files | `backend/data/reports/change-vocabulary/golden/` | 440 KB | Golden drafts (`expected-batch*.md`) | NAS only |
| Experiments | `backend/data/experiments/` | 30 MB | Census runs, triage files cited by tests | Git (153 files) and NAS |
| Code reviews | `backend/data/code-reviews/` | 724 KB | Review outputs | Git (25 files) and NAS |
| Test fixtures | `backend/test/fixtures/` | 25 MB (catalogues 24 MB; see TESTING.md) | Pattern catalogues, golden, checked rows, regression list | Git |
| Restore points | NAS `snapshots/restore-points/<date>-<tag>/` | 1.6 GB, 92 points | `pg_dump --data-only` of named tables | NAS only |

Risk: the verdict files that `mix lat.measures` turns into published pass bounds, and the reports that sessions cite as evidence, live only on the laptop and the NAS. They are not in git.

---

## (d) The two paths side by side

| Job | Old path | New path | Duplicate? |
|---|---|---|---|
| Read the feed | `ChangeCollector.Feed` (one record per effect, latest InForce date) | `Readers.Feed` (one change per effect and stage, every claim kept) | Yes |
| Read the markup | `ChangeCollector.Markup` (ChangeIds no effect explains) | `Readers.Markup` (every ChangeId) | Yes |
| Read amending law text | `Amendment.Collect` over `amendment_rules` (`amending_law` collector) | `Readers.AmendingLaw` over the same `amendment_rules` | Yes (same input table) |
| Commencement | `ChangeCollector.Commencement` (law-level record + per-row `provision_*`) | `Readers.OwnCommencement`, `Readers.AmendingCommencement` over `commencement_rules`; **law start still from `lat_change_log`** | Partly |
| Join sources | Fidelity gate and per-row joins (`EffectIndex`) | `Merge` by identity (`Merge.Partner`, `Precise`, `Candidates`) | Yes |
| Decide between sources | Order of precedence inside `LabelProjection` | `Evidence` table (`Evidence.resolve/3`), claims kept | Yes |
| Change record table | `lat_change_log` | `provision_changes` + `provision_change_claims` | Yes: two tables both called "the change register" |
| Fold into periods | `LabelProjection.timeline/4` (1,166 lines) via `LabelTimeline.build` | `ChangeVocabulary.Label` + `LabelSource` + `LabelPeriods` | Yes |
| Gaps reported | `no_start`, `commenced_by_order`, `pending_change`, `outstanding_effect` … (reports only) | None (nil fields; conflicts on `Resolved.conflicts`) | Old only |
| Write labels | `LabelTimeline.write/3` | same | Shared |
| Version stamp | `LabelVersion` → `labels_refreshed` event | `ChangeVocabulary.Version` → `changes_built` event | Two versions |
| Staleness | `LabelStaleness` (`mix lat.stale`, counted by `--strict`) | `ChangeStaleness` and the labels stage's reasons (in `mix lat.stale`, counted by `--strict` since #193) | Two checks |

Size of the old label path: 3,365 lines (`wc -l label_projection.ex label_timeline.ex change_collector.ex change_collector/*.ex law_start.ex effect_facts.ex label_refresh.ex label_staleness.ex label_version.ex`). The new path: 71 files, 11,030 lines under `scraper/change_vocabulary/`.

---

## (e) Retirement plan

Source: `backend/data/reports/change-vocabulary/cv-05-retirement-list.md` (CV-05, 2026-10-31). Its tally over 61 items: **KEEP 33, RETIRE 24, GAP 4**. Most KEEP items are parse code that still writes `legal_articles` columns the Zenoh LAT pull serves (brackets, `excluded_extent`, `territory_provenance`). They stay until a separate "parse switch".

### What the new path still borrows from the old

| # | Borrowed | Where | What replaces it before retirement |
|---|---|---|---|
| 1 | ~~**The law's start**~~ **Done 2026-11-07** | `Build.start/1` (`LawStart.resolve/1` over `LawStart.Input`) stored on the `changes_built` event (`Store.write/4`); `LabelSource.start/1` reads `Store.start/1`; golden calls `Build.start/1` | Done: equal to the old register's for all 285 built laws |
| 2 | **The old labels for known limits**: `LabelSwitch.timeline/2` keeps their periods for `KnownLimits.sids()` | Since 2026-11-07 the stored ones (`LabelSwitch.stored/1`), no longer a rebuild of the old register | Each known limit must be fixed or given an explicit "unknown" label in the new fold |
| 3 | **`amending_law` records**: `mix lat.commencement --orders/--read-orders` pick their Acts and orders from `lat_change_log WHERE collector='amending_law'` | `amending_acts/0`, `cited_orders/0` in `lat.commencement.ex` | Take them from `amendment_rules` / `provision_changes` |
| 4 | ~~`ChangeCollector.law_start_input/2`~~ **Done 2026-11-07** | Moved to `LawStart.Input.of/2`; `ChangeCollector` delegates | Done |
| 5 | ~~The old path always runs first~~ **Done 2026-11-07** | `LabelRefresh.run/2` branches first: a switched law builds and writes from its merged changes only | Done |

### Gaps the new path has (from CV-05)

L4 by-order rows (read as in force from the law's start), L10 and L17 pending or unapplied changes (`:prospective`, `:applied` claimed but not read), no gap list for `lat.timeline` / `wave_preview`, provision rows only (headings, tables and signatures get no labels), a sentinel start `1900-01-01` for an undated law.

### When every family has switched (in order)

1. Replace borrowings 1–5 above.
2. Teach `LabelStaleness` the change register (`:changes_version`, CV-S11 note) and count it in `mix lat.stale --strict`.
3. Delete the RETIRE items: `ChangeCollector` and its collectors (R1, R2, R4b), `Compact` and the `lat_change_log_rows` view, `LabelProjection` (L1–L19), `LabelTimeline.build` and its helpers, `Commencement.Amending` (G1), `Amendment.Evaluator.reach` (G3), `EffectFacts.partial?` (L11), `LabelVersion`.
4. Take a restore point of `lat_change_log`, then drop the table (106 MB), and remove it from `nas-backup.sh`.
5. Remove the `:label_families` setting and `LabelSwitch` (no switch left).
6. Retire the old-path tests (about 178 tests in 8 files: `label_projection_test`, `label_timeline_test`, `law_start*_test`, `change_collector*_test`, `effect_facts_test`); keep `law_start_test` if `LawStart` survives.
7. Rename `provision_changes` docs to be "the change register" and nothing else.

---

## (f) Restore points

### How they are taken today

There are three ways, none registered in one place:

| Way | Where it goes | Made by | Count | Size |
|---|---|---|---|---|
| NAS restore point | `/mnt/nas/sertantai-data/data/snapshots/restore-points/<YYYY-MM-DD>-<tag>/` (`pg_dump --data-only --format=custom` per table, `manifest.json` with rows and sha256) | `./scripts/nas/nas-backup.sh --tables t1,t2 --tag NAME` (before each apply; memory "backup finesse") | 92 (`ls … \| wc -l`) | 1.6 GB (`du -sh`) |
| In-DB snapshot tables (public schema) | `lat_reparse_<tag>` + `<tag>_cm`, `*_snapshot_<date>` | Code: `LatReparse` (`mix lat.reparse`, `live.application`), `live.recompute`, `live.apply_effects`, `live.unapplied_effects`, `EffectsBackfill`, `making.resolve`, `extent.resolve`, `drrp.remap` | 208 (+ orphan `law_change_snapshots` = 209) | 5.2 GB |
| Ad hoc schemas | `r6b.*` (claims1…18, rules10…15, `s06_*`, `ar_before`, `comm13`), `rp9.amendment_rules` | By hand in sessions (CV-S05, CV-S06) to diff a run against the last | 31 | 182 MB |

The `r6b` schema (30 tables, 169 MB) was not in the earlier audit. Both `r6b` and `rp9` hold copies of pipeline tables with no code reference.

### Cleared 2026-11-03

All 240 snapshot tables were archived to the NAS, then dropped with Jason's go. That was 209 in `public` (including `law_change_snapshots`) plus schemas `r6b` (30) and `rp9` (1). The database went from 7.9 GB to 2.6 GB.
- **Archive:** `snapshots/archive/2026-11-03-snapshot-tables.dump` (pg_dump custom format, 844 MB), with the table list beside it.
- **Restore one table:** `pg_restore -d sertantai_legal_dev -t <table> <dump>`.

The tables below are as they stood before the drop.

### The 208 snapshot tables by prefix (before 2026-11-03)

Measured with a `CASE` over `pg_class.relname` in the public schema, `pg_total_relation_size`:

| Prefix | Tables | Size | Dates / tags | Made by |
|---|---|---|---|---|
| `lat_reparse_*` (articles copy) | 61 | 4,044 MB | tags `lr13`…`lr38`, `cr06_restamp`, `cv_s02a`, `wave*`, `unenriched_r01…r09` | `LatReparse` (rollback source) |
| `lat_reparse_*_cm` (control_mappings copy) | 61 | 9 MB | as above | `LatReparse` |
| `*_taxa_snapshot_*` | 9 | 364 MB | 2026-09-25 … 09-29 | live/taxa tasks |
| `lat_status_snapshot_*` | 6 | 201 MB | 2026-10-01 … 10-08 | live tasks |
| other `*_snapshot_*` (making, extent, enabling, drrp68, unapplied_effects) | 9 | 168 MB | 2026-09-25 … 10-01 | `making.resolve`, `extent.resolve`, `live.unapplied_effects` … |
| `*_provision_snapshot_*` | 5 | 135 MB | 2026-09-25 … 09-30 | live/taxa tasks |
| `sort_key_rewrite_*snapshot_*` | 4 | 131 MB | 2026-09-26 … 09-27 | sort-key rewrite |
| `live_status_snapshot_*` | 38 | 111 MB | 2026-09-28 … 09-29 | `live.recompute` |
| `effects_backfill_snapshot_*` | 6 | 35 MB | 2026-09-28 | `EffectsBackfill` |
| `drrp_remap_snapshot_*` | 9 | 7 MB | 2026-09-29 … 09-30 | `drrp.remap` |
| **Total** | **208** | **5,205 MB** | | |

For scale: the whole public schema is 7,743 MB; the snapshots are two thirds of it.

### Policy (PROPOSED; the old tables are cleared, the writers are not yet changed)

Tasks that still create restore tables in `public`: `live.recompute`, `live.apply_effects`, `drrp.remap`, `extent.resolve`. Moving them to the restore schema below is parked on the code-reduction session's list.


1. **One schema.** Every in-DB copy goes into a schema named `restore` (`restore.<tag>__<table>`), never into `public`. Code that makes copies (`LatReparse` and the live tasks) takes the schema from one helper.
2. **A registry.** A table `restore.points` with `tag`, `taken_at`, `session` (session file), `tables`, `rows`, `nas_path`, `dropped_at`. The helper writes it; `nas-backup.sh --tables --tag` writes a row too.
3. **NAS first, then drop.** At session close, each in-DB copy the session made is dumped to the NAS restore point folder (if not already) and dropped. The `session-close` skill lists the session's open points.
4. **One-off clean-up**, with Jason's go: dump the 208 tables, `r6b`, `rp9` and `law_change_snapshots` to the NAS, verify checksums, drop them. Frees about 5.4 GB.
5. **NAS retention.** Restore points older than 90 days and not named in an open session are moved to `archive/`.

---

## (g) Orphans and naming problems

| Item | Problem | Evidence | Proposed |
|---|---|---|---|
| "The change register" | Means `lat_change_log` in old docs and `scraper/CLAUDE.md`, and `provision_changes` in new ones | `ProvisionChange` moduledoc: "The change register of the change vocabulary"; `ChangeCollector`: "Fills the change register `lat_change_log`" | Call `lat_change_log` "the change log (old)"; reserve "change register" for `provision_changes` |
| `lat_changes` | Name suggests legal changes; it is the parse audit of our copy | `Zenoh.LatChanges` moduledoc; `LatChangeLog` moduledoc warns "Not `lat_changes`" | Rename `lat_parse_changes` (needs fractalaw's queryable path kept) |
| `law_change_snapshots` | Orphan: no reference in `backend/lib` or migrations; 3,774 rows all written 2026-09-25 11:15 | `grep -rn law_change_snapshots backend/lib backend/priv` → nothing | Dump to NAS, drop |
| `rp9.amendment_rules` | Ad hoc copy (43,778 rows, CV-S05 diff) | session `cv-s05-extent-reader.md:1064` | Dump, drop |
| `r6b.*` (30 tables) | Ad hoc diff copies, CV-S05/S06 | sessions cite `r6b.claims6` … `r6b.claims18` | Dump, drop |
| Two version stamps | `LabelVersion` and `ChangeVocabulary.Version` for one label | (d) | One after retirement |
| Family setting | Substring match against a name with an emoji prefix | `LabelSwitch.switched?/1` | Match on a family code, not display text |
| `lat_label_timeline.change_ids` | Column doc says "lat_change_log evidence"; switched laws store `provision_changes` keys | CV-05 gap 6 | Fix the column doc; add a `source` column or rely on `code_version` |
| `LabelTimeline.code_version()` | Switched laws are stamped with the old path's version | `label_refresh.ex:38` | Stamp with the path that produced the periods |

---

## (h) Raw SQL and Ash

**Facts.**

- Every pipeline table has an Ash resource in `backend/lib/sertantai_legal/legal/` (`ProvisionChange`, `ProvisionChangeClaim`, `LatChangeLog`, `LatLabelTimeline`, `AmendmentRule`, `CommencementRule`, `ExtentRule`, `LatEvent` …). They define the schema so `mix ash_postgres.generate_migrations` works, and declare a few actions that the pipeline does not call.
- No pipeline code calls Ash. 43 files under `backend/lib` name a pipeline table and use `Repo.query`, `Repo.insert_all` or Ecto queries; none of them call `Ash.read/create/update/destroy`. Only 5 scraper files use Ash at all (`reparse_manager`, `law_parser`, `lat_session_manager`, `persister`, `staged_parser`), for the LRT, not the pipeline.
- The views (`lat_labels_today`, `lat_change_log_rows`, `uk_lrt`) are SQL only.

**Trade-off.**

| | Raw SQL (today) | Ash actions |
|---|---|---|
| Bulk writes (delete + insert per law, 5,000+ claims) | Fast, one transaction, `insert_all` | Bulk actions add overhead; need tuning |
| Reading by intent | SQL strings spread over 43 files; table names greppable | Named actions; one place per table |
| Sole-writer rule | Enforced by grep tests (`lat_write_path_test`) | Can be enforced by action policy |
| Schema drift | Resource and SQL can disagree silently | Compile-time attribute checks |
| Compliance reuse | Compliance must copy SQL | Compliance has its own resources anyway |

**Recommendation (PROPOSED).** Keep raw SQL for the bulk per-law writes and the heavy reads. Do not convert wholesale. Instead: (1) give each table **one** module that owns all its SQL (it mostly exists: `ChangeVocabulary.Store`, `Amendment.Store`, `Commencement.Store`, `Extent.Store`, `LabelTimeline`); (2) move the reads scattered across mix tasks into those modules; (3) add an architecture test per table, like `lat_write_path_test`, that only the owner names the table in a write; (4) say in each Ash resource's moduledoc that it is schema-only and name the owner module.

---

## (i) Staleness and fingerprints

Two staleness checks, both reported by `mix lat.stale` (read-only):

| Check | Module | Reads | Reasons | Counted by `--strict` |
|---|---|---|---|---|
| LAT and labels | `LabelStaleness` | latest `parsed`, `labels_refreshed`, `labels_failed` and `changes_built` events per law, and its family | `no_parse_event`, `parser_version`, `labels_behind_parse`, `labels_version` (old path only), `labels_failed`; a switched law also `fold_version` (folded by other `FoldVersion`), `labels_behind_changes` (the latest build's output digest is not the one folded) and `fold_inputs` (the fold's other inputs moved), all recorded on `labels_refreshed` (#193, #194) | Yes; `--switched` counts only the switched families' laws |
| Change register | `ChangeStaleness` (pure) + `ChangeVocabulary.Store.builds/0` + `Store.Inputs.of/3` + `Store.Inputs.readers/3` | latest `changes_built` event per law | `no_build`, `code_version`, an input moved (`lat_rows`, `law_text`, `feed`, `amendment_rules`, `commencement_rules`, `extent_rules`), or readings it read made by other reader code (`commencement_reader`, `extent_reader`: `reader_version` on `commencement_rules` / `extent_rules`, `Commencement.ReadVersion` / `Extent.ReadVersion`) | Yes (#193) |

**Readings carry their reader's version** (#193). The build reads stored readings, never the readers, so before #193 a reader fix that was never re-run left every rebuild looking current. Each commencement and extent rule now carries `reader_version`. NULL means it was read before the version was recorded, and counts as stale. An extent re-read that comes out the same updates only the stamp, so it needs no rebuild. Amendment readings need no stamp: the build reads a stale amending law from its text (`Primary.primary/2`). A version's file list recompiles when a file is added under its patterns (`SourceVersion.__mix_recompile__?/0`, `fresh?/0`).

What a `changes_built` event records (`lat_events.provenance`): `claims` count, and `inputs` with content digests of the LAT rows, the law text and the feed (`ClmlStore.feed_files/3`), the latest `read_at` of each rules table it read, and the lists of affecting and commencing laws, so `lat.stale` can fingerprint the rules again without a build (about 2 s for 168 laws, CV-S11). An input the build didn't record counts as moved.

Measured (CV-S11, 2026-10-31): two builds of 168 laws gave identical digests (`mix lat.changes_digest`); 0 of 168 stale after the build; 898 laws hold LAT but have no build. Today 168 laws have a `changes_built` event and 164 hold rows in `provision_changes`.

**Two stages, each stale on its own code and inputs** (#194):

- **The changes stage** is the readers, merge and evidence, stored in `provision_changes`. Its version is `ChangeVocabulary.Version`: exactly the files a build reaches.
- **The labels stage** is the fold, stored in `lat_label_timeline` for a switched law. Its version is `FoldVersion`: exactly the files the timeline path reaches (`LabelSwitch` → `LabelSource` → `Fold` → `Label`), stopping at the stores.
- `StageSplitTest` holds both lists exact. A file both stages reach, such as `Readers.Markup` or `Territory`, is in both, so editing it stales both stages.
- Each `changes_built` event records `changes_digest`: the stored changes and the law's start (`ChangeDigest.build/2`), read back in the write's transaction.
- Each switched `labels_refreshed` event records three things:
  - `fold_version`;
  - the `changes_digest` it folded;
  - `fold_inputs` (`FoldInputs`: the rows as the fold reads them, the made date and title, the CLML body's text and the known-limit rows).
- So a fold-only edit stales labels only and rebuilds no change. A rebuild that gives the same output stales no label.
- `mix lat.vocabulary --build --stale` walks the stages in order (`StaleStages`):
  - it rebuilds the stale changes;
  - it then reads the label staleness again;
  - it folds labels again from the stored changes (`LabelRefresh.refold/1`), refreshes laws parsed since, and lists any law whose parse is stale.
- Measured 2026-11-08, right after the split:
  - 285 laws were rebuilt in 198 s, and 266 labels were re-folded in 95 s;
  - all 285 change digests and all 1,145 timelines were byte-equal;
  - golden stayed at 26/27, and `lat.stale --strict --switched` gave 0.
