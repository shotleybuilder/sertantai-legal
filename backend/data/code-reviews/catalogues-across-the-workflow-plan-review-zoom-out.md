# Catalogues Across the Workflow plan: review (Fable `reviewer`, standard `zoom-out`, 2026-11-21)

Document: `catalogues-across-the-workflow-plan.md`. No Blockers; six Majors, two Nits. Read-only, nothing run.

## Cold runs, the stated trigger, are untouched — Major
- Where: The problem; changes 2–4.
- Finding:
  - The problem names re-runs "after a reader fix", and the aim is a run "about as long as its slowest law".
  - Changes 2–4 all key on the whole code version, so every reader fix is a cold run and only warm runs gain. `WORKFLOW.md:203`: "a reader fix moves the catalogue's code version, so each fix after the catalogue costs one more cold run".
  - A cold run is capped at 4 workers: total/4, not the slowest law.
  - Markup cold is given as 5½ min, but `WORKFLOW.md:202` says "Each cold run took about 25 min, not #195's 329 s (#198)".
- Fix: say what share of runs are cold and whether the aim covers them; narrow the aim to warm runs, or land change 1 first and decide 3 and 4 from its log.

## The proof method holds for two of six catalogues — Major
- Where: the changes' intro; Proof, per change.
- Finding:
  - `CommencementCatalogue.Target` is used only by `lat.order_patterns.ex:59` and `lat.commencement_patterns.ex:62`.
  - `lat.amendment_patterns.ex:57` writes `opts[:out] || @dir` without `--accept`; feed, markup and extent likewise (`WORKFLOW.md:285`).
  - So changes 1 and 4's proof runs would overwrite fixtures.
- Fix: `--out` to a scratch copy with `expected.json` (`WORKFLOW.md:332`), or put the other four tasks on `Target`.

## The machinery test cannot check what it says — Major
- Where: change 6.
- Finding:
  - `module_reach.ex` follows module atoms, not functions or arities.
  - The feed, markup and commencement tasks never call `fetch` (their `LawRead` modules do).
  - A hand-kept task list does not catch a new catalogue.
  - The list differs between change 6 and Out of scope.
- Fix: drop it, or find tasks by name pattern and state the reach rule.

## The run record does not fit the caches — Major
- Where: change 1.
- Finding:
  - `Extent.ReadCache.law/2` returns no `:hit | :read`.
  - After change 3, commencement has two caches.
  - `peak_mb` from two samples of `:erlang.memory(:total)` is not a peak.
  - The new last line repeats `CatalogueCache.summary/1` and the `merge:` line.
- Fix: give extent's hit signal and hits per cache; say which printed lines are replaced; drop `peak_mb` or name a real source.

## Change 3's gain rests on an unmeasured split — Major
- Where: change 3.
- Finding:
  - The "70 s merge" is `:timer.tc` round `law_result/3` (`lat.commencement_patterns.ex:91`), which is `LawScan.select`: the selection plus `merge_law`.
  - The new key holds each law's whole input, digested serially.
- Fix: time `merge_law` alone, and the key's digest, before committing to 25 s.

## Change 2: the existing order reading not named, serial work left in — Major
- Where: change 2.
- Finding:
  - `Commencement.OrderRead` exists, as "one reading"; the catalogue reads `Order.rules/2` directly, a fourth reading, unexplained.
  - `act/1`'s fallback parses the Act's document, not the order's.
  - `pairs/1` "unchanged" keeps `commenced/2`'s serial `Doc.new`: 87 of 1,904 listed orders sit under more than one Act.
  - The Act's title is a cache input with no grouped query.
- Fix: name `OrderRead` and the reason; move the multi-Act choice and the title into the cached read or a grouped query.

## `CatalogueRun` mixes pure and IO — Nit
- Where: change 1.
- Finding: the "pure module" holds `append/1`, a file write.
- Fix: split the writer, or stop calling the module pure.

## New version beside an existing one — Nit
- Where: change 2.
- Finding: `Commencement.ReadVersion` already covers `order/*.ex`; the plan doesn't say why a second version is needed.
- Fix: one sentence.
