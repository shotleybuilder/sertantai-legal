---
session: 'LR-16: Non-text Inserts'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "LAT misses inserted/substituted text: 3,483 provisions end 'insert—/substitute—' with no body, and schedules are present for only 84 of 910 LAT laws"
    category: lat-amending-text
    module: scraper/lat_parser.ex
    affected: 22
    fix: "fixed by #174 and waves 2-4: 3,483 → 22 rows / 14 laws; the residue inserts forms, formulae or images (no text); schedules: LR-10"
    status: fixed
  - pattern: "Amending provisions that insert a form, formula or image end 'insert—/substitute—' with nothing after: the inserted object isn't text"
    category: lat-amending-text
    module: scraper/lat_parser
    affected: 22 rows / 14 laws
    fix: "known limit, or a placeholder naming the object (e.g. «[formula]», «[form]»)"
    status: open
---

# Session: LR-16 Non-text Inserts (PENDING)

## Problem

The old bug (QQ-00: 3,483 provisions ending "insert—/substitute—" with no inserted text) is down to 22 rows in 14 laws after #174 and waves 2–4. What's left inserts something that isn't text: forms (2023/588 CAA Forms 15b, 52, 65), formulae (2016/257 reg.23(2)(a) "for the formula 'B x C' substitute—"), images, tables of images. A reader sees an amending provision that ends mid-sentence.

## Todo

- ⬜ List the 22 rows with what each inserts (from the store)
- ⬜ Decide: known limit, or a placeholder naming the object (`«[formula]»`, `«[form]»`) test-first

## Decisions for Jason

- **D1 — Known limit or placeholder**

## Dependencies

- ✅ LR-06 wave 4 applied and verified
