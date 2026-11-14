---
session: 'Fire and OH&S: Commencement reader'
status: closed
opened: '2026-11-14'
closed: '2026-11-14'
outcome: success
family: Fire and OH&S (round)
step: Commencement reader
summary: 'Six fixer calls took the step''s 31 parked bugs and the round''s 16 leftover groups: our faults 599 on stored rules (31 fresh) to 0, leftovers not named 16 to 0. 86 reviewed held moves accepted (Decision 4 a); the round re-read and rebuilt (29,281 to 31,774 changes), then the HSWA checked rows (22 to 3) and the sources'' stale rules (Decisions 5 a, 6 a); step close Commencement reader PASS, stale on the Commencement reader 0.'
decisions:
- what: 'Decision 4 (a): accept the catalogues'' held moves'
  why: each reviewed against its sentence, every one toward the law's words; at the last commit's code all 1,579 held examples pass, so every move is this step's
  result: 70 own-clause and 25 order readings written (the example set re-chosen by --accept; 21 formerly pending reviewed again); 1971 c.10 s.40(2) kept pending
- what: 'Decision 5 (a): re-read the Railways Act 2005 orders and rebuild HSWA; --effects --law for FRSA 2004'
  why: the pass rule asks that the HSWA fixes show in the checked rows, and that no round law is stale on the reader
  result: checked rows 22 to 3; FRSA's 483 feed rules current; the read version kept unchanged by keeping the option in the task
- what: 'Decision 6 (a): re-read the 129 source laws'' stale rules'
  why: the round's stale laws named source laws (most with LAT rows in other families) on older reader code
  result: stale on the Commencement reader 56 to 0; no fetches
- what: Lean fixer briefs from call 4 (Jason)
  why: calls 1 to 3 took about 430k tokens and an hour each, re-running heavy checks
  result: calls 4 to 6 about 120k to 145k tokens and 10 minutes each; the session ran the full checks once after each
metrics:
  commencement_check:
    our_faults_stored: 599 to 0
    our_faults_fresh: 31 to 0
    leftovers_not_named: 16 to 0
    dated_rows: 19,342 to 21,360
    by_order_rows: 5,499 to 3,416
  gaps:
    rules_not_held: 106 to 50
    no_amending_law: 579 to 262
    appointed: 181 to 142
  build:
    changes: 29,281 to 31,774
    laws_moved: 46
  catalogues:
    held_moves_written: 95
    new_patterns: 49
    leftover_groups_statused: 24
  tests:
    mix_test: 11,114 passed, 0 failures
    golden: 27/27
    seed_71: identical
  agent_tokens:
    fixer_fable: about 1.70M over 6 calls and 4 follow-ups (calls 1 to 3 about 1.29M on the old brief)
lessons:
- title: Lean fixer briefs cost a third
  detail: calls 1 to 3 ran the full suite, four family checks and catalogue runs inside the call (about 430k tokens, an hour each); calls 4 to 6, one class group with the affected tests, one preview and a 150k cap, took about 120k to 145k tokens and 10 minutes. The session runs the full checks once after each call.
  tag: tooling
- title: Review the held moves one by one before the Decision
  detail: two misreadings got past the fixers' own tests (items lost beside a "so far as relating to" item when the day is unread; another Order's Articles read as the Order's own) and showed only in the moved readings against their sentences
  tag: data
- title: --accept re-chooses the examples
  detail: 'the readings written after --accept are not the set reviewed: 18 left and 21 joined (formerly pending, their pattern keys new and so auto-accepted). Write the held readings with a script after a second look, and keep a still-unread pattern pending'
  tag: tooling
- title: A store.ex change stales every stored rule
  detail: commencement/store.ex is in the commencement read version; a write-path option there would have staled every rule just re-read. Keep task options in the mix task
  tag: tooling
- title: A round's stale laws reach past its own laws
  detail: the build records the commencement sources it read; 129 source laws, most with LAT rows in other families, held rules on older reader code and kept 56 round laws stale after the round's own re-read
  tag: data
- title: Checked rows of a switched family need their own re-read
  detail: 'the 20 HSWA rows were Occupational''s: the round''s re-read and rebuild never touched them; the Railways Act 2005 orders'' re-read and HSWA''s rebuild moved them (22 to 3)'
  tag: data
bugs:
- pattern: '"Chapters II and III of Part I" in a clause list read as the whole Part I'
  category: commencement reading
  module: LawStart.Provisions
  affected: Freedom of Information Act 2000 s.103(2) (a catalogued pending class)
  fix: fixed, call 2 (@chapter_of_part)
  step: Commencement reader
  status: fixed
- pattern: A Schedule's Parts in an Act's clause ("Parts III and IV of Schedule 16") dropped rather than read as sch.N.pt.X
  category: commencement reading
  module: LawStart.Provisions
  affected: FOIA 2000 s.103(2), Access to Justice Act 1999 s.108(3)(f) (a catalogued pending class)
  fix: fixed, calls 1 and 2 (ScheduleParts)
  step: Commencement reader
  status: fixed
- pattern: An items-first order's "in Schedule 8, the entries relating to:—" heading reads nothing
  category: commencement reading
  module: Commencement.Order (split_head)
  affected: SI 1978/1583 (a catalogued pending class)
  fix: fixed, call 1 (items-first head)
  step: Commencement reader
  status: fixed
- pattern: 'An Act whose clause leaves its provisions to orders in other words still falls to Royal Assent: "Apart from section 54(1) and (2), the preceding provisions of this Act come into force in accordance with orders made by the Treasury" (Tax Credits Act 2002 s.61), "the remainder of this Act shall come into operation on such day as Her Majesty may by Order in Council appoint" (ukpga 1962/58, its rest unread); the SOCPA class, older'
  category: commencement
  module: LawStart.Clause (general / by_order forms)
  affected: unmeasured (2 seen in the catalogue)
  fix: fixed, call 2 ("Apart from", "the remainder")
  step: Commencement reader
  status: fixed
- pattern: Commencement orders held in the store but not read as rules (SI 1995/2950, 1997/1097, 2006/266, 2013/1869, 2016/603, 2020/1662; SSI 2009/319, 2013/51); SI 2015/994's 48 rules stored as commencing SI 2015/1637 (title-prefix match); a repealed commencement section falls back to Royal Assent (EPCA 1978)
  category: commencement reader
  module: Commencement.Orders / LawStart
  affected: 60
  fix: the round's held orders read at the re-read; three date-first forms fixed, call 6; NISR 1993/452 and SI 1993/2406 to Sources
  step: Commencement reader
  status: fixed
- pattern: 'Commencement reader: an order list cut at ''(except …)'' (SI 1995/2950, P6); ''section 10(6) and (7) (so far as aforesaid)'' read as {s.10(6)}; an NI-only order rule never emitted (TR); a catch-all ''so far as not already in force'' order dating provisions earlier orders (not held) brought in (SI 1997/134, KC-order); an amending law''s whole-law date not attached to its undated substitution (V8, SI 1989/2367)'
  category: upstream (CV-S09)
  module: Commencement.Order / Commencement.Amending
  affected: HSWA s.10, s.28(10)[S]; 2007/19 s.2(1)(d); EA 1989 repeals; SI 1989/462 reg.4, reg.7
  fix: '"(except …)" cut fixed, call 1; "(so far as aforesaid)" already right; the NI-only rule stored, its claim downstream; SI 1997/134 to Sources; SI 1989/2367 to the Amending-law reader'
  step: Commencement reader
  status: fixed
- pattern: 'A qualified list item''s "except …" is read as items (1981 c.69 s.74(2): s.72(4), (6), (14) read partly); a list with no ";" between items takes one item''s qualifier for all (1996 c.56 s.583(3))'
  category: list-item-qualifier-scope
  module: law_start/provisions.ex (sentence_groups/10)
  affected: 2 statements, 5 held readings in the way
  fix: fixed, call 2 (a qualifier binds its own item; no-";" lists split at commas)
  step: Commencement reader
  status: fixed
- pattern: 'A staged clause''s items dated "the seventh day after … made" and "on exit day" left unread beside an application item (SI 2019/145 reg.1(2)); a "namely—" list on a day the Act names ("the transfer date": 1986 c.44 s.68(3), 1984 c.12 s.110(3))'
  category: staged-and-named-day-lists
  module: law_start/provisions.ex
  affected: 3 statements
  fix: fixed, call 2 (exit day, the transfer date)
  step: Commencement reader
  status: fixed
- pattern: An amending SI's own commencement clause is held in the store but never read into commencement_rules, so its changes have no commenced_by and their date falls back to the feed (e.g. SI 2018/667 reg.1 'come into force on 12th July 2018'; SI 2018/1202, 2019/308, 2019/509)
  category: amending-law-own-clause-unread
  module: commencement/ (Commencement.Amending; mix lat.commencement --read-amending coverage)
  affected: 94 amending laws, 1,473 Maritime Safety text changes without commenced_by (gate gaps 'amending law has no commencement rules' 1,478)
  fix: fixed in code, call 3 (HeldAmenders, read by the same own-clause reader); read for the round at todo 6
  step: Commencement reader
  status: fixed
- pattern: 'An order''s table rules lose the territory its article names: SI 1988/818 art.2 brings the Schedule in ''in England and Wales'', every table rule reads ''everywhere'' (e.g. COPA 1974 s.12)'
  category: order-table-territory
  module: commencement/order.ex (tables/2)
  affected: unknown (every table-dated order whose article names a territory)
  fix: fixed, call 1 (a Schedule's rows take the introducer's place)
  step: Commencement reader
  status: fixed
- pattern: A law's cached order list names another Act's orders (SI 1996/1030 lists three Environment Act 1995 orders)
  category: order-list-wrong-law
  module: commencement/orders.ex
  affected: 4 orders listed under two family laws
  fix: fixed at the cause, call 5 (Orders.act_title/2); the Scotland Acts 2012 and 2016 lists parked
  step: Commencement reader
  status: fixed
- pattern: --read-orders without --law (amending Acts' cited orders) still replaces an order's rules by source alone
  category: cited-orders-write-overlap
  module: mix lat.commencement (read_orders)
  affected: unknown
  fix: fixed, call 5 (each cited order written per Act)
  step: Commencement reader
  status: fixed
- pattern: The check's --fresh reads own clauses without ScheduleEffect, so fresh and stored differ where a Schedule is tied (SI 2020/206)
  category: fresh-read-without-schedule-effects
  module: mix lat.commencement_check (fresh_rules)
  affected: 1 law in this family
  fix: fixed, call 5 (OwnRead shared)
  step: Commencement reader
  status: fixed
- pattern: The held-amenders list for --read-amending is built by hand and took in 21 commencement orders
  category: re-read-amenders-list
  module: mix lat.commencement (read-amending)
  affected: 21 orders in this family
  fix: fixed, call 3 (HeldAmenders)
  step: Commencement reader
  status: fixed
- pattern: 'Commencement rules left on an old reader version by orders no longer in an Act''s cached order list: 25 rules (2000 c.37 by SIs 2006/1279, 2005/423; 2000 c.38 by SI 2002/2024); 5,822 across the corpus for families not yet through'
  category: stale-order-rules-after-list-change
  module: lib/sertantai_legal/scraper/commencement/orders.ex (read-orders keeps rules of orders dropped from the list)
  affected: 25 reaching the three families
  fix: fixed, call 5 (a re-read reads every stored order; Store.order_sources/1); the round's 36 rules re-read; the store-wide 5,822 wait for each family's re-read
  step: Commencement reader
  status: fixed
- pattern: An order's 'in section N— (i) in subsection (2), paragraph (f) …' (or 'in Part 1(B) of Schedule 15 the entries relating to …') read as all of section N or the Schedule (SI 2004/2528 art.2(q) on Water Act 2003 s.86; SI 2007/709 on 2006 c.48 Sch.15)
  category: order-in-list-read-whole
  module: commencement/ (order list reading)
  affected: '42 changes in 2 laws (Environmental Protection: 2003 c.37 40, 2006 c.48 2)'
  fix: fixed, call 1 (SectionHeads)
  step: Commencement reader
  status: fixed
- pattern: 'An order item read as partial though it brings the provision wholly in: its bracketed heading taken as a territory or purpose (''(water and sewerage undertakers in England: …)'', ''(… for the purpose of access rights)''), or a Welsh order''s W for a Welsh Act extending to England and Wales (SI 2022/48 on 2021 c.30 s.86; WSI 2023/1149 on asc 2023/2)'
  category: order-item-read-partial
  module: commencement/ (order list reading; territory)
  affected: 22 changes in 3 laws (asc 2023/2 17, 2021 c.30 4, asp 2026/6 1)
  fix: fixed, call 1 (Asides; a devolved order on its own legislature's Act carries no territory)
  step: Commencement reader
  status: fixed
- pattern: An amending law's own clause dates some provisions apart and they take the general date ('This Regulation and regulation 2 come into force on the 22nd day after … laid', 'except for the following provisions which come into force on 5th July 2018—', '(except regulation 4(2) and (5))' held as '(except regulation and )') (SI 2018/1202 reg.1(3); SI 2018/575, 2018/942, 2018/1227)
  category: clause-exception-date-unread
  module: commencement/ (Commencement.Amending, own clause)
  affected: '22 changes in 4 laws (Maritime Safety 19: SI 2018/1202; Environmental Protection 3)'
  fix: fixed, call 3 (inline citations kept; "except for the following provisions …—"; relative days kept unread)
  step: Commencement reader
  status: fixed
- pattern: 'The commencement and order catalogues'' dry runs write patterns, examples, laws and leftover groups whether or not --accept is given (only expected.json waits); a dry run must write nothing (Environmental Protection: Commencement reader lesson)'
  category: catalogue-dry-run-writes
  module: lib/mix/tasks/lat.commencement_patterns.ex, lat.order_patterns.ex
  affected: every catalogue dry run
  fix: 'fixed, call 5 (CommencementCatalogue.Target: dry runs write under data/reports/commencement-reader/dry-run/)'
  step: Commencement reader
  status: fixed
- pattern: 'An Act''s territorial by-order clause read as a partial commencement at Royal Assent (CNEA 2005 s.108(1)(a): ''in relation to England, in accordance with provision made by order'')'
  category: territorial-by-order-read-qualified
  module: commencement/ (own clause reading)
  affected: 553 changes (CNEA 2005, s.108(2) provisions)
  fix: fixed, call 2 (a by-order clause for one country is by order there)
  step: Commencement reader
  status: fixed
- pattern: A change on HSWA 1974 by the Railways Act 2005 is dated 2005-07-24 by SI 2005/1909, whose rules for the Act are mostly partial ('for specified purposes', 'in relation to'), where it came in on 2006-04-01 (HSWA s.11(1), s.14, s.16, s.18(5)(b), s.43A(2)(a) and others)
  category: partial-order-dates-in-full
  module: Commencement (evaluator over the 2026-11-10 order re-reads, ReadVersion de2446699978)
  affected: '20 OH&S checked rows (HSWA 1974); not yet counted elsewhere. Present before this step: rules read 2026-11-10, a path this step''s code doesn''t reach. OH&S''s stored timeline already carries it (switched laws refold at each build)'
  fix: 'fixed, call 4 (repeal entries are another law''s; completing form full): 19 of the 20 HSWA rows match after the Railways Act 2005 orders'' re-read and HSWA''s rebuild (Decision 5 a); s.64 parked with the Label fold'
  step: Commencement reader
  status: fixed
- pattern: 'The round''s 49 laws built at Fire and OH&S: Sources are stale for the commencement reader (their commencement reads predate the build), so the step close''s Stale laws fails 49'
  category: built-before-commencement-read
  module: mix lat.commencement (the mode that wrote them), then build
  affected: 49 laws (Fire and OH&S)
  fix: 'fixed: the round re-read and rebuilt; the source laws'' stale rules re-read (Decision 6 a); stale on the Commencement reader 0'
  step: Commencement reader
  status: fixed
- pattern: 'An amending law''s purpose-limited first stage is held as a commencement rule but no partial commencement change is emitted for the provisions it inserts, so the chosen date is the later full stage and the partial period is lost (e.g. MSA 1995 s.255N by 2011 c.8: SI 2015/133 art.2(1) from 2015-02-05 for art.2(2) purposes, the feed''s partial date 2015-02-05; chosen 2015-04-14)'
  category: amending-law-staged-start-dropped
  module: commencement/amending.ex (Commencement.Amending)
  affected: 21 Maritime Safety text changes (MSA 1995 Pt 9A by 2011 c.8); others in the store (2006 c.16 s.89A, 1990 c.8 s.252(12), SI 2010/2214 reg.20(3A), (3D))
  fix: reader half fixed, call 3 (commencement.stages on the claim); the label half moved to the Label fold (label-reads-commencement-stages)
  step: Commencement reader
  status: moved
- pattern: 'EU wording ''shall enter into force'' is not commencement words for SentencePatterns (@cif reads come/came/coming/brought into force or operation only), so a retained EU Regulation''s own entry-into-force article reads as a requirement (e.g. UK_eur_2019_1010 art. 11, its only one: decided making)'
  category: eu-enter-into-force
  module: Commencement.SentencePatterns (@cif)
  affected: 1 law decided on it (Environmental Protection); every retained EU instrument's entry-into-force article
  fix: 'not landed: no own-clause rule moves; two making verdicts would (EU 2019/1010, SI 2011/1506), none in the round; moved to Making laws'
  step: Commencement reader
  status: moved
- pattern: 'EU wording ''shall enter into force'' is not commencement words for SentencePatterns (@cif reads come/came/coming/brought into force or operation only), so a retained EU Regulation''s own entry-into-force article reads as a requirement (e.g. UK_eur_2019_1010 art. 11, its only one: decided making)'
  category: eu-enter-into-force
  module: commencement/sentence_patterns.ex (@cif) and the making verdicts
  affected: 68 LAT laws (106 rows) hold the wording; 2 making verdicts would move
  fix: read "shall enter into force" as commencement words, then re-decide the two making verdicts
  step: Making laws
  status: open
- pattern: 'Five own-clause forms left: CNEA 2005 s.108(2)(h) "other than the repeal to section 33 of that Act" read as the Act''s own s.33; a provision left to an order for one country keeps the general rule elsewhere (2017 c.29 s.124(3)); a bracketed heading''s "in Wales" still qualifies a non-list statement (SI 2010/490); "This Act except … on the transfer date" unread (1971 c.10 s.40(2), its pattern kept pending); a qualifier over several items qualifies the whole list (1996 c.52 s.232(2))'
  category: own-clause-forms-left
  module: law_start/provisions.ex, commencement/own_clause.ex
  affected: 5 statements, unmeasured rows
  fix: one test per form, then the fix
  step: Commencement reader
  status: open
- pattern: The cached order lists for the Scotland Act 2012 and the Scotland Act 2016 hold other Acts' orders (the Police and Fire Reform (Scotland) Act's SSIs 2012/253, 2012/333, 2013/47; the Inquiries into Fatal Accidents Act's SSIs 2016/196, 2016/370), from the tail-of-title match; the reader now reads nothing from them
  category: order-list-other-acts-orders
  module: commencement/orders.ex (cached lists)
  affected: 2 lists, 41 rules
  fix: re-read both Acts' orders (--read-orders --law … --held) with their families
  step: Commencement reader
  status: open
- pattern: Leftovers' named-day dates hold only exit day and IP completion day, not "the principal appointed day"; Order.own_articles/2 keeps capital Article refs for any instrument (an order commencing an SI that names its own Articles could misread)
  category: named-days-and-own-articles
  module: commencement/leftovers.ex, commencement/order.ex
  affected: unknown
  fix: add the principal appointed day to Leftovers; scope own_articles to Orders in Council
  step: Commencement reader
  status: open
- pattern: SI 2020/852's Schedule paragraphs hang on a tied day, so 9 round changes are not reached
  category: tied-day-schedule
  module: commencement/
  affected: 9 round changes
  fix: known-limit candidate, or read the tied day
  step: Commencement reader
  status: open
- pattern: A purpose-limited first stage is carried on the amending law's claim (commencement.stages) but the fold does not read it, so the partial period is lost (MSA 1995 s.255N by 2011 c.8)
  category: label-reads-commencement-stages
  module: change_vocabulary/label (start from claims)
  affected: 36 round text changes (2013 c.32 ×21, 2004 c.20 ×7, SI 2005/1643 ×4), 60 Maritime Safety
  fix: read commencement.stages as partial in-force entries before the full date
  step: Label fold
  status: open
- pattern: HSWA 1974 s.64's checked label has in_force_from 1974-07-31, but the Act is all by order and none of its six held orders (nor SI 1974/1439) names s.64, so the label now has none (left-to-an-order-date-unknown)
  category: checked-row-by-order-no-order
  module: change_vocabulary/label (start), or the checked fixture
  affected: 1 checked row (HSWA s.64)
  fix: 'decide: accept the current label with the rule as the why, or find s.64''s commencing order'
  step: Label fold
  status: open
- pattern: An Act's title is cut at the first year inside it, as Orders.act_title/2 did (SI 2015/1637 matched as the Deregulation Act 2015)
  category: act-title-cut-at-inner-year
  module: amendment/read_law.ex:109
  affected: unknown
  fix: drop only the law's own trailing year
  step: Amending-law reader
  status: open
- pattern: The same title cut at the first year inside an Act's title
  category: act-title-cut-at-inner-year
  module: change_collector.ex:286
  affected: unknown
  fix: drop only the law's own trailing year
  step: Register
  status: open
- pattern: 40 of the round's amending laws are not held (92 changes); NISR 1993/452 has no body held; SI 1993/2406 not held
  category: amending-laws-not-held
  module: sources
  affected: 40 laws, 92 changes; 2 orders
  fix: fetch with the next Sources sweep (ask first)
  step: Sources
  status: open
- pattern: FRSA 2004's backlog documents SI 2017/399 (body and schedules) and SI 2018/227 (body) are stale in the store (step close Sources 3)
  category: sources-stale-backlog
  module: sources
  affected: 3 documents
  fix: swept by the Extent reader's first todo (RULES sources-fetch-failures-swept-each-step)
  step: Sources
  status: open
- pattern: 'The pre-commit hook''s mix credo diff leaves its /tmp/credo-diff-* clone behind on every run (about 131 MB each), so /tmp (a 20 GB tmpfs) filled: 106 clones from 9 to 14 Nov, ~14 GB, and credo diff then fails'
  category: credo-diff-clones-left
  module: .githooks/pre-commit (credo diff step)
  affected: every commit since 2026-11-09; 105 cleared 2026-11-14 on Jason's go
  fix: remove the clone at the end of the hook's credo diff (trap EXIT), or point credo diff at a fixed reused dir
  step: Tooling
  status: open
artifacts:
- backend/lib/sertantai_legal/scraper/commencement/order/ (asides, section_heads, schedule_parts, territory, entries)
- backend/lib/sertantai_legal/scraper/commencement/held_amenders.ex, amending_read.ex, own_read.ex
- backend/lib/sertantai_legal/scraper/law_start/ (statements, list_items, territorial, number_words, that_day)
- backend/lib/sertantai_legal/scraper/commencement_catalogue/target.ex
- backend/test/fixtures/commencement_patterns/, order_patterns/
- backend/data/reports/commencement-reader/fire-and-ohs-*.txt, held-write.exs
- docs/lat-change-pipeline/RULES.md, WORKFLOW.md, COMMENCEMENT-GUIDE.md
- .claude/skills/commencement-reader-check/SKILL.md
depends_on:
- 2026-11-14-fire-and-ohs-markup-reader
- 2026-11-13-fire-and-ohs-meta
enables:
- 'Fire and OH&S: Extent reader (first todo: sweep Sources, SI 2017/399 and SI 2018/227)'
---

# Session: Fire and OH&S: Commencement reader (CLOSED)

## Problem

This is step 4 of the round, over 139 UK laws with LAT rows. Each provision must be dated, left to an order, or undated with a reason. The dates come from the law's own commencement clause, its orders and, for a change, its amending provision's commencement.

The step also takes:
- the 31 parked Commencement reader bugs of any family;
- the 22 HSWA checked rows (SI 2005/1909);
- the Sources sweep: 9 documents not fetched or stale (RULES `sources-fetch-failures-swept-each-step`).

- **Plan (approved 2026-11-14):** `~/.claude/plans/gleaming-doodling-matsumoto.md`
- **Aim:** `binds-on-date`; principle `law-text-wins`
- **Time box:** two days
- **Meta:** `2026-11-13-fire-and-ohs-meta.md`
- **Skill:** `commencement-reader-check`

## Todo

- ✅ Open the step session and meta row. Sources swept (`fire-and-ohs-sources-fetch.txt`): the 9 fetched, gate PASS, failures 0 (`fire-and-ohs-sources-after.txt`). Baseline saved (`fire-and-ohs-0.txt`). The 22 checked rows are 20 HSWA 1974 rows (SI 2005/1909, this step's) and 2 CLP rows (EU 2008/1272 Arts 53a and 53b, already parked with the Label fold, which the round reaches at step 9)
- ✅ Reach and dispositions (section below): the fresh baseline puts our faults at 31 (SI 1994/232 only; the 568 `no_rules` rows clear with a re-read); the 16 leftover groups and 31 parked bugs mapped to five fixer calls, with known limits and other owners named
- ✅ Fixer calls: order-list and own-clause classes, test first, reviewed in turn; pre-flight (calls 1 and 2 below: the fresh check's our faults 0, leftovers not named 7, all call 3's; 74 held moves for todo 5)
- ✅ Fixer calls: amending-law classes (with the 22 HSWA rows), order-store and task classes taken; pre-flight (calls 3–6 below; the session's own full checks after them)
- ✅ Catalogues once after the fixes (dry run into a scratch copy, compared with the last commit's code); every leftover group reviewed; held moves to Jason (Decision 4 a: accepted; catalogue tests and `LeftoversReviewTest` pass; the round's fresh check PASS)
- ✅ Restore point; re-read (own, orders with the title-search laws named first, missing orders fetched, amending `--workers 1`) and one round rebuild (Jason's go); checks for the round and the three switched families (no searches or fetches; round 29,281 → 31,774 changes; all four checks PASS)
- ✅ Pass: `lat.commencement_check` PASS; seed 71 twice under `cmp`; golden; checked rows; `mix test`; `mix lat.step_close --family "Fire and OH&S" --step "Commencement reader"` (Commencement reader PASS; checked rows 22 → 3, parked with the Label fold; stale on the Commencement reader 0; Sources 3 for the Extent reader's sweep; Decisions 5 and 6 a)
- ✅ Close: RULES, WORKFLOW, the skill's history, the meta row, commits by path (code a9af8e41)

## Dependencies

- ✅ Fire and OH&S: Markup reader closed (2026-11-14, pushed 11e6c45e)

## Pass rule (fixed)

1. `mix lat.commencement_check --family "Fire and OH&S"` prints PASS: rows' our faults 0, and every leftover reaching the round named `known:`.
2. Both catalogues are regenerated. Every leftover group is reviewed (`LeftoversReviewTest`), and the catalogue tests pass. Held expectations move only after Jason's decision.
3. Seed 71 twice: the samples are identical under `cmp`.
4. Golden 27/27.
5. Each parked Commencement reader bug is fixed with a test, named a known limit, or left parked with its size and a reason.
6. The switched families' commencement checks stay at our faults 0, or change only by the fixed classes. Their moved laws are listed.
7. `mix test` 0 failures; the architecture tests, the Credo ratchet and the hooks are clean.
8. The step close is recorded:
   - Sources PASS;
   - Checked rows: the 22 fixed or accepted with a rule;
   - Stale laws: 0 for the Commencement reader's reason.

   Any other failure is parked with its owner.

**Frozen:** `golden.exs`, the checked-row fixtures, and the held expectations in the catalogues and `leftovers.json`.

## Parking list

- Commencement reader (this step, later calls or known limits): five own-clause forms from call 2 (CNEA s.108(2)(h) "other than the repeal to section 33"; one-country by-order left general elsewhere; bracketed heading's "in Wales" on a non-list statement; 1971 c.10 s.40(2); a qualifier over several items).
- Label fold: read `commencement.stages` (a purpose-limited first stage's partial period; 36 round, 60 Maritime changes).
- Commencement reader (Maritime's next pass): SI 2006/1244 purpose-limited date as whole start, 93 Maritime labels, round 0.
- Amending-law reader: act-title-cut-at-inner-year — `amendment/read_law.ex:109` cuts an Act's title at the first year inside it (as `Orders.act_title/2` did; SI 2015/1637); reach unknown.
- Register: act-title-cut-at-inner-year — the same cut in `change_collector.ex:286`; reach unknown.
- Sources: NISR 1993/452 body not held; SI 1993/2406 not held.
- Sources: 40 round amending laws not held (92 changes).
- Making laws: eu-shall-enter-into-force — 2 making verdicts would move (EU 2019/1010, SI 2011/1506), none in the round.
- Tooling: credo-diff-clones-left. The pre-commit hook's `mix credo diff` leaves a 131 MB clone in /tmp per run; 105 were cleared on Jason's go.

## Baseline (2026-11-14)

The check was `mix lat.commencement_check --family "Fire and OH&S"` (76 s). The result is **FAIL**: rows' our faults 599, and 16 leftovers not named.

- **Rows:** 27,114 in 139 laws.
  - 19,342 dated.
  - 5,499 left to orders.
  - **568 with no rules, in 37 laws:** never read.
  - **31 not reached:** SI 1994/232, revoked with rows (parked with the LAT parser).
- **Leftovers reaching the round:** 14 groups `fix:`, 1 `known:`, 2 with no status. The largest reaches are SI 2004/2304 art.2(2) (1,225), the Mines and Quarries Act 1954 s.194 (396), 1969 c.10 s.38(3) (286), SI 1989/1401 reg.1(3) (101), SI 1994/232 reg.1(a) (60) and 2021 c.24 s.4(5) (32).
- **Gap-filler:** 1,328 changes no other source dates (306 text changes).
  - 235 dated via the feed, 135 via a note.
  - Undated: 579 with no amending law, 181 appointed, 106 with rules not held, 70 with no pointer, 17 not reached.

## The fresh baseline (2026-11-14)

The check was `mix lat.commencement_check --family "Fire and OH&S" --fresh --all` (50 s): own clauses read fresh, nothing written (`fire-and-ohs-0-fresh.txt`).

- **Our faults: 31**, all `not_reached` in SI 1994/232. It is revoked but still holds rows, which is the parked LAT parser bug. The 568 `no_rules` rows clear with a re-read.
- **Leftovers:** the same 16 groups not named.
- **Other figures:** 24 rows `unread` in 16 laws (not a fault); 93 rows differ from the feed (yardstick only).

## Dispositions: the 16 leftover groups and the 31 parked bugs

Reach in the round is taken from the gate (leftovers, gaps, faults). The store reach is the parked entry's.

**Fixer call 1: order-list reading** (`Commencement.Order`)
- **The leftover.** SI 2004/2304 art.2(2), "Subject to article 3 the 2004 Act shall, insofar as it is not already in force, come into force on 1st October 2004", reads nothing. It reaches 1,225 rows, and 3 statements, 1,228, store-wide.
- **The parked bugs:**
  - the items-first "in Schedule 8, the entries relating to:—" head (SI 1978/1583);
  - a list cut at "(except …)", "so far as aforesaid", an NI-only rule, and the catch-all;
  - "in section N— (i) in subsection (2) …" read whole (42 in Environmental Protection);
  - a bracketed heading read as a territory or purpose (22);
  - table rules losing the article's territory (SI 1988/818, unknown).
  - The shared namer's nested schedule ids have no effect while schedules are unparsed, so that bug stays parked on that reason.

**Fixer call 2: the law's own clause** (`LawStart.Provisions`, `LawStart.Clause`, `Commencement.OwnClause`)
- **The leftovers:**
  - 1969 c.10 s.38(3): Part II by order, per territory (286);
  - SI 1989/1401 reg.1(3): a staged list of three dates (101; 3 statements, 162);
  - the Mines and Quarries Act 1954 s.194's Interpretation Act tail (396): to be judged a check's own error or a known limit;
  - 2021 c.24 s.4(5): "at the same time as section 1 comes fully into force in relation to premises in England" (32);
  - SI 1994/232 reg.1(a) (60);
  - SI 2017/720 reg.1(2) (9, no status).
- **The parked bugs:** "Chapters II and III of Part I"; a Schedule's Parts; "Apart from … orders"; a schedule commenced through its introducing provision, and "This section has effect from"; a qualified item's "except"; staged items and "namely—" (1984 c.12 s.110(3) reaches the round, 2 rows); EU "shall enter into force"; CNEA 2005's territorial by-order clause (553).

**Fixer call 3: the amending law's commencement** (`Commencement.Amending`, and the held-amenders list)
- **The leftovers:**
  - "reads nothing — date left": SI 1991/259 reg.1 and SI 1999/2463 reg.1 (13 statements, 151);
  - SI 2002/716 reg.1(2);
  - SI 1988/1729 reg.1(1)(a);
  - 1968 c.64 s.20(4);
  - 2014 c.12 s.185(2)(b) (5 statements, 172);
  - SI 2026/40 reg.1(2) (no status).
- **The parked bugs:**
  - an amending SI's own clause never read, together with the held-amenders list built by hand. In the round this is the gap `rules_not_held`, 106 changes by about 40 amending laws.
  - a purpose-limited first stage emitting no partial change (21);
  - a purpose-limited date taken as the whole start (113);
  - provisions the clause dates apart taking the general date (22);
  - an insertion holding no date though its law's orders are read (692).

**Fixer call 4: SI 2005/1909 on HSWA 1974** (the 20 HSWA checked rows).

**Fixer call 5: the order store and the task**
- orders held but not read (60);
- one Act's orders in another's list (4);
- `--read-orders` without `--law`;
- `--fresh` without the schedule's effect (1 law);
- rules left on an old version by dropped orders (25 in three families; 5,822 in the store);
- the catalogue dry runs writing fixtures.

**Known limits and other owners:**
- **Event days** (2014 c.12 s.185(6); SI 2026/40's agreement): a known limit already (COMMENCEMENT-GUIDE §4).
- **A change dated before its amending law was made** (2 Maritime and 7 Environmental Protection rows): named known limits already.
- **The 2 CLP checked rows:** parked with the Label fold.
- **SI 1994/232's 31 `not_reached` rows:** the LAT parser's revoked-with-rows bug. Pass rule 1 needs a Decision if they stay.
- **The 49 stale laws:** cleared by todo 6's re-read and rebuild.

Each fixer call returns its classes as fixed, known limit, or left parked with size and reason. The table is updated after each call.

## Fixer call 1: order-list reading (2026-11-14)

The call cost 377k tokens (Fable).

- **Fixed, test first** (`order_list_reading_test`, 19 tests):
  - SI 2004/2304 art.2(2) now reads all, 2004-10-01, E+S. The order's title names its territory.
  - SI 1978/1583's "in Schedule 8, the entries relating to" now reads sch.8.
  - SI 1995/2950's lists are read past "(except …)".
  - "in section N—" is a heading over its items.
  - Bracketed headings give no territory or purpose. A devolved order on its own legislature's Act carries no territory (223 rules).
  - A Schedule's rows take the place its introducing article names (SI 1988/818, six rules to E+W).
- **Parts of class 3 that are not order-list reading:**
  - "(so far as aforesaid)" already read right.
  - The NI-only rule is stored, but no claim is emitted from it: downstream.
  - SI 1997/134 reads faithfully, but SI 1990/189 is not held: Sources.
  - SI 1989/2367: the Amending-law reader.
- **Reach** (own rows, HEAD against now, over stored rules):
  - Fire and OH&S: 1,139 FRSA 2004 rows move from partly by order to staged (partly from 2004-10-01, fully from 2004-11-10 by WSI 2004/2917).
  - Environmental Protection: 202 rows.
  - Occupational and Maritime Safety: 0.
  - About 120 of 589 orders' rules change.
  - Fresh checks: the round's leftovers not named go from 16 to 15; the switched families PASS.
- **Held expectations moved:** 21 (16 in the order catalogue, 5 in the own-clause catalogue through the shared Schedule reading). These go to Jason at todo 5.
- **New classes found:**
  - SI 2005/1909's "The entries relating to sections … of the Transport Act 2000" is read as the Act's own sections. This bears on the HSWA rows, so it goes to fixer call 4.
  - A defined abbreviation for another law ("of the WIA") is read as the Act's (SI 2004/2528).
  - A repeals table of other Acts is read as the Act's (SI 1994/2850).
  - Mixed-level bracket lists, known limit (Water Act 2003 s.100).
- **Review:** `order.ex` grew to 1,987 lines because the helpers stayed private. The fixer was sent back to split them into modules, behaviour-preserving, and to run `mix credo diff` once /tmp was cleared.
- **The split** (the same fixer, resumed; 414k tokens for call 1 in all):
  - four pure modules under `commencement/order/`: `Asides`, `SectionHeads`, `ScheduleParts`, `Territory`;
  - `order.ex` is down to 1,845 lines;
  - the seven version files that ask for it list `commencement/order/*.ex`;
  - the rule read for all 589 orders is byte-identical, and the same 21 held expectations fail;
  - `mix credo diff` added no issues.
- **A latent fault, for call 5:** `Territory.only/1` keeps the old behaviour, where a place named in two introducing texts gives no territory.

## Fixer call 2: the law's own clause (2026-11-14)

The call cost 431k tokens (Fable).

- **The round's fresh check:** our faults 31 → 0, and leftovers not named 15 → 7. The 7 left are amending-law statements, which are call 3's.
- **The leftovers:**
  - 1969 c.10 s.38(3), fixed: Part II is by order for E+W and for S.
  - SI 1989/1401 reg.1(3), fixed: all three dated statements are read.
  - 1954 c.70 s.194: the check's error is fixed (its construction words), and sections in words are now read (s.172 and s.190 on Royal Assent).
  - 2021 c.24 s.4(5): read as appointed with s.3, an event day (GUIDE §4), so class `by_order`.
  - SI 1994/232 reg.1(a), fixed: the "except for …" item was unread, and reg.6's qualifier had spread to reg.4. This clears the 31 `not_reached` rows, so no Decision is needed.
  - SI 2017/720: the check's pointer error is fixed, and "6th July2017" is read. reg.2(2) is an event day, a known limit.
- **The parked bugs:**
  - Fixed: Chapters of a Part; a Schedule's Parts; "Apart from … orders" and "the remainder … by Order in Council" (1962 c.58: s.41 on passing and the rest by order, so 488 rows move from staged to `by_order`, checked against the text); a qualified item's "except"; "on exit day" and "on the transfer date"; CNEA 2005's territorial by-order clause.
  - Known limit: "This section has effect from" (one statement, LGA 1985 s.84(3), not in the round).
  - EU "shall enter into force": not landed. No own-clause rule changes, but two making verdicts would (EU 2019/1010, SI 2011/1506, neither in the round). Left parked with Making laws.
- **Reach:**
  - The round's rows: dated 20,135 → 19,961; by_order 4,061 → 4,812; staged_start_only 488 → 0; partial_only 34 → 0; unread 24 → 16.
  - Environmental Protection: dated +25 and by_order +5 (CNEA 2005); PASS.
  - Occupational: no change; PASS. Maritime Safety: no row change; PASS.
  - The whole store: leftover groups 209 → 183, and unread sentences 173 → 139.
- **Held expectations moved:** 54 more (53 own-clause, 1 order), for 74 in all with call 1's 21 (one of call 1's now passes). Each moved reading is in `backend/data/reports/commencement-reader/fire-and-ohs-held-moved-call-2.txt`. They go to Jason at todo 5. In `leftovers.json`, 27 statused groups no longer arise, and 1971 c.10 s.40(2) moves.
- **New classes found, for the parking list:**
  - CNEA s.108(2)(h): "other than the repeal to section 33 of that Act" is read as the Act's own s.33.
  - A provision left to an order for one country keeps the general rule elsewhere (2017 c.29 s.124(3)).
  - A bracketed heading's "in Wales" still qualifies a statement that is not a list (SI 2010/490).
  - 1971 c.10 s.40(2), "This Act except … on the transfer date", is `clause_unread`.
  - A qualifier over several items still qualifies the whole list (1996 c.52 s.232(2)).
  - COMMENCEMENT-GUIDE §3.2 is not yet updated for these forms (todo 8).
- **Review:**
  - Compile with warnings as errors, and `mix credo diff`, are clean.
  - `mix test` has 74 failures, all held catalogue examples.
  - Pre-flight (`fire-and-ohs-preflight-1.txt`): compile, architecture and golden 27/27 PASS. Checked rows 22 FAIL is the baseline, for call 4.

## Fixer briefs from call 4 (Jason 2026-11-14)

Calls 1 and 2 each took over 400k tokens, and call 2 took 80 minutes. From call 4 the briefs are lean:
- one small class group per call;
- only the affected tests, and one `--fresh` over the affected laws;
- a cap of about 150k tokens.

The session itself runs compile, `mix credo diff`, `mix test` and the four families' fresh checks once, after each call. Call 3 was already running on the old brief.

## Fixer call 3: the amending law's commencement (2026-11-14)

The call cost 429k tokens (Fable), on the old brief.

**Round fresh check** (`fire-and-ohs-call-3-fresh.txt`):
- our faults 0;
- leftovers not named 7 → 1, SI 1988/1729 reg.1(1)(a);
- `rules_not_held` 106 → 50, by laws not held or with no amender named;
- row outcomes unchanged.

Environmental Protection, Occupational and Maritime Safety each PASS, byte-identical.

**The leftovers:**
- Fixed:
  - SI 1991/259 ("may cited as");
  - SI 1999/2463 (a bracketed date);
  - 1968 c.64 s.20(4) ("namely …" before the verb; "this section (except subsection (2))");
  - 2014 c.12 s.185(2)(b) ("beginning with that day") and s.185(6) (the Scottish Ministers' order is by order, not an event day);
  - SI 2026/40 (the check's own error).
- SI 2002/716 was already read after call 2.
- **Known limit:** SI 1988/1729 reg.1(1)(a), a start staged by the cases it applies to (1989 for most mines, 1994 for existing miscellaneous mines). It is read at its first date. One law, 8 changes. Its `known:` status is written with todo 5.

**The parked bugs:**
1. **An amending SI's own clause never read, and the held-amenders list built by hand: fixed in code.**
   - `Commencement.HeldAmenders` derives the list from code, and `mix lat.commencement --amenders --family F` prints it.
   - For the round it is 319 laws to read (`fire-and-ohs-held-amenders.txt`), 112 of which hold no rules (483 changes).
   - Left out: 19 commencement orders, 85 LAT laws, and 40 laws not held (92 changes, Sources).
   - `--fresh` now reads the amending laws fresh too. The re-read itself is todo 6.
2. **A purpose-limited first stage: the reader half is fixed.** `commencement.stages` is now carried on the claim (36 round changes, 60 Maritime). Reading it is the Label fold's half (Parking).
3. **A purpose-limited date as the whole start (SI 2006/1244): left parked.** It reaches 0 in the round and no checked rows. It would move 93 Maritime labels, so it waits for Maritime's next pass.
4. **Provisions dated apart taking the general date: fixed.** There were three causes, one of them inline citations dropped from clause text ("(except regulation and )"). 34 stored changes move, all onto the feed's date but one: SI 2010/1110 dates SI 2010/330 reg.11(6)(b) at 5 April 2010 from the law, against the feed's 6 April.
5. **An insertion or repeal undated though orders are read: left for call 6.** It reaches 30 round changes. 22 are 1991 c.22 Sch.8, where SI 1992/2984 and SI 1992/2990's "in so far as it relates to England and Wales … and has not already been commenced" is read as purpose-partial; this is order-list work. The rest are whole-Schedule pointers, undated by design.

**New classes found:**
- "the principal appointed day" (SI 1999/1750, 1999/1756): 35 round changes, the day 1 July 1999 by SI 1998/3178. This goes to call 6.
- SI 2020/852: 9 changes not reached, its Schedule paragraphs hung on a tied day. Known-limit candidate.
- Label fold: read `commencement.stages`.
- Sources: 40 amending laws not held.

**Held expectations moved:** 8 more, 82 in all (`fire-and-ohs-held-moved-call-3.txt`).

**Review:**
- The fixer clobbered `lat.commencement.ex` with a scripted edit and restored it from HEAD. I checked it: every task mode survives in one `dispatch/2`, and `MIX_ENV=dev mix compile --warnings-as-errors` is clean.
- `mix test`: 82 fail, all held examples.
- `credo diff --strict` flags 3 readability issues in calls 1–2's new tests; they are fixed before the commit.
- Pre-flight: golden 27/27; checked rows 22, as before.

**The remaining calls (lean briefs):**
- Call 4: SI 2005/1909 on HSWA (20 checked rows), with the Transport Act 2000 entries class.
- Call 5: the order store and task, with `Territory.only/1`.
- Call 6: order-list follow-ups, "has not already been commenced" and "the principal appointed day".

## Fixer call 4: SI 2005/1909 on HSWA 1974 (2026-11-14)

The call cost 123k tokens and 8 minutes on the lean brief (Fable), against about 430k and 70–80 minutes on the old one.

**The cause.** Two misreadings in `Commencement.Order`; both had to be fixed.
1. SI 2005/1909's repeal entries, "The entries relating to Schedule 2, Schedule 3 and Schedule 6 of the Railways Act 1993", were read as the Railways Act 2005's own sch.2 and sch.3, fully in force on 2005-07-24. Sch.3 holds the HSWA changes.
2. SI 2006/266's "Schedule 3, to the extent that it has not already come into force" was read as partial. It is a completing form.

**The fix.** It is in `order/entries.ex` (new) and in `order.ex` (`line_items/3`, `entry_line_items/3`, `@full`). There are 3 tests in `order_list_reading_test`.

**Reach.** Over all 7,832 order rules, only the four Railways Act 2005 orders change:
- 25 rules for other Acts' entries are dropped;
- 6 now read sch.13 Part 1 partly;
- 20 move from partial to full.

**The HSWA claims:**
- s.11(1), s.14, s.16, s.18(5)(b), s.50(1A) and s.53(1) move from 2005-07-24 to 2006-04-01, by SI 2006/266.
- s.43A moves to 2006-02-07, by SI 2006/266 art.2(1); the order and the feed agree.
- The 20 checked rows re-score only after the re-read and rebuild (todo 6).

**Found.** SI 2005/2812's "Schedule 13, Part 2, paragraph 2." is read as the whole of Sch.13. The same fixer was resumed to take it, with a cap of about 60k tokens.
- **The follow-up** (the same fixer, resumed, on the lean brief):
  - "Schedule 13, Part 2, paragraph 2." now reads `sch.13.para.2`. Before, it read `sch.13, pt.2, sch.12.para.2`, which took in the whole Schedule. A Part that only says where its paragraphs are is not kept in the ref, as for NISR 2020/58.
  - The fix is in `ScheduleParts.as_place/1` and `Order.plain_line_items/3`, with 2 tests.
  - Exactly one rule changes over all 7,832.
  - The HSWA s.18(5) and s.78(7)(c) repeals lose the wrong 2005-10-16, leaving the feed's dates (2005-06-08 and 2006-04-01).
  - `OrderPatternsTest` still has 17 failures, the same set.

## Fixer call 5: the order store and the task (2026-11-14)

Lean brief (Fable, stopped at the ~150k cap). Affected tests 150 pass; compile and credo diff clean.

1. **Orders held but not read: left to the re-read.** In the round, 15 orders are listed for 7 laws. Four are not yet read, and todo 6 reads them: SSI 2012/253, 2012/333 and 2013/47, and SI 2004/2304.
   Three are read as nothing, and go to call 6 as order forms:
   - SSI 2013/51, date first: "1st April 2013 is the day appointed …";
   - NISR 1996/251, "The day appointed … is 14th July 1996";
   - NISR 2010/328, "In so far as not already in operation, the day appointed …".

   NISR 1993/452 has no body held, and SI 1993/2406 is not held at all (Sources).
2. **One Act's orders in another's list: fixed.** The Act's title was cut at the first year inside it, so SI 2015/1637 was matched as the Deregulation Act 2015.
   - `Orders.act_title/2` now drops only the trailing year.
   - 70 wrong rules stored for SI 2015/1637 are dropped by a `--read-orders --law UK_uksi_2015_1637 --held` run.
   - 67 rules of the Deregulation Act are restored.
3. **`--read-orders` without `--law`: fixed.** A cited order is written per Act.
4. **`--fresh` without the schedule's effect: fixed.** `--read` and `--fresh` now share `Commencement.OwnRead.rules/1`. This reaches 33 round laws.
5. **Rules left by orders dropped from a list: fixed, by replacing them.** A re-read takes the list plus `Store.order_sources/1`. In the round this is 3 pairs, 36 rules. The 5,822 across the store wait for each family's re-read.
6. **Catalogue dry runs writing fixtures: fixed.** A dry run now writes under `data/reports/commencement-reader/dry-run/<name>/`, and only `--accept` writes fixtures.
7. **`Territory.only/1`: fixed.** A place named in two texts is one place.

**For todo 6, the re-read:**
- `--read-orders --family "Fire and OH&S"` covers the family's laws and their amending laws from orders held, and never searches. The preview: 68 laws, 283 orders, 3,236 rules, 23 orders changing.
- Seven by-order laws have no cached order list: asp 2005/5, and ukpga 1954/70, 1962/58, 1969/10, 1971/61, 1998/33 and 2021/24. Only `--read-orders --law` without `--held` would title-search for them.
- The preview's rule losses on the Railways Act 2005 orders (SI 2005/1909 95 → 81, 1444 58 → 56, 2812 49 → 47, SI 2006/266 16 → 15) are call 4's dropped repeal entries.

**Found, not fixed:** the same title cut sits in `change_collector.ex:286` (Register) and `amendment/read_law.ex:109` (Amending-law reader). Both are parked.

## Fixer call 6: order forms read wrongly or as nothing (2026-11-14)

Lean brief (Fable, 122k tokens, 9 minutes; stopped at the cap before the round re-score).

1. **"in so far as it relates to England and Wales [Scotland] and has not already been commenced": fixed.**
   - The fix is `Order.Territory.completing/1`.
   - SI 1992/2984 sch.8 and sch.9 now read E+W fully, and SI 1992/2990 reads S fully (1993-01-01).
2. **"the principal appointed day": fixed as a named day.**
   - It sits in the clauses of SI 1999/1750 and 1999/1756, so the fix is `LawStart.Clause.principal_appointed_day/2`.
   - It reads 1999-07-01 only for an instrument made from 1998-11-19 to 1999-07-01. The Wales Act 2017 has its own principal appointed day.
   - It is unit-tested only. SI 1999/1746, 1747 and 1820 should gain too.
3. **Three "day appointed" forms: fixed.**
   - SSI 2013/51 and NISR 2010/328 are read as whole-Act statements.
   - NISR 1996/251's "Article 4(3)" now reads as reg.4(3) of the NI Order. An order's own Articles are dropped when it commences an Act.
4. **A fault this exposed, fixed:** `Order.named?/2` matched an Act's title as the tail of a longer one. "Police and Fire Reform (Scotland) Act 2012" was read as the Scotland Act 2012.

**Preview** (every held order/Act pair; 7,813 → 7,786 rules):
- 14 rules gained: six whole-law rules and 8 NI Order Article rules.
- 4 moved: class 1.
- 41 lost, all for the wrong Act: Scotland Act 2012 from three Police and Fire Reform orders, and Scotland Act 2016 from two Inquiries into Fatal Accidents orders.

**Tests:** `order_day_forms_test` (8) and `principal_appointed_day_test` (3); the affected files' 311 pass. The three readability issues were not hook failures, but are fixed.

**Found, not fixed (Commencement reader):**
- The cached order lists for the Scotland Acts 2012 and 2016 hold other Acts' orders. They stay wrong until those Acts are re-read; neither is in the round.
- `Leftovers`' named days lack "the principal appointed day".
- `own_articles/2` keeps capital "Article" refs for any instrument.

All three are noted for the catalogue review.

## The session's checks after the six calls (2026-11-14)

The reports are `after-calls-*.txt`.

- **Compile** with warnings as errors: clean. **`mix credo diff`:** no issues added.
- **`mix test`:** 84 failures, all held catalogue examples: 65 own-clause and 19 order. These are call 3's 82, plus 2 order examples from calls 4–6.
- **The round's fresh check:** our faults 0; 1 leftover not named, SI 1988/1729, whose `known:` status is written at todo 5.
  - The rows: 21,360 dated, 3,416 by order, 1,233 staged, 16 unread and 3 partly by order. Against call 3: dated +1,399 and by order −1,396.
  - Most of that is asp 2012/8 (1,215 rows), whose rest SSI 2013/51 now dates 2013-04-01.
  - It differs from the feed in 70 rows, e.g. s.2(1)(b) at 2013-04-01 against the feed's 2013-01-01. The earlier orders, SSI 2012/253, 2012/333 and 2013/47, are read only at the re-read: their rules were stored under the Scotland Act 2012.
- **Environmental Protection, Occupational and Maritime Safety:** each PASS.
- **Found:** NISI 2006/1254 differs from the feed in 44 rows, e.g. reg.50 at 2006-07-01 against the feed's 2010-11-15. NISR 2006/257's sub-items under Schedule 4 name another Order's Articles (the 1984 Order's 49A to 52), and are read as the 2006 Order's own. Call 6's fixer was resumed to take it (cap about 50k).
- **NISR 2006/257, fixed** (call 6's fixer resumed, 9k tokens):
  - The new `@other_order_articles` in `Order.drop_other_laws/2` drops another Order's Articles. One test.
  - 2 rules go, both on NISI 2006/1254. Its reg.49A to reg.52 are left to NISR 2010/328, at 2010-11-15.
  - The round's fresh check again (`after-calls-fresh-fire-and-oh-s-2.txt`): NISI 2006/1254 no longer differs from the feed. Row outcomes are unchanged; our faults 0; 1 not named (SI 1988/1729).

## Catalogues, dry run (todo 5, 2026-11-14)

Both catalogues were run once on today's code (`fire-and-ohs-catalogue-own.txt`, `fire-and-ohs-catalogue-orders.txt`), and once at the last commit's code in a separate worktree. At the last commit's code every held expectation passes (1,579 of 1,579), so every move below comes from this step's fixes, not from moved inputs.

**My review of the moves found two misreadings, both sent back:**
- Unqualified items were lost beside a "so far as relating to" item when the day is unread (1984 c.12 s.110(4); 1986 c.44; 1986 c.63 s.57(1)). Fixed by call 2's fixer, resumed: `Provisions.beside/2`, with 2 tests.
- 2002 c.21 s.61's lost "Apart from section 54(1) and (2)" is an artefact of the stored example, whose rows hold s.54 whole. Read from the law itself, the exception is kept.

After the follow-up, the fresh checks give the round FAIL (our faults 0, 1 not named: SI 1988/1729, its `known:` written with the accept). Environmental Protection, Occupational and Maritime Safety each PASS.

**Held moves: 86** (67 own-clause, 19 order). Each one, with its sentence, held reading and new reading, is in `backend/data/reports/commencement-reader/fire-and-ohs-held-moves.txt`.
- **Own clause (67):**
  - A qualifier binds only its own item, so the unqualified items read fully (about 30; e.g. 1996 c.53 s.148: s.126–s.145 fully, s.147 in relation to).
  - Schedule Parts and Chapters are named (e.g. 2000 c.37 pt.I.ch.II; 1998 c.31 sch.11.pt.I and pt.III).
  - Days read where they were unread before: by order, "the transfer date", "at the same time as" (e.g. 1971 c.78; 1989 c.15; SI 2006/641 reg.15; SI 2010/490).
  - Unread items are kept by name rather than dropped (e.g. 1982 c.39 s.151, sch.20; 2018 c.12).
  - Second dates and parts are read: 1962 c.58 rest by order; 1954 c.70 s.172 and s.190; 1969 c.10 Part II for E+W and S; SI 2001/3208 regs 3–12 on 2002-05-01.
  - A by-order clause for one country is by order for that country (2006 c.28, 2008 c.23, 2010 c.29, 2014 c.12, 2022 c.30).
- **Order (19):**
  - Devolved orders on their own legislature's Acts carry no territory (8).
  - A table's or heading's place name is no territory (2, e.g. SI 1972/1763 "in Northern Ireland").
  - Completing forms read fully (SI 1992/2984 E+W; SI 2009/3318).
  - Refs cleaned or added (s.98(c) gone; s.140 and sch.7.para.21 added; NISR 2006/257 its own Articles).
  - SI 2010/2169 now reads s.36 and s.76A(2), on its run-on date.

**Leftover groups:** with the accept, the groups that no longer arise are dropped, and SI 1988/1729 is named `known:`. The dry run shows 15 own-clause and 8 order groups with no status; each is reviewed and given `fix:` or `known:` before `LeftoversReviewTest` passes.

### Decision 4: accept the 86 held moves

- **Question.** Should the catalogues' held expectations take the 86 new readings? The alternative is to hold some back for more work in this step.
- **Aim.** `binds-on-date` and `law-text-wins`: each held reading should match the law's own words. These examples are the reader's ratchet.
- **Options:**
  - **(a) Accept all 86 (recommended).** Each was reviewed against its sentence, and each moves toward the law's words. The one artefact, 2002 c.21, is the stored example's rows, not the reader.
  - **(b) Accept all but named ones,** which are held back for another fixer round.
  - **(c) Review them one by one** with Jason before any accept.
- **Recommendation: (a).** Then `--accept` both catalogues, status the leftover groups, and run the catalogue tests and `LeftoversReviewTest`.
- **Decided (Jason 2026-11-14): (a), accept all 86.**

**Accepted (Decision 4 a), 2026-11-14:**
- `--accept` for both catalogues added 36 own-clause and 13 order patterns. It also re-chose the examples, so the held readings that moved became 70 own-clause and 25 order.
  - 18 of the reviewed 86 left the example set.
  - 21 examples joined it, all pending at the last commit. Each was reviewed: they are forms that read nothing before and now read as their sentences say (e.g. NISR 2009/114, SSI 2015/109, SI 2004/2304, "at the same time as" days).
  - The pattern of 1971 c.10 s.40(2), still unread, was kept `pending` rather than auto-accepted.
- Written by `backend/data/reports/commencement-reader/held-write.exs` (a dry run, then `write`). `CommencementPatternsTest` and `OrderPatternsTest` pass (1,630).
- `leftovers.json`:
  - 24 new groups got a status (16 own-clause, 8 order), most in the class form of their old keys.
  - SI 1988/1729 is `known:`.
  - `LeftoversReviewTest` passes.
- The round's fresh check: **PASS** (our faults 0, leftovers not named 0).

## Re-read and rebuild (todo 6, 2026-11-14, Jason's go)

The reports are `fire-and-ohs-reread-*.txt`, `fire-and-ohs-build.txt` and `fire-and-ohs-after-*.txt`.

- **Restore point:** `2026-11-14-commencement-reader-fire-and-ohs`, of `commencement_rules`, `provision_changes`, `provision_change_claims` and `lat_events`.
- **Own clauses:** 139 laws read, 274 rules, 0 errors.
- **Orders:** `--read-orders --family`, 68 laws and 283 orders, 3,232 rules. No searches.
  - SI 2015/1637 `--held`: 0 rules, so its 70 wrong rules are gone.
  - The 7 by-order laws with no cached list were not title-searched.
- **Amending laws:** the derived 319, `--workers 1`, 1,068 rules, 0 errors.
- **Rebuild:** 139 laws in 62 s; 29,281 → 31,774 changes; 46 laws move. The largest moves are all this step's classes:
  - asp 2012/8 +882: its orders are read under the right Act, and its rest by SSI 2013/51;
  - FRSA 2004 +827: staged, partly from 2004-10-01 and fully from 2004-11-10;
  - NISI 2006/1254 +528: NISR 2006/257 and 2010/328;
  - 1969 c.10 −266: Part II by order, undated;
  - laws with no rules before now hold their commencement changes (e.g. SI 2024/1278 0 → 23).
- **Commencement checks** on the stored rules: the round PASS (our faults 0, leftovers not named 0; 21,360 dated, 3,416 by order, 1,233 staged, 16 unread). Environmental Protection, Occupational and Maritime Safety PASS.
- **Gap-filler:** `rules_not_held` 106 → 50, `no_amending_law` 579 → 262, appointed 181 → 142.

## Pass (todo 7, 2026-11-14)

- **Repeatability:** seed 71, run twice: `cmp` identical, outputs the same (`fire-and-ohs-seed71.json`).
- **Golden:** 27/27.
- **`mix test`:** 11,114 passed, 0 failures.
- **The round's commencement check** on stored rules: PASS.
- **Step close** (`fire-and-ohs-step-close.txt`): FAIL.
  - Feed reader, Markup reader and Commencement reader: PASS.
  - Sources: 3 failing. The backlog documents SI 2017/399 (body and schedules) and SI 2018/227 (body) are stale, for FRSA 2004. They need only a fetch, so the next step's first todo sweeps them (RULES `sources-fetch-failures-swept-each-step`).
  - Checked rows: 22, unchanged. 20 are HSWA 1974 rows. HSWA is Occupational's, not the round's, so neither its changes nor the Railways Act 2005's orders were re-read or rebuilt. Calls 4's fixes reach it only once the Railways Act orders are re-read and HSWA is rebuilt.
  - Stale laws: 139.
    - All 139 are stale on `labels_version`, the Label fold's version, refreshed at Store and build.
    - 55 are stale on the extent reader, and 28 on the extent reader's changes (the Extent reader, next).
    - 56 are stale on the Commencement reader. All 56 come from one law, FRSA 2004: SI 2004/2304's and WSI 2004/2917's `feed_commencement` rules (483) are on the older reader version. Only `mix lat.commencement --effects` writes those rules, and it runs over every amending Act and may fetch feeds.

### Decision 5: the HSWA checked rows and FRSA 2004's feed rules

- **Question.** Should two narrow writes happen now, so the pass rule's checked rows and the Commencement reader's stale reason can be met?
  1. `--read-orders --law UK_ukpga_2005_14 --held` and a rebuild of HSWA 1974 alone (Occupational, switched), then the checked rows again.
  2. A `--law` option for `--effects` (a small task change, with a test), run for FRSA 2004 with the store only (no fetch), then the round rebuilt.
- **Aim.** `binds-on-date`. HSWA's dates and FRSA's are this step's fixes, and the pass rule asks that they show.
- **Options:**
  - **(a) Both now (recommended).** The restore point of today covers these tables. Occupational's labels stay one reading behind until Store and build (Decision 5 b of the Feed reader), but its changes for HSWA are rebuilt.
  - **(b) Only 1.** FRSA's stale feed rules are parked with Store and build.
  - **(c) Neither.** Both are parked: the checked rows with Store and build, and the stale rules with the Commencement reader's next pass.
- **Decided (Jason 2026-11-14): (a), both now.**

**Decision 5 (a), carried out:**
1. **HSWA:** `--read-orders --law UK_ukpga_2005_14 --held` (5 orders, 199 rules), then HSWA rebuilt alone (3,152 changes). Checked rows: 22 → 3 changed. 19 of the 20 HSWA rows now match.
   - Left: HSWA s.64 and the 2 CLP rows.
   - s.64's held label has `in_force_from` 1974-07-31. Its label now has none: the Act is "all by order", and no order of HSWA's six held orders names s.64; SI 1974/1439's text doesn't mention it either.
   - That follows the decided by-order rule. It was among the 22 before this step, and no change of this step moved it.
   - Parked with the Label fold, with the CLP rows (the label's start from existence evidence).
2. **FRSA:** `mix lat.commencement --effects --law A,B` was added. It reads those Acts' feeds from the store only and writes a law at a time (`effects_scope/1`, `effects_writes/2`; 4 tests in `test/mix/tasks/lat_commencement_effects_scope_test.exs`).
   - A first version put a list filter in `Commencement.Store`. That changed the commencement read version, which would have staled every rule just re-read, so it was reverted. The version is unchanged (`c326c4afb198`).
   - Run for FRSA 2004: 483 rules, 0 feed errors; all 488 of its rules are on the current version. Round rebuilt: 31,774 changes.
3. **Step close again** (`fire-and-ohs-step-close-2.txt`):
   - Sources: 3 (fetch only, for the Extent reader's sweep).
   - Checked rows: 3 (parked with the Label fold).
   - Stale laws: 139.
     - All 139 on `labels_version` (Store and build).
     - 55 on the extent reader, and 28 on its changes (Extent reader).
     - 56 still on the Commencement reader. The cause is not FRSA: it is the rules of 129 source laws the round's changes cite, on the older reader version (`fire-and-ohs-stale-sources.txt`).
       - 116 hold own-clause rules: most are laws with LAT rows in other families (e.g. ERRA 2013 c.32, SI 2008/960), which `HeldAmenders` leaves to their own `--read`.
       - 40 hold feed rules (e.g. 2013 c.32's by SI 2014/251).
       - 2 hold order rules.

### Decision 6: the 129 source laws' stale rules

- **Question.** Should the 129 source laws' rules be re-read now, so the round's Commencement reader stale count reaches 0?
  - `--read --law` the laws with own-clause rules;
  - `--effects --law` the 40 with feed rules (store only);
  - `--read-orders --held` for the 2 with order rules;
  - then the round rebuilt.

  This writes rules for laws of other families, including the switched ones. Their labels are untouched until their builds.
- **Aim.** `binds-on-date`: the round's dates should come from the current reader.
- **Options:**
  - **(a) Re-read them now (recommended).** A few minutes, no fetches, covered by today's restore point.
  - **(b) Park them,** with the Commencement reader's next pass of each family (the 5,822-rule class).
- **Decided (Jason 2026-11-14): (a), re-read now.**

**Decision 6 (a), carried out** (no fetches):
- **Own clauses:** 88 LAT laws `--read` (566 rules), and 28 more `--read-amending --law` (49 rules).
- **Feed rules:** 40 Acts `--effects --law`, from the store (19,975 rules across 351 instruments, 0 feed errors).
- **Orders:** 1972 c.71 and HSWA `--read-orders --held` (11 orders, 127 rules).
- **Rebuilds:** the round (31,774 changes) and HSWA again.

**Step close, final** (`fire-and-ohs-step-close-3.txt`): FAIL, with every failure owned elsewhere.
- Feed reader, Markup reader and Commencement reader: PASS.
- Sources: 3. The FRSA 2004 backlog, SI 2017/399 and SI 2018/227, need only a fetch; the Extent reader's first todo sweeps them.
- Checked rows: 3 changed. HSWA s.64 and CLP Arts 53a and 53b, parked with the Label fold.
- Stale laws: 139.
  - All 139 on `labels_version`: the Label fold's version, refreshed at Store and build.
  - 83 also on the extent reader's readings: the Extent reader, next.
  - **0 on the Commencement reader.**

## Close (todo 8, 2026-11-14)

**Which docs did this session change?**
- `RULES.md`: seven rules, from `a-qualifier-binds-its-own-item` to `a-step-re-reads-its-sources-rules`, and a Known limits row.
- `WORKFLOW.md`: the round's Commencement reader notes.
- `COMMENCEMENT-GUIDE.md`: §3.2, §3.3 and §3.5, the forms read.
- The `commencement-reader-check` skill: its history.

**The parked bugs:**
- 22 fixed, and 2 moved (the label half of the staged start, and EU "shall enter into force").
- Left parked with a reason:
  - the shared namer (no effect while schedules are unparsed);
  - SI 2006/1244 (round 0, 93 Maritime labels);
  - the amending law's start misread (Maritime);
  - the two changes dated before their law was made (known limits);
  - the schedule through its introducer (NISR 2003/152) and SOCPA's bare numbers;
  - undated insertions whose orders are read: 22 of the round's 30 dated by call 6, the rest whole-Schedule pointers.
- New entries for the parking list's items are in the frontmatter.

**Code:** a9af8e41, with hooks.
