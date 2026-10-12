---
session: 'LR-15: changed_by Gaps on Change Notes'
status: suspended
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "changed_by null when the note cites a bare SI number ('by 2002/794', 'SI 1992/2823') the register holds, no Citation markup, no effect"
    category: lat-change-facts
    module: AmendmentNote / ChangeFacts note fallback
    affected: 28 notes (recounted 2026-10-12; was 22)
    fix: "resolve bare YYYY/NNN against the register by the note law's series"
    status: open
---

# Session: LR-15 changed_by Gaps on Change Notes (SUSPENDED)

## Problem

200 change notes in 69 laws name the changing law in their text but have no `changed_by`:
- 101 (13 laws): the law changes itself — null by design (`ChangeFacts.not_self`);
- 4: "as inserted by" chains and the uksi/wsi twin 2018/647 (twin → LH-07);
- 95 (57 laws): no Citation markup and no matching effect, so only the note's text names the law:
  - 22 (3 laws) cite a bare SI number the register holds ("by 2002/794", "SI 1992/2823");
  - 73 name laws legal doesn't hold (e.g. General Rate Act 1967, Water Consolidation (Consequential Provisions) Act 1991).
EU "by Regulation (EC) No …" notes (LH-08): 32 now; the 11 with no changed_by are Official Journal footnotes or editorial notes — correct.

## Suspended (2026-10-12)

Jason: the reliance on notes is systemic; architecture before bug fixes. This session's 28 notes are one class of LR-20's inventory: a note pointing at a law the feed confirms (5) is an effect-join fix (LR-19); the rest have no data behind them (LR-20 rule / LR-08). D2 (known limit for laws legal doesn't hold) stands. **Resume** only if anything is left after LR-21.

## Todo

- ✅ Recount (2026-10-12, Python; the earlier SQL count was wrong — in PostgreSQL a lazy quantifier makes the whole pattern lazy, so "by 1993/1897" read as "1993/1", a real SI): 90 change notes name a changing law but have no changed_by and no Citation; 28 cite an SI by number only, and the register holds it
- ✅ Whose data (Jason's question): legislation.gov.uk's editorial markup — see Answers
- ✅ D2 decided (Jason 2026-10-12): known limit — the changing law isn't in the register; legal scopes EHS and HR laws and doesn't parse the whole legislation.gov.uk corpus
- ✅ New finding split out: changed_by from the latest joined effect, not the note's own Citation (1,716 notes / 176 laws) → LR-19
- ⬜ Jason decides D1 (fix the 28)
- ⬜ If fix: tests first (bare "YYYY/NNN", "S.I YYYY/NNN", "SI YYYY/NNN" after " by " resolve against the register in the note law's series); classified diff (only these notes change); re-parse the affected laws: dry run → Jason → apply

## Answers (2026-10-12)

**Whose data is it?** legislation.gov.uk's. Its editors normally wrap the changing law in a `<Citation URI=".../id/uksi/2000/1973">S.I. 2000/1973</Citation>` element, which we read (`citation_law`, LR-05). On these notes they typed it as plain text, often in a non-standard form — and neighbouring notes in the same law are marked up:
- 1993/11 s.31(4)(a): `by <Citation …uksi/2000/1973>S.I. 2000/1973</Citation>`; s.31(4)(b): plain `by S.I 2000/1973` (no dot after I, no markup)
- 1954/70 s.182(2): `by <Citation …uksi/1993/1897>`; ss.2–20, 60, 91: plain `by 1993/1897` (no "S.I.")
- 1995/21 s.15(6)(a): plain `by 2002/794`
- 1988/52 s.15(3A): plain `by S.I 1992/3105`; s.15(4): marked up
The changes feed holds no matching effect for these notes either, so neither source gives the changing law in structured form; only the note's text does.

**"A bare number the register holds"**: the note names the SI by year/number only ("2002/794", or "S.I 2000/1973" — not the form our note reader expects), and `legal_register` has a record for it (`UK_uksi_2002_794`). So the changing law can be resolved to a law we hold; our note reader just doesn't recognise the form.

| Class (90 notes) | Notes |
|---|---|
| SI by number only, in the register (fixable) | 28 |
| SI by number only, not in the register | 1 |
| Act by short title (mostly old Acts legal doesn't hold) | 14 |
| Act by year and chapter ("1990 c. 43", often inside "as substituted by" chains) | 8 |
| SI by title | 3 |
| Other (OJ footnotes, "fully exercised by SR 1983/165,376", editorial) | 36 |

Plus 101 notes where a law changes itself: null by design (`ChangeFacts.not_self`).

## Decisions for Jason

- **D1 — Fix the 28** (recommended): read "YYYY/NNN", "S.I YYYY/NNN", "SI YYYY/NNN" after " by " as an SI number and resolve it against the register in the note law's series. Under the authority order this is a note-derived fact (`fact_provenance` = note), the fallback where markup and effects are silent
- **D2 — DECIDED: known limit** (Jason 2026-10-12) — the remaining 62 name laws legal doesn't hold or aren't changes (we scope EHS and HR laws, not the whole corpus); the 101 self-changes are null by design

## Dependencies

- ✅ LR-06 wave 4 applied and verified
