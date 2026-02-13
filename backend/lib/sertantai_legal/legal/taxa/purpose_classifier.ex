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
  # Pre-compiled Regex Patterns (compiled at module load time)
  # ============================================================================

  # Em dash character (U+2014)
  @emdash <<226, 128, 148>>

  # Pattern definitions as module attributes (for compile-time access)
  @amendment_patterns_raw [
    "shall be inserted the words#{@emdash}",
    "shall be inserted#{@emdash}",
    "there is inserted",
    "insert the following after",
    " (?:substituted?|inserte?d?)#{@emdash}?",
    "shall be (?:inserted|substituted) the words",
    "for.*?substitute",
    "omit the (?:words?|entr(?:y|ies) relat(?:ing|ed) to|entry for)",
    "omit the following",
    ~s/[Oo]mit ["'""]?(?:section|paragraph)/,
    "[Oo]mit[ ]+(?:section|paragraph)",
    "entry.*?shall be omitted",
    "shall be amended",
    "there shall be added the following paragraph",
    "add the following after (?:subsection|paragraph)",
    "[Aa]mendments?",
    "[Aa]mended as follows",
    "are amended on accordance with"
  ]

  @enactment_patterns_raw [
    "(?:Act|Regulations?|Order) may be cited as",
    "(?:Act|Regulations?|Order).*?shall have effect",
    "(?:Act|Regulations?|Order) shall come into (?:force|operation)",
    "comes? into force",
    "has effect.*?on or after",
    "commencement"
  ]

  @interpretation_patterns_raw (
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

                                 quote_pattern = ~s/[""']/

                                 [
                                   "[A-Za-z\\d ]#{quote_pattern}.*?(?:#{defn})",
                                   "#{quote_pattern}.*?#{quote_pattern} is",
                                   "In thi?e?se? [Rr]egulations?.*?#{@emdash}",
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
                               )

  @application_scope_patterns_raw [
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

  @extent_patterns_raw [
    "(?:Act|Regulation|section)(?: does not | do not | )extends? to",
    "(?:Act|Regulations?|Section).*?extends? (?:only )?to",
    "[Oo]nly.*?extend to",
    "do not extend to",
    "[R|r]egulations under",
    "enactment amended or repealed by this Act extends",
    "[Cc]orresponding provisions for Northern Ireland",
    "shall not (?:extend|apply) to (Scotland|Wales|Northern Ireland)"
  ]

  @exemption_patterns_raw [
    "shall not apply in any case where",
    "by a certificate in writing exempt",
    "\\bexemption\\b"
  ]

  @process_rule_patterns_raw [
    "\\bshall\\b",
    "\\bmust\\b",
    "\\brequired\\b",
    "\\brequirements?\\b",
    "\\bobligations?\\b",
    "\\bprocedures?\\b",
    "\\brules?\\b",
    "\\bconditions?\\b",
    "\\bconstraints?\\b",
    "\\bduty\\b",
    "\\bduties\\b",
    "\\bcomply\\b",
    "\\bcompliance\\b",
    "\\bprohibited\\b",
    "\\bpermitted\\b",
    "\\bmay not\\b",
    "\\bstandards?\\b",
    "\\bspecifications?\\b",
    "\\bensure\\b",
    "\\bmaintain\\b",
    "\\bresponsible\\b",
    "\\bresponsibilities\\b"
  ]

  @repeal_revocation_patterns_raw [
    "\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.\\s+\\.",
    "(?:revoked|repealed)",
    "(?:[Rr]epeals|revocations)",
    "following Acts shall cease to have effect"
  ]

  @transitional_patterns_raw [
    "transitional provision",
    "transitional arrangements?"
  ]

  @charge_fee_patterns_raw [
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

  @offence_patterns_raw [
    " ?[Oo]ffences?[ \\.,#{@emdash}:]",
    "(?:[Ff]ixed|liable to a) penalty"
  ]

  @enforcement_patterns_raw [
    "proceedings",
    "conviction"
  ]

  @defence_appeal_patterns_raw [
    " [Aa]ppeal ",
    "[Ii]t is a defence for a ",
    "may not rely on a defence",
    "shall not be (?:guilty|liable)",
    "[Ii]t shall (?:also )?.*?be a defence",
    "[Ii]t shall be sufficient compliance",
    "rebuttable"
  ]

  @power_conferred_patterns_raw [
    " functions.*(?:exercis(?:ed|able)|conferred) ",
    " exercising.*functions ",
    "power to make regulations",
    "[Tt]he power under (?:subsection)"
  ]

  @liability_patterns_raw [
    "\\bliability\\b",
    "\\bliable\\b"
  ]

  # Raw pattern map for runtime compilation (Regex structs can't be stored in module attributes)
  @raw_pattern_map %{
    amendment: @amendment_patterns_raw,
    enactment: @enactment_patterns_raw,
    interpretation: @interpretation_patterns_raw,
    application_scope: @application_scope_patterns_raw,
    extent: @extent_patterns_raw,
    exemption: @exemption_patterns_raw,
    process_rule: @process_rule_patterns_raw,
    repeal_revocation: @repeal_revocation_patterns_raw,
    transitional: @transitional_patterns_raw,
    charge_fee: @charge_fee_patterns_raw,
    offence: @offence_patterns_raw,
    enforcement: @enforcement_patterns_raw,
    defence_appeal: @defence_appeal_patterns_raw,
    power_conferred: @power_conferred_patterns_raw,
    liability: @liability_patterns_raw
  }

  # Returns compiled patterns map, cached in :persistent_term
  defp do_compiled_patterns do
    case :persistent_term.get({__MODULE__, :compiled_patterns}, nil) do
      nil ->
        compiled =
          Map.new(@raw_pattern_map, fn {k, patterns} ->
            {k, Enum.map(patterns, &Regex.compile!(&1, "i"))}
          end)

        :persistent_term.put({__MODULE__, :compiled_patterns}, compiled)
        compiled

      cached ->
        cached
    end
  end

  @doc """
  Returns pre-compiled regex patterns for a given category.
  """
  @spec compiled_patterns(atom()) :: list(Regex.t())
  def compiled_patterns(category), do: Map.get(do_compiled_patterns(), category, [])

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
  # Public API
  # ============================================================================

  @doc """
  Classifies legal text and returns a list of purposes.

  Runs all pattern checks and returns all matching purposes.
  """
  @spec classify(String.t()) :: purposes()
  def classify(text) when is_binary(text) and text != "" do
    text
    |> run_all_patterns()
    |> apply_defaults()
    |> Enum.uniq()
    |> sort_purposes()
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
    |> check_patterns_compiled(text, :enactment, @purposes.enactment_citation_commencement)
    |> check_patterns_compiled(text, :interpretation, @purposes.interpretation_definition)
    |> check_patterns_compiled(text, :application_scope, @purposes.application_scope)
    |> check_patterns_compiled(text, :extent, @purposes.extent)
    |> check_patterns_compiled(text, :exemption, @purposes.exemption)
    |> check_patterns_compiled(text, :process_rule, @purposes.process_rule_constraint_condition)
    |> check_patterns_compiled(text, :repeal_revocation, @purposes.repeal_revocation)
    |> check_patterns_compiled(text, :transitional, @purposes.transitional_arrangement)
    |> check_patterns_compiled(text, :charge_fee, @purposes.charge_fee)
    |> check_patterns_compiled(text, :offence, @purposes.offence)
    |> check_patterns_compiled(text, :enforcement, @purposes.enforcement_prosecution)
    |> check_patterns_compiled(text, :defence_appeal, @purposes.defence_appeal)
    |> check_patterns_compiled(text, :power_conferred, @purposes.power_conferred)
    |> check_patterns_compiled(text, :liability, @purposes.liability)
    |> check_patterns_compiled(text, :amendment, @purposes.amendment)
  end

  defp check_patterns_compiled(acc, text, category, purpose) do
    regexes = Map.get(do_compiled_patterns(), category, [])

    if Enum.any?(regexes, &Regex.match?(&1, text)) do
      [purpose | acc]
    else
      acc
    end
  end

  defp apply_defaults([]), do: [@purposes.process_rule_constraint_condition]
  defp apply_defaults(purposes), do: purposes

  # ============================================================================
  # Amendment Detection
  # ============================================================================

  defp title_matches_amendment?(title) do
    String.contains?(title, "(Amendment)") or
      String.match?(title, ~r/\(Amendment No\.\s*\d+\)/i) or
      String.match?(title, ~r/\(Amendments?\)/i) or
      String.match?(title, ~r/Amendment (?:Regulations?|Order|Act|Rules?)/i)
  end
end
