---
session: 'Environmental Protection: Commencement reader'
status: closed
opened: '2026-11-09'
closed: '2026-11-09'
outcome: success
family: '💚 ENVIRONMENTAL PROTECTION'

summary: >
  The family's 35,518 rows in 122 laws are dated from their own words on stored rules: rows' faults 9,954 → 0 and
  leftovers reaching the family 23 → 0 (5 named known limits). Ten reader forms, two check errors and an order-store
  overlap were fixed, each with a test, and the catalogues regenerated with 24 new patterns and 36 held readings moved.
  Seed 67 is repeatable, golden 27/27, mix test 10,512 pass, no agent pass.

decisions:
  - what: Five one-law commencement wordings named known limits (Decision 1 (a))
    why: each in one law under 10 family rows; only WSI 2006/2797 has a date to lose, and that needs another instrument's start
    result: leftovers.json `known:` entries; RULES.md one-law commencement wordings row extended
  - what: Accept 24 new catalogue patterns (12 pending) and move 36 held readings (Decision 2 (a))
    why: every move checked against its text; a dry run at the last commit's code over the same store separated this step's changes from new laws
    result: catalogue tests pass whole; 13 of the moved examples rotated out with their patterns

metrics:
  stored_check: { rows: 35518, laws: 122, faults_before: 9954, faults_after: 0, dated: 27880, left_to_orders: 4595, leftovers_not_named_before: 23, after: 0, known: 6 }
  fresh_before_fixes: { not_reached: 5, leftovers_not_named: 23 }
  catalogues: { sentence_laws: 3028, sentences: 8963, patterns: 780, new_sentence: 20, new_order: 4, pending_new: 12, held_moved: 36, orders: 715, order_statements: 4032, cold_run_s: 274 }
  reread: { own_rules: 261, title_searches: 113, orders_listed: 116, orders_held: 108, amenders: 80, amender_rules: 230, build_s: 220 }
  other_families: { ohs: "PASS before and after; 3 rows (HSWA 1974 Pts I, II, IV) dated by the Part fix", maritime: "PASS, unchanged" }
  repeatability: { seed: 67, samples_identical: true }
  golden: "27/27"
  mix_test: 10512
  agent_tokens: 0

lessons:
  - title: A catalogue dry run still writes the fixtures; use --out to a scratch copy
    detail: lat.commencement_patterns and lat.order_patterns write patterns, examples, laws and leftover groups whether or not --accept is given; only expected.json waits for --accept. Copy the fixtures to a scratch dir and pass --out.
    tag: tooling
  - title: Compare against the last commit's code over the same store, not against the fixtures
    detail: the store had gained laws since the last catalogue run, so new unstatused groups and moved examples mixed this step's changes with the store's. A stashed run at HEAD into another scratch copy, compared statement by statement, found three regressions (a purpose-first item read as the whole law; a pointer check stopping "except the provisions mentioned in subsection (1)" being followed).
    tag: tooling
  - title: The fresh check cannot stand in for the stored one
    detail: --fresh re-reads own clauses only, without schedule effects or the order store's write semantics. The stored check after the re-read found 957 rows wiped by an order listed under two laws (SI 1996/186 under SI 1996/1030) and 416 rows not reached by schedule-only rules (SI 2020/206).
    tag: data
  - title: Never hand-build the amending list for --read-amending
    detail: the 81 laws passed included 21 commencement orders, which the family gate leaves out; take the list the way the gate takes it.
    tag: tooling
  - title: --accept keeps held readings; moves are written separately
    detail: the task writes statuses for new patterns but keeps every held example's expected reading; agreed moves are written from the reader with the task's encoder (FeedPatterns.encode), and laws.json regeneration can surface one more (1998 c.47) after the accept.
    tag: tooling

bugs:
  - pattern: "A \"the following provisions … for the purpose of making regulations / so far as they relate to a power …\" head's qualifier does not reach its items, which are read fully (SI 2015/425, 2015/1329, 2025/1370, 1993/274)"
    category: order-head-qualifier
    module: commencement/order.ex
    affected: about 10 orders
    fix: "list_qualifier/1: a the-following head's qualifier reaches items with none of their own"
    step: Commencement reader
    status: fixed
  - pattern: "\"Part IV, apart from section 66 and Schedule 9 …\" in a clause list item: the apart-from after a Part item not read as its except"
    category: apart-from-after-part-item
    module: law_start/provisions.ex
    affected: 1999 c.22 s.108(3)(b)
    fix: "@except reads \"apart from\" outside brackets"
    step: Commencement reader
    status: fixed
  - pattern: "An order read for one law replaced its rules for every law it commences: SI 1996/1030's order list names SI 1996/186, 1996/2857, 1996/2909, wiping the Environment Act 1995's 957 rows of order dates"
    category: order-rules-overwrite
    module: commencement/store.ex, mix lat.commencement
    affected: 957 rows (Environment Act 1995)
    fix: "Store.write/3 commences: option; the law-order read scopes its delete"
    step: Commencement reader
    status: fixed
  - pattern: "A law's cached order list names another Act's orders (SI 1996/1030 lists three Environment Act 1995 orders)"
    category: order-list-wrong-law
    module: commencement/orders.ex
    affected: 4 orders listed under two family laws
    fix: "check the title search's match against the commenced Act"
    step: Commencement reader
    status: open
  - pattern: "--read-orders without --law (amending Acts' cited orders) still replaces an order's rules by source alone"
    category: cited-orders-write-overlap
    module: mix lat.commencement (read_orders)
    affected: unknown
    fix: "write per commenced Act with commences:"
    step: Commencement reader
    status: open
  - pattern: "The check's --fresh reads own clauses without ScheduleEffect, so fresh and stored differ where a Schedule is tied (SI 2020/206)"
    category: fresh-read-without-schedule-effects
    module: mix lat.commencement_check (fresh_rules)
    affected: 1 law in this family
    fix: "include ScheduleEffect.rules in fresh_rules"
    step: Commencement reader
    status: open
  - pattern: "The held-amenders list for --read-amending is built by hand and took in 21 commencement orders"
    category: re-read-amenders-list
    module: mix lat.commencement (read-amending)
    affected: 21 orders in this family
    fix: "a --family option taking the gate's amenders"
    step: Commencement reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/leftovers.ex
  - backend/lib/sertantai_legal/scraper/commencement/order.ex
  - backend/lib/sertantai_legal/scraper/commencement/store.ex
  - backend/lib/sertantai_legal/scraper/law_start/clause.ex
  - backend/lib/sertantai_legal/scraper/law_start/provisions.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/own_commencement.ex
  - backend/lib/mix/tasks/lat.commencement.ex
  - backend/test/fixtures/commencement_patterns/
  - backend/test/fixtures/order_patterns/
  - backend/data/reports/commencement-reader/environmental-protection-*.txt
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - .claude/skills/commencement-reader-check/SKILL.md

depends_on:
  - 2026-11-09-environmental-protection-markup-reader

enables:
  - Environmental Protection Extent reader step
---

# Session: Environmental Protection: Commencement reader (CLOSED)

## Problem

Step 4 for Family 3. The commencement readers must date the family's 35,518 rows (122 laws) from the laws' own words: their own clauses, the orders made under them, and the held amending laws' clauses. Every row is dated, left to an order, or undated with a reason, and every word of those statements that bears on a date is used by a rule or sits in a named group. Baseline: stored FAIL (9,533 rows with no rules, 55 laws never read); on a fresh read 5 rows are not reached and 23 leftovers reaching the family are not named.

Plan approved 2026-11-09: `~/.claude/plans/gleaming-doodling-matsumoto.md`.

## Todo

- ✅ Session and baseline; the order-table territory bug reaches no family row and the EU "enter into force" bug changes no family date (both stay parked); the 5 rows not reached are the reader's (Part rows and a heading left to an order), not the check's
- ✅ The check's own errors, test first: another law's provisions split from their Act by a range's dash or a list's commas, a repeal of another Act's section, a limit on a scheme's day (`Leftovers`)
- ✅ Own-clause reader fixes, test first: the Part and heading rows; a citation sentence's date; a statement's exceptions; a staged item purpose first; a "These provisions …—" head; an item's own provisions beside another Act's; 18 held readings move (Decision 2)
- ✅ Order reader fix, test first: a "the following" head's qualifier reaches its items, never a completing or place head; a day after a qualifier. `--fresh`: rows' faults 0, 5 leftovers (Decision 1: known). OH&S and Maritime Safety PASS before and after; OH&S 3 rows by the Part fix (HSWA 1974 Pts I, II, IV dated), Maritime unchanged; 6 held order readings move (Decision 2)
- ✅ Both catalogues regenerated (dry runs twice, cold: three regressions found and fixed between); 24 new patterns (12 pending, none reaching the family), 19 leftover groups given a status; Decisions 1 and 2; `--accept`; 36 held readings moved (23 written, 13 rotated out); `mix test` 10,506 pass
- ✅ Re-read and rebuild (Jason's go): restore point (7 s); own clauses 122 laws (261 rules); orders (113 title searches, 116 listed, 108 held, 8 not held); 80 amenders (230 rules); build 220 s. The stored check then found an order list's overlap wiping another law's order rules, fixed (`Store.write commences:`) with a staged-start fix and SSI 2006/19's whole-Act form; orders re-read and rebuilt
- ✅ Stored check PASS (rows' faults 0, leftovers not named 0); seed 67 twice identical; golden 27/27
- ✅ Pass and close: `mix test` 10,512 pass; WORKFLOW step 4; RULES known-limits row; the skill's steps and history; meta row; commits

## Pass rule (fixed)

1. Stored check PASS: our faults 0 (not reached, no rules), every leftover reaching the family `known:`.
2. Every undated change has a reason.
3. Both catalogues regenerated; new patterns accepted, fixed or `pending:`; `CommencementPatternsTest`, `OrderPatternsTest`, `LeftoversReviewTest` pass; no held expectation moves without Jason (dry run, decision, `--accept`).
4. Seed 67 twice: samples and reports identical.
5. Golden 27/27.
6. `mix test` 0 failures; Credo ratchet; hooks.

Frozen: `golden.exs`; held expectations in both catalogues' `expected.json`. Triage size: a form reaching 10 rows or more, or in two or more laws, is fixed; below that, a named known limit (Decision 1).

## Dependencies

- ✅ Environmental Protection: Markup reader closed (2026-11-09, pushed d13a7131)

## Baseline (2026-11-09)

Reports: `backend/data/reports/commencement-reader/environmental-protection-0.txt` (stored), `-0-fresh.txt`, `gate-environmental-protection-2026-11-09.txt`.

| | Stored | Fresh |
|---|---|---|
| Dated | 18,265 | 27,600 |
| Left to orders | 5,090 | 4,872 |
| No rules (fault) | 9,533 (55 laws) | 0 |
| Not reached (fault) | 421 | 5 (Environment (Wales) Act 2016 pt.7; Environment Act 2021 pt.3) |
| Gaps (undated changes, each with a reason) | 2,742 | 2,742 |
| Leftovers reaching the family not named | 23 | 23 |

The 23 leftovers, by class (the plan's table): a citation sentence's date (6 laws); a whole-law or Part statement's exception (4); an order head's purpose qualifier (2, parked class); a staged item qualifier first (1); a "These provisions …—" head (1); the check's own errors (4); one-statement wordings (4).

### Todo 1 findings

- **Order-table territory** (SI 1988/818 on the Control of Pollution Act 1974): the Act holds no LAT rows in this family. 0 rows reached; stays parked.
- **EU "enter into force"**: the family's 10 EU laws are dated by `LawStart.Eu` (the Ecodesign regulation (EU) 2019/1010 from EUR-Lex, 2022-01-01) or are known limits (7 directives, 2 publication-relative regulations). The classifier words change no date here; it stays with Making laws.
- **The 5 rows not reached** are a reader miss, so they move from the check's todo to the own-clause fixes:
  - the Environment Act 2021's pt.3, pt.4 and pt.5, and the Environment (Wales) Act 2016's pt.7. These are Parts whose sections are named one by one under different dates; no rule names the Part.
  - the 2016 Act's h.81, a cross-heading whose first section (s.81) is left to an order.
  - The reader dates a cross-heading from its first dated provision (`OwnCommencement.evaluate/3`), but has no such step for a Part, and none when every provision under the heading is left to an order. Fix: a Part takes the same step (its provisions to the next Part), and a heading or Part with no dated provision takes its first provision's outcome (left to an order).

### Todo 2–3: the fixes (2026-11-09)

Each has a unit test first: `leftovers_test`, `own_commencement_test`, `law_start_test`, `own_clause_test`.

- **The check** (`Commencement.Leftovers`). Another law's provisions are stripped before the dash and comma split ("sections 47–50 of the Countryside and Rights of Way Act 2000"; "sections 5, 6 and 28 of the Local Government Act 1999"). So is "the repeal of section 6 of the 1989 Act". "… for the scheme to come into force must not fall after …" is not a statement.
- **Part and heading rows** (`OwnCommencement.evaluate/3`). A Part no rule names takes its first dated provision, to the next Part. A heading or Part with none dated is left as its first provision is (left to an order).
- **A citation sentence's date** (`Clause`). "may be cited as …, shall come into force on …" (a comma for the "and"). "The title of these Regulations is …. They come into force on …" is a citation for the pronoun reading. The six laws are now read from their words, not the register's date.
- **Exceptions** (`Provisions`).
  - "apart from" is an exception, except inside brackets, whose bracket ends it.
  - The inline exception may hold brackets ("section 26(2)", "regulation 4(3) and (4)", "(apart from this section and paragraph 6(2) …)"), but never a ";".
  - A pointer ("in accordance with", "provided in", "specified in") is never what is excepted.
  - The asc 2026/4 test shows the effect: s.45 was dated 1 May 2026, the Part's day; it is now dated by its own statement.
- **A staged item purpose first** (`Provisions.open_item`). "insofar as …, on 16 November 2006" is the whole law partly; "for all other purposes, on 10 December 2006" is fully.
- **"These provisions …—"** heads its list as "The following provisions" does.
- **An item's own provisions beside another Act's** (`Provisions.weighted_refs`). Another Act's provisions ("sections 1 and 2 of the Control of Pollution (Amendment) Act 1989") and "the repeals to the <Act>" are stripped. The item keeps its own provisions; before, the whole item was dropped (2005 c.16 s.108(4)(a), (f): ss.3–5 and s.40 lost). An item still naming "to/of that Act" is dropped as before.

**Held readings moved: 18** (`CommencementPatternsTest`). Each was checked against its text; for Decision 2 with the catalogue run.
- **The parked "apart from" after a Part item** (1999 c.22 s.108(3)(b)): fixed. Schedule 15 is no longer dated whole.
- **An Act's bracketed exceptions subtracted and on Royal Assent:** asp 2003/1 s.62(2).
- **Items now read for their own provisions:**
  - 2005 c.16 s.108(3) and (4);
  - 1999 c.9 s.17(2) s.15, Sch.4;
  - 1994 c.29 s.94(3) ss.26, 60, 63;
  - 2007 c.28 s.245(2) ss.141–143, s.241;
  - 2022 c.30 s.170(4)(b) s.42;
  - 1971 c.78 s.294(2) "This section".
- **Another Act's provisions no longer read as the law's own:**
  - 1987 c.12 s.27;
  - 2000 c.21 ss.91, 142;
  - 1990 c.43 s.100;
  - asc 2023/4 s.53(5)(a);
  - SI 1996/186 reg.2, reg.4;
  - SI 1994/1096 reg.1.
- **The law-start rule carries the clause's exceptions; a pointer's ref dropped** (2001 c.16 s.138(2), 2000 c.32 s.79(1)). Neither changes a date.
- **SI 2004/827 reg.3:** an order's statement held in the sentence catalogue gains Sch.8. That reading was already noise.

### The fresh read after the fixes (2026-11-09)

Report: `backend/data/reports/commencement-reader/environmental-protection-1-fresh.txt`.

- **Rows' faults: 0** (5 not reached before).
  - Dated: 27,640 (was 27,600).
  - Staged: 993 (was 908).
  - Left to orders: 4,835.
  - Staged-start only: 526 (was 609).
- **Leftovers reaching the family not named: 5** (23 before). They are the 5 one-statement wordings of Decision 1.
- **Gaps:** unchanged, every one with a reason.

### The catalogue dry runs (2026-11-09)

Both runs go to a scratch copy of the fixtures (`--out`), because a run writes the generated fixture files even without `--accept`.

- **First sentence run** (cold, 281 s, 3,028 laws, 8,963 sentences, 0 unclassified).
- **The same run at the last commit's code over today's store** (4½ min) separated what is this step's from what is the store's: the store has gained laws since the last run (15 unstatused groups at the old code). Against it, this step's code:
  - clears the leftovers of 41 statements;
  - gives 15 statements new leftovers;
  - changes 8.
- **Three regressions found that way, fixed before the second run:**
  - A purpose-first list item ("for the purposes of regulation 4 …, on 1st May 2007": SI 2004/1261, SI 2005/2759) was read as the whole law. It now applies only to an item that names none of the law's own provisions.
  - The pointer check in the exception split stopped "except the provisions mentioned in subsection (1)" being followed into that subsection (2022 c.30 s.170(2), 2007 c.27 s.94(1), SI 1988/1324). It is now kept only on a general clause's inline exception. That returns 2000 c.32 s.79(1) to its held reading.
  - Three statements now in an existing `fix:` class (SI 2007/765, NISR 2011/127, NISR 2012/187) read the same at the old code. They differ only in the catalogue's input and already carry a status.
- **Held readings moved: 35** (sentence and order, the pending examples counted). The 9 pending sentence examples are this step's forms now read: the comma and titled citations, the titled pronoun, 1980 c.65 s.120, SI 2019/1440 reg.27. 11 other pending examples read differently at the old code too, and are not this step's.

## Decision 1 — five one-statement wordings: known limits?

**Question.** Five commencement statements reaching the family each have words no rule uses. Each is one wording in one law, and each reaches at most a few of the family's rows. Should they be named known limits, so the gate passes, or fixed in this step?

**Aim:** `binds-on-date`. A provision's in-force date comes from the law's own words; where a wording is not read, the date falls back to an order, the feed or no date, with a reason.

The five:
1. **A day another instrument sets.** WSI 2006/2797 art.3: "section 2 (gating orders) comes into force on the date on which the Highways Act 1980 (Gating Orders) (Wales) Regulations 2007 come into force". This is s.2 of the Clean Neighbourhoods and Environment Act 2005 in Wales. The day is the other Regulations' own start, which we would have to read from that instrument. The leftover's reach (718) is the whole Act's rows; the statement dates only s.2 in Wales.
2. **An item's bracketed exception.** 2007 c.28 s.245(2), an amending law: "Chapter 1 of Part 5 (except section 116)". s.116 is not left out of the item. 3 family rows.
3. **An item qualified by its entries.** 2007 c.28 s.245(4): "section 241 so far as relating to those entries" is not read. 3 rows.
4. **An inverted statement.** asp 2001/8 s.81(2), an amending law: "There shall come into force at the end of the period of fourteen days beginning with the day of Royal Assent sections 1, 4, …" reads nothing. 1 row.
5. **"The provisions to which this subsection applies"**, by order in England and in Wales. 2008 c.17 s.325(4), an amending law. Both days are left to orders, so no date is lost. 1 row.

**Options.**
- **(a)** Name all five as known limits in `leftovers.json` (`known:`), one line each, and in RULES.md's known limits as one row: commencement wordings below the triage size.
- **(b)** Fix them in the reader now. That means five new forms, each tested, for at most 8 rows.

**Recommendation: (a).** Each is below the plan's triage size (under 10 rows, one law), as RULES' rabbit-hole rule asks. Form 1 is the only one with a date to lose. A real fix needs the other instrument's start (Sources). If more such forms turn up, it can be parked as a class.

**Decided (Jason, 2026-11-09): (a), known limits.** The five are named apart in `leftovers.json`: the order's in the order catalogue's file, the four sentences in the sentence catalogue's. A RULES.md known-limits row is added at close.

### The order fix and the other families (2026-11-09)

- **The order reader** (`Commencement.Order`). A "the following …" head's own qualifier, before its list, now reaches each item with none of its own. "but only insofar as they enable the Secretary of State to give directions" (SI 1993/274 art.2(2)) and "for the purpose of making regulations …" (SI 2015/425 art.2) are now partial.
  - A head that completes ("so far as not already commenced", "To the extent to which they have not already been commenced", "(in so far as not coming into force under article 2(9))") is not a qualifier.
  - Nor is a place ("in relation to England"; "Except to the extent that they extend to Scotland").
  - A day after a qualifier (", for the purpose of …, on the day after …") is read.
- **6 held order readings move**, each to partial: SI 2015/1329, 2025/1370, 2002/2306 (for making regulations), SI 1993/274, SI 2012/873 ("so far as is necessary for the purposes set out in paragraph (2)"), and SI 1994/1096 ("save for the purposes of their application to …", already partial for the items listed elsewhere). For Decision 2.
- **OH&S and Maritime Safety**, fresh read before and after: both PASS both times.
  - Maritime Safety: unchanged.
  - OH&S: 3 rows move from left-to-orders to dated, HSWA 1974 Parts I, II and IV, each now taking its first dated section's day (the Part fix). The golden run will check them.
  - Reports: `backend/data/reports/commencement-reader/{ohs,maritime-safety}-after-ep-{before,after}.txt`.
- **The first order catalogue dry run** (scratch `--out`, 42 s, 705 orders held, 4,024 statements, 0 unclassified) found two more forms, fixed with tests before the cold sentence run:
  - a qualifier after a made-relative day is the subject's ("… on the day after this Order is made so far as they relate to the repeal of …": SI 2009/1261 art.4, read as full);
  - "in relation to England" is a place in the leftovers check, never a qualifier (SI 2009/2096 art.2(2), the check's error).
  - This moves one more held order reading to partial: SI 2010/2191 art.2, "… on the day after … made for the purpose of enabling regulations to be made". Order moves: 7.
- **Credo:** `Provisions.except_refs/2` reached complexity 10, so its inline forms were split out (`inline_except/1`). The pointer check stays on the first form only, because a later form's pointer is followed into the provision it names (1994 c.21: "the provisions specified in subsection (6) below").

## Decision 2 — the catalogues: new patterns and moved held readings

**Second dry runs** (after the three corrections; scratch `--out`):
- order catalogue: 705 orders, 4,024 statements, 0 unclassified, 4 new patterns, 3 gone;
- sentence catalogue: cold, 274 s; 3,028 laws, 8,963 sentences, 0 unclassified; 780 patterns, 20 new, 13 gone.
- Every leftover group now has a status: 19 new groups (17 sentence, 2 order). Four carry specific text (2016 c.11 s.72(2) and SI 2006/1244 reg.1(4) `known:`; SI 2019/1440 reg.1(3) and 2007 c.28 s.245(2)'s group), and the rest the class wording.

Detail: `backend/data/reports/commencement-reader/environmental-protection-catalogue-review.txt` (each new pattern's examples as read, and each move, now against held).

**Question.** Accept the new patterns with the statuses below, and move the 35 held readings to how the reader now reads them?

**Aim:** `binds-on-date`. The catalogue holds what each wording reads as, so a change in reading is seen and reviewed.

**New patterns, proposed statuses.**
- **Order (4), all accepted:**
  - "the following …" heads now partial (SI 2012/873, 2015/425, 2025/1370; SI 2010/2191's whole-Act form);
  - SI 2009/1261 art.2 (Schedule 11's excepted paragraphs; schedules are not parsed);
  - SI 2020/216 "for all remaining purposes", full.
- **Sentence (20).**
  - **8 accepted**, read right: a mention (SI 2017/582); an order's own sentences (SI 2007/2194, two); "may be cited as …, come into force on …, and take effect …" (SI 2018/396); "on exit day" (SI 2019/584); "for the purposes for which Schedule 26 … is in force" partial (2026 c.11); "Subject to paragraph (2) this Order comes into force on the day after …" (SI 2007/1388).
  - **12 pending, each a form not read yet** (none reaches this family):
    - a completing aside read as a mention (2023 c.30);
    - a table's time (SI 2007/1388);
    - "forthwith" (NISR 2007/321);
    - "for the purposes referred to in that subsection on the day after …" (asc 2024/6);
    - "(and has effect in relation to …)" and "has effect in relation to acts …" read as qualifiers (2026 c.11, two);
    - a list item continuing its head (2016 c.1);
    - an order's own article read as its Schedule (SI 2012/1923);
    - "(and section 15 in so far as …)" making the whole list partial (asc 2024/6);
    - part of a law read as the whole on IP completion day (SI 2020/1091);
    - a day tied to another law's commencement (2023 c.30, 2026 c.11);
    - a defined or event day (NISR 2016/76).
- **Gone:** 13 sentence and 3 order patterns. Each is a pattern whose examples now read under the forms fixed (for example, the 1991 citation sentences now `law:clause_date`).

**Held readings that move: 35** (28 sentence, 7 order), each checked against its text above:
- this step's forms now read;
- another Act's provisions no longer read as the law's own;
- items' own provisions now read;
- purpose heads now partial.

Two that touch other steps:
- HSWA 1974 is not among them; its Part rows change only in the check, not in a held reading.
- SI 1994/1096 reg.2(1) now reads nothing, where it read an order's statement as the SI's own reg.1.

**Options.**
- **(a)** Accept the new patterns as proposed, and move all 35 held readings to the new reading. Written by the task (`--accept`) for the statuses; the 35 readings are written from the reader with the task's own encoder, then the tests run.
- **(b)** Accept the new patterns, but move only the readings in this family's laws; leave the rest failing for review one by one.

**Recommendation: (a).** Every move was checked against its text: three regressions were found and fixed, and none remains. The catalogue tests then pass whole.

**Decided (Jason, 2026-11-09): (a), accept and move all.**

- Written with `--accept` (both catalogues; the sentence run warm, 3,028 cache hits).
- 12 pending statuses set.
- The moved readings written from the reader with the task's encoder (`FeedPatterns.encode`): 23. Another 13 rotated out of the held examples as their patterns changed. One more surfaced only after the accept, because `laws.json` was regenerated: 1998 c.47 s.101(2)(c) "… section 100(2) so far as relating to that repeal", the Act's own s.100(2) now read partly. 36 moves in all.
- The pending examples keep the reading as read, tagged pending.
- `mix test`: 10,506 passed, 0 failures.

## Re-read, rebuild and the stored check (2026-11-09)

Reports: `backend/data/reports/commencement-reader/environmental-protection-{reread-own,reread-orders,reread-orders-2,reread-amending,rebuild,rebuild-2,2,3,4,5a,5b,golden}.txt`.

- **Re-read.**
  - Own clauses: 122 laws, 261 rules, 11 s.
  - Orders: 113 order-list title searches of legislation.gov.uk (the cache grew from 515 to 628 lists). 116 orders listed, 108 held and read; 282 s.
  - Held amending laws without LAT: 80 of 81, 230 rules.
  - Family build: 122 laws, 220 s.
  - 0 errors.
- **Not held** (for Sources, not fetched): 8 listed orders, under asc 2026/4 (1), anaw 2016/3 (1), the two EU Ecodesign regulations (2 each) and 2006 c.16 (2).
- **The first stored check failed** (rows' faults 416, leftovers 1), against PASS on a fresh read. Three causes, all this step's code, each fixed with a test:
  1. **An order listed under two laws wiped one law's rules.** SI 1996/1030's cached order list wrongly names three Environment Act 1995 orders (SI 1996/186, 1996/2857, 1996/2909). Read for SI 1996/1030, they give no rules, and the write replaced the order's `order_date` rules by source alone, so 957 rows of the 1995 Act fell back to left-to-orders. `Store.write/3` now takes `commences:`, and the law-order read replaces only the order's rules for the law it reads for.
  2. **A law whose only text rules tie its Schedules** (`schedule_effect`, written by `--read` but not by the check's fresh read) was "not reached" everywhere: SI 2020/206, 416 rows. It now keeps the outcome it has without them (staged start only).
  3. **SSI 2006/19 art.2**, an order the new lists brought in: "Subject to article 3, the provisions of the Environmental Assessment (Scotland) Act 2005, so far as not then in force, shall come into force, for all purposes, on 20th February 2006" read nothing. The whole-Act form now drops a lead "Subject to article N," and "the provisions of", and reads "not then in force" as completing. 234 rows are now dated. The order catalogue then gains 10 orders (715), with 0 new patterns and 0 moves.
- Then: orders re-read for the 122 laws (no searches), the family rebuilt (219 s), and asp 2005/15 re-read and rebuilt.
- **Stored check PASS** (`-4.txt`):
  - rows' faults 0;
  - dated 27,880, left to orders 4,595;
  - leftovers reaching the family: 6 named, 0 not.
- **My error, recorded:** the 81 "held amenders" passed to `--read-amending` included 21 commencement orders, which the gate itself leaves out. Reading an order's own clause is what an earlier amending read did too (its self-rules held at the restore point, 2026-11-08), so no rows were removed. But the list should leave orders out, as the gate does.
- **Repeatability:** seed 67 twice; the samples are identical under `cmp`, and the reports differ only in the sample's file name (`-5a.txt`, `-5b.txt`).
- **Golden:** 27/27, one worker, 4 min 48 s (`-golden.txt`).

## Parking list

- Commencement reader: order-list-wrong-law — a law's cached order list (from the title search) names another Act's orders (SI 1996/1030 lists three Environment Act 1995 orders); harmless since `commences:`, but the search's match should be checked
- Commencement reader: cited-orders-write-overlap — `--read-orders` without `--law` (the amending Acts' cited orders) still replaces an order's rules by source alone; one order cited for an Act and listed for another would lose one set
- Commencement reader: fresh-read-without-schedule-effects — the check's `--fresh` reads own clauses without `ScheduleEffect`, so fresh and stored differ where a Schedule is tied (SI 2020/206); the stored run is the pass
- Commencement reader: re-read-amenders-list — the step's held-amenders list for `--read-amending` should leave orders out as the family gate does (a task option, not a hand list)
