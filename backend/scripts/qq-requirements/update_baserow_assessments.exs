# Update Baserow Assessments table with org-level compliance from QQ aggregate.
#
# Reads org_compliance_by_law.csv (output of `map_requirements.py aggregate --csv`),
# maps to Baserow assessment rows by Legal_Register Name, and batch-updates
# Compliance_Status and Notes.
#
# Thresholds:
#   Action Required at >5 sites  → ❌ Non-Compliant
#   Action Required at >2 sites  → ⚠️ Partially Compliant
#   All sites Compliant          → ✅ Compliant
#   Not Applicable               → left as-is (Not Assessed)
#
# Usage:
#   mix run scripts/qq-requirements/update_baserow_assessments.exs [--config UUID] [--dry-run]

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Baserow.Client
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{args, _} = OptionParser.parse!(System.argv(), strict: [config: :string, dry_run: :boolean])

config_id = args[:config] || "90b9c916-e06b-48ff-861f-065f3778fd7a"
dry_run = args[:dry_run] || false

csv_path =
  Path.join([
    File.cwd!(),
    "..",
    "backend",
    "data",
    "qq",
    "requirements",
    "output",
    "org_compliance_by_law.csv"
  ])
  |> Path.expand()

# Also try relative from project root if running from backend/
csv_path =
  if File.exists?(csv_path) do
    csv_path
  else
    Path.join([File.cwd!(), "data", "qq", "requirements", "output", "org_compliance_by_law.csv"])
    |> Path.expand()
  end

# --- 1. Read aggregate CSV ---
IO.puts("Reading #{csv_path}...")

NimbleCSV.define(AggCSV, separator: ",", escape: "\"")

rows =
  csv_path
  |> File.read!()
  |> AggCSV.parse_string(skip_headers: false)
  |> then(fn [headers | data] ->
    Enum.map(data, fn row ->
      Enum.zip(headers, row) |> Map.new()
    end)
  end)

IO.puts("  #{length(rows)} laws in aggregate")

# --- 2. Apply thresholds ---
status_map = %{
  "non_compliant" => "❌ Non-Compliant",
  "partial" => "⚠️ Partially Compliant",
  "compliant" => "✅ Compliant"
}

updates =
  rows
  |> Enum.filter(fn row -> row["org_status"] in ["COMPLIANT", "ACTION_REQUIRED"] end)
  |> Enum.map(fn row ->
    name = row["name"]
    sites_ar = String.to_integer(row["sites_action_required"])
    breakdown = row["site_breakdown"]

    {baserow_status, notes} =
      cond do
        sites_ar > 5 ->
          {"❌ Non-Compliant", "Action required at #{sites_ar} sites.\n#{breakdown}"}

        sites_ar > 2 ->
          {"⚠️ Partially Compliant", "Action required at #{sites_ar} sites.\n#{breakdown}"}

        sites_ar > 0 ->
          {"⚠️ Partially Compliant", "Action required at #{sites_ar} site(s).\n#{breakdown}"}

        true ->
          {"✅ Compliant", "Compliant across all applicable sites.\n#{breakdown}"}
      end

    {name, baserow_status, notes}
  end)

# Summarise
compliant = Enum.count(updates, fn {_, s, _} -> s == "✅ Compliant" end)
partial = Enum.count(updates, fn {_, s, _} -> s == "⚠️ Partially Compliant" end)
non_compliant = Enum.count(updates, fn {_, s, _} -> s == "❌ Non-Compliant" end)

IO.puts("\nUpdates to apply:")
IO.puts("  ✅ Compliant:           #{compliant}")
IO.puts("  ⚠️ Partially Compliant: #{partial}")
IO.puts("  ❌ Non-Compliant:       #{non_compliant}")
IO.puts("  Total:                  #{length(updates)}")

if dry_run do
  IO.puts("\n--dry-run: not updating Baserow")

  updates
  |> Enum.reject(fn {_, s, _} -> s == "✅ Compliant" end)
  |> Enum.each(fn {name, status, _notes} ->
    IO.puts("  #{name} → #{status}")
  end)

  System.halt(0)
end

# --- 3. Authenticate to Baserow ---
IO.puts("\nAuthenticating to Baserow...")
{:ok, sc} = Ash.get(SyncConfiguration, config_id)
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

assessments_table_id = sc.target_config["assessments_table_id"]
config = Map.put(config, "assessments_table_id", assessments_table_id)

IO.puts("  Assessments table: #{assessments_table_id}")

# --- 4. Get existing assessment rows (Name → row_id) ---
IO.puts("Fetching existing assessment rows...")
{:ok, assessment_map} = Client.list_all_rows(config, assessments_table_id)
IO.puts("  #{map_size(assessment_map)} assessment rows in Baserow")

# --- 5. Build batch_update payload ---
update_rows =
  updates
  |> Enum.flat_map(fn {name, status, notes} ->
    case Map.get(assessment_map, name) do
      nil ->
        IO.puts("  WARN: no assessment row for #{name}")
        []

      row_ids ->
        # Usually one row per law, but handle multiple
        Enum.map(row_ids, fn row_id ->
          %{
            "id" => row_id,
            "Compliance_Status" => status,
            "Notes" => notes
          }
        end)
    end
  end)

IO.puts("\n  #{length(update_rows)} Baserow rows to update")

if update_rows == [] do
  IO.puts("Nothing to update.")
else
  case Client.batch_update(config, :assessments, update_rows) do
    {:ok, count} ->
      IO.puts("  ✓ Updated #{count} assessment rows")

    {:error, reason} ->
      IO.puts("  ERROR: #{inspect(reason)}")
  end
end
