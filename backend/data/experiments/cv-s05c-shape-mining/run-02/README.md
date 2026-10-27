# CV-S05c census: run-02, after CV-S05 round 11 (2026-10-27)

This run uses run-01's scripts unchanged (their checksums are in the manifest), on the reader as of code `e28dfe96`. The population is 3,040 extent sentences from 3,358 laws.

## Against run-01

| Measure | run-01 | run-02 |
|---|---|---|
| Items read (lettered list items) | 801 | 851 |
| Withheld (deliberately unread) | 34 | 50 |
| Not held: missing / unread / partial | 69 / 25 / 2 | 13 / 16 / 4 |
| Laws with a drop in a sentence read as a list | 33 | 10 |
| Over-reach hits (excluded, qualified, scope) | 14 (5 real) | 4 (all known check limits) |

## The 10 laws still flagged, traced

**Not drops: known, counted.** Two kinds:
- *Known in run-01:*
  - 1975/21 s.463 and uksi 2019/696 reg.3: sub-lists of amendments by the Act amended; exceptions held as `not NI`.
- *Artefacts of the per-item check:* the reader's lists are right in every case.
  - 1986/50 s.87: s.66 is withheld, and the check parsed the qualifier's object.
  - 2000/19 s.87: the excepted s.82 and s.83 are out of the list, which is right.
  - 2004/20 s.198 and 2020/21 s.56: the check's own exclusion words lack "with the exception of" and "apart from", while the reader honours them.
  - 2009/23 s.323(4)(f): the check counts the Chapter, while the reader holds only the sections.
  - 2021/30 s.146: Schedule 15 is now `same` only; run-01 also had it, wrongly, in the UK list.

**Real, residual (3 items in 3 laws):**
- **2009/23 s.323(2)(f)(iii)**, "section 314 (which inserts Part 4A into the Energy Act 2008 (c. 32))": dropped. `ListItems`' other-law test matches "into the … Act" because it has no word boundary.
- **2015/7 s.56(2)(b)**, "an amendment or repeal made by Part 1, other than the amendment made by section 17(7), has the same extent as the provision to which it relates": a same-extent item with its own exception, unread.
- **2008/4 s.152(c)**, "section 113 (together with such of the other provisions of Part 7 as relate to …)": s.113 dropped along with its describing bracket.
