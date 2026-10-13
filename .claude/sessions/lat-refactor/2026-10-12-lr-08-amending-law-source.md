---
session: 'LR-08: The Amending Law as a Source'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-08 The Amending Law as a Source (ACTIVE)

## Problem

The other half of Jason's 2026-10-09 decision: a change the markup and effects don't carry is "checked against the law it was built from". Parked as "later, not scheduled" (2026-10-09), so notes filled the gap (LR-00 meta, "Why the notes decision was not delivered"). The amending law's own text names the provision it changes, the change and its commencement and extent; that is law, where a note is not. Scope (LR-20, Jason approved D2 2026-10-12): class b — 1,828 notes in 183 laws with no effect whose amending law is in the CLML store — and a law's own commencement provisions (part of class c1). Amending laws not in the store stay empty for v0.1 (#179, compliance v0.2).

## Todo

- ✅ Size, in rows (after LR-19): which note-labelled rows have their amending law in the store
- ⬜ Probe: find the amending provision for a change (amending law + affected provision from the effect or the note's pointer), read its operation (substitute / insert / omit / repeal), commencement and extent from the amending law's CLML
- ⬜ Design (Gemini, then Jason): which facts this source may supply (changed_by, dates, territory, status) and how provenance marks it (`law`)
- ⬜ Tests first; offline classified diff; wave via LR-21
- Not in scope: applying unapplied amendments to the text (#171), backlog

## Decisions for Jason

- **D1 — Scope** (see Size): (a) rows whose amending law is in the store, 3,628; (b) the 1,206 rows with no law named, from the law's own commencement; (c) the 7,150 rows whose amending law has a `uk_lrt` record but no CLML file: not downloaded from legislation.gov.uk for v0.1 (#179)
- **D2 — Dates**: the amending law names the change and itself; the date is usually set by a commencement order (a second law). effective_from only when the amending law fixes the date itself or its commencement order is in the store; otherwise empty

## Dependencies

- ✅ LR-20 inventory and rule (D1, D2 approved)

## Size (2026-10-13)

Rows labelled from notes (`change_provenance.change = note`) after LR-19: 14,709 rows, 262 laws. By which data repo holds their amending law (the law the note names). Repos: CLML store = `backend/data/cache/clml/<type>/<y>/<n>/body/data.xml.gz` (968 laws' XML); LAT = `legal_articles` (1,066 laws, parsed from the CLML); `uk_lrt` = the legal register table (19,813 laws, metadata only, no text); report `backend/data/reports/lat-refactor/lr08_rows.tsv` (gitignored).

| Class | Rows | Laws | Amending laws | Amending law before 2002 |
|---|---|---|---|---|
| CLML store + LAT; the feed has effects by it on other provisions | 1,944 | 50 | 63 | 1,041 |
| CLML store + LAT; no effect by it on the law | 1,684 | 53 | 56 | 1,635 |
| `uk_lrt` only (37 of the 404 also in LAT, without CLML) | 7,150 | 201 | 404 | 4,838 |
| No repo | 2,725 | 119 | 231 | 2,003 |
| No law named (date only; own commencement?) | 1,206 | 64 | — | — |

The two store classes total 3,628 rows in 82 laws, from 113 amending laws. Most are pre-2002 changes, where the feed records few effects (legislation.gov.uk's effects run from 2002). Example: Town and Country Planning Act 1990: 512 rows labelled from notes as changed by the Planning and Compensation Act 1991; the feed holds only that Act's prospective repeals on 1990/8. The rows' dates (1991-09-25, 1992-01-02, 1992-07-17 …) come from commencement orders, not from the 1991 Act.
