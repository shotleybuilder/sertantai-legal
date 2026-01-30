defmodule SertantaiLegal.Legal.Taxa.DutyType do
  @moduledoc """
  Classifies legal text by duty type (role-based classification).

  Duty types identify WHO has obligations based on role holders found in legal text:

  ## Duty Type Categories (sorted by priority)

  1. **Duty** - Obligations on governed entities (employers, companies, etc.)
  2. **Right** - Rights granted to governed entities
  3. **Responsibility** - Obligations on government entities
  4. **Power** - Discretionary powers granted to government

  Note: For function-based classification (WHAT the law does), see `PurposeClassifier`.

  ## Usage

      # Process a single record
      iex> DutyType.process_record(%{text: "The employer shall ensure...", role: ["Org: Employer"]})
      %{text: "...", role: [...], duty_type: ["Duty"], duty_holder: ["Org: Employer"], ...}

      # Process multiple records
      iex> DutyType.process_records(records)
      [%{...}, ...]

      # Sort duty types
      iex> DutyType.duty_type_sorter(["Power", "Duty", "Right"])
      ["Duty", "Right", "Power"]
  """

  alias SertantaiLegal.Legal.Taxa.{DutyTypeLib, TaxaFormatter}

  @type duty_types :: list(String.t())
  @type text :: String.t()
  @type record :: map()

  @duty_type_values ["Duty", "Right", "Responsibility", "Power"]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Returns all valid duty type values.
  """
  @spec all_duty_types() :: duty_types()
  def all_duty_types, do: @duty_type_values

  @doc """
  Processes a single law record, extracting role holders and classifying duty types.

  Expects a map with:
  - `:text` or `"text"` - The legal text to analyze
  - `:role` or `"role"` - List of governed actors found (optional)
  - `:role_gvt` or `"role_gvt"` - List of government actors found (optional)

  Returns the map with additional fields:
  - `:duty_type` - List of duty type classifications (Duty, Right, Responsibility, Power)
  - `:duty_holder` - Actors with duties
  - `:rights_holder` - Actors with rights
  - `:responsibility_holder` - Government actors with responsibilities
  - `:power_holder` - Government actors with powers
  - `:duty_holder_article_clause` - Formatted match details
  - `:rights_holder_article_clause` - Formatted match details
  - `:responsibility_holder_article_clause` - Formatted match details
  - `:power_holder_article_clause` - Formatted match details
  """
  @spec process_record(record()) :: record()
  def process_record(%{text: text} = record) when is_binary(text) and text != "" do
    do_process_record(record, text, :atom)
  end

  def process_record(%{"text" => text} = record) when is_binary(text) and text != "" do
    do_process_record(record, text, :string)
  end

  def process_record(record), do: record

  @doc """
  Processes a list of law records.
  """
  @spec process_records(list(record())) :: list(record())
  def process_records(records) when is_list(records) do
    Enum.map(records, &process_record/1)
  end

  @doc """
  Sorts duty types by priority order: Duty → Right → Responsibility → Power
  """
  @spec duty_type_sorter(duty_types()) :: duty_types()
  def duty_type_sorter(duty_types) do
    priority = %{
      "Duty" => 1,
      "Right" => 2,
      "Responsibility" => 3,
      "Power" => 4
    }

    duty_types
    |> Enum.filter(&Map.has_key?(priority, &1))
    |> Enum.sort_by(&Map.get(priority, &1))
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_process_record(record, text, key_type) do
    # Get actors from record
    {governed_actors, government_actors} = get_actors(record, key_type)

    # Find role holders for each duty type
    # Phase 2b: matches are now structured lists instead of formatted strings
    {dutyholders, duties, duty_matches, regexes} =
      DutyTypeLib.find_role_holders(:duty, governed_actors, text, [])

    {rightsholders, rights, right_matches, regexes} =
      DutyTypeLib.find_role_holders(:right, governed_actors, text, regexes)

    {resp_holders, resp, resp_matches, regexes} =
      DutyTypeLib.find_role_holders(:responsibility, government_actors, text, regexes)

    {power_holders, power, power_matches, _regexes} =
      DutyTypeLib.find_role_holders(:power, government_actors, text, regexes)

    # Combine duty types (only role-based: Duty, Right, Responsibility, Power)
    duty_types =
      (duties ++ rights ++ resp ++ power)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()
      |> duty_type_sorter()

    # Update record with holder lists and duty types
    record
    |> put_field(:duty_holder, dutyholders, key_type)
    |> put_field(:rights_holder, rightsholders, key_type)
    |> put_field(:responsibility_holder, resp_holders, key_type)
    |> put_field(:power_holder, power_holders, key_type)
    |> put_field(:duty_type, duty_types, key_type)
    # Phase 2b: Store structured matches for legacy text generation
    |> put_field(:duty_holder_article_clause, matches_to_legacy_text(duty_matches), key_type)
    |> put_field(:rights_holder_article_clause, matches_to_legacy_text(right_matches), key_type)
    |> put_field(
      :responsibility_holder_article_clause,
      matches_to_legacy_text(resp_matches),
      key_type
    )
    |> put_field(:power_holder_article_clause, matches_to_legacy_text(power_matches), key_type)
    # Phase 2b: Store new JSONB format
    |> put_field(:duties, TaxaFormatter.duties_from_matches(duty_matches), key_type)
    |> put_field(:rights, TaxaFormatter.rights_from_matches(right_matches), key_type)
    |> put_field(
      :responsibilities,
      TaxaFormatter.responsibilities_from_matches(resp_matches),
      key_type
    )
    |> put_field(:powers, TaxaFormatter.powers_from_matches(power_matches), key_type)
  end

  # Phase 2b: Convert structured matches back to legacy text format for backwards compatibility
  defp matches_to_legacy_text([]), do: ""
  defp matches_to_legacy_text(nil), do: ""

  defp matches_to_legacy_text(matches) when is_list(matches) do
    matches
    |> Enum.map(&format_match_entry/1)
    |> Enum.uniq()
    |> Enum.map(&String.trim/1)
    |> Enum.join("\n")
  end

  # Format a single match entry to legacy text format
  @spec format_match_entry(map()) :: String.t()
  defp format_match_entry(%{holder: holder, duty_type: duty_type, clause: clause}) do
    ~s/#{duty_type}\n👤#{holder}\n📌#{clause}\n/
  end

  # Gets actors from record based on key type
  defp get_actors(record, :atom) do
    governed = get_list_field(record, :role)
    government = get_list_field(record, :role_gvt)
    {governed, government}
  end

  defp get_actors(record, :string) do
    governed = get_list_field(record, "role")
    government = get_list_field(record, "role_gvt")
    {governed, government}
  end

  # Gets a list field, handling nil and various formats
  defp get_list_field(record, key) do
    case Map.get(record, key) do
      nil -> []
      [] -> []
      list when is_list(list) -> list
      %{"items" => items} when is_list(items) -> items
      _ -> []
    end
  end

  # Puts a field in the record with appropriate key type
  defp put_field(record, key, value, :atom), do: Map.put(record, key, value)
  defp put_field(record, key, value, :string), do: Map.put(record, Atom.to_string(key), value)
end
