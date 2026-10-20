---
session: 'LR-45: Streaming XML Parse'
status: pending
opened: '2026-10-20'
parent: lat-refactor/2026-10-09-lr-00-meta.md
depends_on: ["lat-refactor/2026-10-15-lr-31-pipeline-performance"]
---

# Session: LR-45: Streaming XML Parse (PENDING)

## Problem

Every XML read goes through xmerl (SweetXml): 27 modules — the LAT parser (walker, text, ids, refs, effects), the amending-law reader (`AmendingLaw.Doc`, `DefinedTerms`, `RepealTable`), the commencement order reader, the changes feed, definitions, metadata. xmerl is slow and very memory-hungry (records with parent chains, charlists): parsing dominated the amending-law collector (LR-31: `xmerl_scan` 41% of 1988/52's collection), one law's amending documents peaked at ~3.3 GB, and a 5-wide parity run exhausted memory and crashed the machine (AR-03, 2026-10-20). LR-31 listed a streaming parser (option D: Saxy) and dropped it while parallelism and fewer parses were enough; AR-03's read-once pass removed the repeated parsing for amendments, but every parse and read still pays xmerl. Jason 2026-10-20: "create a new pending session for stream XML parse … Let's plan that too".

## Todo

- ⬜ Measure the baseline: time and peak memory per document for xmerl on a fixed set (the 10 largest amending laws; 10 large LAT laws' bodies + Schedules); where the time goes (scan vs xpath)
- ⬜ Decide the approach (options below) — Jason; Gemini review of the plan
- ⬜ Phase 1: `AmendingLaw.Doc` on the new parser behind its existing API (`element/2`, `text/1`, `lines/1`, `title/2`, `ids`, `elements`) — gate: the read pass writes identical rules for every amending law (`amendment_rules` diff = 0), LR-08/41/43 and AR tests green; measure time and memory
- ⬜ Phase 2: the LAT parser (walker, text, ids, refs, effects, xml helpers) — gate: `mix lat.parse_snapshot --all` zero diff (LR-04's gate)
- ⬜ Phase 3, only if measured worth it: the commencement order reader, changes feed, definitions, metadata
- ⬜ Remove SweetXml / xmerl where nothing uses it; architecture note in scraper CLAUDE.md

## Options (to decide)

| Option | What | Gain | Cost / risk |
|---|---|---|---|
| **A. Saxy SimpleForm behind an adapter** | parse to compact tuples (binaries, no parent chains); a small adapter gives the xpath subset the code uses (`//X`, `./X`, `local-name()`, attributes, text) so call sites barely change | memory ~5–10× smaller, scan several × faster | the adapter must match SweetXml's semantics exactly (document order, whitespace, namespaces) — the zero-diff gates catch any drift |
| **B. Saxy streaming handlers per reader** | SAX handlers build only what each reader needs (e.g. `Doc`: id → text / lines / title / quote paths) | the most speed and least memory | rewrites each reader; largest change |
| **C. Fragment parse** | parse only the provisions a note points to (amending laws) | small for the collector | the read pass already parses once; little left to gain there |
| **D. Cache derived artefacts** (LR-31 B) | store a compact `Doc` / parsed effects per document, keyed by content hash | repeated reads become loads | doesn't make the first parse faster; storage |

Leaning: **A first** (one adapter, mechanical call-site changes, strong gates), **B** only for a hot path A leaves slow. Saxy is pure Elixir, streaming-capable, no NIF; not yet a dependency (SweetXml and Floki are).

## Gates (non-negotiable)

- Behaviour-preserving: `mix lat.parse_snapshot --all` zero diff (LAT); `amendment_rules` identical (amending laws); commencement rules identical (`commencement_rules` diff); full suite green.
- One law at a time in any corpus measure (memory; AR-03 crash); a 10-law pilot first; one whole-corpus run per phase (Jason 2026-10-19).
- A parser version change stales every law: Phase 2 lands with its own single restamp re-parse, nothing else in it.

## Dependencies

- ✅ LR-31 pipeline performance (parallel runs; option D recorded)
- ⬜ AR-03/AR-04 amendment ruleset switch-over first (Phase 1's gate uses the read pass)
