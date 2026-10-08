---
session: "LH-01: Note Metadata"
status: pending
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
---

# Session: LH-01 Note Metadata (PENDING)

## Problem

QA run 1: a note's dates and status reach only the last row of its `affected_sections` (`LatStatus.note_target/1`), so a note cited by several rows (sibling ranges, "S. 95A inserted" on the section, whole-instrument revocations whose last citing row is the signature, alternative versions) dates one row — up to ~59,000 rows with a dated note have nil `effective_from`. Welsh SIs come out as `UK_uksi_…` in `changed_by`, and marginal citations (Commentary Type="M") are stored as modification notes.

## Todo

- ⬜ Place notes on the rows that cite them at their own level (not via a descendant); a note applies to each citing row and its descendants (status, `effective_from`/`changed_by`) — `affected_sections` semantics change → LH-05 contract
- ⬜ Welsh SIs: "W.S.I." prefix; Citation URI type over the bare "S.I." text
- ⬜ Commentary Type="M" (marginal citation) → editorial, not modification; no `changed_by`
- ⬜ Offline measure: rows gaining dates / status changes; feeds LH-04

## Dependencies

- ✅ LAT = parser output (Coverage II wave 1)
