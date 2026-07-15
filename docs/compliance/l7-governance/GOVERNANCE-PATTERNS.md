# L7 Decisions & Governance — Patterns

The meta-layer that governs the compliance framework itself. L7 does not manage compliance — it asks whether the compliance framework is adequate, proportionate, and effective. It sets policy, defines risk appetite, reviews performance, and holds accountability.

---

## What L7 IS and IS NOT

### IS

- **Governance OF the compliance framework** — is it working? Is it adequate? Is it proportionate to the risks?
- **Policy** — the organisation's stated approach to compliance, approved at board level
- **Risk appetite** — how much residual compliance risk is the organisation willing to accept, explicitly
- **Management review** — periodic review of the framework's performance by senior leadership
- **Senior reporting** — compliance posture communicated to board, audit committee, regulators
- **Accountability** — who is accountable for the compliance framework functioning (not who runs each control)
- **Decision provenance** — audit trail for governance decisions: risk acceptance, policy approval, resource allocation

### IS NOT

- **Not operational compliance management** — that's L1–L6. L7 does not design controls (L3), collect evidence (L4), or manage remediation actions (L2).
- **Not individual compliance decisions** — L4 Gaps already capture reconciliation decisions with three exits (correct work, amend constraint, protect adaptation). L7 is about the framework, not about specific obligations.
- **Not task tracking** — the Actions entity in L2 already tracks remediation tasks. L7 doesn't duplicate this.
- **Not a second audit function** — L5 Assurance provides the seam for independent verification. L7 receives and acts on assurance findings; it doesn't conduct audits.

**The boundary**: governance asks "is it working?" Operations answers "here is how it is working." Governance sets risk appetite, approves policy, allocates resources, reviews effectiveness, and makes escalation decisions. Operations designs controls, conducts assessments, manages remediation, and collects evidence.

---

## Six governance functions

### 1. Policy

The organisation's stated approach to compliance — what it commits to, how it will operate, and what values guide its decisions.

| ISO requirement | What it means |
|----------------|--------------|
| **ISO 45001 / 14001 / 9001 Clause 5.2** | Policy must be appropriate to context, provide a framework for objectives, include commitment to fulfil requirements + continual improvement, be documented, communicated, and available to interested parties |

Policy is not a document on a shelf. It is a **declared commitment** that the governance layer is accountable for. The test: does the policy match what the organisation actually does? If not, either the policy is wrong or the practice is wrong — and that gap is a governance concern, not an operational one.

**What compliance policy typically addresses**: scope of the compliance framework, commitment to legal compliance, approach to risk (appetite statement), accountability structure, escalation principles, resourcing commitment, culture expectations, and review cycle.

### 2. Risk appetite

How much residual compliance risk the organisation is willing to accept, explicitly.

| Concept | Level | Definition |
|---------|-------|-----------|
| **Risk appetite** | Strategic | The amount and type of risk the organisation is willing to pursue or retain to meet strategic objectives |
| **Risk tolerance** | Operational | Acceptable variation in outcomes — "no location may go more than 18 months without assessment" |
| **Risk capacity** | Maximum | The point at which non-compliance threatens licence to operate, reputation, or existence |

Most organisations say "zero tolerance for legal non-compliance." This is performative — resource constraints force prioritisation, which is itself a risk appetite decision. The governance obligation is to make risk appetite **explicit and documented**, not to pretend it doesn't exist.

**Risk appetite and the VoI 2x2**: the VoI framework (see [VALUE-OF-INFORMATION.md](../l4-evidence/VALUE-OF-INFORMATION.md)) allocates evidence effort proportionally to Expected Loss. Risk appetite sets the **threshold** — below what Expected Loss does governance accept residual risk without active mitigation? This is a governance decision, not an operational one.

**Risk acceptance decisions** require particular rigour: what risk is being accepted, why, for how long, what compensating measures exist, when will it be reviewed, and who is accountable. These decisions need decision provenance (function 6).

### 3. Management review

Periodic, structured review of the compliance framework's performance by senior leadership. This is the primary governance mechanism.

**ISO 9.3 requires (at minimum):**

| Inputs | What it tells governance |
|--------|-------------------------|
| Status of actions from previous reviews | Are we closing the loop? |
| Changes in external/internal issues | Has the context shifted? |
| Performance and effectiveness trends | Is the framework improving or degrading? |
| Audit results (L5) | What did independent assurance find? |
| Event trends (L6) | What is the regulatory environment doing? |
| Adequacy of resources | Do we have enough to do this properly? |
| Effectiveness of risk treatment | Are the controls actually working? |

| Outputs | What governance decides |
|---------|----------------------|
| Continuing suitability, adequacy, effectiveness | Does the framework still fit? |
| Continual improvement opportunities | What should change? |
| Need for changes to the management system | Structural changes, not just fixes |
| Resource needs | Budget, people, tools |

**What makes management review governance rather than operational**: the review must include someone with **authority to allocate resources and make binding decisions**. If decisions cannot be made, the review is procedurally compliant but governancially useless. It is a decision-making forum, not an information-sharing meeting.

**Frequency**: ISO requires "planned intervals" without specifying. In practice: quarterly operational reviews, annual strategic reviews. High-risk sectors (nuclear, aviation) often monthly.

### 4. Senior reporting

Compliance posture communicated to board, audit committee, and regulators.

**Two levels, both needed:**

| Level | What it provides | Risk |
|-------|-----------------|------|
| **Dashboard (quantitative)** | Heat maps, overdue actions, audit findings, event pipeline, trends | Dashboard fatigue — 40-page packs that obscure rather than illuminate |
| **Narrative (qualitative)** | What has changed, what concerns the team, what decisions the board needs to make, where exposure is greatest | Can be subjective, may lack rigour |

**What non-executive directors need**: clear plain-language summaries, trend information (not snapshots), comparison to risk appetite thresholds, and explicit identification of decisions required from the board.

**The critical distinction — posture vs activity:**

| | Compliance activity (what we did) | Compliance posture (where we stand) |
|---|---|---|
| **Measures** | Audits completed, training hours, assessments done | % obligations with effective controls, residual risk by domain, coverage gaps |
| **Value** | Effort | Outcome |
| **Board needs** | Context only | Primary |

Boards that only see activity metrics are governing effort, not effectiveness. This is the Measurement Inversion applied to governance reporting.

**Leading vs lagging at governance level:**

| | Leading (what might happen) | Lagging (what did happen) |
|---|---|---|
| **Examples** | Regulatory change pipeline, L6 events in triage, controls approaching verification due date, assurance coverage gaps | Enforcement actions, audit findings, non-conformances, prosecution |
| **Value** | Preparation | Learning |
| **Governance action** | Allocate resources, adjust risk appetite | Investigate root causes, demand improvement |

### 5. Accountability

Named individuals with defined responsibilities for the compliance framework's governance — not who runs each control (that's L3 Control.Owner), but who is accountable at organisational level.

**SM&CR model (applicable beyond financial services):**

| SM&CR concept | Generalised | L7 role |
|--------------|------------|---------|
| **Senior Management Function** | Named individual pre-approved for a governance role | The person accountable for the compliance framework |
| **Prescribed Responsibility** | Specific responsibility allocated to exactly one individual | "Responsibility for the effectiveness of the compliance framework" — no sharing, no gaps |
| **Statement of Responsibilities** | Document defining what each person is accountable for | The governance accountability map |
| **Reasonable steps** | Defence: "I took reasonable steps to prevent this" | Creates a decision trail requirement — governance must show it asked, resourced, and escalated |

**The accountability map**: at governance level, accountability is for the *framework*, not for individual obligations. A director is not accountable for whether a specific permit is filed (that's an operational owner in L3). They are accountable for ensuring the framework that manages permits is adequate, resourced, and effective.

**UK legal drivers**: HSWA s.37 (directors' duties — consent, connivance, or neglect), Environmental Permitting Regulations (adequate management systems), Building Safety Act 2022 (Accountable Person), Health and Care Act 2022 (CQC governance conditions). The consistent pattern: directors who "should have known but did not ask" are culpable.

### 6. Decision provenance

Audit trail for governance decisions — risk acceptance, policy approval, resource allocation, escalation decisions.

| Decision type | What must be recorded |
|--------------|----------------------|
| **Risk acceptance** | What risk, why accepted, for how long, compensating measures, review date, who is accountable |
| **Policy approval** | What changed, why, who approved, effective date, supersedes which version |
| **Resource allocation** | What was requested, what was approved, rationale for any gap, who decided |
| **Escalation** | What was escalated, by whom, to whom, what was decided, what changed as a result |
| **Management review outputs** | Conclusions, decisions, action items, resource commitments, accountable parties |

Decision provenance is the governance equivalent of L4's Judgement record — it captures who decided, seeing what, with what rationale. The difference: L4 captures operational judgements about controls; L7 captures governance decisions about the framework.

**Connection to the SMS dialectic**: the build spec's `decisions` entity (deferred in L4) is primarily a governance concept. Decisions about risk acceptance, constraint amendment, and resource allocation are L7 governance acts, not L4 operational judgements. The `Decisions` entity, when built, may live at L7 rather than L4.

---

## The governance-operations boundary

| Governance (L7) | Operations (L1–L6) |
|-----------------|-------------------|
| Sets risk appetite | Implements controls proportionate to risk |
| Approves policy | Operates within policy |
| Allocates resources | Uses resources to manage compliance |
| Reviews effectiveness | Reports on effectiveness |
| Makes escalation decisions | Escalates when thresholds are breached |
| Accepts residual risk (with provenance) | Identifies and quantifies residual risk |
| Asks "is it working?" | Answers "here is how it is working" |

**Governance becomes operational** when the board starts specifying control mechanisms (micro-management). **Operations become ungoverned** when management stops reporting upward or when governance bodies stop asking challenging questions.

The test: can you distinguish between a governance meeting (reviewing framework performance, making resource decisions) and an operational meeting (discussing specific controls and actions)? If not, the boundary has blurred.

---

## Regulatory expectations — what gets organisations in trouble

**Governance failures are punished more severely than operational failures.** An organisation with a functioning governance framework that experiences an operational failure (a control that didn't work) is treated more leniently than one where governance was absent or performative.

| Regulator | What they look for | What triggers enforcement |
|-----------|-------------------|--------------------------|
| **HSE** | Directors' duties under HSWA s.37: "consent, connivance, or neglect" | Directors who should have known but did not ask |
| **EA** | Adequate management systems for environmental permits | Sentencing guidelines consider governance quality (R v Thames Water) |
| **FCA** | SM&CR — named individuals, prescribed responsibilities, reasonable steps | Failure to allocate resources, failure to act on known risks, inadequate board reporting |
| **ONR** | Licence Condition 36 — organisational capability | Does the organisation have the governance structures to manage nuclear safety? |

**The consistent message**: regulators expect organisations to **govern** their compliance frameworks actively, not just **operate** them. The existence of controls (L3) without governance oversight (L7) is a systemic failure.

---

## How L7 relates to other layers

L7 does not add data to L1–L6. It consumes their outputs and makes governance decisions about the framework as a whole.

| What L7 receives | From | Governance action |
|-----------------|------|-------------------|
| Compliance posture summary | L2 Assessments | Is the overall posture acceptable? Does it match risk appetite? |
| Control effectiveness data | L3 Controls + L4 Judgements | Are controls working? Is the control framework adequate? |
| Assurance findings and ratings | L5 Assurance seam | What did independent assurance find? Any Limited/No Assurance ratings? |
| Event trends | L6 Compliance Events | Is the regulatory environment shifting? Are we detecting changes early enough? |
| Framework self-assessment | L1–L6 collectively | Is the compliance framework itself adequate and proportionate? |

| What L7 produces | Effect on other layers |
|------------------|----------------------|
| Updated policy | Cascade through all layers — new commitments create new requirements |
| Revised risk appetite | L2 risk scoring thresholds adjust; L4 VoI allocation shifts |
| Resource decisions | All layers — more/fewer people, tools, budget |
| Escalation decisions | L4 Gaps may be elevated; L6 Events may require urgent response |
| Improvement mandates | Cross-cutting — "redesign the evidence process" affects L4 architecture |

---

## The interface pattern

Like L5 and L6, L7 is an **interface** — governance of the compliance framework, not a separate system. The governance function uses its own tools (board papers, minute-taking systems, GRC platforms) and the compliance framework provides the data and receives the decisions.

What the compliance framework provides to governance:
- Aggregated compliance posture (from L2 assessments)
- Control coverage and effectiveness (from L3 + L4)
- Assurance opinions (from L5)
- Event pipeline and trends (from L6)
- Framework performance metrics (cross-cutting)

What governance decisions produce in the compliance framework:
- Updated risk appetite thresholds (affects L2 scoring, L4 VoI)
- Policy changes (may create new obligations at L1)
- Resource allocation (affects all layers)
- Risk acceptance records (documented decision provenance)

---

## References

- ISO 45001:2018, ISO 14001:2015, ISO 9001:2015 — Clause 5 (Leadership), Clause 9.3 (Management Review)
- UK Corporate Governance Code 2024 — Principle O, Provisions 25, 29
- FCA SM&CR — Senior Management Functions, Prescribed Responsibilities, Statements of Responsibilities
- DOJ Evaluation of Corporate Compliance Programs (2020, updated 2023)
- ISO 31000:2018 — Risk management framework design, risk appetite
- COSO ERM (2017) — Risk appetite and strategy alignment
- IRM Risk Appetite Guidance (2011) — Maturity model
- HSWA 1974 s.37 — Directors' duties (consent, connivance, neglect)
- Building Safety Act 2022 — Accountable Person
- ONR Licence Condition 36 — Organisational capability
- Haddon-Cave (2009) — Nimrod Review: governance failures and "shelfware"
- `COMPLIANCE-7-LAYERS.md` — L7 definition
- `VALUE-OF-INFORMATION.md` — VoI framework (risk appetite sets the threshold)
- `ASSURANCE-INTERFACE.md` — L5 seam (governance receives assurance findings)
- `EVENTS-SCHEMA.md` — L6 events (governance receives event trends)
