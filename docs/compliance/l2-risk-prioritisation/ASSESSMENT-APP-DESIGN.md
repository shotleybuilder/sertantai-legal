# L2 Assessment App — Baserow Application Builder Design

## Purpose

Give customers a clean workflow for reviewing and recording compliance assessments against their legal register, without exposing them to the raw grid view. This is the standard Assessment App that every customer lands with. The first deployment is QQ, but the design is generic.

## Context

- **N laws** in the customer's legal register (e.g. 488 for QQ)
- **Each law needs an assessment**: compliance status, risk level, owner, review date
- **Current state**: Assessments table exists in Baserow with correct schema but no data
- **For new customers**: assessments seeded as "Not Assessed", worked through via this App
- **For migrating customers**: legacy vendor data (Enhesa, Nimonik, etc.) imported then maintained via this App
- **Users**: EHS/compliance team (3-5 people), not technical

## Architecture: Baserow Application Builder

The App sits in the same Baserow workspace as the database tables. It reads from and writes to the Assessments, Legal Register, and Personnel tables via Data Sources. No external infrastructure needed.

```
┌─────────────────────────────────────────────────────┐
│  Baserow Application (published URL)                │
│                                                     │
│  ┌─────────┐   ┌──────────┐   ┌──────────────────┐  │
│  │ Queue   │──▶│ Assess   │──▶│ Review Complete  │  │
│  │ (list)  │   │ (form)   │   │ (confirmation)   │  │
│  └─────────┘   └──────────┘   └──────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │ Dashboard (summary widgets)                  │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
└──────────────────────┬──────────────────────────────┘
                       │ Data Sources
          ┌────────────┼────────────────┐
          ▼            ▼                ▼
    ┌──────────┐ ┌──────────┐  ┌──────────────┐
    │Assessments│ │Legal     │  │Personnel     │
    │(read/write)│ │Register │  │(read-only)   │
    │          │ │(read-only)│  │              │
    └──────────┘ └──────────┘  └──────────────┘
```

## Pages

### Page 1: Assessment Queue (`/`)

The landing page. Shows all assessments that need attention, prioritised by status.

**Data Source**: List Rows from Assessments table, filtered by view or formula.

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│  Compliance Assessment Review                        │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Summary: 488 laws │ 0 assessed │ 488 remaining  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  Filter: [Status ▼] [Family ▼] [Search...]           │
│                                                      │
│  ┌──────────────────────────────────────────────────┐│
│  │ Law Title           │ Family   │ Status    │ ▶   ││
│  │─────────────────────┤──────────┤───────────┤─────││
│  │ HSWA 1974           │ OHS      │ Not Assd  │ [→] ││
│  │ MHSW Regs 1999      │ OHS      │ Not Assd  │ [→] ││
│  │ COSHH Regs 2002      │ CHEM     │ Not Assd  │ [→] ││
│  └──────────────────────────────────────────────────┘│
│                                        [Show More]   │
└─────────────────────────────────────────────────────┘
```

**Elements**:
- Heading: "Compliance Assessment Review"
- Summary row (3× Summarize Field data sources): total, assessed count, remaining
- Table element: list of assessments with link column to detail page
  - Columns: Law (from Legal_Register lookup), Family, Compliance_Status, Risk_Level, Next_Review_Date
  - Link field: navigates to `/assess/:id`
  - User-filterable by Compliance_Status, Family
  - Sortable by columns

**Key decisions**:
- Table orientation: horizontal (standard grid)
- Items per page: 25 (488 laws = 20 pages, manageable)
- Default sort: Compliance_Status (Not Assessed first), then Family

### Page 2: Assessment Form (`/assess/:id`)

The workhorse. User reviews a single law and records their assessment.

**Data Sources**:
- "Get Single Row" from Assessments table using `:id` path parameter
- Shared data source for Personnel (for owner/assessor dropdowns)

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│  ← Back to Queue                                     │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │ Health and Safety at Work etc. Act 1974        │  │
│  │ Family: OHS  │  Status: ✔ In force             │  │
│  │ [View on legislation.gov.uk ↗]                 │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ── Assessment ─────────────────────────────────     │
│                                                      │
│  Compliance Status:  [Compliant           ▼]         │
│  Risk Level:         [Medium              ▼]         │
│                                                      │
│  ── Ownership ──────────────────────────────────     │
│                                                      │
│  Assessment Owner:   [Select person...    ▼]         │
│  Assessed By:        [Select person...    ▼]         │
│  Assessment Date:    [2026-07-18          📅]        │
│                                                      │
│  ── Review Schedule ────────────────────────────     │
│                                                      │
│  Review Frequency:   [Annually            ▼]         │
│  Next Review Date:   [2027-07-18          📅]        │
│                                                      │
│  ── Details ────────────────────────────────────     │
│                                                      │
│  Gap Description:    [                         ]     │
│  Notes:              [                         ]     │
│  Reference:          [Enhesa ref / internal ID ]     │
│                                                      │
│  [Save Assessment]                                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Elements**:
- Link: "← Back to Queue" → `/`
- Context block (read-only text from Legal_Register lookup):
  - Law title, family, status, legislation URL
- Form container with:
  - Choice: Compliance_Status (5 options)
  - Choice: Risk_Level (4 options)
  - Record Selector: Assessment_Owner → Personnel table
  - Record Selector: Assessed_By → Personnel table
  - Date-time Picker: Assessment_Date
  - Choice: Review_Frequency (4 options)
  - Date-time Picker: Next_Review_Date
  - Data Input (long text): Gap_Description
  - Data Input (long text): Notes
  - Data Input: Reference
- Button: "Save Assessment"

**Events**:
- On Submit → Update Row (Assessments table, row ID from path parameter)
- On Submit → Show Notification ("Assessment saved")
- On Submit → Open Page (`/`) — return to queue

**Key decisions**:
- The law context (title, family, status) is READ-ONLY — pulled from Legal_Register via the Assessment's link_row. Users don't edit law data.
- Assessment_Date defaults to today
- Next_Review_Date auto-calculates from Review_Frequency (or can be manual)
- Record Selectors for Personnel enable searching by name

### Page 3: Bulk Import (optional, for Enhesa migration)

A dedicated page for the initial Enhesa data migration. Could also be done via API script outside the App — see "Migration Strategy" below.

## Data Sources Summary

| Data Source | Type | Table | Scope | Used By |
|------------|------|-------|-------|---------|
| Assessment Queue | List Rows | Assessments | Page 1 | Table element |
| Total Count | Summarize | Assessments | Page 1 | Summary widget |
| Assessed Count | Summarize | Assessments (filtered: status ≠ Not Assessed) | Page 1 | Summary widget |
| Current Assessment | Get Row | Assessments (by :id) | Page 2 | Form pre-fill |
| Law Context | Get Row | Legal_Register (via Assessment link) | Page 2 | Context block |
| Personnel List | List Rows | Personnel | Shared | Record Selectors |

## Migration Strategy: Enhesa → Assessments

The Enhesa data needs to land in the Assessments table before the App is useful. Two approaches:

### Option A: API Script (recommended for initial load)
1. Export Enhesa assessments as CSV
2. Map columns: Enhesa status → our Compliance_Status, Enhesa risk → our Risk_Level, etc.
3. Match laws by name/type_code+year+number to Legal_Register rows
4. Batch create Assessment rows via Baserow API with link_row references
5. Run once, verify, then users maintain via the App

### Option B: App Builder Bulk Import Page
- Use the CSV Read action + Batch Create Rows
- More complex to build, but reusable for future imports
- Defer to later — the API script is faster for a one-off migration

## Implementation Plan

### Phase 1: Seed Assessments (sync engine)
- Create one Assessment row per law in the customer's register (N rows)
- Default: Compliance_Status = "Not Assessed", Next_Review_Date = 90 days
- Link each to its Legal_Register row
- Pre-populate Risk_Level from significance_rating (HIGH→High, MEDIUM→Medium, LOW→Low)
- This is a standard sync step, not customer-specific

### Phase 2: Build App (Baserow API — programmatic, reusable)
1. Create Application in customer's workspace
2. Page 1: Assessment Queue (table + summary)
3. Page 2: Assessment Form (form + context block)
4. Configure data sources and events
5. Publish
6. This should be repeatable for every new customer

### Phase 3: Legacy Migration (customer-specific, optional)
- For customers migrating from Enhesa/Nimonik: import legacy assessment data
- Update seeded rows (not create) — match by law name
- Map legacy statuses to our vocabulary
- Preserve legacy reference IDs in the Reference field

### Phase 4: Polish
- Tune filters and default sorts per customer preference
- Add "Next/Previous" navigation on the form page
- Future: provision-level drill-down from law assessment

## API Creation

Everything in this design is API-creatable. The Baserow Application Builder API supports:
- `POST /api/builder/applications/` — create application
- `POST /api/builder/pages/` — create pages with path parameters
- `POST /api/builder/data-sources/` — create data sources
- `POST /api/builder/elements/` — create elements (table, form, inputs, buttons)
- `POST /api/builder/events/` — create event/action chains

This means we can build the App programmatically, just like we build database tables via `mix templates.apply`. The App becomes part of the standard customer onboarding pipeline — every customer gets the same Assessment App seeded with their legal register.

## Decisions

1. **Assessment grain**: Law-level (488 rows). Provision-level is a future extension — the App design should accommodate stepping into provision detail later.
2. **Risk scoring**: Simple (single select: Critical/High/Medium/Low). Risk Level is used to prioritise which assessments to complete first, not as a standalone risk methodology.
3. **Personnel**: Assume Personnel table is populated. Use `:linked` people pattern (Record Selectors for Assessment_Owner and Assessed_By).
4. **Auth**: Workspace member access. Baserow simplest paid tier — no separate App login needed, users are workspace members.
