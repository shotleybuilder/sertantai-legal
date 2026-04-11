defmodule SertantaiLegal.Sync.Delta.ColumnMapper do
  @moduledoc "Discovers Elixir attribute → Postgres column mappings from Ash resources."

  def writable_columns(resource, excluded) do
    pk_names =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(& &1.primary_key?)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reject(fn attr ->
      pg_name = postgres_column_name(attr)
      # Always include PK columns (even if writable? is false)
      # Skip non-writable (generated/trigger-maintained) or explicitly excluded columns
      !MapSet.member?(pk_names, attr.name) && (!attr.writable? || pg_name in excluded)
    end)
    |> Enum.map(fn attr ->
      %{
        elixir_name: attr.name,
        pg_name: postgres_column_name(attr),
        type: attr.type
      }
    end)
  end

  def postgres_column_name(attr) do
    # The source: option on the attribute holds the actual Postgres column name
    # (e.g., emoji-prefixed stats columns). Falls back to the Elixir attribute name.
    to_string(attr.source || attr.name)
  end
end
