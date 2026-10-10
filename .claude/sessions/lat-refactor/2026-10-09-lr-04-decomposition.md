---
session: 'LR-04: Parser Decomposition'
status: closed
opened: 2026-10-09
closed: 2026-10-10
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  LatParser (1,871 lines) split into a 68-line orchestrator and eight pure modules (Walker, Text, Inline, Ids,
  Refs, Effects, Rows, Xml), plus InForceQualifier out of EffectTerritory and the Gemini LR-07 ChangeFacts items.
  A new full-parse snapshot gate (mix lat.parse_snapshot) shows 0 differences in 1,068 laws; it also exposed two
  pre-existing note-order nondeterminism bugs in CommentaryParser, fixed at source in separate commits.

decisions:
  - what: Eight modules instead of the design's four (Inline split from Text; Rows, Effects, Xml added)
    why: Text alone would be ~530 lines; ids/parallels/disambiguation work on row maps not XML; the LR-03/07 effects glue postdates the design; shared helpers avoid Text/Ids/Refs cycles
    result: Jason agreed; largest modules Text 423, Walker 415, Rows 364
  - what: Zero-diff gate is a full parse snapshot (every row, note and change-fact field), not lat.text_diff
    why: text_diff compares 4 fields against a DB that LR-03/LR-07 have already moved away from
    result: mix lat.parse_snapshot; tamper test 3/3; final 0 differences in 1,068 laws
  - what: One full compare over the whole extraction chain, not one per step
    why: each compare takes 10-15 min of all cores; steps each had red→green unit tests; bisect by step if ever needed
    result: the only differences traced to pre-existing nondeterminism, not the refactor
  - what: Gate compares notes (and their facts) in note-id order
    why: ids are the output ({law}:{code_type}:{seq}); the list order is read by nothing downstream
    result: scoped re-baseline 0 differences in 100 laws
  - what: Behaviour changes routed out (Schs./Pts. qualifier lists, 4 unread qualifier kinds, credo complexity rewrites) → LR-05
    why: LR-04's exit criterion is zero diff
    result: LR-05 todo carries them
  - what: Rejected Gemini's Text split (Blocks / ContentRenderers) and moving law_extent out of Effects
    why: lists/tables/quotes and text_blocks call each other (cycle); the type→extent fallback is the effects layer's rule
    result: boundaries as planned

metrics:
  lat_parser_lines: { before: 1871, after: 68 }
  module_lines: { walker: 415, text: 423, rows: 364, effects: 186, ids: 181, inline: 174, refs: 158, xml: 128, in_force_qualifier: 147 }
  gate: { laws: 1068, final_differences: 0, baseline_minutes: 15, final_compare_minutes: 10 }
  compare_run1: { laws_differing: 14, fields: 6595, all_scoped_multi_fragment: true, row_differences: 0 }
  tests: { suite_passed: 2579, skipped: 2, new_module_tests: 52, qualifier_gallery: 30 }
  qualifier_strings: { territorial_distinct: 89, unread_kinds: 4, unread_occurrences: 19 }
  dialyzer: { changed_module_errors: 0, preexisting_elsewhere: 78 }

lessons:
  - title: Atom-keyed maps iterate in atom-table order, which changes with module load order and concurrency
    detail: "group_by on code_type atoms and a large tuple-keyed map both gave note orders that varied between VM runs (Map.keys(%{zebra: 1, apple: 2}) → [:zebra, :apple]). Four sequential runs in one VM looked deterministic; only the concurrent snapshot runs and pre-created atoms exposed it. Never let map iteration decide an order that becomes ids or output; sort explicitly."
    tag: data
  - title: A zero-diff gate needs a determinism check of the baseline code itself
    detail: "When compare 1 showed differences, running the pre-refactor code in a git worktree gave a third order for the same law — proving nondeterminism, not the refactor. Run the old code twice (ideally under concurrency) before trusting a baseline."
    tag: tooling
  - title: A worktree with a copied _build can silently run new beams — verify the loaded module
    detail: "The worktree's _build was copied from the main tree (already holding LR-04 beams). Checking LatParser.module_info(:compile)[:source] and the function count (198, no Walker) confirmed it ran the old parser. Symlink deps and data/cache by absolute path (the worktree has a tracked data/ dir)."
    tag: tooling
  - title: Full-corpus offline parse is ~10-15 minutes, not hours
    detail: "Early progress counts misled an estimate of 1-2 h; file mtimes showed the baseline took 15 min. Parsing the XML once instead of three times in parse/2 cut the compare to ~10 min."
    tag: tooling
  - title: Gemini 2.5 Pro can hang on a large prompt and Flash truncates from thinking tokens
    detail: "A 22K-token Pro request ran 20+ min with no reply (killed; pkill matched the shell's own command line and killed it too). Flash with maxOutputTokens 8192 spent 6.3K on thinking and truncated; capping thinkingConfig.thinkingBudget at 2048 gave a complete answer. Default to Flash with a thinking cap."
    tag: tooling
  - title: The dialyzer PLT can be in an old format while dialyxir reports it up to date
    detail: "'PLT is up to date' then ':dialyzer.run error: Old PLT file' — move the PLT aside and rebuild."
    tag: tooling

bugs:
  - pattern: "Scoped (multi-fragment) law's note order and ids changed run to run: CommentaryParser.renumber/2 broke ties between fragments' equal note numbers by map order, which follows the VM's atom table"
    category: nondeterminism
    module: CommentaryParser
    affected: 14 laws differed between two runs (6,595 note/fact fields); any multi-fragment scoped law
    fix: "Dedupe in first-occurrence (fragment) order before the stable sort (751916f2)"
    status: fixed
  - pattern: "Parsed note list order varied with module load order: group_by on code_type atoms iterates in atom-table order"
    category: nondeterminism
    module: CommentaryParser
    affected: list order only (ids are per code_type); 34 scoped laws in one run
    fix: "Group code types in name order (b24d6dd6)"
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/lat_parser.ex
  - backend/lib/sertantai_legal/scraper/lat_parser/{walker,text,inline,ids,refs,effects,rows,xml}.ex
  - backend/lib/sertantai_legal/scraper/in_force_qualifier.ex
  - backend/lib/sertantai_legal/scraper/effect_territory.ex
  - backend/lib/sertantai_legal/scraper/change_facts.ex
  - backend/lib/sertantai_legal/scraper/amendment_note.ex
  - backend/lib/sertantai_legal/scraper/commentary_parser.ex
  - backend/lib/mix/tasks/lat.parse_snapshot.ex
  - backend/test/sertantai_legal/scraper/lat_parser/
  - backend/test/sertantai_legal/scraper/in_force_qualifier_test.exs
  - backend/lib/sertantai_legal/scraper/CLAUDE.md
  - backend/data/code-reviews/2026-10-09-lr04-plan-gemini.md
  - backend/data/code-reviews/2026-10-09-lr04-acceptance-gemini.md
  - backend/data/reports/lat-refactor/lr04-snapshot/ (1,068 laws, gitignored)

depends_on:
  - lat-refactor/2026-10-09-lr-02-lat-territory
  - lat-refactor/2026-10-09-lr-03-note-only-changes
  - lat-refactor/2026-10-09-lr-07-change-metadata-from-effects

enables:
  - LR-05 non-territory fixes land in the new modules (plus qualifier gaps, map-order audit)
  - LR-06 wave (expect a one-off "note id renumbered (scoped)" class)
  - mix lat.parse_snapshot as the zero-diff gate for future refactors
---

# Session: LR-04 Parser Decomposition (CLOSED)

## Problem

`lat_parser.ex` is 1,871 lines with 86 private functions: the walk, text rendering, ids, note refs, the effects glue and the post-walk row pipeline sit in one module, and LR-05's fixes would land in it. Split it into a thin orchestrator plus pure modules, each under ~400 lines, with **zero** change in output (exit criterion, meta). Public surface is only `parse/2` and `to_insert_maps/2`, so callers don't move.

## Todo

- ✅ Zero-diff gate: `mix lat.parse_snapshot` — every law parsed offline (`--store only`, with effects) and saved whole (every row field); `--compare` reports any difference. Baseline taken before the first extraction
- ✅ Plan → Gemini (plan review), decisions below
- ✅ Red: unit tests against the new module names (small CLML fixtures), per module — 52 tests in `test/sertantai_legal/scraper/lat_parser/`
- ✅ Extract `LatParser.Xml` — shared element helpers + element-name sets (no cycles)
- ✅ Extract `LatParser.Inline` — inline markup → segments, change markup → `%LatTerritory.Change{}`
- ✅ Extract `LatParser.Ids` — Pnumbers, Numbers, titles, P2 wrapper (before Text: Text's structural text reads the title)
- ✅ Extract `LatParser.Text` — text blocks, lists, tables, signatures, «…» quotes, structural text, trailing content (#174)
- ✅ Extract `LatParser.Refs` — own-level note refs, group refs, counts, ref type lookup
- ✅ Extract `LatParser.Effects` — effect index, row segments, whole-provision changes, excluded_extent, row effect_ids
- ✅ Extract `LatParser.Rows` — post-walk pipeline: versions, positions, fields, repealed markers, status, parallels, disambiguation, `to_insert_maps` (defdelegate)
- ✅ Extract `LatParser.Walker` — walk, `%Ctx{}` struct, row emission (the two identical emitters made one)
- ✅ `LatParser` thin orchestrator: `parse/2` pipeline only (68 lines)
- ✅ Gemini LR-03 item: `InForceQualifier` out of `EffectTerritory`, gallery of 30 real qualifier strings (4 unread kinds → LR-05)
- ✅ Gemini LR-07 items: `ChangeFacts.resolve/5` split (`with_fact/4`, `row_facts/5`), `group_partial?/3` commented, `twin/1` → `AmendmentNote.same_law?/2`
- ✅ Gate found 2 nondeterminism bugs in note order (CommentaryParser) — fixed at source, separate commits
- ✅ Full suite (2,579 / 2 skipped), credo (4 pre-existing complexity items), final full-corpus compare: 0 differences in 1,068 laws; dialyzer clean for every changed module (PLT rebuilt: the April one was in an old format; `parse/2` context and `Walker.Ctx.t()` specs tightened; 78 pre-existing errors elsewhere)
- ✅ Gemini acceptance (accept); scraper CLAUDE.md module map + gate tool documented

## Dependencies

- ✅ LR-02 LatTerritory (territory code already out of the parser)
- ✅ LR-03 effects layer, LR-07 change facts (their code moves here unchanged)
- ✅ Local CLML store complete for the corpus (`--store only` parses offline)

## Plan

### Module map (proposed)

| Module | Holds | ~lines |
|---|---|---|
| `LatParser` | `parse/2` pipeline, moduledoc, `to_insert_maps` delegate | ~100 |
| `LatParser.Walker` | `walk_children` / `walk_element` / `walk_own`, alt versions, `%Ctx{}`, row emission | ~330 |
| `LatParser.Text` | `text_blocks`, `join_blocks`, lists, tables, signee, quoted blocks, structural / leaf text, `with_trailing`, `open_lead_in?` | ~330 |
| `LatParser.Inline` | `extract_inline_text`, `render_inline` (substitution pairs), `change` / `pair_change`, `block_change` | ~150 |
| `LatParser.Ids` | Pnumber / Number parsing, titles, `p2_is_wrapper?`, first P1 number | ~150 |
| `LatParser.Refs` | `collect_commentary_refs`, `own_refs`, `placement_refs`, ref type lookup | ~120 |
| `LatParser.Effects` | effect index + orphans, `row_segments`, whole-provision changes, `excluded_extent`, `row_effect_ids`, law extent | ~150 |
| `LatParser.Rows` | drop repeated versions, positions, citations / sort keys, repealed markers, status, parallels, disambiguation, `to_insert_maps` | ~330 |
| `LatParser.Xml` | `element_name`, `local_name`, `blank_to_nil`, `xml_id`, `element_extent`, `change_id`, element-name sets | ~80 |

Dependency order (no cycles): Xml ← Inline ← Text ← {Ids, Refs, Effects} ← Walker ← LatParser; Rows depends only on Xml-free data (row maps).

### Departures from the design table (`docs/LAT-PARSER-REFACTOR-DESIGN.md` §4)

- **Inline split from Text**: Text alone would be ~530 lines; inline rendering (change markup → segments) is a feature of its own and is what LatTerritory consumes.
- **Rows** for the post-walk pipeline: the design put section ids / parallels / disambiguation in Ids, but those work on row maps, not XML — a different input and a different test style.
- **Effects** for the LR-03/LR-07 glue: written after the design; it reads XML + ctx and hands segments to `LatTerritory`.
- **Xml**: shared helpers every module needs; avoids Text ↔ Ids ↔ Refs cycles.

### Rules for every step

- Red tests against the new module first (CLAUDE.md TDD); functions moved verbatim, made public with `@spec` + `@doc`; private callers rewired.
- `mix lat.parse_snapshot --compare` = 0 differences before the commit (text diff vs DB is not a zero-diff gate: it compares 4 fields against a DB that LR-03/LR-07 have already moved away from).
- Row maps stay maps (shape is the persistence / test contract); only the walk context becomes a struct.
- No behaviour change rides along.

### Decisions (Jason, 2026-10-09: agreed all three)

1. The four departures above (Inline, Rows, Effects, Xml) stand.
2. The LR-03 Gemini note "qualifier provision lists cover only s./ss./reg./regs. (not Schs., Pts.)" is a behaviour change → LR-05.
3. `LatTerritory` (627 lines) stays out of LR-04's scope.

### Gemini plan review (2.5 Flash; `backend/data/code-reviews/2026-10-09-lr04-plan-gemini.md`)

Truncated mid point 4 (thinking used the budget); not retried. A 2.5 Pro attempt hung and was killed. Points:

- **Taken:** order (Xml → … → Rows before Walker) confirmed; the gate is "sufficient for zero output difference". Its blind spots are performance and error paths: run times are compared (below); error paths are unchanged code moved verbatim.
- **Rejected: split Text into Blocks + ContentRenderers.** Lists, tables and quoted blocks call `text_blocks/2` and `text_blocks/2` calls them, so the split would create a cycle. Text is under the line limit.
- **Rejected: move `law_extent` out of Effects.** The document's RestrictExtent read is in `Xml.root_extent/1`; the type → extent fallback is the effects layer's rule (LR-03), so it stays with its only user.

### Zero-diff gate

`mix lat.parse_snapshot` (new; `backend/lib/mix/tasks/lat.parse_snapshot.ex`): `fetch_changes` + `ChangeFacts.resolve` per law (`--store only`, concurrent), saved as ETF; `--compare` diffs every row / note / fact field and every resolved row. Tamper test: 3 planted differences → 3 reported. Baseline: `backend/data/reports/lat-refactor/lr04-snapshot/` (1,068 laws).

Gate runs:

- **Per-step compare: not run.** A full compare takes ~15 min of all 6 cores, and the steps were made in one sitting, so one compare covered the whole chain (bisect by step if it ever disagrees). Each step did have its red → green unit tests and the 3 parser test files (271 tests).
- **Compare 1** (all extractions, old-code baseline): 0 differences in 1,054 laws. 6,595 differences in 14, all multi-fragment scoped laws, all note order (and the facts that follow it), no row anywhere. The pre-LR-04 code in a worktree gave a third order for the same law, so it wasn't LR-04: note order followed the VM's atom table (bugs above).
- **Scoped laws re-baselined** from pre-LR-04 code + fix 1 (worktree at 751916f2, checked to run the old 198-function parser) → compare: 34 laws differed in list order only (fix 2's bug) → the gate compares notes and facts in note-id order (the ids are the output; the list order is not) → **0 differences in 100 scoped laws**.
- **Final compare** of the code as committed (LR-04 + both fixes + credo tidy): **0 differences in 1,068 laws**. ~10 min against the baseline's ~15 (parse/2 parses the XML once, not three times).

### Module sizes

`lat_parser.ex` 1,871 → 68. Walker 415, Text 423 (each just over ~400: `walk_own`'s element dispatch and `text_blocks`'s cond are one function each), Rows 364, Effects 186, Ids 181, Inline 174, Refs 158, Xml 128. `parse/2` now parses the XML once (it read the root extent from two more full parses). `walk_own`'s four Part / EUTitle / Chapter / EUChapter branches are two; the heading row computes its exclusion once.

### Found for later

- **Qualifiers unread** (gallery, `InForceQualifier`): "for E. insofar as…" (5), "except for W." (8), "in so far as not already in force for N.I." (2), "…except in relation to W" with no full stop (4) → LR-05.
- **Credo complexity** (pre-existing, moved verbatim): `Walker.walk_own/2` 21, `Text.text_blocks/2` 22, `EffectTerritory.claim` 15, `Effects.with_whole_provision/2` nesting 4. Not split here (a rewrite of logic, not a move).
- **LR-06 wave**: after the note-order fixes, a re-parse of a multi-fragment scoped law can give its notes different ids from the stored ones (once, then stable). Expect a "note id renumbered (scoped)" class.

### Gemini acceptance (2.5 Flash; `backend/data/code-reviews/2026-10-09-lr04-acceptance-gemini.md`)

**Accept for commit.** Its caveats:

- **Per-step compares not run** (bisecting would have been harder): recorded above. In the end, every difference traced to pre-existing nondeterminism.
- **Note list order not compared**: within scope. Ids are the output, and nothing downstream reads the list order (persistence and `LatStatus.Apply` go by id).
- **Map-order risk elsewhere**: taken. LR-05 gets an audit of the parse path for order-dependent use of map / `group_by` iteration, especially over atom keys.
