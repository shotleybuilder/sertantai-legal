---
session: 'LR-27: Text-only Effect Refs'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "A feed effect whose structured ref names a container (cross-heading, Part, Chapter: 'part-2B-crossheading-general') joins only the container's row; the provisions inside get it only where their own text carries markup"
    category: effect-join
    module: EffectIndex.new / LatParser.Effects.index
    affected: "3,338 effects (not words-level) in 227 laws; behind LR-24 J5 rows (1996/18 s.27V)"
    fix: "expand a container ref to the ids of the elements inside it in the CLML document (non-words-level effects); re-collect; rebuild the timeline"
    status: open
  - pattern: "Feed effects whose affected provision is given only as text ('Part 2B inserted', no AffectedProvisions refs) reach no LAT row, so the rows of an inserted Part have no dated insertion"
    category: effect-join
    module: ChangeCollector.Feed / EffectIndex (affected_provisions text → rows)
    affected: "25 unreached Part/Chapter effects; behind most of LR-24 J5's 7,157 rows in 144 laws (1996/18 Pt. 2B, ss. 27U-27Y, inserted by 2023/13)"
    fix: "Resolve affected_provisions text naming a Part / Chapter / cross-heading to its LAT rows (the rows' part / chapter / heading_group), join via ref; re-collect; the J5 rows then take their insertion date from the effect"
    status: open
---

# Session: LR-27 Text-only Effect Refs (ACTIVE)

## Problem

Some changes-feed effects give their affected provision only as text, with no structured `AffectedProvisions` refs. Example: 2023/13 "Part 2B inserted" into the Employment Rights Act 1996 (ss. 27U–27Y). The collector joins by structured refs, ranges, markup and note pointers, so such an effect reaches no row and sits in `lat_change_log` as a gap. The inserted provisions then have no dated insertion, and LR-24 (J5) leaves their start unknown rather than guess. This session makes those effects reach their rows. Pre-2002 insertions the feed doesn't record at all are LR-08's.

## Todo

- ✅ Measure: unreached effects naming a Part / Chapter / cross-heading / Schedule Part as text only; the LR-24 J5 rows they would date
- ⬜ Tests first: a container ref (cross-heading / Part / Chapter) reaches the provisions inside it (1996/18 ss. 27U–27Y); a words-level change to a heading doesn't
- ⬜ EffectIndex: expand container refs from the CLML tree; re-collect (fidelity gate; dry run → Jason → apply)
- ⬜ Timeline rebuilt: J5 gaps that now have a date

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
