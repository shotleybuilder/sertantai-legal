# Set the law query parameter on the Duties link in the Legal Register page

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

{:ok, %{body: elements}} = Req.get("#{base}/api/builder/page/1071076/elements/",
  headers: headers, receive_timeout: 15_000)
table = Enum.find(elements, fn e -> e["type"] == "table" end)

# LRT Name field = 9564633
updated_fields = Enum.map(table["fields"], fn f ->
  if f["name"] == "Duties" do
    Map.put(f, "query_parameters", [
      %{"name" => "law", "value" => "get('current_record.field_9564633')"}
    ])
  else
    f
  end
end)

{:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{table["id"]}/",
  headers: headers, json: %{"fields" => updated_fields}, receive_timeout: 15_000)
IO.puts("Set query_parameters: #{s}")

# Publish
{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
