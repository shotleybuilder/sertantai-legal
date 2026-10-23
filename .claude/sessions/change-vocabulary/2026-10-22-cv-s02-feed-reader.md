---
session: 'CV-S02: Feed Reader'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-23'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
outcome: success

summary: >
  The changes-feed reader accounts for every effect in the OH&S family (6,568 effects, 149 laws,
  0 reader faults, from 885) and carries the feed's facts as read. A seed-17 sample of 50 checked
  by a Claude agent came out clean (placement 50/50, facts 50/50), golden 27/27, repeatable. The
  check is repeatable for the next ~49 families: the feed-reader-check skill, a prerequisites gate,
  tell-tales by kind, and a recipe in CV-00.

decisions:
  - what: Readers carry what the source says; what it means for a label is the label fold's (CV-S09)
    why: 'Jason: "the reader accurately parses the feed info, what it means comes later" (D5)'
    result: commencements carry effect_extent, savings and in_force_for as read; the territorial reading is logged in CV-S09
  - what: Markup faults are raised against the parser as measured patterns, never fixed for one law, and fixed in a sub-session straight after the step
    why: 'Jason: "to sense markup bugs ... The pattern needs abstracting"'
    result: '#183 (structure faults: 27 + 14 elements), #184 (id-less list items: 1,652 in 114 laws), #185 (doubled brackets: 79 rows in 9 laws); with #182 in CV-S02a'
  - what: Accommodate the non-breaking space in the vocabulary (Ref.canonical) rather than re-parse
    why: The spelling is unstable even within a law; a canonical spelling keeps stored changes stable when the parse is fixed
    result: feed, markup and law-text readers agree on 639 rows in 15 laws without a re-parse
  - what: Only text changes on a deep provision move to the held row above; a commencement stays for "commenced through its parts"
    why: A commencement of a deep item changes the parent's status only through its parts
    result: placement PASS; golden 27/27
  - what: Staged commencement only for whole insertions; other staged text changes date from the first stage, partly, with the full date as a fact
    why: Making every staged substitution a commencement broke golden (TCPA s.284(3)(a), EUWA s.6)
    result: golden back from 24/27 to 27/27
  - what: A feed ref the text doesn't hold, for an event the text marks (ChangeId), gives way to the markup's placement
    why: Trusting the feed's path put an EPA 1989 Scottish insertion on s.3(5) (the feed's "s. 3(5)(ia)" is s.3(5)(c)(ia))
    result: placed_by_markup 42; unapplied effects (id only in the metadata) are not in text
  - what: Effect-type words mapped on the label side (EffectFacts.type), never in EffectKind
    why: EffectKind is a ParserVersion input; a label-side mapping doesn't stale every parse
    result: replacement, addition, completion, deleted, rev in pt, subst and misspellings read
  - what: Close with a clean sample only (Jason, "One more sample of 50 - that hasn't passed clean yet")
    why: The pass rule is a clean result, not a mostly-clean one
    result: seed 17 clean, 50/50

metrics:
  placement: { effects: 6568, laws: 149, placed: 3483, schedule_not_parsed: 2471, placed_versions: 261, not_in_text: 159, not_a_provision: 79, whole_law: 71, placed_by_markup: 42, placed_ancestor: 1, ref_ambiguous: 1, our_faults: 0, our_faults_at_start: 885 }
  agent_samples: { seed_2026_10_22: "defects A-F", seed_7: "38/50 placement, 48/50 facts; D1-D5", seed_11: "49/50, 49/50; NEW-A, NEW-B", seed_13: "49/50, 49/50; NEW-C (K10), NEW-D", seed_17: "50/50, 50/50 clean" }
  golden: { provisions: 27, pass: 27 }
  tell_tales: { finer_form_not_held: 16, no_ids: 10, naming: 1, not_found: 5 }
  feed_corpus_shapes: { pages: 1208, effects: 251692, id_shapes: 2614, id_shapes_99pct: 36, qualifications: 566, qualifications_99pct: 63 }
  family_scope: { family_laws: 377, with_lat_rows: 149 }

lessons:
  - title: A downstream check senses parser bugs best; raise them as measured patterns
    detail: >
      The feed check found the non-breaking space (#182), legislation.gov.uk structure faults (#183),
      id-less list items (#184) and doubled brackets (#185). Each looked like one law's problem
      until measured across the family's stored CLML. Jason redirected a one-law fix to "the pattern
      needs abstracting".
    tag: data
  - title: Count the right attribute — Ref="…" also matches FoundRef= and err:Ref=
    detail: >
      A regex for Ref=" counted FoundRef (legislation.gov.uk's nearest-found provision), inflating
      parent+child refs from 44 to 264 and producing a wrong explanation (reg. 11(6)). Use a
      lookbehind or an XML parser, and read the raw record before explaining a defect.
    tag: tooling
  - title: The effect id in the CLML is not proof the change is in the text
    detail: >
      UnappliedEffects metadata carries EffectId; notes carry CommentaryRef. Only a ChangeId on
      change markup means the change was made. Scanning the whole file for key- ids counted 63
      unapplied effects (legislation.gov.uk's backlog) as placed.
    tag: data
  - title: A fix that reads well can break golden — run golden after every reader change
    detail: >
      Generalising staged insertion to all staged text changes, and trusting the feed's path for
      marked events, each broke golden (24/27) though the unit tests passed. Golden caught both.
    tag: tooling
  - title: legislation.gov.uk links one citation in pieces
    detail: >
      "Title 5 Ch. 1 heading" is <Section Ref="title-V">Title 5</Section><Section
      Ref="title-V-chapter-1">Ch. 1</Section>: one path, not two targets. 1,417 effects in the family
      (1,373 in schedules). Jason read the applied effect to be sure: show the raw record and the
      markup when explaining.
    tag: data
  - title: Version hashes include shared readers — say so before committing
    detail: >
      ChangesFeed and EffectKind are ParserVersion inputs. Word mappings went label-side
      (EffectFacts) to avoid staling every parse; the lowercase "other" fix had to touch ChangesFeed,
      so ParserVersion moved, folded into CV-S02a's planned re-parse.
    tag: tooling
  - title: Step through defects one at a time with the evidence
    detail: >
      Jason asked to step through D1-D5 one by one; that exposed a wrong explanation (D1 "Addition
      tag") and a miscount (D4). For later families only NEW defects go to Jason.
    tag: tooling
  - title: A clean pass, not a mostly-clean one
    detail: >
      Four agent rounds each found new minor defects; closing waited for a fully clean sample.
      Samples can miss rules a sample doesn't hit; the bounded feed grammar (36 id shapes cover 99%
      of 251K effects) points to a pattern-catalogue fixture (CV-S02b).
    tag: tooling

bugs:
  - pattern: "Feed effects naming grouped provisions (\"s. 78(4BA)(4BB)\", \"s. 1(4)(b) and word\") reach no row, so the row takes its dates from an older wrapping change (s.78(4BA) dated from the 2008/29 insertion of 4A-4D)"
    category: feed reader
    module: EffectTarget / ChangesFeed affected_refs parsing
    affected: unknown — measure in CV-03
    fix: "Verified 2026-10-23: s.78(4BA)(4BB) → s.78(4BA), s.78(4BB); s.17(1)(b) and word → s.17(1)(b)"
    status: fixed
  - pattern: Non-breaking space in EU article section_ids (#182)
    category: parser tell-tale
    module: LAT parse (lat_parser/ids.ex)
    affected: 639 rows / 15 laws
    fix: name from the number, normalised (CV-S02a); accommodated in the vocabulary by Ref.canonical
    status: open
  - pattern: legislation.gov.uk CLML structure faults — ids contradicting nesting, levels skipped (#183)
    category: parser tell-tale
    module: LAT parse
    affected: 27 + 14 elements in the OH&S family
    fix: sense as diagnostics; one general repair rule if any (CV-S02a)
    status: open
  - pattern: Numbered list items with no id get no row (#184)
    category: parser tell-tale
    module: LAT parse
    affected: 1,652 ListItems / 114 laws
    fix: decide whether numbered items become rows (CV-S02a)
    status: open
  - pattern: Row names with doubled brackets "art.Article 77(2)((e))" (#185)
    category: parser tell-tale
    module: LAT parse
    affected: 79 rows / 9 laws
    fix: strip brackets from a number before naming (CV-S02a)
    status: open
  - pattern: Shared namer drops nested schedule ids (schedule-N-part-P-paragraph-M → sch.N.pt.P; unnumbered schedule-paragraph-1 → sch.paragraph)
    category: namer
    module: Commencement.Order.ref/1
    affected: 48 collisions in the family's feeds, none in the body
    fix: with the schedule naming decision when schedules are parsed (CV-S02a, deferred)
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/placement.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/ref.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary.ex
  - backend/lib/sertantai_legal/scraper/effect_facts.ex
  - backend/lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
  - backend/lib/mix/tasks/lat.feed_check.ex
  - backend/lib/mix/tasks/lat.vocabulary.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/placement_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/feed_targets_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/feed_facts_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/canonical_test.exs
  - .claude/skills/feed-reader-check/SKILL.md

depends_on:
  - 2026-10-22-cv-s01-sources.md

enables:
  - CV-S02a parser tell-tales (#182-#185)
  - CV-S02b feed pattern catalogue (fixture)
  - CV-S03 markup reader
  - the feed-reader check for the next families
---

# Session: CV-S02: Feed Reader (CLOSED)

## Problem

Step 2 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each legislation.gov.uk changes-feed effect becomes one change, on the right provision.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (agreed 2026-10-22, below): every effect accounted for; 50 random effects checked by a Claude agent; facts faithful; tested; repeatable
- ✅ Build the acceptance check; run it (ask Jason before any long run)
- ✅ Unplaced effects counted and reported with a reason (`Placement`, `mix lat.feed_check`)
- ✅ Grouped provisions in an effect ("s. 78(4BA)(4BB)", "s. 1(4)(b) and word") reach no row (open bug, CV-03): checked 2026-10-23, TCPA 1990 "s. 78(4BA)(4BB)" → s.78(4BA), s.78(4BB); Forestry Act 1967 "s. 17(1)(b) and word" → s.17(1)(b)
- ✅ NI Order kind words: "art. 10" in the feed is the row reg.10 (CV-04 Provision facts): checked 2026-10-23, NISI 1998/1069 "art. 4(4)(f)" → reg.4(4)(f), the family's only NI Order effect on an article
- ✅ EU annex refs converted (`annex-XVII` → `annex.XVII`; unparsed like schedules, a known v0.1 limit)
- ✅ Fix until the check passes reliably; record the result (final checks: feed check twice + fresh 50 at seed 11, golden, agent)
- ✅ Repeatable for the next family (Jason 2026-10-23: "We have about 50 Families"; right after the final checks):
  - ✅ The agent's instructions saved as a project skill (`feed-reader-check`): reader rules, read-only limits, a fixed report format (table + defects, each a known pattern or new)
  - ✅ A prerequisites gate in `lat.feed_check`: a family whose feeds, text or rows aren't stored is stopped and pointed to `mix lat.sources --family X`
  - ✅ Tell-tales printed by kind (no ids in the text, naming fault, gone from the text), no ad hoc scripts
  - ✅ A one-page recipe in CV-00 for a new family: sources → feed check → sample + agent → golden where held; pass = no reader faults, clean agent check, repeatable; only defects with no known pattern go to Jason

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

**D1 fixed** (`1e7e1396`). `Placement.marked/1` reads the effect ids in change markup (`ChangeId`) only. An unapplied effect has none: its id appears only in the metadata's `UnappliedEffects` (`EffectId`; 1,258 in the family). The 161 unapplied effects whose id is also in the text are all commencements carrying a note reference (`CommentaryRef`), a pointer, not markup. Feed check: placed by markup 105 → 42; not in text 96 → 159 (63 were unapplied effects, legislation.gov.uk's backlog, wrongly counted as placed). Reader faults 0.

**D2 raised: #183** (Jason 2026-10-23: "We're raising against the parser, even though our parser was faithful, to sense markup bugs. The broken pattern can be detected. We mustn't make a fix just for this one bug in the XML. The pattern needs abstracting."). In legislation.gov.uk's CLML, HSWA s.28(3)(f) has the id `section-28-f` and sits outside subsection (3), in all three versions. Two general patterns, measured over the family:
- ids that contradict their nesting: 27 elements in 4 laws (CLP 15);
- a level skipped beside siblings at the right level: 14 in 3 laws (HSWA 10).

The item stays "not in text" until the parse senses the fault. Parser bugs raised here (#182, #183) are fixed in the sub-session CV-S02a, straight after this one; then back to the workflow.

**D3 fixed** (`9838192e`; Jason: "if we cannot find the finer form we can default but we should be able to spot those as possible tell tales that our parse of the text has a bug"). For EU law with one article ref, the feed's words are read further: "para. N" is (N), and "Point (x)", "Point x)" and "Point B)III)" are (x)(y). The change goes on the deepest of those held, else on the article. A finer form not held is a `:finer_unheld` claim, which the feed check lists as a parse tell-tale. Family: 14 tell-tales, checked against the CLML and rows:
- **10: the CLML gives the points or paragraphs no ids**, so the parse makes no rows. EUDR 98/24 Art. 2(b)(i)–(iii); REACH Art. 57(a)–(c), 76(1)(c), 77(3)(a); CLP Art. 23(f), in two forms. This is the same gap as fix A (CLP Art. 2's definitions).
- **1: a real parse naming bug.** REACH Art. 77(2)(e) is held as `art.Article 77(2)((e))`: the number is taken with its brackets. Across the DB: 79 rows in 9 laws (EU mostly; also UK_ukpga_2006_46).
- **3: gone from the text.** CLP Art. 54 is omitted, so 54(3) and (4) are gone; REACH Art. 14(2) holds (a) and (b) only, so the feed's (e) isn't there. Not parse bugs: the tell-tale is a candidate.

**Raised from D3's tell-tales:** #184 (numbered items with no id get no row: 1,652 ListItems in 114 laws) and #185 (doubled brackets: 79 rows in 9 laws). Both are in CV-S02a.

**D4 fixed** (`e1d2f7e4`). legislation.gov.uk links one citation in pieces: "Title 5 Ch. 1 heading" is `<Section Ref="title-V">Title 5 </Section><Section Ref="title-V-chapter-1">Ch. 1</Section> heading`. The reader took every `Ref`, so it made a second change on all of Title V. The applied effect sits only in Chapter 1's heading (CLP, SI 2019/720 Sch. 2 para. 31). Now a ref that another of the effect's refs extends is part of that path, not a target; siblings ("reg. 7(3A)(3B)") stay two. Family: 1,417 effects linked in pieces (schedules 1,373, annexes 39, titles 4, sections 1). Placement counts unchanged; only the extra parent target is gone.
- **Correction:** my first count (1,637, with 264 outside schedules) matched `FoundRef=` too. That is legislation.gov.uk's note of the nearest provision found in the current text, never read by the reader (reg. 11(6) has one ref). A possible pointer for unapplied effects later.
- A hand-built test that expected both Title I and Ch. 1 (from `bcf6987f`) was rewritten to test the naming alone.

**D5 fixed** (`1a273eb2`; Jason: "the reader accurately parses the feed info, what it means comes later"). A commencement change, from the feed or the later stage of a staged insertion, now carries the effects extent and the savings. It also carries the territory its qualification names ("for E.W.S." → `in_force_for` "E+W+S"), as read, not applied. Family: 1,777 commencements, with territorial application 0, effects extent 81 (80 restate an NI law's own N.I.), savings 6, territory in the qualification 2. What `in_force_for` means for the label (in force there, prospective elsewhere) is logged in CV-S09 Label fold.

## Final checks (2026-10-23, after `1a273eb2`)

- **Placement: PASS.** 6,568 effects, reader faults 0; finer-form tell-tales 14 (as classified above).
- **Repeatability: PASS.** Two runs at seed 11: counts identical, samples byte-identical.
- **Golden: PASS.** 27/27.
- **Agent, fresh 50 (seed 11; 1 effect shared with earlier samples): 49 OK, 0 wrong, 1 doubtful (#5).** Known patterns labelled: K1 (schedules and annexes unparsed) on 16, K7 on 1. Two new, both minor, both on #5:
  - **NEW-A. An EU paragraph written ".N"** ("Art. 35 .2 L2", ref `article-35`) is not read, so it is placed on the article though `art.Article 35(2)` is held. EUR-Lex notation: ".2" is paragraph 2, "L2" subparagraph 2 (no row). 24 such effects across the stored EU feeds, plus 8 "(N) LN".
  - **NEW-B. The EU type "completion" gives no operation.** 28 such effects across the stored feeds, all applied, none with change markup (EU-era changes are in the base text), mostly on annexes. Example: Directive 2004/35 Annex III "completion" by Directive 2006/21, the mining-waste directive that added an activity to Annex III. That suggests inserted; it needs Jason's call.
  - **Observation (not a defect).** `placed_versions` targets the bare provision. The feed's extent (E+W+N.I., "modifications do not extend to Scotland") and the markup (only in the [E+W] version) say which version is changed; the reader carries the extent. Narrowing to the version is the label fold's job: logged in CV-S09.

**NEW-A and NEW-B fixed** (`e2807584`; Jason: "Agree New A and New B"). EUR-Lex paragraph forms ".2 L2" and "(7)" are read as paragraph N (a subparagraph names no row). "completion" maps to inserted. Two more tell-tales surfaced (REACH Art. 3(20)(b), (c): no ids): 16 in all.

**Repeatable for the next family** (`638c23a9`, skill `feed-reader-check`, CV-00 recipe):
- **The gate:** stored feed and text are required for every family law with LAT rows; otherwise FAIL, pointing to `mix lat.sources`. OH&S: 377 family laws, 149 with rows (in scope), all held.
- **Tell-tales by kind** (`Placement.tell_tale/3`): naming 1 (#185); no ids 10 (#184); not found 5. Not found is a candidate: the tool looks only at the held row's own text, up to the next id, so REACH 76(1)(c) and 77(3)(a), which I had classed as no ids by hand, show as not found.
- **The saved agent prompt:** reader rules, known patterns K1–K9, fixed report format.

## Closing run (seed 13, the recipe and the saved agent prompt, first use)

- **Gate, placement (our faults 0), repeatability (identical), golden 27/27: PASS.**
- **Agent: placement 49/50, facts 49/50.** Known: K1 ×13, K4 ×1, K6 ×1. Two new, both minor, checked by me in the code:
  - **NEW-C. A schedule Part's paragraph is cut short to the Part** (#20, SI 1996/341 "Sch. 1 Pt. III para. 5"). `Commencement.Order.ref/1` maps `schedule-1-part-III-paragraph-5` to `sch.1.pt.III`, so with D4 the one target is the Part. It shares the namer with the commencement and amendment readers (14 callers). No effect in v0.1 (no schedule rows); it matters when schedules are parsed.
  - **NEW-D. A lowercase `Qualification="other"` never reads its `OtherQualification`** (#16, #33). `ChangesFeed` swaps in the free text only for exactly "Other" (lines 209, 352); the stored feeds hold 181 lowercase against 7,547 "Other". #16: "for specified purposes and 1.1.1996 in so far as not already in force" is read as "other": partial true only by luck, the text unread.
  - **Not counted:** a staged application ("applied (with modifications)", two stages) is one change with no stages. Modifications carry no operation; the rule stages text changes only.

**NEW-C measured as a pattern** (Jason: "isn't it just random a schedule ref found the bug, why could it not happen on a body"). All 4,173 refs in the family's feeds were run through the namer (`Ref.from_clml` → `Order.ref`). 48 names are shared by different ids, **none in the body**. Body ids are flat: a section's, regulation's or article's number is unique in the law, and its id carries no Part. Body Parts, Titles and Chapters aren't named by `Order.ref` (nil); they're named by our rows (`xml_ids`). Schedule and annex ids nest (Part → Chapter → paragraph), and the namer drops the nested pieces:
- `schedule-N-part-P-…` → `sch.N.pt.P`: 36 shapes, e.g. SI 1996/341 Sch. 1 Pt. V paragraphs 1, 2 all → `sch.1.pt.V`; NISR 2009/238 Sch. 4 Pt. II Chapters A–C and their paragraphs → `sch.4.pt.II`;
- an unnumbered schedule: `schedule-paragraph-1` → `sch.paragraph`, `schedule-part-I` → `sch.part`;
- annexes → `annex.X` (deliberate: annexes named as a whole while unparsed).

No effect in v0.1 (no schedule rows). The namer is shared (commencement and amendment readers, 14 callers), so it is fixed with the schedule naming decision when schedules are parsed: logged in CV-S02a and as known pattern K10 in the `feed-reader-check` skill.

**NEW-D fixed** (`3bb53088`). `ChangesFeed` reads `OtherQualification` for "other" in any case. `ChangesFeed` is a `ParserVersion` input (the parse reads in-force qualifications through `InForceQualifier`), so every law's parse shows stale. That is honest, and it folds into CV-S02a's re-parse, which moves `ParserVersion` anyway. Placement re-run: PASS, our faults 0. A second date in the free text ("and 1.1.1996 in so far as not already in force") is not made a stage; the text is carried.

## Clean pass (seed 17, 2026-10-23; Jason: "One more sample of 50 - that hasn't passed clean yet")

Run by the `feed-reader-check` skill, with the prompt as the skill holds it (K1–K12):
- **Gate:** 149 of 149 in-scope laws held. **Placement:** our faults 0. **Repeatability:** counts and samples identical. **Golden:** 27/27, after NEW-D.
- **Agent: placement 50/50, facts 50/50, no new defects.** Known: K1 ×15, K7 ×3, K9 ×2. Closer checks: an unapplied insertion correctly not in text (its id only in the metadata); "in earlier amending provision" types carry no operation; one path linked in pieces (`annex-XV` + `annex-XV-part-1`); sibling refs (1A, 1B); savings matched on 13 items.
- **This sample's coverage:** no OtherQualification text, no staged multi-date effects, no placed by markup, no ranges, no territory in a qualification, no EU finer form. Those rules are covered by unit tests and by the earlier samples (seeds 7, 11, 13), where each was found and fixed.

**Note (2026-10-23):** commits from the D1 fix onward were rewritten before the first push, to scrub three real legislation.gov.uk effect ids (`key-` plus 32 hex, read by GitHub push protection as Mailgun keys) from a test. The hashes cited above are the rewritten ones; the branch `backup/pre-key-scrub-2026-10-23` holds the originals.
