---
session: "LH-01: Note Metadata"
status: closed
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
---

# Session: LH-01 Note Metadata (CLOSED)

## Problem

QA run 1: a note's dates and status reach only the last row of its `affected_sections` (`LatStatus.note_target/1`), so a note cited by several rows (sibling ranges, "S. 95A inserted" on the section, whole-instrument revocations whose last citing row is the signature, alternative versions) dates one row — up to ~59,000 rows with a dated note have nil `effective_from`. Welsh SIs come out as `UK_uksi_…` in `changed_by`, and marginal citations (Commentary Type="M") are stored as modification notes.

## Todo

- ✅ Place notes on the rows that cite them at their own level (not via a descendant); a note applies to each citing row and its descendants (status, `effective_from`/`changed_by`) — `affected_sections` semantics change → LH-05 contract
- ✅ Welsh SIs: "W.S.I." prefix; Citation URI type over the bare "S.I." text
- ✅ Commentary Type="M" (marginal citation) → editorial, not modification; no `changed_by`
- ✅ Offline measure (`lh01-place-dry.csv`, rolled back): 81,358 notes narrowed to their citing rows, 73,154 rows' effective_from/changed_by change; statuses in_force → partial 2,099 (sampled: whole sections/chapters inserted "for specified purposes" now mark every row, not only the last), partial → in_force 281, repealed → repealed_saved 115; 5,965 unmatched = the M notes (code_type changed; re-persisted in the wave)

## Dependencies

- ✅ LAT = parser output (Coverage II wave 1)

## Work (2026-10-08)

- Placement: `LatParser.own_level_refs/1` — a row keeps only the commentary refs none of its descendant rows hold, so `affected_sections` lists the rows citing a note at their own level (siblings "(3H)(3I)" both; a section-level note on the section). Per-row counts unchanged (struct_hash).
- Effect: `LatStatus.note_targets/1` (every affected row) replaces `note_target/1` (last); `LatStatus.resolve`, `LatStatus.Apply` (row effective_from/changed_by), `LatCause.Apply` and `LatChangeLog` apply a note to each target and its descendants. `ancestors/1` keeps the extent tag at every level (a note on reg.33[S] reaches reg.33(1)[S]).
- Welsh SIs: `AmendmentNote` reads "W.S.I."; `AmendmentNote.resolve_law/2` + `LatStatus.Apply` use the `UK_wsi_` twin when a plain "S.I." names no uksi in the register.
- Marginal citations: Commentary Type="M" → `extent_editorial`; an editorial note without " by " has no `changed_by` (5,961 M notes in the store).
- Tests: parser placement, LatStatus multi-target + tagged ancestors, Apply Welsh resolution, AmendmentNote W.S.I./resolve_law/marginal citations, CommentaryParser M mapping.
