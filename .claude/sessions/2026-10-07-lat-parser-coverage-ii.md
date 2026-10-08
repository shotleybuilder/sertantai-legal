---
session: "LAT Parser Coverage II"
status: active
opened: 2026-10-07
related: [169, 175]
depends_on: ["2026-10-07-lat-parser-coverage", "2026-10-07-issue-175"]

bugs:
  - pattern: "P1group/Title (regulation/section heading) never captured; P1group is a pass-through container"
    category: LAT coverage
    module: SertantaiLegal.Scraper.LatParser (P1group in @container_elements; extract_title)
    affected: "31,644 empty section/article rows in 1,033 of 1,069 laws"
    fix: "title column (item 1)"
    status: fixed
  - pattern: "xmerl ./Title//text() returns text nodes out of document order (direct text first, then descendants'); extract_title scrambles headings with inline markup"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (extract_title; //text() elsewhere)
    affected: "623 Title elements in 218 stored docs (Pnumber/Number clean); only those used in row text matter (Part/Chapter/Pblock/P1 own Title)"
    fix: "Ordered inline walk of every ./Title (joined by a space), retained territorial Repeal kept apart from its replacement; Pnumber/Number via descendant::text()"
    status: fixed
  - pattern: "Repealed provision whose CommentaryRef sits in a dots-only P1group Title (Pnumber clean, <Text/>) reads in_force with empty text, not [Repealed]"
    category: LAT status
    module: SertantaiLegal.Scraper.LatParser (mark_repealed_provisions reads the P1's own refs only)
    affected: "subset of 877 empty section/article rows left untitled (e.g. UK_ukpga_1962_58:s.24)"
    fix: "Fixed via note placement (P1group Title refs on the P1 → [Repealed])"
    status: fixed
  - pattern: "CommentaryParser reads .//Para//text() and .//Text//text() (xmerl: direct text first, then descendants') — amendment note text scrambled corpus-wide, e.g. 'substituted (17.9.2002) by , Reg. 10(1) (2) The Health and Safety ... regs. 1 7(a)'"
    category: annotation text
    module: SertantaiLegal.Scraper.CommentaryParser (extract_commentary_text); taxa_parser.ex has the same xpaths
    affected: "80,012 of 90,210 amendment_annotations reordered (4,058 drift left for re-parse)"
    fix: "Each Text block in document order; mix lat.reorder_notes re-keyed in place (LatStatus.Apply refresh, lat_changes change_ids mapped)"
    status: fixed
  - pattern: "mix lat.repair_text rewrote text without re-deriving status: rows repaired to dots (repealed) still read in_force"
    category: LAT status
    module: Mix.Tasks.Lat.RepairText (apply!/3)
    affected: "34 rows in 14 laws (mix lat.status dry run 2026-10-08)"
    fix: "LatStatus.Apply.refresh(law) in the repair transaction (done); mix lat.status --apply for the 34"
    status: fixed
  - pattern: "Notes cited only by a CommentaryRef attribute (Addition/Substitution/Repeal) or from a P1group Title had no affected_sections"
    category: annotation placement
    module: SertantaiLegal.Scraper.LatParser (collect_commentary_refs: .//CommentaryRef/@Ref only; P1group Title outside the P1)
    affected: "39,041 unplaced notes: 35,353 attribute-only in body, 912 element refs outside a row (P1group Title), 2,282 scoped laws, 494 unreferenced"
    fix: "Placement refs = element refs ∪ @CommentaryRef; P1group Title refs onto its P1 rows; counts unchanged; mix lat.place_notes"
    status: fixed
  - pattern: "LatStatus @full missed 'in so far as it is / they are not already in force', 'in operation', 'remaining purposes', typos → rows wrongly in_force_partial"
    category: LAT status
    module: SertantaiLegal.Scraper.LatStatus (@full)
    affected: "162 rows in 6 laws now (mix lat.status dry run), more once notes are placed"
    fix: "Widened @full (tests from corpus wordings)"
    status: fixed
  - pattern: "LatStatus marks a row in_force_partial on any non-modification note on it/its ancestors matching 'for specified purposes', even when the note is about another provision (source-duplicated notes, 'except for … for specified purposes' clauses)"
    category: LAT status
    module: SertantaiLegal.Scraper.LatStatus (status/2)
    affected: "~10-15 of 451 rows newly partial after placement (e.g. UK_ukpga_2017_20 s.43/s.44 carry the source's copied 'S. 2 in force for specified purposes' note; UK_ukpga_1993_12 s.50)"
    fix: "partial_note?: phrase within a commencement step before ' by ', not in a repeal's except-clause, note subject (s./reg./art. numbers) covers the row"
    status: fixed
  - pattern: "#165 schedule rows empty text (TitleBlock title not read)"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (extract_title)
    affected: "16 of 17 schedule rows"
    fix: "extract_title falls back to TitleBlock/Title"
    status: fixed
  - pattern: "Amending provisions end 'insert—/substitute—': BlockAmendment text skipped on structural rows, unquoted on leaf rows"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (text_blocks: @quoted_elements)
    affected: "4,107 rows / 289 laws (qq-00)"
    fix: "One «…» block with numbers and titles (Jason: amending text used to update records)"
    status: fixed
  - pattern: "Table cells (XHTML) not captured; signatures (Signee) empty; P2group/P3group titles; Versions alternatives skipped"
    category: LAT coverage
    module: SertantaiLegal.Scraper.LatParser
    affected: "208 tables, 722 signatures (half empty), 90 group titles, 577 alternative provision versions"
    fix: "table_text, signee_text, grouped/2, alt_versions (walked beside their counterpart)"
    status: fixed
  - pattern: "Old-generation sort keys (22 segments)"
    category: LAT
    module: legal_articles.sort_key
    affected: "0 rows left (2026-10-08)"
    fix: "SortKeyRewrite (2026-09-27)"
    status: fixed
  - pattern: "Repealed provision whose CommentaryRef sits in a dots-only P1group Title reads in_force with empty text"
    category: LAT status
    module: SertantaiLegal.Scraper.LatParser
    affected: "e.g. UK_ukpga_1962_58:s.24 — now [Repealed]/repealed"
    fix: "P1group Title refs placed on the P1 (item 4) → repealed marker"
    status: fixed
  - pattern: "Note dates/status reach only the note's last affected row (LatStatus.note_target = List.last(affected_sections)): sibling ranges, section-level insertion notes, whole-instrument revocations (target = signature row), alternative versions"
    category: note metadata
    module: SertantaiLegal.Scraper.LatStatus (note_target/1), LatStatus.Apply
    affected: "QA: T7 29 defects / ~50 rows with notes; up to 59,486 of 104,503 lower-level rows with a dated note have nil effective_from"
    fix: "Place notes on the rows that cite them at their own level; a note applies to each citing row and its descendants"
    status: open
  - pattern: "Welsh SIs in changed_by as uksi: 'S.I. 2018/35' citing id/wsi/…, 'W.S.I. 2026/112'"
    category: note metadata
    module: SertantaiLegal.Scraper.AmendmentNote (changed_by)
    affected: "4+ QA rows"
    fix: "W.S.I. prefix; prefer the Citation URI type"
    status: open
  - pattern: "Acts of Senedd Cymru (asc), mwa, ukla parsed as SIs (reg. ids, [Revoked])"
    category: LAT identity
    module: SertantaiLegal.Scraper.LatParser (@act_type_codes)
    affected: "every asc/mwa/ukla law"
    fix: "add to @act_type_codes; re-parse those laws"
    status: open
  - pattern: "Extent qualifier on a provision with no alternative version: a child's narrower RestrictExtent trips parallel detection"
    category: LAT identity
    module: SertantaiLegal.Scraper.LatParser (detect_and_qualify_parallels, parallel_key)
    affected: "QA 2+ rows; whole sections (uksi 2017/1047 reg.3, ukpga 1967/10 s.30, ukpga 1992/51 s.12)"
    fix: "qualify only when the same provision row (same hierarchy keys) occurs with different extents"
    status: open
  - pattern: "Welsh Version's rows labelled England (inner P1 RestrictExtent=E inside a Description=W version)"
    category: LAT identity
    module: SertantaiLegal.Scraper.LatParser (alt_versions)
    affected: "uksi 2010/2214 reg.36 and similar"
    fix: "a version's own extent governs its rows when an inner extent contradicts it"
    status: open
  - pattern: "Whole-row territorial text bracketed instead of excluded_extent when the row has child provisions"
    category: LAT territory
    module: SertantaiLegal.Scraper.LatParser (excluded_extent over the subtree)
    affected: "QA 3 rows (1989/14 s.3(5), 1992/51 s.12(1ZA)(a))"
    fix: "decide on the row's own text; subtree only when it has none"
    status: open
  - pattern: "Complex tables lose cells; a definitions table reads [Repealed]; tables inside «…» lost"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (table_text, mark_repealed_provisions, quoted_text)
    affected: "QA 3 rows (ukpga 2003/20 table.1032, 1991/22 table.1059, 2017/3 s.173(2))"
    fix: "investigate cell markup; quoted_text renders tables"
    status: open
  - pattern: "«…» quotes drop Number (Schedule/Part), list letters, trailing AppendText"
    category: LAT text
    module: SertantaiLegal.Scraper.LatParser (quoted_child)
    affected: "QA 3 rows"
    fix: "render Number, ListItem numbering, AppendText after the block"
    status: open
---

# Session: LAT Parser Coverage II (ACTIVE)

## Problem

The rest of the parser audit (2026-10-07) after the list-text bug and #174 were fixed and the corpus repaired (`2026-10-07-lat-parser-coverage`). The LAT still drops regulation/section titles, misses attribute-style CommentaryRefs (so many annotations can't be placed), and reads territorial repeals as live everywhere. All passes now run offline from the local CLML store (#175), measured with `mix lat.text_diff --all --store only` before anything is written.

## Todo

- ⬜ Capture P1group/Title into a new `title` column — parser + tests ✅, migration ✅ (dev-only for prod delta), offline measure ✅, fractalaw contract (Zenoh column + manifest `title_hash`) ⬜, title-only backfill applied ✅ (45,964 titles, 1,060 laws, 0 errors; Jason 2026-10-08). (row text unchanged; migration + fractalaw contract). Stopgap in use: `backend/data/reports/clml-headings-2026-10-07.csv` (46,894 headings, 1,060 laws; script `backend/data/reports/extract_headings.py`)
- ✅ Heading text order: parser fix (tests), 64 rows / 51 laws repaired (34 correction, 30 unattributed; verify dry run 0), UK_uksi_1979_628 Part renames via store re-parse (4 renamed, 54/54 enriched kept), 9 title corrections
- ✅ Annotation note text order (folded in by Jason 2026-10-08): parser fix (tests), `mix lat.reorder_notes` applied — 80,012 notes / 758 laws, 943 row effective_from/changed_by, 76,976 change_id mappings (`notes-reorder-2026-10-08.csv.change-ids.csv`), 4,058 unmatched left for re-parse; stale statuses fixed first (`mix lat.status --apply`, 34 rows)
- ✅ Note placement (attribute-style CommentaryRef + P1group Title refs): parser fix (tests), LatStatus full-commencement wordings, applied — 36,493 notes placed + 1,328 gaining sections, unplaced amendment notes 38,427 → 1,970, 38,972 rows' effective_from/changed_by; statuses 162 (`lat.status`) + 451 → partial, 27 → in_force, 2 saved → repealed
- ✅ Retained repeals (`Repeal RetainText`): `repealed_extent` on 7,015 rows / 103 laws, 1,963 rows → repealed_saved, 536 rows text repaired (133 bracketed territorial wording, 402 empty → [Repealed]/[Revoked], 1 spacing), all `correction`
- ✅ Remaining parse bugs closed in place (Jason 2026-10-08, §6): territorial words/insertions bracketed, `excluded_extent`, amending text «…», tables, signatures, P2group/P3group titles, alternative versions, #165 schedules, partial-status misfires; P5 already in P4 text; footnotes #176 and figures #177 left out (future enhancements); prelims/RestrictStart/EndDate not provision text
- ✅ One re-parse wave, offline from the store: 1,056 laws, 97% of enriched rows carried, verified (LAT = parser output); 1 control mapping left for Jason (EU 2008/1272 Art. 37A)
- ⬜ Randomised eyeball QA of LAT records by a Claude agent against the CLML store (spec `docs/LAT-QA-SAMPLE-SPEC.md`, sampler `mix lat.qa_sample`); its findings gate the hand-off
- ⬜ fractalaw contract (frame columns `title`, `excluded_extent`; manifest `title_hash`, `notes_hash`; vectors) — built after QA, one message; don't flag fractalaw until Jason says

## Dependencies

- ✅ LAT parser coverage (list-text bug, #174, corpus repair) closed 2026-10-07
- ✅ #175 local CLML store (all 1,068 LAT laws)
- ⬜ fractalaw contract for the `title` column (and any annotation/status changes) before the re-parse wave

## 1. Provision titles (`title` column)

Rules (`LatParser`, tests in `lat_parser_test.exs` "parse/2 title column"):
- a P1group's Title → every P1 row it wraps (multi-P1 groups too); consumed by the P1, so nested provisions and sub-rows stay nil
- Part / Chapter / Pblock rows → their own Title; Schedule → TitleBlock/Title
- inline markup joined in document order without spaces (`descendant::text()`), whitespace collapsed; dots-only (repealed) → nil
- row text unchanged; not in `lat_hash` / `struct_hash`

Schema: `legal_articles.title text`, appended to the `lat` view (migration 20261008070000, codegen no-op 20261008070005); `Sync.Delta.Config` marks it dev-only for `lat` until compliance asks.

Rollout (no re-parse): a title-only UPDATE from the offline store parse, matched on section_id. Triggers: only the `legal_register` stats trigger fires (lat_count, updated_at); hashes untouched → fractalaw needs a `title_hash` in the manifest (as `status_hash`, #167) to see it.

### fractalaw contract (2026-10-08)

Proposed and agreed in principle: `title` appended to the Arrow LAT frame (decoder reads by name, unknown columns ignored); manifest `title_hash` mirroring `status_hash` (`section_id TAB title LF`, null → "", never null); do NOT bump `updated_at` (title_hash is the only signal; they add a title-only apply path). Asked for: a `title_hash` vector with a null-title row in `test/fixtures/lat_hash/vectors.json`; the 218-doc list before the heading-scramble `correction` round.
Jason: fractalaw builds nothing until this round of fixes settles → send ONE final contract message (frame columns, manifest fields, hash vectors) at the end. (Correct then: the scramble example in the proposal was a test string, not a real heading.)

### Measurement (offline, store, 2026-10-08)

`backend/data/reports/lat-parser-coverage-ii/titles-2026-10-08.csv` (+ `.laws`): 1,068 laws, 0 errors, 372,249 parsed rows → 46,079 titles in 1,060 laws (article 20,023, section 17,320, heading 4,449, part 3,047, chapter 1,225, schedule 15 — schedules are mostly not in the LAT). Of 28,287 stored empty-text section/article rows, 27,410 (97%) get a title. The 877 left: dots-only (repealed) titles → nil (and see the status bug), stale rows no longer in the XML (e.g. 1936/49 s.101), bare P1s outside a P1group (e.g. 2001/838 reg.6E/6F — no title in the source). 115 titled ids are not in the stored LAT (amendment drift; left for a re-parse).

## 2. Heading text order

Root cause: xmerl evaluates `./Title//text()` as direct text first, then descendants' text, and across *every* Title child — so headings with inline markup were scrambled ("ADULTS IN THE FRONT OR OF A VEHICLE RE AR") and a heading split over two Title elements ("International Oil Pollution" + "Compensation Fund") only survived by accident. `/descendant::text()` is ordered.

Fix (`LatParser.heading_text/1`, `titles_text/1`): an ordered inline walk of each Title, inline markup joined without spaces ("CO<Sub>2</Sub>" → CO2), whitespace collapsed, several Titles joined by a space; a `Repeal RetainText` whose `SubstitutionRef` names the next element's `ChangeId` keeps a space (territorial alternative — item 3 renders it properly; body text has the same glue). Pnumber/Number/first-P1 number use `descendant::text()`.

Offline diff (`heading-order-diff-2026-10-08.csv`, all 1,068 laws): the fix changes 64 heading rows in 51 laws (34 correction = same words reordered, 30 unattributed = joined/restored words, e.g. "CO emissions 2" → "CO2 emissions", "PM , PM" → "PM10, PM2·5") and 4 Part ids in UK_uksi_1979_628 ("pt.P IIart" → "pt.II"). Plan: `data/reports/lat-parser-coverage/repair-plan-heading-order-2026-10-08.csv`.

Pre-existing drift the diff also shows (not this fix, identical with the old parser): 38,152 rows differing only in whitespace or the " … " gap marker (repairs wrote only rows whose words changed), and 2,606 inserted/removed ids in 44 laws (EU `#position` suffixes, signed blocks, amendments in newer stored XML, e.g. UK_uksi_2010_2214 1,117).

Final dry runs (2026-10-08, after the territorial-pair refinement `SubstitutionRef` → `ChangeId`): heading repair 64 rows / 51 laws (34 correction, 30 unattributed); 1979/628 single-law store re-parse preview: 4 Part renames, 66/66 enriched carried, 0 changed/dropped; title re-check 9 corrections to the applied title column (split Titles, territorial pairs). All awaiting Jason.

Applied 2026-10-08 (Jason): `repair-applied-heading-order-2026-10-08.csv`, `lat-reparse/heading_order_1979_628.csv`, `titles-recheck-2026-10-08.csv`.

## 3. Annotation note text order (folded in 2026-10-08)

`CommentaryParser` read `.//Para//text()` ++ `.//Text//text()` (uniq'd): every note with a Citation came out scrambled ("substituted (17.9.2002) by , Reg. 10(1) (2) The Health and Safety …"). Now each Text block is read in document order (`descendant::text()`), blocks joined by a space. `AmendmentNote` was written against the scrambled form but parses the ordered text as well or better.

Offline measurement (`notes-order-laws.csv` / `notes-order-fields.csv`, 785 laws with notes, 27 not in the store): 86,120 of 90,178 stored notes match their commentary's old text (pair on code_type + code + old text — ids renumber in scoped laws); 80,012 change text. Derived fields: effect 0 changes, effective_from 11 (dates written "( 1.4.1991)" now before "by"), changed_by 929 (645 modification, 237 amendment, 41 commencement, 17 editorial — mostly the amending instrument instead of the cited/commencing one, wsi for "(W. n)" SIs; "does not form part of domestic law under EUWA" notes lose ukpga_2018_16, which isn't an amender).

change_id is a hash of the text, and LatCause reads new change_ids as an amendment → the rollout re-keys in place: `mix lat.reorder_notes` (`NoteReorder.plan/2`, `CommentaryParser.text_pairs/1` — temporary, remove after) rewrites matched notes, `LatStatus.Apply.refresh/1` re-derives fields / statuses / row effective_from+changed_by, and `lat_changes.change_ids` are mapped (one row holds any: UK_ukpga_2016_24). Per law, one transaction; dry run rolls back. Old → new change_id mapping kept for fractalaw. Contract: propose a manifest `notes_hash` so fractalaw can see note changes (nothing signals them today).

Corpus dry run (`notes-reorder-2026-10-08-dry.csv`, rolled back): 758 laws, 80,012 notes reordered, 4,058 unmatched (drift → next re-parse), 79,996 notes re-derived, 943 rows' effective_from/changed_by change, 1 lat_changes re-key. 27 laws skipped: no stored XML, no LAT, 32 orphan notes. The 29 status changes it showed were stale statuses, not the reorder: rows repaired to dots by `lat.repair_text` kept `in_force` (bug above, fixed); `mix lat.status` dry run: 34 rows / 14 laws in_force → repealed — apply that first so the reorder's numbers are its own.

Applied 2026-10-08 (Jason): `mix lat.status --apply` (34 in_force → repealed, snapshot `lat_status_snapshot_20261008_0916`), then `mix lat.reorder_notes --all --store only --apply` — matches the dry run exactly (statuses_changed 0 after the status fix). Verified: every lat_changes change_id resolves; `mix lat.status` 0 to change; re-run is a no-op (NoteReorder.plan skips already-ordered notes).

## 4. Note placement

Why notes were unplaced (`unplaced_scan`, 39,041 notes with no `affected_sections`): 35,353 cited only by a `CommentaryRef` attribute on Addition/Substitution/Repeal in the body (the parser collected `<CommentaryRef>` elements only); 912 by an element outside any row (a P1group Title — "Word in s. 3ZB heading omitted" sat on the cross-heading); 2,282 in scoped laws (not scanned); 494 referenced nowhere (orphans).

Fix: a row's placement refs = element refs ∪ attribute refs (deduped); a P1group Title's refs go on its P1 row(s). Per-row `*_count` columns stay element-only, so LAT rows (text, ids, counts, struct_hash) don't change — only notes' `affected_sections` and the note-derived row fields. Already-placed notes can gain sections ("S. 4(6)(7) repealed" now covers s.4(6) and (7), not just s.4(8)) — reported as `notes_moved`.

Rollout: `mix lat.place_notes` — store parse (`LatStagedParser.fetch_notes/2`), match on `{code_type, code, text}` (`NotePlacement.plan/2`, never clears sections), `LatStatus.Apply.refresh`; per law, dry run rolls back.

Found on the way: newly placed RTA 1988 s.184 notes ("28.3.2009 for certain purposes, 31.10.2009 in so far as it is not already in force") made rows in_force_partial — `LatStatus` @full missed that wording and four more found in the corpus; widened (tests). Alone, 162 rows / 6 laws in_force_partial → in_force (`mix lat.status` dry run).

Corpus dry run (`notes-place-2026-10-08-dry.csv`, rolled back): 758 laws, 36,493 notes placed + 1,328 gaining sections, 3,924 unmatched (drift), 2,548 still unplaced (from 39,041), 38,972 rows' effective_from/changed_by change. Status transitions: 451 in_force → in_force_partial (49 laws), 189 in_force_partial → in_force (13 laws; the @full wordings), 2 repealed_saved → repealed. Of the 451, 397 rest on a note naming the row's own provision; most of the other 54 are Part/Chapter/cross-heading insertions "for specified purposes" covering the row (right); ~10-15 misfire (bug above).

Applied 2026-10-08 (Jason): `mix lat.status --apply` (162 in_force_partial → in_force), then `mix lat.place_notes --all --store only --apply` (`notes-place-2026-10-08.csv`) — matches the dry run (189 partial → in_force = 162 + 27). Verified: `mix lat.status` 0 to change, re-run a no-op. Unplaced now: amendment 1,970, editorial 327, modification 235, commencement 16.

## 5. Retained repeals (territorial / purposes / savings)

Survey (`terr_scan.py`, `terr_rows.py` over the store): `Repeal RetainText="true"` wraps text repealed but kept — never a whole provision element, always its words/Pnumber/Title. Territory from `@Extent`, else the note ("revoked (S.)"); 7,898 retained repeals have no territory — the note says "for specified purposes" / "subject to savings". Rows (P1–P4): 6,612 wholly retained-repealed (93 laws), 526 with territorial substitutions (old kept for one territory beside its replacement), 178 with some words repealed for one territory. All read in_force today.

Decisions (Jason, 2026-10-08):
- Wholly repealed for some territory, live elsewhere → new nullable `repealed_extent` column (e.g. "S"); status stays in_force; text and `extent_code` unchanged; additive (not in struct_hash).
- Wholly repealed with no territory (purposes / savings) → status `repealed_saved` (existing value).
- Territorial wording → both versions bracketed in the text, e.g. "used by a [S: fire and rescue authority] [E+W: fire brigade]"; text change logged as a repair.

Built (tests): `Territory` (note territory "(S.)"/"(E.W.)"/"(E. and W.)"/"(N.I.)"/"(in relation to W.)", extent-code set ops); `LatParser` row `repealed_extent` (all text — sub-provisions included, numbers/titles not — inside retained repeals: union of their territories from `@Extent`, else the note; any without a territory → the row's whole extent) and status `repealed_saved` when it covers the row's extent; `LatStatus` applies the same rule on refresh (`Apply` reads `repealed_extent`, `extent_code`). Column `legal_articles.repealed_extent` (migration 20261008110200, codegen no-op, lat view, dev-only delta). Territorial substitution pairs (Repeal `SubstitutionRef` = partner `ChangeId`, territory from either `@Extent`) render "[S: new] [E+W: old]" — the old wording's label is the row's extent minus the pair's; extent-less pairs (262 of 301 are timing: "substituted … for specified purposes") keep both, space-separated (they were glued). Headings/titles unchanged (space). Retained words with no replacement stay as text (178 rows; not decided).

Fixes on measurement: pairs whose old wording is split across Repeals sharing a SubstitutionRef or nested in a Term (TCPA 1990 s.247(1)(a), CROW 2000 s.1(3)(a)) rendered twice / lost words → a pair takes every node from its first Repeal to the partner. `Territory.from_note` also reads "(1.4.2015 for S. for the repeal of …)" / "(… in relation to E.W.)" (EPA 1990 ss.1-28 had read as repealed everywhere), not "except in relation to W.". `mix lat.repair_text --cause correction` labels a parser-fix round's repairs `correction` (new words like "[S: …]"/"[Repealed]" would otherwise be unattributed); `mix lat.backfill_titles --column repealed_extent`.

Dry runs (2026-10-08, store):
- `repealed_extent` backfill: 7,015 rows / 103 laws (`repealed_extent-backfill-2026-10-08-dry.csv`) → expected status: 4,769 rows / 84 laws stay in_force (repealed in some territories), 1,963 rows / 30 laws → repealed_saved (whole extent: "revoked with savings", "in so far as …"); dotted rows stay repealed.
- Text repair (`repair-plan-retained-2026-10-08.csv`, 98 laws, all `correction`): 536 rows — 402 empty rows → "[Repealed]"/"[Revoked]" (they now carry the repeal note's ref: a side effect of note placement, item 4), 133 bracketed territorial wording, 1 glued word ("1965the").

Applied 2026-10-08 (Jason), in order: `mix lat.backfill_titles --column repealed_extent --all --store only --apply` (7,015 rows / 103 laws); `mix lat.status --apply` (in_force → repealed_saved 1,948, in_force_partial → repealed_saved 15; 33 laws); `mix lat.repair_text --laws-file retained-laws.txt --whole --store only --tag retained --cause correction --apply` (536 rows, all correction). Verified: repair re-dry-run 0, `mix lat.status` 0. Pairs whose SubstitutionRef resolves to no element (12 in the survey, e.g. 1986/1078 reg.107(2)(a)) stay as written (both versions in sequence). Not done: 178 rows with words repealed for one territory and no replacement keep the words as plain text (undecided).

## 6. Close every remaining parse bug in place (Jason, 2026-10-08)

Jason: "I want clean data handed off to fractalaw given the time, effort and cost of enrichment. We cannot continue to iterate while data quality improves — data quality needs all fixed in place." Every open LAT parse bug is fixed in this session, then one hand-off.

Inventory (2026-10-08): old-generation sort keys — 0 rows left (fixed earlier); P1group-Title repeal notes — fixed (rows now [Repealed]/repealed); empty section/article rows — not a bug (text in sub-provisions; title column). Open: #165 schedule rows empty (16 of 17); amending provisions ending "insert—/substitute—" (4,107 rows / 289 laws; BlockAmendment 5,939 blocks, 5.6M chars, skipped); tables (208 Tabular / 85 docs, cell text missing — 80 of 212 rows empty); signatures (722; half empty); P2group/P3group titles (90 / 10 docs); Versions blocks (86); partial-status misfires (~10–15 rows); footnotes (4,567 / 502 docs) and figures (102); drift (whitespace-only 28,710 rows, gap-marker-only 9,112, ids 1,703 inserted / 903 removed in ~43 laws, 3,924 unmatched notes).

Decisions (Jason, 2026-10-08):
- Retained words with no replacement: bracket "[E+W: words]" (done, + territorial insertions "[E+W: words]", adjacent brackets merge).
- Amending provisions: append the inserted text, quoted «…» — "because leg.gov.uk doesn't apply amendments in good time — we have an issue to use the amending text to update our records. Were it not for this reason it would be [a marker only]."
- Rows inserted wholly for a narrower territory (494): plain text; rename `repealed_extent` → `excluded_extent` (territories where the row's text does not apply), covering whole-row repeals and whole-row insertions.
- Footnotes and figures: leave out; future enhancements #176 (footnotes), #177 (figures).

Built (tests, 2026-10-08): retained words "[E+W: words]" and territorial insertions "[E+W: words]" (narrower than the row), adjacent same-territory brackets merge, nested repeals plain inside; `Territory.normalize/1` (dotted "E.W."); `excluded_extent` (renamed from `repealed_extent`, migration 20261008130300) also for rows inserted wholly for a narrower territory (plain text); amending text «…» (BlockAmendment/AppendText/BlockExtract, numbers + titles, also as trailing content); tables (cells " | " / "; ", Tabular title → title column; not repeated in the provision's text); signatures (Signee: name, job title, address, date); P2group/P3group titles + refs; alternative versions (Versions/Version via AltVersionRefs, beside their counterpart, qualified by extent); schedule row text from TitleBlock (#165); partial status only from the note's own commencement step (58 rows partial → in_force: NPA 2017 copies, GWA boilerplate, citation tails, repeal except-clauses). Issues #176 (footnotes), #177 (figures).

Final offline diff (`final-diff-2026-10-08.csv`, all 1,068 laws; 1,057 with a change): whitespace-only 27,824 rows (1,030 laws), gap-marker-only 8,890 (700), amending text «» 5,529 (390), table/signature/schedule 781 (691), territorial brackets 674 (99), other text 115 (68), ids inserted 15,731 / removed 7,731 in ~83 laws — 11,428 inserted rows have a removed row's text (renames: extent-qualified ids from alternative versions, #position shifts). No placeholder leaks.

Rollout proposal: one offline re-parse wave from the store (`mix lat.reparse --store only`, no `--cause`): LatMerge carries enrichment for rows whose normalised text is unchanged (whitespace-only) and renames, notes are re-read and re-placed, and LatCause labels each law from evidence (same source hash → parser; newer XML → legislative/unattributed per row). Dry run: `lat-reparse/wave_preview.csv`.

### Re-parse wave (dry runs, 2026-10-08)

First dry run (`lat-reparse/wave_preview.csv`, 1,056 laws; UK_uksi_1979_791 left out — its stored XML is a body-less "made" document, its LAT came from the PDF pipeline; preview now reports an empty parse instead of crashing): enriched 301,552 rows, carried 288,726, changed 8,568, dropped 832, ambiguous 3,426, gate failures 57 laws. Causes and fixes:
- alternative versions made reg.33 → reg.33[E+W+NI] + reg.33[S] with shared text: the extent-tag rename took a single candidate only → now the first matching new row in document order (the body version) — ambiguous 3,426 → 12
- a Version repeating its counterpart (uksi 2010/2214: the Welsh version of reg.7 holds a P1 marked E) duplicated rows → version rows that repeat a body row (same place, extent, text) are dropped
- repeal-marker rows ("[Repealed]", dots) matched dozens of rows and tripped the gate → not evidence of a matching failure
- a table's cells were repeated in the provision's own (leaf) text → only on the table row
Remaining gate rows (13 in 8 laws) are real: renumbered by amendment (EU 2008/1272 Art. 37(4)(b) → 37(5)(c)), `#position` shifts of duplicate source ids (1875/17 s.23(3)), wording that moved (1968/73 s.10(1) E+W+NI changed, the S version keeps it) — re-enriched (`--force` for those 8 laws).

Final dry run (`lat-reparse/wave_final_preview.csv`, 1,056 laws, store only): enriched 301,552 rows — carried 292,596 (97.0%), changed 8,568 (text really changed), dropped 376 (ids gone: amendments in newer XML, renumbering), ambiguous 12; gate 8 laws / 13 rows (above); errors 0. Enriched rows to re-enrich: 8,956 (3.0%). Applied 2026-10-08 (Jason) — see below.

### Re-parse wave applied (2026-10-08)

1. NAS backup (`nas-backup.sh --archive`): exit 0, previous snapshot archived to `snapshots/archive/2026-10-07T21:55:25+01:00/`.
2. `mix lat.reparse --store only --tag wave` on 1,048 laws (snapshot table `lat_reparse_wave`), 0 errors.
3. `mix lat.reparse --store only --force --tag wave_gate` on the 8 gate laws (`lat_reparse_wave_gate`).

Totals (`lat-reparse/wave.csv` + `wave_gate.csv`, 1,056 laws): rows 371,290 → 379,340; enriched 301,552 → 292,596 (carried as the dry run said); renamed 7,255, changed 10,747, ambiguous 15, dropped 400. Stored text has no placeholder leaks. Law-level cause (LatCause, from evidence): legislative 199, parser 66, unattributed 791 — the stored XML's hash differs from each law's last recorded parse hash for most laws, so rows without their own amendment evidence are `unattributed` rather than `parser`.

Control mappings orphaned by the wave: 4. Three re-pointed to the body version of a provision that gained a territorial alternative with changed text (UK_uksi_2008_1597:reg.7(5)/(6) → `[E+W+S]`, UK_ukpga_1968_73:s.135(1) → `[E+W+S]`). One left for Jason: UK_eur_2008_1272:art.Article 37A(3)(2) — Article 37A is repealed in the current XML (similar wording now in Art. 37(6)(c)); control 4288493d-…. Two older orphans predate the wave: UK_ukpga_1990_43:s.40(4), s.74(3) (control 40a9d67d-…, mapped 2026-07-13; neither id existed before the wave).

Post-wave verification: `mix lat.status` 0 to change; offline diff of all laws (`post-wave-diff-2026-10-08.csv`) — 0 real differences: 28,637 rows were stored "" vs parsed nil (a diff-tool artefact, fixed: `LatTextDiff.diff/2` treats nil and "" alike — the earlier "whitespace-only 27,824" was mostly this), 58 removed = UK_uksi_1979_791 (left out on purpose: PDF-sourced LAT, body-less stored XML). The LAT now equals the parser's output for every law.

## 7. Randomised eyeball QA (Jason, 2026-10-08)

Jason: a Claude agent runs a randomised QA sample of LAT records against the XML store — an eyeball QA, with a spec; the fractalaw contract folds into it as the values it will receive (not the transport/hashes).

- Spec: `docs/LAT-QA-SAMPLE-SPEC.md` — the rendering rules the LAT applies (so the agent judges against them), checks T1 text … T8 identity, verdicts pass/minor/defect/unsure, outputs `findings.csv` + `summary.md`, read-only.
- Sampler: `mix lat.qa_sample --n N --seed S` — strata (plain 28%, title, territorial brackets, amending text, excluded_extent, repealed_saved, in_force_partial, repealed, table, signed, structural, qualified ids, placed notes), md5(seed||id) order so a seed is reproducible; packets carry the stored row, its notes with their `<Commentary>`, the row's XML fragment (own id, the enclosing provision for tables, the SignedSection for signatures) and store paths. Read-only, offline.

### QA run qa-2026-10-08 — not ready (2026-10-08)

100 packets (90 distinct rows — sampler bug: an unparenthesised OR let placed_notes redraw plain rows; fixed, re-draw gives 100 distinct), 71 laws, four agents × 25. Consolidated: `backend/data/reports/lat-parser-coverage-ii/qa/qa-2026-10-08/summary.md`, `findings.csv` (57 non-pass lines). Text, artefacts and titles clean; all four slices "not ready" on: note → row targeting (systemic), Welsh SI changed_by, asc ids, spurious extent qualifiers, Welsh version labelled E, whole-row territorial text bracketed, complex tables, «…» numbers/tables (bugs above). Minor: "[elsewhere: …]" labels, whole-extent brackets, signature commas, marginal citations (Commentary Type="M") stored as modified notes. Process: two agents were refused writing their summary; one wrote it through the shell anyway.
