---
session: 'Amending-law reader: stamps that follow what changed'
status: pending
opened: 2026-11-26
---

# Session: Amending-law reader: stamps that follow what changed (PENDING)

## Problem

`Amendment.ReaderVersion` globs `amendment/reader/*.ex` and names shared files (`amending_law/doc.ex`, `text.ex`, `lat_ref.ex`, `territory.ex`), with no exactness test, so any edit stales all 2,627 amending laws: two Commencement reader edits to `lat_ref.ex` (2026-11-21) did. The build re-reads stale amenders from their text (`Primary.fresh_rules`), so `ChangeVocabulary.Version` holds the whole reader and any reader edit stales every build. Decided: Amending-law reader readiness review, Decision 1 (Jason 2026-11-26), (a) + (b) + (d).

## Todo

- ⬜ Measure: what each stamp's reading uses (by name); the fallback's reach (amenders read from text per build, by family); `read_at` kept on unchanged rules (`Store.write_changed`)
- ⬜ `ReaderVersion` by name, held exact both ways by a test (as `ExtentReadStampsTest`); `CatalogueVersion` apart from the tools
- ⬜ Shared document code stamped by what each reader's reading uses, so a commencement-only edit stales no amender (the parked shared-document-readers bug)
- ⬜ Split `ReadPass` and `ReadLaw` where they set the stamp's line (pure reading apart from DB, feed and file IO)
- ⬜ Drop the build's fallback (Store and build's code, on Jason's go): an `:amending_reader` stale reason in `Store.Inputs`; `ChangeVocabulary.Version` drops `amendment/*.ex`, `reader/*.ex`; reverses the 2026-10-25 choice in `scraper/CLAUDE.md`
- ⬜ Proof: catalogue digests and a preview over every amender unchanged (hash with `[:deterministic]`); golden 27/27; suite, Credo diff, Dialyzer
- ⬜ Docs: AMENDING-LAW-READER §3–§5, the gotchas, `scraper/CLAUDE.md`, DATA-ARCHITECTURE

## Dependencies

- ✅ Amending-law reader readiness review (2026-11-26)
