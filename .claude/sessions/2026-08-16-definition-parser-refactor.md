---
session: Definition Parser Refactor
status: pending
opened: 2026-08-16
---

# Session: Definition Parser Refactor (PENDING)

## Problem

The definition parser has 3 strategies with implicit priority, conditional execution, and dedup split between parser and persister. Strategy 3 computes `references_other_law` from the wrong text scope (full P2 text instead of individual definition text), causing incorrect flags when a P2 contains a Definition list with mixed cross-ref and standalone definitions.

## Todo

- ⬜ Add `:source` key to every definition map (`:definition_list`, `:inline_text`, `:section_term`)
- ⬜ Skip P2s containing `UnorderedList[@Class='Definition']` in Strategy 3
- ⬜ Run all three strategies unconditionally (remove `if results == []` guard on S2)
- ⬜ Single `deduplicate/1` function with explicit priority: S1 > S2 > S3
- ⬜ Remove persister's `Enum.reduce` dedup — parser guarantees uniqueness
- ⬜ Update test counts, add `:source` provenance assertions

## Dependencies

- ✅ Definition Backfill & QA session (current) — surface bugs that motivate this refactor
