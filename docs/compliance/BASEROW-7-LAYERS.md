# Baserow PoC: 7-Layer Compliance Architecture Mapping

How the SertantAI Baserow PoC maps to the Compliance 7-Layer Architecture defined in `COMPLIANCE-7-LAYERS.md`.

---

## Layer Status Overview

| Layer | Name | Status | What We Have | What's Missing |
|-------|------|--------|-------------|----------------|
| **L1** | Obligations | **Built** | Legal Register, Duties, Actor Tuples | — |
| **L2** | Risk & Prioritisation | **Partial** | Significance ratings (fractalaw) | External signals, dynamic risk scoring |
| **L3** | Controls | **Gap** | — | Control framework linking obligations to operations |
| **L4** | Evidence | **Template ready** | Evidence Vault template (not applied) | Evidence-by-design, control-linked evidence |
| **L5** | Assurance | **Template ready** | Audit Management, Training Tracker templates | Control-linked assurance chain |
| **L6** | Events & Change Intelligence | **Partial** | Change Detection, Incident Register template | External intelligence feeds |
| **L7** | Decisions & Governance | **Not built** | — | Decision records, approval workflow, risk acceptance |

---

## L1 — Obligations (Legal Source + Derived)

**Status: Built**

| Component | Baserow Table | Source | Rows (QQ) |
|-----------|--------------|-------|-----------|
| Legal source | Legal Register | `mix sync.run` from `legal_register` | 274 |
| Derived obligations | Duties | `mix sync.run` — aggregated provisions, Obligation DRRP, governed actors | 2,400 |
| Actors | Actor Tuples | `mix sync.run` — normalised actor × position × DRRP | 485 |

**Architecture notes:**
- Source law → derived obligation separation is clean: LRT holds the law, LAT/Duties holds the provisions
- Obligation text is the aggregated (Goldilocks) provision text with sub-provisions concatenated
- Actor classification uses Hohfeldian positions (active = duty-bearer, counterparty = claim-holder)
- Governed-only filter excludes government responsibilities from the customer's Duties table
- Significance filter (HIGH + MEDIUM) manages row budget

**Key entities from L1 spec:** Laws ✓, Regulations ✓, Clauses ✓ (provisions), Obligations ✓ (DRRP-classified provisions)

---

## L2 — Risk & Prioritisation

**Status: Partial — significance built, external signals missing**

### What we have

| Signal | Source | Granularity | In Baserow? |
|--------|--------|------------|-------------|
| Significance overall | Fractalaw SLM | Per provision | ✓ Duties table |
| Significance gravity | Fractalaw SLM | Per provision | ✓ Duties table |
| Significance scope | Fractalaw SLM | Per provision | ✓ Duties table |
| Significance strength | Fractalaw SLM | Per provision | ✓ Duties table |
| Significance score | Fractalaw aggregation | Per law | ✓ Legal Register |
| Significance rating | Fractalaw percentile | Per law | ✓ Legal Register |

### What's missing

| Signal | Description | Potential source |
|--------|-------------|-----------------|
| Enforcement activity | Recent HSE/EA prosecutions, notices, fines | HSE enforcement database, EA public register |
| Regulatory press | Media coverage, consultations, upcoming changes | Gov.uk, HSE news feeds |
| Incident history | Customer's own incident data affecting this obligation | Incident Register (L6) |
| Near-miss correlation | Internal near-misses linked to specific obligations | Incident Register (L6) |
| Industry benchmarks | Peer compliance rates for this obligation | External data providers |

### To build for PoC

The Compliance Assessment template has `Risk_Level` (simple select: Critical/High/Medium/Low) which is the manual risk judgement. The matrix variant adds Likelihood × Impact scoring.

The gap is connecting fractalaw's AI-derived significance with the customer's own risk assessment. A provision rated HIGH by fractalaw might be LOW risk for a specific customer if their operations don't trigger that obligation.

**Future**: A composite risk score combining `significance_overall` (what the law demands) with `risk_level` (what the customer's exposure is).

---

## L3 — Controls

**Status: Gap — critical bridge missing**

### The problem

The Compliance Assessment template records "are we compliant?" but doesn't capture "how are we compliant?" — the operational controls that implement obligations.

Without L3, the compliance model is:
```
L1 Obligation → L4 Evidence (direct)
```

With L3, it becomes:
```
L1 Obligation → L3 Control → L4 Evidence
```

The control is the operational mechanism — a procedure, policy, inspection regime, training programme, engineering control — that ensures the obligation is met.

### What a Controls template would need

| Field | Type | Purpose |
|-------|------|---------|
| Control_ID | Formula (primary) | Display: concat(type, ' — ', title) |
| Title | Text | Short description of the control |
| Control_Type | Single select | Preventive / Detective / Corrective / Directive |
| Obligations | Link_row → Duties | Which obligations this control implements (many-to-many) |
| Owner | Link_row → Personnel | Who is accountable for this control operating |
| Frequency | Single select | Continuous / Daily / Weekly / Monthly / Quarterly / Annual / Ad-hoc |
| Description | Long text | How the control works operationally |
| Status | Single select | Active / Under Review / Planned / Retired |
| Last_Verified | Date | When control effectiveness was last checked |

### Why this matters

- **Proportionality**: One control can satisfy multiple obligations (e.g., a risk assessment procedure covers HSWA s.2, MHSW reg.3, CDM reg.4)
- **Gap analysis**: Obligations without controls = compliance gaps
- **Efficiency**: When a law changes, trace which controls are affected
- **Evidence linking**: Evidence proves the control operated, not the obligation directly

### Relationship to existing templates

```
Duties (L1) ←→ Controls (L3) ←→ Evidence (L4)
                    ↓
              Assessments (L2)  — compliance judgement based on control effectiveness
                    ↓
              Actions (L2)     — remediation when controls are inadequate
```

The Assessment should assess whether controls are adequate, not whether the obligation is met directly. This is a subtle but important shift.

---

## L4 — Evidence

**Status: Template ready, not applied**

The Evidence Vault template exists with two storage modes:
- `:embedded` — file uploads into Baserow
- `:reference` — URLs pointing to SharePoint/DMS

Currently links to Assessments and Actions. With L3 Controls, evidence should also link to Controls — proving the control operated at a specific time.

### Evidence-by-design gap

The L4 spec calls for "evidence-by-design" — controls that automatically generate evidence (sensor logs, system audit trails, training completion records). This requires integration with operational systems beyond Baserow's scope. For the PoC, evidence is manually uploaded/referenced.

---

## L5 — Assurance

**Status: Template ready, not applied**

Two templates available:
- **Audit Management** — internal/external audit scheduling, findings, reports
- **Training Tracker** — competency requirements, completion tracking, certificate expiry

### Gap: Control-linked assurance

Currently Audits link to Assessments. With L3 Controls, the assurance chain becomes:
```
Audit → verifies → Control → implements → Obligation
```

This enables: "this audit tested 12 controls covering 45 obligations across 8 laws" — real assurance coverage metrics.

---

## L6 — Events & Change Intelligence

**Status: Partial — internal change detection built, external intelligence missing**

### What we have

| Component | Implementation | Status |
|-----------|---------------|--------|
| Law change detection | ChangeDetector — monitors for new/amended/revoked laws | Built |
| Change notifications | ChangeNotifier — Zenoh pub/sub to fractalaw | Built |
| Incident Register | Template ready | Not applied |
| Webhooks | Template webhook specs for Assessments, Actions | Built |
| ComplianceMetrics | ETS-backed dashboard metrics from webhook events | Built |

### What's missing

| Component | Description |
|-----------|-------------|
| Enforcement feed | HSE prosecution data, enforcement notices, improvement notices |
| Regulatory horizon | Upcoming legislation, consultations, regulatory intent |
| Event → obligation mapping | "This enforcement action relates to these obligations in your register" |
| Impact assessment | "This law change affects these controls and these assessments" |

### For the PoC

The Incident Register template is the internal event capture mechanism. Applying it gives customers a way to record non-conformances and link them back to Assessments and Actions. The external intelligence feeds are a product roadmap item.

---

## L7 — Decisions & Governance

**Status: Not built**

### What's needed

| Component | Description |
|-----------|-------------|
| Decision record | Formal record of compliance decisions with rationale |
| Approval workflow | Sign-off chain for compliance status changes |
| Risk acceptance | Explicit acceptance of residual risk with conditions |
| Escalation | Rules for when decisions must be escalated (e.g., non-compliance with HIGH significance) |
| Board reporting | Aggregated compliance posture for governance bodies |

### Why this is last

L7 depends on all other layers being operational. You can't make governance decisions without:
- Knowing your obligations (L1)
- Understanding the risk (L2)
- Having controls in place (L3)
- Evidence that controls work (L4)
- Independent assurance (L5)
- Awareness of changes and events (L6)

### Baserow capability

Baserow's audit trail (row history) captures who changed what and when. This provides basic decision traceability. For formal approval workflows, Baserow's current capabilities are limited — no native approval chains or conditional logic. This may require the sertantai-legal UI (Phase 3, #113) rather than pure Baserow.

---

## PoC Priority Path

```
L1 ✓ Obligations (built)
 ↓
L2 ~ Risk & Prioritisation (significance built, Assessment template applied)
 ↓
L3 ✗ Controls (GAP — next to build)
 ↓
L4 ~ Evidence (template ready — apply after Controls)
 ↓
L5 ~ Assurance (templates ready — apply after Evidence)
 ↓
L6 ~ Events (partial — apply Incident Register)
 ↓
L7 ✗ Decisions (future — needs all layers operational)
```

### Immediate next steps

1. **Design Controls template** — the L3 gap is the most critical for a credible compliance solution
2. **Apply Evidence Vault** — link evidence to Assessments (and later Controls)
3. **Apply Incident Register** — internal event capture
4. **Apply Audit Management + Training Tracker** — assurance chain

### Row budget impact

| Layer | Template | Estimated Rows | Cumulative |
|-------|----------|---------------|------------|
| L1 | Legal Register + Duties + Actors | ~3,160 | 3,160 |
| L2 | Assessments + Actions + Personnel | ~300 + growing | ~3,500 |
| L3 | Controls | ~200-500 | ~4,000 |
| L4 | Evidence | growing | ~4,500 |
| L5 | Audits + Training | ~100 each | ~4,700 |
| L6 | Incidents | growing | ~5,000 |

Comfortably within 50K Baserow limit.

---

## Related Docs

- [`COMPLIANCE-7-LAYERS.md`](COMPLIANCE-7-LAYERS.md) — the architecture definition
- [`BASEROW-TEMPLATES.md`](BASEROW-TEMPLATES.md) — all 12 templates with dependency graph
- [`SIGNIFICANCE-SCOPING-GUIDE.md`](SIGNIFICANCE-SCOPING-GUIDE.md) — L2 significance data usage
- [`BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md`](BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md) — L2 assessment options
- [`BASEROW-ACTION-TRACKER-PATTERNS.md`](BASEROW-ACTION-TRACKER-PATTERNS.md) — L2 remediation tracking
- [`BASEROW-PERSONNEL-PATTERNS.md`](BASEROW-PERSONNEL-PATTERNS.md) — people patterns across all layers
- [`EVIDENCE-SCHEMA.md`](EVIDENCE-SCHEMA.md) — L4 canonical schema (Evidence, Calibrations, Gaps)
- [`EVIDENCE-VAULT-PATTERNS.md`](EVIDENCE-VAULT-PATTERNS.md) — L4 evidence design patterns
- [`BASEROW-CONTROLS-DESIGN.md`](BASEROW-CONTROLS-DESIGN.md) — L3 Controls ontology
