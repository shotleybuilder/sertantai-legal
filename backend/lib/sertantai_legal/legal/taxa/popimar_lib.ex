defmodule SertantaiLegal.Legal.Taxa.PopimarLib do
  @moduledoc """
  Regex pattern definitions for POPIMAR taxonomy classification.

  POPIMAR (Policy, Organisation, Planning, Implementation, Monitoring, Audit, Review)
  is a management system framework used to categorize legal requirements.

  ## Categories

  1. **Policy**: Strategic direction and objectives
  2. **Organisation**: Structure, appointments, roles
  3. **Organisation - Control**: Processes, procedures, supervision
  4. **Organisation - Communication & Consultation**: Information sharing
  5. **Organisation - Collaboration, Coordination, Cooperation**: Working together
  6. **Organisation - Competence**: Training, skills, knowledge
  7. **Organisation - Costs**: Financial aspects
  8. **Records**: Documentation requirements
  9. **Permit, Authorisation, License**: Formal approvals
  10. **Aspects and Hazards**: Risk identification
  11. **Planning & Risk / Impact Assessment**: Risk evaluation
  12. **Risk Control**: Risk mitigation measures
  13. **Notification**: Reporting requirements
  14. **Maintenance, Examination and Testing**: Equipment/system upkeep
  15. **Checking, Monitoring**: Ongoing verification
  16. **Review**: Periodic assessment

  ## Performance

  All regex patterns are pre-compiled at module load time. Use `regex_compiled/1`
  for the pre-compiled version, or `regex/1` for backwards compatibility.

  ## Usage

      iex> PopimarLib.regex_compiled(:policy)
      ~r/(Policy|Objectives|Strateg)/m

      iex> PopimarLib.patterns(:risk_control)
      ["[Rr]isk [Cc]ontrol", "control.*?risk", ...]
  """

  # Em dash character (U+2014) and right quote (U+2019)
  @emdash <<226, 128, 148>>
  @rquote <<226, 128, 157>>

  # Pre-compile all POPIMAR regexes at module load time
  # Using Regex.compile!/2 directly in module attributes
  @compiled_regexes %{
    policy:
      Regex.compile!(
        "(#{Enum.join(["[Pp]olicy?i?e?s?", "[Oo]bjectives?", "[Ss]trateg"], "|")})",
        "m"
      ),
    organisation:
      Regex.compile!(
        "(#{Enum.join(["[Oo]rg.? chart", "[Oo]rganisation chart", "making of appointments?", "(?:must|may|shall)[ ]?(?:jointly)?[ ]?appoint", "person.*?appointed", "appoint a person"], "|")})",
        "m"
      ),
    organisation_control:
      Regex.compile!(
        "(#{Enum.join(["[Pp]rocess", "[Pp]rocedure", "[Ww]ork instruction", "[Mm]ethod statement", "[Ii]nstruction", "comply?i?e?s? with.*?(?:duties|requirements)", "is responsible for", "has control over", "must ensure, insofar as they are matters within that person's control", "take such measures as it is reasonable for a person in his position to take", "(?:supervised?|supervising)"], "|")})",
        "m"
      ),
    organisation_communication_consultation:
      Regex.compile!(
        "(#{Enum.join(["[Cc]omminiate?i?o?n?g?", "[Cc]onsult", "[Cc]onsulti?n?g?", "[Cc]onsultation", "(?:send a copy of it|be sent) to", "must identify to", "publish a report", "must (?:immediately )?inform[[:blank:][:punct:]#{@emdash}]", "report to", "(?:by|to) provide?i?n?g?.*?information", "made available to (?:the public)", "supplied (?:in writing|with a copy)", "aware of the contents of"], "|")})",
        "m"
      ),
    organisation_collaboration_coordination_cooperation:
      Regex.compile!("(#{Enum.join(["[Cc]ollaborat", "[Cc]oordinat", "[Cc]ooperat"], "|")})", "m"),
    organisation_competence:
      Regex.compile!(
        "(#{Enum.join(["[Cc]ompetent?c?e?y?[ ](?!authority)", "[Tt]raining", "[Ii]nformation, instruction and training", "[Ii]nformation.*?provided to every person", "provide.*?information", "person satisfies the criteria", "skills, knowledge and experience", "organisational capability", "instructe?d?"], "|")})",
        "m"
      ),
    organisation_costs:
      Regex.compile!(
        "(#{Enum.join(["[Cc]ost[- ]benefit", "[Nn]ett? cost", "[Ff]ee[[:blank:][:punct:]#{@rquote}]", "[Cc]harge", "[Ff]inancial loss"], "|")})",
        "m"
      ),
    records:
      Regex.compile!(
        "(#{Enum.join(["(?:[Rr]ecord|[Rr]eport (?!to)|[Rr]egister)", "[Ll]ogbook", "[Ii]ventory", "[Dd]atabase", "(?:[Ee]nforcement|[Pp]rohibition|[Ii]mprovement) notice", "[Dd]ocuments?", "(?:marke?d?i?n?g?|labelled)", "must be kept", "certificate", "health and safety file"], "|")})",
        "m"
      ),
    permit_authorisation_license:
      Regex.compile!(
        "(#{Enum.join(["[ #{@rquote}][Pp]ermit[[:blank:][:punct:]#{@rquote}]", "[Aa]uthorisation", "[Aa]uthorised (?:^representative)", "[Ll]i[sc]en[sc]ed?", "[Ll]i[sc]en[sc]ing"], "|")})",
        "m"
      ),
    aspects_and_hazards:
      Regex.compile!("(#{Enum.join(["[Aa]spects and impacts", "[Hh]azard"], "|")})", "m"),
    planning_risk_impact_assessment:
      Regex.compile!(
        "(#{Enum.join(["[Aa]nnual plan", "[Ss]trategic plan", "[Bb]usiness plan", "[Pp]lan of work", "construction phase plan", "written plan", "measures? to be specified in the plan", "(?:project|action) plan", "project is planned", "[Ii]mpact [Aa]ssessment", "[Rr]isk [Aa]ssessment", "assessment of any risks", "suitable and sufficient assessment", "[Ii]n making the assessment", "(?:reassess|reassessed|reassessment)", "general principles of prevention", "identify and eliminate"], "|")})",
        "m"
      ),
    risk_control:
      Regex.compile!(
        "(#{Enum.join(["avoid the need", "suitable and sufficient steps", "steps as are reasonable in the circumstances must be taken", "taken? all reasonable steps", "takes immediate steps", "[Rr]isk [Cc]ontrol", "control.*?risk", "[Rr]isk mitigation", "use the best available techniques not entailing excessive cost", "eliminates.*?the risk", "reduces? the risk", "provided to.*?employees", "provision and use of", "safety management system", "corrective measures?", "meets the requirements?", "standards for the construction", "shall make full and proper use", "measures?.*?specified.*?plan", "take such measures"], "|")})",
        "m"
      ),
    notification:
      Regex.compile!(
        "(#{Enum.join(["given?.*?notice", "accident report", "[Nn]otify", "[Nn]otification", "[Aa]pplication for", "publish.*?a notice"], "|")})",
        "m"
      ),
    maintenance_examination_and_testing:
      Regex.compile!(
        "(#{Enum.join(["[Mm]aintenance", "[Mm]aintaine?d?", "[Ee]xamination", "[Tt]esting", "[Ii]nspecti?o?n?e?d?"], "|")})",
        "m"
      ),
    checking_monitoring:
      Regex.compile!(
        "(#{Enum.join(["[Cc]heck", "[Mm]onitor", "medical exam", "at least once every.*?years", "kept available for inspection"], "|")})",
        "m"
      ),
    review:
      Regex.compile!(
        "(#{Enum.join(["[Mm]anagement review", "(?:[Rr]eviewed|is [Rr]evised)", "(?:conduct|carry out|carrying out) (?:a|the) review", "review the (?:assessment)"], "|")})",
        "m"
      )
  }

  @doc """
  Returns a pre-compiled regex for the given category.
  Use this for performance - avoids runtime regex compilation.
  """
  @spec regex_compiled(atom()) :: Regex.t() | nil
  def regex_compiled(function) when is_atom(function) do
    Map.get(@compiled_regexes, function)
  end

  @doc """
  Builds a compiled regex from patterns for a category.
  Legacy interface - consider using `regex_compiled/1` instead for better performance.

  Returns nil if patterns return nil or empty list.
  """
  @spec regex(atom()) :: Regex.t() | nil
  def regex(function) when is_atom(function) do
    # Use pre-compiled version if available
    case Map.get(@compiled_regexes, function) do
      nil ->
        # Fallback to dynamic compilation for any custom functions
        case apply(__MODULE__, function, []) do
          nil ->
            nil

          [] ->
            nil

          patterns when is_list(patterns) ->
            term = Enum.join(patterns, "|")
            {:ok, regex} = Regex.compile("(#{term})", "m")
            regex
        end

      compiled ->
        compiled
    end
  end

  @doc """
  Returns patterns for policy-related text.
  """
  @spec policy() :: list(String.t())
  def policy do
    [
      "[Pp]olicy?i?e?s?",
      "[Oo]bjectives?",
      "[Ss]trateg"
    ]
  end

  @doc """
  Returns patterns for organisation-related text (appointments, roles).
  """
  @spec organisation() :: list(String.t())
  def organisation do
    [
      "[Oo]rg.? chart",
      "[Oo]rganisation chart",
      "making of appointments?",
      "(?:must|may|shall)[ ]?(?:jointly)?[ ]?appoint",
      "person.*?appointed",
      "appoint a person"
    ]
  end

  @doc """
  Returns patterns for organisational control (processes, procedures).
  """
  @spec organisation_control() :: list(String.t())
  def organisation_control do
    [
      "[Pp]rocess",
      "[Pp]rocedure",
      "[Ww]ork instruction",
      "[Mm]ethod statement",
      "[Ii]nstruction",
      "comply?i?e?s? with.*?(?:duties|requirements)",
      "is responsible for",
      "has control over",
      "must ensure, insofar as they are matters within that person's control",
      "take such measures as it is reasonable for a person in his position to take",
      "(?:supervised?|supervising)"
    ]
  end

  @doc """
  Returns patterns for communication and consultation requirements.
  """
  @spec organisation_communication_consultation() :: list(String.t())
  def organisation_communication_consultation do
    emdash = <<226, 128, 148>>

    [
      "[Cc]omminiate?i?o?n?g?",
      "[Cc]onsult",
      "[Cc]onsulti?n?g?",
      "[Cc]onsultation",
      "(?:send a copy of it|be sent) to",
      "must identify to",
      "publish a report",
      "must (?:immediately )?inform[[:blank:][:punct:]#{emdash}]",
      "report to",
      "(?:by|to) provide?i?n?g?.*?information",
      "made available to (?:the public)",
      "supplied (?:in writing|with a copy)",
      "aware of the contents of"
    ]
  end

  @doc """
  Returns patterns for collaboration, coordination, and cooperation.
  """
  @spec organisation_collaboration_coordination_cooperation() :: list(String.t())
  def organisation_collaboration_coordination_cooperation do
    [
      "[Cc]ollaborat",
      "[Cc]oordinat",
      "[Cc]ooperat"
    ]
  end

  @doc """
  Returns patterns for competence requirements (training, skills).
  """
  @spec organisation_competence() :: list(String.t())
  def organisation_competence do
    [
      "[Cc]ompetent?c?e?y?[ ](?!authority)",
      "[Tt]raining",
      "[Ii]nformation, instruction and training",
      "[Ii]nformation.*?provided to every person",
      "provide.*?information",
      "person satisfies the criteria",
      "skills, knowledge and experience",
      "organisational capability",
      "instructe?d?"
    ]
  end

  @doc """
  Returns patterns for cost-related requirements.
  """
  @spec organisation_costs() :: list(String.t())
  def organisation_costs do
    rquote = <<226, 128, 157>>

    [
      "[Cc]ost[- ]benefit",
      "[Nn]ett? cost",
      "[Ff]ee[[:blank:][:punct:]#{rquote}]",
      "[Cc]harge",
      "[Ff]inancial loss"
    ]
  end

  @doc """
  Returns patterns for records and documentation requirements.
  """
  @spec records() :: list(String.t())
  def records do
    [
      "(?:[Rr]ecord|[Rr]eport (?!to)|[Rr]egister)",
      "[Ll]ogbook",
      "[Ii]ventory",
      "[Dd]atabase",
      "(?:[Ee]nforcement|[Pp]rohibition|[Ii]mprovement) notice",
      "[Dd]ocuments?",
      "(?:marke?d?i?n?g?|labelled)",
      "must be kept",
      "certificate",
      "health and safety file"
    ]
  end

  @doc """
  Returns patterns for permits, authorisations, and licenses.
  """
  @spec permit_authorisation_license() :: list(String.t())
  def permit_authorisation_license do
    rquote = <<226, 128, 157>>

    [
      "[ #{rquote}][Pp]ermit[[:blank:][:punct:]#{rquote}]",
      "[Aa]uthorisation",
      "[Aa]uthorised (?:^representative)",
      "[Ll]i[sc]en[sc]ed?",
      "[Ll]i[sc]en[sc]ing"
    ]
  end

  @doc """
  Returns patterns for aspects and hazards identification.
  """
  @spec aspects_and_hazards() :: list(String.t())
  def aspects_and_hazards do
    [
      "[Aa]spects and impacts",
      "[Hh]azard"
    ]
  end

  @doc """
  Returns patterns for planning and risk/impact assessment.
  """
  @spec planning_risk_impact_assessment() :: list(String.t())
  def planning_risk_impact_assessment do
    [
      # Plan
      "[Aa]nnual plan",
      "[Ss]trategic plan",
      "[Bb]usiness plan",
      "[Pp]lan of work",
      "construction phase plan",
      "written plan",
      "measures? to be specified in the plan",
      "(?:project|action) plan",
      "project is planned",
      # Assessment
      "[Ii]mpact [Aa]ssessment",
      "[Rr]isk [Aa]ssessment",
      "assessment of any risks",
      "suitable and sufficient assessment",
      "[Ii]n making the assessment",
      "(?:reassess|reassessed|reassessment)",
      "general principles of prevention",
      "identify and eliminate"
    ]
  end

  @doc """
  Returns patterns for risk control measures.
  """
  @spec risk_control() :: list(String.t())
  def risk_control do
    [
      "avoid the need",
      # STEPS
      "suitable and sufficient steps",
      "steps as are reasonable in the circumstances must be taken",
      "taken? all reasonable steps",
      "takes immediate steps",
      # RISK
      "[Rr]isk [Cc]ontrol",
      "control.*?risk",
      "[Rr]isk mitigation",
      "use the best available techniques not entailing excessive cost",
      "eliminates.*?the risk",
      "reduces? the risk",
      # PROVIDES
      "provided to.*?employees",
      "provision and use of",
      # MEASURES
      "safety management system",
      "corrective measures?",
      "meets the requirements?",
      "standards for the construction",
      "shall make full and proper use",
      "measures?.*?specified.*?plan",
      "take such measures"
    ]
  end

  @doc """
  Returns patterns for notification requirements.
  """
  @spec notification() :: list(String.t())
  def notification do
    [
      "given?.*?notice",
      "accident report",
      "[Nn]otify",
      "[Nn]otification",
      "[Aa]pplication for",
      "publish.*?a notice"
    ]
  end

  @doc """
  Returns patterns for maintenance, examination, and testing.
  """
  @spec maintenance_examination_and_testing() :: list(String.t())
  def maintenance_examination_and_testing do
    [
      "[Mm]aintenance",
      "[Mm]aintaine?d?",
      "[Ee]xamination",
      "[Tt]esting",
      "[Ii]nspecti?o?n?e?d?"
    ]
  end

  @doc """
  Returns patterns for checking and monitoring.
  """
  @spec checking_monitoring() :: list(String.t())
  def checking_monitoring do
    [
      "[Cc]heck",
      "[Mm]onitor",
      "medical exam",
      "at least once every.*?years",
      "kept available for inspection"
    ]
  end

  @doc """
  Returns patterns for review requirements.
  """
  @spec review() :: list(String.t())
  def review do
    [
      "[Mm]anagement review",
      "(?:[Rr]eviewed|is [Rr]evised)",
      "(?:conduct|carry out|carrying out) (?:a|the) review",
      "review the (?:assessment)"
    ]
  end
end
