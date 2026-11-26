---
session: 'Amending-law reader: stamps that follow what changed'
status: closed
opened: 2026-11-26
closed: 2026-11-26
outcome: success
summary: >
  The Amending-law reader's stamps list their files by name, exact by reach (AmendmentReadStampsTest), and the build reads stored amendment rules only: a stale or never-read amending law is the new :amending_reader stale reason, so 23 reader files left the build's version. A re-read now writes only the amended laws whose rules changed.
  Golden's 596 amending laws were written first (74 changed, two edits both gains); golden is 27/27, the catalogue dry run unchanged, the suite and Dialyzer green.
decisions:
  - what: "ReaderVersion follows the read pass's reading (ReadLaw), not Amendment.Reader"
    why: "the stored rules are read through ReadLaw.rules/3, which reaches defined_terms, locator, pointer and four files no stamp held (read_law, provision_read, law_doc, amending_law/enacted)"
    result: "29 files by name; an edit to the four now stales the rules it can change"
  - what: "Drop the build's fallback; :amending_reader from the law's text amenders (stored rules' sources and the feed's amending laws on non-commencement changes)"
    why: "Primary.fresh_rules read 969 never-read and 1,828 stale amending laws from text on every build; the affecting list holds commencement orders, which are never indexed and would read stale for ever"
    result: "ChangeVocabulary.Version holds Rule, Store and Index of the reader; 834 of 1,261 builds name the reason until the step's write"
  - what: "Write golden's 596 amending laws before the drop (Jason: preview, then write)"
    why: "without the fallback, golden's 54 never-read amenders would give no rules and the 542 stale ones their 2026-11-15 rules"
    result: "74 changed, 1,183 rules added, 1 operation and 1 target changed (both gains from 5d1c188d); golden 27/27"
metrics:
  stamps: { reader_files_before: 25, reader_files_after: 29, missed_added: 4, unreached_removed: 0, catalogue_files: 29, build_amendment_files_out: 23 }
  fallback: { built_laws: 911, amenders_stale: 1828, amenders_never_read_held: 969, round_never_read: 738, golden_amenders_written: 596 }
  golden_write: { laws: 596, changed: 74, rules_before: 29671, rules_after: 30854, added: 1183, operation_changed: 1, targets_changed: 1 }
  proof: { golden: "27/27", catalogue_new: 0, catalogue_gone: 0, catalogue_differing: 0, suite: 12763, architecture: 53 }
  stale_after: { builds_code_version: 1261, amending_reader: 834, extent_reader: 75, commencement_reader: 4 }
lessons:
  - title: "A stamp's entry point is the stored reading's path, not the reader module"
    detail: "ReaderVersion followed Amendment.Reader, but the rules are read through ReadLaw.rules/3; four files on that path were in no stamp, and three listed were never reached by the reader. Measure reach from what writes the store."
    tag: tooling
  - title: "The feed's affecting laws include commencement orders, so they can't define an amending stale reason"
    detail: "Orders are never indexed by the read pass; taking the reason over Store.Inputs' affecting list would stale their builds for ever. The text amenders are the stored rules' sources plus the feed's by on non-commencement changes."
    tag: data
  - title: "The sandbox's now() is the transaction's"
    detail: "A test that a write keeps read_at passes before the fix, because every row's default now() is the same inside the test transaction; date the rows back first."
    tag: tooling
  - title: "A failed pre-commit hook leaves the paths staged"
    detail: "git commit -- <paths> with git add first stages them; on a hook failure they stay in the shared index. Unstage at once (git restore --staged) before fixing."
    tag: tooling
bugs:
  - pattern: "Shared amending-law document readers (amending_law/text.ex, doc.ex) sit in 5–8 reader versions, so an amendment-only reading change stales commencement and extent rules too: EP's two zero-diff re-reads of 798 laws cost about 25 min each, and one text.ex edit a corpus read, four commencement passes, four title searches and 27 fetches (change D, EP retrospective)"
    category: shared-reader-version-cascade
    module: "lib/sertantai_legal/scraper/amending_law/text.ex, doc.ex (and the reader versions that hash them)"
    affected: "narrowed 2026-11-26: no build stales through the amending reader; still the Commencement order reader and the catalogues, by whole file"
    fix: "split the shared files by the readers that use each function, so a stamp holds only what its reading calls"
    step: Amending-law reader
    status: open
artifacts:
  - backend/lib/sertantai_legal/scraper/amendment/reader_version.ex
  - backend/lib/sertantai_legal/scraper/amendment/catalogue_version.ex
  - backend/lib/sertantai_legal/scraper/amendment/text_effect.ex
  - backend/lib/sertantai_legal/scraper/amendment/index.ex
  - backend/lib/sertantai_legal/scraper/amendment/read_pass.ex
  - backend/lib/sertantai_legal/scraper/amendment/store.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/primary.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store/inputs.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/version.ex
  - backend/test/sertantai_legal/architecture/amendment_read_stamps_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/store_inputs_amending_test.exs
  - backend/data/reports/amending-reader/stamps/
  - docs/lat-change-pipeline/AMENDING-LAW-READER.md
  - docs/lat-change-pipeline/DATA-ARCHITECTURE.md
depends_on:
  - 2026-11-26-amending-law-reader-readiness-review
enables:
  - "Amending-law reader: step procedures (--read --stale --family over the :amending_reader laws)"
  - "Waste, Water and Climate: Amending-law reader (write 1 reads the round's 738 never-read and 527 stale amending laws)"
---

# Session: Amending-law reader: stamps that follow what changed (CLOSED)

## Problem

`Amendment.ReaderVersion` globs `amendment/reader/*.ex` and names shared files (`amending_law/doc.ex`, `text.ex`, `lat_ref.ex`, `territory.ex`), with no exactness test, so any edit stales all 2,627 amending laws: two Commencement reader edits to `lat_ref.ex` (2026-11-21) did. The build re-reads stale amenders from their text (`Primary.fresh_rules`), so `ChangeVocabulary.Version` holds the whole reader and any reader edit stales every build. Decided: Amending-law reader readiness review, Decision 1 (Jason 2026-11-26), (a) + (b) + (d).

## Todo

- ✅ 1. Measure: the reader's and read pass's reach (`ModuleReach`); the fallback's reach (stale and never-read amenders per built law, the round and switched families); a preview of every amender against stored rules (Jason's go)
- ✅ 2. Exact stamps, test first: `AmendmentReadStampsTest` holds `ReaderVersion` and `CatalogueVersion` to their reach both ways; lists by name
- ✅ 3. Split where the stamp's line runs: `Index` read apart from write; `ReadLaw.text_effect?` to a pure module; `ReadPass`/`ReadLaw` IO apart as needed (defdelegate)
- ✅ 4. Write only what changed, by (source law, amended law): unchanged keeps `read_at`
- ✅ 5. Drop the build's fallback: stored rules only; `:amending_reader` stale reason in `Store.Inputs`; `lat.stale` counts it; `ChangeVocabulary.Version` by reach (golden's never-read amenders written first, if any)
- ✅ 6. Proof: golden 27/27; catalogue dry run 0 changed; suite, Credo diff, Dialyzer; stale counts before and after
- ✅ 7. Close: docs (spec §3–§5, gotchas, scraper CLAUDE.md, DATA-ARCHITECTURE); the shared-document-readers bug; commits by path; report

## Dependencies

- ✅ Amending-law reader readiness review (2026-11-26)

## Plan (approved 2026-11-26)

`~/.claude/plans/gleaming-doodling-matsumoto.md`. Correction to the review: 6d7f44ce changed `LatRef.covers?`, which the reader calls (`reader/new_numbers.ex:47`), so that stale was real; the gain is the stamp's unreached files, the build's re-reading, and re-reads that change nothing staling no build.

## 1. Measure (2026-11-26)

- **Reach** (`ModuleReach`, a scratch test, deleted; stops at IO and every stamp):
  - `Amendment.Reader` reaches 22 files, all in `ReaderVersion` (25). The 3 extra, `defined_terms.ex`, `locator.ex` and `pointer.ex`, are the read pass's, reached through `ReadLaw.rules/3`.
  - `ReadLaw` also reaches `read_law.ex`, `provision_read.ex`, `law_doc.ex` and `amending_law/enacted.ex`, which `ReaderVersion` misses: an edit to them stales no stored rule today. So the stamp's entry is the read path (`ReadLaw.rules/3`), not `Reader`.
  - `CatalogueRead` reaches 30 files; `CatalogueVersion` lists itself and misses `catalogue_cache.ex`.
  - `Index` reaches the whole reader (its `write` calls `Reader.references/parts`); the build reaches it through `Primary`.
- **The fallback's reach.** These are the text changes' amending laws (feed `by` on non-commencement changes, plus the stored rules' sources) for the built laws:

  | | Built laws | Indexed (stale) | Never read, text held | No text held |
  |---|---|---|---|---|
  | The round | 385 | 527 | 738 | 377 |
  | Switched families | 401 | 1,325 | 214 | 520 |
  | Other | 125 | 715 | 68 | 1,520 |
  | Golden's laws | 24 | 542 | 54 | 656 |
  | All | 911 | 1,828 | 969 | 1,866 |

  Every build reads the 969 never-read laws, and the stale ones, from their text. Dropping the fallback leaves the never-read laws with no rules, and the stale ones on their 2026-11-15 rules, until a write. So golden's 596 amending laws (542 + 54) are written first.

## 2–5. The code (2026-11-26)

- **Commit `74d7b8ed`** (hooks passed; the first try failed on format and left files staged, unstaged at once):
  - `ReaderVersion` and `CatalogueVersion` list files by name; `AmendmentReadStampsTest` holds them to `ReadLaw`'s and `CatalogueRead`'s reach both ways. `ReaderVersion` gains `read_law`, `provision_read`, `law_doc`, `amending_law/enacted` and keeps 25 (29 in all).
  - `VersionCoverageTest` stops at a stamp's own file too.
  - `TextEffect` split out of `ReadLaw`; `Index.write` takes entries from `ReadPass.index_entries/1`, so `Index` reaches no reading code.
  - `Store.write_changed` replaces only the amended laws whose rules differ (`store_test`, rows dated back because the sandbox's `now()` is fixed).
- **Golden's 596 amending laws written first** (Jason's go). Restore point `amending-stamps-before-golden-write` (`amendment_rules`, `extent_rules`) and the index tar `backend/data/reports/amending-reader/stamps/amendment-index-before-golden-write.tgz`. Preview: 74 changed, rules 29,671 → 30,854, and the field diff shows 1,183 added, 1 operation and 1 target. Both are gains from `5d1c188d`:
  - SSI 2011/207 reg.3: the quote's new numbers are inserted;
  - SSI 2009/319 Sch.3: the repeal is on s.84(2)(a), (b), not s.84.

  The write matched the preview (74 changed).
- **The fallback dropped:**
  - `Primary` takes stored rules only;
  - `Store.Inputs.readers/3` gives `:amending_reader` (`store_inputs_amending_test`: commencement-only affecting laws are no reason);
  - `ChangeStaleness` and `lat.stale` carry the reason and its fix line;
  - `ChangeVocabulary.Version` lists only `Rule`, `Store` and `Index` of the reader, and `doc`, `list_items`, `extent`, `pointer`, `ref_list`, `sub_path` of `amending_law/` (23 files out, `text.ex` among them);
  - `VersionTest` now asserts the reader is not in the build's version.

## 6. Proof (2026-11-26)

- Golden 27/27 from inputs (`stamps/golden.txt`, 4 m 18 s).
- Catalogue dry run over the 527 switched-family laws (1,436 amending laws, cold, 364 s): 0 new patterns, 0 gone, 0 examples reading differently.
- Architecture 53/53; targeted suites (amendment, architecture, change vocabulary, mix) 4,843 + the VersionTest fix; Credo diff no new issues.
- `lat.stale` after: 1,261 of 1,261 builds stale on `code_version` (the build's version moved, as planned; the step rebuilds). `amending_reader` 834, `extent_reader` 75, `commencement_reader` 4.
- The 768 amending laws `extent_reader` names were on older Extent code before this session (reader versions `d7e273cc45de` and older, last read 2026-11-15 or earlier, 17 on 2026-11-26 06:43). This session touched no Extent file. They are other families' laws; the step's `--stale` write covers the ones the round reaches.

## 7. Close (2026-11-26)

- **Docs changed:** AMENDING-LAW-READER §3–§5 and §7; `amendment/CLAUDE.md` (5 gotchas revised or added); `scraper/CLAUDE.md` (the 2026-10-25 "speed, not correctness" note replaced); DATA-ARCHITECTURE (`amendment_rules` readers, the `amending_reader` reason, the stamps paragraph).
- **Parked bug, shared-reader-version-cascade** (2026-11-12): left open, narrowed. The build no longer reaches `text.ex`, `operation.ex` or `schedule_refs.ex`, so a shared edit stales no build through this reader. But every stamp counts whole files, and `text.ex` is reached by the Commencement order reader and the catalogues too. So an amendment-only edit there still stales their readings. Fixing that would split the shared files by reader use (Sources/Commencement code too), which this session did not do.
- **Suite** 12,763 passed, 0 failures; Dialyzer passed (`stamps/suite.txt`, `dialyzer.txt`).
