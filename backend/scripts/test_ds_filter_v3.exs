# Verify we can set the same filter via API

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

ds_id = 1960034

# Clear first
Req.patch!("#{base}/api/builder/data-source/#{ds_id}/",
  headers: headers, json: %{"filters" => []}, receive_timeout: 15_000)
IO.puts("Cleared filters")

# Set with the correct format discovered from UI
{:ok, %{status: s}} = Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
  headers: headers,
  json: %{
    "filters" => [%{
      "field" => 9565223,
      "type" => "link_row_has",
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
