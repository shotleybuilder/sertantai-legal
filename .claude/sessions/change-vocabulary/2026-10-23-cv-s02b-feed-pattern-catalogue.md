---
session: 'CV-S02b: Feed Pattern Catalogue'
status: active
release: v0.1
opened: '2026-10-23'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-S02b: Feed Pattern Catalogue (ACTIVE)

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
