# Usage Rules for Sertantai-Legal

This file defines usage rules for this microservice. These rules are enforced during development via the `usage_rules` package.

See [usage_rules documentation](https://hexdocs.pm/usage_rules/readme.html) for more information.

## Package: SertantaiLegal

**IMPORTANT**: This is a microservice. It does NOT own User/Organization resources.
- Authentication comes from JWT validated using `SHARED_TOKEN_SECRET`
- `organization_id` comes from JWT claims, not a database relationship

### Core Principles

1. **Multi-tenancy**: All domain resources must include `organization_id` for data isolation
2. **Ash Framework**: Use Ash resources for domain modeling, not plain Ecto schemas
3. **Real-time Sync**: Resources meant for frontend sync should be configured for ElectricSQL
4. **Type Safety**: Use Dialyzer types and avoid dynamic typing where possible
5. **Testing**: All resources and actions should have test coverage

### Resource Design Guidelines

#### All Domain Resources Must:

```elixir
# ✓ GOOD: Includes organization_id, uses Ash Resource, proper timestamps
defmodule SertantaiLegal.YourDomain.YourResource do
  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "your_resources"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false  # From JWT claims
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # NOTE: No belongs_to :organization - this microservice doesn't own Organization
  # organization_id is a plain UUID that comes from JWT claims

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :organization_id]
    end

    update :update do
      accept [:name]
    end
  end
end
```

```elixir
# ✗ BAD: Missing organization_id, no timestamps, plain Ecto schema
defmodule SertantaiLegal.YourDomain.YourResource do
  use Ecto.Schema

  schema "your_resources" do
    field :name, :string
  end
end
```

#### Authentication (Microservice Pattern):

- **This service does NOT have User/Organization resources**
- Authentication is handled by `sertantai-auth` via JWT
- JWT validation happens at the plug level using `SHARED_TOKEN_SECRET`
- `organization_id` is extracted from JWT claims and used to scope data
- Never create local User or Organization tables in this service

#### ElectricSQL Integration:

Resources synced to frontend must:
1. Have `REPLICA IDENTITY FULL` enabled
2. Have appropriate ELECTRIC GRANT statements
3. Include `organization_id` for filtering
4. Be added to frontend TanStack DB collections

### API Design

#### JSON API Endpoints:

```elixir
# ✓ GOOD: Organization ID from JWT assigns, uses Ash actions
def index(conn, _params) do
  org_id = conn.assigns.organization_id  # From AuthPlug
  case YourResource.by_organization(org_id) do
    {:ok, resources} -> render(conn, "index.json", resources: resources)
    {:error, error} -> handle_error(conn, error)
  end
end
```

```elixir
# ✗ BAD: No organization scoping, direct Ecto query
def index(conn, _params) do
  resources = Repo.all(YourResource)
  render(conn, "index.json", resources: resources)
end

# ✗ BAD: Taking organization_id from params instead of JWT
def index(conn, %{"organization_id" => org_id}) do
  # NEVER trust organization_id from request params!
  # Always use conn.assigns.organization_id from JWT
end
```

### Testing Requirements

All resources must have:
1. Basic CRUD tests
2. Validation tests
3. Organization isolation tests (using plain UUIDs, no Organization records)
4. Relationship tests (if applicable)

```elixir
# ✓ GOOD: Comprehensive test coverage (microservice pattern)
defmodule SertantaiLegal.YourDomain.YourResourceTest do
  use SertantaiLegal.DataCase

  describe "create/1" do
    test "creates resource with valid data" do
      # Note: organization_id is just a UUID, no Organization record needed
      org_id = Ash.UUID.generate()

      assert {:ok, resource} =
        YourResource
        |> Ash.Changeset.for_create(:create, %{
          name: "Test",
          organization_id: org_id
        })
        |> Ash.create()

      assert resource.name == "Test"
      assert resource.organization_id == org_id
    end

    test "requires organization_id" do
      assert {:error, %Ash.Error.Invalid{}} =
        YourResource
        |> Ash.Changeset.for_create(:create, %{name: "Test"})
        |> Ash.create()
    end

    test "enforces organization isolation" do
      org1_id = Ash.UUID.generate()
      org2_id = Ash.UUID.generate()

      resource = create_resource(organization_id: org1_id)

      # Should not be accessible from different org
      assert {:ok, []} =
        YourResource
        |> Ash.Query.for_read(:by_organization, %{organization_id: org2_id})
        |> Ash.read()
    end
  end
end
```

### Configuration

#### Environment Variables:

Required:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key base
- `SHARED_TOKEN_SECRET` - JWT validation secret (must match sertantai-auth)

Optional:
- `FRONTEND_URL` - CORS configuration
- `ELECTRIC_URL` - ElectricSQL service URL

#### Database Migrations:

Always use Ash generators:
```bash
# ✓ GOOD: Ash handles the schema
mix ash_postgres.generate_migrations --name add_feature

# ✗ BAD: Manual Ecto migrations (loses Ash context)
mix ecto.gen.migration add_feature
```

### Code Quality

All code must:
1. Pass Credo checks (no issues in strict mode)
2. Pass Dialyzer (no warnings)
3. Pass Sobelow security checks (no high-severity issues)
4. Be formatted with `mix format`
5. Have no compiler warnings

Pre-commit hooks enforce:
- Code formatting
- Credo checks
- Test suite passes

Pre-push hooks enforce:
- Dialyzer type checking
- Sobelow security analysis
- Full test suite with coverage

### Frontend Integration

When creating resources for frontend sync:

1. **Backend**: Add ElectricSQL grants in migration
```sql
ALTER TABLE your_resources REPLICA IDENTITY FULL;
ELECTRIC GRANT ALL ON your_resources TO ANYONE;
-- Or with RLS: WHERE organization_id = auth.organization_id()
```

2. **Frontend**: Create TanStack DB collection
```typescript
export const collections = {
  your_resources: {
    schema: {
      id: 'string',
      name: 'string',
      organization_id: 'string',
      inserted_at: 'string',
      updated_at: 'string'
    },
    primaryKey: 'id'
  }
}
```

3. **Frontend**: Set up sync
```typescript
syncCollection('your_resources', organizationId)
```

## Custom Rules

### Forbidden Patterns

❌ Direct Ecto queries bypassing Ash
❌ Resources without `organization_id` (except shared reference data like UK LRT)
❌ Storing sensitive data without encryption
❌ Skipping validation in actions
❌ Using `String.t()` instead of specific string constraints
❌ Database operations in controllers (use actions/changesets)
❌ Hard-coded organization IDs
❌ Creating User or Organization tables (this is a microservice!)
❌ Trusting organization_id from request params instead of JWT
❌ Validating JWTs anywhere except AuthPlug

### Required Patterns

✅ Use Ash Resource for all domain entities
✅ Include organization_id in all tenant-scoped tables
✅ Use UUID primary keys
✅ Include timestamps (inserted_at, updated_at)
✅ Define explicit actions (avoid `:all` in defaults)
✅ Use code_interface for common queries
✅ Scope all queries by organization_id from JWT
✅ Write tests for all actions
✅ Extract organization_id from JWT claims in AuthPlug
✅ Use SHARED_TOKEN_SECRET for JWT validation

## Microservice-Specific Rules

This is a microservice in the SertantAI ecosystem:

1. **No local auth**: User/Organization come from sertantai-auth via JWT
2. **JWT validation**: Use SHARED_TOKEN_SECRET (same across all services)
3. **organization_id**: Always from JWT claims, never from database
4. **Shared reference data**: UK LRT is shared (no organization_id)
5. **Tenant data**: Locations, Screenings scoped by organization_id

## Enforcement

Run usage rules check:
```bash
mix usage_rules.check
```

This is run automatically in CI and pre-commit hooks.
