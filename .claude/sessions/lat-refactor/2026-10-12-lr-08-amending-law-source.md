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
- ✅ Stop rules for fetching amending laws into the CLML store (Jason, 2026-10-13: rules first, so we don't run through the legislation.gov.uk corpus)
- ✅ Fetch hop 1 (the amending laws meeting the rules) into the CLML store: list → Jason → fetch
- ⬜ Probe: find the amending provision for a change (amending law + affected provision from the effect or the note's pointer), read its operation (substitute / insert / omit / repeal), commencement and extent from the amending law's CLML
- ⬜ Design (Gemini, then Jason): which facts this source may supply (changed_by, dates, territory, status) and how provenance marks it (`law`)
- ⬜ Tests first; offline classified diff; wave via LR-21
- Not in scope: applying unapplied amendments to the text (#171), backlog

## Decisions for Jason

- **D1 — Scope** (see Size): (a) rows whose amending law is in the store, 3,628; (b) the 1,206 rows with no law named, from the law's own commencement; (c) the 7,150 rows whose amending law has a `uk_lrt` record but no CLML file: not downloaded from legislation.gov.uk for v0.1 (#179)
- **D3 — Stop rules**: approved 2026-10-13, R1–R6 with **N = 5** (191 amending laws, 47% of 404; 6,768 of 7,150 rows, 95%)
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

## Stop rules (draft, 2026-10-13)

Jason: rules first, then pull the share of the 404 that meets them into the CLML store. The cascade to stop: a fetched law names further laws (its own amenders, its commencing orders, laws it cites), and each could name more.

- **R0 Top of the cascade** (Jason, 2026-10-13: "not all LRT laws equally need enrichment"). Demand comes only from LAT rows of laws that are in force in some way (`uk_lrt.live` ✔ In force or ⭕ Part Revocation / Repeal) and have an EHS&HR family (`uk_lrt.family` set).
- **R1 Demand only.** A law is fetched only because a LAT row (`legal_articles`) is labelled from a note naming it and no effect covers the row. Nothing else triggers a fetch.
- **R2 Fetched laws make no demand.** A law fetched as a source is stored as source only: no LAT rows, no `uk_lrt` change, not added to `clml.fetch`'s LAT list. Its notes, feed and citations are never read for further fetches.
- **R3 Two hops at most.** Hop 1: the amending law. Hop 2: the commencing SI the row's note names (the "; S.I. YYYY/N" after the amending citation), and only when hop 1 doesn't date the change itself. No hop 3.
- **R4 Threshold.** An amending law qualifies when it labels at least N LAT rows.
- **R5 Caps.** A fixed list per hop, written before anything is fetched; the run fetches that list and stops. Hop 2's list is drawn up after hop 1 has been read.
- **R6 Text types only.** Types with CLML text (ukpga, uksi, asp, ssi, wsi, nia, nisr, nisi, eur, eudr); not ukcm, eudn.

Measured on the 7,150 rows / 404 amending laws held only in `uk_lrt`:

| N (rows per amending law) | Amending laws | Share of 404 | Rows covered | Share of 7,150 |
|---|---|---|---|---|
| 1 | 404 | 100% | 7,150 | 100% |
| 5 | 191 | 47% | 6,768 | 95% |
| 10 | 127 | 31% | 6,349 | 89% |
| 20 | 78 | 19% | 5,712 | 80% |
| 50 | 28 | 7% | 4,118 | 58% |

Hop 2 (from note pointers, a ceiling): 1,967 rows name a commencing SI after the amending citation; 97 distinct SIs, 65 in `uk_lrt`, none in the CLML store. 1,384 rows' notes carry a date but no SI (dated by the amending law itself, or by an order the note doesn't name). Notes name the amending provision (s. / reg. / Sch. …) for 4,158 of the 4,700 rows with a placed note: the pointer to the provision to read.

## Hop 1 list (2026-10-13)

`backend/data/reports/lat-refactor/lr08_hop1.tsv` (gitignored): 191 amending laws at N = 5; R6 drops UK_eudn_2018_853 (5 rows), leaving **190 laws, 6,763 rows**. 21 of them are LAT laws without a CLML file (a normal LAT store fill). Largest: Utilities Act 2000 (1,086 rows), Forestry and Land Management (Scotland) Act 2018 (322), Transport Act 2000 (285), Directive (EU) 2018/851 (208), Employment Rights (Dispute Resolution) Act 1998 (194).

R2 holds without a code change: nothing enumerates the CLML store to choose LAT laws (`clml.fetch`'s default list is the laws in `legal_articles`; `lat.qa_sample` reads the store only for laws it samples), so a stored body creates no LAT rows. Fetch with `mix clml.fetch --laws <list>`: body only for a law with no `LatScope`; resumable, one request per document.

R0 applied (2026-10-13): of the 7,150 rows, 568 (28 laws) have no family and 6 (3 laws) aren't in force; demand 6,576 rows in 170 laws naming 379 amending laws. At N = 5 with R6: **hop 1 = 173 laws, 6,203 rows** (`lr08_hop1_r0.tsv`), all within the approved 190. Fetch started: `mix clml.fetch --laws <173>`.

## Hop 1 fetch (2026-10-13)

- **151 of 173 bodies stored** (CLML store 968 → 1,118 body files).
- **1 unavailable:** Merchant Shipping (Registration, etc.) Act 1993 (ukpga 1993/22, repealed 1996). legislation.gov.uk serves no body for it.
- **21 are LAT laws with a `LatScope`** (fragments only), so `clml.fetch` fetched only their LAT fragments. Their amending provisions came instead from the notes' pointers (s. / Sch. after the amending citation): 109 named fragments, 3 already held, 104 fetched (`section/N`, `schedule/N`). 2 returned 404: ukpga 1960/34 Sch. 1 and ukpga 1994/22 Sch. 7, probably pointer misreads. Their bodies were not fetched, so `LatScope` fragment reads and `lat.qa_sample` are unchanged.
