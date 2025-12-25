defmodule SertantaiLegal.Legal.FunctionCalculator do
  @moduledoc """
  Calculates the `function` field for UK LRT records.

  The function field is a JSONB map indicating law functions:
  - Making: Creates substantive duties/responsibilities (from is_making flag)
  - Commencing: Brings other laws into force (from is_commencing flag)
  - Enacting: Enables other laws that are NOT makers
  - Enacting Maker: Enables other laws that ARE makers (is_making = true)
  - Amending: Modifies other laws that are NOT makers
  - Amending Maker: Modifies other laws that ARE makers
  - Revoking: Revokes other laws that are NOT makers
  - Revoking Maker: Revokes other laws that ARE makers

  "Maker" suffix indicates the TARGET laws have is_making = true.
  """

  import Ecto.Query
  alias SertantaiLegal.Repo

  @doc """
  Calculate the function field for a record.

  Requires database lookups to check is_making for target laws.

  ## Parameters
  - record: Map with :name, :amending, :enacting, :rescinding arrays,
            :is_making, :is_commencing flags

  ## Returns
  Map with function keys set to true (e.g., %{"Making" => true, "Amending" => true})
  """
  @spec calculate(map()) :: map()
  def calculate(record) do
    # Collect all target law names for batch lookup
    all_targets =
      (get_array_field(record, :enacting) ++
         get_array_field(record, :amending) ++
         get_array_field(record, :rescinding))
      |> Enum.uniq()

    # Batch lookup is_making for all targets
    is_making_map = lookup_is_making(all_targets)

    %{}
    |> add_making(record)
    |> add_commencing(record)
    |> add_enacting(record, is_making_map)
    |> add_amending(record, is_making_map)
    |> add_revoking(record, is_making_map)
  end

  @doc """
  Calculate function for multiple records efficiently.

  Batches all target lookups into a single query.
  """
  @spec calculate_batch([map()]) :: [{map(), map()}]
  def calculate_batch(records) do
    # Collect all target law names across all records
    all_targets =
      records
      |> Enum.flat_map(fn record ->
        get_array_field(record, :enacting) ++
          get_array_field(record, :amending) ++
          get_array_field(record, :rescinding)
      end)
      |> Enum.uniq()

    # Single batch lookup
    is_making_map = lookup_is_making(all_targets)

    # Calculate function for each record
    Enum.map(records, fn record ->
      function =
        %{}
        |> add_making(record)
        |> add_commencing(record)
        |> add_enacting(record, is_making_map)
        |> add_amending(record, is_making_map)
        |> add_revoking(record, is_making_map)

      {record, function}
    end)
  end

  @doc """
  Calculate and return the function field, or nil if empty.
  """
  @spec calculate_or_nil(map()) :: map() | nil
  def calculate_or_nil(record) do
    case calculate(record) do
      result when map_size(result) == 0 -> nil
      result -> result
    end
  end

  # Batch lookup is_making for a list of law names
  # Returns map: %{"UK_uksi_2020_1" => true, "uksi/2020/1" => true, ...}
  # Handles both name formats: UK_uksi_2020_1 and uksi/2020/1
  defp lookup_is_making([]), do: %{}

  defp lookup_is_making(names) do
    # Normalize all names to database format (UK_type_year_number)
    # Also keep original names for lookup map
    {normalized_names, name_mapping} = normalize_names(names)

    query =
      from(u in "uk_lrt",
        where: u.name in ^normalized_names,
        select: {u.name, u.is_making}
      )

    db_results =
      Repo.all(query)
      |> Enum.into(%{}, fn {name, is_making} ->
        {name, is_making_true?(is_making)}
      end)

    # Build result map with original names
    Enum.into(names, %{}, fn original_name ->
      normalized = Map.get(name_mapping, original_name, original_name)
      is_making = Map.get(db_results, normalized, false)
      {original_name, is_making}
    end)
  end

  # Normalize names to database format and build mapping
  # Input: ["uksi/2020/1", "UK_ukpga_2020_5"]
  # Output: {["UK_uksi_2020_1", "UK_ukpga_2020_5"], %{"uksi/2020/1" => "UK_uksi_2020_1", ...}}
  defp normalize_names(names) do
    Enum.reduce(names, {[], %{}}, fn name, {normalized_list, mapping} ->
      normalized = normalize_name(name)
      {[normalized | normalized_list], Map.put(mapping, name, normalized)}
    end)
    |> then(fn {list, mapping} -> {Enum.uniq(list), mapping} end)
  end

  # Normalize a single name to database format
  # "uksi/2020/1" -> "UK_uksi_2020_1"
  # "UK_uksi_2020_1" -> "UK_uksi_2020_1" (already normalized)
  defp normalize_name(name) when is_binary(name) do
    cond do
      # Already in UK_ format
      String.starts_with?(name, "UK_") ->
        name

      # Slash format: uksi/2020/1 -> UK_uksi_2020_1
      String.contains?(name, "/") ->
        "UK_" <> String.replace(name, "/", "_")

      # Unknown format, return as-is
      true ->
        name
    end
  end

  defp normalize_name(name), do: name

  # Check if is_making value is truthy (boolean field)
  defp is_making_true?(true), do: true
  defp is_making_true?(_), do: false

  # Making: from is_making flag
  defp add_making(function, record) do
    if get_boolean_flag(record, :is_making) do
      Map.put(function, "Making", true)
    else
      function
    end
  end

  # Commencing: from is_commencing flag
  defp add_commencing(function, record) do
    if get_boolean_flag(record, :is_commencing) do
      Map.put(function, "Commencing", true)
    else
      function
    end
  end

  # Enacting: from enacting array, classify by target's is_making
  defp add_enacting(function, record, is_making_map) do
    add_relationship_functions(function, record, :enacting, "Enacting", is_making_map)
  end

  # Amending: from amending array, classify by target's is_making
  defp add_amending(function, record, is_making_map) do
    add_relationship_functions(function, record, :amending, "Amending", is_making_map)
  end

  # Revoking: from rescinding array, classify by target's is_making
  defp add_revoking(function, record, is_making_map) do
    add_relationship_functions(function, record, :rescinding, "Revoking", is_making_map)
  end

  # Generic handler for relationship arrays
  defp add_relationship_functions(function, record, field, base_name, is_making_map) do
    targets = get_array_field(record, field)

    if targets == [] do
      function
    else
      {maker_count, non_maker_count} = classify_targets(targets, is_making_map)

      function
      |> maybe_put(base_name, non_maker_count > 0)
      |> maybe_put("#{base_name} Maker", maker_count > 0)
    end
  end

  # Classify targets into maker and non-maker counts
  defp classify_targets(targets, is_making_map) do
    Enum.reduce(targets, {0, 0}, fn target, {makers, non_makers} ->
      if Map.get(is_making_map, target, false) do
        {makers + 1, non_makers}
      else
        {makers, non_makers + 1}
      end
    end)
  end

  # Helper to get boolean flag
  defp get_boolean_flag(record, field) do
    Map.get(record, field) == true
  end

  # Helper to get array field
  defp get_array_field(record, field) do
    case Map.get(record, field) do
      nil -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  # Helper to conditionally put a key
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, true), do: Map.put(map, key, true)
end
