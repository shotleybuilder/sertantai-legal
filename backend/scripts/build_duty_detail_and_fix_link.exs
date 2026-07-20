# Build duty_detail page and fix the Details link on duties_list page

alias SertantaiLegal.Baserow.App.{RecipeParser, FieldResolver, PageBuilder}
alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

{:ok, sc} = Ash.get(SyncConfiguration, "90b9c916-e06b-48ff-861f-065f3778fd7a")
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
{:ok, config} = BaserowProvider.authenticate(config)

headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
base = config["base_url"]

{:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
builder = Enum.find(apps, fn a -> a["type"] == "builder" end)
{:ok, %{body: intgs}} = Req.get("#{base}/api/application/#{builder["id"]}/integrations/", headers: headers, receive_timeout: 15_000)

tc = sc.target_config
table_ids = %{lat: tc["lat_table_id"], lrt: tc["lrt_table_id"]}
|> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()
resolver = FieldResolver.build(config, table_ids)

pages = builder["pages"] |> Enum.reject(fn p -> p["shared"] end)
duties_page_id = Enum.find_value(pages, fn p -> if p["path"] == "/legal-duties", do: p["id"] end)

# Step 1: Build duty_detail page from recipe
page_registry = %{duties_list: duties_page_id}

{:ok, recipe} = RecipeParser.load(:duty_detail)
{:ok, detail_page_id} = PageBuilder.build(recipe,
  config: config, builder_id: builder["id"], integration_id: hd(intgs)["id"],
  table_ids: table_ids, resolver: resolver, page_registry: page_registry)
IO.puts("Detail page: #{detail_page_id}")

# Step 2: Fix the Details link on duties_list table
{:ok, %{body: elements}} = Req.get("#{base}/api/builder/page/#{duties_page_id}/elements/",
  headers: headers, receive_timeout: 15_000)
table = Enum.find(elements, fn e -> e["type"] == "table" end)

formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

updated_fields = Enum.map(table["fields"], fn f ->
  if f["name"] == "Details" do
    %{
      "name" => "Details",
      "type" => "link",
      "navigate_to_page_id" => detail_page_id,
      "navigation_type" => "page",
      "page_parameters" => [%{"name" => "id", "value" => "get('current_record.id')"}]
    }
  else
    f
  end
end)

{:ok, %{status: s}} = Req.patch("#{base}/api/builder/element/#{table["id"]}/",
  headers: headers, json: %{"fields" => updated_fields}, receive_timeout: 15_000)
IO.puts("Fixed Details link: #{s}")

# Publish
{:ok, %{body: domains}} = Req.get("#{base}/api/builder/#{builder["id"]}/domains/", headers: headers, receive_timeout: 15_000)
{:ok, %{status: ps}} = Req.post("#{base}/api/builder/domains/#{hd(domains)["id"]}/publish/async/", headers: headers, json: %{}, receive_timeout: 15_000)
IO.puts("Published: #{ps}")

IO.puts("\nManual steps for duty_detail:")
Enum.each(RecipeParser.manual_steps(recipe), fn s -> IO.puts("  - #{s}") end)
