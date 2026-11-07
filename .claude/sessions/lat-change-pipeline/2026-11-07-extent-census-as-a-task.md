---
session: 'Extent census as a task (#192)'
status: pending
opened: '2026-11-07'
---

# Session: Extent census as a task (#192) (PENDING)

## Problem

The whole-reader census, which checks every held law's extent reading against an independent reading of its text, is Python, copied into each run (`backend/data/experiments/cv-s05d-whole-reader-census/run-01…07/`):
- `census.py`, 409 lines;
- `finder.py`, 626;
- `bench.py`, 73;
- `rdiff.py`, 38.

#192's last part ports it to a mix task (GLOSSARY: "Extent census as a task"). It is owned by the Extent reader and was split from `2026-11-07-pipeline-checks-in-elixir.md` (Jason, 2026-11-07). It starts in plan mode.

## Todo

- ⬜ Plan: aim, pass rule (byte for byte against run-07's `out/` on run-07's `input.jsonl.gz`), golden, scope, time box

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
