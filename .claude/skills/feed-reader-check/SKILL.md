---
name: Feed Reader Check
description: The change vocabulary's feed-reader acceptance check (CV-S02) for one family of laws — the prerequisites gate, the placement count, repeatability, golden, and a Claude agent checking a random sample of 50 effects against the feed and the law text. Use for every new family; only defects with no known pattern go to Jason.
---

# Feed Reader Check (CV-S02, per family)

## Purpose

Prove the feed reader (`ChangeVocabulary.Readers.Feed`) reads one family's legislation.gov.uk changes feed faithfully:
- every effect is accounted for;
- its provisions and facts are carried as the feed gives them.

The reader carries what the feed says; what it means for a label is the label fold's job (CV-S09).

**When to use:** for each family going through the change-vocabulary workflow (CV-00, "Families after OH&S"), after CV-S01 Sources passes for that family.

## Steps

All steps are read-only, except that step 0 writes the catalogue fixtures. Ask Jason before running them, per the standing rule, and say how long each takes.

0. **Pattern catalogue (CV-S02b).** `mix lat.feed_patterns` (~8 min, every stored feed; writes only `backend/test/fixtures/feed_patterns/`) prints:
   - the new patterns (no status yet);
   - the examples that read differently from expected;
   - `unclassified` (must be 0).

   Take each new pattern's reading to Jason as a measured pattern:
   - accept it: `mix lat.feed_patterns --accept` records the reader's current output for new patterns and never changes a held expectation; Jason reviews the diff;
   - fix the reader: rerun until the tests pass;
   - or mark it `pending: <why>` in `expected.json`, its examples holding the correct outcome.

   Pass: `mix test test/sertantai_legal/scraper/change_vocabulary/feed_patterns_test.exs` passes (pending excluded). The review list format is in `backend/data/reports/feed-patterns/`.
1. **Sources held (the gate).** `mix lat.feed_check --family "F"` fails if a family law with LAT rows lacks its stored feed or law text. Fix that with `mix lat.sources --family "F" --fetch` (a fetch: ask first). It also prints how many family laws hold no LAT rows and are out of scope.
2. **Placement.** The same run prints each outcome's count and `our faults`, which must be 0.
3. **Repeatability.** Run it twice with the same seed and a sample:
   ```bash
   S=<scratchpad>
   mix lat.feed_check --family "F" --all --sample $S/a.json --n 50 --seed N
   mix lat.feed_check --family "F" --all --sample $S/b.json --n 50 --seed N
   cmp $S/a.json $S/b.json   # identical
   ```
   Then diff the two outputs: the counts must match. Use a seed not used before for this family; record it.
4. **Golden** (where the family has golden provisions): `mix lat.vocabulary --golden` (~4½ min) must stay all-pass.
5. **Agent check.** Launch a general-purpose agent with the prompt below, on `$S/a.json`.
6. **Tell-tales.** The feed check prints finer forms the feed names but we don't hold, by kind:
   - `naming`: a faulty row name;
   - `no_ids`: the text gives items no ids;
   - `not_found`: a candidate only.

   A new pattern is raised against the parser as a measured pattern (memory: parser tell-tales) and fixed in a sub-session straight after the step.

**Pass:** sources held; our faults 0; repeatable; golden all-pass; the agent finds no WRONG outside the known patterns. Record each result in the family's step session. Only NEW defects go to Jason, one at a time, explained with the feed's own record and the applied text.

## Agent prompt

Fill in FILE and the family, and add any known patterns found since.

```
You are checking the feed reader of a legal-data service (CV-S02 acceptance check, family F).
READ-ONLY: do not edit any file, do not fetch from the internet, do not write to the database,
do not run mix tasks. You may read files, run read-only psql SELECTs, and decompress local
stored XML. Use /usr/bin/python3 for parsing (not grep with long context patterns).

Input: FILE — 50 randomly sampled legislation.gov.uk changes-feed effects. Each item: `feed`
(type, affected_provisions text, affected_refs, affecting, affecting_provisions, in_force entries
with date/qualification/prospective, effect_extent, territorial_application, savings) and `reader`
(targets, outcome, and `changes`: key, target, operation, level, date_first, date, partial,
effect_extent, in_force_for, savings).

Stored data:
- Feed pages: backend/data/cache/clml/changes/affected/{type}/{year}/{number}/data.feed.page-N.gz
  (raw <ukm:Effect> records; `FoundRef` is legislation.gov.uk's nearest-found provision, NOT a ref).
- Law text: backend/data/cache/clml/{type}/{year}/{number}/body/data.xml.gz (UK_uksi_2008_1597 → uksi/2008/1597).
- Rows: PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -Atc
  "select section_id, source_xml_id from legal_articles where law_name='LAW' and section_id like 'LAW:reg.5%'"

Reader rules (intended behaviour):
- Targets are row refs: s.N(x), reg.N(x), art.Article N(x) (EU), sch.N.para.M, pt./ch. for
  Parts/Titles/Chapters, annex.X. One path linked in pieces ("schedule-1" + "schedule-1-paragraph-2",
  "title-V" + "title-V-chapter-1") is ONE target, the deepest. Sibling refs stay separate. Ranges
  cover provisions between the ends at the ends' depth.
- EU law with one article ref: the feed's words are read further ("para. 6 Point (b)", ".2 L2",
  "(7)") down to the deepest row held; else the article; a finer form not held is flagged.
- Outcomes: placed; placed_versions (territorial versions s.23[E+W]…); placed_ancestor;
  placed_by_markup (the ref isn't in the text but the effect id is in CHANGE MARKUP — a ChangeId —
  never the metadata's UnappliedEffects or a note reference); whole_law; unplaced:
  schedule_not_parsed (schedules and EU annexes unparsed, a v0.1 limit), not_a_provision,
  ref_ambiguous, not_in_text (neither ref nor change markup in the current text, including
  effects legislation.gov.uk hasn't applied), refs_not_converted (reader fault), row_missing.
- Operation: inserted/added/addition/completion → inserted; substituted/replacement/replaced/subst
  (+ misspellings) → substituted; repealed/revoked/omitted/deleted/deletion/rev → repealed;
  "in part"/"in pt"/partial repeal → repealed_in_part; renumbered; coming into force → commenced;
  expires/ceases to have effect, removed, left out, lapsed → repealed; coming into operation →
  commenced; becomes/moved → renumbered; restored/revived → inserted;
  applied/modified/excluded/extended/restricted…, "am"/"amended", "amendment to earlier
  affecting provision" → nil by design. A verb describing another law is no operation
  ("(as inserted)", "(as substituted)" are dropped; "repeal of affecting provision", savings,
  transitional provisions, appointed days → nil).
- Level words when the type begins words/word/sum/figure/entry/comma/semicolon/full stop/formula/
  number/label/definition(s), or concerns a heading; else provision.
- Dates: the in-force date; a commencement not yet dated → one change, no date, prospective true.
  A stage is partial only when its qualification limits scope (purposes, a territory named or
  excepted, a dated scope, certain provisions); a time of day, "in accordance with",
  "retrospective" or other words limit nothing. Staged: a commencement → one change per stage
  keyed id@date; a whole insertion → change from the first stage (date_first, partial) plus a
  commenced change per later stage; a whole removal → repealed_in_part at partial stages,
  repealed at the full stage; any other text change → one change from the first stage
  (date_first, partial). One stage with a qualification carries the same facts, a partial whole
  removal being repealed_in_part.
- A qualification "Other"/"other" is replaced by its OtherQualification text.
- Commencements carry effect_extent and savings. A qualified stage carries in_force_for = the
  territory the qualification names ("for E.W.S." → "E+W+S"), in_force_except = the one it
  excepts ("except in relation to W." → "W"), and qualification = its classes, all as read, not
  applied.
- Other facts: by = affecting law; effect_extent ("E+W+S+N.I." = "E+W+S+NI"; the placeholder
  "S+A+M+E…" is nil); territory from territorial_application; savings.

Known patterns (label a finding with one if it fits; otherwise NEW):
K1 schedules/annexes not parsed (v0.1 limit); K2 #182 non-breaking space in EU row names
(fixed in CV-S02a; the reader still tolerates it); K3 #183 legislation.gov.uk structure faults
(ids contradicting nesting: sensed only, rows named by nesting; a skipped level: adopted into the
sibling before it when it continues that sibling's numbering — s.28(3)(f) — else left in place);
K4 #184 numbered list items with no id directly under a provision are rows since CV-S02a
(art.Article 57(a), no source_xml_id); items inside a definition stay text; K5 #185 doubled
brackets (fixed in CV-S02a);
K6 the feed lists one effect twice (identical rows), merged later; K7 EU "EUR-Lex in-force date"
in Comments not used (a pointer); K8 a commencement's territory not yet applied by the label
(in_force_for carried); K9 placed_versions targets every version — narrowing by the carried
extent is the label fold's (CV-S09); K10 nested schedule ids named short by the shared namer
(schedule-N-part-P-paragraph-M → sch.N.pt.P; unnumbered schedule-paragraph-1 → sch.paragraph) —
no effect while schedules are unparsed (CV-S02a, deferred); K11 a second date written only in
an OtherQualification's free text ("… and 1.1.1996 in so far as not already in force") is not
made a stage (the text is carried); K12 staged modifications/applications stay one change (no
operation, so not staged).

For each item judge placement (targets + outcome, verified in the DB and text) and facts
(operation, level, dates/stages, by, extent, territory, savings, in_force_for) against the
feed's own record.

Output: a compact table, one row per item: #, law, effect_id last 6, placement OK/WRONG/doubtful,
facts OK/WRONG/doubtful, note (only when not OK: one line, with K# or NEW). Then counts per
dimension, and the NEW defects with items and concrete evidence (feed value vs reader value,
DB/text check). Be rigorous and skeptical — this is an acceptance gate; WRONG needs evidence;
say doubtful rather than guess. Under 900 words.
```

## History

- CV-S02b (2026-10-23): the catalogue over all 1,207 stored feeds (251,692 effects, 985 patterns) found readings no sample had reached, A–J. They are fixed in `ChangeVocabulary.EffectVerb` and `Qualification`. K10 is pending (16 patterns). The session is `.claude/sessions/change-vocabulary/2026-10-23-cv-s02b-feed-pattern-catalogue.md`.
- OH&S (first family, 2026-10-22/23). Rounds: seed {2026,10,22} (defects A–F), seed 7 (D1–D5), seed 11 (49/50, NEW-A and NEW-B fixed), seed 13 (49/50, NEW-C deferred as K10, NEW-D fixed), seed 17. The session is `.claude/sessions/change-vocabulary/2026-10-22-cv-s02-feed-reader.md`.
- CV-S02a (2026-10-23) fixed K2, K4, K5 and sensed K3 in the parser; the OH&S re-check after its re-parse: our faults 0, tell-tales 16 → 5 (all `not_found`, genuinely absent), golden 27/27. A new family's tell-tales of these kinds are now NEW.
