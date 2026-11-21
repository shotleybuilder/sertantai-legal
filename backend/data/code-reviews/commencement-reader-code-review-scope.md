# Commencement reader: code review scope

**Standard:** `.claude/review-standards/code.md`.

**Focus:** architecture and speed. Report the other sections' Blockers and Majors only.

## The question

The Commencement reader step of the LAT Change Pipeline takes far too long to run for a family. Find the code patterns that waste time or work:
- the same data pulled again and again, such as a law's rows, a CLML document decompressed and parsed, the stored rules, or an order's document;
- loops over the same data, and per-law or per-row queries;
- work done twice by different modules or tasks;
- tasks that hold logic which should be shared;
- what each long-running task's time is most likely spent on.

Name the measurement that would confirm each finding.

## The code under review

All paths are under `backend/`.

- `lib/sertantai_legal/scraper/law_start.ex`, `lib/sertantai_legal/scraper/law_start/` (the own-clause reader's parsing: Clause, Provisions, Statements, ListItems and the rest)
- `lib/sertantai_legal/scraper/commencement/` (OwnClause, Order and `order/`, Orders, OwnRead, AmendingRead, Amending, Evaluator, Check, Leftovers, FamilyLeftovers, HeldAmenders, SentencePatterns, OrderPatterns, PartScope, Store; `review/`: Misreads, FeedDifferences)
- `lib/sertantai_legal/scraper/commencement_catalogue/` (LawRead, LawScan, the catalogue cache)
- `lib/sertantai_legal/scraper/change_vocabulary/readers/own_commencement.ex`, `readers/note_date.ex`, `readers/amender_start.ex`
- the mix tasks: `lib/mix/tasks/lat.commencement.ex` (the re-reads), `lat.commencement_check.ex` (the check, run once per family with `--fresh`, about 8 minutes for the round of 565 laws), `lat.commencement_patterns.ex` (the own-clause catalogue, about 10 minutes over 3,804 laws), `lat.order_patterns.ex` (about 30 seconds over 1,129 orders), `lat.law_start.ex`

## The long-running tasks to time, from the code

- `mix lat.commencement_check --family F --all --fresh`
- `mix lat.commencement_patterns`
- `mix lat.commencement --read --law <laws>`, `--read-orders --family F`, `--read-amending --family F`

## Also report

- whether the catalogue's per-law cache (`CatalogueCache`) keeps a re-run cheap, or whether code changes invalidate it wholesale;
- whether the tests a fixer call or the session runs could be narrower, for example a test that reads the whole CLML store or the database where a fixture would do.
