# Gemini Review: Baserow Template Architecture

**Date**: 2026-07-03
**Model**: Gemini 2.5 Flash
**Reviewer**: Google Gemini (external architecture review)
**Context**: Template application system for building compliance workspaces in Baserow

---

## Overall Assessment

The current architecture provides a solid foundation for template definition and provider abstraction. However, the `mix run -e` approach for application, coupled with the "skip if exists" idempotency, indicates a PoC stage that needs significant hardening for production use, especially with the upcoming UI-driven configuration. The core challenge is transitioning from a stateless, script-like application to a stateful, reconciliatory service.

---

## Recommendations

### 1. Default Column Handling → Adapter's `create_table` responsibility

The Baserow Provider Adapter's `create_table` method must be responsible for handling Baserow's default fields.

- **Immediate Cleanup**: Upon successful table creation, query the newly created table's fields.
- **Delete "Notes"**: Automatically delete the Notes field. This is an unwanted default and should not concern higher layers.
- **Identify Primary Field**: Identify Baserow's auto-created Name field as the provider's primary field.
- **Template Primary Field Declaration**: Templates must explicitly declare their intended primary field (see Q7).
- **Reconcile Primary Fields**: If the template declares a primary field other than "Name", rename Baserow's default Name to `_baserow_internal_id`. If the template declares "Name" as primary, update its metadata to match.

**Why**: The adapter is the encapsulation point for provider-specific quirks. Abstracting this away from the applicator and templates makes the system cleaner and more truly provider-agnostic.

### 2. Table ID Persistence → New `workspace_resource_state` table

Create a dedicated table to persist all applied provider resource IDs and their mappings:

- `workspace_configuration_id` (FK to desired state)
- `provider_type` (baserow, monday, etc.)
- `resource_type` (table, field, view, webhook)
- `template_resource_name` (internal logical name)
- `provider_resource_id` (Baserow ID)
- `provider_resource_metadata` (JSONB for provider-specific details)

**Why**: `sync_configurations.target_config` JSONB is a dangerous anti-pattern for storing application state. It conflates operational sync parameters with the fundamental mapping of template resources to concrete provider IDs.

### 3. Mix Task → Supervised Service + Oban Jobs

Abolish `mix run -e` for all production template application. Implement a `WorkspaceApplicatorService`:

- **Authentication Management**: GenServer managing Baserow JWTs with caching, refresh, revocation handling.
- **State Management**: Interact with `workspace_resource_state` table.
- **Async Processing**: Oban integration for retry, concurrency control, progress tracking.
- **Recovery**: Inherently idempotent — Oban retries call the service which can resume without side effects.

**Why**: `mix run -e` is for one-off scripts, not for a core application feature. It's slow, stateless, resource-intensive, and lacks error recovery.

### 4. UI-Driven Config → New `workspace_configuration` table

Create a new table representing the "desired state" defined by the customer:

- `customer_id`, `workspace_name`, `provider_type`
- `sub_patterns_config` (JSONB: the 9 dimensions)
- `status` (pending, applying, applied, failed, needs_reconciliation)

**Why**: `sync_configurations` should be strictly for data synchronization settings. Customer structural choices (sub-patterns) define the shape of their workspace — a separate concern. Changes trigger reconciliation jobs.

### 5. `:collaborator` → `:workspace_member`

Adopt `:workspace_member` as the universal type. `:collaborator` is a role, not an entity type. Add a `role` attribute for granularity.

**Why**: Prevents future impedance mismatches with providers that have different user involvement concepts.

### 6. Idempotency → Full Reconciliation

The applicator must actively reconcile and update ALL existing resources to match the template spec, not just skip them:

- **Compare**: Deep comparison between template spec and provider state.
- **Update**: Add `update_field`, `update_view`, `update_webhook` to the provider adapter.
- **Drift Detection**: Handle resources on provider not in template (mark, archive, or ignore).
- **Destructive Changes**: Define strategy for type changes with existing data (block, warn, migrate, force).

**Why**: "Idempotent" means reaching the desired end state, not just avoiding duplicates. This is crucial for UI-driven configuration.

### 7. Primary Field → `primary: true` flag

Templates should declare their logical primary field:

```elixir
%{name: "Employee_ID", type: :text, primary: true, description: "Unique identifier"}
```

Adapter handles the Baserow gymnastics (rename default Name to match or to placeholder).

---

## Architectural Gaps Flagged

1. **Stateless scripting** (`mix run -e`) — biggest anti-pattern, immediate priority
2. **No `update_*` methods** on provider adapter — only create, no reconciliation
3. **No drift detection** — resources on provider not in template go untracked
4. **No destructive change strategy** — field type changes with existing data undefined
5. **Config/state conflation** — desired state, applied state, and sync config all in one JSONB
6. **No authentication caching** — fresh JWT per invocation, no refresh management

---

## What's Done Well

- Template behaviour is clean and provider-agnostic
- Sub-pattern system is well-designed with orthogonal dimensions
- Dependency resolution (topological sort) handles ordering correctly
- Capability checking allows graceful degradation per provider
- Field description with 🚫 marker for managed fields is practical
