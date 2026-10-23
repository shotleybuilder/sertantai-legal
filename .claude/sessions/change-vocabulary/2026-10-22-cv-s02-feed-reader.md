---
session: 'CV-S02: Feed Reader'
status: active
release: v0.1
opened: '2026-10-22'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S02: Feed Reader (ACTIVE)

## Problem

Step 2 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each legislation.gov.uk changes-feed effect becomes one change, on the right provision.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (agreed 2026-10-22, below): every effect accounted for; 50 random effects checked by a Claude agent; facts faithful; tested; repeatable
- ⬜ Build the acceptance check; run it (ask Jason before any long run)
- ⬜ Unplaced effects counted and reported with a reason (today they are dropped as target "?")
- ⬜ Grouped provisions in an effect ("s. 78(4BA)(4BB)", "s. 1(4)(b) and word") reach no row (open bug, CV-03)
- ⬜ NI Order kind words: "art. 10" in the feed is the row reg.10 (CV-04 Provision facts)
- ⬜ EU annex refs converted (`annex-XVII` → a provision we can hold or name): 824 effects, 14 laws
- ⬜ Fix until the check passes reliably; record the result

## Dependencies

- ✅ The steps before it passed (CV-00 order): CV-S01 Sources held (closed PASS 2026-10-22)

## What good looks like (agreed with Jason 2026-10-22)

**The reader's one job** (Jason: "a single purpose, very Elixir pattern"): turn each legislation.gov.uk feed effect into changes on the right provisions, carrying the effect's facts faithfully. Whether the feed itself is right is CV-S08's (evidence).

**Scope:** the OH&S core family's 149 feeds (held and checked, CV-S01).

**Pass when all hold:**
1. **Every effect accounted for:** placed on provisions we hold, or listed unplaced with a reason from a fixed set:
   - provision not in our LAT (outside its scope, or gone);
   - whole-law;
   - reference unparsed (our fault);
   - provision form not read (our fault).
   Nothing unplaced without a reason, and none for our-fault reasons.
2. **Right provision, checked:** 50 effects sampled at random, checked by a Claude agent against each effect's own affected-provision text. Every one right, or each error fixed and re-checked.
3. **Facts carried faithfully** on the same 50: operation, in-force date, affecting law, extent, savings, as the effect states them.
4. **Tested:** the counting and the reasons defined in words, with unit tests.
5. **Repeatable:** two runs give the same report.


## Survey of placement today (2026-10-22, read-only)

OH&S core family, 6,568 effects. `Feed.read` places each effect on its structured refs; one with none usable becomes `"?"`. The reader never checks a target against the rows we hold.

| outcome | effects | laws |
|---|---|---|
| placed on a row we hold | 3,443 | 98 |
| placed on its territorial versions (C3: `s.23[E+W]`) | 261 | 2 |
| target in a schedule; our LAT holds no schedules | 1,704 | 69 |
| refs not converted (EU annexes: `annex-XVII`) | 824 | 14 |
| not in the current CLML (gone, or a grouped ref split wrongly: "reg. 13(2)(a)(vi)(vii)") | 201 | 25 |
| no ref ("C/O", "specified amended provision(s)", "Directive") | 75 | 21 |
| whole law | 53 | 22 |
| in the CLML, not in our LAT | 7 | 3 |

**Decision (Jason 2026-10-22): schedules absent from LAT are a known limit for v0.1.** "We started by not parsing schedules into LAT. Some are huge reference tables. Then two schedule roles we need them for: amending and duties. I don't think selective schedule parsing is done." An effect on a schedule we don't parse is unplaced with that reason, a known limit, not a reader fault.

## Known faults (2026-10-22; Jason: "Fix known faults first, then baseline")

- **EU annexes (824 effects, 14 laws): fixed** (`e0220498`). `Ref.from_clml` converts `annex-XVII` to `annex.XVII`. No law in the DB holds annex rows, so an unparsed annex is the EU form of the schedule limit. My reading of the schedules decision, flagged to Jason.
- **"In the text, not our rows" (7 effects, 3 laws).** Each looked at in the CLML:
  - **NI SR 1997/248 reg.13(2)(b)(i)(aa):** a P5 item, deeper than our rows. Its words sit inside row `reg.13(2)(b)(i)`, so the change belongs there, but the fold never sees a change on `(aa)`. **Policy for Jason:** move a target deeper than our rows to its nearest held ancestor, as a words change? (C9, "a child's change never versions its parent", was written for children with their own rows.)
  - **EU 1989/391 Article 17 and REACH Article 127EA:** in the CLML with text, but the LAT parse made no row (the row made is `art.Article 17a`). A LAT parse bug, not the feed reader's.
  - **"(bb)" in the same NI effect:** legislation.gov.uk's own structured ref is `regulation-13-2-bb` (under 13(2), not 13(2)(b)(i)). The feed's error, faithfully read, so "not in the text"; noted for CV-S08.

## Faults fixed; placement PASS (2026-10-22)

Jason: "Yes, treat EU Annex like Schedules"; "A really deep affect is small. We can again be smart and choose the changes that will affect our labels"; "Good to capture tell tales for parser bugs. Raise but don't fix."

- **EU annexes** converted, and unparsed like schedules (`e0220498`).
- **Deeper than our rows:** a change on a provision in the law's text with no row of its own moves to the nearest held row as a words change, keeping the feed's target (`Placement.retarget/3`, `:rows` option; `e937bea8`).
- **One namer:** the reader names a provision as the parse did (`source_xml_id` → `section_id`), else `Ref.from_clml`. That fixed Parts, EU Titles and Chapters, and the EU articles whose `section_id` holds a non-breaking space.
- **Bare words in the refs:** the instrument ("Rules", or the effect's own text) is the whole law; any other word is no provision.
- **`ref_ambiguous`:** the feed's ref names a part found under several (CLP "Ch. 2 heading", `chapter-2`: Titles II, III, V). The feed's own, not ours.
- **#182 raised and corrected.** First raised as "no row for EU 1989/391 Art 17, REACH Art 127EA"; the rows exist, but the LAT parse put a non-breaking space in the name: 639 rows in 15 EU laws. Raised, not fixed.

**Check (`mix lat.feed_check`):** our faults went from 885 to 0.

| outcome | effects |
|---|---|
| placed | 3,483 |
| placed on territorial versions | 261 |
| placed on the nearest held row | 1 |
| whole law | 71 |
| schedule / annex not parsed (known v0.1 limit) | 2,471 |
| not in the current text | 201 |
| not a provision | 79 |
| ref ambiguous (the feed's own) | 1 |

Still to do: the 50-effect sample checked by a Claude agent (criteria 2 and 3), tests already in, repeatability, and golden re-checked (the reader changed).

**Deep effects refined** (`40aa55b1`; Jason: "Make the change. I Agree the logic"). Only text changes move to the row above a deep provision: inserted, substituted, repealed (whole or in part), renumbered, in any territory. The row's words change, its status doesn't. A commencement of a deep item stays on it, where "commenced through its parts" makes the row above partly in force until it is. A modification or application changes no label and stays.

**Non-breaking space accommodated** (`e6cd3863`; Jason: "Can we make the reader more accommodating?"). The parse names 639 rows in 15 laws with U+00A0 (#182), and the spelling isn't stable even within a law: UK_eur_2016_2031 has 736 articles with an ordinary space and 42 with a non-breaking one. The feed reader matched them through `source_xml_id`, but markup, the law's text, application and expiry name them from the CLML with an ordinary space. On those rows the feed's change and the others' could not join. `Ref.canonical/1` (any Unicode space → " ") now applies to every LAT name the vocabulary reads: provisions, `:rows`, `:xml_ids`, stored `:changes`, and the feed check's held rows. Canonical, not the row's spelling: stored changes don't move when the parse is fixed. Anything joining stored changes back to `legal_articles` compares canonical names until #182 is re-parsed. #182 stays open (raise, don't fix).

## Check results (2026-10-22, after `e6cd3863`)

- **Repeatability: PASS.** Two runs of the feed check give the same counts, and the two 50-effect samples (seed {2026,10,22}) are byte-identical.
- **Golden from inputs: PASS.** 27/27 (4½ min).
- **Placement: PASS.** 6,568 effects in 149 laws; reader faults 0.
- **Agent sample (50 effects): FAIL.** Placement 46/50; facts 43/50, 1 doubtful. Claims A, B, D and E checked by me against the CLML, the DB and `EffectKind`.
  - **A. Definitions without ids are called "not in text" (#1, #5, #40).** CLP Art. 2's definitions are `ListItem`s with no `id`, so `article-2-38` and the like are missing from the CLML id set, though the effect's key is in the text. They should be placed on the row above (Art. 2) as words changes; today they are dropped. Ranges over such items keep only their ends; that is moot once A is fixed.
  - **B. A shared `source_xml_id` picks a row at random (#13).** In the parse, `article-38-1` names 38(A1), 38(1) and 38(3); 119 ids corpus-wide name more than one row. The feed's own text ("Art. 38(1)") should break the tie. The duplicate ids are the parse's tell-tale: raise, don't fix.
  - **C. Staged changes other than insertions keep only the first date, with no `partial` (#12, #23).** "For specified purposes" and then "in so far as not already in force": a repeal reads as fully effective from the purposes-only date. `Feed.changes/1` splits stages only for commencements and whole insertions.
  - **D. "words deleted" has no operation (#22).** Not in the `EffectKind` verbs.
  - **E. EU types "replacement" and "addition" have no operation (#2, #11, #30).** They should be substituted and inserted; "deletion" probably too.
  - **F (doubtful). "sum substituted" is read as provision level (#48).** `Feed.level/1` knows only words and heading.
  - **Latent:** a schedule paragraph's commencement also targets the whole schedule (feed parent and child refs). Hidden today by `schedule_not_parsed`.

**Fixes** (`a92a5011`; Jason: "Go"):
- **A.** A provision with no id of its own whose change the text marks (the effect id is in the CLML) goes on the row above as a words change. The feed check calls it `placed_ancestor`. In the vocabulary, the deep record is dropped where the markup already put that event on the row.
- **B.** `Ref.xml_ids/2` builds one map for both tasks. An id naming several rows resolves to the row it names by itself, else one without `#n`. This is not a parser bug: legislation.gov.uk repeats the id in the CLML (119 ids in 59 laws, mostly `#2` repeats and cross-headings), and the parse names each row from its own number. No issue raised.
- **C.** Every staged text change keeps its stages: it takes effect from the first, partly, and each later stage is a commencement. A whole removal in stages is a removal in part at each partial stage, then the removal at the full one. Staged modifications stay one change.
- **D and E.** `EffectFacts.type/1` maps the feed's other words to the verbs. The stored feeds (whole corpus) show many: replacement 2,435; addition 912; repeal 311; rev and "rev in pt" variants; subst; words/word deleted 146; deleted 48; replaced 43; misspellings (substititued, subsitituted, omittted). This is label side only: `EffectKind` (the parse's, in `ParserVersion`) is unchanged.
- **F.** Words level also covers sums, figures, entries, punctuation, formula, number, label and definitions.
- **Not mapped (a gap, noted):** "am" and "amendment" (about 1,300) say only "amended", with no operation to label.
- **Feed check** (`eb5e31bf`): `--seed N` draws a fresh sample, and each change the reader made is shown (stage keys, level, first date).

**Golden regressions from the fixes, and the revision** (`285c9f3e`). After `a92a5011`, golden was 24/27:
- **Staged substitutions** in provisions already in force commenced the provision (TCPA 1990 s.284(3)(a) turned prospective; EUWA 2018 s.6 took 2020/1's stage as its commencement). Now only a whole insertion's later stages are commencements. Any other staged text change takes effect from its first stage, partly, with its full date as a fact (`date_full`).
- **Fix A trusted the feed's path** (EPA 1989: the feed's "s. 3(5)(ia)" is s.3(5)(c)(ia) in the text) and moved a Scottish insertion onto s.3(5). Now a feed ref the text doesn't hold, for an event the text marks, gives way to the markup's change, which places it where the text does. Feed-check outcome: `placed_by_markup`.

## Re-check (2026-10-23)

- **Golden: PASS.** 27/27.
- **Repeatability: PASS.** Counts repeat.
- **Placement: PASS.** Reader faults 0. Placed 3,483; schedules 2,471; versions 261; by markup 105; not in text 96; not a provision 79; whole law 71; ancestor 1; ambiguous 1.
- **Same 50:** every flagged item now reads correctly (checked by me).
- **The feed repeats effects:** #11 and #30 (first sample) are two identical feed entries with one EffectId (rows 107 and 163). The merge joins them into one change.
- **Fresh 50 (seed 7), agent: FAIL.** Placement 38 OK, 4 wrong, 8 doubtful; facts 48 OK, 2 wrong. D1 and D3 checked by me.
  - **D1. The feed check's `marked` includes unapplied-effects metadata (#14, #25).** It scans every `key-` in the CLML, including `<ukm:UnappliedEffect>`, so effects legislation.gov.uk has not applied look marked. Feed check only; the vocabulary reads markup claims.
  - **D2. A CLML id that names a provision wrongly (#7).** HSWA `section-28n1-f-i` is s.28(3)(f)(i)[S], held as `s.28(f)(i)[S]`. The feed's `section-28-3-f-i` meets nothing, and the markup is legacy (`d29p…`), so the outcome says not in text. A parse tell-tale: raise, don't fix.
  - **D3. EU refs coarser than the feed's text (#8).** The refs give `article-56`; the text says "Art. 56 para. 6 Point (b)", a row we hold. It is placed as the whole article replaced. Two feed rows share the effect id.
  - **D4. A parent ref kept beside its child (8 items).** `schedule-1` + `schedule-1-paragraph-2` gives a change on `sch.1`, and a commencement there claims the whole schedule. Hidden in v0.1 by `schedule_not_parsed`; it matters once schedules are parsed.
  - **D5. Commencements carry no extent, territory or savings (#24).** The commenced branch, and the later stages of a staged insertion, build only operation, level, date, partial and by. "Commenced for N.I." loses N.I.
  - **Not counted:** EU effects have no date, but the feed's `Comments` says "EUR-Lex in-force date …". That is an editorial comment, a pointer like a note, not a fact.

**D1 fixed** (`90f1fe95`). `Placement.marked/1` reads the effect ids in change markup (`ChangeId`) only. An unapplied effect has none: its id appears only in the metadata's `UnappliedEffects` (`EffectId`; 1,258 in the family). The 161 unapplied effects whose id is also in the text are all commencements carrying a note reference (`CommentaryRef`), a pointer, not markup. Feed check: placed by markup 105 → 42; not in text 96 → 159 (63 were unapplied effects, legislation.gov.uk's backlog, wrongly counted as placed). Reader faults 0.

**D2 raised: #183** (Jason 2026-10-23: "We're raising against the parser, even though our parser was faithful, to sense markup bugs. The broken pattern can be detected. We mustn't make a fix just for this one bug in the XML. The pattern needs abstracting."). In legislation.gov.uk's CLML, HSWA s.28(3)(f) has the id `section-28-f` and sits outside subsection (3), in all three versions. Two general patterns, measured over the family:
- ids that contradict their nesting: 27 elements in 4 laws (CLP 15);
- a level skipped beside siblings at the right level: 14 in 3 laws (HSWA 10).

The item stays "not in text" until the parse senses the fault. Parser bugs raised here (#182, #183) are fixed in the sub-session CV-S02a, straight after this one; then back to the workflow.

**D3 fixed** (`89778f5d`; Jason: "if we cannot find the finer form we can default but we should be able to spot those as possible tell tales that our parse of the text has a bug"). For EU law with one article ref, the feed's words are read further: "para. N" is (N), and "Point (x)", "Point x)" and "Point B)III)" are (x)(y). The change goes on the deepest of those held, else on the article. A finer form not held is a `:finer_unheld` claim, which the feed check lists as a parse tell-tale. Family: 14 tell-tales, checked against the CLML and rows:
- **10: the CLML gives the points or paragraphs no ids**, so the parse makes no rows. EUDR 98/24 Art. 2(b)(i)–(iii); REACH Art. 57(a)–(c), 76(1)(c), 77(3)(a); CLP Art. 23(f), in two forms. This is the same gap as fix A (CLP Art. 2's definitions).
- **1: a real parse naming bug.** REACH Art. 77(2)(e) is held as `art.Article 77(2)((e))`: the number is taken with its brackets. Across the DB: 79 rows in 9 laws (EU mostly; also UK_ukpga_2006_46).
- **3: gone from the text.** CLP Art. 54 is omitted, so 54(3) and (4) are gone; REACH Art. 14(2) holds (a) and (b) only, so the feed's (e) isn't there. Not parse bugs: the tell-tale is a candidate.
