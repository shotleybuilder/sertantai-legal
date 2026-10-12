---
session: 'LR-10: Bug List & Known Limits'
status: active
opened: 2026-10-12
bugs:
  - pattern: "#position section_ids hide parser identity gaps: per-Part chapters without the Part, nested lists losing a level, territorial versions without a qualifier, mixed types sharing an id; ids shift when earlier rows change"
    category: lat-identity
    module: scraper/lat_parser/rows.ex, ids.ex
    affected: 1307 rows / 123 laws
    fix: "id carries the distinguishing path (Part, list level, version qualifier); #position only for true source duplicates"
    status: open
  - pattern: "Notes on laws that hold no LAT (26 revoked + 2011/971)"
    category: lat-notes
    module: amendment_annotations
    affected: 32 notes / 27 laws
    fix: "delete (dry run → Jason)"
    status: open
  - pattern: "changed_by null when the note cites a bare SI number ('by 2002/794', 'SI 1992/2823') the register holds, no Citation markup, no effect"
    category: lat-change-facts
    module: AmendmentNote / ChangeFacts note fallback
    affected: 22 notes / 3 laws
    fix: "resolve bare YYYY/NNN against the register by the note law's series"
    status: open
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-10 Bug List & Known Limits (ACTIVE)

## Problem

Plan step 1 (LR-00 meta, 2026-10-12). The open LAT bugs were logged before wave 4, and LH-08's open items were taken over by LR-02 to LR-05 without being reconciled, so no one can say what is still wrong in the data fractalaw will get. Each item is re-measured on the wave-4 dev DB and the CLML store (offline) and ends as **fixed**, **fix now** (test-first, lands in a later targeted wave) or **known limit**. Jason approves the known-limits list, the only things allowed to stay wrong at hand-off and the list QA run 4 classifies against.

## Todo

- ✅ #165 schedule rows with empty text: schedules aren't in `/body` (#169 deferred past v0.1); 13 of 1,068 LAT laws hold schedule rows (scoped fragments). Empty rows corpus-wide: all but 67 have child rows; the 67 are Parts/headings with only a Number in the XML (no Title) → **known limit candidate: no schedules (#169)**
- ✅ "insert—/substitute—" with no body: 3,483 → **22 rows / 14 laws**; residue is inserted forms, formulae, images (2023/588 CAA forms, 2016/257 reg.23(2)(a) formula) → **fixed**; residue = known limit candidate (non-text inserts)
- ✅ 32 notes in 27 laws that hold no LAT: 26 revoked laws + 2011/971 (part-revoked, not Making) — none should hold LAT → **fix now: delete the 32 notes** (dry run → Jason)
- ✅ Savings listed + feed silent on territory (8 rows): the territory is only in the note or the amending law's text (LR-08, unapplied effects, not scheduled) → **known limit**; LatTerritoryCheck flags them
- ✅ 39 Making laws whose LAT was deleted: 39 → 1 (QQ-01 re-reviews); the 1 is Companies Act 1989, excluded by #166 → **fixed**
- ✅ fractalaw holds stale LAT for revoked laws legal no longer holds → **routed to LH-05** (the manifest lists removals; fractalaw drops them)
- ✅ 1949/97, 1949/74 still marked Revoked (no LAT, not in the store); regnal-year 1961 name → **out of LAT scope**: register question for Jason (both Acts look live; if so they join the LAT parse queue)
- ✅ LH-08's 12 open items: each matched to its LR fix in the LH-08 doc (0 open); LH-08 ready to close
- ✅ New: `#position` ids — 1,307 rows / 123 laws (96 in 2026-09). 525 groups: 392 same status, different text (1,008 rows / 107 laws); 74 different status (158); 45 identical text (91); 14 mixed type (50). Mostly real identity defects, not source duplicates → **fix now** (see Findings)
- ✅ New: changed_by null on change notes that name an amender: 200 notes / 69 laws. 101 self-changes (null by design, `not_self`); 4 chains / uksi-wsi twin (LH-07); 95 no Citation, no effect: 22 (3 laws) cite a bare "2002/794" / "SI 1992/2823" the register holds → **fix now**; 73 name laws legal doesn't hold → **known limit**
- ⬜ Known-limits list → Jason → approved

## Findings

**`#position` ids** (`Rows` disambiguation, LAT-TRANSFORMS §10). The suffix is the row's position, so the id changes whenever an earlier row is added or removed, and fractalaw's enrichment keys on it. Sampled groups are parser identity gaps, not true duplicates in the source:
- chapters numbered per Part with no Part in the id: asc 2025/4 `ch.2#70`, `ch.2#397`;
- nested lists losing a level: 1990/31 `s.17(1)(a)` ×3, 1974/40 `s.12(7)(b)` ×2;
- territorial versions with no qualifier: 1990/43 `s.153(1)(l)` plain and `[E+W: …]`;
- mixed types sharing an id: 1990/43 `s.33A(4)[S]` sub_section and paragraph; EU `art.Article 14#118` (number not parsed).
Fix: an id carries the path that makes it unique (Part for per-Part chapters, the missing list level, the version qualifier); `#position` only for true source duplicates. It renames rows → LatMerge carries enrichment (rename class), and fractalaw's message lists the renames.

**Observation (not a defect yet):** sort_key sub-segments repeat after an inserted subsection (2016/1105 reg.49(2)…(8)[E+W+S] all `.002`); order holds through the position suffix. Check in the id fix.

**Scope of "done"** (for Jason): LAT covers 1,068 laws. `making_funnel` queues 3,219 more Making laws for a first LAT parse (2,543 in force). Data quality done = these 1,068; the others are later coverage, not this hand-off — confirm.

## Draft decision list (→ Jason)

Fix now (test-first, one targeted wave, dry run → Jason → apply):
1. `#position` identity gaps (~1,000 rows / 107 laws) — renames, enrichment carried
2. Delete the 32 notes on 27 laws without LAT
3. changed_by from bare SI numbers the register holds (22 notes / 3 laws)

Known limits (stay wrong or absent at hand-off; QA run 4 classifies against them):
1. No schedules in LAT (#169; 13 scoped laws are the exception)
2. Inserted forms, formulae, images aren't text (22 rows / 14 laws end "substitute—")
3. Territory only in a note or the amending law's text (8 rows; LR-08 unscheduled)
4. changed_by null where the amender isn't in the register (73 notes) or the law changes itself (101, by design)
5. Parts/headings whose XML has only a Number carry no text (67 rows)

Out of LAT scope: 1949/97, 1949/74 register status; regnal-year name; the 3,219 Making laws without LAT.

Out of scope (not LAT): definition parser bugs, fractalaw tree/fitness bugs, AU is_making, the fitness doc.

## Dependencies

- ✅ LR-06 wave 4 applied and verified
