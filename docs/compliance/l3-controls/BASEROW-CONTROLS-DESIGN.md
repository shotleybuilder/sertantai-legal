# L3 Controls Layer: Design Document

**Status**: Design draft
**Layer**: L3 Controls (from `COMPLIANCE-7-LAYERS.md`)
**Purpose**: Define how obligations are implemented operationally — the wiring diagram between what the law requires and what the organisation does.

---

## Design Principle

**L3 is a mapping layer, not a documentation layer.**

Controls themselves live in operational systems — HSE management systems, quality procedures, HR training records, engineering maintenance schedules, IT security policies. L3 maps which controls satisfy which obligations, without duplicating the control documentation.

Think of it as a **tube map**:
- **Stations** = obligations (from L1 Duties) and controls (from operational systems)
- **Lines** = the mappings showing which controls serve which obligations
- **Interchanges** = controls that serve multiple obligations (the high-value nodes)

---

## Research Summary

### Industry consensus

Based on ISO 27001, COSO, NIST OSCAL, ServiceNow GRC, and the Secure Controls Framework:

1. **The mapping is a first-class entity** — not just a join table. It carries its own metadata: coverage level, justification, who mapped it, when.
2. **Controls are records in the compliance system** — they hold summary metadata (title, type, owner, frequency, status) plus an optional pointer to detailed operational documentation.
3. **The obligation-to-control relationship is many-to-many** — one control can satisfy multiple obligations; one obligation may need multiple controls.
4. **Controls have multiple classification axes** — function (preventive/detective/corrective), nature (manual/automated), domain (organisational/people/physical/technical), effectiveness (design/operating).
5. **Testing and evidence are separate from the control definition** — a control persists; each assessment cycle creates test records with evidence.

### The hybrid pattern (recommended)

The GRC system holds a **control summary** sufficient for compliance reporting, plus a **reference/link** to the detailed operational procedure. This avoids duplication while ensuring the compliance system can function independently.

---

## Data Model

### Entities

```
Duties (L1)
    │
    │  many-to-many via Control Mappings
    │
Controls (L3)
    │
    │  1:many
    │
Evidence (L4) — proof the control operated
```

### Control Record

The control record answers: "what is this control, who owns it, how does it act on risk, and where is it documented?"

**Properties** (static):

| Field | Type | Purpose |
|-------|------|---------|
| Control | Formula (primary) | Display: `concat(field('Control_Type'), ' — ', field('Title'))` |
| Title | Text | Short name (e.g., "Lone working risk assessment") |
| Description | Long text | Summary of how the control works — enough for compliance reporting |
| Control_Type | Single select | Preventive / Detective / Corrective / Directive |
| Nature | Single select | Manual / Automated / IT-dependent manual |
| Domain | Single select | Organisational / People / Physical / Technical |
| Owner | Link_row → Personnel | Who is accountable for this control operating |
| Status | Single select | Active / Under Review / Planned / Retired |
| Tier | Single select | Corporate / Jurisdiction / Contract |
| External_Ref | URL | Link to detailed procedure/policy in operational system |
| Design_Effectiveness | Single select | Effective / Ineffective / Not Tested |
| Operating_Effectiveness | Single select | Effective / Ineffective / Not Tested |
| Last_Verified | Date | When control effectiveness was last checked |

**Methods** (how it acts on risk):

| Field | Type | Purpose |
|-------|------|---------|
| Risk_Method | Multi select | Consequence / Exposure / Likelihood |
| Blast_Radius | Single select | Local / Area / Site / Enterprise |

**Events** (demand regime):

| Field | Type | Purpose |
|-------|------|---------|
| Frequency | Single select | Continuous / Daily / Weekly / Monthly / Quarterly / Annual / Ad-hoc |
| Demand_Mode | Single select | Normal / Abnormal / Emergency |

**Organisational context** (links to Hierarchy table):

| Field | Type | Purpose |
|-------|------|---------|
| Org_Unit | Link_row → Hierarchy | Where in the org structure (Division, Department, etc.) |
| Location | Link_row → Hierarchy | Where geographically (Site, Building, etc.) |

**Distance**:

| Field | Type | Purpose |
|-------|------|---------|
| Info_Distance | Single select | Direct / Adjacent / Mediated / Remote |

**Notes**:

| Field | Type | Purpose |
|-------|------|---------|
| Notes | Long text | Implementation notes, conditions, limitations |

### Control Mapping (the wiring)

The mapping is a **lean join table** linking Controls to obligations at two tiers. This is the tube map — the wiring diagram.

| Field | Type | Purpose |
|-------|------|---------|
| Mapping | Formula (primary) | Display: see below |
| Law | Link_row → Legal Register | Law-level mapping (coarse). Always populated. |
| Obligation | Link_row → Duties | Provision-level mapping (granular). Empty for law-level mappings. |
| Control | Link_row → Controls | Which control addresses it |
| Strength | Single select | Primary / Supporting / Ancillary |

Four fields plus the primary. No status (implied by Control + Law status), no justification (that's L7 governance), no audit trail (Baserow row history provides this).

**Primary formula**: `if(field('Obligation') != '', concat(field('Obligation'), ' ↔ ', field('Control')), concat(field('Law'), ' ↔ ', field('Control')))`

### Strength

How strongly this control addresses the obligation:

| Value | Meaning | Example |
|-------|---------|---------|
| **Primary** | Main control for this obligation — specifically designed to address it | Risk assessment procedure is the primary control for MHSW reg.3 |
| **Supporting** | Contributes but doesn't fully address alone | Training programme supports the risk assessment requirement |
| **Ancillary** | Tangentially relevant, not designed for this obligation | General site induction touches on this duty incidentally |

AI-suggested mappings would typically start as Supporting or Ancillary until a compliance officer confirms them as Primary. The absence of any Primary mapping for an obligation is a coverage signal — not a "Gap" field value, but the absence of a row.

### Two-tier mapping

A control can map at **law level** or **provision level**:

| Scenario | Law field | Obligation field | Meaning |
|----------|-----------|-----------------|---------|
| Law-level | HSWA 1974 | (empty) | Control covers the whole law — implicitly all provisions |
| Provision-level | HSWA 1974 | s.2(1) | Control specifically addresses this provision |

**Law-level** is the common case. A compliance officer says "our risk assessment procedure covers HSWA" — they don't need to map it to each of the 80+ provisions. The law-level mapping implicitly covers all provisions beneath.

**Provision-level** is for targeted controls. "Our confined space entry permit specifically addresses reg.4 of the Confined Spaces Regulations." When the provision-level mapping is set, Law is also populated (via lookup or manual selection) for grouping and reporting.

This mirrors how compliance officers actually work — start coarse, drill into provisions only where the control is specific to a particular duty.

### Why a separate mapping table?

The many-to-many relationship between obligations and Controls could be modelled as link_row fields directly. But a separate mapping table adds:

- **Two-tier obligation linking** — law level OR provision level on the same mapping
- **Strength** — qualifies the relationship (Primary/Supporting/Ancillary)
- **Gap detection by absence** — obligations with no mapping rows are uncovered

The table stays lean — a pure join with one qualifying dimension. Organisational hierarchy context lives on the Control (via Org Structure links), not on the mapping. Governance decisions (justification, approval) live at L7, not here.

### Where things DON'T live on the mapping

| Concern | Where it lives | Why not on mapping |
|---------|---------------|-------------------|
| Status | Control.Status + Law.live | Mapping is implicitly active when both sides are active |
| Justification | L7 Decisions & Governance | Governance record, not a wiring property |
| Owner | Control.Owner | The control has an owner, the wire doesn't |
| Hierarchy | Control → Org Structure links | Organisational context is a property of the control |
| Audit trail | Baserow row history | Who changed what and when is automatic |

---

## How It Connects

### The full L1→L3→L4 chain

```
Legal Register (L1)
  └── Duties (L1) — governed obligations
        └── Control Mappings (L3) — wiring
              └── Controls (L3) — operational mechanisms
                    └── Evidence (L4) — proof of operation
                    └── Audits (L5) — effectiveness verification
```

### Relationship to existing templates

| Template | Current Link | With Controls |
|----------|-------------|---------------|
| **Assessment** | Assesses obligation directly | Assesses whether CONTROLS are adequate |
| **Action Tracker** | Remediates assessment gaps | Targets a CONTROL — fix/improve/create it |
| **Evidence Vault** | Evidence for assessments | Evidence that CONTROLS operated |
| **Audit Management** | Audits assessments | Audits CONTROL effectiveness |

**Actions point to Controls, not obligations.** An action is "fix this control" or "create a new control." You can't directly act on a law — you can only change the operational mechanisms that implement it. The compliance chain:

```
Assessment identifies gap
  → "Controls for HSWA s.2(1) are inadequate"
    → Action created: "Develop lone working risk assessment"
      → Action targets: Control (new or existing)
        → Control change → compliance improves
```

The Assessment shifts from "is the organisation compliant with this law?" to "are the controls that implement this obligation effective?" This is the ISO 19011 / COSO model.

---

## Control Ontology: Properties, Methods, Events

Borrowing from OOP, a control has **Properties** (what it is), **Methods** (how it changes risk), and responds to **Events** (demands placed on it).

### Properties (static characteristics)

What the control IS — its classification and ownership.

| Property | Values | Purpose |
|----------|--------|---------|
| **Control_Type** | Preventive / Detective / Corrective / Directive | Function — what the control does |
| **Nature** | Manual / Automated / IT-dependent manual | How the control operates |
| **Domain** | Organisational / People / Physical / Technical | ISO 27001:2022 category |
| **Owner** | Link_row → Personnel | Accountability |
| **Status** | Active / Under Review / Planned / Retired | Lifecycle state |
| **Design_Effectiveness** | Effective / Ineffective / Not Tested | As-designed adequacy |
| **Operating_Effectiveness** | Effective / Ineffective / Not Tested | As-operated adequacy |
| **Tier** | Corporate / Jurisdiction / Contract | Inheritance level |
| **External_Ref** | URL | Pointer to operational documentation |

### Methods (how the control changes risk)

A control acts on one or more dimensions of risk. The three dimensions (from Kinney's risk model):

| Risk Dimension | What it measures | How controls act on it |
|----------------|-----------------|----------------------|
| **Consequence / Impact** | Size of harm if the event occurs | Engineering controls reduce severity (guards, containment). The **blast radius** of the control — inverse of the maximum consequence it can contain. A local exhaust ventilation system has a small blast radius (one workstation); a site emergency plan has a large one (entire facility). |
| **Exposure** | Time/frequency of exposure to the hazard | Administrative controls reduce exposure duration (shift rotation, work scheduling, zoning). Time dimension — how long people/assets are in the hazard zone. |
| **Likelihood** | Probability of the event per unit exposure | Procedural controls reduce probability (permits to work, interlocks, training). Chance per exposure event. |

A single control typically acts on one primary dimension:
- **Guard rail** → reduces Consequence (fall from height → fall arrested)
- **Shift rotation** → reduces Exposure (workers spend less time in hazard zone)
- **Permit to work** → reduces Likelihood (unauthorised entry prevented per access attempt)

The control record should capture which dimension(s) it primarily acts on:

| Field | Type | Purpose |
|-------|------|---------|
| Risk_Method | Multi select | Consequence / Exposure / Likelihood |
| Blast_Radius | Single select | Local (single process) / Area (department/zone) / Site / Enterprise |

### Events (demands placed on the control)

Controls don't operate in a vacuum — they respond to demands. The demand regime determines when and how hard the control is exercised.

**Demand types** (adapted from ITIL + EHS):

| Demand | Description | Control response | Example |
|--------|-------------|-----------------|---------|
| **Normal** | Routine operations within design envelope | Control operates as designed, at planned frequency | Daily inspection, monthly fire alarm test |
| **Abnormal** | Deviation from routine but within contingency | Control may operate at elevated frequency or scope | Increased inspections after a near-miss, temporary procedure change |
| **Emergency** | Beyond design envelope, immediate threat | Control operates at maximum capacity or fails to a safe state | Emergency evacuation, emergency shutdown, crisis response |

The `Frequency` field captures the **normal demand signal** — how often the control is exercised under routine conditions:

| Frequency | Demand rate |
|-----------|------------|
| Continuous | Always active (engineering control, monitoring system) |
| Daily | Once per day (shift handover check, daily inspection) |
| Weekly | Once per week (toolbox talk, weekly review) |
| Monthly | Once per month (safety committee, monthly audit) |
| Quarterly | Four times per year (management review, quarterly drill) |
| Annual | Once per year (annual risk assessment, external audit) |
| Ad-hoc | On demand only (incident investigation, permit to work) |

But the demand type matters: a control designed for monthly normal demand may face daily abnormal demand after an incident. The gap between **design demand** and **actual demand** is a risk signal.

| Field | Type | Purpose |
|-------|------|---------|
| Frequency | Single select | Normal demand rate (design operating frequency) |
| Demand_Mode | Single select | Normal / Abnormal / Emergency — current operating mode |

### Information Distance (Westrum)

Ron Westrum's concept of **information distance** measures how many organisational boundaries information must cross between the controller and the controlled. High information distance = weak control.

| Distance | Description | Risk implication |
|----------|-------------|-----------------|
| **Direct** | Controller and controlled are the same person/team | Low — immediate feedback (e.g., operator follows own procedure) |
| **Adjacent** | One boundary — direct report, same department | Low-medium — supervisor checks worker's compliance |
| **Mediated** | Two+ boundaries — via management chain or systems | Medium — compliance officer verifies site manager who oversees workers |
| **Remote** | Cross-organisational — contractor, supplier, regulator | High — corporate HQ verifies subsidiary compliance via reports |

Information distance affects:
- **Detection lag** — how long before non-compliance is noticed
- **Response time** — how long before corrective action reaches the controlled process
- **Signal fidelity** — how much the compliance signal degrades through intermediaries

| Field | Type | Purpose |
|-------|------|---------|
| Info_Distance | Single select | Direct / Adjacent / Mediated / Remote |

A control with Remote information distance and Emergency demand mode is a high-risk configuration — the organisation should invest in reducing the distance (better monitoring, closer oversight) or adding redundant controls.

---

## Control Types for EHS/Compliance

Combining the Properties/Methods/Events model with EHS-specific examples:

| Type | Function | Risk Method | EHS Examples |
|------|----------|-------------|-------------|
| **Preventive** | Stops harm before it occurs | Primarily Likelihood | Risk assessments, permits to work, engineering guards, interlocks, training |
| **Detective** | Identifies harm/non-compliance after it occurs | Reduces Exposure (by shortening time between event and detection) | Inspections, monitoring, incident reporting, audits, gas detection |
| **Corrective** | Restores safe state after detection | Reduces Consequence (by limiting damage duration/extent) | Emergency response, incident investigation, corrective actions, shutdown |
| **Directive** | Guides behaviour toward compliance | Reduces Likelihood (by increasing probability of correct behaviour) | Policies, procedures, signage, codes of conduct, safety rules |

### Nature dimension

| Nature | Description | Info Distance | Examples |
|--------|-------------|--------------|---------|
| **Manual** | Performed by a person | Adjacent-Remote | Manager walkabout, permit check, training delivery |
| **Automated** | Performed by a system | Direct | Gas detection alarm, access control, monitoring sensor, interlock |
| **IT-dependent manual** | Manual activity using system output | Adjacent-Mediated | Reviewing system-generated exception report, checklist audit |

---

## Baserow Template Design

### Tables

| Table | Purpose | Estimated Rows |
|-------|---------|---------------|
| Controls | Control register — what mechanisms exist | 100–500 |
| Control Mappings | Wiring — which controls satisfy which obligations | 500–2,000 |

### Views — Controls table

| View | Type | Purpose |
|------|------|---------|
| All Controls | Grid | Default |
| By Type | Grid | Grouped by Control_Type |
| By Owner | Grid | Grouped by Owner — who is responsible for what |
| By Status | Kanban | Active / Under Review / Planned / Retired |
| By Domain | Grid | Grouped by Domain |
| Needing Verification | Grid | Filtered: Last_Verified is empty or > 12 months ago |

### Views — Control Mappings table

| View | Type | Purpose |
|------|------|---------|
| All Mappings | Grid | Default |
| Coverage Gaps | Grid | Filtered: Coverage = "Gap" or Coverage = "Partial" |
| By Obligation | Grid | Grouped by Obligation — see all controls per duty |
| By Control | Grid | Grouped by Control — see all obligations per control |

### Cross-table fields

| Table | Field | Purpose |
|-------|-------|---------|
| Duties | Control_Count | Count of linked control mappings |
| Duties | Coverage_Status | Rollup: any Gap mappings? → "Has Gaps" |
| Controls | Obligation_Count | Count of linked control mappings |

---

## The Tube Map Concept

For a visual representation, each obligation is a "station" and each control is a "line" connecting stations:

```
HSWA s.2(1)  ───── Risk Assessment Procedure ───── MHSW reg.3(1)
     │                                                    │
     │                                                    │
     ├──── Safety Training Programme ──── CDM reg.4(1) ──┘
     │
     └──── Workplace Inspection Regime ──── HSWA s.2(2)
```

A control like "Risk Assessment Procedure" is an **interchange** — it serves multiple obligations across multiple laws. These are the highest-value controls to maintain.

In Baserow, the "By Control" grouped view on Control Mappings gives this perspective — expand a control and see all the obligations it satisfies.

---

## Implementation Notes

### Populating the Controls table

Controls are **customer-specific** — they reflect the organisation's actual operational mechanisms. SertantAI cannot pre-populate this table from legal data. The customer's compliance team populates it from their management system.

We CAN suggest controls based on the obligation text (AI-assisted control recommendation), but the final control register is the customer's responsibility.

### Populating the Control Mappings table

This is where AI can add significant value:
- Given a duty text and a list of the customer's controls, suggest which controls map to which duties
- Flag obligations with no mapped controls (coverage gaps)
- Flag controls with no mapped obligations (orphan controls — may be unnecessary)

### Row budget

| Component | Rows | Notes |
|-----------|------|-------|
| Controls | 100–500 | Customer-specific, manually populated |
| Control Mappings | 500–2,000 | Many-to-many, grows with controls × obligations |
| Cumulative with existing | ~7,000 | Well within 50K |

---

## Sub-Pattern Dimensions

| Dimension | Values | Effect |
|-----------|--------|--------|
| `people` | flat / linked / workspace_member / hybrid | Control Owner field type |

Controls template is simpler than Assessment — fewer sub-pattern dimensions. The main variation is people mode.

---

## Hierarchy Table (Adjacency List)

A single table for all organisational hierarchies. Replaces the previous Org Structure template (separate Sites + Divisions tables) with a flexible adjacency list pattern.

### Schema

| Field | Type | Purpose |
|-------|------|---------|
| Node | Formula (primary) | Display: `concat(field('Type'), ': ', field('Name'))` |
| Name | Text | Node name (e.g., "Manchester", "EHS Department") |
| Hierarchy | Single select | org / geo / finance / reporting |
| Type | Single select | Organisation / Division / Department / Function / Site / Building / Floor / Region / Country / Cost Centre |
| Parent | Link_row → Hierarchy (self) | Parent node in the tree |
| Description | Long text | Notes about this node |

### How it works

Every node in every hierarchy lives in one table. The `Parent` field is self-referential — each node points to its parent. Root nodes have no parent.

```
Hierarchy = org:
  QinetiQ Group (Organisation)
    ├── UK Division (Division)
    │     ├── EHS Department (Department)
    │     └── Engineering (Department)
    └── AU Division (Division)
          └── Operations (Department)

Hierarchy = geo:
  United Kingdom (Country)
    ├── Manchester (Site)
    │     ├── Building A (Building)
    │     └── Building B (Building)
    └── Farnborough (Site)

Hierarchy = finance:
  UK Division (Division)
    ├── CC-4502 (Cost Centre)
    └── CC-4503 (Cost Centre)
```

### Views

| View | Filter/Group | Purpose |
|------|-------------|---------|
| Org Structure | Hierarchy = org | Organisational tree |
| Locations | Hierarchy = geo | Geographic tree |
| Cost Centres | Hierarchy = finance | Finance hierarchy |
| Top Level | Parent is empty | Root nodes across all hierarchies |
| By Type | Grouped by Type | All Sites together, all Departments together |

### How Controls link to it

Controls have **two link_row fields** to the Hierarchy table:

| Field | Purpose | Filter hint |
|-------|---------|-------------|
| Org_Unit | Which part of the organisation owns/operates this control | Typically nodes where Hierarchy = org |
| Location | Where this control operates geographically | Typically nodes where Hierarchy = geo |

A control linked to "UK Division" at the org level implies it covers all departments beneath. A control linked to "Manchester" at the geo level implies it operates at that site and all buildings within.

Inheritance is implied by tree position — no duplicate records needed.

### Why one table, not many

| Approach | Tables | Flexibility | Depth |
|----------|--------|-------------|-------|
| Chained tables (old) | 1 per level (Sites, Divisions) | Rigid — fixed levels | Fixed at 2 |
| Adjacency list (new) | 1 table | Any hierarchy, any depth | Unlimited |

The adjacency list handles any customer structure. One customer has Org→Division→Site. Another has Region→Country→Business Unit→Location→Building. Same table, different Type values, different Parent chains.

### Trade-offs

- **No native tree view** in Baserow — the grid is flat. Parent→child visible when expanding a row. Grouping by Parent gives a partial hierarchy view.
- **Self-referential link_row works** in Baserow — tested and confirmed.
- **Type values are customer-specific** — the single select options should be populated based on the customer's structure, not hardcoded.

---

## Tiering and Inheritance

### The DRY problem

Compliance requirements cascade through multiple tiers. A control that satisfies a UK law obligation also satisfies the corporate policy that mandated that law's adoption, and may satisfy a customer contract clause that demands compliance with that law. Building each tier's compliance register from scratch duplicates work.

**Principle: Don't Repeat Yourself.** Higher tiers inherit down, lower tiers surface up. The work at each tier is to **supplement and spot conflicts**, not rebuild.

### Tier model

```
┌──────────────────────────────────────────────────────┐
│  T1  Corporate / Group / Pan-national                │
│      Group HSE policy, corporate standards,          │
│      parent company requirements                     │
│      Controls: group-wide procedures                 │
├──────────────────────────────────────────────────────┤
│  T2  Country / Jurisdiction                          │
│      Laws and regulations (this is where L1 lives)   │
│      Controls: country-specific implementations      │
│      INHERITS from T1 + adds jurisdiction-specific   │
├──────────────────────────────────────────────────────┤
│  T3  Contract / Customer                             │
│      Customer-imposed requirements                   │
│      Controls: contract-specific measures             │
│      INHERITS from T1+T2 + supplements               │
└──────────────────────────────────────────────────────┘
```

### How inheritance works

**Downward (T1→T2→T3):**
- A corporate policy control at T1 ("All sites must conduct annual fire risk assessments") automatically satisfies the UK law obligation at T2 (Regulatory Reform (Fire Safety) Order 2005, Article 9)
- The T2 register doesn't need to create a separate control — it inherits from T1 and maps it to the local obligation
- A customer contract at T3 that requires "compliance with all applicable fire safety legislation" is satisfied by the inherited T1+T2 chain

**Upward (T3→T2→T1):**
- A T3 customer contract demands something beyond the law ("weekly fire drills" when the law only requires "regular" drills)
- This T3-specific control supplements the inherited T2 controls
- The T3 register shows: inherited controls (from T1+T2) + supplementary controls (T3-specific)
- If the T3 requirement CONFLICTS with a T2 requirement, this needs flagging — not silent override

### Obligation tiering

Obligations also tier:

| Tier | Obligation Source | Granularity | Example |
|------|------------------|-------------|---------|
| **Law** | Legal Register | Per law | "HSWA 1974 applies to this organisation" |
| **Provision** | Duties table | Per clause | "s.2(1): employer shall ensure health and safety" |
| **Contract** | Customer requirements | Per clause | "Contractor shall provide weekly safety reports" |

A control can map at any tier:
- "Risk assessment procedure" maps to HSWA (law tier) — covers all provisions beneath
- "Confined space entry permit" maps to reg.4 of Confined Spaces Regulations (provision tier) — specific
- "Weekly safety report" maps to a contract clause (contract tier) — customer-specific

### The "supplement and conflict" workflow

When building a T3 (contract) compliance register:

1. **Start with inheritance** — pull in all T2 controls that satisfy the jurisdiction's laws
2. **Map contract clauses** — identify which contract requirements are ALREADY satisfied by inherited controls
3. **Supplement** — add new controls only where the contract demands something beyond the inherited set
4. **Flag conflicts** — where a contract clause contradicts or exceeds a legal requirement (e.g., stricter frequency, different methodology)

The compliance officer's work is steps 2-4, not step 1. This is where the value lies — the system does the heavy lifting of inheritance, the human does the gap analysis.

### Implications for the Baserow data model

The Control record carries the `Tier` field:

| Value | Meaning |
|-------|---------|
| Corporate | Group-wide, applies across all jurisdictions and contracts |
| Jurisdiction | Country/region-specific |
| Contract | Customer/contract-specific, supplements inherited controls |

Inheritance is **implied, not modelled on the mapping**. A Corporate-tier control that maps to HSWA is visible to all tiers — no duplicate mapping rows needed. Tier filtering happens on the Control, not the Mapping.

The Control Mapping stays lean — no inheritance metadata. The same mapping row serves all tiers because the Control itself carries the tier context.

### Conflict detection

When a lower-tier obligation sets requirements that exceed the inherited control:
- The conflict is detected by comparing Control.Tier with the obligation's demands
- Resolution is a governance decision (L7) — not a property of the mapping
- The compliance officer creates a new Control at the lower tier to supplement

### Multi-national implications

For a multinational with operations in UK, Australia, Germany:
- T1 corporate controls are shared across all countries — one Control record, mapped to obligations in each jurisdiction
- T2 controls are jurisdiction-specific (UK HSWA, AU WHS Act, DE ArbSchG)
- The same corporate control maps to DIFFERENT country obligations via separate Mapping rows — but the Control is NOT duplicated
- Organisational hierarchy (which division, which site) lives on the Control via Org Structure links

This is the "interchange" on the tube map — a single corporate control is a station where multiple country obligation lines converge.

---

## Open Questions

1. **Should the Assessment template assess Controls rather than Obligations directly?** The COSO/ISO model assesses control effectiveness, not obligation compliance. This is a bigger architectural shift.
2. **How to handle control effectiveness feeding back into L2 risk scoring?** A control rated "Ineffective" should elevate the risk for its obligations.
3. **When to build the tiering infrastructure vs keeping it simple for PoC?** The Baserow PoC could start with flat controls (no tiering) and add inheritance later.
4. **Should AI suggest control mappings?** Given a duty text and the customer's control register, suggest which controls map to which duties and flag coverage gaps.

---

## References

- ISO 27001:2022 Annex A — control classification with 5 attribute types
- COSO 2013 — internal control framework (5 components, 17 principles)
- NIST OSCAL — machine-readable control catalog/mapping/assessment models
- Secure Controls Framework — 1,400+ controls mapped to 200+ frameworks
- ServiceNow GRC — commercial data model with control/risk/policy tables
- `COMPLIANCE-7-LAYERS.md` — the architecture this implements
- `BASEROW-7-LAYERS.md` — layer status mapping
