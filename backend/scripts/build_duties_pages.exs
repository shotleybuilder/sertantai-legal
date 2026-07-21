# Build the Legal Duties pages on the Compliance Workbench app.
#
# Two pages:
# 1. /duties?law=LAW_NAME — table of duties filtered by law, with Controls link
# 2. /duty/:id — detail view of a single duty (provision text, actors, Controls)
#
# Linked from Legal Register page → /duties?law=LAW_NAME
#
# ## Manual Steps After Running
#
# 1.  Set "Details" link text in duties table config
# 2.  Set "Controls" link text in duties table config
# 3.  Set "Edit Action" data source Row ID to: Query parameter > edit (on detail page)
# 4.  Add link from Legal Register page to Duties page
# 5.  Re-publish
#
# ## Usage
#
#   mix run scripts/build_duties_pages.exs

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

lat_table_id = sc.target_config["lat_table_id"]
cm_table_id = sc.target_config["control_mappings_table_id"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

IO.puts("=== Legal Duties Pages Builder ===\n")

# ── Find builder app and integration ────────────────────

{:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
builder = Enum.find(apps, fn a -> a["type"] == "builder" end)
builder_id = builder["id"]

{:ok, %{body: integrations}} = Req.get("#{base}/api/application/#{builder_id}/integrations/",
  headers: headers, receive_timeout: 15_000)
integration_id = hd(integrations)["id"]

IO.puts("App: #{builder["name"]} (#{builder_id})")

# ── Get field IDs ───────────────────────────────────────

{:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, lat_table_id)
f = Map.new(fields, fn field -> {field["name"], field["id"]} end)

IO.puts("Duties fields: Name=#{f["Name"]} Type=#{f["Type"]} Provision=#{f["Provision"]} Text=#{f["Provision_Text"]} Significance=#{f["Significance"]} LR=#{f["Legal_Register"]} CM=#{f["Control Mappings"]} Actors=#{f["Actors"]}")

# ── Find or create pages ────────────────────────────────

pages = builder["pages"] |> Enum.reject(fn p -> p["shared"] end)

# Page 1: Duties list
duties_page =
  case Enum.find(pages, fn p -> p["path"] == "/duties" end) do
    nil ->
      IO.puts("Creating Duties page...")
      {:ok, %{body: page}} = Req.post("#{base}/api/builder/#{builder_id}/pages/",
        headers: headers,
        json: %{"name" => "Legal Duties", "path" => "/duties"},
        receive_timeout: 15_000)
      page
    existing ->
      IO.puts("Found duties page: #{existing["id"]}")
      existing
  end

# Add query param for law filter
{:ok, _} = Req.patch("#{base}/api/builder/pages/#{duties_page["id"]}/",
  headers: headers,
  json: %{"query_params" => [%{"name" => "law", "type" => "text"}]},
  receive_timeout: 15_000)

# Page 2: Duty detail
detail_page =
  case Enum.find(pages, fn p -> p["path"] != nil and String.contains?(p["path"], "/duty/") end) do
    nil ->
      IO.puts("Creating Duty Detail page...")
      {:ok, %{body: page}} = Req.post("#{base}/api/builder/#{builder_id}/pages/",
        headers: headers,
        json: %{"name" => "Duty Detail", "path" => "/duty/:id",
          "path_params" => [%{"name" => "id", "type" => "numeric"}]},
        receive_timeout: 15_000)
      page
    existing ->
      IO.puts("Found detail page: #{existing["id"]}")
      existing
  end

duties_page_id = duties_page["id"]
detail_page_id = detail_page["id"]

IO.puts("Duties page: #{duties_page_id}, Detail page: #{detail_page_id}")

# Find Controls page for linking
controls_page = Enum.find(pages, fn p -> p["path"] == "/actions" end)
# Actually we don't have a Controls page — Control Mappings are in the grid view
# Link to the ControlMappings table view isn't possible from App Builder
# For now, just show Controls count/names in the detail view

# ── Check if pages already have elements ────────────────

{:ok, %{body: existing_els}} = Req.get("#{base}/api/builder/page/#{duties_page_id}/elements/",
  headers: headers, receive_timeout: 15_000)

if length(existing_els) > 0 do
  IO.puts("Duties page already has #{length(existing_els)} elements — skipping")
else
  # ── PAGE 1: Duties List ─────────────────────────────────

  IO.puts("\n--- Building Duties List Page ---")

  # Data source: List duties (will be filtered by law query param in UI)
  {:ok, %{body: list_ds}} = Req.post("#{base}/api/builder/page/#{duties_page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Duties", "type" => "local_baserow_list_rows",
      "integration_id" => integration_id, "table_id" => lat_table_id},
    receive_timeout: 15_000)
  IO.puts("  Duties DS: #{list_ds["id"]}")

  # Heading
  Req.post!("#{base}/api/builder/page/#{duties_page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => duties_page_id,
      "value" => formula.("\"Legal Duties\""), "level" => 1})

  # Back to Legal Register link
  lr_page = Enum.find(pages, fn p -> p["path"] == "/" end)
  Req.post!("#{base}/api/builder/page/#{duties_page_id}/elements/",
    headers: headers,
    json: %{"type" => "link", "page_id" => duties_page_id,
      "value" => formula.("\"← Legal Register\""),
      "navigate_to_page_id" => lr_page["id"], "navigation_type" => "page"})

  # Table element
  {:ok, %{body: table_el}} = Req.post("#{base}/api/builder/page/#{duties_page_id}/elements/",
    headers: headers,
    json: %{"type" => "table", "page_id" => duties_page_id,
      "data_source_id" => list_ds["id"], "items_per_page" => 25,
      "is_publicly_filterable" => true, "is_publicly_sortable" => true,
      "is_publicly_searchable" => true})
  IO.puts("  Table: #{table_el["id"]}")

  # Table columns
  table_fields = [
    %{"name" => "Provision", "type" => "text",
      "value" => formula.("get('current_record.field_#{f["Provision"]}')")},
    %{"name" => "Type", "type" => "text",
      "value" => formula.("get('current_record.field_#{f["Type"]}.*.value')")},
    %{"name" => "Actors", "type" => "text",
      "value" => formula.("get('current_record.field_#{f["Regulated_Actors"]}.*.value')")},
    %{"name" => "Significance", "type" => "text",
      "value" => formula.("get('current_record.field_#{f["Significance"]}.value')")},
    %{"name" => "Controls", "type" => "text",
      "value" => formula.("get('current_record.field_#{f["Control Mappings"]}.*.value')")},
    %{"name" => "Details", "type" => "link",
      "navigate_to_page_id" => detail_page_id,
      "navigation_type" => "page",
      "page_parameters" => [%{"name" => "id",
        "value" => "get('current_record.id')"}]}
  ]

  {:ok, %{status: ts}} = Req.patch("#{base}/api/builder/element/#{table_el["id"]}/",
    headers: headers, json: %{"fields" => table_fields}, receive_timeout: 15_000)
  IO.puts("  Columns: #{ts}")
end

# ── PAGE 2: Duty Detail ─────────────────────────────────

{:ok, %{body: detail_els}} = Req.get("#{base}/api/builder/page/#{detail_page_id}/elements/",
  headers: headers, receive_timeout: 15_000)

if length(detail_els) > 0 do
  IO.puts("Detail page already has #{length(detail_els)} elements — skipping")
else
  IO.puts("\n--- Building Duty Detail Page ---")

  # Data source: Get single duty
  {:ok, %{body: detail_ds}} = Req.post("#{base}/api/builder/page/#{detail_page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Current Duty", "type" => "local_baserow_get_row",
      "integration_id" => integration_id, "table_id" => lat_table_id},
    receive_timeout: 15_000)
  IO.puts("  Detail DS: #{detail_ds["id"]} (Row ID must be set manually: Path parameter > id)")

  ds_id = detail_ds["id"]

  # Back link to duties list
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "link", "page_id" => detail_page_id,
      "value" => formula.("\"← Back to Duties\""),
      "navigate_to_page_id" => duties_page_id, "navigation_type" => "page"})

  # Provision heading
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => detail_page_id,
      "value" => formula.("get('data_source.#{ds_id}.field_#{f["Provision"]}')"),
      "level" => 2})

  # Classification row: Type + Significance + Gravity + Strength
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "text", "page_id" => detail_page_id,
      "value" => formula.("concat('Type: ', get('data_source.#{ds_id}.field_#{f["Type"]}.*.value'), ' | Significance: ', get('data_source.#{ds_id}.field_#{f["Significance"]}.value'), ' | Gravity: ', get('data_source.#{ds_id}.field_#{f["Gravity"]}.value'), ' | Strength: ', get('data_source.#{ds_id}.field_#{f["Strength"]}.value'))")})

  # Actors
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => detail_page_id,
      "value" => formula.("\"Regulated Actors\""), "level" => 3})

  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "text", "page_id" => detail_page_id,
      "value" => formula.("get('data_source.#{ds_id}.field_#{f["Regulated_Actors"]}.*.value')")})

  # Provision Text (the full legal text)
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => detail_page_id,
      "value" => formula.("\"Provision Text\""), "level" => 3})

  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "text", "page_id" => detail_page_id,
      "value" => formula.("get('data_source.#{ds_id}.field_#{f["Provision_Text"]}')")})

  # Controls (via Control Mappings link)
  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => detail_page_id,
      "value" => formula.("\"Mapped Controls\""), "level" => 3})

  Req.post!("#{base}/api/builder/page/#{detail_page_id}/elements/",
    headers: headers,
    json: %{"type" => "text", "page_id" => detail_page_id,
      "value" => formula.("get('data_source.#{ds_id}.field_#{f["Control Mappings"]}.*.value')")})

  IO.puts("  Detail page built")
end

# ── Now add Duties link to the Legal Register page ──────

IO.puts("\n--- Updating Legal Register page ---")

lr_page = Enum.find(pages, fn p -> p["path"] == "/" end)
{:ok, %{body: lr_elements}} = Req.get("#{base}/api/builder/page/#{lr_page["id"]}/elements/",
  headers: headers, receive_timeout: 15_000)
lr_table = Enum.find(lr_elements, fn e -> e["type"] == "table" end)

if lr_table do
  # Get current fields and add Duties link
  existing_fields = lr_table["fields"] || []

  # Check if Duties link already exists
  has_duties = Enum.any?(existing_fields, fn f -> f["name"] == "Duties" end)

  unless has_duties do
    # LRT field for Name (law_name) = 9564633
    duties_link = %{
      "name" => "Duties", "type" => "link",
      "navigate_to_page_id" => duties_page_id,
      "navigation_type" => "page",
      "query_parameters" => [%{"name" => "law",
        "value" => "get('current_record.field_9564633')"}]}

    updated_fields = existing_fields ++ [duties_link]

    {:ok, %{status: ls}} = Req.patch("#{base}/api/builder/element/#{lr_table["id"]}/",
      headers: headers, json: %{"fields" => updated_fields}, receive_timeout: 15_000)
    IO.puts("  Added Duties link to Legal Register: #{ls}")
  else
    IO.puts("  Duties link already exists on Legal Register")
  end
end

# ── Publish ─────────────────────────────────────────────

{:ok, %{body: domains}} = Req.get("#{base}/api/builder/#{builder_id}/domains/",
  headers: headers, receive_timeout: 15_000)

if domains != [] do
  {:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
    headers: headers, json: %{}, receive_timeout: 15_000)
  IO.puts("\nPublished: #{ps}")
end

IO.puts("""

=== DONE ===

Duties page: #{duties_page_id} (/duties?law=LAW_NAME)
Detail page: #{detail_page_id} (/duty/:id)

MANUAL STEPS:
1. Set "Details" link text in duties table config
2. Set "Controls" link text or column content in duties table
3. Set "Current Duty" data source Row ID to: Path parameter > id
4. Set "Duties" data source filter: Legal_Register field contains query parameter "law"
5. Set "Duties" link text on Legal Register page
6. Test: Legal Register → Duties → Detail
7. Re-publish
""")
