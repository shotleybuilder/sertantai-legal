# Waste, Water and Climate: Markup reader — the fixes

Detail moved from the step session (`.claude/sessions/lat-change-pipeline/2026-11-19-waste-water-and-climate-markup-reader.md`).

## Fix: the bracketed plural citation (Fix, fixer call 1, about 93k tokens)

- **Cause:** legislation.gov.uk marks only the first piece of a plural citation operative. In "S.I. 1988/1729, regs. 1(1), 12(1)(a)" that is reg.1(1), the citation and commencement; the amending reg.12(1)(a) is unmarked. Brackets do not tell it apart from the reverted case; the mark on provision 1 does.
- **Rule built:** when every operative piece is regulation, article or rule 1 of an instrument, the affecting pointers are the unmarked pieces listed with it, provision 1 left out; the list ends at its first other words. An Act's s.1, or a mark anywhere else, is read as before. `Readers.Markup.FirstProvisionList`; test `markup_plural_list_test` (8; 4 red before).
- **Reach (in-memory diff over 113 candidate laws):** 203 claim sets in 44 laws, `affecting` only; targets gone 0, added 0. Largest SI 2013/1773 27, NISI 1995/1980 24, ICTA 1988 22. Report `waste-water-and-climate-plural-diff.txt`.
- **Moves:** one held catalogue reading (Mines and Quarries Act 1954 s.34: reg.1(1) → reg.12(1)(a)); the RULES known-limit example EPA s.153(1)(ee) "arts. 1, 2" now reads art.2.
- **Not reached:** asp 2005/5 s.24A (SSI 2006/367 "arts. 1(1) {8}": the 8 is plain text, no structured pointer). 2 such notes in the store: a known limit.
- Tests: change-vocabulary and architecture 3,978/3,979; the one is the held reading above.

## Fix 2: the territory pair (fixer call 2)

- **Rule:** a change's territory is the first Extent its elements state, except that a retained Repeal's own new words (the Addition its SubstitutionRef names, under the same note) give it when they state one. `Readers.Markup.SubstitutionTerritory`; test `markup_substitution_territory_test` (4; the Childcare shape red first).
- **Store scan:** 124 laws hold such pairs; about 520 same-note pairs state one Extent on both; only the 3 Childcare Act pairs differ, all "(W.)" in their notes.
- **Reach:** 3 claim sets, 1 law (Childcare Act 2006 s.101(1)(a), s.30, s.101(9)), territory E → W only; 0 in the round. Report `waste-water-and-climate-territory-diff.txt`.
- **Waste and Emissions Trading Act 2003 s.25(2) was right already:** its "E+W | W" comes from a mis-pointed SubstitutionRef (legislation.gov.uk's error); the same-note guard keeps it. But the mis-pointing groups the Wales Addition under the England and Wales change: a new class, `substitution-ref-mis-pointed` (1 change, in the round), fixed as fix 4 under Decision 3's direction.

## Fix 3: the copied "w" id (fixer call 3)

- **Cause:** SI 2014/2384 art.2(1): "environmental statement" marked with the neighbouring Addition's ChangeId plus "w"; its note and the feed say "words substituted" by SI 2015/723 (another effect). It was carried under the insertion's effect.
- **Rule:** key a change by its own note's effect id when its ChangeId is `key-<hex>-<digits>` plus one letter, the unlettered id is another element's in the document, and its CommentaryRef names a different effect. `Readers.Markup.CopiedChangeIds`; test `markup_copied_change_id_test` (7, red first).
- **Store scan:** 757,507 key-form change elements; 624 whose ChangeId and note name different effects; 1 of them is the copied form (the only lettered key ChangeId in the store).
- **Reach:** 1 claim set, 1 law (SI 2014/2384 reg.2(1)), moved from the insertion's key to the substitution's, no attribute changed. Report `waste-water-and-climate-copied-id-diff.txt`.
- **Found, not fixed:** the other 623 mismatched elements (84 changes, 40 laws; e.g. 2005 c.15 ss.73-75, SI 1992/3280, SI 2010/2214's version pairs). In 11 changes (126 elements) only the note's effect is in the feed, so the change is keyed under an id the feed does not know. To be sized and put to Jason (`changeid-note-effect-differ`).

## Fix 4: the piece written in braces (fixer call 4)

- **Rule:** after a sole provision-1 mark, the list runs through marked pieces and list words (joiners, braces, numbers with brackets, "Sch./Pt./para./Group"); written pieces read by `AmendingLaw.Pointer.refs_in/1`, named as SectionRefs. `FirstProvisionList`; 7 new tests in `markup_plural_list_test` (5 red first).
- **Store scan:** 8 notes have a digit or brace after a sole provision-1 mark; 4 are the shape (asp 2005/5 s.24A art. 8 and 1984 c.12 s.89 confirmed by the feed; 1983 c.54 s.19, 1970 c.9 s.113(1B)).
- **Reach:** 2 claim sets in 2 laws, `affecting` only (asp 2005/5 s.24A reg.1(1) → reg.8; 1983 c.54 s.19 reg.1(2) → reg.6(2)); 0 in the round (asp 2005/5 is in Fire and OH&S). Report `waste-water-and-climate-braces-diff.txt`.
- **Found, not fixed:** the markup's fallback for a note with no structured pointers (`Pointer.to_refs/1`) names a domestic Order's article "art.N", where the structured path and the feed reader give "reg.N" (`fallback-pointer-art-for-order`). To be sized.

## Fix 5: the mis-pointed SubstitutionRef (fixer call 5)

- **Cause:** `Markup.substitutions/1` took every SubstitutionRef as written. In 2003 c.33 s.25(2) the E.W. Repeal names the Wales change's Addition. Wider form in the store: a later substitution's Repeal names the Addition of an earlier insertion round it, so the earlier insertion is read under the later change's key, with the wrong cited law.
- **Rule:** a pair stands as written, except where the Repeal's SubstitutionRef names an Addition under another note and an Addition under the Repeal's own note is named by none: pair with its own-note Addition. `Readers.Markup.SubstitutionPairs`; test `markup_substitution_pairs_test` (6; 3 red first).
- **Store scan:** 1,024 Repeal→SubstitutionRef pairs in 187 laws; 984 same note; 11 re-paired (9 laws); the rest untouched (legitimate or another form).
- **Reach:** 9 laws, 13 targets gone, 16 added, 3 sets changed in place; in the round 1 (2003 c.33 s.25(2): the stray E.W. "inserted" set gone). Others: 1907 c.24 s.6(3A)-(3D), 1962 c.58 s.44 (Fire and OH&S), 1968 c.73, 1970 c.9, 1988 c.50, 1996 c.18, 2003 c.21, and EPA 1990 s.6(6A)/(6B). Report `waste-water-and-climate-subref-diff.txt`.
- **Trap checked: EPA 1990 s.6(6A)/(6B)** (switched Environmental Protection family). Before: the 2000 insertion (note c13732581, SI 2000/1973) sat under the 2013 Scottish substitution's key on both rows, and on s.6(6B) read "substituted, S, SI 2000/1973", which neither note says. After: each row carries the 2000 insertion once (legacy key) and the 2013 substitution once (S, retained, SSI 2012/360). Right by both notes. The catalogue's held readings and golden for EPA may move: read at Settle.
- **Found, not fixed:** the 2000 insertion's note names two instruments ("inserted (E.W.) … by S.I. 2000/1973 … and inserted (S.) … by S.S.I. …"), but the markup cites only the first, with no territory (`note-two-laws-one-cited`); before and after alike.

## Fix 6: id and note name different effects (fixer call 6, stopped before an edit)

- **Reading by kind** (99 groups): not-in-feed id / in-feed note 17 **wrong** (a stale id; e.g. 1984 c.55 s.52(1)(d)-(f)); both in feed 26 **legitimate** (two real effects in one note: SI 1990/2457 "revoked (S.) … and revoked (E.)"); neither in feed 53 (32 in laws with no feed held; 2005 c.15 ss.74-75 carry their own ids under s.73's note), left; in-feed id / not-in-feed note 3 (a swapped pair), left.
- **Why not here:** 15 of the 17 wrong and 17 of the 26 legitimate look the same in the markup; only the feed tells them apart, and the reader has no feed. Merge holds it (`Merge.Candidates.rekey/2`). Parked with Merge, sized: `stale-changeid-note-in-feed`.

## Fix 7: the pointer read from a note's words (fixer call 7)

- **Reading of the 35 built sets:** 14 prefix only (`art.2` for an Order's `reg.2`: EPA s.153(1)(zz)); 17 the wrong law: the reader took the note's first Citation, inside the date bracket (SI 2020/1265: "(… immediately after S.I. 2023/850 comes into force) by … S.I. 2023/1387, arts. 2(1), 6(3)", cited 2023/850; 1974 c.40: cited SI 1994/1096 for EPA 1990); 2 run on into another law's articles; copied notes (1967 c.10 and 7 of 1974 c.40's) read from words.
- **Rule:** a note's amending law is its first Citation outside the note's date bracket (an unclosed "(" opening with a date; not the bracket round an instrument's number); words-read pieces of an Order are named `reg.`, as the marked path does. `Readers.Markup.NoteCitation`; test `markup_note_citation_test` (10; 7 red first).
- **Reach:** 290 claim sets in 75 laws, none gone or added: `affecting` prefix 178, `cited`+`affecting` 93, `cited` 14, same law twice 5. Built store: 45 sets in 12 laws (Climate Change 10, Environmental Protection 10, Pollution 9, Water 4, Road Safety 4, Waste 2, Forestry 2, Air Quality 1, Mines 1, Occupational 1). Report `waste-water-and-climate-fallback-reach.tsv`.
- **Labels:** the markup's `cited` feeds `by` (which law made it so), so 107 sets can move `by`: right by the notes; golden to check.
- **Found:** `copied-note-pieces-unmatched` (298 notes, 119 laws); `note-words-run-into-other-law` (2 sets).

## Fix 8: a note pairing territories with instruments (fixer call 8)

- **Size:** 680 notes in 130 laws pair two or more territories with instruments; 419 (73 laws) carry change elements (3,097 elements, 460 change ids; 132 legacy under 103 notes in 27 laws).
- **EPA 1990 s.6(6A)/(6B) itself:** the feed holds two effects, one per instrument (SI 2000/1973 E+W 2000-08-01; SSI 2000/323 S 2000-09-28); the build already holds both from the amending laws' text. The legacy element states no Extent, so the reader cannot say which instrument it is: not a reader fix.
- **Rule:** a change whose every element states one Extent, under a note pairing that territory with exactly one instrument, cites that instrument and its amending provisions (the first Citation after that territory's "by"); territory stays the Extent's. Anything else keeps today's reading. `Readers.Markup.TerritoryCitations`; test `markup_territory_citations_test` (9; 3 red with the fix off, checked by the session).
- **Reach:** 64 claim sets in 9 laws, `cited` 64 / `affecting` 59, no targets moved; 61 now cite the law the feed names for that key (1981 c.29 s.22(3): asp 2010/5, was 2009 c.23; Housing Act 2004: 44 to WSI 2013/1788); round 12 (Noise 1996 c.37 10, Air Quality 1993 c.11 1, Waste SI 2000/1043 1); switched families 0.
- **Trap:** SI 2000/1043 reg.11(3)(b): the Welsh words sit under the English effect's key; the note gives Wales to SI 2005/1806, the feed's key is SI 2005/894. The reading follows the note (law); Evidence's `by` stays the feed's.
- **Left:** about 100 legacy notes with no Extent on the element cite only the first instrument (Merge/Evidence); two 2000 effects with `Type=""` carry no operation (Feed reader).

## Fix 9: a copied note's pieces (fixer call 9, Decision 5 a)

- **Scan:** 677 copied Citations in 437 notes, 138 laws; 298 the note's first Citation (119 laws); 103 of their 687 pieces have a SectionRef that contradicts the piece's words.
- **Feed check (18 same-law copies):** today 0/18 have every piece in the feed; marks + SectionRefs 14/18; marks + words where contradicted about 14-15/18. The rest: legislation.gov.uk's own (2000 c.38, 1992 c.12).
- **Rule:** a Citation whose id is the pre-copy id + "n<digits>", named by no piece, is a copy: its pieces are renamed to it, so the note runs through NoteCitation, FirstProvisionList and TerritoryCitations; marks as given; a piece whose SectionRef contradicts its words takes the words. `Readers.Markup.CopiedNotePieces`; test `markup_copied_note_pieces_test` (10; 8 of 9 red first). Fix 7's test now expects `reg.3(3)` (it had asserted the bug).
- **Reach:** 139 sets in 66 laws, affecting only: narrowed to the marked piece 102 (1967 c.10 s.8(2),(3)), gained 16, changed 21 (1970 c.9 reg.1(1) → reg.10(2)(a)(ii)); round Pollution 7, Waste 6, Water 4, Noise 1.
- **Lost 7:** compound SectionRef carried whole (4: 2003 c.1 s.446R, 2005 c.5 s.628), "(with s. 111)" listed (2: 1990 c.10, 2001 c.2), split words (1: 2002 c.32 s.76(1)). Fixes 10 and 11 take the first two kinds.
- **Found:** 69 feed effects name another law than the note's first Citation ("applied by X (as inserted by Y)").

## Fix 10: where a note's list of amending pieces ends (fixer call 10)

- **Scan (6,156 bodies):** 152 unmarked notes in 47 laws list a "(with …)"/"(subject to …)" piece; 576 words-read notes in 153 laws run past an opener or another Citation ("(with" 302, "(as …" 169, another Citation 76, "(subject" 22).
- **Rule:** the amending pieces run from the amending Citation through pieces and list words to the first other words or Citation. Not an end: the instrument's own number bracket ("(N.I. 1)"), the same law cited again, a piece under another Citation's id, legislation.gov.uk slips ("ss. 4. 6(2)", "(c}"). Empty `<Citation/>`: the old reading.
- **Test:** `markup_list_end_test.exs`, red 10/15 first, now 22 (7 from diff losses). Markup reader + architecture 167 pass; compile clean; Credo no new issues.
- **Reach:** 327 sets in 89 laws, affecting only, no targets: narrowed 181 (2002 c.40: 64), gained 69, widened 61, lost all 11, changed 4, duplicate removed 1. Round: 4 sets (1956 c.52 s.16A → s.162(1), sch.15.para.6; SI 2011/988 reg.3(1); 1980 c.45 s.76HA(2)(e); 1974 c.40 s.78(2) lost). Switched: Environmental Protection 7, Occupational 2, Mines 1, Fire 1.
- **Feed agreement (200 sets with a feed effect):** 161 pieces dropped, none in the feed; 108 added, 49 in the feed; sets covering the feed's pieces 120 → 160; exactly equal 7 → 13.
- **Losses:** 4 right by the note (1954 c.70 s.182(1), 1967 c.86 s.75(6), 1974 c.40 s.78(2), 1990 c.9 s.20A); 7 with a wrong `cited` whose pieces were right only by accident → `note-citation-not-amending` (fix 12).
- **Trap:** widened sets list the note's whole run, including the amending Act's commencement section ("2000 c. 21, ss. 149, 154(5), Sch. 9 para. 51"), so 7 sets that equalled the feed no longer do. Merge's second-legacy-note join (`cited_apart?`) needs the note's refs inside the feed's; golden and the merge figures at Check show any cost.
- **Found:** `note-citation-not-amending`, `unmarked-list-words-beside-marks` (about 30 notes), `half-copied-note-mark-unread` (1 seen).

## Fix 11: a compound SectionRef split (fixer call 11)

- **Scan (868,239 note pieces, 2,342 laws):** 14,577 pieces in 612 laws join provisions or cannot be settled; 4,263 under a change element (370 laws). The words join the parts exactly as the id does, so the words cannot decide.
- **Rule (checked against the ids of 1,970 amending laws held):** a number climbs back to the number before it (`section-86-2-c-5-8` → s.86(2)(c), s.86(5), s.86(8)); a part after one of its own form is a sibling (`(c)(d)`, `(iii)(iv)`); a lower form nests (carried whole); a Schedule after a provision is its own piece. Unsettled shapes (`(a)(i)(viii)`, `(i)(ii)`, roman then letter…) are carried as given (my change: the joined id is a real id in 151 of 433 checked; the reader carries the source's own fact). Split pieces are ids of the amending law in 5,841 of 6,188 checkable.
- **Test:** `markup_compound_ref_test.exs`, red 1/23, now 25 green; `markup_list_end_test.exs` one expectation that asserted the bug updated. Compile clean; Credo no new issues.
- **Reach:** 1,883 sets in 145 laws, affecting only, no targets, no losses. Round 77 (5 laws); Environmental Protection 21, Occupational 3, Mines 1, Fire 2, Maritime Safety 4. Fix 9's four losses read right (2003 c.1 s.446R; 2005 c.5 s.628).
- **Held readings moved (3, for the Settle dry run):** 1968 c.73 `s.57(2)(5)` → s.57(2), s.57(5); 1976 c.57 → reg.5, sch.4.para.2(5); 1992 c.12 `s.39(6)(11)` → s.39(6), s.39(11).
- **Found:** `letter-roman-sibling-ambiguous`, `regulation-section-joined` (about 30), `feed-joined-ref-nested` (Feed reader), `compound-expand-two-groups` (Merge); notes read from words may still give joined refs (not measured).

## Fix 12: a note's amending Citation (fixer call 12, revised once)

- **Scan (123,294 notes under change elements with a linked Citation):** a bracket not opening with a date 179 (49 re-picked, 130 unsettled), nested in the date bracket 3, a Citation before "by" 4, a commencement order after ";" taken for an Act in words only 53 (checked by eye).
- **Rule:** the operative "by" is the first outside every bracket; the amending Citation is the first after it outside any bracket but the instrument's own number, not past a ";" closing another law's pieces; none qualifying gives no `cited`. "(as inserted/substituted/added by Y)" reads Y and Y's pieces; "(as amended by Y)" keeps X; two laws before the bracket keep the first. `NoteCitation.unlinked/1` limits the words read to "by" → first Citation. `ListEnd.words` ends at the bracket's close.
- **My brief was wrong first:** I asked for X in "(as inserted by Y)"; the feed names Y (81 to 0 for inserted, 228 to 9 for substituted), the date binds from Y's commencement, and Merge joins by Y. The fixer flagged the drop (120 agreeing sets lost); revised to Y. For "as amended" the feed names X 1,637 to 35, so X stays.
- **Test:** `markup_note_citation_test.exs` red 6/9, now 24 green; `markup_list_end_test.exs` one expectation (1970 c.9 Pt. 6 now reg.1, reg.3). Compile clean; Credo no new issues.
- **Reach:** 809 sets in 126 laws, no target: `cited` re-picked 718, law read from words 21, no law 69, affecting only 1; 73 lose `affecting`. Round 67 (Climate Change 34, Waste 12, Water 11, Pollution 8, Noise 2); Environmental Protection 78, Occupational 28, Fire 15, Mines 0; Patient Safety 309 (SI 2012/1916, not built).
- **Feed agreement:** moved sets with a feed effect 30 → 214 of 258 (the 30 that fell: "as substituted" where the feed names X, 8 laws); all notes with a feed effect 55,554 → 55,744 of 56,117.
- **Held readings moved (2):** `UK_eur_2004_852/260ee0c1c8`, `UK_uksi_2012_1916/0b0fa2c9b0`. Fix 10's 7 wrong-`cited` losses: 6 read right; 1995 c.46 s.58A(1)(b) left (quoted text leaves a bracket open).
- **Found:** `note-law-words-forms` (69 sets, open); `TerritoryCitations` tests only the date bracket; `NestedAdditions` takes the note's cited year (no placement moved here).
