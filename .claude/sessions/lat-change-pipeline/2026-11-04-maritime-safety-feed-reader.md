---
session: 'Maritime Safety: Feed reader'
status: closed
opened: '2026-11-04'
closed: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
step: Feed reader
outcome: success
summary: >
  The feed reader accounts for all 4,786 changes-feed effects of Maritime Safety's 117 making laws, with our
  faults 10 → 0 (Part numbers spelled otherwise by the feed and the text; an unnumbered Schedule; a Part the
  text doesn't hold). The pattern catalogue regenerated over 1,318 laws found its own gap (examples dropped the
  commencing order, so commenced_by was never checked), fixed under Decision 1; the agent sample came out clean
  first time; golden 27/27, mix test green. Same day, first plan.
decisions:
  - what: Part matching only (Roman = Arabic, letter case), never naming a Part the rows don't hold
    why: naming them moved 55 held catalogue examples and added Parts beside sections in 4 more (frozen expectations)
    result: 3 Parts placed; SI 1997/1510 Pt. 6 classed not in text by Placement from the text's groups; 0 held examples moved
  - what: Carry each stage's commencing order in catalogue examples; bring 308 held expectations to the current reading (Decision 1, Jason)
    why: 295 differed only by commenced_by, which the examples dropped; 13 read better on fuller context (EU Art. N BIS, ranges spanning)
    result: a checked script wrote only those two named kinds (0 others); 1,697 examples pass
  - what: '"for enabling the exercise of power to make regulations" is a purposes qualification, partial (Decision 2, Jason)'
    why: it limits the commencement to a purpose; 6 effects, CJA 2003
    result: one line in Qualification; RULES.md partial-commencement-is-partial extended
metrics:
  placement: { effects: 4786, laws: 117, placed: 3943, schedule_not_parsed: 571, not_in_text: 116, whole_law: 77, not_a_provision: 67, placed_by_markup: 7, row_missing: 3, placed_ancestor: 2, our_faults: 0, our_faults_at_start: 10 }
  catalogue: { laws: 1318, effects: 262918, patterns: 1024, new_accepted: 20, held_updated: 308, examples: 1697, run_minutes: 10 }
  agent: { seed: 41, placement_ok: 50, facts_ok: 50, new_defects: 0, tokens: 98791 }
  checks: { repeatable: true, golden: "27/27", tests: 9862, failures: 0, ohs_unchanged: true }
  cost: { days: 1, plan_changes: 0, agent_tokens: 98791 }
lessons:
  - title: A new family's faults show first in the namer's edges
    detail: OH&S had 0 faults; Maritime's 10 were all naming (Part numerals and case, an unnumbered Schedule). The fix belonged in the feed reader's lookup, not the shared Ref namer, so the markup reader stayed out of scope.
    tag: data
  - title: Measure a naming fix against the whole catalogue before keeping it
    detail: A fallback that named any Part the rows don't hold passed the family check but moved 59 held examples; the catalogue test caught it in 40 s. Narrowing to matching kept every held reading.
    tag: tooling
  - title: The catalogue can miss a field the reader added after it
    detail: commenced_by was added on 2026-10-30 but the example decoder never carried the commencing order, so 295 expectations silently lacked it. The full-context re-run (report "reading differently") showed it; the test alone did not.
    tag: tooling
bugs:
  - pattern: "Two Part rows named 'pt....' and 'pt....#2' (SI 2003/3049 Pt. 3 and Pt. 4): the parse gives the rows no number"
    category: group-row-unnumbered
    module: lat_parser (Ids / Rows)
    affected: 2 rows in 1 law
    fix: "Name Part rows from the Part's number (part-3 → pt.3); found by the feed catalogue (ref: part-N → pt....)"
    step: LAT parser
    status: open
  - pattern: "Catalogue examples dropped each stage's commencing order, so held expectations never checked commenced_by (295 examples)"
    category: catalogue-drops-commencing
    module: change_vocabulary/feed_patterns.ex (decode/1)
    affected: 295 examples
    fix: "decode carries commencing; expectations updated (Decision 1)"
    step: Feed reader
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed_group.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/placement.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/feed_patterns.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
  - backend/test/fixtures/feed_patterns/*.json
  - backend/data/reports/feed-reader/maritime-safety-0.txt, -1.txt, -2.txt, -sample-seed41.json
  - docs/lat-change-pipeline/RULES.md (partial-commencement-is-partial: purposes include powers)
depends_on:
  - 2026-11-04-maritime-safety-sources.md
  - 2026-11-04-maritime-safety-meta.md
enables:
  - "Maritime Safety: Markup reader"
---

# Session: Maritime Safety: Feed reader (CLOSED)

## Problem

Every changes-feed effect of the 117 making laws must land on the provisions it changes, or be unplaced for a named reason, with the feed's facts carried as read. The baseline check fails: 10 effects whose refs the reader can't convert, in two classes new with this family (Part numbers spelled differently by the feed and the text; an unnumbered Schedule).

- **Plan (approved 2026-11-04):** `~/.claude/plans/gleaming-doodling-matsumoto.md`.
- **Aim:** `binds-on-date`, `one-record-per-change`; principle `coverage-from-lgu`.
- **Time box:** one day.
- **Meta session:** `2026-11-04-maritime-safety-meta.md`.
- **Skill:** `feed-reader-check`.

## Todo

- ✅ Session and baseline: 4,786 effects in 117 laws; 3,940 placed; 10 our faults (`backend/data/reports/feed-reader/maritime-safety-0.txt`); parked Feed reader bugs read in as known patterns
- ✅ Part names (TDD): `part-7` finds `part-VII`, `part-10A` finds `part-10a` (3 placed); SI 1997/1510 Pt. 6 not in text (68f61558)
- ✅ Unnumbered Schedule (TDD): "schedule" + `paragraph-N` is one schedule target (6 schedule not parsed); our faults 0, PASS (`-1.txt`); OH&S unchanged
- ✅ Pattern catalogue: 21 new patterns reviewed; Decisions 1 and 2 (a); 20 accepted, 308 held expectations updated by a checked script; 1,697 examples pass; OH&S unchanged (726d2b63)
- ✅ Repeatability: seed 41 twice, sample files identical (`cmp`), counts identical (`reports/feed-reader/maritime-safety-sample-seed41.json`)
- ✅ Golden 27/27; agent check on 50 effects clean first time (98,791 tokens)
- ✅ Pass: `mix test` 9,862 pass; final feed check PASS (`-2.txt`); RULES.md `partial-commencement-is-partial` extended (Decision 2)
- ✅ Close; meta status row

## Pass rule (fixed)

1. `mix lat.feed_check` for the family: our faults 0; every effect placed or unplaced with a reason.
2. `mix lat.feed_patterns` regenerated over every stored feed; each new pattern accepted, fixed or pending; `feed_patterns_test.exs` passes.
3. Seed 41 twice: sample files identical (`cmp`), counts match.
4. `mix lat.vocabulary --golden` 27/27.
5. The agent finds nothing wrong outside the known patterns, on a clean sample.
6. `mix test` 0 failures.

Frozen: `golden.exs` and held expectations in `expected.json`.

## Dependencies

- ✅ Sources closed: 682 needs held or absent, including the 101 feeds
- ✅ `mix lat.feed_check`, `mix lat.feed_patterns`, `mix lat.vocabulary --golden`

## Known patterns for the agent

K1–K10 as in the `feed-reader-check` skill, plus the parked Feed reader bugs (`2026-11-03-parked-bugs.md`):
- a feed range spanning rows inserted later by other laws (SI 2009/1348 reg. 19A–19F);
- an earlier change reaching rows inserted later (OLA 1984 s.1(6A)–(6C); HSWA s.11(4AA));
- the `#made` twin placed only on a range's ends; "substituted for" over a finer insertion; "omitted in earlier amending provision" at provision level; "revoked in part" placed on another law's provision;
- the doubtful HSWA s.48 effect (a feed error, not ours).

## Results

### Our faults 10 → 0 (68f61558)

- **Part numbers.** A new module, `Readers.FeedGroup`, finds a group id that misses the rows' xml ids by its kinds and numbers, with Roman equal to Arabic and letter case ignored. The match is used only when exactly one row group has it.
  - My first version also named groups the rows don't hold ("pt.6"). Across the corpus that moved 55 held catalogue examples from "?" to a Part target, and added a Part beside sections in 4 more. That broke frozen expectations, so I reverted it to matching only, which moves no held example.
- **SI 1997/1510 Pt. 6:** the text has Parts I–V only. `Placement` now classes a group ref as "not in text" when the text's groups (passed by `lat.feed_check` as `held.groups`) don't hold it. Without `groups` (the markup check), nothing changes.
- **SI 1998/2411:** "Sch. Pt. I. para. 1" with refs "schedule" and `paragraph-1` reads `schedule-paragraph-1`, which is sch.para.1, so the outcome is "schedule not parsed". The full name, with its Part, waits for K10.
- **Complexity ratchet:** `Placement.classify` (16) and `Feed.targets` (13) were split into named functions. Tests, and both families' checks, were unchanged across the split.
- **Maritime:** placed 3,940 → 3,943; schedule not parsed 565 → 571; not in text 115 → 116.
- **OH&S:** unchanged (placed 3,549, our faults 0, the same 5 tell-tales).

### Pattern catalogue, first run (10 min)

- 1,318 laws, 262,918 effects, 1,024 patterns (985 at CV-S02b), unclassified 0.
- **21 new patterns**, each reviewed against its examples:
  - 19 read as the rules intend:
    - modifications, exclusions, "ext", "power modified": operation nil;
    - headings at words level;
    - cross-heading refs "?", for the markup to place;
    - annexes and the feed's malformed Schedule ids (`schedule-part-I.`, `schedule-para-section-17`, `part-1-part-1`), all in schedules we don't parse;
    - "brings paras N into force only" on an amendment to an earlier affecting provision.
  - "ref: part-N → pt...." carries a row name the parse gave without a number. The reader is right; that is a LAT parser bug, parked.
  - "for enabling the exercise of power to make regulations" is read as not partial. That is Decision 2.
- **308 held examples read differently from their expectations under each law's full context.** None is from this step's change: with the old contexts the code reads them all as held (the test passed at 68f61558). A script checked every held example:
  - 1,326 read the same;
  - **295 differ only in `feed.commenced_by`.** The catalogue's examples drop each in-force entry's `commencing` order (`FeedPatterns.decode/1` builds the entry without it). So the held expectations have never covered `commenced_by`, which the reader has carried since 2026-10-30. That is Decision 1;
  - **13 read differently on fuller context**:
    - 6 EU "Art. N BIS" land on Article Na, now a held row;
    - 6 ranges now span their middle provisions, e.g. EA 2003 s.105Z18–105Z21, now that the document order is in the example;
    - 1 range of Companies Act 2006 Pts. 1–39 reaches pt.15, the one Part its scoped rows hold.
- **The test against the regenerated fixtures:** 1,625 of 1,703 pass. The 78 failures are those 13, plus 65 new examples awaiting `--accept`.

### Catalogue, after Decisions 1 and 2 (726d2b63)

- `FeedPatterns.decode/1` now carries each stage's `commencing` (round-trip test). `Qualification`'s purposes class now includes "for enabling the exercise of" (new `qualification_test.exs`).
- **Re-run with `--accept`:** 20 new patterns accepted. The power wording now falls in the existing purposes pattern.
- **A checked script** compared each held example's reading with its expectation. It would write only where the two differed by `commenced_by` alone, or for one of the 13 named, and stop on anything else. Result: 1,389 the same, 295 `commenced_by`, 13 named, 0 others. 308 written; a second pass found all 1,697 the same.
- **Change vocabulary tests:** 3,234 pass. The fixture diff holds no effect ids.
- **Both families:** Maritime placed 3,943 and OH&S placed 3,549, our faults 0 in both, so both are unchanged.

### Agent check, seed 41 (98,791 tokens, 2½ min)

- **Placement 50/50 OK, facts 50/50 OK, no NEW defects, clean on the first sample.**
  - 42 placed, 1 whole law, 7 schedule not parsed (K1).
  - The sample is identical before and after the catalogue fixes (`cmp`).
- **The agent's notes, none a new pattern:**
  - **#23, MSA 1995 Sch. 6 Pt. II para. 9A.** The feed nests para. 9A under Part II, but the text has `schedule-6-paragraph-9A` outside it: a K3 structure fault. It has no effect while schedules are unparsed.
  - **#16:** a prospective Schedule addition is not yet in the text (K1).
  - **#32:** the sample output doesn't carry `commenced_by`, so the agent couldn't audit it. Parked as a change to the check tool.
- **Cost:** 98,791 tokens, above the plan's 60–80k estimate.

## Parking list

- Feed reader (check tool): sample-lacks-commenced-by — `lat.feed_check --sample` writes no `commenced_by` per change, so the agent can't audit it; add it before the next family's check

- LAT parser: group-row-unnumbered — SI 2003/3049 Part rows named "pt...." (2 rows)

## Decisions for Jason

### 1. The catalogue's held expectations: carry the commencing order, and accept the 13 fuller readings? — DECIDED (a), Jason 2026-11-04

- **Question.** The catalogue's examples drop the order that commences each stage, so 295 held expectations lack the `commenced_by` claim the reader makes. Separately, 13 examples read better now that their context is fuller. Should both be brought into the held expectations? The plan froze them, so this is yours to decide.
- **Aim:** `binds-on-date`. `commenced_by` names the order that brought a provision in. The catalogue is the check that the reader carries it.
- **Options:**
  - (a) Fix `FeedPatterns.encode/decode` to carry `commencing`. Then rewrite the 308 held expectations to the reader's current reading. A script checks that each one differs only by `commenced_by` (295), or is one of the 13 named above, and that nothing else moves.
  - (b) Leave the expectations as they are. Keep the old contexts for the 13. `commenced_by` stays unchecked by the catalogue.
- **Recommendation:** (a). It closes a gap in the check and changes no reading. Every change is one of two named kinds, shown by the script.

### 2. "for enabling the exercise of power to make regulations": a partial commencement? — DECIDED (a), Jason 2026-11-04

- **Question.** The feed's qualification "for enabling the exercise of power to make regulations" (6 effects, all CJA 2003 s.254 and nearby provisions; none in this family) is read as class "other", so not partial. It limits the commencement to a purpose, as "for specified purposes" does. Should it count as partial?
- **Aim:** `binds-on-date`. A provision commenced only to let regulations be made doesn't yet bind anyone.
- **Options:**
  - (a) Add "for enabling the exercise of" to the purposes class in `Qualification`. That is one line plus a test. The 6 effects become partial.
  - (b) A named known limit, left as it is.
- **Recommendation:** (a). The fix is smaller than the known-limit entry would be, and the reading is plainly a purpose.
