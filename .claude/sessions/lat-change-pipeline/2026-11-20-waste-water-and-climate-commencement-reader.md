---
session: 'Waste, Water and Climate: Commencement reader'
status: suspended
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

# Session: Waste, Water and Climate: Commencement reader (SUSPENDED)

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
- ⏸️ Code review (deferred, Jason 2026-11-21: to its own session straight after this one closes, which Jason starts; architecture and speed. Its standard `.claude/review-standards/code.md` is kept and committed with this step) — as first planned (Jason 2026-11-20, this session only: not a standing part of the step): after the fix calls, before Settle, the `reviewer` agent (Fable) reviews the commencement reader's code. The focus is architecture and speed; it also reports correctness, tests, Credo and the module rules. Its standard is a new `code` standard in `.claude/review-standards/`. The review is saved to `backend/data/code-reviews/`, and each finding is triaged Taken or Contested here; the findings Taken are fixed before the re-read.
- ✅ Settle (2026-11-21: Decision 6, 61 accepted; 54 own and 5 order readings written; SI 2018/1251 pending; 36 leftover groups `check:` open for the resume): catalogues again (and at the last commit's code); held moves reviewed, to Jason; written with held-write.exs
- ⬜ Rebuild then fetch: restore point; re-read (own, held orders, amending `--workers 1`, sources' stale rules); orders not held to Jason; one round rebuild; Sources gate; NAS sync
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

## Measure (todo 1)

Reports: `backend/data/reports/commencement-reader/waste-water-and-climate-{sources-0,0,0-fresh}.txt`; gate `gate-waste-water-and-climate-2026-11-20.txt`.

- **Sources:** PASS (4,532 needs, failures 0). No sweep fetch needed.
- **Stored rules:** 109,705 rows in 565 laws; our faults 33,572 (no_rules 33,401 in 295 laws never read; not_reached 171 in 5); leftovers not named 38.
- **Fresh:** our faults 1,670:
  - no_rules 929 in 3 laws: NI Orders 1973/69 (477) and 1981/158 (439), and SSI 2005/351 (13);
  - not_reached 741 in 14 laws (the largest: SI 2012/2079 230, SI 1974/607 131, SI 2017/462 121, SI 2005/1726 89).
- **Fresh dating:** 84,380 dated, 15,736 left to orders. Against the feed: 1,622 differ, 24,610 agree.
- **Leftovers reaching the round:** 43 in all; 26 `fix:`, 5 `known:`, 12 unreviewed. The largest: SI 1978/954 art.3 (reach 910), SI 2012/2079 reg.1(3A) and (4) (700), SI 2010/2169 art.3 (699).
- **EU entry into force:** `SentencePatterns.@cif` is read by `MakingLaws` (`making_laws.ex:140,167`), so the fix moves Making laws decisions (the stop): sized at Fix, to Jason first.

## Find (todo 2)

Dry runs into `data/reports/commencement-reader/dry-run/wwc-1/` at HEAD code (reports `waste-water-and-climate-catalogue-{orders,own}.txt`, `leftovers[-orders]-2026-11-20.txt`).
- **Orders:** 1,129 orders, 6,760 statements, unclassified 0; 210 patterns, 30 new; held moved 0; 62 leftover groups, 20 with no status.
- **Own clauses:** 3,804 laws, 10,174 sentences, unclassified 0; 821 patterns, 22 new; **11 held examples read differently at HEAD code** (the store moved since the last accept: for Settle); 200 leftover groups, 14 with no status.
- **Classes and calls:** `backend/data/reports/commencement-reader/waste-water-and-climate-classes.md`, with five calls:
  1. own clauses, a date left or a row not reached;
  2. own clauses, a provision, qualifier, exception or relative day left (with the `no_rules` NI Orders);
  3. orders;
  4. amending-law dating;
  5. golden, lists, the namer; EU entry into force sized.

## Fix (todo 3)

### Call 1: own clauses, a date left or a row not reached

First pass (Fable, about 138k tokens, 17 min). Round fresh: our faults 1,670 → 1,210; leftovers not named 38 → 32.
- **Fixed, test first:**
  - the rest clause after "and" (`Statements.split`: SI 2005/1726, 1974/607, 2005/1638, SSI 2004/358);
  - the verbless rest ("and the remainder on 1st October 1988": SI 1988/1048);
  - a commencement order's "The following provisions of the 2014 Act come into force …—" read as its own articles (`Provisions.other_law_list?/1`: SI 2015/773, 2013/1966, 2017/462, 2017/58). Their 270 rows are now `no_clause`; about 99 were dated before, from the other Act's section numbers. That was wrong, so the change is right by design.
  - the check's own error: an unreached signature row is `not_a_provision` (`Check.rows`).
- **Held examples moved: 17.** Two gain a rest rule; fifteen "The following provisions of the … Act" heads now read none (`call1/moves.txt` in the scratchpad). They go to Settle.
- **Sent back** for the "or, if later" form, the two Royal-Assent-relative forms and SI 2000/2911's Scheme paragraphs.
- **Decided in the session:** an expiry date ("shall cease to have effect on …": SI 2001/1623, 2003/3341, 2001/1478) is not a commencement leftover. An end is a repeal fact, which the feed carries as "expires". The fix is in `Leftovers`.

Second pass (Fable, about 171k tokens in all for call 1). Round fresh: our faults 1,210 (all call 2's); leftovers not named 29.
- **Fixed, test first:**
  - "or, if later" takes the later day, or is unread if either day is (SI 2018/797);
  - "beginning with day on which" with no "the" (2012 c.21 s.122(2));
  - a purpose before the day (2011 c.19 s.38(1));
  - expiry dates are not leftovers.
- **Held moved:** 2 more (19 in all).
- **SI 2000/2911**, a Scheme's paragraphs: the only such law; 39 rows `staged_start_only`. The fix is not narrow (five patterns across `Provisions` and `Statements`), so it is a known-limit candidate for Settle.
- **Expiry in the feed:**
  - SI 2003/3341: yes, stored as repealed;
  - SI 2001/1623 and 2001/1478: no. Parked as `own-expiry-not-carried`.
- **Call 2 also takes** 2011 c.19 s.38(3) ("at the end of the period of 2 months beginning with that day").
- The session checks: the four switched families' fresh checks at HEAD and with call 1's code, and the full suite (`wwc-switched-{head,call1}-*.txt`).
- **Session checks after call 1:**
  - The four switched families' fresh checks give identical rows at HEAD and with call 1's code. Fire and OH&S, Occupational and Maritime PASS.
  - Environmental Protection has our faults 0 and leftovers not named 2 → 1: the expiry went, and WSI 2001/1506 reg.1(2) is left. It has no status and is new at HEAD too, so the store moved; it goes to call 2b.
  - `mix test`: 11,985/12,004; the 19 failures are all `CommencementPatternsTest` held examples.

### Call 2 (split)

- **2a:** the fresh faults (NI 1973/69, NI 1981/158, SSI 2005/351, 1973 c.37, SI 2012/2079) and the eight largest leftovers.
- **2b:** the smaller leftovers, the amending ones, WSI 2001/1506, 2011 c.19 s.38(3), and the parked own-clause forms.

**Call 2a, first pass** (Fable, about 144k tokens). Round fresh: our faults 1,210 → 52; leftovers not named 29.
- **The no-clause laws:** NI 1973/69, NI 1981/158 and SSI 2005/351 state no commencement of their own (the revised text omits it, or the order commences another Act). The check now counts a law whose only rules are `schedule_effect` as `no_clause` (`Check.no_clause?/2`), which is right by design.
- **SI 2012/2079:** the aside no longer swallows Parts 5–7 as exceptions; "for all remaining purposes, on …" is read; "so far as is necessary for …, on 1st October 2012" is read as partial. Part 8 is staged 2012-10-01, then 2013-01-28; the feed holds the first date only. The law's text wins.
- **Held moved:** one more, 2004 c.33 s.263(10)(b). It is still misread: the qualifier reaches s.261(1) and Sch.27. Sent back.
- **Sent back too:**
  - 1973 c.37 s.39(1): the rest after a following-list comes in at Royal Assent (Interpretation Act 1978 s.4(b)), measured over the round and the switched families;
  - three of the check's own errors in `Leftovers`: a council order's commencement, another Act's, a mention.
- **Moved to call 2b:** the remaining large leftovers.

**Call 2a, second pass** (call 2a in all: Fable, about 207k tokens, 47 min). Round fresh: **our faults 0**; leftovers not named 29 → 25.
- **2004 c.33 s.263(10)(b):** a qualifier mid-subject reaches only the items after it. The "except so far as relating to …" item form is fixed with it: 1975 c.59, 2021 c.30 and 2022 c.30 move, toward their words.
- **1973 c.37 s.39(1):** an Act's dated "the following provisions of this Act" list gives the rest Royal Assent (Interpretation Act 1978 s.4(b)). The rule is limited to a calendar date. 56 rows move, all in 1973 c.37; a whole-LAT scan finds the form in that law only.
- **The check's own errors in `Leftovers`:** an order made under the law, another Act's provisions, and a "within which … come into force" mention (`Clause.mention?`).
- **Held moved:** 5 more (24 in all).
- **Reach outside the step:** `AmendingLaw.SweepForm` (the Extent reader) calls `Clause.mention?`, so such a sentence there is now `noise:commencement`. Checked by the full suite and the extent catalogue test; named in the code review.
- **Not measured by the fixer:** held amending Acts with a dated following-list. That is left for the re-read's reach.
- **Session checks after call 2a:**
  - The switched families' rows are identical to HEAD, and all four PASS. Environmental Protection's WSI 2001/1506 went, possibly from call 2b's first edits, which overlapped the run.
  - `mix test`: 25 failures, all held examples. Call 2b had begun, so this count is not clean; it is re-run after the calls.

**Call 2b** (Fable, about 160k tokens, 32 min). Round fresh: our faults 0; leftovers not named 25 → 16. Environmental Protection PASS.
- **Reader, test first:**
  - "it receives Royal Assent" (NIA 2022/31 s.64);
  - "that day" in a list head, sought back through items (2011 c.19 s.38(2), (3));
  - a named provision then "all other regulations" (SI 2010/740: reg.9 2015-01-01, the rest 2010-04-06);
  - a no-break space inside a date;
  - "Except for regulation 2(3) and (4), these Regulations …" (SI 2025/407).
- **The check's own errors:**
  - an end date without "on" (WSI 2001/1506);
  - provisions describing an event's day (SI 1994/3308, SSI 2000/236, SI 1997/1115);
  - provisions named in a partial rule's purpose words (SI 2012/2079 reg.1(3A), (4));
  - "may not appoint a day for …" (asp 2014/14 s.104(4)).
- **Held moved:** 1 more, 2011 c.19 "… at the end of the period of 2 months beginning with that day—", now 2012-01-03.
- **Known-limit candidates:**
  - SI 2025/287 reg.1(2), counted from the laying day (limit C, as SI 2018/1221);
  - 1968 c.47 s.60(2), whose appointed day is carried by s.61(2)'s by-order rule (call 2c confirms);
  - SI 2000/2911.
- **Lookup (the session):** 1987 c.26 is in the register with no made or enactment date, so its s.340(2) period cannot be dated. That is the Register's (parked).
- **Call 2c** takes the six reader forms it stopped on:
  - the rest within a container (SSI 2020/154, NISR 2008/231);
  - the whole law staged by purpose (SI 2015/776, 1991/346);
  - "Except section 53 …, this Part" (asp 2013/5);
  - "that is to say" lists (1963 c.33 s.94(2));
  - SI 2024/1366's conditional heads.
- **Call 2d** takes the parked own-clause forms.

**Call 2c** (Fable, about 126k tokens, 18 min). Round fresh: our faults 0; leftovers not named 16 → 14. Environmental Protection PASS.
- **Fixed, test first:**
  - the rest within a container ("the remaining provisions of Part 5": SSI 2020/154; "The remainder of regulation 11": NISR 2008/231);
  - "11(1) (a) and (5)" broken at the space;
  - "for the purposes only of" as a qualifier;
  - an item after an "insofar as" item kept (NISR 2008/231 reg.1(6)).
- **The feed yardstick:**
  - SSI 2020/154 differ 172 → 231. The law as amended puts Parts 2, 7, 8 and the rest of Part 5 on 1 October 2027, while the feed holds 2025-10-01. The law wins.
  - NISR 2008/231 differ 53 → 10.
- **Held moved:** 2 more (27 in all):
  - SSI 2020/154 reg.1(5), as intended;
  - SI 2010/231 reg.1(3), "unread" → "none", a side effect of the "only" qualifier. Sent to 2d.
- **Call 2d** takes forms 2–5, NISR 2008/231 reg.1(6)'s "Sub-paragraph (a) of paragraph (1) of regulation 9", and the SI 2010/231 side effect.

**Call 2d** (Fable, about 180k tokens, 25 min). Round fresh: our faults 0; leftovers not named 14 → 8. Environmental Protection PASS.
- **Fixed, test first:**
  - the whole law staged by purpose (new `LawStart.PurposeStages`: SI 2015/776, 1991/346 "may he cited"). The provision the purpose names is partial on the first day and the law full on the second, as SI 2004/1261;
  - a leading "Except section 53 (and schedule 4), this Part" (asp 2013/5);
  - "that is to say" lists (1963 c.33 s.94(2));
  - making-day heads (new `LawStart.MadeCondition`: SI 2024/1366, "at the end of 31st December 2024" = 2025-01-01);
  - "Sub-paragraph (a) of paragraph (1) of regulation 9" (NISR 2008/231);
  - described provisions unread again (SI 2010/231).
- **Round rows:** dated +125, staged +6, staged_start_only −131 (SI 2015/776); no losses. Feed differ 1,845 → 1,839.
- **Held:** 29 failing. SI 2010/231 is back; 3 new, all intended (1963 c.33 s.94(2), SI 2015/776, SI 2017/1312 reg.3 → reg.3(2)).
- **Confirmed:** 1968 c.47 s.60(2) adds no rule, since s.61(2) carries the Act by order. A `known:` candidate.
- **Left:** SI 1978/954 and SI 2010/2169 ×3 (orders, call 3); the known-limit candidates 1968 c.47, SI 2025/287 and SI 2000/2911; 1987 c.26 (the Register).
- **Call 2e** takes the parked own-clause forms, plus two found here: SI 2017/1312 reg.1(3)'s qualifier put on reg.4, not reg.3(3); and 1988 c.33 s.171(6) "subsection (2) of that section" read as s.171(2), not s.170(2).

**Decision (Jason, 2026-11-20): a whole law brought in for a purpose is partly in force.** In "This Order comes into force— (i) for the purposes of article 18(1), one month after the day on which it is made; (ii) for all other purposes, on 5th October 2015" (SI 2015/776 art.1(c)), the subject is the Order. Article 18(1) only names the purpose. So the whole law is partly in force on the first day and fully in force on the second, when "for all other purposes" completes it. The same holds for SI 1991/346 reg.1(1) and SI 2004/1261. This corrects call 2d's reading, which marked only the named provision partial; call 2e fixes it test first. Rule for RULES.md: `whole-law-purpose-is-partial`.
- **Session checks after call 2d:**
  - The switched families' rows are identical to HEAD except Environmental Protection's SI 2017/1312 differ row (now reg.3(3), as intended). All four PASS.
  - Compile clean; Credo diff adds no issues.
  - `mix test`: 34 failures, 29 of them held examples. The other 5 were architecture tests: call 2d's new `PurposeStages` and `MadeCondition` were in no version's patterns. The session added them to `FoldVersion`, `CommencementCatalogue.Version`, `MarkupPatterns.Version` and `FeedPatterns.Version`; architecture 23/23.
  - The law_start files are in `FoldVersion`, so this step's code stales the switched families' fold (RULES Decision 10's batch: one apply refolds them). For Rebuild.

**Decision refined (Jason, 2026-11-20, provisionally agreed): the partial label is a provision's; the law's label is a read-through.** A purpose limits a provision to that purpose at first, then to all purposes. So "partly in force" always sits on a provision. The law as a whole is partly in force while any of its provisions is, read through its provisions' labels on the date picked. It is never a rule written to every provision.
- **Narrow purpose first** (SI 2015/776 art.1(c), SI 1991/346 reg.1(1)): the subject is the whole law, so every provision is partly in force from the first day and fully from the last.
- **"All other purposes" first, the waiting purpose naming provisions** (SI 2004/1261: "for the purposes of regulation 4 as it gives effect to paragraphs 50(a) and 54(8) of Schedule 1, on 1st May 2007; … for all other purposes, on 1st May 2004"): every provision is wholly in force from the first day, except the provisions named, which are partly in force from the first day and fully from the last.
- RULES.md: `purpose-partial-is-the-provisions` (replaces `whole-law-purpose-is-partial`). A law-level read-through is not this step's work: parked as a question for the Label fold.

**Call 2e** (Fable, about 158k tokens, 37 min). Round fresh: our faults 0; leftovers not named 8.
- **Fixed, test first:**
  - the whole law staged by purpose (SI 2015/776, SI 1991/346, SI 2020/1095: 320 round rows dated → staged);
  - a qualifier written before its item (SI 2017/1312 reg.1(3): EP's 15 rows staged → dated, the feed row agrees);
  - "subsection (2) of that section" as the section last named (new `LawStart.ThatProvision`: 1988 c.33 s.171(6)).
- **Held:** 30 failing (1988 c.33 s.171(6) new).
- **Not started:** the eight parked forms (item 4), for call 2f.
- **SI 2004/1261** reads the whole law partial, which the refined decision corrects. Call 2f fixes it.
- **Found** (this step's), for call 2f:
  - 1988 c.33 s.171(6)'s "Schedule 3 to the Criminal Justice Act 1967" read as the Act's own Sch.3;
  - SI 2017/1312 reg.1(4)'s "In relation to an offence under regulation 3(2)" puts reg.3(2) in scope;
  - SOCPA s.178(1)'s whole list read partial.

**Call 2f** (Fable, about 127k tokens, 25 min). Round fresh: our faults 0; leftovers not named 8. Environmental Protection and Fire and OH&S PASS.
- **Fixed, test first:**
  - SI 2004/1261 under the refined decision: the named provisions are partial 2004 → full 2007, and the rest are full 2004;
  - another Act's Schedule named by title and year is dropped (1988 c.33 s.171(6));
  - a lead-in "In relation to an offence under regulation 3(2)," is not part of the subject (SI 2017/1312 reg.1(4)).
- **Held:** 4 more, all scope-only and toward the words, no date lost (34 in all): SI 2017/1312 reg.1(4), 1984 c.54 s.157(3), SI 2019/1440 reg.1(2B), asc 2023/4 s.56(3).
- **Call 2g** takes asc 2023/4 s.56(3)'s "Part 2" (Schedule 2's, not the Act's), SOCPA s.178(1), and the seven parked forms.

**Call 2g** (Fable, about 132k tokens). Round fresh: identical to 2f (our faults 0, leftovers not named 8). Fire and OH&S PASS. Environmental Protection PASS, with 6 rows from left-to-orders to dated (4 are CNEA s.85, now given the Act's general rule).
- **Fixed, test first:**
  - a Schedule-headed list's bare items (asc 2023/4 s.56(3));
  - a bracketed "(and section 117(6) so far as relates to it)" kept to its item (SOCPA s.178(1));
  - "This section has effect … from the day on which it is established" (LGA 1985 s.84(3), unread);
  - a provisions list read as list items, with an exception ending at ", and in Part 7 …" (CNEA s.108(2)).
- **Already handled:** 2017 c.29 s.124(3) (`left_to_orders` needs two or more countries).
- **Held:** 3 more (37 in all), toward the words: 1994 c.21 s.68(6)(f), 2008 c.23 s.44(5)(a), SI 2012/3039 reg.1(3)(c).
- **Found:**
  - SI 2012/3039 reg.1(3)(b) drops reg.18;
  - CNEA s.108(2)(h)'s "in Part 4 of Schedule 5" is unread;
  - SOCPA s.178(1)'s law-level `clause_staged` rule from a following-list.

## Decision 1: more own-clause calls, or move on

**The question.** The round's own-clause work is done: our faults 1,670 → 0, and leftovers not named 38 → 8. Of those 8:
- 4 are orders (call 3's);
- 3 are known-limit candidates (SI 2000/2911, 1968 c.47 s.60(2), SI 2025/287);
- 1 is the Register's (1987 c.26).

Seven own-clause calls (2a–2g, about 1.1M Fable tokens) have cleared the parked forms one by one, and each call finds two or three new one-statement forms. Most are in laws outside the round, or in held examples with no round rows. Left:
- 4 parked forms (SI 2010/490's heading "in Wales"; a qualifier over several items, 1996 c.52 s.232(2); 1971 c.10 s.40(2) "on the transfer date"; NISR 2003/152's Schedule via reg.15(2));
- 3 found by call 2g.

**The aim.** `binds-on-date`. None of the seven reaches a round row today. Each would move only a few rows in other families, and those rows would be seen at those families' next pass.

**Options.**
- (a) **Move on (recommended).** Stop the own-clause calls here. Size and park the seven with this step: each is one statement, its reach named. Go on to the orders (call 3, the round's 4 order leftovers and the parked order bugs), amending-law dating (call 4) and the golden cases (call 5). Each remaining group touches round rows or golden.
- (b) **One more own-clause call** for the seven, then move on. About 150k tokens and 30 min. It will likely find two or three more forms, to be parked then.
- (c) **Continue until no new form is found.** Unbounded; the pattern so far gives no sign it converges.

**Recommendation:** (a). The step's own pass needs the round's leftovers named and its faults 0, and both are in hand for own clauses. The orders, amending-law dating and golden groups bear on the round's labels, and the seven don't.

**Decision 1 (Jason, 2026-11-20): run to zero new patterns by a misread scan in code, then fix by class.**
- **Why.** Fable found the new forms by reading one law at a time: a by-product of fixing, never converging (seven calls, about 1.1M tokens). The leftovers check finds words no rule uses, but nearly every new form was words used wrongly, which no code looks for:
  - another Act's provisions read as the law's own;
  - a qualifier reaching too far;
  - a Schedule's "Part 2" read as the Act's.
- **Plan:**
  1. **The scan (one fixer call, about 150k tokens).** `Commencement.Misreads`, with tests, beside `Leftovers`, run in both catalogues: the 10,174 own-clause statements and the 6,760 order statements. It flags rules whose scope:
     - holds a ref the sentence gives to another law ("of the … Act", "to the … Regulations", "of that Act");
     - holds a ref the law has no row for;
     - has a qualifier reaching items before it, or past a list item's end;
     - comes from a container-headed list ("of Schedule 2") but lands on the law's own Parts.

     Groups are by shape, ranked by the round rows they reach, and each is reviewed `fix:` / `known:` / `check:` in a fixture, with a test that fails on a group with no status (as `LeftoversReviewTest`). The seven own-clause forms already found are its first groups.
  2. **Fix by class.** Each fixer call takes one shape group with every instance the scan lists, so it does not open laws to discover them.
  3. **The cheap parts go to cheaper agents:** `summariser` (Haiku) turns the scan's output into the group list; the session reviews each group against one sentence; Fable writes the fixes only.
  4. **Zero new patterns, in code:** every misread group and every leftover group has a status, and a re-run finds no group without one.
- **Then** calls 3–5 (orders, amending-law dating, golden), with the orders' scope errors taken through the scan's groups.
- **The seven forms open:**
  - SI 2010/490 (the heading's "in Wales");
  - 1996 c.52 s.232(2) (a qualifier over several items);
  - 1971 c.10 s.40(2) ("on the transfer date");
  - NISR 2003/152 (a Schedule via reg.15(2));
  - SI 2012/3039 reg.1(3)(b) (reg.18 dropped);
  - CNEA s.108(2)(h) (the Part 4 of Schedule 5 repeals);
  - SOCPA s.178(1) (a law-level `clause_staged` rule from a following-list).
- **Session checks after call 2g:** all four switched families PASS (EP's moves are SI 2017/1312's and CNEA's); `mix test` has 37 failures, all held examples; Credo adds no issues.
- **The scan call** started 2026-11-20 (Fable, cap about 150k): `Commencement.Misreads`, its review fixtures and test, wired into both catalogues, with sample runs only. The session runs the full catalogue.
- **The scan call's result** (about 172k): `Commencement.Misreads` (`commencement/review/misreads.ex`, outside the reader versions; pure) flags six kinds: another law's ref, a ref with no row, a qualifier reaching too far, a container's list landing outside it, and two the seeds needed: a whole-law rule from a list of provisions, and a list item no rule holds. Both catalogues print "misreads by shape" and write `misread_groups.json`; `MisreadsReviewTest` fails on a group with no status. All five seeds are found. Sample: own 12 groups (17 statements); orders 24 groups (123), 113 of them `no_row` (likely repealed provisions with no row, not misreads). Blind spots: order list items (an order is one unit), Chapter containers, scoped laws' `no_row`, "it" qualifiers. The full catalogues run next, into scratch.
- **Full catalogues with the scan** (scratch `scratchpad/fullscan/`): own 49 misread groups (111 statements), orders 24 (122). `mix test` 39 failures: the 37 held examples and `MisreadsReviewTest` ×2 (no `misread_groups.json` held yet). Credo adds no issues.
- **Group review, first pass** (each against its sentence):
  - **whole_law is no misread in effect:** of 133 laws with a whole-law `clause_staged` rule, no row is dated by it alone (evaluator over every law's fresh own rules, `scratchpad/scan/all_rule_reach.exs`): a more specific rule wins every row; the rule marks the law's start (LR-33 P1). The SOCPA seed goes from `fix:` to `known:`.
  - **Real, by class:** a closing qualifier read over earlier items (SI 2004/759 art.8 ss.118, 119; 1996 c.52 s.232(2); 2022 c.30 s.170(4)(b); 2012 c.9 s.120(5)); another law's provisions in a qualifier read as own (SI 2007/2472 "sections 3 and 3A of that Act", the 1988 Act); bare items after a parenthesis named a level short (SI 1992/3253 s.118(n) for s.118(1)(n)); repeals-only items held whole (CNEA s.108(1)–(4)); list items dropped (2022 c.30 s.170(4)(a), 2001 c.10 s.43(6), SI 2025/662, SI 2012/3039).
  - **False flags, the scan's precision:** `no_row` mostly repealed provisions (OSRPA 1963's first-aid sections); `container` from a qualifier's "relates to the following provisions of Schedule 22" (SSI 2003/206); `other_law` "the 2023 Act" in an order for that Act (SI 2024/452); "that Act" pointing back to another law named earlier is read as own (SI 2007/2472).
  - **Next:** one fixer call sharpens the scan (the false flags above); a full run; then the group statuses and the fixes by class.
- **item_dropped is the scan's strongest class, misdated rows hidden from the check:** SI 2025/662 reg.1(2) lists provisions for 1 October 2025, each with a bracketed description ("regulation 4(c) (amendment of regulation 17A of the 2008 Regulations: …)"). Only regs.18 and 20 are read. Regs.4(c), 6(2), 7(2)–(11), 13(1), 15(a) and 16 fall to reg.1(3)'s "Otherwise … 2nd July 2025", three months early. "Our faults 0" cannot see this, because the row is dated, just wrongly. The same form: 2022 c.30 s.170(4)(a) (s.32(3) and s.42 "so far as relating to section 91ZD of that Act") and SI 2003/2635 reg.1(2) (Parts by territory, read only as a law-level rule). This is the first fix class after the scan's precision call. A further false flag went to that call: a bracketed qualifier "(and Article 65 so far as relating thereto)" not counted as the ref's own (NISI 2003/419).
- **The scan's precision call** (about 114k). Orders: 24 → 17 groups (28 statements). 292 not-held refs are counted, not grouped. Own: 49 → 42 groups (99 statements). Held readings are unmoved (the same 38 ids). Two corrections to the brief:
  - SI 2024/452 is a true misread: a two-Act order gives every provision to both Acts (`Order.rules/2`).
  - WSI 2006/345's container flag was false (a regex backtracked "Schedule 11" to "Schedule 1").
  - New, true: other-law refs in order list items (5 checked, all true); misnamed SI 2010/2317 s.136(e) and SI 2005/2714 s.100(2)(iii).
  - Still unseen: another law's provision named with no "of <law>" (WSI 2006/345 art.6(2)(d)); a two-Act order's mirror; orders' item-level qualifier and drop checks.
- **Fix by class, order:** (3a) list items dropped (15 instances, call started); (3b) a qualifier's reach (points back, repeals only, territory, no mark of its own); (3c) another law's provisions (order list items, two-Act orders, own clauses). Statuses are set after the fixes, on the groups left.
- **Call 3a, list items dropped** (Fable, about 180k). Cause: `Provisions.weighted_refs/4` read no refs for any item naming another law anywhere. An item's own words are now read first: description brackets dropped, cut at the qualifier (new `LawStart.ItemSubject`). 9 of 15 instances fixed, test first (10 tests).
  - **Moves:** SI 2025/662 17 rows 2025-07-02 → 2025-10-01, and reg.13(1) staged; SI 2022/159 reg.2 2022-04-01 → 2022-03-15; 2016 c.12 s.33 and 1998 c.23 s.1 now partly from a date; SI 2026/15's 43 rows from not reached to partial from 2026-02-18; SI 2012/3039 reg.18 now partial only, like its siblings.
  - **Held:** 3 more readings move (40 in all): 1998 c.23, 1999 c.30, SI 2026/15.
  - **Judged false:** SI 2019/145 (an application statement) and SI 2017/701 ("to enable—" purposes).
  - **Open, one-law forms:** SI 2003/2635 (Parts by territory), 1985 c.73 s.60(3) (the law's typo "may be order appoint"), SI 2000/3251 ("for the purposes of the following provisions, namely–"), SI 1996/1974.
  - **Found:** SI 2026/15 reg.1(3) "In so far as they are not already in force" is unread, so no full date; 2001 c.10 s.43(6) holds sch.27 of the 1996 Act and "subsection (4)"; SI 2017/701 reg.1(3), (4) "to enable—" stages read as full.
  - **Tooling:** `lat.commencement_patterns --laws --out` still overwrites the dated `misreads-` and `leftovers-` reports; the full scan run restores them.
- **Session checks after 3a:** all four switched families PASS; round fresh unchanged (our faults 0, leftovers not named 8); `mix test` 40 held + 2 review failures only; Credo adds no issues. **Call 3b** (a qualifier's reach: points back, repeals only, no mark of its own) started.
- **Call 3b, a qualifier's reach** (Fable, about 132k). Forms 1 and 2 fixed, test first (10 tests):
  - **Causes:** a one-row list with a closing "so far as they …" kept as one item (new `LawStart.PointingBack`); a bracket naming several subsections taken as one; an order's last item after the Act's name with no comma (`LastItemLimit`); a Part named for its repeals only read as plain.
  - **Moves:**
    - partial → full: 1996 c.52 s.232(2) ss.81, 82, 85, 94, 95, 221 and sch.18 paras 27–29; 2012 c.9 s.120(5) s.113, sch.9.pt.12 and sch.10.pt.10;
    - full → partial: CNEA s.108(3), (4) sch.5 Parts; 2009 c.25 s.182(2), (3) sch.23 pt.2 and pt.3;
    - SI 2004/759 art.8: by the unit test only.
  - **Held:** 4 more readings move (44 in all).
  - **Judged false:** 2022 c.30 s.170(4)(b) (the head's "in relation to Wales" reaches every item); 2008 c.25 s.173(3).
  - **Left:** form 3 (11 instances, not read); CNEA s.108(1)/(2) Parts carry no purposes limit; 2007 c.28 s.245(2)'s completing form; 2009 c.25 s.182(1)(j), (4)(g).
  - **Found** (Commencement reader):
    - Schedule paragraphs dropped from lists: 1996 c.52 sch.18 paras 24, 26; 2022 c.30 s.170(4)(b)(viii), (ix); 2008 c.25 sch.1 paras;
    - 2009 c.25 s.182(1)(i) "Part 1 and paragraphs 26 and 47 of Schedule 22" read as the Act's Part 1.
- **Session checks after 3b:** four switched families PASS; round fresh unchanged; the 4 new held moves are the 4 intended (44 in all); Credo adds no issues. **Call 3c** (another law's provisions: two-Act orders, order list items, own clauses) started. Fable on the scan and fixes so far this round: about 730k (scan 172k, precision 114k, 3a 180k, 3b 132k, plus 3c).
- **Call 3c, another law's provisions (orders)** (Fable, about 138k). Order scan: 16 → 5 groups (7 statements). 73 statements in 58 orders moved (`scratchpad/call3c/moves.txt`). New `Order.OtherLaw`.
  - **Causes:**
    - a two-Act order's statement head never asked which Act it names (SI 2024/452, 2022/816, 2025/1370);
    - capital "Section … of the X Act" missed;
    - "of that Act" never resolved;
    - the "of, and Schedule 5 to, the Police Act 1996" connectors;
    - another law's Part;
    - the own Act by its short title.
  - **Held:** 5 `OrderPatternsTest` readings move.
  - **Regression:** SI 1994/3262 art.3(2), a transitional "shall have effect as if … after the amendments … have come into force", now gives a rule. SI 1990/431 Sch.1 gains two refs from transitional text. Both sent back to the same call to close.
  - **Left:**
    - all own-clause instances: 2010 c.29, 1988 c.33, SI 2022/500, 2001 c.10, 2008 c.25, 2009 c.25;
    - orders: SI 2023/362 "58Z4", SI 2010/2169 s.76A(2), SI 2012/57;
    - WSI 2006/345 art.6(2)(d);
    - a table row naming its own Act by title treated as another law (unmeasured).
- **Call 3c follow-up** (about 8k more, 146k in all): the regression is closed at the statement test. A head whose only "come into force" is in the perfect tense ("have come into force") states no commencement (`Order.already_in_force?/1`). The only line moved over every held order is SI 1994/3262 art.3(2). Open: SI 1990/431 Sch.1 (the table reader reads transitional text as rows; the row was misread before); SI 1994/3262's Schedule goes from 36 to 35 rules with the same refs, not yet looked at. Checks and both full catalogues are running.
- **Session checks after 3c** (full catalogues, scratch `fullscan3/`):
  - four switched families PASS; round fresh unchanged (our faults 0, not named 8);
  - held: 44 own and 5 order readings move, all intended; Credo adds no issues.
  - **Misreads left:**
    - own: 32 groups (89 statements), of which 11 groups (about 65 statements) are `whole_law` alone, given one `known:` status;
    - orders: 5 groups (7 statements); not held, counted: 274 order refs and 5 own.
  - **Leftover groups with no status:** own 10, orders 20 (moved by the fixes; reviewed at Settle).
  - **New catalogue patterns:** own 31, orders 30 (accepted at Settle).
  - **Call 3d** (the own-clause groups left; each fixed, known or false) started. Fable so far on the scan and fixes: about 744k.
- **Call 3d, first part** (Fable, about 102k): no code changed. Each true statement is one law's wording across the whole store (5,813 bodies scanned).
  - **Known-limit candidates:**
    - 2022 c.30 s.170(4)(b)(viii), (ix): no row effect;
    - 1985 c.73 s.60(3): dayless items dropped and all dated by (d), no LAT rows; the law's typo "may be order appoint";
    - SI 1996/1974 reg.1(2): a nested "as to—" list;
    - SI 2000/3251 reg.1(2): "for the purposes of the following provisions, namely–";
    - 2004 c.33 s.263(8)(e): "listed in subsection (9)";
    - SI 2017/701 reg.1(2)–(6): "to enable—" stages inverted.
  - **False flags:** CNEA s.108(3), (4) (the rules are right; the scan misses "the repeal(s) to" as a limit); SI 2019/145; SI 2017/701 reg.1(3) items.
  - My "already known" list was read as done; the same call was resumed to take it (the 12 "no mark of its own" instances, own-clause other-law refs, CNEA s.108(1)/(2), 2007 c.28 s.245(2), SI 2026/15 reg.1(3), SI 2003/2635), with the two scan precision faults.
- **Call 3d, second part** (Fable; about 252k in all for 3d).
  - **Causes fixed, test first (4 test files):**
    - the completing form "so far as not [already] in force" limits nothing (new `LawStart.Completing`);
    - a territory read only after dropping bracketed headings (`OwnClause`);
    - other-law Parts and Chapters, the curly apostrophe, "of and Schedule N to the … Act", "to the 2020 Act";
    - a mentioned subsection's lead-in names no provision.
  - **Scan precision:** "the repeal(s) to" and "provisions of … which" are an item's own mark; points-back takes only purpose-partial rules.
  - **Fixed instances:** 1986 c.63, SI 2010/490, 2026 c.18 s.175, 2010 c.29, 1988 c.33 refs, SI 2022/500, 2001 c.10, 2007 c.28 s.245(2), SI 2026/15 reg.1(3).
  - **False flags:** 2008 c.29, asc 2024/3, 1999 c.30, SI 2011/2581, SI 2020/1419.
  - **True, not fixed:** asc 2021/1 s.175(1) and SI 2013/1675 reg.1(2) (nested rows under a dash-ended item read flat: 3 laws); SI 2015/63 (one law); CNEA s.108(1)/(2); SI 2003/2635.
  - **Reach:** 86 of 1,383 candidate laws move; 7 have LAT rows: 2009 c.23, 2010 c.29, 2019 c.3, 2023 c.52, SI 2007/605, SI 2010/724, SI 2026/15.
  - **Held:** 9 more readings move (53 in all).
  - **The session's read of the doubtful moves:**
    - the 55-plus SIs moved are commencement orders through the own-clause path, losing other Acts' Schedules, all with no LAT rows;
    - 2022 c.7 s.131(2) loses an unread head rule, its items still dated.
  - **SI 2007/605's 6 `not_reached` (reg.15)** are on its stored rules too, so they are not new (Road Safety, outside the round): park.
- **Session checks after 3d** (scratch `fullscan4/`):
  - four switched families PASS; round fresh unchanged (our faults 0, not named 8);
  - held: 53 own and 5 order readings move, the 9 new ones the intended; Credo adds no issues.
- **Misreads left:** own 20 groups (76 statements), orders 5 (7).
- **Every group now has a status** (scratch `fullscan4/{own,orders}/misreads-reviewed.json`, written to the fixtures at Settle):
  - `known:` whole-law rule (13 groups);
  - `known:` one law's wording (3: SI 2003/2635, 1985 c.73, SI 1996/1974; SI 2000/3251; 2004 c.33 s.263(8)(e));
  - `false:` SI 2019/145, SI 2017/701;
  - `fix:` 6 classes: nested dash rows; CNEA s.108(1); bare items after a parenthesis (orders); "58Z4"; SI 2010/2169 s.76A(2); SI 2012/57's range.
- **Call 3e** (the six fix classes, hard cap 150k) started. Park after 3e: SI 2007/605 reg.15 (6 rows `not_reached` on stored rules, Road Safety); SI 2017/701 reg.1(2)–(6) "to enable—" stages inverted.
- **Call 3e** (Fable, about 117k). The four order classes are fixed, test first (8 tests); the order scan is now **0 misread groups**. Own classes 5 and 6 (nested dash rows; CNEA s.108(1)) were not started.
  - **Causes:**
    - `bare_bracket` glued a bare bracket after a qualified item onto the section number;
    - roman sub-items had no level rule (new `Order.Sibling`);
    - a bracket range did not carry its end forward;
    - the number form missed "58Z4" (`\d+(?:[A-Z]+\d*)*`);
    - an unspaced date ("1stSeptember2010") hid the qualifier after it;
    - a colon inside a heading bracket was taken as a list opener;
    - "including italic headings" sat between a range and "of the 2000 Act".
  - **Moves:** 19 statements over every held order (rules 11,432 → 11,429), no regression found. Judged from the refs only: SI 2004/2528, SI 1997/1712, SSI 2001/81, SI 2005/950.
  - **Held:** 2 more order readings move (SI 2010/2169).
  - **New leftover:** SI 2010/2169 art.3(3) s.76A(2), now unused words, which needs a `known:` entry.
  - **Found:**
    - SI 2012/57 "in sections 34(3), 35(3) and 36(3) in the 2000 Act" is still held for the Localism Act;
    - SI 2012/1831 holds sections inserted into the 2006 Act for the 2012 Act.
  - Checks running.
- **Session checks after 3e:** four switched families PASS; round fresh our faults 0, **leftovers not named 8 → 7**; held moves 53 own and 7 order (the 2 new are SI 2010/2169's, intended); Credo adds no issues. **Call 3f** (nested dash rows: SI 2013/1675, a round law with 288 rows, asc 2021/1, 1988 c.33; and CNEA s.108(1)/(2), 718 rows in Environmental Protection; hard cap 120k) started. Fable on the scan and fixes so far: about 1.23M.
- **Call 3f** (Fable, about 126k): both classes fixed, test first (13 tests). New `LawStart.NestedItems`: a provision opened for its parts, an exception opened, or a qualifier opened, each read under the item that opens it. `mentioned_item` keeps an item's partly refs apart (CNEA's sch.5 Parts get per-country partly rules, by order).
  - **Held:** 1 more reading moves (PMCA 1994 s.94(3)(a), toward the words).
  - **Session review of the unreviewed moves:** 2012 c.9 s.120(3) is right (only "(c) section 53 and Schedule 3" stands alone); SI 2008/172 and SI 2018/652 and SI 2026/169 are orders through the own-clause path, so no row effect.
  - **Regression:** 1994 c.21 s.68(6)(f) "Part I of Schedule 11 to this Act and subsection (8) of section 67 so far as it relates to that Part of that Schedule" is now dropped. Sent back to the same call (cap 50k), with asc 2021/1 s.175(2)'s new unread rules to check, and the checks the call did not run.
- **Call 3f follow-up** (Fable, about 155k in all for 3f). The 1994 c.21 regression is closed.
  - **Cause:** `mentioned_item`'s split carried the partly refs only in `whole_subject`, and "subsection (N) of section M so far as …" was not a last-qualified form. Partly refs are now excepted from a general clause and get a Royal Assent rule `:in_relation_to`.
  - **Checks:** Environmental Protection PASS; SI 2013/1675 and CNEA PASS on their 1,006 rows.
  - **asc 2021/1 s.175(2):** a true read of an unread sentence, with noise refs (`pt.2` of Schedule 11, `s.129(6)` in quoted words). `NestedItems` doesn't open "in Schedule N—", which is left for the parking list.
  - Full checks and both catalogues running (scratch `fullscan5/`).
- **Session checks after 3f** (scratch `fullscan5/`):
  - Switched families: OH&S, Maritime and Environmental Protection PASS. **Fire and OH&S** has 1 leftover not named: asc 2021/1 s.175(2) "s.175(1)(f)", from the sentence 3f newly read.
  - Round fresh unchanged (our faults 0, not named 7). Compile clean.
  - Held: 1 more reading moves (PMCA, intended): 54 own and 7 order in all.
  - **Credo** failed at first, `/tmp` full: 89 `credo-diff` clones, 15 GB of RAM-backed tmpfs. Jason said yes to deleting them, and the re-run adds no issues.
  - Misreads: orders 0 groups; own 18 groups (76 statements). The one new group is asc 2021/1 s.175(2) (s.139–141, 149 "no qualifier of its own"), the same "in Schedule N—" form.
- **Parking list additions:**
  - Commencement reader: `nested-schedule-dash-items`. `NestedItems` doesn't open "in Schedule N—" (asc 2021/1 s.175(2): noise refs pt.2, s.129(6); Chapter 2 of Part 7 and the Schedule 1, 11 and 12 paragraphs missing). This is the Fire leftover's cause.
  - Tooling: `credo-diff-tmp-clones`, **fixed in-session at Jason's ask**: `scripts/maintenance/credo-diff.sh` gives credo a scratch TMPDIR and removes it, as the hook does (9ec6cd27). Session checks and the fixer agent file use it.
- **Call 3g, "in Schedule N—" opener** (Fable, cap 80k; started before Jason's in-session rule, below):
  - **Fix:** `NestedItems` opens a Schedule. Bare paragraphs and Parts are that Schedule's; "in paragraph X, the words …" leaves that paragraph partly in. Under a section opener, "in subsection (3), the words …" gives `s.N(3)` partly. Quoted words are blanked. `ListItems.in_part/2` reads "provisions in Part 7 … (a) Chapter 2" as pt.7.ch.2. `Leftovers` reads "Subsection (1)(f) does not apply to" as a mention.
  - **Tests:** 9 (asc 2021/1 s.175(2)).
  - **Moves:** asc 2021/1 s.175(2) (toward the words); SI 2003/2938 reg.2, 3 and SI 2007/2709 reg.3 (orders through the own-clause path, no LAT rows).
  - **Checks:** Fire and OH&S PASS (leftovers not named 1 → 0); Environmental Protection PASS. No new held moves.
  - **Left, one law:** asc 2021/1 s.150(1)(a) and (b)(ii) sibling expansion; s.175(1) holds s.175(2) "subject to subsection (2)".
- **Jason 2026-11-20, on fixer routing:** "Couldn't you fix that small bug … Every big fix with the reader is routing to the Agent." From here, a fix of one form in one module whose code is in context is made by the session, test first. Fable takes classes. Also fixed in-session: the Credo clone leak (`scripts/maintenance/credo-diff.sh`; the fixer agent file uses it).
- **Call 4, amending-law dating** (group C, seven parked forms; Fable as a class, hard cap 150k, the plan's stop written in: a fix moving more than 2,000 changes is sized and comes to Jason) started.
- **Call 4, amending-law dating** (Fable, about 136k). Reach is 369 changes, under the 2,000 stop. All four switched families PASS. The round's gap tallies are unchanged (6,578 gaps); the fixes sit on dated changes and on first starts.
  - **Fixed, test first (8 tests):**
    - SI 2006/1244: the register's day was made the whole-law rule though it is reg.1(4)'s purpose-limited day; its 108 changes on MSA 1995 lose the full 2006-07-15 date and keep a partial stage, so the feed's 2008-11-21 dates them after the re-read;
    - a provision's deemed back-date ("shall be taken to have come into force on …") set an amending law's first start (`Rule.deemed?/1`, `AmenderStart.first_start`). 1997 c.28 1996-09-15 → 1997-03-19, plus 1980 c.65, 2014 c.26, 2023 c.55, 2023 c.30 and others; 63 of the 369 are otherwise undated.
  - **False here:** MSA s.255N by 2011 c.8 (both stages are carried; a missing partial change would be the Label fold's); the "in relation to" stage (it reads partial fresh).
  - **Not reached (cap):** Acts read as starting at Royal Assent (2025 c.36, 2006 c.36, 2015 c.15; 2011 c.8 is right); EA 1995 s.57/Sch.24's undated 692 rows; 2003 c.39 Sch.8 para.56's feed difference.

**Decision 2 for Jason: SI 2018/1221, a narrow purpose that names the provisions themselves.**
- **The question.** "These Regulations come into force— (a) for the purposes of regulations 1, 2 and 3 on the 22nd day after the day on which these Regulations are laid, and (b) for all other purposes, on exit day." Reg.3 is headed "Amendments which take effect before exit day". Under `purpose-partial-is-the-provisions` (narrow purpose first: the subject is the whole law), every provision is partly in force from day 22 and fully from exit day. So reg.3's amendments read partial until exit day. Read literally, "for the purposes of regulation 3" is all of reg.3's purposes, so reg.3 is fully in force from day 22.
- **The aim:** `binds-on-date`. On a date between day 22 and exit day, do reg.3's amendments bind?
- **Options:**
  - (a) keep the decided rule as is: all partial from day 22, full on exit day;
  - (b) refine it: where the narrow purpose is "the purposes of" provisions of the same law, those provisions are fully in force on the first day, and the rest partly in force from it (for those provisions' purposes) and fully from the last.
- **Recommendation: (b).** The words make regs 1–3 operate whole on day 22; the heading says so too. Partial would understate what binds. Under (b), SI 2015/776 stays as decided: art.18(1) is in force on its first day, the rest partly then fully.
- **Decided (Jason, 2026-11-21):** "1-3 fully 22nd day after being laid and the remaining not in force until exit day. All in force come exit day. Nothing is partly in force."
  - **Rule for RULES.md** (`purpose-of-own-provisions-is-a-list`): where a narrow purpose names the law's own provisions ("for the purposes of regulations 1, 2 and 3"), it reads as a list of provisions. Those provisions are fully in force on the first day; the rest are not in force until the last day. No provision is partly in force.
  - Where the purpose is not the law's own provisions (SI 2015/776 "for the purposes of article 18(1)"), `purpose-partial-is-the-provisions` stands.
  - Fixed in-session (one form, `LawStart.PurposeStages`), test first.
- **Decided further (Jason, 2026-11-21), on SI 2015/776, the same shape:** "18(1) is full in force one month after made and everything else 5th October. The Order overall would be partly in force until the 5th. Same pattern."
  - This **replaces the "narrow purpose first" branch** of `purpose-partial-is-the-provisions`. Where the narrow purpose names the law's own provisions, those are fully in force on the first day, and every other provision from the last day; none is partly in force.
  - The law reads partly in force between the two days as a read-through of its provisions' labels (the Label fold's question, parked).
  - A narrow purpose that names no provision of the law keeps the law partly in force until the last day.
  - Applies to SI 2015/776, SI 1991/346 and SI 2018/1221. One rule for RULES.md: `purpose-names-own-provisions`.
- **The decision, fixed in-session, test first:** `PurposeStages.settle/2` now reads a narrow purpose before the general day that names the law's own provisions as a named group, fully in force on its day. A narrow purpose naming none stays whole-law partial. `Leftovers.whole_law_purpose/2` reads "for the purpose of" as the list's lead.
  - **Tests:** SI 2015/776 and SI 1991/346 changed to the decision; new tests for SI 2018/1221 and a purpose naming no provision.
  - **Check:** SI 2015/776 and 1991/346 have 192 rows dated, none staged, PASS. Suites show only the known 63 failures; Credo adds no issues.
- **Found:** SI 2018/1221 reg.2(a)'s "22nd day after the day on which these Regulations are laid" is silently dropped (no rule, no unread record). The reader's input carries no laid day, though the CLML holds `<ukm:Laid Date="2018-11-28">`. This is the same class as SI 2025/287 (the step's laid-day known-limit candidate). It goes to Fable as a class (call 4b), with call 4's unreached forms.
- **Call 4b, a day relative to laying** (Fable, about 157k). Part 1 fixed, test first (14 tests).
  - **What changed:** new `LawStart.LaidDay` reads `ukm:Laid` (the later where several differ); new `LawStart.OwnDays` carries `made` and `laid` on every input path (own clause, `AmendingRead`, `OwnRead`, the catalogue input). The made-relative forms are read against the laid day too, plus "a period … beginning with the day after … laid". New treatment `:clause_laid_relative`.
  - **The general silent drop:** an undated list item is now an unread group with a reason (`:laid_day_not_held`, `:made_day_not_held`, `:day_unread`).
  - **Readings:** SI 2018/1221 regs 1–3 2018-12-20, the rest exit day, nothing partly; SI 2025/287 2025-04-01. Round leftovers not named 8 → 7. All four families PASS.
  - **Reach:** 436 changes moved (under the stop): SI 2019/1440, 2019/188, WSI 2019/414, SI 2019/74, 2023/994 and others.
  - **Part 2 not reached:** Acts read as starting at Royal Assent (2025 c.36, 2006 c.36, 2015 c.15); EA 1995 s.57/Sch.24; 2003 c.39 Sch.8 para.56.
- **Loss found by 4b, fixed in-session, test first:** SI 2019/74 reg.2 holds no (1), so its own paragraph (2) ("Any provision … has the same extent …") was taken as a third item under the dash. With 4b's unread groups that broke `PurposeStages.settle`, and the whole law read partial (23 changes). `Provisions.dash_items/2`: a numbered paragraph beside lettered items is no item of the list. SI 2019/74 now reads regs 1–3 fully 2019-02-11, the rest exit day. Suites show the known 63 only; Credo adds no issues. Full checks and both catalogues running (scratch `fullscan6/`).
- **Session checks after 4b and the SI 2019/74 fix** (scratch `fullscan6/`):
  - four switched families PASS; round fresh unchanged (our faults 0, not named 7);
  - full `mix test` 12,134/12,197, the 63 failures exactly the known held set (54 own, 7 order) plus `MisreadsReviewTest` ×2;
  - misreads: orders 0, own as reviewed, plus asc 2021/1 s.175(2)'s one-law leftover form.
  - **Call 4c** (the three amending-law forms 4b did not reach; hard cap 150k) started. Fable so far on the step's fix calls this round: about 1.75M.
- **Call 4c, stopped by the session** at Jason's word ("Fable limit at 75% The strategy burning too many tokens"). It had already fixed, test first (6 tests, `amending_provision_start_forms_test.exs`; `LawStart.Clause`, `Readers.NoteDate`):
  - 2025 c.36 s.159 "in accordance with regulations made by" leaves the day to regulations, with no Royal Assent rule;
  - EA 1995 Sch.22 para.25 and Sch.24: the paragraph dates the repeal beside the repeals Schedule.
  - **Its after-run:** round "provisions disagree" 86 → 5, dated via feed 1,228 → 1,315; Fire and OH&S and Environmental Protection PASS. The session runs the rest.
- **Decision 3 (Jason, 2026-11-21): token budget.** No more Fable fixer calls this step. Small fixes are done in-session; the rest are parked with size and reason. The code review runs on Sonnet, narrowed to architecture and speed over the modules this step added or changed most.
  - **Parked by this decision** (Commencement reader): Acts read as starting at Royal Assent (2006 c.36, 2015 c.15); 2003 c.39 Sch.8 para.56 and 2017 c.3 s.12(2) (law's date vs feed's); the namer dropping nested schedule ids (48 feed collisions, no body rows); `HeldAmenders` nil-op counts (39 laws).
  - **Still this step's:** the two extended-golden cases (OSRPA 1963 s.76/s.91; RTRA 1984 Welsh SI naming), in-session; the EU "shall enter into force" class sized by script, then to Jason.
- **Fable spent on the step's fix calls:** about 1.9M.
- **Golden, RTRA 1984 s.1A(b), s.1(6B), fixed in-session, test first** (`order_held_as_test.exs`, 3 tests).
  - **Cause:** legislation.gov.uk answered the request for `/uksi/2005/423` with the Welsh SI 2005/423, so the store holds the Welsh order under both names. Read as `UK_uksi_2005_423`, it doubled CROW 2000's 9 rules under a law that does not exist, and RTRA's golden case named it.
  - **Fix:** new `Commencement.Order.HeldAs.itself?/2` (the document's `ukm:DocumentMainType` must be its name's type). Both order-read loops in `lat.commencement` and the fresh check's order read give no rules for an order held as another instrument, so the re-read removes the old ones.
  - **Size, over every stored order:** 3 orders, 25 rules:
    - SI 2005/423 and SI 2006/1279 (CROW 2000 orders; their WSI copies are held and read, so nothing is lost);
    - SI 2002/2024 (Transport Act 2000 (Commencement No. 2) (Wales) Order: its 3 rules go until WSI 2002/2024 is fetched; **a fetch for Jason** at Rebuild then fetch).
  - The store's own double holding is Sources' (the client stores a redirected answer under the asked path): parked, Sources.
- **Golden, OSRPA 1963 s.76, s.91, fixed in-session, test first** (`order_schedule_exception_test.exs`, 2 tests).
  - **Cause:** SI 1964/191 art.1 brings in Schedule 1's Parts "Except in relation to the premises to which Article 2 of this Order applies" (covered market places). The Schedule's table rules took no limit from the article, so s.76 and s.91 read fully in force from 1964.
  - **Fix:** `Order.schedule_limit/2`. The articles bringing a Schedule in (or its Schedule, for a Part) with "Except/Save in relation to (as respects)" make its rules `:in_relation_to`, as `schedule_territory` carries a place.
  - **Reach:** of 93 orders with full Schedule rules stored, only SI 1964/191 (69 rules). The golden cases read stored rules, so they show the change after the orders' re-read.

**Decision 4 for Jason: EU "shall enter into force" as commencement words** (the plan's stop: a fix moving a Making laws decision).
- **The question.** `SentencePatterns.@cif` reads "comes/came/brought into force/operation", not EU law's "shall enter into force", "shall apply from". `MakingLaws` reads the same pattern, so the entry-into-force article counts as a requirement.
- **Size** (scratch `eu_cif.out`; `MakingLaws` unchanged since): of 71 EU laws decided making, 18 rest on that article alone (e.g. EUR 2008/740, 2014/1234, EUDN 2014/955). In 32 more it is one requirement among others. Adding the words would turn up to 18 EU laws from making to not making.
- **The aim:** `binds-on-date` for the law's start, plus the register's making flag, which is Making laws' step.
- **Options:**
  - (a) park it with Making laws, sized; this step leaves `@cif` as is. EU starts are dated by `LawStart.EU` (EUR-Lex dates), not by these words.
  - (b) widen `@cif` now and re-decide the 18 laws' making flag here.
- **Recommendation: (a).** The commencement reader dates EU law from EUR-Lex already. The words matter to the making decision, which is another step's (scope rule), and it needs that step's review of the 18 laws.
- **Decided (Jason, 2026-11-21):** "I don't follow the logic of deferral to another step. The commencement reader works to extract info from commencing text. Either this needs changing for the laws or doesn't." Sized over the 70 EU laws with rows: "shall enter into force" in 37; whole-law "It shall apply from <date>" in 11; staged "Article(s) N shall apply from" in 3 (EUR 2016/879, 2018/2066, 2019/2088).
  - **Go (Jason):** in-session, test first:
    - `@cif` reads "shall enter into force" and "shall apply from";
    - an EU law's start is its "apply from" date where stated;
    - "Articles N shall apply from …" dates those articles;
    - the up to 18 making decisions that follow are a dry-run list for Jason before anything is written.
  - **Rule for RULES.md:** `eu-applies-from-is-the-start`.
- **EU fix, in-session, test first** (`own_clause_eu_applies_from_test.exs`, 7 tests):
  - **`LawStart.EuWords`** (new, pure): "It/This Regulation shall apply from <day>" becomes "This Regulation shall come into force on <day>", and "Articles N shall apply from" becomes "… shall come into force on". "Shall enter into force" is left as written; quoted inserted words are never rewritten (EUR 2008/1272). Applied once in `LawStart.Input` to EU rows.
  - **`LawStart.Eu`:** a stated apply-from day is the start, before EUR-Lex (new catalogue treatment `:eu_applies_from`).
  - **`OwnClause.clause/4`:** an EU start's clause is read for its sentences.
  - **`Provisions.number_prefix/2`:** EU rows' "art.Article N" naming.
  - **Version files:** `eu_words.ex` after `eu.ex` (not `fold_version.ex`). `Order.HeldAs` is excluded from both stage versions (no build reaches it). Architecture 23/23.
- **Reach, EU laws with rows (70):** dated rows 1,021 (13 laws) → 4,388 (43 laws).
  - 22 laws are now dated by EUR-Lex entry into force where no rule was stored;
  - 9 by their apply-from day (EUR 2009/1005 2010-01-01, 2014/517 2015-01-01, 2018/2066 2021-01-01, 2019/2088 2021-03-10 …);
  - EUR 2016/879 staged (arts 1–2 2017, 3–4 2018).
  - EUR 2018/2067's "1 January 2019 or the date of entry into force …, whichever is the later" reads 1 January 2019.
  - EUR 2016/879 art.5 (its entry-into-force article) reads `not_reached`, not `eu_publication_relative`: 1 row.
- **Item (4), the making decisions (dry run, nothing written):** widening `SentencePatterns.@cif` (which `MakingLaws` reads) would flip 2 EU laws with rows (EUR 2019/1010, 2019/2088 SFDR) and 17 of the 18 entry-into-force-only laws to not making. That **fails 15 of Making laws' checked rows** ("is making (review)"), which are frozen for this step. So `SentencePatterns` is unchanged: the reader's fix needs only `EuWords`, which `MakingLaws` never reads.
  - **Found:** SFDR was making by accident. `MakingLaws` counted only its art.20 "shall apply from" as a requirement, never its "Financial market participants shall publish …" duties. Making laws' requirement reader misses EU duties (parked, Making laws, with the 19 laws' dry-run list in `scratchpad/eu_making_after.txt` and `eu_only_after.txt`).
- **Jason 2026-11-21, on Making laws:** "This step does one thing - reads commencement from text and saves the results. Does it do it correctly for these laws?" Answered in the reader's terms, with a table of EU forms. Making is not this step's question.
  - **SFDR:** its duty articles hold no words (". . . ."). They never became UK law (SFDR applied from 10 March 2021, after IP completion day), so Making laws' logic holds; no bug to raise.
  - **`SentencePatterns` stays unchanged:** the reading does not need it.
- **The EU fix's checks:**
  - Directives were pushed to `not_reached` by `EuWords` (Directive 2010/75 562 rows; 2014/28 184 rows in Fire and OH&S). Directives are now left out of the rewrite: they are never in force in the UK (`:eu_directive`).
  - EUR 2016/879 art.5, the entry-into-force article: an EU regulation's row no stated day reaches now reads `eu_publication_relative` (`OwnCommencement.class/4`), test first.
  - Fire and OH&S PASS; round fresh our faults 0, not named 7. Full `mix test` before these two fixes: only the known held set (61) and review tests failed; Credo adds no issues.

**Decision 5 (Jason, 2026-11-21): the feed comparison is a two-way gate in this step.** "any feed for any law, whatever the date, can be trusted … The diff is a great way to gate our Commencement reader - assuming our parser for the Feed is sound. So it cannot be a one way Gate - it might show problems in Feed reader wrt commencement." Then: "Choose 2. But, I want don't want to run more fix iterations until the pending architecture / speed session for the commencement reader is done."
- **Plan amended** (pass rule 1a): every `differ` and `feed_only` row is grouped by cause and each group named. Causes: ours (`fix:`), the Feed reader's (moved), legislation.gov.uk's or a yardstick difference (`known:`).
- **Order:** build the gate and run it once now, with no fixes. Then suspend this session for the review session, and resume for fixes, Settle, the rebuild and close.
- **The round today:** agree 25,395; differ 1,825; feed_only 11,082; feed_partial_only 685; own_only 59,013; neither 11,705.
- **The feed gate, built test first** (`feed_differences_test.exs`, 6 tests): new pure `Commencement.FeedDifferences` (`commencement/review/`, in no reader version).
  - **Shape** of each `differ`, `feed_only` and `feed_partial_only` row: our outcome, the rule that decides it, and which side is earlier (or whether the feed is partial).
  - **Groups** are ranked by rows, with three examples from different laws.
  - **`lat.commencement_check`** prints the groups with their status from `test/fixtures/commencement_check/feed_differences.json` (empty for now), and writes `data/reports/commencement-reader/feed-differences-<scope>-<date>.txt/.json`.
  - The feed side is the Feed reader's stored record (changes with a feed claim), so the gate tests both readers.
  - Architecture 23/23. The first run (round and four families) is running.
- **The feed gate's first run** (reports `data/reports/commencement-reader/feed-differences-<scope>-2026-11-21.txt`; rows marked `inserted` where a stored change inserted them):

  | Scope | Groups | Rows | Of them inserted |
  |---|---|---|---|
  | Waste, Water and Climate | 58 | 13,592 | 2,133 |
  | Environmental Protection | 35 | 3,370 | 482 |
  | Fire and OH&S | 12 | 2,006 | 502 |
  | OH&S: Occupational / Personal Safety | 9 | 176 | 27 |
  | Maritime Safety | 4 | 11 | 7 |

  - **Inserted provisions:** a yardstick difference. The feed dates the insertion (the Amending-law reader's), not the law's own commencement, e.g. NISI 1978/1049 reg.29A, 1991 c.56 s.2(2A)(e).
  - **Feed dates it, our reader leaves it to orders** (7,778 rows, 19 laws: asp 2009/12, asp 2003/3, anaw 2017/3, NISI 1978/1049 …): these laws have no order rules. Their order lists are missing (never searched) or their listed orders are not held. **Ours: orders to fetch**, at Rebuild then fetch.
  - **Unread clauses** (1,252 rows, 3 laws: MWA 2010/8, SI 2006/641, SI 2023/1394): ours.
  - **The rest** (`differ` own later/earlier, staged, partial): reviewed by group at resume, each named ours, the Feed reader's, legislation.gov.uk's or yardstick.

**Decision 6 for Jason: the 61 held readings that move** (`held-write.exs` dry run: 54 own, 7 orders; each re-read from its frozen inputs, so all are this step's code, none the store's; sheet `scratchpad/held-review.txt`). Each was read against its words:
- **Commencement orders through the own-clause path now hold none of another Act's provisions** (16: SSI 2009/319, SI 1993/3237, 1995/1983 ×2, 1996/186 ×2, 1999/3434, 1999/3440 ×2, 2004/827 ×2, 2006/1281, 2022/500, 2026/82, WSI 2024/207; and the order SI 2025/1370 ×2's 2025 Act provisions held for the 2023 Act). The order reader dates them.
- **Another law's provisions dropped:** 1984 c.54 sch.10 (RTRA's); 1988 c.33; SI 2019/1440's 2012 Regulations' Schedule paragraphs; SI 1976/731 pt.1 (the London Government Act's); SI 2021/1322 pt.1 (the 2006 Act's, a purpose); SI 2010/2169 ×2 (s.76A(2) of the 1991 Act; s.4 and s.36 for their purposes).
- **Excepted provisions no longer commenced:** 1975 c.59 s.14(5)'s Schedule 6 Parts III and IV; 1973 c.37 sch.8 ("except so far as relating to the amendments … made by Schedule 8"); 2008 c.23 ss.7, 17, 18, 31, 32; 2004 c.33 s.261(1), sch.27 full, s.261(4), sch.30 partial.
- **Items read that were dropped or unread:** asc 2026/7, 2004 c.5, 2009 c.23, 2011 c.19 ×2, 2012 c.21, 2015 c.11, 2020 c.21 (completing forms, made-relative days); 1998 c.23 s.1, 1999 c.30 s.88, SI 2026/15 regs 4–14, SI 2012/3039 reg.18 (items naming another law); SI 1988/1048, SI 2005/1726 (the rest after "and"); SI 2020/154 (named, not "rest"); NISR 2016/332 sch.3 ("of, and Schedule 3 to").
- **Qualifiers to their reach:** 1996 c.52 (points back); 2005 c.16 ×2 and 2009 c.25 (repeals only); 2007 c.28 (completing form); 2026 c.18 (completing form: full); PMCA 1994 s.3 and sch.1C; 2017/1312 ×2; 1986 c.63 and SI 2010/490 (no territory from a bracketed heading); 1994 c.21 s.67(8); asc 2023/4; 2021 c.30; 2022 c.30.
- **The decided purpose rule:** SI 2015/776, the law's earliest day.
- **One with a gap left:** 1963 c.33 s.94(2) "Parts II, III, and V to VIII other than sections 17(6), 48(2), 62(4), 66, 69, and 70". It now reads the Parts, not "rest", but excepts only ss.66 and 69. Toward the words: accept, and park the four sub-provision exceptions (Commencement reader).
- **Recommendation:** accept all 61 (`held-write.exs write` after `--accept`).
- **Decided (Jason, 2026-11-21): accept all 61.** Both catalogues are running with `--accept` (fixtures backed up to `scratchpad/fixtures-before-*`). Then `held-write.exs write`, after a second look at any examples that joined, and the misread statuses into `misreads.json`. Parked: 1963 c.33 s.94(2)'s sub-provision exceptions (ss.17(6), 48(2), 62(4), 70), Commencement reader.
- **Settle done (2026-11-21):**
  - both catalogues `--accept`ed (52 own and 31 order patterns new); `--accept` re-chose the examples, so the 18 that joined were reviewed again: 17 toward their words, and SI 2018/1251 reg.1(2) a misread, held `pending` with its correct reading;
  - `held-write.exs write`: 54 own and 5 order readings; a dry run after shows 0 moved;
  - `misreads.json`: all 18 own groups statused (`known:` whole-law rule and one-law wordings, `check:` the scan's false flags, `fix:` the seeds);
  - `leftovers.json`: the 36 groups the fixes moved are `check:` open, reviewed at resume (no fixes before the code review);
  - full `mix test` 12,357/12,359 before those statuses, the 2 failures the leftover review now passing.
  - **Commits:** 260644cf (code), 4cb506a1 (fixtures).
