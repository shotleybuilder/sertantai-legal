---
session: 'CV-S05: Extent and Application Reader'
status: active
release: v0.1
opened: '2026-10-22'
bugs:
  - pattern: "Amendment reader target precision: \"of that subsection\" not resolved to the subsection named before; a nested list item's parent bracket (\"(f) in subsection (5)— (i) in paragraph (a)\") not carried; \"—shall be omitted; (i) the words …\" read as provision-level (1995/25 Sch. 22 para 30(6))"
    category: amendment
    module: Amendment.Reader.Targets / Clauses
    affected: 9
    fix: "2c1bf0b0: parents' brackets (lead-in only), \"that subsection\" the last named, words listed; plus captions never targets, Schedule paragraphs no section rules"
    status: fixed
  - pattern: "extent_rules written without an SI's enabling powers or a devolved law's competence: the amendment read pass (ReadPass.write) and --extents' parents step stored the bare Extent.read/1, so every full read pass wiped those rows (482 laws stale, 2026-10-26)"
    category: extent
    module: Amendment.ReadPass / mix lat.amending --extents (now Extent.Store.write_read/3)
    affected: 482
    fix: "One writer, Extent.Store.write_read/3 (with_powers, cached: true from the read pass); ExtentWriteTest; then re-write the affected laws' extent rules"
    status: fixed
  - pattern: "Commencement: an Act with a by-order clause also holds an \"all — act_enactment\" (Royal Assent) rule, so an amending provision no order rule names is dated Royal Assent: SOCPA 2005 Sch.7 para 27(2) repealing RTA 1988 s.4(6) dated 2005-04-07, golden expects 2006-01-01 (SI 2005/3495). Exposed 2026-10-25 when the read pass (with SOCPA's Schedules now held) first reached that repeal: golden 26/27"
    category: commencement
    module: Commencement (OwnClause / LawStart act_enactment rule beside a by-order clause; CV-S04)
    affected: 1
    fix: "65bf8b34 / 9c28b1ad (the assent floor and own-parts fixes; golden 27/27)"
    status: fixed
  - pattern: "Amendment reader: \"The Localism Act 2011 is amended as follows\" (PCA 2017 Sch.1 para 94) read as amending FRSA 2004 whenever FRSA is among the laws pointing to the amending law; with only the Localism Act it reads nothing"
    category: amendment
    module: Amendment.Reader (law?/laws title matching)
    affected: 3
    fix: "fixed with DefinedTerms' thing-under rule (a caption naming FRSA 2004 under \"a fire and rescue authority under …\"), 2026-10-25"
    status: fixed
  - pattern: "Amendment reader: a parent's \"listed in sub-paragraph (4)\" (the amending law's own) inherited as a place (SI 2026/386 Sch. 3 para 6(3)(a) → reg.2(4)); a sibling list item naming a law outranks the provision's own heading (SI 2026/386 Sch. 3 para 6(5): was DPA 2018 s.155, now nothing, should be PEC reg.32)"
    category: amendment
    module: Amendment.Reader.LawNamed (placed_by, named)
    affected: 2
    fix: "Drop parent brackets after \"listed/mentioned/specified in\"; prefer the provision's headings and parents over siblings when naming the law"
    status: open
  - pattern: "\"Nothing in this Act extends to Northern Ireland\" read as extending only there (the subject matched inside \"Nothing in this Act\"); \"Scotland or (to) Northern Ireland\", \"England and Wales and to Scotland\" dropped the second place"
    category: extent
    module: AmendingLaw.Extent (@subject, @place_list, @not_extends)
    affected: 9
    fix: "71ca78a7: the subject never follows \"in \"; \"Nothing in … extends to X\" is a not-extends; \"or\", \"or to\", \"and to\" join places"
    status: fixed
  - pattern: "Own-words rule over-applied to extent (mine, in fix round 2): stripping Addition and Substitution left extent statements amended into a law unread (catalogue run 4: 7 read patterns gone)"
    category: extent
    module: AmendingLaw.Extent (own_words)
    affected: 7
    fix: "71ca78a7: for extent only BlockAmendment is stripped; application keeps the as-made rule (N2). Caught in the run 4 review; run 5 confirms"
    status: fixed
  - pattern: "Fragments beside the whole text: scoped LAT (#166) fetched section/part/schedule fragments; fetching the body or Schedules later never removed them, and every reader globbed **/data.xml.gz, so the fragments' ids repeated the body's and moved document positions (TCEA 2007 Part 1 read as s.44 only)"
    category: data
    module: ClmlStore / LatStagedParser / the CLML loaders (lat.amending, lat.commencement*, change_collector, lat.vocabulary, lat.extent_*, lat.order_patterns)
    affected: 40
    fix: "689c0adb: one loader (ClmlStore.law_docs: body + Schedules, fragments only without them); storing the whole removes the fragments; a scoped law with its body held is parsed from the body, cut to its scope (LatScope.cut). The duplicates were removed (40 laws, 116 files, archived in backend/data/cache/clml-duplicate-fragments-2026-10-24.tar.gz)"
    status: fixed
  - pattern: "The extent check fetched from legislation.gov.uk unasked: the shared powers step (`lat.amending` with_powers) re-fetches an SI's made introduction whenever the enabling cache holds nothing parsed for it (retry_empty)"
    category: tooling
    module: mix lat.amending (with_powers) / mix lat.extent_check
    affected: "about 65 introductions fetched 2026-10-24 (SIs with no parsed powers); only data/cache/enabling written"
    fix: "with_powers(e, law, cached: true): the enabling cache only; the check always passes it; `--extents --cached` for re-reads"
    status: fixed
  - pattern: "Stored extent_rules stale against the extent reader (written before the CV-S05 forms); 13 family amending laws never stored"
    category: extent reading
    module: extent_rules (mix lat.amending --extents)
    affected: "OH&S: 62 stale, 13 not stored, of 444 amending laws"
    fix: "re-read the family's amending laws (--cached), then rebuild (2026-10-24: our faults 0)"
    status: fixed
  - pattern: "LawStart's own-parts fallback took a mention as an Act's clause (SOCPA 2005 s.101(2) \"… taken before this section comes into force\" before s.178), so SOCPA fell to Royal Assent beside its by-order clause and the vocabulary dated RTA 1988 s.4(6)'s repeal 2005-04-07 (golden 26/27); and a section commencing itself alone (\"This section shall come into force on 1st April 1982\") set an Act's start"
    category: commencement
    module: LawStart.Clause (own_parts)
    affected: "21 catalogue examples (reviewed); SOCPA re-read, RTA 1988 golden passes"
    fix: "own_parts skips mentions; for an Act it skips \"This section … come into force\" alone (Clause.read/3 act?), never one going on to the rest (ukpga 1992/34 s.8(3))"
    status: fixed
  - pattern: "DefinedTerms kept terms meaning a thing under a law (\"fire and rescue authority\" = \"a fire and rescue authority under the Fire and Rescue Services Act 2004\"), so PCA 2017 Sch.1 para 94's caption named FRSA 2004 and its Localism Act 2011 amendments were read as FRSA's"
    category: amendment
    module: AmendingLaw.DefinedTerms (law_title?)
    affected: "PCA 2017: 6 of 7 terms; corpus reach unmeasured until the read pass"
    fix: "a term means a law only when its definition is the title itself: not \"a/an/that …\", \"under / for the purposes of / defined in / section N of\" a law"
    status: fixed
  - pattern: "A UK Act's staged clause leaving provisions out (\"other than this section and sections 42 and 43 … by order\", \"shall not come into force until 1st April 1965\") dated the Act's start from its first stage, after Royal Assent (CJPA 2001: 2001-07-11; LGA 1963: 1965-04-01); exposed once mentions stopped hiding these clauses"
    category: commencement
    module: LawStart (assent_floor)
    affected: "4 catalogue examples (reviewed)"
    fix: "9c28b1ad: ukpga only, the start no later than Royal Assent when the clause says \"this Act / the provisions of this Act, other than|except …\" or \"not … until\""
    status: fixed
  - pattern: "An Act whose clause leaves its provisions to orders in other words still falls to Royal Assent: \"Apart from section 54(1) and (2), the preceding provisions of this Act come into force in accordance with orders made by the Treasury\" (Tax Credits Act 2002 s.61), \"the remainder of this Act shall come into operation on such day as Her Majesty may by Order in Council appoint\" (ukpga 1962/58, its rest unread); the SOCPA class, older"
    category: commencement
    module: LawStart.Clause (general / by_order forms)
    affected: unmeasured (2 seen in the catalogue)
    fix: "read \"in accordance with orders\" and \"the remainder … by Order in Council\" as by order"
    status: open
  - pattern: "Amendment reader drops a context's subsection: \"In section 43(1) …— (a) omit the 'or' at the end of paragraph (h)\" targets s.43(h), not s.43(1)(h) (PCA 2017 Sch.1 para 94(3)); a target the amended law lacks is then dropped as a misread"
    category: amendment
    module: Amendment.Reader (numbers / brackets from context)
    affected: unmeasured
    fix: "carry the context's brackets onto the instruction's paragraph"
    status: open
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S05: Extent and Application Reader (ACTIVE)

## Problem

Step 5 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Where an amending law's changes apply, from its own text: its extent clause, its application clause, else its enabling powers, else its legislature's competence.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (the acceptance check): a hand-checked sample from the OH&S core family, and the measures, each defined in words with a test
- ✅ The extent/application/powers catalogue (every sentence in held amending laws, classed by form × reading; fixtures + test)
- ✅ Build the acceptance check; run it (ask Jason before any long run)
- ✅ Checked on a sample of each wording read (CV-07 built four rounds, checked only by golden)
- ✅ Act wordings not read: "Parts I and III of this Act … extend to …"; "except for Part N, which extends to …"; "the same part or parts … as the provision to which it relates" (CV-07)
- ⬜ Enabling-power parser: 6 other unparsed forms and 1 with no enacting formula (CV-07 agent sample); SI 1999/3232 matched to "ECA 1972 s.80, Sch.9" (a multi-law citation marker misread)
- ⬜ The competence rule (a devolved SI's competence doesn't confine its insertion, V1-04) confirmed on cases beyond Forestry Act s.1(1A)
- ⬜ SI 2012/760: its made introduction (held) names no enabling provisions (from CV-S01)
- ✅ Before round 6, the two defects the run-time read pass exposed — fixed (`65bf8b34`, `9c28b1ad`); runs below (Jason: "Run")
- ⬜ Round 6 (Jason 2026-10-26: "go ahead"): ✅ (1) [`1085611f`] ✅ (2) [`a79b5c36`] ✅ (3) [`b1a1aad5`] never drop a statement silently: a sentence saying where provisions extend that isn't turned fully into rules is recorded unread, and its provisions get no bound, never the default; the catalogue and the check count it; (2) the misreads and my regressions: NEW-A (Chapter of Part), NEW-C (section in brackets), uksi 2019/696's exceptions read as items, 2022/1037's Part 4; (3) forms: "except as aforesaid … shall not extend there", lettered places "to— (a) England and Wales, (b) …", "extends to any part of the United Kingdom to which the amended enactment extends"; (4) the same runs, then agent round 6 (misses that are counted are known classes; only misreads and silent drops are NEW)
- Reader correctness done in the run-time session (moved here 2026-10-26):
  - ✅ After the gate: a caption names no law, nested quotes stripped whole — `be32c526` (Petroleum Act 1998 +9, SI 2024/1268 +1; regression 29 changed, net +78)
  - ✅ Environment Act 1995 Sch. 22 para 30 (HSWA): "The Health and Safety at Work etc. Act 1974 (in this paragraph referred to as “the 1974 Act”)" read as "Work etc. Act 1974" (apposition title stopped at "at"), naming no law — fixed `407df2c2` (short words, bracketed parts); regression preview 2 changed, +34 (1995/25 +10 HSWA; SI 2012/3119 +24 on SI 2010/2215, its bracketed title). Indexes stale until the round's full pass
  - ✅ Reader target precision — `2c1bf0b0`: a list item's place from its parents (lead-in only; a named sub-paragraph level 2), "that subsection", words listed, captions (nested too) never brackets or numbers, one quoted target per subsection, Schedule-paragraph instructions no section rules
  - ✅ End of round: full read pass (restore point `run-time-before-read-pass-9`): 7 min 49 s, 2,102 laws, 635 changed, rules 43,778 → 42,335, traced by class (see below); golden 27/27
  - ⬜ Next round: a parent's "listed in sub-paragraph (4)" (the amending law's own) is inherited as a place (SI 2026/386 Sch. 3 para 6(3)(a) → reg.2(4); no rule stored yet); a sibling list item naming a law outranks the provision's heading (SI 2026/386 para 6(5): was DPA 2018 s.155, now nothing, should be PEC reg.32)
  - ⏸️ Annex/Schedule targets — deferred (Jason 2026-10-26): LAT holds no Schedule or Annex rows (LR-10, v0.1), so these rules would reach no row and change no output; the instructions are held back / dropped, never placed on real sections. Prerequisite if Schedules come into LAT. Known cases: PSTI 2022 → CA 2003 Sch. 3A ("the electronic communications code"); SI 2019/758 Sch. 3 → REACH Annexes
  - ✅ 202 laws stale in `lat.extent_check` (OH&S) traced: corpus-wide 483 of 2,050 — 482 the read pass's bare extent write wiping powers/competence (fixed `1a4626b8`, one writer `Extent.Store.write_read/3` + `ExtentWriteTest`), 1 (`UK_ukpga_1995_15`) last written 2026-10-22, before CV-S05's reader fixes
  - ✅ Repaired the 483 laws' `extent_rules` (restore point `run-time-before-extent-repair`; `--extents --cached`, 1 min 28 s, 483 + 49 parent Acts); OH&S extent check PASS, 0 stale. CV-S05's rebuild picks the territories up
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01–S04 closed PASS on OH&S (CV-S04 2026-10-24)

## What good looks like (PROPOSED 2026-10-24, awaiting Jason)

Shaped on CV-S04's agreed approach and stopping rule. The unit is each OH&S amending law (356 of them), and each text change's territory claim.

1. **Every amending law accounted for (our faults 0).** Each law has one extent basis: own clause, application clause, enabling powers, competence, or none (with its reason). Our fault means one of:
   - the text holds an extent or application clause and we read none, or read a lower tier;
   - powers are read where the SI states its extent;
   - competence is used where powers were read;
   - a stored row is stale against the reader.

   The reasons for none are counted classes: no clause and no powers read, parent not held, no enacting formula.
2. **The catalogue first (don't skip):** every extent and application sentence in held amending laws, plus every powers clause, classed by form × reading, with real examples as fixtures and a test. Fix by count, and record pending forms with their reason.
3. **The check:** `mix lat.extent_check --family F`, built here.
   - Rows: which tier each amending law's basis came from.
   - Changes: which text changes have territory from the law and which have an extent bound, and why the rest have neither.
4. **Agent check on 50 + 50:** 50 amending laws stratified by tier, and 50 text changes. Each is checked against the law's own words and its parent Act's extent clause.
5. **Golden all-pass, tests, repeatable** (the same seed gives the same sample).

**Pass (CV-S04's stopping rule):** rows show our faults 0; golden is all-pass; the agent sample has no NEW defect, and every remaining gap sits in a counted pending class. Later families extend the catalogue.

## Agreed (Jason 2026-10-24: "Agree, start with the catalogue")

The definition of good above stands as agreed.

## The catalogue: design

Built on the CV-S04 shape (`Commencement.SentencePatterns`, `mix lat.commencement_patterns`).

- **Population:** every held body of a type whose extent the reader reads (`Extent.Store.reads?`): 3,369 laws (ukpga 639, uksi 2,062, ssi 219, nisr 177, wsi 139, asp 64, nisi 29, nia 16, asc 11, anaw 9, apni 4). One law at a time.
- **Units:** each top-level provision's sentence speaking of extent ("extend(s) to", "does not extend", "same extent as") or of whole-instrument application ("apply / have effect in relation to …").
- **Form:**
  - `kind`: extent or application;
  - `subject`: whole (this Act / these Regulations), following (a list below), parts, named, this (this section), amendments ("an amendment or repeal … has the same extent as the enactment"), or other;
  - `verb`: extends, not_extends, same_extent, applies, not_applies, or other;
  - `lead`: except, apart_from, subject_to, or none;
  - `place`: one place, a list, same, or none;
  - `only` and `also`.
- **Outcome**, what `Extent.read/1` made of it: `default:<code>`, `list:<kind>:<code>`, `applies:<code>`, a `part_not` list, or `unread` (the sentence is there but no reading took it).
- **Examples:** a pruned law XML (the provision holding the sentence, plus the ids of the Parts and sections that `parts/3` and the introductions need), read alone with `Doc.new/2` + `Extent.read/1`.
- **Files:** `test/fixtures/extent_patterns/{patterns,examples,expected}.json`, `ExtentPatternsTest`; module `AmendingLaw.Extent.Patterns` (pure); task `mix lat.extent_patterns` (read-only, writes only the fixture directory).
- **Powers clauses:** an SI's introduction isn't held. The enabling cache keeps only the parsed provisions (2,805 laws); the CLML store holds 55 introductions. A text-level powers catalogue needs the introductions stored (a fetch; Jason to decide). Without them, the powers side is catalogued by parse outcome only.

## NAS backup (2026-10-24, Jason: "also check NAS backup … in case we've fallen behind")

- **Behind:** the last full snapshot was 2026-10-19, and 12 of legal's tables had never been in the list, `amendment_rules`, `extent_rules` and the change store among them. 6,540 project files were newer than the last sync, including all of `cache/amendment-index`.
- **Fixed** (`ac634118`): the 12 tables are added. A new extras sync (`project-data/extras/`) covers the Claude memory, `.claude/memory`, `docs/qq`, `backend/priv/scraper` and `priv/metrics`. Left out (Jason): `.env` and `scripts/sync`'s May delta dumps.
- **Run:** `nas-backup.sh --archive` (the 10-19 snapshot to `archive/`). The new snapshot holds 41 tables, and 29,456 project files (1.4 GB) are synced. Then `--data-only` for the extras. No errors.
- **Not done (housekeeping, for Jason):** the database holds about 4.5 GB of old snapshot tables (`lat_reparse_*`, `live_status_snapshot_*`).

## The catalogue: built (2026-10-24)

- `AmendingLaw.Extent.Patterns` (pure):
  - units are each top-level provision's subsections (else the provision), so lists stay with their statement;
  - Schedule and Schedule-Part containers are skipped where their paragraphs or Parts are units;
  - quoted words and amending instructions ("insert—") are ignored;
  - application counts only where the law, or a part of it, applies;
  - the outcome classes are listed in its moduledoc.
- `Extent.statement/1` (new, public): what one sentence states in the reader's own terms, so the catalogue never re-implements the reader.
- `mix lat.extent_patterns` (read-only, one law at a time) and `ExtentPatternsTest`. An example is held only where its sentence reads the same in the flattened law as in the whole one.
- **Trial on 6 laws, already finding gaps:**
  - EPA 1990 s.164 ("Only the following provisions of this Act … extend to Northern Ireland") is not read, so EPA has no extent;
  - Access to Justice Act 1999 s.109 ("Sections 32 to 34 and 73(2) extend to Scotland") is unread inside the clause;
  - WSI 2013/755 ("An amendment … made by this Order has the same extent as the provision to which it relates") is not read;
  - provision-level wordings ("This section applies only to England", "Subsections (3) to (13) above do not extend to Scotland").
- Fixed while building:
  - a binding-to-`false` filter in a comprehension;
  - the self-subject test was case-sensitive, so no "These Regulations apply …" was counted.

## Catalogue run 1 (2026-10-24, Jason: "Run it"; about 25 min)

- **Size:** 3,357 laws, 2,781 sentences, 566 patterns, 986 examples, unclassified 0. 39 laws have a sentence that reads differently alone (not held). The fixtures hold no effect ids.
- **By outcome:**

  | outcome | sentences |
  |---|---|
  | default | 732 |
  | unread: in clause | 506 |
  | unread: provision extent | 472 |
  | unread: not read | 421 |
  | none (mentions) | 247 |
  | applies | 157 |
  | unread: provision application | 130 |
  | list | 84 |
  | another default | 14 |
  | unread application | 10 |
  | other provision | 5 |
  | part_not | 2 |
  | corresponds | 1 |

**Fixes by count (`Extent.read/1`; the reader's tests are 31, all passing):**
- **A, amendments' same extent:** "The amendments and repeals in Schedules 20 and 21 have the same extent as the enactments to which they refer" gives `{:same, nil, refs}`. "… made by this Act / Order" gives `["*"]`, every amendment the law makes, used only where no other list names the provision. "… made by the following provisions— …" takes the listed provisions. Never read with exceptions after it or in its subject; never "bind the Crown to the same extent", "as if".
- **B, named provisions' own extent, wherever stated:** "Sections 107 and 116A of this Act extend to Scotland only" gives `:only`; "… extend to Scotland" (with no only or also) gives `:named`, which widens a default or decides where there is none; "do not extend" gives `:not`.
  - Read only as plainly stated. Never another law's provisions ("… of that Act shall continue to extend", "the 1989 Act shall cease to extend"), a mention ("so far as they extend"), "so much of … as relates", a subject with exceptions (brackets included: "(except paragraph 12)"), or a qualified or excepted tail (", except that—", "so far as they amend—", "(apart from this section)").
- **C, list headings:** with "namely", ", and no others,", "shall extend".
- **D, a Part's own clause:** "This Part (of this Act) shall (not) extend to …" (through B).
- **H, a citation clause's list:** "These Regulations— (a) …; (b) …; and (c) extend to Scotland only".
- **Places:** "England and Wales, and Scotland" (a comma before the "and").
- **Bug found:** `from_rows/1` dropped `:not` lists, so a stored "Part III … does not extend to Scotland" read back as nothing. Fixed.
- **Catalogue diff:** 134 examples changed. All were reviewed against their text (over-reads found in review and excluded, as above) and re-accepted.

**Left as counted classes (not read):**
- provision-level application ("This section applies only to England");
- compound sentences (the second half: "Sections 28 and 33 do not extend to Scotland and sections 34 and 35 extend to Scotland only");
- a number in words ("Section twenty-three");
- Schedule paragraphs' own extent ("This Part of this Schedule shall extend to Scotland only");
- qualified or excepted extents.

## Catalogue run 2 (2026-10-24, Jason: "Run")

- **By outcome:** list 84 → 528; unread in clause 506 → 253; unread not read 421 → 322; unread provision extent 472 → 335. Unchanged: default 732, applies 157, none 247, provision application 130.
- 113 new patterns accepted; 18 no longer seen.
- **Found and fixed after the run:**
  - **EPA 1990 s.164**, the family's own: "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— …" now gives default E+W+S, and the unqualified items (Part V, s.3(5), s.141 …) also extend to Northern Ireland. "Where any enactment amended or repealed by this Act extends to any part of the United Kingdom, the amendment or repeal extends to that part" is every amendment's same extent. The repealed-text dots (". . .") no longer end the list.
  - **A provision's territorial versions** gave the same sentence twice; the second copy read as `another_default`, and both shared one example id. Each sentence is now read once per provision.
- **Code:** `fb6d8bfe` (hooks passed). The reader's tests are 32; the related suites pass (4,061).
- **Not run again yet:** the catalogue keys still show EPA's old class until the next run, which can go with the next fixes. The stored `extent_rules` are stale against the reader; they are re-read at the check step (ask first).

## The check: `mix lat.extent_check` (built 2026-10-24)

- **Amending laws** (the family's stored text changes' `by`): each law's basis as the reader reads it now (clause, lists, application, powers, competence, or none with why). Our faults: stored `extent_rules` that differ from the reading now (`stale`) or are missing (`not_stored`). Beside it: the law's own extent sentences left unread, by catalogue class.
- **Text changes** (inserted, substituted, repealed, repealed_in_part, renumbered): where the territory comes from (`territory:law`, `bound:law`, `territory:feed` / `markup`), or none and why.
- `--sample FILE --n --seed`: stratified, for the agent.
- **Dry run before the re-read:** 444 amending laws, 4,953 text changes. FAIL with our faults 75 (62 stale, 13 not stored).
  - Basis: clause 102, powers 96, competence 73, none (no powers) 61, none (type not read: EU) 60, lists 29, none (no clause) 16, application 6, not held 1.
  - Changes: bound by the law 3,383; none (law's type not read) 573; none (no powers) 524; none (provision not named) 132; not named 88; competence only 79; territory from the law 47; none (no clause) 45; no amending law 42; same 20; markup 17; feed 1.
- **A slip, mine:** the dry run fetched about 65 SI introductions from legislation.gov.uk unasked. The shared powers step re-fetches where the enabling cache parsed nothing. Fixed: the check reads the cache only, and re-reads take `--cached`. Logged as a bug (fixed).

## Re-read, rebuild, check 1, golden (2026-10-24, Jason: "Okay for all 3")

- **Restore point** `cv-s05-before-extent-reread` (`extent_rules`, `provision_changes`, `provision_change_claims`).
- `mix lat.amending --extents --cached` on the 444 family amending laws: 383 read (60 EU types aren't read, 1 not held), 42 parent Acts read first. No errors, no fetch.
- `mix lat.vocabulary --build --family "OH&S: Occupational"`: 149 laws, no errors.
- **Check (seed 5 sample): PASS, our faults 0.**
  - Basis: clause 102, powers 98, competence 73, none (EU type) 60, none (no powers) 59, lists 29, none (no clause) 16, application 6, not held 1.
  - Unread own sentences: 79 laws (66 in the clause, 66 not read, 22 other provision, 3 another default, 3 list, 1 application).
  - Text changes (4,953):

    | territory from | changes |
    |---|---|
    | bound by the law | 3,385 |
    | none: law's type not read (EU) | 573 |
    | none: no powers | 496 |
    | none: not named | 143 |
    | none: competence only (insertions, V1-04) | 79 |
    | none: same as the enactment, or not named | 69 |
    | none: provision not named | 54 |
    | territory from the law | 47 |
    | none: no clause | 45 |
    | none: no amending law | 42 |
    | markup | 17 |
    | none: law not held | 2 |
    | feed | 1 |

- **Golden 27/27.**

## Agent check, seed 5 (round 1): laws 31 OK / 15 WRONG / 4 doubtful; changes 43 OK / 7 WRONG — FAIL (16 NEW)

NEW defects. N9 and N15 were verified by me (code and stored rows); the rest are as the agent reports them, with its evidence:
- **N1:** an amending instruction's inserted words are read as the law's own application (2020/1577 reg.15 "After regulation 1 insert— … These Regulations apply to Northern Ireland"). The REACH changes then carry NI; the feed says UK. (`ApplicationClause`, via `Extent.application`)
- **N2:** an application clause inserted later (2008/2852 reg.1A, 2020) is applied to the law's own 2008 changes.
- **N3:** a list heading's body runs on into qualified items and other Acts' sections (1977/45 s.65(10)); "subsections (1), (3) … of this section" becomes s.52(3)…; "in Schedule 14, paragraph 5" becomes sch.5.
- **N4:** a list heading naming several places is never read (`@heading` takes one place): "…extend to England and Wales, Scotland and Northern Ireland—", "…also to Scotland and Northern Ireland—".
- **N5:** "Subject to …, Parts 1 to 5 extend to England and Wales only" and "extends to the same part or parts of the United Kingdom as the provision to which it relates" are unread (2006/48 s.54).
- **N6:** "This Act, which subject to subsections (8) to (10) below extends to Scotland only—" is unread (1995/36 s.105(1)), and the half-read s.105(8) bounds s.18 to E+W.
- **N7:** "the preceding provisions of this Act (including the Schedules) do not extend to Northern Ireland" is unread and uncounted (1998/8 s.16(1)).
- **N8:** named Articles, regulations and Parts in SIs are never read (`@named` knows Sections, Parts and Schedules; `parts()` collects only section ids): 2016/1142 art.1(3)–(6), 2020/1460 reg.2.
- **N9 (verified):** `Extent.to_rows/2` writes only a `none` row when there is no default, so the lists are lost in storage (2015/20, 1995/36, 2006/48, 2016/1142 stored as `none`). This also breaks powers (2015/1637's power 2015/20 s.112 reads as nothing). The check's stale test compares through `to_rows`, so it can't see it.
- **N10:** "has the same application and extent as the provision amended" is unread (2020/660), so a UK powers bound is used instead of `:same`.
- **N11:** "The following provisions of these Regulations extend to England and Wales—" is unread (2025/361).
- **N12:** RefList: "paragraphs 5, 35 … of Schedule 23" becomes s.5, s.35…; "26(7) to (10)" becomes s.26(7) only; "Parts 4 and 5 of Schedule 13" is dropped (2015/20 s.114).
- **N13:** a same-extent subject naming Parts or regulations becomes `*` ("made by Parts 4, 5 and 6"; "made by regulations 3, 4, 6, …").
- **N14:** amendments or modifications with their own extent are unread ("The amendments made by regulations 8, 12, 17 and 19 extend to England, Wales and Scotland only"); "(and article 26 …)" is stored as sch.26.
- **N15 (verified):** "This Act shall extend to Northern Ireland with the exception of— (a) … Part 1; …" (CPA 1987 s.49(1)) is stored as default **NI**, so every CPA change to HSWA (a GB Act) carries an NI bound. It must be unread (an excepted statement) or read in full.
- **N16:** `NoteDate.extent_claims` falls back to the law's default when markup names no amending provision, ignoring `feed:affecting` and same-extent lists (OSRPA 1963 changes by the Licensing Act 2003, claimed E+W, though they follow the enactment, which is GB).
- **Doubtful:** devolved Acts (asp, asc, nia) get no competence (`with_powers` applies it to SIs only). "Parts 2 and 3 do not extend to NI" with no default is left unread (2001/10).
- **Minor:** the check reports an empty clause for basis `application`; the enabling cache for 2020/1111 lists ukpga 2005/14 (result unaffected).
- **Known (K):** K1 EU ×6, K3 ×3, K5, K6, K9 ×2 (1994/3140 refer-back, 2008/396 garbled title).

## Fix round 1 (2026-10-24, Jason: "Go ahead"), code `d5cba338`

N1–N16 are fixed as logged above, with tests (the reader's tests are 44). Also fixed, found while reviewing the catalogue diff:
- **A default with exceptions after it:** read only where the exceptions are plain ("except regulation 15" becomes not there; "except for Part 1, which extends to …" and "except that section 12 extends …" become those lists; "except as otherwise provided …" means the exceptions are stated elsewhere). Otherwise unread, and never with another law's provisions.
- **Atomic place lists**, so a shorter list can't slip past the exception guard.
- **Lists:** a list inside an enumerated item ends at the parent's next item. Items are split at each provision noun, with dots removed. A qualified aside in brackets names nothing. A complement (", but otherwise this Act extends there") is no compound.
- **Never read:** "together with corresponding entries in Schedule 4"; "in so far it applies".
- **Devolved Acts** (asp, nia, anaw, asc) stating no extent take their legislature's competence.
- **Catalogue:** 100 examples changed. The risky ones (changed defaults, lists now unread) were reviewed against their text, the rest sampled; all re-accepted. The related suites pass (4,073).

## Round 2 runs (2026-10-24)

- **Catalogue run 3:** 3,357 laws, 2,778 sentences. 62 new patterns accepted, 41 no longer seen; examples reading differently 0.
  - By outcome: default 736, list 706 (was 528), unread in clause 177 (was 253), unread not read 302, provision extent 268 (was 335), none 247, applies 157, provision application 130.
- **Restore point** `cv-s05-before-round2`; re-read 383 (`--cached`, no fetch, no errors); rebuild 149.
- **First check:** PASS, but bound by the law fell from 3,385 to 2,768. **Cause, mine:** a named list blocked the enabling-powers fallback. SI 2019/758 says only "Regulation 12 and Schedule 10 extend to England and Wales and Scotland", so its other 580 changes lost their bound. Fixed (`b87027d7`): powers or competence apply wherever there is no default; a `named` list decides over an implied extent and widens only a stated default. With a test.
- **Re-read, rebuild, check (seed 6): PASS, our faults 0.**
  - Basis: clause 104, powers 95, competence 80, lists 39, application 4; none: EU 60, no powers 55, no clause 6, not held 1.
  - Unread own sentences: 67 laws (was 79).
  - Changes: bound by the law 3,369; none: EU 573, no powers 470, not named 178, same 118, competence only 79, provision not named 53, no amending law 42, no clause 24, not held 2; territory from the law 31; markup 14.
- **Golden 27/27.** Agent round 2 launched on the seed-6 sample.

## Agent check, seed 6 (round 2): laws 38 OK / 1 WRONG (K5) / 7 WRONG NEW / 4 doubtful; changes 44 OK / 6 doubtful — FAIL (11 NEW)

- **A:** "The provisions of this Act extend to England and Wales and, except as mentioned below, to Northern Ireland" is read as E+W (truth E+W+NI). And "The following provisions of Part II do not extend to NI— section 92 …" matches `@part_not` on "Part II do not extend", making all of Part II not NI (Arbitration Act 1996 s.108).
- **B:** "does not extend to Scotland or Northern Ireland": "or" isn't in the place list, so only S is subtracted (Defective Premises Act 1972 s.7(3)).
- **C:** lists are applied in stored order, so an `also` list applied before an `only` list gives nothing (Police and Justice Act 2006 s.54: s.5, Sch 3, s.38, s.41 should be E+W+S+NI).
- **D:** "This Act, except this section and the following provisions, namely— …, does not extend to Northern Ireland": `@except_list` only takes "except—" (Gas Act 1986 s.68(6)).
- **E:** `@part_not` is read only inside a default clause ("Parts 2 and 3 do not extend to Northern Ireland", SENDA 2001 s.43(12)).
- **F (verified, wider than extent):** 377 laws in the CLML store hold fragment files (`section/N`, `schedule/N`, from scoped fetches) beside the whole body. Every loader globs `**/data.xml.gz`, so the fragments' ids duplicate the body's and move document positions (TCEA 2007: Part 1 reads as s.44 only). The loaders are lat.amending, lat.commencement (+ check, patterns), change_collector, lat.vocabulary, lat.extent_* and lat.order_patterns, so the CV-S04 readers may be affected too. Also unread: "(2) The other provisions of this Act extend only to England and Wales" (a complement default).
- **G:** "this Act extends throughout the United Kingdom" isn't read (the pattern needs "extends to") (Police Act 1997 s.137(1)).
- **H:** the extent default is read from BlockAmendment words the law inserts elsewhere (uksi 2026/867 reg.2). The own-words rule was applied to application only.
- **I:** changes known only from law text (only `law_text:by`) never get an extent claim. `NoteDate.extent_claims` resolves the law from markup's cited or feed's by only (C5, C7, C31–C34).
- **J:** heading lists are parsed only in the clause provision ("The following provisions extend to the United Kingdom— a Part 1; …" in reg.3, while the clause is reg.2; uksi 2019/696).
- **K (minor):** qualified items in a parent Act's "also extend to Scotland" list (FRSA 2004 s.63(2)). No effect on powers here.
- **Minor:**
  - ukpga 2011/13: "this section and sections 157 and 158" dropped; a carve-out not applied.
  - ukpga 1996/18 s.244(4): "Sections 240 and 242 and Schedules 1 and 3 have the same extent as the provisions amended" unread (the subject isn't "amendments").
  - The check's labels `competence_only` / `provision_not_named` misstate the cause for I.
- **Known:** K1 ×5, K3, K5 ×3, K6 ×2, K8 ×2, K9 ×3, K10.

## F fixed: fragments, and the missing Schedules (2026-10-24, Jason: "The duplicates are our fault and need removing"; "Get all the schedules for the laws we need them for")

- **Measured properly:** the 377 included 260 preamble folders (the enabling cache's `made/introduction`), which repeat no ids. Fragment laws: 24 with the body (the duplicates), 33 with Schedules only, 45 with fragments only.
- **The cause is ours:** scoped LAT (#166) fetched fragments for parent Acts (2026-10-08/13). Their bodies were fetched later (2026-10-22), and the fragments were never removed.
- **Schedules fetched:** 160 laws in the OH&S scope had a body naming Schedules we didn't hold, and 2 had no body. Among the 160 are 80 family laws, 137 amending laws (3,036 changes, 938 of them made by Schedule provisions) and 64 commencing laws (12,136 commencements). `mix clml.fetch --whole` ran for 7 minutes: 161 laws now hold both. UK_uksi_2006_475 has no body on legislation.gov.uk. The rest of the store (about 1,100 laws in other families) is left for each family's turn.
- **Fix (`689c0adb`):**
  - `ClmlStore.law_docs` is the one loader: the body (else its fragments), plus the Schedules (else the schedule fragments). Never the introduction or the made version.
  - Storing a body removes the law's other fragments; storing its Schedules removes its schedule fragments.
  - A scoped law with its body held is parsed from the body, and `LatScope.cut` keeps the scope's rows. `clml.fetch` and `lat.sources` fetch the body for it, never a fragment.
  - The cut was checked against the stored LAT of all 24 scoped laws: the section rows match on every one, and only some cross-heading ids differ. In 11 laws a fragment parse had named a shared cross-heading after its own section (h.60 where the whole text gives h.59); the cut gives the whole parse's id. No re-parse was run. Tests pass (8,668).
- **Duplicates removed:** 40 laws, 116 files: the 24, plus laws where the fetch added Schedules beside schedule fragments. They're archived first in `backend/data/cache/clml-duplicate-fragments-2026-10-24.tar.gz`. 77 laws still hold fragments, each with no body, so the fragments are their only text.
- **Next:** CV-S04's check and catalogues, and CV-S05's runs, must be re-run; the readers now see Schedules and no duplicates. Ask Jason first.

## CV-S04 re-check after F (2026-10-24, Jason: "Go for it")

- **Commencement check, fresh, seed 7: PASS, our faults 0.** It matches CV-S04's final figures exactly (rows and gaps). `--fresh` re-reads only the family laws' own clauses, which come from LAT rows, not the XML.
- **Order catalogue:** no example reads differently. About 40 statements changed pattern count (mostly rules → rules+partial), with +2 orders and +2 units. Run in a worktree with the code before F (bfba7f69) and with CV-S04's own code (e5be305f), against today's store, it gives byte-identical output. So no code change caused it; it's data. That points at today's fetch, which gave several commencing laws their Schedules. Two new patterns were reviewed and accepted: an Act "insofar as not already in force" read as rules+all, and SI 1999/803's in-relation-to plus Schedule paragraphs.
- **Commencement catalogue (13 minutes):** one example reads differently: 1994/21's rules now name s.67(2)–(6), a refinement. Six patterns are gone and three are new:
  - 1991/65 and 1988/45: now read as left to orders (they were none and unread);
  - 1968/13: now `clause_date`;
  - 1971/10, "on the transfer date": now seen but unread, kept `pending` (a defined or event day, the known limit);
  - 1981/56, "Part III of that Schedule so far as relates to—": now none. This is CV-S04's own R4-N4 (a Part followed by "of Schedule" is never the Act's), so it is the counted pending class and is marked `pending`.
- **CV-S04 holds.**

## Fix round 2 (2026-10-24), code `71ca78a7`

- A, B, C, D, E, G, H, I, J are fixed as listed in agent round 2, each with a test (`extent_test.exs` "CV-S05 agent round 2", `note_date_test.exs`).
- **Also fixed:**
  - "does not extend to NI except so far as it affects other enactments": the default stands, and the amendments follow the enactments they change (`same` "*");
  - "Sections 240 and 242 … have the same extent as the provisions amended";
  - qualified list items ("with the exception of", "so much of Part 2 as", "Chapter 3 of Part 1") stay unread.
- **Found in the catalogue review and fixed:**
  - "Nothing in this Act extends to Northern Ireland" had been read as extending only there;
  - "Scotland or to Northern Ireland" and "England and Wales and to Scotland" dropped a place.
  - Bugs logged.
- **My regression, caught in the review:** run 4 lost 7 read patterns. H's own-words rule had stripped words amended into the law (Addition, Substitution), as the application rule does. Extent now strips only BlockAmendment. Run 4 also took 60 minutes because it shared the machine.
- **Catalogue run 5 (58 minutes, `--accept`):**
  - 19 examples read differently, each reviewed against its text and re-expected;
  - 27 new patterns reviewed (several from the newly held Schedules, e.g. "Paragraphs 15 to 17 extend only to England and Wales" in a Schedule: `unread:other_provision`, a counted class);
  - 10 gone, each moved to the reviewed reading.
- **Not done (open, minor):**
  - K, qualified items in a parent Act's list (no effect);
  - ukpga 2011/13, "this section and sections 157 and 158";
  - "The following have the same extent as the amendments, modifications, enactments … to which they relate" (2012/10) is unread;
  - "The relevant NCA provisions do not extend to NI" (2013/22 Sch.) reads as none.
- **Tests:** 8,709 pass.
- **Run time:** a PENDING session to reduce it is opened at Jason's request, `2026-10-24-cv-run-time.md`.
- **Restore point** `cv-s05-before-round3` (`extent_rules`, `provision_changes`, `provision_change_claims`). The re-read (cached) and the rebuild are running.


## Re-read, rebuild, check, golden (round 3, 2026-10-24)

- Re-read 383 (`--cached`, 12 min, no fetch, no errors); rebuild 149 (2 min).
- **Check, seed 8: PASS, our faults 0.**
  - Basis: clause 103, powers 97, competence 80, lists 41, application 4; none: EU 60, no powers 54, no clause 4, not held 1.
  - Unread own sentences: 72 laws (67 before: the Schedules now held add text).
  - Changes: bound by the law 3,449 (3,369 before); provision not named 0 (53 before: fix I).
- **Golden 27/27.**

## Agent check, seed 8 (round 3): laws 45 OK / 2 WRONG / 3 doubtful; changes 44 OK / 3 WRONG / 3 doubtful — FAIL (5 NEW)

The stored rows match the sample for all 50 laws. Every round-2 fix the sample reaches holds.
- **NEW-A (checked in the text):** a Westminster Act's "This Act extends to Northern Ireland." (Ministers of the Crown Act 1975 s.9(2)) is read as NI only. It adds NI to Great Britain. So uksi 2020/942's powers come out as NI; they should be E+W+S+NI.
- **NEW-B:** nisr 2018/17's application, NI, is read from reg.20(2), "… are also revoked to the extent that they apply in Northern Ireland", which is about other laws. The value is harmless here; changes 35, 37 and 38 inherit it.
- **NEW-C (checked in the code):** `of/2` halts on a `same` list, so an `only` or `named` list naming the same provision never applies. In SI 2013/602 art.1(6)–(7), sch.2 para.76 should be S (the feed agrees).
- **NEW-D (checked in the code):** the competence-only guard reads the operation from markup or law text only, so an insertion known only from the feed takes competence (nisr 2006/205, change 45).
- **NEW-E:** a default "subject to paragraphs (2) to (5)" is applied where the paragraph it defers to is unread (SI 2014/469 art.3(5), "same extent as the provisions which they amend, except that—"). The change should follow the enactment (GB).
- **NEW-F (data):** ukpga 2004/17 and 1978/44 are stored in their repealed version, every section dotted out, so their extent words as made are lost.
- **NEW-G (minor):** "This Act, except sections …, extends to Scotland only" (LG(S)A 1973 s.238(3)) is unread.
- **Outside the sample:**
  - HSCA 2012 s.308(3)(f): the bracketed "(Part 7: consequential provision etc.)" is read as naming Part 7;
  - LRRA 2006 s.34(3), "The repeals in the Schedule have the same extent …", is stored as `*`, not the Schedule.
- **Cosmetic:** the check's label `not_named` for a provision in a `same` list.
- **Known:** P1 ×4, P2 ×5.

## Fix round 3 (2026-10-24/25, Jason: "Go start"), code `1492a41b`

- **A:** an Act of the UK Parliament that "extends to Northern Ireland" (no "only") extends to the UK. `statement/2` takes the law's type, so the catalogue reads the sentence the same way as the law.
- **B:** "to the extent that they apply in …" is never the law's own application.
- **C:** an `only` or `named` list beats a `same` (or `unread`) list for the provisions it names.
- **D:** the competence guard reads the feed's operation too.
- **E:** "same extent …, except that the amendments made by paragraphs X of that Schedule extend to P only" is read: same, plus those paragraphs only there. Any other exception gives a new list kind, `unread`: the provisions' extent is unknown, never the default. It is stored and read back.
- **Outside the sample:** a bracketed description never names a Part (HSCA 2012).
- **Found in the catalogue review and fixed:**
  - The subject "this Act" never follows "to ". "Schedule 17 to this Act shall extend to NI" had been read as the Act's default (NI); it now reads correctly, and "… and save as aforesaid this Act shall not extend to NI" gives E+W+S.
  - "extends only to", "as well as to", "except for—" and "that is to say—" are now read; "so much of" items stay unread.
- **Not done:**
  - LRRA 2006: the unnumbered Schedule has no ref (`Order.ref("schedule")` is nil), so "the repeals in the Schedule" stays `*`;
  - NEW-F, repealed laws stored in their repealed version: a data limit, counted;
  - NEW-G, "This Act, except sections …, extends to Scotland only".
- **Catalogue run 6 (66 minutes, `--accept`):** 38 examples re-read, each among the 46 reviewed against their text; 14 new patterns reviewed; 27 gone. Tests: 8,699 pass.
- **CV-S04 is not affected:** the commencement readers don't use `AmendingLaw.Extent`, so their catalogues weren't re-run.
- **Restore point** `cv-s05-before-round4`. The re-read and the rebuild are running.

## Round 4 runs and agent check, seed 9 (2026-10-25)

- Re-read 383 (12 min, no fetch, no errors); rebuild 149 (2 min).
- **Check: PASS, our faults 0.**
  - Bound by the law fell from 3,449 to 3,184. This is intended: 184 changes under the three `unread` lists (SI 2014/469 Sch.3, Energy Act 2013 Sch.12, SI 2013/602 Sch.1) no longer take the default (E), and about 98 feed-only insertions are no longer confined by competence (D).
- **Golden 27/27.**
- **Agent check: laws 44 OK / 6 WRONG; changes 49 OK / 1 WRONG — FAIL (5 NEW).** The stored rows and claims match the sample.
  - **N-A:** "Any amendment or revocation made by the provisions in Parts 2 and 3 has the same extent as the provision amended" is unread (uksi 2023/1071 reg.1(2)). Change a7393c takes the enabling powers' E+W+S+NI instead.
  - **N-B:** same-extent wordings unread, and not counted as unread:
    - "has the same extent within the United Kingdom as …" (REUL 2023 s.23(2));
    - "Except as provided by subsections (2) and (3), a repeal, revocation or other amendment … has the same extent as …" (Deregulation Act 2015 s.114(1));
    - "an amendment … extends to the part or parts of the United Kingdom to which the enactment extends" (CJA 2009 s.181(6)).
  - **N-C:** lettered statements under a lead-in are unread and uncounted:
    - "In Part 5— (a) sections 220 to 224 extend to England and Wales only; …" (CPA 2004 s.262(4));
    - "Part 3 extends to …, except as follows— (a) …" and "Part 5 extends as follows— (a) …" (ERRA 2013 s.102).
  - **N-D:** a sentence's second clause is dropped: "Paragraphs 34 and 35 … extend to England and Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland only" (CJA 2009 s.181(5)).
  - **N-E (minor):** a number in words, "section seventy-seven", is unread (Factories Act 1961 s.185(3)), and an empty `also` list is stored.
  - **Known:** P1–P7.

## Fix round 4 (2026-10-25, Jason: "Do 1"), code `c2532fe6`

- **N-A, N-B:** the same-extent wordings are read: "made by the provisions in Parts 2 and 3"; the leads "Except as provided by / set out in / mentioned in …"; "or other amendment"; "the same extent within the United Kingdom as"; "extends to the part or parts of the United Kingdom to which the enactment extends".
- **N-C, N-D:** `Extent.statements/1` gives a sentence's own statements: each lettered item under a lead-in, and a compound's second clause (with "that Schedule" named).
- **N-E:** an exception that isn't parsed gives no list (no empty `also`).
- **The counting gap:** the catalogue now counts the wider same-extent, "extends throughout" and "extends as follows" wordings, so unread ones are seen and counted.
- **Found in run 7 and fixed:** "Regulations under this section may extend throughout England and Wales …" had been read as a named list since round 3 (G). I missed it in the run 6 review. A modal "may" or "under this" statement is never the law's own.
- **Catalogue run 7 (62 minutes, `--accept`):** 10 new patterns reviewed; 4 examples read differently, then 10 after the fix above, each reviewed against its text.
  - Remaining unread forms, counted:
    - "A provision of this Act which amends … has the same extent within the United Kingdom as …, subject to subsections (6) to (9)" (2022/32);
    - "These Regulations extend as follows." (2019/837);
    - "Any amendment … of an enactment which does not extend throughout the United Kingdom shall extend only to the part …" (1983/29).
  - The pattern keys of the 10 examples re-read after the run stay as run 7 wrote them until the next catalogue run; only their expectations were updated. Tests: 8,717 pass.
- **Restore point** `cv-s05-before-round5`. The re-read and the rebuild are running.

## Round 5 runs and agent check, seed 10 (2026-10-25)

- Re-read and rebuild, then a check: PASS, but one law had moved from powers to no powers. **My regression from round 4:** REUL 2023's new `same *` list was applied to its enabling sections, so uksi 2025/82 lost its powers. Fixed (`61cf4177`): an SI's powers ignore a parent's every-amendment lists. Re-read, rebuild, check again.
- **Check, seed 10: PASS, our faults 0.** Basis: powers 99 (96 before), no powers 52, lists 41. Bound by the law 3,183.
- **Golden 27/27** (after the second rebuild).
- **Agent check: laws 41 OK / 7 WRONG / 2 doubtful; changes 44 OK / 3 WRONG / 3 doubtful — FAIL (8 NEW).**
  - **NEW-A (mine, round 3):** the "Chapter N of Part M" stripping drops real list items: Energy Act 2013 s.155(2)(b) Chapters of Part 2; CJA 2009 s.181(3)(h)–(i).
  - **NEW-B:** a compound's first clause is dropped and not counted: "Any amendment or repeal … of an enactment which extends to Scotland or Northern Ireland has the same extent as that enactment but, save as aforesaid, this Act extends to England and Wales only" (1985/51 s.106(2)).
  - **NEW-C:** a section named inside a bracketed description, "(amendment to section 24A of the Nuclear Installations Act 1965 …)", is read as a list item: s.24A, which Energy Act 2013 doesn't have.
  - **NEW-D:** "extends to any part of the United Kingdom to which the amended enactment extends" is unread and uncounted (uksi 2012/2404 reg.4(2)).
  - **NEW-E:** "… but except as aforesaid this Act shall not extend there" is unread (ukpga 1975/71 s.129(6)), so two sampled HSWA changes get no bound.
  - **NEW-F:** a parent's lettered places, "This Part shall extend to— (a) England and Wales, and (b) Scotland, and (c) Northern Ireland" (RTSA 2003 s.17), are unread, so uksi 2015/1682 has no powers.
  - **NEW-G (doubtful):** "Section 98 and Schedule 15 apply to England and Wales and Scotland" inside the extent section.
  - **NEW-H:** "Amendments, repeals and revocations in this Order have the same extent as the provisions amended, repealed or revoked" is unread (no effect on claims).
  - **Outside the sample:**
    - uksi 2019/696 reg.3(c): a list's exceptions are stored as its items, and Part 5 itself is missing;
    - "In Schedule N— (a) paragraph X extends to …" is unread (2019/758, 2014/469);
    - 2022/1037 "Part 3 and Part 4" keeps Part 3 only;
    - 2009/20 s.147(1), "Parts 1 to 7 … except that—", stores nothing and is uncounted.
- **The trend:** NEW per round is 16, 11, 5, 5, 8. Three of the defects found since round 3 are regressions from my own fixes ("may extend", powers, Chapter of Part). Most of the rest are statements the reader skips silently: neither read nor counted.

## Suspended (2026-10-25)

Jason: "Let's suspend and sort out run time." Each fix round's runs cost about 2½ hours: catalogue ~60 min, re-read 12, rebuild 2, check 30, golden 6. Resume after `2026-10-24-cv-run-time.md`, from the round-6 todo.

State at suspension:
- code `61cf4177`;
- stored readings from round 5's second re-read and rebuild;
- check PASS, our faults 0; golden 27/27;
- agent round 5 FAIL (8 NEW).
- Restore points: `cv-s05-before-round3` to `cv-s05-before-round5`.
- Nothing pushed since `e5be305f`.

## Resumed (2026-10-25)

- The run-time session is closed (`2026-10-24-cv-run-time.md`). A round's runs now take about 10 minutes:
  - extent catalogue: 5 min cold, seconds warm (`Extent.ReadCache`);
  - re-read: seconds;
  - rebuild: ~1 min;
  - check: seconds;
  - golden: ~2.6 min.
- Its amendment read pass (rules 37,719 → 41,435, every difference traced to the fuller store) exposed two defects; they come first, see the todo above.
- **Golden is now 26/27** (RTA 1988 s.4(6)).
- Round 6 still needs Jason's go-ahead on its step 1.


## The two exposed defects (2026-10-25)

- **SOCPA's Royal Assent (golden 26/27).** `LawStart.Clause`'s fallback for a law with no whole-law clause (`own_parts`) took the first sentence naming a part's commencement, mentions included: SOCPA's s.101(2) ("… taken before this section comes into force") came before s.178, so SOCPA had no clause and fell to Royal Assent, and the vocabulary's amending-law reader (which keeps an Act's Royal Assent rule, CV-S04: "an Act with a clause has the clause's rule") dated Sch.7 para 27(2)'s repeal 2005-04-07.
  - Fix: `own_parts` skips mentions; for an Act it also skips a section commencing itself alone ("This section shall come into force on 1st April 1982": Finance Act 1981 s.137(4) set the Act's start), keeping "This section and sections 62, 63 and 65 …" (asp 2024/14, an Act's first stage) and "… but otherwise this Act comes into force … by order" (ukpga 1992/34).
  - SOCPA now: `clause_staged` 2005-04-07 (s.178(1)), every s.178 group, the rest by order (s.178(8)). Re-read alone (12 rules); RTA 1988 golden passes.
  - 21 commencement catalogue examples change, all reviewed: five Acts move from Royal Assent to their staged clause (same date); mentions stop standing as clauses (anaw 2015/4 s.1(12), NISR 2007/321 reg.42(1), Finance Act 1974 s.46(5)); three Finance Acts' "deemed to have come into force" or lone-section dates give way to Royal Assent. Finance Act 1982 stays unread (s.151(2)'s "three months beginning with …" not computed; its fixture holds no metadata head).
- **Localism read as FRSA.** `DefinedTerms` kept "fire and rescue authority" (= "a fire and rescue authority under the Fire and Rescue Services Act 2004") as a term meaning a law, so the caption in para 94(2) "named" FRSA before para 94(1)'s Localism Act was reached. Fix: a term means a law only when its definition is the title itself. PCA's other false terms (collaboration agreement, metropolitan police district, museum firearms licence, park trading offence, articles of war of 1876) go too. Para 94 now reads as the Localism Act 2011's.
- Found on the way (open, logged): "In section 43(1) …— (a) … paragraph (h)" targets s.43(h).
- Full suite: only the 21 reviewed catalogue examples fail, pending `--accept`.

## Runs after the fixes (2026-10-25, Jason: "Run")

- Restore point `cv-s05-before-exposed-fixes` (commencement_rules, amendment_rules, provision_changes); amendment indexes copied to the scratchpad.
- **Commencement catalogue** (`--accept`, 6 min 16 s): 12 new patterns accepted, 17 gone, 0 unclassified; 20 example readings updated by hand after review (`--accept` keeps changed expectations). Committed `65bf8b34`.
- **Own clauses re-read:** 45 laws' starts changed. Finance Acts' deemed or lone-section dates → Royal Assent; Acts → their real staged clause (Scottish, Welsh, NI: the day after Royal Assent); mentions gone. The re-read exposed CJPA 2001 (2001-07-11) and LGA 1963 (1965-04-01): staged clauses leaving provisions to Royal Assent, dated by their first stage. Fixed (`9c28b1ad`, Royal Assent floor, UK Acts only after a first try misdated three devolved Acts), re-read again: no errors.
- Label timelines (law starts changed for LAT laws) are not refreshed: a later relabel.
- **Amendment read pass** (35 min; SI 2019/696 alone the last ~9 min; peak 1.8 GB): rules 41,435 → 41,581, 13 laws changed, each traced to the term fix. Additions where a caption's false term had blocked the named law (e.g. ukpga 1994/39 +64); PCA 2017 para 94 → Localism Act; SI 2009/1941 para 76 → Insolvency Act 1986 ("unregistered company" had read Companies Act 2006); ukpga 1995/23 Sch.5 para 5 no longer read as RTA 1988 (it amends 1995/23 itself); Planning Act 2008 Sch.7 → TCPA 1990 / Listed Buildings Act (had read TCP (Scotland) Act 1997 through "local planning authority").
- **Exposed:** Planning Act 2008 s.174/175 ("TCPA 1990 is amended as follows") then read nothing: "TCPA 1990 … means the Town and Country Planning Act 1990 (c. 8)" failed the title test on its chapter. Fixed `5d404342` (chapter stripped; "set out in", "article N of" are things under a law). A text search finds 241 amending laws with definitions in these forms; `ReaderVersion` hashes `defined_terms.ex`, so all 2,102 indexes are stale again (builds fall back to parsing, correct but slow).

## Suspended again (2026-10-25)

Jason: "suspend the session and make the unclosed/suspended runtime session active again". The run-time work left the amendment read pass slow (35 min for a fix touching ~241 laws), and every `DefinedTerms` fix stales all 2,102 indexes.

State at suspension:
- code `5d404342` (all tests pass); nothing pushed since `d1d26d75` — another lane is fixing GitHub CI, so any push is to be named to Jason first;
- own commencement clauses re-read (after `9c28b1ad`); commencement catalogue accepted;
- amendment rules from the read pass before `5d404342`; all amendment indexes stale against `5d404342`;
- stored changes not rebuilt; golden not re-run (RTA 1988 s.4(6) passes alone);
- restore point `cv-s05-before-exposed-fixes`.

On resume: re-read the affected amending laws (with the incremental read if built), rebuild, golden; then round 6.

## Reader correctness found during the run-time session (moved here 2026-10-26)

The run-time session's full read passes changed rules and exposed reader defects; their tracing and the fixes belong to this session (Jason 2026-10-26: "the reader correctness work should be moved into cv-s05"). The passes' timings stay in `2026-10-24-cv-run-time.md`.

### Pass 3 (2026-10-25, 7 min 19 s)

- Rules 41,581 → 42,270; 17 laws changed, all from the definition fixes (`5d404342`): abbreviations with a chapter now read — Local Transport Act 2008 → Transport Act 2000 (+191), Railways Act 2005 → Railways Act 1993 (+219), Energy Act 2004 → Electricity Act 1989 (+77), GLA Act 2007 → GLA Act 1999 (+135), Planning (Wales) Act 2015 → TCPA 1990 (+68, was the Hazardous Substances Act), Employment Relations Act 2004 → TULRCA 1992 (+119, was ERA 1996), Planning Act 2008 → TCPA 1990.
- **Exposed, fixed:** asp 2011/6 (WANE) lost 344 rules — its definitions list ends items with "," ("…Act 1981 (c.69),"), so only the last term was read and every 1981 Act instruction went to the 2004 Act (before, with no terms, to all three laws). `DefinedTerms` now ends a definition at ";", "." or "," (each perhaps with "and"/"or").
- **Removed rightly:** PSTI 2022 (ukpga 2022/46) −17 against the Communications Act 2003: "paragraph 3", "paragraph 4" of the electronic communications code (Sch. 3A) had been placed on CA 2003 ss.2, 4, 17A — false changes on real sections.

### Read pass 4 of today (2026-10-25, Jason: "Run it") and what it exposed

- **7 min 14 s**, 2,102 laws, 0 errors, peak 2.1 GB. Rules 42,270 → 42,561; 18 laws, traced: the list-comma fix (`81016a36`) put WANE (asp 2011/6) on the Wildlife and Countryside Act 1981 (127) and the Badgers Act 1992 (23); Water Act 2003 → Water Industry / Water Resources Acts 1991; NC(S)A 2004 → WCA 1981; Scottish Acts → Civic Government (Scotland) Act 1982; SSI 2004/332's rules leave the Listed Buildings (Scotland) Act for "the 1997 Act" (TCP (Scotland) Act 1997, not offered for that SSI).
- **Exposed, fixed `8b3026bd`:** SI 2019/598 regs 6–7 (2 rules) lost. "For regulation 24 substitute—" sits in Part 3 "Amendment to the 2009 Regulations", but `Doc` kept only a provision's deepest heading, so the reader walked back into Part 2 and met "the 2008 Regulations" (newly recognised: its definition ends "; and"); before, it reached the definitions sentence naming all three laws and got the 2009 Regulations by luck. `Doc.headings/2` keeps every container's title, nearest first; the reader checks them all before the text before. Reg 7 now reads the 2009 Regulations.
- Pattern: each definitions fix exposes a reader shortcut that luck had covered; each pass's diff is traced per law before accepting.

### Read pass 5 of today (2026-10-25, Jason: "Run it") and the heading work

- **7 min 20 s**, 2,102 laws, 0 errors. Rules 42,561 → 42,534; SI 2019/598 regained its 2 rules, but **my heading rule was too strong**: SI 2019/453 lost 69 (its Part "Amendments pursuant to the European Communities Act 1972" names the enabling Act and beat "The Transport Act 1968 is amended …" earlier in the Part).
- Fixed: structural nearness in `Text.before` — earlier provisions in the Part, then the Part's headings, then earlier Parts (a Schedule: its earlier paragraphs, its headings, then the body naming it). The reader passes only the nearest heading again.
- Exposed and fixed: titles garbled by xmerl's `//text()` order ("etc.The Building (Approved Inspectors ) Regulations 2010", WSI 2013/747 −5; "EnforcementAmendment of the REACH Regulations 2008", SI 2019/758) — `Doc` titles now read in document order (an old LR-31 zero-diff choice kept the garbling).
- Exposed: SI 2019/758 Sch. 3 ("Amendment of the Annexes and Appendices to the REACH Regulation") read Annex paragraphs as REACH Articles 1, 2(7), 4, 8 — false changes on real Articles. Held back: no Article rules under an Annex/Appendix heading until Annex targets are read (open todo).
- 13 changed laws re-read against the rules before the heading work: 7 differ, all checked right — gains by Part/Schedule headings (asp 2024/15 → CC(S)A 2009; ukpga 1972/70 Sch. 24 → TA 1968; ukpga 2026/6 → MCAA 2009; SI 2019/598 → the 2009 Regulations; SI 2019/758 para 61 → REACH Title 10) and corrections (ukpga 1994/39 → Sewerage (Scotland) Act 1968 / Water (Scotland) Act 1980, not LGFA 1992; SI 2019/544 off a 2011 SI).

### End-of-round pass (2026-10-25, Jason: "implement the plan"), and the "etc." fix

- Read pass with largest-first and the guard's own measure (0.8 GB a law, max 5): **7 min 19 s**, still 4 workers (1.1 cores busy at start → 6 − 2); peak 3.25 GB (largest laws together). Report: 6 laws changed, rules 42,576 → 42,591 — the first report printed by the pass itself.
- Traced: SI 2009/229 and WSI 2016/413 right (cross-headings naming the amended Act); SI 2013/283 and SI 2016/912 **wrong** — "The Maternity and Parental Leave etc. Regulations 1999", "(Licensing etc.) Regulations 2010": the title pattern stopped at the "." of "etc.", so an "etc." title named no law (hidden until the title fix by luck).
- Fixed: one title pattern in the reader allowing "etc." (and in DefinedTerms' apposition). Regression preview: 41 of 258 laws change, rules 21,893 → 22,030 — HSWA ("Health and Safety at Work etc. Act 1974"), the Local Government etc. (Scotland) Act 1994 and the Water Services etc. (Scotland) Act 2005 now named; moves checked (ERRA 2013 s.69 → HSWA s.47; Environment Act 1995 HSWA paragraphs off COPA 1974; the Approved Inspectors Regulations are SI 2010/2215, not 2010/2214 the Building Regulations — the earlier "+6" was itself wrong).
- Open: Environment Act 1995 Sch. 22 para 30 now reads nothing for HSWA (todo).

### Caption and nested-quote fixes (2026-10-25, Jason: "Carry on")

- First try (`asides/1` on the texts searched for a law) was too blunt: regression preview 52 changed with net losses — `asides` keeps a bracket only right before "Act/Regulations/…", so a title with two bracketed parts ("The Environmental Protection (Disposal of …) (England and Wales) Regulations 2000") lost its first and named nothing. Caught by the preview, never written.
- Fix: `Clauses.uncaptioned/1` drops only the bracket right after a provision reference ("section 1 (…)", "regulation 2(1) (…)"); `unquote_words/1` strips nested quotes innermost first.
- Previews: the two laws as intended; regression 29 changed, net +78 — moves to the Act the text amends (WSI 2025/1320's 20 rules to the Wales 2024 Regulations its context names; SI 2009/1941 off the Insolvency Act 1986); losses checked (each caption had named another Act).
- The preview workflow paid for itself: the blunt version would have been a full write pass and a revert.
- ✅ End of this round: full write pass (Jason: "Run the pass and push"; restore point `run-time-before-read-pass-8`): **6 min 58 s** (writes; the preview is 4.5), 2,102 laws, 52 changed, rules 43,548 → 43,778 (+230); 2 pure losses, both checked (captions naming the Scotland Act 1998, the Electricity Act 1989); the rest moves to the Act amended (Enterprise Act 2002 Sch. 25 → Railways Act 1993, Gas Act 1986; laws off the Enterprise Act its captions named) and gains (Employment Rights Act 2025 Sch. 12 +31 on ERA 1996). Every index fresh.

### The 202 stale laws (2026-10-26, Jason: "Push then start 1")

- Pushed first: `04a761e7..a00838f7` (16 commits; Dialyzer caught `String.Extent.t()` — my step 10 text replacement — fixed `a00838f7`).
- Corpus-wide diff of stored `extent_rules` against the reading now (`with_powers`, enabling cache only): **483 of 2,050 laws differ — 307 lack the `competence` row, 175 the `powers` row, 1 (`UK_ukpga_1995_15`) stored `none` against a default E+W+S now** (its rows date from 2026-10-22, before CV-S05's reader fixes; no pass since reached it).
- Cause: `ReadPass.write` stored `Extent.read(doc)` bare (since CV-04, `46d2b13a`), as did `--extents`' parents step; only `--extents`' own laws were stored with powers. Each full read pass (3 on 2026-10-25) wiped them. The build then reads such an SI's changes as unknown territory, not its powers' reach.
- Fix `1a4626b8`: `Extent.Store.write_read/3`, the one writer (with powers or competence; the read pass passes `cached: true`, never a fetch); `Store.write` private; `ExtentWriteTest` holds it (it also caught `lat.vocabulary`'s alias, a different store — the test follows aliases). Suite 8,826 + store test pass.
- Repair (2026-10-26, Jason: "do the repair"): restore point `run-time-before-extent-repair` (`extent_rules`); `mix lat.amending --extents --amending <483> --cached` — 1 min 28 s, 49 parent Acts first. **OH&S extent check: our faults 0, PASS** (was 202 stale).
- Basis shifted in the check: powers 97 → 106, competence 82 → 73 — SSIs (and WSI 2020/1211) under devolved parent Acts: those parents were stored without their competence row, so the SI's powers didn't resolve and it fell back to competence; same territory (S, E+W), now by powers.
- Still to come: provision_changes take the territories at CV-S05's rebuild (its resume step).

### Todo 1 deferred, todo 2 fixed (2026-10-26, Jason: "Push then start 1")

- Pushed `a00838f7..ef1b4ac9` (3 commits).
- Annex/Schedule targets deferred (Jason): LAT holds no Schedule or Annex rows (LR-10), so the rules would reach nothing.
- Environment Act 1995 Sch. 22 para 30: traced to `DefinedTerms.apposition/2` — the title pattern allowed only "and/of/the/for/etc." inside a title, so "Health and Safety at Work etc. Act 1974" became "Work etc. Act 1974"; the context's "the 1974 Act" was then the nearest law-naming words, and named nothing. Fixed `407df2c2` (at, to, by, in, on; a bracketed part). Regression preview 1 min 52 s: 274 laws, 2 changed (both checked right). Para 30's targets show three precision limits of the reader (logged, open).

### Round: target precision, full pass, golden (2026-10-26, Jason: "do 1 through 3")

- Fixes `2c1bf0b0` (tests from 1995/25 Sch. 22 para 30, asc 2023/4 s.47, 1994/19, 2013/22, 2009/20, 1999/28, SI 2015/664). Regression previews iterated 6 times (each ~2 min, nothing written) as the target diffs were classified; two of my own overshoots were caught there (a guard on the provision's first words only; a second bracket filter).
- Full pass: **7 min 49 s, 2,102 laws, 635 changed, rules 43,778 → 42,335 (−1,443)**. Old rules loaded from the restore point (`rp9` schema) and diffed by class: 9,479 refined (parents' brackets added); 1,216 to a different provision — 878 new number in the words not the old, 322 old number only in a caption, 16 both, 0 otherwise; 1,382 groups gone — 1,365 under a Schedule (paragraphs read as sections), 17 others checked (an Order's article read as an Act's caption section; Schedule A1 paragraphs; words-level now; one existing law-naming flaw, logged). Every index fresh.
- Golden first **crashed**: `Extent.Rows.from_rows/1` (my decomposition) used `String.to_existing_atom` — atoms present only once `Extent` was loaded, which the gate always did. Fixed (kinds by name); **golden 27/27**.
- Golden's "N amending laws read from their text (stored rules stale)" counts laws never indexed (HSWA: 46 text not held, 29 held with no text-change pointer), not stale ones — wording only.


## Resumed (2026-10-26): rebuild, golden, check

- The run-time session is closed: a full read pass takes ~6 min and writes only what changed. The precision round's rules (42,335) and the repaired `extent_rules` are stored.
- Restore point `cv-s05-before-resume-rebuild` (`provision_changes`, `provision_change_claims`).
- **Rebuild and golden** (`mix lat.vocabulary --check --family "OH&S: Occupational"`): 3 min, run one law at a time because a VM was running. 149 laws; conflicts 2,663 uncovered primary, 641 unread, 84 uncovered derived, 64 unjoined, values 59 level / 19 date / 11 operation. **Golden 27/27.**
  - 30 laws read a parent's extent from CLML (not in `extent_rules`; NI Orders and similar). The result is correct, only slower.
- **Extent check: PASS, our faults 0.** 69 laws have unread extent sentences, all counted. Of 4,993 text changes, 3,215 are bound by the law and 1,742 have no territory, each by a counted reason.
- Next: round 6. Its step 1 is a design change and needs Jason's go-ahead.

## Round 6 step 1: never drop a statement silently (2026-10-26, Jason: "go ahead"), code `1085611f`

- **Measured first:** 55 laws amending OH&S law, behind 1,336 bound changes, had 152 extent sentences left unread. They fell into three kinds: real statements about named provisions; whole-law qualified statements; and noise (words quoted inside amendments, mentions, "to the same extent as" idioms).
- **`Extent.Unread`:** a sentence in an unread class (the catalogue's) withholds its subject's bound, `{:unread, nil, refs}` (Lookup → nil, never the default).
  - **What the subject can be:**
    - named provisions ("Subsections (5) to (7) above" → s.5(5)–(7));
    - a following list's items;
    - "In Schedule N— (a) paragraphs …" → that Schedule's paragraphs;
    - a Schedule paragraph's own statement → the paragraph;
    - "This Part of this Schedule" → the Schedule;
    - the law or its amendments → `*`.
  - **What it ignores:** the law's own words only, so never words it inserts; mentions; idioms; another law's provisions; a list item's pronoun (the lead-in's subject).
  - **Rules:** when unsure, the wider container. Lookup applies an unread statement first. `ReadCache` carries the bounds. The check counts `none:unread_statement`. Tests: `extent/unread_test.exs` (10, from real sentences).
- **Runs:**
  - The catalogue is identical to the baseline (classes unchanged, 0 examples differ).
  - Restore point `cv-s05-before-round6-unread` (`extent_rules`). Extents rewritten corpus-wide (`--cached`): 252 laws carry 451 withheld-bound rows (11 before).
  - Rebuild; **golden 27/27**; **check PASS, our faults 0**. Suite 8,855 pass.
- **Bound changes 3,215 → 3,086 (−129), each traced:**
  - **Whole-law statements unread:**
    - SI 2005/1082, 40 ("To the extent that these Regulations concern the importation …");
    - SI 2020/1112, 28 ("These Regulations— … (c) extend to Northern Ireland only");
    - SI 2025/82, 15 ("… same extent as the enactment … unless otherwise specified");
    - ukpga 2002/30, 10 (two defaults in s.108);
    - 2005/11 s.56, 2020/29 s.40, 1998/31 s.145.
  - **Named provisions:** 1989/38 s.30, 1998/8 s.16, 1995/36 s.105, 2017/3 s.182, 1994/29 s.96, 1989/15 s.194, SI 2014/469, SI 2010/93, SI 2008/2683.
  - **Through a parent's powers (all or nothing):**
    - Public Expenditure and Receipts Act 1968 s.5 ("shall extend to Northern Ireland in so far as it affects— …"): 9 SIs lose their powers, and 3 SSIs fall to competence (E+W+S → S);
    - ukpga 2015/15 s.99 ("Chapter 3 of this Part"): the whole Part is withheld because of NEW-A, so uksi 2015/1630 loses 4. Step 2 narrows it.
  - Caught on the way and fixed before commit:
    - "In Schedule 11— (a) paragraph 2" read as Schedules 11 and 2 (SI 2019/758 lost a Sch. 2 change);
    - "except that— (a) it does not extend to Scotland" read as the whole law (ukpga 2007/27).
- **Forms step 3 could read, now visible as withheld:** "These Regulations— … (c) extend to …"; "A provision … that amends … has the same extent as the enactment … unless otherwise specified"; "paragraph 8(2)(b) to (d)" (only (b) named, so (c) and (d) are bound by the default).

## Round 6 step 2: misreads (2026-10-26, Jason: "go ahead"), code `a79b5c36`

- **Extent reader:**
  - **NEW-A:** Chapters are read as their sections (`Parts.parts`): "Chapter N of Part M", "of this Part", and a bare Chapter after "in Part M—" or "that Part" (`Parts.qualify_chapters`, applied before a list is split). An item's "(except section 84)" is taken out of it. A description ("the service courts provisions of Chapter 2") is never the whole Chapter. Named subjects may start "Chapter".
    - Gains: ukpga 2015/15 s.99 (Chapter 3 E+W; uksi 2015/1630 regains its powers, +4); SI 2013/1506 reg.3(2) Chapter 3 of Part 3 → NI (22 changes E+W+S → UK); 2008/32 s.112(3); 1993/28 s.188(5); Energy Act 2013 s.155(2)(b).
  - **NEW-C:** no provision named inside a bracketed description ("paragraph 25 (amendment to section 24A of the NIA 1965 …)" no longer gives s.24A).
  - **SI 2019/696 reg.3(c):** "Part 5 …, except— (i) …" now takes the sub-list out of the item (`{:except}` → `{:not, place − default}` in `Extent.read`), instead of storing the exceptions as the list's items. Sch. 35 para 2 changes: UK → E+W+S (correct). 1996/53 s.148(3) is read the same way.
  - **SI 2022/1037:** every Part named ("Part 3 and Part 4").
  - **Catalogue:** examples keep Chapter shells. 5 sentences unread → read, none the reverse; 2 example expectations updated after review; 5 stale statuses with no pattern dropped by `--accept`.
- **Amendment reader:**
  - **SI 2026/386 Sch. 3 para 6(5)–(6):** a caption after run-on brackets ("paragraph 15(b) and (f) (… Data Protection Act 2018)") names no law. +10 rules on PEC regs 32 and 33. 6(3) "listed in sub-paragraph (4)" now yields no rule (not a wrong one); resolving the cross-reference is left open.
  - **Exposed by the step-2 rebuild:** the build re-reads stale amending laws, offering only the law built, and SI 2019/720 / 2019/696 lost rules. Traced: the stored rules were **wrong**. "Regulation (EU) No 649/2012 is amended as follows" named no law, so the walk back reached COSHH 2002 (Sch. 2 para 168 "After Article 23, insert—" → COSHH regs 1–7), and Sch. 35 para 3 (the PPE Regulation's Articles) reached IRR 2017.
    - Fixed with `Reader.EuCitation`: EU Regulations, Directives and Decisions by number name the law where they are what's amended ("… is amended", "In Regulation …", "Amendment of Regulation …"), never a passing mention. A first, ungated version stopped walks at "for the purpose of complying with Council Directive …" (SI 1996/1974 −93, SI 2020/1369 −88); caught in the regression preview, never written.
    - Also: a closing quote with no opener ends quoted words back to the dash (SI 2019/696 Sch. 29 para 2's inserted definition had named EU laws).
  - **Regression preview:** 6 laws change, all checked: +105 SI 2019/453 on the tachograph Regulation 165/2014; +193 SI 2019/696 on Regulation 2016/425 (−15 IRR 2017); +4 ukpga 2020/29; SI 2022/1393 and SI 2024/504 Radio Equipment Regs → Regulation 2016/425 (both amend it); +10 SI 2026/386. Plus SI 2019/720: −8 COSHH, +229 Regulation 649/2012. Three laws added to the regression list.
- **Runs:** restore point `cv-s05-before-round6-step2` (extent_rules, provision_changes, claims). Extents rewritten; rebuild; **golden 27/27**; **check PASS, our faults 0**; bound 3,086 → 3,067, each shift traced (above, plus SI 2019/720 / 2019/696's false rules dropped by the build's re-read).
- Suite 8,868 pass.
- **Still to come:** the round's one full read pass (the amendment reader changed, so all indexes are stale), then rebuild, check and golden.

### Round 6 full read pass (2026-10-26, Jason: "go ahead"), code `a779f5c3`

- Restore point `run-cv-s05-r6-read-pass` (amendment_rules, extent_rules); rules snapshot `r6b.rules_before`.
- **5 min 56 s, 2,102 laws, 26 changed, rules 42,335 → 43,518**, traced:
  - **EU laws named as the law amended (pure gains):** the tachograph Regulations (SI 2019/453, 2021/135, 2022/1260, 2023/739, 2025/402), REACH and CLP (SI 2019/556, 2021/904, 2023/1344, 2025/361, 2026/195), PIC (SI 2019/720 +229, SI 2022/1037), PPE (SI 2019/696 +193, ukpga 2020/29), 2015/2066–2067 (SI 2019/583), 2012/965.
  - **Moves, all corrections:**
    - SI 2020/1482: 61 off the England plant-health SI onto Regulation 2016/2031 (+624);
    - SI 2019/696: 15 off IRR 2017, and 2 Radio Equipment → PPE Regulation;
    - SI 2022/1393, SI 2024/504: Radio Equipment → PPE Regulation;
    - ukpga 2015/26 s.135(3): IA 1986 → Enterprise Act 2002 (the run-on caption named the 1986 Act).
  - **Losses, both correct:** SI 2019/720 −8 (COSHH), SI 2019/742 −7 (SI 2008/296; these amend the Drug Precursors Regulation).
- **Traced after the pass and fixed (`a779f5c3`):**
  - SI 2019/696 Sch. 22 para 44 (the Lifts Regulations 2016) still reached the Machinery Regulations 2008 (12 false OH&S changes). An earlier paragraph's flattened quote has no closer ("substitute “Schedule 2 to the Supply of Machinery (Safety) Regulations 2008/1597; and"). An unclosed opening quote now quotes to the end.
  - The same fix stops quoted numbers being read as targets (SI 2019/1440 reg.18(4)(a); SI 2020/1369 reg.16(b); SI 2019/696 3 provisions).
  - "Regulation (EC) 273/2004" (no "No") now reads number/year (SI 2019/742: +30 Regulation 273/2004, +75 Regulation 111/2005).
  - Written for these four laws only; every other index is stale until the next round's full pass (correct, slower).
- **Rebuild:** golden 27/27; check PASS, our faults 0; **4,970 text changes, 3,067 bound**. Suite 8,869.
- **Open:** SI 2026/386 para 6(3) "In each of the provisions listed in sub-paragraph (4)—", where resolving the cross-reference would give its rules.

## Round 6 step 3: forms (2026-10-26, Jason: "step 3 next"), code `b1a1aad5`

- **`Units.unlettered/1`**, read wherever a provision's words are (the clause, units, the catalogue, `Unread`):
  - lettered places: RTSA 2003 s.17 "This Part shall extend … to— (a) England and Wales, (b) Scotland, (c) Northern Ireland" → UK. Before, this was **dropped silently**, not even counted;
  - a verb lettered under its subject: SI 2020/1112 reg.1 "These Regulations— … (c) extend to Northern Ireland only" → NI;
  - "not extend there" after a place: ukpga 1975/71 s.129(6) → E+W+S. Its "any provision … which amends … the Disqualification Acts" is read by `Extent.Amends` (the provisions naming those Acts; here repealed, so none);
  - "In Schedule N— (a) paragraph 3 extends …" → that Schedule's paragraphs (SI 2014/469, SI 2019/758);
  - bare Chapters under "In Part M—" (ukpga 2025/36).
- **Units:** a provision whose children are lettered items is read whole with its lead-in (`Units.numbered_children`). Before, the lead-in, the statement itself, was never a unit: SI 2019/146 reg.3's same-extent statement was dropped silently and is now counted (withheld). Statements split before Chapters and "the amendments made by".
- **Same-extent wordings:** "A provision of these Regulations that amends …" (SI 2025/82, ukpga 2020/29 s.40, 2021/10 s.17); "extends to any part of the UK to which the amended enactment extends" (SI 2012/2404 art.4(2); also counted as extent words now).
- **RefList:** lettered ranges spelt out ("8(2)(b) to (d)").
- **Catalogue:** a sentence of lettered statements is classed by them when every one is read. A first version credited by the first item; ukpga 2025/36 s.158's unread Chapters showed it, and now every item with extent words must be read.
  - 17 example expectations updated after review: 15 unread → read, 2 unread class nuance.
  - Corpus-wide, 35 laws' extents change; 3 lose rows, each checked (2009/23 gains s.293–294 in a list; SI 2019/146 none → unread, its statement now counted; SI 2020/818 an application list, now excluded from `Unread`).
- **Runs:** restore point `cv-s05-before-round6-step3`. Extents rewritten; rebuild; **golden 27/27**; **check PASS, our faults 0**.
  - **Bound 3,067 → 3,141:** SI 2020/1112 +28 (NI), SI 2015/1682 +25 (powers through RTSA s.17), 1975/71 +17, SI 1976/2004 +5, SI 2014/469 +5 and 2 UK → E+W+S; SI 2012/2404 1 to the enactment's own extent.
  - Withheld by unread statements: 422 → 358. Unread sentences: 69 laws → 65.
- Suite 8,881. `Extent.Patterns` is 428 lines (390 when Jason chose not to split it; ballpark).
- **Next:** step 4, agent check round 6 on a fresh seed (counted misses are known classes; only misreads and silent drops are NEW).

### Agent check prompt saved as a skill (2026-10-26, Jason: "was this not caught in a skill - bit of an oversight")

- Rounds 1–5's agent prompt lived only in conversation (unlike CV-S02's `feed-reader-check`). After compaction it was rebuilt for round 6, and the known classes (K1–K10, P1–P7) had never been recorded.
- Now `.claude/skills/extent-reader-check/SKILL.md`: steps (catalogue review, extents, rebuild, golden, check, claims diff, repeatable sample), the agent prompt with the known counted classes (KU, KP, KE, KC, KN, KD, KS), and a seed history. Memory: every reader acceptance check keeps its prompt in a skill.

## Agent check, seed 11 (round 6): laws 45 OK / 2 WRONG / 3 doubtful; changes 50 OK — FAIL (3 NEW, all silent drops)

- Sample repeatable (two runs identical); check PASS on the run; prompt from the new `extent-reader-check` skill.
- **Changes: 50/50 OK.** Three are right but labelled `none:not_named`, when their amending provisions are in `same` lists (D4).
- **NEW, verified: none of these sentences is in the catalogue classes at all (not counted):**
  - **D1 (misread through a drop):** ukpga 2003/39 (Courts Act 2003) s.111(2) "Subsection (1) does not apply to section 59(3), 90, 91, 100, … 106 or 109". The exception to the default is unread and uncounted, so ss.102–106 (Northern Ireland provisions) take the E+W default. Also s.111(1)'s "Subject to … section 27(13) of the Crime and Courts Act 2013 (extent of paragraphs 9A, 9C and 10 of Schedule 5)".
  - **D2:** ukpga 2007/28 s.244(3) "The extent of any amendment, repeal or revocation made by section 60, 202(1), … or Part 1, 8, … of Schedule 18 is the same as that of the provision amended". This form isn't extent words (no "same extent as"), so it is dropped. Effects seen: HSWA s.28(6) and RTA 1988 s.144(2)(a)(i) changes by Sch.13 bound E+W, when they should follow the enactment.
  - **D3 (doubtful effect):** ukpga 2016/19 s.95(4) "But subsection (3) does not apply to the amendments made to the Modern Slavery Act 2015 by paragraphs 30 and 35 of Schedule 3 …". The exception to `same *` is dropped, so those paragraphs take `same`.
  - Pattern: D1 and D3 are one form, "Subsection (N) does not apply to <provisions>", an exception to an extent subsection worded as "apply". D2 is "The extent of … is the same as that of …".
- **D4 (check label):** `none_listed/1` returns `not_named` before looking for a `same` list.
- **Doubtful, not NEW:** application wording not read nor shown (uksi 2014/1639 "These Regulations apply— (a) within Great Britain; (b) … outside", no effect; uksi 2008/960 sch.1 para.12(3) "This paragraph does not apply to Scotland", provision_application, counted in the catalogue, not in the sample's unread).
- **Aside:** LRRA 2006 s.34(3) "The repeals in the Schedule have the same extent …" stored as `same *` (round 3 noted it; still open).
- The trend of NEW per round: 16, 11, 5, 5, 8, 3. For the first time the changes are 50/50, and every NEW is a silent drop of a statement, none a misread of a statement the reader reads.
