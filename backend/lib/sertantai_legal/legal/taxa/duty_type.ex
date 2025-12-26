defmodule SertantaiLegal.Legal.Taxa.DutyType do
  @moduledoc """
  Classifies legal text by duty type.

  Duty types categorize what kind of legal provision a text represents:

  ## Duty Type Categories

  Sorted by priority:

  1. **Duty** - Obligations on governed entities (employers, companies, etc.)
  2. **Right** - Rights granted to governed entities
  3. **Responsibility** - Obligations on government entities
  4. **Power** - Discretionary powers granted to government
  5. **Enactment, Citation, Commencement** - When law takes effect
  6. **Purpose** - Why the law exists
  7. **Interpretation, Definition** - Term definitions
  8. **Application, Scope** - What the law applies to
  9. **Extent** - Geographic coverage
  10. **Exemption** - Excluded situations
  11. **Process, Rule, Constraint, Condition** - Procedural requirements
  12. **Power Conferred** - General powers granted
  13. **Charge, Fee** - Financial obligations
  14. **Offence** - Criminal provisions
  15. **Enforcement, Prosecution** - Legal proceedings
  16. **Defence, Appeal** - Defences and appeals
  17. **Liability** - Liability provisions
  18. **Repeal, Revocation** - Superseded provisions
  19. **Amendment** - Changes to other laws
  20. **Transitional Arrangement** - Temporary provisions

  ## Usage

      # Process a single record
      iex> DutyType.process_record(%{text: "The employer shall ensure...", role: ["Org: Employer"]})
      %{text: "...", role: [...], duty_type: ["Duty"], ...}

      # Process multiple records
      iex> DutyType.process_records(records)
      [%{...}, ...]

      # Get duty types for text (without role holder analysis)
      iex> DutyType.get_duty_types("This Act may be cited as...")
      ["Enactment, Citation, Commencement"]
  """

  alias SertantaiLegal.Legal.Taxa.{DutyTypeDefn, DutyTypeLib}

  @type duty_types :: list(String.t())
  @type text :: String.t()
  @type record :: map()

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Gets duty types from text without role holder analysis.

  This performs generic pattern matching only (amendments, definitions, etc.).
  For full analysis including role holders, use `process_record/1`.
  """
  @spec get_duty_types(text()) :: duty_types()
  def get_duty_types(text) when is_binary(text) and text != "" do
    # First check for amendments - if found, don't process further
    amendment =
      DutyTypeLib.process({text, []}, DutyTypeDefn.amendment())
      |> elem(1)
      |> Enum.uniq()

    case amendment do
      ["Amendment"] -> ["Amendment"]
      [] -> DutyTypeLib.duty_types_generic(text) |> process_defaults()
    end
  end

  def get_duty_types(_), do: []

  @doc """
  Processes a single law record, classifying duty types and extracting role holders.

  Expects a map with:
  - `:text` or `"text"` - The legal text to analyze
  - `:role` or `"role"` - List of governed actors found (optional)
  - `:role_gvt` or `"role_gvt"` - List of government actors found (optional)

  Returns the map with additional fields:
  - `:duty_type` - List of duty type classifications
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
  Sorts duty types by priority order.

  Priority ensures the most important classifications appear first.
  """
  @spec duty_type_sorter(duty_types()) :: duty_types()
  def duty_type_sorter(duty_types) do
    proxy = %{
      "Duty" => "01Duty",
      "Right" => "02Right",
      "Responsibility" => "03Responsibility",
      "Power" => "04Power",
      "Enactment, Citation, Commencement" => "05Enactment, Citation, Commencement",
      "Purpose" => "06Purpose",
      "Interpretation, Definition" => "07Interpretation, Definition",
      "Application, Scope" => "08Application, Scope",
      "Extent" => "09Extent",
      "Exemption" => "10Exemption",
      "Process, Rule, Constraint, Condition" => "11Process, Rule, Constraint, Condition",
      "Power Conferred" => "12Power Conferred",
      "Charge, Fee" => "13Charge, Fee",
      "Offence" => "14Offence",
      "Enforcement, Prosecution" => "15Enforcement, Prosecution",
      "Defence, Appeal" => "16Defence, Appeal",
      "Liability" => "17Liability",
      "Repeal, Revocation" => "18Repeal, Revocation",
      "Amendment" => "19Amendment",
      "Transitional Arrangement" => "20Transitional Arrangement"
    }

    reverse_proxy = Map.new(proxy, fn {k, v} -> {v, k} end)

    duty_types
    |> Enum.map(&Map.get(proxy, &1))
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort()
    |> Enum.map(&Map.get(reverse_proxy, &1))
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_process_record(record, text, key_type) do
    # First check for amendments
    amendment =
      DutyTypeLib.process({text, []}, DutyTypeDefn.amendment())
      |> elem(1)
      |> Enum.uniq()

    case amendment do
      ["Amendment"] ->
        put_field(record, :duty_type, ["Amendment"], key_type)

      [] ->
        # Get actors from record
        {governed_actors, government_actors} = get_actors(record, key_type)

        # Find role holders
        {dutyholders, duties, duty_matches, regexes} =
          DutyTypeLib.find_role_holders(:duty, governed_actors, text, [])

        {rightsholders, rights, right_matches, regexes} =
          DutyTypeLib.find_role_holders(:right, governed_actors, text, regexes)

        {resp_holders, resp, resp_matches, regexes} =
          DutyTypeLib.find_role_holders(:responsibility, government_actors, text, regexes)

        {power_holders, power, power_matches, _regexes} =
          DutyTypeLib.find_role_holders(:power, government_actors, text, regexes)

        # Get generic duty types
        duty_types_generic = DutyTypeLib.duty_types_generic(text)

        # Combine all duty types
        duty_types =
          (duties ++ rights ++ resp ++ power ++ duty_types_generic)
          |> process_defaults()
          |> Enum.filter(&(&1 != nil))
          |> Enum.uniq()
          |> duty_type_sorter()

        # Update record
        record
        |> put_field(:duty_holder, to_jsonb(dutyholders), key_type)
        |> put_field(:rights_holder, to_jsonb(rightsholders), key_type)
        |> put_field(:responsibility_holder, to_jsonb(resp_holders), key_type)
        |> put_field(:power_holder, to_jsonb(power_holders), key_type)
        |> put_field(:duty_type, duty_types, key_type)
        |> put_field(:duty_holder_article_clause, duty_matches, key_type)
        |> put_field(:rights_holder_article_clause, right_matches, key_type)
        |> put_field(:responsibility_holder_article_clause, resp_matches, key_type)
        |> put_field(:power_holder_article_clause, power_matches, key_type)
    end
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

  # Converts list to JSONB-compatible format
  defp to_jsonb([]), do: nil
  defp to_jsonb(list) when is_list(list), do: %{"items" => list}

  # If no duty types found, default to Process/Rule/Constraint
  defp process_defaults([]), do: ["Process, Rule, Constraint, Condition"]
  defp process_defaults(duty_types), do: duty_types

  # Puts a field in the record with appropriate key type
  defp put_field(record, key, value, :atom), do: Map.put(record, key, value)
  defp put_field(record, key, value, :string), do: Map.put(record, Atom.to_string(key), value)
end
