# CV-S05d census: run-07, the seed 20 batch's check (2026-10-28)

CV-S05d is closed. This run is CV-S05's check of the fix batch for seed 20's three observations. It is stored here with the census's other runs.

**Reader:** `84dd509c`.

**Reading diff** (`out/reading_diff_vs_run06.txt`): 15 of 3,358 laws changed, each checked against its text.
- **Exception lists whose items are another subsection's:** 1989/38, 1986/31.
- **"Subsection(s) (N) … extend/do not extend":** 1980/65, 1987/43, 1988/52, 1990/42, 1990/43, 2004/20, 2007/15.
- **A Schedule paragraph's "Sub-paragraph (N) …":** 2003/39.
- **"(and the related repeals in Schedule 28)" withheld:** 2008/4.
- **"… of that section":** 2009/26.
- **Withheld only:** 2006/16, 2012/10, 2013/22.

**Acceptance chain:**
- golden 27/27;
- extent, feed and markup checks PASS (our faults 0);
- sweep: 0 sentences in a read form;
- `law_text` claims: 13 gained. 1989/38's changes take its default E+W+S: they were withheld while s.30's list was unread, and the qualified item keeps the default (KX). The enactments they amend are Great Britain-only, so E+W+S is right.

| Measure | run-06 | run-07 |
|---|---|---|
| Silent candidate sentences | 57 | 58 (+1 finder-side: 2009/26 "of section 105" owner) |
| Unnamed stored refs | 329 (42 laws) | 360 (45 laws): +31 of the fixes' new reads (mentioned-subsection items, s.105's subsections) |
| Recall bench | 5/10 | 5/10 |
