# Fix the Mapping formula on ControlMappings table in Baserow
# Usage: mix run scripts/fix_mapping_formula.exs

alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
alias SertantaiLegal.Baserow.Client
alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

config_id = "90b9c916-e06b-48ff-861f-065f3778fd7a"

{:ok, sc} = Ash.get(SyncConfiguration, config_id)
creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)

config = %{
  "base_url" => sc.target_config["base_url"],
  "credentials" => creds
}

{:ok, config} = BaserowProvider.authenticate(config)
cm_table_id = sc.target_config["control_mappings_table_id"]

IO.puts("Fetching fields for CM table #{cm_table_id}...")
{:ok, fields} = Client.list_fields(config, cm_table_id)

mapping = Enum.find(fields, fn f -> f["name"] == "Mapping" end)

unless mapping do
  IO.puts("ERROR: Mapping field not found")
  System.halt(1)
end

IO.puts("Found Mapping field: #{mapping["id"]} (type: #{mapping["type"]})")

new_formula = """
if(isblank(join(field('Duties'), '')), \
concat(join(field('Legal_Register'), ', '), ' ↔ ', join(lookup('Controls', 'Title'), ', ')), \
concat(join(field('Duties'), ', '), ' ↔ ', join(lookup('Controls', 'Title'), ', ')))\
"""

IO.puts("New formula: #{new_formula}")

result = Client.update_field(config, mapping["id"], %{"formula" => String.trim(new_formula)})
IO.inspect(result, label: "Result", limit: 5)
