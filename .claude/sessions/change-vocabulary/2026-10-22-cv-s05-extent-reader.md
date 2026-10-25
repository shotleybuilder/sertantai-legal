---
session: 'CV-S05: Extent and Application Reader'
status: active
release: v0.1
opened: '2026-10-22'
bugs:
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
- ⬜ Before round 6, two defects the run-time session's amendment read pass exposed (logged there, open): SOCPA 2005's "all — act_enactment" Royal Assent rule beside its by-order clause dates RTA 1988 s.4(6)'s repeal 2005-04-07, not 2006-01-01, so golden is 26/27 (a CV-S04 commencement fault; golden all-pass is in this session's stopping rule); and PCA 2017 Sch.1 para 94 "The Localism Act 2011 is amended" read as amending FRSA 2004 (amendment reader). The stored changes haven't been rebuilt since that read pass
- ⬜ Round 6 (proposed 2026-10-25, Jason's go-ahead needed on step 1, a design change): (1) never drop a statement silently: a sentence saying where provisions extend that isn't turned fully into rules is recorded unread, and its provisions get no bound, never the default; the catalogue and the check count it; (2) the misreads and my regressions: NEW-A (Chapter of Part), NEW-C (section in brackets), uksi 2019/696's exceptions read as items, 2022/1037's Part 4; (3) forms: "except as aforesaid … shall not extend there", lettered places "to— (a) England and Wales, (b) …", "extends to any part of the United Kingdom to which the amended enactment extends"; (4) the same runs, then agent round 6 (misses that are counted are known classes; only misreads and silent drops are NEW)
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

