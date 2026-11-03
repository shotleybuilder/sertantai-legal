# Baserow Personnel Patterns

How people are represented in a customer's Baserow compliance workspace. The choice depends on the customer's Baserow plan, SSO setup, and whether non-Baserow users need to be tracked.

---

## Three Patterns

### Pattern 1: Collaborators Only

**Sub-pattern**: `people: :collaborator`

No Personnel table. Assignment fields on Assessment, Action Tracker, etc. use Baserow's native **Collaborators** field type, which references workspace members directly.

**How it works:**
- Collaborators field shows a dropdown of all workspace members
- Assigning someone triggers in-app notification (optional)
- If a user is removed from the workspace, their assignments are auto-cleaned
- Filter/group/sort by collaborator works natively

**Baserow API format:**
```json
// Read: [{"id": 42, "name": "Jane Smith"}, {"id": 17, "name": "John Doe"}]
// Write: [{"id": 42}, {"id": 17}]  (integer user ID, not email)
```

To get user IDs: `GET /api/workspaces/users/workspace/{workspace_id}/`

**Best for:** Small compliance teams (5-20 people) where everyone has a Baserow account. Works well with SSO — users appear after first login.

**Limitations:**
- Only workspace members can be assigned — no external people
- No department/role/certification tracking
- No employee directory beyond what Baserow user profiles provide
- API requires integer user ID mapping (not email)

---

### Pattern 2: Linked Personnel Table

**Sub-pattern**: `people: :linked`

A standalone **Personnel** table synced/managed by sertantai. Assignment fields on other templates use **link_row** to the Personnel table.

**Schema:**
| Field | Type | Purpose |
|-------|------|---------|
| Name | Text (row name) | Full name |
| Email | Email | Contact |
| Role | Single select | Compliance Officer, Site Manager, etc. |
| Department | Single select | EHS, Operations, Legal, etc. |
| Employee ID | Text | HR system reference |
| Active | Boolean | Filter inactive people |

**Views:** All People (grid), By Department (grouped), Active Only (filtered), Add Person (form)

**How assignments work:**
- Other templates (Assessment, Action Tracker) have a link_row field → Personnel
- Selecting an assignee shows rows from the Personnel table
- Rollups can count assignments per person

**Best for:** Organisations where:
- Not everyone uses Baserow (site managers, contractors, external auditors)
- Department/role structure needs tracking
- Training/certification data needs a home
- The people list is managed programmatically (HR system sync)

**Limitations:**
- No native notifications on assignment
- Data can go stale if not maintained
- Duplicate management between Personnel table and Baserow user accounts

---

### Pattern 3: Hybrid (Collaborators + Personnel)

**Sub-pattern**: `people: :hybrid`

Both a Personnel table AND Collaborators fields. Each serves a different purpose:

- **Collaborators** → "Who is doing this task?" (active Baserow users, notifications)
- **Personnel link_row** → "Who is responsible in the org?" (full directory, including non-users)

**How it works on an Assessment row:**
| Field | Type | Example |
|-------|------|---------|
| Assigned To | Collaborators | Jane Smith (Baserow user, gets notified) |
| Responsible Person | Link_row → Personnel | John Doe (site manager, not a Baserow user) |

**Best for:** Enterprise customers with:
- SSO (SAML/OIDC) for Baserow users on Advanced/Enterprise plan
- A broader workforce that includes non-Baserow users
- Need for both task assignment (notifications) and organisational accountability

**Limitations:**
- Two "people" concepts to explain to users
- More complex template schema
- Potential confusion: "why is Assigned To different from Responsible Person?"

---

## Baserow Enterprise SSO Context

| Feature | Support | Notes |
|---------|---------|-------|
| SAML 2.0 | Yes (Advanced+) | Okta, Azure AD, OneLogin |
| OAuth 2.0 | Yes (Advanced+) | Google, GitHub, GitLab |
| OIDC | Yes (Advanced+) | Generic connector |
| User provisioning | JIT only | Account created on first SSO login |
| SCIM | No | No auto-deprovisioning or group sync |
| Workspace auto-join | No | Admin must invite, or user joins via link |
| IdP group → Team sync | No | Teams managed manually in Baserow |

**Implication:** Even with SSO, there's a manual step to get users into the right workspace. The Collaborators field only shows users who have both logged in AND been added to the workspace.

---

## Baserow Teams as Departments

Baserow Teams (Advanced/Enterprise) can model departments:

- Create teams: "EHS UK", "Legal", "Operations"
- Assign workspace-level roles per team (Admin/Builder/Editor/Commenter/Viewer)
- Members inherit the highest role from any team they belong to
- Table-level and field-level permissions can further restrict access

**Not synced from IdP** — teams must be managed manually in Baserow. No SCIM group mapping.

---

## Sub-Pattern Configuration

The `people` dimension in `SubPatterns` controls which pattern is used:

| Value | Personnel Table | Assignment Fields | Template Behaviour |
|-------|----------------|-------------------|--------------------|
| `:flat` | No | Text field (name only) | Simplest — no linking |
| `:collaborator` | No | Collaborators field | Baserow-native, notifications |
| `:linked` | Yes | Link_row → Personnel | Full directory, no notifications |
| `:hybrid` | Yes | Both Collaborators + Link_row | Enterprise, maximum flexibility |

Templates that reference people (Assessment, Action Tracker, Evidence Vault, Incident Register, Audit Management, Training Tracker, RACI) adapt their field specs based on this sub-pattern value.

---

## Sync Considerations

| Pattern | Sertantai Syncs People? | API Complexity |
|---------|------------------------|----------------|
| `:flat` | No | None — text field |
| `:collaborator` | No | Need user ID mapping for programmatic assignment |
| `:linked` | Yes — populates Personnel table | Standard row CRUD |
| `:hybrid` | Yes — Personnel table + user ID mapping | Both row CRUD and user ID resolution |

For `:collaborator` and `:hybrid`, sertantai would need to call `GET /api/workspaces/users/workspace/{id}/` to resolve email → Baserow user ID before setting Collaborators fields programmatically.
