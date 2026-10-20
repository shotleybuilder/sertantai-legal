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
    status: fixed
  - pattern: 'A feed effect on a provision is also placed on its ancestors (via whole) with its whole-provision operation, so the projection versions every row under the ancestor: each sibling insertion into s.153(1) (SSI 2024/371 z10) re-versions s.153(1)(q)…(vv); hidden while T1 blanked them'
    category: label-projection
    module: ChangeCollector.Feed / LabelProjection
    affected: '10 rows in the 6-law pilot (1990 c.43 s.153(1)); corpus unknown'
    fix: 'an ancestor''s record whose affected_ref names a descendant versions only that descendant, never its siblings'
    status: fixed
  - pattern: 'A row''s own words-level omission ("word omitted") does not start a version: 1986 c.44 s.23C(2) by 2013 c.24 (2014-04-01) was dated only through the sibling s.23C(2A) insertion on s.23C; with that cut it shows 2011 (also 1991 c.56 s.159(2)(a), s.99(2A)(a)) — cause unverified'
    category: label-projection
    module: LabelProjection
    affected: '3 rows in the 10-law pilot'
    fix: 'trace why an own repealed / "word omitted" change is not a version (covers_row? or period split)'
    status: open
---

# Session: AR-10: RTA 1988 s.92 Insertion Recheck (ACTIVE)

## Problem

RTA 1988 9 rows: in_force_from moved 1992-07-01 → 1988-11-15 when an undated "insertion of s.92" by RTA 1991 was no longer read (LR-41 open bug, module `AmendingLaw.Target` — deleted by AR-04); s.92(1)'s 2009 words substitution never dates it. Recheck under the ruleset.

## Todo

- ✅ Recheck on the ruleset: RTA 1991 s.18(1) "at the end there shall be added— (10)" added s.92(10) only; the 9 rows' 1988-11-15 is right (the old 1992-07-01 was the matcher's error)
- ✅ Fix at source: AR-08's `quoting_clause` missed "added" — s.92(10) now inserted 1992-07-01 (SI 1992/1286); pilot 6 laws vs control
- ✅ Markup pointer (Jason: here): `Refs.change_refs/1` — a change's note ref by ChangeId, from its attribute else the CommentaryRef just before it; unjoined markup takes it. Pilot: 28 rows gain dates (s.92(10) 1992-07-01 RTA 1991)
- ✅ Ancestor placement (Jason: here): `LabelProjection.relevant/2` — an ancestor's record reaches a row only when its affected_ref is the row or above it; a list or range reaches its members only; unparsed refs reach all. Pilot: ~1,630 rows, 1,400 of 1,403 lost dates came only via a sibling; 167 false repeals gone (markup in force)

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

## 3. Markup pointer (Jason: fix here)

`Refs.change_refs/1` maps each ChangeId to its note: the Addition / Substitution / Repeal's CommentaryRef attribute, else a CommentaryRef element just before it in the same parent; the walker fills an unjoined change's nil ref from it (the Text occurrence of d29p11612 carries neither). Only the markup collector reads `unjoined_changes`; relabel re-parses from the store, so no LAT re-parse. The effects-index join (`Effects.change_occurrences`) still reads the attribute only — left alone (a wider join change).

Pilot `ar10_fix2` vs `ar10_ctl2` (10 laws; control = HEAD with the reader fix): 56 diffs only with the fixes, 0 only in the control — 28 rows gain changed_by / effective_from, all T1 rows whose markup now meets its dated law record: RTA 1988 s.92(10), s.94(3A), s.40A, s.45(3)(b), s.67(1)(a), s.67(2) (RTA 1991, 1992-07-01), s.92(7D) (2003 c.32, 2004-10-11); 1990 c.8 (1991 c.34) 16 rows; 1984 c.27 4 rows; 1991 c.57 s.135(7) (1992 c.14).

## 4. Ancestor placement (Jason: fix here)

The projection's `relevant/2` counted every non-words change on an ancestor; the feed places an effect on the ancestors of the provision it names (`whole`), so a sibling's insertion versioned (and, via LR-30, dated the insertion of) every row under the ancestor. Now an ancestor's record whose `affected_ref` reads as one provision reaches the row only when that provision is the row or above it. A ref listing siblings ("s. 33(9)(10)", "(h)(i)") or not read as one provision (ranges, Parts, Schedules) reaches every row as before. First pilot showed no change: `LabelTimeline` didn't select `affected_ref` — added.

Rule as built: `affected_ref` read as {path, members} — "s. 153(1)(z10)" the path s.153(1)(z10); a list "s. 153(1)(z8)(z9)" / "s. 33(9)(10)" its parent and members; a range "s. 153(1)(a)-(nn)" its parent and an ordered range (numbers, letters by length, romans by value). The row counts the record only when it is the path or under it (for a list / range: under a member). Not read ("ss. 92-94", "Pt. 2B", "s. 161 heading", Schedules): reaches every row as before. A record naming a provision under the row never versions the row (AR-04 option c).

Pilot `ar10_fix4` vs `ar10_fix2` (same 10 laws, pointer fix in both): 3,255 diffs only with the rule, 28 gone (s.102(9) of 1984 c.27: dated by its own laws, 1991 c.40 1993-07-05 / 2004 c.18 2008-03-31, not SI 2008/2367's sibling change). Classes: effective_from moved 1,252; changed_by changed 868 / emptied 535; repealed(_saved) → in_force 170 and the rows' markup says in force for all 167 checked (e.g. "s. 61A(1) repealed" placed on s.61A had repealed s.61A(3)(b); "s. 87C(8) omitted" had repealed s.87C(2)); in_force → unknown 42: J5 rows (inserted, undated) that had taken a sibling's insertion date (1990 c.43 s.161(5): Part VIII's s.153(1) insertions). Check: of 1,403 rows losing a changed_by law, 1,400 had no record by that law on the row — the date came through an ancestor only. The 3 others logged (own "word omitted" not a version).

Suite 2,925 pass. Corpus: the measure run counts it.
