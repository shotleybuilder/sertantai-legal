---
session: 'Commencement catalogue: leftovers'
status: closed
opened: '2026-11-05'
closed: '2026-11-05'
step: Commencement reader
outcome: partial
summary: 'A check in code for the long tail of commencement forms: every commencement statement held (8,480 sentences, 3,496
  order statements) has the words bearing on a date that no rule uses listed, grouped and ranked by reach, inside the two
  catalogues, no agents. After review the sentences hold 256 groups (403 statements) and the orders 71 (229), every group
  with a status. Partial: 4 check errors stay open in the top 20s and the corpus runs exceeded the plan (4 and 5, not 2).'
decisions:
- what: 'Decision 1 (c): the family gate first (lat.commencement_check prints the leftovers reaching the family), then fix
    by class corpus-wide by reach'
  why: a step passes on code over every statement; fixing works down a ranked list, never a sample
  result: WORKFLOW.md step 4; next sessions
- what: 'Statuses: the top 20 of each catalogue by hand, the rest by class (fix: reads nothing / half-read, kinds, count,
    reach)'
  why: about 330 groups; the plan reviewed the top 20, and the class status keeps the rest counted, not hidden
  result: 'leftovers.json: sentences 252/2/2, orders 68/1/2 (fix/known/check)'
metrics:
  sentences:
    statements: 8480
    laws: 2787
    groups_first_run: 480
    statements_first_run: 1219
    groups: 256
    statements_left: 403
    fix: 252
    known: 2
    check: 2
  orders:
    statements: 3496
    groups_first_run: 140
    statements_first_run: 1035
    groups: 71
    statements_left: 229
    fix: 68
    known: 1
    check: 2
  runs:
    sentence: 4
    order: 5
    planned_each: 2
  tests:
    leftovers: 18
    review: 2
    suite: 9937/9938 (1 Extent reader, parked)
  cost:
    days: 1
    plan_changes: 0
    agent_tokens: 0
lessons:
- title: A leftover check finds what samples found, and the rest of their class
  detail: Every Maritime agent finding is a leftover; the corpus run also surfaced parked OH&S classes (an order list cut
    at "(except …)", "section 10(6) and (7) (so far as aforesaid)") by count, and new ones ("This Act (apart from this section
    and section 56(1)) …" with no exception subtracted).
  tag: tooling
- title: A check needs its own precision pass before its counts mean anything
  detail: 'The first run was mostly the check’s own errors (orders’ own articles, resolved relative days, pointers, other
    instruments): 480 → 256 sentence groups and 140 → 71 order groups came from fixing the check, not the readers. Review
    the top groups against their text first.'
  tag: tooling
- title: Name the run budget by refinements, not runs
  detail: Each refinement needs a fresh 10-minute catalogue run; the plan named 2 runs and 4 were needed. Plan one run per
    refinement, at most N refinements.
  tag: tooling
bugs:
- pattern: 'Open check errors in the leftovers check: "different days may be appointed … in relation to" read as a qualifier
    (1963 c.41); a SentencePatterns mention read as a statement (SI 2015/1947); "Subsections (1) to (3) … of section 190"
    named as s.190 (SI 2009/2260); "(in so far as those sections are not already in force)" not completing (SI 1998/604)'
  category: leftovers-check-precision
  module: commencement/leftovers.ex
  affected: 4 groups (top 20s)
  fix: power phrase, SentencePatterns role, finer-scope coverage, completing "those … are"
  step: Commencement reader
  status: open
- pattern: Own-clause and order statements read as nothing or half-read, ranked in leftovers.json (orders’ tables "specified
    in column 1 of the Schedule" unread, 123 statements; qualifiers read as full, 27; "This Act (apart from this section and
    section 56(1)) …" no exception)
  category: commencement-leftovers
  module: commencement/order.ex, law_start/provisions.ex
  affected: 632 statements (403 sentences, 229 order)
  fix: by class, widest reach first (Decision 1 c), after the family gate
  step: Commencement reader
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/commencement/leftovers.ex
- backend/test/sertantai_legal/scraper/commencement/leftovers_test.exs
- backend/test/sertantai_legal/scraper/commencement/leftovers_review_test.exs
- backend/test/fixtures/commencement_patterns/leftover_groups.json, leftovers.json
- backend/test/fixtures/order_patterns/leftover_groups.json, leftovers.json
- backend/data/reports/commencement-reader/leftovers-2026-11-05.txt, leftovers-orders-2026-11-05.txt
- docs/lat-change-pipeline/WORKFLOW.md (step 4)
depends_on:
- 2026-11-05-maritime-safety-commencement-reader.md
enables:
- 'Commencement reader: the family leftovers gate (lat.commencement_check)'
- 'Commencement reader: fix the leftover classes by reach'
---

# Session: Commencement catalogue: leftovers (CLOSED)

## Problem

On Maritime Safety the Commencement reader step's two agent rounds (274k tokens) were whack-a-mole: each found a few one-law forms (Jason: "we've regressed … how to surface the long tail of patterns in a systemic and comprehensive way"). Every form was a half-read sentence: a date, provision, exception, qualifier or relative day in the text that no rule read from it uses. The catalogue classes sentences by form and outcome, never by whether each such word was used. This session builds that check in code, inside the catalogues, ranked by the rows and changes each leftover reaches.

- **Plan (approved 2026-11-05):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`; principle `law-text-wins`; `checks-in-code`. **Time box:** one day; no agents.
- **Known forms (the tests):** SI 2018/1107 ("30th November 2019" after ";"), SI 2012/3152 ("12th January 2013", no ";"), SI 2012/2267 (exception "regulation 3(3)(b)"), SI 1996/3146 ("except sections 85 to 87" read as the scope), SI 2007/3075 ("6th April 2008", "in relation to"), SI 2004/1495 ("1st July 2005", "for international shipping"), SI 2018/1221 ("the 22nd day after … laid"). Evidence: `2026-11-05-maritime-safety-commencement-reader.md`.

## Todo

- ✅ Session
- ✅ The known forms as tests (red): `leftovers_test.exs`, 8 tests (the 7 forms, old reading → its leftover, current → none; SI 2018/1221, a named known limit, keeps its leftover; plus never-counted cases)
- ✅ `Commencement.Leftovers` and `Provisions.refs_in/3`, `Order.refs_in/1` (green, 8 pass)
- ✅ Into the catalogues: `lat.commencement_patterns` and `lat.order_patterns` write `leftover_groups.json` and a ranked report; `OrderPatterns.own_rules/2` exposed; a trial on 9 laws found 3 check errors (fixed: parentheses split refs, item rules carry the reader's sentence, a power to provide for commencement)
- ✅ Corpus runs and review: sentences 480 groups / 1,219 statements → 256 / 403; orders 140 / 1,035 → 71 / 229, as check errors were found in each top 20 and fixed (with a test each). 4 sentence runs and 5 order runs (the plan named 2 each); 4 check groups stay open in the top 20s (`check:` in the lists)
- ✅ The reviewed lists `leftovers.json` (both catalogues) and `leftovers_review_test.exs`: sentences 252 fix / 2 known / 2 check; orders 68 / 1 / 2; top 20 of each by hand, the rest by class
- ✅ Decision for Jason: (c) the family gate first, then fix by class (Decision 1); WORKFLOW.md step 4 updated
- ✅ Close: `mix test` 9,937/9,938 (the 1 is the Extent reader's version coverage, parked); commits

## Pass rule (fixed)

1. The 7 known forms each give their leftover from the old reading, none from the current.
2. Both catalogues report leftovers over the whole corpus, 0 unclassified; report written.
3. Top 20 groups by reach reviewed by hand; after one refinement none is a `check` group.
4. Every group has a status in `leftovers.json`; its test passes.
5. `mix test` passes; catalogue tests unchanged.

## Dependencies

- ✅ Maritime Safety: Commencement reader closed (2026-11-05)

## Results (2026-11-05)

**The check** (`Commencement.Leftovers`, 18 tests) runs inside both catalogues in their usual time, 0 unclassified, no held catalogue reading moved. Reports: `backend/data/reports/commencement-reader/leftovers-2026-11-05.txt` (sentences) and `leftovers-orders-2026-11-05.txt`.

**Check errors found and fixed by review (each with a test):** list items carrying the reader's sentence; parentheses splitting refs; a power to provide for commencement; a relative day the reader resolved to a date; pointers ("Except as provided by", "Subject to", "to the extent specified in"); no time and no rule; another instrument's commencement (also after a lead-in); orders' own articles; a Schedule's table rules; Schedules never counted; completing forms ("insofar as it is not already in force", "to the extent that … not in force"); containers ("provisions of Part 1"); the whole law's one time.

**Open check errors** (`check:`, in the top 20s): "different days may be appointed … in relation to" (1963 c.41); a SentencePatterns mention read as a statement (SI 2015/1947); "Subsections (1) to (3) … of section 190" named as s.190 (SI 2009/2260); "(in so far as those sections are not already in force)" (SI 1998/604).

**What it surfaced — the `fix` groups, by kind** (reach: rows or changes, summed by group):

| Catalogue | Kind | Groups | Statements | Reach |
|---|---|---|---|---|
| orders | reads nothing — dates (tables, "specified in column 1 of the Schedule", following lists) | 18 | 123 | 67,418 |
| orders | qualifier read as full ("but only insofar as", "save for the purposes of", "for the purpose of enabling regulations") | 13 | 27 | 24,101 |
| orders | reads nothing — qualified ("so far as required for …") | 15 | 32 | 18,892 |
| sentences | reads nothing — dates and relative days (list items, "These provisions …—", "22nd day after … made") | 54 | 112 | 16,203 |
| sentences | reads nothing — provisions (event days, unread items) | 34 | 49 | 14,399 |
| sentences | reads nothing — qualified statements | 47 | 80 | 11,491 |
| sentences | half-read — dates, provisions, qualifiers, exceptions ("This Act (apart from this section and section 56(1)) …", "This section and the following provisions …") | 115 | 154 | 24,037 |

Among them are classes already parked from OH&S (an order list cut at "(except …)"; "section 10(6) and (7) (so far as aforesaid)" read as s.10(6) only) — the check finds parked bugs by count.

## Decisions for Jason

### 1. What to do with the surfaced classes — DECIDED (c), Jason 2026-11-05

- **Question.** The check lists every half-read or unread commencement statement over the corpus, ranked. Which do we fix, and when?
- **Aim:** `binds-on-date`; the retrospective's `checks-in-code` (a family starts from a ranked list, not a sample).
- **Options:**
  - (a) **Fix by class, widest reach first, in a following session**: the orders' unread tables and lists, then qualifiers read as full, then the own clauses' unread list items and relative days. Each fix is measured by its groups' counts falling in the two catalogues, with no agent rounds.
  - (b) **Gate by family.** `lat.commencement_check` prints the leftovers reaching the family's laws, and a step passes when each is fixed or named. Fixing is done step by step for each family.
  - (c) **(b) now, then (a)**: the gate first, so the next family (Maritime's later steps, or the next family's Commencement reader) sees its own list; then (a) as its own session.
- **Recommendation:** (c). The gate makes the step's pass rule code over every statement. Then (a) works down the corpus list by reach, never by sample.

## Parking list

- Commencement reader: the catalogue's exact-text sentence matching (`SentencePatterns.outcome/2`) misses rules read from part of a sentence.
- Evidence (or its own session): legislation.gov.uk's `RestrictStartDate` as an independent yardstick over every row.
- Feed, Markup, Extent readers: the same leftover idea for their inputs.
