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
- ⬜ Tests first: no fact from note text (ChangeFacts, AmendmentNote, LatStatus, CommentaryParser `citation_law` a pointer only)
- ⬜ Parse hook: collect + timeline for the law after each LAT parse; `ChangeFacts.row_facts` retired
- ⬜ Staleness check: 0 laws whose latest `parsed` event is newer than their `lat_change_log.collected_at` (LR-23 Gemini D1)
- ⬜ Delete the dead parse-time label and note-fact paths (LR-21)
- ⬜ Offline classified diff (store only); NAS backup; dry run → **Jason** → apply → verify
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

**D1 — The `legal_articles` label columns until D2.** Recommend:
- **Inputs stay parse output.** `extent_code`, `excluded_extent`, `territory_provenance` and `effect_ids` come from markup and effects only, and the timeline reads them. The markup status the timeline needs (J2) moves to its own internal column, `markup_status`, written by the parse; it is not synced or served.
- **The outward columns are frozen until D2.** The parse and the hook stop writing `status`, `effective_from`, `changed_by` and `change_provenance`. Re-parses carry the old values, so nothing prod or fractalaw sees changes and no hash moves before QA run 4. D2 drops them from the sync and the pull in favour of the timeline.
- **Rejected:**
  - mirroring today's timeline into them now (true values, but it changes hashes and fractalaw re-pulls before QA);
  - emptying them now (an outward change with nothing to replace it yet).
- **Known cost:** until D2, those four columns are legacy. They include 519 note-sourced statuses and the note-dated labels. They are documented as deprecated, and nothing in -legal reads them except the `mix lat.timeline` diff.

**D2 — The notes' changed-by pointer.**
- Recommend: keep the part of `AmendmentNote` that names the law, as a pointer only (where to look). It feeds the collector and timeline (964 notes).
- Delete its effect and date reading, the `LatStatus` note regexes and the `ChangeFacts` note fallback.
- `change_id` (a hash of the note text, used by `LatParseLog`) stays: it's an id, not a fact.

**D3 — The hook covers both parse paths.** Collect, then the timeline, runs after `LatStagedParser` and after the `persist_body_lat` bypass. A failure is logged and left for the staleness check to show, rather than failing the parse.
