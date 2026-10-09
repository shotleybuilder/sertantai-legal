---
session: 'LR-03: Effects Layer'
status: active
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-03 Effects Layer (ACTIVE)

## Problem

Rescoped 2026-10-09 (Jason: "we're going the wrong way in the chain"). Changes the text markup doesn't carry — a whole section repealed with no `Repeal` element (1974/40 s.101, 1993/12 s.18), a change element with no `Extent`, an except-clause (1984/22 Pt. II "except in relation to ss. 13-15") — must come from the **effects layer** (changes feed), not note prose. Notes are hints of where to look. LR-02's note-text territory fallback (`NoteTerritory`, ~27,500 elements) is interim and is replaced here where an effect exists.

## Precedence is by cause, not by source (Jason, 2026-10-09)

"markup and effects diff most likely when the effects haven't been pushed into markup … should markup really have precedence?" No single precedence. Classify each disagreement by cause, measured in the probe:
- effect **not yet applied** (`Applied=false`): the markup is stale; the effect is current law → record the effect's territory on the row with provenance (the text itself lags: #171);
- effect **applied** but disagreeing with the markup → editorial data issue: flag, don't guess;
- other causes the probe finds (whole-provision effect vs word-level markup, effects outside scoped LAT, legacy notes with no effect, …).

## Todo

- ✅ Plan agreed: `docs/LAT-EFFECTS-LAYER-PLAN.md` (Gemini critical review + Jason's decisions)
- ✅ Probe: changes-feed cache — keep each effect's id; coverage by law and by year; join rates effect ↔ note (`Commentary/@id` = effect id for `key-` notes) and effect ↔ markup `ChangeId`; legacy (`c…`) notes with no effect
- ⬜ Whole-provision changes not marked in the text, from effects (AffectedProvisions refs + territorial application) → `excluded_extent` (3 pending fixtures)
- ⬜ Change territory from effects for elements without `Extent`; note text only where no effect exists, flagged as such (or the amending law)
- ⬜ Classified diff; review

## Dependencies

- ⬜ LR-02 closed
- ✅ `LegislationGovUk.ChangesFeed` (#168), cache `data/cache/changes-feed*`

## Pending tests this session must turn green (from LR-02)

`mix test --only pending` — tagged `pending: "LR-03"`:
- note territory (no attribute)
- note territory, no attribute (1990/8 s.150(1)(b) "or 24ZA(c)")
- note territory, no attributes
- retained for some territories (note)
- a Part inserted for W (note only): 2010/2214 Pt. 2B
- retained for E+W with an inner E+W insertion: plain + excluded (Q3; 1974/40 s.30(5))
- attribute and note both name territories: union (Q1; 1996/1527 reg.16(1))
- a signature whose parts are retained-repealed for S (1989/1263 signed.72)
- a section repealed for S by a note in its number only: 1974/40 s.101
- a note-only repeal adds to an element repeal for other territories: 1993/12 s.18
- a Part repeal "except in relation to ss. 13-15" doesn't touch s.13 (Q2; 1984/22)
- a provision repealed in one territory (from the note) keeps its text and status
- the Repeal's own Extent and its note's territory together
- a Repeal wrapping whole Text elements counts too
- the territory can come from the repeal's note

## From LR-02's acceptance review (Gemini, `backend/data/code-reviews/2026-10-09-lr02-acceptance-gemini.md`)

- Effects are **additive**: take LR-02's segments and markup territory as given; don't re-parse text or change `LatTerritory`'s rules.
- **Provenance**: every territory claim records its source (markup vs effect) — distinguishable downstream.
- **Precedence**: a documented rule for markup vs effect disagreement (default: markup), else flag for review.
- Pure, unit-testable effect interpretation (one effect record × segments → claim).

## Work (2026-10-09)

- **Offline probe of the existing cache**: of 1,068 LAT laws, 381 fully cached (in-force + refs), 274 basic, **413 none**; 168,418 effects — **10,434 (6%) not yet applied** to the text; 82,499 explicit effect extent, 28,105 "same as affected" (legislation.gov.uk's `S+A+M+E+A+S+A+F+F+E+C+T+E+D` sentinel — `LiveStatus` already handles it), 9,628 territorial application; 138,357 with structured affected refs; **no effect ids kept** (`data/reports/lat-refactor/lr03-probe-offline.txt`).
- **Pagination**: `results-count=5000` returns 1990/43's 1,940 effects in one page → one request per law (2006/46: 2 pages).
- **Raw feeds stored** (test-first): `ClmlStore` keeps changes-affected feed pages as `changes/affected/<t>/<y>/<n>/data.feed.page-N.gz` (freshness = fetch age); `ChangesFeed` keeps `effect_id`, `affecting_provisions`, `modified`, passes the store mode; `mix lat.fetch_effects` (resumable, per-law log). Smoke: 2 laws, 6,095 effects, offline re-read OK.

- **Full fetch**: 1,068 laws, 204,622 effects, 0 errors (one retried timeout); 35 MB raw feeds stored. **Probe** (`lr03_probe.py`, `lr03_noelement.py`): modern F notes → effect 95.7%; insertions → effect 200,322/281,160, retained repeals 17,000/20,548 (rest legacy ids); attribute vs effect 15,170 agree / 2,373 differ — not conflicts: effect *extent* is the amending provision's (upper bound), TA is narrower application; 2/200 disjoint. No-element territorial effects: schedules 20,167, scoped-out 17,976, dots 3,806, text present 9,312 applied + 3,160 unapplied.
- **Decisions** (Jason, after Gemini): application first kept; effect extent never used; rule 3 only whole-provision repeal/insert with no markup at all; structured provenance with ids (row column); sanity checks + conflict report before any write; no golden set (corpus patterns are the test); notes unused today (future untrusted hint); **unapplied effects → a later session** (getting ahead of the markup, with #171).
