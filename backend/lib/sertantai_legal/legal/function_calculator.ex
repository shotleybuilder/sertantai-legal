defmodule SertantaiLegal.Legal.FunctionCalculator do
  @moduledoc """
  Calculates the `function` field for UK LRT records.

  The function field is a JSONB map indicating a law's **structural role**
  in the legislative graph:

  - Commencing: Brings other laws into force (from is_commencing flag)
  - Enacting: Enables other laws (has children via enacted_by)
  - Amending: Modifies other laws (has amending[] targets)
  - Revoking: Revokes other laws (has rescinding[] targets)

  Obligation-content labels (Making, Empowering, Housekeeping) are NOT stored
  in function — they are derivable from `is_making` and `duty_type` columns.

  ## Timing in Scraper Workflow

  - **Immediate** (Commencing): Calculated at persist time
  - **Deferred** (Amending, Revoking): Calculated end-of-batch
  - **Dynamic** (Enacting): Calculated when child laws are added
  """

  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  # ============================================================================
  # PUBLIC API - Full Calculation
  # ============================================================================

  @doc """
  Calculate the complete function field for a law record.

  ## Parameters
  - record: Map or struct with relationship arrays and boolean flags

  ## Returns
  Map with function keys set to true (e.g., %{"Amending" => true, "Commencing" => true})
  """
  @spec calculate_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_function_of_law(record) do
    %{}
    |> add_commencing(record)
    |> add_enacting(record)
    |> add_amending(record)
    |> add_revoking(record)
  end

  @doc """
  Calculate function for multiple law records.
  """
  @spec calculate_function_of_laws([map()]) :: [{map(), map()}]
  def calculate_function_of_laws(records) do
    Enum.map(records, fn record ->
      {record, calculate_function_of_law(record)}
    end)
  end

  # ============================================================================
  # PUBLIC API - Staged Calculation (for Scraper Workflow)
  # ============================================================================

  @doc """
  Calculate immediate function labels for a law (no DB lookup needed).

  These labels depend only on the law's own properties:
  - Commencing: from is_commencing field

  Call this immediately after persisting a new law.
  """
  @spec calculate_immediate_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_immediate_function_of_law(record) do
    %{}
    |> add_commencing(record)
  end

  @doc """
  Calculate relationship-based function labels for a law.

  These labels depend on whether the law has relationship arrays:
  - Amending: from amending[] array
  - Revoking: from rescinding[] array
  - Enacting: from enacting[] array

  Call this at end-of-batch after all persists are complete.
  """
  @spec calculate_relationship_function_of_law(map()) :: %{optional(String.t()) => true}
  def calculate_relationship_function_of_law(record) do
    %{}
    |> add_enacting(record)
    |> add_amending(record)
    |> add_revoking(record)
  end

  @doc """
  Calculate relationship-based function labels for multiple laws.
  """
  @spec calculate_relationship_function_of_laws([map()]) :: [{map(), map()}]
  def calculate_relationship_function_of_laws(records) do
    Enum.map(records, fn record ->
      function =
        %{}
        |> add_enacting(record)
        |> add_amending(record)
        |> add_revoking(record)

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
          {:ok, LegalRegister.t()} | {:error, any()}
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
  @spec persist_function_of_law(LegalRegister.t(), map()) ::
          {:ok, LegalRegister.t()} | {:error, any()}
  def persist_function_of_law(law, function) do
    function_to_persist = if map_size(function) == 0, do: nil, else: function

    law
    |> Ash.Changeset.for_update(:update, %{function: function_to_persist})
    |> Ash.update()
  end

  @doc """
  Calculate and persist function for multiple laws by their IDs.
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
  - child_is_making: Whether the child law has is_making = true (unused, kept for API compat)

  ## Returns
  {:ok, updated_parent} or {:error, reason}
  """
  @spec add_child_to_enacting_of_parent_law(String.t(), String.t(), boolean()) ::
          {:ok, LegalRegister.t()} | {:error, any()}
  def add_child_to_enacting_of_parent_law(parent_name, child_name, _child_is_making) do
    case get_law_by_name(parent_name) do
      {:ok, parent} ->
        current_enacting = parent.enacting || []

        # Only update if child not already in enacting[]
        if child_name in current_enacting do
          {:ok, parent}
        else
          new_enacting = [child_name | current_enacting]
          current_function = parent.function || %{}
          new_function = Map.put(current_function, "Enacting", true)

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

        get_array_field(child, :enacted_by)
        |> Enum.map(fn parent_name ->
          {normalize_name(parent_name), child_name}
        end)
      end)
      |> Enum.group_by(fn {parent, _} -> parent end, fn {_, child_name} -> child_name end)

    # Update each parent
    updated_count =
      Enum.reduce(parent_children, 0, fn {parent_name, child_names}, count ->
        case update_enacting_of_parent_with_children(parent_name, child_names) do
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
    LegalRegister
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one()
  end

  defp get_law_by_name(name) do
    normalized = normalize_name(name)

    LegalRegister
    |> Ash.Query.filter(name == ^normalized)
    |> Ash.read_one()
  end

  defp get_laws_by_ids(ids) do
    LegalRegister
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read()
  end

  defp update_enacting_of_parent_with_children(parent_name, child_names) do
    case get_law_by_name(parent_name) do
      {:ok, parent} when not is_nil(parent) ->
        current_enacting = parent.enacting || []

        new_children = Enum.reject(child_names, fn name -> name in current_enacting end)

        if new_children == [] do
          {:ok, parent}
        else
          new_enacting = new_children ++ current_enacting
          current_function = parent.function || %{}
          new_function = Map.put(current_function, "Enacting", true)

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

  # ============================================================================
  # PRIVATE - Name Normalization
  # ============================================================================

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

  defp add_commencing(function, record) do
    if get_boolean_flag(record, :is_commencing) do
      Map.put(function, "Commencing", true)
    else
      function
    end
  end

  defp add_enacting(function, record) do
    if has_array?(record, :enacting) do
      Map.put(function, "Enacting", true)
    else
      function
    end
  end

  defp add_amending(function, record) do
    if has_array?(record, :amending) do
      Map.put(function, "Amending", true)
    else
      function
    end
  end

  defp add_revoking(function, record) do
    if has_array?(record, :rescinding) do
      Map.put(function, "Revoking", true)
    else
      function
    end
  end

  # ============================================================================
  # PRIVATE - Field Access Helpers
  # ============================================================================

  defp get_boolean_flag(record, field) do
    get_field(record, field) == true
  end

  defp has_array?(record, field) do
    case get_field(record, field) do
      nil -> false
      [] -> false
      list when is_list(list) -> true
      _ -> false
    end
  end

  defp get_array_field(record, field) do
    case get_field(record, field) do
      nil -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp get_field(record, field) when is_atom(field) do
    cond do
      is_struct(record) -> Map.get(record, field)
      is_map(record) -> record[field] || record[Atom.to_string(field)]
      true -> nil
    end
  end
end
