# L7 Decisions & Governance — Schema

How governance interfaces with the compliance framework. L7 produces two things: **configuration** that shapes how L1–L6 operate, and **decision records** that provide provenance for governance acts.

---

## What governance produces

| Output type | What it is | Persistence |
|------------|-----------|-------------|
| **Configuration** | Rules, thresholds, and parameters that shape framework behaviour | Persisted as governance parameters — not operational data |
| **Decision records** | Provenance for governance acts (risk acceptance, policy approval, resource allocation) | Persisted as governance decisions — or in external governance tools |
| **Reports** | Projections from L1–L6 data for board/management consumption | Not persisted — generated on demand from operational data |

L7 does not add operational data to L1–L6. It **configures** L1–L6 and **records** the governance decisions that drove the configuration.

---

## Governance functions (synthesis, not a standard)

Six functions synthesised from ISO management system requirements (Clause 5 Leadership, Clause 9.3 Management Review), UK Corporate Governance Code 2024, FCA SM&CR, DOJ Compliance Programme Evaluation, and IRM Risk Appetite Guidance. No single standard lists exactly these six — they are a working model, not a citation.

| Function | What it does | Framework effect |
|----------|-------------|-----------------|
| **1. Policy** | States the organisation's approach to compliance | Creates the context within which L1–L6 operate. Policy documents are Artefacts. |
| **2. Risk appetite** | Defines acceptable residual risk, explicitly | Sets thresholds that configure L2 scoring, L4 VoI allocation, drift_interval calculations |
| **3. Management review** | Periodic review of framework performance, decision-making | Produces decisions (resource allocation, improvement mandates) and updates to configuration |
| **4. Senior reporting** | Posture-based reporting to board/committee | Consumed from L1–L6 data. No persistence — reports are projections. |
| **5. Accountability** | Named individuals accountable for framework effectiveness | Configures the governance roles on Personnel. Not control-level ownership (that's L3). |
| **6. Decision provenance** | Audit trail for governance decisions | Decision records with who, when, what information, what rationale, what was decided |

---

## Configuration: governance parameters

Governance decisions produce **parameters** that shape how the compliance framework operates. These are not operational data — they are the *settings* that operational data is evaluated against.

### Examples of governance parameters

| Parameter | What it configures | Layer affected |
|-----------|-------------------|---------------|
| "No obligation with Risk_Score > 15 may remain Non-Compliant for more than 90 days" | Maximum tolerance for high-risk non-compliance | L2 — triggers escalation when threshold breached |
| "All Enterprise blast radius controls must have a Judgement within 6 months" | Minimum judgement frequency for highest-consequence controls | L4 — configures drift_interval for Enterprise controls |
| "Any Gap with Exit_Decision = Protect Adaptation must be reviewed at next management review" | Governance review of adaptation decisions | L4 → L7 — adaptation gaps surfaced to governance |
| "Limited or No Assurance ratings must be reported to the board within 5 working days" | Assurance escalation threshold | L5 → L7 — assurance findings trigger governance notification |
| "All Regulatory Change events with urgency = Immediate must have an owner within 24 hours" | Event response SLA | L6 — time-bound ownership requirement |
| "Management review covers L1–L6 performance quarterly" | Review cycle | Cross-cutting — defines the review cadence |
| "Compliance posture report to board includes leading indicators" | Reporting content requirements | Cross-cutting — defines what reports must contain |

### Where parameters live

Two options:

**Option A: Governance Parameters entity** — a key-value table storing named parameters with values, effective dates, approval provenance, and the governance decision that set them. This makes parameters first-class, queryable, and version-controlled.

**Option B: Distributed configuration** — parameters live on the entities they configure (e.g. a `max_noncompliance_days` field on Assessments, a `min_judgement_interval` field on Controls). Simpler but harder to see the full governance picture.

**Recommended: Option A for the canonical schema, Option B for the Baserow projection.** The canonical schema has a Governance Parameters entity that captures the governance intent. The Baserow projection may implement these as fields on existing tables or as fractalaw-enforced rules, since Baserow can't enforce cross-table business rules.

### Governance Parameters entity (canonical)

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `id` | uuid | no | PK |
| `parameter_name` | text | no | Human-readable name of the parameter |
| `parameter_key` | text | no | Machine-readable key (e.g. `max_noncompliance_days_high_risk`) |
| `value` | text | no | The parameter value (text — interpreted by consuming layer) |
| `layer_affected` | enum | no | Which layer this parameter configures (L1–L6 or Cross-cutting) |
| `rationale` | text | yes | Why this parameter is set to this value |
| `effective_from` | date | no | When this parameter takes effect |
| `supersedes_id` | uuid | yes | FK → governance_parameters. Which prior parameter this replaces. |
| `approved_by_id` | uuid | no | FK → personnel. Who approved this parameter (governance role). |
| `approved_at` | timestamp | no | When approval was given |
| `review_date` | date | yes | When this parameter should be reviewed |
| `decision_ref` | text | yes | Reference to the governance decision that set this (management review minutes, board paper) |
| `status` | enum | no | Active / Superseded / Retired |

```
layer_affected: L1 | L2 | L3 | L4 | L5 | L6 | Cross-cutting

status: Active | Superseded | Retired
```

This entity is **version-controlled by construction** — changing a parameter creates a new record that supersedes the old one. The history is the audit trail. "What was the risk appetite threshold in January 2026?" is answerable by querying supersession chains.

---

## Decision records: governance provenance

Governance decisions that need provenance — risk acceptance, policy approval, resource allocation, escalation decisions, management review outputs.

### Do we need a new entity?

The deferred `Decisions` entity from the SMS build spec (see [EVIDENCE-SCHEMA.md](../l4-evidence/EVIDENCE-SCHEMA.md) § 4) was designed for this. It captures: trigger, what was seen, options considered, choice made, risk classification, owner, approver, supersession.

**The question**: does `Decisions` live at L4 (as originally planned) or at L7?

**Answer: L7.** The Decisions entity was originally placed at L4 as provenance for Gap exits. But Gap exits are operational decisions ("correct the work" vs "amend the constraint"). The full Decisions entity — with approval chains, supersession, risk classification (risk-making / risk-taking / risk-averse / risk-blind) — is a governance concept. Operational decisions are adequately captured by Gaps (reason + owner + decision_date). Governance decisions need more.

For now (PoC): governance decisions are recorded in external systems (board minutes, GRC tools) and referenced via `decision_ref` on Governance Parameters and via `assurance_ref` on Artefacts (for policy documents). The Decisions entity remains deferred.

When built, the Decisions entity should sit at L7 and link downward:

```
Governance Decision (L7)
    |
    |--> Governance Parameter changed (L7) — "risk appetite threshold updated"
    |--> Policy Artefact created (L4) — "new policy document approved"
    |--> Resource allocation — "budget approved for L4 judgement programme"
    |--> Risk acceptance — "residual risk in domain X accepted until review date"
    |--> Escalation response — "board decided to escalate L6 event to regulator"
```

---

## Policy as an Artefact

A compliance policy document is an **Artefact** in L4 — a thing that exists. It has:
- `artefact_type`: Policy
- `artefact_class`: Activity (the policy exists, but its existence alone doesn't prove compliance)
- `assurance_ref`: may reference the governance decision that approved it
- Version, expiry, status (Current / Superseded)

The policy's *content* (risk appetite statement, escalation rules, accountability definitions) produces **Governance Parameters** when those statements are translated into actionable thresholds. The policy document is the source; the parameters are the operational expression.

---

## Accountability as Personnel configuration

Governance accountability extends the Personnel entity (already in the schema) with governance-level role information.

Two options:

**Option A: Governance role field on Personnel** — add a `governance_role` field (e.g. "Compliance Framework Owner", "Board Sponsor", "Management Review Chair"). Simple.

**Option B: Separate accountability map** — a table mapping governance roles to personnel, with statements of responsibility. More structured, closer to SM&CR.

**For the PoC**: Option A. Add a `governance_role` text field to Personnel. The full SM&CR-style accountability map (prescribed responsibilities, statements of responsibility) is a future extension.

---

## Senior reporting as projections

Reports are generated from L1–L6 data, not persisted. L7 defines **what reports must contain** (via governance parameters) but does not store the reports themselves.

Standard governance reports (generated, not entities):

| Report | Source data | Governance question it answers |
|--------|-----------|-------------------------------|
| **Compliance posture by domain** | L2 Assessments grouped by Family | Are we meeting our obligations? Where are the gaps? |
| **Control coverage** | L3 Controls × L4 Judgements | Which controls have been judged? Which haven't? How stale? |
| **Assurance coverage** | L5 Artefacts with assurance metadata | What has been independently verified? What hasn't? |
| **Event pipeline** | L6 Compliance Events by response_status | What's coming? How quickly are we responding? |
| **Risk appetite compliance** | L2 Risk Scores vs L7 Governance Parameters | Are we within appetite? Where are we breaching thresholds? |
| **Open gaps by exit type** | L4 Gaps by exit_decision | How many adaptations are we protecting? How many are corrective? |
| **Leading indicators** | L4 judgements due, L6 events in triage, L3 controls approaching verification | What might go wrong next? |

These are **queries/views**, not entities. In Baserow, they are saved views with filters and grouping. In CAT, they are dashboards. In the canonical schema, they are defined as report specifications in the governance parameters ("quarterly posture report must include X, Y, Z").

---

## Baserow projection

| Canonical concept | Baserow adaptation |
|-------------------|-------------------|
| **Governance Parameters** | A table with parameter_name, value, layer_affected, approved_by, effective_from, status. Simple key-value with provenance. |
| **Decisions** | Deferred. Governance decisions recorded in external tools. Referenced via `decision_ref` on parameters. |
| **Policy documents** | Artefacts with artefact_type = Policy |
| **Accountability** | `Governance_Role` text field on Personnel |
| **Reports** | Saved views on existing tables (L2, L3, L4, L5, L6) |

### Views on Governance Parameters table

| View | Type | Purpose |
|------|------|---------|
| All Parameters | Grid | Default |
| Active Parameters | Grid | Filtered: status = Active |
| By Layer | Grid | Grouped by layer_affected |
| Under Review | Grid | Filtered: review_date approaching |

---

## What L7 is NOT (final clarity)

- **Not a second Actions table.** L2 Actions tracks remediation tasks. L7 does not duplicate this.
- **Not a second Gaps table.** L4 Gaps captures operational reconciliation decisions. L7 governs the framework that produces Gaps, not the Gaps themselves.
- **Not an audit function.** L5 provides the assurance seam. L7 receives assurance findings and acts on them.
- **Not operational.** L7 does not design controls, assess compliance, or collect evidence. It configures the framework that does.

L7 is the thermostat, not the heating system. It sets the desired temperature (governance parameters) and checks whether the room is warm enough (management review). The boiler, pipes, and radiators are L1–L6.

---

## References

- `GOVERNANCE-PATTERNS.md` — research findings, six governance functions, regulatory expectations
- `EVIDENCE-SCHEMA.md` § 4 — deferred Decisions entity (now positioned at L7)
- `VALUE-OF-INFORMATION.md` — VoI framework (risk appetite sets the threshold)
- `ASSURANCE-INTERFACE.md` — L5 seam (governance receives assurance findings)
- `EVENTS-SCHEMA.md` — L6 events (governance receives event trends)
- `COMPLIANCE-7-LAYERS.md` — L7 definition
- ISO 45001/14001/9001 Clause 5 (Leadership), Clause 9.3 (Management Review)
- UK Corporate Governance Code 2024 — Principle O, Provisions 25, 29
- FCA SM&CR — accountability model
- DOJ Evaluation of Corporate Compliance Programs
