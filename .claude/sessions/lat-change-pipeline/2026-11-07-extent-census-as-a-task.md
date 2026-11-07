---
session: 'Extent census as a task (#192)'
status: closed
opened: '2026-11-07'
closed: '2026-11-07'
outcome: success

summary: >
  The whole-reader census (dump.exs, census.py, finder.py, bench.py, rdiff.py) is now
  `mix lat.extent_census`, in Checks.ExtentCensus and 13 modules outside every SourceVersion.
  Its outputs are run-07's byte for byte from the frozen input and structures (ExtentCensusTest),
  and the same as Python's over today's dump of 3,590 laws. A test holds the finder to sharing
  no code with the extent reader.

decisions:
  - what: Freeze each law's structure, as Python's finder read it, into the test fixture
    why: the finder reads law structure from the CLML store; 1,353 laws' structures come to 0.8 MB gzipped, so the frozen test needs no store
    result: the frozen test checks all four census files and the bench by sha256 in 2.3 s
  - what: Compare the dump by decoded content, and write its keys in a fixed order
    why: dump.exs encodes atom-keyed maps, whose key order follows the VM's atom table, so its bytes are not stable
    result: today's dump decodes equal to dump.exs's (3,590 laws)
  - what: The census takes the store or a map of structures, and looks a law up before its task starts
    why: a closure over the frozen-structures map was copied into each of 3,358 tasks (60 s, timed out)
    result: 4 s serially for the census over every law; 29.5 s with structures read from the store

metrics:
  reference: { run07_vs_today_python: identical, hash_seeds: "0 and 1 identical", python_seconds: 29 }
  structure: { laws: 3358, differ: 0, seconds: 33, parse_errors: 0 }
  frozen_test: { tests: 15, seconds: 2.3 }
  today: { laws: 3590, sentences: 3837, unnamed_refs: 369, unnamed_laws: 53, bench: "5/10", elixir_seconds: 38, python_seconds: 32 }
  pass: { stale: "0 of 285", mix_test: 10248, credo_new: 0, dialyzer: clean, sobelow_high: 0 }

lessons:
  - title: A task's function closing over a big map copies the map into every task
    detail: Task.async_stream(fn d -> f(d, structure.(law)) end) with structure = &Map.get(frozen, &1) copied the 1,353-law map per task, making a 4 s census time out at 60 s. Look the value up in the caller (Stream.map before async_stream), or pass small terms only. The same family of fault as #191's packed folds.
    tag: tooling
  - title: Python dict insertion order can be output, so fixtures must keep it
    detail: finder.Structure's members dict order decides container_of (the last match wins). A first fixture dumped with sort_keys would have silently changed verdicts; members go as ordered [container, refs] pairs.
    tag: data
  - title: Cross-string positions and N-character windows are the byte-for-byte traps in a regex port
    detail: finder.py slices one string at a position found in another (a VERB match in unrelative(text) applied to text) and takes windows of 4, 10 and 24 characters, one with a negative start that wraps. Bytes work everywhere else; these need code points (ExtentCensus.Re carry_from, window). String.length and String.slice count graphemes, not code points.
    tag: tooling

bugs: []

artifacts:
  - backend/lib/mix/tasks/lat.extent_census.ex
  - backend/lib/sertantai_legal/scraper/checks/extent_census.ex
  - backend/lib/sertantai_legal/scraper/checks/extent_census/
  - backend/test/sertantai_legal/scraper/checks/extent_census_test.exs
  - backend/test/fixtures/extent_census/run-07/
  - backend/test/support/module_reach.ex
  - backend/data/reports/extent-census/structures.py
  - backend/data/reports/extent-census/2026-11-07/

depends_on:
  - 2026-11-07-pipeline-checks-in-elixir.md

enables:
  - "#192 closed: the pipeline's core checks run as mix tasks"
  - Family 3 (Environmental Protection) runs its Extent reader census with mix lat.extent_census
---

# Session: Extent census as a task (#192) (CLOSED)

## Problem

The whole-reader census, which checks every held law's extent reading against an independent reading of its text, is Python, copied into each run (`backend/data/experiments/cv-s05d-whole-reader-census/run-01…07/`):
- `census.py`, 409 lines;
- `finder.py`, 626;
- `bench.py`, 73;
- `rdiff.py`, 38.

#192's last part ports it to a mix task (GLOSSARY: "Extent census as a task"). It is owned by the Extent reader and was split from `2026-11-07-pipeline-checks-in-elixir.md` (Jason, 2026-11-07). It starts in plan mode.

## Todo

- ✅ Plan approved (2026-11-07): `/var/home/jason/.claude/plans/gleaming-doodling-matsumoto.md`; branch `extent-census-to-elixir`
- ✅ Open: references (Python census on run-07's input under 2 hash seeds, against `out/`); fixtures (input, Python structures of every law with sentences, sha256)
- ✅ Tests first (red): frozen hash test; unit tests with inline sentences per module; independence test (reach walk into `test/support/module_reach.ex`)
- ✅ Finder ported: `Structure`, `Places`, `Segments`, `Mentions`, `Refs`; Elixir structures equal Python's over the whole store
- ✅ Census ported: `Stored`, `Judge`, `ScopeKind`, `LawCheck`, `Census`; frozen hash test green
- ✅ `Dump`, `Bench`, `ReadingDiff`, `mix lat.extent_census`: today's run equal to Python's; reading diff equal to rdiff's
- ✅ Pass: stale 0, `mix test`, Credo, Sobelow, Dialyzer; wall times; run-folder READMEs; WORKFLOW, TESTING, GLOSSARY
- ✅ Close: session closed; code commit `3886feb7` with hooks; the fast-forward and closing #192 on GitHub wait for Jason's go

## Dependencies

- ✅ Pipeline checks in Elixir: the store scan and extent shapes (#192 part 1), closed 2026-11-07. Reuse `Checks.PyCompat` (Python's rounding, `most_common`, `json.dump`, strip, slices) and the frozen-run hash test pattern (`checks/extent_shapes_test.exs`); copy TSV fields out of the file (`LawReading.row/1`)

## Notes for the plan (from the 2026-11-07 survey)

- **Inputs:** `dump.exs`, which is already Elixir, writes one JSON line per law over `Extent.ReadCache.held/0` in sorted order. Each line holds the default, the application, lists and applies as `{kind, place, refs}`, and the sentences, which are `classes` plus `uncaught` with `"sweep:" <> SweepForm.form/1` and `net`.
- **Outputs to match:** `out/sentences.tsv`, `scope.tsv` (sentence cut to 800 characters), `unnamed.tsv`, `stats.json` (`indent=1`, keys sorted as `worst/counted`) and `bench.txt` ("5/10 flagged"). `rdiff.py` writes a per-law diff of two dumps.
- **Independence:** `finder.py` "shares no code with the extent reader (no RefList, Parts, Forms, Units)". It reads law structure from CLML itself (ElementTree iterparse, a hard-coded path at line 19, swallowing `ParseError`). The port gets its own module tree and a test that it reaches no extent-reader module. It can reuse the reach walk in `test/sertantai_legal/architecture/version_coverage_test.exs` (`reach/1` and `walk/4`, private for now, so they must be extracted into a shared helper).
- **Byte-for-byte traps:**
  - `Counter.most_common` breaks ties by first insertion;
  - Python's `round` rounds half to even;
  - `str` regex `\w` is Unicode, so Elixir needs `u`, and the lookbehind at `finder.py:105` must carry over;
  - sets are sorted at output (`census.py:313,345`), and refs use a natural-sort key (line 207);
  - structure order follows `sorted(glob(*/data.xml.gz))`;
  - JSON formatting is Python's;
  - run-07 has no `manifest.json`, so hash its `out/` first as the reference.
- **Docs:** TESTING.md:163 asks that folded tests carry their example text inline, not a path.

## Plan (approved 2026-11-07)

- **Aim:** the Extent reader's whole-law check runs as tested code in the app (AIMS: checks in code). Nothing a label is made from changes.
- **Pass rule:**
  1. the reference is run-07's `out/` if today's Python run on its input equals it, else today's Python output, with the cause recorded;
  2. the frozen ExUnit test matches the reference sha256 from the fixture input and structures;
  3. the Elixir structures equal Python's for every held law;
  4. today's dump is decoded-equal to `dump.exs`'s, and the census files and bench are byte-equal to Python's over it;
  5. the reading diff equals rdiff's stdout;
  6. independence test; stale 0 of 285; `mix test`, Credo, Sobelow, Dialyzer;
  7. wall times recorded.
- **Out of scope:** any change to the census's judgements (faults are parked and ported as they are); extent reader code; retiring the run folders' Python.
- **Time box:** one and a half days.

## Results

- **The reference** (pass rule 1): today's Python census and bench on run-07's input equal run-07's `out/` byte for byte, under hash seeds 0 and 1 (29 s per seed), and rdiff's stdout equals the reading diff file after its count line. So run-07's hashes are the reference, and the store has not moved under the census since 2026-10-28.
- **Store facts:** of the 3,358 held laws' CLML files, none fails to parse; the folders are `body` (3,358) and `schedules` (944). No sentence makes a nested range.
- **Fixtures** (`test/fixtures/extent_census/run-07/`, 1.2 MB): `input.jsonl.gz`; `structures.json.gz`, Python's `Structure` for the 1,353 laws with sentences (no law without sentences has a range ref), with containers in first-seen order, since `container_of` takes the last match; `sha256.txt`. The generator is `backend/data/reports/extent-census/structures.py`.
- **Structure** (pass rule 3): the Elixir `Structure` (an `xmerl_sax` walk) equals Python's for all 3,358 laws (33 s, 4-wide).
- **The census, frozen** (pass rule 2): all four files equal run-07's on the first full run. `ExtentCensusTest` holds them, with the bench, by sha256: 15 tests, 2.3 s.
  - First try: 60 s, because each task copied the whole frozen-structures map in its closure. The census takes the store or a map now, and looks a law up before its task starts. The census itself takes 4 s serially over all laws.
- **Independence:** the test walks every module the census files reach (`test/support/module_reach.ex`, now shared with `VersionCoverageTest`) and finds none under `amending_law/`. `Dump` is the one module that reads the extent reader.

- **Today's inputs** (pass rule 4): a fresh `mix lat.extent_census --out data/reports/extent-census/2026-11-07` (38 s: dump 0.6 s, census 29.5 s with the store's structures, bench 6.0 s) against `dump.exs` and Python's census and bench over the same dump (32 s). The dump decodes equal (3,590 laws), and all five files are byte-equal. Today: 3,837 sentences, 369 unnamed refs in 53 laws, bench 5/10. The rise from run-07 (3,669, 360 in 45) is the 232 laws held since.
- **Reading diff** (pass rule 5): `--from` run-07's input with `--diff` run-06's gives run-07's `reading_diff_vs_run06.txt` byte for byte (15 of 3,358 laws).
- **The pass** (pass rule 6): stale 0 of 285; `mix test` 10,248 passed; Credo no new issue (four functions split for the limits); Dialyzer clean; Sobelow no high. Docs: WORKFLOW (Extent reader step 8, Census), TESTING (ported checks), GLOSSARY, a superseded line in each run folder's README.

## Parking list

(none)

