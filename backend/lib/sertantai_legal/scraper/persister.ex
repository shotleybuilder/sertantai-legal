defmodule SertantaiLegal.Scraper.Persister do
  @moduledoc """
  Persists categorized laws to the uk_lrt table.

  Reads group JSON files and creates/updates UkLrt records.
  Handles duplicate detection by name (type_code/year/number).
  """

  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query

  @doc """
  Persist a specific group to the uk_lrt table.

  Groups: :group1, :group2, :group3

  Returns {:ok, count} with the number of records persisted.
  """
  @spec persist_group(String.t(), atom()) :: {:ok, non_neg_integer()} | {:error, any()}
  def persist_group(session_id, group) when group in [:group1, :group2, :group3] do
    IO.puts("\n=== PERSISTING #{group} for session: #{session_id} ===")

    case Storage.read_json(session_id, group) do
      {:ok, records} when is_list(records) ->
        persist_records(records)

      {:ok, records} when is_map(records) ->
        # Group 3 is indexed as a map - extract values
        persist_records(Map.values(records))

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Persist a list of records to the uk_lrt table.
  """
  @spec persist_records(list(map())) :: {:ok, non_neg_integer()} | {:error, any()}
  def persist_records(records) do
    IO.puts("Persisting #{Enum.count(records)} records...")

    results =
      Enum.reduce(records, {0, 0, []}, fn record, {created, updated, errors} ->
        case persist_record(record) do
          {:ok, :created} ->
            {created + 1, updated, errors}

          {:ok, :updated} ->
            {created, updated + 1, errors}

          {:error, reason} ->
            {created, updated, [{record, reason} | errors]}
        end
      end)

    {created, updated, errors} = results

    IO.puts("Created: #{created}, Updated: #{updated}, Errors: #{Enum.count(errors)}")

    if Enum.any?(errors) do
      IO.puts("\nFirst 5 errors:")

      errors
      |> Enum.take(5)
      |> Enum.each(fn {record, reason} ->
        IO.puts("  - #{record[:name]}: #{inspect(reason)}")
      end)
    end

    {:ok, created + updated}
  end

  @doc """
  Persist a single record to the uk_lrt table.

  Returns {:ok, :created} or {:ok, :updated} on success.
  """
  @spec persist_record(map()) :: {:ok, :created | :updated} | {:error, any()}
  def persist_record(record) do
    name = get_field(record, :name)

    # Check if record already exists
    case find_by_name(name) do
      nil ->
        create_record(record)

      existing ->
        update_record(existing, record)
    end
  end

  # Find existing record by name
  defp find_by_name(name) when is_binary(name) and name != "" do
    case UkLrt
         |> Ash.Query.filter(name == ^name)
         |> Ash.read() do
      {:ok, [existing | _]} -> existing
      {:ok, []} -> nil
      _ -> nil
    end
  end

  defp find_by_name(_), do: nil

  # Create a new UkLrt record
  defp create_record(record) do
    attrs = build_attrs(record)

    case UkLrt |> Ash.Changeset.for_create(:create, attrs) |> Ash.create() do
      {:ok, _} -> {:ok, :created}
      {:error, reason} -> {:error, reason}
    end
  end

  # Update an existing UkLrt record
  defp update_record(existing, record) do
    attrs = build_attrs(record)

    # Only update fields that are present in the scraped record
    # Don't overwrite existing enriched data
    update_attrs = filter_update_attrs(attrs, existing)

    if map_size(update_attrs) == 0 do
      {:ok, :updated}
    else
      case existing |> Ash.Changeset.for_update(:update, update_attrs) |> Ash.update() do
        {:ok, _} -> {:ok, :updated}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Build attributes map from scraped record
  defp build_attrs(record) do
    %{
      name: get_field(record, :name),
      title_en: get_field(record, :title_en),
      type_code: get_field(record, :type_code),
      year: get_integer_field(record, :year),
      number: get_string_field(record, :number),
      number_int: get_integer_field(record, :number),
      si_code: build_si_code(record),
      leg_gov_uk_url: get_field(record, :leg_gov_uk_url),
      # Mark as newly scraped
      live: "🆕 Newly Published"
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Only update fields that are nil in existing record
  # Preserve any existing enriched data
  defp filter_update_attrs(attrs, existing) do
    attrs
    |> Enum.filter(fn {key, _value} ->
      existing_value = Map.get(existing, key)
      # Update if existing value is nil or empty
      is_nil(existing_value) || existing_value == "" || existing_value == [] || existing_value == %{}
    end)
    |> Map.new()
  end

  # Build si_code JSONB from scraped si_code field
  defp build_si_code(record) do
    si_code = get_field(record, :si_code)

    case si_code do
      nil -> nil
      "" -> nil
      [] -> nil
      codes when is_list(codes) -> %{"codes" => codes}
      code when is_binary(code) -> %{"codes" => [code]}
      _ -> nil
    end
  end

  # Get field value from either atom or string keyed map
  defp get_field(record, key) when is_atom(key) do
    record[key] || record[Atom.to_string(key)]
  end

  # Get field as string
  defp get_string_field(record, key) do
    case get_field(record, key) do
      nil -> nil
      val when is_binary(val) -> val
      val when is_integer(val) -> Integer.to_string(val)
      _ -> nil
    end
  end

  # Get field as integer
  defp get_integer_field(record, key) do
    case get_field(record, key) do
      nil -> nil
      val when is_integer(val) -> val
      val when is_binary(val) -> parse_integer(val)
      _ -> nil
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> nil
    end
  end
end
