---
session: 'CV-S05: Extent and Application Reader'
status: active
release: v0.1
opened: '2026-10-22'
bugs:
  - pattern: "Amendment reader's Pointer/Locator name a Schedule paragraph inside a Part without its Part (sch.N.para.M), while Order.ref and RefList use the triple sch.N.pt.R.para.M (round 13, Jason 2026-10-27); RefList.covers? matches the two, but identity by target (merge) can split where a Schedule numbers each Part apart"
    category: naming
    module: AmendingLaw.Pointer, AmendingLaw.Locator
    affected: 439 Part-less collisions in 58 laws (ids store); no effect while Schedules are unparsed (K1)
    fix: "v0.2, with #169 (Schedules in LAT): Pointer.to_ref and Locator emit/try the triple; one amendment read pass (ReaderVersion)"
    status: open
  - pattern: "Extent round 12 agent seed 17: Applies locator 'in regulation 16, paragraphs (4) and (5)' read as all of reg.16 (uksi 2020/818 reg.1A, wrong bound); '34 (f)' with a space read as reg.34 whole (uksi 2013/1506 reg.3(2), wrong bound); 'They apply in relation to— (a) England … (b) Wales' unread and uncounted (uksi 2016/1154 reg.1(3))"
    category: extent
    module: Extent.Applies / RefList / Application
    affected: 3
    fix: "locator in Applies as in ListItems; RefList joins 'N (f)'; application lettered places; round 13"
    status: open
  - pattern: "Extent: a default sentence carrying lettered items before its 'save as aforesaid … extends to E+W only' (ukpga 1977/45 s.65(10)) is credited default; items (a) (c) (d) and part of (b) silently dropped — wrong bound on HSWA s.15(6)(d) (E+W, text E+W+S via s.63(2))"
    category: extent
    module: Extent.Default / Lists / Units
    affected: 1
    fix: "read the lettered items as lists (qualified ones withheld), the default from the trailing 'save as aforesaid'; round 12 (agent seed 16 NEW-1)"
    status: open
  - pattern: "Extent ListItems residuals after round 11 (census run-02): other-law test matches 'into the … Act' (no word boundary, 2009/23 s.314); a same-extent item with its own 'other than' unread (2015/7 s.56(2)(b)); 'section 113 (together with such of the other provisions of Part 7 …)' dropped (2008/4 s.152)"
    category: extent
    module: Extent.ListItems / Same
    affected: 3
    fix: "\\b on the other-law test; same-extent items through ItemExceptions; strip a 'together with such of …' bracket; round 12"
    status: open
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
  - pattern: "Extent statements outside the catalogue's vocabulary are dropped silently (neither read nor counted): \"Subsection (1) does not apply to section 59(3), 90, …\" (ukpga 2003/39 s.111(2): ss.102–106 take E+W); \"But subsection (3) does not apply to the amendments made … by paragraphs 30 and 35 of Schedule 3\" (ukpga 2016/19 s.95(4))"
    category: extent
    module: Extent.Patterns / Extent.Forms
    affected: 2
    fix: "CV-S05a recall sweep: every extent-ish sentence counted; then read or count the form"
    status: fixed
  - pattern: "\"The extent of any amendment, repeal or revocation made by section 60, … is the same as that of the provision amended\" not recognised (ukpga 2007/28 s.244(3)): Sch.13 changes to HSWA s.28(6), RTA 1988 s.144 bound E+W"
    category: extent
    module: Extent.Forms (amendments_same)
    affected: 1
    fix: "read as same for the provisions named (after the CV-S05a sweep counts the form)"
    status: fixed
  - pattern: "lat.extent_check none_listed/1 labels a provision in a `same` list `not_named` when the law has no default"
    category: tooling
    module: Mix.Tasks.Lat.ExtentCheck
    affected: 3
    fix: "look for a same list naming the provision before not_named"
    status: fixed
  - pattern: "LRRA 2006 s.34(3) \"The repeals in the Schedule have the same extent …\" stored as `same *`, not the Schedule"
    category: extent
    module: Extent.Same
    affected: 1
    fix: "subject \"The repeals in the Schedule\" → the Schedule"
    status: open
  - pattern: "Round 7 agent misreads/partial reads: \"Paragraphs 9A … as amended by … this section\" read as s.27 (2013/22, NEW-1); a qualified item's sub-list read as this Act's (1975/21 s.463(1), NEW-2); \"This article\" and parts dropped (SI 2016/1142, NEW-3); \"Section 7 extends to NI, but the other provisions … do not\" (1997/42, NEW-4); \"In Schedule 3— (a) paragraphs … (and article 27 …)\" dropped (SI 2013/602, NEW-5)"
    category: extent
    module: Extent.Named / Lists / Units / RefList
    affected: 5
    fix: "fbec0738 (round 8); 1997/42 gains 65 E+W+S bounds; 1975/21 Sch.9 para 51 E+W+S → S"
    status: fixed
  - pattern: "Feed affecting refs kept \"art. N\" while a domestic Order's provisions are reg.N, so no extent list matched a feed-cited article (round 7 NEW-6; 3,894 affecting claims)"
    category: change-vocabulary
    module: Readers.FeedAffecting
    affected: 3894
    fix: "fbec0738: art. → reg. (as Order.ref names them); SI 2022/1174 art.18 bound E+W+S"
    status: fixed
  - pattern: "The catalogue credited a list sentence as read when any list of its kind and place existed, so partial reads were silent (round 7 NEW-3, 1988/33)"
    category: extent
    module: Extent.Patterns
    affected: 14
    fix: "fbec0738: Extent.Credit (own refs read, else unread:list_partial)"
    status: fixed
  - pattern: "An unnumbered Schedule's Parts and paragraphs have no usable ref (Order.ref(\"schedule-part-1\") = \"sch.part\"; FeedAffecting needs a Schedule number), so \"Part 1 of the Schedule extends to …\" can't be read (SI 2016/1142 art.1(3)); counted unread:list_partial"
    category: extent
    module: Commencement.Order.ref / Readers.FeedAffecting / RefList
    affected: 2
    fix: "name an unnumbered Schedule's Parts/paragraphs (sch.pt.N, sch.para.N) in Order.ref, RefList and FeedAffecting together"
    status: open
  - pattern: "List sentences still read in part, counted unread:list_partial: 1974/44 s.131 (\"Parts IV, V, VI, VII, and VIII and,, in Part IX, sections …110 to116…\" text glitches); 2013/24 s.102 (\"Part 2 extends only to E+W and S, except that the following … also to NI\"); 1975/21 s.463(1)(a) \"(8) 189\" (no comma)"
    category: extent
    module: Extent.Lists / Named
    affected: 3
    fix: "round 9: 2013/24 s.102 read (Extent.Excepting); the other two re-logged below"
    status: fixed
  - pattern: "List sentences still read in part, counted unread:list_partial: 1974/44 s.131 (text glitches); 1975/21 s.463(1)(a) \"(8) 189\" (no comma) — 2013/24 s.102 now read (round 9)"
    category: extent
    module: Extent.Lists / Named
    affected: 2
    fix: "tolerate missing separators"
    status: open
  - pattern: "A change only the law's own text gives was looked up at its raw key id (\"schedule-7\"), never matching a list: the default placed over withheld bounds (round 8 NEW-1)"
    category: extent
    module: Readers.NoteDate
    affected: 80
    fix: "round 9: own_ref via Order.ref (sch.7)"
    status: fixed
  - pattern: "\"Part N extends to P, except as follows— (a) …\" / \"except that— …\" / \"except that the following provisions of Part N extend also to …\": only the exceptions stored, the Part's own extent dropped; \"of that Schedule\" unresolved; another Act's provisions in a repeals list taken as the law's (ERRA 2013 s.102, round 8 NEW-2)"
    category: extent
    module: Extent.Excepting (new), Units, Lookup, Unread
    affected: 1
    fix: "round 9: Excepting reads the lead (less the provisions its exceptions set) when every exception reads plainly; Units resolves \"of that Schedule\"; a list setting a Schedule paragraph outranks its introducing section's; Unread drops other Acts' items"
    status: fixed
  - pattern: "\"with the exception of— (b) any provision amending or repealing an enactment which does not so extend\" dropped silently (CPA 1987 s.49(1), round 8 NEW-3)"
    category: extent
    module: Extent.Lists
    affected: 1
    fix: "round 9: read as same \"*\""
    status: fixed
  - pattern: "The extent clause was the first section with an extent form even when it states no default (a list), so a later \"this Act extends to Northern Ireland\" was dropped (ukpga 1981/45 ss.31–32, round 8 NEW-4)"
    category: extent
    module: AmendingLaw.Extent
    affected: 1
    fix: "round 9: the first such section stating a default, else the first"
    status: fixed
  - pattern: "An SI's Schedule's Reference (\"Regulation 30\") not read, so its Schedules had no introducing provision (SI 2019/696, round 8 NEW-5)"
    category: extent
    module: AmendingLaw.ScheduleRefs
    affected: 1
    fix: "round 9: Reference Section|Regulation|Article|Rule N"
    status: fixed
  - pattern: "\"Any amendment or repeal by this Act of an enactment which extends to S or NI has the same extent as that enactment but, save as aforesaid, …\": the same part dropped (LGA 1985 s.106(2), round 8 NEW-6)"
    category: extent
    module: Extent.Same
    affected: 1
    fix: "round 9: same \"*\" with the default"
    status: fixed
  - pattern: "A headed list's item led by its qualifier (\"b in so far as relating to … Fire Services Act 1947, section 52\") was read whole: the comma split cut the qualifier off (FRSA 2004 s.63(2); exposed when NEW-1's own keys met the list: Sch.1 para 44 → E+W+S)"
    category: extent
    module: Extent.Lists
    affected: 3
    fix: "round 9: such items withheld ({:unread, nil, refs}), the qualifier's object out"
    status: fixed
  - pattern: "A commencement sentence's \"This Act, except— (a) …\" read as Forms.except_list through a later \"… do not extend to Scotland\" in the same section, so the default became the UK less Scotland (ukpga 2002/30 s.108: E+W+NI, the text says E+W); its UK list read as also S (round 9 agent NEW-1)"
    category: extent
    module: Extent.Forms / Default
    affected: 1
    fix: "round 10 (56f98e86): except_list within one subsection; s.108(7) read as named UK (MakesFollowing)"
    status: fixed
  - pattern: "\"In Schedule N— (a) the amendments made by paragraph X of Schedule N apply in relation to England only; …\" dropped silently (SI 2014/1638 reg.3(5), round 10 agent NEW-1)"
    category: extent
    module: Extent.Applies
    affected: 1
    fix: "read provision application under an \"In Schedule N—\" lead-in"
    status: open
  - pattern: "Headed-list items with an unbracketed \"other than\" read their exceptions as items; \"in Chapter 1 of Part 6, sections 165, 166 and 186\" read as the whole Chapter; \"Chapters 1 to 5 of Part 8 and section 295\" over-reaches; same-list items with \"other than\" mishandled; \"this Part (other than …, except as provided by …)\" dropped; partial reads not counted (ukpga 2009/23 s.323, round 10 agent NEW-2)"
    category: extent
    module: Extent.Lists / Same / Parts
    affected: 1
    fix: "unbracketed other-than as minus; \"in X, sections …\" as those sections only; Chapter ranges by structure; credit partial reads as list_partial"
    status: open
  - pattern: "\"(v) this Chapter\" item dropped from a named list (ukpga 2017/3 s.182(2): ss.180–184 get the default E+W, the text says UK; round 10 agent NEW-3)"
    category: extent
    module: Extent.Lists / Parts
    affected: 1
    fix: "read \"this Chapter\" as the clause's Chapter's sections"
    status: open
  - pattern: "lat.extent_check's per-law unread classes left out unread:list_partial and unread:provision_*"
    category: tooling
    module: mix lat.extent_check
    affected: 0
    fix: "round 9: every unread: class"
    status: fixed
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S05: Extent and Application Reader (ACTIVE)

> **Suspended 2026-10-27** (Jason: "open CV-S05d and suspend CV-S05"): for CV-S05d Whole-Reader Census (`2026-10-27-cv-s05d-whole-reader-census.md`). CV-S05c censused list items only, and round 12's agent NEW sat in other readers (application, `RefList`, the sweep's noise bin). Resume with round 13 from CV-S05d's counted shapes, plus the open seed 17 NEW-1–3 and the 2009/23 Chapter 6 residual. Then the agent check as the final confirmation.

> **Suspended 2026-10-27** (Jason: "make the sub session active and suspend this one"): for CV-S05b List shape audit, which finds the technique that counts list misreads across the corpus. Resume with: the pass-bar decision (below), then round 11 from CV-S05b's ranked shapes plus round 10's NEW-1. (CV-S05b, a technique-choice session, was a path not followed and was deleted on 2026-10-27; the work went to CV-S05c Shape Mining, closed.)

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
- ✅ Round 7 [`aee9b3d9`] (from CV-S05a's sweep; agent check pending): read the `read:*` forms — same_extent_of (12), same_extent (5), exception (6: round 6 D1, D3), also_there (7), lettered "extends only to—" (1), provision-level application (52; Jason "a"); fold in round 6's D2 (same_extent_of), the check's `same` label (D4), LRRA s.34(3); then the runs, the sweep (OH&S read forms 0), and a fresh-seed agent check
- ✅ Round 8 [`fbec0738`] (Jason 2026-10-26: "round 8 go ahead - run through to completion as proposed in steps 1 to 4"): ✅ (1) feed affecting refs `art.` → `reg.` (NEW-6); ✅ (2) the catalogue credits a list sentence only when its own provisions were read (`Extent.Credit`, `unread:list_partial`); ✅ (3) NEW-1 to NEW-5 and the partial reads (2) exposed; ✅ (4) the runs (check PASS, golden 27/27), agent round 8 seed 13: FAIL, 6 NEW
- ✅ Round 9 [`cac5e205`] (Jason 2026-10-26: "Round 9 for items 1 through 6"): round 8's NEW-1 to NEW-6 and the tooling gap; one misread NEW-1 exposed (FRSA 2004 s.63(2) qualified items) fixed in the round; the runs (check PASS, golden 27/27); agent round 9 seed 14 — see below
- ✅ Amendment reader full read pass after round 9 (Jason 2026-10-27: "Push. Do 1. Run round 10."): pushed `bf9cfc46..605fe46f`; restore point `cv-s05-before-round9-read`; 2,102 laws, 9 changed (rules 43,623 → 43,678), traced
- ✅ Round 10 [`56f98e86`]: round 9's NEW-1 (2002/30 s.108) and the agent's side readings; the runs (check PASS, golden 27/27); agent round 10 seed 15 — see below
- ✅ CV-S05c Shape Mining (CLOSED 2026-10-27): census of all extent sentences (`backend/data/experiments/cv-s05c-shape-mining/run-01/`); classes A–F and the 'this paragraph' rule logged as open bugs in CV-S05c, for round 11
- ✅ Pass bar for the agent check: decided 2026-10-27 (see "Pass bar: decided")
- ⬜ Round 11: CV-S05c's classes by count (A: "In Part N— (a) … (b) …" only (a) read, 6 laws; B: item's own exception drops it, 8+3; C: plain refs dropped with a qualified companion, 4+1; D: trailing-qualified item not withheld, 4+2; E: one-offs, 7; F: excluded provisions held, 4 new; Schedule "this paragraph" own extent, ~12) with their laws as fixtures (`run-01/confirmed.md`, `overreach.md`, `unread_tail.md`); round 10's NEW-1 (lost lead "In Schedule N—", 9 laws); then re-run run-01's commands as run-02 and compare; then agent check against the agreed bar
- ⬜ Deferred from CV-S05c: after round 11's run-02, decide whether the census earns a permanent read-only mix task (pure modules + tests)
- ⬜ CV-S05d Whole-Reader Census (SUSPENDED for round 13, `2026-10-27-cv-s05d-whole-reader-census.md`): fix list S1–S17 (~65 laws) in `backend/data/experiments/cv-s05d-whole-reader-census/run-03/out/triage.md`; run-04 is round 13's check
- ⬜ Round 13 (Jason 2026-10-27; code done, runs next): S1–S17 from CV-S05d run-03, plus seed 17 NEW-1–3 (= S11, S8, S2) and the 2009/23 Chapter 6 residual; tests per wording on the laws' real words; then restore point, one extents run, golden, check, census run-04, agent check
- ⬜ **Application Scope Hand-off to Fractalaw (PENDING, `2026-10-27-application-scope-handoff.md`; Jason 2026-10-27):** application to cases is fitness scope (skill class KA), not extent. CV-S05d's census extracts these sentences for fractalaw (61 laws with no fitness data in run-01). It is not closed by CV-S05 or CV-S05d: keep it open until it is done.
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

## Pass bar: question for Jason (2026-10-27)

The pass above needs "the agent sample has no NEW defect". Over ten rounds, NEW per round has been 16, 11, 5, 5, 8, 3, 6, 6, 1, 3. Each round fixes its defects, and each fresh sample of 50 laws finds a few rarer wordings. With 3,000+ extent sentences, a bar of zero NEW per sample may never be met, even by a good reader. Options to decide:
- **(a) Keep it:** zero NEW on a fresh seed.
- **(b) Counted first:** after the census (CV-S05c), the agent's NEW may only be what the audit can't see, such as a dropped sentence or wrong data. Anything the audit counts is a known class with a count and goes on a fix list.
- **(c) By rate:** misreads under an agreed rate (for example ≤ 1 law in 50) on two fresh seeds in a row, with no wrong bound on a sampled change.
- **(d) By effect:** no wrong bound on any sampled change (rounds 9 and 10 had none). Law-level misreads that place no wrong bound are counted, not failing.

Recommendation: (b), with (d)'s "no wrong bound on a sampled change" as a hard line.

## Pass bar: decided (Jason 2026-10-27: "yes, resume CV-S05 and start round 11")

A round passes when all three hold:
1. **Census (run-02, CV-S05c's commands):** classes A–F are at zero in list sentences, apart from cases logged as known and counted.
2. **Golden:** 27/27.
3. **Agent sample:** no wrong bound on any sampled change. A new wording the reader withholds (unread, counted) is a known class, not a failure. A law-level misread that sets a wrong bound is NEW.

(Option (b), counted first, with (d)'s hard line, made concrete by the census.)

## Resumed (2026-10-27): round 11

The work comes from CV-S05c (closed), whose run-01 evidence is in `backend/data/experiments/cv-s05c-shape-mining/run-01/`:
- classes A–F (33 laws, with fixtures in `confirmed.md` and `overreach.md`);
- the Schedule "this paragraph" own-extent rule (~12 laws, `unread_tail.md`);
- round 10's NEW-1 (the lost lead "In Schedule N—", 9 laws).

Method, as before:
1. Write tests on each law's real wording.
2. Make the fixes.
3. Preview, then run once: catalogue, restore point, re-read, rebuild, golden, check.
4. Run-02 census and compare with run-01.
5. Agent check.

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

## Suspended (2026-10-26)

Jason: "do we need to build the catalogue - are we using the agents to randomly find unmatched variation (smack a mole) rather than systematically seeding the patterns like in previous stages?" — then "let's build the sweep in a sub-session. Suspend this main session to come to once the sweep sub session is closed".

- **Why:** the catalogue classes only sentences its own detector recognises as extent words, so a wording outside that vocabulary is never seen, counted or flagged. Most NEW defects since round 4, and all three of round 6, were such silent drops, found by sampling.
- **Sub-session:** `2026-10-26-cv-s05a-extent-recall-sweep.md`. Every extent-ish sentence of the held amending laws is collected with a wide net, what the catalogue doesn't class is subtracted, the remainder is clustered by form and reviewed by count, and "uncaught" becomes a counted outcome in the catalogue and the check.

State at suspension:
- code `b1a1aad5` (+ skill `e5a59faf`), pushed to `5e284141`;
- stored extents and changes from step 3's runs (check PASS, golden 27/27, bound 3,067 → 3,141);
- round 6 agent FAIL (3 NEW, all silent drops; logged as open bugs above).

On resume: fold round 6's defects into the sweep's clusters (fixed there, or here by count); then the round's runs and a fresh-seed agent check (`extent-reader-check`).

## Resumed (2026-10-26, after CV-S05a closed)

- CV-S05a built the recall sweep (`mix lat.extent_sweep`, `Extent.Sweep`, `AmendingLaw.SweepForm`). Of 3,358 laws, 551 own-words sentences that may state extent or application are not classed by the catalogue: 83 in a form to read, 25 to count, 443 noise.
- `lat.extent_check` now lists the family's misses: **OH&S 29 in a read form**, including round 6's D1–D3.
- The pass now needs no uncaught sentence in a read form (skill `extent-reader-check`, step 0).
- Next: round 7, reading those forms (todo above).

## Round 7: the sweep's forms read (2026-10-26, Jason: "Round 7 start"), code `aee9b3d9`

- **`Extent.Applies`, provision-level application** (Jason: "read them as provision-level application"):
  - forms read: "Regulation 44 applies to Scotland only"; "This paragraph applies in relation to England only" (Schedule paragraphs too); subsections; "… respectively"; "The following regulations do not apply in relation to Wales— …"; "the amendments made by … apply …"; "extends and applies" (also an extent list);
  - kept as `Extent.applies` (rows `applies_to` / `applies_not`), apart from the extent lists so "lists and no default" logic is untouched;
  - `Extent.application_at/2` gives a change's territory (feed and amending-law readers): the provision's own application, else the law's; "does not apply to S" is where it otherwise applies or extends, less S;
  - whole statements only. A first version read "Subsection (2) applies if, … as it applies in relation to England" (1984/55 s.120G) as an application; subjects now exclude verbs and conditions.
- **`Extent.Excepted`:** "Subsection (N) does not apply to <provisions>" withholds those provisions' bound (unread), only where subsection N is an extent or application statement. Round 6 D1 (Courts Act s.111(2)) and D3 (ukpga 2016/19 s.95(4)). "or" items joined; a descriptive bracket stripped before the "which" filter.
- **Same extent:**
  - "The extent of any amendment … is the same as that of the enactment …" (round 6 D2: ukpga 2007/28 s.244(3); also 2000/6, 2002/17, 2004/5, SIs 2002/3135, 2008/912);
  - "a provision that amends …";
  - "same extent and application / in the United Kingdom as";
  - "also extends there", and "also extend to any place (except …) to which the enactments … extend";
  - "that Schedule" resolves to the Schedule named last in the provision.
- **Lettered:** "extends only to— (a) …" (ukpga 2006/3 s.94).
- **Check:** a `same` list is labelled `same_or_not_named` first (D4: `not_named` 146 → 12, `same_or_not_named` 74 → 213; outcomes unchanged).
- **Catalogue:**
  - These forms are now classed. The exception gate first admitted every "Subsection (N) does not apply to …" (unread:not_read 308 → 1,258); now it admits only an exception actually read.
  - An application is credited only where its own entries are read.
  - 16 examples updated after review: 6 applications read, 5 exceptions, 1 same with exception, and 4 unread class shifts.
- **Sweep:** an exception to a non-extent subsection (ukpga 2013/22 s.61(4), a commencement) is no miss. Forms: instruction words first (ukpga 2005/15 Sch. 7 para 59), "extends outside …" is outside the UK, an application not read whole is counted.
- **Runs:** restore point `cv-s05-before-round7`; catalogue accept; sweep (corpus uncaught 551 → 522, **read forms 83 → 0**); extents rewritten; rebuild; **golden 27/27**; **check PASS, our faults 0, OH&S read-form misses 29 → 0**. Suite 8,957.
- **Claims:** 8 bounds now follow the enactment (`same`): ukpga 2007/28 1 (D2: Sch.13's HSWA s.28(6) change, was E+W), SI 2008/912 3, ukpga 2020/17 2, SI 2002/3135 2. No territory claims changed: no OH&S change is made by a provision with its own application. Bound 3,141 → 3,133.
- `Extent.Patterns` is 456 lines (ballpark noted).
- **Next:** agent check round 7, seed 12 (sample repeatable), running on the skill's prompt with round 7's rules added.

## Agent check, seed 12 (round 7): laws 41 OK / 5 WRONG / 4 doubtful; changes 46 OK / 3 WRONG / 1 doubtful — FAIL (6 NEW)

Sample repeatable (two runs identical). All six NEW are **misreads or partial reads of statements the reader does read**, so the sweep (recall) can't see them:

- **NEW-6 (verified, systemic):** the feed reader keeps the feed's "art. 18" as `art.18`. Domestic articles are `reg.` by our convention (extent lists, `Order.ref`), so no Order's extent list matches a feed-cited article. 3,894 affecting claims carry `art.` refs. Seen as SI 2022/1174 art.18 (Part 3 "E+W+S only"), none:not_named.
- **NEW-4 (verified):** ukpga 1997/42 s.9(3) "Section 7 extends to Northern Ireland, but the other provisions of this Act do not extend there". Stored: only `named NI {s.7}`, no default. Truth: default E+W+S, s.7 UK. HSWA changes (s.6(1), s.2) come out none:not_named instead of E+W+S.
- **NEW-1:** ukpga 2013/22 s.27(13) "Paragraphs 9A, 9C and 10, as amended by the preceding provisions of this section, extend to Scotland and Northern Ireland" (paragraphs of the Courts Act 2003's Sch.5) is stored as `named S+NI {s.27}`, which outranks s.61(15)'s same extent for s.27(1)–(12).
- **NEW-2:** ukpga 1975/21 s.463(1), a long lettered list with other Acts' sections. "sch.1961" (from "the Criminal Justice Act 1961"); the 1973 Act's ss.53, 58(a) placed on this Act's own; item (b) Part II dropped; all of Sch.9 E+W.
- **NEW-3:** SI 2016/1142 art.1(3), (5) partly read ("This article" and Schedule Parts 1 and 2 missing). It is credited as read because the list's kind and place matched, so the drop is silent.
- **NEW-5:** SI 2013/602 art.1(8) "In Schedule 3— (a) paragraphs 1 to 11 and 13 to 18 (…) have the same extent …; (b) paragraphs 12 and 19 (…) extend to Scotland only": no row, no unread, so silent.
- **Doubtful, not NEW:**
  - ukpga 2000/32 s.80(3) "same extent as the statutory provisions" counted unread;
  - application clauses that equal the extent (SI 2014/1639, 2016/1154);
  - SI 2008/2852 reg.1A "These Regulations apply to Northern Ireland, including offshore installations …" counted unread:application;
  - change 44's label (no affecting claim, labelled unread_statement).
- **Pattern:** the catalogue credits a sentence as read when any list of the same kind and place exists (NEW-3; also 1988/33's same-with-exception). So partial reads and misreads stay invisible. Round 7 already moved application crediting to the sentence's own entries; the same for lists would make partial reads counted (precision, as the sweep did for recall).

## Round 8 (2026-10-26, Jason: "round 8 go ahead - run through to completion as proposed in steps 1 to 4"), code `fbec0738`

- **(1) Feed affecting refs (NEW-6):** `Readers.FeedAffecting` (extracted from `Readers.Feed`, 548 → 509 lines) names the feed's "art. N" `reg.N`, as `Order.ref` names our provisions. Merge, Conflicts and commencement crediting compare against `reg.` refs too. 511 `feed.affecting` values in the feed catalogue's expected fixtures moved `art.` → `reg.` (mechanical; nothing else moved).
- **(2) Precision: `Extent.Credit`:**
  - A list sentence is credited in the catalogue only when each provision its subject names is in a list of its kind and place. Otherwise it is `unread:list_partial`, a counted class.
  - The subject is the words before the verb, cut at each provision named. Left out: a lead ("Subject to section 17(6), …"), a describing bracket, a locator ("in Part 13"), another Act's provisions, and a heading's lead-in.
  - Lettered sentences are credited per item.
  - First pass: 19 examples moved. False ones were fixed in `Credit` ("Subject to", brackets, "in Part", a `same *` covering all, a Schedule's own Part).
  - The true partial reads it exposed were then fixed in the reader (3): "This article" / "This Regulation" / "This section and the following"; naming brackets ("(with Schedule 9)"); roman items and "(b) an amendment … made by …" split; "repealed or amended … the repeal or amendment extends to that part"; a lettered "paragraphs … have the same extent as …".
- **(3) Round 7's NEW:**
  - NEW-1: "as amended by" asides out of a named subject.
  - NEW-2: a qualified item, its sub-list and a qualified number left out; a bare "in section 47" locator is no item.
  - NEW-3: "This article" read; "Part 1 of the Schedule" (unnumbered Schedule) left counted, an open bug.
  - NEW-4: "…, but the other provisions of this Act do not extend there" read as "This Act, except— …".
  - NEW-5: "In Schedule 3— … (and article 27 …)".
- **Still partial, counted (`unread:list_partial`, logged open):** 1974/44 s.131 (text glitches), 2013/24 s.102 ("Part 2 extends only to …, except that the following … also …"), SI 2016/1142 (unnumbered Schedule). Same-with-exception statements held unread by design (SI 2013/602 Sch.1, SI 2014/469 Sch.3, SI 2020/904) now show as `list_partial`.
- **Runs:**
  - sweep: corpus uncaught 522 → 520, read forms 0;
  - catalogue accept: 16 examples reviewed, 13 new patterns;
  - restore point `cv-s05-before-round8`;
  - extents re-written for 2,058 laws (58 s, no fetch);
  - rebuild and **golden 27/27**;
  - **check PASS**: our faults 0, OH&S read-form misses 0.
  - Suite (extent + CV) 4,322.
- **Claims** (against `r6b.claims6`): 0 lost; 66 gained (1997/42 NEW-4: 65 HSWA changes E+W+S; SI 2022/1174 art.18 NEW-6: E+W+S); 1 changed (1975/21 Sch.9 para 51 → HSWA s.34(5)(c): E+W+S → S, right: Sch.9 extends to E+W only for the amendments relating to the Acts listed, and HSWA isn't one). bound:law 3,133 → 3,140; none:not_named 12 → 5.
- **Next:** agent check round 8, seed 13 (sample repeatable).

## Agent check, seed 13 (round 8): laws 44 OK / 2 WRONG / 4 doubtful; changes 45 OK / 3 WRONG / 2 doubtful — FAIL (6 NEW)

Sample repeatable (two runs identical). Round 7's six are gone. Four new are misreads and two are silent drops; one is systemic (verified):
- **NEW-1 (verified, systemic):** a change with no markup or feed affecting claim falls back on its own key. `NoteDate.own_ref` passes the raw id ("schedule-7", "schedule-12-paragraph-15-13"), not `Order.ref`'s `sch.7`. No list matches it, so the default is placed even where a row withholds the bound (ukpga 1989/38 Sch.7 `unread`; ukpga 2013/32 Sch.12 `unread`). 80 law_text extent claims are affected.
- **NEW-2:** ERRA 2013 (ukpga 2013/24) s.102(4), (8) "Part 4 extends to E+W, S and NI, except as follows—": only the exceptions are stored, with no UK row for Parts 4 and 6, yet the catalogue credits them (`list:only:E+W+S`). s.102(6) also makes another Act's provisions this law's (`unread {s.67, sch.2.para.32 …}`).
- **NEW-3:** CPA 1987 s.49(1)(b) "any provision amending or repealing an enactment which does not so extend" is dropped from "This Act shall extend to Northern Ireland with the exception of— …". s.36 and Sch.3 (HSWA amendments) take E+W+S+NI.
- **NEW-4:** ukpga 1981/45 s.32 "It is hereby declared that this Act extends to Northern Ireland" is dropped. `Extent.read` takes the first matching section (s.31) as the clause, so no default is stored. Part I of the unnumbered Schedule is also missing.
- **NEW-5:** SI 2019/696 has no `introduces` rows ("Schedule N contains amendment of …" not read), so sch.33–37 take E+W+S, not reg.3's UK for "Part 5 and its related schedules".
- **NEW-6:** LGA 1985 s.106(2) "Any amendment or repeal by this Act of an enactment which extends to Scotland or Northern Ireland has the same extent as that enactment but, save as aforesaid, this Act extends to England and Wales only": only `default E+W` is stored. HSWA s.28(6) (Sch.14 para 52) gets bound E+W.
- **Tooling (verified):** `lat.extent_check`'s `@law_unread` leaves out `unread:list_partial` and `unread:provision_extent`, so the sample's per-law unread classes hide KL counts.
- **Doubtful:** ukpga 2005/11 s.56(2) "same extent as the enactment (or the relevant part …)" is unread while 2003/20's same words are read; ukpga 2003/20 s.121(3)(a) "has effect despite" (same over a Part clause); ukpga 2007/15 plain "extends only to England and Wales" left unread (counted); 1986/44 qualified items take the default.
- Trend of NEW per round: 16, 11, 5, 5, 8, 3, 6, 6.

## Round 9 (Jason 2026-10-26: "Round 9 for items 1 through 6") [`cac5e205`]

- **NEW-1 (systemic):** `NoteDate.own_ref` looks a change up at its key's provision as a ref (`Order.ref`: "schedule-7" → `sch.7`).
- **NEW-2:** `Extent.Excepting` (new) reads ERRA 2013 s.102's "Part N extends to P, except as follows— …", "… except that the following provisions of Part N extend also to …— …" and "This Part extends to … except that— …". The Part's provisions are read (only/named), less those its exceptions set, and only when every exception reads plainly. Three supporting changes:
  - `Units` resolves "of that Schedule" to the law's own Schedule named before it.
  - `Lookup`: a list setting a Schedule paragraph (only/named) outranks its introducing section's lists, as the rule says.
  - `Unread` drops other Acts' provisions in a "following" list (s.102(6)).
- **NEW-3:** CPA 1987 s.49(1)(b) "any provision amending or repealing an enactment which does not so extend" is read as same `*`.
- **NEW-4:** the clause is the first section stating a default (1981/45 s.32), else the first with an extent form.
- **NEW-5:** `ScheduleRefs` reads an SI Schedule's Reference "Regulation N" / "Article N". This stales the amendment reader's index (0 rule changes on `--preview --regression`, 279 laws); its full `--read` pass was not run (asked).
- **NEW-6:** LGA 1985 s.106(2) "Any amendment or repeal by this Act of an enactment which extends to … has the same extent as that enactment but, save as aforesaid, …" is read as same `*`, with the default kept.
- **Exposed by NEW-1 and fixed:** FRSA 2004 s.63(2) "The following provisions also extend to Scotland—…;b in so far as relating to … Fire Services Act 1947, section 52;c in so far as relating to— … section 53(1) and Schedule 1;d …" had its qualified items read whole. Once own keys matched the list, Sch.1 para 44 (HSWA s.23(4)) got E+W+S. Now an item led by its qualifier is withheld (`unread`). An item split at "andb" also reads 2008/14 s.169's plain s.74 (unread → list).
- **Tooling:** `lat.extent_check` counts every `unread:` class per law.
- **Runs:**
  - sweep: uncaught 520, read forms 0;
  - catalogue accept twice (before and after the FRSA fix): 3 new patterns; re-keyed examples ("of that Schedule" resolved, same classes); 3 reviewed by hand: 2013/24 ×2 now read, 2008/14 s.169 now read;
  - restore point `cv-s05-before-round9` (extent_rules, provision_changes, provision_change_claims);
  - extents for 2,058 laws (no fetch);
  - rebuild, **golden 27/27**;
  - **check PASS**: our faults 0, OH&S read-form misses 0.
  - Suite (extent + CV) 4,331.
- **Claims** (against `r6b.claims8`), every movement traced in the text:
  - lost 59:
    - CPA 1987 30 (now same);
    - LGA 1985 5 (same);
    - SI 2020/1460 5 (Sch.3 by reg.5, Part 4 same);
    - 1989/38 6, 1989/15 3, SI 2014/469 3, 2013/32 1 (NEW-1: own key now meets a withheld bound);
    - 2003/17 1, SI 2015/21 1, SI 2018/1370 1 (NEW-1: own key now meets a same list);
    - FRSA 3 (Sch.1 withheld).
  - gained 6:
    - 1981/45 1 (NEW-4);
    - SI 2021/1273 2 (Sch.1, Sch.2 by reg.7, reg.8: E+W+S);
    - SI 2013/1666 3 (powers via ERRA s.99, Part 6 now UK).
  - changed 23:
    - SI 2020/1460 22: Sch.2 by reg.4 (Part 3: NI only) ×18; Sch.5 by reg.8 (Part 7: E+W+S) ×4; was its powers' UK. References and Parts were checked in the XML.
    - SI 2015/21 1 (reg.12(4): its "only E+W+S" list).
  - `bound:law` 3,092; `none:unread_statement` 406.
- **Next:** agent check round 9, seed 14 (sample repeatable).

## Agent check, seed 14 (round 9): laws 48 right / 1 doubtful / 1 WRONG; changes 50/50 right — FAIL (1 NEW)

Sample repeatable (two runs identical). Round 8's six are gone. Changes: none wrong (OK or a counted class: KE, KP, KD, KL, KU).
- **NEW-1 (verified; predates round 9, the same rows are in restore point `cv-s05-before-round9`):** Police Reform Act 2002 (ukpga 2002/30) s.108: stored `default E+W+NI`, but s.108(6) says "Subject to subsections (7) to (9), this Act extends to England and Wales only".
  - The clause is the whole of s.108. Its commencement words in (2), "This Act, except— a the provisions specified …", appear to match `Forms.except_list` up to (10)'s "… do not extend to Scotland", giving the UK minus Scotland.
  - With a wrong default, (7) "This Act extends to the United Kingdom so far as it makes the following provision— … (a) … Part 5; (b) … section 82; …" is stored as `also S {s.82, s.103(6)}`. The two errors cancel to UK, and Part 5 is missing.
  - Bounds placed today are right: (9)'s `unread *` withholds every provision no list names. The stored default is still false.
- **Doubtful:** ukpga 2004/33 s.262(1) "Part 2 …, excluding section 35 but including Schedules 1 to 9, extends to England and Wales only" is a plain statement, left unread and counted (`provision_extent`).
- **Side notes (outside the sample):**
  - SI 2014/469 art.3(5)(d) "paragraph 182(3) and (5) apply in relation to Wales only" has no `applies` row.
  - LRRA 2006 `same *` (the open s.34(3) bug).
  - SI 1983/978's enabling cache is empty though its introduction names HSWA ss.15, 49, 82 (KP).
- Trend of NEW per round: 16, 11, 5, 5, 8, 3, 6, 6, 1.

## Amendment reader read pass (after round 9)

Run because round 9's `ScheduleRefs` change staled `ReaderVersion` (`--preview --regression`: 0 rule changes, 279 laws). Restore point `cv-s05-before-round9-read` (amendment_rules, extent_rules).
- 2,102 laws read, 9 changed, rules 43,623 → 43,678; diffed against the restore point (`r6b.ar_before`).
- None of the 9 came from `ScheduleRefs`. They are reader behaviour since these laws' last read (10:00 the same day) catching up:
  - Targets are no longer taken from the words inserted: SI 2006/1244 reg.23 "… substituted 'has the meaning given by section 153A(7)'" moves from s.153A to its own s.170. The same holds for 2023/52 Sch.16 para 7, 2014/21 Sch.7 para 60(2)(b), WSI 2019/414 reg.7(6) and SSI 2019/436 reg.2(2)(b)(i).
  - New rules: SI 2019/188 +9 (SI 2015/1640), SI 2026/607 +45 (EU), SI 2020/1658 +1.
  - SI 2020/1488 Sch.2 paras 93 and 132(c): targets at a different depth (reg.123(1)(a) → reg.123(a); the source text is garbled).

## Round 10 (Jason 2026-10-27: "Run round 10") [`56f98e86`]

- **Round 9 NEW-1:** `Forms.except_list` reads within one subsection, never a commencement's "This Act, except— …, shall come into force" run on to a later "… do not extend to Scotland".
  - Police Reform Act 2002 s.108: default E+W+NI → E+W.
  - 1993/28 s.188 had the same misread: a false E+W+S default and an "also NI" list of its commencement items. Now there is no default, and its sentences are counted unread.
- **s.108(7):** `Extent.MakesFollowing` (new) reads "This Act extends to the United Kingdom so far as it makes the following provision— (za) … paragraph 19F of Schedule 3 (…); (a) … Part 5; (b) … section 82; (c) . . .; (d) … section 103(6)" as named UK.
- **Civil Partnership Act 2004 s.262(1):** "Part 2 (…), excluding section 35 but including Schedules 1 to 9, extends to England and Wales only" is read in `Named`.
- **LRRA 2006 s.34(2):** "In section 31— (a) subsections (1) and (2) extend …" is read in `Units`.
- **SI 2014/469 art.3(5)(d):** a lettered item's bare "paragraph 182(3) and (5)" is the Schedule named before it, read in `Extent.ScheduleWords`, which also holds "of that Schedule" (moved out of `Units`, now 295 lines). It gives `applies W` for Sch.3 paras 182(3), (5).
- **Tried and reverted:** LRRA s.34(3) "The repeals in the Schedule have the same extent …" with no `*`. The sentence diff showed 7 other laws with the same wording for an unnumbered Schedule that holds their amendments (2001/3, 2018/24, 2023/18, 2023/20, SI 2004/1771, SI 2004/1822, SI 2019/734, SI 2023/1386). There `same *` is right, and dropping it misread SI 2023/1386 (same → the default UK). Kept as a known class (KU1) under the open unnumbered-Schedule bug.
- **Review method:** a per-sentence class dump under round 9's code (a worktree at `cac5e205`) and round 10's. 15 sentences moved, each one reviewed; the rest are unchanged.
- **Runs:**
  - catalogue accept: 5 examples reviewed by hand (1993/28 ×3, 2002/30, 2004/33); sweep 520, read forms 0;
  - restore point `cv-s05-before-round10`;
  - extents for 2,058 laws;
  - **golden 27/27**;
  - **check PASS**: our faults 0.
  - Suite (extent + CV) 4,334.
- **Claims** (against `r6b.claims9`): no law_text claim lost, gained or changed. Two outcomes move `none:unread_statement` → `none:same_or_not_named`: Civil Partnership Act 2004 Sch.27 paras 23, 49 (now `same` by s.262(10), no longer withheld by the unread s.262(1)).
- **Next:** agent check round 10, seed 15 (sample repeatable).

## Agent check, seed 15 (round 10): laws 43 OK / 4 doubtful / 3 WRONG; changes 50/50 — FAIL (3 NEW)

Sample repeatable (two runs identical). Round 9's NEW-1 is gone. No sampled change is made by the three WRONG laws. All three were verified by lookup:
- **NEW-1 (silent drop):** SI 2014/1638 reg.3(5) "In Schedule 13— (a) the amendments made by paragraph 14(2) and (4) of Schedule 13 apply in relation to England only; and (b) … 14(3) and (5) … apply in relation to Wales only": no `applies` rows, and not counted.
- **NEW-2 (misreads):** Marine and Coastal Access Act 2009 (ukpga 2009/23) s.323:
  - (4)/(5) items with an unbracketed "other than" ("Part 4 …, other than paragraph 1 of Schedule 8"; "Chapter 1 of Part 5 …, other than section 146 and Schedules 11 and 12"): the exceptions are read as items. s.146, sch.8.para.1 and sch.11 look up UK; the text says E+W.
  - (4)(f) "in Chapter 1 of Part 6, sections 165, 166 and 186" is read as the whole Chapter (s.150 → E+W+S).
  - (4)(h)/(5)(f) "Chapters 1 to 5 of Part 8 and section 295" adds s.293–294 (Chapter 6).
  - (2)'s same list holds the excepted sch.4.para.2 and drops Parts 1–2, Chapters 3–4 of Part 7 and Part 9.
  - (4)(i)/(5)(g) "this Part (other than section 321 and Schedule 22, except as provided by …)": Part 11 is in no list.
  - None of these is counted `list_partial`.
- **NEW-3 (misread, narrower than the agent said):** ukpga 2017/3 s.182(2) "(v) this Chapter" (Part 9 Chapter 2, ss.180–184) is left out of the named UK list, so s.180 → E+W. The qualified items are withheld by an unread row (sch.1.para.81 → nil), not given the default as the agent said.
- **Doubtful:**
  - CPA 1987 s.5(8) "Subsections (5) to (7) above shall not extend to Scotland" is plain but unread (counted).
  - SI 2008/2852 reg.1A is held in two versions, one counted.
  - ukpga 2000/32 s.80(3) "the same extent as the statutory provisions to which they relate" is not in `amendments_same` (unread, counted).
  - SI 2013/235 art.1(5) unread `*` outranks art.1(4) same `*` (over-withheld).
- Trend of NEW per round: 16, 11, 5, 5, 8, 3, 6, 6, 1, 3.

## Round 11 fixes (2026-10-27), code `e28dfe96`

Tests: `round11_reads_test.exs`, 25 tests on each law's real wording, written red first.

| Class | Cause | Fix |
|---|---|---|
| A ("In Part N— (a) X extends …, (b) Y extends …") | `Units.statements/1` split items only at "—" and ";" | items after a comma split too, only where every item states its own extent (never 1975/59's shared verb); a glued "andb" accepted |
| B, F (an item's own exception) | `Lists.list_refs` dropped any item with "except"; its bracket regex failed on nested brackets and knew no "apart from", "with the exception of" or "but excluding" | new `Extent.ItemExceptions`: in brackets (one level deep) or to the item's end; the item read less what it excepts; one holding an excepted subsection withheld; the excepted kept as `:except` (it keeps the default) and never also in the list (2000/19) |
| C (qualified companion) | the whole item dropped | the plain provisions read, the companion withheld ("… and section 73 so far as relating to those Parts"; "section 6, so far as relating to paragraphs …, and those paragraphs") |
| D (wholly qualified item) | dropped silently | withheld (`{:unread, nil, refs}`), piece by piece in an unlettered list |
| E | heading form; "za"; "section 61 to 65"; same-list items | heading takes "This section, and …", "provisions only of", "the whole of the United Kingdom"; a body starting "—a" is labelled; a singular word before a range; `Same` reads a following-list through `ListItems`; "in Chapter 1 of Part 6, sections …" names the sections only |
| "This paragraph [does not] extend(s) …" | Schedule provisions' own sentences unread | new `Extent.OwnParagraph` (the whole sentence only) |
| Lost lead "In Schedule N—" | `Units.in_schedule` qualified bare paragraphs only; "; andb" not split | bare Parts qualified too ("Part 1 of Schedule 8"); glued labels split |

**Modules:**
- new: `ListItems` (287 lines, moved out of `Lists`, now 253), `ItemExceptions` (71), `OwnParagraph` (55);
- `Credit.list_class/7` moved out of `Patterns` (481 → 481 net).

**Partial reads:** a list counts as partial only where the matching list isn't a Schedule paragraph's own statement. Otherwise "Paragraphs 15 to 17 extend only to England and Wales" would stop being withheld.

**Test changes, each a reviewed behaviour change:**
- NEW-A test: the bracketed exception is now `{:except, …}`;
- 1993/9 test: the qualified item is withheld, `s.47(1)`;
- catalogue expectations:
  - 1973/32 (list now read; citation sentence now `in_clause`, withholding nothing);
  - 1971/23 (`unread:list`);
  - 1989/29 and 1978/44 (`list:…`);
  - 1990/42 and 2014/1638 (every item read).
- The 2020/22 example's sentence now reads "Part 1 of Schedule 8 …", so its id changes. The catalogue regeneration replaces it.

Suites: extent and CV, 4,358 of 4,359 (that example).

**Next:** the round's runs, which need Jason's OK:
1. catalogue regenerate and accept, reviewed;
2. commit;
3. restore point;
4. re-read and write `extent_rules`;
5. rebuild;
6. golden;
7. check;
8. run-02 census against run-01;
9. agent check against the pass bar.

## Round 11 runs (2026-10-27, Jason: "VM closed, go ahead with the runs")

1. **Catalogue** (9 min, cold): `--accept`, 3 new patterns. Examples reviewed:
   - new examples, each checked in its text: 2025/18, 2008/4, 1999/9, 2003/39, 1989/29 (both stay safely unread), 2012/9 Sch.2 para 2 (read);
   - the rest is example rotation;
   - sweep: read forms 0.

   By outcome against run-01: list 830 → 877, unread:provision_extent 294 → 251, not_read 308 → 305, in_clause 153 → 151.
2. **Code** `e28dfe96` (hooks passed).
3. **Restore point** `cv-s05-before-round11` (extent_rules, provision_changes, provision_change_claims); snapshots `r6b.claims10`, `r6b.rules10`.
4. **Extents** (1 min): rules for 80 laws changed, 8,536 → 8,644 rows.
5. **Rebuild and golden** (1½ min): **golden 27/27**.
6. **Check:** **PASS**, our faults 0.
   - Against round 10: bound:law 3,092 → 3,091, none:unread_statement 404 → 405; unread:provision_extent 100 → 78 (OH&S).
   - **Claims** (against `r6b.claims10`): one law_text claim lost, none gained or changed.
   - The lost claim is 1984/3 s.1(6AA), changed by 2009/23 s.306. It was E+W from the default only, because round 10 dropped Part 9 from s.323(2)'s same list. s.306 now reads `:same`, which is right.
7. **Census run-02** (`backend/data/experiments/cv-s05c-shape-mining/run-02/`, `b06ad5cd`; run-01's scripts unchanged, formatted only):

   | Measure | run-01 | run-02 |
   |---|---|---|
   | items read | 801 | 851 |
   | withheld | 34 | 50 |
   | not held (missing / unread / partial) | 69 / 25 / 2 | 13 / 16 / 4 |
   | laws with drops | 33 | 10 |
   | over-reach hits | 14 (5 real) | 4 (all known check limits) |

   Of the 10 laws:
   - 2 are known not-drops: 1975/21, 2019/696.
   - 5 are artefacts of the per-item check, each traced with the reader right: 1986/50, 2000/19, 2004/20, 2020/21, 2009/23(4)(f). 2021/30 is an improvement: Sch.15 is now `same` only.
   - **3 are real residuals, now known and counted:**
     - (R1) 2009/23 s.323(2)(f)(iii), "section 314 (which inserts … into the Energy Act 2008)": the other-law test has no word boundary;
     - (R2) 2015/7 s.56(2)(b), a same-extent item with its own "other than";
     - (R3) 2008/4 s.152(c), "section 113 (together with such of the other provisions of Part 7 as relate to …)".
   - **Pass bar 1 holds:** classes A–F are at zero, apart from the logged residuals.
8. **Agent check:** next, on a new seed (16).

## Agent check, seed 16 (round 11): laws 48 OK / 1 WRONG / 1 doubtful; changes 50/50 — FAIL (1 NEW, a wrong bound)

The sample repeats (two draws identical). The prompt is the skill's, with round 11's rules, the KR residuals and the decided pass bar. The round 10 NEW are gone (2009/23, 2017/3, 2014/1638 not sampled again, but the census confirms them).

**NEW-1 (verified; a silent drop that places a wrong bound): ukpga 1977/45 s.65(10).** The sentence:

> "In this Act— (a) Part V and, so far as there provided, the provisions mentioned in section 63(2) above extend to Scotland; (b) the following provisions extend to Northern Ireland namely— …; (c) … so far as they amend …; (d) subsections (4) and (5) above and Schedules 12 and 13, so far as they relate to— … but save as aforesaid, this Act extends to England and Wales only."

- The whole sentence is credited `default:E+W`, and only (b)'s "namely—" list is read, and that in part.
- (a), (c) and (d), and "subsections (1), (3) and (6) to (10) of this section" in (b), are neither read nor counted unread.
- **Wrong bound:** HSWA 1974 s.15(6)(d), inserted by 1977/45 Sch.12, is stored `law_text:extent=E+W`. By s.63(2) and s.65(10)(a), Sch.12 so far as it relates to HSWA has effect in Scotland, so the bound should be E+W+S, or withheld.
- **Cause:** a default sentence that carries lettered items before its "save as aforesaid" default; the items aren't read as lists.

**Doubtful:** ukpga 1995/25 s.125(8), "Part III …, and Schedule 24 … so far as relating to Part III", withholds Part III too. The companion rule wasn't applied because the qualified companion is a Schedule, not a section. It withholds rather than misreads (counted), so it isn't NEW.

**Round 12 (proposed):**
- NEW-1;
- the residuals R1–R3;
- the 1995/25 companion (a Schedule as the companion).

Then the same runs, census run-03 and a fresh seed.

## Push (2026-10-27, Jason: "push then round 12")

The push was blocked by one Dialyzer error, in `Credit.list_class/7`'s spec (`Patterns` passes a nil unread class). It was fixed in `2a8f0811` and pushed; the remote is at `2a8f0811`.

## Round 12 (2026-10-27), code `f1f70bc2`, `e779fe71`, `b09df1be`

Tests: `round12_reads_test.exs`, 14 tests on the laws' real wording.

| Item | Fix |
|---|---|
| NEW-1 (1977/45 s.65(10)) | `Extent.QualifiedItems`: in a sentence ending "but save as aforesaid, this Act extends to …", a lettered item qualified by "so far as …" has its qualified pieces withheld. Sch.12 and Sch.13 are withheld, so HSWA s.15(6)(d) gets no bound instead of a wrong one. |
| R1 (2009/23 s.314) | `ListItems`' other-law test needs a word boundary ("into the Energy Act") |
| R2 (2015/7 s.56(2)(b)) | `Same`: a subject with its own exception is read less it; an exception naming another Act leaves the statement unread (2002/26 s.91) |
| R3 (2008/4 s.152) | "(together with such of … as relate to …)": the item read, the rest withheld |
| 1995/25 s.125(8), doubtful | `Named`: a subject with a qualified piece reads its plain pieces, the qualified withheld. Never an exception list's items. |
| 2015/7 s.56(6), 2021/30 | `Extent.PartLead`: "In Part 5— (a) an amendment or repeal has the same extent …" = the amendments Part 5 makes |
| Found in the trace | "X and, so far as relating to those provisions, Y" qualifies Y (2006/47 s.66). A withheld subject keeps only its words before the qualifier (2014/6 s.140). A provision after an "and" in the object is withheld (2015/7: s.37(6)). |
| Found by the census's new default-sentence check | 1972/71 s.66(a) (read for Scotland); 1994/21 s.68 ("This Act, except for— a …, b …": comma items read as also NI) |

**The trace caught two regressions of my own before they were committed or run past the check:**
1. The first `QualifiedItems` fired in every lettered sentence. It withheld HSWA Part I through s.84(1)'s exception list, so **400 OH&S changes lost their SI powers' placement** (bound:law 3,091 → 2,652). It was narrowed to the "save as aforesaid" shape.
2. `Named`'s qualified rule read an exception list's items as "not NI" statements (1976/55 s.27, 1995/45 s.18). It now never reads exception-list items.

**Lesson:** compare the check's counts with the round before after every extents run, not only at the end. My first rules diff query was also wrong: an unparenthesised `EXCEPT … UNION ALL … EXCEPT` shows only lost rows.

**Runs:**
- restore point `cv-s05-before-round12`, snapshots `r6b.claims11`, `r6b.rules11`;
- final chain: catalogue 0 new and 0 reading differently; extents (24 laws' rules changed against round 11); **golden 27/27**; **check PASS**;
- bound:law unchanged at 3,091; 11 changes relabelled none:same_or_not_named → none:unread_statement (no bound either way).

**Census run-03** (`2e28feb7`):
- drops: 10 laws, all known not-drops or check artefacts, R1–R3 fixed;
- over-reach: 4 known check limits;
- new default-sentence check: 23 sentences, 8 items, all class KX (an exception list's qualified item keeps the default, round 6 design) apart from 1972/71 s.64(2) (KQ, minor).

**Pass bar 1 holds.** Skill updated with round 12's rules and classes KX and KQ. Agent check: seed 17.

## Agent check, seed 17 (round 12): laws 42 OK / 5 doubtful / 3 WRONG (2 NEW + 1 known open); changes 49 OK / 1 doubtful — FAIL (3 NEW)

The sample repeats; the prompt is the skill's (round 12 rules, KX, KQ). Each NEW was verified against the stored rows and the text. None touches a sampled change.

- **NEW-1 (wrong bound): uksi 2020/818 reg.1A.** "The following provisions … do not apply in England and Wales or Scotland— (a) in regulation 16, paragraphs (4) and (5); (b) regulation 17; (c) in regulation 18, paragraphs (8)(b) and (9)."
  - Stored: `applies_not E+W+S {reg.16, reg.16(5), reg.17, reg.18, reg.18(9)}`.
  - The locator "in regulation 16, paragraphs (4) and (5)" is read as all of reg.16, and reg.16(4) and reg.18(8)(b) are missing.
  - This is the `Applies` reader; round 11's locator rule covers lists only.
- **NEW-2 (silent drop, no wrong bound): uksi 2016/1154 reg.1(3).** "They apply in relation to— (a) England and the sea adjacent to England …, and (b) Wales" is unread and uncounted; the sweep calls it `noise:procedure`. The E+W extent bounds every change.
- **NEW-3 (wrong bound): uksi 2013/1506 reg.3(2).** "Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f) and Chapter 3 of Part 3 … shall extend to Northern Ireland."
  - Stored: `named NI … reg.34`. The space in "34 (f)" loses the sub-letter, so reg.34(a)–(e) look up as UK (text: E+W+S).
  - Also: reg.3(3) "In so far as regulations 4, 31, 32 and 38 apply to Chapter 3 of Part 3 …" withholds the object reg.19–29 (an over-withhold; the named NI outranks it).
- **Known, open:** 2009/23 s.323 "Chapters 1 to 5 of Part 8 and section 295" holds s.293–294 (Chapter 6): R10 NEW-2's residual.
- **Doubtful:**
  - 1986/44 s.68(6): KX items' plain pieces keep E+W+S where the text gives UK. This questions the round 6 design for the plain pieces, and the law is missing from run-03's default check.
  - 2007/15 s.147(2) "The other provisions of this Act extend only to England and Wales" is unread (counted).
  - 2015/20 s.114(2): a comma list withheld whole (counted).
  - 2001/10: `not NI` and `unread` both held.
  - 1982/48: an object withheld.
  - Change 28 is labelled unread_statement though its lookup is `same`.

NEW per round: 16, 11, 5, 5, 8, 3, 6, 6, 1, 3, 1, 3.


## Round 13 (2026-10-27): the CV-S05d fix list

Jason 2026-10-27: "I don't need to look at the list - we should have a clear idea about what right looks like by now". Fixes S1–S17 from CV-S05d run-03 (`backend/data/experiments/cv-s05d-whole-reader-census/run-03/out/triage.md`). Each has tests on its law's real words (`round13_reads_test.exs`; `sub_path_test.exs`, `ref_list_test.exs`, `application_clause_test.exs`). Commits `714ec6de`, `5bea7724`, `23c0c8df`, `21bc0306`, `7d9db213`, `9eab994c`.

**S2 sub-letter runs:** `AmendingLaw.SubPath` (new). A bracket continuing the one before replaces it at its own level, with ranges spelt out. `RefList` and `Applies` use it: "2(1)(a) and (b)", "(2)(aa)", "34 (f)", "(w)(i) and (ii)", "(1A), (2)(b) and (2ZZA) to (2ZZC)".

**S11 locators:** "in regulation 16, paragraphs (4) and (5)" is those paragraphs (`RefList.owned/1`).

**S1 exception lists:** `Extent.ExceptionList` (new) holds every wording and finds each exception sentence anywhere in the clause:
- the forms: "This Act, except— …"; "Except for the following provisions …— …, this Act does not extend …"; "Except for section 8, …"; "does not extend to Scotland, with the exception of— …"; "except for the following provisions, shall not extend to NI, that is to say, …"; two clauses in one sentence (1973/26: default E+W);
- items read by `ListItems`: plain pieces read, and a qualified item keeps the default (KX) unless its qualifier points back ("so far as relating to those paragraphs");
- the clause's other "does not extend to" places taken off the default (1973/37: E+W).

**S13 owners:**
- "subsections (1) to (6) of section 11", "Paragraphs (28) … of regulation 5" and "sub-paragraph (2) of paragraph 3 of Schedule 1" are those subdivisions (`RefList.owned/1`);
- "in Schedule 2, Part II and paragraph 11" is that Schedule's;
- a bare "subsections (4) and (5) above" or "… of this section" is the clause's own, never one after "subject to", "within", "by" or "in".

**S3 "or"-lists:** in Parts, Schedules and numbers; "Part 1, 8 … or 19 of Schedule 18" is never the Act's own Parts (2007/28: 109 provisions).

**S4 qualified asides:** "(and section 55 so far as …)" and "(including Schedule 13 so far as …)" are withheld, never dropped (`Extent.Asides`, new, also taking `together_with_such`).

**S5 a provision's own:** subsections, "this Chapter", and "; and this section extends also to Scotland".

**S6 statements in one sentence:** compounds split ("… and sections 34 and 35 extend to Scotland only"), within an item too, an item's "in Part IV," lead dropped; the late-verb list "the following provisions of this Act— (a) …, extend to P" (`Lists.late_lists`).

**S7 defaults:** "extends to Scotland (subject to …) and Northern Ireland"; "not extend to Scotland or, . . . to NI"; "extends only to E+W, except that— (a) …" (items read as their own statements).

**S8 territorial application (KA):** `ApplicationClause.parse_bound/1` (new; `parse/1`, live status, unchanged) reads things in a place and lettered places as the law's application bound. Provision-level "applies in relation to live fish … in Wales" is read too; a disapplication of things is fitness scope.

**The other wordings:**
- S9: "to the extent that" is a qualifier.
- S10: repealed dots inside number lists.
- S12: "the enactments which they amend or repeal".
- S14: "cease to apply" is not applying.
- S15: "229 (and Schedule 22), 230".
- S16: "except as provided by section 189" is no item.

**Module sizes:** `Units.statements` moved to `Extent.Statements`; `units.ex` 249, `list_items.ex` 320.

**Checked on real text** (fresh reads of the fix-list laws, `Extent.of`): every wording reads as its text states. The census's 2014/2 s.46 flag was a finder miss: "(c) section 46" is in the list plainly.

**Runs next (ask Jason):** `mix lat.extent_patterns --accept` and the fixture review; restore point; one extents run; golden; check; census run-04 (CV-S05d); agent check seed 18.

**Runs** (Jason 2026-10-27: "VM is closed, start"):
- **Catalogue** (`5fa36bbb`): 27 new patterns. The 12 examples now reading differently were each checked in the text and accepted: defaults read, exception lists read, and unread statements now counted where they were silent before.
- **Restore point** `cv-s05-before-round13` (extent_rules, provision_changes, provision_change_claims); snapshots `r6b.claims12`, `r6b.rules12`.
- **First chain:** extents (1 min), **golden 27/27**, **check PASS**.
- **Census run-04, round 13's own check**, found regressions from round 13's first pass, all fixed and re-run (`fa71db4b`, `fbf94b8b`):
  - loose application reads, where cases were read as places: "a freezing order made … by a magistrates' court in …", "as they apply to", "an agent who …", "as if", and another law's section;
  - a range before a describing bracket;
  - "in Schedule 2, …, in Schedule 4, paragraphs …";
  - "by virtue of subsection (6)" read as an item;
  - glued paragraph numbers ("only.3 They apply …");
  - 2021/30's Part 6 lead (a bracket, same-extent exceptions).
- **Final chain:**
  - catalogue: 4 new patterns; 8 patterns gone (round 13's own loose reads) and 2021/30 → `list:named:E+W`;
  - extents, then **golden 27/27**, then **check PASS** (our faults 0); OH&S outcome counts unchanged;
  - claims against `r6b.claims12`: **0 lost, 4 gained**, all right: SI 2016/1154's changes to SI 2015/483 get E+W ("They apply in relation to— (a) England … (b) Wales"); SI 2000/2853's HSWA Part I change gets E ("apply in relation to local authorities in England").
- **Census run-04** (`a75e80b8`):
  - silent candidates 113 → 64 (51 cleared, 2 new, both finder-side); unnamed refs 358 → 234;
  - the fix-list check: every wording reads as its text states.
- **Agent check:** seed 18 (sample repeatable), round 13 rules added to the skill's prompt. The result is below.

## Agent check, seed 18 (round 13): laws 48 OK / 2 WRONG; changes 50/50 OK — FAIL (2 NEW, one root)

The sample repeats; the prompt is the skill's, with round 13's rules. Every change is right. Both NEW defects verified:

- **NEW-1: SI 2005/2060 art.1(4).** "This article extends to England and Wales, Scotland and Northern Ireland, and paragraphs 1 and 14 of the Schedule, and article 3 in so far as it relates to those paragraphs, have the same extent as the provisions modified."
  - Only "This article" is read (`named UK {reg.1}`); the second statement is dropped.
  - The sentence is credited `list:named`, because the subject before the first verb is "This article".
  - Schedule paras 1 and 14 take art.3's default S (wrong bound; the text gives the modified provisions' extent, UK).
- **NEW-2: ukpga 1981/45 s.31(b)** "Part I of the Schedule" (do not extend to Scotland) is dropped, yet credited `list:not:S`. The repeals in Part I of the unnumbered Schedule keep the UK default.

**Root, one cause:** the shared namer `Commencement.Order.ref` names an unnumbered Schedule's ids as junk refs (`schedule-part-I` → `sch.part`, `schedule-paragraph-1` → `sch.paragraph`, `schedule` → nil). This is CV-S02a's K10 tell-tale, deferred. So nothing can name these provisions, and `Credit` reads "Part I of the Schedule" as the Act's own Part I.

**Not NEW:**
- ukpga 1981/45 s.11 is `section-ll` in the CLML (KD).
- SI 2013/1506 reg.3(3) withholds the qualifier's object, but no wrong bound results (named outranks unread).

**Decision for Jason:** name unnumbered Schedules in the shared namer (`sch.pt.I`, `sch.para.1`, `sch`) and read "of the Schedule" in `RefList`; or count these sentences unread only (no wrong bound fixed).

**Root fix for seed 18** (Jason 2026-10-27: "Do 1 the root"; "Triple it is"). Code `ac2b4798`, `39ca4aa9`, `4403cccd`.
- **Schedule names** (`Order.ref`):
  - an unnumbered Schedule is `sch` (`sch.pt.I`, `sch.para.1`);
  - a paragraph whose id sits in a Part is the triple `sch.N.pt.R.para.M`, nested Parts kept.
  - The whole-store scan: 368,103 Schedule ids, no crash; the Part-less form would have collided 439 times in 58 laws.
- **Matching** (`RefList`): reads "of the Schedule" and "paragraphs … of Part I of Schedule 25"; `covers?` takes a citation without its Part as its triple's paragraph.
- **SI 2005/2060:** the same-extent second statement is read, its qualified piece withheld.
- **CV-S02a K10 closed.**
- **Known limit** (`Pointer`/`Locator` stay Part-less): on the V1-00 v0.2 list with #169 (`3848b2a2`).
- **Lesson** (Jason: "40 minute of compute as part of a debug and test routine - madness!"): the first chain crashed on `schedule-part`, which a 1-minute whole-store scan finds. Pre-flight in seconds, one acceptance chain per round (memory `preflight-before-chain`).
- **Acceptance run** (extents cold 9m47s):
  - golden 27/27; extent, feed and markup checks PASS (our faults 0);
  - 53 feed, 5 markup and 2 extent catalogue examples accepted after review; schedule naming only, apart from two extent classes that now read (SI 2016/1142 Part 2 of the Schedule) or are counted (SI 2009/462);
  - census: silent 64, unnamed 251/44;
  - claims against `r6b.claims12`, Parts set aside: target renames (a Part → its paragraph's triple) with the same values, and 3 real moves, all right:
    - HSWA s.33(1)(m) by 1981/45 → E+W+NI (seed 18 NEW-2);
    - SI 1998/494 reg.4(3)(e) by SI 2005/2060: the S bound is gone, now same extent (NEW-1);
    - the two application gains (SI 2016/1154 E+W, SI 2000/2853 E).
- **Agent check:** seed 19 (repeatable).

## Agent check, seed 19 (round 13 after the root fix): laws 41 OK / 2 WRONG / 7 doubtful; changes 48 OK / 1 WRONG / 1 doubtful — FAIL (1 NEW wrong bound, 1 NEW no bound)

Seed 18's two NEW are gone. Verified with fresh reads:

- **NEW-1 (wrong bounds):** "Part N of Schedule M" never reached the Part's paragraphs where legislation.gov.uk numbers the Schedule straight through (ids without the Part: `schedule-10-paragraph-8` inside `schedule-10-part-2`).
  - SOCPA 2005 s.179(6)(d): Sch 10 paras 7–10 were E+W+NI; the text gives NI.
  - SI 2016/1142 art.1(5): change 22 lost its E+W+NI bound.
  - Police and Justice Act 2006 s.54(2) "Parts 5 and 6 of Schedule 1 (and section 1(3) so far as …)": withheld whole, because the aside's nested "1(3)" broke the qualified-aside patterns. Sch 1 Part 5 paragraphs were E+W; the text gives the UK.
- **NEW-2 (no wrong bound):** PJA 2006 s.53(4), a commencement list ("… so far as they extend to Scotland"), was read into unread rows.

**Fixed** (`9a721593`), with tests on the real words:
- `Parts`: "Part 2 of Schedule 10" and "Part 2 of the Schedule" are the paragraphs the Part holds in the document;
- the aside patterns allow one nested bracket;
- `Statements`: a commencement list's items are no statements.

Fresh reads: SOCPA Sch 10 para 8 NI; PJA Sch 1 para 40 UK; PJA Sch 14 para 17 same; SI 2016/1142 Sch para 3(3) E+W+NI.

**Doubtful, no wrong bound (noted for later rounds):**
- 1975/71 s.129(6) (amendments of the HCDA/NIADA 1975, now repealed);
- 2015/2 s.96(6)(h) "Parts 1 to 4 of Schedule 10" (withheld by `*`);
- SI 2004/1822 "paragraphs 2, 3, 4 … 15 of the Schedule … extend to Scotland only" (unread `*`);
- SI 2013/1387 reg.1A "These Regulations apply in England and Wales, and Scotland" (counted);
- 1989/15 s.194(8)(b) "Part V" withheld with its qualified siblings;
- PJA 2006 s.1(3): E+W through "Parts 1 to 5 extend to England and Wales only" (explicit only outranks the withheld aside, by design).

Acceptance run and seed 20 next.

**Acceptance run for the seed 19 fixes:**
- golden 27/27; extent, feed and markup checks PASS (our faults 0);
- claims against `r6b.claims14`: 0 lost, 1 gained, right: HSWA s.34(1)(d) by SI 2016/1142 → E+W+NI (seed 19 change 22).
- **Census:** silent 64 → 62. Unnamed 251 → 793 (53 laws). That rise is the finder: the reader now expands "Part N of Schedule M" to the Part's paragraphs, which the finder names only as the Part. Not reviewed.

**Stopped here** (Jason 2026-10-27: "stop when the acceptance run is done"). Next:
- census finder: name a Schedule Part's paragraphs as the reader does (expected to clear most of the new unnamed);
- agent check, seed 20.

## Strategy to close (2026-10-27, before compaction)

**Closure aims:** the pass bar, Jason 2026-10-27.
- census classes at zero, apart from known counted ones;
- golden all-pass; the check at our faults 0 (and the feed and markup checks, since `Order.ref` is shared);
- an agent check with no NEW that places a wrong bound or silently drops.

**Steps, in order.** Pre-flight in seconds; one acceptance chain per fix batch, never as a debug loop.
1. **Finder (CV-S05d), read-only, minutes.** Name a Schedule Part's paragraphs as the reader does. Re-run the census as run-05, and triage every silent and unnamed item to one of: known class, finder miss, doubtful, or real.
   - Done when nothing is untriaged.
   - Real items found here go to step 3, not to an agent.
   - ✅ **Done 2026-10-27 (run-05, `cv-s05d…/run-05/out/triage.md`).**
     - Unnamed refs: 793 → 320, all triaged. Silent sentences: 64, all triaged.
     - 16 real wordings, R1–R16. R1 is a regression of the seed 19 fix: in uksi 2006/1407, "Paragraphs … of Part 1 of Schedule 1 to this Order apply in relation to England only" gives every paragraph of the Part. "to this Order apply" also sets the whole SI's application, an older `ApplicationClause.parse` prefix fault.
     - Q1 goes to step 2.
2. **Decide the residuals with Jason, one line each, fix or known class.** Recorded in the skill's known classes:
   - 2009/23 "Chapters 1 to 5 of Part 8" holding Chapter 6 (R10 residual);
   - 1986/44 KX plain pieces;
   - seed 19's doubtfuls: 1975/71 s.129(6), 2015/2 s.96(6)(h), SI 2004/1822 unnumbered-Schedule paragraphs, SI 2013/1387 reg.1A, 1989/15 Part V, PJA s.1(3).
   - ✅ **Decided 2026-10-27:**
     - Q1, the qualified companion that points back, keeps the default (KX).
     - The seed 19 and census doubtfuls are logged as known (KW).
     - R14–R16 are logged as known (KT).
     - The fix batch is R1–R13 plus 2009/23's Chapters 1–5 reaching Chapter 6 ("Bounds + schedules").
3. **One fix batch** for whatever steps 1 and 2 make real: tests, pre-flight, one acceptance chain.
   - ✅ **Done 2026-10-27 (`89a580a6`; evidence `cv-s05d…/run-06`).**
     - **Fixes:** R1–R13 and 2009/23, with 17 tests (`census_run05_reads_test.exs`) and the new module `Extent.NestedLocators`.
     - **Pre-flight, whole store:** 21 of 3,358 laws changed, all checked against their text. That covers the 15 intended; 2014/12 and 2016/12 improved by the item-exception owner fix; 2019/453 newly withheld. Live status is untouched: only 2006/1407 has the "to this Order apply" wording, and it is revoked.
     - **Acceptance chain (one):**
       - golden 27/27; extent, feed and markup checks PASS (our faults 0); `law_text` claims unchanged against `r6b.claims15`;
       - catalogue: 1 example accepted, 4 re-keyed; the feed catalogue's 31 Schedule-triple renames from round 13 accepted;
       - census run-06: silent 64 → 57, nothing new that is real.
     - Full suite: 9,178 pass. Restore point `cv-s05-before-run05-batch`; snapshots `r6b.rules14`, `r6b.claims15`.
4. **Agent check, seed 20.**
   - ✅ **PASS 2026-10-28.** Seed 20 drawn twice, identical; the sweep has 0 uncaught sentences in a read form.
     - Laws: 49 OK, 1 doubtful. 1975/21 is KT: "188(3) to (8) 189" leaves s.188(4)–(8) and s.189 on the default S. That's historic, and the KT wording is now corrected.
     - Changes: 49 OK, 1 doubtful. A CPA 1987 Sch.3 change is labelled `none:unread_statement` where its lookup is `:same`: a label only.
     - No NEW: no wrong bound, no silent drop.
     - Withheld observations go to the open bugs: 1989/38 s.29(5)–(6) cross-subsection exception list; CPA 1987 s.5(8) plain statement stored unread; the `none_why` label.
   - Pass: close.
   - A NEW that places a wrong bound or silently drops: fix it with tests and fresh reads, one acceptance chain, seed 21.
   - Doubtful findings with no wrong bound: log them as known; they never block.
5. **Close-out:**
   - close CV-S05 (frontmatter, bugs, lessons);
   - close CV-S05d: run-01 to run-05 evidence, and the permanent read-only mix task decided (build, or defer to a PENDING session);
   - the application scope hand-off stays PENDING; the Pointer/Locator naming stays on the v0.2 list (#169);
   - CV-00 meta updated; push, listing `origin/main..HEAD` first.

**Schedule naming, kept (Jason asked whether the triple was wrong):** the name is the document's own address. Sequential numbering (ids without the Part) gets `sch.N.para.M`; the triple appears only where legislation.gov.uk's id holds the Part, mostly where numbering restarts per Part (439 collisions in 58 laws without it). Seed 19 NEW-1 was not caused by the triple: a Schedule Part never reached its Part-less paragraph ids under any naming. Residual risk: a Part-less citation in a restart Schedule matches every Part's paragraph of that number (over-broad, rare); tighten with the document if an agent finds a case.
