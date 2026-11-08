---
session: "Store and build: silent staleness (#193)"
status: closed
opened: 2026-11-07
closed: 2026-11-07
issue: 193
outcome: success

summary: >
  Every stored record a switched label is made from now shows as stale in mix lat.stale when its code or inputs moved:
  - switched laws' labels against the change vocabulary's version and their latest build;
  - commencement and extent readings against their reader's version (a new column);
  - a corrected commencement and extent fingerprint;
  - version lists that recompile when a file is added.
  The catch-up re-parsed 165 parser-stale switched laws (1 row moved), re-read every commencement and extent reading, rebuilt 285 laws and relabelled 266: lat.stale --strict --switched exits 0. Golden is 26/27, and about 110 provisions' labels moved, two faults parked for their owners.

decisions:
  - what: "lat.stale --strict --switched: the switched families' labels plus the change register must be stale 0; the old path's backlog stays reported (Decision 1)"
    why: "--strict always counted the old path's 1,066 parser-stale and 901 relabel-stale laws, which only a re-parse outside scope clears; the switched families are what is served from the change register"
    result: "exit 0 after the catch-up; old path 901 / 901 reported"
  - what: "Parser-stale is unproven, not different: a read-only text diff before any re-parse; each family's Making laws step re-parses its parser-stale laws (RULES.md family-re-parses-its-parser-stale-laws)"
    why: "Jason: why reparse, isn't that data stable; the diff over 165 switched laws moved 1 row"
    result: "165 re-parsed to re-stamp; 1 duplicate heading dropped"
  - what: "Readings stamped with their reader's version on the row (reader_version column), NULL counting as stale; no backfill"
    why: "the build reads stored readings, so a reader fix never re-run left rebuilds looking current; a backfill would assert freshness nobody checked"
    result: "58,738 commencement and 9,430 extent rules re-read and stamped"
  - what: "No amendment_reader reason (dropped from the plan)"
    why: "the build already re-reads a stale amending law from its text (Primary.fresh_rules via Index.fresh?)"
    result: "no silent amendment staleness"
  - what: "Keep the moved labels; fix the faults in their owning steps (Jason)"
    why: "today's readings are the current evidence; restoring would return the switched labels to stale"
    result: "undated-repeal-backdated (Label fold) and golden-order-now-held (Commencement reader) parked"

metrics:
  before: { switched_labels_stale: 266, built_stale: "285/285", commencement_reader: 277, extent_reader: 222, switched_parser_stale: 165 }
  after: { switched_labels_stale: 0, built_stale: "0/285", strict_switched_exit: 0, golden: "26/27", labels_moved_provisions: 110, labels_moved_laws: 6 }
  runs: { text_diff_165: "7 min, 1 row", reparse_165: "about 5 min", commencement_rereads: "about 12 min", extents: "10 min", rebuild: "223 s + 55 s", relabel_266: "4 min" }
  tests: { mix_test: 10263, credo_added: 0, dialyzer: pass }

lessons:
  - title: "A rebuild reads stored readings, so reader-code staleness hid behind a fresh build stamp"
    detail: "ChangeVocabulary.Version staled every build on a reader edit, but the rebuild read the old commencement and extent rules and stamped itself current. 277 of 285 builds had read commencement rules no one could date to today's reader; 32,335 feed rules dated from 2026-10-18."
    tag: data
  - title: "lat.vocabulary --build never refreshes a switched law's timeline"
    detail: "OH&S's switched labels sat unrefreshed from 2026-11-02 while its changes were rebuilt many times; only LabelRefresh (relabel, parse) writes timelines. Staleness must compare the refresh with the latest build."
    tag: data
  - title: "Parser-stale means unproven, not different"
    detail: "A text diff (read-only, --store only) over 165 parser-stale laws moved 1 row. Prove before re-parsing; the re-parse is then a re-stamp."
    tag: tooling
  - title: "Re-reading readings with today's code moves labels"
    detail: "The catch-up's finer commencement readings moved about 110 provisions and exposed a label fold fault (an undated repeal backdated to the law's start). A catch-up is a measurement, and its label diff must be read before closing."
    tag: data
  - title: "systemd user units cannot block the network (IPAddressDeny is ignored)"
    detail: "To keep a run offline, check what it would fetch (29 feeds not held) and ask; prefer --store only modes."
    tag: infrastructure

bugs:
  - pattern: "An undated repeal folds as repealed from the law's own start: after the commencement re-read, the Local Government Act 2003's repeals Schedule (sch.8) is commenced by order with no date, so Ports Act 1991 s.29 shows repealed from 1991-07-25 with no in-force period (before: repealed 2003-09-18 from the Act's Royal Assent rule)"
    category: undated-repeal-backdated
    module: ChangeVocabulary.Label / LabelSource
    affected: 5 provisions (UK_ukpga_1991_52 s.29, s.29(1)-(4)); unknown corpus-wide
    fix: "An undated removal holds the provision's last dated period open (unknown from), never repeals from the start"
    step: Label fold
    status: fixed  # 2026-11-08-parked-owner-bugs
  - pattern: "Golden UK_ukpga_1974_40 s.101 expects UNDECIDABLE (order not held), but today's order re-read reads SI 1988/818 as commencing it on 1988-06-06: golden 26/27"
    category: golden-order-now-held
    module: ChangeVocabulary.Golden (expectation) or Commencement.Order
    affected: 1 golden provision
    fix: "Check SI 1988/818 against s.101; if it commences it, update the golden expectation (Jason)"
    step: Commencement reader
    status: fixed  # 2026-11-08-parked-owner-bugs
  - pattern: "A switched law's labels can go stale silently"
    category: switched-labels-staleness
    module: LabelStaleness / mix lat.stale
    affected: 266 switched laws
    fix: "timeline_version and labels_behind_changes reasons; --strict counts the change register"
    step: Store and build
    status: fixed
  - pattern: "A SourceVersion's file list misses files added under its patterns until it recompiles"
    category: version-wildcard-stale
    module: SourceVersion
    affected: every SourceVersion
    fix: "__mix_recompile__?/0 and fresh?/0; VersionCoverageTest checks every version"
    step: Store and build
    status: fixed
  - pattern: "Switched laws stamped with the old path's code version"
    category: family-switch-by-display-name
    module: LabelRefresh
    affected: 143 OH&S laws
    fix: "relabelled; refresh records ChangeVocabulary.Version"
    step: Switch-over
    status: fixed
  - pattern: "Commencement and extent readings carry no reader version, so a rebuild after a reader fix looks current"
    category: unstamped-readings
    module: Commencement.Store / Extent.Store / Store.Inputs
    affected: 277 builds (commencement), 222 (extent)
    fix: "reader_version column, Inputs.readers/3, reader reasons"
    step: Store and build
    status: fixed
  - pattern: "The commencement fingerprint read rules from the commencing laws, not rules commencing them; the extent fingerprint missed the rules' sources and cited laws"
    category: rules-fingerprint-scope
    module: ChangeVocabulary.Store.Inputs
    affected: 14 + 11 builds
    fix: "commences = ANY(law ∪ sources); extent over affecting ∪ sources"
    step: Store and build
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/commencement/read_version.ex
  - backend/priv/repo/migrations/20261107203657_rule_reader_version.exs
  - backend/lib/sertantai_legal/scraper/label_staleness.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/store/inputs.ex
  - backend/lib/sertantai_legal/scraper/source_version.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/data/reports/silent-staleness/
  - backend/data/reports/pipeline-scaling/2026-11-07-scaling-review.md

depends_on:
  - 2026-11-07-extent-census-as-a-task.md

enables:
  - "#194 rebuild only what an edit changes"
  - "#195 incremental catalogues"
  - Environmental Protection (family 3)
---

# Session: Store and build: silent staleness (#193) (CLOSED)

## Problem

Stored records a label is made from can be out of date without `mix lat.stale` saying so. Every switched law's labels are stale right now: OH&S's since 2026-11-02, while the changes were rebuilt many times. The readings the build reads (commencement, extent, amendment rules) carry no reader version, so after a reader fix a rebuild reads old readings and calls itself current. Scaling review item 2: `backend/data/reports/pipeline-scaling/2026-11-07-scaling-review.md`. Plan: approved 2026-11-07 (below).

## Todo

- ✅ 1. Open the session: plan into the doc; branch `silent-staleness`; the parked bugs listed
- ✅ 2. Tests first (red): a planted fault for each case in the pass rule
- ✅ 3. The version list stays current: `__mix_recompile__?/0` and `fresh?/0` in `SourceVersion`, with the all-versions test
- ✅ 4. Switched labels: `LabelStaleness` facts and reasons; `lat.relabel --stale` takes them; the 6 OH&S laws with no timeline explained
- ✅ 5. Readings stamped: `Commencement.ReadVersion` and coverage; `reader_version` on both resources (Ash migration), written by both stores; `Inputs.readers`; reader reasons in `ChangeStaleness`; `lat.stale` hints, `--strict`, the no-changes count
- ✅ 6. The pass on code: `mix test`, Credo, Dialyzer, Sobelow; `lat.stale --list` before the catch-up, recorded
- ✅ 7. The catch-up (on Jason's go): restore point; re-read stale readings; rebuild; relabel switched laws; golden from inputs; both families' gates; `lat.stale --strict` 0
- ✅ 8. Close: DATA-ARCHITECTURE, WORKFLOW, TESTING; parked bugs fixed; session and #193 closed; commits; fast-forward on Jason's go

## Dependencies

- ✅ Scaling review and Gemini triage (a66f3550)
- ✅ Both families switched (OH&S 2026-11-02, Maritime Safety 2026-11-07)

## Plan (approved 2026-11-07)

**Aim:** every stored record a label is made from is reported stale when the code or inputs it came from have moved (AIMS: `binds-on-date`). Nothing a reader, the fold or a check outputs changes.

**Pass rule:**
1. Tests plant each fault: timeline by other code (`:timeline_version`); timeline older than the latest build (`:labels_behind_changes`); extent or commencement rule with an old or NULL `reader_version`; a stale amendment index (`:amendment_reader`); a version wildcard gaining a file (`fresh?` false); `--strict` non-zero on each.
2. `VersionCoverageTest` passes with `Commencement.ReadVersion`; every version is `fresh?`.
3. `lat.stale --list` recorded before the catch-up.
4. After the catch-up: `lat.stale --strict` 0; golden from inputs 27/27; both switched families' gates pass as at switch-over. A gate that moves is a finding for the owning reader, not fixed here.
5. `mix test`, Credo, Dialyzer, Sobelow.

**Golden:** frozen (`golden.exs`, label fixtures, OH&S checked rows). **Out of scope:** #194, #195, any reader's logic, the old register path's reasons. **Time box:** a day of code plus the catch-up.

**Rejected:** a reading stamp as a `lat_events` row (can't say which kind went stale); backfilling NULL stamps with today's version (a false fresh); re-reading inside the build (#194's ground).

## Survey (2026-11-07)

- Switched timelines: OH&S 143 laws stamped `c8c643cd` (the old path's git-hash stamp), built 2026-11-02; Maritime 117 laws stamped `97ffe3c82175`, built 2026-11-07; `Version` now `26073db6e3a5`. `lat.vocabulary --build` writes `provision_changes` only, never the timelines.
- Readings: `amendment_rules` (index carries `ReaderVersion`), `extent_rules` 9,430 rows / 2,208 laws and `commencement_rules` 45,212 / 3,595 carry no reader version. 32,335 `feed_commencement` rules read 2026-10-18.
- 281 vs 285: four laws built with 0 changes (`UK_eudr_2009_104`, `UK_eudr_2009_161`, `UK_eudr_2013_35`, `UK_nisr_2012_286`). Not a fault.

## Parked bugs this session fixes

- `switched-labels-staleness` (parked-bugs, #193)
- `version-wildcard-stale` (Pipeline checks in Elixir, #193)
- `family-switch-by-display-name`: its second half, switched laws stamped with the old path's version (OH&S's `c8c643cd` rows)

## Code (todos 2–6)

- **Version list current:** `SourceVersion` defines `fresh?/0` and `__mix_recompile__?/0`. Proved live: adding `commencement/read_version.ex` recompiled `ChangeVocabulary.Version`, which its wildcard covers. `VersionCoverageTest` asserts every version is `fresh?`. `source_version.ex` joins the allowed list: versions reach it through `fresh?/0`, and it shapes no reading.
- **Switched labels:** `LabelStaleness` adds `:timeline_version` and `:labels_behind_changes` for a switched law, and drops the old path's `:labels_version` for it. The version comes from the refresh record (`labels_refreshed.provenance.changes_version`, now written by `LabelRefresh.run_switched`), not from the timeline rows. The 6 OH&S laws with no timeline (`UK_eudr_1989_656`, `UK_eudr_2009_104`, `UK_eudr_2009_161`, `UK_eudr_2013_35`, `UK_nisi_1998_2795`, `UK_nisr_2012_286`) are refreshed with 0 periods, so an empty timeline is still checked. `lat.relabel --stale` takes the two reasons; its resume tag carries both versions.
- **Readings stamped:**
  - `Commencement.ReadVersion` is new, and the coverage test holds it to all its modules reach. Its known limit: the input glue in `mix lat.commencement` is not covered.
  - Migration `20261107203657_rule_reader_version` (Ash-generated) adds `reader_version` to `commencement_rules` and `extent_rules`.
  - Both stores stamp it. An extent re-read that comes out the same updates only the stamp and keeps `read_at`, so it needs no rebuild.
  - `Store.Inputs.readers/3` gives `:commencement_reader` and `:extent_reader`, and `ChangeStaleness` appends them.
- **Found and fixed (`Store.Inputs`):** the commencement fingerprint read the rules *from* the commencing laws (`source_law = ANY(sources)`). The build reads the rules *commencing* them, so a re-read order never moved the fingerprint. The extent fingerprint also missed the rules' sources and the cited laws the build reads. Both now match what the build reads.
- **Dropped from the plan, with evidence:** `:amendment_reader`. The build already re-reads a stale amending law from its text (`Primary.primary/2`, `fresh_rules`, which uses `Index.fresh?`), so stale amendment readings can't be silent.
- **`lat.stale`:** `--strict` now counts the change register; it prints the fix for each reader reason and "N built with no changes".
- **Checks:** `mix test` 10,263 passed; Credo diff added no issues; Dialyzer passed; Sobelow found nothing high.

## Before the catch-up (`backend/data/reports/silent-staleness/2026-11-07-before.txt`)

`lat.stale --list`, 3 s:

- **Labels:** 1,167 stale laws.
  - Switched (266 = OH&S 149 + Maritime 117): `timeline_version` 266 and `labels_behind_changes` 266. Every switched law's labels predate its latest change build.
  - Old path: `parser_version` 1,066 and `labels_version` 901 (as before this session).
- **Change register:** 285 of 285 built laws stale (4 built with no changes).
  - `code_version` 285 (this session's edits);
  - `commencement_rules` 14, `extent_rules` 11 (the corrected fingerprints);
  - `commencement_reader` 277 and `extent_reader` 222: readings no one can say were made by today's reader code.

## Decision 1: what "stale 0" means at the end of this session

- **Question:** pass rule 4 says `lat.stale --strict` exits 0 after the catch-up. But `--strict` has always counted the old label path's 1,066 `parser_version` laws (parsed by older parser code) and 901 `labels_version` laws. Clearing those means a re-parse and a relabel of the old path, outside this session's scope. So rule 4, as written, can't pass.
- **Aim:** `binds-on-date`: the labels that are served must be current. The switched families are served from the new path; the old path's backlog is what the switch-over retires.
- **Options:**
  - (a) Scope rule 4: `--strict` exits 0 for the switched families' laws and the change register. Add `lat.stale --strict --switched`, which counts only switched-family label reasons plus every change-register reason. The old path's backlog stays reported, and is noted on the parking list for the Switch-over.
  - (b) Clear the old path too: a whole-corpus re-parse (about 22 min) and relabel (about 18 min). That writes `legal_articles` for 1,066 laws, out of scope, with its own dry-run → Jason → apply.
  - (c) Leave rule 4 failing and record it.
- **Recommendation:** (a). It checks exactly what this session fixes and what the switched labels are made from. (b) is a LAT-parser and Switch-over job.

**Jason asked:** if (a), when does (b) happen? **Answer and a correction to (a):**
- No step owns the old path's parser backlog today. The 901 unswitched laws parsed by older parser code are re-parsed only when someone runs `lat.reparse`. The old label code's `labels_version` (901) disappears when the old path retires (`LabelVersion` is deleted, DATA-ARCHITECTURE (e)).
- **165 of the 266 switched laws are also parser-stale**: their LAT rows, the rows the served labels are placed on, come from older parser code. So (a) as written would not pass either, and these 165 are not an old-path matter.
- **Revised recommendation:**
  - (a′) `--strict --switched` counts every reason for switched-family laws, the parser included, and the change register.
  - The catch-up re-parses the 165 first (`lat.reparse --laws … --store only`, dry run first). A re-parse refreshes the labels, and the commencement own-clause readings read the rows.
  - (b) becomes a rule: each family's Making laws step re-parses its parser-stale laws, so the backlog clears family by family, and the old path never needs a whole-corpus re-parse.

**Catch-up:** restore point `issue193-catch-up` taken 2026-11-07 (commencement_rules, extent_rules, provision_changes, provision_change_claims, lat_label_timeline, lat_events; 8 s).

**Decided (Jason, 2026-11-07): (a′)**, with the family rule. Jason: "why reparsing into LAT. Isn't that data stable". Mostly, yes: `parser_version` moves on any edit to the parser's files, so parser-stale means *unproven*, not *different*. So no re-parse on trust either way. First the read-only proof: `mix lat.text_diff --laws <the 165> --store only` (writes nothing).
- Zero rows changed: the rows are stable. A zero-diff re-parse only re-stamps them (identical rows, a new `parsed` event); asked before it runs.
- Rows changed: those are parser changes the served labels have not seen. Listed for Jason by class; not re-parsed in this session.

**Text diff of the 165** (`backend/data/reports/silent-staleness/textdiff-165.csv`, read-only, about 7 min):
- 1 row changed in 165 laws: `UK_ukpga_1979_39:h.22` "Safety and health on ships", the second of two identical headings over two repealed sections (h.21 / s.21, h.22 / s.22). Today's parser drops it, and it carries no label.
- 0 territory findings.
- So the rows are stable. **Jason:** re-parse the 165 to re-stamp them (restore point `issue193-reparse`: legal_articles, amendment_annotations, lat_changes, lat_section_id_renames, lat_label_timeline, lat_events).
- `lat.stale --strict --switched` added (95022022).

## Catch-up (todo 7), 2026-11-07, all in `systemd-run` (MemoryMax=14G); logs in `backend/data/reports/silent-staleness/`

| Run | Result | Time |
|---|---|---|
| Re-parse of the 165 parser-stale switched laws (`--store only`) | 165 re-parsed; 1 row dropped (Merchant Shipping Act 1979 h.22, as the text diff said); 0 failures | about 5 min |
| Commencement own clauses (`--read --all`; `--read-amending`) | 1,167 laws, 2,888 rules; 1,621 amending laws, 4,277 rules; 0 errors | 6½ min |
| Feed effects (`--effects`, 29 feeds fetched, Jason's go) | 272 Acts, 914 instruments, 44,189 rules (32,335 before); 0 feed errors | 3½ min |
| Cited orders; own orders of the 515 Acts with cached lists | 140 orders, 2,023 rules; 515 Acts | 30 s |
| 86 named amending laws no mode reselects (`--read-amending --law`) | 127 rules; every commencement rule now stamped | 1 min |
| Extents (`--extents --amending <2,208> --cached`) | 9,430 rules, all stamped | 10 min |
| Rebuild of the 285 built laws, then the 49 that read the 86 | 223 s + 55 s | 5 min |
| Relabel of the 266 switched laws (named list) | 0 failed | 4 min |

**Pass rule 4:**
- `lat.stale --strict --switched` **exits 0**: switched families 0 of 266, change register 0 of 285.
- Old path reported: `labels_version` 901, `parser_version` 901.
- **Golden from inputs: 26/27.** Control of Pollution Act 1974 s.101 now reads as commenced by SI 1988/818 on 1988-06-06. Golden expects UNDECIDABLE, because the order was not held (bug `golden-order-now-held`, for Jason).
- **Gates:**
  - Maritime: Sources, Feed, Markup, Commencement, Merge and Label fold pass. Extent reader 4 and Amending-law reader 1 fail, as recorded on 2026-11-06 (Maritime Measures), so they predate this session. Evidence fails 3, with no earlier record.
  - OH&S: Feed, Markup and Commencement pass. Sources 112, Extent 48, Amending 91, Merge 85, Evidence 23 and Label fold 1 fail. There is no earlier all-steps record for OH&S: it switched over on 2026-11-02, before `lat.gates` checked every step. So "as at switch-over" can't be compared.
- **Labels moved** (`labels-before.tsv` / `labels-after.tsv`): 216 rows out and 209 in, about 110 provisions in 6 laws:
  - Health and Safety at Work etc. Act 1974: 87 provisions, period dates;
  - SI 1995/1802: 12;
  - Merchant Shipping Act 1995: 6;
  - Ports Act 1991: 5;
  - SI 1997/2962: 1;
  - SI 2025/278: 1.

  The Ports Act's s.29 move is wrong (bug `undated-repeal-backdated`, Label fold). The others follow from today's readings and need the owning steps' judgement.

## Parking list

- Label fold: `undated-repeal-backdated` — an undated repeal folds as repealed from the start (Ports Act 1991 s.29)
- Commencement reader: `golden-order-now-held` — COPA 1974 s.101 golden vs SI 1988/818
- Switch-over: OH&S has no all-steps gate record; its failing gates (Sources 112 … Label fold 1) need their owners
- Making laws: rule — each family's Making laws step re-parses its parser-stale laws (Decision 1)
- Store and build: `lat.reparse` left `lat_reparse_issue193` and `_cm` in public (the parked snapshot-tables bug)
