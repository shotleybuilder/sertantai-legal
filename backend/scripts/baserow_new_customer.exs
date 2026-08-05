# Add a new customer to the Baserow demo Compliance Workbench.
#
# Creates a customer row in the Customers table and links applicable
# LRT rows to the new customer via the Customers link_row field.
#
# Usage:
#   mix run scripts/baserow_new_customer.exs --name "Acme Corp"
#   mix run scripts/baserow_new_customer.exs --name "Acme Corp" --industry "Manufacturing"
#   mix run scripts/baserow_new_customer.exs --name "Acme Corp" --families "Health and Safety,Environment"
#   mix run scripts/baserow_new_customer.exs --name "Acme Corp" --all-laws
#   mix run scripts/baserow_new_customer.exs --list
#
# Options:
#   --name        Customer name (required unless --list)
#   --industry    Industry sector (optional)
#   --notes       Internal notes (optional)
#   --families    Comma-separated list of law families to link (default: all)
#   --all-laws    Link all LRT rows (same as omitting --families)
#   --list        List existing customers and exit
#   --config      Sync config UUID (default: first found)
#   --dry-run     Show what would be created without creating

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Repo

{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [
      name: :string,
      industry: :string,
      notes: :string,
      families: :string,
      all_laws: :boolean,
      list: :boolean,
      config: :string,
      dry_run: :boolean
    ]
  )

# ── Load sync config ──────────────────────────────────────────────

config_id =
  case opts[:config] do
    nil ->
      case Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
        {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
        _ -> raise "No sync configuration found"
      end

    uuid ->
      uuid
  end

sc = Repo.get!(SyncConfiguration, config_id)
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)

token =
  creds["database_token"] ||
    raise "No database_token in credentials — use update_sync_target.exs --token"

base_url = sc.target_config["base_url"]

customers_table_id =
  sc.target_config["customers_table_id"] ||
    raise "No customers_table_id — run templates.apply with customers template"

lrt_table_id = sc.target_config["lrt_table_id"] || raise "No lrt_table_id in config"

headers = [{"Authorization", "Token #{token}"}, {"Content-Type", "application/json"}]

# ── List mode ─────────────────────────────────────────────────────

if opts[:list] do
  {:ok, %{body: %{"results" => rows, "count" => count}}} =
    Req.get(
      "#{base_url}/api/database/rows/table/#{customers_table_id}/?user_field_names=true&size=200",
      headers: headers,
      receive_timeout: 15_000
    )

  IO.puts("Customers in demo Baserow (#{count}):\n")

  if count == 0 do
    IO.puts("  (none)")
  else
    for r <- rows do
      laws = length(r["Legal Register"] || [])

      IO.puts(
        "  #{r["id"]}. #{r["Name"]} — #{r["Industry"] || "(no industry)"} — #{laws} laws linked"
      )
    end
  end

  System.halt(0)
end

# ── Validate ──────────────────────────────────────────────────────

name = opts[:name] || raise "Missing --name"
dry_run = opts[:dry_run] || false

IO.puts("Customer: #{name}")
IO.puts("Baserow:  #{base_url}")
IO.puts("Database token auth")
if dry_run, do: IO.puts("DRY RUN — no changes will be made")
IO.puts("")

# Check customer doesn't already exist
{:ok, %{body: %{"results" => existing}}} =
  Req.get(
    "#{base_url}/api/database/rows/table/#{customers_table_id}/?user_field_names=true&filter__Name__equal=#{URI.encode(name)}",
    headers: headers,
    receive_timeout: 15_000
  )

if existing != [] do
  IO.puts("ERROR: Customer '#{name}' already exists (row #{hd(existing)["id"]})")
  System.halt(1)
end

# ── Determine which LRT rows to link ─────────────────────────────

family_filter = opts[:families]

{lrt_ids, filter_desc} =
  if family_filter && !opts[:all_laws] do
    families = String.split(family_filter, ",") |> Enum.map(&String.trim/1)

    # Fetch LRT rows filtered by family
    # Baserow OR filter: filter__Family__contains_word for each family
    # Simpler: fetch all and filter locally (max ~700 rows)
    {:ok, %{body: %{"count" => total}}} =
      Req.get("#{base_url}/api/database/rows/table/#{lrt_table_id}/?size=1", headers: headers)

    pages = max(ceil(total / 200), 1)

    ids =
      Enum.flat_map(1..pages, fn page ->
        {:ok, %{body: %{"results" => results}}} =
          Req.get(
            "#{base_url}/api/database/rows/table/#{lrt_table_id}/?user_field_names=true&size=200&page=#{page}&include=Family",
            headers: headers,
            receive_timeout: 30_000
          )

        results
        |> Enum.filter(fn r ->
          family_value = get_in(r, ["Family", "value"]) || ""
          family_value in families
        end)
        |> Enum.map(& &1["id"])
      end)

    {ids, "families: #{Enum.join(families, ", ")}"}
  else
    # All LRT rows
    {:ok, %{body: %{"count" => total}}} =
      Req.get("#{base_url}/api/database/rows/table/#{lrt_table_id}/?size=1", headers: headers)

    pages = max(ceil(total / 200), 1)

    ids =
      Enum.flat_map(1..pages, fn page ->
        {:ok, %{body: %{"results" => results}}} =
          Req.get(
            "#{base_url}/api/database/rows/table/#{lrt_table_id}/?size=200&page=#{page}&fields=",
            headers: headers,
            receive_timeout: 30_000
          )

        Enum.map(results, & &1["id"])
      end)

    {ids, "all laws"}
  end

IO.puts("Laws to link: #{length(lrt_ids)} (#{filter_desc})")

if dry_run do
  IO.puts("\nDry run complete. Would create customer '#{name}' and link #{length(lrt_ids)} laws.")
  System.halt(0)
end

# ── Create customer row ───────────────────────────────────────────

customer_data = %{"Name" => name}

customer_data =
  if opts[:industry], do: Map.put(customer_data, "Industry", opts[:industry]), else: customer_data

customer_data =
  if opts[:notes], do: Map.put(customer_data, "Notes", opts[:notes]), else: customer_data

{:ok, %{status: 200, body: row}} =
  Req.post(
    "#{base_url}/api/database/rows/table/#{customers_table_id}/?user_field_names=true",
    headers: headers,
    json: customer_data
  )

customer_row_id = row["id"]
IO.puts("Created customer '#{name}' (row #{customer_row_id})")

# ── Link LRT rows ────────────────────────────────────────────────

if lrt_ids == [] do
  IO.puts("No laws to link.")
else
  lrt_ids
  |> Enum.chunk_every(200)
  |> Enum.with_index(1)
  |> Enum.each(fn {chunk, batch_num} ->
    items = Enum.map(chunk, fn id -> %{"id" => id, "Customers" => [customer_row_id]} end)

    case Req.patch(
           "#{base_url}/api/database/rows/table/#{lrt_table_id}/batch/?user_field_names=true",
           headers: headers,
           json: %{"items" => items},
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200}} ->
        IO.puts("  Linked batch #{batch_num}: #{length(chunk)} laws")

      {:ok, %{status: s, body: b}} ->
        IO.puts("  Batch #{batch_num} FAILED: #{s} #{inspect(b)}")

      {:error, reason} ->
        IO.puts("  Batch #{batch_num} ERROR: #{inspect(reason)}")
    end
  end)
end

IO.puts("\nDone. Customer '#{name}' added with #{length(lrt_ids)} laws linked.")

IO.puts(
  "View at: #{base_url}/database/#{sc.target_config["database_id"]}/table/#{customers_table_id}"
)
