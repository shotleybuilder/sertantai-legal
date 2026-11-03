# Baserow Compliance Assessment Patterns

How the Compliance Assessment template adapts to customer needs. The template creates an **Assessments** table linked to the Legal Register, with fields and views controlled by 4 sub-pattern dimensions.

---

## The Assessments Table

One row per applicable law (or provision). Each row tracks: is the customer compliant, who assessed it, when is the next review, and what's the risk if non-compliant.

**Dependencies**: Foundation (LRT/LAT tables) + Personnel table.

**Cross-table**: Adds an `Assessment_Count` rollup field to the Legal Register, showing how many assessments are linked to each law.

**Webhook**: Fires on row update — drives the ComplianceMetrics dashboard.

---

## Core Fields (always present)

| Field | Type | Purpose |
|-------|------|---------|
| Law | Link_row → Legal Register | Which law is being assessed |
| Compliance_Status | Single select | Compliant / Partially Compliant / Non-Compliant / Not Assessed / Not Applicable |
| Family | Lookup → Legal Register.Family | Auto-populated law family for grouping |
| Law_Status | Lookup → Legal Register.Status | Auto-populated in-force status |
| Gap_Description | Long text | What's missing or non-compliant |
| Notes | Long text | General notes |
| Reference | Text | Internal ID or cross-reference |

---

## Sub-Pattern 1: People (`--people`)

Controls how assessment ownership and audit trail fields work.

### `:linked` — Personnel table references

| Field | Type | Description |
|-------|------|-------------|
| Assessment_Owner | Link_row → Personnel | Accountable person |
| Assessed_By | Link_row → Personnel | Who performed the assessment |
| Assessment_Date | Date | When last assessed |

**Best for**: Organisations with a Personnel table. Full cross-referencing — "show me all assessments owned by Jane Smith".

### `:workspace_member` — Baserow Collaborators

| Field | Type | Description |
|-------|------|-------------|
| Assessment_Owner | Collaborators | Accountable person (Baserow user, gets notifications) |
| Assessed_By | Collaborators | Who performed the assessment |
| Assessment_Date | Date | When last assessed |

**Best for**: Small teams where everyone has a Baserow account. Native notifications on assignment.

### `:hybrid` — Both Collaborators + Personnel

| Field | Type | Description |
|-------|------|-------------|
| Assessment_Owner | Collaborators | Accountable person (Baserow user) |
| Responsible_Person | Link_row → Personnel | Responsible in the org (may not be a Baserow user) |
| Assessed_By | Collaborators | Who performed the assessment |
| Assessment_Date | Date | When last assessed |

**Best for**: Enterprise with SSO. Baserow users do the work (get notified), the Personnel directory tracks organisational accountability.

### `:flat` — Text fields

| Field | Type | Description |
|-------|------|-------------|
| Assessment_Owner | Text | Name of accountable person |
| Assessed_By | Text | Name of assessor |
| Assessment_Date | Date | When last assessed |

**Best for**: Quick setup, no Personnel table needed. No cross-referencing.

---

## Sub-Pattern 2: Risk Scoring (`--risk`)

Controls how compliance risk is quantified.

### `:simple` — Single select

| Field | Type | Options |
|-------|------|---------|
| Risk_Level | Single select | Critical, High, Medium, Low |

**Best for**: Quick risk triage. Compliance officer picks a level. No formula.

### `:matrix` — Likelihood × Impact

| Field | Type | Description |
|-------|------|-------------|
| Risk_Level | Single select | Critical / High / Medium / Low (overall rating) |
| Likelihood | Single select | Almost Certain / Likely / Possible / Unlikely / Rare |
| Impact | Single select | Catastrophic / Major / Moderate / Minor / Insignificant |
| Risk_Score | Formula | `Likelihood × Impact` (1–25 scale) |

**Formula**: Maps each select to a number (5–1), multiplies them. Score 0 if either is blank.

**Best for**: ISO 31000 / formal risk management. Enables risk heatmaps and prioritised remediation.

### Risk Matrix (`:matrix` reference)

| | Insignificant (1) | Minor (2) | Moderate (3) | Major (4) | Catastrophic (5) |
|---|---|---|---|---|---|
| **Almost Certain (5)** | 5 | 10 | 15 | 20 | **25** |
| **Likely (4)** | 4 | 8 | 12 | 16 | 20 |
| **Possible (3)** | 3 | 6 | 9 | 12 | 15 |
| **Unlikely (2)** | 2 | 4 | 6 | 8 | 10 |
| **Rare (1)** | 1 | 2 | 3 | 4 | 5 |

---

## Sub-Pattern 3: Review Cycle (`--review`)

Controls how reassessment scheduling works.

### `:scheduled` — Frequency + automated status

| Field | Type | Description |
|-------|------|-------------|
| Review_Frequency | Single select | Quarterly / Bi-annually / Annually / Biennial |
| Next_Review_Date | Date | When to reassess |
| Days_Until_Review | Formula | Days until next review (negative = overdue) |
| Review_Status | Formula | OVERDUE / Due Soon / OK |

**Formulas**:
- `Days_Until_Review`: `date_diff('day', field('Next_Review_Date'), today())`
- `Review_Status`: `if(Days_Until_Review < 0, 'OVERDUE', if(Days_Until_Review < 30, 'Due Soon', 'OK'))`

**Best for**: Organisations with formal review cycles. The "Overdue Reviews" view and "Review Calendar" use these fields.

### `:manual` — Date only

| Field | Type | Description |
|-------|------|-------------|
| Next_Review_Date | Date | When to reassess |

**Best for**: Informal review process. No automated overdue tracking.

---

## Sub-Pattern 4: Assessment Grain (`--grain`)

Controls what each assessment row represents.

### `:law` — One row per applicable law

- Seeded from Legal Register (274 rows for QQ)
- Each row links to one law via the Law field
- Compliance status is at the law level
- Simpler, fewer rows, suitable for most customers

### `:provision` — One row per provision (duty)

- Seeded from Duties table (up to 2,400 rows for QQ)
- Each row represents a specific obligation within a law
- Compliance status at the provision level
- More granular, more rows, suitable for detailed compliance programmes

**Row budget consideration**: `:law` = ~274 rows, `:provision` = ~2,400 rows. For Baserow free tier (now 50K), both fit comfortably. For very large registers, `:law` may be preferable.

---

## Views

| View | Type | Purpose |
|------|------|---------|
| All Assessments | Grid | Default view — all rows |
| Non-Compliant | Grid | Filtered: Compliance_Status contains "Non-Compliant" |
| Overdue Reviews | Grid | Filtered: Review_Status = "OVERDUE" (`:scheduled` only) |
| By Family | Grid | Grouped by Family lookup — see compliance by law category |
| Compliance Board | Kanban | Stacked by Compliance_Status — drag-and-drop workflow |
| Review Calendar | Calendar | Date field: Next_Review_Date — visual review schedule |

---

## Seeding

When the template is applied, it can pre-populate assessment rows:

- **`:law` grain**: Creates one "Not Assessed" row per law in the Legal Register, linked via the Law field. Next review date set to 90 days from now.
- **`:provision` grain**: Creates one "Not Assessed" row per provision in the Duties table.

Seeding requires `row_mappings` from a previous `mix sync.run` — the LRT/LAT external row IDs are needed to set the Law link_row values.

---

## Recommended Configuration

| Customer Profile | People | Risk | Review | Grain |
|-----------------|--------|------|--------|-------|
| Small team, quick start | `:flat` | `:simple` | `:manual` | `:law` |
| Mid-size, formal programme | `:linked` | `:matrix` | `:scheduled` | `:law` |
| Enterprise with SSO | `:hybrid` | `:matrix` | `:scheduled` | `:law` |
| Detailed compliance (large org) | `:linked` | `:matrix` | `:scheduled` | `:provision` |

**QQ PoC**: `--people linked --risk matrix --review scheduled --grain law` — full feature set at law-level granularity (274 assessment rows).

---

## CLI

```bash
# Apply with recommended settings
mix templates.apply --templates compliance_assessment --people linked --risk matrix --review scheduled --grain law

# Minimal setup
mix templates.apply --templates compliance_assessment --people flat --risk simple --review manual --grain law
```

Note: Compliance Assessment requires Foundation and Personnel templates. If Personnel hasn't been applied yet, include it: `--templates personnel,compliance_assessment`
