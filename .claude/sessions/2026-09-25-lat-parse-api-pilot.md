---
session: "LAT Parse via API: Pilot (22 QQ Laws)"
status: pending
opened: 2026-09-25
related: [161]
enables: [2026-09-25-ai-parsing-workflow, qq-data-readiness/2026-09-25-qq-02-tree-coverage]
---

# Session: LAT Parse via API Pilot (PENDING)

## Problem

22 Making laws in QQ's register have no LAT, so fractalaw can't enrich them and they have no expression tree (QQ-02 bucket a).

LAT sessions normally run through the admin UI. This pilot runs one **through the API, semi-automatically (Claude + Jason)**, as the first proven slice of the AI parsing workflow (`2026-09-25-ai-parsing-workflow`): LAT session → parse → QA → fractalaw handoff → receipt check.

What it learns decides what the workflow API needs before an agent can run it.

## Todo

- ⬜ Pre-parse gate: check the 22 against the amending-SI policy ("inserts duties into a principal Act" means not Making). Candidates: `UK_ssi_2007_80`, `UK_uksi_2018_98`, `UK_wsi_2001_3545` and `UK_wsi_2009_2861`. Record verdicts with `mix making.review`, and drop any that aren't Making.
- ⬜ Machine access for the LAT session endpoints: an `X-API-Key` scope following the `:api_ai` / `AiApiKeyPlug` precedent (`AI_SERVICE_API_KEY`), and no browser cookie. Read vs write.
- ⬜ Drive the session through the API:
  1. `POST /api/lat/sessions/preview`
  2. `POST /api/lat/sessions/from-view` (by names)
  3. `PATCH …/records/select`
  4. Parse each law via `GET …/parse-stream?name=` (SSE, one law at a time)
  5. `POST …/confirm`

  Log each call, its result, and each point where a human decision was needed.
- ⬜ Assess the parse trigger. SSE per law suits a browser, but an agent needs a job-style trigger plus status polling, or a batch endpoint. Decide whether to add one.
- ⬜ QA: `lat-qa` checks (shape, hierarchy, annotations) for the parsed laws; confirm the #162 extent refresh ran after LAT persist (`geo_extent_source` may move to `lat_provisions`)
- ⬜ Fractalaw handoff:
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
