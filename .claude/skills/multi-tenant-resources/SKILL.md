# SKILL: Multi-Tenant Resource Patterns

**Purpose:** Comprehensive guide for implementing organization-based multi-tenancy in Ash resources with proper data isolation

**Context:** Elixir + Ash Framework 3.0 + PostgreSQL + ElectricSQL + Multi-tenant SaaS architecture

**When to Use:**
- Creating any domain resource (except User/Organization)
- Implementing data isolation between organizations
- Setting up ElectricSQL sync with tenant filtering
- Testing organization-scoped queries
- Implementing authorization policies

---

## Core Principles

### 1. Organization is the Tenant Boundary

**Key Understanding:**
- Every organization owns their own data
- Users belong to one organization
- All domain data scoped by `organization_id`
- No cross-organization data access (except admins)

**Data Model:**
```
Organization (id: uuid)
  ├─→ User (organization_id: uuid)
  ├─→ Post (organization_id: uuid)
  ├─→ Comment (organization_id: uuid)
  └─→ [Your Domain Resource] (organization_id: uuid)
```

### 2. organization_id is NOT Updatable

**CRITICAL:** Once a resource is created with an `organization_id`, it can NEVER change.

**Why:**
- Moving data between organizations creates audit trails issues
- Can leak data if authorization checks fail
- Breaks ElectricSQL sync assumptions
- Violates data isolation guarantees

**Implementation:**
```elixir
create :create do
  accept [:title, :content, :organization_id]  # OK: Set on create
end

update :update do
  accept [:title, :content]  # NO organization_id - prevent updates
end
```

### 3. Every Query Must Filter by Organization

**Default behavior:**
```elixir
# ❌ BAD: Returns ALL posts across ALL organizations
Post.read()

# ✅ GOOD: Returns posts for ONE organization
Post.by_organization(org_id)
```

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Missing organization_id Attribute

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
- Data not isolated between tenants
- ElectricSQL can't filter by organization
- Violates usage rules
- Security vulnerability

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
  belongs_to :organization, MyApp.Auth.Organization do
    allow_nil? false
  end
end
```

### ❌ Pitfall 2: organization_id is Updatable

**WRONG:**
```elixir
update :update do
  accept [:title, :content, :organization_id]  # ← DANGER!
end
```

**Why it's dangerous:**
```elixir
# User from Org A could move data to Org B!
Post.update(post_id, %{organization_id: other_org_id})
# This breaks data isolation
```

**✅ Correct Pattern:**
```elixir
create :create do
  accept [:title, :content, :organization_id]  # Set once on create
end

update :update do
  accept [:title, :content]  # NO organization_id
end
```

### ❌ Pitfall 3: Unscoped Read Actions

**WRONG:**
```elixir
actions do
  defaults [:read, :create, :update, :destroy]
  # Default :read has NO organization filter!
end
```

**Why it's problematic:**
```elixir
# Returns ALL posts from ALL organizations
{:ok, posts} = Post.read()
# Security breach!
```

**✅ Correct Pattern:**
```elixir
actions do
  # Keep default :read for admin use (with authorization)
  defaults [:read, :destroy]

  create :create do
    accept [:title, :organization_id]
  end

  update :update do
    accept [:title]
  end

  # Primary read action: scoped by organization
  read :by_organization do
    argument :organization_id, :uuid, allow_nil?: false
    filter expr(organization_id == ^arg(:organization_id))

    # Make this the primary read for non-admins
    primary? true
  end

  # For lists scoped to organization
  read :list do
    argument :organization_id, :uuid, allow_nil?: false
    filter expr(organization_id == ^arg(:organization_id))
    pagination offset: true, keyset: true, default_limit: 25
  end
end
```

### ❌ Pitfall 4: Missing Organization Relationship

**WRONG:**
```elixir
attributes do
  attribute :organization_id, :uuid, allow_nil?: false
end

# Missing belongs_to relationship!
```

**Why it's incomplete:**
- Can't load organization data
- Harder to query across relationships
- Loses referential integrity benefits

**✅ Correct Pattern:**
```elixir
attributes do
  attribute :organization_id, :uuid, allow_nil?: false
end

relationships do
  belongs_to :organization, MyApp.Auth.Organization do
    allow_nil? false
    attribute_writable? true  # Can set in create action
  end
end
```

### ❌ Pitfall 5: Forgetting to Test Organization Isolation

**WRONG:**
```elixir
test "creates post" do
  # Only tests that creation works
  # Doesn't verify organization isolation
  {:ok, post} = create_post()
  assert post.title == "Test"
end
```

**✅ Correct Pattern:**
```elixir
test "organization isolation" do
  org1 = create_organization()
  org2 = create_organization()

  # Create posts in different organizations
  post1 = create_post(organization_id: org1.id, title: "Org 1 Post")
  post2 = create_post(organization_id: org2.id, title: "Org 2 Post")

  # Query org1 - should only see org1's post
  {:ok, org1_posts} = Post.by_organization(org1.id)
  assert length(org1_posts) == 1
  assert hd(org1_posts).id == post1.id

  # Query org2 - should only see org2's post
  {:ok, org2_posts} = Post.by_organization(org2.id)
  assert length(org2_posts) == 1
  assert hd(org2_posts).id == post2.id
end
```

---

## Complete Working Pattern

### Step 1: Define Multi-Tenant Resource

```elixir
defmodule MyApp.Blog.Post do
  @moduledoc """
  Blog post resource with organization-based multi-tenancy.
  All posts are scoped to a single organization.
  """

  use Ash.Resource,
    domain: MyApp.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :content, :string do
      allow_nil? true
    end

    # CRITICAL: Organization scoping
    attribute :organization_id, :uuid do
      allow_nil? false
      # Cannot be changed after creation
      writable? :create
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    # Required relationship to organization
    belongs_to :organization, MyApp.Auth.Organization do
      allow_nil? false
      attribute_writable? true
    end

    # Posts belong to user (who belongs to organization)
    belongs_to :author, MyApp.Auth.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:destroy]

    # Allow default read for admin use only
    read :read do
      # Add authorization policy
      # authorize_if actor_attribute_equals(:is_admin, true)
    end

    create :create do
      accept [:title, :content, :organization_id, :author_id]

      # Validate author belongs to same organization
      validate fn changeset, _context ->
        author_id = Ash.Changeset.get_attribute(changeset, :author_id)
        org_id = Ash.Changeset.get_attribute(changeset, :organization_id)

        case MyApp.Auth.User.by_id(author_id) do
          {:ok, user} ->
            if user.organization_id == org_id do
              :ok
            else
              {:error, field: :author_id, message: "must belong to same organization"}
            end

          _ ->
            :ok  # Will fail on foreign key constraint
        end
      end
    end

    update :update do
      # NO organization_id - prevent updates
      accept [:title, :content]
    end

    # PRIMARY read action: by organization
    read :by_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
      primary? true
    end

    # Read with pagination
    read :list do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
      pagination offset: true, keyset: true, default_limit: 25
    end

    # Read single post (still scoped to organization for security)
    read :get do
      argument :id, :uuid, allow_nil?: false
      argument :organization_id, :uuid, allow_nil?: false
      get? true

      filter expr(
        id == ^arg(:id) and
        organization_id == ^arg(:organization_id)
      )
    end
  end

  code_interface do
    define :create
    define :update, args: [:id]
    define :destroy, args: [:id]
    define :by_organization, args: [:organization_id]
    define :list, args: [:organization_id]
    define :get, args: [:id, :organization_id]
  end
end
```

### Step 2: Generate Migration with Indexes

```bash
mix ash_postgres.generate_migrations --name add_posts
```

**Review migration** (should include organization_id index):
```elixir
defmodule MyApp.Repo.Migrations.AddPosts do
  use Ecto.Migration

  def up do
    create table(:posts, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :title, :text, null: false
      add :content, :text
      add :organization_id, :uuid, null: false
      add :author_id, :uuid, null: false
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    # CRITICAL: Index on organization_id for fast scoped queries
    create index(:posts, [:organization_id])

    # Foreign key constraints ensure referential integrity
    create constraint(:posts, :fk_organization_id,
      foreign_key: [:organization_id],
      references: :organizations,
      on_delete: :delete_all  # or :restrict
    )

    create constraint(:posts, :fk_author_id,
      foreign_key: [:author_id],
      references: :users,
      on_delete: :delete_all  # or :restrict
    )
  end

  def down do
    drop table(:posts)
  end
end
```

### Step 3: Comprehensive Tests

```elixir
defmodule MyApp.Blog.PostTest do
  use MyApp.DataCase
  alias MyApp.Blog.Post

  describe "create/1" do
    test "creates post with organization_id" do
      org = create_organization()
      user = create_user(organization_id: org.id)

      assert {:ok, post} =
        Post.create(%{
          title: "Test Post",
          content: "Content",
          organization_id: org.id,
          author_id: user.id
        })

      assert post.organization_id == org.id
    end

    test "requires organization_id" do
      user = create_user()

      assert {:error, %Ash.Error.Invalid{}} =
        Post.create(%{
          title: "Test",
          author_id: user.id
        })
    end

    test "validates author belongs to same organization" do
      org1 = create_organization()
      org2 = create_organization()
      user = create_user(organization_id: org2.id)

      # Try to create post in org1 with author from org2
      assert {:error, error} =
        Post.create(%{
          title: "Test",
          organization_id: org1.id,
          author_id: user.id
        })

      assert error.errors
             |> Enum.any?(fn e ->
               String.contains?(e.message, "must belong to same organization")
             end)
    end
  end

  describe "update/1" do
    test "updates post attributes but NOT organization_id" do
      org = create_organization()
      user = create_user(organization_id: org.id)
      post = create_post(organization_id: org.id, author_id: user.id)

      # Update should work
      assert {:ok, updated} = Post.update(post.id, %{title: "Updated"})
      assert updated.title == "Updated"
      assert updated.organization_id == org.id  # Unchanged

      # Attempting to update organization_id should be ignored
      # (because it's not in the accept list)
    end
  end

  describe "by_organization/1" do
    test "returns only posts for specified organization" do
      org1 = create_organization()
      org2 = create_organization()
      user1 = create_user(organization_id: org1.id)
      user2 = create_user(organization_id: org2.id)

      post1 = create_post(organization_id: org1.id, author_id: user1.id)
      post2 = create_post(organization_id: org1.id, author_id: user1.id)
      _post3 = create_post(organization_id: org2.id, author_id: user2.id)

      {:ok, org1_posts} = Post.by_organization(org1.id)

      assert length(org1_posts) == 2
      assert Enum.all?(org1_posts, &(&1.organization_id == org1.id))
      assert Enum.map(org1_posts, & &1.id) |> Enum.sort() ==
               [post1.id, post2.id] |> Enum.sort()
    end

    test "returns empty list for organization with no posts" do
      org = create_organization()

      {:ok, posts} = Post.by_organization(org.id)

      assert posts == []
    end
  end

  describe "get/2 (organization-scoped single read)" do
    test "returns post when organization matches" do
      org = create_organization()
      user = create_user(organization_id: org.id)
      post = create_post(organization_id: org.id, author_id: user.id)

      {:ok, found} = Post.get(post.id, org.id)

      assert found.id == post.id
    end

    test "returns error when organization doesn't match" do
      org1 = create_organization()
      org2 = create_organization()
      user = create_user(organization_id: org1.id)
      post = create_post(organization_id: org1.id, author_id: user.id)

      # Try to get org1's post using org2's id
      assert {:error, %Ash.Error.Query.NotFound{}} =
               Post.get(post.id, org2.id)
    end
  end

  describe "organization isolation (comprehensive)" do
    test "complete isolation between organizations" do
      # Set up two organizations with users and posts
      org1 = create_organization(name: "Org 1")
      org2 = create_organization(name: "Org 2")

      user1 = create_user(organization_id: org1.id, email: "user1@org1.com")
      user2 = create_user(organization_id: org2.id, email: "user2@org2.com")

      post1a = create_post(organization_id: org1.id, author_id: user1.id, title: "Post 1A")
      post1b = create_post(organization_id: org1.id, author_id: user1.id, title: "Post 1B")
      post2a = create_post(organization_id: org2.id, author_id: user2.id, title: "Post 2A")

      # Verify org1 can only see org1 posts
      {:ok, org1_posts} = Post.by_organization(org1.id)
      assert length(org1_posts) == 2
      assert Enum.all?(org1_posts, &(&1.organization_id == org1.id))

      # Verify org2 can only see org2 posts
      {:ok, org2_posts} = Post.by_organization(org2.id)
      assert length(org2_posts) == 1
      assert hd(org2_posts).organization_id == org2.id
      assert hd(org2_posts).id == post2a.id

      # Verify can't access other org's posts
      assert {:error, _} = Post.get(post2a.id, org1.id)
      assert {:error, _} = Post.get(post1a.id, org2.id)
    end
  end
end
```

---

## Authorization Patterns

### Pattern 1: Implicit Organization Filtering

```elixir
# In controller or API
def list_posts(conn, _params) do
  current_user = conn.assigns.current_user
  org_id = current_user.organization_id

  # Automatically scoped to user's organization
  {:ok, posts} = Post.by_organization(org_id)

  render(conn, "index.json", posts: posts)
end
```

### Pattern 2: Explicit Organization Check

```elixir
def show_post(conn, %{"id" => post_id}) do
  current_user = conn.assigns.current_user
  org_id = current_user.organization_id

  # Will only return post if it belongs to user's organization
  case Post.get(post_id, org_id) do
    {:ok, post} ->
      render(conn, "show.json", post: post)

    {:error, _} ->
      send_resp(conn, 404, "Not found")
  end
end
```

### Pattern 3: Ash Policies (Advanced)

```elixir
policies do
  policy action_type(:read) do
    authorize_if expr(organization_id == ^actor(:organization_id))
  end

  policy action_type(:create) do
    authorize_if expr(organization_id == ^actor(:organization_id))
  end

  policy action_type([:update, :destroy]) do
    authorize_if expr(
      organization_id == ^actor(:organization_id) and
      author_id == ^actor(:id)
    )
  end
end
```

---

## ElectricSQL Integration

### Migration with ELECTRIC GRANT

```elixir
def up do
  create table(:posts, primary_key: false) do
    # ... columns ...
  end

  # Enable ElectricSQL sync
  execute "ALTER TABLE posts REPLICA IDENTITY FULL"

  # Grant with organization filtering
  execute """
  ELECTRIC GRANT SELECT ON posts
  TO AUTHENTICATED
  WHERE organization_id = auth.organization_id()
  """

  # Or for development (less secure):
  # execute "ELECTRIC GRANT ALL ON posts TO ANYONE"
end
```

### Frontend Subscription (Organization-Filtered)

```typescript
// frontend/src/lib/electric/sync.ts
import { ShapeStream } from '@electric-sql/client'

export async function syncPosts(organizationId: string) {
  const stream = new ShapeStream({
    url: `${PUBLIC_ELECTRIC_URL}/v1/shape`,
    params: {
      table: 'posts',
      where: `organization_id='${organizationId}'`  // ← Organization filter
    }
  })

  stream.subscribe((messages) => {
    // Only receives posts for this organization
    db.collections.posts.load(messages)
  })
}
```

---

## Quick Reference

### Checklist for Multi-Tenant Resources

- [ ] Includes `organization_id` attribute (`allow_nil?: false`)
- [ ] Has `belongs_to :organization` relationship
- [ ] organization_id is NOT in update action's accept list
- [ ] Has `by_organization` read action with filter
- [ ] Includes index on organization_id in migration
- [ ] Tests organization isolation
- [ ] Uses organization-scoped queries in controllers
- [ ] ElectricSQL grants filter by organization (if syncing)

### Code Template

```elixir
attributes do
  uuid_primary_key :id
  attribute :organization_id, :uuid, allow_nil?: false
  create_timestamp :inserted_at
  update_timestamp :updated_at
end

relationships do
  belongs_to :organization, MyApp.Auth.Organization, allow_nil?: false
end

actions do
  create :create do
    accept [:organization_id, ...]
  end

  update :update do
    accept [...]  # NO organization_id
  end

  read :by_organization do
    argument :organization_id, :uuid, allow_nil?: false
    filter expr(organization_id == ^arg(:organization_id))
  end
end
```

---

## Related Skills

- **Creating Ash Resources**: `.claude/skills/creating-ash-resources/` - Basic resource creation
- **ElectricSQL Sync**: `.claude/skills/electricsql-sync-setup/` - Real-time sync with tenant filtering

---

## Key Takeaways

1. ✅ **Every domain resource** must include `organization_id`
2. ✅ **organization_id is immutable** after creation
3. ✅ **Always filter queries** by organization
4. ✅ **Index organization_id** for performance
5. ✅ **Test organization isolation** thoroughly
6. ✅ **Use scoped read actions** as primary
7. ✅ **Validate cross-resource** organization consistency
8. ❌ **Never allow** organization_id updates
9. ❌ **Never query** without organization filter (except admin)
10. ❌ **Never expose** unscoped read actions to non-admins
