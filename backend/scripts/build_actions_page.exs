# Build the Actions page on the Compliance Workbench app.
#
# Same-page create+edit pattern (proven in Phase 2 Hierarchy):
# - Table listing all actions (filterable/sortable/searchable)
# - "+ Add Action" button → creates blank row → navigates to ?edit=NEW_ID
# - Form pre-fills from ?edit= query param → Update Row on submit
# - Edit link on each table row → same page with ?edit=ROW_ID
#
# ## Prerequisites
# - Compliance Workbench app exists (run build_assessment_app.exs first)
# - Actions table exists with fields (run mix templates.apply)
#
# ## Manual Steps After Running
#
# 1.  Drag form inputs (Title, Status, Priority, Action Type, Assigned To,
#     Assessment, Due Date, Notes) INTO the Form container
# 2.  Configure "Update a row" on Form submit:
#     - Row ID: Query parameter > edit
#     - Map: Title, Status, Priority, Action_Type, Assigned_To, Assessments,
#       Due_Date, Notes from form data
# 3.  Configure "Create a row" on "+ Add Action" button:
#     - Table: Actions (leave all fields empty — creates blank row)
# 4.  Configure "Open Page" on "+ Add Action" button:
#     - Navigate to: Actions /actions?edit=#
#     - edit = Previous action > Create a row > Id
# 5.  Set Edit link text to "Edit" in table column config
# 6.  Set Edit column edit param to: Data source: All Actions > Id
# 7.  Set "Edit Action" data source Row ID to: Query parameter > edit
# 8.  Reorder form actions: Update Row → Notification → Refresh
# 9.  Test Add + Edit workflows
# 10. Re-publish
#
# ## Usage
#
#   mix run scripts/build_actions_page.exs [--config UUID]

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

actions_table_id = sc.target_config["actions_table_id"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

# ── Find builder app and integration ────────────────────

IO.puts("=== Actions Page Builder ===\n")

{:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
builder = Enum.find(apps, fn a -> a["type"] == "builder" end)

unless builder do
  IO.puts("ERROR: No builder app found. Run build_assessment_app.exs first.")
  System.halt(1)
end

builder_id = builder["id"]
IO.puts("App: #{builder["name"]} (#{builder_id})")

{:ok, %{body: integrations}} = Req.get("#{base}/api/application/#{builder_id}/integrations/",
  headers: headers, receive_timeout: 15_000)
integration_id = hd(integrations)["id"]

# ── Get field IDs ───────────────────────────────────────

{:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, actions_table_id)
field_map = Map.new(fields, fn f -> {f["name"], f["id"]} end)

title_f = field_map["Title"]
status_f = field_map["Status"]
priority_f = field_map["Priority"]
type_f = field_map["Action_Type"]
assigned_f = field_map["Assigned_To"]
assessments_f = field_map["Assessments"]
due_f = field_map["Due_Date"]
completed_f = field_map["Completed_Date"]
notes_f = field_map["Notes"]
action_formula_f = field_map["Action"]
overdue_f = field_map["Overdue"]
law_f = field_map["Law"]

IO.puts("Fields: Title=#{title_f} Status=#{status_f} Priority=#{priority_f} Type=#{type_f}")

# ── Find or create page ─────────────────────────────────

pages = builder["pages"] |> Enum.reject(fn p -> p["shared"] end)

actions_page =
  case Enum.find(pages, fn p -> p["path"] == "/actions" end) do
    nil ->
      IO.puts("Creating Actions page...")
      {:ok, %{body: page}} = Req.post("#{base}/api/builder/#{builder_id}/pages/",
        headers: headers,
        json: %{"name" => "Actions", "path" => "/actions"},
        receive_timeout: 15_000)
      page

    existing ->
      IO.puts("Found page: #{existing["id"]}")
      existing
  end

page_id = actions_page["id"]

# Add query parameter for edit mode
{:ok, _} = Req.patch("#{base}/api/builder/pages/#{page_id}/",
  headers: headers,
  json: %{"query_params" => [%{"name" => "edit", "type" => "numeric"}]},
  receive_timeout: 15_000)
IO.puts("Query param 'edit' set")

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
    json: %{"name" => "All Actions", "type" => "local_baserow_list_rows",
      "integration_id" => integration_id, "table_id" => actions_table_id},
    receive_timeout: 15_000)
  IO.puts("  All Actions DS: #{list_ds["id"]}")

  {:ok, %{body: edit_ds}} = Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Edit Action", "type" => "local_baserow_get_row",
      "integration_id" => integration_id, "table_id" => actions_table_id},
    receive_timeout: 15_000)
  IO.puts("  Edit Action DS: #{edit_ds["id"]} (Row ID must be set manually: Query parameter > edit)")

  list_ds_id = list_ds["id"]
  edit_ds_id = edit_ds["id"]

  # ── Elements ────────────────────────────────────────────

  IO.puts("\nCreating elements...")

  # Heading
  Req.post!("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "heading", "page_id" => page_id,
      "value" => formula.("\"Action Tracker\""), "level" => 1})

  # "+ Add Action" button
  {:ok, %{body: btn}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "button", "page_id" => page_id,
      "value" => formula.("\"+ Add Action\"")})
  IO.puts("  Button: #{btn["id"]}")

  # Table
  {:ok, %{body: table_el}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "table", "page_id" => page_id,
      "data_source_id" => list_ds_id, "items_per_page" => 25,
      "is_publicly_filterable" => true, "is_publicly_sortable" => true,
      "is_publicly_searchable" => true})

  # Configure table columns
  table_fields = [
    %{"name" => "Action", "type" => "text",
      "value" => formula.("concat(get(\"current_record.field_#{assessments_f}.*.value\"), \" — \", get(\"current_record.field_#{title_f}\"))")},
    %{"name" => "Status", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{status_f}.value\")")},
    %{"name" => "Priority", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{priority_f}.value\")")},
    %{"name" => "Assigned To", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{assigned_f}.*.value\")")},
    %{"name" => "Due Date", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{due_f}\")")},
    %{"name" => "Overdue", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{overdue_f}\")")},
    %{"name" => "Edit", "type" => "link",
      "navigate_to_page_id" => page_id,
      "navigation_type" => "page",
      "query_parameters" => [%{"name" => "edit", "value" => "get(\"current_record.id\")"}]}
  ]

  Req.patch!("#{base}/api/builder/element/#{table_el["id"]}/",
    headers: headers, json: %{"fields" => table_fields})
  IO.puts("  Table: #{table_el["id"]} (7 columns)")

  # Form container
  {:ok, %{body: form}} = Req.post("#{base}/api/builder/page/#{page_id}/elements/",
    headers: headers,
    json: %{"type" => "form_container", "page_id" => page_id,
      "submit_button_label" => formula.("\"Save Action\"")})
  IO.puts("  Form: #{form["id"]}")

  # Form inputs — will be siblings, must be dragged into form via UI
  form_inputs = [
    {"input_text", "Title", "Short action phrase (e.g. 'Develop lone working RA')", false,
      "get(\"data_source.#{edit_ds_id}.field_#{title_f}\")"},
    {"choice", "Status", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{status_f}.value\")"},
    {"choice", "Priority", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{priority_f}.value\")"},
    {"choice", "Action Type", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{type_f}.value\")"},
    {"record_selector", "Assigned To", "Select person...", false, nil},
    {"record_selector", "Assessment", "Link to assessment...", false, nil},
    {"datetime_picker", "Due Date", nil, false,
      "get(\"data_source.#{edit_ds_id}.field_#{due_f}\")"},
    {"input_text", "Notes", "Progress notes...", true,
      "get(\"data_source.#{edit_ds_id}.field_#{notes_f}\")"}
  ]

  # Need personnel and assessments data sources for record selectors
  {:ok, %{body: personnel_ds}} = Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Personnel", "type" => "local_baserow_list_rows",
      "integration_id" => integration_id,
      "table_id" => sc.target_config["personnel_table_id"]},
    receive_timeout: 15_000)
  IO.puts("  Personnel DS: #{personnel_ds["id"]}")

  {:ok, %{body: assessments_ds}} = Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
    headers: headers,
    json: %{"name" => "Assessments", "type" => "local_baserow_list_rows",
      "integration_id" => integration_id,
      "table_id" => sc.target_config["assessments_table_id"]},
    receive_timeout: 15_000)
  IO.puts("  Assessments DS: #{assessments_ds["id"]}")

  Enum.each(form_inputs, fn {type, label, placeholder, multiline, default_expr} ->
    json =
      %{"type" => type, "page_id" => page_id,
        "label" => formula.("\"#{label}\"")}

    json = if placeholder, do: Map.put(json, "placeholder", formula.("\"#{placeholder}\"")), else: json
    json = if multiline, do: Map.put(json, "is_multiline", true), else: json
    json = if default_expr, do: Map.put(json, "default_value", formula.(default_expr)), else: json

    json =
      case label do
        "Status" ->
          Map.merge(json, %{"option_type" => "manual",
            "options" => Enum.map(["Open", "In Progress", "Completed", "Cancelled"],
              &%{"name" => &1, "value" => &1})})

        "Priority" ->
          Map.merge(json, %{"option_type" => "manual",
            "options" => Enum.map(~w(Critical High Medium Low),
              &%{"name" => &1, "value" => &1})})

        "Action Type" ->
          Map.merge(json, %{"option_type" => "manual",
            "options" => Enum.map(~w(Corrective Preventative Improvement Maintenance),
              &%{"name" => &1, "value" => &1})})

        "Assigned To" ->
          Map.put(json, "data_source_id", personnel_ds["id"])

        "Assessment" ->
          Map.put(json, "data_source_id", assessments_ds["id"])

        _ ->
          json
      end

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
        "integration_id" => integration_id, "table_id" => actions_table_id}})
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
        "integration_id" => integration_id, "table_id" => actions_table_id}})
  IO.puts("  Form Update Row: #{ur["id"]} (configure field mappings in UI)")

  {:ok, _} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "notification", "element_id" => form["id"], "event" => "submit",
      "title" => formula.("\"Action Saved\""),
      "description" => formula.("\"The action has been updated.\"")})
  IO.puts("  Form Notification")

  {:ok, _} = Req.post("#{base}/api/builder/page/#{page_id}/workflow_actions/",
    headers: headers,
    json: %{"type" => "refresh_data_source", "element_id" => form["id"], "event" => "submit",
      "data_source_id" => list_ds_id})
  IO.puts("  Form Refresh")
end

# ── Publish ─────────────────────────────────────────────

{:ok, %{body: domains}} = Req.get("#{base}/api/builder/#{builder_id}/domains/",
  headers: headers, receive_timeout: 15_000)

if domains != [] do
  domain = hd(domains)
  {:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{domain["id"]}/publish/async/",
    headers: headers, json: %{}, receive_timeout: 15_000)
  IO.puts("\nPublished to #{domain["domain_name"]}: #{ps}")
end

IO.puts("""

=== DONE ===

Page: #{page_id} (/actions)

MANUAL STEPS:
1.  Drag Title, Status, Priority, Action Type, Assigned To, Assessment,
    Due Date, Notes INTO the Form container
2.  Configure "Update a row" on Form submit:
    - Row ID: Query parameter > edit
    - Map: Title, Status, Priority, Action_Type, Assigned_To, Assessments,
      Due_Date, Notes from form data
3.  Configure "Create a row" on "+ Add Action" button:
    - Table: Actions (leave all fields empty)
4.  Configure "Open Page" on "+ Add Action" button:
    - Navigate to: Actions /actions?edit=#
    - edit = Previous action > Create a row > Id
5.  Set Edit link text to "Edit" in table column config
6.  Set Edit column edit param to: Data source: All Actions > Id
7.  Set "Edit Action" data source Row ID to: Query parameter > edit
8.  Reorder form actions: Update Row → Notification → Refresh
9.  Test Add + Edit workflows
10. Re-publish
""")
