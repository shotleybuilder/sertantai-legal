defmodule SertantaiLegal.Sync.Delta.SqlGenerator do
  @moduledoc "Generates INSERT ... ON CONFLICT DO UPDATE SQL statements."

  def generate_upsert(table_name, pk_col, columns, row) do
    col_names = Enum.map(columns, fn c -> quote_ident(c.pg_name) end)
    values = Enum.map(columns, fn c -> escape_value(Map.get(row, c.pg_name), c.type) end)

    update_cols =
      columns
      |> Enum.reject(fn c -> c.pg_name == pk_col end)
      |> Enum.map(fn c -> "#{quote_ident(c.pg_name)} = EXCLUDED.#{quote_ident(c.pg_name)}" end)

    """
    INSERT INTO #{quote_ident(table_name)} (#{Enum.join(col_names, ", ")})
    VALUES (#{Enum.join(values, ", ")})
    ON CONFLICT (#{quote_ident(pk_col)}) DO UPDATE SET
      #{Enum.join(update_cols, ",\n      ")};
    """
  end

  def quote_ident(name), do: ~s("#{name}")

  def escape_value(nil, _type), do: "NULL"

  # Maps and JSONB — handle Ash.Type.Map and plain :map
  def escape_value(value, _type) when is_map(value) and not is_struct(value) do
    json = Jason.encode!(value)
    "'#{escape_string(json)}'::jsonb"
  end

  # Arrays of maps/JSONB — build ARRAY[elem::jsonb, ...] literal
  def escape_value(value, {:array, inner})
      when is_list(value) and inner in [:map, Ash.Type.Map] do
    if value == [] do
      "'{}'"
    else
      elements =
        Enum.map(value, fn elem ->
          json = Jason.encode!(elem)
          "'#{escape_string(json)}'::jsonb"
        end)

      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # Arrays of strings
  def escape_value(value, {:array, inner})
      when is_list(value) and inner in [:string, Ash.Type.String] do
    if value == [] do
      "'{}'"
    else
      elements = Enum.map(value, fn v -> "'#{escape_string(to_string(v))}'" end)
      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # Arrays of other types
  def escape_value(value, {:array, _inner}) when is_list(value) do
    if value == [] do
      "'{}'"
    else
      elements =
        Enum.map(value, fn
          v when is_binary(v) -> "'#{escape_string(v)}'"
          v when is_integer(v) -> to_string(v)
          v when is_map(v) -> "'#{escape_string(Jason.encode!(v))}'"
          v -> to_string(v)
        end)

      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # UUID binary (16 bytes from Postgrex) — only when type is :uuid or Ash.Type.UUID
  def escape_value(<<_::128>> = value, type) when type in [:uuid, Ash.Type.UUID] do
    "'#{format_uuid(value)}'"
  end

  # Scalars — booleans before atoms (false/true are atoms)
  def escape_value(value, _type) when is_boolean(value), do: to_string(value)

  # Atoms (Ash enums stored as strings in Postgres)
  def escape_value(value, _type) when is_atom(value) and not is_nil(value) do
    "'#{escape_string(to_string(value))}'"
  end

  def escape_value(value, _type) when is_binary(value), do: "'#{escape_string(value)}'"
  def escape_value(value, _type) when is_integer(value), do: to_string(value)
  def escape_value(value, _type) when is_float(value), do: to_string(value)

  # Dates/times
  def escape_value(%DateTime{} = dt, _type), do: "'#{DateTime.to_iso8601(dt)}'::timestamptz"

  def escape_value(%NaiveDateTime{} = dt, _type),
    do: "'#{NaiveDateTime.to_iso8601(dt)}'::timestamp"

  def escape_value(%Date{} = d, _type), do: "'#{Date.to_iso8601(d)}'::date"

  # Decimal
  def escape_value(%Decimal{} = d, _type), do: Decimal.to_string(d)

  # Catch-all for unexpected types — JSON encode
  def escape_value(value, _type) do
    json = Jason.encode!(value)
    "'#{escape_string(json)}'::jsonb"
  end

  defp escape_string(str), do: String.replace(str, "'", "''")

  defp format_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    # Fixed widths per UUID spec: 8-4-4-4-12
    [{a, 8}, {b, 4}, {c, 4}, {d, 4}, {e, 12}]
    |> Enum.map_join("-", fn {part, width} ->
      Integer.to_string(part, 16) |> String.pad_leading(width, "0") |> String.downcase()
    end)
  end
end
