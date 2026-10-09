---
session: 'LR-01: Territory Fixtures & Diff Tool'
status: closed
opened: 2026-10-09
closed: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
outcome: success

summary: >
  Territory now has its own fixture suite (30 cases from real QA CLML: 18 green, 12 pending for LR-02/LR-03),
  and the corpus diff classifies changes across text, title, excluded_extent and extent_code with an
  expected-classes check. Baseline diff against the DB is zero apart from the known PDF-sourced law.

decisions:
  - what: Fixtures assert parse output ({text, excluded_extent, status}) through LatParser.parse, not LatTerritory internals
    why: The same suite must judge the current parser, the LR-02 rewrite and the LR-04 extraction unchanged
    result: 30 cases; pending ones reproduce the QA corpus output verbatim
  - what: Broken cases tagged pending and excluded by default
    why: Hooks run the suite; red-by-design tests must not block commits, but stay one command away
    result: mix test --only pending → 12 red
  - what: Nested rule refined — narrower insertion inside a wider one keeps its own bracket; nested repeals live outside their union
    why: The old "inner plain" rule lost a narrower territory (Gemini's nested-subset case)
    result: QA spec and design updated

metrics:
  fixtures: { total: 30, green: 18, pending_lr02: 9, pending_lr03: 3 }
  baseline_diff: { laws: 1068, changed_rows: 58, unexpected_outside_1979_791: 0 }
  suite: { passed: 2349, excluded: 12 }

lessons:
  - title: Check QA agents' claims against the XML before encoding them as fixtures
    detail: One agent reported 2006/47 s.60(1) as unbracketed (it is bracketed), and two "note-only" insertion cases turned out to be element-level Additions without Extent — which moved them from LR-03 to LR-02.
    tag: data

artifacts:
  - backend/test/sertantai_legal/scraper/lat_territory_fixtures_test.exs
  - backend/lib/sertantai_legal/scraper/lat_diff_class.ex
  - backend/test/sertantai_legal/scraper/lat_diff_class_test.exs
  - backend/lib/mix/tasks/lat.text_diff.ex
  - backend/test/test_helper.exs
  - docs/LAT-QA-SAMPLE-SPEC.md
  - docs/LAT-PARSER-REFACTOR-DESIGN.md
  - backend/data/reports/lat-refactor/lr01-baseline.csv

depends_on:
  - lat-refactor/2026-10-09-lr-00-meta

enables:
  - LR-02 LatTerritory (9 pending fixtures, classified diff)
  - LR-03 note-only changes (3 pending fixtures)
---

# Session: LR-01 Territory Fixtures & Diff Tool (CLOSED)

## Problem

Territory has no test suite of its own: "done" has meant "QA didn't hit it". Before `LatTerritory` (LR-02) is written, every territory path gets a fixture asserting the parse's `{text, excluded_extent}` (and status where it follows), red where today's parser is wrong, so LR-02/03 are judged by the suite going green. The corpus diff must also classify changes so a wave is reviewed by pattern, not by row.

## Todo

- ✅ Real CLML excerpts for each broken QA case (from the store, via QA packets)
- ✅ Fixture suite `test/sertantai_legal/scraper/lat_territory_fixtures_test.exs`: paths × sources (attribute / note / none), nested, mixed, versions, spanning siblings, prospective; decided rules (meta Q1–Q6)
- ✅ Broken cases tagged `pending: "LR-02"` / `"LR-03"`, excluded by default; `mix test --only pending` shows them red
- ✅ `mix lat.text_diff` classifies (no flag: always on): change classes (field × old→new pattern) with counts, an expected-classes file, unexpected = 0 check
- ✅ Baseline: classified diff of today's parser vs DB — 0 apart from UK_uksi_1979_791 (58 removed, PDF-sourced)

## Dependencies

- ✅ Design decisions (meta Q1–Q6)

## Work (2026-10-09)

- **Fixtures** (`lat_territory_fixtures_test.exs`): 30 cases — 18 green today, 12 pending (9 `LR-02`, 3 `LR-03`). Every pending case reproduces the corpus output QA reported, word for word; no case expected green failed.
  - LR-02: words/pair with note-only territory; pair halves not siblings (1990/8 s.150(1)(b)); repeal S around substitution E+W (1968/73 s.102(4)); narrower insertion nested in a wider one; whole-row insertion with note-only territory (1990/8 s.202D, 2010/2214 Pt. 2B); retained row + inner insertion (Q3, 1974/40 s.30(5)); attribute ∪ note (Q1, 1996/1527).
  - LR-03: note in the number only (1974/40 s.101); note-only S on top of element E+W (1993/12 s.18); except-clause (Q2, 1984/22).
- **Findings while building them** (checked against the XML):
  - QA3 slice 3's "2006/47 s.60(1) unbracketed" was wrong — the stored row is bracketed; only the "“ adult ”" spacing is real.
  - The "inserted for E." / "Pt. 2B inserted (W.)" cases are element-level (Addition without Extent), not note-only → LR-02, not LR-03.
  - `Territory.from_note` must read spelled-out names ("disapplied in relation to Wales") for Q1.
- **Rules settled** into the QA spec and design: attribute ∪ note; pair halves needn't be siblings; nested repeals → live outside the union; a narrower nested insertion keeps its bracket; note-only whole-provision changes; except-clauses.
- **Test infra**: `:pending` excluded by default (`test_helper.exs`); `mix test --only pending` shows the 12 red.
- **Diff tool**: `LatDiffClass` (pure, 8 tests) + `mix lat.text_diff` now compares text, title, excluded_extent, extent_code; writes `classes`, a `<out>.classes.csv` summary, and `--expect FILE` (regex per line) → unexpected count.
- Full suite: 2,349 passed, 12 excluded.
- **Baseline** (`data/reports/lat-refactor/lr01-baseline.csv`, 1,068 laws, store only): 58 rows changed, all `removed` in UK_uksi_1979_791. Text, title, excluded_extent and extent_code otherwise identical to the DB — LR-02's diff starts from zero.
