defmodule SertantaiLegal.Legal.Taxa.DutyTypeDefn do
  @moduledoc """
  Generic regex pattern definitions for classifying legal text by duty type.

  These patterns identify structural/procedural elements of legislation that apply
  regardless of the specific actors involved.

  ## Duty Type Categories

  - **Enactment, Citation, Commencement**: When the law takes effect
  - **Interpretation, Definition**: Definitions of terms
  - **Application, Scope**: What the law applies to
  - **Extent**: Geographic coverage
  - **Exemption**: Excluded situations
  - **Repeal, Revocation**: Superseded provisions
  - **Transitional Arrangement**: Temporary provisions
  - **Amendment**: Changes to other laws
  - **Charge, Fee**: Financial obligations
  - **Offence**: Criminal provisions
  - **Enforcement, Prosecution**: Legal proceedings
  - **Defence, Appeal**: Defences and appeals
  - **Power Conferred**: Powers granted to authorities
  """

  @type pattern :: {String.t(), String.t()}

  # Special characters used in legal text
  # Em dash character (U+2014)
  defp emdash, do: <<226, 128, 148>>
  # Left double quotation mark (U+201C)
  defp lquote, do: <<226, 128, 156>>
  # Right double quotation mark (U+201D)
  defp rquote, do: <<226, 128, 157>>

  @doc """
  Returns patterns for enactment, citation, and commencement provisions.
  """
  @spec enaction_citation_commencement() :: list(pattern())
  def enaction_citation_commencement do
    duty_type = "Enactment, Citation, Commencement"

    [
      "(?:Act|Regulations?|Order) may be cited as",
      "(?:Act|Regulations?|Order).*?shall have effect",
      "(?:Act|Regulations?|Order) shall come into (?:force|operation)",
      "comes? into force",
      "has effect.*?on or after",
      "commencement"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for interpretation and definition clauses.

  The most common pattern is: "term" means...
  """
  @spec interpretation_definition() :: list(pattern())
  def interpretation_definition do
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

    duty_type = "Interpretation, Definition"

    [
      # Pattern: "term" means... (with curly quotes)
      "[A-Za-z\\d ]#{lquote()}.*?(?:#{defn})[ #{emdash()},]",
      "#{lquote()}.*?#{rquote()} is.*?[ #{emdash()},]",
      "In thi?e?se? [Rr]egulations?.*?#{emdash()}",
      "has?v?e? the (?:same )?(?:respective )?meanings?",
      # ?<! Negative Lookbehind
      "(?<!prepared) [Ff]or the purposes? of (?:this Act|determining|these Regulations) ",
      "(?:any reference|references?).*?to",
      "[Ii]nterpretation",
      "interpreting these Regulation",
      "for the meaning of #{lquote()}",
      "provisions.*?are reproduced",
      "an?y? reference.*?in these Regulations#{rquote()}",
      "[Ww]here an expression is defined.*?and is not defined.*?it has the same meaning",
      "are to be read",
      "[Ff]or the purposes of (?:this Act|these Regulations|the definition of|subsection)"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for application and scope provisions.
  """
  @spec application_scope() :: list(pattern())
  def application_scope do
    duty_type = "Application, Scope"

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
      # For the Purposes
      "Section.*?apply for the purposes",
      "[Ff]or the purposes of.*?the requirements? (?:of|set out in)",
      "[Ff]or the purposes of paragraph",
      # Other
      "requirements.*?which cannot be complied with are to be disregarded",
      "(?:[Rr]egulations|provisions) referred to",
      "without prejudice to (?:regulation|the generality of the requirements?)",
      "Nothing in.*?shall prejudice the operation",
      "[Nn]othing in these (?:Regulations) prevents",
      "shall bind the Crown"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for extent (geographic coverage) provisions.
  """
  @spec extent() :: list(pattern())
  def extent do
    [
      {"(?:Act|Regulation|section)(?: does not | do not | )extends? to", "Extent"},
      {"(?:Act|Regulations?|Section).*?extends? (?:only )?to", "Extent"},
      {"[Oo]nly.*?extend to", "Extent"},
      {"do not extend to", "Extent"},
      {"[R|r]egulations under", "Extent"},
      {"enactment amended or repealed by this Act extends", "Extent"},
      {"[Cc]orresponding provisions for Northern Ireland", "Extent"},
      {"shall not (?:extend|apply) to (Scotland|Wales|Northern Ireland)", "Extent"}
    ]
  end

  @doc """
  Returns patterns for exemption provisions.
  """
  @spec exemption() :: list(pattern())
  def exemption do
    [
      {" shall not apply in any case where[, ]", "Exemption"},
      {" by a certificate in writing exempt", "Exemption"},
      {" exemption", "Exemption"}
    ]
  end

  @doc """
  Returns patterns for repeal and revocation provisions.
  """
  @spec repeal_revocation() :: list(pattern())
  def repeal_revocation do
    duty_type = "Repeal, Revocation"

    [
      " . . . . . . . ",
      "(?:revoked|repealed)[ [:punct:]#{emdash()}]",
      "(?:[Rr]epeals|revocations)",
      "following Acts shall cease to have effect"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for transitional arrangement provisions.
  """
  @spec transitional_arrangement() :: list(pattern())
  def transitional_arrangement do
    duty_type = "Transitional Arrangement"

    [
      "transitional provision"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for amendment provisions.
  """
  @spec amendment() :: list(pattern())
  def amendment do
    duty_type = "Amendment"

    [
      # insert
      "shall be inserted the words#{emdash()} ?\\n?#{lquote()}[\\s\\S]*?#{rquote()}",
      "shall be inserted#{emdash()} ?\\n?#{lquote()}[\\s\\S]*?#{rquote()}",
      "there is inserted",
      "insert the following after",
      # inserted substituted
      " (?:substituted?|inserte?d?)#{emdash()}? ?\\n?#{lquote()}[\\s\\S]*?#{rquote()}",
      "shall be (?:inserted|substituted) the words",
      # substitute
      "for.*?substitute",
      # omit
      "omit the (?:words?|entr(?:y|ies) relat(?:ing|ed) to|entry for)",
      "omit the following",
      "[Oo]mit #{lquote()}?(?:section|paragraph)",
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
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for charge and fee provisions.
  """
  @spec charge_fee() :: list(pattern())
  def charge_fee do
    duty_type = "Charge, Fee"

    [
      " fees and charges ",
      " (fees?|charges?).*(paid|payable) ",
      " by the (fee|charge) ",
      " failed to pay a (fee|charge) ",
      " fee.*?may not exceed the sum of the costs",
      " fee may include any costs",
      " may charge.*?a fee ",
      " [Aa] fee charged",
      "invoice must include a statement of the work done"
    ]
    |> Enum.map(fn x -> {x, duty_type} end)
  end

  @doc """
  Returns patterns for offence provisions.
  """
  @spec offence() :: list(pattern())
  def offence do
    [
      {" ?[Oo]ffences?[ \\.,#{emdash()}:]", "Offence"},
      {"(?:[Ff]ixed|liable to a) penalty", "Offence"}
    ]
  end

  @doc """
  Returns patterns for enforcement and prosecution provisions.
  """
  @spec enforcement_prosecution() :: list(pattern())
  def enforcement_prosecution do
    [
      {"proceedings", "Enforcement, Prosecution"},
      {"conviction", "Enforcement, Prosecution"}
    ]
  end

  @doc """
  Returns patterns for defence and appeal provisions.
  """
  @spec defence_appeal() :: list(pattern())
  def defence_appeal do
    [
      {" [Aa]ppeal ", "Defence, Appeal"},
      {"[Ii]t is a defence for a ", "Defence, Appeal"},
      {"may not rely on a defence", "Defence, Appeal"},
      {"shall not be (?:guilty|liable)", "Defence, Appeal"},
      {"[Ii]t shall (?:also )?.*?be a defence", "Defence, Appeal"},
      {"[Ii]t shall be sufficient compliance", "Defence, Appeal"},
      {"rebuttable", "Defence, Appeal"}
    ]
  end

  @doc """
  Returns patterns for power conferred provisions.
  """
  @spec power_conferred() :: list(pattern())
  def power_conferred do
    [
      {" functions.*(?:exercis(?:ed|able)|conferred) ", "Power Conferred"},
      {" exercising.*functions ", "Power Conferred"},
      {"power to make regulations", "Power Conferred"},
      {"[Tt]he power under (?:subsection)", "Power Conferred"}
    ]
  end
end
