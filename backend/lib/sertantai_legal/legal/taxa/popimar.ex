defmodule SertantaiLegal.Legal.Taxa.Popimar do
  @moduledoc """
  Classifies legal text by POPIMAR taxonomy.

  POPIMAR (Policy, Organisation, Planning, Implementation, Monitoring, Audit, Review)
  is a management system framework used to categorize legal requirements by the type
  of management action they require.

  ## POPIMAR Categories (16 total)

  1. Policy
  2. Organisation
  3. Organisation - Control
  4. Organisation - Communication & Consultation
  5. Organisation - Collaboration, Coordination, Cooperation
  6. Organisation - Competence
  7. Organisation - Costs
  8. Records
  9. Permit, Authorisation, License
  10. Aspects and Hazards
  11. Planning & Risk / Impact Assessment
  12. Risk Control
  13. Notification
  14. Maintenance, Examination and Testing
  15. Checking, Monitoring
  16. Review

  ## Usage

      # Get POPIMAR categories for text
      iex> Popimar.get_popimar("The employer shall provide training to employees.")
      ["Organisation - Competence"]

      # Process a record with duty types
      iex> Popimar.process_record(%{text: "...", duty_type: ["Duty"]})
      %{text: "...", duty_type: ["Duty"], popimar: ["Risk Control"]}
  """

  alias SertantaiLegal.Legal.Taxa.PopimarLib

  @type popimar :: list(String.t())
  @type text :: String.t()
  @type record :: map()

  # POPIMAR categories in display order
  @popimar_categories [
    "Policy",
    "Organisation",
    "Organisation - Control",
    "Organisation - Communication & Consultation",
    "Organisation - Collaboration, Coordination, Cooperation",
    "Organisation - Competence",
    "Organisation - Costs",
    "Records",
    "Permit, Authorisation, License",
    "Aspects and Hazards",
    "Planning & Risk / Impact Assessment",
    "Risk Control",
    "Notification",
    "Maintenance, Examination and Testing",
    "Checking, Monitoring",
    "Review"
  ]

  # Duty types that should trigger POPIMAR classification
  @duty_types_for_popimar MapSet.new([
                            "Duty",
                            "Right",
                            "Responsibility",
                            "Discretionary",
                            "Process, Rule, Constraint, Condition"
                          ])

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Returns all POPIMAR categories.
  """
  @spec categories() :: list(String.t())
  def categories, do: @popimar_categories

  @doc """
  Gets POPIMAR classifications for text.

  Returns a list of matching POPIMAR categories.
  """
  @spec get_popimar(text()) :: popimar()
  def get_popimar(text) when is_binary(text) and text != "" do
    @popimar_categories
    |> Enum.reduce([], fn category, acc ->
      function = category_to_function(category)
      regex = PopimarLib.regex(function)

      if regex != nil and Regex.match?(regex, text) do
        [category | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
    |> popimar_sorter()
  end

  def get_popimar(_), do: []

  @doc """
  Gets POPIMAR classifications for text, considering duty types.

  If the text has relevant duty types but no POPIMAR match,
  defaults to "Risk Control".
  """
  @spec get_popimar(text(), list(String.t())) :: popimar()
  def get_popimar(text, duty_types) when is_binary(text) and is_list(duty_types) do
    popimar = get_popimar(text)

    # Default to Risk Control if no match but has relevant duty types
    if popimar == [] and has_relevant_duty_types?(duty_types) do
      ["Risk Control"]
    else
      popimar
    end
  end

  @doc """
  Processes a single law record, classifying by POPIMAR.

  Expects a map with:
  - `:text` or `"text"` - The legal text to analyze
  - `:duty_type` or `"duty_type"` - List of duty types (optional)

  ## Options
  - `:article` - Article reference for JSONB output (e.g., "regulation/4")

  Returns the map with `:popimar` added.
  """
  @spec process_record(record(), keyword()) :: record()
  def process_record(record, opts \\ [])

  def process_record(%{text: text, duty_type: duty_types} = record, opts)
      when is_binary(text) and text != "" do
    duty_types = normalize_duty_types(duty_types)
    do_process_record(record, text, duty_types, :atom, opts)
  end

  def process_record(%{text: text} = record, opts) when is_binary(text) and text != "" do
    do_process_record(record, text, [], :atom, opts)
  end

  def process_record(%{"text" => text, "duty_type" => duty_types} = record, opts)
      when is_binary(text) and text != "" do
    duty_types = normalize_duty_types(duty_types)
    do_process_record(record, text, duty_types, :string, opts)
  end

  def process_record(%{"text" => text} = record, opts) when is_binary(text) and text != "" do
    do_process_record(record, text, [], :string, opts)
  end

  def process_record(record, _opts), do: record

  @doc """
  Processes a list of law records.
  """
  @spec process_records(list(record())) :: list(record())
  def process_records(records) when is_list(records) do
    Enum.map(records, &process_record/1)
  end

  @doc """
  Sorts POPIMAR categories by priority order.
  """
  @spec popimar_sorter(popimar()) :: popimar()
  def popimar_sorter(categories) do
    proxy = %{
      "Policy" => "01Policy",
      "Organisation" => "02Organisation",
      "Organisation - Control" => "03Organisation - Control",
      "Organisation - Communication & Consultation" =>
        "04Organisation - Communication & Consultation",
      "Organisation - Collaboration, Coordination, Cooperation" =>
        "05Organisation - Collaboration, Coordination, Cooperation",
      "Organisation - Competence" => "06Organisation - Competence",
      "Organisation - Costs" => "07Organisation - Costs",
      "Records" => "08Records",
      "Permit, Authorisation, License" => "09Permit, Authorisation, License",
      "Notification" => "10Notification",
      "Planning & Risk / Impact Assessment" => "11Planning & Risk / Impact Assessment",
      "Aspects and Hazards" => "12Aspects and Hazards",
      "Risk Control" => "13Risk Control",
      "Maintenance, Examination and Testing" => "14Maintenance, Examination and Testing",
      "Checking, Monitoring" => "15Checking, Monitoring",
      "Review" => "16Review"
    }

    reverse_proxy = Map.new(proxy, fn {k, v} -> {v, k} end)

    categories
    |> Enum.map(&Map.get(proxy, &1))
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort()
    |> Enum.map(&Map.get(reverse_proxy, &1))
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_process_record(record, text, duty_types, key_type, opts) do
    article = Keyword.get(opts, :article)

    # Only process if has relevant duty types (or no duty types provided)
    popimar =
      if duty_types == [] or has_relevant_duty_types?(duty_types) do
        get_popimar(text, duty_types)
      else
        []
      end

    # Add popimar list field
    record = put_field(record, :popimar, popimar, key_type)

    # Add popimar_details JSONB field with article context
    popimar_details =
      if popimar != [] do
        SertantaiLegal.Legal.Taxa.TaxaFormatter.popimar_to_jsonb(popimar, article: article)
      else
        nil
      end

    put_field(record, :popimar_details, popimar_details, key_type)
  end

  # Converts category name to function name
  defp category_to_function(category) do
    category
    |> String.downcase()
    |> String.replace("-", "")
    |> String.replace("&", "")
    |> String.replace("/", "")
    |> String.replace(~r/[ ]{2,}/, " ")
    |> String.replace(", ", "_")
    |> String.replace(" ", "_")
    |> String.to_atom()
  end

  # Checks if any duty types are relevant for POPIMAR classification
  defp has_relevant_duty_types?(duty_types) do
    Enum.any?(duty_types, &MapSet.member?(@duty_types_for_popimar, &1))
  end

  # Normalizes duty types to a list of strings
  defp normalize_duty_types(nil), do: []
  defp normalize_duty_types([]), do: []
  defp normalize_duty_types(list) when is_list(list), do: list
  defp normalize_duty_types(%{"items" => items}) when is_list(items), do: items
  defp normalize_duty_types(_), do: []

  # Puts a field in the record with appropriate key type
  defp put_field(record, key, value, :atom), do: Map.put(record, key, value)
  defp put_field(record, key, value, :string), do: Map.put(record, Atom.to_string(key), value)
end
