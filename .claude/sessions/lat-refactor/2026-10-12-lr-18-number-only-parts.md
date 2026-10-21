---
session: 'LR-18: Number-only Parts and Headings'
status: pending
release: v0.1
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-18 Number-only Parts and Headings (PENDING)

## Problem

67 Part, Chapter and heading rows have empty text and no title: their XML holds only a `<Number>` (e.g. 1984/22 Part III "Part III", no Title; 1994/1768 Parts I–III; nisr 2024/201 Parts 1–6). Other Part rows carry their heading as text. The number is in the id, so nothing is lost, but the row reads as blank.

## Todo

- ⬜ Confirm all 67 have only a Number in the XML
- ⬜ Decide: known limit, or text = the Number ("PART III") test-first

## Decisions for Jason

- **D1 — Known limit, or carry the Number as text**

## Dependencies

- ✅ LR-06 wave 4 applied and verified
