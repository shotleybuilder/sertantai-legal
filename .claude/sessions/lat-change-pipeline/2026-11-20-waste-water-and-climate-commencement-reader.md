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
  - pattern: "A list opening \"This regulation, …\" reads as the whole law: `Clause.general?` takes the case-insensitive \"Regulation\" for the instrument (SI 2018/1251 reg.1(3), held pending; SI 2025/418 reg.1(2), held with the same misreading as its expectation). Making the singular case-sensitive is not enough: the items' sub-provisions (reg.6(2), reg.13(1)) are finer than a no-LAT law's held rows, and weighted refs drop them"
    category: this-regulation-list-read-as-rest
    module: law_start/clause, law_start/provisions
    affected: 2 laws seen
    fix: "the singular Regulation case-sensitive (EU only), the last item's own qualifier after it (\"and regulation 6(1) so far as it relates to those provisions\"), and keep a named sub-provision finer than the rows held; then both held readings to Jason. Named a known limit for now (Jason 2026-11-22): RULES section 11, Waste, Water and Climate one-law commencement wordings; the held SI 2018/1251 example stays pending"
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

- Commencement reader: this-regulation-list-read-as-rest — SI 2018/1251 reg.1(3) and SI 2025/418 reg.1(2) read "This regulation, …" as the whole law; a known limit (Jason 2026-11-22), the fix (case and finer sub-provisions kept) parked here. Size: 2 laws.

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


## B, held orders (round 6): Water Act 2014 (114dec3a, b1998312)

- **The reader (114dec3a, test first):** "section 6 (…) as follows— (i) subsection (1) so far as …; (ii) subsection (2) …" (SI 2015/1938) and "subsection (1) of section 8 (…) as follows— (i) so far as it inserts section 40E into the 1991 Act" (SI 2016/1007) now head their lines. The lines below are that provision's, in part. An open "subsection (1) so far as it— (aa) substitutes section 110A" carries to its lines, and the sections a limit names belong to the amended law, never to the Act. `Order.SectionHeads`.
- **The gate (b1998312, test first):** the feed's record for a row is fully in force once the record itself or an ancestor's is. For example, s.6 is wholly in force by SI 2016/465, while s.6(1) has purposes only.
- **Water Act 2014:**

  | | Before | After |
  |---|---|---|
  | agree | 404 | 427 |
  | feed only | 40 | 19 |
  | feed partial only | 56 | 54 |
  | differ | 10 | 10 |

  s.1(2), s.4, s.6, s.41 and s.82 are cleared. The commencement-patterns catalogue for the law: 0 examples reading differently. Per-fix tests: only the 11 held examples fail.
- **Left:** 80 rows are Decision 11 (below). s.34(1), s.56 and s.53(1)(f) are one row each. For s.34(1) and s.56 the Act's own two-month date (s.94(2)) is one the feed doesn't record, so ours is right; to name `known:`.

## Decision 11 for Jason: Water Act 2014's commencing authorities, in its Schedule 12

- **The question:** Water Act 2014 s.94(6) puts its authority table in Schedule 12. Schedules are not parsed, so Decision 10's reader never sees it. The table says:
  - **ss.10–12, 16–20, 23 and 38:** "The Secretary of State, in relation to wholly or mainly English undertakers. The Welsh Ministers, in relation to wholly or mainly Welsh undertakers."
  - **s.7:** "The Scottish Ministers." **s.5, s.40(2)(a) and s.41:** "The Welsh Ministers."
  - **ss.24, 29, 39, 40(1) and 54:** split by function or licence, not by undertaker.

  The feed reads the undertaker split as England and Wales. For example, s.10(1) is England from 1 October 2017 (SI 2017/462) and Wales from 1 April 2019 (WSI 2017/1288). We read s.18–20 and s.10–11 as fully in force from the UK order, and s.7 (an SSI) as Scotland's only, so never fully in force. Do we read Schedule 12?
- **The aim:** `binds-on-date`. s.10 and s.11 read fully in force 18 months early for Welsh undertakers. s.7 never reads fully in force.
- **Reach:** Water Act 2014, 80 rows:
  - 62 for the undertaker split (44 for s.18–20, 11 for s.10–11, 7 for s.17, 23 and 38);
  - 18 for s.7.

  No other law found in the family puts its table in a Schedule. That's unmeasured beyond the ten held-orders laws.
- **Options:**
  - (a) **Read it in this step, test first:**
    - Read the Act's authority table from its stored Schedules text, offline from the CLML store with no fetch, through the same `Commencement.Authority` table reader.
    - Read "wholly or mainly English undertakers" as England and "Welsh" as Wales, as legislation.gov.uk does, so the two orders complete each other.
    - Add the Scottish Ministers, so that an SSI takes the Scottish Ministers' place.
    - A clause split by something other than undertakers or place (ss.24, 29, 39, 40(1), 54) gives no authority, and the order's own reading stands.
    - Cost: about a third of a session.
  - (b) **A known limit:** the 80 rows date fully from the first order (undertaker split) or never (s.7).
- **Recommendation: (a).** It is Decision 10's rule, met in a Schedule. The Act's own words are primary, and the feed agrees with the reading. Reading "mainly English undertakers" as England is an approximation (an undertaker's area can cross the border), but legislation.gov.uk makes the same one. RULES would name it.
- **Decided: (a)** (Jason 2026-11-22).

## B, held orders (round 7): Decision 11 and the Scottish orders (7bdb61fe, d7542ce9, 5362fc03, 4b8f0a2d)

- **Decision 11, done test first (7bdb61fe):**
  - `Authority.Tables` reads each table of a Schedule titled for commencement from the Act's stored text. A one-cell row is a further authority for the row above.
  - `Authority` reads "in relation to wholly or mainly English (Welsh) undertakers" as England (Wales). A clause limited by anything else that names no place gives no authority (ss.24, 29, 39, 40(1), 54). The Scottish Ministers are an authority, made by an SSI.
  - **Found on the way:**
    - The evaluator read a completing rule with its general rule as fully in force whatever place they held. It now completes only the general rule's place (s.10(1): England's by SI 2017/462).
    - A bracketed heading named a place ("section 41 (… premises in Wales)": WSI 2015/1786). `Territory.of` now drops headings.
    - The gate counted only "territory" stages. It now counts "complete + territory" too.
- **The gate (d7542ce9):** a row's own stages for each place combine before an ancestor's full date is taken (Water Act 2003 s.86(2)(f)).
- **Scottish orders (5362fc03, 4b8f0a2d):**
  - A range of lettered or roman paragraphs ("79(2)(a) to (d)") is written out as its members. `LatRef` orders ranges by number, so a lettered range covered nothing; `LatRef` is shared with the Amending-law reader, so it is left as it is.
  - A Schedule takes its date from its article's paragraph that brings in the provisions it lists (SSI 2013/163 art.3(1)), never from one commencing the article (SI 2005/968 art.4(3)).
  - A table's header-named Purpose column is the row's purpose (SSI 2013/163).
  - "<date> is the appointed day on which the following provisions … come into force" (SSI 2007/530).
- **Water Act 2014:** 490 agree (427), 0 differ (10).
- **The ten held-orders laws:**

  | | Before | After |
  |---|---|---|
  | agree | 3,932 | 4,115 |
  | feed only | 165 | 46 |
  | feed partial only | 59 | 5 |
  | differ | 11 | 1 |

  Their commencement-patterns catalogue: 0 examples reading differently. The leftovers gate fails on the same 3 statements as before.
- **Held moves for Settle, new (5, all improvements):**
  - SI 1991/1042 and SI 1991/96: lettered ranges written out as their members.
  - SSI 2000/10, SSI 2017/330 and SSI 2025/170: the Purpose column now leaves those rows partly in force ("Only for the purpose of …", "For the purpose of making regulations only").

  One unit expectation was updated (SI 2005/2714 art.2(k)(i): the roman range written out).
- **To name `known:` (feed wrong):**
  - Water Act 2014 s.10 and s.11, 18 rows: WSI 2017/1288 art.3(c)–(d) were omitted by SI 2019/706 on 26 March 2019, before their day (1 April 2019). The feed keeps the made order's Wales date.
  - s.16(1)–(2): the feed has s.16 complete by a UK order, though Schedule 12 gives the Secretary of State English undertakers only.
  - ASP 2009/6 s.79(2)(h): the feed adds 24 December 2010. SSI 2010/401 art.3 says "(e) to (g) and (i)", and art.4 brings in (h) on 1 June 2011.
  - Water Act 2014 s.34(1) and s.56: the Act's own two-month date, which the feed doesn't record.
- **Left in B:**
  - ASP 2003/3 s.24(1) and s.23 (29 + 7 rows);
  - 1999 c.24 and 2025 c.5 s.3 (2 rows);
  - s.53(1)(f) and Water Act 2003 s.100(2)(b) (one row each);
  - the inserted groups (class C, 92 rows);
  - the 3 leftovers;
  - SI 2018/1251.

## Decision 12 for Jason: a register of proven feed errors, row by row, with its proof

- **The question:** today, when the feed gate shows that the feed is wrong, the only record is a group's `known:` line in `feed_differences.json` and a row in RULES. A group is a shape, not a row. The proof sits in the session doc, and nothing notices when it goes stale: a row the reader later misreads would hide under the same `known:`, and a row legislation.gov.uk later corrects would stay named. Jason (2026-11-22): "we need a way to capture a known/proven feed error so that the gap is closed mindfully and with an audit trail, not just captured in docs." How do we record one?
- **The aim:** `binds-on-date`, through `law-text-wins` and `coverage-from-lgu`. The feed is the yardstick, and we may overrule it only where the law's text proves it wrong, and only visibly.
- **Rows now:** about 25 in Waste, Water and Climate:
  - Water Act 2014 s.10 and s.11 (18);
  - s.16(1)–(2);
  - s.34(1) and s.56 (the feed says nothing);
  - ASP 2009/6 s.79(2)(h);
  - Water Act 2003 s.58(10).
- **Options:**
  - (a) **A register of feed errors in code, one entry per row:**
    - **The file:** `test/fixtures/commencement_check/feed_errors.json`, held like the fixtures, so it changes only through the accept path: dry run, Jason, then write.
    - **What each entry holds:**
      - the row (law and provision);
      - the feed's record as it is stored (its dates, and the affecting law and provision);
      - what the feed gets wrong: a wrong date, a wrong place, or no record at all;
      - the proof: the law and provision that show it, with their own words quoted;
      - our date;
      - who decided it, when, and in which session and decision.
    - **What the gate does with them:**
      - These rows are counted apart as `feed error (proven)`, with the entry beside each row. They are never dropped silently and never counted as agreeing.
      - **It fails on a stale entry:** our reading no longer gives the entry's date, the feed's stored record has changed (legislation.gov.uk may have corrected it, so we review it again), or the row has gone.
      - So a proof is checked on every run, not only when it is written.
    - **Later steps:** Evidence and the Label fold could read the same file to show the conflict as proven. That is their work, parked to them, not this step's.
    - **Cost:** about a quarter of a session, test first.
  - (b) **As today:** a group's `known:` and a RULES row. It costs nothing, but there is no row-by-row record and no check that an entry still holds.
  - (c) **Correct the feed's stored record:** rejected. Readers carry what their source says, and the error would vanish from view.
- **Recommendation: (a).** It closes each gap row by row, proof first, and the gate keeps every entry honest. RULES' known limits would point to the file instead of listing the rows. legislation.gov.uk could be sent the list later if you want; not in this step.
- **Decided: (a)** (Jason 2026-11-22).

## B, held orders (round 8): one-sentence orders and places (bbb1b131, eb3a2b56, 6dde97b8, 2ccb2d36)

- **Fixed, test first:**
  - "<date> is the appointed day on which section 23 (…) of the Act comes into force" (SSI 2013/252): ASP 2003/3 s.23, 7 rows.
  - "… for the purpose of P is D1 and for all other purposes is D2", read as two statements (SSI 2007/50): ASP 2003/3 s.24, 22 rows.
  - "so far as relating to undertakers whose areas are wholly or mainly in England (Wales)" is a place alone, Decision 11's reading (SI 2025/726, WSI 2025/936): 2025 c.5 s.3 and s.5.
  - The sections an open "so far as it relates to—" list names are never brought in (SI 2015/1469 art.2(f)(i)(bb)), and a Schedule's paragraphs under such a list still are (SI 1975/1938): Water Act 2014 s.53(1)(f). The other rows the misread reached were right by accident, as SI 2015/773 had already brought them in.
  - "in so far as they extend to England and Wales" is a place alone (SI 2000/800).
- **The ten held-orders laws:** agree 4,138 (was 4,115), feed only 24 (was 46), feed partial only 4 (was 5), differ 1. Their patterns catalogue: 0 examples reading differently. The leftovers gate fails on the same 3 statements as before.
- **Held moves for Settle, new (2, both improvements):** SSI 2007/50 (two stages) and SI 2000/800 (England and Wales fully).
- **Feed errors for the register (Decision 12), new:**
  - **Water Act 2003 s.100(2)(b), (b)(iv), (b)(v):** SI 2007/1021 art.2(c) brings in s.100(2) "for all remaining purposes" on 1 April 2007. The feed has no completing record for them.
  - **1999 c.24 s.6(1):** the feed has neither SI 2000/800's start (England and Wales, 21 March 2000) nor SSI 2000/322's (Scotland, 29 September 2000).
- **Moved to class C:** 1974 c.40 s.46A–D are inserted provisions (Environment Act 1995). The gate judges them by their inserting law; my probe didn't mark them.
- **Left in B:** the inserted groups (class C); the 3 leftovers; SI 2018/1251.

## Decision 13 for Jason: the inserted provisions the feed dates differently (class C, 92 rows in the ten held-orders laws)

- **The question:** Decision 7 C judges an inserted provision by its inserting law. In the ten laws, 92 inserted rows still differ from the feed. All sit in four kinds, and none is a misread in our order reader. What do we do with each?
- **The aim:** `binds-on-date`. An inserted provision that no rule dates has no date from which it binds.
- **The four kinds:**
  1. **We date the insertion, and the feed gives it no date (31 rows, 3 laws):** mostly the Environment Act 1995's insertions into COPA 1974, from 1 April 1996. Nothing contradicts us; the yardstick has nothing to compare.
  2. **The inserting Act's own orders were never read (38 rows):** the Act's clause leaves the provision to "such day as … may appoint", and no order of the Act is held as rules. The Acts:
     - ASP 2013/7 (8 rows), ASP 2014/3 (7), ASP 2011/9 (3), ASP 2019/9 (2);
     - ANAW 2016/3 (7, 3 of them not reached);
     - the Environment Act 1995 (12, COPA s.46–46D);
     - 2018 c.12 (2), ASC 2024/3 (1);
     - one with no inserting law named.

     Their orders belong to their own families, and those families' Commencement reader steps haven't run.
  3. **WSI 2018/101 (7 rows, ANAW 2017/3):** it reads fine fresh ("on the day on which section 2 of the … Act comes into force", 1 April 2018, as the feed says), but its rules were never stored. The Rebuild's re-read stores them, with no code change.
  4. **SSI 2005/348 (2 rows, ASP 2003/3):** revoked, so its stored text is all dots and holds no clause to read. Its made text is stored.
- **Options:**
  - **Kind 1:**
    - (a) `known:` as a yardstick gap (recommended);
    - (b) leave it as `check:`.
  - **Kind 2:**
    - (a) add these Acts' orders to the Rebuild's orders list, one hop from our rows (`feedback_effects_first`): read the ones already stored, and fetch the rest in the decided fetch, counted at its dry run (recommended);
    - (b) a known limit until each Act's family reaches its Commencement reader.
  - **Kind 3:** the Rebuild's re-read. No choice is needed; it is listed so it isn't lost.
  - **Kind 4:**
    - (a) read a revoked amending law's commencement clause from its made text, test first, measuring its reach across the round first (recommended if it reaches more than these 2 rows; otherwise (b));
    - (b) a known limit.
- **Recommendation:** 1 (a), 2 (a), 4 (a) if the measure finds it wider, else (b).
- **Decided: as recommended** (Jason 2026-11-22: "Agree 12 and 13 Finish B").

## B, held orders (round 9): Decisions 12 and 13, the leftovers, SI 2018/1251 (7dd419d8, 0a04cfc0, f5037691)

- **Decision 12, done test first (7dd419d8):**
  - `Commencement.FeedErrors` (in `review/`, beside `FeedDifferences`) and the gate's register, `test/fixtures/commencement_check/feed_errors.json`, held empty.
  - A registered row is counted apart as `feed_error`, its entry and proof printed. An entry fails the gate when its row is gone, its feed record or our reading has changed, or it is incomplete (proof, decision). Tested end to end: a stale entry gave FAIL and put its row back to `differ`.
  - **Writing:** `--feed-errors-dry-run` fills the hand-written proposals (`data/reports/commencement-reader/feed-errors-proposed.json`: wrong, proof with the law's own words, decision) with each row's feed record, our reading and the feed's affecting laws (the row's and its ancestors'). `--feed-errors-write` writes them, on Jason's go.
  - **The dry run:** 24 proposals filled, 0 refused (`feed-errors-dry-run-2026-11-22.json`):
    - Water Act 2014 s.10 and s.11, 15 rows (date: WSI 2019/706 art.2 omits WSI 2017/1288 art.3(c)–(d));
    - s.16(1)–(2) (place: Sch.12, "The Secretary of State, in relation to wholly or mainly English undertakers");
    - s.34(1) and s.56 (no record: s.94(2)(i) and (s));
    - ASP 2009/6 s.79(2)(h) (date: SSI 2010/401 art.4(b));
    - Water Act 2003 s.100(2)(b), (b)(iv), (b)(v) (no record: SI 2007/1021 art.2(c));
    - 1999 c.24 s.6(1) (no record: SI 2000/800 art.2).

    These are held moves for Jason at Settle. Water Act 2003 s.58(10) is our own known limit, not a feed error, so it stays out.
- **Decision 13:**
  - **Kind 1 (0a04cfc0):** the shapes "inserted | ours_only | ours dated via feed / law_text / note" named `known:` as a yardstick gap.
  - **Kind 2:** the inserting Acts' orders go to the Rebuild's orders list (ASP 2013/7, 2014/3, 2011/9, 2019/9, ANAW 2016/3, the Environment Act 1995 for COPA s.46–46D, 2018 c.12, ASC 2024/3), counted at the fetch's dry run.
  - **Kind 3:** WSI 2018/101, the Rebuild's re-read.
  - **Kind 4, measured:** across the family, 406 amending laws read no clause, leaving 332 undated gaps (the largest are 1996 c.61 with 87 and SI 2019/123 with 19). No made body text is stored for any of them: the store's `made/` holds only the introduction. So reading the made text means a fetch. **To ask Jason at Rebuild then fetch:** fetch the made bodies of the amending laws that read nothing (a list of about 400, by gap count), or name a known limit.
- **The 3 leftovers (f5037691):**
  - **SI 1978/954 art.3:** "The following subsections of section 13 of the … Act 1974, namely— (a) subsections (5) and (6) …" now reads as section 13's (COPA s.13(3)–(8) dated 1 August 1978).
  - **SI 2010/2169 art.3(2) and (3):** purpose references, rightly not brought in, each statement named `known:` on its own (not its group).
- **SI 2018/1251:** tried, and reverted.
  - Making the singular "Regulation" case-sensitive gets past the whole-law reading. But the items' sub-provisions (reg.6(2), …) are finer than the rows held for a law without LAT, and are dropped.
  - SI 2025/418 has the same misreading, held as its expected reading.
  - Two laws, and a change to how refs are kept: left pending, with the bug entry widened.
- **The ten held-orders laws:** agree 4,138, own only 1,379, feed only 24, differ 1. Their patterns catalogue: 0 examples reading differently.
- **B is done.** Settle is next: the full suite, Dialyzer, the round and switched checks, both catalogues, and the held moves to Jason (18 catalogue examples plus the 24 feed errors).

## Settle 1 (2026-11-22): back to Fix

- **Runs** (`backend/data/reports/commencement-reader/wwc-settle-*.txt`, about 21 min):
  - suite: 12,447/12,465, the 18 failures all held examples;
  - Dialyzer: passes;
  - the four switched families: PASS;
  - the round: FAIL. Our faults 0; 5 leftovers not named; 31 of 34 feed-difference groups with no status;
  - catalogues: own clauses 3 new patterns, 14 examples reading differently; orders 1 new pattern, 14 examples reading differently.
- **Correction:** "B is done" (round 9) was wrong. It held for the ten held-orders laws only. Decision 7's B leftovers (1968 c.47 s.60(2), SI 2020/1095 reg.1(2), SI 2000/2911 reg.1, 1987 c.26 s.340(2)) and the statuses for A, C and D across the round were not done.
- **A regression found and fixed (783eb09e):** the SI 2000/800 fix (2ccb2d36) made "so far as they extend to Northern Ireland" a place, but the place reader had no "extend to" form, so SI 1989/1557 art.3(1) read the Water Act 1989 s.4, s.13 and Sch.2 as in force everywhere. Now Northern Ireland's. "Except to the extent that they extend to Scotland" names the place left out (SI 2005/1521). SI 1996/3056 art.2 ("the repeals extend to England and Wales") now reads England and Wales: a new held move.
- **The rest of B, by decision:**
  - A, `fix: fetch`: NISI 2006/3336, ASP 2009/12, NISI 1997/2778, ASP 2011/9, ASP 2005/3 and the other laws left to unsearched orders (about 6,560 rows). Statuses need a per-law key, since several shapes mix A's laws with others (the gate change, test first).
  - C, the feed alone dates an insertion (about 2,320 rows: appointed, rules not held, no amending law, not reached, no text rules, no pointer, unread): `known:`, the feed's date standing. Decision 13 kinds 2 and 4 are their Rebuild items.
  - D and the feed-error register: SSI 2020/154 (the text defers to 2027); the 24 proposals.
- **To examine (about 1,900 rows, 20 laws):** SI 2017/462 and 2015/773 (no clause); WSI 2017/1041 and 2011/1014 (a staged start only); SI 2015/962 (partly only); SI and WSI 2016/359 (end 2018 against 2020); SI 2012/2079; SI 2020/1095; NISR 2002/331, 2008/231, 2011/127; SI 2019/544, 2021/1095, 2020/1265, 2024/1332; WSI 2005/1806; ASP 2014/2; the inserted rows that differ (278, 1991 c.56 211).

## Fix round 10 (2026-11-22): the round's differences, law by law

Each fix test first, the per-fix tests and a `--laws --fresh` check after each:
- **783eb09e** "so far as they extend to Northern Ireland" (SI 1989/1557); "Except to the extent that they extend to Scotland" is no place (SI 2005/1521).
- **eb5c0425** "The title of these Regulations is …; they apply in relation to Wales and come into force on …" (WSI 2017/1041, 2011/1014): 271 rows now agree.
- **388e6335** a general rule subject to several qualified ones is complete when the last starts (WSI 2016/359): 220 rows now agree. Its reg.1 (the clause itself, in force from the first day) still differs from the feed's staging: 20 rows, a yardstick difference.
- **b7692b84** "regulation 5 or 11" names both (SI 2020/1095); the five leftovers named `known:` each alone. The gate's leftovers are now 0 for the round.
- **f1682351** "paragraphs (4) and (5) of regulation 29" (NISR 2002/331); a provision another list names only partly keeps its partial Royal Assent day (1994 c.21 s.68(6)(f)).
- **ce6aceef** "on the day before that on which exit day falls" (SI 2019/544): agrees.
- **b8da12a4** a purpose in a list item's middle limits only what follows it (WSI 2005/1806): 574 agree, none differ.
- **228369fa** "regulation 12(2)(a) and (b)" is 12(2)(b) (SI 2021/1095): agrees.
- **Held moves, new (13, all improvements):** SI 1996/3056 (E+W); WSI 2017/1041, 2011/1014, 2010/1821 (clause date, not staged); 2011 c.16 and 1994 c.21 s.68(2) (subsections, not whole sections); SI 2019/544 (30 December 2020); SI 2023/588, SSI 2005/658, SI 2019/1440, SI 2026/318, 1992 c.15, ASC 2021/1, SSI 2025/165 (a bracket's sibling found, a false ref gone).
- **Feed errors found (the text is plain, the feed's record contradicts it):**
  - SI 2012/2079 Part 8, 240 rows: reg.1(4)(b) "for all remaining purposes, on 28th January 2013"; the feed has it fully in on 1 October 2012;
  - SI 2012/2079 Part 9, 22 rows: reg.1(5) "comes into force on 1st October 2012"; the feed says 1 October 2021 (a typo);
  - SI 2020/1095, 122 rows: reg.1(2)(b) "for all other purposes, on 1st May 2021"; the feed says 8 October 2020;
  - SSI 2020/154, about 280 rows: the current text's 1 October 2027; the feed's 2025 is stale (Decision 7 D);
  - NISR 2002/331 reg.29(4)–(5) and reg.32, 10 rows; NISR 2008/231 reg.8 and reg.11(1)(a), 9 rows: the feed's day contradicts reg.1's list.
- **Named known limits (one law each, rabbit-hole triage):** SI 2000/2911 (a Scheme's paragraphs); SI 2020/1265 art.25 ("…, whichever is later" after the items, 2 rows); NISR 2011/127 reg.28–31 (the commencing paragraph omitted in the current text).
- **Rebuild then fetch:** SSI 2014/277's Schedule is not stored, so ASP 2014/2's 100 rows read nothing from it.
- **Still to examine:** the inserted rows that differ (278, 14 laws; 1991 c.56's 211, mostly the Water Act 2003 and 2014 insertions, which we date 1 April 2004 against the feed's 1 December 2005).

## Decision 14 for Jason: two rules and the feed errors' audit trail

- **The aim:** `binds-on-date`.
- **(a) An instrument with no commencement clause.** SI 2017/462 and SI 2015/773 (Water Act 2014 commencement orders, 209 rows) state no day of their own. An Act with none is in force on Royal Assent (RULES, Interpretation Act 1978 s.4). The feed dates them on their made date.
  - Options: (i) a rule: an instrument stating no day is in force at the start of its made date (recommended: the common-law rule, and the feed's); (ii) a known limit.
- **(b) Purposes that together cover everything.** SI 2015/962 Part 3 (258 rows): "(a) on 1st April 2017 in relation to non-domestic PR property, (b) on 1st October 2017 in relation to domestic PR property". We read it as partly in force from April 2017, never fully. The feed has it fully in force from October.
  - Options: (i) keep it partly in force (the reader can't know that two purposes exhaust the provision); (ii) a rule: items that each name a purpose and leave no "all other purposes" complete the provision at the last; (iii) a named known limit for this law. **Recommended: (iii).** (ii) would complete provisions whose purposes don't exhaust them.
- **(c) The feed errors' entries.** Decision 12's register holds one entry per row. These are about 680 rows in 6 laws, each group with one proof.
  - Options: (i) one register entry per row, generated by the dry run from a proposal per group (law, rows, proof in the law's own words); (ii) a per-law group status `known: feed error` in the feed-differences fixture, with the proof. **Recommended: (i).** It keeps Decision 12's audit trail and its stale check: each row's entry fails the gate if the feed's record changes.
- **Also, no decision needed:** the feed-differences fixture needs a status per law within a shape (`"<shape> @ <law>"`, as the leftovers already have). Several shapes mix laws left to unsearched orders (Decision 7 A, `fix: fetch`) with others. A gate change, test first.

## The held moves for Jason, and a pass condition added (2026-11-22)

- **Pass condition added (Jason 2026-11-22):** the Commencement reader's tests and `mix test` pass, with no held example failing, before any push. Held moves are dry-run, decided and written first. Recorded in WORKFLOW (the Commencement reader's pass rule) and in the `commencement-reader-check` skill. The push asked for today was refused by the pre-push suite (32 held examples) and is held until then.
- **The dry run** (`held-write.exs`, sheet `backend/data/reports/commencement-reader/wwc-held-moves-2026-11-22.md`): 32 moved, 16 own and 16 order examples. Each was read against its words:
  - **31 right, recommend accepting.** The 18 from earlier rounds and the 13 of fix round 10. SI 1991/96 and 1991/1042 only list a range's members one by one (the same provisions).
  - **1 not to write: SI 2010/2169 art.3(2).** Its example text was cut short ("… section 4(2)(f) of the Act— a"), so it reads nothing alone. In its law it reads ss.1, 2, 3 and 6 partly. It needs a re-cut at the next `--accept`, not "none" written.
- **Decided (Jason, 2026-11-22): accept the 31; re-cut SI 2010/2169.** The pass condition's tests are the targeted ones (commencement, law-start, change-vocabulary, architecture, about a minute); the full suite is the pre-push hook's (Jason). Done:
  - an order-catalogue `--accept` was tried for the re-cut and reverted: it re-chose the examples (32 left, 23 joined with unreviewed readings, some visibly wrong: SSI 2012/218, SSI 2000/10, SI 2010/2169 Sch.). Lesson: `--accept` is not a re-cut;
  - SI 2010/2169 art.3(2) re-cut alone (`scratchpad/recut.exs`): its unit text "1stSeptember2010" predated Decision 9's marked-up spaces; fresh from the store it reads ss.1, 2, 3 and 6 partly, its held reading;
  - `held-write.exs write`: 16 own, 15 order; a dry run after shows 0 moved; the targeted tests 6,736 pass, none failing.

- **Decision 14 (a) decided (Jason, 2026-11-22): (i), the rule.** "The annotation points us to using the Made date … our rule stands. And we have confirmatory check with the Feed." Done test first: `LawStart`'s `:instrument_made`, only where the instrument states no day for any of its own provisions (a sentence bringing in another law's provisions doesn't count; Church Measures and EU texts never). SI 2015/773 and SI 2017/462: 210 rows agree. Reach in the own-clause catalogue: 14 of 870 laws, all commencement orders; no held example moves. RULES `instrument-stating-no-day-on-its-made-date`. (b) and (c) still open.
- **Decision 14 (b) decided (Jason, 2026-11-22): (ii).** "A named known limit for this law is far too specific for the parser … These conditionals are the territory of fractalaw … partly in force from 1 April to 1 October and fully thereafter." Done test first: a provision's items each for a purpose, none "for all other purposes", complete it at the last (`Provisions.last_purpose_completes/1`). SI 2015/962: 498 rows agree, none differ; no held example moves. RULES `purposes-staged-last-completes`. (c) still open.
- **Decision 14 (c) decided (Jason, 2026-11-22): (i), one register entry per row.** Proposals generated per row from one proof per group (`data/reports/commencement-reader/feed-errors-proposed.json`, 634 added beside Decision 12's 24; the earlier file kept in the scratchpad). The rows come from a fresh read with today's code, each group checked to hold one kind of difference only. Dry run (`--feed-errors-dry-run` over the ten held-orders laws and the five): **658 filled, 0 refused** (`feed-errors-dry-run-2026-11-22.json`): SI 2012/2079 262 (Part 8 240, Part 9 22), SSI 2020/154 231, SI 2020/1095 122, Water Act 2014 19, NISR 2002/331 10, NISR 2008/231 9, Water Act 2003 3, ASP 2009/6 1, 1999 c.24 1. **To write with `--feed-errors-write` on Jason's go** (a held move).
- **Written (Jason's go, 2026-11-22):** `--feed-errors-write`, 658 entries in `test/fixtures/commencement_check/feed_errors.json`. A fresh check of the fifteen laws after: 658 `feed_error`, 0 stale, no row of these groups still differing; PASS. Jason: finding typos in the feed (SI 2012/2079 Part 9, 2021 for 2012) is evidence of the reader's quality.

## The inserted rows that differ (2026-11-22)

The round's 278 (14 laws; 1991 c.56 211), measured again today with the inserting laws' rules (`scratchpad/insdiff*.exs`, by change, not by row: one row carries an insertion and its later substitutions). Today's code gave 352 before the fixes below; SI 2019/107's 62 had come from this morning's made-date rule.
- **Fixed, the Water Act 2003 (d7477b73):** SI 2004/641 Sch.2 is a table headed "Schedule | Provision". We had read its first cell ("Schedule 8") as the whole Schedule in force on 1 April 2004, so every Sch.7 and Sch.8 paragraph no rule named came in then. Now the second cell's paragraphs only, each sentence its own item ("In paragraph 27, sub-paragraphs (5)(a)(ii), … (7)(a)" as paragraph 27's). The only other order with the form is SI 2006/795. 1991 c.56 and c.57: 234 rows differing become 87, with the Water Act 2003 read fresh. **One held order example moves, for Jason:** SI 2004/641 Sch.2's Schedule 7 row, "sch.7 fully" becoming its 16 paragraph rules. One wording, "(2)(a)(i)(b) and (iii)", is legislation.gov.uk's own run-together text (as the feed has it), left alone.
- **Fixed, the made-date rule (5156347d):** an instrument is dated by its made date only when some provision holds words. SI 2019/107 is revoked and shown as dots; it had been dated its made date across 62 insertions into SI 2012/3038 (its feed: IP completion day). The own-clause catalogue's reach is unchanged (14 of 870).
- **The gate compares a partial feed record with our full date:** 79 rows have a feed record "for specified purposes" (partial), and our full date set against it. Compared first stage with first stage, 43 agree. Decision 15.
- **Left, 79 rows in 28 groups (9 at most):** one pattern across laws, an Act's Royal Assent dating an insertion the feed dates by an order (Enterprise Act 2002, Deregulation Act 2015, NIA 2016/13, 2019 c.1, 2023 c.55: about 16 rows), to look at next; the rest are single-law wordings (rabbit-hole triage: named known limits or feed errors).

## Decision 15: a partial feed record against our full date

- **The question:** the gate judges an inserted provision by setting our full date beside the feed's date. When the feed's record is partial ("coming into force for specified purposes"), its date is a first stage, not a full one. Should the gate compare our first stage with it instead?
- **The aim:** `binds-on-date` (a provision partly in force binds for those purposes from the first stage).
- **Options:** (i) compare like with like: a partial feed record against our first stage (our partial start, else our full date); (ii) leave the comparison as it is and status the groups `known:`.
- **Recommendation: (i).** It is a fault in the yardstick, not in either reading: of 79 such rows, 43 agree on the first stage. The other 36 stay as differences to examine.

## Decision 16 (Jason 2026-11-22): the inserted rows left are known limits

- **Jason:** "The 1 law only wordings can be a known limit. We cannot claim feed error w/o evidence. Blast radius excludes post 2002 because we have the feed. Therefore utility for pre 2002 laws is very, very limited."
- **The rule** (RULES `inserted-differences-known-where-the-feed-dates`): the feed holds every effect from 2002, so where it dates an insertion our reading is a check, not a date the label lacks. The 79 rows left after the two fixes are `known:`, the Royal Assent pattern (about 16 rows, five Acts) with them; none is a feed error without proof in the law's words.
- **Its consequence for Decision 15:** whichever comparison the gate makes, the group is `known:`, so (i)'s yardstick change buys nothing here. Proposed: drop (i), take (ii).
- **The status, dry run** (`test/fixtures/commencement_check/feed_differences.json`, on Jason's go): `"inserted | differ | ours dated via feed": "known: the feed dates the insertion (it holds every effect from 2002); our reading of the inserting law is a check only, and a difference no proof in the law's words makes a feed error (Decision 16, Jason 2026-11-22)"`.
- **Jason 2026-11-22:** the status agreed and written; Decision 15 (ii) agreed, (i) dropped; the held move SI 2004/641/b2b041555c (Sch.2's Schedule 7 row: 16 paragraph rules, not "sch.7 fully") accepted and written with `held-write.exs` (the only move). Targeted tests 6740/6740.

## The never-searched orders, fetched (2026-11-22, Jason's go)

- **Restore point:** `nas-backup.sh --tables commencement_rules --tag wwc-orders-fetch-2026-11-22` (61,990 rows).
- **Searched and read:** 12 laws had never had their order list searched (Decision 7 A's "17" was its count then). 11 have orders: 43 orders, 364 rules written, all new (stored 0). SI 2006/641 has none.
- **The check on the 12 (`--fresh`):** of 10,937 rows, the feed-only rows left to orders fell from about 6,550 to 3,230 (NISI 2006/3336 and NISI 1997/2778).
- **Two new findings, both ours:**
  - **A purpose in a table cell read as full:** NISR 1999/325 Sch.1 "Article 3(3)(a) and 3(6) (both paragraphs for the purposes of Article 40(5))" dates NISI 1997/2778 art.3(3)(a) fully from 19 August 1999 (the feed: 27 November 2003). 165 rows differ, in NISI 1997/2778 (105) and ASP 2005/3 (60).
  - **"To the extent that it is not already in operation"** (NISR 2007/282 art.2(1)) is an unreviewed leftover reaching 4,222 rows of NISI 2006/3336: a completing form ("so far as not already in force") in a wording not yet read.
- **Per-law status keys:** `"<shape> @ <law>"` (24b934bc).
- **The two findings fixed (55a27e92, test first):**
  - NISR 1999/325's "(both paragraphs for the purposes of …)" now qualifies both items (the bracket had been dropped as a heading).
  - NISR 2007/282 art.2(1), which had been dropped, now reads: Article 280 from 4 May 2007, for making secondary legislation. Several forms were involved: "the date of this Order" as the made date; "so much of" as a purpose; regulations "to be made"; "not already in operation" as completing; and another Order's Articles now dropped only up to their own "of the" (the pattern had swallowed Article 280 of the 2006 Order with them).
  - The check on the 12 laws: PASS (our faults 0, leftovers 0). NISI 1997/2778's rows that differ: 105 → 70.
  - **Eight held order examples move, all to the stated reading (for Jason):**
    - for making secondary legislation, not "in relation to": SI 1993/2050, NISR 2012/13 (two units), SI 2010/2191;
    - completing, so fully: SI 1976/530 s.110 and SI 1976/1379 Sch.16 Pt III ("so far as it is not already in operation");
    - partly ("so much of Schedule 14 as relates to— …"): SI 1992/1755 and SI 1992/2454.
  - **Accepted (Jason 2026-11-22)** and written with `held-write.exs` (exactly the eight); targeted tests 6744/6744.

## SI 2018/1251, and the statuses drafted (2026-11-22)

- **SI 2018/1251 (Jason 2026-11-22: a known limit and a bug):** RULES section 11 gains a row for this step's one-law commencement wordings. It covers SI 2018/1251 and SI 2025/418 ("This regulation, …" read as the whole law), WSI 2016/359 reg.1, SI 2020/1265 art.25, NISR 2011/127 reg.28–31, SI 2000/2911 and SI 2006/641 reg.15. The bug `this-regulation-list-read-as-rest` stays open in this step, and is on the parking list.
- **Statuses, dry run** (not written to `feed_differences.json`). They come from the 12 laws' check (`scratchpad/fd-12laws.txt`) and a check of the six named-limit laws (6 s).
  - **Shape-wide, known** (Settle 1 and Decision 16: the feed alone dates an insertion, and its date stands):
    - `inserted | feed_only | ours undated: appointed` (117 rows), `…: rules_not_held` (209), `…: no_text_rules` (30), `…: not_reached` (13), `…: no_amending_law` (21) and `…: no_pointer` (1). Each: "known: the feed alone dates the insertion (it holds every effect from 2002); the inserting law's commencement is unread or unheld here, so the feed's date stands (Settle 1, Decision 16)".
    - `feed_partial_only | own dated by order_schedule | first agrees` (18): "known: the feed holds only the first stage, and it agrees with ours".
  - **Per law, known** (the RULES row above): `differ | own dated by clause_date | own earlier @ UK_wsi_2016_359` and `@ UK_nisr_2011_127`; `differ | own dated by clause_made_relative | own earlier @ UK_uksi_2020_1265`; `feed_only | own by_order by provision_by_order | feed full @ UK_uksi_2006_641`.
  - **Per law, `fix: fetch`** (Rebuild then fetch):
    - `feed_only | own by_order by by_order | feed full @ UK_nisi_2006_3336` (3,218) and `… feed partial @ UK_nisi_2006_3336` (8). NISR 2007/194's Schedule 1 is not stored; its body holds no Schedules and the store has no `schedules/` part.
    - `feed_only | own by_order by provision_by_order | feed full @ UK_nisi_2007_611` (17). NISI 2007/611's later order is not held: NISR 2007/294 is the only one.

## Decision 17 for Jason: four misreads of ours in the fetched laws' orders

- **The question:** the 12 laws' check shows four misreads in the order reader. They come to about 280 rows, all in this step's own code. Do we fix them now, test first, before the statuses are written?
- **The aim:** `binds-on-date`.
- **The four:**
  1. **A table's "Purpose" column is not read** (SSI 2005/351 Sch.1, ASP 2005/3: 60 rows). "Section 1(1) … Only for the purpose of bringing into force the new section 1(1)" is read as fully in force on 20 June 2005; the feed has it partly in force, then fully from 1 July.
  2. **A completing phrase in a Purpose column is read as a purpose** (SSI 2016/42, ASP 2011/9: 89 rows). "In so far as not already in force" is read as partly, so the provision never completes.
  3. **A repeals list under another law's heading is read as the commenced law's** (NISR 2003/489 Sch.: 70 rows of NISI 1997/2778). "In the Pollution Control … Order 1978 – Articles 3, 5 to 13, 16 and 18" dates the 1997 Order's own art.3–18 on 27 November 2003.
  4. **A completing qualifier in the middle of a list ends the list** (NISR 2003/489: 13 rows). In "Article 4(1)(a) and (b) and (5) and to the extent that they are not already in force (2) to (4) and (6) to (9)", art.4(2)–(4) and (6)–(9) are dropped. art.3(3)(b)–(6) is dropped the same way.
- **Also found:**
  - **Fetch:** 15 commencement orders refer to their own Schedule, but it is not stored (NISR 2007/194, SSI 2012/333, SI 1991/2092, 1997/2164, 1997/304, 2004/288, 2004/759, 2006/3397, WSI 2006/345 and six more). The fix is to fetch their `schedules/` part at Rebuild then fetch.
  - **A fifth misread while a Schedule is missing:** NISR 2007/194 art.2(2) reads "Article 1(3) of the 2006 Order" and the order's own "Part II of Schedule 1" as the Act's provisions. To be checked once the Schedule is fetched.
  - **To examine:** the Waste and Emissions Trading Act 2003's orders, one per territory (26 rows), and MWA 2010/8 (20 rows).
- **Options:**
  - (i) fix 1 to 4 now, by class and test first, with the per-fix checks; then write the statuses and examine the last two laws;
  - (ii) name them known limits.
- **Recommendation: (i).** They are our own forms. Forms 1 and 3 can reach other orders, while (ii) would leave wrong dates on rows before 2002.

- **Decision 17 decided (Jason 2026-11-22): (i), fix the four.** Done test first (56d1f36d, `order_table_purpose_forms_test`):
  1. A Purpose column is counted within its own header row (SSI 2005/351's "Column 1 | Column 2 | Column 3" row had pushed it past the cells).
  2. A completing purpose brings its row in fully (SSI 2016/42).
  3. A repeals row's subject-less entries are dropped (`RepealLists.drop_table_entries/1`; NISR 2003/489).
  4. A completing qualifier inside a row is dropped, and the items after it stay (NISR 2003/489).
- **Results:**
  - targeted tests 6745/6748, the 3 failing tests all held examples;
  - Credo adds no issues;
  - the check on the 12 laws: "own earlier" 130 → 6 rows; ASP 2011/9's 89 rows are gone;
  - NISI 1997/2778's 70 rows read from the 1978 Order's repeals are now left to orders: the feed dates them by an order of 2008-04-03, which is not held. They move to the `fix: fetch` status for that law.
- **Held moves, 3, for Jason** (`held-write.exs` dry run), all to the order's words:
  - SSI 2001/81 ×2 (fa98f53c24, d4a1b0923b): its Purpose column is read, "Only for the purpose of … insofar as it relates to continuing attorneys", so fully becomes partly;
  - NISR 2012/13 (a308dfc0df): "Section 4 | In so far as not already in operation" is completing, so "in relation to" becomes fully, as the other NISR 2012/13 units were accepted earlier today.
- **Written (Jason's go, 2026-11-22):**
  - **The held moves:** the three, with `held-write.exs`; a dry run after shows 0 moved.
  - **The statuses:** 21 in `feed_differences.json`. They are:
    - the drafted ones;
    - NISI 1997/2778's fetch (the order of 2008-04-03);
    - the Waste and Emissions Trading Act 2003's two one-law wordings, added to the RULES row: WSI 2004/1488's "Subject to paragraph (2)", and the feed's first stage taken from England's order.
- **Two more fixes found while statusing (6f7b0f43, test first, no held example moves):**
  - "Section 4, apart from subsection (6)" now excepts the subsection (ASP 2005/3, 4 rows).
  - A devolved order on its own legislature's Act no longer takes a territory from its title or its application ("This Order applies in relation to Wales": WSI 2011/476 on MWA 2010/8, 20 rows), as RULES `devolved-order-carries-no-territory` holds. Stored rules affected: 104 (ANAW 2017/2 92, four asps 11, MWA 2010/8 1). They change at the re-read.
- **The check on the 12 laws:** PASS. Our faults 0, leftovers not named 0, every feed-difference group statused. Targeted tests 6750/6750.
- **Seen outside these laws, for Settle's round check:** ASP 2005/13 has 13 rows `not_reached` as our fault, and ASP 2014/2 has 100 rows "own later" (SSI 2014/277's Schedule is not stored, already on the fetch list). Both were there before today's fixes.

## Settle 2 (2026-11-22)

- **Runs** (`backend/data/reports/commencement-reader/wwc-settle-*.txt`):
  - the round: PASS (our faults 0, leftovers not named 0, stale feed errors 0), with 5 feed-difference groups still to status;
  - the four switched families: PASS;
  - Dialyzer: passes;
  - the suite: 12,491 pass, none failing (`wwc-settle-suite2.txt`). The first run crashed: the BEAM segfaulted after 60 s, before any failure was reported, and the second run was clean;
  - catalogues: own clauses 4 new patterns and orders 3, unclassified 0 in both.
- **Examples reading differently in the catalogue run: 14.**
  - 13 sit under `pending:` patterns. The tests and `held-write.exs` skip these by design, and they now read where they didn't (e.g. SSI 2013/163's "The purpose of making subordinate legislation" as for making secondary legislation, by this round's Purpose-column fix).
  - 1 is accepted, MWA 2010/8/b9ba052913, now read by the Measure's approval day. It moves to a new pattern.

## Decision 18 for Jason: Settle 2's new patterns and the round's last statuses

- **The aim:** `binds-on-date`.
- **(a) The 7 new catalogue patterns.** Each was read against its words.
  - **Accept 6:**
    - WSI 2010/1821 ("…; it applies in relation to Wales and comes into force on 15 July 2010": the clause date);
    - SSI 2019/436 and SI 2023/1394 ("on the later of—");
    - MWA 2010/8 ("The remaining provisions … two months beginning on the day on which this Measure is approved");
    - SSI 2005/52 and SI 2004/3181 (each commencing ss.4, 5 and 10(1) of the Waste and Emissions Trading Act 2003 for its own territory, on the day after it was made);
    - NISR 2007/294 (NISI 2007/611 art.11, NI, fully).
  - **`pending:` 1:** SI 2010/2169 Sch. "Paragraph 54, so far as the amendments made by that paragraph provide power … to make regulations under section 21F of the Local Government Act 2000" reads nothing. It is the existing `pending:` table class "a table row not read"; one law, 3 statements.
  - **How to write them:** copy the 7 patterns, their examples and their readings into the fixtures by a script, as a dry run first. `--accept` re-chooses the examples of existing patterns, which this morning's re-cut showed is unsafe.
- **(b) The round's 5 groups with no status:**
  1. `inserted | feed_only | ours undated: unread` (72 rows, 7 laws, EU law): `known:`, the same status as the other insertions only the feed dates.
  2. `differ | own dated by order_date | own later @ UK_asp_2014_2` (100 rows): `fix: fetch`. SSI 2014/277's Schedule is not stored.
  3. `differ | own dated by clause_date | own earlier @ UK_uksi_2016_359` (10 rows): `known:`. This is the English twin of WSI 2016/359 reg.1 (the same one-law wording).
  4. `feed_only | own by_order_partly by by_order | feed full @ UK_ukpga_2003_37` (1 row, s.58(10)): `known:`, the Water Act's own wording, named earlier in the step.
  5. `differ | own staged by clause_made_relative | own later @ UK_uksi_2024_1332` (32 rows): **a feed error with proof.** reg.1(3)(b) brings reg.2(1), 3, 7(1)–(4) and 57(1) in on the day after the making "for the purposes of interpretation of the provisions listed in sub-paragraphs (c), (d) and (e)". The rest comes in on the 21st day, 1 January 2025. The feed has them fully in force from 12 December 2024. Proposed: register entries, one per row, from this one proof (Decision 14 (c)), as a dry run first.
- **Recommendation:** (a) and (b) as above. Each write is a dry run first, then written on Jason's go.

**Decision 18, decided (Jason 2026-11-22: "Do (a) and (b) as recommended", then "Clear to write").** Written after dry runs:
- (a) 7 patterns copied into the fixtures by script, not `--accept`. 6 are accepted and SI 2010/2169's is `pending:`. MWA 2010/8's held input gained its approval date, 2010-12-15; its other two examples read the same. Two old patterns that only these examples held were dropped. No other example moved.
- (b) `feed_differences.json`: 4 statuses (21 → 25 keys). RULES section 11's one-law row names SI 2016/359 and SI 2009/359 art.1(2) (Water Act 2003 s.58(10)).
- (b) The feed-error register: 32 entries for SI 2024/1332, all from the one proof, reg.1(3)(b). It now holds 690 entries. reg.57(1) is left out because the feed stages it as we do. reg.2(1) is left out because its group is its insertion's.
- Check PASS; targeted tests 6,753 green.
