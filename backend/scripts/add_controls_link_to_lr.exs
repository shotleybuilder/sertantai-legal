# Add Controls link column to Legal Register table

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]
formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

# Get LR table element
{:ok, %{body: elements}} = Req.get("#{base}/api/builder/page/1071076/elements/",
  headers: headers, receive_timeout: 15_000)
table = Enum.find(elements, fn e -> e["type"] == "table" end)

# Check if Controls link already exists
has_controls = Enum.any?(table["fields"], fn f -> f["name"] == "Controls" end)

unless has_controls do
  # LRT Name field = 9564633
  controls_link = %{
    "name" => "Controls",
    "type" => "link",
    "navigate_to_page_id" => 1074454,
    "navigation_type" => "page",
    "query_parameters" => [%{"name" => "law", "value" => "get('current_record.field_9564633')"}],
    "link_name" => formula.("\"Controls →\"")
  }

  # Insert before Duties (second to last position)
  {before_duties, from_duties} = Enum.split_while(table["fields"], fn f -> f["name"] != "Duties" end)
  updated_fields = before_duties ++ [controls_link] ++ from_duties

  {:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{table["id"]}/",
    headers: headers, json: %{"fields" => updated_fields}, receive_timeout: 15_000)
  IO.puts("Added Controls link: #{s}")
else
  IO.puts("Controls link already exists")
end

# Publish
{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
