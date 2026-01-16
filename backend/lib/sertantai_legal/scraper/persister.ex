defmodule SertantaiLegal.Scraper.Persister do
  @moduledoc """
  Persists categorized laws to the uk_lrt table.

  Reads group JSON files and creates/updates UkLrt records.
  Handles duplicate detection by name (type_code/year/number).

  ## Function Calculation Workflow

  Function calculation follows a staged approach:

  1. **Immediate** (at persist time): Making, Commencing
     - These depend only on the law's own properties

  2. **End-of-batch** (after all persists): Amending/Revoking Maker
     - These depend on is_making of target laws
     - Target laws' is_making may change during cascade rescraping

  3. **Dynamic** (enacted_by → enacting): Enacting/Enacting Maker
     - Parent's enacting[] updated when child declares enacted_by

  ## Change Logging

  Updates are tracked in the `record_change_log` JSONB column.
  - No entry is created on initial record creation
  - Each update appends an entry with timestamp, changed_by, and field diffs
  """

  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.ChangeLogger
  alias SertantaiLegal.Scraper.ParsedLaw
  alias SertantaiLegal.Legal.UkLrt
  alias SertantaiLegal.Legal.FunctionCalculator

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

  Includes Function calculation:
  1. Immediate Function (Making, Commencing) after each record
  2. End-of-batch relationship Function (Amending/Revoking Maker)
  3. Update parent enacting[] from child enacted_by
  """
  @spec persist_records(list(map())) :: {:ok, non_neg_integer()} | {:error, any()}
  def persist_records(records) do
    IO.puts("Persisting #{Enum.count(records)} records...")

    # Phase 1: Persist all records and calculate immediate Function
    {results, laws_needing_relationship_calc, laws_with_enacted_by} =
      Enum.reduce(records, {{0, 0, []}, [], []}, fn record, {counts, rel_laws, enacted_laws} ->
        {created, updated, errors} = counts

        case persist_record_with_immediate_function(record) do
          {:ok, :created, law} ->
            # Track for relationship Function calc if has amending/rescinding
            rel_laws = maybe_track_for_relationship_calc(rel_laws, law)
            enacted_laws = maybe_track_enacted_by(enacted_laws, law, record)
            {{created + 1, updated, errors}, rel_laws, enacted_laws}

          {:ok, :updated, law} ->
            rel_laws = maybe_track_for_relationship_calc(rel_laws, law)
            enacted_laws = maybe_track_enacted_by(enacted_laws, law, record)
            {{created, updated + 1, errors}, rel_laws, enacted_laws}

          {:error, reason} ->
            {{created, updated, [{record, reason} | errors]}, rel_laws, enacted_laws}
        end
      end)

    {created, updated, errors} = results

    IO.puts("Created: #{created}, Updated: #{updated}, Errors: #{Enum.count(errors)}")

    # Phase 2: Update parent enacting[] from child enacted_by
    if Enum.any?(laws_with_enacted_by) do
      IO.puts("Updating enacting[] for #{Enum.count(laws_with_enacted_by)} parent laws...")

      {:ok, enacting_count} =
        FunctionCalculator.update_enacting_from_enacted_by_of_laws(laws_with_enacted_by)

      IO.puts("Updated #{enacting_count} parent laws with enacting[]")
    end

    # Phase 3: Calculate relationship Function for laws with amending/rescinding
    if Enum.any?(laws_needing_relationship_calc) do
      IO.puts(
        "Calculating relationship Function for #{Enum.count(laws_needing_relationship_calc)} laws..."
      )

      calculate_relationship_function_of_persisted_laws(laws_needing_relationship_calc)
    end

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

  # ============================================================================
  # PRIVATE - Persist with Function Calculation
  # ============================================================================

  # Persist record and calculate immediate Function (Making, Commencing)
  defp persist_record_with_immediate_function(record) do
    name = get_field(record, :name)

    case find_by_name(name) do
      nil ->
        case create_record_with_immediate_function(record) do
          {:ok, law} -> {:ok, :created, law}
          error -> error
        end

      existing ->
        case update_record_with_immediate_function(existing, record) do
          {:ok, law} -> {:ok, :updated, law}
          error -> error
        end
    end
  end

  # Create new record with immediate Function
  defp create_record_with_immediate_function(record) do
    attrs = build_attrs(record)

    # Calculate immediate Function (Making, Commencing)
    immediate_function = FunctionCalculator.calculate_immediate_function_of_law(record)

    attrs_with_function =
      if map_size(immediate_function) > 0 do
        Map.put(attrs, :function, immediate_function)
      else
        attrs
      end

    case UkLrt |> Ash.Changeset.for_create(:create, attrs_with_function) |> Ash.create() do
      {:ok, law} -> {:ok, law}
      {:error, reason} -> {:error, reason}
    end
  end

  # Update existing record with immediate Function
  defp update_record_with_immediate_function(existing, record) do
    attrs = build_attrs(record)
    update_attrs = filter_update_attrs(attrs, existing)

    # Merge immediate Function with existing function
    immediate_function = FunctionCalculator.calculate_immediate_function_of_law(record)
    existing_function = existing.function || %{}
    merged_function = Map.merge(existing_function, immediate_function)

    update_attrs_with_function =
      if map_size(merged_function) > 0 do
        Map.put(update_attrs, :function, merged_function)
      else
        update_attrs
      end

    if map_size(update_attrs_with_function) == 0 do
      {:ok, existing}
    else
      # Build change log entry before applying updates
      update_attrs_with_log =
        case ChangeLogger.build_change_entry(existing, update_attrs_with_function, "persister") do
          {:ok, log_entry} ->
            existing_log = existing.record_change_log || []
            updated_log = ChangeLogger.append_to_log(existing_log, log_entry)
            Map.put(update_attrs_with_function, :record_change_log, updated_log)

          {:no_changes, nil} ->
            update_attrs_with_function
        end

      case existing
           |> Ash.Changeset.for_update(:update, update_attrs_with_log)
           |> Ash.update() do
        {:ok, law} -> {:ok, law}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Track law for relationship Function calc if it has amending or rescinding arrays
  defp maybe_track_for_relationship_calc(tracked, law) do
    has_amending = law.amending != nil and law.amending != []
    has_rescinding = law.rescinding != nil and law.rescinding != []

    if has_amending or has_rescinding do
      [law | tracked]
    else
      tracked
    end
  end

  # Track law if it has enacted_by (for updating parent's enacting[])
  defp maybe_track_enacted_by(tracked, law, original_record) do
    # get_field handles both atom and string keys
    enacted_by = get_field(original_record, :enacted_by)

    case enacted_by do
      nil ->
        tracked

      [] ->
        tracked

      _ ->
        # Build a map with what FunctionCalculator.update_enacting_from_enacted_by_of_laws expects
        [%{name: law.name, enacted_by: enacted_by, is_making: law.is_making || false} | tracked]
    end
  end

  # Calculate relationship Function for a batch of laws
  defp calculate_relationship_function_of_persisted_laws(laws) do
    # Calculate relationship Functions (Amending/Revoking Maker)
    results = FunctionCalculator.calculate_relationship_function_of_laws(laws)

    # Persist the relationship Function merged with existing
    Enum.each(results, fn {law, relationship_function} ->
      if map_size(relationship_function) > 0 do
        existing_function = law.function || %{}
        merged_function = Map.merge(existing_function, relationship_function)

        law
        |> Ash.Changeset.for_update(:update, %{function: merged_function})
        |> Ash.update()
      end
    end)
  end

  # ============================================================================
  # PRIVATE - Record Operations
  # ============================================================================

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

  # Create a new UkLrt record (without Function - used by persist_record/1)
  defp create_record(record) do
    attrs = build_attrs(record)

    case UkLrt |> Ash.Changeset.for_create(:create, attrs) |> Ash.create() do
      {:ok, _} -> {:ok, :created}
      {:error, reason} -> {:error, reason}
    end
  end

  # Update an existing UkLrt record (without Function - used by persist_record/1)
  defp update_record(existing, record) do
    attrs = build_attrs(record)
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

  # Build attributes map from scraped record using ParsedLaw for consistent JSONB conversion
  defp build_attrs(record) do
    # Derive is_amending/is_rescinding from arrays
    is_amending = has_array_field?(record, :amending)
    is_rescinding = has_array_field?(record, :rescinding)

    # Build enriched map with derived fields
    enriched =
      record
      |> Map.put(:is_amending, is_amending)
      |> Map.put(:is_rescinding, is_rescinding)
      |> Map.put(:live, "🆕 Newly Published")

    # Use ParsedLaw for consistent field handling and JSONB conversion
    enriched
    |> ParsedLaw.from_map()
    |> ParsedLaw.to_db_attrs()
  end

  # Only update fields that are nil in existing record
  defp filter_update_attrs(attrs, existing) do
    attrs
    |> Enum.filter(fn {key, _value} ->
      existing_value = Map.get(existing, key)

      is_nil(existing_value) || existing_value == "" || existing_value == [] ||
        existing_value == %{}
    end)
    |> Map.new()
  end

  # ============================================================================
  # PRIVATE - Field Access Helpers
  # ============================================================================

  # Get field value from either atom or string keyed map
  defp get_field(record, key) when is_atom(key) do
    record[key] || record[Atom.to_string(key)]
  end

  # Check if array field has values
  defp has_array_field?(record, key) do
    case get_field(record, key) do
      nil -> nil
      [] -> nil
      list when is_list(list) and length(list) > 0 -> true
      _ -> nil
    end
  end
end
