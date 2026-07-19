# Fix Legal Register page columns:
# - Remove Actions link (two-hop, can't link directly)
# - Fix Assess link to go to Assessment Form (/assess/:id) with correct row ID
# - Assessment Status uses single-quote formula (working)

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

table_element_id = 14062228
assess_form_page_id = 1069372

fields = [
  %{"name" => "Title", "type" => "text",
    "value" => formula.("get('current_record.field_9565190')")},
  %{"name" => "Year", "type" => "text",
    "value" => formula.("get('current_record.field_9565192')")},
  %{"name" => "Family", "type" => "text",
    "value" => formula.("get('current_record.field_9565191.value')")},
  %{"name" => "Status", "type" => "text",
    "value" => formula.("get('current_record.field_9565195.value')")},
  %{"name" => "Significance", "type" => "text",
    "value" => formula.("get('current_record.field_9565198.value')")},
  %{"name" => "Assessment", "type" => "text",
    "value" => formula.("get('current_record.field_9627086.*.value.value')")},
  %{"name" => "Assess", "type" => "link",
    "navigate_to_page_id" => assess_form_page_id,
    "navigation_type" => "page",
    "page_parameters" => [
      %{"name" => "id", "value" => "get('current_record.field_9564709.0.id')"}
    ]}
]

{:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{table_element_id}/",
  headers: headers, json: %{"fields" => fields}, receive_timeout: 15_000)
IO.puts("Updated columns: #{s}")

# Publish
{:ok, %{body: domains}} = Req.get("#{base}/api/builder/497540/domains/",
  headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/",
  headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")
