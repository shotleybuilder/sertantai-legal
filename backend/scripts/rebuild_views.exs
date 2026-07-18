# Delete all custom views (keeping only default "Grid") from all Baserow tables,
# then re-run templates.apply to recreate with proper filters/sorts/groups.
# Usage: mix run scripts/rebuild_views.exs

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

# Collect all table IDs
table_ids =
  sc.target_config
  |> Enum.filter(fn {k, _} -> String.ends_with?(k, "_table_id") end)
  |> Enum.map(fn {k, v} -> {String.replace_suffix(k, "_table_id", ""), v} end)
  |> Enum.reject(fn {_, v} -> is_nil(v) end)

total_deleted =
  Enum.reduce(table_ids, 0, fn {label, table_id}, acc ->
    case Client.list_views(config, table_id) do
      {:ok, views} ->
        # Delete all views except the default "Grid" (first view, usually ID-ordered lowest)
        custom_views = Enum.reject(views, fn v -> v["name"] == "Grid" end)

        if custom_views != [] do
          IO.puts("#{label}: deleting #{length(custom_views)} custom views")

          Enum.each(custom_views, fn view ->
            case Client.delete_view(config, view["id"]) do
              :ok -> :ok
              {:error, reason} -> IO.puts("  FAILED: #{view["name"]} — #{reason}")
            end
          end)
        end

        acc + length(custom_views)

      {:error, reason} ->
        IO.puts("#{label}: failed to list views — #{reason}")
        acc
    end
  end)

IO.puts("\nDeleted #{total_deleted} custom views")
IO.puts("Now run: mix templates.apply --templates <all> to recreate with proper config")
