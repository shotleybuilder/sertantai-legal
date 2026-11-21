---
session: 'Waste, Water and Climate: Commencement reader'
status: active
opened: 2026-11-20
family: Waste, Water and Climate (round)
step: Commencement reader
bugs:
  - pattern: "An SI's own expiry ('shall cease to have effect on …') is carried by no source where its feed holds no expiry effect (SI 2001/1623, SI 2001/1478); SI 2003/3341's is in the feed, stored as repealed"
    category: own-expiry-not-carried
    module: commencement/own_clause (an end date carried as a fact for the fold)
    affected: 2 laws seen; corpus unmeasured
    fix: "carry an own clause's expiry date as a repeal claim, measured over the store first"
    step: Commencement reader
    status: open
  - pattern: "An amending Act held in the register with no made or enactment date, so a period it counts from its passing cannot be dated (Housing (Scotland) Act 1987 c.26 s.340(2): md_made_date and md_enactment_date empty)"
    category: register-act-no-enactment-date
    module: register (uk_lrt md_enactment_date)
    affected: 1 law seen (3 reach in the round's leftovers)
    fix: "fill the Royal Assent date from the Act's introduction or the register scrape; measure how many Acts lack it"
    step: Register
    status: open
  - pattern: "Acts' amending provisions read as starting at Royal Assent (2006 c.36, 2015 c.15; 2011 c.8 reads right)"
    category: amender-start-royal-assent
    module: commencement/amending, readers/amender_start
    affected: about 113 changes (sized 2026-11-14), unmeasured since
    fix: "date an Act's amending provision by its own clause or orders, never Royal Assent where the clause says otherwise"
    step: Commencement reader
    status: open
  - pattern: "The law's date for an amending provision differs from the feed's (2003 c.39 Sch.8 para.56 on 1883 c.3 s.6(1) undated: appointed; 2017 c.3 s.12(2) on SI 2005/1541 reg.2)"
    category: amender-date-differs-from-feed
    module: commencement/amending
    affected: about 9 changes
    fix: "trace the own-text pointer; the feed gate names it at resume"
    step: Commencement reader
    status: open
  - pattern: "The shared namer drops nested schedule ids (schedule-N-part-P-paragraph-M named sch.N.pt.P)"
    category: namer-nested-schedule-ids
    module: change_vocabulary readers' namer
    affected: 48 feed collisions, no body rows
    fix: "name nested schedule paragraphs in full"
    step: Commencement reader
    status: open
  - pattern: "Commencement.HeldAmenders counts nil-op changes as amenders to read"
    category: held-amenders-nil-op
    module: commencement/held_amenders
    affected: 39 laws
    fix: "count only changes with an operation"
    step: Commencement reader
    status: open
  - pattern: "A dash-ended item under regulation 15 leaves its rows not reached (SI 2007/605 reg.15, on stored rules too)"
    category: nested-regulation-items-not-reached
    module: law_start/nested_items
    affected: 6 rows, 1 law (Road Safety)
    fix: "read \"in regulation 15 —\" items under their regulation"
    step: Commencement reader
    status: open
  - pattern: "\"come into force on [date]— (a) to enable …\" stages read as full, and \"for all other purposes\" as partial — inverted (SI 2017/701 reg.1(2)-(6))"
    category: to-enable-stages-inverted
    module: law_start/clause
    affected: 1 law
    fix: "read \"to enable\" items as purposes of the whole law's first stage"
    step: Commencement reader
    status: open
  - pattern: "A Parts list's sub-provision exceptions dropped (1963 c.33 s.94(2): \"other than sections 17(6), 48(2), 62(4), 66, 69, and 70\" excepts only ss.66 and 69)"
    category: parts-list-subprovision-exceptions
    module: law_start/provisions
    affected: 1 law
    fix: "carry each excepted provision, subsection or not"
    step: Commencement reader
    status: open
  - pattern: "A list naming this regulation, numbered provisions and a qualified one reads as the whole law partly (SI 2018/1251 reg.1(2); held pending with its correct reading)"
    category: this-regulation-list-read-as-rest
    module: law_start/provisions
    affected: 1 law seen
    fix: "read \"This regulation, regulation 6(2), (4) to (6) …\" as the provisions named"
    step: Commencement reader
    status: open
  - pattern: "The store holds a document legislation.gov.uk served for another path under the path asked (the Welsh SI 2005/423, 2006/1279, 2002/2024 under uksi/)"
    category: store-redirected-document
    module: legislation_gov_uk/clml_store (client store on redirect)
    affected: 3 orders found; the reader now refuses them (Order.HeldAs)
    fix: "store a redirected answer under the path it was served from"
    step: Sources
    status: open
---

# Session: Waste, Water and Climate: Commencement reader (ACTIVE)

## Suspended (2026-11-21)

Suspended after Settle and the push, for the commencement reader's code review (architecture and speed), its own session (Jason). **On resume:**
1. the feed gate's groups named and fixed by class (Decision 5), with the 36 `check:` leftover groups and SI 2018/1251;
2. the review's findings Taken;
3. Settle again for any held moves;
4. Rebuild then fetch (restore point, re-read, fetch WSI 2002/2024 and the round's unheld orders, one rebuild);
5. Check, the step close and Close.

## Problem

The round's first commencement reading (565 laws). 210 round laws are stale for this reader since the Sources build, and 25 Commencement reader bugs are parked from earlier families. The plan (approved 2026-11-20) fixes them, test first, or sizes them with a reason, then re-reads and rebuilds the round.

## Todo

- ✅ Measure: open the session and meta row; Sources gate; baseline on stored rules and `--fresh`; the 25 parked bugs read in with their reach
- ✅ Find: both catalogues dry run into scratch; new patterns and leftover groups sorted into fix / known / check
- ✅ Fix (2026-11-21; group C's last forms and the namer and nil-op counts parked by Decision 3; the feed gate's fixes wait for the resume): fixer calls by group (A own-clause, B orders, C amending-law dating, D golden, lists, namer; EU entry-into-force sized first), each reviewed with reach, golden and the suite
- ✅ Code review: its own sessions, closed 2026-11-21 — Commencement Reader Code Review (Decision 1 (a): the new loop), Commencement Reader Speed Fixes (all Taken findings fixed, output identical) and Catalogues Across the Workflow (the catalogues cached and recorded)
- ✅ Resume 1, Find once (plan approved 2026-11-21, `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`): the round's `--fresh` check with the feed gate, the four switched families, both catalogues; the work list in `backend/data/reports/commencement-reader/wwc-resume-work-list.md`; the per-round logs moved out
- ✅ Resume 2, Decide before fixing: Decision 7 (2026-11-21)
- ⬜ Resume 3, Fix by class: the session fixes, test first, cheap checks per fix
- ⬜ Resume 4, Settle once per batch: suite, Dialyzer, round and switched checks with the gate, both catalogues; held moves to Jason
- ⬜ Rebuild then fetch: restore point; the orders fetch decided; re-read (own, held orders, amending `--workers 1`, sources' stale rules); one round rebuild; Sources gate; NAS sync
- ⬜ Check: round and four switched families' checks; seed 73 twice; extended golden; `mix test`, architecture, Credo
- ⬜ Step close: `mix lat.step_close --family "Waste, Water and Climate" --step "Commencement reader"`
- ⬜ Close: RULES, WORKFLOW, skill history, meta row, session close, commits by path, step report

## Dependencies

- ✅ Waste, Water and Climate: Markup reader closed (2026-11-20, pushed 590d315a)

## Parking list

- Commencement reader (own session, next): code review of the commencement reader, architecture and speed, against `.claude/review-standards/code.md` (deferred from this step, Jason 2026-11-21; Jason starts it after this session closes).
- Label fold (question): the law as a whole's commencement label as a read-through of its provisions' labels on the date picked (Jason 2026-11-20) — not held anywhere today; decide whether the fold or Measures shows it.

- Register: register-act-no-enactment-date — 1987 c.26 held with no Royal Assent date (frontmatter).

- Commencement reader: own-expiry-not-carried — an SI's own "shall cease to have effect on …" is carried by no source where the feed holds no expiry (SI 2001/1623, 2001/1478); an end date is a new fact for the fold. Size: 2 laws seen, corpus unmeasured.

## Before the suspension (Measure, Find, Fix, Settle; 2026-11-20 to 21)

The full log is in `backend/data/reports/commencement-reader/wwc-commencement-reader-log.md` (calls, scans, decisions as written). The decisions:
- **Decision 1:** run to zero new patterns by a misread scan in code, then fix by class.
- **A whole law brought in for a purpose is partly in force**; refined: the partial label is a provision's, and the law's label is a read-through. Applied to SI 2015/776, SI 1991/346, SI 2018/1221 (`purpose-names-own-provisions`).
- **Decision 2 (SI 2018/1221):** the provisions a narrow purpose names are fully in force on the first day, the rest on the last day, none partly.
- **Decision 3:** no more Fable fixer calls this step; small fixes in-session.
- **Decision 4:** EU "shall apply from" is the start (`eu-applies-from-is-the-start`); directives excluded; Making's logic holds.
- **Decision 5:** the feed comparison is a two-way gate in this step.
- **Decision 6:** the 61 held readings that moved, accepted (54 own and 5 orders written; SI 2018/1251 pending).

## Resume 1: Find, once (2026-11-21)

- **Runs** (`backend/data/reports/commencement-reader/wwc-resume-*.txt`), about 7 min in all:
  - the round's `--fresh` check: 135 s (about 8 min before the speed fixes). Our faults 0; leftovers not named 7 (4 `fix:`, 3 `check:`).
  - the four switched families: all PASS.
  - both catalogues: no new pattern.
- **The work list:** `backend/data/reports/commencement-reader/wwc-resume-work-list.md`. Every class with every law; the gate now records each group's laws (`FeedDifferences`' `by_law`, test first).
- **The feed gate:** 58 groups, 13,592 rows:
  - the feed dates rows we leave to orders: 8,846 rows, 28 laws;
  - clauses unread: 1,440;
  - dated by our reading, the dates differing: 1,374;
  - the feed partial only: 577;
  - staged, differing: 451;
  - smaller classes (a staged clause's start only, partly only, no clause): about 800.
- **The per-round logs** moved to `backend/data/reports/commencement-reader/wwc-commencement-reader-log.md`.

## Decision 7 for Jason: the resume's work, decided before any fix

**The aim:** `binds-on-date`. Every round row's commencement read right or its reason named, with the feed as a two-way check (Decision 5).

**A. The orders never searched (fetch).** 17 laws, about 5,900 rows, are left to orders whose list has never been searched (`mix lat.commencement --read-orders` searches legislation.gov.uk). The largest are NISI 2006/3336 (3,548 rows), ASP 2011/9 (1,094), ASP 2009/12 (905) and ASP 2005/3 (422). The feed dates all of them.
- **Proposal:** search and fetch these 17 laws' orders at Rebuild then fetch, one process at a time. Until then their groups are `fix: fetch`.

**B. Our misreads (fix, test first, by class):**
- **"comes into force on the later of— (a) … (b) …"**: SI 2023/1394, 1,131 rows.
- **A Welsh Measure "approved by Her Majesty in Council"** as the day counted from: MWA 2010/8 s.21(2), 118 rows.
- **A tied day for one regulation, then "all other provisions … on <date>"**: SI 2006/641, 3 rows.
- **Held orders that reach none of the rows they commence**: 11 laws, about 2,900 rows. Examples: 2010 c.29 (15 orders held and read, 519 rows), ASP 2003/3 (9 held, no rules), ANAW 2017/3 (2 held, no rules). Examined law by law, then fixed by class.
- **A list missing a comma** ("20(2) 28(8)(a)(ii)"), with whole regulations dated by their latest part: SI 2013/3113, 187 rows.
- **The 4 `fix:` leftovers:** SI 1978/954 art.3's date; SI 2010/2169 art.3(2)'s power provision; 1968 c.47 s.60(2)'s qualifier; 1987 c.26 s.340(2)'s relative day (the last a Register gap).
- **The 3 `check:` leftovers** (SI 2010/2169 art.3(3), SI 2020/1095 reg.1(2), SI 2000/2911 reg.1), each reviewed into `fix:` or `known:`; and SI 2018/1251.

**C. A rule: inserted provisions.** About 1,430 rows are provisions another law inserted, which the host law's own clause dates (by its own clause date, or by order), while the feed dates them by their insertion. Example: 1991 c.56 s.2(2A)(e), which the clause dates 1991-12-01 and the feed 2015-12-18.
- (a) **The reader carries the clause's claim; the fold prefers the inserting law's date** for an inserted provision (readers carry, the fold means). The groups become `known: inserted, the inserting law's commencement`, and the Label fold is checked to rank it first (parked against the Label fold, measured there).
- (b) **The reader makes no claim on an inserted provision** (the host's clause never spoke of it). A change to the reader's output, for every family.
- **Recommendation: (a).** It keeps the reader's claims faithful to the text, and the choice belongs to the fold, which holds both sources.

**D. Where the feed is wrong (the two-way gate).**
- SSI 2020/154: our 1 October 2027 against the feed's 1 October 2025, about 160 rows. The current text defers Parts 2, 7 and 8 and Part 5 to 1 October 2027, so the feed's record is stale.
- **Proposal:** each group where the text and our reading agree against the feed is `known: the feed's record superseded by the text`, with its evidence, and parked against the Feed reader as legislation.gov.uk's error (source authority: the text wins where it speaks).
- The remaining smaller groups (about 1,900 rows) are examined in Fix and sorted into B, C or D.

**Recommendation:** A, B, C (a) and D as proposed.

**Decided (Jason, 2026-11-21): A, B and D as proposed. On C,** Jason: "inserted laws are dated by the law that inserts them (the amending law)? Is this really within Commencement scope?" Answered: yes, the inserting law's commencement dates an inserted provision, and the Commencement reader's amending-law dating (`Commencement.Amending`) is this step's. **Decided:**
- the gate leaves inserted rows out of the own-clause comparison;
- it judges each by its inserting law's commencement (the amending-law dating);
- whatever doesn't match there is a fix class in this step;
- the host clause's reading of the rest of the law is unchanged.

## Resume 3: Fix by class

- **C (be673fff):** an inserted provision is judged by its inserting law (`Check.inserted/3`), and left out of the own-clause gate. Of the round's 5,306 insertions both sides date, 5,028 agree.
  - 278 differ (14 laws): a fix class.
  - 2,325 the feed alone dates (the inserting law's text leaves them to an order, its rules not held, no amending law found): to be `known:`, the feed's date standing.
  - 417 we alone date: to be `known:`, ours filling the feed's gap.
  - 760 neither dates.
- **Also (47924a54):** the gate lists every law in each group (`by_law`).
- **B, "the later of" (96b82406):** the clause reader reads "the later of / the earlier of" its lettered items, and "the day which is N days after". SI 2023/1394: 1,397 rows dated, 1,273 agreeing with the feed. Two held catalogue moves for Jason at Settle: SI 2023/1394 (unread → 2024-01-03) and SSI 2019/436 (unread → 2020-12-31, exit day read as IP completion day by the existing rule).
- **Outside the step (Jason's go, 2026-11-21):** the dev stack's auth and hub moved to sertantai-stack. Legal's side is in 1aecec7b; Jason removed the auth and hub keys from `.env` by hand (gitignored, nothing committed).

