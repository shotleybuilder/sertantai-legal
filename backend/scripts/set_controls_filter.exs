# Set the Legal_Register filter on the Controls data source

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

# Find the Controls data source on the Controls page (1074454)
{:ok, %{body: ds_list}} = Req.get("#{base}/api/builder/page/1074454/data-sources/",
  headers: headers, receive_timeout: 15_000)
controls_ds = Enum.find(ds_list, fn d -> d["name"] == "Controls" end)
IO.puts("Controls DS: #{controls_ds["id"]}")

# Get the Legal_Register field ID on the Controls table
{:ok, fields} = SertantaiLegal.Baserow.Client.list_fields(config, sc.target_config["controls_table_id"])
lr_field = Enum.find(fields, fn f -> f["name"] == "Legal_Register" end)
IO.puts("Legal_Register field: #{lr_field["id"]}")

# Set the filter
{:ok, %{status: s}} = Req.patch("#{base}/api/builder/data-source/#{controls_ds["id"]}/",
  headers: headers,
  json: %{
    "filters" => [%{
      "field" => lr_field["id"],
      "type" => "link_row_contains",
      "value" => %{
        "formula" => "get('page_parameter.law')",
        "mode" => "simple",
        "version" => "0.1"
      },
      "value_is_formula" => true
    }]
  },
  receive_timeout: 15_000)
IO.puts("Set filter: #{s}")

# Publish
{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
