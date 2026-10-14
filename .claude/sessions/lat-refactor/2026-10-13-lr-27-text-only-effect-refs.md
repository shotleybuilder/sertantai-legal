---
session: 'LR-27: Text-only Effect Refs'
status: closed
opened: 2026-10-13
closed: 2026-10-14
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  Opened for feed effects named only as text ("Part 2B inserted"); measuring showed those are rare (24) and the real cause
  of undated inserted provisions was container refs — an effect referencing a cross-heading, Part or Chapter reached only
  the container's row (3,338 effects in 227 laws). Container refs now reach the provisions inside them; the register was
  re-collected (139,691 records, 0 fidelity failures) and the timeline rebuilt (505,244 periods): insertion gaps 12,084 → 8,134.

decisions:
  - what: "Re-scope from text-only refs to container refs"
    why: "Text-only Part refs: 24 effects, 47 J5 rows; the 1996/18 case had a structured ref (part-2B-crossheading-general) that joined only the cross-heading row"
    result: "3,338 container-ref effects in 227 laws found"
  - what: "Expand a non-words-level effect's container ref to the elements inside it in the CLML (EffectIndex.new/4, LatParser.Effects.index/3); a words change to a heading stays on the heading"
    why: "The feed names the container; the provisions inside it are what changed"
    result: "per-row ref joins 272,220 → 736,334; stored records 132,965 → 139,691 (compaction)"
  - what: "D1 re-collect, D2 timeline rebuild (dry run → Jason → apply)"
    why: "process"
    result: "1,559 insertion gaps fully dated, 2,329 now 'date unknown' with a timeline, 8,134 remain (LR-08 / not in the feed); s.27V dated 2023-07-31 partial, 2024-10-01 in force"

metrics:
  container_ref_effects: { total: 3338, laws: 227, inserted_crossheading: 628, part_applied: 571, part_modified: 521, part_chapter_inserted: 321 }
  register: { records: 139691, ref_per_row: 736334, unreached: 14100, fidelity_failures: 0 }
  timeline: { periods: 505244, code_version: cc2c9a3c }
  gaps: { insertion_not_in_register: 8134, undated_change: 19031, no_start: 22113, markup_conflict: 7705 }
  territory_today: { known: 312689, nowhere: 11816, unknown: 19674 }

lessons:
  - title: Measure the hypothesis before building the fix it implies
    detail: "The session was opened for text-only refs from one example; measuring found 24 such effects. Following the same example into the register showed the effect was there with a structured ref — to a container — which was the real, 140x larger gap."
    tag: data
  - title: A structured ref can still under-reach
    detail: "legislation.gov.uk often references the cross-heading or Part that was inserted or modified rather than each provision; an exact-id join treats it as one row. Containment comes from the CLML tree, which the parse already holds."
    tag: data
  - title: Don't recompile while a long mix task runs
    detail: "A forced compile during the dry run crashed it mid-way (walker stack trace); re-running clean confirmed no code fault."
    tag: tooling

bugs:
  - pattern: "A feed effect whose structured ref names a container (cross-heading, Part, Chapter: 'part-2B-crossheading-general') joins only the container's row; the provisions inside get it only where their own text carries markup"
    category: effect-join
    module: EffectIndex.new / LatParser.Effects.index
    affected: "3,338 effects (not words-level) in 227 laws; behind LR-24 J5 rows (1996/18 s.27V)"
    fix: "expand a container ref to the ids of the elements inside it in the CLML document (non-words-level effects); re-collect; rebuild the timeline"
    status: fixed
  - pattern: "Feed effects whose affected provision is given only as text ('Part 2B inserted', no AffectedProvisions refs) reach no LAT row, so the rows of an inserted Part have no dated insertion"
    category: effect-join
    module: ChangeCollector.Feed / EffectIndex (affected_provisions text → rows)
    affected: "24 unreached effects named only as a Part (measured 2026-10-13; not the main J5 cause after all — that was container refs)"
    fix: "Resolve affected_provisions text naming a Part / Chapter / cross-heading to its LAT rows (the rows' part / chapter / heading_group), join via ref; re-collect; the J5 rows then take their insertion date from the effect"
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/effect_index.ex (new/4 containers)
  - backend/lib/sertantai_legal/scraper/lat_parser/effects.ex (containers/1)
  - backend/test/sertantai_legal/scraper/lat_parser/effects_test.exs (container refs)
  - backend/data/reports/lat-refactor/lr27_collect*.csv, lr27_dry*.csv, lr27_rebuild*.csv (gitignored)

depends_on:
  - 2026-10-13-lr-24-label-projection
  - 2026-10-13-lr-23-change-log-collectors

enables:
  - LR-08 (the remaining 8,134 insertion gaps, pre-2002)
  - LR-25 switch-over (the parse's own joins also gain container refs on the next re-parse)
---

# Session: LR-27 Text-only Effect Refs (CLOSED)

## Problem

Some changes-feed effects give their affected provision only as text, with no structured `AffectedProvisions` refs. Example: 2023/13 "Part 2B inserted" into the Employment Rights Act 1996 (ss. 27U–27Y). The collector joins by structured refs, ranges, markup and note pointers, so such an effect reaches no row and sits in `lat_change_log` as a gap. The inserted provisions then have no dated insertion, and LR-24 (J5) leaves their start unknown rather than guess. This session makes those effects reach their rows. Pre-2002 insertions the feed doesn't record at all are LR-08's.

## Todo

- ✅ Measure: unreached effects naming a Part / Chapter / cross-heading / Schedule Part as text only; the LR-24 J5 rows they would date
- ✅ Tests first: a container ref (cross-heading / Part / Chapter) reaches the provisions inside it (1996/18 ss. 27U–27Y); a words-level change to a heading doesn't
- ✅ EffectIndex: expand container refs from the CLML tree; re-collect (fidelity gate; dry run → Jason → apply)
- ✅ Timeline rebuilt: J5 gaps that now have a date (12,084 → 8,134)

## Decisions for Jason

- **D1 — approved and applied 2026-10-13.** Re-collect the register with container refs (dry run below): `mix lat.collect_changes --all --apply`; then a timeline dry run → D2 rebuild

- **D2 — approved and applied 2026-10-14.** Rebuild the timeline: `mix lat.timeline --all --apply`

## Dependencies

- ✅ LR-23 register; ✅ LR-24 / LR-26 timeline filled (479,265 periods; 12,084 provisions with gap `insertion_not_in_register`)

## Measure (2026-10-13) — re-scoped

**Text-only refs are rare:** 24 unreached effects named only as a Part ("Pt. 11 heading", "Pt. 2"), covering 47 of the J5 rows.

**The real gap behind J5.** 1996/18's "Part 2B" case isn't text-only. The register holds 2023/13's insertion of ss. 27U–27Y, but it reaches only the subsection rows carrying insertion markup (s.27V(1) …), not s.27V itself. The feed's structured ref is the cross-heading, `part-2B-crossheading-general`, and a ref joins only the row with that exact id.

**Effects whose refs name a container** (cross-heading, Part, Chapter), not words-level: **3,338 in 227 laws**:
- inserted under a cross-heading: 628;
- Part applied: 571; Part modified: 521;
- Part / Chapter inserted: 321;
- substituted cross-heading: 232;
- the rest smaller.

Each reaches only the container's row.

**Fix:** expand a container ref to the provisions inside it in the CLML document (non-words-level effects; a words change to a heading stays on the heading). This is a join fix: it changes the register (via `ref` / `whole`) and, through the timeline, the dates of provisions in inserted cross-headings and Parts.

## Build and register dry run (2026-10-13)

**Built:**
- `EffectIndex.new/4` takes `containers` (container id → ids inside it) and expands a non-words-level effect's ref to them.
- `LatParser.Effects.index/3` builds the map from the CLML (Part, Chapter, Pblock, PsubBlock with an id).
- Tests: cross-heading → its sections; Part → everything inside; a words change to a heading stays on the heading. Suite 2,683.

**Register dry run** (`lr27_collect_dry`): 1,066 laws, 0 errors, **0 fidelity failures**.

| | Last fill | With container refs |
|---|---|---|
| Per-row `ref` joins | 272,220 | 736,334 |
| `whole` joins | 17,227 | 18,181 |
| `markup` joins | 104,515 | 103,804 |
| Unreached effects | 14,140 | 14,100 |
| Records stored (compact) | 132,965 | 139,691 |

The per-row growth is mostly Part-wide applications and modifications now reaching the provisions in the Part. Compaction keeps the stored increase to +6,726.

## Re-collect and timeline dry run (2026-10-13)

**Register re-collected** (approved): 1,066 laws, 0 errors, 0 fidelity failures; **139,691 records**.

**Timeline dry run** (`lr27_dry`), against the timeline now in the table:

| | Now | With container refs |
|---|---|---|
| Periods | 479,265 | 505,244 |
| insertion_not_in_register | 12,084 | **8,134** |
| undated_change | 16,231 | 19,031 |
| no_start | 22,203 | 22,113 |
| markup conflicts | 7,890 | 7,705 |
| territory unknown before today | 26,373 | 26,479 |

Where the 12,084 insertion gaps went:
- **1,559 now fully dated**;
- **2,329 now have a timeline, but their text has an undated change** (honestly "date unknown" rather than no row);
- 62 are markup conflicts;
- 8,134 remain (the feed holds no insertion reaching them: LR-08, or an insertion the feed doesn't record).

**1996/18 s.27V:** partly in force from 2023-07-31, in force from 2024-10-01 (2023/13), territory set. It was "unknown" before.

## Rebuild (2026-10-14)

`lr27_rebuild` (approved): 1,066 laws, 0 errors; **505,244 periods**, `code_version` cc2c9a3c. As at today (14 Oct):
- territory known 312,689;
- nowhere (repealed) 11,816 (+1,950: whole-Part repeals now reach the provisions in the Part);
- unknown 19,674.
