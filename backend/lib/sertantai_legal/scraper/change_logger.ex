defmodule SertantaiLegal.Scraper.ChangeLogger do
  @moduledoc """
  Builds and manages unified change logs for UK LRT records.

  The change log captures field-level changes when records are updated during scraping,
  providing an audit trail of how records have evolved over time.

  ## Entry Format

  Each entry is a map with the following structure:
  ```
  %{
    "timestamp" => "2025-01-10T18:30:45Z",   # ISO 8601 UTC timestamp
    "source" => "scraper",                    # Origin of the change
    "changed_by" => "staged_parser",          # Specific module/process
    "summary" => "Updated 3 fields: role, amending, live",
    "changes" => %{
      "role" => %{
        "old" => ["Ind: Employer"],
        "new" => ["Ind: Employer", "Ind: Worker"]
      },
      "amending" => %{
        "old" => nil,
        "new" => ["UK_uksi_2020_847"]
      },
      "live" => %{
        "old" => "🆕 Newly Published",
        "new" => "✔ In force"
      }
    }
  }
  ```

  ## Usage

  ```elixir
  # Build a change entry from old and new record maps
  {:ok, entry} = ChangeLogger.build_change_entry(old_record, new_record, "staged_parser")

  # Append to existing log
  updated_log = ChangeLogger.append_to_log(existing_log, entry)

  # Get a human-readable summary
  summary = ChangeLogger.format_summary(entry)
  ```
  """

  @doc """
  Build a change log entry by comparing old and new record maps.

  Returns {:ok, entry} if there are changes, or {:no_changes, nil} if identical.

  ## Parameters
  - `old_record` - The existing record (map or struct), or nil for new records
  - `new_record` - The new/updated record (map)
  - `changed_by` - Identifier for the source of change (e.g., "staged_parser", "csv_import")
  - `opts` - Optional settings:
    - `:source` - Override the default source ("scraper")
    - `:exclude_fields` - List of fields to ignore in comparison

  ## Examples

      iex> old = %{role: ["Ind: Employer"], live: "🆕 Newly Published"}
      iex> new = %{role: ["Ind: Employer", "Ind: Worker"], live: "✔ In force"}
      iex> {:ok, entry} = ChangeLogger.build_change_entry(old, new, "staged_parser")
      iex> entry["changes"]["role"]["new"]
      ["Ind: Employer", "Ind: Worker"]
  """
  @spec build_change_entry(map() | struct() | nil, map(), String.t(), keyword()) ::
          {:ok, map()} | {:no_changes, nil}
  def build_change_entry(old_record, new_record, changed_by, opts \\ []) do
    source = Keyword.get(opts, :source, "scraper")
    exclude_fields = Keyword.get(opts, :exclude_fields, default_exclude_fields())

    old_map = normalize_to_map(old_record)
    new_map = normalize_to_map(new_record)

    # Only compare keys that are in the NEW record
    # If a key isn't being updated, we don't track it as a change
    # This prevents "field deleted" false positives when the update
    # only includes a subset of fields
    new_keys =
      new_map
      |> Map.keys()
      |> Enum.reject(&(&1 in exclude_fields))
      |> Enum.map(&to_string/1)
      |> Enum.uniq()

    # Find fields that changed
    changes =
      new_keys
      |> Enum.reduce(%{}, fn key, acc ->
        atom_key = safe_to_atom(key)
        old_value = get_normalized_value(old_map, key, atom_key)
        new_value = get_normalized_value(new_map, key, atom_key)

        if values_differ?(old_value, new_value) do
          Map.put(acc, key, %{
            "old" => serialize_value(old_value),
            "new" => serialize_value(new_value)
          })
        else
          acc
        end
      end)

    if map_size(changes) == 0 do
      {:no_changes, nil}
    else
      entry = %{
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "source" => source,
        "changed_by" => changed_by,
        "summary" => build_summary(changes),
        "changes" => changes
      }

      {:ok, entry}
    end
  end

  @doc """
  Append a change entry to an existing log.

  Returns the updated log array. If the entry is nil, returns the existing log unchanged.
  """
  @spec append_to_log(list() | nil, map() | nil) :: list()
  def append_to_log(existing_log, nil), do: existing_log || []
  def append_to_log(nil, entry), do: [entry]
  def append_to_log(existing_log, entry), do: existing_log ++ [entry]

  @doc """
  Format a human-readable summary of changes.

  ## Examples

      iex> entry = %{"changes" => %{"role" => %{}, "live" => %{}}}
      iex> ChangeLogger.format_summary(entry)
      "Updated 2 fields: live, role"
  """
  @spec format_summary(map()) :: String.t()
  def format_summary(%{"changes" => changes}) when map_size(changes) == 0 do
    "No changes"
  end

  def format_summary(%{"changes" => changes}) do
    field_names = changes |> Map.keys() |> Enum.sort() |> Enum.join(", ")
    count = map_size(changes)
    "Updated #{count} #{pluralize(count, "field", "fields")}: #{field_names}"
  end

  def format_summary(_), do: "No changes"

  @doc """
  Get a compact summary of the full change log.

  Returns a summary like "5 updates since 2024-01-15"
  """
  @spec log_summary(list() | nil) :: String.t()
  def log_summary(nil), do: "No change history"
  def log_summary([]), do: "No change history"

  def log_summary(log) when is_list(log) do
    count = length(log)
    first_entry = List.first(log)
    first_date = first_entry["timestamp"] |> String.slice(0, 10)
    "#{count} #{pluralize(count, "update", "updates")} since #{first_date}"
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp default_exclude_fields do
    [
      # Metadata fields that shouldn't be tracked
      :id,
      :__meta__,
      :inserted_at,
      :updated_at,
      :created_at,
      :calculations,
      :aggregates,
      # The change log itself
      :record_change_log,
      # Legacy change logs (migrated separately)
      :amending_change_log,
      :amended_by_change_log,
      # String versions
      "id",
      "__meta__",
      "inserted_at",
      "updated_at",
      "created_at",
      "calculations",
      "aggregates",
      "record_change_log",
      "amending_change_log",
      "amended_by_change_log"
    ]
  end

  defp normalize_to_map(nil), do: %{}

  defp normalize_to_map(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> match?(%Ash.NotLoaded{}, v) end)
    |> Enum.into(%{})
  end

  defp normalize_to_map(map) when is_map(map), do: map

  defp get_normalized_value(map, string_key, atom_key) do
    # Try both string and atom keys
    case Map.get(map, string_key) do
      nil -> Map.get(map, atom_key)
      value -> value
    end
  end

  defp safe_to_atom(key) when is_atom(key), do: key

  defp safe_to_atom(key) when is_binary(key) do
    # Only convert known keys to atoms to avoid atom table exhaustion
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp values_differ?(old, new) do
    # Normalize both values for comparison
    normalize_for_comparison(old) != normalize_for_comparison(new)
  end

  defp normalize_for_comparison(nil), do: nil
  defp normalize_for_comparison(""), do: nil
  defp normalize_for_comparison([]), do: nil
  defp normalize_for_comparison(%{} = map) when map_size(map) == 0, do: nil

  defp normalize_for_comparison(list) when is_list(list) do
    # Sort lists for consistent comparison
    Enum.sort(list)
  end

  defp normalize_for_comparison(value), do: value

  defp serialize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp serialize_value(%Decimal{} = d), do: Decimal.to_string(d)
  defp serialize_value(value), do: value

  defp build_summary(changes) do
    field_names = changes |> Map.keys() |> Enum.sort() |> Enum.join(", ")
    count = map_size(changes)
    "Updated #{count} #{pluralize(count, "field", "fields")}: #{field_names}"
  end

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_, _singular, plural), do: plural
end
