# Build the Hierarchy (Organisation) page on the Compliance Workbench app.
#
# Adds a single-page Create+Edit workflow:
# - Table listing all hierarchy nodes (filterable by hierarchy type)
# - "Add Node" button → creates blank row → navigates to ?edit=NEW_ID
# - Form pre-fills from ?edit= query param → Update Row on submit
# - Edit link on each table row → same page with ?edit=ROW_ID
#
# ## Prerequisites
# - Compliance Workbench app exists (run build_assessment_app.exs first)
# - Hierarchy table exists with fields (run mix templates.apply)
#
# ## Manual Steps After Running
#
# 1. Drag form inputs (Node Name, Hierarchy, Node Type, Parent Node, Description)
#    INTO the Form container
# 2. Configure "Update a row" action on the Form:
#    - Row ID: Query parameter > edit
#    - Map Name, Hierarchy_Type, Type, Parent, Description from form data
# 3. Configure "Create a row" action on the "+ Add Node" button:
#    - Table: Hierarchy (leave all fields empty — creates blank row)
# 4. Configure "Open Page" action on the "+ Add Node" button:
#    - Navigate to: Organisation /org?edit=#
#    - edit = Previous action > Create a row > Id
# 5. Set Edit link text to "Edit" in table column config
# 6. Set Edit link edit param to: Data source: All Nodes > Id
# 7. Add query parameter "edit" (numeric) to the Organisation page
# 8. Set "Edit Node" data source Row ID to: Query parameter > edit
# 9. Reorder form actions: Update Row → Notification → Refresh
# 10. Re-publish
#
# ## Usage
#
#   mix run scripts/build_hierarchy_page.exs [--config UUID]

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

# ── Config ──────────────────────────────────────────────

config_id =
  case System.argv() do
    ["--config", id | _] -> id
    _ -> "90b9c916-e06b-48ff-861f-065f3778fd7a"
  end

{:ok, sc} = Ash.get(SyncConfiguration, config_id)
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

hierarchy_table_id = sc.target_config["hierarchy_table_id"]
integration_id =
  case Req.get!("#{base}/api/application/#{sc.target_config["database_id"]}/../integrations/",
         headers: headers, receive_timeout: 15_000) do
    _ -> nil
  end

formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

# ── Find builder app and integration ────────────────────

IO.puts("=== Hierarchy Page Builder ===\n")

{:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)

builder = Enum.find(apps, fn a -> a["type"] == "builder" end)

unless builder do
  IO.puts("ERROR: No builder app found. Run build_assessment_app.exs first.")
  System.halt(1)
end

builder_id = builder["id"]
IO.puts("App: #{builder["name"]} (#{builder_id})")

# Find integration
{:ok, %{body: integrations}} = Req.get("#{base}/api/application/#{builder_id}/integrations/",
  headers: headers, receive_timeout: 15_000)

integration = Enum.find(integrations, fn i -> i["type"] == "local_baserow" end)

unless integration do
  IO.puts("ERROR: No local_baserow integration found.")
  System.halt(1)
end

integration_id = integration["id"]

# ── Find or create page ─────────────────────────────────

pages = builder["pages"] |> Enum.reject(fn p -> p["shared"] end)

org_page =
  case Enum.find(pages, fn p -> p["path"] == "/org" end) do
    nil ->
      IO.puts("Creating Organisation page...")
      {:ok, %{body: page}} = Req.post("#{base}/api/builder/#{builder_id}/pages/",
        headers: headers,
        json: %{"name" => "Organisation", "path" => "/org"},
        receive_timeout: 15_000)
      page

    existing ->
      IO.puts("Found page: #{existing["id"]}")
      existing
  end

page_id = org_page["id"]

# Add query parameter for edit mode
{:ok, _} = Req.patch("#{base}/api/builder/pages/#{page_id}/",
  headers: headers,
  json: %{"query_params" => [%{"name" => "edit", "type" => "numeric"}]},
  receive_timeout: 15_000)
IO.puts("Query param 'edit' set")

# ── Get field IDs ───────────────────────────────────────

{:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, hierarchy_table_id)
field_map = Map.new(fields, fn f -> {f["name"], f["id"]} end)

name_field = field_map["Name"]
ht_field = field_map["Hierarchy_Type"]
type_field = field_map["Type"]
node_field = field_map["Node"]
parent_field = field_map["Parent"]
desc_field = field_map["Description"]

IO.puts("Fields: Name=#{name_field} HT=#{ht_field} Type=#{type_field} Node=#{node_field} Parent=#{parent_field} Desc=#{desc_field}")

# ── Check if page already has elements ──────────────────

{:ok, %{body: existing_els}} = Req.get("#{base}/api/builder/page/#{page_id}/elements/",
  headers: headers, receive_timeout: 15_000)

if length(existing_els) > 0 do
  IO.puts("Page already has #{length(existing_els)} elements — skipping build")
else
  # ── Data sources ────────────────────────────────────────

  IO.puts("\nCreating data sources...")

  {:ok, %{body: list_ds}} = Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "All Nodes", "type" => "local_baserow_list_rows",
      "integration_id" => integration_id, "table_id" => hierarchy_table_id},
    receive_timeout: 15_000)
  IO.puts("  All Nodes DS: #{list_ds["id"]}")

  {:ok, %{body: edit_ds}} = Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Edit Node", "type" => "local_baserow_get_row",
      "integration_id" => integration_id, "table_id" => hierarchy_table_id},
    receive_timeout: 15_000)
  IO.puts("  Edit Node DS: #{edit_ds["id"]} (Row ID must be set manually: Query parameter > edit)")

  list_ds_id = list_ds["id"]
  edit_ds_id = edit_ds["id"]

  # ── Elements ────────────────────────────────────────────

  IO.puts("\nCreating elements...")

  # Heading
  Req.post!("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => page_id,
      "value" => formula.("\"Organisation Structure\""), "level" => 1})

  # "+ Add Node" button
  {:ok, %{body: btn}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "button", "page_id" => page_id,
      "value" => formula.("\"+ Add Node\"")})
  IO.puts("  Button: #{btn["id"]}")

  # Table
  {:ok, %{body: table_el}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "table", "page_id" => page_id,
      "data_source_id" => list_ds_id, "items_per_page" => 50,
      "is_publicly_filterable" => true, "is_publicly_sortable" => true,
      "is_publicly_searchable" => true})

  # Configure table columns
  table_fields = [
    %{"name" => "Node", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{node_field}\")")},
    %{"name" => "Hierarchy", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{ht_field}.value\")")},
    %{"name" => "Type", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{type_field}.value\")")},
    %{"name" => "Parent", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{parent_field}.*.value\")")},
    %{"name" => "Description", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{desc_field}\")")},
    %{"name" => "Edit", "type" => "link",
      "navigate_to_page_id" => page_id,
      "navigation_type" => "page",
      "query_parameters" => [%{"name" => "edit", "value" => "get(\"current_record.id\")"}]}
  ]

  Req.patch!("#{base}/api/builder/element/#{table_el["id"]}/",
    headers: headers, json: %{"fields" => table_fields})
  IO.puts("  Table: #{table_el["id"]} (6 columns)")

  # Form container
  {:ok, %{body: form}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "form_container", "page_id" => page_id,
      "submit_button_label" => formula.("\"Update Node\"")})
  IO.puts("  Form: #{form["id"]}")

  # Form inputs (will be siblings — must be dragged into form via UI)
  inputs = [
    {"input_text", "Node Name", "e.g. Manchester, EHS Department", false,
      "get(\"data_source.#{edit_ds_id}.field_#{name_field}\")"},
    {"choice", "Hierarchy", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{ht_field}.value\")"},
    {"choice", "Node Type", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{type_field}.value\")"},
    {"record_selector", "Parent Node", "Select parent (empty = root)", false, nil},
    {"input_text", "Description", "Notes about this node", true,
      "get(\"data_source.#{edit_ds_id}.field_#{desc_field}\")"}
  ]

  Enum.each(inputs, fn {type, label, placeholder, multiline, default_expr} ->
    json =
      %{"type" => type, "page_id" => page_id,
        "label" => formula.("\"#{label}\""),
        "required" => (type != "record_selector" and type != "input_text" and label != "Description")}

    json = if placeholder, do: Map.put(json, "placeholder", formula.("\"#{placeholder}\"")), else: json
    json = if multiline, do: Map.put(json, "is_multiline", true), else: json
    json = if default_expr, do: Map.put(json, "default_value", formula.(default_expr)), else: json

    # Choice options
    json =
      case label do
        "Hierarchy" ->
          Map.merge(json, %{
            "option_type" => "manual",
            "options" => [
              %{"name" => "Organisation", "value" => "org"},
              %{"name" => "Geography", "value" => "geo"},
              %{"name" => "Finance", "value" => "finance"},
              %{"name" => "Reporting", "value" => "reporting"}
            ]
          })

        "Node Type" ->
          Map.merge(json, %{
            "option_type" => "manual",
            "options" =>
              ~w(Organisation Division Department Function Site Building Floor Region Country)
              |> Enum.concat(["Cost Centre"])
              |> Enum.map(&%{"name" => &1, "value" => &1})
          })

        _ ->
          json
      end

    # Record selector needs data_source_id
    json = if type == "record_selector", do: Map.put(json, "data_source_id", list_ds_id), else: json

    {:ok, %{body: el}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
      headers: headers, json: json, receive_timeout: 15_000)
    IO.puts("  #{label}: #{el["id"]}")
  end)

  # ── Workflow actions ──────────────────────────────────────

  IO.puts("\nCreating workflow actions...")

  # Button: Create Row (blank) → Open Page (same page with ?edit=new_id)
  {:ok, %{body: cr}} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "create_row", "element_id" => btn["id"], "event" => "click",
      "service" => %{"type" => "local_baserow_upsert_row",
        "integration_id" => integration_id, "table_id" => hierarchy_table_id}})
  IO.puts("  Button Create Row: #{cr["id"]}")

  {:ok, %{body: nav}} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "open_page", "element_id" => btn["id"], "event" => "click",
      "navigate_to_page_id" => page_id})
  IO.puts("  Button Navigate: #{nav["id"]} (set edit = Previous action > Create a row > Id in UI)")

  # Form: Update Row → Notification → Refresh
  {:ok, %{body: ur}} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "update_row", "element_id" => form["id"], "event" => "submit",
      "service" => %{"type" => "local_baserow_upsert_row",
        "integration_id" => integration_id, "table_id" => hierarchy_table_id}})
  IO.puts("  Form Update Row: #{ur["id"]} (configure field mappings in UI)")

  {:ok, _} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "notification", "element_id" => form["id"], "event" => "submit",
      "title" => formula.("\"Node Saved\""),
      "description" => formula.("\"The hierarchy node has been updated.\"")})
  IO.puts("  Form Notification")

  {:ok, _} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "refresh_data_source", "element_id" => form["id"], "event" => "submit",
      "data_source_id" => list_ds_id})
  IO.puts("  Form Refresh")
end

IO.puts("""

=== DONE ===

Page: #{page_id} (/org)

MANUAL STEPS:
1.  Drag Node Name, Hierarchy, Node Type, Parent Node, Description INTO the Form container
2.  Configure "Update a row" on Form submit:
    - Row ID: Query parameter > edit
    - Map: Name ← Node Name, Hierarchy_Type ← Hierarchy, Type ← Node Type, Parent ← Parent Node, Description ← Description
3.  Configure "Create a row" on "+ Add Node" button:
    - Table: Hierarchy (leave all fields empty)
4.  Configure "Open Page" on "+ Add Node" button:
    - Navigate to: Organisation /org?edit=#
    - edit = Previous action > Create a row > Id
5.  Set Edit link text to "Edit" in table column config
6.  Set Edit column edit param to: Data source: All Nodes > Id
7.  Set "Edit Node" data source Row ID to: Query parameter > edit
8.  Reorder form actions: Update Row → Notification → Refresh
9.  Test Add + Edit workflows
10. Re-publish
""")
