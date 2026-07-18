# Build the Assessment App in Baserow Application Builder.
#
# This script creates the "Compliance Workbench" app with:
# - Page 1: Assessment Queue (table listing all assessments)
# - Page 2: Assessment Form (form to review/update a single assessment)
#
# ## API Limitations (Baserow SaaS as of July 2026)
#
# The Baserow SaaS REST API does NOT expose:
# - `parent_element_id` / `place_in_container` — elements created via API
#   are always top-level siblings, cannot be nested inside form_container
# - Workflow action `service` sub-object PATCH — returns 500
#
# Therefore this script creates the structural skeleton, and TWO manual
# UI steps are required after running:
#
# ### Manual Step 1: Drag form fields into form container
# In the App Builder editor, on the Assessment Form page:
# - Drag Compliance Status, Risk Level, Gap Description, Notes INTO the Form container
#
# ### Manual Step 2: Configure Update Row action
# On the Form's Events tab:
# - Click "Update a row" action
# - Set Integration: Local Database
# - Set Database: (customer database), Table: Assessments
# - Set Row ID: Parameter > id
# - Enable Compliance_Status → Form data > Compliance Status
# - Enable Risk_Level → Form data > Risk Level
# - Enable Gap_Description → Form data > Gap Description
# - Enable Notes → Form data > Notes
# - Drag "Update a row" to the TOP of the action list (before Open Page)
#
# ## Usage
#
#   mix run scripts/build_assessment_app.exs [--config UUID]
#
# Idempotent — skips creation if app/pages already exist.

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

assessments_table_id = sc.target_config["assessments_table_id"]

# ── Helpers ─────────────────────────────────────────────

api_get = fn path ->
  {:ok, resp} = Req.get("#{base}#{path}", headers: headers, receive_timeout: 15_000)
  resp
end

api_post = fn path, body ->
  {:ok, resp} = Req.post("#{base}#{path}", headers: headers, json: body, receive_timeout: 15_000)
  resp
end

api_patch = fn path, body ->
  {:ok, resp} = Req.patch("#{base}#{path}", headers: headers, json: body, receive_timeout: 15_000)
  resp
end

formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

# ── Step 1: Find or create builder app ──────────────────

IO.puts("=== Assessment App Builder ===\n")

%{body: apps} = api_get.("/api/applications/")
workspace_id = hd(apps)["workspace"]["id"]

builder =
  case Enum.find(apps, fn a -> a["type"] == "builder" end) do
    nil ->
      IO.puts("Creating builder app...")
      %{body: app} = api_post.("/api/applications/workspace/#{workspace_id}/",
        %{"name" => "Compliance Workbench", "type" => "builder"})
      app

    existing ->
      IO.puts("Found existing: #{existing["name"]} (#{existing["id"]})")
      existing
  end

builder_id = builder["id"]

# ── Step 2: Find or create integration ──────────────────

%{body: integrations} = api_get.("/api/application/#{builder_id}/integrations/")

integration =
  case Enum.find(integrations, fn i -> i["type"] == "local_baserow" end) do
    nil ->
      IO.puts("Creating local_baserow integration...")
      %{body: intg} = api_post.("/api/application/#{builder_id}/integrations/",
        %{"type" => "local_baserow", "name" => "Local Database"})
      intg

    existing ->
      IO.puts("Found integration: #{existing["id"]}")
      existing
  end

integration_id = integration["id"]

# ── Step 3: Find or create pages ────────────────────────

pages = builder["pages"] |> Enum.reject(fn p -> p["shared"] end)

queue_page =
  case Enum.find(pages, fn p -> p["path"] == "/" end) do
    nil ->
      IO.puts("Creating queue page...")
      %{body: page} = api_post.("/api/builder/#{builder_id}/pages/",
        %{"name" => "Assessment Queue", "path" => "/"})
      page

    existing ->
      IO.puts("Found queue page: #{existing["id"]}")
      existing
  end

form_page =
  case Enum.find(pages, fn p -> String.contains?(p["path"] || "", "assess") end) do
    nil ->
      IO.puts("Creating form page...")
      %{body: page} = api_post.("/api/builder/#{builder_id}/pages/",
        %{"name" => "Assessment Form", "path" => "/assess/:id",
          "path_params" => [%{"name" => "id", "type" => "numeric"}]})
      page

    existing ->
      IO.puts("Found form page: #{existing["id"]}")
      existing
  end

queue_page_id = queue_page["id"]
form_page_id = form_page["id"]

# ── Step 4: Get field IDs from assessments table ────────

{:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, assessments_table_id)
field_map = Map.new(fields, fn f -> {f["name"], f["id"]} end)

IO.puts("\nAssessments fields:")
Enum.each(["Name", "Legal_Register", "Compliance_Status", "Risk_Level",
           "Gap_Description", "Notes", "Assessment_Owner", "Next_Review_Date"],
  fn name -> IO.puts("  #{name}: #{field_map[name]}") end)

# ── Step 5: Queue page — data source + elements ────────

IO.puts("\n--- Queue Page ---")

# Data source
%{body: queue_ds_list} = api_get.("/api/builder/page/#{queue_page_id}/data-sources/")

queue_ds =
  case Enum.find(queue_ds_list, fn d -> d["name"] == "All Assessments" end) do
    nil ->
      IO.puts("Creating queue data source...")
      %{body: ds} = api_post.("/api/builder/page/#{queue_page_id}/data-sources/",
        %{"name" => "All Assessments", "type" => "local_baserow_list_rows",
          "integration_id" => integration_id, "table_id" => assessments_table_id})
      ds

    existing ->
      IO.puts("Found queue data source: #{existing["id"]}")
      existing
  end

queue_ds_id = queue_ds["id"]

# Elements — only create if page has no elements yet
%{body: existing_els} = api_get.("/api/builder/page/#{queue_page_id}/elements/")

if length(existing_els) == 0 do
  IO.puts("Creating queue elements...")

  # Heading
  api_post.("/api/builder/page/#{queue_page_id}/elements/",
    %{"type" => "heading", "page_id" => queue_page_id,
      "value" => formula.("\"Compliance Assessment Review\""), "level" => 1})

  # Table with columns
  %{body: table_el} = api_post.("/api/builder/page/#{queue_page_id}/elements/",
    %{"type" => "table", "page_id" => queue_page_id,
      "data_source_id" => queue_ds_id, "items_per_page" => 25})

  # Configure columns
  lr_field = field_map["Legal_Register"]
  status_field = field_map["Compliance_Status"]
  risk_field = field_map["Risk_Level"]
  owner_field = field_map["Assessment_Owner"]
  review_field = field_map["Next_Review_Date"]

  table_fields = [
    %{"name" => "Law", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{lr_field}.*.value\")")},
    %{"name" => "Status", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{status_field}.value\")")},
    %{"name" => "Risk", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{risk_field}.value\")")},
    %{"name" => "Owner", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{owner_field}.*.value\")")},
    %{"name" => "Review Due", "type" => "text",
      "value" => formula.("get(\"current_record.field_#{review_field}\")")},
    %{"name" => "Review", "type" => "link",
      "navigate_to_page_id" => form_page_id,
      "navigation_type" => "page",
      "page_parameters" => [%{"name" => "id", "value" => "get(\"current_record.id\")"}]}
  ]

  api_patch.("/api/builder/element/#{table_el["id"]}/", %{"fields" => table_fields})
  IO.puts("  Table columns configured")
else
  IO.puts("Queue page already has #{length(existing_els)} elements — skipping")
end

# ── Step 6: Form page — data source + elements ──────────

IO.puts("\n--- Form Page ---")

# Data source
%{body: form_ds_list} = api_get.("/api/builder/page/#{form_page_id}/data-sources/")

form_ds =
  case Enum.find(form_ds_list, fn d -> d["name"] == "Current Assessment" end) do
    nil ->
      IO.puts("Creating form data source...")
      %{body: ds} = api_post.("/api/builder/page/#{form_page_id}/data-sources/",
        %{"name" => "Current Assessment", "type" => "local_baserow_get_row",
          "integration_id" => integration_id, "table_id" => assessments_table_id})
      # Set row_id formula (must be done via PATCH after creation)
      api_patch.("/api/builder/data-source/#{ds["id"]}/",
        %{"row_id" => formula.("get(\"page_parameter.id\")")})
      ds

    existing ->
      IO.puts("Found form data source: #{existing["id"]}")
      existing
  end

form_ds_id = form_ds["id"]

# Elements
%{body: existing_form_els} = api_get.("/api/builder/page/#{form_page_id}/elements/")

if length(existing_form_els) == 0 do
  IO.puts("Creating form elements...")

  status_field = field_map["Compliance_Status"]
  risk_field = field_map["Risk_Level"]
  gap_field = field_map["Gap_Description"]
  notes_field = field_map["Notes"]

  # Back link
  api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "link", "page_id" => form_page_id,
      "value" => formula.("\"← Back to Queue\""),
      "navigate_to_page_id" => queue_page_id, "navigation_type" => "page"})

  # Law name heading (from data source)
  lr_field = field_map["Legal_Register"]
  api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "heading", "page_id" => form_page_id,
      "value" => formula.("get(\"data_source.#{form_ds_id}.field_#{lr_field}.*.value\")"),
      "level" => 2})

  # Form container
  # NOTE: Elements created below will be OUTSIDE the form container.
  # Manual Step 1 required: drag them into the form in the UI.
  %{body: form_container} = api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "form_container", "page_id" => form_page_id})

  form_container_id = form_container["id"]

  # Compliance Status choice
  %{body: status_el} = api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "choice", "page_id" => form_page_id,
      "label" => formula.("\"Compliance Status\""),
      "placeholder" => formula.("\"Select status...\""),
      "option_type" => "manual",
      "options" => [
        %{"name" => "Compliant", "value" => "Compliant"},
        %{"name" => "Partially Compliant", "value" => "Partially Compliant"},
        %{"name" => "Non-Compliant", "value" => "Non-Compliant"},
        %{"name" => "Not Assessed", "value" => "Not Assessed"},
        %{"name" => "Not Applicable", "value" => "Not Applicable"}
      ],
      "default_value" => formula.("get(\"data_source.#{form_ds_id}.field_#{status_field}.value\")")})

  # Risk Level choice
  %{body: risk_el} = api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "choice", "page_id" => form_page_id,
      "label" => formula.("\"Risk Level\""),
      "option_type" => "manual",
      "options" => [
        %{"name" => "Critical", "value" => "Critical"},
        %{"name" => "High", "value" => "High"},
        %{"name" => "Medium", "value" => "Medium"},
        %{"name" => "Low", "value" => "Low"}
      ],
      "default_value" => formula.("get(\"data_source.#{form_ds_id}.field_#{risk_field}.value\")")})

  # Gap Description
  %{body: gap_el} = api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "input_text", "page_id" => form_page_id,
      "label" => formula.("\"Gap Description\""),
      "placeholder" => formula.("\"What is missing or non-compliant?\""),
      "is_multiline" => true,
      "default_value" => formula.("get(\"data_source.#{form_ds_id}.field_#{gap_field}\")")})

  # Notes
  %{body: notes_el} = api_post.("/api/builder/page/#{form_page_id}/elements/",
    %{"type" => "input_text", "page_id" => form_page_id,
      "label" => formula.("\"Notes\""),
      "placeholder" => formula.("\"General notes...\""),
      "is_multiline" => true,
      "default_value" => formula.("get(\"data_source.#{form_ds_id}.field_#{notes_field}\")")})

  IO.puts("  Created: back link, heading, form_container, 2 choices, 2 text inputs")

  # ── Step 7: Workflow actions ──────────────────────────

  IO.puts("\nCreating workflow actions...")

  # Update Row (will be created unconfigured — Manual Step 2 required)
  api_post.("/api/builder/page/#{form_page_id}/workflow_actions/",
    %{"type" => "update_row", "element_id" => form_container_id, "event" => "submit",
      "service" => %{"type" => "local_baserow_upsert_row",
        "integration_id" => integration_id, "table_id" => assessments_table_id}})
  IO.puts("  Created: update_row (REQUIRES MANUAL CONFIGURATION — see script header)")

  # Notification
  api_post.("/api/builder/page/#{form_page_id}/workflow_actions/",
    %{"type" => "notification", "element_id" => form_container_id, "event" => "submit",
      "title" => formula.("\"Assessment Saved\""),
      "description" => formula.("\"Your assessment has been saved.\"")})
  IO.puts("  Created: notification")

  # Navigate back to queue
  api_post.("/api/builder/page/#{form_page_id}/workflow_actions/",
    %{"type" => "open_page", "element_id" => form_container_id, "event" => "submit",
      "navigate_to_page_id" => queue_page_id})
  IO.puts("  Created: open_page → queue")

else
  IO.puts("Form page already has #{length(existing_form_els)} elements — skipping")
end

# ── Summary ─────────────────────────────────────────────

IO.puts("""

=== DONE ===

App: #{builder["name"]} (#{builder_id})
Queue: #{queue_page_id} (/)
Form: #{form_page_id} (/assess/:id)
Integration: #{integration_id}

MANUAL STEPS REQUIRED:
1. Open App Builder editor → Assessment Form page
2. Drag Compliance Status, Risk Level, Gap Description, Notes INTO the Form container
3. On Form Events tab → Update Row action:
   - Set Row ID: Parameter > id
   - Map Compliance_Status ← Form data > Compliance Status
   - Map Risk_Level ← Form data > Risk Level
   - Map Gap_Description ← Form data > Gap Description
   - Map Notes ← Form data > Notes
   - Drag Update Row to TOP of action list
4. On Queue page table → Review column → set Link text to "Review →"
5. Preview and test end-to-end
6. Publish
""")
