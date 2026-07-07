# L5 Assurance Patterns

How assurance works within a compliance framework — the patterns, models, and principles that inform the L5 canonical schema. Assurance is independent verification that **any part of the compliance framework** is working as intended — not just controls (L3), but obligations (L1), risk scoring (L2), evidence and judgement processes (L4), the assurance programme itself (L5), event response (L6), governance (L7), and the compliance framework as a whole.

---

## The critical boundary: L4 Judgement vs L5 Assurance

L4 and L5 both assess controls. They are NOT the same thing.

| | L4 Judgement | L5 Assurance |
|---|---|---|
| **Who** | A named person close to the control (control owner, calibrated assessor) | Someone structurally independent of the control |
| **What** | Assesses whether the control works and the obligation is met | Verifies that the L4 judgement process itself is working — and tests controls independently |
| **Independence** | First-line: knows the control, examines evidence, records finding | Second or third-line: independent of the thing being assessed |
| **Question** | "Is this control still true?" | "Can we trust that the first-line assessment is reliable?" AND "does this control actually work when we test it independently?" |
| **Output** | Finding (Still True / Drifted / Retired) | Assurance opinion (Full / Substantial / Limited / No Assurance) + findings + recommendations |
| **Line** | 1LOD (management self-assurance) | 2LOD (oversight) or 3LOD (independent audit) |

L5 examines the same artefacts as L4 but also examines **the L4 judgements themselves** — was the judge calibrated? Was the method appropriate? Did the finding match the evidence? L5 can confirm an L4 Judgement, challenge it, or discover something the first line missed entirely.

---

## The Three Lines Model (IIA 2020)

The IIA's Three Lines Model (updated from "Three Lines of Defence" in 2020) structures assurance into three functionally distinct roles:

### First line: management controls

Operational managers own and manage risk. They design, implement, and operate controls. They perform self-assessment.

**In our model**: L4 Judgement. The control owner or a calibrated person assessing whether the control still works. This is self-assurance — valuable but not independent.

### Second line: oversight and challenge

Risk management, compliance, and quality functions provide frameworks, set policies, monitor first-line performance, and challenge management. They do NOT own the controls but provide oversight assurance.

Critically: second-line functions **report to management** and are part of the management structure. They are independent of the control but not independent of management.

**Examples**: A compliance function reviewing whether control designs match regulatory requirements. A quality team reviewing whether documented procedures match actual practice. An EHS function conducting thematic reviews across sites.

### Third line: independent assurance

Internal audit provides assurance to the governing body. The defining characteristic is **structural independence**: the third line reports functionally to the board or audit committee, not to management.

**In our model**: L5 at its strongest. The auditor verifies that both first-line and second-line activities are effective. They test controls independently, examine judgement quality, and report to governance without management filtering.

### Beyond the three lines

External assurance providers sit outside the model:

| Provider | Independence | What they do |
|----------|-------------|-------------|
| **External auditors** | Full (different organisation) | Certify compliance with standards (ISO 45001, 14001) |
| **Regulators** (HSE, EA, FCA, ONR, ORR) | Full + statutory authority | Inspect, enforce, prosecute |
| **Independent Safety Auditor** (Def Stan 00-56) | Full (structurally independent of project) | Verify Safety Case |
| **Independent Competent Person** (ORR) | Full (external to project) | Verify safety verification scheme |

The regulator does not replace the duty holder's own assurance. The regulator assures that the duty holder's assurance *arrangements* are adequate. Each layer asks "does the layer below actually work?" — not "let me redo what they did."

---

## Assurance scopes on the whole framework, not just controls

Assurance is not confined to testing L3 controls. Any part of the compliance framework — and the framework itself — is a legitimate assurance subject.

| Assurance subject | Layer | Example question |
|-------------------|-------|-----------------|
| **Legal Register completeness** | L1 | Have we identified all applicable legislation? Are repealed laws still in the register? |
| **Risk scoring proportionality** | L2 | Does our risk assessment methodology produce proportionate results? Are high-significance obligations rated appropriately? |
| **Control coverage** | L3 | Are there obligations with no mapped controls? Are control designs adequate for the risks? |
| **Control effectiveness** | L3 | Do the controls actually work when tested? (Operating effectiveness, not just design) |
| **Evidence quality** | L4 | Are artefacts discriminating (Type-B) or just activity records (Type-A)? Is the artefact register current? |
| **Judgement process** | L4 | Are judgements being performed by calibrated people? Are findings supported by the basis? Is measurement drift being detected? |
| **Assurance programme** | L5 | Does the assurance programme have coverage gaps? Are high-risk areas under-assured? (QAIP / meta-assurance) |
| **Event response** | L6 | Is the incident reporting system working? Are change notifications being acted on? |
| **Governance decisions** | L7 | Do decisions have rationale? Are risk acceptances documented and reviewed? |
| **The compliance framework itself** | All | Is the management system adequate and proportionate? Does it achieve its intended outcomes? Are the layers coherent and connected? |

The last row is critical. The compliance framework as a whole is a legitimate — and arguably the most important — assurance topic. An auditor can ask: "Does this organisation's compliance system actually work?" That question spans all seven layers. It is the question regulators ask during inspection, and the question a safety case assessor asks when reviewing the management system leg of a safety argument.

**Implication for the schema**: the Assurance Activity entity must be able to scope on *any* entity in the system — a control, an assessment, a judgement, a gap, a law, a process, or the system as a whole. The `subject` field is not limited to controls. It can reference any layer.

---

## Assurance activities: a spectrum

| Activity | What it does | Independence | Typical line | Depth |
|----------|-------------|-------------|-------------|-------|
| **Self-assessment** | Control owner evaluates own work | None | 1LOD (L4 Judgement) | Shallow-medium |
| **Management review** | Manager evaluates subordinate's controls | Limited (line management) | 1LOD/2LOD boundary | Medium |
| **Inspection** | Compliance/quality function checks specific requirements against criteria | Moderate | 2LOD | Narrow and deep |
| **Thematic review** | Cross-cutting review of a topic across multiple controls/sites | Moderate-high | 2LOD | Broad and medium |
| **Audit** | Systematic, independent, documented evaluation against criteria | High | 3LOD | Broad and deep |
| **External audit** | Independent organisation evaluates against a standard | Full | External | Broad and deep |

L4 Judgement covers self-assessment (and possibly management review). L5 Assurance covers inspection through external audit — everything that has **independence from the control being assessed**.

---

## Design effectiveness vs Operating effectiveness

From SOX/PCAOB and SOC frameworks — two distinct things that assurance tests:

### Design effectiveness

Does the control, *as designed*, adequately address the risk? Evaluated at a point in time.

> "If this control operates as intended, would it prevent or detect the risk?"

Tested by: walkthrough, design review, comparison against requirements.

### Operating effectiveness

Does the control actually operate as designed, consistently, over a period of time?

> "Did this control actually work when it was needed?"

Tested by: sample-based testing, observation, reperformance, inspection of evidence across the assessment period.

**SOC Type 1 vs Type 2**: Type 1 evaluates design effectiveness at a point in time. Type 2 evaluates both design AND operating effectiveness over a period (typically 6-12 months). L5 should support both — but operating effectiveness is the more valuable and harder assessment.

**Connection to Type-A/B evidence**: Type-A artefacts (activity evidence) support design effectiveness claims — the control exists and was executed. Type-B artefacts (outcome evidence) support operating effectiveness claims — the control achieved its purpose when tested. L5 should prefer Type-B evidence and flag when only Type-A exists.

---

## Assurance opinions and ratings

Assurance activities produce opinions with ratings. From JSP 815, ISO 19011, and common practice:

| Rating | Meaning | Implication |
|--------|---------|-------------|
| **Full assurance** | Controls well designed and operating effectively | No significant action needed |
| **Substantial assurance** | Controls largely effective, minor improvements identified | Actions recommended but not urgent |
| **Limited assurance** | Significant weaknesses identified; controls partially effective | Mandatory escalation; actions required |
| **No assurance** | Controls inadequate or absent | Immediate escalation to governance (L7); emergency actions |

**Escalation rule**: Limited or No Assurance triggers mandatory escalation. This is where L5 connects to L7 Decisions & Governance.

---

## Combined assurance and assurance mapping

### The problem

Without coordination, assurance activities cluster on easy-to-audit, visible controls (the legible quadrant) and leave hard-to-audit, high-risk controls uncovered (the load-bearing quadrant). This is the Measurement Inversion applied to assurance — the same pattern as L4.

### The assurance map

A matrix listing controls/risks on one axis and assurance providers on the other. Each cell records:
- What assurance activity covers this control
- By which line (1st / 2nd / 3rd / external)
- At what frequency
- Most recent outcome

The map reveals:

| Finding | What it means | Action |
|---------|-------------|--------|
| **Over-assured** | Multiple providers duplicating effort on the same low-risk control | Reduce — redirect effort to under-assured areas |
| **Under-assured** | High-risk controls with no second or third-line coverage | Add assurance — this is the real exposure |
| **Gaps** | Controls with no assurance coverage at all | Investigate — why is nobody looking at this? |

### VoI connection

The assurance map is the VoI 2x2 applied to assurance effort. Expected Loss (uncertainty x consequence from control properties) should drive assurance allocation — not convenience, habit, or auditor preference. High blast radius + remote + stale controls need more assurance, not less.

---

## The assurance lifecycle

```
Plan → Perform → Report → Act → Close → Learn
```

1. **Plan**: scope the assurance activity (which controls, which criteria, what method, who)
2. **Perform**: execute the assessment (gather evidence, test controls, interview, observe)
3. **Report**: document findings, assign ratings, make recommendations
4. **Act**: management responds (accept, remediate, dispute). Creates actions with owners and deadlines.
5. **Close**: verify that actions have been implemented AND are effective (not just done — working)
6. **Learn**: feed findings back into the assurance programme. Update the assurance map. Adjust priorities.

### Connection to L4 Gaps

An L5 finding may:
- **Confirm** an existing L4 Judgement ("the first-line assessment was correct")
- **Challenge** an L4 Judgement ("the first-line said Still True but we found Drifted")
- **Create** a new L4 Gap ("we discovered something the first line missed entirely")

When L5 creates a Gap, the same three exits apply: Correct Work, Amend Constraint, Protect Adaptation. The assurance finding provides the basis; the Gap entity records the decision.

---

## Competence and training as an assurance subject

Training and competence sit at the boundary of multiple layers:

| Layer | What it does with training |
|-------|--------------------------|
| **L3 Controls** | "Maintain a training programme" is a control. The programme is an operational mechanism. |
| **L4 Evidence** | Training records are artefacts (Type-A). Demonstrated competence under real conditions is Type-B. |
| **L4 Judgement** | "Is this person actually competent?" — not "did they attend the course?" |
| **L5 Assurance** | "Does the competence framework produce genuinely competent people?" Independent review of the whole system. |

**Key principle**: Training completion is Type-A (activity). Demonstrated competence is Type-B (outcome). Assurance of competence asks whether the entire framework works — not whether individual records are filed. This is a second or third-line activity.

**For the schema**: Training Tracker is an L5 entity only if it tracks *assurance of competence* (independent verification). If it only tracks *training completion* (activity records), it's an L3 control / L4 artefact.

---

## Meta-assurance: quality assurance of the assurance programme

The IIA's Global Internal Audit Standards require a **Quality Assurance and Improvement Programme (QAIP)**:

- **Internal assessments**: ongoing monitoring (supervision, checklists, feedback) + periodic self-assessments (at least annually)
- **External assessments**: at least every five years by a qualified independent assessor

The QAIP evaluates: (1) conformance with professional standards, and (2) achievement of the audit function's performance objectives.

**For the schema**: the assurance programme itself is a subject that can be audited. A QAIP review is a special assurance activity where the subject is the assurance function, not a control.

---

## Defence sector: Independent Safety Assurance

The UK MOD's model (via DSA) provides the strongest example of structural independence:

- DSA has a **charter from the Secretary of State** granting independence
- DSA **regulates, investigates, and provides assurance** on health, safety, and environmental protection
- The Director General DSA provides an **Annual Assurance Report** to the Secretary of State
- The **Independent Safety Auditor (ISA)** under Def Stan 00-56 is structurally independent of the project team — they verify the Safety Case

This is independence by design — chartered, structurally separated, reporting to the top. For commercial organisations, the equivalent is internal audit reporting to the audit committee (not to the CEO or management).

---

## What L5 needs as entities

Based on the patterns above, L5 requires:

| Entity | Purpose | Distinct from L4 because... |
|--------|---------|----------------------------|
| **Assurance Activities** | The planned and performed engagement (audit, inspection, review) | Has independence level, assurance line, **subject** (any layer, any entity, or the whole framework), criteria |
| **Assurance Findings** | What was observed, linked to the subject (control, law, process, system) and optionally to L4 Judgements being verified | Carries an assurance rating (Full/Substantial/Limited/No) — L4 Finding is binary |
| **Assurance Actions** | Recommendations with owners, deadlines, close-out verification | Distinct from L2 Actions because they require *verified effectiveness* not just completion |
| **Assurance Programme** | The plan of all activities, with the assurance map | No L4 equivalent — the programme is the coordination layer across all layers |

**Subject flexibility**: the Assurance Activity `subject` is not restricted to L3 controls. It can reference a control, a law (L1), an assessment (L2), a judgement process (L4), the assurance programme itself (L5), the incident reporting system (L6), a governance decision (L7), or the compliance framework as a whole. This is what makes L5 a horizontal layer — it assures everything else.

**Training Tracker** sits as a specific assurance concern — competence assurance. It may be a specialised view of Assurance Activities focused on competence, or a standalone entity that feeds the assurance map.

**Document Control** is cross-cutting infrastructure, not specifically L5. It supports all layers.

---

## Principles for the canonical schema

1. **Independence is the defining property.** Every assurance activity must declare its line (1st/2nd/3rd/external) and the independence of the assurer from the subject being assessed. Without this, L5 collapses into L4.

2. **Assurance scopes on anything.** The subject of an assurance activity can be a control, a law, a process, a judgement, the assurance programme itself, or the entire compliance framework. L5 is horizontal — it assures all other layers.

3. **Assurance tests operating effectiveness, not just design.** Prefer Type-B evidence. Flag subjects with only Type-A assurance.

4. **The assurance map drives allocation.** Like VoI for evidence, the assurance map allocates finite assurance effort proportionally to risk. High-risk under-assured subjects get priority.

5. **Findings can confirm, challenge, or create L4 entities.** L5 doesn't operate in isolation — it feeds back into the L4 Judgement and Gap process.

6. **The programme itself is assured.** QAIP is meta-assurance. The schema should support it.

7. **Ratings are structured, not free text.** Full / Substantial / Limited / No Assurance — not narrative opinions.

8. **The compliance framework itself is a subject.** The most important assurance question is: "does this organisation's compliance system actually work?" This spans all seven layers and is the question regulators ask during inspection.

---

## References

- IIA Three Lines Model (2020) — structural independence, role clarity, value creation
- IIA Global Internal Audit Standards (2025) — QAIP, competence, independence
- JSP 815 Element 12 (2024) — MOD assurance framework, 1LOD/2LOD/3LOD, assurance ratings
- JSP 815 Annex H — Audit Manual (methodology, reporting, close-out)
- Def Stan 00-56 Issue 7 (2017) — Independent Safety Auditor, Safety Case assurance
- DSA Charter — structural independence by design
- ISO 19011:2018 — Audit principles, competence, programme management
- PCAOB AS 2201 / SOC 1&2 — Design vs operating effectiveness, Type 1 vs Type 2
- ONR Licence Condition 17 — Quality management, adequate arrangements
- ORR ROGS / Safety Verification — Independent Competent Person
- CAA State Safety Programme — Performance-based oversight, RSMS
- `EVIDENCE-SCHEMA.md` — L4 canonical schema (Artefacts, Judgements, Gaps)
- `EVIDENCE-CALIBRATION.md` — Judgement vs calibration vs drift terminology
- `LEGIBLE-vs-LOAD-BEARING.md` — VoI 2x2, operationalisation paradox
- `VALUE-OF-INFORMATION.md` — EVI applied to evidence and assurance allocation
- `COMPLIANCE-7-LAYERS.md` — L5 definition: verify controls are effective
