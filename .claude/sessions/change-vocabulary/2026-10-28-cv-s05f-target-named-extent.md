---
session: 'CV-S05f: Target-Named Extent Statements'
status: pending
opened: '2026-10-28'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
depends_on:
  - change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: CV-S05f: Target-Named Extent Statements (PENDING)

## Problem

Some amending laws state the extent of a change by its target in the amended law, not by their own provision: "The repeal of section 4(8) extends also to Scotland" (SOCPA 2005 Sch.7 para 27(4)), "The repeal of the Arbitration Act 1975 extends only to England and Wales and Northern Ireland" (ukpga 1996/23), "The amendments of the International Criminal Court Act 2001 extend to England and Wales and Northern Ireland only" (ukpga 2010/23). Extent rows are keyed by amending provision, so the reader leaves these unread, which withholds the bound (CV-S05 round 6: wider is safe). Where one amending provision makes several changes with different extents (SOCPA Sch.7 para 27(2) repeals RTA 1988 s.4(6)–(8): s.4(6) and (7) E+W, s.4(8) also S), no bound on the provision is right for all of them.

Found by CV-S06's golden run from inputs (2026-10-28): RTA 1988 s.4(6) fails, repealed everywhere from 2006 where it stays in force in Scotland. Placed by Jason 2026-10-28: a PENDING sub-session straight after CV-S06's agent seeds; the golden case is a known limit until then.

## Todo

- ⬜ Measure: every extent sentence naming a target of the amended law (the extent catalogue's examples hold about 10; count over the store)
- ⬜ Design: an extent row naming the amended target (law and provision), matched by target in `Extent.Lookup` (`of_change` with the change's target), stored in `extent_rules`
- ⬜ Read the forms: "The repeal of X extends …", "The repeals in Y relating to …", "The amendments of the Z Act extend …"; and SOCPA Sch.7's own-paragraph forms not read ("This paragraph extends to the whole of the United Kingdom", "… extends also to Scotland", "… has the same extent as that Act", "… (but not to Scotland)")
- ⬜ Golden from inputs 27/27; extent check and catalogue; one chain
- ⬜ Agreement measure (CV-S06's revised check, Jason 2026-10-28): the extent reader's bound (`law_text.extent`) against the feed's `effect_extent` / `territorial_application`, like for like, over every bounded change; agents on the disagreements and on changes with no feed extent. Added to the quality statement

## Dependencies

- ✅ CV-S05 Extent and application reader (closed)
