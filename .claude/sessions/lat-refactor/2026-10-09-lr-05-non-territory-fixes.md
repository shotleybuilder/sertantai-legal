---
session: 'LR-05: Non-territory QA3 Fixes'
status: active
opened: 2026-10-09
resumed: 2026-10-10
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-05 Non-territory QA3 Fixes (ACTIVE)

## Problem

The QA3 / QA3b defects that aren't territory (LH-08), plus residue routed here from LR-03, LR-04 and LR-07. They now land in the decomposed parser modules (LR-04). Each fix is test-first and gets a classified corpus diff (expected classes, 0 unexpected) before the LR-06 wave. Example: 1993/11 s.23(1)(c) — the parent's closing words stay on the parent when the open child has its own sub-provisions (#174 limit).

## Todo

- ✅ Re-measure (LR-04 snapshot = current parse): 2 items dropped, 2 merged into one Citation fix (below)
- ✅ #174 limit: an open child with sub-provisions of its own, under a parent whose lead-in is open, no longer takes the closing words (`Text.takes_trailing?/2`) — 114 laws, 195 parents gain / 197 children lose, 0 unexpected
- ✅ changed_by fallback from the note's `<Citation URI=…/id/{type}/{year}/{number}>` after "by": `CommentaryParser.citation_law/2` → `amendment_annotations.citation_law` (Ash migration 20261010122611, dev + test) → `ChangeFacts` prefers it over the text; `LatStatus.Apply` reads it
- ✅ Minors (text): AppendText after the closing » (Jason 2026-10-10; was "..»", 1,367 rows); zero-width characters stripped from row text and titles (U+200B/C/D, U+2060, U+FEFF; 149 rows + 3 titles); InlineAmendment quotes hold words, not line breaks ("“ general ”", ≤2,683 rows); table-cell provisions keep their numbers; double spaces: none left (dropped)
- ✅ Minors (ids): a spaced hyphen splits Number from heading ("PART 2B - WALES" → `pt.2B`, title WALES); a Number holding only a heading takes its number from the id (1965/57 "Nuclear site licences" → `pt.2`; 1,139 rows had headings as `part`)
- ✅ Qualifiers (`InForceQualifier`): the 4 unread kinds read ("insofar", "except for W.", the phrase before the territory, a territory without its full stop but never "Wales"); gallery 35. ❌ Schs./Pts. provision lists: only 1 real territorial qualifier names a schedule ("for E. so far as it relates to the omission of Sch. 1 para. 5", another phrasing) — nothing to read
- ✅ Territory residue: 1990/43 s.153(1)(z7)(ii) fixed (a lone ";" inside a change isn't the row's words; only a dot run is) → excluded E+W+NI like its parent; 2011/988 reg.13(1) fixed (a dots-only row inside a change renders plain → repealed; 4 such rows in the corpus); 2010/2214 reg.2(6) explained, no change (outer Addition Extent=E but its effect's application is E+W, and the claim order puts application first; inner substitutions W/E only bracket; `#n` = two (c)s with one extent)
- ✅ Savings-silent residue: `LatTerritoryCheck` `:note_territory_hint` (report only; `lat.text_diff` now passes notes) — flags 2010/404 reg.14 (4 rows: "excluded E+W on effect evidence; the note says E"); 2020/7 s.8's note ("expires in part") names no territory, so no hint is possible
- ✅ uksi 1979/791 (58 rows "removed" in every diff): a PDF-only law. legislation.gov.uk serves metadata only, and its LAT came from a PDF backlog transcript. `LatStagedParser.with_backlog/3` + `PdfBacklog.Batch.clml/2` → the parse gives the 58 rows again (bug: the wave would have emptied it)
- ✅ Map-order audit of the parse path: clean. Maps are iterated only to build lookups or MapSets; `EffectIndex.parallel/2`'s `Map.values` is string-keyed (deterministic) and feeds a union; the atom-keyed `code_type` groupings were LR-04's two fixes
- ✅ Classified corpus diff (`lat.parse_snapshot --compare` against the LR-04 baseline, `backend/data/reports/lat-refactor/lr05-compare-final.csv`, classifier `lr05_classify.py`): 103,615 fields in 880 laws, every class explained, 0 unexpected (below)
- ✅ Gemini acceptance (accept; `backend/data/code-reviews/2026-10-10-lr05-acceptance-gemini.md`); full suite 2,606 / 2 skipped; credo: my two findings fixed (the rest pre-existing); dialyzer clean for changed modules

## Dependencies

- ✅ LR-04 decomposition (fixes land in the new modules; `lat.parse_snapshot` baseline in `backend/data/reports/lat-refactor/lr04-snapshot/`)
- ✅ LR-07 change facts from effects (re-measure the changed_by items against it)

## Re-measure (2026-10-10, from the LR-04 snapshot: 90,674 notes, 65,648 facts from effects / 25,026 from note text)

| QA3 item | Now | Action |
|---|---|---|
| changed_by wsi vs uksi (2013/755, was 883) | effects give `UK_wsi_2013_755` for 948 notes; 15 note-fallback notes still say uksi (both names in the register, so `resolve_law/2` keeps uksi) | fix from the note's Citation URI (`/id/wsi/2013/755`, `Class="WelshStatutoryInstrument"`) |
| EU "by Regulation (EC/EU) …" (was 162) | 146 notes from text with no changed_by; 21 from effects | same fix: EU notes carry `<Citation URI=".../id/eur/2019/1243">` / `/id/eudr/2007/30` |
| "except in relation to ss. 13-15" (1984/22) | ss.13–15 and their subsections `in_force` (markup) | dropped: fixed by LR-03 |
| Substitution edges (1968/73 s.102(4), 1990/8 s.150(1)(b)) | `[E+W: …] purposes [S: …]`; `[W: …24ZA] [E: or paragraph 24]` | dropped: rendered right since LR-02/03. 1990/8 shows a live U+200D (minors) |

21,085 row changed_by values aren't register names. That's expected: they are amending laws legal doesn't hold.

## #174 limit (`Text.takes_trailing?/2`, `lead_in_before_children_open?/1`)

Example: 1993/11 s.23(1), "Any person who— (a) … (b) … (c) … to— (i) (ii) shall be guilty". The closing words finish the parent's sentence: the parent's lead-in is open, and (c)'s "to—" is completed by its own (i) and (ii). Where the parent is not open, the child keeps its trailing content: CAA 1982 s.44(6), SI 2010/93 reg.7(5) and PUWER reg.2(1) are unchanged (the existing tests still pass).

Corpus (`lr05-compare-174.csv`, against the LR-04 snapshot): 392 row texts in 114 laws, 195 parents gain and 197 children lose. Every shrinking child's new text is a prefix of its old one, and 193 parents gain exactly the old suffix. The other two are right too:
- **1990/31 s.17(1):** further definitions sitting between the parent's children.
- **1986/1078 reg.47(2):** a new sentence after a completed child.

Note effects (24 rows) and change facts (11) follow the words they sit in. Unexpected: 0.

## Text minors

- **AppendText** (Jason 2026-10-10: after »): `LatSegments.append_after_quote/2` replaces `append_in_quote/2`. The amending sentence's punctuation isn't part of the quoted block: «…section.». (was "..»"), «…and”». (2019/17 s.55(3), test updated).
- **Zero-width** `LatSegments.strip_invisible/1` (in `Inline` text nodes and `Ids` titles); a no-break space is visible spacing and stays (643 rows).
- **InlineAmendment quotes**: `<InlineAmendment>“⏎ general ⏎”</InlineAmendment>` collapsed to "“ general ”"; the source's whitespace just inside its own quote marks is dropped.
- **Table cells**: a `:cell` text mode, which is `:leaf` with P1–P4 numbered like list items (2020/1265 table.111 "Installation in— (a) England; (b) …").

## changed_by from the note's Citation (`CommentaryParser.citation_law/2`)

The law named in the URI (`/id/{type}/{year}/{number}`) of the note's first `<Citation>` after " by ". It is persisted on `amendment_annotations.citation_law` (Ash migration `20261010122611_lr05_citation_law`, dev + test), so `LatStatus.Apply` reads it. `ChangeFacts` prefers it over the text's reading, with two guards found in the corpus diff:

- **It must be the first instrument after "by".** An instrument the markup doesn't cite, sitting before the first Citation ("by virtue of S.I. 2019/530 … (as inserted by <Citation>2020/1016</Citation>)", nisi 2003/419), leaves the text to decide.
- **A uksi URI never turns the text's Welsh SI into a uksi.** "(Wales) Regulations 2024 (S.I. 2024/1229)" carries a uksi URI generated from "S.I."; a wsi URI is specific knowledge, a uksi one may only echo the text.

What it gives:
- EU Regulations and Directives that the text couldn't read (`UK_eur_2019_1243`).
- Welsh SIs cited as plain S.I. (`UK_wsi_2013_755`).
- Northern Ireland Acts read as ukpga (`UK_nia_2008_5`).
- "2001 asp 8" before "S.S.I. 2002/162".

## Qualifiers (`InForceQualifier`)

The four kinds that were read as nothing are now read, with the gallery at 35 strings:
- "insofar as not already in force";
- "except for W.";
- "in so far as not already in force for N.I." (the phrase before the territory);
- "…except in relation to W" (no full stop; never "Wales").

Effect: 2021/30, 29 rows `in_force` → `in_force_partial`. Correct: "in so far as not already in force" used to count as complete everywhere, but it completes only NI, and the E+W rows are in force there "for specified purposes" only.

The Schs./Pts. provision lists are dropped: the corpus has one territorial qualifier naming a schedule, in a phrasing ("so far as it relates to the omission of Sch. 1 para. 5") the list reader doesn't take.

## Territory residue

- **Punctuation inside a change** (`LatTerritory` pieces): only a dot run counts, as the repeal marker; a lone ";" doesn't.
  - 1990/43 s.153(1)(z7)(ii) and (z9) now match their parent (excluded E+W+NI, plain).
  - s.153(1)(aaa) is live nowhere: an E+W addition inside an E+W repeal, as in s.6(6A)(c). It is now excluded E+W+S+NI → `repealed_saved`.
- **Dots-only rows** (`LatTerritory.render/3`): a row that is only a dot run renders plain, whatever change holds it, and so reads as repealed. Four rows: 2005/894 reg.65(b), 2011/988 reg.13(1) ("omitted (1.10.2020)"), 2014/1638 reg.62, 2015/595 reg.33(7)(c).
- **2010/2214 reg.2(6): no change.** The outer `<Addition Extent="E">` joins an effect whose territorial application is E+W, and the agreed claim order puts application before markup. The inner substitutions' effects (W or E) only bracket. The `#n` ids come from two (c)s with the same extent. This would reopen only if markup should beat application.
- **Savings-silent** (LR-07 bug): `:note_territory_hint` reports it, but it stays a report and the bug stays open. The data has no territory, and notes are never the source.

## Map-order audit

Clean. The parse path iterates maps only to build lookups or MapSets. The string-keyed `Map.values` in `EffectIndex.parallel/2` is deterministic and feeds a union.

## Classified diff (final; `lr05-classes.txt`)

The compare ran on the code as committed, against the LR-04 snapshot, so it shows LR-05's changes only. `lat.text_diff` / `lat.change_diff` against the DB would add LR-03/LR-07's not-yet-written changes on top; those are the LR-06 wave's dry run.

| Class | Fields | Laws |
|---|---|---|
| notes: `citation_law` (new field) | 90,674 | 767 |
| ids: Number heading split (2010/2214 "PART 2B - WALES", 1965/57 headings, nisr 2016/366 "SUB-PART B: …" → `ch.8`); section_id and its keyed fields | 4,175 + 94 + 26 | 3 |
| text: AppendText after » | 3,363 (+23 with quote spaces) | 347 |
| text: InlineAmendment quote spaces | 2,200 | 173 |
| row / note changed_by filled from the Citation (EU, …) | 861 rows / 256 notes | 45 / 66 |
| row / note changed_by changed by the Citation (ukpga→nia, ssi→asp, uksi→wsi, local Acts) | 160 / 159 | 17 / 35 |
| #174: closing words to the open parent (+ effects that follow: 24 + 24 + 2, dates 5 + 1) | 416 | 120 |
| text: zero-width stripped (+3 titles) | 137 | 15 |
| 1979/791 parsed from its transcript (0 → 58 rows) | 59 | 1 |
| status: 2021/30 in_force → in_force_partial (newly read qualifier) | 29 | 1 |
| table-cell provisions numbered | 17 | 9 |
| compound (AppendText + bare punctuation unwrapped, quote spaces on both sides, punctuation rule, cell numbering) | 18 | 6 |
| dots-only rows unbracketed → repealed / repealed_saved | 4 + 4 | 4 |
| punctuation rule: excluded / status (1990/43 (z7)(ii), (z9), (aaa)) | 2 + 1 + 1 | 1 |

### Gemini acceptance (2.5 Flash): accept

No rule challenged. Taken: **downstream impact.** The `section_id` changes (2010/2214 `pt.2B`, 1965/57 `pt.1`–`pt.N`, nisr 2016/366 `ch.8`/`ch.9`) and changed `changed_by` values reach fractalaw. They go to the LR-06 dry run as named classes, so fractalaw is told what is a rename and what is a correction. Its other points (cases outside the corpus, performance, interactions with later changes) are general: the snapshot gate runs again on every change.
