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

- ✅ #165 schedule rows with empty text — re-examined 2026-10-12 (Jason: compliance v0.1 ships without Schedules; are these parser output, and would a re-parse recreate them?). See **Schedule rows** below; decision D3
- ✅ "insert—/substitute—" with no body: 3,483 → **22 rows / 14 laws**; residue is inserted forms, formulae, images (2023/588 CAA forms, 2016/257 reg.23(2)(a) formula) → **fixed**; residue = known limit candidate (non-text inserts)
- ✅ 32 notes in 27 laws that hold no LAT: 26 revoked laws + 2011/971 (part-revoked, not Making) — none should hold LAT → **fix now: delete the 32 notes** (dry run → Jason)
- ✅ Savings listed + feed silent on territory (8 rows): the territory is only in the note or the amending law's text (LR-08, unapplied effects, not scheduled) → **known limit**; LatTerritoryCheck flags them
- ✅ 39 Making laws whose LAT was deleted: 39 → 1 (QQ-01 re-reviews); the 1 is Companies Act 1989, excluded by #166 → **fixed**
- ✅ fractalaw holds stale LAT for revoked laws legal no longer holds → **routed to LH-05** (the manifest lists removals; fractalaw drops them)
- ✅ 1949/97, 1949/74 still marked Revoked (no LAT, not in the store); regnal-year 1961 name → **out of LAT scope**: moved to QQ-06 (register hygiene)
- ✅ LH-08's 12 open items: each matched to its LR fix in the LH-08 doc (0 open); LH-08 ready to close
- ✅ New: `#position` ids — 1,307 rows / 123 laws (96 in 2026-09). 525 groups: 392 same status, different text (1,008 rows / 107 laws); 74 different status (158); 45 identical text (91); 14 mixed type (50). Mostly real identity defects, not source duplicates → **fix now** (see Findings)
- ✅ New: changed_by null on change notes that name an amender: 200 notes / 69 laws. 101 self-changes (null by design, `not_self`); 4 chains / uksi-wsi twin (LH-07); 95 no Citation, no effect: 22 (3 laws) cite a bare "2002/794" / "SI 1992/2823" the register holds → **fix now**; 73 name laws legal doesn't hold → **known limit**
- ⬜ D1 fix-now list and D2 known-limits list → Jason → approved (then close; fixes go to LR-13)

## Findings

**`#position` ids** (`Rows` disambiguation, LAT-TRANSFORMS §10). The suffix is the row's position, so the id changes whenever an earlier row is added or removed, and fractalaw's enrichment keys on it. Sampled groups are parser identity gaps, not true duplicates in the source:
- chapters numbered per Part with no Part in the id: asc 2025/4 `ch.2#70`, `ch.2#397`;
- nested lists losing a level: 1990/31 `s.17(1)(a)` ×3, 1974/40 `s.12(7)(b)` ×2;
- territorial versions with no qualifier: 1990/43 `s.153(1)(l)` plain and `[E+W: …]`;
- mixed types sharing an id: 1990/43 `s.33A(4)[S]` sub_section and paragraph; EU `art.Article 14#118` (number not parsed).
Fix: an id carries the path that makes it unique (Part for per-Part chapters, the missing list level, the version qualifier); `#position` only for true source duplicates. It renames rows → LatMerge carries enrichment (rename class), and fractalaw's message lists the renames.

**Observation (not a defect yet):** sort_key sub-segments repeat after an inserted subsection (2016/1105 reg.49(2)…(8)[E+W+S] all `.002`); order holds through the position suffix. Check in the id fix.

## Schedule rows

- The LAT parser fetches `/body/data.xml` for a whole law, which holds no Schedules. For a scoped law (#166) it fetches the fragments in `lat_scope`, and `Walker` parses a `Schedule` element like any other (`walker.ex:308`).
- **12 parent Acts** have scopes that list schedule fragments, set 2026-09-29 by `mix lat.scope --enabling` (purpose `enabling_extent`): SIs made under a schedule need that schedule's extent. 1972/68, 1974/28, 1984/27, 1997/16, 1998/47, 2000/17, 2001/9, 2007/15, 2009/20, 2015/15, 2020/1, 2020/29. None is Making.
- **1979/791** (Making, PDF-only): its transcript-built CLML holds the whole document, so its 2 schedules (forms) parse too.
- **A re-parse recreates them**: the scopes still list the fragments and the parser still reads Schedule elements.
- Size: 4,646 rows (17 schedule header rows + 4,629 rows under them); 9 enriched; 0 control mappings; 978 notes in 11 laws touch only schedule rows.
- Quality: the words are the provisions' words, but schedule paragraphs are typed `section` with ids `sch.5.s.1` (should be paragraphs, `sch.5.para.1`), and headed paragraphs carry empty text (their words sit in sub-rows). Not checked by any QA run.
- Dependency: `EnactedBy.EnablingExtent` reads the extent_code of any row in the named schedule; 71 SIs name a schedule of these Acts (2000/17: 33, 1972/68: 13, 2001/9: 8, …). Each schedule's **header row** carries the extent_code (all 17 coded), so the header alone keeps that evidence.

## Decisions for Jason

**D1 — Fix-now list** (approve, amend or move items to known limits). Built in LR-13, one targeted wave:
1. `#position` identity gaps (~1,000 rows / 107 laws), see Findings — ids rename, enrichment carried, fractalaw told
2. Delete the 32 notes on 27 laws that hold no LAT
3. changed_by from bare SI numbers the register holds (22 notes / 3 laws)

**D3 — Schedule rows: DECIDED b** (Jason 2026-10-12: no schedules at all; built in LR-13):
- Of the 71 SIs, 56 aren't Making (e.g. 2015/947 only amends the Climate Change Levy (General) Regulations 2001; an amending SI's extent drives no DRRP). 15 are Making; 12 of them hold no LAT; all 15 already have a stored extent.
- `enabling_provisions` is rank 5 in `ExtentResolver`: it is used only when the SI's own RestrictExtent, own LAT, contents and extent clause all give nothing. If the parent holds no LAT (or not the named provision), `EnablingExtent` returns nil (all-or-nothing) and the resolver falls to `affected_effects`, then `type_code`; an unknown never clears a stored extent.
- a. The parser emits only the Schedule header row (number, title, extent), never its contents; remove the 4,629 rows under the headers and the 978 schedule-only notes. Keeps the rank-5 evidence for SIs made under these schedules.
- b. No schedules at all: the parser skips Schedule elements; narrow the 12 scopes to their sections; remove all 4,646 rows and the 978 notes. Cost: a new or re-scraped SI made only under one of these schedules gets no rank-5 verdict and falls through; the 15 Making SIs keep their stored extents. Matches "the parser doesn't parse Schedules".
- c. Keep the rows; exclude schedules from what fractalaw and compliance get.
- Either a or b: built test-first in LR-13 and applied in its wave; a re-parse can't recreate what's removed.

**D2 — Known-limits list** (the only things allowed to stay wrong or absent at hand-off; LR-11's guide states them, QA run 4 classifies against them, LH-05's message lists them):
1. No schedules in LAT (#169; compliance v0.1 ships without them; D3 b: the parser skips Schedule elements, scopes hold sections only)
2. Inserted forms, formulae, images aren't text (22 rows / 14 laws end "substitute—")
3. Territory only in a note or the amending law's text (8 rows; LR-08 unscheduled; flagged by LatTerritoryCheck)
4. changed_by null where the amender isn't in the register (73 notes) or the law changes itself (101, by design)
5. Parts/headings whose XML has only a Number carry no text (67 rows)

Routed elsewhere: scope of "done" (1,068 laws vs the Making parse queue) → LR-12; 1949/97, 1949/74 register status and the regnal-year name → QQ-06; stale fractalaw LAT for revoked laws → LH-05.

Out of scope (not LAT): definition parser bugs, fractalaw tree/fitness bugs, AU is_making, the fitness doc.

## Dependencies

- ✅ LR-06 wave 4 applied and verified
