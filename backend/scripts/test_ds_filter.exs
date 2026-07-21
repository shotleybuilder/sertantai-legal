# Test data source filter formats for link_row field

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

ds_id = 1960034

# Try various filter types for link_row
filter_types = [
  "link_row_has",
  "link_row_contains",
  "has_value_contains",
  "contains",
  "equal"
]

Enum.each(filter_types, fn type ->
  body = %{
    "filters" => [%{
      "field" => 9565223,
      "type" => type,
      "value" => formula.("get('query_parameter.law')")
    }]
  }

  {:ok, %{status: s, body: resp}} = Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
    headers: headers, json: body, receive_timeout: 15_000)

  if s == 200 do
    IO.puts("  #{type}: ✓ SUCCESS")
    # Reset filters
    Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
      headers: headers, json: %{"filters" => []}, receive_timeout: 15_000)
  else
    error = get_in(resp, ["detail", "filters", Access.at(0)])
    IO.puts("  #{type}: ✗ #{s} #{inspect(error, limit: 3)}")
  end
end)
