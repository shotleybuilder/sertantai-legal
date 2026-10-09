# LAT Parser Refactor — Design (territory first)

Status: draft for review (2026-10-09). Context: LAT hand-off to fractalaw (`.claude/sessions/lat-handoff/`), QA spec `docs/LAT-QA-SAMPLE-SPEC.md`.

## Why

`LatParser` turns legislation.gov.uk CLML XML into LAT rows (one per provision): text, title, ids, extent, `excluded_extent`, note refs, status markers. Four agent QA runs (100 random rows each, checked against the stored XML) show most features converging and one not:

| Feature | Defects per run (QA1 → QA3b) | State |
|---|---|---|
| Titles | 0 → 1 → 0 → 0 | done |
| «…» amending text | 3 → 0 → 0 → 0 | done |
| Ids / versions | 6 → 3 → 0 → 0 | done (known minors) |
| Text | 2 → 3 → 1 → 0 | sound; one heuristic (#174 trailing content) |
| Note placement / metadata | 29 → 21 → 6 → 3 | converged (last 3 already fixed) |
| Status | 3 → 3 → 1 → 0 | follows territory |
| **Territory** (brackets, `excluded_extent`) | **3 → 8 → 3 → 5** | **not converging** |

Every territory fix has patched one path; each QA run finds the next one. The cause is structural.

## Current state (territory)

The spec's rule is: a change's territory is its `Extent` attribute, else the territory its commentary note names ("repealed (S.)", "(1.4.2015 for S.)"). The code applies it in one of five places:

| Path | Code (lat_parser.ex) | Attribute | Note |
|---|---|---|---|
| Row extent | `element_extent` (RestrictExtent), versions, root | yes | n/a |
| Retained repeal words (`Repeal RetainText`) | `retained_territory` | yes | yes |
| Inserted words (`Addition`/`Substitution`) | `territorial_insertion?`, `inserted_label` | yes | **no** |
| Whole-row insertion → `excluded_extent` | `inserted_excluded` | yes | **no** (≤1,500 rows) |
| Substitution pairs (`SubstitutionRef`) | `pair_territory` | yes | **no** |
| Change only in a note, no element ("Ss. 1-24 repealed (S.)") | — | — | **not handled** (~260 rows) |
| Row mixing retained + inserted segments | `excluded_extent` → nil | — | wrong (35 rows) |

Mechanism: rendering embeds private-use placeholder characters (pair open/new/old/close, words open/mid/close) into the row text string, because the row's extent isn't known while its inline markup is rendered; `with_territories/4` later regex-parses them and emits "[S: new] [E+W: old]", "[E+W: words]", or plain words. Leaks, nesting and edge-whitespace bugs came from this round trip. `excluded_extent` is computed separately by `retained_segments` walking the same elements a second time with its own rules.

Code health: `lat_parser.ex` is 1,828 lines / 136 functions (project rule: split above ~300). It holds the walker, text rendering, territory, note refs, ids, versions, tables/lists/signatures and status markers. Territory logic is ~20 functions plus `Territory` (pure, 112 lines: note territory parsing and set operations). 192 parser tests, all through `LatParser.parse/2`.

## Proposed design

### 1. One territory rule, one module: `LatTerritory`

Pure. Every change is classified once into a `%Change{}`:

```
%Change{kind: :repeal_retained | :insert | :substitute_pair | :note_only_repeal | :note_only_insert,
        territory: code | nil, source: :attribute | :note | :none, ref: commentary_id, scope: :words | :row}
```

`territory = attribute || note_territory(ref) || nil` — the same function for every kind. Note territory comes from `Territory.from_note/1` (already pure and tested).

### 2. Rendering as data, not placeholder strings

Inline rendering returns a segment list instead of a string with placeholders:

```
[{:text, "the Council under"}, {:change, %Change{}, new: [...segments], old: [...segments]}, ...]
```

Once the row's extent is known, one function `LatTerritory.render(segments, row_extent)` returns `{text, excluded_extent}`:
- words: bracket with the territory still live / inserted, plain when it covers or misses the row extent;
- pairs: "[T: new] [rest: old]", only new / only old at the extremes;
- whole-row (all own segments are changes): plain text + `excluded_extent` (repeal → its territories; insertion → extent minus its territories; mixed repeal+insertion → defined rule, see Q3);
- nested changes: inner rendered plain inside an outer bracket (current behaviour), defined in one place.

This removes the placeholder alphabet, `plain_text/1`, `merge_brackets` re-parsing, and the second walk in `retained_segments`.

### 3. Note-only whole-provision changes

A note cited at a row's own level whose effect is a whole-provision repeal/insertion ("S. 18 repealed (S.)", "Pt. 2B inserted (W.)") and that names a territory gives the row (and its descendants) `excluded_extent`, unless an element-level change already covers it. Effect from `AmendmentNote` (already parses effect). Decided at parse time: the row's own refs (`own_refs`) and the ref → note lookup are both available then.

### 4. Parser decomposition (behaviour-preserving, after territory)

`LatParser` becomes a thin orchestrator (`parse/2` pipeline) delegating to:

| Module | Holds |
|---|---|
| `LatParser.Walker` | recursive walk, ctx, row emission, trailing content (#174) |
| `LatParser.Text` | text blocks, inline rendering → segments, lists, tables, signatures, «…» quotes |
| `LatParser.Ids` | numbers, titles, section ids, versions, parallels, disambiguation |
| `LatParser.Refs` | own-level note refs, counts |
| `LatTerritory` | as above |

Per CLAUDE.md: tests first against the new module names (red), extract (green), `defdelegate` for callers.

### 5. Verification

- A territory fixture suite: one CLML fixture per row of the "Current state" table plus nesting, mixed and version cases, each asserting `{text, excluded_extent}`.
- Offline whole-corpus diff (`mix lat.text_diff --all --store only`) before/after each step: extraction steps must give **zero** row changes; the territory rewrite's changes are reviewed by class.
- Then one re-parse wave (dry run → Jason → apply, enrichment carried by `LatMerge`) and a fresh QA run.

## Order

1. `LatTerritory` + fixture suite (red) → segments rendering (green) → corpus diff classified.
2. Note-only changes.
3. Extract Text / Ids / Refs / Walker (zero-diff each).
4. Non-territory fixes from QA3 (independent): #174 limit, `changed_by` from Citation URI, EU `changed_by`, minors.
5. Wave + QA → fractalaw contract.

## Open questions

1. **Attribute vs note conflict.** 1996/1527 regs have `Extent="S"` but the note also disapplies them in Wales from 1.4.2018. Union both, prefer the attribute, or prefer the note?
2. **"except in relation to ss. 13-15"** on a Part repeal: the parser treats retained text with no territory as "saved for some purposes" → `repealed_saved`. Should an except-clause naming the row's own section mean "not repealed for this row" (in_force)?
3. **Mixed whole-row**: a row whose own text is retained-repealed for S and has an inner insertion for E+W. Plain + `excluded_extent` = S, or something else?
4. **Note-only scope**: how strict should "whole-provision" matching be (note's provision list must cover the row id? effect verbs?) to avoid territory from a note about a different provision?
5. **Order**: territory rewrite before or after the mechanical decomposition? (Proposed: before — it removes code the decomposition would otherwise move.)
6. **Null `extent_code`** where the stored document has no extent markup (274 of 1,068 laws have some): fill from the register's law extent, or leave nil?
