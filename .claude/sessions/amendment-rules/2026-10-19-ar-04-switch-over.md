---
session: 'AR-04: Switch-over'
status: active
bugs:
  - pattern: 'Parent placement left the note''s row with no record: the label timeline saw a dated change by the law on an ancestor, dropped the row''s undated_change gap, and fell back to the law''s start — a confident wrong date (Electricity Act s.42(1)(b): 1989 for text changed in 2001)'
    category: amending-law
    module: Amendment.Collect
    affected: 'up to 165 rows (the parent placement class)'
    fix: 'the change lands on the provision named and on the note''s row inside it (Jason option a)'
    status: fixed
  - pattern: 'A rule reaching a row through an ancestor (bracket set semantics: a repeal of (1)(c) also targets (1)) wrote a whole "repealed" on the ancestor and the note''s row — the projection would mark both repealed'
    category: amending-law
    module: Amendment.Collect
    affected: 'caught in test before any write'
    fix: 'through an ancestor both records are words-level; a rule naming the row itself wins'
    status: fixed
  - pattern: 'A section named at the start of a sentence ("Section 42 of the 1989 Act is amended as follows.") gave no section number: the kind word matched lower case only (same in the deleted Target) — every sub-provision instruction under such a lead read no rules'
    category: amending-law
    module: Amendment.Reader.numbers
    affected: 'unknown until the corpus preview (2000 c.27 s.57(2) among them)'
    fix: 'kind word case-insensitive'
    status: fixed
opened: '2026-10-19'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-04: Switch-over (ACTIVE)

## Problem

Amendment ruleset (AR-00 meta): labels still come from the old row matcher (`ChangeCollector.AmendingLaw` → `AmendingLaw.Target` / `RepealTable`), re-parsing every amending law per law collected. AR-03 built the reader, the stored rules and a store-backed collector (corpus gate: 0 lost, 101 relabels, 165 parent placement — Jason, 93 new). Switch the change register onto them, delete the old matching, one corpus run, Jason, apply.

## Todo

- ✅ Read-pass index carries the reader version and the laws read for; the read pass re-reads a stale or missing index (not just a missing one)
- ✅ `ChangeCollector.amending_law/4` onto `Amendment.Collect`: stored source when the index is current and covers the law, else the document read as before (no silent loss for an amending law not yet read)
- ✅ Delete `ChangeCollector.AmendingLaw`, `AmendingLaw.Target`, `RepealTable` (its `reference/2` into the reader), `RowRef`; port the LR-08 collector tests onto `Amendment.Collect`
- ✅ Architecture test: only `Amendment.Reader` reads instructions into changes (no row matcher)
- ✅ `Commencement.Evaluator` onto `LatRef` (chain / covers?) — behaviour-preserving, its tests unchanged
- ✅ `LabelVersion`: `scraper/amendment/*.ex`, `lat_ref.ex`; `provision_qualified` catalogue text (AR-00)
- ✅ Full suite (2,880); commit `dab2ea1a`
- ✅ Read pass under the new reader version (every index stale) — and again after the "Section" fix (`9db8483b`)
- ⬜ Dry run: relabel preview on a few laws, then the corpus (one run); classify the label diff
- ⬜ Jason; restore point (`--tables lat_change_log … --tag`); apply; tell nobody until Jason says (compliance / fractalaw)

## Dependencies

- ✅ AR-00 schema decided (2026-10-19)
- ✅ AR-03 reader, store-backed collector, read pass (closed 2026-10-20)

## Design (2026-10-20)

**Stored rules or the document.** The read pass reads each amending law once for the LAT laws its notes point to *at that time*. A law LAT-parsed later, an amending law first cited later, or rules read by an older reader would silently lose records if the collector only read the store. So the index records `reader` (a hash of the reader's code) and `laws` (the laws read for); the collector uses the stored rules only when both hold, else reads the document as the old collector did (parsed once per law's collection). The read pass re-reads an index whose reader is stale (AR-03 lesson: it skipped by file existence).

## Switch-over (2026-10-20, `dab2ea1a`)

- `Reader.read/4`, `references/1`, `reference/2` moved into the reader (`Collect.read/3` memoises terms only), so `ReaderVersion` counts what a rule depends on (reader, rule, `Doc` / `Text` / `Operation` / `DefinedTerms` / `Locator` / `Pointer`), not the collector.
- Ported, not dropped: the `Target` / `RepealTable` cases run on `Reader.of_text/5` + the evaluator in the matcher's shape; the LR-08 collector tests on `Collect` (`collect_records_test.exs`); the old collector's records on the fixtures pinned (`collect_test.exs`). Three assertions changed — a row inside the provision named now reaches that provision (Jason "Parent"): NRSWA s.148(3)(a), EPA s.6(2)(a), Electricity Act s.11A(7)(b). One caught a reader bug: "at the end of the subsection there shall be added the following paragraph—" is a provision, not words (fixed: the at-the-end rule needs no kind of provision named).
- `provision_qualified` catalogue entry: starts its rows partly (CR-03), text and flag corrected.

**Streaming XML after AR-04** (Jason 2026-10-20: "agree to finish ar-04 first"): LR-45 would save minutes on AR-04's remaining runs (read pass, one preview, apply) for days of work; memory is flat one law at a time; an XML-layer change in the same corpus run would confound the label diff; LR-45 Phase 1's gate (identical rules for every amending law) needs the reader settled. LR-45 starts after the apply.

## Pilot preview (2026-10-20, 4 laws: EPA 1990, Electricity Act 1989, FEPA 1985, Building Act 1984)

- **Pilot 1:** 9 label diffs, 8 right (gains: dated changes now read). 1 wrong: s.42(1)(b) took the law's start, 1989 (bug 1 above) → **Jason: option (a)**, the change on the provision named and on the note's row.
- Tracing (b) found bug 3 (no rules under "Section 42 … is amended as follows"); writing (a)'s test found bug 2 (whole repeals through an ancestor) before any write.
- **Pilot 2** (option (a) only): 380 diffs, almost all gains (191 changed_by, 190 effective_from); Electricity Act undated_change 390 → 216.
- Pilot 3 (all three fixes): running after the read pass.
