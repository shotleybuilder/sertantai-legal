# L5 Assurance Interface

How the compliance framework serves — and is served by — an organisation's assurance programme. L5 is not an audit management system. It is the **seam** where assurance and compliance meet: data flows out to inform assurance planning, and findings flow back in as signals that drive the compliance response.

---

## The seam, not the system

An organisation's assurance programme is larger than its compliance framework. It assures safety cases, quality systems, financial controls, information security, operational processes — and compliance is one subject among many. The compliance framework does not own the audit programme. It provides:

- **Inputs** that the assurance function needs to plan, prioritise, and scope their work
- **Access** to compliance data when auditors are undertaking their assessments
- **A receiver** for findings that flow back as new signals into the compliance framework
- **Traceability** so that an assurance finding can be tracked through the compliance response to resolution

This is a **seam** — a well-defined boundary where two systems meet and exchange value. Not a docking point (too mechanical), not an API (too technical), not an integration (too vague). A seam: each side does its own work, and the seam is where the work connects.

---

## What flows out: inputs to assurance planning

The assurance function needs compliance data to plan, prioritise, and schedule their work. Without it, they plan from habit, institutional memory, or convenience — and effort clusters on the legible, low-risk subjects while high-risk areas go unexamined.

### Data the compliance framework provides

| What | Where it lives | How assurance uses it |
|------|---------------|----------------------|
| **Legal Register** (L1) | Laws, duties, actor tuples | Scope: which obligations apply. Significance ratings drive audit priority. |
| **Compliance Assessments** (L2) | Status, risk scores, review dates | Priority: Non-Compliant and Partially Compliant obligations need assurance attention. High risk scores signal where to look. |
| **Controls** (L3) | Control register with ontology properties | Coverage: which controls exist, who owns them, how they map to obligations. Properties (Blast_Radius, Info_Distance, staleness) drive assurance allocation — the same VoI logic that drives L4. |
| **Control Mappings** (L3) | Wiring between obligations and controls | Gap detection: obligations with no mapped controls, controls with no obligations. |
| **Artefacts** (L4) | Evidence register with Type-A/B classification | Evidence quality: controls with only Type-A artefacts (activity evidence) need deeper assurance than those with Type-B (outcome evidence). |
| **Judgements** (L4) | First-line findings, basis, verified meaning | Judgement quality: which controls have recent judgements? By whom (calibrator quality)? What did they find? Are findings consistent over time? |
| **Gaps** (L4) | Reconciliation decisions, three exits | Open gaps, patterns of drift, controls that repeatedly produce Drifted findings. |
| **Coverage Status** (L3, computed) | fractalaw-computed per control | Quick triage: No Artefact, Artefact Only, Judgement Current, Judgement Stale, Unknown. |
| **Incidents** (L6) | Non-conformances, near misses, linked to controls and judgements | Incident patterns signal where assurance should investigate. Incidents that contradicted prior judgements are high-priority. |

### Standard queries for assurance planning

These are the questions assurance asks of the compliance framework:

| Query | What it answers | Source |
|-------|----------------|--------|
| "Which controls have the highest expected loss and lowest assurance coverage?" | Where to focus next | Controls (Blast_Radius x Info_Distance x staleness) cross-referenced with assurance finding dates |
| "Which obligations have no Primary control mapping?" | Coverage gaps in L3 | Control Mappings where no row has Strength = Primary for a given obligation |
| "Which controls have only Type-A artefacts?" | Where evidence is legible but not discriminating | Artefacts grouped by Control, filtered for Class = Activity only |
| "Which judgements were made by people with low calibration scores?" | Where first-line assessment quality is weakest | Judgements joined to Personnel.Calibration_Score |
| "Which controls repeatedly produce Drifted findings?" | Systemic problems, not one-off issues | Judgements grouped by Control, filtered for Finding = Drifted, counted |
| "Which incidents contradicted prior judgements?" | Where the first line got it wrong | Incidents where Vindication_Status = Contradicted |
| "What has changed since the last audit?" | Scope for follow-up | Changes to Controls, new Judgements, new Gaps, since a given date |

These queries are **reports**, not entities. They don't need new tables — they need well-defined views or query interfaces against existing L1–L4 data.

---

## What flows in: access during audit

When auditors are undertaking an assessment of a compliance subject, they need access to the compliance data at the right level of the DIKW hierarchy:

| Level | What the auditor needs | Where it is |
|-------|----------------------|-------------|
| **Data** | Raw records: artefact files, sensor readings, training records, inspection logs | Artefacts table + linked operational systems (DMS, monitoring systems) |
| **Information** | Structured context: which control, which obligation, who owns it, what's the risk score, when was it last judged | Controls + Assessments + Judgements + Personnel |
| **Knowledge** | Patterns over time: is this control drifting? Is the judge reliable? Are incidents clustering here? | Judgement history per control, Calibration_Score trajectory, Incident patterns |
| **Wisdom** | The "so what": is the compliance framework working for this obligation? Is the organisation's approach proportionate? | The auditor brings this — the framework provides the inputs |

**The compliance framework provides D, I, and K. The auditor provides W.** The framework should make D-I-K easily accessible, linked, and navigable — not require the auditor to assemble it from disconnected sources.

### What this means for the schema

No new entities needed for audit access. But the schema needs:

- **Views / reports** that present the Control → Artefacts → Judgements → Gaps chain for a given subject
- **Temporal queries**: "show me everything for this control since date X" — the audit period
- **Linked navigation**: from a Control, reach its obligations (via Control Mappings), its artefacts, its judgement history, its gaps, its incidents
- **Export capability**: the auditor may work in their own tools. The compliance framework should export the relevant slice.

---

## What flows back: findings as signals

When assurance produces a finding about a compliance subject, that finding enters the compliance framework as a **new signal**. It is not fundamentally different from any other signal — it is information that changes what a rational person should believe about whether an obligation is met.

### How assurance findings enter

| Finding type | What happens in the compliance framework |
|-------------|----------------------------------------|
| **Confirms an L4 Judgement** | The judgement's reliability is reinforced. The calibrator's track record gets a data point (Vindication_Status = Supported). |
| **Challenges an L4 Judgement** | A new L4 Judgement may be warranted. If the assurance finding shows drift that the first line missed, a Gap is created with three exits. Vindication_Status = Contradicted on the original judgement. |
| **Discovers something new** | The first line didn't look at this at all. A new Judgement record is created (by the auditor or triggered for the control owner). If finding is negative, a Gap follows. |
| **Finds a systemic issue** | Not about one control but about a pattern — e.g. "judgements across the EHS domain are consistently over-optimistic." This is a finding about the L4 *process*, not about a single control. |
| **Assesses the framework itself** | "The compliance framework has coverage gaps in environmental obligations." This is a finding about L1-L3 architecture, not about a control. Creates work items at the appropriate layer. |

### The finding as an Artefact

An assurance finding — the audit report, the inspection record, the review output — is itself an **Artefact** in L4. It is a thing that exists and carries information. Type-B (outcome): it discriminates, because it reflects what the auditor found when they independently tested.

The finding enters the Artefacts register with:
- `artefact_type`: Inspection Report (or Audit Report, Review Report — extend the enum)
- `artefact_class`: Outcome (Type-B — the audit found something)
- `source`: External (if external audit) or the assurance function
- Control link: the control that was assessed (or multiple)

If the finding triggers a new L4 Judgement or Gap, those are created through the normal L4 process — the Artefact (audit report) is the basis.

### Extending the schema for assurance signal provenance

To trace an assurance finding through the compliance response, the existing schema needs minimal extension:

| Extension | Where | Purpose |
|-----------|-------|---------|
| `assurance_ref` (text) | On Artefacts | External reference to the audit/inspection that produced this artefact (audit number, inspection ID) |
| `assurance_line` (enum) | On Artefacts | 1st / 2nd / 3rd / External — which line produced this artefact |
| `assurance_rating` (enum) | On Artefacts | Full / Substantial / Limited / No Assurance — the opinion associated with this finding |
| `source_activity_type` (enum) | On Artefacts | Inspection / Review / Audit / External Audit / Regulatory Inspection — what kind of assurance activity |

These are fields on the **existing Artefacts entity**, not a new table. An artefact that comes from an assurance activity carries these fields; an artefact that comes from normal operations doesn't (they're nullable).

This means:
- Assurance findings are artefacts with assurance metadata
- They feed L4 Judgements and Gaps through the normal flow
- Traceability is built in: Artefact (with assurance_ref) → Judgement → Gap → Action
- The assurance function can query "show me all compliance actions that resulted from our audit findings" by filtering Artefacts on assurance_ref

---

## Traceability: the assurance thread

An assurance finding needs to be traceable through the compliance response. The thread:

```
Assurance Activity (external)
    |
    |--> Artefact (audit report, with assurance_ref + rating)
              |
              |--> Judgement (triggered by the finding)
                        |
                        |--> Gap (if Finding = Drifted)
                                  |
                                  |--> Action (if Exit = Correct Work)
                                            |
                                            |--> Close-out Artefact (evidence that action was completed)
                                                      |
                                                      |--> Follow-up Judgement (was the fix effective?)
```

The entire thread is navigable through existing link_row relationships. The `assurance_ref` field on the originating Artefact is the anchor — it ties the compliance-side work back to the assurance-side activity.

### What the assurance function can query

| Question | How to answer it |
|----------|-----------------|
| "What happened as a result of our audit?" | Filter Artefacts by assurance_ref → follow links to Judgements → Gaps → Actions |
| "Are our audit recommendations closed?" | Follow the thread to Actions → check Status (Completed?) |
| "Were our recommendations effective?" | Follow to the close-out Artefact → the follow-up Judgement → was the control Still True? |
| "Which of our findings led to Protect Adaptation (not remediation)?" | Filter Gaps linked to Artefacts with this assurance_ref → Exit_Decision = Protect Adaptation |
| "Which compliance subjects have we never audited?" | Controls / Assessments / Laws with no linked Artefacts where assurance_line is populated |

---

## What L5 is NOT in this framework

- **Not an audit management system.** It doesn't schedule audits, manage auditor workload, or run the QAIP. Those are the assurance function's responsibility.
- **Not a duplicate of L4.** L4 Judgement is first-line self-assessment. Assurance findings that enter L5 come from independent sources and flow through L4 as new signals.
- **Not a separate data store.** Assurance findings land in the existing Artefacts entity with additional metadata. No parallel evidence repository.
- **Not prescriptive about methodology.** ISO 19011, IIA standards, sector-specific approaches — the compliance framework is agnostic. It receives findings regardless of how the assurance function produced them.

---

## Summary: the seam in three flows

| Flow | Direction | What moves |
|------|-----------|-----------|
| **Out** | Compliance → Assurance | Data for planning: controls, obligations, risk scores, coverage status, judgement quality, incident patterns. Standard queries and reports. |
| **Access** | Assurance ↔ Compliance | During audit: D-I-K from the compliance framework. Controls, artefacts, judgement history, gaps, linked navigation, temporal queries. |
| **Back** | Assurance → Compliance | Findings as artefacts with assurance metadata. Feed L4 Judgements and Gaps. Traceable through the compliance response via assurance_ref. |

The compliance framework does its job (L1–L4, L6–L7). The assurance function does its job (planning, scoping, auditing, reporting). The seam is where they exchange value — data flows out, findings flow back, and traceability connects the two.

---

## References

- `ASSURANCE-PATTERNS.md` — Three Lines Model, independence, assurance scope, combined assurance
- `EVIDENCE-SCHEMA.md` — L4 canonical schema (Artefacts, Judgements, Gaps)
- `EVIDENCE-CALIBRATION.md` — Judgement vs calibration terminology
- `VALUE-OF-INFORMATION.md` — VoI as the basis for assurance prioritisation
- `DEFINITION-OF-EVIDENCE.md` — evidence as information that changes rational credence
- `EVIDENCE-SAFETY-ARGUMENT.md` — horizontal evidence for safety argument (compliance, ALARP, hazard log)
- IIA Three Lines Model (2020)
- ISO 19011:2018 — audit principles and programme management
- JSP 815 Element 12 (2024) — MOD assurance framework
