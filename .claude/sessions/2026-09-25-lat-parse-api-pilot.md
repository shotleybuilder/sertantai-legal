---
session: "LAT Parse via API: Pilot (22 QQ Laws)"
status: active
opened: 2026-09-25
related: [161]
enables: [2026-09-25-ai-parsing-workflow, qq-data-readiness/2026-09-25-qq-02-tree-coverage]

bugs:
  - pattern: "lat view missing sub_provision since 20260812203258; every LatPersister insert failed with 42703"
    category: lat-persist
    module: DB view lat (compat view over legal_articles_uk)
    fix: "Migration 20260925160400 appends sub_provision; first LatPersister test added"
    status: fixed
  - pattern: "propagate_lat_stats is a per-row trigger that recounts the whole law and rewrites legal_register on every provision insert or update (O(n^2)); large Acts time out, and provision publishes crawl (~30/s)"
    category: lat-persist-performance
    module: DB trigger trg_propagate_lat_stats on legal_articles (and its partitions)
    affected: 1
    fix: "Migration 20260925161749: statement-level INSERT/UPDATE/DELETE triggers with transition tables on legal_articles + each partition. 6,000-row persist went from 18.2s to 0.56s; the Communications Act now persists 10,900 rows in 28s"
    status: fixed
  - pattern: "LatStagedParser runs the annotation stages after persist_lat fails, leaving annotations without LAT"
    category: lat-persist
    module: scraper/lat_staged_parser.ex
    affected: 2015
    fix: "LatStagedParser.run_stages/5 skips both annotation stages (:skipped) when persist_lat fails and sets result.error. The orphans for UK_ukpga_2003_21 were deleted and recreated by the successful re-parse"
    status: fixed
  - pattern: "LAT session record is marked 'parsed' even when persist_lat failed"
    category: lat-session-status
    module: lat_admin_controller.ex (lat_send_parse_complete) / LatStagedParser result
    affected: 1
    fix: "LatStagedParser.record_outcome/1: any stage error means failed, with the error; the controller uses it. The fetch_body failure path now also carries an error"
    status: fixed
  - pattern: "Making.record dropped Ash notifications (Ash.update inside the row-locked transaction); logged 'Missed 1 notifications in action LegalRegister.update' per Making verdict"
    category: making-traceability
    module: legal/making.ex
    fix: "return_notifications?: true inside the transaction; Ash.Notifier.notify after commit (7873331). Test runs with missed_notifications: :raise"
    status: fixed
  - pattern: "ProvisionSubscriber updates one provision per statement (Ash.get + Ash.update), so the lat stats trigger recounts the law and rewrites legal_register once per provision; ~32 provisions/s"
    category: lat-persist-performance
    module: zenoh/provision_subscriber.ex, trg_lat_stats_upd
    affected: 17468
    fix: "ProvisionSubscriber.upsert_rows/2: one UPDATE ... FROM jsonb_array_elements per 1,000 rows, writing only the keys present (as the :update_taxa action did). 3,000 provision updates took 136ms (per-row was ~94s at ~32/s). The trigger then fires once per batch, so its COUNT is no longer a concern"
    status: fixed
  - pattern: "Fresh trees Not the law's own subject: Not(conditional:at_work) on Merchant Shipping & Fishing Vessels (Noise / Vibration at Work) Regs, so orgs with at_work are categorically excluded"
    category: tree-not
    module: fractalaw tree compiler (L3-type defect)
    affected: 2
    fix: "Fractalaw: never Not a conditional code the law applies to (extend the L3 guard beyond territory)"
    status: open
---

# Session: LAT Parse via API Pilot (ACTIVE)

## Problem

22 Making laws in QQ's register have no LAT, so fractalaw can't enrich them and they have no expression tree (QQ-02 bucket a).

LAT sessions normally run through the admin UI. This pilot runs one **through the API, semi-automatically (Claude + Jason)**, as the first proven slice of the AI parsing workflow (`2026-09-25-ai-parsing-workflow`): LAT session → parse → QA → fractalaw handoff → receipt check.

What it learns decides what the workflow API needs before an agent can run it.

## Todo

- ✅ Pre-parse gate: check the 22 against the amending-SI policy ("inserts duties into a principal Act" means not Making). Candidates: `UK_ssi_2007_80`, `UK_uksi_2018_98`, `UK_wsi_2001_3545` and `UK_wsi_2009_2861`. Record verdicts with `mix making.review`, and drop any that aren't Making.
- ✅ Machine access for the LAT session endpoints: an `X-API-Key` scope following the `:api_ai` / `AiApiKeyPlug` precedent (`AI_SERVICE_API_KEY`), and no browser cookie. Read vs write.
- ✅ Drive the session through the API:
  1. `POST /api/lat/sessions/preview`
  2. `POST /api/lat/sessions/from-view` (by names)
  3. `PATCH …/records/select`
  4. Parse each law via `GET …/parse-stream?name=` (SSE, one law at a time)
  5. `POST …/confirm`

  Log each call, its result, and each point where a human decision was needed.
- ✅ Assess the parse trigger (gap confirmed, see below). SSE per law suits a browser, but an agent needs a job-style trigger plus status polling, or a batch endpoint. Decide whether to add one.
- ✅ QA: `lat-qa` checks (shape, hierarchy, annotations) for the parsed laws; confirm the #162 extent refresh ran after LAT persist (`geo_extent_source` may move to `lat_provisions`)
- ✅ Fractalaw handoff prepared (17 laws; waiting for Jason to launch):
  - Produce the law list and the preconditions (legal server up, snapshot of taxa and provision columns).
  - Jason launches fractalaw: parse → embed → classify (RunPod SLM) → reconcile → publish (law-level, then provisions).
- ✅ Receipt check, as for T4:
  - TaxaSubscriber received = updated, and ProvisionSubscriber counts match fractalaw's log.
  - Making changes against the snapshot.
  - Tree lint; application present.
- ✅ Benchmark `2026-09-25T1821-legal-lat-pilot`, recorded in the QQ meta Results table
- ✅ Write-up for the AI parsing workflow session (below): the step list with each step classed as mechanical, judgement or external launch; API gaps; timings; stop conditions an agent would need

## Dependencies

- ✅ The Making write path (QQ-01a) and the extent refresh on LAT persist (#162), so the pilot's writes are traceable
- ✅ Legal Phoenix server running, with subscribers live (T4)
- ⬜ QQ-01 triage for the 13 Q1 LAT candidates. They're **out of scope** for this pilot and join a later run.

## The 22 laws (QQ-02 bucket a)

UK_anaw_2016_3, UK_asp_2003_2, UK_ssi_2007_80, UK_ukpga_2003_21, UK_ukpga_2006_49, UK_ukpga_2020_7, UK_uksi_1989_1796, UK_uksi_1997_2962, UK_uksi_2002_1587, UK_uksi_2006_2183, UK_uksi_2006_2184, UK_uksi_2007_3075, UK_uksi_2007_3077, UK_uksi_2010_330, UK_uksi_2010_332, UK_uksi_2015_962, UK_uksi_2016_1026, UK_uksi_2018_800, UK_uksi_2018_98, UK_wsi_2001_3545, UK_wsi_2009_2861, UK_wsi_2010_1821

## Progress (2026-09-25)

**Gate (Jason): the 4 amending SIs are not Making.**
- `UK_ssi_2007_80`, `UK_uksi_2018_98`, `UK_wsi_2001_3545` and `UK_wsi_2009_2861` are each "X Regulations are amended as follows" instruments.
- Recorded with `mix making.review --verdict not_making --note …`, the task's first real use. The source is `review` and the note is in the change log.
- The pilot parses the remaining **18**.

**Machine access** (commit `6a4b02c`):
- `AiApiKeyPlug` takes an `env:` option.
- New `/api/workflow/lat/*` routes (preview, from-view, create, show, records, select, confirm, parse-stream) sit behind a separate write key, `WORKFLOW_API_KEY`, stored in the gitignored root `.env`. The AI service's read-only `AI_SERVICE_API_KEY` is not reused.
- Legal's server was restarted with the key: 401 without it, 200 with it, and all Zenoh subscribers came back up.

**API run:**
1. `POST /api/workflow/lat/sessions/from-view` (18 names, label `qq-lat-api-pilot`) created `lat-parse-qq-lat-api-pilot-2026-09-25-1602` in 1s.
2. `PATCH …/records/select` updated 18.
3. `GET …/parse-stream?name=…` runs one law at a time.

**Bug found by the pilot (fixed, commit `5b267e5`): LAT persist has been broken since 12 Aug.**
- `20260812203258_add_sub_provision` added `legal_articles.sub_provision` but not the `lat` compatibility view that `LatPersister` inserts through.
- Every persist failed with 42703. The UI was affected too, but no LAT session had run since, so nobody noticed.
- Fix: migration `20260925160400` appends the column to the view.
- Added the first `LatPersister` test. It reproduced the error before the fix, and it also verifies the #162 extent refresh after persist.
- The first law, `UK_uksi_2002_1587`, then parsed cleanly: 142 rows, and SSE events ran connected → stage_start/complete ×5 → parse_done → parse_complete.

**API gap (confirmed):** parsing is per law over SSE. A client has to hold one connection per law and scrape the stage summaries from event text. An agent needs a batch or job trigger plus a structured status endpoint.

## Parse results (2026-09-25)

**17 of 18 parsed and persisted**, 0 stage errors. Per-law timings are in the pilot log.
- Rows range from 110 to 2,283, plus annotations. Most laws took 2–7s; `UK_asp_2003_2` took 18s.
- **`UK_ukpga_2003_21` (Communications Act) failed:** it parsed into 10,900 rows, but persist hit the pool/transaction timeout after 171s, so 0 LAT rows were saved.
  - Cause: the per-row `propagate_lat_stats` trigger is O(n²), as logged in the bugs above.
  - The annotation stage still saved 2,015 annotations with no LAT (also logged).
  - The session record still says `parsed`.

**QA (`mix lat.qa <session>`):** 0 failures and 18 warnings. The warnings are the known kinds (sort breaks, disambiguated IDs), plus the Communications Act's 0 rows.

**Extent refresh after LAT persist (#162 hook) works:** `UK_uksi_2010_332` went from unverified `UK` to `lat_provisions`. The others kept a higher-ranked law-level source, or have no LAT extent codes (unrevised).

**Confirm:** 17 records confirmed via `POST …/confirm`.

**Handoff:**
- Snapshot `lat_pilot_taxa_snapshot_20260925` (17 laws); no provision snapshot, because the LAT rows are new.
- List: `.claude/sessions/qq-data-readiness/worklists/08-lat-pilot-handoff.txt`.
- Fractalaw has been told to hold for Jason's go.

**Timing so far:** about 40 minutes from gate to handoff. Most of it went on the `lat` view bug and the Communications Act diagnosis; the API calls themselves took seconds per law.

**Where a human was really needed:**
- the amending-SI verdicts (judgement);
- starting fractalaw (external launch);
- deciding whether to fix the trigger now or later.

Everything else was mechanical.

## Trigger fix (2026-09-25; Jason brought it into this session)

- **Migration `20260925161749_lat_stats_statement_triggers`** replaces the per-row `trg_propagate_lat_stats` with statement-level `trg_lat_stats_ins`, `_upd` and `_del`, using transition tables.
  - They're attached to the parent `legal_articles`, which Ash and direct SQL use, and to `legal_articles_uk` / `_au`, because `lat` view inserts target the partition directly.
  - Statement triggers aren't inherited, so each write path fires once. **A new country partition needs the three triggers too.**
- **TDD:**
  - The correctness test covers all three events, the view path and the parent path, and passed on both the old and new triggers.
  - The timing test (6,000 rows) failed on the old trigger at 18,192ms and passes on the new one at 558ms.
  - Full suite: 1,747 passed.
- **Communications Act re-parsed via the API:** 10,900 rows and 2,015 annotations in 28s (it previously failed at 171s). QA: 0 failures. Confirmed and added to the handoff, so there are now **18 laws**.
- **Expected side effect:** fractalaw provision publishes should now run far faster than ~30/s. Verify on the next publish.

## Remaining bugs fixed (2026-09-25; Jason brought them into this session)

- **Orphan annotations:** `LatStagedParser.run_stages/5` (now public) skips `parse_annotations` and `persist_annotations` when `persist_lat` fails, reports them as `:skipped`, and returns `error: "LAT persist: …"`.
- **Wrong record status:** `LatStagedParser.record_outcome/1` returns `{:parsed, r}` only when every stage succeeded, otherwise `{:failed, error}`. The controller no longer records partial success as `parsed`. The fetch_body failure path had the same gap: it now carries `error: "fetch_body: …"`.
- **Tests:** `lat_staged_parser_test.exs` has 6 tests. Persist failure is forced with a law_id that has no legal_register row, using the `body_uksi_1991_899` fixture.

## Compile warnings cleared (2026-09-25, `ecbd13e`; Jason brought it into this session)

- **lib: 18 → 0.**
  - Unused `require Logger` (8 files).
  - `@type record` shadowed the built-in, so it's renamed `taxa_record`.
  - Unreachable clauses in `staged_parser`, `duty_type_lib` and `pdf_parser`.
  - Redundant `|| []` in `federal_client`.
- **Two of them were real bugs:**
  - `scrape_controller` confirm always answered `action: "updated"`, because it checked existence after persisting.
  - `provision_subscriber` treated every `Ash.get` error as not-found and skipped it silently.
- **Tests: 0 warnings.**
  - The filters "excludes X" tests never checked `excluded`; they now assert it.
  - Removed an `assert true` placeholder and dead helpers.
- **`.githooks/pre-commit` now runs `mix compile --warnings-as-errors`.** It used to only notify; its README already claimed this.
- **Legal's server restarted,** so the `provision_subscriber` GenServer change is live. The workflow key is loaded and all 7 subscribers are up.

## Fractalaw publish and results (2026-09-25)

**Receipt:**
- **Law level:** TaxaSubscriber received 30 and updated 30, with 0 errors. That's 18 pilot laws (all verdict `making`) plus fractalaw's 12-law T4 correction (fitness-only). The T4 correction exists because a UK Act saying "extends to Northern Ireland" had been read as an NI-only application.
- **Provisions:** ProvisionSubscriber received 18 of 18 laws and 17,468 of 17,468 provisions, 0 errors, with 10,508 now carrying DRRP. **It took 540s, about 32/s, unchanged from T4.** The statement-trigger fix sped up bulk inserts, but this path writes one provision per statement (bug logged above).
- **Making, against `lat_pilot_taxa_snapshot_20260925`:** 0 flips. All 18 are now `enrichment`-sourced (they were legacy), and all have trees and application.
- **Known gap (fractalaw):** law-level `significance_rating` is NULL for the 18.
- **The 12 corrected T4 laws are now UK-wide.** Two other non-NI instruments are NI-only (the EU ETS regs `UK_uksi_2012_3038` and `2020_1369`). That's correct post-Brexit, and matches QQ's register "No".

**Benchmark `legal-lat-pilot`:**
- `both` 250 → 266; evaluable agreement 63.8% → **68.6%**; no_tree 28 → **6**; not_making 154 → 158 (the 4 amending SIs).

**Attribution** (per-law triage transitions, nothing unexplained):
- **Pilot:** 11 moved from no_tree to both. 7 now miss for tree reasons: 3 generic gate, 1 government actor, 1 material, and **2 disapplied by `Not(at_work)`** (fractalaw defect, logged).
- **T4 correction:** 5 moved into both; 3 are new screener-only.
- **Amending SIs:** 4 moved from no_tree to not_making.

## Write-up for the AI parsing workflow

**Steps, classified:**

| Step | Kind | Notes |
|---|---|---|
| Pick laws (QQ-02 bucket a) | mechanical | from a worklist/view |
| Amending-SI gate | **judgement** | Evidence gathering is mechanical (titles, "X Regulations are amended as follows" and insertion/substitution counts); the verdict is human (`mix making.review`). An agent can propose, a human confirms. |
| Create, select and parse the LAT session | mechanical | via `/api/workflow/lat/*`; seconds per law |
| LAT QA (`mix lat.qa`) | mechanical | warnings are routine; failures are a stop condition |
| Confirm records | mechanical | after QA passes |
| Snapshot + handoff list | mechanical | |
| Launch fractalaw (SLM on RunPod) | **external launch** | Jason, and fractalaw asks him directly |
| Receipt check (subscriber counts vs publish log, Making flips, trees, application) | mechanical | |
| Benchmark and attribution | mechanical | a human reads the result |

**API gaps before an agent can run it:**
1. **Parsing is one SSE connection per law.** It needs a batch trigger plus a structured status endpoint (per-law stage results), rather than scraping event text.
2. **No API for QA, snapshot or receipt checks.** They're mix tasks and SQL today and need endpoints or a workflow runner.
3. **The Making review is CLI-only** (`mix making.review`). It needs an endpoint that records a human verdict with a note.
4. **Subscriber throughput.** Provision ingest is ~32/s, so a 17k-provision publish takes ~9 minutes. The run has to wait for the ingest to drain before verifying.

**Stop conditions an agent needs:**
- any stage error, or a LAT QA failure;
- a persist timeout;
- a Making flip from true to false on enrichment;
- subscriber received ≠ updated;
- ingest going idle before the expected count is reached.

**Human time needed:** the amending-SI verdict (minutes) and the fractalaw launch. The rest was debugging bugs this pilot surfaced, all now fixed except provision batching.

**Bugs the pilot surfaced (7):**
- **Fixed (5):** the `lat` view missing `sub_provision` (LAT persist broken since 12 Aug), the O(n²) stats trigger, orphan annotations, wrong record status, and dropped Ash notifications.
- **Open (2):** provision batching (legal) and `Not(at_work)` (fractalaw).

## Provision batching (2026-09-25; Jason brought it into this session)

- **`ProvisionSubscriber.upsert_rows/2`** normalises rows with the existing `normalize_taxa/1` (DRRP mapping, actor roles), then writes each law in chunks of 1,000 with a single `UPDATE legal_articles … FROM jsonb_array_elements($1)`.
  - Each column is set only when its key is present (`CASE WHEN p ? 'col'`), so absent fields stay unchanged, as with the per-row `:update_taxa` action.
  - Casts cover `text[]`, `jsonb[]` (actors), int and float8.
  - `not_found` = sent − updated, and rows with no section_id count as `invalid`.
  - The per-row `Ash.get` + `Ash.update` (`upsert_provision`, `find_article`) is removed.
- **Tests** (`provision_subscriber_batch_test.exs`):
  - Field writes, actor role enrichment, absent fields unchanged, not-found counting, and `lat_count` unchanged.
  - 3,000 updates in 136ms.
- **Found along the way:** the test fixtures used `section_type: "regulation"`, which isn't a valid SectionType. LatPersister writes raw SQL, so it wasn't caught until Ash read the rows back. Fixed to `"article"`.
