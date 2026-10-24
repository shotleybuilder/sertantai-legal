---
session: 'CV-S04: Commencement Reader'
status: active
release: v0.1
bugs:
  - pattern: "An Act whose clause leaves it to orders read as in force on Royal Assent; its clause's sentences never read (LawStart decides the Act's start by ukm:EnactmentDate and its evidence is then metadata)"
    category: commencement reading
    module: Commencement.OwnClause / LawStart
    affected: "OH&S: HSWA 1974, OSRPA 1963, EMAS 1972, CMCHA 2007 (2,632 rows with 3 dated-in-words Acts)"
    fix: "OwnClause reads the clause behind a metadata start; an Act's general by-order/tied/unread clause is its rule; Royal Assent only with no clause (CV-S04)"
    status: fixed
  - pattern: "Dates in words not read (\"the first day of April, nineteen hundred and sixty-two\"): the clause unread, the Act falls back to Royal Assent"
    category: commencement reading
    module: LawStart.Clause.date_at_start
    affected: "OH&S: Factories Acts 1937, 1961; Occupiers' Liability Act 1957"
    fix: "date_in_words/1 (ordinal day, month, year in words)"
    status: fixed
  - pattern: "Register date (lrt_metadata) decides the rules over the law's own clause, and the clause's provision sentences are never read"
    category: commencement reading
    module: Commencement.OwnClause
    affected: "OH&S: NISR 1997/455 (69 rows a year early), NISR 2006/1 (130 rows), NISR 2007/31"
    fix: "the clause found decides the rules when dated; LawStart still decides the law's start record"
    status: fixed
  - pattern: "\"The preceding provisions … by order\" read as all the rest, provisions after the clause included"
    category: commencement reading
    module: Commencement.OwnClause
    affected: "CMCHA 2007 s.28, s.29; the 2003/20-like test"
    fix: "preceding/2 excludes the provisions after the clause"
    status: fixed
  - pattern: "Order forms not read: the whole Act named as the item (SI 1973/28, NISR 1998/235); \"Apart from the provisions mentioned in paragraph (2), the Act shall … come into force\" (SI 2008/401)"
    category: commencement reading
    module: Commencement.Order
    affected: "EMAS 1972, NI Order 1997/1774, CMCHA 2007 (main order)"
    fix: "Order.whole_act/2"
    status: fixed
  - pattern: "An order read as its own Act's order commences itself (NISR 2012/286 rule commences = itself)"
    category: commencement reading
    module: Commencement.Order.rules
    affected: "1 rule corpus-wide"
    fix: "an order never commences itself; the re-read replaces the rule"
    status: fixed
  - pattern: "Clause forms not read: \"except regulation 20(4) which shall come into operation on …\" in the general sentence; \"shall not come into operation [for X] until D\""
    category: commencement reading
    module: LawStart.Provisions
    affected: "corpus: 6 and 14 laws (OH&S: NISR 2007/31, NISR 2006/1)"
    fix: "except_which/5, not_until/6"
    status: fixed
  - pattern: "The vocabulary's own-commencement reader evaluated with no row structure or extent: a territorial commencement covering the provision read as partial; Parts/Chapters and ranges by order not reached"
    category: commencement reading
    module: Readers.OwnCommencement / ChangeVocabulary
    affected: "OH&S: NI Order 1997/1774 (32 rows)"
    fix: "own_context (OwnClause.context/1) and each provision's extent passed from the build"
    status: fixed
  - pattern: "Commencement orders never read for Acts resolved to Royal Assent (CR-07 read orders only for by-order laws), though found and held"
    category: commencement sources
    module: mix lat.commencement --read-orders
    affected: "HSWA 1974 (6 orders), OSRPA 1963 (3, not held), EMAS 1972, CMCHA 2007"
    fix: "re-read orders for the Acts now by order (applied 2026-10-23: HSWA 74 rules, OSRPA 72, CMCHA 4, EMAS 1, NI 1997/1774 1)"
    status: fixed
  - pattern: "HSWA 1974's commencement orders hold their dated lists in Schedules the store doesn't hold (body only)"
    category: commencement sources
    module: CLML store (orders' schedules)
    affected: "HSWA 1974: 6 orders; OSRPA 1963: 3 orders not held at all"
    fix: "fetched 9 orders' body + schedules (Jason 2026-10-23); HSWA Nos. 2-6 are PDF-only on legislation.gov.uk (no text): a known limit"
    status: fixed
  - pattern: "A qualifier on one item of a bare paragraph list read over the whole list"
    category: commencement reading
    module: Commencement.Order
    affected: "SI 1996/186 Sch. 22"
    fix: "bare_items/3: each item its own qualifier (round 2)"
    status: fixed
  - pattern: "An order whose Schedule is not held dates nothing it lists (SI 1997/3114); once held, its repeal-entries cell (\"In the Schedule—the entries relating to sections 11 to 14 … of … the Firearms (Amendment) Act 1997\") read as the Act's own s.11-14, sch.1, sch.2.para.13"
    category: commencement reading
    module: Commencement.Order (tables, line_items)
    affected: "SI 1997/3114 (Firearms (Amendment) (No. 2) Act 1997): 1 rule"
    fix: "a repeal-entries cell is read whole, the Schedule in relation to; \"In the Schedule\" unnumbered (9d9f2ab3)"
    status: fixed
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S04: Commencement Reader (ACTIVE)

## Problem

Step 4 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: When each provision came into force, from the law's own clauses and its commencement orders; and a change's date from its amending law's commencement.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ✅ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ OH&S family: 90 status-relevant text changes still undated (whole insertions and repeals), 342 undated in all (CV-07)
- ⬜ The gap-filler (NoteDate: the amending law's commencement at the provision the feed or note names) verified on a sample (CV-07, built `a50a00fc`)
- ✅ An order whose Schedule is not held dates nothing it lists (open bug: SI 1997/3114): its Schedule is held (fetched 2026-10-20) and read. Its repeal-entries cell was read as the Act's own provisions; fixed `9d9f2ab3`
- ✅ A qualifier on one item of a bare paragraph list read over the whole list (open bug, Commencement.Order): fixed in round 2 (`Order.bare_items/3`, SI 1996/186)
- ✅ Step 1 (Jason 2026-10-23: "agreed order and approach - dont skip"): fix B, A, C, K (+ the s.33(1)(a) and (b) sibling, the titled repeals line)
- ✅ Step 2: the commencement-sentence catalogue (every commencement sentence in held laws, classed by form × what the reader made of it, real examples as fixtures); fix by count (F–J, D, E and what it finds). Plus the orders catalogue
- ✅ Step 3: one corpus-wide own-clause re-read (restore point first), golden (+ the HSWA s.78 golden update, asked), the agent on a new seed (rounds 3–4, seed 7; option 1 fixes and the final rewrite: check PASS, golden 27/27)
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed: CV-S01 Sources, CV-S02 Feed reader (+ S02a, S02b), CV-S03 Markup reader (2026-10-23)

## What good looks like (agreed with Jason 2026-10-23: "Agree, start")

**The reader's one job:** turn the law's own commencement text (its clause, and the orders made under it) into dated `:commenced` changes on each provision, staged when it came in partly first. It also gives a change no other source dates the date its amending provision came into force (the gap-filler, `NoteDate`). The feed's coming-into-force records belong to the feed reader (CV-S02). They are a yardstick here, never a source. Which source wins is CV-S09's question.

**Scope:** the OH&S core family: its LAT rows and the commencement rules already held (`commencement_rules`, built in CR-00–09).

**Pass when all hold:**
1. **Every row accounted for:** dated (full, or partial then full); left to an order no rule dates (J6); or undated with a reason from a fixed set:
   - the clause is unread;
   - the rule is appointed and no order dates it;
   - the rule is `with` another provision;
   - an order's Schedule is not held.

   Our faults: a rule names the row (by ref, ancestor, container, range or rest) but nothing is dated; or the reader reads a clause with nothing to give. These must be 0.
2. **Every undated change accounted for** (CV-07: 342 undated, 90 of them status-relevant):
   - dated by the gap-filler;
   - or undated, with the reason: no pointer, the amending law's rules not held, the named provisions disagree, or the provision is appointed but undated.
3. **Checked by an agent:** 50 sampled rows, each date against the clause or order text in the stored CLML, including stage, partial, territory and purpose. Then 50 gap-filled changes, each date against the amending law's own commencement.
4. **Yardsticks (counted, not gates):** agreement with the feed's coming-into-force records where both exist, and with dates stated in notes. Disagreements are classed.
5. **Tested:** each rule in words, with a unit test.
6. **Repeatable:** same seed, same report.
7. **Golden** stays 27/27.

**Proposed approach:** as in CV-S02b and S03:
- first a catalogue of rule shapes over every held rule (treatment × `when` kind × scope kind × qualification × territory), each pattern with real examples as fixtures;
- then a `mix lat.commencement_check` (the gate, every row and undated change accounted for, the sample);
- then the agent on 50 + 50.

The two open bugs (SI 1997/3114 Schedule; the bare-list qualifier) are fixed in-session if the check reaches them.

## The check: `mix lat.commencement_check` (built 2026-10-23)

Read-only, ~3 s for 3 laws.
- **Rows:** `OwnCommencement.outcome/4` gives each row's outcome. Our faults: `not_reached` (text rules reach the row nowhere) and `no_rules`. Beside it sit the law's own feed record as a yardstick, and a count of rows the fuller context (Parts and Chapters, order, extent) would read differently.
- **Gaps:** `NoteDate.why/2` gives each change no other source dates: dated via the feed or note pointer, or undated with a reason (no amending law, no pointer, rules not held, no text rules, appointed, not reached, provisions disagree).
- **Sample:** stratified round-robin over outcomes (rows) and reasons (gaps), with each rule's words.
- **Tests:** `own_commencement_test.exs` (5) and `note_date_test.exs` `why/2` (4).

**Trial on 3 laws** (CMCHA 2007, SI 2015/21, HSWA 1974):
- CMCHA 2007: 308 `not_reached`. Its law-level rule reads as Royal Assent (`act_enactment`), but s.27 leaves the Act to orders. Only SI 2010/276 (s.10) and SI 2011/1867 (s.2(1)(d)) are held; the main order SI 2008/401 isn't.
- HSWA 1974: only `act_enactment` is held, and the Act was commenced by orders.
- **Finding:** `royal_assent_only` is ambiguous by construction. The CR-06 `act_enactment` treatment means "an Act whose clause states no date". Each Act needs one of two answers: either it really did start on Royal Assent, and the reader should then date its rows by it, or the clause was misread.

## Family run 1 (2026-10-23, stored rules, 6 s): FAIL, our faults 2,205

Rows (20,170):
- 14,192 dated;
- 2,632 `royal_assent_only` (8 Acts);
- 1,894 `no_rules` (REACH, CLP);
- 1,071 EU directives;
- 311 `not_reached` (CMCHA, NISR 2012/286).

Feed yardstick: 4,497 agree, 203 differ (4 laws). Gaps: 2,362 changes no other source dates (555 text changes), every one with a reason.

## Fixes (2026-10-23, dry run by `--fresh`, no writes)

The root fault in each fix:
- **Metadata decided the start and the clause was never read.** For an Act, `LawStart` takes Royal Assent over a by-order clause. For an SI, the register date beats the clause. In both cases the start's evidence is metadata, so `Provisions.groups` read no sentences. Fix: `OwnClause` now reads the clause behind a metadata start. A dated clause decides the rules over the register (the text is primary). An Act's general by-order, tied or unread clause is its rule, and Royal Assent stands only with no clause. The law-start record is unchanged.
- **Dates in words** (`Clause.date_in_words`).
- **"The preceding provisions"** now stops at the clause.
- **Order forms:** the whole Act named, and "Apart from the provisions mentioned in paragraph (2), the Act …". An order never commences itself.
- **Clause forms:** "except X which shall come into …", and "shall not come into operation … until D" (partly from the start, fully from D).
- **The reader's context:** the Parts, Chapters and order from `own_context`, and each provision's extent.
- `OwnCommencement` keeps Royal Assent (now only an Act with no clause: Interpretation Act 1978 s.4).
- The check classes EU publication-relative (REACH Art. 141 and CLP Art. 62 are omitted in the retained text; LR-33 P3 limit) and `no_clause` as known limits.

**Tests:** OwnClause +5, Order +3, LawStart +2, OwnCommencement 6, NoteDate why 4. One expectation was corrected: in the 2003/20-like test, s.121 comes after the clause.

**Dry run 6:** PASS on rows, our faults 0.
- dated 15,545, staged 579;
- by order 1,074 (HSWA and OSRPA, whose orders' Schedules aren't held; NI 1998/2795);
- EU directive 1,071, EU publication-relative 1,894, `no_clause` 3, partial only 4.

Feed yardstick: agree 4,955 (was 4,497), differ 5 (was 203):
- 3 rows a later insertion (SI 1992/3004 reg.3(5));
- CMCHA s.2(1), the open "commenced through some children" bug;
- NISR 1997/455 reg.15, where the feed dates the parent from reg.15(3).

Gaps are unchanged until the amending laws are re-read.

## Decisions (Jason 2026-10-23: "1 yes 2 yea 3 fetch the 9 docs")

1. **Apply** the re-read and the rebuild, after a restore point.
2. **Royal Assent dates an amending provision of an Act with no commencement clause** (Interpretation Act 1978 s.4). CR-06's "never" assumed Royal Assent also stood in for by-order Acts, which these fixes end. `AmendingLaw` (and so `NoteDate`) and `Feed` keep `act_enactment`. The legacy `Commencement.Amending` is unchanged, since CV-06 retires it.
3. **Fetch** the 9 orders (HSWA's 6, OSRPA's 3), body and schedules: 30 s. HSWA orders Nos. 2–6 are PDF-only, with no XML text.

## Apply (2026-10-23)

- **Restore point:** `restore-points/2026-10-23-cv-s04-before-reread` (`commencement_rules`, `provision_changes`, `provision_change_claims`, `lat_events`; 3 s).
- **(a) Own clauses:** `mix lat.commencement --read --law <149 family laws>` (2 s; `--law` now takes a list).
- **(b) Orders:** `--read-orders` for HSWA, OSRPA, EMAS, CMCHA, NI 1997/1774 and NI 1998/2795 (1 s).
- **(c) Amending laws' own clauses:** `--read-amending --workers 1` on 288 held (77 of 365 not held; 44 s), and `--read` on the 89 with LAT (3 s). No errors.
- **(d) Rebuild:** `mix lat.vocabulary --build --family "OH&S: Occupational"` (2 min, 149 laws, no errors).

## Check run 2 (stored, seed 4): PASS on rows, our faults 0

Rows (20,170):
- dated 16,367;
- staged 579;
- by order 181, and by order partly 71 (HSWA rows its PDF-only orders would date; NI 1998/2795);
- EU directive 1,071, EU publication-relative 1,894;
- partial only 4, `no_clause` 3.

Feed yardstick: agree 5,028, differ 169:
- 157 rows of SI 1992/3004 are later insertions (P2), as are HSWA s.3(2A) and others;
- OSRPA s.91(1): the feed records 1964-08-01 at full.

**Gaps:** 2,740 changes no other source dates (955 text). The rise from 555 is not a regression:
- Outside Schedules and annexes, undated text changes are flat, 338 → 344.
- In Schedules and annexes they rose 4 → 343. These are changes the CV-S02/S03 reader fixes now read (EU annexes, mostly CLP's), which the 2026-10-22 build predated. That's the K1 limit.

Dated by the gap-filler: via note 225 (was 185), via feed 648. `no_text_rules` text changes went 99 → 0, after the re-read plus decision 2.

## Golden after apply: 24/27

- **HSWA s.78:** our result is right. The golden case was "UNDECIDABLE commencement" (Royal Assent as a placeholder). SI 1974/1439 art.2(c) and Sch. 3 now date it 1975-04-01, so I propose updating the case (asked Jason).
- **TCPA s.284(3)(a) and EUWA s.6:** stale stored rules for amending Acts outside the family. PCA 1991 and the REUL Act 2023 hold `act_enactment` from the old reader, and decision 2 now trusts it. A fresh read is right for both: PCA `by_order`; REUL `clause_staged` with the other provisions by regulations. This needs a corpus-wide own-clause re-read (asked Jason; held until the reader is fixed, so it runs once).

## Agent check, seed 4 (50 rows, 50 gaps): FAIL

Rows 37 OK, 12 WRONG, 1 doubtful. Gaps 27 OK, 16 WRONG, 7 doubtful. The doubtful `no_amending_law` gaps were unverifiable because the sample shortens keys, so the sample now needs the change's row id.

New defects:
- **A:** "Section 43 (except so far as already in operation)" / "(except as aforesaid)" read as partial; it means the rest, in full (SI 1974/1439).
- **B:** my regression. `OwnClause.context` `order` holds top-level refs only, so a subsection range ("s.10(2)..s.10(4)") covers nothing; `LatRef.in_range?` needs a fallback.
- **C:** one item's qualifier spread over the sentence (SI 2015/21 reg.1(2)); the open bulk-qualifier bug class.
- **D:** "premises … to which section 51 … relates" read as commencing s.51 (SI 1964/191 art.2).
- **E:** the covered-market split in SI 1964/191 is lost (Sch.1 Pt. V unqualified).
- **F–J:** amending Acts' clause sentences unread or misread (confirmed on fresh reads):
  - EA 1995 s.125(3) "Except as provided in subsection (2) …, this Act … by order";
  - DRA 2014 s.50(1) "Parts 1 to 3 … by order";
  - LGRA 1997 s.34 "is to come into force";
  - PMCA 1994 s.94(1) "Except as provided by (2) and (3), the preceding sections of, and the Schedules to, this Act … by order";
  - GLA Act 1999 s.425(2) "Apart from this section, section 420 …, the provisions of this Act … by order", misread as dated on passing.
- **K:** "Regulations 5 to 27 and the Schedules" drops the Schedules (SI 1992/3004, NISR 1993/37).
- **Not in the sample:** "Section 33(1)(a) and (b)" read as `s.33(b)`; an order's Sch. 10 repeals line naming EMAS 1972 sections read as HSWA's; Petroleum Act 1998 s.52(1) on passing unread.

**Lesson:** the sample keeps reaching sentence forms the reader doesn't know. Build the commencement-sentence catalogue first (as S02b and S03 did); I agreed that approach at the start and skipped it.

## Step 1 fixes (2026-10-23)

- **B:** `LatRef.covers?` falls back to number order when the document order doesn't hold the range's ends (it lists whole provisions only).
- **A:** in `Order` `@full`, "(except so far as already in operation)" and "(except as aforesaid)" mean the rest, in full.
- **Bracket sibling:** `Order.list_refs` reads "33(1)(a) and (b)" as `s.33(1)(b)`, via `sibling/2`.
- **Titled repeals line:** `Order.drop_other_laws` drops another law's title followed by a dash and the provisions after it. "the following repeals" is partial.
- **K:** `Provisions` reads "… and the Schedules" as the container `sch`, and `LatRef.chain` puts `sch` above any Schedule provision.
- **C:** `Provisions.bracket_qualified/1` keeps an item's own bracketed qualifier on that item only (SI 2015/21: reg.1 and reg.22 full 2015-05-31; reg.2 partly then, fully 2015-06-01).
- **Tests:** Order +3, OwnClause +2, LatRef +1. 3,062 pass.

## Step 2: commencement-sentence catalogue

**Built (2026-10-23/24):**
- `Commencement.SentencePatterns` (pure): classes each sentence by role, lead, subject, verb, when and qualified, and records the reader's outcome: `law:<treatment>`, `rules:<treatments>`, `unread` or `none`.
- `mix lat.commencement_patterns`: covers LAT laws and held amending laws read from CLML, one at a time.
- `CommencementPatternsTest`.
- An example is pruned to the smallest level (`tight`, then `named`, then `full`) that reads alone as in its law, with compact rows.

**Run 1 (2026-10-24, 12 min, read-only):** 2,606 laws (1,066 with LAT), 8,099 sentences, 819 patterns, 1,563 examples.
- The fixtures came to 64 MB. After pruning they're 5.3 MB, but 248 examples were lost to a comprehension bug (`x = false` filters); they'll be regenerated on the next run.

Statement outcomes:
- `law:clause_date` 1,146;
- **`none` 1,145**;
- `rules:provision_by_order` 163;
- `law:clause_staged` 157;
- `rules:provision_dated` 156;
- **`unread` 153**;
- `law:by_order` 147;
- `rules:provision_qualified` 64;
- `law:clause_named_day` 58;
- **`law:clause_unread` 31**.

Fix list, by count:
1. **Statements outside the clause's provision are never read.** `Provisions` reads only the section holding the law's clause. Examples: ukpga 1999/24 s.7(3); NERC Act 2006 s.107(1) "Part 1 … by order"; PMCA 1994 s.94; EA 1995 s.125.
2. **Schedule references are dropped** (refs survive only for held rows, and LAT holds no Schedules): "paragraphs 4 to 10 and 21 of Schedule 3", "Part II of Schedule 9". These matter for the gap-filler.
3. **CLML-read laws have no Parts** (`doc_rows` part nil), so "Part 3 comes into force", "This Part", "Parts 1 to 3" don't resolve (DRA 2014, LGRA 1997).
4. **Lead-ins and "not until":** "Except as provided …", "Other than …", "Apart from— …", "In Part 5, …"; "shall not come into force until such day as … appoint" means by order.
5. **Made-relative wordings:** "the day after receiving Royal Assent", "the day after that on which it is passed", "when they are made", "on the expiration of one month beginning with the date of the passing thereof"; "is to come into force" (LGRA).
6. **Pronouns:** "The title of this Order is … and it comes into force on …".
7. **List heads** whose items carry the dates: "Section 1 comes into force—", "regulations 3 to 6 … come into force—".

Known limits seen: tied to another law's provision ("immediately after Schedule 3 to the Digital Economy Act 2017 comes fully into force"); a defined day ("the main commencement day").

### Fixes 1–7 (2026-10-24; development loop over the 1,315 held examples, a snapshot diff per fix)

1. **Statements anywhere:** `Provisions.groups` also reads statements in other provisions (`elsewhere/4`), each in its own provision. Never a mention (`Clause.mention?/1`, shared with the catalogue), a general clause, or "this section" alone.
2. **Schedule refs:** `Order.own_schedule_refs/1` is shared with `Provisions` and kept though no row holds them ("paragraphs 15 to 20 of Schedule 2", "Schedules 16 and 17", "Part V of Schedule 6").
3. **Parts in CLML-read laws:** `OwnClause.doc_rows` takes each provision's Part and Chapter from its containers. "Parts 1 to 3" expands; "Chapter N" alone is read in its own Part.
4. **Lead-ins:**
   - long "Except as provided … / Apart from … / Other than …" leads before a general clause;
   - "except for X (which come into force on Y)";
   - "the preceding sections of, and the Schedules to, this Act";
   - another general sentence in a clause dates the rest (partial when qualified; one group per country for "in England on X and in Wales on Y");
   - a staged clause gives the law's rule over the register's date;
   - a by-order law's other clause sentences are read.
5. **Made-relative wordings:** "the day after receiving Royal Assent", "the day after that on which it is passed", "when they are made", "the expiration of one month beginning with the date of the passing thereof", "the day after the Bill for this Act receives Royal Assent"; also "is to come into force".
6. **Title pronoun:** "The title of this Order is … and it comes into force on …".
7. **List heads:** "Section 1 comes into force— (a) …; (b) …", where each item dates the head's provisions.

**Also:** `Provisions`'s dash split gains the `u` flag (it cut "—" mid-character), and a provision's own words are read once (rules deduped). In the test "provisions the reader can't resolve", a Schedule's commencement is now read, so the test uses an unreadable sentence instead and a new test covers the Schedule.

**Tests:** OwnClause +7 (25 in all). 210 pass in law_start, commencement and change_collector.

**Run 2 (2026-10-24, 12 min):** 8,099 sentences, 824 patterns, 1,561 examples; 2 examples read differently alone (was 33).

Statements by outcome:
- `law:clause_date` 1,168;
- **`none` 769** (was 1,145);
- `rules:provision_by_order` 294 (was 163);
- `rules:provision_dated` 249 (was 156);
- `law:clause_staged` 177;
- `rules:provision_qualified` 153 (was 64);
- `law:by_order` 150;
- **`unread` 111** (was 153);
- `law:clause_unread` 25.

The fixtures are still 28 MB: 62 big-Act examples fell through to every row. So there's a new pruning level, `ids` (every row's id; text only where it has commencement words), before `full`.

Most of the remaining `none` aren't this law's commencement: a scheme, an order made under it, a notice, a prohibition coming into force. The catalogue now classes those as the subject `instrument`.

### Fixes R1–R10 (2026-10-24)

- **R1:** lead-ins "Except as mentioned / provided for / in so far as …", "Subject as follows"; a long lead ending in a bracket ("… of that paragraph) this Act shall come into force": EA 1995 s.125(3).
- **R2:** "The rest of this Act".
- **R3:** "The provisions mentioned in subsection (3)": that subsection's list, read once (a subsection naming itself looped: Petroleum Act 1998 s.52 hung the run).
- **R4:** "… does not apply to section 195 which shall come into force when this Act is passed"; "the day / date of Royal Assent"; "when this Act is passed".
- **R5:** "for all purposes on 6th April 1988" before the date.
- **R6:** "in accordance with provision to be made by … by order".
- **R7:** "save that regulations 9 and 12(1)(b) shall come into force on …".
- **R9/R10:** "These Regulations apply in relation to Wales and come into force on …"; "may be cited as … which shall come into force on …".
- **Also:**
  - "in Schedule 4, paragraphs 8, 10 …" is read as those paragraphs;
  - bracket ranges "5(1) to (4)" are expanded;
  - a statement elsewhere must name provisions first (Building Societies Act 1986 s.186(1): a notice "served under section 183" was read as commencing s.183).

**Tests:** OwnClause 30 (+5). 210 pass in law_start, commencement and change_collector.

**Pending forms (to mark `pending` in review):**
- descriptive item lists ("so much of any provision as authorises …": ICTA 1988 s.843(3));
- date-first list items ("1st April 1989 in respect of all mines other than …": SI 1988/1729);
- purpose-staged general clauses ("for the purposes of regulation 13 on 1st April 1988 and for all other purposes on 6th May 1987");
- tied to another law's provision;
- defined days ("the main commencement day").

**Run 3 (2026-10-24, 12 min):** 8,099 sentences, 861 patterns, 1,625 examples.
- `none` 798, `unread` 95.
- `rules:provision_by_order` 289, `rules:provision_dated` 255, `rules:provision_qualified` 127.
- The rise in `none` from 769 is the false-hit filter.

**Fixture layout (2026-10-24):** a law's examples now share one input in `laws.json` (one law a line, the union of the rows they keep), each example rechecked against it.
- An example in a law over 1,000 rows that needs every row's text isn't held (too large).
- Run 3 was converted offline (the reader unchanged): 1,594 examples, 810 laws, 6.8 MB (was 30 MB); 6 too large, 25 dropped on recheck.

**Run 3 review fixes:**
- a general clause's bracketed exception, nested brackets allowed: "This Act (except the provisions listed in subsection (3), which come into force on the passing of this Act) shall come into force …" (CA 2003 s.411(2));
- "shall not / does not come into force until …" (ECA 2000 s.17(3)); "until" before a date;
- a list between commas: "This Act, except section 120 above, this section and section 122 below, shall …" (PACE 1984 s.121(1));
- mentions:
  - a sentence beginning "When / Where / If / Until / Unless / Once" is a mention, and the clause's own sentences are tested too (PACE s.121(3));
  - "the day / date on which" is a mention only before a coming into force. The rule had also made "… come into force on the day on which this Act is passed" a mention, mis-classing run 3's statements and filtering them out of `elsewhere`.

**Tests:** OwnClause 33 (+3). 215 pass.

**Run 4 (2026-10-24, 12 min):** 8,099 sentences, 804 patterns, 1,547 examples (1 too large), 6.4 MB. The mention fix shows: `rules:provision_dated` 453 (was 255), `law:clause_made_relative` 208 (was 17).

Review classes:
- mentions read as nothing: 234 patterns, 4,206 sentences;
- mentions with rules (statements misclassed): 20, 36;
- statements read: 320, 2,907;
- statements about another instrument: 70, 381;
- **statements naming this law's provisions, not read: 160, 569**.

**Run 4 review fixes:**
- `Clause.mention?` reads only the sentence's head, before its first "comes into force": a later "which comes into force …" no longer makes a statement a mention (SI 2009/1581). "coming" as the verb, "the date upon which", "the date these Regulations …" are mentions.
- A provision's own words left to an order ("This section comes into force on such day as the Treasury may by order … appoint": FA 2014 s.300(3)).
- "the provisions of this Act" as the whole law (HSCA 2008 s.170(3)), never with an except list after it (asp 2003/8 s.60; ukpga 1998/8 "(apart from section 16, …)"), which stays the rest.
- A list item "may be cited as … and come into force on …" under "These Regulations—" (SI 2017/407).
- Against run 4, 50 of 1,547 examples read differently, nearly all to rules. One regression is noted: NISR 1993/3160 "This Article (other than paragraph (2) …) and any regulations made thereunder shall come into operation …" now reads nothing.
- 218 tests pass.

**Run 5, accepted (2026-10-24, Jason: "Run 5"):** 8,099 sentences, 767 patterns, 1,486 examples (1 too large), 6.3 MB of fixtures. Statements by outcome:
- `law:clause_date` 1,175;
- `none` 656;
- `rules:provision_dated` 458;
- `rules:provision_by_order` 274;
- `law:clause_staged` 243;
- `law:by_order` 210;
- `law:clause_made_relative` 210;
- `rules:provision_qualified` 164;
- `unread` 135;
- `rules:provision_dated+qualified` 76;
- `law:clause_named_day` 61;
- `law:clause_unread` 38;
- `rules:provision_by_order+qualified` 31;
- `law:tied_to_other_law` 13.

**Statuses (the policy proposed 2026-10-24):** everything accepted, except a statement naming this law's provisions that reads nothing or is unread. Those 136 patterns are `pending: <reason>`, and their examples hold the reading as it is now. This deviates from S03, where pending examples held the correct reading. By sentences:
- a form not read yet: 211;
- no date read: 163;
- a list whose items aren't read: 29;
- tied to another provision: 24;
- a defined or event day: 19;
- descriptive items: 4.

Statements naming another law's provisions (20) are accepted, as the order reader's.

**`CommencementPatternsTest`:** 1,250 pass, 240 excluded (pending), 25 s. Each law is read once in setup, in parallel, and kept in `:persistent_term`; it was 104 s with a read per example.

### Orders catalogue (2026-10-24)

**Built:**
- `Commencement.OrderPatterns` (pure): units are each article's statement and each Schedule-table row. Kinds: `inline`, `following`, `items_first`, `appointed`, `appointed_is`, `whole_act`, `table`, `table_header`, `schedule_intro`, `own`. Also when, qualified, full and other-law flags, and the outcome (`none`, or `rules` with `+partial` / `+all`).
- `mix lat.order_patterns`: every held order with the Act it commences (cached order lists plus stored rules' sources); 30 s.
- `OrderPatternsTest`.
- An example is the order cut to its title, made date, articles and the unit's Schedule (whole when ≤ 20 KB), checked to read alone as in the order. Over 30 KB it isn't held.

**Run 1:** 666 held orders (of about 1,422 listed), 3,459 statements; 171 orders gave no rules at all.

**Fixes:**
- **O1:** "D is the **appointed day** for the coming into force of …" (only "day appointed" was read).
- **The day kept:** `clean_line` cut a date's day as a paragraph number ("18 March 2011" → "March 2011": WSI 2011/824).
- **O2:** "the 1989 Act" names the Act unless the order defines it otherwise (SI 1997/134).
- **O3:** a bracketed alias in a whole-Act subject ("The Petroleum Act 1998 (hereinafter referred to as “the Act”) …"); "so far as not already in force" without "it is".
- **Table context:** each row takes the Schedule an earlier row names, else the table's title ("EXTENT OF COMMENCEMENT OF SCHEDULE 7": SI 1991/2905), else its introducing article.

**Catalogue classes:** `own` (the order's own citation and commencement), `table_header`, `schedule_intro`; repeals rows naming another law flagged `other_law`.

**Final:** 3,459 statements, 166 patterns, 343 examples (184 too large).
- table rows: 1,145 read, 540 not;
- appointed-day statements: 148 + 53 read.

**Statuses (as for sentences):** 41 of 166 pending, by units:
- a table row not read: 473;
- a column table's purposes or provisions: 249;
- a list head whose items aren't read: 104;
- "the day appointed … is …" not read: 68;
- other forms: 49.

The agent's D ("premises … to which section 51 … relates") and E (SI 1964/191's covered-market split) sit in these pending classes.

**Tests:** Order 37 (+3); `OrderPatternsTest` 258 pass, 87 pending. All suites: 1,737 pass.

**Not held (a known limit):** about 756 listed orders aren't held at all, and some held orders (e.g. SSI 2011/30) are body-only, their tables in Schedules not fetched. That's the class of the open SI 1997/3114 bug; a fetch is for Jason to decide.

## Step 3 (2026-10-24, Jason: "Update golden HSWA and step 3.")

**Golden HSWA s.78 updated:** prospective from 1974-07-31, in force from 1975-04-01 (SI 1974/1439 art.2(c), Sch. 3), repealed_saved from 2006-10-01. It was UNDECIDABLE, with Royal Assent as a placeholder.

**The rewrite:**
- **Restore point:** `restore-points/2026-10-24-cv-s04-before-corpus-reread` (`commencement_rules`, `provision_changes`, `provision_change_claims`, `lat_events`; 4 s).
- **Own clauses:** `--read --all` on 1,066 laws, 1,516 rules (18 s); `--read-amending --workers 1` on 1,541 held amending laws, 2,363 rules (3 min 50 s). No errors.
- **Orders:** `--read-orders --law <399 Acts with cached lists>` (16 s); `--read-orders` on 133 cited orders, 1,720 rules (6 s).
- **Rebuild:** the OH&S family (2 min, 149 laws, no errors).

**Check, seed 5: PASS on rows, our faults 0.**
- dated 16,383, staged 608;
- by order 158, by order partly 53;
- EU directive 1,071, EU publication-relative 1,894, `no_clause` 3.
- Feed yardstick: agree 5,028, differ 170 (157 of them SI 1992/3004's later insertions, P2).
- Gaps (958 text changes):
  - dated via note 211, via feed 537;
  - `appointed` 242, as by-order Acts now read so (EA 1995 ×80);
  - `no_pointer` 650 (552 text, 342 of them in EU annexes, K1);
  - `no_amending_law` 836, `rules_not_held` 274, `not_reached` 8.

**Golden after step 3: 26/27.** HSWA s.78 passes. EUWA s.6 failed on the REUL Act 2023, whose clause had been read from its **scoped LAT**: 45 rows, without s.22, so "no clause", so Royal Assent.
- **Fix:** `lat.commencement --read` reads a scoped law's clause from its whole CLML (`clause_input/1`).
- 104 scoped laws re-read (31 s, 217 rules); the REUL Act now reads `clause_staged`, with s.18 at two months and the rest by regulations.
- 72 laws whose own-clause rules predated step 3 were also re-read.

## Agent check, seed 5 (round 2): rows 41 OK / 3 WRONG / 6 doubtful; gaps 35 OK / 10 WRONG / 5 doubtful

New defects and their fixes:
- **N4 (a safety rule):** an Act whose own commencement words are unread was treated as having no clause, so Royal Assent stood in (Gas Act 1995 s.18(2), "This Act, except— … on the appointed day, that is to say, such day as … by order"). **Fixed:** where the Act's own sentence ("This Act …", "The provisions of this Act …", any lead) gave no group, the rule is `unread`, never Royal Assent (`OwnClause.unread_own/2`).
- **N1:** one item's qualifier spread over the list. **Fixed:**
  - a bare Schedule list with its own qualifiers is read item by item (`Order.bare_items/3`): SI 1996/186 Sch. 22 para.30 is now fully in force from 1996-04-01;
  - "Section 33 (except subsection (1)(a) and (b))" is the section with those excepted, in full (`except_subsections/2`).
  - This fixes the open bug "A qualifier on one item of a bare paragraph list read over the whole list".
- **N5:** "may be cited as … and subject to paragraphs (2) and (3) shall come into force on …" (Quarries Regulations 1999). **Fixed** in the citation general clause.
- **N3:** "the Schedule entitled Schedule 1C" was read as every Schedule (`sch`). **Fixed:** "the Schedule(s)" never after "of", nor followed by "entitled" or "to the … Act". In the catalogue, PMCA's example was re-accepted and 2003/22's "(and the Schedule)" kept.
- **Pending (catalogued):**
  - N2: SI 1964/191's covered-market split (the D/E case);
  - N6: a commencement set out in the law's own Schedule (SI 1989/2169 Sch. 1 Pt. I);
  - "68(1)(c) and (2)" read as `s.68(1)(2)`;
  - SI 1964/1045 "that is to say—";
  - a mis-attributed rule from SI 1996/396 (another Act's "Section 21");
  - containers (Part / section rows) never added up from their children's rules: a decision for the label fold.

**Tests:** Order 39 (+2), OwnClause 36 (+3). All suites 1,742 pass.

## Round 3 fixes and round 4 (2026-10-24, Jason: "Go with the fixes and round 4")

**Fixes:**
- **Except lists on general clauses:** "This Act, except— (a)…", ", apart from sections 7 and 8 and this section,", "Except for section 26 and this section the provisions of this Act …" (`Provisions.except_refs/2`). They become the law rule's `except`, and the excepted provisions of an Act are in force on Royal Assent (Interpretation Act 1978 s.4). A provision's own sentence wins over the except list (Gas Act s.12 by s.18(4)).
- **The appointed day for a section:** "The day appointed for the purpose of section 18(2) of the Gas Act 1995 shall be 1st March 1996" (SI 1996/218) takes the scope and except of the Act's own appointed-day rule from that section (`Order.resolve_appointed_for/2`, applied when orders are read). This dates the Gas Act's 121 HSWA records (applications, amendments, savings; feed `Prospective`, no date).
- **NEW-A:** a table cell is split per provision, outside brackets (`provision_segments/1`), so each provision takes its own qualifier (SI 1974/1439: "Section 11(4) and (5)" fully, "Section 11(6) (so far as aforesaid)" partly).
- **NEW-B:** "insofar" as one word. The order reader's qualifier patterns had "insofar\s*far", which never matched; "insofar as not already in force" is full.
- **NEW-C:** repeal descriptions naming another Act ("the repeals to the Game Licences Act 1860", "in relation to the Water Resources Act 1991, the repeal of …", "in the Town and Country Planning Act 1990, sections 226 and 245") are dropped. "In Schedule N, the repeals …" is part of Schedule N, and the rest of its line is read.
- **NEW-D:** ", which extend to Great Britain," in a citation clause.
- **Lead-ins:** "Except as otherwise expressly provided", "Except for"; "other than— …".
- **Catalogues:** 31 sentence and 7 order examples re-read and re-accepted after review. The tests are 4,601 passing.

**Round 4 rewrite:**
- restore point `restore-points/2026-10-24-cv-s04-before-round4`;
- own clauses for 1,066 LAT laws, 1,541 amending laws and 72 stale ones;
- orders for 399 Acts' lists and 133 cited orders;
- the family rebuild. No errors.

**Check, seed 7: PASS, our faults 0.**
- Rows: dated 16,430, staged 608, by order 158, by order partly 6.
- Gaps: dated via feed pointer 643 (was 486; the Gas Act's), via note 221, `appointed` 109 (was 164; the Police (Health and Safety) Act 1997 now dated), `unread` 0 (was 131).

**Order reader's reach (read-only measure):** 668 orders, 2,901 statements about the Act, 1,951 read (67%):
- table rows 1,279/1,752;
- lists 277/344;
- appointed-day 197/328;
- inline 156/424;
- whole Act 27/31;
- items first 15/22.

## The stopping rule (agreed with Jason 2026-10-24: "Agreed on the stopping rule - that clearly bounds our work here and provides the clear rules that other families may extend the catalogue with their own forms")

The order and clause grammar is bounded: a statement head (about eight shapes), a when, items (refs plus a qualifier) and context carriers (the Act's aliases, a Schedule's context). What varies is the drafting within each part. A family's commencement step passes when:
1. the check passes on rows (our faults 0);
2. golden is all-pass;
3. **the agent sample finds no NEW defect**: every WRONG falls in a known pattern or a catalogued pending class.

Every remaining gap then sits in a counted pending class (both catalogues). Later families extend the catalogues with their own forms through their catalogue runs, and fix what is new to them.

## Agent check, seed 7 (round 4): rows 45 OK / 4 WRONG / 1 doubtful; gaps 50/50 OK

- The 4 WRONG rows are all known patterns: **P7**, the catalogued pending forms (a statement tied to another provision, a defined or event day, descriptive items), and **P8**, container rows never added up from their children (the label fold's, CV-S09).
- **0 NEW at sample level.** The agent named four rule-level defects behind sampled rules (R4-N1–N4). Jason chose "option 1": fix them, then a final re-read, rebuild, check and golden, with no new agent round.

## Option 1: the round-4 rule-level fixes (2026-10-24)

- **R4-N1, a qualifier after the date** ("… come into force on 1st April 2015 in so far as they relate to paragraph 81 of Schedule 22": SSI 2015/73) belongs to the subject (`Order.statement/2`).
- **R4-N2, other laws' provisions in an order's items:**
  - quoted words are never refs ("the words “… section 54 …”");
  - an item ending ", to the X Act" is that law's;
  - a title may hold brackets and the connectors at, to, with and etc.;
  - "paragraph 77 of Schedule 4 to the X Act" is that Act's.
- **R4-N3, per-item bracket qualifiers** ("Sections 1, 2, 4 to 28, …, 105 (in so far as it is not already in force), 159 and 162(2) (in so far as it relates to Part V of Schedule 16)": SI 1990/2635). Each item takes its own qualifier, and a list's trailing qualifier covers the items without one (SSI 2015/17) (`Order.bracket_items/1`).
- **R4-N4, Schedule Parts read as the Act's Parts:**
  - `LatRef.covers?` compares Part numerals either way;
  - in `Provisions` and `Order`, a Part list followed by "of Schedule" is never the Act's: the list is matched atomically, so "Parts I and III of Schedule 11" drops both;
  - an item "in Schedule 15, Part III and Part V(1)" reads no Act Part.
- **Found in the catalogue diff review and fixed:**
  - "In Schedule N, the entries relating to …" is Schedule N in relation to (SSI 2007/434, SI 1974/335);
  - the lines under "the following repeals / entries" are other provisions' repeals, never commenced, and the Schedule they are in is in relation to (SI 1996/3056, SSI 2015/73, SSI 2015/139);
  - full qualifiers: "so far as not then in force", "in so far as those sections are not already in force", "to the extent that it is not already in force";
  - related paragraphs carry a qualifier after them ("… in so far as the amendments … confer any power to make regulations": SI 1996/2909).
- **Catalogues:** 26 sentence and 25 order examples changed. Each was reviewed against its text and re-accepted. The related suites pass (4,607).

**Final rewrite:**
- restore point `restore-points/2026-10-24-cv-s04-before-final`;
- own clauses: 1,066 LAT laws (1,614 rules), 1,541 amending laws (2,387) and 72 stale (86);
- orders: 399 Acts' lists, then 133 cited orders (1,771 rules);
- the family rebuild (149 laws). No errors.

**Final check, seed 7: PASS, our faults 0.**
- Rows: dated 16,430, staged 608, by order 158, by order partly 6, no clause 3.
- Gaps: dated via feed 643, via note 221; undated `appointed` 109, `rules_not_held` 274, `no_pointer` 650, `no_amending_law` 830, `not_reached` 6, `unread` 0.
- These are the same counts as round 4: the fixes change which provisions the orders' rules name, not this family's row outcomes.

**Golden after the final rewrite: 27/27.**

**Close held (Jason 2026-10-24: "Keep session open"):** the open order bugs are worked before CV-S04 closes.

**Open, pending classes carried to later work (counted, not NEW):**
- "Part IV, apart from section 66 and Schedule 9 …" in a list item: the "apart from" after a Part item isn't read as its except (Access to Justice Act 1999 s.108(3)(b));
- "Chapters II and III of Part I" read as Part I (Freedom of Information Act 2000 s.103(2));
- a Schedule's Parts in an Act clause ("Parts III and IV of Schedule 16") dropped rather than read as `sch.16.pt.III`;
- "in Schedule 8, the entries relating to:—" heading items-first orders (SI 1978/1583) reads nothing.

## The two open order bugs (2026-10-24, Jason: "Keep session open")

- **Bare-list qualifier:** already fixed in round 2 (`bare_items/3`); its todo is now ticked.
- **SI 1997/3114:** the Schedule is held and its rules are read. Its repeal-entries cell was read as the Firearms (Amendment) (No. 2) Act's own s.11–14, sch.1 and sch.2.para.13, though those provisions belong to the Firearms (Amendment) Act 1997. **Fixed** (`9d9f2ab3`): a repeal-entries cell is read whole as the Schedule in relation to ("In the Schedule" unnumbered, like "In Schedule N").
  - A read-only preview gives `sch` in relation to on 1997-12-17 and 1998-02-01; the other Act's provisions are gone.
  - The catalogues are unchanged; the related suites pass (4,608).
  - The stored rules are not rewritten yet: one order, `--read-orders --law UK_ukpga_1997_64`, which is outside OH&S (ask first).
