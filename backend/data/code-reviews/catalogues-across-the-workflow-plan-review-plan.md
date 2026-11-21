# Catalogues Across the Workflow plan: review (Fable `reviewer`, standard `plan`, 2026-11-21)

Document: `catalogues-across-the-workflow-plan.md`. Paths under `backend/`.

## The proof run exists for two of six catalogues — Blocker
- Where: "The changes" intro; "Proof, per change".
- Finding: the proof is "a dry run without `--accept`", but only `lat.order_patterns` and `lat.commencement_patterns` use `CommencementCatalogue.Target`.
  - Feed, markup, extent and amendment have `dir = opts[:out] || @dir` (e.g. `lib/mix/tasks/lat.amendment_patterns.ex` `run/1`), so a run without `--accept` overwrites the generated fixtures.
  - `lat.amendment_patterns` raises without a scope; `amending-reader-check/SKILL.md:55` warns "a `--family` run replaces the fixture".
  - Changes 1 and 4 have no stated proof command or law set.
- Fix: the exact command per catalogue (`--out DIR` with the fixtures copied in, as `extent-reader-check/SKILL.md:39`, or extend `Target`), and the `--laws` set for amendment.

## Order catalogue: four choices left to the builder — Blocker
- Where: change 2.
- Finding:
  - (a) "`pairs/1`, unchanged" still parses serially: `commenced/2` calls `doc(order)` and `act/1`, with one `uk_lrt` query per Act and a `doc(law)` fallback. That contradicts "the order's one `Doc`", and it runs before any cache hit.
  - (b) The cache inputs include the Act's title, but only reach and ids get grouped queries.
  - (c) "each unit's example built alone" conflicts with "as `LawScan.scan/3`", which builds only those a law alone would take; the choice sets the cold time and whether mismatch and too_large counts match today's.
  - (d) A raising order today goes to `unclassified`; `LawRunner.ordered/3` has no rescue. The error shape, and whether errors are cached, are unstated.
- Fix: decide each; name the file paths for `OrderCatalogue.LawRead` and `Version`, and whether the task gains `--workers` and `--no-cache`.

## Run record undefined for half the catalogues — Blocker
- Where: change 1.
- Finding:
  - `Extent.ReadCache.law/2` returns `reading() | nil`, so extent has a cache but no hit/read signal.
  - Cold/warm/mixed is undefined when `hits` is nil.
  - After change 3, commencement has two caches.
  - Unsaid: whether scoped runs (`--laws`, `--orders`, `--out`, `--no-cache`) append; the record has no scope field; `CatalogueRun`'s file path.
- Fix: state each, including whether `Extent.ReadCache` changes (another step's code).

## The machinery test cannot be built as described — Blocker
- Where: change 6; Out of scope.
- Finding:
  - `test/support/module_reach.ex` reads the beam atoms chunk: module-level reach, no functions or arities.
  - The feed, markup and commencement tasks reference `CatalogueCache.summary`; `fetch` sits in their `LawRead` modules.
  - The list is "the six above" in change 6 but takes in four more scans "with their status", none given.
- Fix: the mechanism (reach from the task file to the three modules) and the full list with each exception's reason.

## Amendment cache thrashes across scopes — Major
- Where: change 4.
- Finding:
  - The task runs per family or `--laws`; with `by_law` in the key and one cache file per law, alternating scopes overwrite each other.
  - `{:error, msg}` would be cached.
  - `ReadLaw.law_ref/1` runs two queries per amended law (`amendment/read_law.ex:105`).
- Fix: decide the key, error caching, and where `law_ref` is computed.

## Merge cache placement — Major
- Where: change 3.
- Finding:
  - `merge_law/4` is private in `LawScan` ("Pure but for the reader it calls"), and the plan doesn't say where the fetch goes.
  - Editing `law_scan.ex` stales `CommencementCatalogue.Version`: a 438 s cold run not listed.
- Fix: name the module holding the fetch; list the cold run.

## No run list — Major
- Where: Proof, per change.
- Finding: cold then warm per change is about 30 min for change 1 alone, plus version-staled runs for changes 2–4. There is no purpose, time and writes list, and none is marked "ask Jason first".
- Fix: add the table.

## No named tests — Major
- Where: "Each change is test first".
- Finding: no test file, case or fixture is named for `CatalogueRun`, `OrderCatalogue.LawRead`, the merge cache or the amendment cache.
- Fix: name the normal and edge cases (nil hits, a raising order, a dropped example freeing a slot).

## Recorded times disagree with their source — Nit
- Where: "Where each catalogue stands".
- Finding: "228 s warm, 170 s merge (#195)", but `WORKFLOW.md:638` says warm 104 s (from 228 s), merge about 30 s.
- Fix: quote the source as written.
