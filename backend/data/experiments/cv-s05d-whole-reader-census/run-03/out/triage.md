# run-03 triage: the round 13 fix list

**Inputs:** run-02's triage (`../run-02/out/triage.md`), re-checked after the finder fixes, plus the over-reach list reviewed in full (`unnamed_view.txt`, 53 laws).

**Confirmation:** each wording has at least one law confirmed with `Extent.of`: `../run-01/verify*.exs`, `../run-02/out/verify3.txt` and `out/verify4.txt`.

**Labels:**
- **V**: confirmed;
- **R**: real by the text against the stored rows.

`nil` is no bound (the change is dropped).

## The fix list, by wording

| # | Wording | Laws | Effect |
|---|---|---|---|
| S1 | **Exception lists' items dropped.** Forms: "This Act, except— …, does not extend to NI"; "Except for the following provisions …"; "Except for section 8, this Act does not extend to NI"; "Except for Part I … and the provisions mentioned in …"; "This Act does not extend to Scotland, with the exception of— …"; "…; but, with the exception of those provisions, …" | V 1971/11, 1972/62, 1976/55, 1996/25, 1990/16, 1995/45, 1993/11, 1981/69 (no default), 1991/65, 1982/49; R 1986/44, 1988/19, 1988/45 | Items get the default; the text adds NI (or S) |
| S2 | **Sub-letter runs lost** (`RefList`): "2(1)(a) and (b)", "36(1), (2)(a), (b) and (d)", "19(2)(a) and (b)", "2(w)(i) and (ii)", "72(2)(a)(ii) and (iii), (b)(i) …", "34 (f)", "(3)(a)", "(2)(aa)". They leave garbage refs `s.264(a)`, `s.70(aa)`, `s.36(b)`, `reg.72(b)(i)`, `reg.2(ii)`, `s.19(b)`. | V 2005/457, 1998/37, 1981/29, 2024/437, 2013/1506, 1980/66, 1990/8; R 2022/1273 | Wrong bound or none |
| S13 | **An owner read as the whole provision:** "subsections (1) to (6) of section 11", "subsections (5) to (9) of section 14", "Paragraphs (28), … of regulation 5", "paragraphs 11, 12, 18 and 19 of Part I of Schedule 25", "Paragraphs 3, 11(a) … of Part 1 of Schedule 1", "in Schedule 2, Part II and paragraph 11", "7(3)" read as para 7 | V 1995/45 (s.11(7) → UK), 2016/12 (s.14(1) → UK), 2007/1843 (reg.5(1) → S), 1980/51 (paras → nil), 1985/71 (para 7(1) → S; para 10 → NI), 1977/38 (sch.2.para.1 → S); R 2006/1407, 2001/24, 2022/32 | Wrong bound over the rest of the provision |
| S3 | **"or"-lists in same-extent subjects;** "Part N of Schedule M" read as the Act's Part N | V 2019/530, 2022/6, 2020/1540, 2007/28 (109 provisions → same) | Dropped, or a wrong same |
| S4 | **A bracketed or trailing qualified companion dropped, not withheld:** "(and section 55 so far as …)", "(including Schedule 13 so far as …)", "(and article 26 in so far as …)" | V 2022/30, 2023/55; R 2013/602, 2005/2060, 1980/34, 1977/38, 1972/71 | Default, or none |
| S5 | **A provision's own subsections, self or Chapter dropped:** "subsections (1) to (4), this subsection", "this section extends also to Scotland", "(v) this Chapter", "subsections (1), (3) and (6) to (10) of this section" | V 1992/43, 1973/32, 1998/31, 2017/3, 1977/45; R 1988/19 | None, or the default |
| S6 | **Two statements in one sentence:** "Sections 28 and 33 … do not extend to Scotland and sections 34 and 35 extend to Scotland only"; "This Act, except section 88, does not extend to NI and, except section 86 and Schedule 3, does not extend to Scotland"; "This Act does not extend to NI and— (a) in Part IV, sections 42 and 43 extend to E+W only and section 44 extends to Scotland …"; "not extend to Scotland or, . . . to NI"; "the following provisions …— (a) …; (b) …, extend to E+W only" (the verb in the last item) | V 1969/10, 1973/26 (default E+W+S; text E+W), 1987/27, 1968/64, 1968/60, 1982/53 | Wrong bound or none |
| S7 | **Whole-law default misread or missing:** "extends to Scotland (subject to …) and Northern Ireland"; "extends only to England and Wales, except that— …"; "Part 6 … extends to England and Wales, except that— …" | V 1999/28, 2010/29, 2021/30 | — |
| S8 | **Territorial application unread** (in the noise bin; KA decision) | R 2016/1154, wsi 2014/3303 (and its reg.17), 2026/335, 2025/1042; extent "extends to other parts of the United Kingdom" 1978/29 | No application bound |
| S9 | **A qualified subject or qualifier object read whole:** "this Part to the extent that it applies to those sections"; "so far as it applies to regulations under section 46" | V 2006/41, 2014/2 | Wrong bound (over) |
| S10 | **Repealed words (". . .") inside number lists** | V 1974/40; R 1976/55, 1972/62 | Item dropped |
| S11 | **A locator read whole:** "in regulation 16, paragraphs (4) and (5)" | V 2020/818 | Wrong bound (over) |
| S12 | **Same-extent item dropped** | V 1999/9 | Wrong bound |
| S14 | **"cease to apply in relation to England" read as applies in England** | V 2013/27 s.61B(1)–(7) | Inverted |
| S15 | **A bracket followed by a bare number continues the bracket's kind:** "229 (and Schedule 22), 230, 233 to 236" read as Schedules 230, 233 … | V 2023/55 (garbage `sch.230` …; s.230 and others lost) | Wrong bound |
| S16 | **A reference read as an item:** "except as provided by section 189" | R 1972/20, 1988/52 | Over |
| S17 | **Another law's provisions read as this SI's** (`s.123`, `s.237` in an SI's list) | R 2010/490, 2017/1012 | Garbage refs |
| — | **One-offs** | 2009/23 Chapters 1–5 hold Chapter 6 (known); 1972/11 (sch.7 paragraphs none); 1980/58; 2009/462; 1967/80; 1968/73 (the provisions "set out in Part I of Schedule 17" not read) | |

## Not real, or not yet decided

- **Known:** KD (1961/34, numbers in words); KX (HSWA s.84(1)(a); 1994/21's "so much of" items).
- **Finder misses still left** (in `candidates.txt`/`unnamed_view.txt`):
  - nested lists (2025/36, 2021/30, 2020/7, 1986/63);
  - "the provisions of Schedule 8 …" (1991/22, 1996/23);
  - "(excluding …) and 25" (2012/9);
  - "in so far as …" objects (2017/1012).
- **Doubtful:** the 2010/708 commencement order; 1990/43 s.153; 1999/30 s.70; 2013/24 Part 2 lists; 2015/2 and 2015/7 places; 1989/15; 2006/3.
