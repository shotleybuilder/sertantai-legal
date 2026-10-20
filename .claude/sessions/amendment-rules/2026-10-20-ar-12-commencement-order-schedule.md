---
session: "AR-12: Provisions Listed in a Commencement Order's Schedule"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'A commencement order commencing "the provisions of the Act specified in Part II of Schedule 1 to this Order" is read as scope sch.1 of the commenced Act (SI 1999/2830 reg.2 → EReA 1999 sch.1, twice, 1999-10-25 and 1999-12-15); the provisions the order''s Schedule lists are never dated'
    category: commencement reader
    module: Commencement.Order
    affected: '56 stored rules in 16 orders quote "Schedule N to this Order" (e.g. SI 1991/2286 sch.1, sch.2); re-read with the AR measure run'
    fix: 'the order''s own Schedule is never a ref; each Part of it dated by its title; "Part N of Schedule M" → sch.M.pt.N; a Schedule paragraph dated by its Part (c24bedc3)'
    status: fixed
  - pattern: 'An order table row "Subsections (1) to (5) of section 18" is read as the whole section s.18, fully (SI 1999/2830 Sch 1 Pt I); "Subsections (1) to (3) of section 13" likewise'
    category: commencement reader
    module: Commencement.Order.refs
    affected: 'seen in SI 1999/2830 (2 rows); corpus count unknown'
    fix: '"Subsections (a) to (b) of section N" → s.N(a)..s.N(b)'
    status: open
  - pattern: 'An order table row naming another law in an aside ("Section 31 and in Schedule 7, paragraphs 1, 2, 5 (to the extent that it inserts section 11A into the Employment Agencies Act 1973), 6 and 8") gives no rule at all'
    category: commencement reader
    module: Commencement.Order.drop_other_laws
    affected: 'seen in SI 1999/2830 (1 row: EReA s.31, Sch 7)'
    fix: drop only the aside naming the other law, keep the row's own refs
    status: open
---

# Session: AR-12: Provisions Listed in a Commencement Order's Schedule (ACTIVE)

## Problem

SI 1999/2830 reg.2(2) commences "the provisions of the Act specified in Part II of Schedule 1 to this Order" on 1999-12-15; the commencement reader stores scope `sch.1` of the commenced Act (EReA 1999), so EReA s.7, s.8 … are undated and EReA Sch 1 is wrongly dated twice (AR-05 trace, open bug; commencement reader).

## Todo

- ✅ Count commencement rules whose source text points to the order's own Schedule ("specified in … Schedule N to this Order")
- ✅ Read the order's Schedule rows as the scope (tests first); never the commenced Act's Schedule
- ⬜ Read-pass the affected orders; pilot; batch into the AR measure run (docs/COMMENCEMENT-GUIDE.md gap note)

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)

## Fix and pilot (2026-10-20, c24bedc3)

- **`Commencement.Order`:**
  - "Schedule N to this Order" is never a ref of the Act.
  - Each Part of the order's Schedule with a dated title gives its own rules. The Schedule is dated as a whole only when no Part is.
  - "Part III of Schedule 4" is scope `sch.4.pt.III`, and `Order.ref("schedule-4-part-III")` gives the same.
- **`Amendment.Collect`:** a Schedule paragraph with no rule of its own is dated by its Part. `Reader.parts/1` maps each paragraph id to its Part, and it is kept in the read pass's index as `parts`.
- **Tests:** written first, in Order (SI 1999/2830's shape) and Collect (Utilities Act Sch 6 Pt II from the document and from the stored index). Suite: 2,895 pass.
- **SI 1999/2830 re-read** (only this order; the full `--read-orders` goes with the AR measure run): 24 rules. Sch 1 Pt I is dated 1999-10-25 and Pt II 1999-12-15, including `s.7, sch.4.pt.I`, `s.8, sch.4.pt.II` and `s.9, sch.4.pt.III`.
- **Corpus count:** 56 stored rules in 16 orders (7 Acts) quote "Schedule N to this Order", e.g. SI 1991/2286 `sch.1` and `sch.2`.
- **Pilot `ar12_pilot`** (ERA 1996, with AR-05; no write):
  - unknown 477 → **319** (158 rows unknown → in force), undated_change 965 → 881, markup_conflict 44 → 41.
  - 777 label diffs: 229 rows gain a date and changed_by, 180 of them 1999-12-15 by EReA (ss.71–80, 57A–57B, 47C, 99, …). The rest are later changes on rows that now have a start.
  - Repeals now dated: s.199(3) and s.212(2) at 1999-12-15, s.209(7) at 1999-10-25. Before, they showed repealed from ERA's own start.
  - **Territory:** 3 repealed rows go E+W+S → blank, and s.236(2)(a)[NI] → NI by EReA. A record from an amending law carries no territory, which is AR-09's bug.
