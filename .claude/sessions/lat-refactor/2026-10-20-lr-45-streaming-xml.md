---
session: 'LR-45: Streaming XML Parse'
status: pending
opened: '2026-10-20'
parent: lat-refactor/2026-10-09-lr-00-meta.md
depends_on: ["lat-refactor/2026-10-15-lr-31-pipeline-performance"]
---

# Session: LR-45: Streaming XML Parse (PENDING)

## Problem

Every XML read goes through xmerl (SweetXml): 27 modules — the LAT parser (walker, text, ids, refs, effects), the amending-law reader (`AmendingLaw.Doc`, `DefinedTerms`, `RepealTable`), the commencement order reader, the changes feed, definitions, metadata. xmerl is slow and very memory-hungry (charlists, a heavy record per node, the scanner's state): parsing dominated the amending-law collector (LR-31: `xmerl_scan` 41% of 1988/52's collection), one law's amending documents peaked at ~3.3 GB, and a 5-wide parity run exhausted memory and crashed the machine (AR-03, 2026-10-20). LR-31 listed a streaming parser (option D: Saxy) and dropped it while parallelism and fewer parses were enough; AR-03's read-once pass removed the repeated parsing for amendments, but every parse and read still pays xmerl. Jason 2026-10-20: "create a new pending session for stream XML parse … Let's plan that too".

## Todo

- ⬜ Measure the baseline: time and peak memory per document for xmerl on a fixed set (the 10 largest amending laws; 10 large LAT laws' bodies + Schedules); where the time goes (scan vs xpath)
- ✅ Gemini review of the plan (2026-10-20, `backend/data/code-reviews/2026-10-20-lr-45-saxy-gemini.md`); accepted points below
- ⬜ Spike: `AmendingLaw.Doc` on a Saxy compact tree, the 10 largest amending laws — pass = `amendment_rules` diff 0, peak memory ≥ 5× lower, parse ≥ 2× faster; else re-plan before Phase 1
- ⬜ Phase 1: `AmendingLaw.Doc` (and `Text`, `DefinedTerms`, `RepealTable`) on the compact tree — gate: the read pass writes identical rules for **every** amending law, LR-08/41/43 and AR tests green; time and memory measured
- ⬜ Phase 2: the LAT parser (walker, text, ids, refs, effects, xml helpers) — gate: `mix lat.parse_snapshot --all` zero diff (LR-04's gate)
- ⬜ Phase 3, only if measured worth it: the commencement order reader, changes feed, definitions, metadata
- ⬜ Remove SweetXml / xmerl where nothing uses it; architecture note in scraper CLAUDE.md

## Options

| Option | What | Gain | Cost / risk |
|---|---|---|---|
| **A. Saxy compact tree** (chosen, as refined by the review below) | parse to compact tuples (binaries); call sites onto tree helpers, the xpath forms used onto a minimal adapter | memory ~5–10× smaller, scan several × faster | the adapter must match SweetXml's semantics exactly (document order, whitespace, namespaces) — the zero-diff gates catch any drift |
| **B. Saxy streaming handlers per reader** | SAX handlers build only what each reader needs (e.g. `Doc`: id → text / lines / title / quote paths) | the most speed and least memory | rewrites each reader; largest change |
| **C. Fragment parse** | parse only the provisions a note points to (amending laws) | small for the collector | the read pass already parses once; little left to gain there |
| **D. Cache derived artefacts** (LR-31 B) | store a compact `Doc` / parsed effects per document, keyed by content hash | repeated reads become loads | doesn't make the first parse faster; storage |

## Gemini review — accepted (2026-10-20)

- **A new compact tree, not xmerl-shaped records.** Saxy parses to `{tag, attrs, children}` with binaries; call sites move onto a small set of tree helpers (children in document order, text, lines, attribute, local name). Emulating xmerl records would rebuild much of the weight and tie the code to xmerl's internals. The 30 direct `{:xmlElement, …}` / `{:xmlText, …}` matches and 9 `xml_element(…)` uses are converted — finite and mechanical. Not taken: the "drop-in" reading of option A.
- **XPath:** SweetXml's xpath runs only on xmerl records, so the 55 `xpath(` calls move to a minimal adapter over the new tree covering only the forms used (`./@a`, `.//X`, `//ns:X/@a`, `local-name()`, unions, `self::` alternations, the one `ancestor::` + `[1]` form) — or are rewritten as tree helpers where simpler.
- **Semantic traps the gates must cover:** whitespace-only text nodes (xmerl keeps them; `text/1`, `lines/1` and any child counting must match exactly); namespaces and prefixes (`ukm:`, `dc:`) and `local-name()`; entity and character-reference decoding; parent and position information (`ancestor::`, `[1]` — the adapter passes the path from the root); attribute order (anything relying on `hd(attributes)`); CDATA, comments, processing instructions.
- **First spike** (above): the amending-law `Doc` only, the 10 largest amending laws, zero diff + ≥ 5× memory + ≥ 2× time.
- **Gates:** a transitional dual-parser mode (both parsers, the structured outputs compared) behind a switch; the **whole corpus per phase** (all ~1,867 amending laws for Phase 1, all ~1,066 LAT laws for Phase 2), never a sample, at the gate; for the LAT parser, intermediate artefacts (e.g. the walker's effects, refs) diffed as well as the final snapshot, to localise a divergence.

## Gemini review — not accepted / corrected

- *"The `parent` field makes a linked graph that stops GC"*: xmerl's `parents` is a list of `{name, pos}`, not pointers. The weight is charlists, a heavy record per node and the scanner's state — the conclusion (a compact binary tree) stands.
- *`fast_xml` wraps RapidXML*: it wraps Expat (C); either way a NIF and a C toolchain — Saxy (pure Elixir) kept unless the spike misses.
- Hybrid stream/DOM: not needed (the AR-03 read pass already parses each amending law once).

Saxy is not yet a dependency (SweetXml and Floki are); adding it is Phase 1's first commit.

## Gates (non-negotiable)

- Behaviour-preserving: `mix lat.parse_snapshot --all` zero diff (LAT); `amendment_rules` identical (amending laws); commencement rules identical (`commencement_rules` diff); full suite green.
- One law at a time in any corpus measure (memory; AR-03 crash); a 10-law pilot first; one whole-corpus run per phase (Jason 2026-10-19).
- A parser version change stales every law: Phase 2 lands with its own single restamp re-parse, nothing else in it.

## Dependencies

- ✅ LR-31 pipeline performance (parallel runs; option D recorded)
- ⬜ AR-03/AR-04 amendment ruleset switch-over first (Phase 1's gate uses the read pass)
