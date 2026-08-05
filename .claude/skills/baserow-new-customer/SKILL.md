---
name: Baserow New Customer
description: Add a new demo customer to the self-hosted Baserow Compliance Workbench. Creates a customer row and links applicable laws from the Legal Register.
---

# Baserow New Customer

## When to use

- Adding a new prospect/demo customer to the Baserow demo instance
- Listing existing demo customers
- Setting up a customer with a filtered law profile (specific families only)

## Architecture

The demo Baserow (`baserow.sertantai.com`) uses a single-database, multi-customer model:

```
Customers table (one row per demo customer)
    │
    │ link_row (many-to-many)
    ▼
Legal Register (shared LRT rows, filtered by customer link)
    │
    ▼
All other tables (Duties, Controls, Evidence, etc.) — shared, no customer tag
```

- The **Customers** table is the only table with customer-specific rows
- **Legal Register** has a `Customers` link_row — defines which laws apply to which customer
- All other tables filter through the Legal Register relationship chain
- Multiple customers can share the same law (link_row is many-to-many)

## Prerequisites

- Self-hosted Baserow running at `baserow.sertantai.com`
- Sync config has `customers_table_id` and `lrt_table_id` in `target_config`
- Database token configured (not email/password — tokens don't expire)
- LRT data already synced (`mix sync.run` completed)

## Commands

All commands run from `backend/`:

```bash
# List existing customers
mix run scripts/baserow_new_customer.exs --list

# Add customer with all laws
mix run scripts/baserow_new_customer.exs --name "Acme Corp"

# Add with industry and notes
mix run scripts/baserow_new_customer.exs --name "Acme Corp" --industry "Manufacturing" --notes "Demo for Q3 pitch"

# Add with specific law families only
mix run scripts/baserow_new_customer.exs --name "Acme Corp" --families "Health and Safety,Environment"

# Dry run (see what would happen)
mix run scripts/baserow_new_customer.exs --name "Acme Corp" --families "Environment" --dry-run
```

## Options

| Flag | Required | Description |
|------|----------|-------------|
| `--name` | Yes (unless `--list`) | Customer name |
| `--industry` | No | Industry sector |
| `--notes` | No | Internal notes |
| `--families` | No | Comma-separated law families to link (default: all) |
| `--all-laws` | No | Explicitly link all laws (default behaviour) |
| `--list` | No | List existing customers and exit |
| `--config` | No | Sync config UUID (default: first found) |
| `--dry-run` | No | Show what would be created without creating |

## What the script does

1. **Validates** — checks customer doesn't already exist, config has required table IDs
2. **Creates** — one row in the Customers table (Name, Industry, Notes)
3. **Fetches** — LRT row IDs (all, or filtered by `--families`)
4. **Links** — batch-updates LRT rows to add the new customer to their `Customers` link_row (appends, doesn't overwrite other customers)

## Family filter

When `--families` is specified, only laws matching those families are linked. Family values are Baserow single_select values matching the `Family` column on the Legal Register table. Common families:

- Health and Safety
- Environment
- Employment
- Fire Safety
- Building Regulations
- Planning
- Food Safety
- Product Safety

Use `--dry-run` to check the count before committing.

## When a new customer brings new laws

The demo sync config has `"demo": true` in `target_config`. This makes the sync engine
query the **union** of all organizations' applicable laws from `org_applicabilities`,
not just the config's own org. Production customer configs don't have this flag and
remain scoped to their single organization — no cross-contamination.

Steps when a new customer has laws not already in the LRT table:

1. Seed `org_applicabilities` for the new customer's organization (status="yes")
2. Run `mix sync.run` — the demo flag queries the union, appending new laws to the shared LRT table
3. Run `baserow_new_customer.exs --name "Customer X"` — link the new customer to their laws

The sync engine is additive — existing LRT rows are untouched, new rows are appended.
Rows shared between customers remain linked to all their customers.

### Demo vs production sync

| | Demo (`"demo": true`) | Production (default) |
|---|---|---|
| Applicability query | Union of ALL orgs | Single org only |
| LRT scope | Superset of all demo customers | One customer's laws |
| Target | `baserow.sertantai.com` | Customer's own Baserow |
| Customers table | Yes (multi-customer links) | No |

## Troubleshooting

**"No database_token in credentials"**: Run `mix run scripts/update_sync_target.exs --url https://baserow.sertantai.com --token YOUR_TOKEN`

**"No customers_table_id"**: Run `mix templates.apply --templates customers` to create the Customers table.

**"Customer already exists"**: The script prevents duplicates. Delete the existing row in Baserow UI first if you need to recreate.

**Link_row appends vs overwrites**: The batch PATCH with `"Customers" => [new_id]` appends to existing links — it doesn't remove other customers from the same law. This is correct for the multi-customer model.
