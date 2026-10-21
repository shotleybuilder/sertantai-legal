---
session: "LH-07: Welsh SI Duplicates (#178)"
status: pending
release: v0.1
opened: 2026-10-08
parent: lat-handoff/2026-10-08-lh-00-meta.md
issue: 178
---

# Session: LH-07 Welsh SI Duplicates (PENDING)

## Problem

Welsh SIs are also numbered in the UK SI series, so legislation.gov.uk serves `/uksi/2012/801` as the Welsh SI (document IdURI `id/wsi/2012/801`). The register holds both a `uksi` and a `wsi` record for 30 such instruments ("(Wales)" titles; more may hide without it), and the LAT sits on the wrong one: 17 `uksi` records hold LAT, 6 `wsi` records do, some both (identical text, enriched twice — 2004/1490, 2005/1806, 2017/544). Fractalaw must get one record per instrument, keyed by legislation.gov.uk's id, before the hand-off.

## Todo

- ⬜ Inventory: every `uksi` record whose stored/fetched document IdURI is `wsi/…` (not just "(Wales)" titles); per pair: LAT rows, enrichment, notes, control mappings, amending / enacted_by / family edges, compliance references
- ⬜ Check with sertantai-compliance whether customer registers reference the `uksi` names
- ⬜ Plan per pair (dry run → Jason): move LAT/notes/enrichment uksi → wsi (law_name, section_id, law_id renamed; enrichment kept); drop the uksi copy where identical; repoint edges and mappings
- ⬜ Retire the `uksi` duplicates (mark, not delete, until compliance confirms)
- ⬜ Prevent recurrence: IdURI check at scrape / LAT parse time
- ⬜ Verify: one record per instrument; LAT counts and enrichment preserved

## Decisions for Jason

- **D1 — Plan per pair** from the dry run: move LAT / notes / enrichment uksi → wsi, drop identical uksi copies, repoint edges and mappings
- **D2 — Retire** the uksi duplicates (marked, not deleted) once compliance confirms customer registers don't need them

Plan step 4 (LR-00 meta, 2026-10-12): done before QA run 4 so the sample is the data fractalaw gets. Also closes the 15 note-fallback changed_by notes still on uksi 2013/755 (LR-05).

## Dependencies

- ⬜ Wave 3 applied (LH-06), so ids are final before moving rows
- ⬜ Compliance's answer on uksi references
