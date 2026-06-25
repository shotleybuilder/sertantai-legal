---
name: Customer Pipeline Status
description: Run `mix customer.pipeline_status` to report a customer's law corpus readiness — from applicability through LAT parsing, fractalaw enrichment, to Baserow-ready governed duties.
---

# Customer Pipeline Status

## When to use

- Before a Baserow sync — check data readiness
- After a LAT parse session — see enrichment progress
- After fractalaw publishing — verify coverage
- Customer onboarding — track pipeline progress
- Ad-hoc — "how many laws/duties do we have for this customer?"

## Usage

```bash
cd backend

# QQ default org
mix customer.pipeline_status

# Specific org
mix customer.pipeline_status --org-id c075d56b-8420-4408-b695-ccfbc1ba15ec

# Per-law detail table
mix customer.pipeline_status --verbose

# Only show flagged laws (issues needing attention)
mix customer.pipeline_status --flags
```

## What it reports

### Summary
- Applicable laws: total, in-force, part-revoked, fully revoked
- LAT coverage: parsed, zero-result (dead end), not yet parsed
- Taxa enrichment: enriched, partially enriched, awaiting fractalaw
- Governed duties: aggregated provision count (Baserow-ready)

### Per-law detail (--verbose)
Columnar table: law_name, title, live status, LAT count, taxa %, fractalaw stage, duty count.

### Flags (--flags)
- Applicable but revoked — consider removing from applicability
- LAT parsed but 0 enriched provisions — fractalaw hasn't processed
- Fractalaw stage != published — still in pipeline

## Pipeline stages

```
1. Applicable (org_applicabilities status=yes)
2. In-force check (legal_register.live)
3. LAT parsed (legal_register.lat_count > 0)
4. Taxa enriched (legal_articles.taxa_enriched_at)
5. Fractalaw stage (needs_lat → needs_embed → needs_parse → needs_classify → needs_validate → ready_to_publish → published)
6. Governed duties (Obligation DRRP + non-Gvt active actors, aggregated to provision level)
```

## Notes

- Fractalaw status requires Zenoh session — skipped gracefully if unavailable
- Governed duty count uses the Goldilocks aggregation model (same as Baserow sync)
- DRRP filter: `Obligation` = duties/responsibilities in Hohfeldian vocab
- Governed filter: active actors excluding `Gvt:` and `EU:` prefixes

## Related skills

- `customer-onboarding-import` — initial CSV import and applicability seeding
- `customer-quality-report` — quality analysis comparing vendor vs SertantAI
- `lat-parse-session` — parse LAT for applicable laws
- `prod-data-sync` — sync data to production
