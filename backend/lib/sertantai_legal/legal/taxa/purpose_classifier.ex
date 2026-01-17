defmodule SertantaiLegal.Legal.Taxa.PurposeClassifier do
  @moduledoc """
  Classifies legal text by purpose (function-based classification).

  Purpose identifies WHAT the law does, as opposed to duty_type which identifies
  WHO has obligations (role-based classification).

  ## Purpose Categories (sorted by priority)

  1. `Enactment+Citation+Commencement` - When law takes effect
  2. `Interpretation+Definition` - Term definitions
  3. `Application+Scope` - What the law applies to
  4. `Extent` - Geographic coverage
  5. `Exemption` - Excluded situations
  6. `Process+Rule+Constraint+Condition` - Procedural requirements (default)
  7. `Power Conferred` - General powers granted
  8. `Charge+Fee` - Financial obligations
  9. `Offence` - Criminal provisions
  10. `Enforcement+Prosecution` - Legal proceedings
  11. `Defence+Appeal` - Defences and appeals
  12. `Liability` - Liability provisions
  13. `Repeal+Revocation` - Superseded provisions
  14. `Amendment` - Changes to other laws
  15. `Transitional Arrangement` - Temporary provisions

  Note: Uses `+` as separator instead of `,` to avoid CSV parsing issues.

  ## Usage

      # Get purposes from text
      iex> PurposeClassifier.classify("This Act may be cited as...")
      ["Enactment+Citation+Commencement"]

      # Get purposes from title
      iex> PurposeClassifier.classify_title("The Environmental Protection (Amendment) Regulations 2024")
      ["Amendment"]
  """

  @type purpose :: String.t()
  @type purposes :: list(purpose())

  # ============================================================================
  # Purpose Values (with + separator)
  # ============================================================================

  @purposes %{
    amendment: "Amendment",
    application_scope: "Application+Scope",
    charge_fee: "Charge+Fee",
    defence_appeal: "Defence+Appeal",
    enactment_citation_commencement: "Enactment+Citation+Commencement",
    enforcement_prosecution: "Enforcement+Prosecution",
    exemption: "Exemption",
    extent: "Extent",
    interpretation_definition: "Interpretation+Definition",
    liability: "Liability",
    offence: "Offence",
    power_conferred: "Power Conferred",
    process_rule_constraint_condition: "Process+Rule+Constraint+Condition",
    repeal_revocation: "Repeal+Revocation",
    transitional_arrangement: "Transitional Arrangement"
  }

  @doc """
  Returns all valid purpose values.
  """
  @spec all_purposes() :: purposes()
  def all_purposes do
    [
      @purposes.enactment_citation_commencement,
      @purposes.interpretation_definition,
      @purposes.application_scope,
      @purposes.extent,
      @purposes.exemption,
      @purposes.process_rule_constraint_condition,
      @purposes.power_conferred,
      @purposes.charge_fee,
      @purposes.offence,
      @purposes.enforcement_prosecution,
      @purposes.defence_appeal,
      @purposes.liability,
      @purposes.repeal_revocation,
      @purposes.amendment,
      @purposes.transitional_arrangement
    ]
  end

  # ============================================================================
  # Special Characters
  # ============================================================================

  # Em dash character (U+2014)
  defp emdash, do: <<226, 128, 148>>

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Classifies legal text and returns a list of purposes.

  Amendment is checked first - if found, no further classification is done.
  """
  @spec classify(String.t()) :: purposes()
  def classify(text) when is_binary(text) and text != "" do
    # Amendment takes precedence - if found, return immediately
    if matches_amendment?(text) do
      [@purposes.amendment]
    else
      text
      |> run_all_patterns()
      |> apply_defaults()
      |> Enum.uniq()
      |> sort_purposes()
    end
  end

  def classify(_), do: []

  @doc """
  Classifies a law title to determine its purpose.

  Useful for quick classification based on title alone.
  """
  @spec classify_title(String.t()) :: purposes()
  def classify_title(title) when is_binary(title) and title != "" do
    cond do
      # Amendment laws
      title_matches_amendment?(title) ->
        [@purposes.amendment]

      # Revocation/Repeal
      String.contains?(title, "(Revocation)") or String.contains?(title, "(Repeal)") ->
        [@purposes.repeal_revocation]

      # Commencement orders
      String.contains?(title, "(Commencement") ->
        [@purposes.enactment_citation_commencement]

      # Application/Scope
      String.contains?(title, "(Application)") ->
        [@purposes.application_scope]

      # Transitional
      String.contains?(title, "(Transitional") ->
        [@purposes.transitional_arrangement]

      # Extent
      String.contains?(title, "(Extent)") or String.contains?(title, "(Extension") ->
        [@purposes.extent]

      true ->
        []
    end
  end

  def classify_title(_), do: []

  @doc """
  Sorts purposes by priority order.
  """
  @spec sort_purposes(purposes()) :: purposes()
  def sort_purposes(purposes) do
    priority = %{
      @purposes.enactment_citation_commencement => 1,
      @purposes.interpretation_definition => 2,
      @purposes.application_scope => 3,
      @purposes.extent => 4,
      @purposes.exemption => 5,
      @purposes.process_rule_constraint_condition => 6,
      @purposes.power_conferred => 7,
      @purposes.charge_fee => 8,
      @purposes.offence => 9,
      @purposes.enforcement_prosecution => 10,
      @purposes.defence_appeal => 11,
      @purposes.liability => 12,
      @purposes.repeal_revocation => 13,
      @purposes.amendment => 14,
      @purposes.transitional_arrangement => 15
    }

    Enum.sort_by(purposes, &Map.get(priority, &1, 99))
  end

  # ============================================================================
  # Pattern Matching
  # ============================================================================

  defp run_all_patterns(text) do
    []
    |> check_patterns(
      text,
      enactment_citation_commencement_patterns(),
      @purposes.enactment_citation_commencement
    )
    |> check_patterns(
      text,
      interpretation_definition_patterns(),
      @purposes.interpretation_definition
    )
    |> check_patterns(text, application_scope_patterns(), @purposes.application_scope)
    |> check_patterns(text, extent_patterns(), @purposes.extent)
    |> check_patterns(text, exemption_patterns(), @purposes.exemption)
    |> check_patterns(text, repeal_revocation_patterns(), @purposes.repeal_revocation)
    |> check_patterns(
      text,
      transitional_arrangement_patterns(),
      @purposes.transitional_arrangement
    )
    |> check_patterns(text, charge_fee_patterns(), @purposes.charge_fee)
    |> check_patterns(text, offence_patterns(), @purposes.offence)
    |> check_patterns(text, enforcement_prosecution_patterns(), @purposes.enforcement_prosecution)
    |> check_patterns(text, defence_appeal_patterns(), @purposes.defence_appeal)
    |> check_patterns(text, power_conferred_patterns(), @purposes.power_conferred)
    |> check_patterns(text, liability_patterns(), @purposes.liability)
  end

  defp check_patterns(acc, text, patterns, purpose) do
    if Enum.any?(patterns, &regex_match?(text, &1)) do
      [purpose | acc]
    else
      acc
    end
  end

  defp regex_match?(text, pattern) do
    case Regex.compile(pattern, "i") do
      {:ok, regex} -> Regex.match?(regex, text)
      {:error, _} -> false
    end
  end

  defp apply_defaults([]), do: [@purposes.process_rule_constraint_condition]
  defp apply_defaults(purposes), do: purposes

  # ============================================================================
  # Amendment Detection
  # ============================================================================

  defp matches_amendment?(text) do
    Enum.any?(amendment_patterns(), &regex_match?(text, &1))
  end

  defp title_matches_amendment?(title) do
    String.contains?(title, "(Amendment)") or
      String.match?(title, ~r/\(Amendment No\.\s*\d+\)/i) or
      String.match?(title, ~r/\(Amendments?\)/i)
  end

  # ============================================================================
  # Pattern Definitions
  # ============================================================================

  defp amendment_patterns do
    [
      # insert
      "shall be inserted the words#{emdash()}",
      "shall be inserted#{emdash()}",
      "there is inserted",
      "insert the following after",
      # inserted substituted
      " (?:substituted?|inserte?d?)#{emdash()}?",
      "shall be (?:inserted|substituted) the words",
      # substitute
      "for.*?substitute",
      # omit
      "omit the (?:words?|entr(?:y|ies) relat(?:ing|ed) to|entry for)",
      "omit the following",
      ~s/[Oo]mit ["'""]?(?:section|paragraph)/,
      "[Oo]mit[ ]+(?:section|paragraph)",
      "entry.*?shall be omitted",
      # amended
      "shall be amended",
      # added
      "there shall be added the following paragraph",
      "add the following after (?:subsection|paragraph)",
      # amend
      "[Aa]mendments?",
      "[Aa]mended as follows",
      "are amended in accordance with"
    ]
  end

  defp enactment_citation_commencement_patterns do
    [
      "(?:Act|Regulations?|Order) may be cited as",
      "(?:Act|Regulations?|Order).*?shall have effect",
      "(?:Act|Regulations?|Order) shall come into (?:force|operation)",
      "comes? into force",
      "has effect.*?on or after",
      "commencement"
    ]
  end

  defp interpretation_definition_patterns do
    defn =
      [
        "means",
        "includes",
        "does not include",
        "is (?:information|the)",
        "are",
        "to be read as",
        "are references to",
        "consists"
      ]
      |> Enum.join("|")

    # Pattern with both curly quotes and straight quotes
    quote_pattern = ~s/[""']/

    [
      # Pattern: "term" means... (with curly or straight quotes)
      "[A-Za-z\\d ]#{quote_pattern}.*?(?:#{defn})",
      "#{quote_pattern}.*?#{quote_pattern} is",
      "In thi?e?se? [Rr]egulations?.*?#{emdash()}",
      "In thi?e?se? [Rr]egulations?.*?—",
      "has?v?e? the (?:same )?(?:respective )?meanings?",
      "[Ff]or the purposes? of (?:this Act|determining|these Regulations)",
      "(?:any reference|references?).*?to",
      "[Ii]nterpretation",
      "interpreting these Regulation",
      "for the meaning of",
      "provisions.*?are reproduced",
      "an?y? reference.*?in these Regulations",
      "[Ww]here an expression is defined.*?and is not defined.*?it has the same meaning",
      "are to be read",
      "[Ff]or the purposes of (?:this Act|these Regulations|the definition of|subsection)"
    ]
  end

  defp application_scope_patterns do
    [
      "Application",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?|Article).*?apply?i?e?s?",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?).*?doe?s? not apply",
      "(?:Act|Part|Chapter|[Ss]ections?|[Ss]ubsection|[Rr]egulations?|[Pp]aragraphs?|[Ss]chedules?).*?has effect",
      "This.*?was enacted.*?for the purpose of making such provision as.*?necessary in order to comply with",
      "does not apply",
      "shall.*?apply",
      "shall have effect",
      "shall have no effect",
      "ceases to have effect",
      "shall remain in force until",
      "provisions of.*?apply",
      "application of this (?:Part|Chapter|[Ss]ection)",
      "apply to any work outside",
      "apply to a self-employed person",
      "Save where otherwise expressly provided, nothing in.*?shall impose a duty",
      "need not be complied with until",
      "Section.*?apply for the purposes",
      "[Ff]or the purposes of.*?the requirements? (?:of|set out in)",
      "[Ff]or the purposes of paragraph",
      "requirements.*?which cannot be complied with are to be disregarded",
      "(?:[Rr]egulations|provisions) referred to",
      "without prejudice to (?:regulation|the generality of the requirements?)",
      "Nothing in.*?shall prejudice the operation",
      "[Nn]othing in these (?:Regulations) prevents",
      "shall bind the Crown"
    ]
  end

  defp extent_patterns do
    [
      "(?:Act|Regulation|section)(?: does not | do not | )extends? to",
      "(?:Act|Regulations?|Section).*?extends? (?:only )?to",
      "[Oo]nly.*?extend to",
      "do not extend to",
      "[R|r]egulations under",
      "enactment amended or repealed by this Act extends",
      "[Cc]orresponding provisions for Northern Ireland",
      "shall not (?:extend|apply) to (Scotland|Wales|Northern Ireland)"
    ]
  end

  defp exemption_patterns do
    [
      "shall not apply in any case where",
      "by a certificate in writing exempt",
      "\\bexemption\\b"
    ]
  end

  defp repeal_revocation_patterns do
    [
      "\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.",
      "(?:revoked|repealed)",
      "(?:[Rr]epeals|revocations)",
      "following Acts shall cease to have effect"
    ]
  end

  defp transitional_arrangement_patterns do
    [
      "transitional provision",
      "transitional arrangements?"
    ]
  end

  defp charge_fee_patterns do
    [
      "fees and charges",
      "(fees?|charges?).*(paid|payable)",
      "by the (fee|charge)",
      "failed to pay a (fee|charge)",
      "fee.*?may not exceed the sum of the costs",
      "fee may include any costs",
      "may charge.*?a fee",
      "[Aa] fee charged",
      "invoice must include a statement of the work done"
    ]
  end

  defp offence_patterns do
    [
      " ?[Oo]ffences?[ \\.,#{emdash()}:]",
      "(?:[Ff]ixed|liable to a) penalty"
    ]
  end

  defp enforcement_prosecution_patterns do
    [
      "proceedings",
      "conviction"
    ]
  end

  defp defence_appeal_patterns do
    [
      " [Aa]ppeal ",
      "[Ii]t is a defence for a ",
      "may not rely on a defence",
      "shall not be (?:guilty|liable)",
      "[Ii]t shall (?:also )?.*?be a defence",
      "[Ii]t shall be sufficient compliance",
      "rebuttable"
    ]
  end

  defp power_conferred_patterns do
    [
      " functions.*(?:exercis(?:ed|able)|conferred) ",
      " exercising.*functions ",
      "power to make regulations",
      "[Tt]he power under (?:subsection)"
    ]
  end

  defp liability_patterns do
    [
      "\\bliability\\b",
      "\\bliable\\b"
    ]
  end
end
