---
session: 'Extent reader: stamps that follow what changed'
status: pending
opened: 2026-11-25
---

# Session: Extent reader: stamps that follow what changed (PENDING)

## Problem

Any edit in `amending_law/extent/` puts every extent reading and every build on an old version. `Extent.ReadVersion` and `ChangeVocabulary.Version` both glob `extent/*.ex`, and that glob takes in the catalogue and tools (`Patterns`, `Credit`, `Sweep`, `ReadCache`, `Store`) and the stamp file itself. As of 2026-11-25, all 2,601 laws in `extent_rules` are on old versions and 768 builds are stale. Decided in the Extent reader readiness review (Decision 1, Jason 2026-11-25), on the pattern of the Commencement reader staleness session.

## Todo

- ⬜ Plan mode: the reach of each module (what the reading, the catalogue and the build's lookup call), measured from the code
- ⬜ `Extent.ReadVersion` becomes the reading's own reach, listed by name; a catalogue stamp for `Patterns`/`Credit`/`Sweep`; `ReadCache` keyed on both; the stamp test exact both ways (`CommencementReadStampsTest`, `StageSplitTest`)
- ⬜ The powers parser (`EnactedBy.EnablingProvisions`) stamped on the enabling cache, so a parser change stales the SIs it parsed
- ⬜ Split the mixed modules: `Powers` (pure placement apart from the cache and DB), `ReadCache` (the reading apart from the catalogue classes and the sweep); TDD, catalogue identical before and after
- ⬜ The build's stamp to the lookup only (Store and build's code, on Jason's go in the review): measure the fallback's reach (`primary.ex:70`), drop it (an unread law is a stale reason), and `ChangeVocabulary.Version` lists `Extent.Lookup` and the struct by name
- ⬜ Prove it: an identical write re-stamps only; a catalogue-only edit stales no reading; tests, the Credo diff and Dialyzer green
- ⬜ Close: the gotchas file and EXTENT-READER.md §4–§5 revised

## Dependencies

- ✅ Extent reader readiness review (closed 2026-11-25): `docs/lat-change-pipeline/EXTENT-READER.md`, `backend/lib/sertantai_legal/scraper/amending_law/extent/CLAUDE.md`
- Note: the step's first write re-reads all 2,601 laws anyway, so this session needs no extra re-read cycle. Its own proof can run on a few laws (`--amending A,B`).
