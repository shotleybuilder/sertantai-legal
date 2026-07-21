# Fix Duties table columns: tags need *.value for values and *.color for colors

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

duties_table_element = 14084049
detail_page_id = 1073186

fields = [
  %{"name" => "Provision", "type" => "text",
    "value" => formula.("get('current_record.field_9565217')")},
  %{"name" => "Duty Text", "type" => "text",
    "value" => formula.("get('current_record.field_9565216')")},
  %{"name" => "Type", "type" => "tags",
    "values" => formula.("get('current_record.field_9565210.*.value')"),
    "colors" => formula.("get('current_record.field_9565210.*.color')")},
  %{"name" => "Actors", "type" => "tags",
    "values" => formula.("get('current_record.field_9565215.*.value')"),
    "colors" => formula.("get('current_record.field_9565215.*.color')")},
  %{"name" => "Significance", "type" => "text",
    "value" => formula.("get('current_record.field_9565218.value')")},
  %{"name" => "Details", "type" => "link",
    "navigate_to_page_id" => detail_page_id,
    "navigation_type" => "page",
    "page_parameters" => [%{"name" => "id",
      "value" => "get('current_record.id')"}]}
]

{:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{duties_table_element}/",
  headers: headers, json: %{"fields" => fields}, receive_timeout: 15_000)
IO.puts("Updated: #{s}")

{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
