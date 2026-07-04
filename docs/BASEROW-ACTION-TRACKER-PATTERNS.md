# Baserow Action Tracker Patterns

How the Action Tracker template creates a remediation task management table linked to Compliance Assessments. Actions track what needs to be done to close compliance gaps — corrective, preventative, improvement, and maintenance tasks with owners, deadlines, and workflow status.

---

## The Actions Table

One row per remediation task. Each action links to the Assessment that identified the gap. Supports kanban-style workflow (drag between statuses) and calendar-based deadline tracking.

**Dependencies**: Compliance Assessment (which depends on Foundation + Personnel).

**Cross-table**: Adds an `Open_Actions` rollup field to the Assessments table (deferred to Phase 2 — same Baserow reverse-link limitation as Assessment_Count).

**Webhook**: Fires on row create and update — drives the ComplianceMetrics dashboard for action completion tracking.

---

## Core Fields (always present)

| Field | Type | Purpose |
|-------|------|---------|
| Title | Text | Action description — what needs to be done |
| Assessment | Link_row → Assessments | Which compliance gap this addresses |
| Law | Lookup → Assessment.Law | Auto-populated — which law the gap relates to |
| Status | Single select | Open / In Progress / Completed / Cancelled |
| Priority | Single select | Critical / High / Medium / Low |
| Action_Type | Single select | Corrective / Preventative / Improvement / Maintenance |
| Due_Date | Date | Deadline for completion |
| Completed_Date | Date | When actually completed |
| Notes | Long text | Progress notes, updates, blockers |
| Days_Until_Due | Formula | Days until deadline (negative = overdue) |
| Overdue | Formula | "OVERDUE" if past due and not completed/cancelled, blank otherwise |

### Action Types Explained

| Type | ISO Term | When to use |
|------|----------|-------------|
| **Corrective** | Corrective action | Fix an existing non-compliance (reactive) |
| **Preventative** | Preventive action | Prevent a potential non-compliance (proactive) |
| **Improvement** | Continual improvement | Enhance beyond minimum compliance |
| **Maintenance** | Operational control | Routine tasks to maintain compliance (inspections, training renewals) |

### Formula Fields

**Days_Until_Due**:
```
date_diff('day', field('Due_Date'), today())
```
Negative values = overdue. Positive = days remaining.

**Overdue**:
```
if(
  and(
    field('Status') != 'Completed',
    field('Status') != 'Cancelled',
    field('Days_Until_Due') < 0
  ),
  'OVERDUE',
  ''
)
```
Only flags as OVERDUE if the action is still open/in-progress AND past its due date.

---

## Sub-Pattern: People (`--people`)

Controls how task assignment works.

### `:linked` — Personnel table reference

| Field | Type | Description |
|-------|------|-------------|
| Assigned_To | Link_row → Personnel | Person responsible for completing this action |

**Best for**: Organisations with a Personnel table. "Show me all actions assigned to Jane Smith."

### `:workspace_member` — Baserow Collaborators

| Field | Type | Description |
|-------|------|-------------|
| Assigned_To | Collaborators | Person responsible (Baserow user, gets notifications) |

**Best for**: Small teams. Native Baserow notifications when assigned.

### `:hybrid` — Both Collaborators + Personnel

| Field | Type | Description |
|-------|------|-------------|
| Assigned_To | Collaborators | Task assignee (Baserow user, gets notified) |
| Responsible_Person | Link_row → Personnel | Organisational accountability (may not be a Baserow user) |

**Best for**: Enterprise. Baserow user does the work, Personnel record tracks accountability.

### `:flat` — Text field

| Field | Type | Description |
|-------|------|-------------|
| Assigned_To | Text | Name of person responsible |

**Best for**: Quick setup, no Personnel table.

---

## Views

| View | Type | Purpose |
|------|------|---------|
| **All Actions** | Grid | Default — all rows |
| **Overdue** | Grid | Filtered: Overdue = "OVERDUE" — the fire-fighting view |
| **Action Board** | Kanban | Stacked by Status — drag actions through Open → In Progress → Completed |
| **Timeline** | Calendar | Date field: Due_Date — visual deadline management |
| **By Priority** | Grid | Grouped by Priority — Critical first |
| **By Type** | Grid | Grouped by Action_Type — separate corrective from preventative |

### Recommended View Configuration

The **Action Board** (kanban) is the primary workflow view. Compliance officers:
1. See new actions in "Open"
2. Drag to "In Progress" when starting work
3. Drag to "Completed" when done (Baserow records the audit trail)
4. Check the **Overdue** view daily for missed deadlines

---

## Workflow: Assessment → Action

```
1. Assessment identifies a gap
   └─ Compliance_Status = "Non-Compliant"
   └─ Gap_Description = "No documented risk assessment for lone working"

2. Action created to close the gap
   └─ Title = "Develop lone working risk assessment"
   └─ Assessment = [linked to the gap]
   └─ Action_Type = "Corrective"
   └─ Priority = "High"
   └─ Assigned_To = [Jane Smith]
   └─ Due_Date = 2026-08-15

3. Action progresses
   └─ Status: Open → In Progress → Completed
   └─ Notes updated with progress

4. Assessment re-evaluated
   └─ Compliance_Status = "Compliant"
   └─ Evidence Vault: [link to completed risk assessment document]
```

---

## Primary Field

The Actions table uses the Baserow default `Name` field (text) — renamed by the adapter. For the PoC, the `Title` field serves as the display name.

A formula primary could be considered:
```
concat(field('Assessment'), ' — ', field('Title'))
```
This would show `UK_ukpga_1974_37_Non-Compliant — Develop lone working risk assessment` in link_row dropdowns from other tables. However, this can be verbose. The simple `Title` may be more practical.

---

## CLI

```bash
# Apply Action Tracker (auto-includes dependencies: Foundation, Personnel, Compliance Assessment)
mix templates.apply --templates action_tracker --people linked --risk simple --review scheduled --grain law

# Apply just Action Tracker if dependencies already exist
mix templates.apply --templates action_tracker --people linked
```

---

## Related Templates

| Template | Relationship |
|----------|-------------|
| **Compliance Assessment** | Parent — actions address assessment gaps |
| **Evidence Vault** | Child — evidence proves actions were completed |
| **Incident Register** | Sibling — incidents may generate corrective actions |
| **PDCA** | Consumer — improvement initiatives link to actions |

---

## Baserow Manual Configuration

After template application, consider adding:
- **Row colouring**: Red for Overdue, amber for Due Soon (Days_Until_Due < 7)
- **Notifications**: Enable on Assigned_To field (if using Collaborators mode)
- **Count field**: Total Actions on the Assessments table (until Phase 2 rollup is available)
