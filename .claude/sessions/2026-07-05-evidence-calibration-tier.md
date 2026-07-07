# Title: Evidence & Calibration Tier — L4 Redesign

**Started**: 2026-07-05
**Status**: ACTIVE

## Context

The Evidence Vault (from the baserow-compliance-poc session) was critically reviewed against the SMS Form Dialectic (`~/Desktop/dialectics/dialectics/output/sms-form-dialectic/`). The review (`docs/EVIDENCE-VAULT-CRITIQUE.md`) found that while the Artifact/Judgement distinction and the Info_Distance × Staleness × Blast_Radius model are sound, the implementation falls short in fundamental ways:

1. Confidence is an uncalibrated H/M/L tick, not measurable calibrated probability
2. Evidence, calibration, and decisions are conflated into one table
3. No scheduling/regime for calibration — theory without mechanism
4. Type-A (activity) evidence dominates; no Type-B (outcome) distinction
5. The three exits (correct work / amend constraint / protect adaptation) are absent
6. No "what's missing" mechanism for the absent gauge problem
7. Reasoning is free-text prose, not structured findings

The deepest challenge: the Evidence Vault is still a document repository with extra fields, not a calibration ledger. This session redesigns L4 as a proper tier with distinct tables, workflows, and — critically — fractalaw edge AI for the "beyond Baserow" mechanism layer.

## Key design inputs

- `docs/EVIDENCE-VAULT-PATTERNS.md` — current design (Artifact/Judgement, operationalisation paradox, control-property-driven strategy)
- `docs/EVIDENCE-VAULT-CRITIQUE.md` — the critique (8 issues, severity ratings, fix proposals)
- `docs/BASEROW-CONTROLS-DESIGN.md` — L3 Controls ontology (Properties/Methods/Events/Distance)
- `docs/reviews/2026-07-05-gemini-evidence-calibration-review.md` — Gemini 2.5 Pro review
- ChatGPT review (2026-07-05) — structural feedback on entity boundaries, lifecycle, falsification
- SMS Form Dialectic:
  - `definitions.md` — calibration, gauge, drift, load-bearing, split terminus
  - `build_spec_draft_v0.1.md` — constraints, readings, calibrations, decisions, people tables
  - `brief_operationalisation-paradox_for_leaders.md` — legible vs load-bearing
  - `brief_calibrating-edges_for_leaders.md` — signal not score; thermometer not thermostat

## Architecture principles

### Two layers, not one

- **Baserow** = the customer-facing compliance workspace (structured data, views, human workflow)
- **fractalaw / sertantai** = edge AI apps that scan data, compute drift_interval, fire calibration signals, detect absent gauges — the mechanism layer Baserow can't provide

fractalaw already runs AI apps on the edge (Zenoh P2P mesh, scanning data, sending informational signals). The calibration regime is a natural fit: edge apps watch control staleness, compute priority, and send signals to the Baserow workspace (or directly to the compliance officer) when calibration is due. The scheduling/regime problem is solved by fractalaw, not Baserow.

### Schema-first, then project

Previous templates (L1–L3, Assessments, Actions, Personnel) were designed *for Baserow* — Baserow field types, Baserow views, Baserow constraints. For the calibration tier we **reverse this**: define the canonical entity model first (provider-agnostic, SQL-expressible), then tune it for Baserow as one projection.

This matters because:
- The canonical schema is the source of truth. It can project onto Baserow, SQL (Ash/Ecto), or a graph store.
- Baserow limitations (no conditional fields, no computed cross-table queries, no scheduling) are handled by *constraining the projection*, not by warping the schema.
- The L1–L3 templates were Baserow-first — and we'll eventually extract their canonical schemas *from* Baserow. For L4, we don't create that debt.

**Deliverable**: `docs/EVIDENCE-SCHEMA.md` — the canonical L4 entity model with relationships, constraints, and lifecycle rules. The Baserow template is derived from it, not the other way around.

## The L4 entity model

The full L4 tier has five first-class entities (mirrors the SMS build spec):

```
Evidence (artifacts — proof of form)
    ↓
Readings (observations — does the predicate hold now?)
    ↓
Calibrations (re-truing — does the gauge still mean what we think?)
    ↓
Gaps (reconciliation — the governed gap with three exits)
    ↓
Actions (work — one possible child of a gap)
```

**For the Baserow PoC**, we build three now and leave two seams visible:

| Entity | Build now? | Rationale |
|--------|-----------|-----------|
| **Evidence** | Yes | Artifacts, Type-A/B distinction. Exists today, refactored. |
| **Calibrations** | Yes | Structured judgement records. The core of the redesign. |
| **Gaps** | Yes | The governed gap with three exits. First-class, not bolted onto Calibrations. |
| Readings | Deferred | fractalaw will generate these. Seam visible: Calibrations.Basis captures what was observed, Readings will formalise it. |
| Decisions | Deferred | The decision trail. Seam visible: Gaps.Exit_Decision captures the choice, Decisions will give it provenance (approved_by, supersedes). |

## Design decisions (resolved)

Reviewed by Gemini 2.5 Pro and ChatGPT. All questions resolved:

### 1. Three tables now, five eventually
**Evidence** (artifacts), **Calibrations** (judgements), and **Gaps** (reconciliation decisions) are separate Baserow tables. Readings and Decisions are deferred but their seams are visible in the schema. The conflation of evidence, calibration, and decisions into one table was the original sin — separate entities enforce distinct lifecycles, authors, cadences, and semantics at the database level.

### 2. No record-level confidence field (ChatGPT challenge — accepted)
**Remove the per-record Confidence field entirely.** Calibration quality belongs to the *observer*, not the *observation*. The important variable is not "Alice felt 82%" vs "Bob felt High" — it's "Alice has demonstrated calibration over 120 predictions." The observation records Finding, Basis, Reasoning. The observer (Personnel) records Calibration_Score, Calibrated_Domains, calibration history. Only introduce probability where the assessment protocol genuinely asks for probabilistic judgement — not as a default field people fill with meaningless numbers.

### 3. fractalaw publishes facts, not conclusions (ChatGPT challenge — accepted)
Don't publish `calibration_due`. Publish **observations**:
```json
{"type": "control.stale", "control": "Permit to Work", "days_since_verification": 183, "expected_interval": 90, "blast_radius": "Site", "info_distance": "Remote"}
{"type": "control.no_calibration", "control": "Confined Space Entry", "days_since_creation": 365}
{"type": "control.artifact_only", "control": "Lone Working RA", "artifact_count": 3, "calibration_count": 0}
```
Then another service (or the sertantai-legal backend) decides: notify / ignore / aggregate / escalate. This keeps fractalaw composable — it observes, it doesn't conclude. The signal carries context for a human decision, not a pre-made verdict.

### 4. Three exits on the Gap entity (ChatGPT challenge — accepted)
**Neither Actions nor Calibrations own the exit. Gaps do.**

The workflow is: Calibration → Gap identified? → Gap classification → Exit → Action (maybe).

- `Protect Adaptation` creates **no Action** — so Action can't own the exit
- A Calibration may find **no gap** (Finding = Still True) — so Calibration shouldn't own it either
- The entity is **Gap**: type, exit, reason, status

```
Gap
├── Correct Work      → Action
├── Amend Constraint  → Constraint Change
└── Protect Adaptation → Learning Record (no action needed)
```

### 5. Coverage: fractalaw writes Coverage_Status to Controls (ChatGPT challenge — accepted)
Don't solve inside Baserow with fragile cross-table formulas. fractalaw periodically computes coverage state per control and writes it back:
```
Coverage_Status: No Calibration / Artifact Only / Calibration Current / Calibration Stale / Unknown
```
Then Baserow views are trivial: `WHERE Coverage_Status != 'Calibration Current'`. One source of truth, computed by the mechanism layer.

## Todo

### Phase 1: Critical review
- [x] Share plan + critique with Gemini for critical feedback
  - Review saved: `docs/reviews/2026-07-05-gemini-evidence-calibration-review.md`
- [x] Incorporate Gemini feedback — 5 design questions initially resolved
- [x] Incorporate ChatGPT feedback — 3 design decisions changed (confidence removed, facts not conclusions, Gap as entity)

### Phase 2: Canonical schema + Baserow projection

#### 2.0 Define canonical L4 schema (`docs/EVIDENCE-SCHEMA.md`)
- [x] Define all 5 entities (Evidence, Readings, Calibrations, Gaps, Decisions) with:
  - Fields, types, constraints (NOT NULL, enums, foreign keys)
  - Lifecycle rules (immutability, state transitions)
  - Relationships (cardinality, cascades)
  - Which are built now vs deferred (Readings, Decisions)
- [x] Define the Calibrator quality extension to People/Personnel
- [x] Define Coverage_Status + audited override (recommended/scheduled/override_reason) on Controls
- [x] Define Incidents falsification link (calibration_id, control_id, vindication feedback loop)
- [x] Express as provider-agnostic types with Baserow projection notes
- [ ] Peer review the schema before building templates

#### 2a. Build **Calibrations** template (Baserow projection of canonical schema)
- Primary: `Calibration` formula — `concat(field('Control'), ' — ', field('Finding'))`
- `Control`: link_row → Controls
- `Calibrator`: link_row → Personnel (people sub-pattern)
- `Calibration_Method`: single select — Visual Inspection / Functional Test / Simulation / Interview / Observation / Exercise / Document Review
- `Basis`: long text — what was observed, reviewed, or tested
- `Finding`: single select — Still True / Drifted / Retired
- `Verified_Meaning`: long text — what "verified" means right now (re-anchored meaning)
- `Next_Due`: date
- `Assessment`: link_row → Assessments (optional)
- `Notes`: long text
- **Immutability principle**: calibration records are never edited. New judgement = new record.
- Views: All Calibrations, By Control, By Finding (kanban), Due Soon, By Calibrator, By Method
- Requires: [:controls, :personnel]

#### 2b. Build **Gaps** template (new table)
- Primary: `Gap` formula — `concat(field('Calibration'), ' → ', field('Exit_Decision'))`
- `Calibration`: link_row → Calibrations (which calibration identified this gap)
- `Control`: link_row → Controls (denormalised for view convenience)
- `Gap_Type`: single select — Drift / Non-Conformance / Deviation / Near Miss
- `Exit_Decision`: single select — Correct Work / Amend Constraint / Protect Adaptation
- `Reason`: long text — why this exit was chosen
- `Status`: single select — Open / Resolved / Accepted
- `Owner`: link_row → Personnel (who owns the resolution)
- `Action`: link_row → Actions (created if Exit = Correct Work)
- `Notes`: long text
- Views: All Gaps, Open Gaps, By Exit (kanban: Correct/Amend/Protect), By Control
- Requires: [:calibrations, :controls, :personnel]

#### 2c. Refactor **Evidence** template (strip judgement fields)
- Remove: Evidence_Nature, Judged_By, Basis, Reasoning, Confidence
- Keep: Title, Type, Assessment, Action, Control, artifact fields, Uploaded_By, Version, Expiry_Date, Status, Notes
- Add: `Evidence_Class` single select — Activity / Outcome (Type-A / Type-B)
- Update requires: [:compliance_assessment, :controls] (no longer depends on Calibrations)

#### 2d. Update **Personnel** template — calibrator quality
- `Calibration_Score`: number (Hubbard-style, 0-100)
- `Last_Cal_Test`: date
- `Calibrated_Domains`: multi-select

#### 2e. Update **Action Tracker** template
- Add: `Calibration` link_row → Calibrations (which calibration triggered this action, via the Gap)
- Add: `Gap` link_row → Gaps (which gap this action resolves)

#### 2f. Add **Coverage_Status** to Controls template
- `Coverage_Status`: single select — No Calibration / Artifact Only / Calibration Current / Calibration Stale / Unknown
- Computed by fractalaw, written via API. Not manually set.

#### 2g. Registry, mix task, tests
- Register Calibrations + Gaps in Registry
- Update templates.apply (table_ids load/save)
- Update test count and add specs for new templates

### Phase 3: fractalaw observation signals (edge AI)
- [ ] Design observation signal app:
  - Scans Controls properties (Blast_Radius, Info_Distance, Frequency, Last_Verified)
  - Computes expected calibration interval per control
  - Emits **fact signals** (not conclusions):
    - `control.stale` — days_since_verification > expected_interval
    - `control.no_calibration` — no linked calibration records
    - `control.artifact_only` — evidence exists but no calibrations
    - `obligation.unmapped` — no control mappings for this obligation
  - **Guard**: no priority score in the signal. Facts only. Let the consumer decide.
- [ ] Design Coverage_Status writer:
  - Periodically computes per-control coverage state
  - Writes Coverage_Status back to Controls table via Baserow API
- [ ] Zenoh topics:
  - `fractalaw/@dev/observations/controls/*` — control-level facts
  - `fractalaw/@dev/observations/coverage/*` — coverage-level facts
  - Subscribe in sertantai-legal backend to route → notification / Baserow update

### Phase 4: Workflow & UX design
- [ ] Map calibration workflow end-to-end:
  1. fractalaw emits `control.stale` → sertantai-legal routes notification
  2. Compliance officer sees the signal → opens Control in Baserow
  3. Calibrator reviews control using specified Calibration_Method → writes Calibration record (immutable)
  4. Finding: Still True → loop closes, Next_Due set
  5. Finding: Drifted → **Gap record created**
  6. Gap owner chooses Exit_Decision:
     - Correct Work → Action created, linked to Gap
     - Amend Constraint → constraint/control update workflow
     - Protect Adaptation → Gap closed as Accepted, learning recorded, no Action
  7. Next_Due set on Calibration → fractalaw picks up new interval → cycle continues
- [ ] Map "absent gauge" workflow:
  1. fractalaw emits `control.no_calibration` or `obligation.unmapped`
  2. Compliance officer reviews
  3. Decision: add control / schedule first calibration / accept risk
- [ ] Design Baserow views:
  - Calibration Queue: Controls where Coverage_Status != 'Calibration Current'
  - Control Health: grouped by Coverage_Status
  - Control Detail: control + obligations + evidence + calibration history + open gaps
  - Gap Board: kanban by Exit_Decision
- [ ] Design standing question: "what's not on this board?" — Controls with Coverage_Status = 'Unknown' or 'No Calibration'

### Phase 5: Apply to QQ Baserow
- [ ] Apply new Calibrations template
- [ ] Apply new Gaps template
- [ ] Refactor existing Evidence table (remove judgement fields, add Evidence_Class)
- [ ] Apply updated Personnel (calibrator fields)
- [ ] Apply updated Action Tracker (Calibration + Gap link_rows)
- [ ] Add Coverage_Status field to Controls
- [ ] Validate end-to-end: Control → Calibration → Gap → Exit → Action → Evidence

### Phase 6: Documentation
- [ ] Finalise `docs/EVIDENCE-SCHEMA.md` — canonical L4 entity model (created in Phase 2.0, refined through implementation)
- [ ] Update `docs/EVIDENCE-VAULT-PATTERNS.md` with final design (two tables, Type-A/B, no confidence)
- [ ] Update `docs/BASEROW-SCHEMA.md` with new tables/relationships
- [ ] Update `docs/BASEROW-TEMPLATES.md` with new/modified templates
- [ ] Write `docs/CALIBRATION-REGIME.md` — fractalaw mechanism layer + workflow design
- [ ] Close issues in EVIDENCE-VAULT-CRITIQUE.md (mark resolved/deferred)
- [ ] Note: L1–L3 canonical schemas to be extracted *from* Baserow templates in a future session (reverse of the L4 approach)

## Review feedback incorporated

### Gemini 2.5 Pro — initial review (`docs/reviews/2026-07-05-gemini-evidence-calibration-review.md`)

| Feedback | Action |
|----------|--------|
| Two separate tables | Adopted — extended to three (+ Gaps) |
| Keep H/M/L, add calibrator quality on Personnel | Superseded by ChatGPT — confidence removed entirely. **Gemini agreed on right of reply.** |
| Rich JSON signal format | Superseded by ChatGPT — publish facts not conclusions. **Gemini agreed: "foundational principle of good event-driven architecture."** |
| Three exits on Calibrations, not Actions | Superseded by ChatGPT — exits on Gap entity. **Gemini strongly agreed: "the single most important improvement."** |
| Hybrid coverage (Baserow rollup + fractalaw) | Superseded by ChatGPT — fractalaw writes Coverage_Status |
| Add UX/view design task to Phase 4 | Adopted |
| Calibration records must be immutable | Adopted — documented as principle |
| Watch that priority score doesn't leak to humans | Adopted — strengthened: no priority score in signals at all |
| Add user training / doctrine track | Noted — deferred to post-build |

### Gemini 2.5 Pro — right of reply (`docs/reviews/2026-07-05-gemini-evidence-right-of-reply.md`)

| Feedback | Action |
|----------|--------|
| Agreed all 3 overturns were correct | Confirmed |
| Calibration_Method must be a controlled list (enum) | Already planned as single select |
| Lifecycle ownership: audited override model (Recommended + Scheduled + Override_Reason) | **Adopted** — open issue #1 resolved |
| Falsification: 4-step mechanism (Incident→Calibration→Personnel score update→Control link) | **Adopted** — open issue #2 resolved |
| Decision provenance: add Decision_Date + append-only Reason | **Adopted** — open issue #3 resolved |

### ChatGPT (2026-07-05)

| Feedback | Action |
|----------|--------|
| Model Gap as first-class entity | **Adopted** — Gaps table with Exit_Decision, linked to Calibrations and Actions |
| Remove record-level confidence | **Adopted** — calibration quality on observer (Personnel), not observation |
| Publish facts not conclusions | **Adopted** — fractalaw emits `control.stale` etc, not `calibration_due` |
| fractalaw writes Coverage_Status to Controls | **Adopted** — single field, trivial Baserow views |
| Add Calibration_Method field | **Adopted** — Visual Inspection / Functional Test / Simulation / Interview / Observation / Exercise / Document Review |
| Leave Reading + Decision seams visible | **Adopted** — noted as deferred entities in entity model |
| Calibration history analytics (trend, false rate, disagreement) | Noted — future work, fractalaw analytics layer |
| Lifecycle ownership (who owns interval changes?) | **Resolved** — audited override model (Gemini right of reply) |
| Falsification / feedback loop (failed predictions) | **Resolved** — 4-step mechanism with Personnel score update (Gemini right of reply) |
| Control effectiveness (success rate from readings) | Deferred to Readings entity |
| Define schema independently of Baserow | **Adopted** — architecture principle added |

## Open issues (from ChatGPT review — resolved via Gemini right of reply)

Gemini right of reply: `docs/reviews/2026-07-05-gemini-evidence-right-of-reply.md`
Gemini agreed with all three overturned decisions ("you made the right call on all three").

### 1. Lifecycle ownership — RESOLVED: audited override model
Two date fields on Controls:
- `Recommended_Next_Due` (read-only, written by fractalaw)
- `Scheduled_Next_Due` (user-editable, **the single source of truth** for alerting)
- `Next_Due_Override_Reason` (text, required if Scheduled differs from Recommended)

fractalaw writes Recommended. An automation copies Recommended → Scheduled only if Scheduled is empty or previously matched Recommended. Humans can override with a documented reason. Best of both: system's objective calculation preserved, human has final say with audited rationale.

### 2. Falsification / closed feedback loop — RESOLVED: four-step mechanism
1. Incident (L6) links to one or more Calibrations
2. `Vindication_Status` on Calibration: Supported / Contradicted / Unrelated
3. When Contradicted → event fires → **update Calibration_Score on the calibrator's Personnel record** (closes the loop to the observer — without this, the system records failure but doesn't learn)
4. Incident also links directly to the Control that failed → enables "controls that failed despite Calibration Current" analysis (identifies method failures, not just calibrator failures)

### 3. Decision provenance — RESOLVED: minimal high-value addition
Keep Gaps.Reason + Gaps.Owner for the PoC. Add:
- `Decision_Date` (timestamp — *when* was the risk accepted)
- Make Reason append-only in practice (each entry dated and attributed):
  ```
  [2026-08-15 | Alice.Jones] Decision: Accept Risk. Reason: cost of remediation outweighs impact...
  ---
  [2026-08-12 | Bob.Smith] Initial Assessment: Gap identified during routine audit.
  ```
This creates a lightweight audit trail on the Gap record — 80% of the value of the full Decisions table, defensible without the full entity.

## Docs referenced
- `docs/EVIDENCE-VAULT-CRITIQUE.md`
- `docs/EVIDENCE-VAULT-PATTERNS.md`
- `docs/BASEROW-CONTROLS-DESIGN.md`
- `docs/BASEROW-SCHEMA.md`
- `docs/reviews/2026-07-05-gemini-evidence-calibration-review.md` — Gemini initial review
- `docs/reviews/2026-07-05-gemini-evidence-right-of-reply.md` — Gemini right of reply (3 overturns + 3 open issues)
- SMS Form Dialectic (all rounds, especially build_spec_draft_v0.1.md)
