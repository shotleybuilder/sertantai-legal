# Baserow Workspace Schema

The complete data model for a customer's compliance workspace in Baserow. Shows all tables, their relationships, and which compliance layer (L1–L7) they belong to.

---

## Table Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  L1 — OBLIGATIONS                                                          │
│                                                                             │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐       │
│  │  Legal Register   │◄──┤     Duties        │◄──┤  Actor Tuples    │       │
│  │  (LRT)            │    │  (LAT)           │    │                  │       │
│  │                   │    │                  │    │  actor ×          │       │
│  │  274 laws         │    │  2,400 governed  │    │  position ×      │       │
│  │  significance     │    │  obligations     │    │  DRRP type       │       │
│  │  rating + score   │    │  significance    │    │                  │       │
│  └────────┬──────────┘    └────────┬─────────┘    └──────────────────┘       │
│           │                        │                                         │
└───────────┼────────────────────────┼─────────────────────────────────────────┘
            │                        │
            │    ┌───────────────────┘
            │    │
┌───────────┼────┼─────────────────────────────────────────────────────────────┐
│  L3 — CONTROLS                                                               │
│           │    │                                                              │
│           │    │    ┌──────────────────┐    ┌──────────────────┐              │
│           │    └───►│ Control Mappings  │◄──┤    Controls       │              │
│           │         │  (wiring)        │    │                  │              │
│           │         │                  │    │  Properties      │              │
│           │         │  coverage        │    │  Methods         │              │
│           │         │  justification   │    │  Events          │              │
│           │         │  inherited?      │    │  Distance        │              │
│           │         │  supplement/     │    │                  │              │
│           │         │  conflict        │    │  Tier: Corp /    │              │
│           │         └──────────────────┘    │  Jurisdiction /  │              │
│           │                                 │  Contract        │              │
│           │                                 └────────┬─────────┘              │
│           │                                          │                        │
└───────────┼──────────────────────────────────────────┼────────────────────────┘
            │                                          │
┌───────────┼──────────────────────────────────────────┼────────────────────────┐
│  L2 — RISK & PRIORITISATION                          │                        │
│           │                                          │                        │
│  ┌────────▼─────────┐    ┌──────────────────┐        │                        │
│  │   Assessments     │───►│  Actions          │        │                        │
│  │                   │    │  (Action Tracker) │        │                        │
│  │  compliance       │    │                  │        │                        │
│  │  status per law   │    │  remediation     │        │                        │
│  │  risk scoring     │    │  tasks           │        │                        │
│  │  review cycle     │    │  kanban workflow │        │                        │
│  └──────────────────┘    └──────────────────┘        │                        │
│                                                       │                        │
└───────────────────────────────────────────────────────┼────────────────────────┘
                                                        │
┌───────────────────────────────────────────────────────┼────────────────────────┐
│  L4 — EVIDENCE                                        │                        │
│                                                       │                        │
│  ┌──────────────────┐                                 │                        │
│  │  Evidence Vault   │◄───────────────────────────────┘                        │
│  │                   │                                                         │
│  │  documents,       │  ◄── linked to Assessments + Actions + Controls         │
│  │  certificates,    │                                                         │
│  │  records          │                                                         │
│  └──────────────────┘                                                          │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│  L5 — ASSURANCE                                                                │
│                                                                                │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐          │
│  │  Audits           │    │  Training         │    │  Documents       │          │
│  │                   │    │  Tracker          │    │  Control         │          │
│  │  internal /       │    │                  │    │                  │          │
│  │  external         │    │  competency,     │    │  versioning,     │          │
│  │  ISO 19011        │    │  certificates,   │    │  review cycle    │          │
│  │                   │    │  expiry          │    │                  │          │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘          │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│  L6 — EVENTS & CHANGE INTELLIGENCE                                             │
│                                                                                │
│  ┌──────────────────┐                                                          │
│  │  Incidents        │  ◄── linked to Assessments + Actions                    │
│  │                   │                                                         │
│  │  non-conformances │                                                         │
│  │  near-misses      │                                                         │
│  │  investigations   │                                                         │
│  └──────────────────┘                                                          │
│                                                                                │
│  + Change Detection (backend, not in Baserow)                                  │
│  + External intelligence feeds (future)                                        │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│  CROSS-CUTTING                                                                 │
│                                                                                │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐          │
│  │  Personnel        │    │  RACI             │    │  Hierarchy       │          │
│  │                   │    │                  │    │                  │          │
│  │  people,          │    │  responsibility  │    │  Single table,   │          │
│  │  roles,           │    │  matrix          │    │  multi-hierarchy │          │
│  │  departments,     │    │  (Hohfeldian     │    │                  │          │
│  │  Baserow users    │    │   actor mapping) │    │  Adjacency list: │          │
│  └──────────────────┘    └──────────────────┘    │  Parent (self-   │          │
│                                                   │  referential)    │          │
│  ┌──────────────────┐                             │  Hierarchy: org  │          │
│  │  PDCA             │  ◄── linked to             │  / geo / finance │          │
│  │                   │    Assessments + Actions    │  Type: Division  │          │
│  │  Plan-Do-Check-   │                            │  / Site / etc    │          │
│  │  Act improvement  │                            └──────────────────┘          │
│  └──────────────────┘                                                          │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## Link Relationships

### Primary chain (the compliance spine)

```
Legal Register ──1:many──► Duties
      │                       │
      │  (law-level)          │ (provision-level)
      │                       │
      ▼                       ▼
  Control Mappings ◄──────────┘
  (wiring — two-tier)
      │
      │  many:1
      ▼
   Controls ──────► Evidence (proof of operation)
      │
      │  1:many
      ▼
   Actions (fix/improve/create controls)
      
Legal Register
      │
      │  1:1
      ▼
  Assessments (compliance judgement — are controls adequate?)
```

Control Mappings link to Legal Register (law-level, always populated) AND optionally to Duties (provision-level). Most mappings are law-level — provision-level for targeted controls.

Actions target Controls, not obligations directly. The compliance chain: Assessment identifies a gap → Action created to fix/improve/create a Control → Control change improves compliance.

### All link_row relationships

| From Table | Field | To Table | Cardinality | Purpose |
|-----------|-------|----------|-------------|---------|
| **Duties** | Parent Law | Legal Register | many:1 | Which law this provision belongs to |
| **Actor Tuples** | (linked to Duties) | Duties | many:many | Which actors bear this duty |
| **Control Mappings** | Law | Legal Register | many:1 | Law-level mapping (always populated) |
| **Control Mappings** | Obligation | Duties | many:1 | Provision-level mapping (empty for law-level) |
| **Control Mappings** | Control | Controls | many:1 | Which control addresses it |
| **Controls** | Owner | Personnel | many:1 | Who is accountable |
| **Controls** | Org_Unit | Hierarchy | many:1 | Organisational position (Division, Department) |
| **Controls** | Location | Hierarchy | many:1 | Geographic position (Site, Building) |
| **Assessments** | Law | Legal Register | 1:1 | Which law is being assessed |
| **Assessments** | Assessment_Owner | Personnel | many:1 | Accountable person |
| **Assessments** | Assessed_By | Personnel | many:1 | Who performed assessment |
| **Actions** | Assessment | Assessments | many:1 | Which gap this addresses |
| **Actions** | Control | Controls | many:1 | Which control to fix/improve/create |
| **Actions** | Assigned_To | Personnel | many:1 | Person responsible |
| **Evidence** | Assessment | Assessments | many:1 | Which assessment this supports |
| **Evidence** | Action | Actions | many:1 | Which action this completes |
| **Evidence** | Control | Controls | many:1 | Which control this proves operated |
| **Incidents** | Assessment | Assessments | many:1 | Related assessment |
| **Incidents** | Actions | Actions | many:1 | Corrective actions taken |
| **Audits** | Assessment | Assessments | many:1 | What was audited |
| **Audits** | Actions | Actions | many:1 | Findings actions |
| **Training** | Assigned_To | Personnel | many:1 | Who needs training |
| **Documents** | Related_Laws | Legal Register | many:many | Which laws this document supports |
| **Hierarchy** | Parent | Hierarchy (self) | many:1 | Parent node in the tree |
| **RACI** | Law/Provision | Legal Register or Duties | many:1 | What this RACI covers |
| **PDCA** | Assessment | Assessments | many:1 | Which gap drives this improvement |
| **PDCA** | Actions | Actions | many:1 | Linked actions |

---

## Tiering Model

Tables participate in a three-tier hierarchy:

```
T1  Corporate          ┌─────────────┐
    (group-wide)       │  Controls   │──── group-wide procedures
                       │  Mappings   │──── which corporate controls satisfy which obligations
                       └──────┬──────┘
                              │ inherits
T2  Jurisdiction       ┌──────▼──────┐
    (country laws)     │  Controls   │──── country-specific implementations
                       │  Mappings   │──── inherited + jurisdiction-specific
                       │  Legal Reg  │──── laws (L1 lives here)
                       │  Duties     │──── obligations from those laws
                       └──────┬──────┘
                              │ inherits
T3  Contract           ┌──────▼──────┐
    (customer)         │  Controls   │──── contract-specific measures
                       │  Mappings   │──── inherited + supplements + conflicts
                       └─────────────┘
```

Each tier's compliance register inherits from above. The work at each tier is to **supplement and spot conflicts**, not rebuild.

---

## Table Summary

| Layer | Table | Source | Primary Field | Rows (QQ) |
|-------|-------|--------|---------------|-----------|
| L1 | Legal Register | `mix sync.run` | Name (law identifier) | 274 |
| L1 | Duties | `mix sync.run` | Name (section_id) | 2,400 |
| L1 | Actor Tuples | `mix sync.run` | Name (composite key) | 485 |
| L2 | Assessments | `mix templates.apply` | Formula: `field('Law')` | 274 |
| L2 | Actions | `mix templates.apply` | Formula: `concat(Assessment, ' — ', Title)` | grows |
| L3 | Controls | `mix templates.apply` | Formula: `concat(Control_Type, ' — ', Title)` | 100–500 |
| L3 | Control Mappings | `mix templates.apply` | Formula: `concat(Obligation, ' ↔ ', Control)` | 500–2,000 |
| L4 | Evidence | `mix templates.apply` | Formula: `concat(Assessment, ' — ', Title)` | grows |
| L5 | Audits | `mix templates.apply` | TBD | grows |
| L5 | Training | `mix templates.apply` | TBD | grows |
| L5 | Documents | `mix templates.apply` | TBD | grows |
| L6 | Incidents | `mix templates.apply` | TBD | grows |
| — | Personnel | `mix templates.apply` | Formula: `concat(Name, ' — ', Employee_ID)` | 10–50 |
| — | Hierarchy | `mix templates.apply` | Formula: `concat(Type, ': ', Name)` | 20–200 |
| — | RACI | `mix templates.apply` | TBD | varies |
| — | PDCA | `mix templates.apply` | TBD | grows |

---

## AI-Assisted Population

| Table | AI Role | How |
|-------|---------|-----|
| Legal Register | Fully automated | Synced from sertantai DB via fractalaw pipeline |
| Duties | Fully automated | Synced — significance-filtered, governed-only |
| Actor Tuples | Fully automated | Synced — normalised from provision actors |
| Controls | **AI-suggested, human-confirmed** | Given obligation text + org context, suggest controls |
| Control Mappings | **AI-suggested, human-confirmed** | Given controls + obligations, suggest wiring + flag gaps |
| Assessments | Seeded (Not Assessed) | Pre-populated with one row per law, human assesses |
| Actions | Human-created | Created when assessments identify gaps |
| Evidence | Human-uploaded | Documents/records proving compliance |

The L3 layer is where AI adds the most value — inferring from obligation text what kind of control an organisation would typically implement, and mapping existing controls to obligations. The human's job is to confirm, supplement, and spot what the AI missed.

---

## Related Docs

- [`COMPLIANCE-7-LAYERS.md`](COMPLIANCE-7-LAYERS.md) — the architecture definition
- [`BASEROW-7-LAYERS.md`](BASEROW-7-LAYERS.md) — layer status mapping
- [`BASEROW-CONTROLS-DESIGN.md`](BASEROW-CONTROLS-DESIGN.md) — L3 detailed design (ontology, tiering, inheritance)
- [`BASEROW-TEMPLATES.md`](BASEROW-TEMPLATES.md) — template modules and sub-patterns
- [`BASEROW-CONFIG-RECIPES.md`](BASEROW-CONFIG-RECIPES.md) — manual Baserow UI configuration
- [`SIGNIFICANCE-SCOPING-GUIDE.md`](SIGNIFICANCE-SCOPING-GUIDE.md) — L2 significance data usage
