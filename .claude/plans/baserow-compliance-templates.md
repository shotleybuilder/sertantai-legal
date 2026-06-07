# Baserow Compliance Templates — Plan

**Status**: DRAFT — Round 3 reviewed (Gemini 2.5 Flash, 2026-06-07), provider-agnostic architecture
**Meta-plan**: Phase 5 (Baserow sync) extension

## Problem

SertantAI syncs two tables into a customer's Baserow workspace: LRT (Legal Register) and LAT (Legal Articles/Provisions). These are the raw data foundation — laws and their duty provisions. But a customer managing compliance needs more than a list of laws. They need:

- **Compliance assessments** — "does this law apply to us? what's our compliance status?"
- **Action tracking** — "what do we need to do? who's responsible? when?"
- **Evidence management** — "how do we prove compliance?"
- **Risk scoring** — "which gaps are highest risk?"
- **Review scheduling** — "when was this last reviewed? when's the next review?"
- **Reporting** — "how compliant are we overall? what's overdue?"

Currently, the customer builds all of this manually in Baserow. SertantAI could bootstrap it — creating a structured compliance workspace with linked tables, views, formulas, and rollups that turn raw legal data into a working compliance management system.

## What Baserow Can Do (API)

| Capability | API? | Notes |
|-----------|:---:|-------|
| Create tables | Yes | `POST /api/database/tables/{database_id}/` |
| Create fields (all types) | Yes | link_row, lookup, rollup, formula, single/multi-select, file, date |
| Create views | Yes | Grid, kanban, calendar, form, gallery, timeline |
| Create view filters/sorts | Yes | Per-view filter rules |
| Create webhooks | Yes | Row created/updated/deleted triggers |
| Batch create/update rows | Yes | 200/batch with `?user_field_names=true` |
| Create automations | **No** | UI-only. Use webhooks + external logic instead |
| Conditional formatting | **No** | UI-only (row coloring) |
| Permissions (RBAC) | Advanced plan | Field-level, view-level (row security) |

**Key constraint**: Automations (email reminders, status-change triggers) can't be created via API. For automated workflows, we use webhooks → sertantai backend.

## Template Concept

A **template** is a set of tables, fields, views, and seed data that SertantAI creates programmatically in a customer's Baserow workspace via the API. Each template has:

- **Table definitions** — columns, types, options, linked relationships
- **View definitions** — filtered/sorted views for specific workflows
- **Formula fields** — computed columns (risk scores, days-until-due, compliance %)
- **Webhook registrations** — notify sertantai on customer changes

Templates are not Baserow's native template feature (which is snapshot-based and not API-accessible). They're code — Elixir modules that call the Baserow API to construct the workspace.

### Template palette

| Template | Purpose | Tables added | Builds on |
|----------|---------|-------------|-----------|
| **Foundation** | Legal register + provisions (existing) | LRT, LAT | — |
| **Personnel** | People, roles, departments | Personnel | — |
| **Compliance Assessment** | Per-law compliance status + gap analysis | Assessments | Foundation, Personnel |
| **Action Tracker** | Remediation tasks with owners and deadlines | Actions | Assessments |
| **Evidence Vault** | Attach documents proving compliance | Evidence | Assessments |
| **Risk Matrix** | Likelihood × impact scoring per gap | — (fields on Assessments) | Assessments |
| **Review Calendar** | Scheduled periodic reviews | — (fields + views on Assessments) | Assessments |
| **Incident Register** | Non-conformances, near misses, deviations | Incidents | Assessments, Personnel |
| **Audit Management** | Plan, conduct, track internal/external audits | Audits | Assessments, Personnel |
| **Training Tracker** | Mandatory training by law/provision | Training | Foundation, Personnel |
| **Document Control** | Governing documents (policies, procedures) | Documents | — |
| **RACI** | Responsibility matrix per law/provision | RACI | Foundation, Personnel |

Templates are **composable** — a customer picks which they want. Each template checks for prerequisites (e.g., Action Tracker requires Assessments table).

### Deployment patterns

Templates come in two flavours based on how the customer stores artifacts:

| Pattern | Artifact storage | Evidence/Document fields | Suits |
|---------|-----------------|------------------------|-------|
| **Embedded** | Files stored directly in Baserow | `file` fields | Smaller orgs, no existing DMS |
| **Reference** | Pointers to external systems (SharePoint, Confluence, Google Drive) | `url` + `text` fields (link + title) | Enterprise orgs with established document management |

Template modules accept a `storage_mode` parameter (`:embedded` or `:reference`) that controls whether artifact fields are file uploads or URL references. Same table structures, different field types.

### Sub-patterns (mix and match)

Rather than one-size-fits-all archetypes, each template dimension offers **sub-patterns** the customer selects independently. The workspace is assembled from choices across dimensions, not from a fixed bundle.

| Dimension | Sub-patterns | What varies |
|-----------|-------------|-------------|
| **Artifact storage** | Embedded (files in Baserow) / Reference (URLs to SharePoint/DMS) | File fields vs URL+text fields |
| **Risk scoring** | Simple (single Risk Level select) / Matrix (Likelihood × Impact formula) | Fields on Assessments |
| **People** | Flat (text fields) / Linked (Personnel table with link_row) | All "assigned to" / "assessed by" fields |
| **Org structure** | Flat / Department / Site / Division-Site | How work is scoped and filtered (see below) |
| **Assessment grain** | Law-level / Provision-level | One Assessment per law vs one per provision |
| **Review cycle** | Manual / Scheduled (frequency + auto-calculated due dates) | Fields + formula fields on Assessments |
| **Reporting** | Standard views / Management dashboard (read-only rollup views) | Additional views + rollup formulas |
| **Data collection** | Grid-only / Forms (self-assessment form views for operational staff) | Form views on Assessments, Incidents, Evidence |
| **Improvement** | None / PDCA tracker (Plan-Do-Check-Act cycle table) | Additional Improvement Initiatives table |

A customer building their workspace might choose: Reference storage + Matrix risk + Linked people + Site-based org + Provision-level assessment + Scheduled reviews + Dashboard reporting + Forms. Each choice is independent.

### Org structure sub-patterns

How the customer's organisation maps onto the compliance workspace. This affects how assessments, actions, and responsibilities are scoped and filtered.

| Pattern | Tables/fields added | Suits |
|---------|-------------------|-------|
| **Flat** | No org structure tables. Personnel has Role + Department fields only. | Single-site SMEs |
| **Department** | Department field on Personnel (single_select). Views grouped/filtered by department. | Single-site, departmental structure |
| **Site** | New `Sites` table (Name, Address, Region). Personnel links to Site. Assessments can be scoped per site. | Multi-site orgs, same jurisdiction |
| **Division-Site** | New `Divisions` table + `Sites` table. Division → Sites hierarchy. Personnel links to Division + Site. Assessments and Actions inherit site/division scope. | Large enterprises, matrix orgs |

The org structure pattern determines:
- How Personnel are grouped (by department, site, division)
- How Assessments are filtered (all-org vs per-site vs per-division)
- How Actions are assigned (within a site team vs cross-org)
- How dashboards aggregate (site-level compliance % vs org-wide)
- How RACI responsibilities map (different sites may have different responsible persons for the same law)


### Authentication

Baserow supports SSO via Active Directory / Okta (Enterprise plan) or SAML. We assume the customer has provisioned their Baserow users via their IdP. The Personnel table links to these provisioned users — SertantAI doesn't manage user accounts.

### Naming convention

All SertantAI-managed tables and fields are prefixed with `SA_` (e.g., `SA_Assessments`, `SA_Compliance_Status`). Customers create their own fields/tables without the prefix. This clearly delineates managed vs custom and prevents conflicts during sync or template upgrades.

## Template 1: Foundation (existing)

Already built. Two tables synced by `Engine.run`:

### LRT table (Legal Register)
The customer's applicable laws. Fields by tier (essential → standard → full).

Key fields: Title, Family, Year, Status, Geographic Extent, Duty Holder, Rights Holder, Power Holder, Function, Fitness dimensions, URL.

### LAT table (Legal Articles)
Provision-level duty text. Linked to LRT via Parent Law field.

Key fields: Type (Duty/Right/Power), Regulated Actors, Provision Text, Provision citation, Duty Type.

## Template 1b: Personnel

Foundational table for people, roles, and departments. Required by most other templates — all "Assigned To", "Assessed By", "Responsible" fields link here instead of using free text.

### Table: Personnel

| Field | Type | Purpose |
|-------|------|---------|
| Name | text | Full name |
| Email | email | For Baserow user linkage |
| Role | single_select | Compliance Manager / Safety Officer / Legal Counsel / Line Manager / Engineer / Operative / Contractor / Other |
| Department | single_select | Customer-defined departments |
| Employee ID | text | Internal reference |
| Active | boolean | Currently employed/active |

### Why this matters

Without Personnel, all people references are free text — "John Doe" vs "J. Doe" vs "john.doe@company.com" makes filtering, grouping, and reporting on responsibilities impossible. Every template that tracks who-did-what links here.

## Template 2: Compliance Assessment

The core compliance workflow table. One row per law in the register (or per provision for granular assessment).

### Table: Assessments

| Field | Type | Purpose |
|-------|------|---------|
| Law | link_row → LRT | Which law is being assessed |
| Provision | link_row → LAT | Optional: provision-level assessment |
| Compliance Status | single_select | Compliant / Partially Compliant / Non-Compliant / Not Assessed / Not Applicable |
| Assessment Owner | link_row → Personnel | Who is accountable for this assessment |
| Assessed By | link_row → Personnel | Who performed the assessment |
| Assessment Date | date | When this was last assessed |
| Review Frequency | single_select | Quarterly / Bi-annually / Annually / Biennial |
| Next Review Date | date | When to reassess |
| Gap Description | long_text | What's missing or non-compliant |
| Notes | long_text | General notes |
| Reference | text | Internal ID or cross-reference |
| Risk Level | single_select | Critical / High / Medium / Low |
| Likelihood | single_select | Almost Certain / Likely / Possible / Unlikely / Rare |
| Impact | single_select | Catastrophic / Major / Moderate / Minor / Insignificant |
| Risk Score | formula | `IF(Likelihood, lookup score) * IF(Impact, lookup score)` |
| Days Until Review | formula | `DATE_DIFF('day', TODAY(), field('Next Review Date'))` |
| Review Overdue | formula | `IF(field('Days Until Review') < 0, 'OVERDUE', IF(field('Days Until Review') < 30, 'Due Soon', 'OK'))` |
| Family (lookup) | lookup | Family from linked LRT row |
| Status (lookup) | lookup | Law status from linked LRT row |

### Views

| View | Type | Filter/Sort | Purpose |
|------|------|-------------|---------|
| All Assessments | grid | Sort by Family, then Law | Master view |
| Non-Compliant | grid | Compliance Status = Non-Compliant or Partially Compliant | Gap analysis |
| Overdue Reviews | grid | Review Overdue = OVERDUE | Governance dashboard |
| By Family | grid | Grouped by Family lookup | Family-level overview |
| Review Calendar | calendar | Date = Next Review Date | Scheduling |
| Compliance Board | kanban | Stack by Compliance Status | Visual workflow |

### Rollups on LRT table (added by this template)

| Field | Type | Purpose |
|-------|------|---------|
| Assessment Count | rollup (count) | How many assessments linked to this law |
| Compliance % | formula on rollup | % of linked assessments that are "Compliant" |

### Seed logic

When the template is applied, create one Assessment row per law in the register (linked to LRT). Set Compliance Status = "Not Assessed", Next Review Date = 90 days from now.

## Template 3: Action Tracker

Remediation and improvement tasks linked to assessments.

### Table: Actions

| Field | Type | Purpose |
|-------|------|---------|
| Title | text | Action description |
| Assessment | link_row → Assessments | Which gap this action addresses |
| Law (lookup) | lookup | Law from linked Assessment |
| Status | single_select | Open / In Progress / Completed / Cancelled |
| Priority | single_select | Critical / High / Medium / Low |
| Action Type | single_select | Corrective / Preventative / Improvement / Maintenance |
| Assigned To | link_row → Personnel | Person responsible |
| Due Date | date | Deadline |
| Completed Date | date | When completed |
| Evidence | link_row → Evidence | Linked evidence items |
| Notes | long_text | Progress notes |
| Days Until Due | formula | `DATE_DIFF('day', TODAY(), field('Due Date'))` |
| Overdue | formula | `IF(AND(field('Status') != 'Completed', field('Days Until Due') < 0), 'OVERDUE', '')` |

### Views

| View | Type | Purpose |
|------|------|---------|
| All Actions | grid | Master view |
| My Actions | grid | Filter by Assigned To (manual filter) |
| Overdue | grid | Overdue = OVERDUE |
| Action Board | kanban | Stack by Status |
| Timeline | calendar | Date = Due Date |

### Rollups on Assessments (added by this template)

| Field | Type | Purpose |
|-------|------|---------|
| Open Actions | rollup (count where Status != Completed) | Outstanding tasks per gap |

## Template 4: Evidence Vault

Documents, certificates, and records proving compliance.

### Table: Evidence

| Field | Type | Purpose |
|-------|------|---------|
| Title | text | Evidence description |
| File | file | Uploaded document (PDF, image, etc.) |
| Type | single_select | Policy / Procedure / Certificate / Training Record / Inspection Report / Risk Assessment / Other |
| Assessment | link_row → Assessments | Which assessment this supports |
| Action | link_row → Actions | Which action this completes |
| Upload Date | date | When uploaded |
| Uploaded By | link_row → Personnel | Who uploaded |
| Version | text | Document version number |
| Expiry Date | date | When this evidence expires (e.g., certificate renewal) |
| Status | single_select | Current / Expired / Superseded |
| Notes | long_text | Context |

### Views

| View | Type | Purpose |
|------|------|---------|
| All Evidence | grid | Master view |
| Expiring Soon | grid | Expiry Date within 30 days |
| By Type | grid | Grouped by Type |
| Gallery | gallery | Card view with file preview |

## Template 5: RACI (future)

Responsibility matrix per law or provision. Maps actors from the structured `actors` column to organisational roles.

| Field | Type | Purpose |
|-------|------|---------|
| Provision | link_row → LAT | Which provision |
| Actor (from law) | lookup | Active actor label from provision |
| Responsible | link_row → Personnel | Org role/person who does the work |
| Accountable | link_row → Personnel | Org role/person who owns the outcome |
| Consulted | link_row → Personnel | Who provides input |
| Informed | link_row → Personnel | Who is kept informed |

This template maps fractalaw's Hohfeldian positions to the customer's RACI:
- `active` → Responsible/Accountable (they bear the duty)
- `counterparty` → Informed (they hold the claim)
- `beneficiary` → Informed (they benefit)

## Template 6: Incident Register

Non-conformances, near misses, and deviations. Critical for ISO 14001/45001.

### Table: Incidents

| Field | Type | Purpose |
|-------|------|---------|
| Title | text | Incident description |
| Date | date | When it occurred |
| Severity | single_select | Critical / Major / Minor / Near Miss |
| Description | long_text | Full details |
| Root Cause | long_text | Investigation findings |
| Assessment | link_row → Assessments | Related compliance gap |
| Corrective Action | link_row → Actions | Corrective action taken |
| Preventative Action | link_row → Actions | Preventative action to avoid recurrence |
| Reported By | link_row → Personnel | Who reported |
| Status | single_select | Open / Investigating / Closed |

## Template 7: Audit Management

Plan, conduct, and track internal/external audits. Informed by ISO 19011.

### Table: Audits

| Field | Type | Purpose |
|-------|------|---------|
| Audit Name | text | Title/scope |
| Type | single_select | Internal / External / Regulatory |
| Auditor | link_row → Personnel | Who conducted |
| Audit Date | date | When conducted |
| Scope | long_text | What was audited |
| Findings | long_text | Summary of findings |
| Related Actions | link_row → Actions | Actions raised from audit |
| Report | file | Audit report document |
| Conclusion | single_select | Conforming / Minor Non-Conformance / Major Non-Conformance / Observation |
| Next Audit Date | date | Scheduled follow-up |

## Template 8: Training Tracker

Mandatory training linked to specific laws or provisions.

### Table: Training

| Field | Type | Purpose |
|-------|------|---------|
| Course Name | text | Training title |
| Required By | link_row → LRT | Which law requires this |
| Provision | link_row → LAT | Specific provision reference |
| Frequency | single_select | One-off / Annual / Biennial / On Change |
| Assigned To | link_row → Personnel | Who needs this training |
| Completed Date | date | When last completed |
| Next Due | date | When renewal due |
| Certificate | file | Completion certificate |
| Status | single_select | Current / Due / Overdue / Not Started |
| Days Until Due | formula | `DATE_DIFF('day', TODAY(), field('Next Due'))` |

## Template 9: Document Control

Governing documents (policies, procedures, work instructions). Distinct from Evidence — these are the org's own documents that demonstrate their compliance system.

### Table: Documents

| Field | Type | Purpose |
|-------|------|---------|
| Document Title | text | Name |
| Type | single_select | Policy / Procedure / Work Instruction / Form / Register / Other |
| Version | text | Current version |
| Owner | link_row → Personnel | Document owner |
| Approval Date | date | When approved |
| Review Date | date | When next review due |
| Status | single_select | Approved / Draft / Under Review / Obsolete |
| File | file | The document |
| Related Laws | link_row → LRT | Laws this document addresses |
| Notes | long_text | Context |

## Compliance frameworks informing design

Templates draw from common elements across:
- **ISO 14001** (Environmental Management) — assessments, aspects & impacts, operational control
- **ISO 45001** (OH&S Management) — hazard ID, risk assessment, incident investigation
- **ISO 27001** (Information Security) — risk treatment, access control, incident management
- **ISO 31000** (Risk Management) — risk identification, analysis, evaluation, treatment
- **ISO 19011** (Audit Guidelines) — audit program management, conducting audits

The template design prioritises elements common across all five frameworks.

## Data Security

*Reviewed by Gemini 2.5 Flash (Round 2, 2026-06-07)*

### Data boundary: what SertantAI sees vs what stays in the customer's workspace

| SertantAI sees | SertantAI NEVER sees |
|---------------|---------------------|
| Provider row/table/database IDs | Gap descriptions, notes, free-text fields |
| Status field values (Compliant/Non-Compliant) | Evidence files, audit reports, training certificates |
| Aggregate counts (laws assessed, actions overdue) | Personnel PII (names, emails, employee IDs) |
| Dates (review due, action due) | Incident details, root cause analysis |
| Link IDs (which assessment links to which law) | Document content |

**Principle**: SertantAI is the orchestrator and analytics layer, not the custodian of sensitive compliance records. The customer's compliance data lives in their chosen provider (Baserow, Airtable, etc.) — SertantAI receives only minimal webhook payloads (row ID + changed field value).

### Webhook security

- HTTPS/TLS 1.2+ for all webhook traffic
- Baserow webhook signature verification on sertantai endpoint
- Minimal payloads: row ID + specific changed field, never full row data
- Dedicated webhook endpoints per data type

### Data residency

- UK customer data must stay in UK — Baserow instance and SertantAI webhook processing must both be UK-hosted
- Regional deployment strategy: sertantai backend has UK endpoint for UK customers
- Data flow documented: Baserow UK → SertantAI UK endpoint → SertantAI UK processing

### Customer churn

The Baserow-centric model makes churn clean:
1. Customer retains their Baserow workspace and all compliance data (it's theirs)
2. SertantAI stops syncing, deregisters webhooks
3. SertantAI purges all SyncConfiguration, SyncRowMapping, and aggregate metrics for the customer
4. SertantAI's own audit logs retained per retention policy (contain no customer compliance data)

### Encryption

- **In transit**: HTTPS/TLS 1.2+ mandatory for all API calls and webhooks
- **At rest**: Baserow encrypts customer data on their infrastructure. SertantAI encrypts credentials (AES-256-CBC, per-record IV) and its own metadata

### Audit logs

Baserow's Advanced plan audit logs are a **component**, not the complete solution. Customers must combine:
1. Baserow's workspace-level audit logs (who changed what in Baserow)
2. SertantAI's own logs (when it synced, what templates were applied, what webhooks were processed)
3. Their other systems' logs (DMS access, training systems, etc.)

SertantAI guides customers on coverage gaps but doesn't claim Baserow's logs alone satisfy regulatory requirements.

### Same workspace, not separate workspaces

Customer-owned tables and SertantAI-managed tables live in the **same workspace/database** (with `SA_` prefix delineation). Separate databases would break cross-table linking (the core value proposition). Where the provider supports it (Baserow Advanced, Airtable Pro), field-level permissions protect SertantAI-owned fields from customer edits.

## Architecture

### Three-layer design

Templates are **provider-agnostic**. Baserow is the first supported provider but not the only one — customers may use Airtable, NocoDB, Monday.com, Notion, or others.

```
Template Definition (universal schema)
    ↓
Provider Adapter (translates to API)
    ↓
Provider API (Baserow, Airtable, NocoDB, ...)
```

### Layer 1: Template definitions

Each template is an Elixir module under `SertantaiLegal.Sync.Templates` that defines abstract schemas using universal field types:

```elixir
defmodule SertantaiLegal.Sync.Templates.ComplianceAssessment do
  @behaviour SertantaiLegal.Sync.TemplateBehaviour

  def name, do: "Compliance Assessment"
  def requires, do: [:foundation, :personnel]
  def tables, do: [:assessments]

  def field_specs(sub_patterns) do
    # Returns universal field definitions, adapted by sub-pattern choices
    [
      %{name: "SA_Law", type: :link_row, target: :lrt},
      %{name: "SA_Compliance_Status", type: :single_select,
        options: ["Compliant", "Partially Compliant", "Non-Compliant", "Not Assessed", "Not Applicable"]},
      %{name: "SA_Assessment_Owner", type: :link_row, target: :personnel},
      %{name: "SA_Next_Review_Date", type: :date},
      %{name: "SA_Days_Until_Review", type: :formula,
        expression: "date_diff('day', today(), field('SA_Next_Review_Date'))"},
      # ... conditional on sub_patterns.risk_scoring
    ] ++ risk_fields(sub_patterns.risk_scoring)
  end

  def view_specs(sub_patterns), do: [...]
  def rollup_specs, do: [...]       # fields added to OTHER tables
  def seed(context), do: ...         # create initial rows
end
```

**Universal field types**: `:text`, `:long_text`, `:number`, `:date`, `:boolean`, `:single_select`, `:multi_select`, `:link_row`, `:lookup`, `:rollup`, `:formula`, `:file`, `:url`, `:email`

**Sub-patterns** are passed as a config map — the template adapts its field specs, views, and seed logic based on the customer's choices.

### Layer 2: Provider adapters

Each provider adapter implements `SertantaiLegal.Sync.ProviderBehaviour` (extended beyond current row CRUD):

```elixir
defmodule SertantaiLegal.Sync.ProviderBehaviour do
  # Existing (row operations)
  @callback batch_create(config, table_key, rows) :: {:ok, mappings} | {:error, reason}
  @callback batch_update(config, table_key, rows) :: {:ok, count} | {:error, reason}
  @callback batch_delete(config, table_key, ids) :: {:ok, count} | {:error, reason}

  # Schema operations (new)
  @callback create_table(config, name) :: {:ok, table_id} | {:error, reason}
  @callback create_field(config, table_id, field_spec) :: {:ok, field_id} | {:error, reason}
  @callback create_view(config, table_id, view_spec) :: {:ok, view_id} | {:error, reason}
  @callback create_webhook(config, table_id, webhook_spec) :: {:ok, webhook_id} | {:error, reason}

  # Existing
  @callback list_fields(config, table_key) :: {:ok, fields} | {:error, reason}
  @callback ensure_fields(config, table_key, field_specs) :: :ok | {:error, reason}
  @callback test_connection(config) :: {:ok, info} | {:error, reason}
end
```

The **Baserow adapter** (`Providers.Baserow`) translates universal types:
- `:text` → `"text"` / `:long_text` → `"long_text"`
- `:single_select` → `"single_select"` with `select_options`
- `:link_row` → `"link_row"` with `linked_table_id`
- `:formula` → `"formula"` with `formula` expression (Baserow formula syntax)
- `:file` → `"file"` / `:url` → `"url"` (switched by storage_mode sub-pattern)

Future adapters (Airtable, NocoDB) implement the same callbacks with their own type mappings and API calls.

### Provider capability matrix

Each adapter declares what it supports via a `capabilities/0` callback:

```elixir
def capabilities do
  %{
    view_types: [:grid, :kanban, :calendar, :form, :gallery],
    field_level_permissions: true,
    webhooks: true,
    webhook_includes_old_values: false,
    webhook_includes_user_id: false,
    batch_size: 200
  }
end
```

The `TemplateApplicator` checks capabilities before creating views or features. If a provider doesn't support a required feature, it fails with a clear error. If it's optional (e.g., timeline view), it skips and logs a warning. Grid view is always the fallback.

### Formula strategy

Formulas are the hardest to abstract — every provider has different syntax. Strategy:

1. **Start with provider-specific formula strings** (get Baserow templates shipping)
2. **Formalise `field('SA_Field_Name')` referencing** as a minimal internal convention
3. **Incrementally build compilers** for core universal functions (`DATE_DIFF`, `TODAY`, `IF`, `AND`, basic arithmetic) as new providers are added
4. **Accept provider-specific strings for complex/unique formulas** stored as `%{baserow: "...", airtable: "..."}`

No full formula DSL upfront — evolve towards one pragmatically.

### Webhook common event struct

Each provider's webhook payload is normalised to:

```elixir
%{
  event_id: "...",
  provider: :baserow,
  table_id: "...",
  row_id: "...",
  event_type: :row_updated,     # :row_created | :row_updated | :row_deleted
  changed_fields: %{"SA_Compliance_Status" => "Non-Compliant"},
  old_values: nil,               # not available from all providers
  user_id: nil,                  # not available from all providers
  timestamp: ~U[2026-06-07 12:00:00Z]
}
```

Known gaps: Baserow webhooks don't include old values or user IDs. SertantAI handles these as optional — if critical for audit trails, a polling reconciliation fills the gaps.

### What NOT to abstract

- **Native automations** — stay with webhooks + sertantai backend (Baserow doesn't support API automation creation, others may)
- **Provider-specific UI features** — Airtable Interfaces, Notion embeds, etc.
- **Deep RBAC beyond field/table level** — too variable across providers
- **Provider migration data** — re-apply templates to new provider (schema), but data migration is a separate, manual export/import process

### Layer 3: Template applicator

Orchestrates template application across any provider:

```elixir
TemplateApplicator.apply(
  config,              # SyncConfiguration with provider details
  [:foundation, :personnel, :compliance_assessment, :action_tracker],
  %{
    storage_mode: :reference,
    risk_scoring: :matrix,
    people: :linked,
    org_structure: :site,
    assessment_grain: :law,
    review_cycle: :scheduled,
    reporting: :dashboard,
    data_collection: :forms,
    improvement: :none
  }
)
```

1. Resolves dependency order from template `requires`
2. For each template: creates tables → fields → views → rollups (idempotent)
3. Seeds initial data
4. Registers webhooks
5. Stores template metadata + sub-pattern config in SyncConfiguration

### Webhook integration

When a customer updates data (changes compliance status, completes an action, uploads evidence), webhooks notify sertantai. This enables:

- Compliance dashboard in `/app/stats` showing real-time assessment status
- Change detection: "Customer marked 3 laws as non-compliant since last review"
- Evidence tracking: count of evidence items per law

Webhook handling is also provider-agnostic — each adapter parses its provider's webhook payload format into a common event struct.

## Sync Strategy

### SertantAI-owned fields (read-only in Baserow)

These fields are synced FROM sertantai. Customer shouldn't edit them — they'll be overwritten on next sync.

- All LRT fields (Title, Family, Status, Holders, Fitness, etc.)
- All LAT fields (Provision Text, DRRP Type, Actors)
- Lookup/rollup fields computed from linked rows

Use Baserow field-level permissions (Advanced plan) to make these read-only.

### Customer-owned fields (never overwritten)

These fields are created by templates but owned by the customer. SertantAI reads them (via webhooks) but never writes.

- Compliance Status, Assessment Date, Assessed By
- Gap Description, Notes
- Risk Level, Likelihood, Impact
- Action fields (Status, Assigned To, Due Date)
- Evidence (files, notes)
- RACI assignments

### Merge strategy on sync

When SertantAI syncs updated law data:
1. **Update SertantAI-owned fields** on existing rows (status, holders, fitness)
2. **Never touch customer-owned fields** (compliance status, notes, evidence links)
3. **Add new rows** for newly applicable laws (with "Not Assessed" default)
4. **Never delete rows** — mark removed laws with Status = "Archived" (per change management plan)

## Phases

### Phase 1: Provider-agnostic infrastructure
- Universal field type system (`:text`, `:link_row`, `:formula`, etc.)
- `TemplateBehaviour` behaviour module with `field_specs(sub_patterns)` callback
- Extended `ProviderBehaviour` with schema operations (`create_table`, `create_field`, `create_view`, `create_webhook`)
- Sub-pattern config struct (9 dimensions)
- Template registry with dependency resolution
- `TemplateApplicator` — idempotent orchestration across any provider

### Phase 2: Baserow adapter (extend existing)
- Implement new `ProviderBehaviour` callbacks on existing `Providers.Baserow`
- Universal type → Baserow type mapping
- Baserow webhook payload → common event struct parsing
- Refactor existing `Engine.run` to use template infrastructure

### Phase 3: Foundation + Personnel + Compliance Assessment
- Foundation template (refactor existing LRT/LAT sync into template pattern)
- Personnel template
- Compliance Assessment template with sub-pattern support
- Seed logic (one Assessment per law, linked to LRT)
- Rollups on LRT (assessment count, compliance %)

### Phase 4: Action Tracker + Evidence Vault
- Action Tracker with kanban/calendar views
- Evidence Vault with storage_mode sub-pattern (file vs URL)
- Rollups on Assessments (open action count)

### Phase 5: Webhook → sertantai pipeline
- Receive provider webhooks (provider-agnostic event struct)
- Update compliance metrics in sertantai
- Surface in `/app/stats` dashboard

### Phase 6: Remaining templates
- Incident Register, Audit Management, Training Tracker, Document Control
- RACI template (maps actors struct to organisational roles)
- PDCA / Improvement Initiatives template

## Resolved Questions

*Reviewed by Gemini 2.5 Flash (2026-06-07)*

1. **Baserow plan requirement** — **Require Advanced plan** ($20/user/mo). Field-level permissions are non-negotiable for protecting SertantAI-owned fields from customer edits. Without it, sync overwrites customer changes without warning. RBAC and audit logs are also essential for enterprise compliance.

2. **Self-hosted vs SaaS** — **SaaS only initially.** Self-hosted introduces operational overhead (customer infrastructure, patching, network access, debugging). Offer as a separate, higher-cost tier once SaaS is proven. API is identical so code works for both.

3. **Template versioning** — **Additive-only upgrades.** New fields/views can be added. Existing fields/formulas are never modified or deleted automatically. Store `template_version` in SyncConfiguration. Customer triggers upgrades via UI button ("Update Templates"). If a formula needs a breaking change, create a new field (`SA_Risk_Score_v2`) and leave the old one.

4. **Webhook reliability** — **Hybrid: webhooks + polling fallback.** Webhooks for near real-time. Every 6-12 hours, full reconciliation poll of Assessments and Actions to catch missed events. Losing "Non-Compliant" status changes is unacceptable for compliance.

5. **Multi-table sync ordering** — **Dependency-ordered creation enforced by TemplateApplicator.** The `requires` field in template definitions manages this. Automated tests for application order. Rollback strategy needed if API calls fail mid-application.

6. **Customer customisation** — **SA_ prefix convention** on all SertantAI-managed tables and fields. Customers create their own fields/tables without the prefix. Clear documentation: never modify SA_-prefixed elements. This prevents conflicts during sync and template upgrades.

## Resolved Questions (continued)

*From Gemini Round 2 (2026-06-07):*

7. **Template rollback** — **Idempotent re-apply, not rollback.** All creation steps check if the element already exists (by SA_ prefix) before creating. If application fails mid-way, status is marked "Failed" in SyncConfiguration. Customer clicks "Retry" — the idempotent applicator picks up where it left off. Never auto-delete partially created tables.

8. **New provision auto-seeding** — **Yes, auto-create "Not Assessed" rows.** When LAT sync adds new provisions, the Assessment template runs incremental seeding — finds provisions without a corresponding Assessment row and creates them with defaults. New compliance obligations should never go untracked.

9. **RACI granularity** — **Provision-level as default.** Different provisions within a law have different responsible parties — law-level RACI is too coarse to be actionable. Thousands of rows are fine for Baserow. Complexity managed via filtered views (by department, by role, by law family).

## Open Questions (Remaining)

None — all resolved.

## Key Files

| Purpose | Path |
|---------|------|
| Baserow provider | `backend/lib/sertantai_legal/sync/providers/baserow.ex` |
| Sync engine | `backend/lib/sertantai_legal/sync/engine.ex` |
| Profile query | `backend/lib/sertantai_legal/sync/profile_query.ex` |
| Sync configuration | `backend/lib/sertantai_legal/sync/sync_configuration.ex` |
| Row mapping | `backend/lib/sertantai_legal/sync/sync_row_mapping.ex` |
| Field tier definitions | `backend/lib/sertantai_legal/sync/field_tiers.ex` |
| Change management plan | `.claude/plans/change-management.md` |
| Actor usage map | `backend/data/actor-tag-usage-map.md` |
