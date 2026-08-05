# Update a SyncConfiguration's base_url and credentials.
#
# Usage (both — recommended for self-hosted: JWT for app builder, token for sync):
#   mix run scripts/update_sync_target.exs --url https://baserow.sertantai.com --email user@example.com --password secret --token YOUR_DATABASE_TOKEN
#
# Usage (email/password only — JWT auth, expires after ~10min):
#   mix run scripts/update_sync_target.exs --url https://baserow.sertantai.com --email user@example.com --password secret
#
# Usage (database token only — permanent, sync only, no app builder):
#   mix run scripts/update_sync_target.exs --url https://baserow.sertantai.com --token YOUR_DATABASE_TOKEN
#
# Options:
#   --config UUID   Target a specific sync config (default: first found)
#   --fresh         Clear all table IDs (for pointing at a new empty database)

alias SertantaiLegal.Repo
alias SertantaiLegal.Sync.Credentials

{opts, _, _} =
  OptionParser.parse(System.argv(),
    strict: [
      config: :string,
      url: :string,
      email: :string,
      password: :string,
      token: :string,
      fresh: :boolean
    ]
  )

url = opts[:url] || raise "Missing --url"
fresh = opts[:fresh] || false

# Build credentials map — supports all three together
creds = %{}

creds =
  if opts[:email] && opts[:password] do
    Map.merge(creds, %{"email" => opts[:email], "password" => opts[:password]})
  else
    creds
  end

creds =
  if opts[:token] do
    Map.put(creds, "database_token", opts[:token])
  else
    creds
  end

if creds == %{} do
  raise "Provide --token and/or --email + --password"
end

auth_mode =
  cond do
    Map.has_key?(creds, "email") && Map.has_key?(creds, "database_token") ->
      "email/password + database_token"

    Map.has_key?(creds, "email") ->
      "email/password"

    true ->
      "database_token"
  end

# Find sync config
config_id =
  case opts[:config] do
    nil ->
      case Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
        {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
        _ -> raise "No sync configuration found"
      end

    uuid ->
      uuid
  end

IO.puts("Sync config: #{config_id}")
IO.puts("New base_url: #{url}")
IO.puts("Auth mode: #{auth_mode}")

# Encrypt new credentials
{encrypted, iv} = Credentials.encrypt(creds)

# Build target_config update
{:ok, %{rows: [[existing_config]]}} =
  Repo.query("SELECT target_config FROM sync_configurations WHERE id = $1", [
    Ecto.UUID.dump!(config_id)
  ])

new_target_config =
  if fresh do
    # Strip all table IDs — fresh database
    keep_keys = [
      "lat_aggregated",
      "lat_drrp_types",
      "lat_governed_only",
      "lat_min_provision_significance"
    ]

    existing_config
    |> Map.take(keep_keys)
    |> Map.put("base_url", url)
  else
    Map.put(existing_config, "base_url", url)
  end

# Update
{:ok, %{num_rows: 1}} =
  Repo.query(
    """
    UPDATE sync_configurations
    SET encrypted_credentials = $1,
        credentials_iv = $2,
        target_config = $3,
        updated_at = NOW()
    WHERE id = $4
    """,
    [encrypted, iv, new_target_config, Ecto.UUID.dump!(config_id)]
  )

IO.puts("\nUpdated sync configuration:")
IO.puts("  base_url: #{new_target_config["base_url"]}")
IO.puts("  auth: #{auth_mode} (re-encrypted)")

if fresh do
  IO.puts("  table IDs: cleared (fresh database)")
end

IO.puts("\nNext steps:")
IO.puts("  1. mix templates.apply --fresh   # create tables on new Baserow")
IO.puts("  2. mix sync.run                  # populate data")
