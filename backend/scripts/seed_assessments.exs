# Seed the Assessments table with one row per law in the customer's Legal Register.
# Creates "Not Assessed" rows with Risk_Level pre-populated from significance_rating.
# Idempotent — skips laws that already have an assessment.
#
# Usage: mix run scripts/seed_assessments.exs [--config UUID]

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Baserow.Client
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

config_id =
  case System.argv() do
    ["--config", id | _] -> id
    _ -> "90b9c916-e06b-48ff-861f-065f3778fd7a"
  end

{:ok, sc} = Ash.get(SyncConfiguration, config_id)
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

lrt_table_id = sc.target_config["lrt_table_id"]
assessments_table_id = sc.target_config["assessments_table_id"]

IO.puts("Seeding assessments for config #{config_id}")
IO.puts("  LRT table: #{lrt_table_id}")
IO.puts("  Assessments table: #{assessments_table_id}")

# 1. Get all LRT rows (Name → row_ids)
{:ok, lrt_map} = Client.list_all_rows(config, lrt_table_id)
IO.puts("  LRT rows: #{map_size(lrt_map)}")

# 2. Get existing assessments to skip duplicates
{:ok, existing_assessments} = Client.list_all_rows(config, assessments_table_id)
existing_names = MapSet.new(Map.keys(existing_assessments))
IO.puts("  Existing assessments: #{map_size(existing_assessments)}")

# 3. Get significance ratings from Postgres for risk level pre-population
org_id = sc.organization_id
{:ok, org_bin} = Ecto.UUID.dump(org_id)

{:ok, %{rows: sig_rows}} =
  SertantaiLegal.Repo.query(
    """
    SELECT lr.name, lr.significance_rating
    FROM legal_register_uk lr
    JOIN org_applicabilities oa ON oa.law_name = lr.name
      AND oa.organization_id = $1
      AND oa.status = 'yes'
    WHERE lr.live NOT LIKE '%Revoked%'
      AND lr.live NOT LIKE '%Repealed%'
      AND lr.live NOT LIKE '%Abolished%'
    """,
    [org_bin]
  )

significance_map = Map.new(sig_rows, fn [name, sig] -> {name, sig} end)

# Map significance to Risk_Level
sig_to_risk = %{
  "HIGH" => "High",
  "MEDIUM" => "Medium",
  "LOW" => "Low"
}

# 4. Build assessment rows for laws that don't have one yet
next_review = Date.add(Date.utc_today(), 90) |> Date.to_iso8601()

new_rows =
  lrt_map
  |> Enum.reject(fn {name, _ids} -> MapSet.member?(existing_names, name) end)
  |> Enum.map(fn {name, _ids} ->
    sig = Map.get(significance_map, name)
    risk = Map.get(sig_to_risk, sig, "Medium")

    %{
      "Name" => name,
      "Legal_Register" => name,
      "Compliance_Status" => "Not Assessed",
      "Risk_Level" => risk,
      "Next_Review_Date" => next_review
    }
  end)

IO.puts("  New assessments to create: #{length(new_rows)}")

if new_rows == [] do
  IO.puts("\nNo new assessments needed.")
else
  config_with_ids = Map.put(config, "assessments_table_id", assessments_table_id)

  case Client.batch_create(config_with_ids, :assessments, new_rows) do
    {:ok, mappings} ->
      IO.puts("\nCreated #{length(mappings)} assessments")

    {:error, reason} ->
      IO.puts("\nERROR: #{inspect(reason)}")
  end
end
