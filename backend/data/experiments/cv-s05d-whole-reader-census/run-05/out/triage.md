# run-05 triage: every silent sentence and unnamed ref (CV-S05 strategy step 1)

**Input:** the round 13 acceptance reading (the dump taken after the seed 19 fixes; `05f66ca4` changes no behaviour). **Finder:** Schedule Parts named as the reader names them.

Every one of the 64 silent sentences (`silent_detail.txt`) and 320 unnamed refs (`unnamed_detail.txt`) is triaged below as one of:
- **Real:** the stored rows contradict the text; checked with `show.py`/`grepl.py`, and the text read in the CLML.
- **Decision:** a residual class for Jason (strategy step 2).
- **Known:** a known class.
- **Doubtful:** no wrong bound shown.
- **Finder:** the reading is right; the finder can't name it.

## Real, by wording (the fix batch, strategy step 3)

| # | Wording | Laws | Effect |
|---|---|---|---|
| R1 | **"Paragraphs … of Part 1 of Schedule 1 to this Order apply in relation to England only".** `Parts.schedule_parts` expands a Part that is only the owner of the paragraphs listed, so the row gets every paragraph of the Part. This is a regression from the seed 19 fix. And "Schedule 1 to this Order apply …" sets the **whole law's application** to E: `ApplicationClause.parse` rejects only the prefix "of" before "this Order", never "to". | uksi 2006/1407 | Wrong bound: applies E on ~40 paragraphs and the whole law |
| R2 | **"… but, subject to that, this Part of this Act extends to England and Wales only"** is dropped | ukpga 1980/65 s.47(8) | Part V takes the default E+W+S |
| R3 | **"section 153 except subsection (1)(k) and (m)"**: an item with its own exception is dropped | ukpga 1990/43 s.164 | s.153 loses NI |
| R4 | **"X extend to England and Wales but apply in relation to England only"**: the extent half is lost. And in "Parts 1, 5 and 6 extend to E+W, but Part 5 applies in relation to England only", the application spreads to Parts 1 and 6 | uksi 2010/708 | Wrong application (art.2, 13, 14); no extent |
| R5 | **Nested locators:** "in regulation 70 (…)— (i) paragraph (1)(e)(ii) and (iii)" is dropped; "in regulation 71 (…), in paragraph (4)— (i) sub-paragraph (b)" is read as all of reg.71; "in Part 1 of Schedule 6 (…)— (i) sub-paragraphs (2) and (4) of paragraph 8" is read as all of Part 1 | uksi 2017/1012 reg.2 | Dropped, and over-broad |
| R6 | **A locator before named repeals or amendments:** "in Part 6 of Schedule 8, the repeals in …"; "in Schedule 11, the amendments to …" are read as the whole Part or Schedule | ukpga 2001/24, 2022/32 | Over-broad |
| R7 | **"This subsection does not apply to Scotland"** is stored against the section, not its subsection | ukpga 1974/39 s.189(3) | Over-broad: applies_not S on all of s.189 |
| R8 | **An anaphoric bracket companion:** "(and those Parts of Schedule 7)", "(and that Part of Schedule 24)", "(and that paragraph of Schedule 25)" | ukpga 2020/7 s.100 | No bound (the law has no default) |
| R9 | **"…, but this paragraph does not apply in Scotland"**, at the end of a long sentence | uksi 2026/194 reg.22(3) | Application dropped |
| R10 | **"this section" in an exception list:** "that is to say, this section and— …"; "Except for this section and any amendment …" | ukpga 1988/19 s.34, 1995/25 s.125 | The extent section loses NI |
| R11 | **"The repeal by this Act of … and the corresponding saving in paragraph 2 of Schedule 2 … shall extend to Northern Ireland"** | ukpga 1980/58 s.41 | sch.2 para 2 loses NI |
| R12 | **"extends to other parts of the United Kingdom"** (S8, left over) | ukpga 1978/29 s.110 | sch.10 para 3 keeps S only |
| R13 | **"The repeals in Part II … extend to E+W only and those in Part III of Schedule 1 to Scotland only"**: the elliptical second clause is dropped | ukpga 1990/11, 1997/11 | The repeals keep the default |
| R14 | **"188(3) to (8) 189"**: the text is missing a comma | ukpga 1975/21 s.463 | s.188(4)–(8) and s.189 lose E+W |
| R15 | **Another law's sections read as this law's** (S17, left over): "section 123 of the Marine Act", "Sections 128(4) … of that Act" | uksi 2010/490, 2017/1012; ukpga 1991/28 | Refs to provisions that don't exist; no rows |
| R16 | **A list runs on into the next statement:** "… section 173;" then "The following provisions— section 56; … extend to Scotland only" lands in the also-NI row; "(c) the following provisions extend to E+W— …; (d) section 71 … extends to Northern Ireland" puts s.71 under E+W | ukpga 1988/33 s.172, 2021/30 s.146 | Wrong rows, but each ref is also unread, so the bound is withheld |

## For Jason (strategy step 2)

**Q1. A qualified companion that points back:** "paragraph 7 of Schedule 1 and section 1(5) so far as relating to that paragraph". Today the companion keeps the default (the round 6 KX design), so the text's added place is lost for that part. Alternatively it could be withheld (unread).
- Laws: ukpga 1986/44, 1989/29, 1990/16, 1995/45, 1976/55.
- This is the same question as the residual "1986/44 KX plain pieces".

## Known

- **KX** ("so much of …", or a qualified item or piece that keeps the default): 1967/80, 1972/62, 1972/71, 1974/37 (HSWA), 1975/21 s.370, 1981/69, 1988/45, 1994/21 (×2), 1996/25 para 8, 2000/19, 2004/20 Part 2, 2005/15 s.161(5), 2009/462 art.2/4/9/10.
- **KD** (numbers in words): 1961/34.
- **KA** (application to cases is fitness scope): 2003/20, 2015/15 (×2), 2012/3119.
- **Schedules not held** (no rows, so no effect): 1967/80 Sch.7 Part II; 2009/462 Schedules 1, 3, 4.
- **Counted catalogue classes** (unread): 1974/44 list_partial (the text's "110 to116", "126of"), 1986/63, 2010/490, 2013/24 (in_clause, list).
- **R10 residual (2009/23):** Chapters 1 to 5 of Part 8 hold s.293, s.294 (Chapter 6).

## Doubtful (no wrong bound shown)

- 1999/30 s.70: excepted and qualified, both rows present; withheld.
- 1998/37 s.120(2): qualified, in a same-extent row.
- 1972/11 Sch.7 paragraphs after "so far as they relate to …": the scope of the qualifier is ambiguous.

## Finder (the reading is right)

1960/62 (modifications), 1973/26, 1973/32, 1975/21 (another law's sections; the rows in Part I and Part II), 1980/34, 1980/51, 1981/45, 1981/56, 1982/53, 1983/35, 1987/43, 1988/33 (the rest), 1989/15, 1991/22, 1994/40, 1995/45 s.11 and its other-law refs, 1996/23, 1996/53, 1997/50, 2002/3135, 2004/20 s.59, 2004/33, 2005/2060, 2006/3, 2007/28, 2007/1375 (the parent Act's sections), 2007/1843, 2010/231, 2012/9, 2013/24, 2014/469, 2015/2 (a Part read as its paragraphs; the Part ref itself is still judged), 2015/7, 2016/12, 2016/1142, 2018/1203, 2018/1370, 2019/458, 2020/7 (nested brackets), 2021/30 s.116, 2023/55, 2023/56, 2024/437, 2025/36.
