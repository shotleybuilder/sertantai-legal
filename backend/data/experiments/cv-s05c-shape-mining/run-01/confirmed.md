# run-01: the 33 drop candidates confirmed (2026-10-27)

Each candidate in `dropped.tsv` was judged against its whole sentence, from the stored law text (`sentences.tsv`), and the law's stored lists (`ReadCache`). 29 laws are real misreads, in five classes. 4 laws are not drops.

## A: "In Part N— (a) X extends to P, (b) Y extends to Q …": only item (a) read (6 laws, plain)

Each lettered item states its own extent, and only the first is held.

| Law | Provision | Dropped |
|---|---|---|
| ukpga 2015/7 | s.56 | Part 6 (b) s.40, s.49 to UK; (c) s.43–48, s.50 E+W only. Part 3 (b) s.22(2) E+W+S |
| ukpga 2020/16 | s.24 | Part 2 (b) s.13–14 E+W+S only; (c) s.15 NI only. Part 3 (b) s.22 E+W+NI |
| ukpga 2025/18 | s.141 | Part 3 (b) s.58, 59, 60(2), Sch 2 NI only |
| ukpga 2006/16 | s.108 | Part 8 (b) Chapter 3 also NI |
| ukpga 1999/9 | s.17 | "In this Act—" (b) Part II Scotland only |
| ukpga 2010/29 | s.49 | "except that—" (c) Sch 4 para 43 E+W+S; (d) is qualified ("in their application to …") |

## B: an item with its own exception, "X except Y" / "X (except Y)" / "(with the exception of Y)": the whole item dropped (8 laws, plus 3 under E)

It should read as X less Y, as round 9's `Excepting` does for a Part lead.

| Law | Provision | Item |
|---|---|---|
| ukpga 1999/30 | s.90 | "Part IV except sections 42 to 44"; "Chapter I of Part V (except …)"; "Schedule 2 (except for paragraphs …)" |
| ukpga 2003/43 | s.202 | "Part 3, except for section 163(3)" |
| ukpga 2004/20 | s.198 | "Chapter 3 of Part 1 (with the exception of …)"; "Part 3 (with the exception of section 151(5))" |
| ukpga 2009/25 | s.181 | "Part 7 (except sections 158(1) and (2), 170(2) and 171 and Schedule 19)" |
| ukpga 2014/12 | s.184 | "Part 12, except sections 166 and 171 to 174"; "section 106 except subsections …"; "section 176 except subsection (7)" (the exceptions are withheld; the rest is dropped) |
| ukpga 2016/12 | s.45 | "section 35 (…), except subsection (2)" |
| ukpga 2022/30 | s.169 | "this Part except section 161, 164 and 167" |
| ukpga 2026/20 | s.254 | "sections 77 to 80 (except section 80(6)) and Schedule 10"; "z1 Part 9 (except section 150(3))" |

Also: 2000/19 (a), 2015/7 (amendments by Part 1 "other than …") and 2009/23 (Part 2 "other than paragraph 2 of Schedule 4"). For 2009/23 the reader holds the exception, sch.4.para.2, in the same-extent list instead of the Part: an inverted read.

## C: plain provisions with a qualified companion: the plain ones are dropped too (4 laws, plus 1 under E)

"Parts 1 and 2 of Schedule 7 and section 73 so far as relating to those Parts". The Parts are plain; only s.73 is qualified.

| Law | Provision | Item |
|---|---|---|
| ukpga 2007/27 | s.93 | Parts 1–3 of Sch 7 (with s.73 so far as relating) |
| ukpga 2008/30 | s.150 | Chapters 5 and 6 of Part 1 (with s.99 so far as …) |
| ukpga 2017/3 | s.182 | "section 6, so far as relating to paragraphs …, and those paragraphs": the paragraphs are plain (×7 items) |
| ukpga 1998/37 | s.121 | Sch 3 para 3; Sch 8 paras … (with s.52(6) / s.119 so far as relating) |

Also: 1980/34 (c), "Parts I and IV of Schedule 9 (and section 69 so far as it relates to those Parts)".

## D: a wholly qualified item dropped silently, not withheld as unread (4 laws, plus 2 under E)

"section 154 and Schedules 7, 8 and 9 so far as they relate to an enactment extending to Northern Ireland." The provisions fall back to the default, a wrong bound. Round 9 withholds only items that begin with their qualifier.

| Law | Provision |
|---|---|
| ukpga 1980/43 | s.155 (NI and S lists) |
| ukpga 1986/50 | s.87 (c) |
| ukpga 1990/41 | s.123 ("so far as necessary") |
| ukpga 1999/2 | s.28 (a, e, g, j: "so far as they amend …") |

Also: 1989/15 (a), 1972/11 (d, g).

## E: one-off plain drops (7 laws)

| Law | Provision | What |
|---|---|---|
| ukpga 1972/11 | s.30 | "This section, and the following provisions only of this Act, extend to Northern Ireland, that is to say,—": only "this section" held; items a, b, e, ee (and qualified d, g) dropped |
| ukpga 1980/34 | s.70 | "section 61 to 65": singular "section" with a range; plus (c) under C |
| ukpga 1989/15 | s.194 | (b) "section 95" dropped; (a) under D |
| ukpga 1994/21 | s.68 | (a) "sections 49 and 50 and Schedule 7" dropped after a "za" item |
| ukpga 2008/4 | s.152 | "section 113 (together with such of the other provisions of Part 7 as relate to …)": s.113 dropped with its bracket |
| ukpga 2009/23 | s.323 | the same-extent list: Part 1, Chapters 3–4 of Part 7 and Part 9 (each with a describing bracket) dropped; "this Part (other than …)" dropped in the S and NI lists (R10 NEW-2); Part 2 inverted (B) |
| ukpga 2000/19 | s.87 | "this Part, except— (i) sections 82 and 83 and Schedule 8": s.82, s.83 held as both `named NI` and `not NI` (a contradiction); (b) under B |

## Not drops (4 laws)

| Law | Provision | Why |
|---|---|---|
| ukpga 1975/21 | s.463 | "in Schedule 9, the amendments relating to— (i) … Acts": a sub-list by amended Act, not provisions of this law. Out of scope here |
| ukpga 2012/9 | s.119 | the same: "the amendments and repeals in respect of— (i) the Police Act 1997 …" |
| uksi 2017/1012 | reg.2 | sub-items of a qualified item ("in so far as that Chapter applies in relation to plans and projects— (i) which …"): the miner's split, not a drop |
| uksi 2019/696 | reg.3 | "Part 5 and its related schedules, except— (i) paragraphs 29 to 40 of Schedule 34 …": the items are exceptions. The reader holds them as `not NI`; whether that bound is right is a separate question |

## Miner limits seen

- Items lettered "z1, z2 …" (2026/20) were not split.
- Sub-items of a qualified item count as items (2017/1012).
