---
session: 'CV-S03: Markup Reader'
status: closed
release: v0.1
opened: '2026-10-22'
closed: '2026-10-23'
outcome: success
parent: change-vocabulary/2026-10-21-cv-00-meta.md

summary: >
  The markup reader passes its acceptance check on the OH&S core family: every change accounted
  for (our faults 0), placement 50/50 and facts 50/50 on an agent-checked sample, repeatable,
  golden 27/27. A corpus pattern catalogue (745 patterns over 164,893 changes) and two agent
  rounds found and fixed eleven defects (A–K).

decisions:
  - what: The reader's single purpose — each change in the markup becomes one change on the provision where it sits, carrying what the markup states; agreement with the feed is CV-S07's, correctness CV-S08's
    why: Jason "single purpose is right"
    result: definition of good with 8 measures; the keys-against-feed count informational, not a gate
  - what: Pattern catalogue first, over every stored law text, as CV-S02b
    why: CV-S02b found readings no sample reached
    result: 1,035 patterns on run 1 exposed A–E; ~2,270 changes landed nowhere, ~430 after
  - what: Changes in a group (Part, Chapter, cross-heading, EU Section) placed per provision; a group's own heading on the group's row, named by our rows (Markup.read takes row xml ids)
    why: a whole inserted cross-heading with its sections was dropped silently
    result: finding A fixed; heading rows named as the parse names them (h.N)
  - what: A provision is placed whole only when the change touches its own number, heading or text, or covers all its text; else per child (H)
    why: two inserted subsections landed as words on the parent; but a repeal round every sub-provision is whole (golden s.78 regressed 25/27 until the cover rule was added)
    result: golden 27/27
  - what: The note's amending provisions read from its structured CitationSubRefs (Operative ones of the first Citation), not parsed from its words (G)
    why: word parsing was wrong on 15/50 (dropped items before "(with", added "(with"/other laws' provisions, split pointers)
    result: affecting right 50/50 after J/K; effect-id changes with amending provisions 99.4%
  - what: EffectIndex.effect_id left untouched; the reader keys ChangeIds itself (Markup.key/1)
    why: EffectIndex is in ParserVersion; changing it stales every law
    result: the parse's /2 fault logged as a parser tell-tale for the next re-parse

metrics:
  catalogue: { laws: 3483, changes: 164893, patterns_run1: 1035, patterns_final: 745, examples: 1127, unclassified: 0, minutes: 16 }
  ohs_check: { changes: 1808, laws_with_changes: 79, placed: 1541, placed_versions: 247, whole_law: 20, note_placements: 1376, our_faults: 0 }
  keys_vs_feed: { in_feed: 1178, legacy: 594, not_in_feed: 36 }
  agent_seed1: { placement_ok: 48, facts_ok: 35, affecting_wrong: 15 }
  agent_seed2: { placement_ok: 50, facts_ok_before_fix: 46, facts_ok_after_fix: 50 }
  legacy_pointers: { legacy_changes: 26836, with_cited_law: 25313, with_amending: 24091 }
  golden: { pass: 27, of: 27 }
  tests: { markup_reader: 14, markup_placement: 8, vocabulary_suite: 2875 }

lessons:
  - title: A corpus catalogue of the reader's own decisions finds silent drops a sample can't
    detail: Placement "nowhere" was invisible in output (no set, no error); classing every change by the reader's dimensions showed ~2,270 changes in Parts/cross-headings dropped. Sample checks only see what the reader emits.
    tag: tooling
  - title: Show the agent the reader's view, not raw ancestry
    detail: The seed-1 agent called two heading changes lost because the sample listed raw ancestor ids; the P1group heading rule placed them correctly. Adding heading_of to the sample stopped the misread.
    tag: tooling
  - title: Re-run golden after every placement rule change
    detail: Per-child placement (H) was right on its own example and broke golden s.78 twice (HSWA, Coronavirus Act) — a repeal round every sub-provision is a whole-provision repeal. The cover-all-text rule restored it.
    tag: data
  - title: In EU law a Section is a group, not a provision
    detail: section-III in EU directives was named s.III; the domestic group-prefix strip had to skip EU law too (chapter-II-section-2).
    tag: data
  - title: The note's markup carries structured pointers — prefer them to its words
    detail: CitationSubRef (CitationRef, SectionRef, Operative) on 99% of notes gives exact amending provisions; word parsing failed on "(with …)", "(as amended by …)", unnumbered schedules and deep refs.
    tag: data

bugs:
  - pattern: "Markup group/heading changes dropped (Part, Chapter, cross-heading lowest holder named nowhere)"
    category: markup reader placement
    module: change_vocabulary/readers/markup.ex
    affected: 2270
    fix: split per provision; group heading on the group's row via row xml ids
    status: fixed
  - pattern: "Retained substitution (paired Repeal + Addition) read as two changes"
    category: markup reader operation
    module: change_vocabulary/readers/markup.ex
    affected: 657
    fix: Addition named by SubstitutionRef joins the Repeal's change
    status: fixed
  - pattern: "Note amending-provision pointers parsed from words: drops/adds/splits provisions"
    category: markup reader pointers
    module: change_vocabulary/readers/markup.ex (cited/1)
    affected: 15 of 50 sampled
    fix: CitationSubRef Operative pointers; schedule paragraphs named as the feed reader names them
    status: fixed
  - pattern: "EU Section id named as a provision (s.III)"
    category: ref naming
    module: change_vocabulary/ref.ex
    affected: 9
    fix: EU section- ids are groups (Ref.group?/2)
    status: fixed
  - pattern: "Repeated CLML id (K3) named by the id, not the element's number"
    category: markup reader placement
    module: change_vocabulary/readers/markup.ex
    affected: 1 sampled
    fix: name a repeated id by its Pnumber
    status: fixed
  - pattern: "EffectIndex.effect_id doesn't strip a ChangeId's -N/2 suffix: occurrences joined apart from their effect in the parse"
    category: parser tell-tale
    module: effect_index.ex (ParserVersion)
    affected: 33
    fix: strip -N(/N) — lands with the next re-parse
    status: open
  - pattern: "AmendingLaw.Pointer.parse word parsing drops the item before '(with', unnumbered 'Sch. para. N', adds '(with …)'/other laws' provisions, splits deep refs"
    category: pointer parsing
    module: amending_law/pointer.ex (its other users)
    affected: 15 of 50 markup notes before G
    fix: prefer CitationSubRef where a note is at hand
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/ref.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_patterns.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/markup_placement.ex
  - backend/lib/mix/tasks/lat.markup_patterns.ex
  - backend/lib/mix/tasks/lat.markup_check.ex
  - backend/test/fixtures/markup_patterns/
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_reader_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_placement_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/markup_patterns_test.exs
  - backend/test/fixtures/feed_patterns/expected.json
  - .claude/skills/markup-reader-check/SKILL.md

depends_on:
  - change-vocabulary/2026-10-22-cv-s02-feed-reader
  - change-vocabulary/2026-10-23-cv-s02b-feed-pattern-catalogue
  - 2026-10-23-issue-186

enables:
  - CV-S04 commencement reader
  - markup-reader-check for later families
---

# Session: CV-S03: Markup Reader (CLOSED)

## Problem

Step 3 of the change-vocabulary workflow (CV-00; Jason 2026-10-22: "restate the aim of each step in the workflow and know what good looks like. Build the step until it is reliably good. Then move on"). Aim: Each change in the revised text's markup becomes one change, on the provision where it sits.

The session does not close until its results pass.

## Todo

- ✅ Define what good looks like (agreed 2026-10-23)
- ✅ Markup pattern catalogue (`mix lat.markup_patterns`), as CV-S02b: 745 patterns accepted
- ✅ Build the acceptance check (`mix lat.markup_check`); run it: OH&S our faults 0
- ✅ Placement checked on a sample: seed 1 (fixes F–I), seed 2 50/50
- ✅ Legacy markup ids carry the note's pointers (94.3% a cited law), from its structured CitationSubRefs, for identity only
- ✅ Fix until the check passes reliably; record the result: PASS 2026-10-23

## Dependencies

- ✅ The steps before it passed (CV-S01, CV-S02 with S02a, S02b and #186 closed 2026-10-23)

## What good looks like (agreed with Jason 2026-10-23: "single purpose is right")

**The reader's one job:** turn each change in the revised text's markup into one change on the provision where it sits, carrying what the markup states. A change is an `Addition`, `Substitution` or `Repeal` element with a ChangeId, however many times that id occurs. Whether legislation.gov.uk's markup is right is CV-S08's job (evidence). What a change means for a label is CV-S09's job.

**Scope:** the OH&S core family's stored CLML (held, CV-S01).

**Pass when all hold:**
1. **Every change id accounted for:** placed on a row we hold, or listed unplaced with a reason from a fixed set. The reasons:
   - in a schedule or annex (K1, the v0.1 limit);
   - outside any provision;
   - whole law (`*`);
   - id not converted (our fault);
   - in the text, not in our rows (our fault).

   Our faults are 0.
2. **Right provision, checked:** a Claude agent checks 50 sampled changes against the CLML. Each must be on the lowest provision holding all its occurrences. A heading change belongs to its group's provision.
3. **Facts carried faithfully** on the same 50:
   - key: the effect id from the ChangeId, else the ChangeId;
   - operation: Repeal / paired Repeal / Substitution / Addition;
   - level: whole provision vs words;
   - retained (RetainText);
   - territory (Extent).
4. **Legacy ids** (`d29p…`, `M_F_…`) carry the note's pointers: the cited law and the amending provisions. These serve identity only and are never facts. The measure: the share of legacy changes with a cited law, and every one checked in the sample.
5. **Tested:** each rule defined in words, with a unit test.
6. **Repeatable:** two runs with one seed give the same report.
7. **Golden** stays 27/27.
8. **Keys against the feed (a count, not a gate).** The markup's keys split three ways:
   - an effect id the feed holds;
   - an effect id the feed lacks (expected small: a large count tells of the feed or our reading of it);
   - legacy.

   Joining them is CV-S07's job; this count tells it how much matching rests on pointers.

**Proposed approach:** take the pattern catalogue first. CV-S02b found readings no sample had reached.
- A `mix lat.markup_patterns` task would run over every stored CLML.
- Each pattern is the element × in the number or title × RetainText × SubstitutionRef × Extent × the kind of id × the place.
- Then a `mix lat.markup_check` (gate, placement, sample) like `lat.feed_check`, and the agent on 50.

## Pattern catalogue (built 2026-10-23)

- **Built:** `ChangeVocabulary.MarkupPatterns` and `mix lat.markup_patterns`, as CV-S02b's feed catalogue. A change is its key's change elements and note refs, classed on 8 dimensions:
  - key, operation, where, level, retained, extent, placement, pointers.
- **Examples:** each is the XML around the change: the smallest element holding it, pruned to the touched provisions when over 8 KB, held only up to 30 KB.
  - Effect ids are scrubbed to `key-E`, `key-E2`, …
  - An example is held only when it reads alone as it does in its law.
- **Tests:** `MarkupPatternsTest` (7, green before the fixtures exist).
- **Trial:** 40 random laws, ~6 s. The whole store (3,483 law texts) should take ~5 min.
- **Seen in trial (to measure):** ChangeId `key-<hex>-<n>/2`. `EffectIndex.effect_id/1` doesn't strip `/2`, so that occurrence is keyed apart from its effect.

## Catalogue run 1 (2026-10-23, 18 min)

The whole store: 3,483 law texts, 164,926 changes, 1,035 patterns, 0 unclassified. 1,463 examples. 188 were too large to hold and 34 read differently alone, so they are not held; other examples cover those patterns. `examples.json` is 8.5 MB (the feed's is 2 MB).

| Dimension | Patterns | Note |
|---|---|---|
| key | 440 | `V_W_`/`V_S_`/`V_NI_` uuid tails not generalised (a shape fix, not a reader fault) |
| placement | 489 | the provision depth (+n) multiplies it |
| operation | 22 | |
| where | 21 | |
| extent | 43 | |
| level, retained, pointers | 6, 7, 7 | |

Note-ref-only keys (effect placed by a `CommentaryRef` only, no change element): 72,461.

**Findings (measured counts of changes; counts are per pattern, so approximate where a change has several):**

- **A. A change in a group lands nowhere** (about 2,270 with change elements, about 655 note refs only).
  - The lowest id holding a change is a Part, Chapter or cross-heading, and `Ref.from_clml` names no provision for it, so the change is dropped.
  - Two cases:
    - the group's own heading changed (`part-1-crossheading-biodiversity-lists` Title Addition);
    - one change across the group's provisions, e.g. a whole cross-heading inserted with its sections (anaw 2016/2 Part 4 "appropriately qualified", s.85B–85F).
  - LAT holds rows for Parts, Chapters and headings (`pt.3`, `pt.3.ch.1`, `h.N`, with `source_xml_id`).
- **B. A non-provision id below the provision** (a `Term`, a `CitationSubRef`) is taken as the lowest id, so the change lands nowhere: about 50.
- **C. Id grammar `part-V-section-36-2An1`** (a Part prefix on a section id): not converted, about 30.
- **D. Retained substitution** (a `RetainText` Repeal with `SubstitutionRef` to an Addition, one effect id; e.g. a staged substitution "for specified purposes") is read as two changes on one provision, one inserted and one substituted (retained): 657, plus about 80 mixed.
- **E. ChangeId `key-<hex>-<n>/2`:** `EffectIndex.effect_id/1` doesn't strip `/2`, so the occurrence is keyed apart from its effect: 33.

## Fixes A–E (Jason 2026-10-23: "All good, start")

- **A:** where the lowest id holding a change is a group (Part, Chapter, cross-heading), each provision under it is placed apart, and the group's own heading or text is a change to the group's row. `Markup.read/3` now takes the law's row ids (`Ref.xml_ids/2`), as the feed reader does: a group has no other name (`pt.4`, `h.N`). A group we hold no row for stays unplaced.
- **B:** paths hold only row ids (provisions, and groups by id word or row), never a `Term`'s or a citation's id.
- **C:** `Ref.from_clml` names `part-V-section-36-2An1` by its provision. This doesn't apply in EU law, where a Section is a group (`chapter-II-section-2`).
  - The feed catalogue gained from it: 3 examples moved from `?` to the provision (`Pt. 3 s. 56`, `Pt. 15 reg. 81(4)`, `Pt. 14 reg. 78`), and their held expectations were updated.
- **D:** an Addition named by a paired Repeal's `SubstitutionRef` joins the Repeal's change: one substitution, retained as the Repeal says.
- **E:** `Markup.key/1` takes the effect id from the ChangeId whatever follows it (`-N/2`).
  - `EffectIndex.effect_id/1` is left alone because it is in `ParserVersion`. **Parser tell-tale, for the next re-parse:** it doesn't strip `-N/2`, so 33 occurrences are joined apart from their effect.
- **Tests:** `MarkupReaderTest` (A–E, 7 tests). Example cap 30 → 15 KB.

## Catalogue run 2 and acceptance (2026-10-23)

- **Run 2** (16 min) after fixes A–E: 164,893 changes, 727 patterns (1,035 before), 0 unclassified. Changes with markup landing nowhere fell from about 2,270 to about 430: Part, Chapter and cross-heading changes in laws holding no row for the group. The examples file is 4.8 MB.
- **Golden:** 27/27.
- **Accepted** (Jason: "Next go"): all 727 patterns. `expected.json` was written from the held examples' readings, and `MarkupPatternsTest` passes (1,113).
- **Mixed operations under one effect, accepted as faithful:**
  - Addition + Substitution on different provisions: 78.
  - Addition + paired Repeal read as inserted + substituted: 11. In one, the `SubstitutionRef` points to another effect's Addition; in another, one effect makes a stand-alone insertion plus a paired substitution.

  A conflict on one provision is for the merge and evidence steps (CV-S07, CV-S08).

## The check: `mix lat.markup_check` (built 2026-10-23)

- **`ChangeVocabulary.MarkupPlacement`** (pure, 8 tests).
  - Outcomes: placed, placed_versions, placed_ancestor, whole_law.
  - Unplaced: schedule_not_parsed (K1), outside_provisions, group_row_missing, id_not_converted, row_missing. The last three are our faults.
  - `against_feed/2`: in_feed, not_in_feed, legacy.
- **The task:** gate on stored text and feed; changes and note placements reported apart; keys against the feed; a seeded sample (`--sample FILE --n N --seed N`).
- **Trial** (3 OH&S laws, 5 s): 332 changes and 296 note placements, all placed. Keys: 95 in the feed, 237 legacy.

## Check on OH&S (2026-10-23, seed 1)

- **First run:** 9 faults, `row_missing`, one pattern. In EU directives `section-III` (a Section, a group of articles) was named as the provision `s.III`, so articles inserted into it weren't placed apart (finding F).
  - **Fixed:** `Ref.from_clml` names no provision for an EU `section-` id. `Ref.group?/2` marks it a group, and the markup reader splits it like a Part.
  - **Feed catalogue:** 2 EU annex examples lost a bogus target (`s.0000A3`, an annex list entry) and keep `annex.V`. Their expectations were updated; 1,601 pass.
- **After the fix** (25 s):

  | | Count | Laws | Outcome |
  |---|---|---|---|
  | Changes | 1,808 | 79 | placed 1,541, placed_versions 247, whole_law 20; **our faults 0** |
  | Note placements | 1,376 | 63 | placed 1,333, placed_versions 43; our faults 0 |
  | Keys against the feed | | | in feed 1,178, legacy 594, **not in feed 36** |

  No law lacked stored sources.
- **Repeatable:** two runs with seed 1 gave identical reports and identical sample files.
- **Agent check** on the 50-change sample: running.

### Agent check, seed 1 (50 changes)

- **Facts:** key, operation, retained and territory are right on all 50. Level is right on 49; #43 is finding H below.
- **Placement:** 47 right; #12 (finding I below), #43 (finding H below).
  - The agent flagged #18 and #22 as group-heading changes lost. Checked: both are the article's own heading (a `P1group` Title), so `art.Article 51` and `art.Article 8` are correct.
  - The sample's `provision_ids` listed raw ancestor ids without the heading-group rule, which misled the agent: to improve.
- **Findings:**
  - **G. `affecting` pointers wrong in 15/50.** They are read from the note's words by `AmendingLaw.Pointer.parse`:
    - the last item before "(with …)" is dropped ("regs. 1, 34(2)(b) (with …)" → reg.1);
    - an unnumbered "Sch. para. N" is dropped;
    - "(with …)" provisions and another law's "(as amended by …)" provisions are added;
    - "Sch. 2 para. 15(a)(i)(aa)" is split into three.

    The note's own `CitationSubRef` elements carry each pointer structured (`CitationRef` to the law's Citation, `SectionRef`, `Operative="true"` on the operative one). In a 200-law sample, 3,094 of 3,113 notes carry them and 3,060 mark Operative.
  - **H. Whole provisions inserted under one change id land as words on their parent** (#43: s.18(1A), (1B) → `s.18`, words). Groups are split per child; provisions are not.
  - **I. K3 duplicate id with our row named right** (#12, eur 2008/1272: three P2s `article-38-1` with Pnumbers A1, 1, 3). Our row `art.Article 38(3)` holds `article-38-1`, but `Ref.xml_ids` picks `art.Article 38(1)`.

### Fixes G, H, I (Jason 2026-10-23: "Agreed")

- **G:** `affecting` comes from the note's `CitationSubRef`s of its first Citation: the Operative ones, else all of that citation's. Each `SectionRef` → `Order.ref`. A note with none falls back to its words.
  - 586 catalogue examples changed. Spot check: the law's own commencement pointer (`reg.1(2)`) drops, leaving the operative provision, and notes that gave nothing now give theirs (`sch.2.para.270(k)`).
  - The merge matches on any shared pointer, so dropping a law's `reg.1` sharpens matching.
  - The shared `AmendingLaw.Pointer.parse` keeps its faults: logged for its other users.
- **H:** a provision is placed whole only when the change touches its own number, heading or text; otherwise each provision under it is placed apart (s.18(1A), s.18(1B)). 16 catalogue examples changed targets.
- **I:** a repeated id (K3) is named by the element's own Pnumber (`article-38-1` numbered 3 → `article-38-3` → art.Article 38(3)).
- **Tests:** `MarkupReaderTest` 13 (A–I).
- **Sample:** `heading_of` gives the provision a P1group title belongs to (the misread behind #18 and #22).
- **Running:** catalogue run 3, the check twice with seed 2, golden.

### Runs 3 and 4 (2026-10-23)

- **Run 3:** golden 25/27. Both failures were `s.78` (HSWA 1974, Coronavirus Act 2020): a repeal round every sub-provision, which H split into the children.
  - **Fix:** a provision stays whole when the change covers all the text under it. Golden 27/27.
- **Run 4** (after the fix): 164,893 changes, 745 patterns, 0 unclassified. 19 new patterns, all placement variants; 551 examples read differently, from G and H.
  - Checked the odd ones: `section-N → art.Article N` is F working (an EU Section's inserted articles).
  - `s.A2D3` (`section-A2D3-3-a` under `section-A2DA-3`) and `article-9-e` inside `section-8-1` are K3 structure faults, carried faithfully.
  - All accepted; tests 2,874 pass.
- **Check, seed 2:** changes 1,808, our faults 0; note placements 1,376, our faults 0; keys 1,178 in the feed, 594 legacy, 36 not in the feed. PASS. Two runs gave identical reports and samples.
- **Agent check, seed 2:** running.

### Agent check, seed 2 (50 changes)

- **Placement:** 50/50, including K9 ×8 and M3 ×1.
- **Facts:** key, operation, level, retained, territory and cited are right on all 50. `affecting` was wrong on 4, from two new defects in G's conversion:
  - **J.** An unnumbered Schedule's `schedule-paragraph-3-3` became `sch.paragraph`.
  - **K.** `schedule-10-part-5-paragraph-9` became `sch.10.pt.5`.

  The shared `Order.ref` names these short (the K10 shape).
  - **Fixed** in the reader's own `pointer_ref/1`, named as the feed reader names affecting provisions (`sch.10.para.9`, Part left out; `sch.para.3(3)`).
  - The four items were re-checked and now read right. 34 catalogue examples improved the same way; re-accepted.
  - Golden 27/27; tests 2,875.
- **Legacy pointers (measure 4, the corpus catalogue):**

  | | With a cited law | With amending provisions |
  |---|---|---|
  | Legacy changes (26,836) | 25,313 (94.3%) | 24,091 (89.8%) |
  | Effect-id changes | | 65,233 of 65,596 (99.4%) |

## Result: PASS (2026-10-23)

1. **Every change accounted for:** OH&S 1,808 changes and 1,376 note placements; our faults 0.
2. **Right provision:** 50/50 on seed 2, after fixes F, H and I from seed 1.
3. **Facts:** 50/50 after J and K were fixed and re-checked.
4. **Legacy pointers:** 94.3% carry a cited law. They are pointers only, from the note's structured `CitationSubRef`s.
5. **Tested:** `MarkupReaderTest` 14, `MarkupPlacementTest` 8, `MarkupPatternsTest` (745 patterns, 1,127 examples).
6. **Repeatable:** seeds 1 and 2, each run twice, gave identical reports and samples.
7. **Golden:** 27/27.
8. **Keys against the feed:** in feed 1,178, legacy 594, not in feed 36.

The recipe is the `markup-reader-check` skill.

## Agent prompt (round 2; the skill's)

```
You are checking the markup reader of a legal-data service (CV-S03 acceptance check, family F).
READ-ONLY: no edits, no internet, no DB writes, no mix tasks. Read files, read-only psql SELECTs,
decompress stored XML; /usr/bin/python3 for parsing. Working dir: backend/.

Input: FILE — 50 sampled changes from the revised-text change markup. Each item: law, key, markup
(element, change_id, provision_ids = ALL id'd ancestors raw, heading_of = the provision a P1group
Title's group holds, attributes RetainText/SubstitutionRef/Extent/CommentaryRef, text), note_refs,
reader (outcome, feed, changes: key, target, claims {operation, level, retained, territory, cited,
affecting, placed}).

Stored data: law text data/cache/clml/{type}/{year}/{number}/body/data.xml.gz; rows:
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
"select section_id, source_xml_id, section_type from legal_articles where law_name='LAW' and section_id like 'LAW:s.5%'"

The reader's one job: each change in the markup becomes one change on the provision where it sits,
carrying what the markup states. Whether the markup is right, and what it means for a label: out of scope.

Rules:
- A change: an Addition/Substitution/Repeal with a ChangeId, however many times it occurs. Key: the
  effect id ("key-"+32 hex, whatever follows), else the ChangeId (legacy).
- A Repeal with a SubstitutionRef and the Addition it names: ONE substitution.
- Placement: only row ids count (provisions; groups — Parts, Chapters, cross-headings, EU Sections;
  never a Term's or citation's id). A P1group Title change → the provision the group holds
  (heading_of). The lowest provision holding all occurrences, IF the change touches its own number,
  heading or text, or covers all the text under it; else each provision under it apart. Under a group
  each provision apart; the group's own heading → its row (pt.N, h.N as our rows name it). No common
  id: effect id → each top provision; legacy → "*". A repeated id is named by the element's Pnumber.
- Names: section-14-1-a → s.14(1)(a); regulation-5 → reg.5; NI Order article → reg.N; EU article →
  art.Article N(x); schedule → sch.N.para.M; source suffix as rows hold it; versions s.23[E+W].
- Operation: paired Repeal → substituted; Repeal → repealed; Substitution → substituted; Addition → inserted.
- Level: provision when the change wraps the Pnumber or covers all its own text; else words.
- retained: a Repeal's RetainText. territory: Extent normalised.
- cited: the law of the note's first Citation with a URI. affecting: that Citation's CitationSubRefs
  (Operative="true" ones, else all), each SectionRef as a ref (a Schedule paragraph by its Schedule,
  Part left out: sch.10.para.9; unnumbered sch.para.3(3)); no CitationSubRef → the note's words.
  Pointers for identity only.
- Outcomes: placed, placed_versions, placed_ancestor, whole_law; unplaced: schedule_not_parsed (K1),
  outside_provisions, group_row_missing, id_not_converted, row_missing.

Known patterns: K1 schedules/annexes unparsed; K3 structure faults (ids contradicting nesting);
K9 placed_versions targets every version; M1 one effect, Addition on some provisions and Substitution
on others; M2 one effect, stand-alone insertion plus paired substitution on one provision; M3 feed vs
markup disagreement; P1 a note citing a law in untagged text (cited = first tagged Citation).

For each item: find every occurrence of its change ids, read the note's Commentary XML, judge placement
(right provision, named right, held in DB?) and facts against the markup.

Output: table per item (#, law, key last 6, placement OK/WRONG/doubtful, facts OK/WRONG/doubtful, note
with K#/M#/P# or NEW); counts per dimension; NEW defects with evidence. Rigorous; WRONG needs evidence;
check heading_of before calling a heading change lost. Under 900 words.
```
