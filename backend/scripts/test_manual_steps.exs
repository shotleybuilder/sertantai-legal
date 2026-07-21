# Test if remaining manual steps can be done via API

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

# ── Test 1: Set Get Row data source row_id ──────────────
# Current Duty DS = 1960747 on detail page 1073685
IO.puts("=== Test 1: Get Row data source row_id ===")

{:ok, %{status: s1}} = Req.patch("#{base}/api/builder/data-source/1960747/",
  headers: headers,
  json: %{"row_id" => formula.("get('page_parameter.id')")},
  receive_timeout: 15_000)
IO.puts("Set row_id: #{s1}")

# ── Test 2: Set List Rows data source filter ────────────
# Duties DS = 1960034 on list page 1073284
IO.puts("\n=== Test 2: List Rows data source filter ===")

{:ok, %{body: ds_list}} = Req.get("#{base}/api/builder/page/1073284/data-sources/",
  headers: headers, receive_timeout: 15_000)
duties_ds = Enum.find(ds_list, fn d -> d["name"] == "Duties" end)
IO.puts("DS id: #{duties_ds["id"]}")
IO.puts("Current filters: #{inspect(duties_ds["filters"])}")

# Legal_Register field on LAT = 9565223 (link_row)
# Try setting a filter that matches the law query parameter
{:ok, %{status: s2, body: b2}} = Req.patch("#{base}/api/builder/data-source/#{duties_ds["id"]}/",
  headers: headers,
  json: %{
    "filters" => [%{
      "field" => 9565223,
      "type" => "link_row_has",
      "value" => formula.("get('query_parameter.law')")
    }]
  },
  receive_timeout: 15_000)
IO.puts("Set filter: #{s2}")
if s2 != 200, do: IO.inspect(b2, limit: 10, pretty: true)

# ── Test 3: Check all data sources for manual_config ────
IO.puts("\n=== All data sources across all pages ===")

{:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
builder = Enum.find(apps, fn a -> a["type"] == "builder" end)

Enum.each(builder["pages"], fn page ->
  unless page["shared"] do
    {:ok, %{body: ds_list}} = Req.get("#{base}/api/builder/page/#{page["id"]}/data-sources/",
      headers: headers, receive_timeout: 15_000)

    Enum.each(ds_list, fn ds ->
      row_id = get_in(ds, ["row_id", "formula"])
      filters = ds["filters"]
      has_config = (row_id && row_id != "") || (filters && filters != [])
      status = if has_config, do: "✓", else: "⬜"
      IO.puts("  #{status} #{page["name"]}/#{ds["name"]} row_id=#{inspect(row_id)} filters=#{inspect(filters)}")
    end)
  end
end)
