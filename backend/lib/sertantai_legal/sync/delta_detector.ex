defmodule SertantaiLegal.Sync.DeltaDetector do
  @moduledoc """
  Detects new, updated, and deleted rows by comparing source data
  against existing SyncRowMapping records.

  Used by Engine.run to determine which rows to create, update, or
  delete in the target provider — eliminating duplicates.

  ## How it works

  Each source row has a `_source_id` field (set during formatting).
  Each existing mapping has `source_id` + `external_row_id` + `last_synced_at`.

  - **new**: source_id in source rows but not in mappings → batch_create
  - **updated**: source_id in both, source.updated_at > mapping.last_synced_at → batch_update
  - **deleted**: source_id in mappings but not in source rows → handle per policy
  - **unchanged**: source_id in both, not updated → skip
  """

  @type mapping :: %{
          source_id: String.t(),
          external_row_id: integer(),
          last_synced_at: DateTime.t() | nil
        }
  @type result :: %{
          new: [map()],
          updated: [map()],
          deleted: [%{source_id: String.t(), external_row_id: integer()}],
          unchanged: non_neg_integer()
        }

  @doc """
  Detect changes between source rows and existing mappings.

  ## Parameters

  - `source_rows` — formatted rows from ProfileQuery, each with `"_source_id"` field
  - `existing_mappings` — list of SyncRowMapping records (or maps with source_id, external_row_id, last_synced_at)
  - `source_timestamps` — map of `%{source_id => updated_at}` for change detection. Optional — if not provided, all matched rows are treated as updated.

  ## Returns

  `%{new: [row], updated: [row], deleted: [%{source_id, external_row_id}], unchanged: count}`

  Updated rows have `"id"` injected (the Baserow external_row_id) for batch_update.
  """
  @spec detect([map()], [mapping()], map()) :: result()
  def detect(source_rows, existing_mappings, source_timestamps \\ %{}) do
    # Build lookup: source_id → {external_row_id, last_synced_at}
    mapping_lookup =
      Map.new(existing_mappings, fn m ->
        sid = access(m, :source_id)
        ext = access(m, :external_row_id)
        synced = access(m, :last_synced_at)
        {sid, %{external_row_id: ext, last_synced_at: synced}}
      end)

    # Track which source_ids we've seen
    source_ids = MapSet.new(source_rows, & &1["_source_id"])

    # Classify each source row
    {new_rows, updated_rows, unchanged_count} =
      Enum.reduce(source_rows, {[], [], 0}, fn row, {new_acc, upd_acc, unch} ->
        source_id = row["_source_id"]

        case Map.get(mapping_lookup, source_id) do
          nil ->
            # Not in mappings → new
            {[row | new_acc], upd_acc, unch}

          %{external_row_id: ext_id, last_synced_at: last_synced} ->
            # In mappings → check if updated
            source_updated = Map.get(source_timestamps, source_id)

            if needs_update?(source_updated, last_synced) do
              # Inject Baserow row ID for batch_update
              updated_row = Map.put(row, "id", ext_id)
              {new_acc, [updated_row | upd_acc], unch}
            else
              {new_acc, upd_acc, unch + 1}
            end
        end
      end)

    # Detect deleted: in mappings but not in source
    deleted =
      mapping_lookup
      |> Enum.reject(fn {sid, _} -> MapSet.member?(source_ids, sid) end)
      |> Enum.map(fn {sid, %{external_row_id: ext_id}} ->
        %{source_id: sid, external_row_id: ext_id}
      end)

    %{
      new: Enum.reverse(new_rows),
      updated: Enum.reverse(updated_rows),
      deleted: deleted,
      unchanged: unchanged_count
    }
  end

  # If no source timestamp available, always treat as updated (safe default)
  defp needs_update?(nil, _last_synced), do: true
  # If never synced before, always update
  defp needs_update?(_source, nil), do: true
  # Compare timestamps (handle NaiveDateTime from DB vs DateTime from mappings)
  defp needs_update?(%NaiveDateTime{} = source, last_synced) do
    needs_update?(DateTime.from_naive!(source, "Etc/UTC"), last_synced)
  end

  defp needs_update?(source, %NaiveDateTime{} = last_synced) do
    needs_update?(source, DateTime.from_naive!(last_synced, "Etc/UTC"))
  end

  defp needs_update?(source_updated, last_synced) do
    DateTime.compare(source_updated, last_synced) == :gt
  end

  # Access struct or map field
  defp access(m, key) when is_struct(m), do: Map.get(m, key)
  defp access(m, key) when is_map(m), do: m[key] || m[to_string(key)]
end
