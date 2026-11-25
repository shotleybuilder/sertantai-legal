---
session: 'Extent reader: stamps that follow what changed'
status: closed
opened: 2026-11-25
closed: 2026-11-25
outcome: success
summary: >
  The Extent reader's one folder-wide stamp is split into four stamps, each held exact by reach in a test:
  Document, Catalogue, ReadVersion (stored rules) and the powers parser's on the enabling cache.
  The build's fallback that read unstored laws from text is gone ("not read" is now a stale reason), so
  the build's version holds 5 extent files, not 41. The catalogue digests match the baseline for all
  2,601 laws, golden is 27/27, and the suite, the Credo diff and Dialyzer are green.
decisions:
  - what: "The stored-rules stamp holds the catalogue's classes (Patterns, Credit, Unread); only Patterns.Example and Sweep form the catalogue stamp"
    why: "extent_rules stores Reader.withheld/1, so Unread withholds bounds by the catalogue's unread: classes; the classes are the reading"
    result: "A catalogue-only edit stales nothing stored; few edits are catalogue-only"
  - what: "Drop the build's read-from-text fallback; a law with text held and no extent_rules is an :extent_reader stale reason"
    why: "1,287 laws were read from text by every build, in no stamp, and they put the whole reader in the build's version (Jason's go in the readiness review)"
    result: "The build's version has 5 extent files (was 41); extent_reader stale 768 → 924; golden's 88 unread laws written first"
  - what: "Stamp the powers parser on each enabling cache entry; a behind entry is re-parsed from the introduction held, never fetched"
    why: "A parser change moved no version; its reach was found by a diff by hand"
    result: "EnablingCache.ParserVersion; 671 entries re-parsed on the after-run, all identical"
  - what: "Accept the catalogue digests and the tests as the proof, with no redo of the row digests (Jason)"
    why: "The row digests weren't comparable across VMs (non-deterministic map encoding); a redo cost about 40 minutes more"
    result: "Catalogue identical for 2,601 laws; one law's rows checked by hand"
metrics:
  stamps: { document_files: 47, catalogue_files: 2, build_extent_files_before: 41, build_extent_files_after: 5, feed_markup_extent_files_before: 33, after: 4 }
  fallback: { unstored_affecting_laws: 3126, with_text_held: 1287, built_laws_reached: 673, golden_unread_written: 88 }
  proof: { laws: 2601, catalogue_digests_identical: 2601, golden: "27/27", suite: 12644, enabling_reparsed_identical: 671 }
  stale_after: { builds_code_version: 1261, extent_reader: 924 }
lessons:
  - title: "Hash with term_to_binary(t, [:deterministic]) when comparing across VM runs"
    detail: "On this OTP a map's atom keys encode in atom-table order, which differs between runs, so the same rows hashed differently before and after. Only the map-free catalogue digest was comparable, and the 46-minute baseline couldn't be reused."
    tag: tooling
  - title: "Measure what is stored before splitting a stamp: here the catalogue's classifier was part of the reading"
    detail: "The plan assumed Patterns was catalogue-only. The stored reading runs Patterns.classes and Unread.withheld, so the real gain was the build's stamp (41 → 5 files), not the catalogue's."
    tag: tooling
  - title: "Tests can't reach the CLML store; give them a temporary root in a non-async module"
    detail: "The test config sets clml_store_dir to nil, so law_files and introductions are empty. Copy a fixture into a tmp root and put it in the app config."
    tag: tooling
  - title: "A cold extent pass, one law at a time, is 46 minutes, not 13"
    detail: "ReadCache.compute over 2,601 laws with no cache; plan corpus-wide cold reads at that cost, or run them in parallel after a system check."
    tag: tooling
artifacts:
  - backend/lib/sertantai_legal/scraper/amending_law/extent.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/reader.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/write.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/patterns/example.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_version.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_version/document.ex
  - backend/lib/sertantai_legal/scraper/amending_law/extent/read_version/catalogue.ex
  - backend/lib/sertantai_legal/scraper/enacted_by/introduction_xml.ex
  - backend/lib/sertantai_legal/scraper/enacted_by/enabling_cache/parser_version.ex
  - backend/lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/primary.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store/inputs.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/test/sertantai_legal/architecture/extent_read_stamps_test.exs
  - backend/test/sertantai_legal/scraper/enacted_by/enabling_cache_parser_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/store_inputs_unread_test.exs
  - docs/lat-change-pipeline/EXTENT-READER.md
depends_on:
  - 2026-11-23-extent-reader-readiness-review.md
enables:
  - "Extent reader: step procedures (its --stale lists the laws not read)"
  - "Waste, Water and Climate: Extent reader (the first write re-reads all 2,601 laws and fills the 1,287 not read)"
---

# Session: Extent reader: stamps that follow what changed (CLOSED)

## Problem

Any edit in `amending_law/extent/` puts every extent reading and every build on an old version. `Extent.ReadVersion` and `ChangeVocabulary.Version` both glob `extent/*.ex`, and that glob takes in the catalogue and tools (`Patterns`, `Credit`, `Sweep`, `ReadCache`, `Store`) and the stamp file itself. As of 2026-11-25, all 2,601 laws in `extent_rules` are on old versions and 768 builds are stale. Decided in the Extent reader readiness review (Decision 1, Jason 2026-11-25), on the pattern of the Commencement reader staleness session.

## Todo

- ✅ Measure (plan mode): the reach of the reading, the catalogue and the build's lookup; the stored-reading path; the fallback's reach; the parser's stamp
- ✅ Find: the baseline digests of every stored law's reading and catalogue output (2,601 laws, cold, ~13 min); golden's unstored affecting laws
- ✅ Fix: the struct / `Extent.Reader` / `Patterns.Example` / `Extent.Write` splits; three read stamps (Document, Catalogue, ReadVersion), each exact both ways
- ✅ Fix: the powers parser's version on `EnablingCache` (behind → re-parsed from the store, never fetched), its files in `Extent.ReadVersion`
- ✅ Fix: the build's stamp to the lookup: drop the fallback, "not read" a stale reason, Feed/Markup pattern versions trimmed
- ✅ Settle: digests identical, golden 27/27, an identical write only re-stamps, stamp moves by test, suite + Credo diff + Dialyzer green
- ✅ Docs: gotchas file, EXTENT-READER.md §3–§5 and §7, DATA-ARCHITECTURE `extent_rules`, WORKFLOW §5
- ✅ Close: step report in the terminal; parked bugs' notes; commits by path

## Dependencies

- ✅ Extent reader readiness review (closed 2026-11-25): `docs/lat-change-pipeline/EXTENT-READER.md`, `backend/lib/sertantai_legal/scraper/amending_law/extent/CLAUDE.md`
- Note: the step's first write re-reads all 2,601 laws anyway, so this session needs no extra re-read cycle. Its own proof can run on a few laws (`--amending A,B`).

## Measure (plan mode, 2026-11-25)

Plan: `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md` (approved). From the compiled code's module reach (`ModuleReach`):
- **The catalogue's classifier is part of the stored reading.** `extent_rules` stores `ReadCache.read` = `Extent.read` → `Patterns.classes` → `Unread.withheld`, so `Patterns` (classes), `Credit` and `Unread` are the reading. Outside it: only the catalogue's example code (`Patterns.example/read/key`), `Sweep`, and the tools (`ReadCache`, `Store`, `Check`, `Withheld`, `ReadVersion`). Few edits are catalogue-only.
- **The build:** `ChangeVocabulary.Version` holds 41 extent files. It reaches the whole reader only through the struct (`extent.ex` holds `%Extent{}` and `read/1`) and the fallback (`primary.ex:70`). With the struct as a stop, `Lookup` reaches 5 files.
- **The fallback:** 3,126 amending laws behind stored changes have no `extent_rules`. 1,287 of them have text held, so builds read them from text (673 built laws), and no stale reason sees them. A stored law always has a row (`none`: 1,586 laws), so "not read" is decidable.
- **The powers parser:** `EnablingCache` is 3,650 bare JSON lists with no version.

## Find: the baseline (2026-11-25)

- Script `scratchpad/baseline.exs` (no DB writes, no cache): per law in `extent_rules`, three digests: the reading's rows (`ReadCache.compute`), the catalogue output (classes, example, alone, uncaught), the stored form (`Powers.with_powers`, cached only). Run on the dev build before any move (`before.tsv`); the after run must match.
- Golden's laws use **88** affecting laws with text held and no `extent_rules`, read by the fallback today. They are written before the fallback goes (todo 5).
- The enabling cache copied before its format changed (`scratchpad/enabling-cache-before.tgz`, 3,650 files).

## Fix (2026-11-25)

- **Splits** (assertions unchanged, callers migrated, no delegate left in the struct):
  - `Extent.Reader` (`read/1`, `withheld/1`) out of `extent.ex`, which keeps the struct and the lookup delegates;
  - `Patterns.Example` (`example/1`, `read/2`, `key/2`) out of `Patterns`;
  - `Extent.Write` (`write_read/3`) out of `Extent.Store`;
  - `EnactedBy.IntroductionXml` out of `EnactedBy`, with a delegate left in `EnactedBy`.
- **Stamps** (`ExtentReadStampsTest`, exact both ways):
  - `ReadVersion.Document`: 47 files;
  - `ReadVersion.Catalogue`: `Example` and `Sweep`;
  - `ReadVersion`: Document, `Powers`, `StatedExtent` and the parser;
  - `EnablingCache.ParserVersion`: the cache, `EnablingProvisions` and `IntroductionXml`.

  `ReadCache` is keyed on Document + Catalogue.
- **Enabling cache entries** are `{"parser", "provisions"}`. A bare list, or an entry by another parser, is re-parsed from the introduction held, never fetched; where none is held, it is kept. `lat.scope` reads the cache through `cached/1`.
- **The build:**
  - the fallback is dropped from `Primary`;
  - `Store.unread/2` names the laws with text held and no rows, recorded as `extents_unread`;
  - `Store.Inputs.readers/3` gives `:extent_reader` for an unread law.

  `ChangeVocabulary.Version` lists 5 extent files (was 41). The Feed and Markup pattern versions list 4 (were 33).
- **Tests needing the CLML store** use a temporary root, not async (the test config disables the store): `StoreInputsUnreadTest`, `EnablingCacheParserTest`.

## Settle (2026-11-25)

- **Baseline against after-run, all 2,601 laws** (46 min each, cold, one law at a time):
  - the catalogue digests (classes, example, alone, uncaught) are **identical for every law**;
  - the row and stored-form digests can't be compared. The script hashed maps with `term_to_binary` without `:deterministic`, and on this OTP a map's atom keys encode in atom-table order, which differs between VM runs. One law was checked by hand, and its rows are right.
  - **Jason accepted the catalogue match and the tests as the proof** (no redo). Lesson: hash with `[:deterministic]`.
- **Enabling cache:** the 671 entries re-parsed on the after-run are identical to their old parse. The other 2,979 are still old-format lists, re-parsed on their next read.
- Full suite 12,644 passed; Dialyzer passed (23 skips, none new); Credo diff clean after `Reader.read/1`'s clause predicate was split out (complexity 13, moved with the function).
- Restore point `extent-stamps-golden` (extent_rules) before writing golden's 88 unread amending laws.
- Golden's 88 unread amending laws written (44 s). **Golden 27/27** from inputs; no golden build met an unread law.
- **An identical write only re-stamps:** HSWA 1974, SI 2008/1597 and SOCPA 2005, written twice. `read_at` was kept and the stamp moved to `c898982531fa`.
- **`lat.stale`:**
  - all 1,261 builds are stale on `code_version`: the build's stamp changed once, here, and the step rebuilds them all anyway;
  - `extent_reader` is 924 (768 before), because it now counts the laws not read.

## Docs changed

- `amending_law/extent/CLAUDE.md`: the stamps-and-cycles lines rewritten; new lines on the classes being the reading, on "not read", and on tests and the CLML store.
- `EXTENT-READER.md` §3, §4, §5.1, §5.5 and §7.
- `WORKFLOW.md` §5: the write covers the laws not read; the parser's stamp; a stamps paragraph.
- `DATA-ARCHITECTURE.md`: the `extent_rules` row.
- The `extent-reader-check` skill: the cache's key; the parser re-parses on read.
- The step-procedures session: its `--stale` todo includes the laws not read.

No new rule for RULES.md: a stamp is code, not a labelling rule.

## Step report

Given in the terminal (2026-11-25).
