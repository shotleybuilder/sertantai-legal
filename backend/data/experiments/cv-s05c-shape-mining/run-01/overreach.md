# run-01 step 3: over-reach in list items the reader holds (2026-10-27)

`overreach.exs` checks three rules on every item of a sentence the reader classes as a list. That is 100 laws, using the stored lists of the item's kind and place:
- **excluded:** a provision the item excludes is held;
- **qualified:** a provision named only under "so far as" is held as plain;
- **scope:** "in Part N, sections …" holds the whole Part.

It found 14 items (`overreach.tsv`), each judged against the whole sentence.

## F: an item's exception not honoured, so the excluded provisions are held (5 laws)

| Law | Provision | Item | Held, though excluded |
|---|---|---|---|
| ukpga 2007/27 | s.93 | "Part 2 (including Schedules 3 and 4 and Part 1 of Schedule 6) but excluding sections 60 and 61, Schedule 5 and Part 2 of Schedule 6" | s.60, s.61, sch.5, sch.6.pt.2 in E+W+NI only |
| ukpga 2012/9 | s.119 | "Chapter 3 of Part 5 (excluding paragraph 5(3) of Schedule 8 and section 91)" | sch.8.para.5(3) and s.91 in E+W+NI only, though another list names them UK-wide |
| ukpga 2020/21 | s.56 | "Part 1, apart from sections 17 and 18" | s.17, s.18 in E+W only |
| ukpga 2022/32 | s.207 | "this Part, other than section 204 (and Schedule 21)" | s.204, sch.21 UK-wide |
| ukpga 2009/23 | s.323 | "Part 4 (…), other than paragraph 1 of Schedule 8"; "Chapter 1 of Part 5 (…), other than section 146 and Schedules 11 and 12"; Part 2 inverted (B); "in Chapter 1 of Part 6, sections 165, 166 and 186" holds all of Chapter 1 (scope) | R10 NEW-2, already known |

## Not misreads (4 laws: the check's own limits)

| Law | Provision | Why |
|---|---|---|
| ukpga 1994/40 | s.78 | s.74 is named plainly in item (a); the check looks at one item at a time |
| ukpga 1975/21 | s.463 | bare numbers ("365, 370 (so far as …), 374") cut into the wrong chunks |
| uksi 2010/490, 2017/1012 | reg.2 | the regulations held are named by other items of the same sentence |

**The check is limited** to one item at a time. A provision held through another item counts as a hit, so every hit needs the sentence read, as was done here.
