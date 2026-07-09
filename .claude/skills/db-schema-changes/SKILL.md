---
name: DB Schema Changes
description: Safe procedures for modifying the database schema. Covers the uk_lrt view + INSTEAD OF trigger pattern, column type changes on partitioned tables, and migration best practices.
---

# DB Schema Changes

## The Golden Rule

**NEVER modify the database schema with raw SQL outside a migration.** Always create an Ecto migration. This ensures changes are tracked, repeatable, and reversible.

```bash
# Generate a migration
cd backend
mix ecto.gen.migration description_of_change

# Run it
mix ash_postgres.migrate
```

## The uk_lrt View + Trigger Pattern

The `uk_lrt` view is **not a simple view**. It has three INSTEAD OF triggers that enable Ash/Ecto to INSERT/UPDATE/DELETE through the view into the partitioned `legal_register` table.

### Why triggers exist

PostgreSQL's partition routing conflicts with BEFORE ROW triggers on partitioned tables. The INSTEAD OF triggers bypass this by inserting directly into the parent `legal_register` table with `country = 'uk'` hardcoded.

### The three components

```
uk_lrt (VIEW)
  ├── trg_uk_lrt_view_insert → uk_lrt_view_insert() 
  ├── trg_uk_lrt_view_update → uk_lrt_view_update()
  └── trg_uk_lrt_view_delete → uk_lrt_view_delete()
```

### What breaks if you DROP VIEW

Dropping the view **silently destroys all three triggers**. The view can be recreated, but the triggers must be explicitly recreated too. Without them, all Ash writes to `uk_lrt` fail.

### Any column change to legal_register requires

1. Drop the `uk_lrt` view (triggers drop automatically)
2. Drop the three trigger functions
3. Make the column change on `legal_register` (parent table — partitions inherit)
4. Recreate the view with explicit column list
5. Recreate all three trigger functions with the column in their INSERT/UPDATE statements
6. Recreate the three triggers

**All six steps in a single migration.**

## Migration Template: Adding a Column

```elixir
defmodule SertantaiLegal.Repo.Migrations.AddNewColumnToLegalRegister do
  use Ecto.Migration

  def up do
    # 1. Drop view + triggers
    execute("DROP VIEW IF EXISTS uk_lrt")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_insert() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_update() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_delete() CASCADE")

    # 2. Add column to parent table
    alter table(:legal_register) do
      add :new_column, :text
    end

    # 3. Recreate view (explicit column list — add new_column)
    execute("""
    CREATE VIEW uk_lrt AS
    SELECT
      id, family, ..., new_column
    FROM legal_register
    WHERE country = 'uk'
    """)

    # 4. Recreate INSERT trigger function (add new_column to column + values lists)
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_insert() RETURNS trigger AS $function$
    BEGIN
      INSERT INTO legal_register (..., new_column) VALUES (..., NEW.new_column);
      RETURN NEW;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # 5. Recreate UPDATE trigger function (add new_column = NEW.new_column)
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_update() RETURNS trigger AS $function$
    BEGIN
      UPDATE legal_register SET ..., new_column = NEW.new_column WHERE id = OLD.id;
      RETURN NEW;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # 6. Recreate DELETE trigger function (unchanged)
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_delete() RETURNS trigger AS $function$
    BEGIN
      DELETE FROM legal_register WHERE id = OLD.id;
      RETURN OLD;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # 7. Recreate triggers
    execute("CREATE TRIGGER trg_uk_lrt_view_insert INSTEAD OF INSERT ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_insert()")
    execute("CREATE TRIGGER trg_uk_lrt_view_update INSTEAD OF UPDATE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_update()")
    execute("CREATE TRIGGER trg_uk_lrt_view_delete INSTEAD OF DELETE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_delete()")
  end

  def down do
    # Reverse: drop view, remove column, recreate view without it
    execute("DROP VIEW IF EXISTS uk_lrt CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_insert() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_update() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_delete() CASCADE")

    alter table(:legal_register) do
      remove :new_column
    end

    # Recreate view + triggers without the new column
    # (copy from previous migration)
  end
end
```

## Getting Current View + Trigger Definitions

Before writing a migration, dump the current state:

```bash
# View definition
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -t -A \
  -c "SELECT pg_get_viewdef('uk_lrt', true);"

# Trigger definitions
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -t -A \
  -c "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'uk_lrt_view_insert';"

PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -t -A \
  -c "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'uk_lrt_view_update';"

PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -t -A \
  -c "SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'uk_lrt_view_delete';"
```

## Changing a Column Type

Cannot ALTER a column used by a view. Must drop view first.

```elixir
# In migration up/0:
execute("DROP VIEW IF EXISTS uk_lrt")
execute("DROP FUNCTION IF EXISTS uk_lrt_view_insert() CASCADE")
execute("DROP FUNCTION IF EXISTS uk_lrt_view_update() CASCADE")
execute("DROP FUNCTION IF EXISTS uk_lrt_view_delete() CASCADE")

# Alter on parent table (partitions inherit automatically)
execute("""
ALTER TABLE legal_register
ALTER COLUMN my_column TYPE jsonb[]
USING CASE WHEN my_column IS NULL THEN NULL
           ELSE ARRAY[my_column]
      END
""")

# Then recreate view + all triggers (same pattern as above)
```

**Do NOT** alter partition tables directly — you'll get `cannot alter inherited column`.

## Partitioned Table Structure

```
legal_register (parent, partitioned by country)
  ├── legal_register_uk (partition, country = 'uk')
  └── legal_register_au (partition, country = 'au')

uk_lrt (VIEW on legal_register WHERE country = 'uk')
  └── INSTEAD OF triggers → INSERT/UPDATE/DELETE on legal_register
```

- Schema changes go on `legal_register` (parent)
- Partitions inherit automatically
- The view must be recreated to pick up column changes
- Triggers must reference the new column explicitly

## Ash Schema Must Match DB

After migration, ensure the Ash resource attribute matches the DB column type:

| Ash Type | PostgreSQL Type |
|----------|----------------|
| `:string` | `text` |
| `:integer` | `bigint` |
| `:map` | `jsonb` |
| `{:array, :map}` | `jsonb[]` |
| `{:array, :string}` | `text[]` |
| `:boolean` | `boolean` |
| `:float` | `double precision` |

Mismatches cause runtime errors like `cannot cast type jsonb to jsonb[]`.

## After Migration

Server must be restarted to pick up schema changes — the compiled Ash resource has the old schema cached.

## Reference Migrations

| Migration | What it does |
|-----------|-------------|
| `20260518000001` | Original uk_lrt view + triggers |
| `20260703000001` | Fixed view after accidental DROP (restored triggers) |
| `20260708000001` | Changed `significance_parts` jsonb → jsonb[] |

## Key Files

| Purpose | Path |
|---------|------|
| LegalRegister resource | `backend/lib/sertantai_legal/legal/legal_register.ex` |
| UkLrt resource (view) | `backend/lib/sertantai_legal/legal/uk_lrt.ex` |
| Migrations | `backend/priv/repo/migrations/` |
