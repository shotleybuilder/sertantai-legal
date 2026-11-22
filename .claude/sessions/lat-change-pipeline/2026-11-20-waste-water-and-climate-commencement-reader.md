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
- **B, a Welsh Measure's approval (5424d0c7):** the made-day words take "approved by Her Majesty in Council"; `DateOfEnactment` reads a Measure's approval date from its enacting words; `Input` reads the introduction as made where the revised one isn't held. MWA 2010/8 is dated 2011-02-15, as the feed. MWA 2009/3 s.12(2) still lacks its approval day, because its introduction isn't held: it joins A's fetch list.
- **B, a named provision's tied day (21e85ae9):** "Regulation 15 … on the date on which section 7(3) of the Water Act 2003 comes into force, and all other provisions … on 1st April 2006". SI 2006/641: 315 rows dated, 309 agreeing with the feed; regulation 15 itself is left with the other provision (1 row, to name `known:`). Third held move: SI 2006/641's example.
- **B, SI 2013/3113 (8d694651):** a list run on without a comma ("20(2) 28(8)(a)(ii)"), and "schedule N, Part P, paragraph Q" read as the Schedule's Part, not the regulations' own. 1,326 rows dated, 1,111 agreeing, leftovers 0. A first version caught the Access to Justice Act 1999 s.108(3)(f) form; it was fixed before the commit.
- **Held moves for Settle so far:** SI 2023/1394, SSI 2019/436, SI 2006/641 (catalogue examples, each unread → dated).
- **B, held orders reaching none of their rows (round 2):**
  - **Two order forms (1e7456c6):** "The appointed day for X coming into force is D" (WSI 2018/35), and "D is hereby appointed the day on which X come into force" with "20th of May" (SSI 2005/256). `Order.statement/2` is split by form.
  - **A range covered a Chapter between its ends (6d7f44ce):** SSI 2003/562's "sections 1 to 7" covered Chapter 2, whose heading sits between s.1 and s.7, and through it s.8, s.9 and on (168 rows of ASP 2003/3). The fault predates the speed fixes. `LatRef`'s order-based range test now requires the element's own kind; the amendment evaluator's tests pass. ASP 2003/3: 306 rows agree with the feed, none differ (172 before).
  - **The gap-filler dated commencements by their commencing power's own start (33b71cf8):** 623 commencements in 9 laws whose feed record is prospective (ASC 2025/4, 2022 c.30, ANAW 2017/3 …). Now undated (`:a_commencement`). Their labels change at the rebuild.
  - **The gate's yardstick read our gap-filler's date as the feed's (2bf91cd1):** it now reads the feed's own date claims. ANAW 2017/3: differences 199 → 1, agreements 161 → 360.
- **Left in this class:** 2010 c.29's 519 rows, ANAW 2017/3's 520 rows the feed alone dates (WSI 2018/35 art.3 and later), ASP 2003/3's 91, and the 8 smaller laws.

## Decision 8 for Jason: a change the feed marks prospective, which our gap-filler dates

- **The question:** 3,200 text changes are marked prospective (not yet in force) by legislation.gov.uk's feed. They are insertions (213), repeals (361), substitutions (60), and changes with no operation (2,564), in 48 laws. Our gap-filler dates them by the amending law's own commencement. Which wins?
- **The aim:** `binds-on-date`. Their labels say in force where the feed says not yet.
- **Options:**
  - (a) **The feed's prospective record wins:** a change the feed marks prospective is no gap. Its label stays prospective until the feed dates it. Simple; trusts the feed (Decision 5: any law's feed can be trusted).
  - (b) **Our dating wins where the amending law's text dates it:** the feed may lag. Each such change becomes a two-way gate group, `fix:` on whichever side is shown wrong.
  - (c) **Measure first:** sample 20 of them against the amending law's text, then decide.
- **Recommendation: (c), then likely (a).** The commencements showed our gap-filler can misdate a change the feed calls prospective. Twenty samples, a few minutes each by script, show whether that is the rule or the exception for text changes. *(Superseded below.)*
- **Jason's point (2026-11-21):** the feed's "not yet" may only mean legislation.gov.uk hasn't updated its record; amending laws state when their amendments commence.
- **Measured:** 4,543 such text changes are stored (every family). The gap-filler gives 4,443 of them a date before 2016. Environment Act 1995 is the amending law for 1,688, and 1,150 of those take 1 April 1996 through SI 1996/186. Example: Water Industry Act 1991 s.184(1), substituted by EA 1995 Sch. 22 para. 119. Its raw feed record has `Applied="true"`, `<InForce Prospective="true">`, no date and no qualification, last modified 2026-04-08. So legislation.gov.uk applied the text, but its in-force entry is a placeholder never filled.
- **This is a different case from the 623 commencements.** Those were dated by the commencing provision's own start ("s.92(3) … on such day as … by order", in force at Royal Assent). That start is never the day the target comes in, however current the feed is. That fix stands.
- **Revised recommendation: (b).** Our dating wins where the amending law's own text dates the amending provision. This is RULES `primary-first-derived-fills`: the law and its commencement are primary, the feed derived. The gate keeps the disagreement as a group, `known:` (legislation.gov.uk's prospective placeholder), parked against no reader. No sampling needed: the dates are the amending laws' real commencement days. The gap-filler is unchanged; only the gate's group and its known limit are new.
- **Decided: (b)** (Jason 2026-11-21). The known limit goes into RULES at Close.


## B, held orders (round 3): Flood and Water Management Act 2010

- **Fixed (25cc40ae):**
  - "so far as not already commenced" completes a provision, as "so far as not already in force" does (SI 2010/2169 Sch.; SI 2011/694 art.3, s.17 and s.22(1));
  - the yardstick agrees where both sides are partly in force from the same day.
- **Held move for Settle:** SI 2011/694's two order-pattern examples (s.17, s.22(1): "in relation to" → "fully"), right by the text.
- **Found:** `AmendingLaw.Doc` drops `<Character Name="NonBreakingSpace"/>`, so SI 2010/2169's "1st October 2010" reads "1stOctober2010" and its Schedule is undated. Decision 9.

## Decision 9 for Jason: the shared document reader drops legislation.gov.uk's marked-up spaces

- **The question:** `AmendingLaw.Doc` (the Amending-law reader's module) is the document reader every commencement order is read through. It reads `<Character Name="NonBreakingSpace"/>` (and EmSpace, EnSpace, ThinSpace) as nothing. So "1st October 2010" becomes "1stOctober2010", and no date is found. The fix is one clause: a Character reads as a space. Is it fixed here, or parked against the Amending-law reader?
- **The aim:** `binds-on-date`.
- **Reach:** 607 of the 9,599 stored documents hold such a Character (2,986 NonBreakingSpace). In 212 places, across 49 laws, it splits a date. For 2010 c.29, a trial of the fix took the rows agreeing with the feed from 98 to 224 (before the round's other fixes).
- **Options:**
  - (a) **Fix it here, test first:** the Amending-law reader's previews (`lat.amending --read --preview --regression`) and the Extent reader's checks show its reach on those steps before the commit. It stales the amendment indexes (`ReaderVersion`), so its full read pass joins this round's Rebuild then fetch.
  - (b) **Park it against the Amending-law reader** (`bug-raise`): 2010 c.29's 239 rows and the other dates stay undated until that step reopens.
- **Recommendation: (a).** It is a one-clause fault at its source, and this step cannot date those orders without it. The previews show any change to the other readers before anything is written. The trial patch is held at `scratchpad/doc-nbsp.patch`.
- **Decided: (a)** (Jason 2026-11-21).
- **Done (test first):** `Doc.walk/2` and `Text`'s word collector each read a `<Character>` as a space (`doc_test` "a marked-up space reads as a space").
  - **2010 c.29:** 617 rows agree with the feed (98), none dated by the feed alone (519); 9 inserted rows left, which belong to the inserting-law class.
  - **Amending-law reader:** the regression preview, with the change and without it, differs in 2 of 386 laws, both right by the text. SSI 2011/207 reg.3 now reads "sections 1 and 2" (it was "sections1 and 2", s.2 alone). SSI 2009/319 now reads "Part 1 of schedule 3". The preview's other 41 laws change identically either way: their stored rules lag the current reader, waiting for the round's full read pass.
  - **Held moves for Settle:** SI 2010/2169 art.3(2), whose example text was cut as "1stSeptember2010" (it needs a re-cut); SSI 2012/191 art.2(1), "paragraph (2)", none → 5 rules (s.10, s.14(6)–(8), s.15(4), s.35(6), s.75, 22 June 2012, S).
  - **Extent reader:** the full catalogue, run cold (17 min, dry run), shows 23 new patterns and 3 examples reading differently. Its laws (19 and 3) read byte-identically with the change and without it, so none comes from this fix. Checked at Settle.
  - **Committed:** 5d1c188d.

## B, held orders (round 4): Landfill Disposals Tax (Wales) Act 2017 (a828d356)

- WSI 2018/35 art.3: "Any provision of the Act to the extent that it has not been commenced before 1 April 2018, comes into force on that date". The rest of the Act, on that date.
- Art.2(w): "Chapter 6 (special cases) of Part 5 (supplementary provision), except for sections 85 to 87". That Chapter, those sections excepted (read before as all of Part 5, partly).
- A heading "in Chapter 1 of Part 1 (green deal)—" names where, never a provision (SI 2012/873 art.2(a), read before as all of Part 1).
- **ANAW 2017/3:** 797 rows agree with the feed (360), 0 differ (1), none left to orders (520 dated by the feed alone).
- **The ten held-orders laws together:** 3,831 rows agree, 177 dated by the feed alone, 121 where the feed holds only a partial stage, 38 differ.
- **Held moves for Settle:** SI 2012/873 art.2 (its pt.1 rule goes), beside SI 2011/694 (two), SI 2010/2169 and SSI 2012/191. The three pending from before are SI 2023/1394, SI 2006/641 and SSI 2019/436.

## B, held orders (round 5): Water Act 2003 (ece087e6)

- **Fixed, test first, each from the order's words:**
  - an item's "in so far as it relates to the following repeals specified in Schedule 9—" sub-list lists repeals, never items (SI 2005/2714 art.2(m), art.4(g)). It read the Water Industry Act's ss.28, 30 and 194 as the Act's (s.30: 18 rows);
  - "the WIA", an abbreviation the order never gives the Act, is another law ("inserting into the WIA paragraph 11 of Schedule 1A");
  - "subsections (3) to (7) and subsection (1) in so far as it relates to those subsections": subsection (1) alone partly (SI 2006/984 art.2(e));
  - "subsection (1), in so far as it relates to subsection (2), and subsections (2) and (4)": the latter fully (SI 2004/641 art.3(h));
  - "The day appointed for the coming into force of— (a) …; (b) …; is 1 April 2004." (WSI 2004/910; 14 stored orders have the form). A bare closing date only: five access-land orders close "is 19th September 2004 or the end of a period of six months …";
  - "section 56 (…), but— (i) …": the section partly (SI 2004/641 art.3(l));
  - ", except the amendments made by subsections (4) and (5)" and "except in so far as subsection (2) gives effect to …" (SI 2004/641 art.3(e), SI 2005/2714 art.4(a));
  - "This Order applies in relation to England only." is the order's territory (SI 2010/975, SI 2008/1922, SI 2012/264). The order's extent ("This Order extends to England and Wales": SI 2024/35) never is.
- **Water Act 2003:** 638 rows agree with the feed (583), 0 differ but one (29), 1 dated by the feed alone (15).
- **The ten held-orders laws together:** 3,894 agree (3,831), 164 dated by the feed alone (177), 108 feed partial only (121), 1 differs (38). The leftovers gate's 3 are the same as before (SI 1978/954, SI 2010/2169 art.3(2) and (3)).
- **To name `known:`:** Water Act s.58(10). SI 2009/359 art.1(2) reads "applies in relation to England only except article 2(d) which extends to Scotland only", a one-law wording, 1 row.
- **Held moves for Settle, new:** SI 2011/2896 art.2(h) ("paragraph 70 of Schedule 3 and section 22 so far as relating to that paragraph": the paragraph fully, the section partly); SI 2012/264 (England, by its art.1(2)).
- **Left for Decision 10:** Water Act ss.67, 77, 78, 80, 81 and 86 (about 40 rows).

## Decision 10 for Jason: an Act that gives Wales its own commencing authority

- **The question:** Water Act 2003 s.105(6) makes the Secretary of State the commencing authority for ss.58, 69, 75, 77, 78, 80, 81 and 86 "in relation to England", and the Assembly "in relation to Wales". s.67 is the Assembly's alone. So:
  - SI 2004/2528 brings s.77 in for England only on 1 October 2004, though it names no place. The feed says so too: England 1 October, Wales 11 November (WSI 2004/2916).
  - WSI 2004/910 brings s.67 in everywhere, though it is a Welsh order. We read every Welsh order as Wales's.

  Do we read the Act's authority split?
- **The aim:** `binds-on-date`. Today s.77 reads fully in force on 1 October 2004, six weeks early for Wales.
- **Reach:** the Water Act, about 40 rows. At least five more Acts give Wales its own commencing authority: 2006 c.28 s.83(4), 2008 c.23 s.44(3), 2010 c.29 s.49(3), 2020 c.7 s.87 and 2022 c.30 s.170(4). 2008 c.29 has the Water Act's table form. Most of their orders name their place in their title, so the reach beyond the Water Act is unmeasured.
- **Options:**
  - (a) **Read it in this step, test first:** the Act's clause rules carry each authority's territory. An order made by that authority (a UK SI for the Secretary of State, a Welsh SI for the Assembly or Welsh Ministers) takes that territory where its own words name none. It replaces the Welsh-type default for the Act's provisions the Act gives the Assembly whole (s.67).
  - (b) **A known limit:** those rows date fully from the first order. Wales's later day is lost.
- **Recommendation: (a).** The Act's own clause is primary (RULES `primary-first-derived-fills`), and the feed agrees with it. The family holds at least six such Acts, so a known limit would keep recurring. Cost: one reader class, about half a session.
- **Decided: (a)** (Jason 2026-11-22).
- **Done, test first (cfa9d1af):**
  - `Commencement.Authority` reads the Act's authority table (Water Act 2003 s.105(6)) and list (Planning Act 2008 s.241(3)–(4)). An order naming no place takes its maker's place: a UK SI the Secretary of State's, a Welsh SI the Assembly's or Welsh Ministers'. A range holding such a provision leaves it out ("sections 81 to 83", s.81 England's). `Orders.act/1` carries the authorities.
  - Found on the way: "in so far as it applies in relation to England" was read as a purpose as well as a place. With a purpose, England's and Wales's days never complete each other in the evaluator. A place alone is now the territory. Two unit-test expectations were updated (SI 1988/818 s.30(1), SI 2010/2169 s.7): each still reads partly in force wherever its place doesn't cover the row's extent.
  - The gate's yardstick: the feed's stages for one place each are fully in force once together they cover the row's extent, as the evaluator reads ours.
- **Water Act 2003:** 678 rows agree with the feed (639). s.77: England 1 October 2004, fully 11 November 2004. s.67: everywhere 1 April 2004. 1 is dated by the feed alone (s.58(10), to name `known:`); 3 are feed partial only (s.100(2)(b)).
- **The ten held-orders laws:** 3,932 agree (3,894), 59 feed partial only (108), 11 differ (1).
  - Water Act 2014's 10 rows now differ, where the old yardstick hid them. Its authority table is in Schedule 12 (Schedules unparsed) and divides by "wholly or mainly English undertakers", not by place: to name `known:`.
- **Held moves for Settle, new:** SSI 2008/150 (Part 6 "in relation to Scotland": purpose → none).

