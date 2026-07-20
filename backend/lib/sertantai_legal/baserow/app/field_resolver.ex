defmodule SertantaiLegal.Baserow.App.FieldResolver do
  @moduledoc """
  Resolves field names to Baserow field IDs for a table.

  Caches resolved fields per table to avoid repeated API calls.
  Handles formula template interpolation: `{Field_Name}` → `field_ID`.
  """

  alias SertantaiLegal.Baserow.Client

  @doc """
  Build a resolver for a set of tables. Returns a map of
  `table_key → %{field_name → field_id}`.
  """
  def build(config, table_ids) when is_map(table_ids) do
    Map.new(table_ids, fn {table_key, table_id} ->
      {:ok, fields} = Client.list_fields(config, table_id)
      field_map = Map.new(fields, fn f -> {f["name"], f["id"]} end)
      {table_key, field_map}
    end)
  end

  @doc """
  Resolve a field name to its ID for a given table.
  """
  def resolve(resolver, table_key, field_name) do
    resolver
    |> Map.get(table_key, %{})
    |> Map.get(field_name)
  end

  @doc """
  Interpolate `{Field_Name}` placeholders in a formula string with actual field IDs.

  Example:
    "get('current_record.field_{Title}')" with resolver for :lrt
    → "get('current_record.field_9565190')"
  """
  def interpolate_formula(formula, resolver, table_key) when is_binary(formula) do
    Regex.replace(~r/\{([^}]+)\}/, formula, fn _, field_name ->
      case resolve(resolver, table_key, field_name) do
        nil -> "{#{field_name}}"
        id -> to_string(id)
      end
    end)
  end

  def interpolate_formula(nil, _resolver, _table_key), do: nil

  @doc """
  Build the formula expression for a table column based on field name and accessor.

  - field + no accessor: `get('current_record.field_ID')`
  - field + accessor: `get('current_record.field_ID{accessor}')`
  - raw formula: interpolate {Field_Name} placeholders
  """
  def column_formula(col, resolver, table_key) do
    cond do
      col["formula"] ->
        interpolate_formula(col["formula"], resolver, table_key)

      col["field"] && col["accessor"] ->
        field_id = resolve(resolver, table_key, col["field"])
        "get('current_record.field_#{field_id}#{col["accessor"]}')"

      col["field"] ->
        field_id = resolve(resolver, table_key, col["field"])
        "get('current_record.field_#{field_id}')"

      true ->
        nil
    end
  end
end
