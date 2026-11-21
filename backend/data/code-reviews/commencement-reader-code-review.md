# Commencement reader: code review (Fable reviewer, standard `code`, focus architecture and speed)

2026-11-21. Scope: `commencement-reader-code-review-scope.md`. The reviewer timed nothing; every cause is read from the code. Measurements and triage are in the session `.claude/sessions/2026-11-21-commencement-reader-code-review.md`.

Findings against `code` (focus: architecture, speed). All paths under `/var/home/jason/Desktop/sertantai-legal/backend/`. Nothing was timed; every cause below is read from the code.

## Speed

### Position map rebuilt on every range check — Blocker
- Where: `lib/sertantai_legal/scraper/lat_ref.ex:165-166`, reached from `commencement/evaluator.ex` (`refs_index`, `excepted?`) with `OwnClause.context/1`'s `order:` list (`own_clause.ex:373`).
- Finding: `ordered_between/4` runs `order |> Enum.with_index() |> Map.new()` on each `covers?` call for a range ref. `Check.rows` evaluates every row against every rule, and `most_specific` passes over the rules three times. Size: largest law 8,308 rows, 35 laws over 2,000; up to 3,137 rules for one law, 77 laws over 200. Likely the top cost of `Check.rows` and the build's `OwnCommencement.read`.
- Fix: build the map once in `OwnClause.context/1`. Measure: `:timer.tc` around `Check.rows/5` for the 8,308-row law.

### `--fresh` reads each clause, order and amender twice — Blocker
- Where: `lib/mix/tasks/lat.commencement_check.ex:358-397, 519-523`; `commencement/family_leftovers.ex:41-97`.
- Finding: `fresh_rules` reads the clause (`OwnRead.rules`) and each order (`Doc.new` + `Order.rules`); `AmendingRead.fresh` reads each amender. The leftovers gate then repeats all three: the rows query, `Input.of`, `OwnClause.read`, `ClmlStore.law_docs` + `Doc.new`, `Order.rules`. `OwnClause.read/2` already returns the rules and the reading together. `orders/2` queries all LAT rows again for `length/1` only (line 71). Size: 565 laws plus their orders and amenders.
- Fix: one read per law, order and amender, passed to both the check and the gate. Measure: `:timer.tc` around `FamilyLeftovers.for_family/2` against the reduce at line 229.

### Same CLML gunzipped and parsed repeatedly, no parsed-document reuse — Major
- Where: `commencement/own_read.ex:20-23, 51-56`; `law_start/input.ex:72-94, 143-155`; `lib/mix/tasks/lat.commencement.ex:397-401`.
- Finding: `OwnRead.rules` gunzips and xmerl-parses the whole law for every law, used only by `ScheduleEffect` and scoped laws. `Input.of` then gunzips the body again for its head. `schedule_clause` re-reads the schedules file per redirecting row. `--read-orders` calls `law_docs(order)` again after `doc(order)`.
- Fix: load once per law and pass it down. Measure: `:timer.tc` around `Doc.new/2` summed over a family.

### Warm catalogue run still parses every amending law — Major
- Where: `lib/mix/tasks/lat.commencement_patterns.ex:155-197`; `commencement_catalogue/law_read.ex:30`.
- Finding: the cache key is `{law, rows, input}`, so a hit still costs the rows query, `Input.of` (including `tied_date`'s `Clause.read`) and, for about 2,160 CLML laws (3,804 less 1,644 with LAT), `Doc.new` + `doc_rows`. `reach/3` is a sequential scan of `amendment_annotations` (101,362 rows; `EXPLAIN` shows Seq Scan, no index on the coalesce) per CLML law. `feed_patterns/law_read.ex:31` already keys on `file_digest`.
- Fix: key CLML laws on file digests; one grouped reach query.

### `CatalogueCache`: invalidated wholesale by any reader edit — Major
- Where: `commencement_catalogue/version.ex:13-50`; `source_version.ex:13-14`.
- Finding: one version covers 36 files, and whitespace changes it. It includes `order.ex` (2,034 lines) and `order/*.ex` only because `own_clause.ex:310` uses `Order.ref`, `own_clause.ex:38` uses `Asides`, and `provisions.ex:1455` uses `Order.own_schedule_refs`. So every fix in a reader loop, order fixes included, re-reads all 3,804 laws; the cache helps only when no reader code changed.
- Fix: move the ref helpers out of `Order`. A measured cold-versus-warm split would show whether a per-law key is worth it.

### Regexes compiled at run time — Major
- Where: `commencement/order.ex:217, 594, 1483, 1518, 1530, 1562, 1568`; `order/asides.ex:22, 33, 42`; `law_start/clause.ex:648-668, 680, 695, 706`.
- Finding: interpolated `~r` inside function bodies compiles on each call, per unit or statement.
- Fix: module attributes where the interpolation is constant.

### Query per law — Nit
- Where: `lat.commencement_check.ex:321-433, 527`; `held_amenders.ex:67`.
- Finding: about five queries per law plus two per amender; `rows ++` in the reduce at line 231. Seconds at 565 laws.

## Architecture

### Order reading exists three times, and differs — Major
- Where: `lat.commencement_check.ex:379, 387-397`; `lat.commencement.ex:397-401`; `family_leftovers.ex:76-84`.
- Finding: `--read-orders` applies `Order.resolve_appointed_for(stored)`; the `--fresh` preview does not, though its moduledoc calls it a dry run. Only the gate applies `Order.commences?` and `order != law`. `OwnRead` was made "one reading, so the two never differ"; orders were not. The gate also reads scoped laws from LAT rows, where `OwnRead` uses the whole CLML.
- Fix: an `OrderRead` module, as `OwnRead`.

### Tasks hold shared logic — Major
- Where: the LAT-rows SELECT in six places (`own_read.ex:40`, `input.ex:201`, `family_leftovers.ex:119`, and three tasks); the Act title in three, only `lat.commencement.ex:283-295` falling back to `Order.title`; `held?` defined two ways (`lat.commencement_patterns.ex:139`, `lat.commencement.ex:434`); the amending-laws SQL twice, run unused under `--family` or `--law` (`lat.commencement.ex:165-171`).
- Fix: use `Input.rows/1`, one Act lookup, one `held?`.

### `Leftovers` holds two concepts — Nit
- Where: `commencement/leftovers.ex:534, 565`: own sentences, order units, and the review bookkeeping.

## Tests
No finding. Only `store_test.exs` and `law_start/input_test.exs` use the database, and none reads the CLML store.

### Outside this standard — Nit
The scope document gives about 10 minutes for `lat.commencement_patterns`; `docs/lat-change-pipeline/WORKFLOW.md:239` gives about 4¼ minutes cold and under 2 warm.
