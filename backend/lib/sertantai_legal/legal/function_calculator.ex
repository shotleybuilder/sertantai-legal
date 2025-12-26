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

  ## Timing in Scraper Workflow

  - **Immediate** (Making, Commencing): Calculated at persist time
  - **Deferred** (Amending/Revoking Maker): Calculated end-of-batch after cascade
  - **Dynamic** (Enacting/Enacting Maker): Calculated when child laws are added
  """

  import Ecto.Query
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query

  # ============================================================================
  # PUBLIC API - Full Calculation
  # ============================================================================

  @doc """
  Calculate the complete function field for a law record.

  Requires database lookups to check is_making for target laws.
  Use this for one-off calculations or when all data is stable.

  ## Parameters
  - record: Map or struct with relationship arrays and boolean flags

  ## Returns
  Map with function keys set to true (e.g., %{"Making" => true, "Amending" => true})
  """
  @spec calculate_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_function_of_law(record) do
    # Collect all target law names for batch lookup
    all_targets =
      (get_array_field(record, :enacting) ++
         get_array_field(record, :amending) ++
         get_array_field(record, :rescinding))
      |> Enum.uniq()

    # Batch lookup is_making for all targets
    is_making_map = lookup_is_making_of_laws(all_targets)

    %{}
    |> add_making(record)
    |> add_commencing(record)
    |> add_enacting(record, is_making_map)
    |> add_amending(record, is_making_map)
    |> add_revoking(record, is_making_map)
  end

  @doc """
  Calculate function for multiple law records efficiently.

  Batches all target lookups into a single query.
  """
  @spec calculate_function_of_laws([map()]) :: [{map(), map()}]
  def calculate_function_of_laws(records) do
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
    is_making_map = lookup_is_making_of_laws(all_targets)

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

  # ============================================================================
  # PUBLIC API - Staged Calculation (for Scraper Workflow)
  # ============================================================================

  @doc """
  Calculate immediate function labels for a law (no DB lookup needed).

  These labels depend only on the law's own properties:
  - Making: from is_making field
  - Commencing: from is_commencing field

  Call this immediately after persisting a new law.
  """
  @spec calculate_immediate_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_immediate_function_of_law(record) do
    %{}
    |> add_making(record)
    |> add_commencing(record)
  end

  @doc """
  Calculate relationship-based function labels for a law (requires DB lookup).

  These labels depend on the is_making status of target laws:
  - Amending / Amending Maker: from amending[] array
  - Revoking / Revoking Maker: from rescinding[] array
  - Enacting / Enacting Maker: from enacting[] array

  Call this at end-of-batch after all is_making updates are complete.
  """
  @spec calculate_relationship_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_relationship_function_of_law(record) do
    all_targets =
      (get_array_field(record, :enacting) ++
         get_array_field(record, :amending) ++
         get_array_field(record, :rescinding))
      |> Enum.uniq()

    is_making_map = lookup_is_making_of_laws(all_targets)

    %{}
    |> add_enacting(record, is_making_map)
    |> add_amending(record, is_making_map)
    |> add_revoking(record, is_making_map)
  end

  @doc """
  Calculate relationship-based function labels for multiple laws efficiently.

  Batches all is_making lookups into a single query.
  """
  @spec calculate_relationship_function_of_laws([map()]) :: [{map(), map()}]
  def calculate_relationship_function_of_laws(records) do
    all_targets =
      records
      |> Enum.flat_map(fn record ->
        get_array_field(record, :enacting) ++
          get_array_field(record, :amending) ++
          get_array_field(record, :rescinding)
      end)
      |> Enum.uniq()

    is_making_map = lookup_is_making_of_laws(all_targets)

    Enum.map(records, fn record ->
      function =
        %{}
        |> add_enacting(record, is_making_map)
        |> add_amending(record, is_making_map)
        |> add_revoking(record, is_making_map)

      {record, function}
    end)
  end

  # ============================================================================
  # PUBLIC API - Persistence
  # ============================================================================

  @doc """
  Calculate and persist the function field for a law by ID.

  Fetches the record, calculates function, and updates the database.
  """
  @spec calculate_and_persist_function_of_law(Ecto.UUID.t()) ::
          {:ok, UkLrt.t()} | {:error, any()}
  def calculate_and_persist_function_of_law(law_id) do
    case get_law_by_id(law_id) do
      {:ok, law} ->
        function = calculate_function_of_law(law)
        persist_function_of_law(law, function)

      error ->
        error
    end
  end

  @doc """
  Persist a calculated function to a law record.
  """
  @spec persist_function_of_law(UkLrt.t(), map()) :: {:ok, UkLrt.t()} | {:error, any()}
  def persist_function_of_law(law, function) do
    function_to_persist = if map_size(function) == 0, do: nil, else: function

    law
    |> Ash.Changeset.for_update(:update, %{function: function_to_persist})
    |> Ash.update()
  end

  @doc """
  Calculate and persist function for multiple laws by their IDs.

  Efficiently batches the is_making lookups.
  """
  @spec calculate_and_persist_function_of_laws([Ecto.UUID.t()]) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def calculate_and_persist_function_of_laws(law_ids) when is_list(law_ids) do
    case get_laws_by_ids(law_ids) do
      {:ok, laws} ->
        results = calculate_function_of_laws(laws)

        updated_count =
          Enum.reduce(results, 0, fn {law, function}, count ->
            case persist_function_of_law(law, function) do
              {:ok, _} -> count + 1
              {:error, _} -> count
            end
          end)

        {:ok, updated_count}

      error ->
        error
    end
  end

  # ============================================================================
  # PUBLIC API - Enacting Updates (Dynamic)
  # ============================================================================

  @doc """
  Add a child law to a parent's enacting[] array and recalculate Function.

  Called when a new law is persisted that has enacted_by pointing to parent.

  ## Parameters
  - parent_name: Name of the parent law (e.g., "UK_ukpga_1974_37")
  - child_name: Name of the child law to add (e.g., "UK_uksi_2024_123")
  - child_is_making: Whether the child law has is_making = true

  ## Returns
  {:ok, updated_parent} or {:error, reason}
  """
  @spec add_child_to_enacting_of_parent_law(String.t(), String.t(), boolean()) ::
          {:ok, UkLrt.t()} | {:error, any()}
  def add_child_to_enacting_of_parent_law(parent_name, child_name, child_is_making) do
    case get_law_by_name(parent_name) do
      {:ok, parent} ->
        current_enacting = parent.enacting || []

        # Only update if child not already in enacting[]
        if child_name in current_enacting do
          {:ok, parent}
        else
          new_enacting = [child_name | current_enacting]

          # Recalculate Enacting/Enacting Maker based on new child
          current_function = parent.function || %{}

          new_function =
            current_function
            |> maybe_put("Enacting", not child_is_making)
            |> maybe_put("Enacting Maker", child_is_making)

          parent
          |> Ash.Changeset.for_update(:update, %{
            enacting: new_enacting,
            is_enacting: true,
            function: new_function
          })
          |> Ash.update()
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Update enacting[] for multiple parent laws from a batch of child laws.

  Efficiently processes enacted_by relationships from newly persisted laws.

  ## Parameters
  - child_laws: List of maps with :name, :enacted_by, :is_making fields

  ## Returns
  {:ok, updated_count}
  """
  @spec update_enacting_from_enacted_by_of_laws([map()]) :: {:ok, non_neg_integer()}
  def update_enacting_from_enacted_by_of_laws(child_laws) do
    # Group children by parent
    parent_children =
      child_laws
      |> Enum.flat_map(fn child ->
        child_name = get_field(child, :name)
        child_is_making = get_boolean_flag(child, :is_making)

        get_array_field(child, :enacted_by)
        |> Enum.map(fn parent_name ->
          {normalize_name(parent_name), {child_name, child_is_making}}
        end)
      end)
      |> Enum.group_by(fn {parent, _} -> parent end, fn {_, child_info} -> child_info end)

    # Update each parent
    updated_count =
      Enum.reduce(parent_children, 0, fn {parent_name, children}, count ->
        case update_enacting_of_parent_with_children(parent_name, children) do
          {:ok, _} -> count + 1
          {:error, _} -> count
        end
      end)

    {:ok, updated_count}
  end

  # ============================================================================
  # PRIVATE - Database Access
  # ============================================================================

  defp get_law_by_id(id) do
    UkLrt
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  defp get_law_by_name(name) do
    normalized = normalize_name(name)

    UkLrt
    |> Ash.Query.filter(name == ^normalized)
    |> Ash.read_one()
  end

  defp get_laws_by_ids(ids) do
    UkLrt
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read()
  end

  defp update_enacting_of_parent_with_children(parent_name, children) do
    case get_law_by_name(parent_name) do
      {:ok, parent} when not is_nil(parent) ->
        current_enacting = parent.enacting || []

        # Add new children
        new_children =
          children
          |> Enum.map(fn {child_name, _} -> child_name end)
          |> Enum.reject(fn name -> name in current_enacting end)

        if new_children == [] do
          {:ok, parent}
        else
          new_enacting = new_children ++ current_enacting

          # Determine Enacting/Enacting Maker from children
          has_maker = Enum.any?(children, fn {_, is_making} -> is_making end)
          has_non_maker = Enum.any?(children, fn {_, is_making} -> not is_making end)

          current_function = parent.function || %{}

          new_function =
            current_function
            |> maybe_put("Enacting", has_non_maker or Map.get(current_function, "Enacting", false))
            |> maybe_put(
              "Enacting Maker",
              has_maker or Map.get(current_function, "Enacting Maker", false)
            )

          parent
          |> Ash.Changeset.for_update(:update, %{
            enacting: new_enacting,
            is_enacting: true,
            function: new_function
          })
          |> Ash.update()
        end

      {:ok, nil} ->
        {:error, :parent_not_found}

      error ->
        error
    end
  end

  # Batch lookup is_making for a list of law names
  # Returns map: %{"UK_uksi_2020_1" => true, "uksi/2020/1" => true, ...}
  defp lookup_is_making_of_laws([]), do: %{}

  defp lookup_is_making_of_laws(names) do
    # Normalize all names to database format
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

  # ============================================================================
  # PRIVATE - Name Normalization
  # ============================================================================

  # Normalize names to database format and build mapping
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
      String.starts_with?(name, "UK_") -> name
      String.contains?(name, "/") -> "UK_" <> String.replace(name, "/", "_")
      true -> name
    end
  end

  defp normalize_name(name), do: name

  # ============================================================================
  # PRIVATE - Function Label Helpers
  # ============================================================================

  defp is_making_true?(true), do: true
  defp is_making_true?(_), do: false

  defp add_making(function, record) do
    if get_boolean_flag(record, :is_making) do
      Map.put(function, "Making", true)
    else
      function
    end
  end

  defp add_commencing(function, record) do
    if get_boolean_flag(record, :is_commencing) do
      Map.put(function, "Commencing", true)
    else
      function
    end
  end

  defp add_enacting(function, record, is_making_map) do
    add_relationship_functions(function, record, :enacting, "Enacting", is_making_map)
  end

  defp add_amending(function, record, is_making_map) do
    add_relationship_functions(function, record, :amending, "Amending", is_making_map)
  end

  defp add_revoking(function, record, is_making_map) do
    add_relationship_functions(function, record, :rescinding, "Revoking", is_making_map)
  end

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

  defp classify_targets(targets, is_making_map) do
    Enum.reduce(targets, {0, 0}, fn target, {makers, non_makers} ->
      if Map.get(is_making_map, target, false) do
        {makers + 1, non_makers}
      else
        {makers, non_makers + 1}
      end
    end)
  end

  # ============================================================================
  # PRIVATE - Field Access Helpers
  # ============================================================================

  defp get_boolean_flag(record, field) do
    get_field(record, field) == true
  end

  defp get_array_field(record, field) do
    case get_field(record, field) do
      nil -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp get_field(record, field) when is_atom(field) do
    # Handle both struct and map access
    cond do
      is_struct(record) -> Map.get(record, field)
      is_map(record) -> record[field] || record[Atom.to_string(field)]
      true -> nil
    end
  end

  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, true), do: Map.put(map, key, true)
end
