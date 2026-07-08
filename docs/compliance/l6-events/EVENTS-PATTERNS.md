# L6 Events & Change Intelligence — Patterns

How the compliance framework receives, triages, and responds to events that affect compliance status. L6 is an **interface** for event signals — not the event generator.

---

## The seam, not the scanner

L6 follows the same architectural pattern as L5 Assurance: the compliance framework provides a **seam** where external and internal event signals land, are triaged, and cascade into the compliance response. The framework does not generate signals — that's the job of:

- **fractalaw** (legislative change detection — already built)
- **Regulatory intelligence providers** (Enhesa, CUBE, Nimonik — for non-UK or enforcement intelligence)
- **Regulator publications** (HSE enforcement register, EA compliance assessments, FCA data portal)
- **Internal operational systems** (audit management, control monitoring, organisational change management)
- **Media / reputational monitoring** (sector incidents, NGO campaigns, peer enforcement)

L6 receives their output, classifies it, maps it to affected obligations and controls, and tracks the compliance response.

---

## The critical boundary: compliance events vs safety events

Compliance events and safety events are different things that serve different purposes.

| | Compliance event | Safety event |
|---|---|---|
| **What it is** | A trigger that affects the compliance register — the set of obligations, their risk profiles, or the adequacy of controls | An unplanned occurrence with actual or potential for harm — accident, dangerous occurrence, near miss |
| **What it serves** | The compliance framework (L1–L7) | ALARP assessments and hazard logs in safety cases |
| **Examples** | New legislation enacted, HSE prosecutes a peer company, EA enforcement notice served, permit conditions changed | Worker injured, gas release, near miss, plant trip |
| **Response** | Update obligations, reassess risk, review controls, collect new evidence | Investigate, update hazard log, reassess ALARP, implement safety recommendations |
| **Owner** | Compliance / EHS governance function | Safety / operations function |

**Where they overlap**: an incident investigation (safety) may reveal a compliance gap — e.g., a workplace accident investigation discovers that a statutory inspection regime was not being followed. The accident is a safety event. The discovery that inspection obligations were unmet is a compliance event. Both enter their respective systems. They are linked (the compliance event references the safety investigation) but they are not the same record.

**The Incident Register** already in the system is primarily a safety domain entity (non-conformances, near misses). L6 compliance events need their own model — "Regulatory Event" or "Compliance Event," not "Incident."

---

## Event classification

### By source

| Source | Examples | Signal generator |
|--------|---------|-----------------|
| **External regulatory** | New/amended/repealed legislation, new guidance, regulator consultation | fractalaw, legislation.gov.uk feeds, regulator websites |
| **External enforcement** | Prosecution, enforcement notice, improvement notice, fine — against self or peer | HSE/EA registers, FCA data portal, media |
| **External reputational** | Media coverage of regulatory failure, sector incident, NGO campaign, political statement | Media monitoring, industry bodies |
| **Internal operational** | Control failure discovered through L4/L5, audit finding that triggers reassessment | L4 Judgements, L5 Assurance findings |
| **Internal organisational** | New site, new process, M&A, restructure, personnel change | HR, operations, corporate development |

### By predictability

| Type | Description | Examples |
|------|------------|---------|
| **Planned** | Known in advance from published schedules | Legislative calendar, scheduled consultations, announced inspection campaigns |
| **Foreseeable** | Signalled but not confirmed | Sector trends, political statements, regulatory strategy documents, regulator budget increases |
| **Unplanned** | No advance warning | Enforcement action served, whistleblowing disclosure, media exposure, surprise inspection |

### By urgency

| Urgency | Description | Response time |
|---------|------------|--------------|
| **Immediate** | Enforcement notice served, prohibition notice — respond now | Days |
| **Scheduled** | New law commences on a future date — prepare by commencement | Weeks to months |
| **Monitoring** | Consultation open, Bill progressing — watch and potentially influence | Months to years |
| **Background** | Sector trend, political signal — note and factor into planning | Ongoing |

### By compliance register effect

| Effect | What changes | Layers affected |
|--------|-------------|----------------|
| **Creates new obligation** | New law, new requirement, new permit condition | L1 → L2 → L3 → L4 |
| **Modifies existing obligation** | Law amended, guidance updated, interpretation changed | L1 → L2 → L3 → L4 |
| **Removes obligation** | Law repealed, permit condition removed, activity ceased | L1 → L2 → L3 |
| **Changes risk profile** | Enforcement action against peer, regulator announces focus area | L2 (risk score adjustment) |
| **Triggers reassessment** | Audit finding, control failure, organisational change | L2 → L3 → L4 |
| **Reveals framework gap** | Audit finding about the compliance system itself | Cross-cutting |

---

## The event lifecycle

```
Detect → Triage → Impact Assessment → Response → Close-out → Learn
```

### 1. Detect

A signal arrives from any source. At this stage it is unfiltered — a raw signal with metadata about source, type, and date. The compliance framework logs it without yet deciding what to do.

**What we already have**: fractalaw's ChangeDetector monitors legislation.gov.uk for new, amended, and repealed laws. ChangeNotifier publishes signals via Zenoh. This is detection for one source (UK primary and secondary legislation). Other sources need equivalent feeds.

### 2. Triage

The event is assessed for applicability and materiality:

- **Does this affect us?** Is the law/enforcement/event relevant to this organisation's activities, locations, and obligations?
- **How material is it?** Does it create new obligations, modify existing ones, change risk profiles, or is it noise?

Triage produces a classification:
- **Material** — triggers downstream work (impact assessment, obligation update, control review)
- **Monitor** — logged, tracked, but no immediate action
- **Not applicable** — dismissed with rationale recorded

### 3. Impact assessment

For material events: which parts of the compliance register are affected?

This is **event-to-obligation mapping** — tracing from the event through to specific duties, controls, assessments, and evidence. The fractalaw pipeline already handles this for legislative change: an amended law triggers re-parsing of provisions → updated duties (L1) → cascades to control mappings (L3) → triggers reassessment (L2).

For enforcement and reputational events, the mapping is different: an HSE prosecution of a peer company for a specific offence maps to the obligations and controls that address that offence in *this* organisation's register.

### 4. Response

The compliance framework updates:

| Layer | What's updated |
|-------|---------------|
| **L1** | Obligations added, modified, or removed in the Legal Register / Duties |
| **L2** | Risk scores adjusted (enforcement activity increases likelihood), assessments triggered |
| **L3** | Controls reviewed for adequacy against changed obligations |
| **L4** | New artefacts collected, judgements triggered for affected controls |
| **L5** | Assurance function notified — may re-scope audit programme |

### 5. Close-out

The event response is verified as complete:
- All affected obligations updated
- All affected controls reviewed
- New assessments completed
- Evidence collected
- The event record is closed with a summary of what changed

### 6. Learn

Patterns across events feed strategic planning:
- Which obligation families generate the most events?
- Which regulatory sources produce the most material changes?
- How long does it take to implement a regulatory change?
- Are we detecting events early enough (leading) or only after enforcement (lagging)?

---

## Leading vs lagging intelligence

| | Leading | Lagging |
|---|---|---|
| **What** | Signals of future regulatory change or enforcement focus | Records of completed regulatory actions |
| **Examples** | Consultation published, Bill introduced, regulator strategy update, enforcement budget increase, inspection campaign announced | Prosecution completed, fine imposed, enforcement notice served, improvement notice issued |
| **Value** | Prepare before it bites — update controls, collect evidence, adjust risk scores | Learn from what happened — prioritise obligations that regulators are actively enforcing |
| **Source** | Parliament, regulator publications, political statements, OECD regulatory outlook | HSE/EA/FCA enforcement registers, court records, media |

Mature compliance functions use both: **leading intelligence drives preparation**, **lagging intelligence drives prioritisation**. An organisation that only monitors lagging indicators is always reacting after the fact.

---

## UK regulatory publication landscape

| Regulator | What they publish | Format | Machine-readable? |
|-----------|------------------|--------|-------------------|
| **legislation.gov.uk** | Statute book, amendment feeds, Statutory Instruments | XML (CLML), Atom feeds, REST API | Yes — the most machine-readable UK source |
| **UK Parliament** | Bills, laid SIs, proceedings | REST API (developer.parliament.uk) | Yes |
| **HSE** | Enforcement notices (5yr), convictions (10yr for orgs), annual statistics | Web database, PDF reports | Partially — searchable but requires scraping |
| **EA** | Enforcement actions, compliance assessment reports, enforcement undertakings | data.gov.uk datasets, web registers | Partially — structured datasets, some API |
| **FCA** | Regulated firms, enforcement outcomes, regulatory data | data.fca.org.uk portal, DRR/MRR initiative | Improving — DRR aims for machine-executable regulation |
| **ONR** | Regulatory guidance, operational instructions | PDFs on website | No |
| **ORR** | Rail regulation data, network statements | Documents and datasets | Partially |

---

## The interface pattern

L6 follows the L5 pattern: the compliance framework provides a seam, not a system.

### What flows in

Event signals from any source, with a common schema:

| Field | Purpose |
|-------|---------|
| **Event type** | Regulatory change / Enforcement action / Reputational / Internal operational / Internal organisational |
| **Source** | Where the signal came from (fractalaw, HSE register, media, internal audit, etc.) |
| **Source reference** | External ID or URL for traceability |
| **Date detected** | When the signal was received |
| **Date effective** | When the event takes effect (commencement date for legislation, notice date for enforcement) |
| **Summary** | Human-readable description of the event |
| **Triage status** | Material / Monitor / Not Applicable |
| **Urgency** | Immediate / Scheduled / Monitoring / Background |
| **Affected obligations** | Links to L1 laws/duties (populated during impact assessment) |
| **Affected controls** | Links to L3 controls (populated during impact assessment) |

### What flows out

Events, once triaged and assessed, produce downstream work in other layers. The event record is the **provenance** — "why did this obligation change?" is answered by the L6 event that triggered it.

### Traceability

Every change to the compliance register should be traceable to the event that triggered it:

```
Event (detected, triaged, assessed)
    |
    |--> Updated Obligation (L1) — "this duty changed because of Event X"
    |--> Revised Risk Score (L2) — "risk increased because of enforcement event Y"
    |--> Control Review (L3) — "control reviewed because obligation changed"
    |--> New Judgement (L4) — "control reassessed because of Event X"
    |--> Assurance Re-scoping (L5) — "audit programme updated because of new obligations"
```

---

## What L6 is NOT

- **Not a horizon scanning service.** Detection is the signal generator's job (fractalaw, Enhesa, CUBE). L6 receives and triages.
- **Not an enforcement database.** That's HSE/EA/FCA's responsibility. L6 receives enforcement signals.
- **Not a media monitoring service.** That's a separate capability. L6 receives reputational signals.
- **Not a safety incident register.** Safety events (accidents, near misses) serve ALARP and hazard logs. L6 handles compliance events — regulatory, enforcement, reputational, and internal triggers that affect the compliance register.
- **Not a regulatory intelligence platform.** That's CUBE, Ascent, fractalaw. L6 is the receiver, not the generator.

---

## References

- OECD Regulatory Policy Outlook 2025 — anticipatory governance, horizon scanning
- Grant Thornton — Better Regulatory Change Management Framework
- MetricStream — Regulatory Change Management lifecycle
- Riskonnect — triage gates in regulatory change management
- ISO 31000 — risk identification, event sources
- ISO 27001 — event vs incident vs non-compliance hierarchy
- COSO ERM — event identification as a component
- HSE — Enforcement Management Model, public registers of notices and convictions
- EA — Register of Enforcement Actions, Enforcement and Sanctions Policy
- FCA — Digital Regulatory Reporting, data portal
- legislation.gov.uk — CLML API, Atom feeds for change detection
- UK Parliament — Developer Hub (Bills, Statutory Instruments)
- FinregE, CUBE, Ascent — regulatory rule mapping, automated classification
- Enhesa, Nimonik, Wolters Kluwer — regulatory intelligence services
- `ASSURANCE-INTERFACE.md` — L5 seam pattern (L6 follows the same architecture)
- `EVIDENCE-SCHEMA.md` — Artefacts entity (events may produce artefacts)
- `COMPLIANCE-7-LAYERS.md` — L6 definition
