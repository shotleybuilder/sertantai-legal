# Build Action Status Rollups: Actions → Assessments → LRT → Legal Register page
#
# Step 1a: Formula fields on Actions (Is_Open, Is_Overdue, Is_Done — return 1 or 0)
# Step 1b: Rollup fields on Assessments (sum through Actions link)
# Step 2:  Lookup fields on LRT (through Assessments link)
# Step 3:  Add column to Legal Register page
#
# Usage: mix run scripts/build_action_rollups.exs

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

actions_table_id = sc.target_config["actions_table_id"]
assessments_table_id = sc.target_config["assessments_table_id"]
lrt_table_id = sc.target_config["lrt_table_id"]

IO.puts("=== Action Status Rollups ===\n")

# Helper: check if field exists, create if not
create_field = fn table_id, name, field_config ->
  {:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, table_id)
  existing = Enum.find(fields, fn f -> f["name"] == name end)

  if existing do
    IO.puts("  #{name} already exists: #{existing["id"]}")
    existing["id"]
  else
    {:ok, %{status: s, body: f}} = Req.post("#{base}/api/database/fields/table/#{table_id}/",
      headers: headers, json: Map.put(field_config, "name", name), receive_timeout: 15_000)

    if s == 200 do
      IO.puts("  Created #{name}: #{f["id"]}")
      f["id"]
    else
      IO.puts("  FAILED #{name}: #{s}")
      IO.inspect(f, limit: 5)
      nil
    end
  end
end

# ── Step 1a: Formula fields on Actions table ──────────────

IO.puts("Step 1a: Actions formula fields")

is_open_id = create_field.(actions_table_id, "Is_Open", %{
  "type" => "formula",
  "formula" => "if(or(field('Status')='Open', field('Status')='In Progress'), 1, 0)"
})

is_overdue_id = create_field.(actions_table_id, "Is_Overdue", %{
  "type" => "formula",
  "formula" => "if(field('Overdue')='OVERDUE', 1, 0)"
})

is_done_id = create_field.(actions_table_id, "Is_Done", %{
  "type" => "formula",
  "formula" => "if(field('Status')='Completed', 1, 0)"
})

# ── Step 1b: Rollup fields on Assessments table ──────────

IO.puts("\nStep 1b: Assessments rollup fields")

# Find the Actions link field on Assessments
{:ok, assess_fields} = SertantaiLegal.Baserow.Client.list_fields(config, assessments_table_id)
actions_link = Enum.find(assess_fields, fn f -> f["name"] == "Actions" end)

if is_nil(actions_link) do
  IO.puts("  ERROR: Actions link field not found on Assessments table")
  System.halt(1)
end

actions_link_id = actions_link["id"]
IO.puts("  Actions link field: #{actions_link_id}")

open_rollup_id = create_field.(assessments_table_id, "Actions_Open", %{
  "type" => "rollup",
  "through_field_id" => actions_link_id,
  "target_field_id" => is_open_id,
  "rollup_function" => "sum"
})

overdue_rollup_id = create_field.(assessments_table_id, "Actions_Overdue", %{
  "type" => "rollup",
  "through_field_id" => actions_link_id,
  "target_field_id" => is_overdue_id,
  "rollup_function" => "sum"
})

done_rollup_id = create_field.(assessments_table_id, "Actions_Done", %{
  "type" => "rollup",
  "through_field_id" => actions_link_id,
  "target_field_id" => is_done_id,
  "rollup_function" => "sum"
})

# ── Step 2: Lookup fields on LRT table ────────────────────

IO.puts("\nStep 2: LRT lookup fields")

# Find the Assessments link field on LRT (reverse link)
{:ok, lrt_fields} = SertantaiLegal.Baserow.Client.list_fields(config, lrt_table_id)
assessments_link = Enum.find(lrt_fields, fn f -> f["name"] == "Assessments" end)

if is_nil(assessments_link) do
  IO.puts("  ERROR: Assessments link field not found on LRT table")
  System.halt(1)
end

assessments_link_id = assessments_link["id"]
IO.puts("  Assessments link field: #{assessments_link_id}")

lrt_open_id = create_field.(lrt_table_id, "Actions_Open", %{
  "type" => "lookup",
  "through_field_id" => assessments_link_id,
  "target_field_id" => open_rollup_id
})

lrt_overdue_id = create_field.(lrt_table_id, "Actions_Overdue", %{
  "type" => "lookup",
  "through_field_id" => assessments_link_id,
  "target_field_id" => overdue_rollup_id
})

lrt_done_id = create_field.(lrt_table_id, "Actions_Done", %{
  "type" => "lookup",
  "through_field_id" => assessments_link_id,
  "target_field_id" => done_rollup_id
})

IO.puts("""

=== DONE ===

Actions table:   Is_Open=#{is_open_id}, Is_Overdue=#{is_overdue_id}, Is_Done=#{is_done_id}
Assessments:     Actions_Open=#{open_rollup_id}, Actions_Overdue=#{overdue_rollup_id}, Actions_Done=#{done_rollup_id}
LRT:             Actions_Open=#{lrt_open_id}, Actions_Overdue=#{lrt_overdue_id}, Actions_Done=#{lrt_done_id}

Next: add an Actions Summary column to the Legal Register page using these field IDs.
""")
