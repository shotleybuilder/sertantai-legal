---
session: 'LR-25: Change Log Switch-over'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-25 Change Log Switch-over (ACTIVE)

## Problem

The register (`lat_change_log`, LR-23/LR-08) and the timeline (`lat_label_timeline`, LR-24/LR-26/LR-27) now answer where and when for each provision, but the LAT parse still computes its own change labels on `legal_articles` (status, effective_from, changed_by, change_provenance), partly from note text, and nothing rebuilds the register and timeline when a law is re-parsed. This session switches -legal over inside -legal: one source of labels, kept fresh after each parse, and the note-fact code deleted (absorbs LR-21).

**Re-scoped 2026-10-14 (Jason: "We're not close to fractalaw handoff yet").** Nothing that reaches compliance or fractalaw happens here. The delta sync change (stop exporting `lat.status` / `effective_from` / `changed_by`, carry the timeline) and fractalaw's pull from the timeline (labels hash in the manifest) move to D2 (LH-05), after QA run 4.

## Todo

- ✅ Re-scoped to inside -legal; meta plan updated (2026-10-14)
- ✅ Inventory: every writer and reader of the `legal_articles` label columns; parse entry points; note-fact paths still called
- ⬜ **Jason: D1** — what the `legal_articles` label columns become once the parse stops computing them
- ⬜ Note-read guard test (D4, approved): fails if a module outside the allow-list reads note text (`amendment_annotations.text`, `AmendmentNote`, note regexes); allow-list = the pointer uses only
- ⬜ Tests first: no fact from note text (ChangeFacts, AmendmentNote, LatStatus, CommentaryParser `citation_law` a pointer only)
- ⬜ Parse hook (after LR-28, in its one place): collect + timeline for the law after each LAT parse; `ChangeFacts.row_facts` retired
- ⬜ Staleness check, two parts:
  - 0 laws whose latest `parsed` event is newer than their `lat_change_log.collected_at` (LR-23 Gemini D1);
  - 0 laws parsed by older parser code: the parse stamps a code version, as the timeline does (found 2026-10-14, see Parse drift)
- ⬜ Delete the dead parse-time label and note-fact paths (LR-21)
- ⬜ Offline classified diff (store only); NAS backup; dry run → **Jason** → apply → verify. The wave re-parses the 162 drifted laws through the one path (LR-28), then re-collects and rebuilds the timeline
- ⬜ `mix lat.backfill_titles` (from LR-28, Jason 2026-10-14): the only tool that sets one parser-derived column (`--column`, e.g. `excluded_extent`) without a re-parse, so a second writer of parse content. Decide after the wave: if re-parsing the drifted laws through the one path is enough, delete it; else route it through the post-parse hook and record its writes
- ⬜ Contract notes for D2 (LH-05): what changed for compliance and fractalaw (written down, not sent)
- ⬜ Close LR-22 (design umbrella) and LR-21 with this session

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
