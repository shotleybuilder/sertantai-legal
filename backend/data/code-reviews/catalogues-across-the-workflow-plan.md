# Catalogues Across the Workflow: plan, r2 (2026-11-21)

Session: `.claude/sessions/lat-change-pipeline/2026-11-21-catalogues-across-the-workflow.md`. Paths under `backend/` unless shown.

- **r1** was reviewed by the Fable `reviewer` against `plan` and `zoom-out` (`…-plan-review-plan.md`, `…-plan-review-zoom-out.md`). Every finding is Taken.
- **r2** settles each open choice.
- **Jason (2026-11-21):**
  - r1 was "back-to-front": it sped warm runs and left the slow cold ones. Go on with the written plan, and tackle cold runs too, in their own pending session, "Catalogue Cold Runs", which starts from this session's profiled cold runs.
  - Steps don't own their code in a meta session, so the changes go across steps, test first.

## The problem

Each step's pattern catalogue reads every law held and classes its forms against fixtures. The step re-runs it at Find, at Settle, and with `--laws` after a fix.

The shared machinery:
- `LawRunner.ordered/3` and `LawRunner.run/4` read laws in parallel, at most 4 (`LawRunner.Guard`);
- `CatalogueCache.fetch/6` keeps each law's result under `data/cache/catalogues/<catalogue>/<law>.bin`;
- the key is the catalogue's code version (`SourceVersion`) and a digest of the law's inputs.

| Catalogue | Step | Parallel | Kept between runs | Recorded times (source, as written) |
|---|---|---|---|---|
| `lat.feed_patterns` | Feed reader | yes | yes | about 2½ min cold, about 4 s warm (`WORKFLOW.md:128`) |
| `lat.markup_patterns` | Markup reader | yes | yes | about 5½ min cold, 5 s warm (`WORKFLOW.md:187`); "each cold run took about 25 min, not #195's 329 s" (`WORKFLOW.md:202`) |
| `lat.commencement_patterns` | Commencement reader | yes; then a serial merge | yes | 104 s warm (from 228 s), the merge about 30 s (`WORKFLOW.md:637`); 438 s cold, 93 s warm, `merge:` 70 s (2026-11-21) |
| `lat.order_patterns` | Commencement reader | **no** | **no** | 96 s, 1,129 orders (2026-11-21); "about 30 s" (`WORKFLOW.md:239`, undated) |
| `lat.extent_patterns` | Extent reader | yes | yes (`Extent.ReadCache`, shared with the extent check) | 7 min 41 s and 7 min 54 s (step sessions); "~5 min cold, seconds warm" (its skill) |
| `lat.amendment_patterns` | Amending-law reader | yes | **no** | 6 min for 527 laws (a step session) |

No session records cold, warm and serial side by side. Change 1 fixes that, and its first runs are the profiles the cold-run session starts from.

**A shared store of parsed documents is ruled out.** For 20 amending laws, `Doc.new` from CLML took 5.7 s; loading the stored `%Doc{}` took 6.8 s, at 30 MB against 1.7 MB of CLML. Only small derived results are shared across steps, as `Commencement.ClmlRows` is. No new sharing is proposed (r1's change 5 is dropped).

**Out of scope:**
- what any reader reads;
- the fixtures (no `--accept`);
- the cold-run work, which belongs to "Catalogue Cold Runs";
- the other whole-store scans (`lat.extent_sweep`, `lat.extent_census`, `lat.extent_shapes`, `lat.store_scan`).

r1's change 6, the machinery test, is dropped. `ModuleReach` follows modules, not functions, and a hand-kept task list catches no new catalogue. The rule goes in WORKFLOW instead, and the run log shows a catalogue with no cache (its `hits` is nil).

## Change 1: every catalogue writes a dry run by default, and records its run

### 1a. One dry-run target for all six

- `CommencementCatalogue.Target` moves to `lib/sertantai_legal/scraper/catalogue_target.ex`, as `SertantaiLegal.Scraper.CatalogueTarget` (unchanged `dirs/3` and `notice/1`). Its two callers move to it.
- Feed, markup, extent and amendment today write `opts[:out] || @dir`, so a run without `--accept` overwrites the fixtures (`WORKFLOW.md:285`).
- Each now takes `CatalogueTarget.dirs(opts, @dir, @dry_run_dir)`:
  - it writes the generated files to `target.write`;
  - it reads the held files it compares against (`expected.json` and the reviewed statuses) from `target.held`.
- Each `@dry_run_dir` is `data/reports/catalogues/dry-run/<catalogue>`.
- Each task's `--accept` keeps its present meaning.
- **Tests:** `catalogue_target_test.exs` covers `dirs/3`:
  - no option gives a dry run;
  - `--accept` writes the fixtures;
  - `--out` writes and holds to `DIR`.

  Each task's fixture test (`FeedPatternsTest`, `MarkupPatternsTest`, `ExtentPatternsTest`, `AmendmentPatternsTest`) is unchanged.

### 1b. The run record

**`SertantaiLegal.Scraper.CatalogueRun`** (pure, `lib/sertantai_legal/scraper/catalogue_run.ex`): a struct with `@enforce_keys`:
- `catalogue`;
- `scope`: `"all"`, `"laws:<n>"`, `"family:<F>"` or `"orders:<n>"`;
- `started_at`;
- `commit`;
- `caches`: `%{cache name => %{hits, read}}`; empty for a catalogue with none;
- `wall_s`;
- `serial_s`;
- `workers`;
- `peak_mb`.

Its functions:
- `kind/1` is `:cold` when every cache has `hits == 0`, `:warm` when every cache has `read == 0`, `:mixed` otherwise, and `:uncached` with no cache;
- `line/1` gives the printed line: `run: <kind>, <cache>: N hits M read …, W s (serial S s), P MB, <workers> workers`;
- `to_json/1`.

**`SertantaiLegal.Scraper.CatalogueRun.Log`** (IO, `catalogue_run/log.ex`):
- `append/1` writes one JSON line to `data/reports/catalogue-runs.jsonl` (a report, not a fixture);
- `sample_peak/1` runs a function while a linked process samples `:erlang.memory(:total)` every 500 ms. It returns `{result, peak_mb}`: a sampled peak, not two points.

**Every run appends**, whatever its scope or options. `--no-cache` gives `read` for every law, and `scope` says what was read.

**Each of the six tasks:**
- builds the record;
- prints `line/1` in place of `CatalogueCache.summary/1`'s line and commencement's `merge:` line;
- appends it.

**The hit signal per cache:**
- **feed, markup, commencement:** `CatalogueCache.fetch/6`'s `:hit | :read`, which they collect today.
- **extent:** `Extent.ReadCache` gets `fetch/2`, returning `{reading | nil, :hit | :read}`, with `law/2` defined as its first element. The catalogue and the extent check keep their behaviour.
- **orders and amendment:** their new caches (changes 2 and 4).
- **commencement after change 3:** two caches, `"law"` and `"merge"`.

**Tests** (`catalogue_run_test.exs`):
- `kind/1` for cold, warm, mixed and uncached (no caches);
- a two-cache record;
- `line/1`'s text;
- `to_json/1` round-trip.

`catalogue_run/log_test.exs`:
- `append/1` to a temporary file adds one line;
- `sample_peak/1` returns the function's result and a peak at least the starting memory.

`read_cache_test.exs`: `fetch/2` gives `:read` then `:hit` for one law in a temporary cache directory.

## Change 2: the order catalogue on the shared machinery

The design decisions, each review finding settled:

- **One cached read per order.** `lib/sertantai_legal/scraper/order_catalogue/law_read.ex` (`OrderCatalogue.LawRead.order/3`) reads an order. Its inputs:
  - the order;
  - every Act it is listed or stored for (today's `pairs/1` list, before the choice);
  - the Acts' titles, reaches and ids, from three grouped queries a run (`uk_lrt` titles; `legal_articles` and `amendment_annotations` counts, as `lat.commencement_patterns`' `reaches/0`; the ids).

  It parses the order's `Doc` once. Inside the read it:
  - chooses the Act (today's `commenced/2`, `Order.commences?/2`);
  - names it by its register title, or, when the register holds none, by the Act's own CLML title (`Order.title/1`, the Act's document, parsed only then);
  - classes its units (`OrderMisreads.order_units/3`);
  - precomputes its examples.
- **The examples, as `CommencementCatalogue.LawScan.scan/3`:** the order alone runs the selection over a fresh accumulator, with today's `take?` rule (`@per_pattern`, one order per pattern). It builds each example that selection asks for (`OrderPatterns.example/3`, read alone as `example/8` reads today), including the next unit tried when one does not hold. The serial fold makes the same selection over the whole run and looks the examples up, so `mismatch` and `too_large` are counted as today.
- **Why `OrderRead` does not fit:** `Commencement.OrderRead` resolves "the day appointed for the purpose of" against the Act's rules (`Order.resolve_appointed_for/2`). The catalogue classes what an order's own text states, before the Act's rules resolve it, so it reads `Order.rules/2`, as today.
- **A new `OrderCatalogue.Version`** (`order_catalogue/version.ex`). `Commencement.ReadVersion` keys stored readings and excludes the catalogue's own code (`order_patterns.ex`, `order_leftovers.ex`, the misreads). It covers `order.ex`, `order/*.ex`, `order_patterns.ex`, `order_leftovers.ex`, `review/order_misreads.ex`, `review/misreads.ex`, `leftovers.ex`, `text_refs.ex`, `reach_groups.ex`, `rule.ex`, the document modules, and whatever `VersionCoverageTest` finds they reach. It is registered in that test.
- **The key:** `{order, the order's CLML file digests, the Acts with their titles, reaches and ids}`.
- **Errors:** the read raises inside `CatalogueCache.fetch/6`, so nothing is written. The task's wrapper rescues to `{:error, message}`, which goes to `unclassified` as today. An error is never cached.
- **The task:**
  - `LawRunner.ordered/3` over the sorted orders;
  - the in-order fold as today, given the precomputed examples;
  - new options `--workers N` and `--no-cache`, as the commencement catalogue has.

**Tests** (`order_catalogue/law_read_test.exs`):
- one order from a fixture's XML read through `LawRead` equals today's per-order contribution: units, patterns, examples;
- an order under two Acts takes the Act it commences;
- a raising order gives `{:error, _}` and leaves no cache file;
- a second read is a `:hit`.

`OrderPatternsTest` is unchanged.

## Change 3: the commencement catalogue's serial merge kept between runs

- **Measure first, in one probe:**
  - the 70 s `merge:` split into the selection and `LawScan.merge_law/4` (run with the merge stubbed through `select/5`'s `:merge` and `:read` options);
  - the time to digest the merge keys.

  The change goes ahead only where `merge_law` is most of the 70 s and the digest is small beside it. The probe goes in the session.
- **The design:**
  - `LawScan` gains a pure public `merge_check/4` (`law, input, [{id, example input, sentence}], read`). It returns the merged input and each id's outcome, which is what `merge_law/4` computes today.
  - `select/5` takes these results through an option instead of reading.
  - A new `CommencementCatalogue.MergeRead` (`commencement_catalogue/merge_read.ex`) runs `merge_check/4` through `CatalogueCache.fetch("commencement_merge", law, CommencementCatalogue.Version.current(), {law, input, chosen ids with their example inputs}, …)`. The key is exactly what the merge reads, so the drops (and the slots they free for later laws) are the same.
- **The cost:** editing `law_scan.ex` stales `CommencementCatalogue.Version`, so one cold run of about 7 min (in the run list).
- **Tests** (`law_scan_test.exs`):
  - `merge_check/4` equals `select/5`'s merge for the existing cases, including a dropped example freeing its slot;
  - `merge_read_test.exs`: a second fetch is a `:hit`.

## Change 4: the amendment catalogue kept between runs

- **The key:** per amending law and amended law, so scopes do not thrash.
  - `amending_result/2` is split per amended law: `Amendment.CatalogueRead.pair/3` (`amendment/catalogue_read.ex`) gives that law's units and each pattern's first example.
  - Its cache: `CatalogueCache.fetch("amendment_patterns", "#{amending}~#{law}", AmendmentCatalogue.Version.current(), {amending, the digests of its CLML and enacted files, law, refs, law_ref}, …)`.
  - The task joins the pairs in sorted law order, taking each pattern's first example as today.
  - The amending law's `Doc` is parsed only when a pair misses, once for all its pairs.
- **`law_ref`:** `ReadLaw.law_ref/1` is computed once a run for every law in scope, before the reads, and passed in.
- **Errors:** raise inside the fetch, so nothing is cached; the task's existing rescue reports them.
- **A new `AmendmentCatalogue.Version`** (`amendment/catalogue_version.ex`) covers `amendment/patterns.ex`, `amendment/patterns/*.ex`, `amendment/catalogue_read.ex`, the reader as `Amendment.ReaderVersion` lists it, and the document modules. It is registered in `VersionCoverageTest`.
- **Tests** (`amendment/catalogue_read_test.exs`):
  - an amending law from `test/fixtures/amending_law` read pair by pair and joined equals today's `amending_result/2`;
  - two scopes keep each other's cache files;
  - an error leaves no file.

## The run list (each asked of Jason before it starts; read-only but for the dry-run directories, the run log and the caches)

| When | Runs | Purpose | About |
|---|---|---|---|
| After change 1 | each of the six once (all are cold: their versions moved in the last session or with this change) | the proof (dry-run files identical to the fixtures), and the profiled cold runs for "Catalogue Cold Runs" | 45–50 min, one at a time |
| After change 1 | each once more | the warm times | 10 min (amendment 6 min, uncached until change 4) |
| After change 2 | orders cold, then warm | proof and times | 2 min |
| After the probe and change 3 | commencement cold, then warm | proof and times | 9 min |
| After change 4 | amendment over the round's 527 laws, cold, then warm, `--out` a scratch copy | proof and times | 8 min |
| Before the push | `mix test` and Dialyzer (the pre-push hook) | | 6 min |

## Docs

- WORKFLOW's whole-store catalogues section (#195) gets:
  - the rule: every catalogue parallel, cached, writing a dry run by default, and recording its run;
  - the run log.
- Each step skill's catalogue line points to `data/reports/catalogue-runs.jsonl` in place of hand-written times.
