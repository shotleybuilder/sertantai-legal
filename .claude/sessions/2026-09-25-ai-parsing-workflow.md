---
session: Monthly Parsing Workflow API (AI-Operable)
status: pending
opened: 2026-09-25
related: [25, 161]
---

# Session: Monthly Parsing Workflow API (PENDING)

## Problem

Each month Jason pulls newly published laws from legislation.gov.uk, screens them for EHS + HR scope, parses them into the LRT, follows the cascade (laws the new ones affect and newly surfaced laws), then stands up a LAT parse session, which needs fractalaw's AI, and Jason launches that.

Today this runs through the admin UI and skills, driven by hand. The goal:
1. First, run it **semi-manually through an API**: Claude and Jason step through it, with a human deciding at each gate.
2. Once that's proven, **hand it to an agent**.

**The cascade needs sensible screening.** Without it, affected laws pull in more affected laws, and the chain reaction could reach all of legislation.gov.uk.

## Todo

- ⬜ Map the current monthly workflow end to end, using the `lrt-scrape-session` skill and `lat-parse-session` skill stages:
  - Stages: scrape → categorise (groups 1/2/3) → persist and parse → cascade → LAT session → fractalaw → QA → NAS → prod.
  - For each step, mark whether it's **mechanical**, a **judgement call**, or an **external launch** (fractalaw).
- ⬜ Scope policy for new laws as data, not UI clicks: the EHS + HR families, the categoriser groups (SI code match / term match / excluded), and how Making detection feeds the LAT queue
- ⬜ **Cascade screening policy.** For each affected law, decide:
  - Is it in scope? (family, already in the DB, Making, in a customer register)
  - What's the maximum layer?
  - What's the per-run budget?
  - Which update type: re-parse, or enacting-link only?

  Out-of-scope laws are recorded as skipped with a reason, never silently dropped.
- ⬜ Triage the existing cascade backlog with that policy: 4,882 layer-1, 921 layer-2 and 145 layer-3 re-parses pending, plus 108 enacting-link updates
- ⬜ Machine auth for the workflow endpoints: an API-key scope (the `:api_ai` / `AiApiKeyPlug` precedent) instead of browser JWT; read versus write keys
- ⬜ Workflow API: a thin, step-wise, idempotent surface over the existing controllers. Each step returns its result **and** the decisions it needs from a human. Steps: start run → screen → review queue → approve → parse → cascade plan → approve cascade → LAT session → fractalaw handoff → status.
- ⬜ Run record: one persisted record per monthly run (laws screened in or out and why, cascade decisions, parse outcomes, errors), in the spirit of `making_funnel`
- ⬜ Fractalaw handoff step: produce the law list and the preconditions (legal server up, snapshot taken), then wait for Jason to launch it; resume when the publish log arrives
- ⬜ Gemini review of the design (CLAUDE.md acceptance gate)
- ⬜ Dry run: take the next monthly batch through the API semi-manually (Claude + Jason). Record the decisions, the time taken, and where a human was really needed.
- ⬜ Agent handoff criteria and spec: which steps the agent may do alone, which need approval, and the stop conditions (for example, cascade growth beyond the budget)

## Dependencies

- ⬜ Fractalaw T4 complete (running 2026-09-25)
- ✅ Making write path and `making_funnel` (QQ-01a). Parse-time Making decisions are now traceable.
- ✅ Source-ranked extent at scrape time (#162)
- ✅ Existing JSON API behind the admin UI: scrape sessions (`/api/sessions/*`), cascade (`/api/cascade/*`), LAT sessions (`/api/lat/sessions/*`)
- ⬜ #25: Making detection with confidence (the parse-time pre-filter)

## Starting facts (2026-09-25)

- **The workflow endpoints already exist, but are admin-only.** They're behind `:api_admin` (cookie JWT + admin role). The one machine-auth precedent is `:api_ai` (API key, LAN).
- **The cascade is already running away.** `cascade_affected_laws` has 5,948 pending re-parses (layers 1–3), and the only brake is a max-layer deferral. Nothing checks whether an affected law is in scope.
- **The scrape categoriser splits new laws into three groups:** group 1 (SI code match), group 2 (term match, no SI code) and group 3 (excluded, for review).
