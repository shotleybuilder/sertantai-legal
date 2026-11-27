---
session: "Amending-law reader: amending Schedules"
status: closed
opened: '2026-11-27'
closed: '2026-11-27'
outcome: success
family: 'Waste, Water and Climate (round)'
parent: lat-change-pipeline/2026-11-26-waste-water-and-climate-amending-law-reader.md
summary: >
  Amending laws' own Schedules now give their changes from the law's text: 396 laws' Schedules
  fetched, and six reader classes fixed (Part-numbered and unnumbered Schedules read with their
  leads, a lead's brackets, a capital "Etc." title, amendments tables, conditions naming no law).
  Schedule-made text changes met by a rule rose from 45.2% to 74.9% (18,907 to 31,324) on fresh
  reads of every amending law, no rule lost; written at the parent's Settle.
decisions:
  - what: Fetch the 396 amending laws' Schedules in this session; raise the Sources need rule
    why: a third of the Schedule-made changes came from laws whose Schedules were never fetched, and the reader read held Schedules as well as bodies
    result: 396 stored, none failed; Schedules not held 14,003 to 25
  - what: Measure on fresh reads of every amending law, not stored rules or targeted previews
    why: the stored rules lag the reader (asp 2005/3 Sch.5), and a fix's reach was found to be wider than its named laws (the Part ids)
    result: fresh-1 to fresh-5 compared by provision; 2,261 provisions changed, none lost a rule
  - what: Fix the Part-less naming bug here, though the plan said it had no effect
    why: measured on the fetched Schedules, Locator dropped the Part, so 79 amending laws' Part-numbered Schedules were never read
    result: Part ids, Part-less sub-paragraphs and shortIds all located
  - what: Fix the amendments table and the condition aside (16 laws; one law with 43 changes)
    why: both over the triage size and Schedule forms (a table only in Schedules; the condition under a Schedule title)
    result: the tables' changes 22% to 84% agreeing; asc 2026/7 85.5% to 90.5%
metrics:
  baseline: { schedule_changes: 41797, met: 18907, schedules_not_held: 14003, read_no_rule: 3460, not_read: 2036, never_read: 3019 }
  after: { met: 31324, schedules_not_held: 25, read_no_rule: 3688, not_read: 3435, never_read: 2832, other_law_only: 493 }
  targets_all_amenders: { changes: 76247, agree_before: 57535, agree_after: 59883, brackets_lost_before: 300, brackets_lost_after: 166 }
  tests: { full_suite: 12944, failures: 8, failures_are: catalogue drift none to rules }
lessons:
  - title: The amendment index's elements are only the ids read
    detail: 'The count of Schedules not held was first taken from the index''s elements; the law''s text (the CLML store) is the only measure of what is held.'
    tag: data
  - title: A plan's "no effect today" needs measuring after the inputs change
    detail: The Part-less naming bug had no effect while Schedules were not fetched; once they were, 79 laws' Part-numbered Schedules were unreadable. Re-measure a parked bug after the step changes its inputs.
    tag: data
  - title: A copied pattern hides a class
    detail: Reader and Patterns.Example each had their own copy of the top-provision pattern, so unnumbered and Part-numbered Schedules read with no lead in both. One public Text.top/1 fixed 270 laws.
    tag: tooling
  - title: Fresh reads compared by provision find losses that targeted previews miss
    detail: The Part-id fix lost SI 2016/1154's sub-paragraphs that carry no Part; only the whole-corpus diff of fresh-1 against fresh-2 showed it.
    tag: tooling
  - title: My own size estimates need measuring before a known limit is named
    detail: asc 2026/7's quote-number class was carried as 15 changes from memory; measured, it was 2 rules, and the law's real class (a condition naming LURA, 43 changes) was over the triage size and fixed.
    tag: data
bugs:
  - pattern: "An amending law's Schedules are needed only on the feed's backlog (Sources.needs/2, :backlog), so 14,003 Schedule-made text changes on held laws' bodies in 396 amending laws were never read from the law's text, though its body always is (e.g. 2018 c.22, asc 2026/7, SI 2014/892)"
    category: amending-schedules-not-needed
    module: sources.ex
    affected: "396 amending laws, 14,003 changes (fetched for this round, 2026-11-27)"
    fix: "Need every amending law's Schedules beside its body (:territory), as the amending-law reader reads them"
    step: Sources
    status: open
  - pattern: "A Schedule title's capital \"Etc.\" ended the title match, so the Schedule named no law (1975 c.71 Sch.15, \"Amendments of the Health and Safety at Work Etc. Act 1974\": HSWA s.2, s.10, s.28(9) …)"
    category: heading-etc-capitals
    module: amendment/reader/law_named.ex
    affected: "1975 c.71 Sch.15"
    fix: "Title words take Etc. as etc."
    step: "Amending-law reader"
    status: fixed
  - pattern: "Schedules of amending laws are held but not read for their insertions: SI 2019/720 Sch 2's substituted CLP articles make new numbers that get no insertion (Art 2(15), 37(7)-(9), 52(5)-(6)); Employment Protection Act 1975 Sch 15 (HSWA s.28(9))"
    category: amending-schedule-insertions
    module: amendment/reader
    affected: "SI 2019/720, 1975 c.71"
    fix: "2019/720: fixed by EU article naming (Art 2(15) inserted, 52(5)-(6) in the substituted Article; 37(7)-(9) not this law's); 1975 c.71: the Etc. fix"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A pointer naming a Schedule paragraph inside a Part found no amending provision: Locator dropped the Part, so Part-numbered Schedules (schedule-29-part-1-paragraph-3) were never read (79 amending laws, 1,551 live paragraphs; SI 2016/1154 Sch.29)"
    category: schedule-part-ids
    module: amending_law/locator.ex
    affected: "79 amending laws"
    fix: "The Part's id, then the Part-less one, then the shortId; full paths in any form before a coarser id"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A lead's brackets lost: \"Regulation 36(3) … is amended as follows.\" then \"In sub-paragraph (a)\" read reg.36(a), no row (SI 2018/139 reg.5(2); 2013 c.24 s.97(3))"
    category: lead-brackets-lost
    module: amendment/reader/law_named.ex
    affected: "300 changes, 108 amending laws"
    fix: "LawNamed.lead/3: the nearest lead naming the provision lends its brackets"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An unnumbered or Part-numbered Schedule's sub-paragraphs were their own top provision, so read with no lead and no law named (SI 2019/734 Sch. para.58(2))"
    category: schedule-top-provision
    module: amending_law/text.ex
    affected: "191 unnumbered Schedules and 79 by Part; 1,839 provisions newly read"
    fix: "One top-provision pattern, Text.top/1 and top?/2, shared by Reader and Patterns.Example"
    step: "Amending-law reader"
    status: fixed
  - pattern: "An amendments table (\"Provision | Amendment\", a law column, \"Title | Extent of amendment\") read no rule (SI 2013/1644 Sch.1, 229 changes; SI 2008/960 Sch.3; SI 2006/1177 Sch.)"
    category: amendments-table
    module: amendment/reader/amendment_table.ex
    affected: "16 amending laws, about 300 changes"
    fix: "Reader.AmendmentTable: each row an instruction under \"In <provision> of <law>—\"; spanning cells, tables running on, a cell's paragraphs and lists"
    step: "Amending-law reader"
    status: fixed
  - pattern: "A condition on another law being in force (\", if paragraphs 4 and 5 of Schedule 11 to LURA 2023 are in force,\") named that law, not the Schedule title's (asc 2026/7 Sch.1 on TCPA 1990)"
    category: condition-names-no-law
    module: amendment/reader/clauses.ex
    affected: "asc 2026/7, 43 changes"
    fix: "A condition is an effect aside (Clauses.no_effect_asides/1), opening the sentence or within it"
    step: "Amending-law reader"
    status: fixed
  - pattern: "\"In each of the provisions listed in sub-paragraph (3)— (a) for … substitute …\" over a list of provisions in another sub-paragraph gives no rule (SI 2026/386 Sch.2 para.23 on the Data Protection Act 2018, 259 changes; its Sch.3 para.24, 36)"
    category: provisions-listed-elsewhere
    module: amendment/reader
    affected: "about 330 changes, 1 amending law"
    fix: "Read the listing sub-paragraph's provisions as the instruction's places (not Schedule-specific: the yield session)"
    step: "Amending-law reader"
    status: open
  - pattern: "Pointer/Locator name a Schedule paragraph inside a Part without its Part"
    category: schedule-part-naming
    module: amending_law/locator.ex
    affected: "79 amending laws"
    fix: "Moved to schedule-part-ids, fixed"
    step: "Amending-law reader"
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader/amendment_table.ex
  - backend/test/sertantai_legal/scraper/amendment/reader/amending_schedules_test.exs
  - backend/data/reports/amending-reader/schedules/ (feed_met.py, check_targets.py, fresh_diff.py, dump_fresh.exs, fresh-1..5.jsonl, after-5.txt, check-all-5.txt)
depends_on:
  - 2026-11-27-amending-law-reader-eu-article-naming.md
enables:
  - "Amending-law reader: yield (the next named session)"
  - "The parent's catalogue cold dry run and Settle write (every amending law re-read; the 396 fetched laws included)"
---

# Session: Amending-law reader: amending Schedules (CLOSED)

## Problem

A named session inside "Waste, Water and Climate: Amending-law reader" (parent suspended). Of 41,797 legislation.gov.uk text changes made by an amending law's Schedules to a held law's body, only 45% have a rule from that law's text. A third (14,003) come from 396 amending laws whose Schedules are not in the store at all. A Schedule's title, Part title or cross-heading that names the amended law is not used to name it (Employment Protection Act 1975 Sch.15 on HSWA).

Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md` (approved 2026-11-27).

## Todo

- ✅ 1. Measure: baseline, the checked script `schedules/feed_met.py`, the fetch list
- ✅ 2. Fetch the 396 laws' Schedules (Decision 1, on Jason's go), then preview their reading; raise the Sources need rule
- ✅ 3. Find: the new rules against the feed's targets, by group; probes (headings, SI 2009/2093, SI 2019/720, 1994 c.28)
- ✅ 4. Fix the heading class (Schedule/Part title, cross-heading names the law) and the Schedule Group, test first
- ✅ 5. Fix each other misread class at or over the triage size, test first
- ✅ 6. Check: previews and regression, feed_met again, mix test, Credo diff
- ✅ 7. Close: frontmatter, RULES, commits by path, parent note, memory

## Dependencies

- ✅ Amending-law reader: EU article naming (closed 2026-11-27, `764fd74e`)

## Parking list

- Amending-law reader (yield session): provisions-listed-elsewhere — "In each of the provisions listed in sub-paragraph (3)—", SI 2026/386, about 330 changes
- Amending-law reader (yield session): defined short names and abbreviations ("ICTA", "the 1970 Act"), rule-less under a naming heading (2009 c.10 Sch.1, 149)

## Decision 1: fetch the amending laws' Schedules

- **Question:** should this session fetch the Schedules of the 396 amending laws whose Schedules are not in the store?
- **Aim:** `binds-on-date`; the source-authority rule (the law's text is primary where it speaks).
- **Options:**
  - (a) Fetch now with `mix clml.fetch --laws … --whole`, one request per law (the body is fresh), about 15–25 min, store files only. Read them in the preview, and raise Sources' need rule (`Sources.needs/2` asks for an amending law's Schedules only on the feed's backlog) with `bug-raise`.
  - (b) Park the gap with Sources; the 14,003 changes stay feed-only.
- **Recommendation:** (a). The reader already reads held Schedules about as well as bodies (76% met against 78%).
- **Decided:** (a), with the plan's approval (2026-11-27). The fetch itself waits for Jason's go.

## Measure (todo 1)

Report `backend/data/reports/amending-reader/schedules/baseline.txt`, script `feed_met.py` (run from `backend/`), fetch list `fetch-list.txt`.

| Schedule-made text changes on held laws' bodies | Changes | Amending laws |
|---|---|---|
| A rule for that law from that provision | 18,907 (45%) | 267 |
| The Schedules not in the store | 14,003 (34%) | 396 |
| Read, no rule | 3,460 (8%) | 251 |
| Not read as amending | 2,036 (5%) | 129 |
| Amending law never read (the Settle reads it) | 3,019 (7%) | 318 |
| A rule for another law only | 372 (1%) | 29 |

- Body-made changes for comparison: 64.5% met; read with no rule 8.7%; not read 8.2%; never read 18.1%.
- The rule-less Schedule changes, by the heading over them:
  - cross-heading names a law: 1,272;
  - the Schedule title: 421;
  - a Part title: 30;
  - none names a law: 2,766 (the yield session's);
  - no heading found: 1,007.
- Parked bugs:
  - Part-less naming: 0 Schedule rows and 0 Schedule targets in the stored rules, so no effect today.
  - SI 2019/720: the stored rules already insert CLP Art 2(15) and 52(5)–(6).

## Fetch and find (todos 2–3)

- **The fetch** (Jason's go, 2026-11-27): `mix clml.fetch --laws <fetch-list> --whole`, log `schedules/fetch-1.txt`. The Sources need rule was raised (`amending-schedules-not-needed`, step Sources).
- **Probes on the heading class:**
  - The reader already reads every heading (`Doc.title`, nearest first). Cross-headings and titles name their laws: 2005 c.15 Sch.4, SI 2010/976 Sch.12, WSI 2018/101 in capitals.
  - The one heading fault: a capital "Etc." ended the title (1975 c.71 Sch.15). Fixed test first (`law_named.ex`, `amending_schedules_test.exs`).
  - The other rule-less changes under naming headings have other causes, all the yield session's:
    - text repealed (dots: 2005 c.15 Sch.4 para.1);
    - a short name ("the 1970 Act", SI 2010/976);
    - an abbreviation ("of LDTA", WSI 2018/101);
    - an amendment to an amending law's inserted text (SI 2020/1460 Sch.3);
    - "The existing provision becomes subsection (1)" (2022 c.30).
  - So the measure's heading split is a pointer, not a class.
- **Stored rules lag the reader:** asp 2005/3 Sch.5 para.7(2) has no stored rule, but the fresh reading has two. Pass items 1 and 6 are measured on fresh readings (the previews), not the stored rules.
- **SI 2009/2093** (VAT Sch.8 Group 17): no rule now, which is right (the amended law's Schedule).
- **SI 2019/720** (probed): CLP Art 2(15) is inserted, and Art 52(5)–(6) come with the substituted Article 52. Art 37(7)–(9) are not 2019/720's (it substitutes Art 37 as (1)–(5)).
- **1994 c.28 Sch.1 para.4:** not in the held document. It stays the parent's named known limit (one provision).
- **Catalogue drift (expected):** after the Etc. fix, `AmendmentPatternsTest` shows two held examples drifting:
  - 1975 c.71 Sch.15 para.2;
  - 1975 c.71 Sch.15 para.12.

  Both go from `unnamed|none` to `named|rules`, as meant. They are left for the parent's cold dry run. Otherwise `test/…/amendment` is 750/752 green.
- **Fresh readings:** `schedules/dump_fresh.exs` writes each amending law's fresh rules and read ids as one JSON line, resumable. `feed_met.py --fresh FILE` measures on them.

## Fresh read 1 and the classes it found (todos 2–5)

- **Fetch:** 396 laws stored, none failed; 387 hold Schedule paragraphs.
- **Fresh read 1** (`schedules/fresh-1.jsonl`, every amending law, nothing written). `feed_met.py --fresh` gives `after-1.txt`:

  | Schedule-made changes on held bodies | Before (stored) | Fresh read 1 |
  |---|---|---|
  | met | 18,907 (45.2%) | 29,083 (69.6%) |
  | Schedules not held | 14,003 | 25 |

  Body-made changes: 64.5% → 66.0% (the stored rules lag).
- **The fetched laws' new rules against the feed** (`check_targets.py`, pass item 2):
  - 14,003 changes; the target agrees for 9,791 (69.9%);
  - target differs 160, in 58 laws, mostly one or two each;
  - another law only 191;
  - read with no rule 2,611;
  - not read 1,219.

  An Order's "art." in the feed is our "reg." (the check's fault, normalised).
- **Classes found, each fixed test first:**
  1. **A lead's brackets lost:**
     - The form: "Regulation 36(3) … is amended as follows." then "In sub-paragraph (a)" read reg.36(a), which is no row, so the change was lost.
     - Over every amending law: 300 changes, 108 laws (SI 2018/139, 2013 c.24 s.97, SI 2019/93, WSI 2013/755, 2014 c.14 Sch.4).
     - Fix: a lead naming the provision the clause takes its numbers from lends its brackets, as a parent does (`LawNamed.lead/3`). The lead's own words after "amended" place nothing.
  2. **A Part-numbered Schedule's paragraphs never read:**
     - `Locator.ids/2` dropped the pointer's Part: "Sch. 29 Pt. 1 para. 3" looked for `schedule-29-paragraph-3`; the id is `schedule-29-part-1-paragraph-3`.
     - 79 amending laws, 1,551 live paragraphs, none read (SI 2016/1154, SSI 2018/219, SI 2012/3039 …).
     - Fix: the Part's id first, then the Part-less one; a Part-less pointer finds the paragraph by its `shortId` (`Doc.short`).
     - This is the parked Part-less naming bug, which does have an effect (the plan's "no effect" was wrong): pointers naming a Part found no amending provision.
  3. **An unnumbered or Part-numbered Schedule's sub-paragraphs read with no context:**
     - `Text.top/1` knew only `schedule-N-paragraph-M`, so `schedule-paragraph-58-2` was its own top: no lead, no law named.
     - 191 unnumbered Schedules (4,411 live paragraphs) and the 79 above.
     - Fix: one top-provision pattern, `Text.top/1` and `top?/2`, now used by `Reader` (twice) and `Patterns.Example`, which had copies.
- **Not fixed here (the yield session's, or text gone):**
  - ~~SI 2013/1644 Sch.1, an amendments table (Provision | Amendment), 229 changes~~ (fixed below: amendments tables);
  - a heading's words ("In the heading …", SI 2018/631);
  - SI 2010/675 Sch.26 Pt.2, repealed (dots).
- **Catalogue drift:** 6 held examples now read rules where they read none:
  - 1975 c.71 Sch.15 para.2, para.12;
  - asp 2019/15 Sch. para.2, para.5;
  - asp 2007/6 Sch. para.8(a);
  - SI 1996/973 Sch. para.19(2).

  Left for the parent's cold dry run.
- **Checks:** `test/…/amendment`, `change_vocabulary`, `architecture` and `commencement`: 7,484/7,490, the 6 drifts aside. The Credo diff adds no issues.

## Fresh read 2, the tables and the conditions (todos 5–6)

- **Fresh read 2** (`schedules/fresh-2.jsonl`, every amending law, Jason's go) after the three fixes above. `fresh_diff.py` compares readings by provision; `fresh-diff-1-2.txt`:
  - 1,839 provisions newly read in unnumbered Schedules (125 laws); 265 lead-bracket refinements (70 laws); 138 others, every one a refinement inside the same provision (checked by code: no target moved to another provision).
  - **One loss found and fixed:** SI 2016/1154 Sch.29's Part paragraphs hold sub-paragraphs without the Part (`schedule-29-paragraph-2-2` under `schedule-29-part-1-paragraph-2`). The Part's id won over the sub-paragraph's. `Locator` now tries the full path in every id form before any coarser one (test first). The 277 laws with Part ids or shortIds were re-read (`fresh-2b`, spliced into `fresh-3`).
  - `fresh-1` → `fresh-3`: 2,261 provisions changed; **none lost a rule, none has fewer.**
- **Amendments tables** (`Reader.AmendmentTable`, test first, five tests from the laws' wordings):
  - forms: "Provision | Amendment" in the law the table's title names (SI 2013/1644); a law column (SI 2011/2131, NISR 2010/160, 2011/295, 2007/31); "Title | Extent of amendment" (SI 2008/960); a table with no header running on; empty or spanning cells; a cell's lead over its list; a cell's paragraphs each its own instruction (SI 2006/1177).
  - Reached only by a Schedule id that is no provision (after the repeals table), so only the 16 laws holding such a table changed (scanned by code; re-read, `fresh-4`).
  - Those 16 laws' Schedule-made changes: target agrees 112 → 423 of 502 (22% → 84%); SI 2013/1644 226 of 229.
- **Conditions** (`Clauses`, test first): ", if … is/are in force," and an opening "If … in force," name no law amended. 30 amending laws hold the form; only asc 2026/7 changed (49 rules move from LURA 2023 to TCPA 1990, as the text says; `fresh-5`). Its changes agreeing: 85.5% → 90.5%.
- `fresh-5` stands for a full read under the final code: every edit after fresh read 2 reaches only the laws re-read (by code: Part ids or shortIds, amendments tables, the condition form).
- **The old collector** builds its own source map for `Locator`; it now carries `short` (from the document; the store keeps none).

## Results (pass rule)

| | Before (stored) | After (`fresh-5`) |
|---|---|---|
| Schedule-made text changes on held bodies, met by a rule | 18,907 (45.2%) | 31,324 (74.9%) |
| Schedules not held | 14,003 | 25 (5 laws, the store's 404s) |
| Read, no rule | 3,460 | 3,688 |
| Not read as amending | 2,036 | 3,435 (the fetched laws' pointers not offered) |
| Amending law never read | 3,019 | 2,832 |
| Rule for another law only | 372 | 493 |

- Over every amending law (`check-all-5.txt`, Schedule and body provisions): the target agrees for 59,883 of 76,247 (78.5%; 75.5% at fresh read 1); a parent's brackets lost 166 (was 300).
- **Named groups left:**
  - read with no rule, and not read as amending: not Schedule-specific (short names, pointers not offered, provisions listed elsewhere): the yield session's;
  - never read: the Settle reads them;
  - known limits below the triage size (RULES): a quote whose number is in its text (asc 2026/7, 2 rules); amendments-table rows placed coarse (SI 2013/1644 on RTA 1988 s.118, 3; SI 2008/960 on 1995 c.15 s.1(2A), 1).
- **Checks:** `mix test` 12,936/12,944 (the 8 catalogue drifts: the six above, NISR 2010/160 Sch.5, SI 2008/960 Sch.3, all none → rules); the amendment, vocabulary, architecture and commencement folders 9,374/9,382 (the same 8). The Credo diff adds no issues. `mix compile --warnings-as-errors` clean.
- **Previews:** the plan's targeted `--preview` runs were replaced by the fresh reads of every amending law, compared by provision against fresh read 1; the regression list's laws are among them. Nine fixed laws added to `regression.txt`.

## Close

- **Docs changed:** RULES `amending-places-read-as-the-amended-law-numbers-them` (an amending law's own Schedules: fetch, a lead's brackets, Part ids, the top provision, titles, amendments tables, conditions) and one known-limits row; `amendment/CLAUDE.md` three gotchas.
- **Parked:** provisions listed elsewhere (SI 2026/386, about 330) and short names (2009 c.10, ICTA) to the yield session; the Sources need rule open with Sources.
- **Step close:** run by the parent at its close, not here (a named session inside the step).
