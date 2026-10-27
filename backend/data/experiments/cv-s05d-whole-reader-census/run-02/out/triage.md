# run-02 triage: the 114 silent candidate sentences, by wording

Each candidate in `cands.txt` (index: verdict, law, ref, class, flags, sentence) was triaged by hand. The labels:
- **V**: confirmed with `Extent.of` (`verify3.txt`, `../run-01/verify*.exs`);
- **R**: real by reading the text against the stored rows (in no row, or in a row of another place), not yet confirmed with `Extent.of`;
- **F**: a finder miss;
- **K**: a known class;
- **D**: doubtful.

A `nil` bound is a law with no default whose provision is in no list: the change gets no bound (dropped). An E+W bound where the text gives more or less is a wrong bound.

## Real, by wording (the round 13 fix list)

| # | Wording | Laws (cands #) | Effect |
|---|---|---|---|
| S1 | Exception lists' items dropped: "This Act, except— …, does not extend to NI"; "Except for the following provisions …— …, this Act does not extend to NI"; "This Act does not extend to Scotland, with the exception of— …"; "X extend to NI; but, with the exception of those provisions, …" | V 1971/11 (15), 1972/62 (16), 1976/55 (19), 1996/25 (13), 1990/16 (23), 1995/45 (25), 1993/11 (24), 1981/69 (56, no default at all); R 1986/44 (20), 1988/19 (21) | The items get the default (E+W+S) where the text adds NI (or S). CV-S05c run-03 had labelled these KX ("by design"): wrong for the unqualified items. |
| S2 | Sub-letter runs lost: "2(1)(a) and (b)", "36(1), (2)(a), (b) and (d)", "19(2)(a) and (b)", "2(w)(i) and (ii)", "72(2)(a)(ii) and (iii), (b)(i) …", "34 (f)", "(3)(a)", "(2)(aa)" | V 2005/457 (28), 1998/37 (46), 1981/29 (40), 2024/437 (32), 2013/1506 (3), 1980/66 (2), 1990/8 (0); R 2022/1273 (29) | Wrong bound or none |
| S3 | "or"-lists in same-extent subjects: "Part 2, 3, or 4", "paragraph 12 or 46 of Schedule 2", "Part 3, 4 or 5 or the Schedule"; and "Part 1, 8 … of Schedule 18" read as the Act's own Parts (run-01) | V 2019/530 (54), 2022/6 (53), 2020/1540 (55), 2007/28; D 2000/29 (50) | Dropped, or wrong same |
| S4 | A bracketed or trailing qualified companion dropped, not withheld: "(and section 55 so far as …)", "(including Schedule 13 so far as it relates to …)", "(and article 26 in so far as …)" | V 2022/30 (95), 2023/55 (96, 97); R 2013/602 (101–103), 2005/2060 (98), 1980/34 (99), 1977/38 (100), 1972/71 (94) | The qualified provision gets the default, or none |
| S5 | The provision's own subsections or self in a list: "subsections (1) to (4), this subsection", "this subsection and subsections (1) to (3) of this section", "this section extends also to Scotland", "(v) this Chapter", "subsections (1), (3) and (6) to (10) of this section" | V 1992/43 (35), 1973/32 (37), 1998/31 (49), 2017/3 (30), 1977/45 (9); R 1988/19 (21) | None, or the default |
| S6 | Two statements joined by "and" or "or": "Sections 28 and 33 … do not extend to Scotland and sections 34 and 35 extend to Scotland only"; "not extend to Scotland or, . . . to NI" | V 1969/10 (42), 1968/64 (107), 1968/60 (106) | Wrong bound |
| S7 | A whole-law default misread or missing: "extends to Scotland (subject to …) and Northern Ireland"; "extends only to England and Wales, except that— …"; "Part 6 … extends to England and Wales, except that— …" | V 1999/28 (108), 2010/29 (110), 2021/30 (52) | Wrong default, or none |
| S8 | Application statements unread (the noise bin; territorial per the KA decision): "They apply in relation to— (a) England … (b) Wales", "apply in relation to live fish in Wales", "apply to buildings and building work in England", "apply to lessors of social homes in England", "Regulation 17 applies in relation to live fish … in Wales"; and the extent statement "Paragraph 3 of Schedule 10 extends to other parts of the United Kingdom" | R 2016/1154 (113), wsi 2014/3303 (112, 65), 2026/335 (109), 2025/1042 (111), 1978/29 (62) | No application bound |
| S9 | A qualified subject read whole: "this Part to the extent that it applies to those sections" | V 2006/41 (104); and the qualifier's object 2014/2 s.46 (run-01); D 1998/37 (105) | Wrong bound (over) |
| S10 | Repealed words (". . .") inside a number list: "except sections ... ... 101 and this section", "Sections ... 4, 5, ...", "Schedules ... 5 to" | V 1974/40 (18); R 1976/55 (43), 1972/62 (47) | The item is dropped |
| S11 | A Schedule locator read as the whole Schedule: "in Schedule 2, Part II and paragraph 11"; "in regulation 16, paragraphs (4) and (5)" | V 1977/38 (4), 2020/818 (1) | Wrong bound (over) |
| S12 | Same-extent item dropped: "(c) section 15 and Schedules 3 and 4 have the same extent as …" | V 1999/9 (45) | Wrong bound |
| — | One-offs | V 1985/71 (38: sch.2.para.10 → NI, the text lists it for Scotland), 1972/11 (33: sch.7 paragraphs none); R 1980/58 (10), 2009/462 (7, 11), 1967/80 (12) | |

## Finder misses (fixed next run)

| Cause | Cands # |
|---|---|
| A commencement or other law's provisions | 6, 27, 57–59 |
| A sub-list locator | 26, 36 |
| "with the exception of" inside brackets not taken as an exception | 41 |
| A garbled ref | 44 |
| "with the following modifications" | 61 |
| Things in a place (scope, not territorial) | 63, 92 |
| An arbitrator clause | 64 |
| A conditional power | 66 |
| "respectively" | 68 |
| Exception-class sentences about cases | 70, 71 |
| Two statements joined by ", and" (the finder takes the first's place) | 72, 78, 79, 80, 87 |
| Nested lists | 73 |
| "(as well as to …)" | 77 |
| An exception sub-list (`except` rows, by design) | 76 |
| A same-extent paraphrase ("extends to any part of the UK to which the amended enactment extends") | 88–90 |
| `first_clause` cut at ", except", which lost the negation | 91 |
| "outside the UK" | 93 |
| A range end with letters (`s.32N..s.32Z` covers `s.32Z1`) | 22 |

## Known

- 14: KD, numbers in words.
- 17: KX, HSWA s.84(1)(a).

## Doubtful (to check)

8, 67, 75 (2010/708, commencement order); 5, 31, 34, 39, 48, 50, 51, 69, 74, 81–85.

## Over-reach (`unnamed.tsv`: 516 refs, 83 laws): first pass

**Real:**

| Law | Wording | Effect |
|---|---|---|
| ukpga 2007/28 | "Part 1, 8 … of Schedule 18" | read as the Act's own Parts (109 refs, V run-01) |
| ukpga 2009/23 | "Chapters 1 to 5 of Part 8" | holds Chapter 6 (known) |
| Sub-letter runs (S2) | various | garbage refs: 1980/66 `s.264(a)`, 1990/8 `s.70(aa)` and `s.70(b)`, 1998/37 `s.36(b)` and `s.36(d)`, 2022/1273 `reg.72(b)(i)` …, 2024/437 `reg.2(ii)`, 1981/29 `s.19(b)`, 2013/1506 `reg.34`, 2020/818 `reg.16` and `reg.18` |
| ukpga 2023_55 Part 12 | "sections 228, 229 (and Schedule 22), 230, 233 to 236, 237 (and Schedule 23) …" | after the bracket, read as Schedules 230, 233 … (s.230, s.233 … lost) |
| ukpga 1972/20 | "except as provided by section 189" | read as an item (`also NI` s.189) |
| ukpga 2014/2 | s.46, a qualifier's object | read as UK (V run-01) |
| ukpga 2006/41 | "this Part to the extent that it applies to those sections" | read whole (S9) |

**Finder misses:**

| Law | Cause |
|---|---|
| 2002/17 | "except for Part 1, which extends to England and Wales only": the verb is in a relative clause |
| 1975/59 | the verb is in the last item ("…, b …, shall extend to Northern Ireland only") |
| 1987/43 | "the provisions of Part 1" |
| 2018/1370 | "the same application and extent" |
| 2014/20 | — |

**Unreviewed:** the rest go to run-03, after the finder fixes.
