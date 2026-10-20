---
session: "AR-10: RTA 1988 s.92 Insertion Recheck"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
bugs:
  - pattern: 'RTA 1988 9 rows: in_force_from moved 1992-07-01 → 1988-11-15 when an undated "insertion of s.92" by RTA 1991 is no longer read; s.92(1)''s 2009 words substitution never dates it'
    category: amending-law
    module: AmendingLaw.Target (deleted)
    affected: 9
    fix: 'not a fault: RTA 1991 s.18(1) added s.92(10) only (note F:c13981151), so 1992-07-01 on s.92 and its other rows was the old matcher''s error; 1988-11-15 is right for them'
    status: fixed
  - pattern: 'An instruction quoting with "there shall be added—" gives no quoted rule: AR-08''s quoting_clause matched only insert / substitut (RTA 1991 s.18(1): s.92(10) unread)'
    category: amending-law
    module: Amendment.Reader
    affected: '≤240 "added" notes in 79 laws (124 amending laws)'
    fix: 'quoting_clause also matches "added"'
    status: fixed
  - pattern: 'Change markup whose Addition has no CommentaryRef attribute (the note ref a sibling <CommentaryRef Ref=…/> in the same Pnumber/Text) gets no pointer, so a dated law record never explains it and T1 blanks the row (RTA 1988 s.92(10): d29p11612 / c13981151)'
    category: lat-parse
    module: LatParser.Effects
    affected: '227 markup records with no pointer; 95 rows with a dated law record beside one'
    fix: 'take the preceding sibling CommentaryRef in the same parent when the Addition / Substitution / Repeal has none'
    status: open
  - pattern: 'A feed effect on a provision is also placed on its ancestors (via whole) with its whole-provision operation, so the projection versions every row under the ancestor: each sibling insertion into s.153(1) (SSI 2024/371 z10) re-versions s.153(1)(q)…(vv); hidden while T1 blanked them'
    category: label-projection
    module: ChangeCollector.Feed / LabelProjection
    affected: '10 rows in the 6-law pilot (1990 c.43 s.153(1)); corpus unknown'
    fix: 'an ancestor''s record whose affected_ref names a descendant versions only that descendant, never its siblings'
    status: open
---

# Session: AR-10: RTA 1988 s.92 Insertion Recheck (ACTIVE)

## Problem

RTA 1988 9 rows: in_force_from moved 1992-07-01 → 1988-11-15 when an undated "insertion of s.92" by RTA 1991 was no longer read (LR-41 open bug, module `AmendingLaw.Target` — deleted by AR-04); s.92(1)'s 2009 words substitution never dates it. Recheck under the ruleset.

## Todo

- ✅ Recheck on the ruleset: RTA 1991 s.18(1) "at the end there shall be added— (10)" added s.92(10) only; the 9 rows' 1988-11-15 is right (the old 1992-07-01 was the matcher's error)
- ✅ Fix at source: AR-08's `quoting_clause` missed "added" — s.92(10) now inserted 1992-07-01 (SI 1992/1286); pilot 6 laws vs control
- ⬜ s.92(10)'s label still blank: its markup has no pointer (sibling CommentaryRef) — LAT parser `Effects` (Jason: here or a stub)
- ⬜ Ancestor `whole` placement versions sibling rows (1990 c.43 s.153(1)(q)…) — fix before the measure run (Jason: here or a stub)

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)

## 1. Recheck

Note F:c13981151: "S. 92(10) added (1.7.1992) by Road Traffic Act 1991 (c. 40), s. 18(1); S.I. 1992/1286". The instruction: "In section 92 of the Road Traffic Act 1988 (physical fitness of drivers) at the end there shall be added— (10) …". So the old matcher's "insertion of s.92" dated the whole section and 8 rows wrongly; LR-41's move to 1988-11-15 corrected them. The stored rules had no rule for section-18-1 at all.

## 2. Fix: "added" quotes

AR-08's `quoting_clause` picks the quote's clause by `insert|substitut`; "there shall be added—" matched neither, so the quote was dropped and an insertion reaches only what it quotes → no rule. Now `insert|substitut|\badded\b` (test: "at the end there shall be added— (10)" → s.7(10) inserted provision). Read: RTA 1991 s.18(1) → s.92(10) inserted; collector: inserted 1992-07-01 by SI 1992/1286.

Pilot `ar10_pilot` vs `ar10_ctl` (reader stashed), 6 laws (1988 c.52, SI 1986/1078, 1990 c.43, 1991 c.57, 1991 c.56, 1980 c.45): 29 label diffs only with the fix —
- 1991 c.57: s.190(1A) 1996-12-31 (1995 c.25), s.190(4) 2013-04-01, s.135(7) / s.96(4) gain status + E+W — right. s.92(3), s.169(4), s.172(3A) in force → partial: dated by SI 1996/186 reg.3's Sch 22 list, which carries "in_relation_to" from one item ("29(1) in so far as … not already in force") — the open CR-06 qualifier-over-list bug, not the reader.
- 1990 c.43 s.153(1)(q)…(vv), 10 rows: changed_by SSI 2024/371 2025-02-06 — wrong. The "added" read dates (q) (SI 1993/1062 art.2, 1993-05-12), which explains its markup and lifts T1; that exposes the pre-existing chain of versions from sibling insertions placed on s.153 via `whole` (bug logged).
- RTA 1988 s.92(10): the timeline period now starts 1992-07-01 (was 2016-01-04), but in_force_from / changed_by stay blank under T1: its markup `d29p11612` has no pointer (bug logged). The today-label diff can't see valid_from.
