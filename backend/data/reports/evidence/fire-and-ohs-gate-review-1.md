# Fire and OH&S: Evidence, gate review 1 (2026-11-15)

The gate left 26 groups not named: 18 in the round (49 changes) and 8 in the switched families (25 changes).
- **How they were read:** each was read in the sources' own records: the feed effect (Type, affected and affecting provisions), the markup's note, the amending words, and the commencement rule and its source text.
- **Dump:** `dump_ev.exs`, `notes.py` and `stages.exs` in the session scratchpad.
- **Result:** the evidence table's order was right on every group. The wrong chosen values are misread claims: 11 by the Feed reader, 11 by the Commencement reader, and 3 one-change forms.

## One shape in all four gates: a substitution's new numbers, inserted (8 groups, 30 changes)

"operation: markup substituted against feed inserted" is new since Environmental Protection's Evidence. It comes from the Feed reader's Fix 8 (RULES `feed-substituted-for-new-numbers-inserted`, 2026-11-13). Where the feed's Type says what was substituted for, the targets under numbers the Type does not name are inserted. The markup wraps the whole new text in one Substitution. The feed's inserted is chosen.

The D rise in Occupational (38 → 42) and Maritime (13 → 23) is this shape: Occupational's three groups and Maritime's ten changes.

| Amending law | Changes | Feed Type / note | Verdict |
|---|---|---|---|
| SI 2023/284 (round) | 3 | "Reg. 7(1)-(1C) substituted for reg. 7(1)" | (1A)–(1C) new: inserted, right |
| SI 2017/1149 (Maritime) | 8 | "Regs. 6-6D substituted for reg. 6", "7-7D for 7" | 6A–6D, 7A–7D new: right |
| SI 2022/1219 (Maritime) | 1 | "Reg. 5(2)(d)(e) substituted for reg. 5(2)(d)" | (e) new: right |
| SI 2023/246 (Maritime) | 1 | "Reg. 3(4)(4A) substituted for reg. 3(4)" | (4A) new: right |
| SI 2002/2174 (Occupational) | 1 | "Reg. 6(1)(1A) substituted for reg. 6(1)" | (1A) new: right |
| SI 2019/556 (Occupational) | 1 | "Art. 15(1)(1A) substituted for Art. 15(1)" | (1A) new: right (the rule's own example) |
| NISR 2010/187 (Occupational) | 1 | Type "substituted for reg. 8(5A)-(5C)" over "reg. 8(5A)-(5D)" | (5D) new: right (the note words it the other way round) |
| **SI 2015/479 (Environmental Protection)** | **11** | "s. 153(1)(a)-(nn) substituted for s. 153(1)(a)-(aaa)" | **wrong** |

**SI 2015/479 on EPA 1990 s.153(1)(ii) and (qq)–(zz) (11 changes) is a Feed reader misread.**
- **The fault:** `FeedSubstitutedFor.rank/2` compares the letters of a range as plain text. So "qq" or "ii" sorts after "aaa", and lands outside "(a)–(aaa)". Each of those numbers then reads as new, and is inserted.
- **The right reading:** every one of them lies inside the old range, so each is substituted (or, in England and Wales, dropped). A letter range should count as a, b, … z, aa, bb, …
- **Owner:** the Feed reader's code, over the triage size (11 changes). It is parked as `substituted-for-letter-range-ranked-as-text`. The gate shows it only where the markup disagrees, so the full reach is unknown.

## Commencement against the feed (7 groups, 29 changes)

| Group | Changes | Records | Verdict |
|---|---|---|---|
| commenced_by @ asp 2012/8 | 7 | FSA 2005 ss.43A–43G (s.119). The feed has one stage, 1 Jan 2013 "for purposes", by SSI 2012/333. The law's commencement is 1 Apr 2013 by SSI 2013/51. The dates are not flagged: the like-for-like rule | Known: the feed's commenced_by is its first, limited stage's order, and the law's full one is chosen and right |
| date @ asp 2012/8 | 4 | FSA 2005 ss.39A–39C, 41M (ss.113, 117). s.129(1) brings them in on 8 Aug 2012 only "in relation to" some purposes; they are wholly in on 1 Apr 2013 by SSI 2013/51. The feed dates them 8 Aug 2012, complete | Known: the law's full date is chosen and right; its first stage is carried (`commencement.stages`) |
| commenced_by @ 2022 c.30 | 6 | SI 2005/1541 regs 21A, 22A, 22B, 22(1)(za), (zb), 22(A1). On 1 Oct 2023, SI 2023/362 commenced them for E and WSI 2023/914 for W | Known: one day, two orders by territory (the form named for 2003 c.38). Either order is right for its territory, and the stages carry both |
| commenced_by + date @ 2004 c.20 | 4 + 4 | Pipe-lines Act 1962 ss.10B, 10C(1); Petroleum Act 1998 ss.17A, 17B: repeals by s.151(5)(b) and Sch.23. SI 2004/2575 Sch.1's item "Schedule 23 Part 2 – paragraph 2" is held with `sch.23` whole in its scope. So the repeals take 5 Oct 2004 by SI 2004/2575, while s.151(5)(b)'s claim (14 Aug 2006 by SI 2006/1964, the feed's) loses as the second commencement claim | **Wrong date and commenced_by:** the Commencement reader's. A new form of `order-in-list-read-whole`, parked. 1 rule corpus-wide, 8 changes |
| date @ SI 2018/797 | 3 | Petroleum Act 1998 s.45A(9), (9A), (10). reg.1(2)(b) says "on the twenty-first day after … made or, if later, the 1st October 2018"; it was read as the 21st day (18 Jul 2018) | **Wrong date:** the Commencement reader's, new class `if-later-date-unread`. 5 rules corpus-wide hold "if later"; this one is wrong for 3 changes |
| date @ SI 2023/320 | 1 | SI 2023/284 reg.1(2). SI 2023/320 comes into force on 5 Apr 2023 (reg.1(1)); the feed dates it 6 Apr, the amended law's start | Known: the law's date is right (the form named for SSI 2025/28) |

## Markup against feed, and the rest (11 groups, 15 changes)

| Group | Changes | Verdict |
|---|---|---|
| operation: markup substituted against feed renumbered @ SI 2016/315 | 6 | By design: the feed's renumbered wins (SI 2014/1638 regs 78–83) |
| by: markup against feed @ asp 2012/8 | 3 | Known: one note for two laws by territory. The definition in 2004 c.21 s.35(6) was "added (E.W.) by S.I. 2013/602 … (S.) by asp 8 Sch.7 para.66(3)". The change is the Scottish one, and the feed's asp 2012/8 is right |
| by: markup against feed @ SI 2020/852 | 1 | By design (the "as amended by" chain): SI 2020/852 amends SI 2019/696 before it came into force (SI 2018/389 reg.1(2)) |
| level: markup provision against feed words @ SI 2020/852 | 1 | Known, one change, the chain: the markup is SI 2019/696 Sch.16 para.28's whole substitution of Pt 13 Sub-Pt C, as amended by SI 2020/852; the feed's words is SI 2020/852's own change inside it. Both fall on 31 Dec 2020 (SI 2014/1638 reg.69) |
| level: markup provision against feed words @ asp 2012/8 | 1 | Known, one change: FSA 2005 Pt 2 Ch 8C's heading "substituted for s.45 cross-heading". The markup wraps the new heading whole; the feed's words is right for a heading (the cross-heading known limit's twin) |
| level: markup provision against feed words @ NISR 2015/325 | 1 | **Wrong level, one change:** apni 1929/13 s.24A(a). A legacy markup record whose note cites SR 2000/93 (another law's insertion) is joined to the feed's "words substituted", and its provision level is taken. The feed's words is right. A known limit (one change; legacy markup names no effect) |
| operation: markup repealed against feed repealed_in_part @ 2003 c.44, SI 2010/807 | 1 + 1 | By design: the feed's "in part" outranks a whole-provision Repeal (Jason 2026-10-11) |
| operation: markup inserted against feed repealed @ SI 1996/973 | 1 | By design: a legacy markup Addition for a repeal ("ceased to have effect (S.)", 1962 c.58 s.37(4)(b)) |
| territory: law_text against markup @ asp 2012/5 | 1 | Known: the law's text is right. An Act of the Scottish Parliament's insertion applies in S; the markup's E+W+S is the provision's extent (1998 c.17 s.5(9)) |
| operation: law_text repealed against feed repealed_in_part @ 1999 c.28 (Environmental Protection) | 1 | Known: like for like. The feed's "repealed in part" is of s.42, and the law repeals s.42(3)(b)(ii) whole; the law's repealed is chosen and right (1995 c.25) |

## The parked bug: `stages-no-evidence-rule`

The stages are claimed by two sources. The feed has `feed.stages` (Feed reader, Decision 3). The commencement has `commencement.stages`, the law's own stages, such as asp 2012/8's 8 Aug 2012 limited start.

| Scope | Changes with `feed.stages` | Date from the feed | Date from the commencement | Changes with `commencement.stages` |
|---|---|---|---|---|
| The round | 124 | 93 | 31 | 120 |
| Environmental Protection | 115 | 86 | 29 | 324 |
| Occupational | 16 | 4 | 12 | 119 |
| Maritime Safety | 2 | 2 | 0 | 31 |

In 72 changes the law's commencement dates the change and the feed also carries stages. If the fold read `feed.stages` there, it would put legislation.gov.uk's dates over the law's. That would be the same fault `partial_with_date` prevents for `partial`.

**Proposed fix:** the chosen stages are the date's own source's. Where the commencement won they come from `commencement.stages`, and where the feed won from `feed.stages`. They are given as `Resolved.stages`, worked out on read in `Evidence.derive/1`, like the tiers, so there is no column and no migration. The Label fold's `stages-not-folded` then reads `resolved.stages`.
