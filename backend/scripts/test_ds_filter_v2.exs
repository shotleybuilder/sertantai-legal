# Test data source filter — try all possible formats

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

# First, let's set a filter manually in the UI, then inspect the result
# For now, try every combination

# Legal_Register = field 9565223 (link_row)
# Name = field 9564636 (text, primary field)

tests = [
  # Static value on text field (should work as baseline)
  {"Name contains static", %{"field" => 9564636, "type" => "contains", "value" => "UK_anaw"}},
  # Formula value on text field
  {"Name contains formula", %{"field" => 9564636, "type" => "contains", "value" => formula.("get('query_parameter.law')")}},
  # Static on link_row
  {"LR link_row_has static", %{"field" => 9565223, "type" => "link_row_has", "value" => "UK_anaw"}},
  # link_row_contains
  {"LR link_row_contains", %{"field" => 9565223, "type" => "link_row_contains", "value" => "UK_anaw"}},
  # Try equal on text field with formula
  {"Name equal formula", %{"field" => 9564636, "type" => "equal", "value" => formula.("get('query_parameter.law')")}},
  # The Name field contains the section_id like UK_anaw_2017_2:s.1
  # We want to match the law prefix. Try contains with formula on Name
  {"Name contains formula single quotes", %{"field" => 9564636, "type" => "contains",
    "value" => formula.("get('query_parameter.law')")}},
]

Enum.each(tests, fn {label, filter} ->
  {:ok, %{status: s, body: resp}} = Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
    headers: headers,
    json: %{"filters" => [filter]},
    receive_timeout: 15_000)

  if s == 200 do
    IO.puts("  ✓ #{label}")
    # Reset
    Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
      headers: headers, json: %{"filters" => []}, receive_timeout: 15_000)
  else
    error = inspect(resp["detail"], limit: 3)
    IO.puts("  ✗ #{label}: #{s} #{error}")
  end
end)
