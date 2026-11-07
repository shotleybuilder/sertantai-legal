# Pipeline scaling: run times and stale records as families grow

Design review before Environmental Protection (family 3), 2026-11-07. Jason's question: what does adding families do to overall run times, and does corpus-wide staleness after a code change become a problem with more laws?

## Problem

The LAT Change Pipeline has switched over two families of 51:
- Occupational Health & Safety: 149 laws with LAT rows, 20,556 rows;
- Maritime Safety: 117 laws, 24,777 rows.

That is 23% of the 1,167 laws holding LAT rows (395,197 rows), and 11% of the rows. Environmental Protection is next: 395 live laws, 59 with rows today. Maritime grew from 16 to 117 laws with rows at its Making laws step, so expect growth. Big families are still to come: Energy (32 laws, 31,450 rows), Water (56, 26,751), Town & Country Planning (26, 26,513).

**Staleness.** Each stored build carries a code version (`provision_changes.code_version`, `changes_built` events), a SHA-256 of the source files the version covers (`scraper/source_version.ex`). `mix lat.stale` reports built laws whose version or inputs moved (lat_rows, law_text, feed, amendment/commencement/extent rules).
- **Any edit to a covered file marks every built law stale**: today all 285 laws, whatever family the edit was for. Example: in the Maritime switch-over, `label_switch.ex`, `known_limits.ex` and `feed.ex` each staled all 285, giving four full rebuilds in one step at about 14 min each (session `…maritime-safety-switch-over.md:50-51`).
- Edits that only touch the label fold or measures also staled every build (label-fold, measures sessions). Editing `version.ex`'s own `except:` list does the same.
- There is no stale-only rebuild. The fix is `mix lat.vocabulary --build`, scoped by `--law`, `--laws`, `--family` or `--golden`, after reading `lat.stale --list` by hand.

**Silent staleness** (not caught by any check):
- **S1.** Switched labels (`lat_label_timeline`): `LabelStaleness` has no changes-version reason, and change staleness is outside `lat.stale --strict` (parked bug `switched-labels-staleness`, all 149 OH&S laws then, every switched law now). A switched family could serve labels from older changes.
- **S2.** `commencement_rules` and `extent_rules` carry only `read_at`, no reader version. The build fingerprints them by `max(read_at)`, so a reader code change does not stale them. A stale extent reading surfaced only as an extent-check "our fault".
- **S3.** A version's file list is a compile-time wildcard. A new file matching it is left out of the hash and of `VersionCoverageTest` until the version module recompiles (parked bug `version-wildcard-stale`; it hid four files from `Extent.ReadVersion`).
- **S4.** `provision_changes` holds 281 built laws, while `lat.stale` and the docs say 285. Unexplained.

**Run times** fall into three kinds:

| Kind | Examples (recorded) | Grows with |
|---|---|---|
| A family's own steps | sources 2 min 43 s; merge 37 s; family build 117 laws in 39 s; `--check` plus gates about 15 min | that family; bounded by its biggest Act |
| Whole-store catalogues | feed patterns about 8–10 min and markup patterns about 16 min (both one law at a time); commencement about 12 min; extent about 10½ min cold; amending-law read pass 10 min; store scan 70 s; extent shapes 126 s | everything fetched so far; about 1 h a round |
| Rebuild of every built law | 285 laws in 232–241 s (13–14 min before #191) | every family built so far |

- The rebuild's wall time is one law, the Environmental Protection Act 1990, at 229 s. The fold costs rows × changes per law.
- `LawRunner.Guard` runs at most 4 laws at once, budgeting 1.8 GB a law with a 6 GB reserve. That budget was set before #191 cut the fold's memory.

**Issues:** item 2 → #193; items 1, 3, 5 → #194; item 4 → #195.

## Goals and non-goals

**Goals:**
1. A code edit costs a rebuild only of what it can change.
2. No stored record can be out of date without `lat.stale --strict` saying so.
3. The whole-store catalogues cost what changed, not the whole store, on a re-run.
4. The rebuild of every built law stays within minutes up to all 51 families.

**Non-goals:**
- Any change to what a reader, the fold or a check outputs. Every item is behaviour-preserving, proved by golden from inputs and byte-equal outputs.
- Production deployment of the label pipeline.

## Proposed items

1. **Automatic stale rebuild, run once per fix round.** The tool: `lat.vocabulary --build --stale` rebuilds exactly what `lat.stale` lists (with item 3, stage by stage), so no one builds a law list by hand. The practice it enables, written into `RULES.md`: during a step, gates and checks run on the family's own laws (`--laws` or `--family`). Earlier families are rebuilt once per fix round, before the round's regression gates, never after each edit. The rule stays after item 3, because a reader fix still re-runs the readers for every built law.
2. **Close silent staleness (S1–S4).** S1: add a `:changes_version` reason to `LabelStaleness` and count it in `--strict`. S2: stamp `commencement_rules` and `extent_rules` with their reader's version, and add it to the build's input fingerprint. S3: `__mix_recompile__?/0` in `SourceVersion` that compares the wildcard with the compiled list. S4: explain the gap, then fix it or record it.
3. **Split the version by stage.** Today one `ChangeVocabulary.Version` covers the readers, merge, evidence and the parts of the fold reached through it. Split it into stage versions (the readers' changes; merge and evidence; the label fold), each stamped where its output is stored. **A stage's output is stale when either its own code version moved, or the digest of its inputs (upstream outputs plus source files) moved.** Its own code change always re-runs it, for every law, regardless of digests. What the digest gate saves is the cascade: a stage whose code is unchanged and whose input digest is unchanged is a deterministic function of the same arguments, so it cannot produce a different output. A fold-only edit then re-folds stored changes and never re-reads; a reader fix that changes no law's changes re-runs the readers but stales nothing downstream. The rebuild orchestration is automatic: `--stale` (item 1) walks the stages in order, rebuilding each stale stage and re-checking downstream digests.
4. **Incremental and parallel whole-store catalogues.** Cache each file's catalogue result keyed by the file's digest and the catalogue's `SourceVersion` (a hash of the catalogue module and every module it reaches, held to that by `VersionCoverageTest`), as `Extent.ReadCache` and `FeedCache` already do. A re-run reads only changed files. Run the feed and markup catalogues in parallel under `LawRunner.Guard`, so the closure-copy rule holds.
5. **Re-measure the parallel budget.** Measure peak memory a law after #191 (the heaviest 10 laws), and set `LawRunner.Guard`'s budget from it under the 14 GB cap.

## Alternatives considered

**For staleness (items 2 and 3):**
- **A. Keep one version.** Simple, and it never misses a dependency. But its cost grows with every family: four full rebuilds in one Maritime step. Rejected as the long-term design, kept as the fallback.
- **B. Per-law dependency tracking:** record which modules or reader forms each law's build exercised, and stale only laws whose exercised code changed. This is the most precise option, but it needs call tracing or a form inventory per law, a fragile recorded set, and a missed dependency means silent staleness, against goal 2. Rejected.
- **C. Rebuild in shadow and re-stamp if equal:** after a code change, rebuild, and re-stamp laws whose output is unchanged. It is correct, but it pays the full rebuild cost every time. It is what item 3's digest gate does between stages, so it is folded into 3, not used alone.
- **D. Serve stale, rebuild lazily or nightly.** This lowers working time but breaks goal 2 (the time-machine aim needs correct labels), and stored-change scoring has already misled once (27/27 stored, while RTA s.4(6) failed from inputs). Rejected.
- **E. Finer versions per module** (one version per reader file). Many small versions, a coverage test each, and a cross-module change still hits several. More bookkeeping than stage splits for little gain. Rejected in favour of stage boundaries, which match where outputs are stored.

**For the catalogues (item 4):**
- **A. Scope catalogues to the family.** Cheap, but the catalogues exist to find forms across the corpus; a family-only run misses a form shared with an earlier family. Rejected.
- **B. Parallelise only.** It divides the hour by the worker count, but every round still re-reads the whole store. Taken together with caching, not alone.
- **C. A cache keyed by digest and version.** The pattern is already proved twice in the code (`ReadCache`, `FeedCache`). Chosen.

**For the rebuild (items 1 and 5):** waiting for more hardware was rejected. The wall time is one Act (229 s), so more workers don't cut it; only items 1 and 3 cut how often it runs.

## What good looks like (measured before and after)

- A fold-only edit stales 0 built changes, and only the labels.
- A no-op reader edit (a comment) stales nothing past the readers' stage.
- `lat.stale --strict` fails on a planted stale switched label, a planted stale extent rule, and a planted new file under a version's wildcard (one test each).
- A second catalogue run with no file changes takes seconds; outputs are byte-equal to today's.
- Golden from inputs is unchanged at 27/27, and every built law's stored changes are byte-equal after the split.
- The 4-at-once budget is set from measured peaks, and the rebuild of 285 laws is under 4 minutes.

## Risks and limits

- **The split (item 3) is the big one.** A missed edge between stages is silent staleness. Mitigations: keep `VersionCoverageTest` per stage version, and run one full rebuild comparing digests after the split.
- Content digests need stable outputs: stored changes must serialise in a fixed order. This has to be checked first.
- The catalogue cache adds disk. The extent cache is the guide to its size.
- Backing out: each item is code. The rebuild after the split writes `provision_changes` and `lat_label_timeline`, so take a restore point of those tables first.

## Open questions (decided)

1. Item 3 before Environmental Protection? **Decided (Jason, 2026-11-07): all five items are fixed before Environmental Protection.**
2. Item 1's rule into `RULES.md`: yes, with the `--stale` tool (see Gemini triage 3).

## Review: Gemini (design standard), triage

Report: `backend/data/code-reviews/2026-11-07-pipeline-scaling-design-gemini.md`.

| # | Finding | Triage |
|---|---|---|
| 1 | Content digest gate risks silent staleness when upstream logic changes but output doesn't (Major) | **Contested, with a clarification taken.** Each stage is stale on its own code version, so a logic change always re-runs the stage it is in. A downstream stage with unchanged code and an unchanged input digest computes a function of the same arguments, so its output cannot differ. The finding's own fix (stage code version plus digest) is the design; item 3 now says so in so many words. |
| 2 | Catalogue cache key must hash the catalogue's code, not a static version (Major) | **Taken.** Item 4 now names `SourceVersion` and `VersionCoverageTest`. |
| 3 | Item 1 relies on a human rule (Major); keep it out of `RULES.md` (open question 2) | **Taken in part.** `--stale` automates which laws to rebuild and in what order, and item 1 now leads with the tool. Contested on `RULES.md`: even after item 3, a reader fix re-runs the readers for every built law, so when to rebuild stays a choice; the rule records it. |
| 4 | 281 vs 285 built laws unexplained (Nit) | **Taken.** It is S4 in item 2. |
