# SKILL: Creating Ash Resources

**Purpose:** Complete guide for creating new domain resources using Ash Framework 3.0 with PostgreSQL and multi-tenancy

**Context:** Elixir + Phoenix + Ash Framework 3.0 + PostgreSQL + Multi-tenant architecture

**When to Use:**
- Adding new domain entities to your application
- Creating resources that need CRUD operations
- Setting up resources for ElectricSQL sync
- Implementing organization-scoped data

---

## Core Principles

### 1. Ash is Declarative, Not Imperative

**Key Understanding:**
- Resources are DEFINED, not programmed
- Actions are DECLARED, not implemented
- Validations are CONSTRAINTS, not code
- Ash generates the implementation from your declarations

**This means:**
```elixir
# You write THIS (declarative)
attribute :email, :string do
  allow_nil? false
end

# Ash generates THIS (imperative)
# - Database column
# - Validation logic
# - Type casting
# - Error messages
```

### 2. Data Layer Determines Storage

**AshPostgres.DataLayer:**
- Stores data in PostgreSQL
- Generates migrations via `mix ash_postgres.generate_migrations`
- Supports all PostgreSQL features (constraints, indexes, triggers)

**Resource Structure:**
```elixir
use Ash.Resource,
  domain: YourApp.Api,              # Which domain owns this resource
  data_layer: AshPostgres.DataLayer # How/where data is stored
```

### 3. Multi-Tenancy is Mandatory

**CRITICAL:** All domain resources MUST include `organization_id` for data isolation.

**Only exceptions:**
- `User` resource (belongs to organization)
- `Organization` resource (is the tenant)

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Using `:text` Type

**WRONG:**
```elixir
attribute :description, :text  # :text type doesn't exist in Ash!
```

**Why it fails:**
- Ash uses `:string` for all text data
- `:text` is a PostgreSQL-specific type
- Ash abstracts database types

**✅ Correct Pattern:**
```elixir
attribute :description, :string do
  allow_nil? false
end
```

### ❌ Pitfall 2: Missing organization_id

**WRONG:**
```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource, ...

  attributes do
    uuid_primary_key :id
    attribute :title, :string
    # Missing organization_id!
  end
end
```

**Why it fails:**
- Violates multi-tenancy requirement
- Data not properly isolated
- ElectricSQL sync won't filter correctly
- Fails `usage_rules.check`

**✅ Correct Pattern:**
```elixir
attributes do
  uuid_primary_key :id
  attribute :title, :string, allow_nil?: false
  attribute :organization_id, :uuid, allow_nil?: false  # ← REQUIRED
  create_timestamp :inserted_at
  update_timestamp :updated_at
end

relationships do
  belongs_to :organization, MyApp.Auth.Organization
end
```

### ❌ Pitfall 3: Using Ecto.Schema Instead of Ash.Resource

**WRONG:**
```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema  # ← NO! Use Ash!

  schema "posts" do
    field :title, :string
    timestamps()
  end
end
```

**Why it fails:**
- Bypasses Ash framework benefits
- No automatic actions, validations, or authorization
- Can't use Ash's declarative features
- Violates project usage rules

**✅ Correct Pattern:**
```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
```

### ❌ Pitfall 4: Forgetting to Register Resource in Domain

**WRONG:**
```elixir
# You created lib/my_app/blog/post.ex
# But didn't update lib/my_app/api.ex

defmodule MyApp.Api do
  use Ash.Domain

  resources do
    resource MyApp.Auth.User
    resource MyApp.Auth.Organization
    # Missing: resource MyApp.Blog.Post
  end
end
```

**Why it fails:**
```
** (RuntimeError) No such resource MyApp.Blog.Post
```

**✅ Correct Pattern:**
```elixir
defmodule MyApp.Api do
  use Ash.Domain

  resources do
    resource MyApp.Auth.User
    resource MyApp.Auth.Organization
    resource MyApp.Blog.Post  # ← Must register here!
  end
end
```

### ❌ Pitfall 5: Using `:all` in Default Actions

**WRONG:**
```elixir
actions do
  defaults [:all]  # Too permissive!
end
```

**Why it's problematic:**
- Exposes all CRUD operations without control
- Can't customize individual actions
- Security risk (unintended mutations)
- Violates usage rules

**✅ Correct Pattern:**
```elixir
actions do
  defaults [:read, :destroy]  # Be explicit

  create :create do
    accept [:title, :content, :organization_id]
    # Custom logic if needed
  end

  update :update do
    accept [:title, :content]
    # organization_id should NOT be updatable
  end
end
```

---

## Complete Working Pattern

### Step 1: Create Resource File

```bash
# Create file: lib/my_app/blog/post.ex
mkdir -p lib/my_app/blog
touch lib/my_app/blog/post.ex
```

### Step 2: Define Resource

```elixir
defmodule MyApp.Blog.Post do
  @moduledoc """
  Blog post resource for content management.
  Scoped by organization for multi-tenancy.
  """

  use Ash.Resource,
    domain: MyApp.Api,
    data_layer: AshPostgres.DataLayer

  # PostgreSQL configuration
  postgres do
    table "posts"
    repo MyApp.Repo
  end

  # Attributes (columns)
  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :content, :string do
      allow_nil? true
    end

    attribute :published, :boolean do
      allow_nil? false
      default false
    end

    # REQUIRED: Organization scoping
    attribute :organization_id, :uuid do
      allow_nil? false
    end

    # Timestamps
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # Relationships
  relationships do
    belongs_to :organization, MyApp.Auth.Organization do
      allow_nil? false
    end

    # Example: Posts can have an author
    belongs_to :author, MyApp.Auth.User do
      allow_nil? false
    end
  end

  # Actions (what you can do with this resource)
  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :content, :published, :organization_id, :author_id]

      # Optional: Add validation
      validate attribute_does_not_equal(:title, "")
    end

    update :update do
      accept [:title, :content, :published]
      # Note: organization_id NOT updatable (prevent data leaks)
    end

    # Custom read action: by organization
    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end

    # Custom read action: published posts only
    read :published do
      filter expr(published == true)
    end

    # Custom update action: publish
    update :publish do
      accept []
      change set_attribute(:published, true)
    end
  end

  # Code interface (for calling actions programmatically)
  code_interface do
    define :read
    define :create
    define :update
    define :destroy
    define :by_organization, args: [:organization_id]
    define :published
    define :publish, args: [:id]
  end

  # Validations
  validations do
    validate present(:title)
    validate string_length(:title, min: 1, max: 255)
  end
end
```

### Step 3: Register in Domain

```elixir
# lib/my_app/api.ex
defmodule MyApp.Api do
  use Ash.Domain

  resources do
    resource MyApp.Auth.User
    resource MyApp.Auth.Organization
    resource MyApp.Blog.Post  # ← Add your new resource
  end
end
```

### Step 4: Generate Migration

```bash
cd backend
mix ash_postgres.generate_migrations --name add_posts
```

**Review the generated migration:**
```elixir
# priv/repo/migrations/TIMESTAMP_add_posts.exs
defmodule MyApp.Repo.Migrations.AddPosts do
  use Ecto.Migration

  def up do
    create table(:posts, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :title, :text, null: false
      add :content, :text
      add :published, :boolean, default: false, null: false
      add :organization_id, :uuid, null: false
      add :author_id, :uuid, null: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    # Indexes for common queries
    create index(:posts, [:organization_id])
    create index(:posts, [:author_id])
    create index(:posts, [:published])
  end

  def down do
    drop table(:posts)
  end
end
```

### Step 5: Run Migration

```bash
mix ash_postgres.migrate
```

### Step 6: Test the Resource

```elixir
# test/my_app/blog/post_test.exs
defmodule MyApp.Blog.PostTest do
  use MyApp.DataCase
  alias MyApp.Blog.Post

  describe "create/1" do
    test "creates post with valid data" do
      org = create_organization()
      user = create_user(organization_id: org.id)

      assert {:ok, post} =
        Post
        |> Ash.Changeset.for_create(:create, %{
          title: "Test Post",
          content: "Test content",
          published: false,
          organization_id: org.id,
          author_id: user.id
        })
        |> Ash.create()

      assert post.title == "Test Post"
      assert post.organization_id == org.id
      assert post.published == false
    end

    test "requires title" do
      org = create_organization()
      user = create_user(organization_id: org.id)

      assert {:error, %Ash.Error.Invalid{}} =
        Post
        |> Ash.Changeset.for_create(:create, %{
          content: "Test content",
          organization_id: org.id,
          author_id: user.id
        })
        |> Ash.create()
    end

    test "requires organization_id" do
      user = create_user()

      assert {:error, %Ash.Error.Invalid{}} =
        Post
        |> Ash.Changeset.for_create(:create, %{
          title: "Test",
          author_id: user.id
        })
        |> Ash.create()
    end
  end

  describe "by_organization/1" do
    test "returns only posts for specified organization" do
      org1 = create_organization()
      org2 = create_organization()
      user1 = create_user(organization_id: org1.id)
      user2 = create_user(organization_id: org2.id)

      post1 = create_post(organization_id: org1.id, author_id: user1.id)
      _post2 = create_post(organization_id: org2.id, author_id: user2.id)

      assert {:ok, posts} =
        Post
        |> Ash.Query.for_read(:by_organization, %{organization_id: org1.id})
        |> Ash.read()

      assert length(posts) == 1
      assert hd(posts).id == post1.id
    end
  end
end
```

---

## Resource Attribute Types

### Common Attribute Types

```elixir
# String (for all text)
attribute :name, :string

# Integer
attribute :count, :integer

# Boolean
attribute :active, :boolean

# UUID
attribute :external_id, :uuid

# Decimal (for money, precise numbers)
attribute :price, :decimal

# Date/Time types
attribute :published_at, :utc_datetime_usec
attribute :birth_date, :date

# Map (JSON-like data)
attribute :metadata, :map

# Array
attribute :tags, {:array, :string}
```

### Attribute Options

```elixir
attribute :email, :string do
  allow_nil? false          # Required field
  public? true              # Visible in API responses
  private? false            # Hidden from API
  writable? true            # Can be set via actions
  default "example@test.com"  # Default value
  constraints [
    min_length: 5,
    max_length: 255,
    match: ~r/@/
  ]
end
```

---

## Action Patterns

### Create Action

```elixir
create :create do
  accept [:title, :content, :organization_id]

  # Set default values
  change set_attribute(:published, false)

  # Validate
  validate present(:title)

  # Argument (not stored)
  argument :send_notification, :boolean, default: false

  # Custom change
  change fn changeset, _context ->
    if Ash.Changeset.get_argument(changeset, :send_notification) do
      # Send notification logic
    end
    changeset
  end
end
```

### Update Action

```elixir
update :update do
  accept [:title, :content]

  # Require actor (for authorization)
  require_atomic? false
end
```

### Read Action

```elixir
read :by_status do
  argument :status, :string, allow_nil?: false
  filter expr(status == ^arg(:status))

  # Pagination
  pagination offset: true, keyset: true, default_limit: 25
end
```

### Destroy Action

```elixir
destroy :archive do
  # Soft delete
  change set_attribute(:archived_at, &DateTime.utc_now/0)
  change set_attribute(:archived, true)

  # Prevent hard delete
  soft? true
end
```

---

## Relationships

### belongs_to

```elixir
relationships do
  belongs_to :author, MyApp.Auth.User do
    allow_nil? false
    attribute_writable? true  # Can set author_id in create
  end
end
```

### has_many

```elixir
relationships do
  has_many :comments, MyApp.Blog.Comment do
    destination_attribute :post_id
  end
end
```

### many_to_many

```elixir
relationships do
  many_to_many :tags, MyApp.Blog.Tag do
    through MyApp.Blog.PostTag
    source_attribute_on_join_resource :post_id
    destination_attribute_on_join_resource :tag_id
  end
end
```

---

## Code Interface

**Purpose:** Call actions programmatically without building changesets manually.

```elixir
code_interface do
  define :create
  define :read
  define :by_organization, args: [:organization_id]
  define :update, args: [:id]
  define :destroy, args: [:id]
end
```

**Usage:**
```elixir
# With code interface
{:ok, post} = Post.create(%{title: "Test", organization_id: org_id})

# Without code interface (more verbose)
{:ok, post} =
  Post
  |> Ash.Changeset.for_create(:create, %{title: "Test", organization_id: org_id})
  |> Ash.create()
```

---

## Quick Reference

### Essential Commands

```bash
# Generate migration from Ash resources
mix ash_postgres.generate_migrations --name <description>

# Run migrations
mix ash_postgres.migrate

# Rollback
mix ash_postgres.rollback

# Check usage rules
mix usage_rules.check

# Format code
mix format
```

### Minimum Resource Template

```elixir
defmodule MyApp.Domain.Resource do
  use Ash.Resource,
    domain: MyApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "resources"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :organization_id, :uuid, allow_nil?: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, MyApp.Auth.Organization
  end

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

---

## Troubleshooting

### Error: "no function clause matching in Ash.DataLayer.data_layer/1"

**Check:**
- Is `data_layer: AshPostgres.DataLayer` specified?

**Fix:**
```elixir
use Ash.Resource,
  domain: MyApp.Api,
  data_layer: AshPostgres.DataLayer  # ← Add this
```

### Error: "Could not find resource MyApp.Blog.Post"

**Check:**
- Is resource registered in domain (`lib/my_app/api.ex`)?

**Fix:**
```elixir
resources do
  resource MyApp.Blog.Post  # ← Add this
end
```

### Error: "type :text does not exist"

**Check:**
- Are you using `:text` type?

**Fix:**
```elixir
attribute :content, :string  # Use :string, not :text
```

### Migration generates wrong column type

**Check:**
- Did you use correct Ash type?
- Ash maps types to PostgreSQL automatically

**Common mappings:**
- `:string` → `text` in PostgreSQL
- `:integer` → `bigint`
- `:uuid` → `uuid`

---

## Related Skills

- **Multi-Tenant Resources**: `.claude/skills/multi-tenant-resources/` - Organization scoping patterns
- **ElectricSQL Sync**: `.claude/skills/electricsql-sync-setup/` - Enable real-time sync

---

## Key Takeaways

1. ✅ **Always use** `Ash.Resource`, never `Ecto.Schema`
2. ✅ **Always include** `organization_id` (except User/Organization)
3. ✅ **Always use** `:string` for text, not `:text`
4. ✅ **Always register** resources in domain
5. ✅ **Always use** `mix ash_postgres.generate_migrations`
6. ✅ **Always test** organization isolation
7. ✅ **Be explicit** with actions (avoid `:all`)
8. ❌ **Never bypass** Ash with direct Ecto queries
9. ❌ **Never make** `organization_id` updatable
10. ❌ **Never skip** timestamps
