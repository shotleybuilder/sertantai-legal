# Baserow Compliance Templates

12 templates that build a compliance workspace on top of the base data (Legal Register, Duties, Actor Tuples). Templates are provider-agnostic — defined using universal field types and adapted per-provider by the adapter layer.

---

## Template Dependency Graph

```
Foundation (LRT/LAT)          Personnel          Org Structure
    │                             │
    ├── Document Control          │
    ├── RACI                      │
    ├── Training Tracker          │
    │                             │
    └── Compliance Assessment ────┘
            │
            ├── Action Tracker
            │       │
            │       ├── Audit Management
            │       └── Incident Register
            │
            ├── Evidence Vault
            │
            └── PDCA
```

Templates are applied in dependency order (topological sort). You can apply any subset — the system resolves and validates dependencies automatically.

---

## Template Summary

| # | Template | Table(s) | Depends On | Purpose |
|---|----------|----------|------------|---------|
| 1 | **Foundation** | LRT, LAT | — | Declares base data tables (not created by template — synced by `mix sync.run`) |
| 2 | **Personnel** | Personnel | — | People directory: names, roles, departments, Baserow user links |
| 3 | **Org Structure** | Sites, Divisions | — | Physical locations and business units (conditional on sub-pattern) |
| 4 | **Compliance Assessment** | Assessments | Foundation, Personnel | Per-law or per-provision compliance status, risk scoring, review scheduling |
| 5 | **Action Tracker** | Actions | Compliance Assessment | Remediation tasks with owners, deadlines, priorities, kanban workflow |
| 6 | **Evidence Vault** | Evidence | Compliance Assessment | Documents, certificates, records proving compliance |
| 7 | **Incident Register** | Incidents | Compliance Assessment, Action Tracker | Non-conformances, near-misses, investigations |
| 8 | **Audit Management** | Audits | Compliance Assessment, Action Tracker | Internal/external audit scheduling and tracking (ISO 19011) |
| 9 | **Training Tracker** | Training | Foundation | Competency requirements, completion tracking, certificate expiry |
| 10 | **Document Control** | Documents | Foundation | Controlled documents with versioning and review calendar |
| 11 | **RACI** | RACI | Foundation | Responsibility matrix mapping Hohfeldian actors to customer roles |
| 12 | **PDCA** | Improvements | Compliance Assessment, Action Tracker | Plan-Do-Check-Act improvement cycle tracking |

---

## Template Details

### 1. Foundation

**Tables**: LRT (Legal Register), LAT (Duties)
**Not created by the template** — these are synced by `mix sync.run` from the sertantai database. The Foundation template declares them so other templates can reference them via link_row fields.

### 2. Personnel

**Table**: Personnel
**Primary field**: Employee_ID (unique reference)
**Fields**: Name, Email, Role (single select), Department (single select), Active (boolean), Baserow User (collaborator)
**Views**: All Personnel, Active, By Role, By Department

Adapts based on `people` sub-pattern — table only created for `:linked` and `:hybrid` modes.

**Detail doc**: [`BASEROW-PERSONNEL-PATTERNS.md`](BASEROW-PERSONNEL-PATTERNS.md)

### 3. Org Structure

**Tables**: Sites, Divisions (conditional)
**Controlled by** `org_structure` sub-pattern:
- `:flat` / `:department` — not applied (no tables created)
- `:site` — Sites table only
- `:division_site` — Divisions + Sites with hierarchy

### 4. Compliance Assessment

**Table**: Assessments
**Core fields**: Law (link → LRT), Compliance_Status, Family (lookup), Law_Status (lookup), Gap_Description, Notes, Reference
**Adapts on 4 dimensions**: people, risk_scoring, review_cycle, assessment_grain
**Views**: All Assessments, Non-Compliant, Overdue Reviews, By Family, Compliance Board (kanban), Review Calendar
**Cross-table**: Adds Assessment_Count rollup to Legal Register
**Webhook**: Fires on row update (drives ComplianceMetrics)

**Detail doc**: [`BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md`](BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md)

### 5. Action Tracker

**Table**: Actions
**Fields**: Title, Assessment (link → Assessments), Law (lookup), Status (Open/In Progress/Completed/Cancelled), Priority (Critical/High/Medium/Low), Action_Type (Corrective/Preventative/Improvement/Maintenance), Assigned_To, Due_Date, Completed_Date, Notes, Days_Until_Due (formula), Overdue (formula)
**Views**: All Actions, Overdue, Action Board (kanban by Status), Timeline (calendar by Due_Date), By Priority, By Type
**Cross-table**: Adds Open_Actions rollup to Assessments
**Webhook**: Fires on create/update

### 6. Evidence Vault

**Table**: Evidence
**Fields**: Title, Type (Policy/Procedure/Certificate/etc.), Assessment (link), Action (link), Version, Expiry_Date, Status (Current/Expired/Superseded), Notes
**Adapts on**: `storage_mode` (`:embedded` = file upload, `:reference` = URL + location), `people`
**Views**: All Evidence, Expiring Soon, By Type, Gallery
**Cross-table**: Adds Evidence_Count rollup to Assessments

### 7. Incident Register

**Table**: Incidents
**Fields**: Title, Description, Severity (Critical/Major/Minor/Near Miss), Status (Open/Investigating/Closed), Date_Occurred, Assessment (link), Actions (link), Root_Cause, Reported_By
**Views**: All Incidents, Open, By Severity, Investigation Board (kanban), Report Form
**Webhook**: Fires on create/update

### 8. Audit Management

**Table**: Audits
**Fields**: Title, Type (Internal/External/Regulatory), Assessment (link), Actions (link), Audit_Date, Auditor, Status, Findings, Next_Audit_Date
**Adapts on**: `storage_mode` (report as file or URL), `people`
**Views**: All Audits, Audit Calendar, By Type, By Status

### 9. Training Tracker

**Table**: Training
**Fields**: Name, Course, Frequency (Annual/Biennial/One-off), Last_Completed, Next_Due, Status (Current/Due/Overdue/Not Started), Assigned_To
**Adapts on**: `storage_mode` (certificate as file or URL), `people`
**Views**: All Training, Due/Overdue, Training Calendar, By Status (kanban)
**Formula**: Days until due, status derived from date comparison

### 10. Document Control

**Table**: Documents
**Fields**: Title, Type, Version, Related_Laws (link → LRT), Owner, Status (Draft/Under Review/Approved/Superseded/Withdrawn), Review_Date, Next_Review
**Adapts on**: `storage_mode` (file or URL), `people`
**Views**: All Documents, Due for Review, By Type, By Status

### 11. RACI

**Table**: RACI
**Fields**: Law or Provision (link → LRT or LAT based on grain), Responsible, Accountable, Consulted, Informed
**Maps Hohfeldian actor positions**: active → Responsible, counterparty/beneficiary → Informed
**Adapts on**: `assessment_grain` (law or provision level)

### 12. PDCA

**Table**: Improvements
**Fields**: Title, Phase (Plan/Do/Check/Act), Assessment (link), Actions (link), Owner, Start_Date, Target_Date, Status, Outcome
**Views**: All Improvements, PDCA Board (kanban by Phase), By Status, Timeline

---

## Sub-Pattern Dimensions

| Dimension | Values | Affects Templates |
|-----------|--------|-------------------|
| `people` | flat, linked, workspace_member, hybrid | Personnel, Assessment, Action Tracker, Evidence, Incident, Audit, Training, Document Control, PDCA |
| `risk_scoring` | simple, matrix | Assessment |
| `review_cycle` | manual, scheduled | Assessment |
| `assessment_grain` | law, provision | Assessment, RACI |
| `storage_mode` | embedded, reference | Evidence, Audit, Training, Document Control |
| `org_structure` | flat, department, site, division_site | Org Structure |
| `improvement` | none, pdca | PDCA (conditional) |
| `reporting` | standard, dashboard | (future) |
| `data_collection` | grid_only, forms | (future) |

---

## CLI

```bash
# List available templates
mix templates.apply --list

# Apply Personnel + Compliance Assessment
mix templates.apply --templates personnel,compliance_assessment --people linked --risk matrix --review scheduled --grain law

# Check what's applied
mix templates.status

# Sync base data (separate from templates)
mix sync.run --clean --direct
```

---

## Row Budget

| Component | Typical Rows |
|-----------|-------------|
| Legal Register (LRT) | 200–400 |
| Duties (LAT) | 1,000–3,000 |
| Actor Tuples | 200–500 |
| Personnel | 10–50 |
| Assessments (law grain) | 200–400 |
| Assessments (provision grain) | 1,000–3,000 |
| Actions | grows over time |
| Evidence | grows over time |
| Other templates | 10–100 each |

Baserow 50K row limit accommodates all templates comfortably for a single customer.

---

## Related Docs

- [`BASEROW-PERSONNEL-PATTERNS.md`](BASEROW-PERSONNEL-PATTERNS.md) — Personnel table people mode options
- [`BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md`](BASEROW-COMPLIANCE-ASSESSMENT-PATTERNS.md) — Assessment sub-pattern options
- [`BASEROW-CONFIG-RECIPES.md`](BASEROW-CONFIG-RECIPES.md) — Manual Baserow UI configuration (views, colours, rollups)
- [`SIGNIFICANCE-SCOPING-GUIDE.md`](SIGNIFICANCE-SCOPING-GUIDE.md) — Using significance to curate the Duties table
