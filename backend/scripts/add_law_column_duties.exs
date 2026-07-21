# Add Law column as first column on duties list table

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

{:ok, %{body: elements}} = Req.get("#{base}/api/builder/page/1073284/elements/",
  headers: headers, receive_timeout: 15_000)
table = Enum.find(elements, fn e -> e["type"] == "table" end)

# Legal_Register on LAT = field 9565223 (link_row to LRT)
law_field = %{
  "name" => "Law", "type" => "text",
  "value" => formula.("get('current_record.field_9565223.*.value')")
}

updated_fields = [law_field | table["fields"]]

{:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{table["id"]}/",
  headers: headers, json: %{"fields" => updated_fields}, receive_timeout: 15_000)
IO.puts("Updated: #{s}")

{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
