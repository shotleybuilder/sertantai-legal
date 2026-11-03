---
session: 'LAT Change Pipeline: Parked Bugs'
status: pending
release: v0.1
opened: '2026-11-03'
parent: archive/change-vocabulary/2026-10-30-cv-s12-retrospective.md
bugs:
- pattern: 'Schedules of amending laws not held (KS): SI 2019/720 Sch 2''s substituted CLP articles make new numbers that get no insertion (Art 2(15), 37(7)-(9), 52(5)-(6)); EPA 1975 Sch.15 (HSWA s.28(9))'
  category: upstream (CV-S09)
  module: CLML store / Amendment.Reader
  affected: CLP-wide; HSWA s.28(9)
  fix: Fetch the amending laws' schedules (one hop), then read
  status: open
  step: Sources
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'S01 sources gate fails today: 103 needed documents not fetched (OH&S, 2026-10-30), 96 of them EU amenders of REACH (70) and CLP (26) — territory bodies and introductions; 7 UK. CV-S01 passed with 0; the needs grew with later steps and nothing re-ran the gate'
  category: workflow / sources gate
  module: mix lat.sources (CV-S01); CV-S11 'sources check re-run after each rebuild'
  affected: 103
  fix: Jason to decide the fetch (EU territory isn't read, KE); re-run the gate in the next pass from step 1; CV-S11's automatic re-run
  status: open
  step: Sources
  moved_from: 2026-10-22-cv-s10-measures
- pattern: 'Feed range spans rows inserted later by other laws (SI 2009/1348 ''reg. 19A-19F'' by 2011/1885 also on 19AA, 19AB, 19BA-19BC, 19CA, 19CB, 19AZA): one key on unrelated provisions'
  category: feed reader range (found by the spread tell-tale, round 5)
  module: ChangeVocabulary.Readers.Feed (spanned) / EffectTarget.span
  affected: 1 of 32 spread keys in OH&S
  fix: A range covers only names of its ends' own sequence (no deeper suffix, e.g. 19AA in 19A-19F); a row inserted after the effect by another law is not in it
  status: open
  step: Feed reader
  moved_from: 2026-10-22-cv-s07-merge
- pattern: 'Rows inserted later reached by an earlier change: a feed range (OLA 1984 s.1(6A)-(6C) by 2000 c.37 also on s.1(6AA), inserted 2010) and markup nesting a later Addition inside an earlier one (HSWA s.11(4AA): the 2013 c.32 key placed on the row 2015 c.20 inserted)'
  category: feed reader range / markup reader placement (round 7 J, doubtful)
  module: ChangeVocabulary.Readers.Feed (spanned), Readers.Markup (nested Additions)
  affected: 2 seen (1 doubtful in J)
  fix: 'Never place a change on a row a later change by another law inserted: the range excludes it; an outer Addition doesn''t place on the inner Addition''s provision'
  status: open
  step: Feed reader
  moved_from: 2026-10-22-cv-s07-merge
- pattern: 'Feed reader: ''#made'' twin placed only on a range''s ends (P8); ''substituted for Art. 15(1)'' over ''Art. 15(1)(1A)'' reads (1A) substituted not inserted (P10); ''omitted in earlier amending provision'' given provision level (P5); ''revoked in part'' placed on another law''s provision (P4)'
  category: upstream (CV-S09)
  module: ChangeVocabulary.Readers.Feed
  affected: CLP Art 2(39)-(42), REACH Art 15(1A), REACH Art 3(A2), HSWA s.48
  fix: Spread with_maker over the record's targets; extra numbers inserted; level from the law text
  status: open
  step: Feed reader
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'Feed effect ''HSWA s.48 revoked in part'' by SI 1996/1513 reg.13 looks false: reg.13 omits words from SI 1977/500 reg.3(1); 1996/1513 touches s.48 only by reg.11 (applied with modifications, its own feed effect)'
  category: upstream / legislation.gov.uk feed error
  module: (feed; derived tier)
  affected: 1
  fix: report to legislation.gov.uk or a known-feed-error list; the law text, where read, should outrank it
  status: open
  step: Feed reader
  moved_from: 2026-10-22-cv-s10-measures
- pattern: 'EU markup inside unnumbered ListItems placed on the Article, not its point (Directive 98/24 art.2(b)(i), (b)(iii): O002001M001/M003; rows art.Article 2(b)(i)/(iii) exist), so each meets two same-operation rivals and stays apart'
  category: markup reader placement (known limit KL-EU-list, round 3)
  module: ChangeVocabulary.Readers.Markup (placement)
  affected: 4 C items in OH&S (one Directive)
  fix: 'Place EU markup on its ListItem''s point by the item''s position in the ordered list (round 6 pointer: the rows exist and the ListItems carry NumberOverride; only their source_xml_id is empty)'
  status: open
  step: Markup reader
  moved_from: 2026-10-22-cv-s07-merge
- pattern: 'Markup ChangeIds at schedule-part wrapper ids carry no markup claim (Repeal/Addition pairs; SI 2008/1597 sch.2.pt.9, sch.2.pt.11): J and markup coverage understated'
  category: upstream / markup reader (CV-S03)
  module: ChangeVocabulary.Readers.Markup (schedule paragraph-wrapper ids)
  affected: null
  fix: place markup on schedule-part wrappers (schedule-N-part-P-paragraph-wrapperXnY) as the Part
  status: open
  step: Markup reader
  moved_from: 2026-10-22-cv-s10-measures
- pattern: Shared namer drops nested schedule ids (schedule-N-part-P-paragraph-M → sch.N.pt.P; unnumbered schedule-paragraph-1 → sch.paragraph)
  category: namer
  module: Commencement.Order.ref/1
  affected: 48 collisions in the family's feeds, none in the body
  fix: with the schedule naming decision when schedules are parsed (CV-S02a, deferred)
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s02-feed-reader
- pattern: '"Part IV, apart from section 66 and Schedule 9 …" in a clause list item: the apart-from after a Part item not read as its except'
  category: commencement reading
  module: LawStart.Provisions
  affected: Access to Justice Act 1999 s.108(3)(b) (a catalogued pending class)
  fix: read "apart from" after an item as that item's except
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s04-commencement-reader
- pattern: '"Chapters II and III of Part I" in a clause list read as the whole Part I'
  category: commencement reading
  module: LawStart.Provisions
  affected: Freedom of Information Act 2000 s.103(2) (a catalogued pending class)
  fix: Chapter lists of a Part → pt.N.ch.X each
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s04-commencement-reader
- pattern: A Schedule's Parts in an Act's clause ("Parts III and IV of Schedule 16") dropped rather than read as sch.N.pt.X
  category: commencement reading
  module: LawStart.Provisions
  affected: FOIA 2000 s.103(2), Access to Justice Act 1999 s.108(3)(f) (a catalogued pending class)
  fix: read Part lists of a Schedule as sch.N.pt.X
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s04-commencement-reader
- pattern: An items-first order's "in Schedule 8, the entries relating to:—" heading reads nothing
  category: commencement reading
  module: Commencement.Order (split_head)
  affected: SI 1978/1583 (a catalogued pending class)
  fix: the entries head as sch.N in relation to in the items-first form
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s04-commencement-reader
- pattern: 'An Act whose clause leaves its provisions to orders in other words still falls to Royal Assent: "Apart from section 54(1) and (2), the preceding provisions of this Act come into force in accordance with orders made by the Treasury" (Tax Credits Act 2002 s.61), "the remainder of this Act shall come into operation on such day as Her Majesty may by Order in Council appoint" (ukpga 1962/58, its rest unread); the SOCPA class, older'
  category: commencement
  module: LawStart.Clause (general / by_order forms)
  affected: unmeasured (2 seen in the catalogue)
  fix: read "in accordance with orders" and "the remainder … by Order in Council" as by order
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: A schedule's commencement not traced through its introducing regulation (NISR 2003/152 Sch.7 Pt II via reg.15(2)); 'This section has effect from' unread (LGA 1985 s.84(3)); SOCPA s.178(1)(a) bare numbers after a parenthesis dropped
  category: commencement reader
  module: Commencement.OwnClause / Readers.AmendingLaw
  affected: 2
  fix: 'Schedule → the provision giving it effect: Commencement.ScheduleEffect (d72ce36d); list items past an aside (d229ba7b, a541f728). Still open: ''has effect from'' (LGA 1985 s.84(3))'
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s08-evidence
- pattern: Commencement orders held in the store but not read as rules (SI 1995/2950, 1997/1097, 2006/266, 2013/1869, 2016/603, 2020/1662; SSI 2009/319, 2013/51); SI 2015/994's 48 rules stored as commencing SI 2015/1637 (title-prefix match); a repealed commencement section falls back to Royal Assent (EPCA 1978)
  category: commencement reader
  module: Commencement.Orders / LawStart
  affected: 60
  fix: Read held orders' Schedules; resolve 'the Act' by the order's enabling Act; no Royal Assent default where the commencement section is gone
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s08-evidence
- pattern: 'Commencement reader: an order list cut at ''(except …)'' (SI 1995/2950, P6); ''section 10(6) and (7) (so far as aforesaid)'' read as {s.10(6)}; an NI-only order rule never emitted (TR); a catch-all ''so far as not already in force'' order dating provisions earlier orders (not held) brought in (SI 1997/134, KC-order); an amending law''s whole-law date not attached to its undated substitution (V8, SI 1989/2367)'
  category: upstream (CV-S09)
  module: Commencement.Order / Commencement.Amending
  affected: HSWA s.10, s.28(10)[S]; 2007/19 s.2(1)(d); EA 1989 repeals; SI 1989/462 reg.4, reg.7
  fix: Read past parenthetical exceptions; emit NI rules; leave catch-all dates unknown where earlier orders are missing; attach whole-law dates
  status: open
  step: Commencement reader
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'Seed 20-22 observations with no bound effect: 1987/43 s.5(5)-(7) row carries source_ref s.49 (words in s.5(8)); a change from the law''s own text (key schedule-N-paragraph-M) labelled by affecting claims only (same_or_not_named / unread_statement where same); SI 2013/1506 reg.3(3) unread row includes the qualifier''s object; 2015/20 s.114(2) withheld whole, plain items included; 1977/45 s.65(10)(a) Part V withheld where readable'
  category: extent
  module: Extent.Named source_ref / lat.extent_check none_why / Extent.Unread
  affected: 5 laws, no wrong bound
  fix: source_ref from the unit; none_why falls back to the change key's own provision; Unread.subject before the qualifier; read plain items of a partly qualified sentence
  status: open
  step: Extent reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: LRRA 2006 s.34(3) "The repeals in the Schedule have the same extent …" stored as `same *`, not the Schedule
  category: extent
  module: Extent.Same
  affected: 1
  fix: subject "The repeals in the Schedule" → the Schedule
  status: open
  step: Extent reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: 'List sentences still read in part, counted unread:list_partial: 1974/44 s.131 (text glitches); 1975/21 s.463(1)(a) "(8) 189" (no comma) — 2013/24 s.102 now read (round 9)'
  category: extent
  module: Extent.Lists / Named
  affected: 2
  fix: tolerate missing separators
  status: open
  step: Extent reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: 'Target statements inside an exception or after a lead-in left unread (bound withheld): 1993/28 s.188(7), 2016/20 s.85(2), RSA 1993 Sch.6 Pt I note, 2002/17 s.42(7), 2015/2 s.96(3)'
  category: extent reader (known limit)
  module: Extent.Targeted
  affected: 5 sentences, none bearing on OH&S
  fix: Read the exception's targets with the lead's place when a family needs them
  status: open
  step: Extent reader
  moved_from: 2026-10-28-cv-s05f-target-named-extent
- pattern: 'Amendment reader reads an amending provision but yields no rule for the amended law (7,448 golden-law changes; 3,531 where the amending law has no rule for that law at all: EU law amended by SIs, Senedd Acts on TCPA, laws amending themselves)'
  category: reader yield
  module: Amendment.Reader / Amendment.Collect
  affected: 7448
  fix: not chased (feed is the coverage baseline); revisit in CV-S06 only where the backlog needs it
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-07-primary-coverage
- pattern: AmendingLaw.Pointer.parse word parsing drops the item before '(with', unnumbered 'Sch. para. N', adds '(with …)'/other laws' provisions, splits deep refs
  category: pointer parsing
  module: amending_law/pointer.ex (its other users)
  affected: 15 of 50 markup notes before G
  fix: prefer CitationSubRef where a note is at hand
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s03-markup-reader
- pattern: Amendment reader's Pointer/Locator name a Schedule paragraph inside a Part without its Part (sch.N.para.M), while Order.ref and RefList use the triple sch.N.pt.R.para.M (round 13, Jason 2026-10-27); RefList.covers? matches the two, but identity by target (merge) can split where a Schedule numbers each Part apart
  category: naming
  module: AmendingLaw.Pointer, AmendingLaw.Locator
  affected: 439 Part-less collisions in 58 laws (ids store); no effect while Schedules are unparsed (K1)
  fix: 'v0.2, with #169 (Schedules in LAT): Pointer.to_ref and Locator emit/try the triple; one amendment read pass (ReaderVersion)'
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: 'Amendment reader: a parent''s "listed in sub-paragraph (4)" (the amending law''s own) inherited as a place (SI 2026/386 Sch. 3 para 6(3)(a) → reg.2(4)); a sibling list item naming a law outranks the provision''s own heading (SI 2026/386 Sch. 3 para 6(5): was DPA 2018 s.155, now nothing, should be PEC reg.32)'
  category: amendment
  module: Amendment.Reader.LawNamed (placed_by, named)
  affected: 2
  fix: Drop parent brackets after "listed/mentioned/specified in"; prefer the provision's headings and parents over siblings when naming the law
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: 'Amendment reader drops a context''s subsection: "In section 43(1) …— (a) omit the ''or'' at the end of paragraph (h)" targets s.43(h), not s.43(1)(h) (PCA 2017 Sch.1 para 94(3)); a target the amended law lacks is then dropped as a misread'
  category: amendment
  module: Amendment.Reader (numbers / brackets from context)
  affected: unmeasured
  fix: carry the context's brackets onto the instruction's paragraph
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s05-extent-reader
- pattern: 'A range of provisions not expanded: ''in paragraphs (1)(b)(i) to (iii)'' gives (i) and (iii), not (ii) (SI 2008/1597 by 2019/696 Sch.12 para 8(a)); ''Section 63(1) to (4)'' gives (1) and (4) (HSWA by 1982 c.30 Sch.7, harmless: no rows between)'
  category: reader gap (target, yield)
  module: Amendment.Reader.Targets
  affected: 2
  fix: expand 'X to Y' between siblings at the same depth, held rows only (LatRef range cover)
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s06-amending-law-reader
- pattern: 'Two instructions in one clause, the first dropped: ''after “a notifier” add “or applicant” and for “2001” substitute “2015”'' gives only the substitution (NI 2012/255 reg.8(1) by 2015/339 reg.34(2)(b))'
  category: reader gap (yield)
  module: AmendingLaw.Operation / Amendment.Reader
  affected: 1
  fix: a clause with two operations joined by 'and' gives a rule for each
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s06-amending-law-reader
- pattern: 'Amending reader coverage: no rules at all for SI 2015/1682, SI 1999/2024, SI 2015/1637; no claim for whole-instrument revocations, ''in regulations 4 to 11, in each place'', some plain body instructions (SI 2023/247 reg.4(b)(ii), SI 2020/660 reg.4, SI 2024/322 reg.15)'
  category: amending reader
  module: Amendment.Reader / ReadPass
  affected: 2841
  fix: 'Coverage (CV-S06/CV-07): commenced_by gaps follow from it (2,841 OH&S text changes dated with no commenced_by)'
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s08-evidence
- pattern: 'Amending reader misses forms: a quote''s last item / ''by substituting for paragraph (3) the following'' (QL/QB); ''Sections 34 to 38 … are repealed'' (RR); ''is amended as follows'' lead-in (LA); ''in regulation 5(3)— … adding (c)'' read as reg.3 (P3); NI verbs ''by deleting'', ''by adding … the following'' (P7)'
  category: upstream (CV-S09)
  module: Amendment.Reader
  affected: HSWA s.6(1)(d), SI 2000/128, SI 2004/3363, SI 1992/3004 reg.3, NISR 2003/423
  fix: One reader session; preview + regression, one read pass
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'Amending reader ''#dropped'' repeal attributes sub-provisions inserted later (by another law) to the earlier substituting law: SI 2011/1885 reg.7(1) substitutes reg.19 of SI 2009/1348 with (1)-(2); (3)-(4) inserted later by SI 2020/1111 reg.8(4) are stored as repealed by 2011/1885 (siblings 19(1A), 19(3), 19(4) alike)'
  category: upstream / amending reader (CV-S06)
  module: Amendment reader, the '#dropped' rows
  affected: null
  fix: a dropped row must have existed under the substituted text at the substituting law's date (not compared with today's text)
  status: open
  step: Amending-law reader
  moved_from: 2026-10-22-cv-s10-measures
- pattern: 'Repealing schedules held only as PDF (6 laws) or in forms not read (27 rows): their rows hold no repeal'
  category: known limit
  module: Amendment.Reader
  affected: 39
  fix: PDF backlog for the 6 laws; a form each for the rest (cv-06a-known-limits.md)
  status: open
  step: Amending-law reader
  moved_from: 2026-10-31-cv-06a-repeal-tables
- pattern: 'Merge leaves a primary change and its legislation.gov.uk twin apart (TCPA 1990: 335 of 548 primary-only text changes have a derived-only change by the same law on the same or parent/child provision); both fold into the label, no conflict seen'
  category: merge identity
  module: ChangeVocabulary.Merge
  affected: 184
  fix: 1,104 → 184 on the golden laws; the rest in CV-S07
  status: open
  step: Merge
  moved_from: 2026-10-21-cv-04-merge-evaluator
- pattern: 'Merge: an alias joins two events (SI 1995/2038 reg.6(8)); an EU '';'' Substitution joined to an addition effect (CLP Art 23(f)); a substitution split Repeal+Addition left as a duplicate (SI 1998/494 reg.4(3)(e)n1); KX territory cut to the later law''s extent'
  category: merge
  module: ChangeVocabulary.Merge
  affected: 4
  fix: 'EU '';'' join and chapeau joins fixed (list items on their rows d72ce36d; deepest markup joins first e1aded30). Open: KX territory (cut to the later law''s extent: SI 2008/1597 reg.3), the alias (SI 1995/2038 reg.6(8)), a KX chain change left apart from the base law''s own-text change (SI 2008/1597)'
  status: open
  step: Merge
  moved_from: 2026-10-22-cv-s08-evidence
- pattern: 'Merge/placement: NISR 2012/179''s whole-law ''*'' rule has no ''*'' change to join once the feed effect is placed per regulation (WL-reach); an ''in each place'' words change kept on the parent while its successor sits on the children (P9)'
  category: upstream (CV-S09)
  module: ChangeVocabulary.Merge
  affected: NISR 2007/31 (40 changes), NISR 2010/160 reg.28
  fix: Attach a '*' law-text rule to every change carrying its feed effect; place 'each place' changes on the children holding the words
  status: open
  step: Merge
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'Feed Type error wins where the law''s text makes no claim (REACH Art 138(1): feed ''inserted'', para 95(3)(d) substitutes); moved words carried as renumbered (SI 1999/3242 reg.3(3))'
  category: evidence table
  module: Evidence (KF-type, KMV)
  affected: 2
  fix: Read the amending provision (para 95(3)(d) has no rule); a 'moved' operation in the vocabulary
  status: open
  step: Evidence
  moved_from: 2026-10-22-cv-s08-evidence
- pattern: Rows left to a commencement order we don't hold (J6, provision_by_order) fold as in force from the law's start, no gap
  category: label gap
  module: ChangeVocabulary.Label.Start
  affected: 55
  fix: 'CV-06: read the by-order records into the fold (or a gap), measured against the old J6 rows (28,122 rows in 55 laws)'
  status: open
  step: Label fold
  moved_from: 2026-10-21-cv-05-consumers
- pattern: Pending and unapplied changes (J4, LR-36) are read by the feed reader but used by no evidence rule or the fold
  category: label gap
  module: ChangeVocabulary.Label
  affected: null
  fix: 'CV-06: classify in the shadow diff; a fold rule if the old J4 is right'
  status: open
  step: Label fold
  moved_from: 2026-10-21-cv-05-consumers
- pattern: 'EU directives (eudr) after IP completion day: no rule fits all. A directive''s end depends on whether the Windsor Framework keeps it in NI (Jason 2026-10-30). Needs that source; golden Directive 90/269 Art 8b(1) is held out'
  category: label
  module: ChangeVocabulary.Label (and a Windsor Framework source)
  affected: 15 OH&S directives
  fix: Hold the Windsor Framework source (which directives continue in NI); the rule per directive to agree with Jason
  status: open
  step: Label fold
  moved_from: 2026-10-22-cv-s09-label-fold
- pattern: 'mix tasks over ~300 lines: lat.extent_check 404, lat.commencement_check 446, lat.sources 383 (logic inline: tallies untested)'
  category: module size
  module: lat.extent_check, lat.commencement_check, lat.sources
  affected: 3
  fix: move the tallies into pure modules with tests (CV-S12 retrospective, improve)
  status: fixed
  step: Measures
  moved_from: 2026-10-22-cv-s10-measures
- pattern: mix lat.vocabulary is 705 lines (debug view, build, check, conflicts, golden in one task)
  category: module size
  module: mix lat.vocabulary
  affected: 1
  fix: split the build, check and golden into modules (CV-S12 retrospective, improve)
  status: fixed
  step: Store and build
  moved_from: 2026-10-22-cv-s11-store-build
- pattern: 'The new source emits no gap list (old: no_start, undated_change, commenced_by_order, pending_change …)'
  category: label gap
  module: ChangeVocabulary.LabelSource
  affected: null
  fix: 'CV-06: derive gaps from the fold''s tiers and undated changes before switching'
  status: open
  step: Labels side by side
  moved_from: 2026-10-21-cv-05-consumers
- pattern: 'EffectIndex.effect_id doesn''t strip a ChangeId''s -N/2 suffix: occurrences joined apart from their effect in the parse'
  category: parser tell-tale
  module: effect_index.ex (ParserVersion)
  affected: 33
  fix: strip -N(/N) — lands with the next re-parse
  status: open
  step: LAT parser
  moved_from: 2026-10-22-cv-s03-markup-reader
- pattern: 'SI 2008/948 Sch.2 paragraph id wrapper2n1 (ref sch.2.para.wrapper2n1): its target statement''s scope never meets a feed ref'
  category: parser tell-tale
  module: Commencement.Order.ref / parser ids
  affected: 1 law (not OH&S)
  fix: Name wrapper paragraphs by their number
  status: open
  step: LAT parser
  moved_from: 2026-10-28-cv-s05f-target-named-extent
- pattern: 'LRT live_description states a scheduled (future-dated) revocation as current: SI 2008/1597 ''Revoked in NI'' (SI 2026/867 from 2027-01-20)'
  category: register
  module: LiveStatus
  affected: 1
  fix: 'GitHub #181: a revocation in force in the future is scheduled, not current'
  status: open
  step: Register
  moved_from: 2026-10-22-cv-s01-sources
- pattern: 'Register records land on the wrong provision (golden-set draft, to verify): nia 2021/8 recorded as revoking all of Coronavirus Act 2020 s.78 (it repealed s.78(3)); anaw 2015/4 recorded on TCPA 1990 s.78(4BA) (it omitted 4B-4D, before 4BA existed); SI 2024/49 recorded on s.284(3)(a) (it inserted s.284(3)(k))'
  category: register / effect target
  module: ChangeCollector.Feed (joins from the parse) / EffectTarget / range expansion
  affected: unknown — measure in CV-04
  fix: the vocabulary's targets read once per source, ranges only over provisions that existed at the date (V1-05)
  status: open
  step: Old label path
  moved_from: 2026-10-21-cv-01-architecture-review, 2026-10-21-cv-03-readers
- pattern: 'A row commenced only through some of the children it is above (SI 2026/318 reg.11(1): (1)(a)-(b) from 2026-09-19, (c)-(i) from 2027-01-19) reads in force, not in force partly'
  category: label projection
  module: LabelProjection (commencement reaching rows above a member, V1-01)
  affected: unknown; found in the V1-01 preview
  fix: a commencement reaching the row only from above a member is partial unless every child it holds is commenced
  status: open
  step: Old label path
  moved_from: v01-pipeline/2026-10-21-v1-03-smaller-label-gaps
- pattern: The new label path reads the law's start from the old register (lat_change_log) by a query with no ORDER BY (LabelSource.start/1); LabelRefresh still runs ChangeCollector and LabelTimeline.build for switched laws
  category: start-from-old-register
  module: ChangeVocabulary.LabelSource / LabelRefresh
  affected: every switched law (149)
  fix: Resolve the start with LawStart in the build and store it with the changes; drop the old-path calls for switched laws when the known limits move over
  step: Switch-over
  status: open
  moved_from: docs/lat-change-pipeline/DATA-ARCHITECTURE.md (2026-11-03)
- pattern: 'A switched law''s labels can go stale silently: LabelStaleness has no changes-version reason and change staleness is outside mix lat.stale --strict'
  category: switched-labels-staleness
  module: LabelStaleness / mix lat.stale
  affected: every switched law (149)
  fix: Add a :changes_version reason and count it in --strict
  step: Store and build
  status: open
  moved_from: docs/lat-change-pipeline/DATA-ARCHITECTURE.md (2026-11-03)
- pattern: 'The family switch matches the display family name by substring (''💙 OH&S: Occupational / Personal Safety'' contains the setting); switched laws are stamped with the old path''s code version'
  category: family-switch-by-display-name
  module: ChangeVocabulary.LabelSwitch.switched?/1
  affected: 377 family laws
  fix: Match the family exactly by a stable key; stamp the new path's version
  step: Switch-over
  status: open
  moved_from: docs/lat-change-pipeline/DATA-ARCHITECTURE.md (2026-11-03)
- pattern: 'The single changed_by picks the alphabetically last law where several made the text (REACH Art 127E: SI 2019/858, the amender of the amender)'
  category: changed-by-alphabetical
  module: ChangeVocabulary.LabelPeriods
  affected: unknown
  fix: Choose by the rule decided in RULES.md open decision 1
  step: Labels side by side
  status: open
  moved_from: docs/lat-change-pipeline/RULES.md (2026-11-03)
- pattern: 'To confirm: HSWA s.78 in force in NI in the written labels from 2006 while golden convention C11 expects E+W+S; HSWA s.52(1)(b): the change''s own territory E+W+S but the label keeps E+W+S+NI; the 2024 repeal of HSWA s.20(9) has no commenced_by though the feed names SI 2024/1021'
  category: written-labels-to-confirm
  module: ChangeVocabulary.Label (territory, commenced_by)
  affected: 3 seen
  fix: Check each against golden and the fold; fix by class or name a known limit
  step: Label fold
  status: open
  moved_from: docs/lat-change-pipeline/README.md worked examples (2026-11-03)
- pattern: 'The Windsor Framework list is marked checked: false, but the code ignores the flag and 160 rows rely on it'
  category: windsor-list-unchecked
  module: ChangeVocabulary.Windsor
  affected: 160
  fix: Jason checks the list (RULES.md open decision 11)
  step: Label fold
  status: open
  moved_from: docs/lat-change-pipeline/RULES.md (2026-11-03)
---

# Session: LAT Change Pipeline: Parked Bugs (PENDING)

## Problem

The open bugs from the change-vocabulary and v0.1-pipeline sessions (archived 2026-11-03), gathered in one place and tagged with the step that owns the fix (retrospective: "intelligently parking them until the step was formally revisited"). Nothing here is worked as a session of its own. When a step's session is planned, its plan starts from its bugs here:

```bash
sqlite3 .claude/sessions/sessions.db "SELECT pattern, affected FROM open_bugs WHERE step='<Step name>';"
```

Each is fixed (mark `fixed` here) or named a known limit in `docs/lat-change-pipeline/RULES.md` (mark `moved`, with the rule's slug). The source entries in the archived sessions are marked `moved`; `moved_from` names them. One duplicate (register records on the wrong provision, raised twice) is merged. The faults routed from the switch-over are in their own pending session, `lat-change-pipeline/2026-11-02-switch-over-routed-fixes.md`.

## Todo

- ⬜ Sources: 2 bugs — taken into the plan when the step next runs
- ⬜ Feed reader: 4 bugs — taken into the plan when the step next runs
- ⬜ Markup reader: 2 bugs — taken into the plan when the step next runs
- ⬜ Commencement reader: 9 bugs — taken into the plan when the step next runs
- ⬜ Extent reader: 4 bugs — taken into the plan when the step next runs
- ⬜ Amending-law reader: 11 bugs — taken into the plan when the step next runs
- ⬜ Merge: 3 bugs — taken into the plan when the step next runs
- ⬜ Evidence: 1 bug — taken into the plan when the step next runs
- ⬜ Label fold: 5 bugs — taken into the plan when the step next runs
- ⬜ Measures: 1 bug — taken into the plan when the step next runs
- ⬜ Store and build: 2 bugs — taken into the plan when the step next runs
- ⬜ Labels side by side: 2 bugs — taken into the plan when the step next runs
- ⬜ Switch-over: 2 bugs — taken into the plan when the step next runs
- ⬜ LAT parser: 2 bugs — taken into the plan when the step next runs
- ⬜ Register: 1 bug — taken into the plan when the step next runs
- ⬜ Old label path: 2 bugs — taken into the plan when the step next runs
- ⬜ The workflow's next pass on the extended golden (`golden_extended.exs`, 50 provisions; 9 fail today, all upstream) — decided when the next family's plan is made

## Dependencies

- ✅ Retrospective (2026-11-03): steps named, bugs carry `step:`, the `bug-raise` skill
