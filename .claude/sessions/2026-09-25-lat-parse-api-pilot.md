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
    fix: "Statement-level trigger with transition tables: recount once per affected law per statement. Check the legal_articles_uk and parent-table firing paths (the lat view inserts via the partition; Ash updates via the parent)"
    status: open
  - pattern: "LatStagedParser runs the annotation stages after persist_lat fails, leaving annotations without LAT"
    category: lat-persist
    module: scraper/lat_staged_parser.ex
    affected: 2015
    fix: "Skip parse/persist_annotations when persist_lat fails; delete the 2,015 orphan annotations for UK_ukpga_2003_21 (or they're replaced on a successful re-parse)"
    status: open
  - pattern: "LAT session record is marked 'parsed' even when persist_lat failed"
    category: lat-session-status
    module: lat_admin_controller.ex (lat_send_parse_complete) / LatStagedParser result
    affected: 1
    fix: "Set record status from the stage results (error if any stage failed)"
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
- ⬜ Receipt check, as for T4:
  - TaxaSubscriber received = updated, and ProvisionSubscriber counts match fractalaw's log.
  - Making changes against the snapshot.
  - Tree lint; application present.
- ⬜ Benchmark `legal-lat-pilot`; record in the QQ meta Results table
- ⬜ Write-up for the AI parsing workflow session: the step list with each step classed as mechanical, judgement or external launch; API gaps; timings; stop conditions an agent would need

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
