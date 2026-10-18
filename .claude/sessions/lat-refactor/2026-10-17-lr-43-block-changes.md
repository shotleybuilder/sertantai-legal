---
session: 'LR-43: Block Changes'
status: pending
opened: '2026-10-17'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-43 Block Changes (PENDING)

## Problem

An instruction inserting or substituting a block — a Part or Sub-Part, a run of sections, a subsection with its paragraphs — never reaches the provisions inside it, so their change stays undated (LR-41 sample: 61 of 159 target failures: no provision number named 37, another number 14, the row inside a named provision 10). SI 2014/1638 reg.76(1)(a): SI 2019/696 "For Part 13, Sub-Part C substitute—" quotes regs 69–76; NRSWA 1991 s.148(3)(a): "for subsection (3) substitute". After LR-41 (Jason 2026-10-17: "Law first, block next").

## Todo

- ⬜ D1: a block instruction reaches the rows inside it (the quote's paths; named brackets a prefix of the row's)
- ⬜ Build, tests, dry run, Jason, apply

## Dependencies

- ⬜ LR-41 (the law check runs first)
