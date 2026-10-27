# CV-S05d census: run-06, the run-05 fix batch's check (2026-10-27)

**Reader:** `89a580a6`, CV-S05's run-05 fix batch: R1–R13 and 2009/23's Chapters 1 to 5. `input.jsonl.gz` is the reading after the acceptance chain. It is byte-identical to the whole-store pre-flight read taken before the chain.

**Pre-flight** (`out/reading_diff_vs_run05.txt`, from `rdiff.py` against run-05's input): 21 of 3,358 laws changed, each checked against its text.
- 15 are the intended fixes.
- 2014/12 and 2016/12: "section 106 except subsections (2)(a)(ii) and (6)" is now excepted from s.106 itself, not the clause's s.184. The provision is withheld; before, a wrong bound covered all of it.
- 2019/453: a counted `unread:in_clause` sentence now names its provisions, so their bound is withheld.
- 2020/7 and 2010/490: their other brackets and nested locators are read alike.
- Nothing moved into an unread class.

| Measure | run-05 | run-06 |
|---|---|---|
| Silent candidate sentences | 64 | 57 (12 cleared, 5 re-flagged: finder-side or known) |
| Unnamed stored refs | 320 (44 laws) | 329 (42 laws): +69 of the fixes' new reads, which the finder can't name (brackets, nested locators, subsections); −60 gone, including 2006/1407's 41 |
| Recall bench | 6/10 | 5/10: 2009/23 "Chapters 1 to 5 of Part 8" is now fixed live |

**Acceptance chain:**
- golden 27/27;
- extent, feed and markup checks PASS (our faults 0);
- `law_text` extent and territory claims unchanged against `r6b.claims15`;
- catalogue: 1980/65's example accepted as `list:only:E+W`; 4 examples re-keyed (the Chapters text corrected, same classes); 2010/490's NI list now read; the feed catalogue's 31 Schedule-triple pattern renames from round 13 accepted (0 examples differ).
