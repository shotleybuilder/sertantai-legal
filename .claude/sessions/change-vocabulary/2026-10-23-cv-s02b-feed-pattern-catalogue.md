---
session: 'CV-S02b: Feed Pattern Catalogue'
status: closed
release: v0.1
opened: '2026-10-23'
closed: '2026-10-23'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
outcome: success

summary: >
  Built a feed pattern catalogue: mix lat.feed_patterns classes all 251,692 stored feed effects by
  what the reader decides into 985 patterns, with real examples as test fixtures, and
  FeedPatternsTest holds the reader to them (unreviewed patterns fail; K10 pending). Its first run
  found ten misreadings no 50-effect sample had reached (A–J), all fixed in the change
  vocabulary's own modules; the OH&S feed check stays at 0 faults and golden at 27/27.

decisions:
  - what: Patterns are one per dimension and value (ref, verb, level, qualification, staging, linkage, range, eu_finer), not their cross product
    why: the literal strings are unbounded but the reader's decisions are bounded; a cross product would be unreviewable
    result: 1,470 → 1,065 → 985 patterns after grouping qualifications into classes and stripping verb noise
  - what: Expectations start as the reader's current output (--accept); Jason reviews the readings flagged by dimension; held expectations never change on accept
    why: hand-writing ~1,600 expectations is waste where the reader is right; review effort goes to the long tail
    result: A–J raised and decided one by one
  - what: Readings fixed in new change-vocabulary modules (EffectVerb, Qualification) and Ref, not in EffectFacts or Commencement.Order
    why: EffectFacts and Order count toward LabelVersion; changing them would stale every law's labels and need a relabel run
    result: LabelVersion and ParserVersion unchanged; no corpus re-run
  - what: B — a verb counts only when it says what this effect did to the affected provision
    why: '"(as substituted)", "repeal of affecting provision", savings and appointed-day types named another law''s change (Jason asked for B explained with the records first)'
    result: 13 effects to no operation; e.g. 2005 c. 15 s.75A no longer read as repealed
  - what: E — a stage is partial only when its qualification limits scope; the qualification's classes are carried as read
    why: 'a time of day, "in accordance with", "retrospective" limit nothing (readers carry facts, the fold decides)'
    result: ~16,000 in-force entries no longer partial; 12 staged removals whole at their unlimited stage
  - what: F — a prospective commencement with no date is a change (commenced, prospective, no date)
    why: the reader dropped 6,135 effects entirely; the provision awaiting commencement is a fact
    result: commenced changes 60,244 → 66,393
  - what: J — one dated stage with a qualification carries partial, qualification, in_force_for/except; a partial whole removal is repealed_in_part
    why: 'found by tracing E''s effect; one-stage changes carried nothing (NISR 2007/31 "revoked" for specified purposes read as whole)'
    result: 367 removals repealed → repealed_in_part; ~2,340 effects carry their qualification
  - what: K10 marked pending with full names (sch.N.pt.R.para.N; unnumbered schedule sch.para.N, a proposed convention)
    why: schedules are not parsed (K1); the correct names wait for that
    result: 16 patterns, ~2,300 effects, 42 examples pending

metrics:
  catalogue: { laws: 1207, effects: 251692, excluded_legacy_dated: 1622, unclassified: 0, patterns: 985, examples: 1638, pending_examples: 42, fixtures_mb: 3.7, run_minutes: 8 }
  dimensions: { verb: 412, ref: 336, qualification: 84, eu_finer: 65, staging: 48, level: 20, linkage: 17, range: 3 }
  fixes: { A_except_entries: 1130, B: 13, C: 24, D: 14, E_entries: 16000, F: 6135, G: 10, H: 40, J_removals: 367 }
  acceptance: { ohs_our_faults: 0, ohs_placed: 3549, ohs_tell_tales: 5, golden: "27/27", change_vocabulary_tests: 1758 }

lessons:
  - title: A full-corpus catalogue finds what repeated samples cannot
    detail: Five 50-effect rounds passed CV-S02, yet the first catalogue run surfaced ten misreadings (A–J), some in thousands of effects (F 6,135; E ~16,000 entries; A ~1,130). The long tail of effect types and qualifications is where readers go wrong.
    tag: data
  - title: Tracing one fix's effect through the catalogue exposes the next defect
    detail: Checking why 12 removals moved after E led to J (one-stage changes carried no qualification at all). The pattern diff between runs is a measure in itself.
    tag: data
  - title: The catalogue is a regression check for refactors
    detail: Reordering the reader's in-part check for speed was verified by the catalogue (all 1,758 examples identical) rather than by reasoning.
    tag: tooling
  - title: Keep reader-only rules out of version-hashed shared modules
    detail: EffectFacts and Commencement.Order count toward LabelVersion; layering the reader's rules in its own modules avoided staling every law's labels.
    tag: tooling
  - title: Per-effect regex chains cost real time at corpus scale
    detail: EffectVerb.kind re-read the type several times (152 µs a call); reading it once halved it, but the catalogue run still went from 2 to 8 minutes.
    tag: tooling

bugs:
  - pattern: "Feed reader read an excepted territory as in_force_for ('except in relation to W.' → W)"
    category: feed reader
    module: ChangeVocabulary.Readers.Feed (now Qualification)
    affected: 1130
    fix: Qualification.in_force_for ignores the except clause; in_force_except carries it
    status: fixed
  - pattern: "Feed reader took a verb describing another law as this effect's operation ('(as substituted)', 'repeal of affecting provision', savings, appointed days)"
    category: feed reader
    module: ChangeVocabulary.EffectVerb
    affected: 13
    fix: drop '(as …)'; no_operation? for affecting-provision repeals, savings, transitional, appointed days
    status: fixed
  - pattern: "Feed reader missed removal and commencement words (cease to have effect after an object, removed, left out, omiited, rep in pt, lapsed, coming into operation, becomes, moved, restored, revived)"
    category: feed reader
    module: ChangeVocabulary.EffectVerb
    affected: 48
    fix: reader word mapping
    status: fixed
  - pattern: "Feed reader marked any non-completing qualification partial (time of day, in accordance with, retrospective)"
    category: feed reader
    module: ChangeVocabulary.Qualification
    affected: 16000
    fix: partial only when scope is limited; classes carried
    status: fixed
  - pattern: "Feed reader dropped prospective commencements with no date entirely"
    category: feed reader
    module: ChangeVocabulary.Readers.Feed
    affected: 6135
    fix: one change, commenced, prospective, no date
    status: fixed
  - pattern: "Feed reader carried no qualification facts on one-stage text changes (revoked for specified purposes read as whole)"
    category: feed reader
    module: ChangeVocabulary.Readers.Feed
    affected: 2340
    fix: one-stage changes carry partial/qualification/territory; partial whole removal is repealed_in_part
    status: fixed
  - pattern: "rule-N ids not named by the reader's converter"
    category: feed reader
    module: ChangeVocabulary.Ref
    affected: 40
    fix: rule- named as regulation (reg.), as the parse does
    status: fixed

artifacts:
  - backend/lib/mix/tasks/lat.feed_patterns.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/feed_patterns.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/effect_verb.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/ref.ex
  - backend/test/fixtures/feed_patterns/
  - backend/test/sertantai_legal/scraper/change_vocabulary/feed_patterns_test.exs
  - backend/data/reports/feed-patterns/catalogue-2026-10-23.md
  - .claude/skills/feed-reader-check/SKILL.md

depends_on:
  - 2026-10-22-cv-s02-feed-reader
  - 2026-10-23-cv-s02a-parser-tell-tales

enables:
  - Feed reader checks for new families start from the catalogue (new patterns as a diff)
  - CV-S03 markup reader (a catalogue of the same kind can follow)
  - K10 pending tests turn green when schedules are named in full
---

# Session: CV-S02b: Feed Pattern Catalogue (CLOSED)

## Problem

The feed reader passed CV-S02 on sampled effects (5 rounds of 50). A sample only tests the rules it happens to hit: the seed-17 clean pass had no staged effects, "other" qualifications, ranges or EU finer forms.

Jason (2026-10-23): "The feed has a wide but bounded pattern. Could all the possible patterns be held as a test fixture? Against which the reader is tested. Things like nested schedules would 'fail'."

Measured across all 1,208 stored feed pages (251,692 effects, every family), with a rough grouping:

| Dimension | Distinct shapes | Shapes covering 99% |
|---|---|---|
| Ref ids | 2,614 | 36 |
| Qualifications | 566 | 63 |
| Effect types | 3,689 (free text) | — |
| Provision text | 2,751 (free text) | — |

The grammar is bounded; the literal strings aren't. The catalogue keys on what the reader decides.

## Todo

- ✅ What good looks like, agreed with Jason (2026-10-23, below)
- ✅ Pattern dimensions in the reader's own terms (`ChangeVocabulary.FeedPatterns`):
  - id grammar (kind → Part → Chapter → paragraph → sub-levels);
  - verb after the word mapping (`EffectFacts.type`);
  - level word;
  - qualification class (complete, partial, territory, other);
  - staging shape;
  - EU finer-reading form;
  - one path linked in pieces vs siblings;
  - ranges.
- ✅ A generator (mix task) writes `test/fixtures/feed_patterns/` from the stored feeds: each pattern with its count and 1–3 real effect records. Regenerable; a new family's feeds show new patterns as a diff
- ✅ A test per pattern: its records through the reader against an expected result
- ✅ Known limits as `:pending` tests with the correct expectation (excluded by default; `mix test --include pending` lists the limits still failing). E.g. nested schedule ids (K10: `schedule-N-part-R-paragraph-N` → `sch.N.pt.R.para.N`)
- ✅ An unreviewed pattern (no expectation yet) fails, forcing a decision
- ✅ Clean up the shape grouping (legacy dated types "am (E) (1.1.2004)", `err:Ref` / `FoundRef` excluded)
- ✅ The `feed-reader-check` skill and the CV-00 recipe: the catalogue runs first for a new family; the agent sample stays for facts against the law text

## Dependencies

- ✅ CV-S02 Feed reader closed PASS (2026-10-23)
- ✅ CV-S02a parser tell-tales closed (2026-10-23); K10 (nested schedule naming) still deferred, so its catalogue tests start pending

## What good looks like (agreed 2026-10-23)

Jason: "Agree, start".

1. **Full coverage.** The generator writes `test/fixtures/feed_patterns/` from every stored feed. Every effect is classed: `unclassified` is 0. Legacy dated types are excluded and counted.
2. **Each pattern is checked.** A pattern holds its count and 1–3 real effects from different laws. Each effect has its context and an expected outcome, and runs through `Feed.read` in a test.
3. **Known limits are visible.** A limit is marked `pending: <why>`, its examples holding the *correct* outcome. Those tests are excluded by default; `mix test --only pending` lists them.
4. **New patterns are forced into a decision.** A pattern with no status fails the suite.
5. **No regression.** The OH&S feed check stays at 0 faults; golden stays 27/27.
6. **The workflow uses it.** The catalogue runs first for a new family; the agent sample stays.

Expectations: today's reader output is accepted as the starting point (`--accept`), and Jason reviews it once as a diff, by dimension. Wrong readings become `pending` with the correct outcome.

## Build

- `ChangeVocabulary.FeedPatterns` (pure) holds:
  - the dimensions: ref (id grammar → row ref, our row's id or the shared namer's; path pieces; range ends), verb, level, qualification, staging, linkage, range, eu_finer;
  - `excluded/1` (legacy dated types);
  - `encode/2` and `decode/1`: an example's effect is "E", never legislation.gov.uk's id (push protection);
  - `outcome/1`: each change's key, target and claims.
- `Feed.complete?/1` and `Feed.in_force_for/1` are now public, so the catalogue classes qualifications by the reader's own rule.
- `mix lat.feed_patterns [--accept] [--laws A,B] [--out DIR]` is read-only over the store, rows and law text, and writes the three JSON files. An example keeps only the context it needs (refs' row ids, the range's stretch of order, the article's rows for EU finer forms). It is checked to read the same as with the whole law's context; `examples needing their law's full context` is counted.
- `FeedPatternsTest`: one test per example; "every pattern reviewed"; "every effect classed"; shape unit tests.
- Four-law trial (HSWA 1974, MHSWR 1999, CLP 2008, 2008/1597): 1,749 effects, 0 unclassified, 142 patterns, 133 examples, 0 needing full context; 138 tests pass. No effect ids in the fixtures.

## Full catalogue (2026-10-23)

`mix lat.feed_patterns --accept`, about 2 minutes:
- 1,207 laws, 251,692 effects, 1,622 legacy dated types excluded, 0 unclassified;
- 1,065 patterns, 1,717 examples, 0 needing a whole law's context;
- by dimension: ref 365, verb 431, qualification 115, staging 48, eu_finer 65, level 21, linkage 17, range 3;
- fixtures are 3.8 MB.

The first full run crashed in `Ref.xml_ids` (`List.last([])`) after law 400. It didn't reproduce on laws 400–500 or on a rerun. A failing law is now recorded as unclassified, by name, instead of stopping the run.

Two classifier passes: qualifications were grouped into classes (279 → 115), and verb words had punctuation and "by …" stripped (594 → 431).

### Review: readings flagged (each checked against the raw feed type and the reader)

| # | Pattern | Effects | Reading now | Evidence |
|---|---|---|---|---|
| A | "except in relation to W." read as a territory | ~1,130 entries | `in_force_for` "W": inverted | `Feed.in_force_for("in so far as not already in force except in relation to W.")` = "W" |
| B | a verb that describes another law | 13 | an operation | "fees confirmed by … (as substituted)" → substituted; "savings for effects of … (as inserted)" → inserted; "repeal of affecting provision 2020 c. 7" → repealed; "saving (mods) re repeal of …" → repealed; "Appointed days (transitional provns added)" → inserted |
| C | removal words not mapped | 24 | nil | "words cease to have effect" (12), "words removed" (3), "words left out" (2), "word omiited" (2), "rep in pt" (3), "lapsed by virtue of the omission of enabling provision" (2) |
| D | "coming into operation" (NI and older SIs) | 14 | nil | SI 1977/500 reg. 3, dated 1978-10-01, "wholly in force" |
| E | qualifications that limit no purpose read as partial | time of day 2,204; "in accordance with" 13,246; retrospective 352; "other(no date)" 583 | partial true (`partial` = not complete) | "at the end of the day" → partial |
| F | a commencement with no date (prospective) | 6,135 | no change at all | `UK_anaw_2016_3` s.54 "coming into force", prospective |
| G | moved / becomes / restored / revived | 10 | nil | "reg. 23 becomes reg. 23(1)"; "restored" s.94 |
| H | rule ids are not named | 40 | none | `rule-2-da` (SI 1998/1941): the shared namer has no `rule` kind |
| I | nested schedule ids named short (K10) | ~2,100 | sch.N.pt.N / sch.paragraph | `schedule-N-part-N-paragraph-N` → sch.N.pt.N; `schedule-paragraph-N` → sch.paragraph |

Read as intended (no action): "insertion/substitution by … extended to N.I." is nil (an extension, not an insertion); an empty feed type is nil (6,784); "repealed & superseded" is repealed; `part-N` / crossheading / chapter → none (not a provision, placed "?").

### Fixes (Jason 2026-10-23: "All good"; B explained in full first)

- `ChangeVocabulary.EffectVerb` (new): the reader's verb reading on top of `EffectFacts`, which is left unchanged so `LabelVersion` doesn't move.
  - B: "(as inserted/substituted/…)" is dropped; the repeal of an affecting provision, savings, transitional provisions and appointed days are no operation (`no_operation?/1`).
  - C, D, G: new words for removal, coming into operation, becomes/moved, restored/revived.
- `ChangeVocabulary.Qualification` (new):
  - A: `in_force_for` never reads an excepted territory; `in_force_except` carries it.
  - E: `partial?` only when the qualification limits scope (purposes, territory, except, dated scope, provisions); its classes are carried as the `qualification` claim.
- `Feed`:
  - F: a prospective commencement with no date is one change (commenced, `prospective: true`, no date);
  - every effect carries `prospective`;
  - the `Feed.complete?` and `Feed.in_force_for` added earlier this session were removed (now `Qualification`).
- H: `Ref.from_clml("rule-…")` names rules as `reg.`, as the parse does. The shared namer `Order` is unchanged (it is in `LabelVersion`).
- Tests: feed facts A–G, the H target, the catalogue's own tests. Change vocabulary: 1,758 pass.
- Regenerated: 969 patterns; the effects are not reclassified.

| Reading | Before | After |
|---|---|---|
| commenced | 60,244 | 66,393 (F: 6,135 prospective; D: 14) |
| no change | 6,135 | 0 |

12 removals moved from repealed_in_part to repealed. They are staged removals whose qualifications all counted as partial, and one stage now limits nothing (E).
- Speed: `EffectVerb.kind` read the type several times (152 µs a call); it now reads it once (82 µs). The catalogue run was ~12 min against ~2 min before.
- The speed-up reorders the in-part check. The catalogue confirmed it: all examples read the same (1,758 pass).
- Shapes: a lettered Part (`sch.1.pt.B`) is now N.

### New finding J (raised 2026-10-23)

A one-stage text change with a limiting qualification carries no `partial`, qualification or territory. The reader carries those only for commencements and multi-stage changes. Examples: "revoked" for specified purposes (NISR 2007/31), "repealed" "for S." (asp 2012/8). Affected: inserted 951, substituted 763, repealed 621, renumbered 7, repealed_in_part 2, i.e. ~2,340 effects.

### J fixed (Jason: "Fix J")

A one-stage change with a qualification now carries `partial`, `qualification`, `in_force_for` and `in_force_except`, as a staged change's first stage does. A whole removal that is partial becomes `repealed_in_part`. Tests use NISR 2007/31 ("revoked", for specified purposes) and asp 2012/8 ("repealed", for S.).

Effect on the corpus: 367 removals moved from repealed to repealed_in_part (31,604 → 31,237; 1,470 → 1,837).

### K10 pending

- 16 ref patterns (~2,300 effects) are marked `pending: K10 …`.
- Their 42 examples hold the full names (`sch.N.pt.R.para.N`; unnumbered schedule `sch.para.N`, my proposed convention), with a range's span expanded.
- Written by a one-off script over `expected.json` (`--accept` never changes a held expectation).
- `mix test …feed_patterns_test.exs`: 1,601 pass, 42 excluded. `--only pending`: 0/42 pass, all K10.

### Catalogue now

- 985 patterns, 1,638 examples, 0 unclassified.
- By dimension: verb 412, ref 336, qualification 84, eu_finer 65, staging 48, level 20, linkage 17, range 3.
- A full run takes ~8 min. The new verb and qualification rules run per effect: 2 → 8 min, acceptable for a regeneration.

### Acceptance (2026-10-23, Jason: "Run")

1. Full coverage: 251,692 effects, 0 unclassified, 1,622 legacy dated types excluded. ✅
2. Each pattern checked: 985 patterns, 1,638 examples; `FeedPatternsTest` passes 1,601 with 42 K10 examples pending. ✅
3. Known limits visible: `--only pending` lists the 42 failing (K10). ✅
4. An unreviewed pattern fails ("every pattern is reviewed" test). ✅
5. No regression ✅:
   - OH&S feed check: our faults 0; placed 3,549, not in text 128, by markup 5, tell-tales 5 (all `not_found`), unchanged from CV-S02a;
   - golden 27/27.
6. The workflow uses it: the `feed-reader-check` skill has a new step 0 and updated reader rules in its agent prompt; the CV-00 recipe runs the catalogue first. ✅

- Review list (local, git-ignored): `backend/data/reports/feed-patterns/catalogue-2026-10-23.md`.
- Code commit f772d521 (all pre-commit checks passed).
