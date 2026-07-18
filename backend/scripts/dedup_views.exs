# Remove duplicate views from all Baserow tables in the sync config.
# Keeps the first view of each name, deletes the rest.
# Usage: mix run scripts/dedup_views.exs

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

# Collect all table IDs from the sync config
table_ids =
  sc.target_config
  |> Enum.filter(fn {k, _} -> String.ends_with?(k, "_table_id") end)
  |> Enum.map(fn {k, v} -> {String.replace_suffix(k, "_table_id", ""), v} end)
  |> Enum.reject(fn {_, v} -> is_nil(v) end)

total_deleted = 0

total_deleted =
  Enum.reduce(table_ids, 0, fn {label, table_id}, acc ->
    case Client.list_views(config, table_id) do
      {:ok, views} ->
        # Group by name, keep first (lowest ID), delete rest
        duplicates =
          views
          |> Enum.group_by(& &1["name"])
          |> Enum.flat_map(fn {_name, group} ->
            group
            |> Enum.sort_by(& &1["id"])
            |> Enum.drop(1)
          end)

        if duplicates != [] do
          IO.puts("#{label}: #{length(duplicates)} duplicate views to delete")

          Enum.each(duplicates, fn view ->
            case Client.delete_view(config, view["id"]) do
              :ok -> IO.puts("  Deleted: #{view["name"]} (#{view["id"]})")
              {:error, reason} -> IO.puts("  FAILED: #{view["name"]} — #{reason}")
            end
          end)
        end

        acc + length(duplicates)

      {:error, reason} ->
        IO.puts("#{label}: failed to list views — #{reason}")
        acc
    end
  end)

IO.puts("\nTotal duplicate views deleted: #{total_deleted}")
