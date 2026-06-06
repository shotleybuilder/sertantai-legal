# Change Management — New Laws, Updates, Repeals + Sync

**Status**: DRAFT — Round 3 reviewed (Gemini 2.5 Flash x2 + ChatGPT o3, 2026-06-06)
**Meta-plan**: Phase 6 (sync) + Phase 7.7 (remaining)

## Problem

The legal landscape changes monthly. Laws are enacted, amended, partially revoked, fully repealed, and re-classified. SertantAI's monthly scrape session captures these changes in the LRT database — but currently there's no mechanism to propagate changes to customer registers or external tools like Baserow.

A customer with 200 laws in their register needs to know:
- "3 of your laws were repealed this month — review and archive?"
- "7 new laws match your profile — add to your register?"
- "12 laws had amendments — their duties may have changed"

Without this, the register goes stale and the compliance assurance gap grows.

## Governance Boundary

*Reviewed with ChatGPT o3 (2026-06-06) — governance feedback incorporated with clear ownership boundaries.*

SertantAI has two sides to compliance governance, and they live in different places:

| Concern | Owner | Where it lives |
|---------|-------|---------------|
| **Change detection** — what changed in the law | sertantai-legal (this service) | LRT database, scrape sessions |
| **Change notification** — telling the org | sertantai-legal | applicability_events, email/in-app |
| **Decision capture** — org records why they acted | sertantai-legal | applicability_events (decision_reason, decision_by) |
| **Materiality classification** — how significant is the change | sertantai-legal | Change event metadata (auto-classified) |
| **Compliance workflow** — assigned → reviewed → approved → closed | sertantai-compliance *(future SaaS)* | Compliance app or Baserow |
| **SLA / ageing** — how long have changes sat unreviewed | sertantai-compliance | Dashboard over event timestamps |
| **Assurance reporting** — register currency score, board metrics | sertantai-compliance | Reporting layer |
| **Multi-user governance** — safety manager → legal team → approved | sertantai-compliance | Workflow engine |
| **Business change events** — acquisition, new site, new activity | sertantai-compliance | Org profile triggers |
| **Interpretive change** — guidance, case law, ACoPs, enforcement focus | sertantai-enforcement + compliance | Risk/heat map overlay |

**This plan covers the left column** — what sertantai-legal owns. The compliance app and Baserow own the full review workflow, but sertantai-legal must capture enough to enable it: specifically the **decision** (what did the org decide?) and the **rationale** (why?).

### What sertantai-legal captures

The `applicability_events` audit trail already logs every change. ChatGPT correctly identified that auditors care less that a change occurred and more that:

> "The organisation became aware of the change, assessed the impact, and recorded a decision."

We extend the event model to capture the decision side:

| Field | Purpose | Example |
|-------|---------|---------|
| `event` | What happened (existing) | `law_repealed`, `added`, `removed` |
| `decision` | What the org decided | `archive`, `keep`, `dismiss`, `add` |
| `decision_reason` | Why (free text) | "Historical projects still reference it" |
| `decision_by` | Who decided (existing `actor`) | `jane.smith@qinetiq.com` |
| `review_due_date` | When should this be revisited | `2026-12-01` (optional) |

This means sertantai-legal records: **Detected → Notified → Decision + Rationale**. The compliance app can layer on top: Assigned → Under Review → Approved → Closed.

### Materiality classification

Not all changes are equal. A title correction and a major duty change shouldn't appear the same in the review queue.

| Level | Meaning | Auto-detection |
|-------|---------|---------------|
| **Informational** | Metadata only (title, description) | `updated_at` changed but no DRRP/status/fitness change |
| **Minor** | No expected duty impact | Fitness change only, or cosmetic status update |
| **Moderate** | Possible impact | DRRP actor change, family reclassification |
| **Major** | Likely compliance impact | Full/part repeal, new Making law, duty holder change |

The Change Review Dashboard then becomes:

```
🔴 1 major change (law repealed)
🟡 4 moderate changes (DRRP updates)
⚪ 7 informational changes (metadata)
```

Much better governance signal than "12 amended laws".

### Subscription-family drift

Explicit policy: **existing register entries remain until reviewed when a family is unsubscribed.** Subscription scope affects *future discovery*, not automatic removal. A customer who unsubscribes from "Waste" keeps their 15 Waste laws in the register — they just won't see *new* Waste laws in the Available panel.

### Applicability source and confidence

The existing `source` field on `org_applicabilities` tracks how a law entered the register (manual, screener, enhesa_import, consultant). ChatGPT raised a valid point: future automation must respect that **customer-confirmed laws have higher authority than screener-suggested laws**. The source hierarchy:

| Source | Authority | Auto-removable? |
|--------|-----------|-----------------|
| `manual` | Highest — human added it deliberately | Never |
| `confirmed` | High — human reviewed and approved screener suggestion | Never |
| `consultant` | High — external expert added | Never |
| `enhesa_import` | Medium — imported from legacy vendor | Never (but flag if match_score = 0) |
| `screener` | Low — auto-seeded, not yet confirmed | Yes, via deprecation preview |

Only `screener`-sourced laws can be auto-suggested for removal when profile changes reduce their match score.

## Change Sources

| Source | Frequency | What changes | Detection |
|--------|-----------|-------------|-----------|
| **Monthly scrape** | Monthly | New laws, status changes, metadata updates | Scrape session diff |
| **Fractalaw enrichment** | Ongoing | DRRP actors, fitness, making classification | Zenoh events |
| **Customer action** | Ad-hoc | Manual add/remove/exclude, profile change | Applicability events |
| **External register import** | One-time | Initial register population | Import session |
| **Compliance landscape** *(awareness)* | Ongoing | Enforcement cases, regulator signals, org's own regulatory dealings | sertantai-enforcement, regulator feeds, org input |

> **Note — Compliance landscape signals**: SertantAI already tracks enforcement (cases/notices) and will monitor regulator activity feeds. Orgs will also feed in their own regulatory dealings with customers/regulators. These signals combine into risk scores and heat maps that influence *prioritisation* of the legal register — e.g. "HSE is actively enforcing COSHH → review your COSHH compliance posture." This is a related but distinct change source: it doesn't change *which* laws apply, but it changes *urgency and risk weighting*. This plan focuses on the law-level changes (Categories 1–6 below). The compliance landscape layer will integrate later as a prioritisation overlay.

## Change Scenarios

### Category 1: Law Status Changes

| Scenario | What happened | Impact on register | Recommended action |
|----------|--------------|-------------------|-------------------|
| **1a. Full repeal** | Law status → `❌ Revoked / Repealed / Abolished` | Law no longer creates duties | Flag for review. Customer decides: archive (remove from register) or keep with status badge |
| **1b. Part repeal** | Law status → `⭕ Part Revocation / Repeal` | Some provisions still active | Update status badge. Don't remove — active duties remain |
| **1c. Commencement** | New law comes into force | Duties now active | Flag as newly active if in register |
| **1d. Superseded** | Old law replaced by new | Old law's duties transfer | Flag both: "X superseded by Y — review" |

### Category 2: New Laws

| Scenario | What happened | Impact on register | Recommended action |
|----------|--------------|-------------------|-------------------|
| **2a. New Making law in subscribed family** | Monthly scrape finds new law with duties | Potential compliance gap | Auto-screen against profile → strong matches auto-seed, others surface in Available panel |
| **2b. New law outside subscribed families** | New law in a family the org doesn't subscribe to | No impact | Ignore (unless family subscription changes) |
| **2c. Law gains Making classification** | Fractalaw enriches → previously non-Making law now has duties | Was invisible, now relevant | Re-run profile match → surface if it matches |

### Category 3: Amendment / Metadata Changes

| Scenario | What happened | Impact on register | Recommended action |
|----------|--------------|-------------------|-------------------|
| **3a. Duty holder change** | Fractalaw updates duty_holder actors | Profile match may change | Re-evaluate match_score. Flag score change but **don't suggest removal** for customer-confirmed laws — only deprecate if the specific profile tags that caused inclusion are removed (Category 4b) |
| **3b. Fitness change** | Fractalaw updates fitness dimensions | Same | Same |
| **3c. Family reclassification** | Law moves between families | May enter/leave subscription | Flag if entering subscribed family (new candidate) or leaving (review) |
| **3d. Title/description update** | Cosmetic metadata change | No duty impact | No action needed — update propagates via sync |

### Category 4: Customer Profile Changes

| Scenario | What happened | Impact on register | Recommended action |
|----------|--------------|-------------------|-------------------|
| **4a. Profile tag added** | Customer adds "asbestos" to materials | New laws may match | Delta seed: find laws matching new tag that aren't already in register |
| **4b. Profile tag removed** | Customer removes "diving operations" | Some laws may no longer match | Deprecation preview: "14 screener-seeded laws no longer match" |
| **4c. Family subscription change** | Customer adds/removes a family | Population changes | Re-run seed with new family scope. Flag newly in-scope laws |

### Category 5: Edge Cases (flagged by Gemini review)

| Scenario | What happened | Impact on register | Recommended action |
|----------|--------------|-------------------|-------------------|
| **5a. Law consolidation** | Laws A+B+C replaced by single new law D | Multiple register entries map to one new law | Flag all: "A, B, C consolidated into D — review" |
| **5b. Temporary/sunset law** | Law has built-in expiry date | Law ceases effect without formal repeal | Track sunset date. Auto-flag when approaching/past expiry |
| **5c. Jurisdiction change** | Law's applicability within UK shifts (E&W→GB, etc.) | May enter/leave org's regional scope | Re-evaluate against org's regions. Flag if newly in/out of scope |

### Category 6: Baserow Sync

| Scenario | What happened | Impact on Baserow | Recommended action |
|----------|--------------|------------------|-------------------|
| **6a. Law added to register** | Customer clicks [+] or seed adds law | New row in Baserow LRT table | Auto-sync: create row with all fields |
| **6b. Law removed from register** | Customer clicks [×] | Row exists in Baserow with customer enrichment | **DON'T auto-delete**. Options: mark as archived, update status field, or flag for manual removal |
| **6c. Law status changes** | Repeal/amendment | Baserow row needs status update | Sync status field. Customer's enrichment (notes, actions, evidence) preserved |
| **6d. DRRP/fitness update** | Fractalaw enrichment | Baserow fields may be outdated | Sync updated fields. Don't overwrite customer-added fields |
| **6e. Full re-sync** | Customer wants fresh push | Smart merge and reconcile | Flag orphaned Baserow rows, create missing, update stale — never delete customer enrichment |
| **6f. Customer deleted Baserow row** | Manual deletion in Baserow for active law | Row missing but law still in SertantAI register | Flag discrepancy: "Law X is in your register but missing from Baserow. Recreate?" Don't silently recreate |

## Design Principles

### 1. Never auto-delete from Baserow

Customer enrichment in Baserow (notes, action items, evidence links, assigned personnel) represents significant investment. Deleting a row because a law was repealed destroys that work. Instead:
- **Update status** field to "Repealed" / "Archived"
- Let the customer decide whether to remove
- Provide a "Clean up archived" button for explicit removal

### 2. Surface changes, don't impose them

The system should present changes as recommendations, not apply them silently:
- "3 laws repealed — review and archive?"
- "7 new laws match your profile — add?"
- "5 laws lost fitness match after profile change — review?"

The customer is the decision-maker. SertantAI surfaces the information.

### 3. Change is an event, decision is an event too

Every change *and every decision* should be logged in the audit trail (`applicability_events`):

**System events** (auto-generated):
- `law_status_changed` — repealed, part-revoked, commenced
- `new_law_available` — matches profile, entered subscribed family
- `match_score_changed` — DRRP/fitness update changed relevance
- `sync_pushed` — data pushed to Baserow
- `sync_failed` — push failed (rate limit, auth error)

**Decision events** (human-generated, with `decision_reason` in metadata):
- `change_reviewed` — user opened and assessed a flagged change
- `change_kept` — user decided to keep a repealed/deprecated law (with reason)
- `change_archived` — user decided to archive a repealed law (with reason)
- `change_dismissed` — user dismissed a new law suggestion (with reason)
- `change_accepted` — user accepted a new law into register (with reason)

The decision events are the governance gold: they prove the org *considered* the change and made an *accountable decision*.

### 4. Sync is a conscious action, not automatic

Don't auto-push to Baserow on every change. The customer controls when to sync:
- "Push to Baserow" button on screening page
- Shows what will change: "42 rows to create, 8 to update, 0 to archive"
- Preview mode before execution
- Sync is idempotent — safe to run multiple times

## Change Detection

### Monthly scrape diff

After each monthly scrape session, compare against the customer's register:

```sql
-- Laws in register that changed status
SELECT u.name, u.title_en, u.live,
       oa.status as register_status
FROM org_applicabilities oa
JOIN uk_lrt u ON u.name = oa.law_name
WHERE oa.organization_id = $1
  AND oa.status = 'yes'
  AND u.updated_at > $2  -- last sync timestamp
```

### New law detection

After scrape, run profile match for new laws only:

```sql
-- New Making laws since last check, not in register, matching profile
SELECT l.name, l.title_en, match_score(...)
FROM laws l
WHERE l.is_making = true
  AND l.created_at > $last_check
  AND l.family = ANY($subscribed_families)
  AND NOT EXISTS (SELECT 1 FROM org_applicabilities WHERE law_name = l.name)
```

### Enrichment change detection

Fractalaw Zenoh events already trigger on the subscriber. Could log a change event when duty_holder or fitness changes for a law in someone's register.

## User-Facing: Change Review Queue

A new section in `/app` — either a dedicated page or a panel on the screening page:

### Change Review Dashboard

```
┌──────────────────────────────────────────────────────────────┐
│ Changes Since Last Review (15 Jun 2026)                      │
│                                                              │
│ 🔴 MAJOR (4)                                                 │
│   Repealed Laws (3)                                  [Review]│
│   New Making Law (1)                                 [Review]│
│                                                              │
│ 🟡 MODERATE (4)                                              │
│   DRRP Actor Changes (3)                             [Review]│
│   Family Reclassification (1)                        [Review]│
│                                                              │
│ 🟢 NEW MATCHES (7)                                           │
│   Laws matching your profile                         [Review]│
│                                                              │
│ ⚪ INFORMATIONAL (7)                                         │
│   Metadata updates (auto-synced)                     [View]  │
│                                                              │
│ Last Baserow sync: 10 Jun 2026                               │
│ [Sync Updates (7)]  [Review Pending Changes (15)]            │
└──────────────────────────────────────────────────────────────┘
```

Each category expands to show the affected laws with recommended actions.

### Repealed Law Review (with decision capture)

```
"3 laws in your register have been repealed since your last review"

  UK_uksi_2002_1144  Personal Protective Equipment Regs
    [Archive] [Keep]  Reason: [________________________]

  UK_uksi_1994_2716  Conservation Habitats Regs
    [Archive] [Keep]  Reason: [________________________]

  UK_uksi_1999_1892  Trees Regulations
    [Archive] [Keep]  Reason: [________________________]

[Archive All]
```

Every decision logs to `applicability_events` with `decision`, `decision_reason`, and `decision_by`. This creates the audit evidence: *"Regulation repealed on 4 May. Reviewed by Jane Smith on 12 May. Decision: Keep. Reason: Historical projects still reference it."*

### New Law Review

```
"7 new laws match your profile (Org: Employer, Scotland)"

  UK_uksi_2026_412   Workplace Safety (Amendment) Regs   Score: 2  [Add] [Dismiss]
  UK_uksi_2026_389   Environmental Monitoring Regs       Score: 1  [Add] [Dismiss]
  ...

[Add All Matching]
```

Dismissals also capture a reason — six months later, this distinguishes "consciously rejected" from "accidentally ignored".

## Baserow Sync Strategy

### Field mapping for status

| Register status | Baserow treatment |
|----------------|------------------|
| `yes` (active) | Create/update row normally |
| `yes` (repealed law) | Update Status field to "Repealed". Don't delete row |
| `excluded` | Don't sync (not in register) |
| `unreviewed` | Don't sync (not confirmed) |

### Sync modes

1. **Incremental** (default): Only push changes since last sync
   - New register laws → create rows
   - Removed register laws → update Status to "Archived"
   - Changed law metadata → update fields (preserve customer fields)

2. **Full refresh**: Smart merge and reconcile *(not delete-and-recreate)*
   - Reconciles all SertantAI register laws against Baserow rows
   - Creates missing rows, updates stale metadata, flags orphaned Baserow rows
   - **Never deletes** customer enrichment — flags discrepancies for review
   - Destructive "delete all and recreate" only as a support-escalation recovery tool, if ever

### What NOT to sync

- Screener-seeded laws that haven't been confirmed (`source: 'screener'`) — optional, customer configurable
- Laws with `live = 'Revoked'` — unless customer explicitly chose to keep them

## Implementation Phases

### Phase A: Change detection
- Monthly scrape diff query for register laws
- New law detection query (profile match on new laws)
- Log change events to applicability_events
- Ensure Fractalaw enrichment changes reliably log events for laws in customer registers

### Phase B: Change notifications
- After each monthly scrape, auto-generate change summary per org
- In-app notification badge on Change Review nav item
- Email notification: "You have 3 repealed laws and 7 new matches to review"
- *Customers need to know changes exist before they can review them*

### Phase C: Change review UI
- `/app/changes` page or panel on screening page
- Categorised change queue (repealed, new, amended)
- Per-law actions (archive, add, dismiss)

### Phase D: Baserow sync button
- Split UI: "Sync Updates" (metadata) vs "Review Pending Changes" (structural)
- Incremental sync using existing Engine + Baserow provider
- Status field propagation (don't delete, update status)
- Scheduled metadata sync option (daily/weekly)

## Resolved Questions

*Reviewed by Gemini 2.5 Flash (2026-06-06)*

1. **Should screener-seeded (unconfirmed) laws sync to Baserow?** **No.** Baserow is for active compliance management, not speculative items. Unconfirmed laws belong in the Change Review Dashboard as recommendations. If a customer insists, offer as an advanced opt-in with a distinct status ("Proposed") — but default is confirmed-only.

2. **How to handle Baserow customer enrichment on repealed laws?** **Status update only, never delete.** Update the status field to "Repealed" / "Archived". Provide a "Clean up archived" button for explicit, manual removal. This is non-negotiable — destroying customer notes/actions/evidence is a critical failure.

3. **Sync frequency?** **Split approach.** On-demand (button press) for *structural changes* (adding new laws, archiving repealed ones). Scheduled (daily/weekly) for *metadata updates* to laws already in Baserow (DRRP changes, title updates, fitness updates). This keeps the register current without constant manual intervention while preserving customer control over what's in/out.

4. **What triggers "new law" detection?** **Batch after the entire monthly scrape session is validated.** Not mid-scrape — an incomplete scrape would produce inconsistent results. The validated scrape session is the atomic unit for triggering change detection across all categories.

5. **Should change review be mandatory before sync?** **Not for metadata updates, but yes for adds/archives.** The sync button should split into two actions:
   - "Sync Updates (to 12 existing laws)" — pushes metadata changes without review
   - "Review Pending Changes (3 repealed, 7 new)" — directs to Change Review Dashboard for decisions

## Open Questions (Remaining)

None — all resolved. See below.

## Resolved Questions (continued)

*From Gemini Round 1 review, resolved in Gemini Round 2 (2026-06-06):*

6. **Partial repeal granularity** — **Explicitly state the limitation.** DRRP/fitness is at law level; SertantAI cannot currently identify which specific provisions are still active after a partial repeal. Show a "Partial Repeal" status badge and recommend manual review. Don't fake sub-law granularity — that creates false assurance. This aligns with sertantai-legal's role in detection; the customer's legal team handles interpretation.

7. **Customer-deleted Baserow rows** — **Flag discrepancy, never auto-recreate.** Show in the Change Review Dashboard: "Law X is active in your register but missing from Baserow. Recreate?" The customer explicitly chooses. Auto-recreation would violate the "never impose" principle and could destroy an implicit customer decision.

8. **Baserow schema conflicts** — **Graceful per-field failure + field mapping UI.** If a required Baserow field is missing or renamed, the sync fails for that field/row and reports a clear error. Offer to create missing fields with explicit customer confirmation. A field mapping UI (future) puts control in the customer's hands. Never silently create or rename fields.

*From ChatGPT review, resolved in Gemini Round 2 (2026-06-06):*

9. **Decision reason — required or optional?** — **Required for Major and Moderate changes, optional for Minor and Informational.** This leverages the materiality classification: significant changes need documented rationale for auditability, while metadata tweaks shouldn't create friction. The UI enforces this — the [Archive]/[Keep]/[Dismiss] button is disabled until a reason is entered for Major/Moderate items.

10. **Review due dates** — **sertantai-legal sets defaults by materiality; customer overrides.** Defaults: Major 30 days, Moderate 60 days, Minor 90 days, Informational none. The customer can override during decision capture. sertantai-compliance consumes these dates for SLA tracking and ageing dashboards — sertantai-legal provides the starting data, not the enforcement.

11. **Interpretive change as first-class concept** — **Stays as compliance landscape overlay until sertantai-enforcement matures.** The trigger for graduation to a tracked change category is when sertantai-enforcement can provide structured, actionable data linked to specific laws and their DRRPs (e.g. "HSE guidance X affects duty Y in law Z"). Until then, interpretive signals remain a prioritisation input, not a change detection input.

## Key Files

| Purpose | Path |
|---------|------|
| Sync engine | `backend/lib/sertantai_legal/sync/engine.ex` |
| Baserow provider | `backend/lib/sertantai_legal/sync/providers/baserow.ex` |
| ProfileQuery | `backend/lib/sertantai_legal/sync/profile_query.ex` |
| ScreeningController | `backend/lib/sertantai_legal_web/controllers/screening_controller.ex` |
| ApplicabilityEvent | `backend/lib/sertantai_legal/sync/applicability_event.ex` |
| Screening page | `frontend/src/routes/app/screening/+page.svelte` |
| Scrape sessions | `backend/lib/sertantai_legal/scraper/resources/scrape_session.ex` |
