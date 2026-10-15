---
session: 'LR-25: Change Log Switch-over'
status: closed
opened: 2026-10-13
closed: 2026-10-15
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  -legal switched to one label source: the change register and its timeline. The parse writes only markup_status, a hook rebuilds each law's register and timeline after every parse, staleness is visible (parser / labels versions, refresh events), and every note-fact path and the old label columns are gone.
  The wave (2026-10-15) re-parsed all 1,066 laws from the store after five rolled-back dry runs that found and fixed LR-29, LR-30, LR-32, a memory leak, a heading-join mistake and two tie-break faults; all 39,638 predicted label changes match the live data, with 0 stale laws.

decisions:
  - what: "Inside -legal only; the delta sync and fractalaw's pull move to D2 (LH-05)"
    why: "Jason: 'We're not close to fractalaw handoff yet'"
    result: "nothing synced or served; contract notes written in LH-05, not sent"
  - what: "D1 remove the parse-time label columns (status, effective_from, changed_by, change_provenance); markup_status for J2"
    why: "nothing goes outward before D2, so freezing bought nothing; status as a label is the timeline's"
    result: "migration dropped them; the lat view recreated; the backup taken first"
  - what: "D2 drop the notes' fact columns (effect, effective_dates, effective_from, fact_provenance)"
    why: "Jason: 'we use leg.gov.uk notes as helpers/pointers not as data we need to store. The data comes from law or effects'"
    result: "NotePointer (law, change_id, same_law?) replaces AmendmentNote; the note-read guard fails on any fact read from note text"
  - what: "Status of fractalaw: it derives status from the timeline and retires unapplied_repealed when it ships"
    why: "Jason 2026-10-14; the liveness gate (#73) and status_hash read status"
    result: "recorded in LH-05"
  - what: "Dry run = the real path in a rolled-back transaction (mix lat.wave_preview)"
    why: "the dry run and the apply can't diverge"
    result: "five full dry runs; each surfaced a real fault before any write"
  - what: "Approve and run the wave (Jason 2026-10-15: 'Do steps 1 to 4')"
    why: "final dry run 2 clean; every change class verified or traced"
    result: "1,066 laws, 0 errors; enrichment 287,676 → 287,676; 0 stale; gaps and labels equal to the dry run"

metrics:
  wave: { laws: 1066, errors: 0, rows: 374866, enriched_kept: 287676, renamed: 0, dropped: 0, label_changes_today: 39638, laws_changed: 240, predicted_vs_live_differences: 0 }
  timeline: { periods_before: 506466, periods_after: 479108, unknown_today_before: 30201, unknown_today_after: 31984 }
  gaps_after: { no_start: 21941, insertion_not_in_register: 9576, undated_change: 16506, markup_conflict: 8163, outstanding_effect: 1526 }
  register: { records_before: 141390, records_after: 134457 }
  tests: { before: 2632, after: 2678 }

lessons:
  - title: "A dry run that runs the real path in a rolled-back transaction is worth its cost"
    detail: "Five full rolled-back runs each found something a unit test couldn't: LR-27's over-reach hidden in the stored data, a heading join mistake, same-day ties flipping labels run to run, a tie-break that named the commencement order. The live result then matched the last dry run on every one of 39,638 changes."
    tag: data
  - title: "Comparing a fresh run against stored data hides faults present in both"
    detail: "Dry run 1 showed 1,227 changes; LR-27's over-reach was in the stored register and in the fresh collect alike, so it matched itself. Only after LR-29 corrected the fresh side did 33,000 wrong labels show."
    tag: data
  - title: "Verify each change class row by row, not by sample alone"
    detail: "A per-row check (does the change behind the old label still reach the row under the new code?) confirmed 95%+ of changed_by changes and every status class, and its exceptions found the heading-join gap and LR-30."
    tag: data
  - title: "Ties need an explicit, meaningful order"
    detail: "Enum.max_by on a date returned whichever same-day change came first from an unordered query, so labels flipped between runs; ordering by law name then named the commencement order. Rank the change itself before its commencement, then a stable key."
    tag: data
  - title: "A per-process cache in a pure-looking module leaks in a corpus run"
    detail: "The LR-08 amending-law collector kept every parsed xmerl document in the process dictionary and an ETS table per call: ~130 MB per law in one process; the dry run was killed after 460 laws. Scope caches to the unit of work."
    tag: tooling
  - title: "Backups must cover what the run writes"
    detail: "nas-backup.sh predated the change register: lat_change_log, lat_label_timeline, lat_events, lat_changes and lat_section_id_renames were added before the wave."
    tag: infrastructure

bugs:
  - pattern: "Amending-law collector caches leak across laws in one process: amending_doc keeps every parsed xmerl document in the process dictionary for the process's life; memo/1 creates an ETS table per call and never deletes it"
    category: memory
    module: ChangeCollector.amending_doc / ChangeCollector.AmendingLaw.memo (LR-08)
    affected: "~130 MB per law; the wave dry run was killed for low memory after 460 of 1,066 laws; the apply (one process, hook per law) would have hit it too"
    fix: "ChangeCollector.with_doc_cache/1 scopes the doc cache to one law's collection (cleared in after); records/7 deletes its memo tables in after. Measured flat (~190 MB over 30 laws)"
    status: fixed
  - pattern: "Step 7 regression: a note's changed_by pointer came only from its text, so a bare citation note ('1996 NI 17') pointed to no law and T1 marked its row 'date unknown' though the register dates it (141 rows lost a date in the dry run)"
    category: lat-change-facts
    module: CommentaryParser.with_effects/3 / CommentaryPersister (LR-25 step 7)
    affected: "141 rows in the LR-25 dry run (apni 1970/10 s.1(4A), mwa 2010/8 s.9(3), ...)"
    fix: "the pointer is the joined effect's affecting law (the latest dated: data from effects), else the law the text names — as before step 7, without note facts"
    status: fixed
  - pattern: "Row change facts pool note facts with effect facts and take the latest date, so a note can override an effect on the same row"
    category: lat-change-facts
    module: scraper/change_facts.ex
    affected: "deleted"
    fix: "ChangeFacts.row_facts deleted; labels from the timeline"
    status: fixed
  - pattern: "Provenance mislabelled or missing for note-derived values"
    category: lat-change-facts
    module: scraper/change_facts.ex / LatStatus.Apply
    affected: "deleted"
    fix: "note-derived values removed with their columns"
    status: fixed
  - pattern: "LAT facts derived from legislation.gov.uk note text alone where no markup or effect supports them"
    category: lat-change-facts
    module: AmendmentNote / LatStatus / ChangeFacts
    affected: "deleted"
    fix: "every note-fact path deleted; note-read guard test"
    status: fixed
  - pattern: "changed_by null when the note cites a bare SI number"
    category: lat-change-facts
    module: AmendmentNote / ChangeFacts note fallback
    affected: "superseded"
    fix: "no facts from notes; changed_by from the register (effects, law)"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/label_refresh.ex
  - backend/lib/sertantai_legal/scraper/labels_today.ex
  - backend/lib/sertantai_legal/scraper/label_staleness.ex
  - backend/lib/sertantai_legal/scraper/source_version.ex
  - backend/lib/sertantai_legal/scraper/parser_version.ex
  - backend/lib/sertantai_legal/scraper/label_version.ex
  - backend/lib/sertantai_legal/scraper/note_pointer.ex
  - backend/lib/sertantai_legal/scraper/effect_facts.ex
  - backend/lib/sertantai_legal/scraper/wave_preview.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/lib/mix/tasks/lat.relabel.ex
  - backend/lib/mix/tasks/lat.wave_preview.ex
  - backend/test/sertantai_legal/architecture/note_read_test.exs
  - backend/priv/repo/migrations/20261015054800_lr25_drop_label_and_note_fact_columns.exs
  - backend/priv/repo/migrations/20261015060000_add_lat_labels_today_view.exs
  - scripts/nas/nas-backup.sh
  - backend/data/reports/lat-reparse/lr25_wave.csv
  - backend/data/backups/lr25/

depends_on:
  - 2026-10-13-lr-24-label-projection
  - 2026-10-13-lr-26-territory-from-register
  - 2026-10-14-lr-28-one-lat-parse-path
  - 2026-10-15-lr-29-container-ref-overreach

enables:
  - A8 timeline gap classes
  - LR-31 pipeline performance
  - D2 LH-05 (sync carries the timeline; fractalaw derives status from it)
---

# Session: LR-25 Change Log Switch-over (CLOSED)

## Problem

The register (`lat_change_log`, LR-23/LR-08) and the timeline (`lat_label_timeline`, LR-24/LR-26/LR-27) now answer where and when for each provision, but the LAT parse still computes its own change labels on `legal_articles` (status, effective_from, changed_by, change_provenance), partly from note text, and nothing rebuilds the register and timeline when a law is re-parsed. This session switches -legal over inside -legal: one source of labels, kept fresh after each parse, and the note-fact code deleted (absorbs LR-21).

**Re-scoped 2026-10-14 (Jason: "We're not close to fractalaw handoff yet").** Nothing that reaches compliance or fractalaw happens here. The delta sync change (stop exporting `lat.status` / `effective_from` / `changed_by`, carry the timeline) and fractalaw's pull from the timeline (labels hash in the manifest) move to D2 (LH-05), after QA run 4.

## Suspended (2026-10-15)

Steps 1–8 are built and committed, and dry run 1 is classified. The wave (step 9) waits for LR-29 (container ref over-reach): applying now would write that regression. Resume with a fresh dry run once LR-29 is fixed.

## Todo

- ✅ Re-scoped to inside -legal; meta plan updated (2026-10-14)
- ✅ Inventory: every writer and reader of the `legal_articles` label columns; parse entry points; note-fact paths still called
- ✅ **Jason: D1** — remove (2026-10-14)
- ✅ Note-read guard test (D4, approved; step 1, 2026-10-14): `test/sertantai_legal/architecture/note_read_test.exs`. Fact calls (`AmendmentNote.parse/row_effective/resolve_law`, `LatStatus.resolve`, `NoteTerritory`) must appear nowhere but a ratchet `@to_delete` list (8 entries; must shrink to empty in step 7). SQL readers of note text are allow-listed with reasons: pointer (LabelTimeline J5, ChangeCollector), display (qa_sample, ai_sync, admin LAT page), to_delete (LatStatus.Apply)
- ✅ Step 2 (2026-10-15), parser version:
  - `ParserVersion.current/0` is a compile-time 12-hex hash of the parse's source files (21 patterns: `lat_parser/**`, `LatStagedParser`, scope, territory, effect index, changes feed, `CommentaryParser`, `Transforms`, PDF transcript CLML, ...) and `mix.lock`. It is curated, not the full alias closure, which reaches the whole Ash domain through `Api`.
  - `lat_events.parser_version` is an Ash attribute with a generated migration. The `lat_events_on_insert` trigger fills it from `sertantai.lat.parser_version`, which `LatPersister` sets (hand migration; down restores the old function).
  - Tests: `parser_version_test.exs` (3) and `lat_event_test.exs` ("a parsed event records the parser version").
- ✅ Step 3 (2026-10-15), `markup_status`:
  - `legal_articles.markup_status` is written by the parse only (`Rows.assign_status`: the same reading as the parse's `status`) and appended to the `lat` view, which `LatPersister` inserts through. It is not a `Lat` attribute, so it is never synced or served.
  - The migration is Ash-generated, with the view edit as in LR-13. Up, down and up were tested.
  - J2 reads it through `LabelTimeline.j2_markup/1` (repealed / prospective only), not `status` + `change_provenance`.
  - Guard `require_markup!/2`: no timeline is built from rows parsed before LR-25. All 374,866 rows are null until the wave, so `mix lat.timeline` refuses until then.
  - **Behaviour change for the wave dry run:** J2 now sees the markup reading even where an effect set `status` (before, only where `change_provenance.status = markup`). This is the approved J2 rule ("markup wins today"), to be classified.
  - **The step-3 gate moves to step 9:** the dry run builds each law's timeline from its fresh in-memory parse (`LabelTimeline.build` gains a rows option), as the collector already reads the store.
- ✅ Step 6 (2026-10-15), readers off the label columns:
  - **6.1 (`7c5cab41`):**
    - The view `lat_labels_today` (the timeline period in force on the UK date, computed in Postgres with Europe/London; agrees with `uk_today`) and `LabelsToday` (`for_law/1`, `put/2`).
    - The Zenoh LAT pull serves `status` / `effective_from` (= `in_force_from`) / `changed_by` from it. A row with no period today serves nils (unknown). The contract shape is unchanged.
    - `status_hash` (Elixir and manifest SQL) runs over today's timeline status, with unknown hashed as "", as fractalaw's own `status_hash` does. It is never nil now; that goes in the D2 contract note.
  - **6.2:**
    - `LatCause` / `LatParseLog` status changes come from `markup_status`. A first reading (null before) is never a change, so the wave doesn't mark every row "status_changed".
    - `mix lat.qa_sample` stratifies and shows rows by today's timeline labels (status, effective_from, changed_by, territory). The `placed_notes` stratum becomes `dated_change`. Notes are shown as notes (text, placement, `citation_law`), with no note facts. Smoke run: 16 packets.
    - `mix lat.change_diff` (LR-07) and `parse_snapshot`'s change-fact part go in step 7, with `ChangeFacts`.
  - Suite green.
- ✅ Step 7 (2026-10-15), note-fact code deleted:
  - **Deleted:**
    - `AmendmentNote` (effect, dates, `row_effective`, `resolve_law`);
    - `LatStatus.Apply` (refresh, note fact writes) and `mix lat.status`;
    - `ChangeFacts.note/resolve/row_facts/holders/saved?`;
    - `LatStatus.resolve` and its note regexes;
    - `NoteTerritory` and `LatTerritoryCheck`'s note hint;
    - `mix lat.change_diff`;
    - the change-fact part of `parse_snapshot`.
  - **Kept:**
    - `NotePointer` (`law/2`, `change_id/2`, `same_law?/2`; pointer tests ported unchanged, 12);
    - `EffectFacts` (was `ChangeFacts`: `kind`, `effect_fact`, `partial?`);
    - `LatStatus` (structural helpers only).
  - `CommentaryPersister` stores each note's `changed_by` (pointer) and `change_id` at parse, with no refresh. The behaviour-preserving test passed before and after.
  - `LatCause` / `LatParseLog` read the stored `change_id`.
  - The Zenoh note pull serves text, placement, `changed_by` and `change_id`, not `effect` / `effective_dates` / `effective_from`.
  - **Guard:**
    - the ratchet list is empty;
    - the SQL scan now also covers one-line strings (it missed `LatCause`'s query; that query is allow-listed as a pointer: renumbering pairs for our copy's change log);
    - checked by removing the entry, which fails the test.
  - The scraper's CLAUDE.md is rewritten (labels are the timeline's; notes are pointers).
  - Suite 2,630 (the note-fact tests are gone).
- ✅ Step 4 (2026-10-15), parse hook:
  - `LabelRefresh.run/2` runs collect → fidelity gate → register write → timeline build → timeline write.
  - `LatStagedParser.persist_stages` calls it after the rows, notes and cause, passing what it just persisted (`ChangeCollector.collect(parsed:)`), so nothing is parsed twice.
  - The result carries `labels: :ok | {:error, _} | :skipped`; `labels: false` skips it.
  - A failure doesn't fail the parse. It is recorded as a `labels_failed` lat_event with the reason.
  - `LatArchive.discard` deletes the law's register and timeline rows in its transaction.
  - `LabelTimeline.code_version/0` moved out of `mix lat.timeline`.
  - Tests: hook (rebuilds; skip), failure event, archive cleanup. Suite 2,692.
- ✅ Step 5 (2026-10-15), staleness:
  - **Versions:** `SourceVersion` (shared compile-time file hash), with `ParserVersion` moved onto it and a new `LabelVersion` (collectors, amending-law readers, projection, refresh, `mix.lock`).
  - **Events:** `LabelRefresh` records `labels_refreshed` (provenance: `labels_version`, records, periods) or `labels_failed`. They are used instead of `collected_at` / `built_at`, because ~200 laws have no register records and laws with no start have no periods, so the tables can't show that a law was refreshed.
  - **Rules:** `LabelStaleness.reasons/2` (pure, 6 tests) gives `no_parse_event`, `parser_version`, `labels_behind_parse`, `labels_version`, `labels_failed`.
  - **`mix lat.stale`** (`--list`, `--strict`). Today: **1,066 stale** (all `parser_version` + `labels_behind_parse`), as expected before the wave.
  - **One writer:** `mix lat.collect_changes` and `mix lat.timeline` are report-only (`--apply` removed). The new **`mix lat.relabel`** (`--laws`, `--stale`, `--all`; resumable) rebuilds through `LabelRefresh`, for label-code changes with no re-parse.
  - **Guard:** `lat_write_path_test.exs` now also asserts that only `LabelRefresh` writes the register and timeline.
  - Suite 2,703.
- ✅ Step 8 (2026-10-15), columns dropped:
  - **Dropped from `legal_articles`:** `status`, `effective_from`, `changed_by`, `change_provenance` (with `legal_articles_status_check`).
  - **Dropped from `amendment_annotations`:** `effect`, `effective_dates`, `effective_from`, `fact_provenance`.
  - **The `lat` view** is recreated without the dropped columns.
  - **Kept:** notes' `changed_by` (the pointer) and `change_id`; `legal_articles.markup_status`.
  - **Migration:** Ash-generated, edited for the view as in LR-13. Up, down and up were tested on the test DB with `--to`; down restores the view columns and the check.
  - **Backup before the drop:** `backend/data/backups/lr25/legal_articles_labels.csv.gz` (374,866 rows) and `amendment_annotations_facts.csv.gz` (89,679).
  - **Resources:** `LegalArticle`, `Lat` and `AmendmentAnnotation` lose the attributes, so the delta sync code no longer carries them. Nothing is synced until D2.
  - **The parse** writes `markup_status` only.
  - **`mix lat.timeline`** now diffs a fresh build against the stored timeline as at today, not against the old columns.
  - Suite 2,629.
- ✅ Step 9a (2026-10-15), wave dry-run tool `mix lat.wave_preview`:
  - **How it works:** the real apply path (`LatStagedParser.parse` from the store → persist → notes → cause → LR-25 hook) runs per law inside a transaction that is always rolled back. Zenoh is off in mix tasks.
  - **What it compares:** `WavePreview` (pure, 3 tests) compares before and after, i.e. labels as at today (status, effective_from, changed_by, territory) and the parse-time columns.
  - **Pilot** (HSWA, uksi 2023/909, anaw 2016/3, 87 s): event / timeline / register / `markup_status` counts were identical after, so nothing persisted.
    - HSWA: 4 dotted-out provisions (s.75, s.78(3), (4), (8)(d)) go in_force → repealed. The old J2 ignored markup wherever an effect had set the status; this is the approved rule.
    - 2023/909: territory E+W → E for 267 rows (the `excluded_extent` drift).
    - anaw 2016/3: E+W → W for 28.
- ✅ Step 9b (2026-10-15), memory leak found and fixed:
  - **What happened:** the dry run was stopped by Claude Code for low system memory after 460 laws. The database was untouched (rolled back).
  - **Not the disk** (33 GB free), and **not Postgres** (174 MB container).
  - **Cause:** the LR-08 amending-law collector cached every parsed amending-law document (xmerl trees) in the process dictionary, and created an ETS table per call that it never deleted. Measured at about 130 MB per law (5.2 GB after 40 laws, 660 cached documents).
  - **Fix:** the document cache is scoped to one law's collection (`with_doc_cache/1`), and memo tables are deleted after each call. Tests first.
  - **Re-measured:** flat at about 190 MB over 30 laws, about 11.6 s per law (previously about 15 s).
- ✅ Step 9c (2026-10-15), dry run 1 complete (`lr25_dry`):
  - **Run:** 1,066 laws. Labels hook `ok` on all 1,066, 0 errors, cause `parser` on every one. The DB is unchanged after.
  - **Changes as at today:** 1,227 label diffs in 67 laws.
  - **Correct:**
    - 277 in_force → repealed and 5 partial → repealed: every one has dotted or [Repealed] text (J2 now reads `markup_status`);
    - their undated repeals empty `effective_from` / `changed_by` and are listed as markup conflicts;
    - uksi 2023/909 E+W → E (267; "Pt. 2 Ch. 3 inserted", territorial application E, the sole container);
    - WIA 1991 ss.29, 30ZA… E+W → UK (13; wrong legacy-id joins dropped, LR-19).
  - **Wrong, from LR-29's over-reach** (cross-heading refs reaching provisions not inserted), 95 rows:
    - ukpga 1991/22 "s. 81 cross-heading" (29);
    - anaw 2016/3 "s. 7 cross-heading" (28);
    - ukpga 1981/69 "s. 27ZA and cross-heading" (23);
    - ukpga 1989/29 "s. 11C–11H and cross-heading" (15; s.12A / s.12B → applying nowhere).
  - **To explain:** ukpga 1993/12 s.51 picks up the "ss. 30–46 repealed (S)" effect though it sits outside the range. In LR-29's measurement.
  - **Wrong, from step 7:** 141 rows lose a date because the notes' pointer lost its effect source. Fixed (bug above); the next dry run should show them gone.
- ✅ ~~Wave apply waits for LR-29~~: LR-29, LR-30 and LR-32 built; final dry run 2 clean (2026-10-15)
- ✅ **Jason: the wave** — approved and applied 2026-10-15 (see "The wave (2026-10-15)") (container ref over-reach, found in this dry run): applying now would write the regression (Electricity Act 1989 s.12A applying nowhere)
- ✅ Offline classified diff (store only); NAS backup; dry run → **Jason** → apply → verify (2026-10-15). The wave re-parses the 162 drifted laws through the one path (LR-28), then re-collects and rebuilds the timeline
- ⏸️ (deferred — the re-parse cleared the drift it was kept for: 0 stale laws; recommend deleting it, Jason's call) `mix lat.backfill_titles` (from LR-28, Jason 2026-10-14): the only tool that sets one parser-derived column (`--column`, e.g. `excluded_extent`) without a re-parse, so a second writer of parse content. Decide after the wave: if re-parsing the drifted laws through the one path is enough, delete it; else route it through the post-parse hook and record its writes
- ✅ Contract notes for D2 (LH-05): what changed for compliance and fractalaw (written down, not sent)
- ✅ Close LR-22 (design umbrella) and LR-21 with this session

## Dependencies

- ✅ LR-24 accepted (when); LR-26 accepted (where); LR-27; LR-08 (timeline 506,466 periods, b9d888bc)

## Inventory (2026-10-14)

**Writers.**
- Parse output (markup + feed effects, no note text): `extent_code`, `excluded_extent`, `territory_provenance`, `effect_ids` (walker / `Effects`), and a first `status` (`Rows.assign_status`: the Prospective flag, repealed text, an exclusion covering the extent).
- `LatStatus.Apply.refresh` then overwrites:
  - `status`, through `ChangeFacts.resolve`: effects first, else the `LatStatus` note regexes;
  - `effective_from`, `changed_by` and `change_provenance`, through `ChangeFacts.row_facts`: effects plus the note facts from `AmendmentNote`.

  It runs from `CommentaryPersister.persist` after each parse, and from `mix lat.status`, `place_notes`, `reorder_notes` and `repair_text`.
- `Apply.write_notes!` writes the notes' own fact columns (`effect`, `effective_from`, `changed_by`, `change_id`, `fact_provenance`).

**Status sources today.**

| Source | Rows |
|---|---|
| effect | 195,461 |
| markup | 178,886 |
| note text | 519 |

The column disagrees with the timeline's status as at today on 11,206 of 345,105 provisions.

**Readers outside -legal.**
- The delta sync upserts `status`, `effective_from`, `changed_by` and `extent_code` to prod.
- The Zenoh pull serves the same four to fractalaw.
- `lat_hash` covers `status` and `extent_code`, so changing either changes the hash fractalaw re-pulls on.

**The timeline reads parse output.**
- "Where" today comes from `extent_code`, `excluded_extent` and `territory_provenance`.
- J2 (markup wins today) reads `status` where `change_provenance.status = markup`.
- The timeline builder and the collector read `coalesce(citation_law, changed_by)` from notes as the pointer to an amending law. 964 notes point only through `changed_by`, which `AmendmentNote` reads from note text.

**Parse entry points.**
- `LatStagedParser.parse/2`, which covers reparse, `mix lat.reparse`, `lat.scope`, the admin controller and `run_scoped_lat`.
- A bypass, `StagedParser.persist_body_lat` (unscoped making laws). It skips `CommentaryPersister` and `LatCause`.
- No Oban.

Reusable for the hook:
- `ChangeCollector.collect/fidelity/write`;
- `LabelTimeline.build/write`, with the code version currently private in `mix lat.timeline`.

## Decisions for Jason

**Jason, 2026-10-14:**
- Nothing goes to compliance or fractalaw, so freezing or removing the columns makes no difference.
- "Disappointed we still derive data from Notes."
- "status goes to fractalaw — have we thought through the implications of removing."
- "Second parse path feels like poor code architecture."

**What fractalaw does with `status`** (read from `~/fractalaw`, 2026-10-14):
1. **The liveness gate (#73).** A row with status repealed or prospective imposes nothing. Its `drrp_types` and actors are blanked, and `extraction_method` is set to 'status' (`fractalaw-store/src/pg.rs:92-121`, 625-639). The blanked taxa are published back to legal.
2. **The re-pull trigger.** `status_hash` (SHA-256 over `section_id TAB status`) tells fractalaw to re-pull.
3. **A second repeal calculation of its own.** `unapplied_repealed()` (`pg_lat_sync.rs:239`) reads the feed's unapplied effects. It counts a provision as repealed when an exact, not-prospective, unsaved repeal has an in-force date on or before `current_date`. That is the timeline's job, done again inside fractalaw and evaluated daily by fractalaw's clock.
4. `effective_from` and `changed_by` are stored in `legislation_text` and not used.

Implications for D2 (LH-05), recorded here and not sent:
- `status` can't simply go. The gate needs an as-at-today status from the timeline.
- Status depends on the date, so a known commencement or repeal date passing changes it with no new data. Either fractalaw holds the periods and evaluates "as at" itself, as it already does with `current_date`, or the labels hash must move when a date passes.
- With the timeline, `unapplied_repealed` should retire: one change system, not two.
- The 11,206 provisions whose status differs from the timeline today would change fractalaw's taxa (classified "none" vs classified).

**Decided 2026-10-14 (Jason):**
- D1 remove;
- D3 as LR-28, opened;
- D4 guard test added.
- **fractalaw** will derive status from the timeline and refactor when the time comes to ship, retiring its own repeal calculation (`unapplied_repealed`) at the same time. Recorded in LH-05 (D2).

**D1 (revised) — remove, not freeze.**
- Remove `effective_from`, `changed_by` and `change_provenance` from `legal_articles`, using an Ash migration with the `Lat` view, sync and Zenoh field lists updated in code. Nothing is run outward.
- `status` becomes `markup_status`: what the revised text shows, written by the parse, which J2 reads. "status" as a label exists only in the timeline.
- Until D2, fractalaw must not pull.

**D3 (revised) — one LAT parse path, before the hook.**
- `StagedParser.persist_body_lat` repeats `LatStagedParser`'s work for unscoped making laws: the parse, the persist and the commentary sub-stage. It skips `LatCause` and the after-parse refresh.
- Fix it in its own session, LR-28 One LAT Parse Path, before LR-25's hook:
  - `LatStagedParser` takes the body already in hand;
  - `persist_body_lat` and its commentary copy are deleted;
  - the hook attaches in one place.
- Zero-diff gate: `mix lat.parse_snapshot`.

**D4 — no new note-fact path can appear unseen.** The note-fact code being deleted is LR-21's list (open since 2026-10-12), not a new find. After deletion, the only reads of note text are pointers:
- J5: a note saying "inserted" withholds the law's default start; it supplies no value;
- T1 and the collector: the law a note names;
- the collector's note joins;
- `change_id`, a hash;
- `NoteTerritory` in the `LatTerritoryCheck` diagnostic.

Recommend an architecture test that fails if any module outside an allow-list reads note text (`amendment_annotations.text`, `AmendmentNote`, note regexes).

## Parse drift (found 2026-10-14, in LR-28's check of the one-off repairs)

**Method.** Stored `legal_articles` was compared with a fresh in-memory parse of all 1,066 laws from the store. It was read-only and nothing was written. Per-law counts are in `backend/data/reports/lat-refactor/lr25-parse-drift.tsv`.

**Matches.** Text, section ids, sort keys, titles, note text, note placement and `extent_code` all match exactly.

**Behind the parser** (code changed after wave 4 and these laws were never re-parsed):

| Column | Rows | Laws | Read by the timeline? |
|---|---|---|---|
| `effect_ids` | 74,151 | 162 | no (the collector re-joins from the store) |
| `territory_provenance` | 1,204 | 16 | yes ("where" today) |
| `excluded_extent` | 451 | 8 | yes ("where" today) |

The largest: uksi 2023/909, ukpga 1984/22, 1991/22, 1981/69, anaw 2016/3. Candidate causes are the parser commits since wave 4:
- `967d2cdd`, the "revoked in part" rule;
- LR-19 `a6ee628d`, effect joins (its wave covered 283 laws);
- LR-27 `19355784`, container refs: the register was re-collected but the LAT was not re-parsed.

This is to be classified in the wave's dry run.

**Lesson.** The planned staleness check (parse newer than collect) can't see this. A change to parser code makes stored output stale with no new parse. The parse needs a code version, and the check needs to compare it.

## Build plan (draft, 2026-10-14)

Each step is test-first and the suite is green after each. No outward run: nothing is synced or served to compliance or fractalaw.

1. **Note-read guard (D4).**
   - Architecture test, as LR-28's: fails when a module outside the allow-list reads note text (`amendment_annotations.text`, `AmendmentNote`, `LatStatus` note regexes).
   - Red now. The allow-list is the pointer uses: J5 in `LabelTimeline`; T1 and the collector's law pointer; `CommentaryParser` (it builds notes); `NoteTerritory` (diagnostic).
2. **Parser code version.**
   - Each `parsed` lat_event records `parser_version`, a hash of the parser's source files taken at compile time (`@external_resource`).
   - It changes only when parse code changes. A git sha would change with every commit and mark every law stale.
   - The timeline keeps its own `code_version`.
3. **`markup_status`.**
   - The parse writes what the revised text shows (`Rows.assign_status`: Prospective flag, repealed text, an exclusion covering the extent) to a new column.
   - `LabelTimeline` J2 reads it instead of `status` + `change_provenance.status`.
   - Gate: the timeline is rebuilt in a dry run from a re-parse and is unchanged except where `markup_status` ≠ today's "markup"-sourced status (classified).
4. **Hook in one place.**
   - After `LatStagedParser.persist_stages` (rows, notes, cause), it runs `ChangeCollector` collect → fidelity → write, then `LabelTimeline` build → write, for that law.
   - A failure is logged and doesn't fail the parse.
   - `LatArchive` deletes the law's register and timeline rows.
   - `LabelTimeline`'s code version moves out of `mix lat.timeline` into the builder.
5. **Staleness check** (`mix lat.stale`, and part of verification). It lists laws:
   - parsed after their latest collect;
   - collected after their timeline was built;
   - whose `parser_version` isn't the current one.
6. **Readers move off the label columns.**
   - `LatHash` `status_hash`: the timeline's status as at today.
   - Zenoh `serialize_lat`: status / effective_from / changed_by come from the timeline as at today (`status`, `in_force_from`, `changed_by`). This is R3's "the pull computes as-at-today labels when it serves"; the contract shape is unchanged. It is only served at D2.
   - `LatCause` / `LatParseLog` `status_changed`: `markup_status`.
   - `mix lat.qa_sample` / `change_diff` / `parse_snapshot` / `timeline`: drop the label columns or read the timeline.
7. **Delete.**
   - `LatStatus.Apply` (refresh and note fact writes), `ChangeFacts`, `LatStatus.resolve` and its note regexes, and the fact-reading part of `AmendmentNote`.
   - The law-naming pointer stays (D2), written at parse by `CommentaryPersister`.
   - `CommentaryPersister` no longer calls the refresh.
8. **Migration** (Ash-generated; the `lat` view, which has no triggers, is recreated):
   - drop `legal_articles.effective_from`, `changed_by`, `change_provenance` and `status`;
   - add `markup_status`;
   - the `Lat` and `LegalArticle` resources follow.
9. **Wave.**
   - `markup_status` needs every law parsed, and 162 laws are behind the parser anyway, so it re-parses all 1,066 laws from the store through the one path, with the hook re-collecting and rebuilding each law's timeline.
   - Order: NAS backup → dry run (classified: labels moved, territory drift on 16 laws) → **Jason** → apply → verify: staleness 0, guard green, no label from note text, timeline as at today classified against the pre-wave timeline.
10. `lat.backfill_titles` decision; LH-05 contract notes (written, not sent); close LR-21 and LR-22.

**Gemini review** (`backend/data/code-reviews/2026-10-14-lr-25-build-plan.md`):

Taken:
- **Order.** Split the migration: an additive one at step 3 (`markup_status`), and the drop at step 8, after readers move (6) and code is deleted (7). Gemini's own order, migration first, would drop `status` while the code still reads it; the split meets its concern.
- **Parser version scope.** Everything the parse output depends on goes into the hash:
  - `lat_parser/**`, `lat_parser.ex`, `lat_staged_parser.ex`;
  - the changes-feed reader, effect index and territory modules;
  - `commentary_parser.ex`, `transforms.ex`;
  - `mix.lock`, for library changes.

  Whitespace edits also mark laws stale, a cost accepted to stay conservative.
- **Hook failure is recorded, not just logged.**
  - It records a `lat_event` `labels_failed` with the reason, and `mix lat.stale` lists it.
  - The register write and the timeline write are each already one transaction per law, so a failure leaves the previous complete state.
  - The staleness check still catches it, because `collected_at` stays older than the parse.
- **Verification adds:**
  - every law's `parsed` event carries the current `parser_version`;
  - a timeline coverage report (provisions with no timeline = the A8 gap classes, counted);
  - a `serialize_lat` shape test, so the contract shape is unchanged with values from the timeline;
  - hook time per law measured during the wave.
- **D2 open point:** Gemini recommends (a), drop.

Not taken:
- **Rolling back the parse when the hook fails.** The parse is valid data on its own, and the failure is visible.
- **An async job queue (Oban).** LAT is parsed on a local tool, with no Oban today. Synchronous per law is simpler to reason about, and a wave runs in a background shell.
- **Time zone.** Already handled: "today" is the UK date (`LabelProjection.uk_today/1`).
- **No timeline row.** Served as status nil = unknown, never a default. For D2: fractalaw's gate treats nil as live (`status IN ('repealed','prospective')`), so the contract note must say "nil = unknown".

**D2 decided 2026-10-15 (Jason): (a) drop.** "Drop them, we use leg.gov.uk notes as helpers/pointers not as data we need to store. The data comes from law or effects." Step 7 deletes the note fact columns (`effect`, `effective_dates`, `effective_from`, `fact_provenance`) with the code that fills them; step 8's migration drops them; the Zenoh note pull stops serving them (D2 contract note).

**Open point for Jason, D2 clarified (decided above).** Deleting `LatStatus.Apply` also stops filling the notes' own fact columns on `amendment_annotations`: `effect`, `effective_dates`, `effective_from`, `fact_provenance`. That is the note enrichment parked on 2026-10-12 ("the architecture track neither fills nor drops it"). The Zenoh note pull serves them. Options:
- **(a) Drop the columns with the code (recommended).** They are facts read from note text, which the rule forbids, and the register now holds the same changes with real sources. If note enrichment is wanted later, it would project from the register, not from note text.
- **(b) Keep the columns frozen** at today's values, documented as legacy, until the note-enrichment question is decided.

`changed_by` on notes stays either way, as the pointer (D2). `change_id` stays as an id.

## The wave (2026-10-15): for Jason's decision

**What it is.** The real pipeline over all 1,066 laws, from the store: re-parse → persist (with the enrichment carry and its gate) → notes → cause → the LR-25 hook (register and timeline per law). The result is what final dry run 2 (`lr25_final2`) showed, minus the rollback.

**What changes as at today** (39,638 label changes in 240 laws):

| Cause | Main classes |
|---|---|
| LR-27 over-reach removed (LR-29) | repealed → in force 1,792; in force → partly in force 535; dates moved 11,783; changed_by changed or emptied (95% verified as the old label's change no longer reaching) |
| J2: the revised text shows a repeal | in force → repealed 278 |
| LR-30: an undated insertion withholds the law's start | in force → unknown about 1,230 |
| LR-29: no honest start left once the over-reach is gone | in force → unknown about 700 |
| LR-32: another territory's change no longer dates a version | changed_by 332 |
| Headings dated by effects naming them | unknown → in force 233; dates and changed_by gained |
| Same-day ties: the law that made the change, stably | changed_by |
| Territory | follows the status changes above (rows becoming unknown lose their territory; rows no longer repealed regain theirs) |

**Timeline totals.**
- Periods: 506,466 → 479,108.
- Provisions unknown today: 30,201 → 31,984.
- Gaps:
  - no start 21,941;
  - insertion not in the register 9,576;
  - undated change 16,506;
  - markup conflict 8,163;
  - outstanding effect 1,526.

**Also fixed by the wave:**
- the parse drift on 162 laws (the stored `effect_ids`, `excluded_extent` and `territory_provenance` behind the parser);
- `markup_status` filled for every row;
- every law's `parsed` event carrying the current `parser_version`, and a `labels_refreshed` event.

**Steps.**
1. NAS backup (`./scripts/nas/nas-backup.sh`).
2. `mix lat.reparse --laws <all 1,066> --store only --tag lr25_wave` (rollback snapshot `lat_reparse_lr25_wave`; it stops at the first error). About 1.5–2 h.
3. Verify:
   - `mix lat.stale --strict` reports 0;
   - 0 `labels_failed` events;
   - today's labels equal the final dry run's (status / gap counts);
   - the note-read and write-path guards are green.
4. Record and close LR-25 (with LR-21, LR-22), LR-29, LR-30 and LR-32.

**Outward.** Nothing is synced. The Zenoh LAT pull, if fractalaw pulls from this dev DB, would serve today's timeline labels and a changed `status_hash`. fractalaw must not pull until D2 (LH-05).
