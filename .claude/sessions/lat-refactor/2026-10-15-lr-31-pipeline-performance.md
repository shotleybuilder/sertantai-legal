---
session: 'LR-31: Pipeline Performance'
status: closed
opened: '2026-10-15'
closed: '2026-10-16'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'A full-corpus relabel went from 58 min to 18.5 min with identical output: laws run 5 at once (LawRunner), and the LAT walk and amending-law Doc read xmerl records directly instead of SweetXml.xpath,
  which re-parses its path string on every call. The planned store artefacts (B) were measured and dropped: a stored xmerl tree loads slower than a fresh parse.'
decisions:
- what: Profile on an idle machine before acting; re-plan from the profile
  why: 'Gemini review; the original diagnosis (xmerl parsing, the store) was wrong: parse 0.2–2.5 s, store 55 ms'
  result: xpath was about half of fetch_changes (457,676 path compilations for one 817-row law); plan revised to A, E2, B (C and D dropped)
- what: 'A: run laws in parallel (5 workers) after an isolation check'
  why: each law writes only its own rows; the cross-law legal_register triggers fire only on md_date, which no LAT path changes
  result: 58 → 23.4 min; parallel preview equal to the sequential labels (0 diffs)
- what: 'E2: read xmerl records directly; keep xmerl''s own orders where the old xpath result was ordered'
  why: a refactor must be zero-diff; xmerl's `//` order is not document order, and switching silently changed 161 laws' joins
  result: 0 differences over 1,066 laws; corpus parse 45 → 6 min; full run 18.5 min; the order question is LR-35
- what: Drop B (stored Doc terms); do B2 (record access in AmendingLaw.Doc)
  why: binary_to_term of a Doc took 2.9 s vs 1.8 s to parse, ~12 MB per artefact; amending laws serve ~2.1 laws each
  result: B2 ~10% on the big Acts; register equal for 106 laws
- what: Stop at 18.5 min (D, a faster parser, not pursued)
  why: the remaining cost is first-time xmerl parsing of amending laws (41% of the collector); dry runs and relabels are now fast enough to iterate
  result: session closed
metrics:
  full_relabel_preview_min:
    sequential_baseline: 58
    A_parallel: 23.4
    A_plus_E2: 18.5
  corpus_parse_snapshot_min:
    before: 45
    after_E2: 6
  fetch_changes_ms:
    uksi_1996_1527:
    - 6257
    - 2351
    ukpga_1988_52:
    - 24945
    - 14018
    ukpga_1991_56:
    - 51760
    - 29465
  amending_law_collector_ms:
    ukpga_1988_52:
    - 45963
    - 38662
    ukpga_1991_56:
    - 53816
    - 53158
  gates:
    parallel_label_diffs: 0
    parse_snapshot_differences: 0
    doc_mismatches_139: 0
    amending_register_laws_differing_106: 0
    tests: 2731
lessons:
- title: SweetXml.xpath re-compiles its path string on every call
  detail: xmerl_xpath tokenises and yecc-parses the expression each time; in a per-element walk this was ~50% of the LAT parse (457,676 ~x evaluations for an 817-row law). Read xmerl records directly in
    hot paths.
  tag: tooling
- title: xmerl's `//` results are not in document order
  detail: '`.//*` lists each node''s children in turn (all Parts before their sections); a union (`a | b`) sorts text nodes by Erlang term order. A refactor to document order changed 161 laws'' effect joins.
    Verify helper-vs-xpath equality on every element before trusting a rewrite.'
  tag: tooling
- title: Measure an artefact cache before building it
  detail: A stored xmerl tree (term_to_binary) loaded slower than re-parsing the XML and was ~20× the gzip size; the plan's biggest item would have cost time.
  tag: infrastructure
- title: A profile taken under load misleads on proportions too
  detail: The first profile (alongside a dry run) blamed xmerl parsing; the idle profile showed the walk's xpath and the amending-law collector.
  tag: tooling
artifacts:
- backend/lib/sertantai_legal/scraper/law_runner.ex
- backend/lib/sertantai_legal/scraper/lat_parser/xml.ex
- backend/lib/sertantai_legal/scraper/effect_target.ex
- backend/lib/sertantai_legal/scraper/amending_law/doc.ex
- backend/lib/mix/tasks/lat.relabel.ex
- backend/lib/mix/tasks/lat.wave_preview.ex
- backend/test/sertantai_legal/scraper/law_runner_test.exs
- backend/data/reports/lat-refactor/lr31-snapshot/
- backend/data/code-reviews/2026-10-15-lr-31-performance-plan.md
depends_on:
- 2026-10-13-lr-25-change-log-switch-over
enables:
- LR-35 EffectTarget document order
- faster A8 dry runs (18.5 min)
- D (Saxy) if ever needed
---

# Session: LR-31 Pipeline Performance (CLOSED)

## Problem

A full-corpus run (the LR-25 wave, its dry runs, a relabel) takes about 1.5 hours for 1,066 laws: about 5 s per law, minutes for the largest. Each verification cycle in LR-29 cost a full run. Jason (2026-10-15): "is there a way to change the architecture to speed things up. Thinking about the xml store".

## Profile (2026-10-15, WIA 1991 / UK_ukpga_1991_56, 8,288 rows)

Measured alongside a running dry run, so absolute times are inflated; the proportions hold.

| Phase | Time |
|---|---|
| store read + gunzip | 55 ms |
| one xmerl parse (`SweetXml.parse`) | 5.2 s |
| `EffectTarget.tree` (xpath per element) | 2.2 s |
| changes feed from the store (Atom XML → effects) | 4.2 s |
| `LatParser.parse` | 31 s |
| `fetch_changes` (rows + notes + effects) | 76 s |
| `ChangeCollector.collect` (amending laws) | 97 s |

**The store is not the bottleneck** (55 ms). The cost is:
1. **xmerl**, Erlang's DOM parser: slow, heavy trees, and xpath walks over them.
2. **The same document parsed several times per law:** `LatParser` (rows), `CommentaryParser` (notes), `EffectTarget.tree` (targets).
3. **The changes feed re-parsed from Atom XML each time**, twice per pipeline (`law_effects`).
4. **Amending laws re-parsed for every law they amend.** Since LR-25's leak fix, the doc cache is scoped to one law. A large amending Act is parsed once per affected law.
5. **Laws run sequentially** on a multi-core machine.

## Plan (in order of payoff for effort)

- **A. Parallel laws.** `mix lat.wave_preview`, `mix lat.reparse` and `mix lat.relabel` run 4–6 laws at once (`Task.async_stream`, bounded). Each law is independent: its own transaction and store reads. Memory is flat since the LR-25 leak fix (about 300 MB per worker). Watch the DB pool size, long transactions, and lat_events ordering.
- **B. Derived artefacts in the store.** Next to each `data.xml.gz`, a compact term file (`.etf.gz`) of its parsed result:
  - the changes feed's effects;
  - each amending law's index (`AmendingLaw.Doc`: ids, text, structure).

  Each is keyed by the source file's content hash and rebuilt only when that changes. No XML is parsed twice across a run. This removes most of the collect cost and the feed cost.
- **C. Parse each document once per law.** Share one parsed tree across `LatParser`, `CommentaryParser` and `EffectTarget.tree` (a moderate refactor of `LatStagedParser`).
- **D. Later, if A–C aren't enough:** replace xmerl with a streaming parser (Saxy) on the hot paths. The largest per-parse gain, but the largest change: the parser and collectors use xpath throughout.

Expected: A + B take a full run from about 1.5 h to roughly 10–15 min. Measure on an idle machine before claiming it.

## Gemini review (2026-10-15)

**Taken:**
- **Measure before acting.** Add to the clean baseline:
  - GC time (`:erlang.statistics(:garbage_collection)`);
  - DB write time separate from preparation;
  - the xpath hot spots;
  - CPU against memory on an idle machine.
- **A: prove isolation, don't assume it.** Check every table a law writes and confirm no two laws write the same row:
  - `lat_events` and the `legal_register` lat_hash triggers are per law row;
  - `lat_change_log` and `lat_label_timeline` delete + insert by `law_name`.

  Then size the DB pool to the workers. Errors are isolated per law: a failed law is reported, and the run goes on. The equality gate (parallel output = sequential output) stays.
- **B: an artefact is valid only for the code that made it.** Key each artefact by the source file's hash **and** the producer's code version: a `SourceVersion` over the modules that build it, the pattern `ParserVersion` / `LabelVersion` already use. A parser change then invalidates the artefact automatically. The term records its version and is read with `binary_to_term(bin, [:safe])`.
- **E (new, quick win): one-pass id index.** `EffectTarget.tree` runs `.//*/@id` per element, roughly O(n × depth) xpath work (2.2 s for WIA). Build the id order, positions and containment in one walk of the tree. Pure, so it can be tested against the current output.
- **C before D:** parse once per law first; Saxy only if A + B + C + E aren't enough.

**Not taken:**
- **Splitting a law's transaction for large laws.** Per-law atomicity is what makes the rollback dry run and the wave safe.
- **A queue process for shared-table writes.** Not needed if the isolation check confirms no cross-law rows; revisit only if it doesn't.
- **A Postgres table or a run-scoped cache instead of `.etf.gz`.** A run-scoped cache loses the cross-run gain. A table adds schema for derived data that belongs with the store it is derived from.

## Todo

- ✅ Clean baseline profile (idle machine, 2026-10-16): below
- ✅ Gemini review of the plan (`backend/data/code-reviews/2026-10-15-lr-31-performance-plan.md`): diagnosis confirmed; C before D
- ✅ **Jason: D1** (2026-10-16: "Yes, try that plan A E2 B")
- ✅ A: parallel runs — `LawRunner` (3 tests) in `mix lat.relabel` and `mix lat.wave_preview` (`--workers`, default 5); gate: a parallel relabel preview over the sequentially applied labels shows 0 label diffs and the same gap totals
- ❌ B: derived artefacts — measured and dropped (a stored Doc loads slower than a parse); replaced by ✅ B2 (record access in `AmendingLaw.Doc`, register equal for 106 laws)
- ❌ C: one parse per document — dropped (parse is 2.5 s at worst; the cost is xpath)
- ✅ E2: direct element access instead of xpath (LAT walk, notes, `EffectTarget.tree`) — zero-diff gate `mix lat.parse_snapshot --all`
- ✅ Re-profile; record before and after (above: 58 → 18.5 min)

## Dependencies

- ✅ LR-25 leak fix (flat memory: the precondition for A)
- ✅ After the LR-25 wave (applied 2026-10-15; LR-33, LR-34 applied 2026-10-16)

## Baseline (2026-10-16, idle machine)

Whole relabel (`mix lat.relabel --stale`, 1,066 laws, sequential): **58 min** (14:34–15:33). Machine: 6 cores, 39 GB; DB pool 20. Script: session scratchpad `lr31_profile.exs` (each public phase of the relabel path, rolled back). Law sizes: median 133 rows, p90 817, p99 3,723.

| Phase (ms) | uksi 1997/1160 (133 rows) | uksi 1996/1527 (817) | ukpga 1988/52 (3,723) | ukpga 1991/56 WIA (8,288) |
|---|---|---|---|---|
| store read | 20 | 14 | 20 | 32 |
| xmerl parse, once | 30 | 193 | 766 | 2,450 |
| EffectTarget.tree | 19 | 30 | 179 | 545 |
| changes feed → effects | 38 | 112 | 814 | 2,085 |
| **fetch_changes** (rows + notes + effects) | 288 | **6,257** | **24,945** | **51,760** |
| collect: feed | 13 | 158 | 2,675 | 7,543 |
| **collect: amending law** | 2 | 63 | **45,963** | **53,816** |
| collect: commencement | 7 | 5 | 451 | 347 |
| fidelity | 5 | 14 | 180 | 688 |
| write register | 11 | 38 | 252 | 428 |
| build timeline | 76 | 362 | 2,326 | 13,477 |
| write timeline | 59 | 568 | 1,629 | 7,294 |

**The plan's diagnosis was half wrong.** xmerl parsing is cheap (0.2 s at p90, 2.5 s for the largest law); the store is cheap. The costs are:

1. **xpath, inside the LAT walk** (`fetch_changes`; eprof on uksi 1996/1527): about half its time is compiling and evaluating xpath — `xmerl_xpath_scan` 19%, `xmerl_xpath` 15%, `xmerl_xpath_parse` 12%. `SweetXml.xpath/2` re-tokenises and re-parses the path string on every call: `~x` evaluated 457,676 times (531K `list_to_atom`) for one 817-row law. 71 call sites (lat_parser/*: text 13, ids 11, inline 9, refs 8, xml 6, walker 6, effects 6; commentary_parser 9; effect_target 3), mostly child-element and attribute lookups.
2. **The amending-law collector re-parses amending laws** (eprof on ukpga 1988/52): `xmerl_scan` 38%, xpath about 22%, zlib 5%. Each amending Act is gunzipped and parsed again for every law it amends.
3. **Timeline build for very large laws** (13 s for WIA): the projection itself; second-order.

## Revised plan (for Jason: D1)

- **A. Parallel laws** (unchanged; Gemini's isolation check first): 5 workers on 6 cores → the whole run roughly ÷4. Largest single gain for the least code.
- **E2 (replaces C and E). Direct navigation instead of xpath in the LAT walk and notes**: helpers in `LatParser.Xml` (children by name, attribute, text) over xmerl records; the 71 call sites move over module by module. Zero-diff gate: `mix lat.parse_snapshot --all` before and after. Expected: `fetch_changes` roughly halved. The old item E (`EffectTarget.tree` in one pass) folds in.
- **B. Parsed amending-law docs as store artefacts** (unchanged, scoped to `AmendingLaw.Doc` first; keyed by source hash + producer `SourceVersion`, `binary_to_term(.., [:safe])`): removes the repeated xmerl parse and gunzip; the feed's effects artefact second.
- **C (one parse per law) dropped**: the parse is 2.5 s at worst; E2 is where the time is. **D (Saxy) dropped** unless A + E2 + B fall short.

Order: A → E2 → B, re-profiling after each. Target: the whole run from 58 min to under 15 min.

## A. Parallel laws (2026-10-16)

**Isolation check (Gemini):** a law's relabel writes only its own `lat_change_log` / `lat_label_timeline` rows (delete + insert by `law_name`) and `lat_events`; a parse writes its own `legal_articles` / `amendment_annotations` / `lat_changes` / `lat_section_id_renames` and, by trigger, its own `legal_register` row (lat stats) and `lat_events`. The `legal_register` triggers that touch other laws (`propagate_amend_date_change`, `propagate_rescind_date_change`) fire only on `UPDATE OF md_date`, which no LAT path changes. No path reads another law's freshly written data (amending laws come from the CLML store). Pool 20 ≥ 5 workers.

**Built:** `LawRunner.run/4` (`Task.async_stream`, unordered, per-law errors isolated, results handled in the caller so file writes stay serial); `--workers` on `mix lat.relabel` and `mix lat.wave_preview` (default 5). `mix lat.reparse` stays sequential for now: `LatReparse.run` stops at the first error or failed enrichment gate, a sequential contract.

**Gate passed (`lr31_a_par`, 2026-10-16):** a parallel (5 workers) relabel preview of all 1,066 laws over the sequentially applied labels: 0 errors, 0 label diffs; unknown today 18,340, periods 483,781 and every gap total equal to the sequential `lr34_dry3`. **Time: 23.4 min** (15:54–16:18), against 58 min sequential: ×2.5, not ×5 — the largest laws (about 2 min each: WIA, EPA, 1988/52) now set the run's length, which E2 and B target.

## E2 design (from the call sites)

71 xpath call sites; the hot ones: `Xml.element_name/1` (`name(.)` on every node), attribute reads (`./@id`, `./@CommentaryRef`, `./@RetainText` …) on every element, `./*` children in the walker, and five subtree searches per node in `Text` (`.//P1[1]` … `.//Pblock[1]`, quadratic on deep laws). Plan: record helpers in `LatParser.Xml` (`attr/2`, `children/1,2`, `descendants/2`, `first_descendant?/2`, `texts/1`) over xmerl records; move the call sites module by module, each checked against xpath on every element of sample documents, the whole by `mix lat.parse_snapshot --all` (zero diff).

## E2. Direct element access (2026-10-16)

`LatParser.Xml` reads xmerl records directly: `element_name/1` (XPath `name(.)` exactly: "{uri}Local" for a declared prefix), `attr/2`, `attr_or_nil/2`, `children/1,2`, `descendants/1,2` (document order: the `descendant::` axis), `descendants_xmerl/1,2` (xmerl's `.//*` order), `descendant?/2`, `texts/1`. The hot call sites moved over (walker, Text — five subtree searches per node became one —, Ids, Inline, Refs, Effects, Xml, CommentaryParser); `EffectTarget.tree` no longer runs an xpath per element. Kept as xpath: once-per-document queries and three rare forms (`own_provisions?`, `first_p1_number`, signatures).

**Finding (LR-35):** xmerl's `//` order is not document order (each node's children in turn). The first one-walk tree used document order and changed 161 laws' effect joins (`span/3` resolves ranges over that order). E2 now reproduces xmerl's order (`descendants_xmerl`) wherever the replaced xpath fed an ordered result; the fix is LR-35's decision.

**Gates:** every helper equals its xpath on every element of 8 sample laws (harness in the session scratchpad); `mix lat.parse_snapshot --all --compare` against the baseline `lr31-snapshot`: **0 differences in 1,066 laws**. 2,731 tests pass.

**Result:** the corpus parse (`parse_snapshot`, 6 at once) **45 min → 6 min**. Per law, `fetch_changes`: 6.3 → 2.4 s (817 rows), 25 → 14 s (1988/52), 52 → 29 s (WIA). The amending-law collector (43–58 s on the big Acts) is now the largest cost: B.

## B measured before building: doesn't pay (2026-10-16)

- **Stored `Doc` terms are slower than parsing:** for WIA's amending laws, `binary_to_term` of the compressed `Doc` took 2.9 s against 1.8 s to parse the XML again, at about 12 MB per artefact against a few hundred KB of gzip. xmerl trees carry parent lists and namespace records on every element; a term of them is bloated.
- **Little cross-law reuse to cache:** 6,456 law × amending-law pairs over 3,009 amending laws (about 2.1 parses each; 100 amending laws serve 10+ laws, the top one 57), and the collector loads one only for rows the feed leaves undated. A shared in-run cache across 5 workers would also copy these large terms between processes.

So B as planned is dropped. Measuring the whole run with A + E2 (`lr31_ae2`) before proposing what replaces it.

**A + E2 measured (`lr31_ae2`, 2026-10-16):** full relabel preview, 5 workers: **18.5 min** (16:52–17:10; from 58 sequential, 23.4 with A alone). 0 errors, 0 label diffs, unknown today 18,340.

## B2 (replaces B): the amending-law readers without per-element xpath

`AmendingLaw.Doc.new/2`: ids by record access in xmerl's `//*[@id]` order (`between/3` and `pos` read it); a container's ids by the `descendant-or-self` axis. **Kept as xpath:** a container's title text — xmerl's union (`./Title//text() | ./TitleBlock/Title//text()`) orders text nodes by Erlang term order, which titles depend on ("No. The Pastoral Measure 1983 ( 1)"). Gate 1: the `Doc` fields equal the xpath-built ones for 139 amending laws (those of WIA, EPA, 1988/52, the Equality Act, and the five most shared): 0 mismatches. Gate 2: every law's amending-law records equal the stored register: 106 laws, 0 differing.

**Gain is small (about 10%: 1988/52 43 → 39 s, WIA 58 → 53 s).** The collector's cost is now parsing itself: for 1988/52, 162 documents of 47 amending laws (body + Schedules each, no duplicates), `xmerl_scan` 41%. Only a faster parser (D, Saxy) or fewer parses would cut it further.
