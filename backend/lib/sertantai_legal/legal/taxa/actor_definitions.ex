defmodule SertantaiLegal.Legal.Taxa.ActorDefinitions do
  @moduledoc """
  Regex pattern definitions for identifying actors (duty holders) in legal text.

  Actors are categorized into two main groups:
  - **Government**: Crown, authorities, agencies, ministers, devolved administrations
  - **Governed**: Businesses, individuals, specialists, supply chain actors

  Each pattern is wrapped with word boundary markers `[[:blank:][:punct:]]` to ensure
  accurate matching without partial word matches.

  ## Usage

      iex> ActorDefinitions.dutyholder_library()
      [{"Crown", ~r/.../, ...}]

      iex> ActorDefinitions.government()
      [{"Gvt: Authority: Local", ~r/.../, ...}]

      iex> ActorDefinitions.governed()
      [{"Org: Employer", ~r/.../, ...}]
  """

  @doc """
  Returns the complete dutyholder library combining government and governed actors.
  """
  @spec dutyholder_library() :: list({String.t(), String.t()})
  def dutyholder_library do
    government() ++ governed()
  end

  @doc """
  Returns government actor patterns (authorities, agencies, ministers, etc.).
  Patterns are sorted descending and wrapped with boundary markers.
  """
  @spec government() :: list({String.t(), String.t()})
  def government do
    ([
       Crown: "Crown",
       "EU: Commission": "[Cc]ommission",
       "Gvt: Commissioners": "[Cc]ommissioners",
       "Gvt: Officer": [
         "[Aa]uthorised [Oo]fficer",
         "[Oo]fficer of a local authority",
         "[Oo]fficer"
       ],
       "Gvt: Appropriate Person": "[Aa]ppropriate [Pp]ersons?",
       "Gvt: Judiciary": [
         "court",
         "[Jj]ustice of the [Pp]eace",
         "[Tt]ribunal",
         "[Ss]heriff",
         "[Mm]agistrate",
         "prosecutor",
         "Lord Advocate"
       ],
       "Gvt: Emergency Services: Police": [
         "[Cc]onstable",
         "[Cc]hief(?: officer | )of [Pp]olice",
         "police force"
       ],
       "Gvt: Emergency Services": "[Ee]mergency [Ss]ervices?"
     ] ++
       authority() ++
       secretary_of_state() ++
       ministries() ++
       agencies() ++
       devolved_administrations() ++
       forces())
    |> Enum.sort(:desc)
    |> process_library()
  end

  @doc """
  Returns governed actor patterns (businesses, individuals, specialists, etc.).
  """
  @spec governed() :: list({String.t(), String.t()})
  def governed do
    (business() ++
       person() ++
       public() ++
       specialist() ++
       supply_chain() ++
       servicer() ++
       maritime() ++
       environmentalist() ++
       he())
    |> process_library()
  end

  @doc """
  Returns terms to exclude from actor matching (false positives).
  """
  @spec blacklist() :: list(String.t())
  def blacklist do
    [
      "local authority collected municipal waste",
      "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
      "[Rr]epresentatives? of"
    ]
  end

  # ============================================================================
  # Government Actor Categories
  # ============================================================================

  defp authority do
    [
      "Gvt: Authority: Enforcement":
        "(?:[Rr]egulati?on?r?y?|[Ee]nforce?(?:ment|ing)) [Aa]uthority?i?e?s?",
      "Gvt: Authority: Local": [
        "[Ll]ocal [Aa]uthority?i?e?s?",
        "council of a county",
        "(?:county|district)(?: borough | )council",
        "London Borough Council",
        "council constituted"
      ],
      "Gvt: Authority: Energy": [
        "Northern Ireland Authority for Energy Regulation",
        "network emergency co-ordinator",
        "Phoenix Natural Gas Limited",
        "British Gas p\\.l\\.c\\."
      ],
      "Gvt: Authority: Harbour": ["[Hh]arbour [Aa]uthority?i?e?s?", "harbour master"],
      "Gvt: Authority: Licensing": "[Ll]icen[cs]ing [Aa]uthority?i?e?s?",
      "Gvt: Authority: Market": "(?:market surveillance|weights and measures) authority?i?e?s?",
      "Gvt: Authority: Public": "[Pp]ublic [Aa]uthority?i?e?s?",
      "Gvt: Authority: Traffic": "[Tt]raffic [Aa]uthority?i?e?s?",
      "Gvt: Authority: Waste":
        "(?:[Ww]aste collection|[Ww]aste disposal|[Dd]isposal) [Aa]uthority?i?e?s?",
      "Gvt: Authority": [
        "(?:[Tt]he|[Aa]n|appropriate|allocating|[Cc]ompetent|[Dd]esignated) authority?i?e?s?",
        "[Rr]egulators?",
        "[Mm]onitoring [Aa]uthority?i?e?s?",
        "officer authorised by the relevant authority",
        "that authority"
      ],
      "Gvt: Official": "Official"
    ]
  end

  defp devolved_administrations do
    [
      "Gvt: Devolved Admin: National Assembly for Wales": [
        "National Assembly for Wales",
        "Senedd",
        "Welsh Parliament"
      ],
      "Gvt: Devolved Admin: Scottish Parliament": "Scottish Parliament",
      "Gvt: Devolved Admin: Northern Ireland Assembly": "Northern Ireland Assembly",
      "Gvt: Devolved Admin:": "Assembly"
    ]
  end

  defp agencies do
    [
      "Gvt: Agency: Environment Agency": "Environment Agency",
      "Gvt: Agency: Health and Safety Executive for Northern Ireland": [
        "Health and Safety Executive for Northern Ireland",
        "HSENI"
      ],
      "Gvt: Agency: Health and Safety Executive": [
        "Health and Safety Executive",
        "[Tt]he Executive"
      ],
      "Gvt: Agency: Natural Resources Body for Wales": "Natural Resources Body for Wales",
      "Gvt: Agency: Office for Environmental Protection": [
        "Office for Environmental Protection",
        "OEP"
      ],
      "Gvt: Agency: Office for Nuclear Regulation": ["Office for Nuclear Regulations?", "ONR"],
      "Gvt: Agency: Office of Rail and Road": "Office of Rail and Road?",
      "Gvt: Agency: Scottish Environment Protection Agency": [
        "Scottish Environment Protection Agency",
        "SEPA"
      ],
      "Gvt: Agency: OFCOM": ["Office of Communications?", "OFCOM"],
      "Gvt: Agency:": "[Aa]gency"
    ]
  end

  defp secretary_of_state do
    [
      "Gvt: Minister: Secretary of State for Defence": "Secretary of State for Defence",
      "Gvt: Minister: Secretary of State for Transport": "Secretary of State for Transport",
      "Gvt: Minister: Attorney General": "Attorney General",
      "Gvt: Minister": [
        "Secretary of State",
        "[Mm]inisters?"
      ]
    ]
  end

  defp ministries do
    [
      "Gvt: Ministry: Ministry of Defence": "Ministry of Defence",
      "Gvt: Ministry: Department of the Environment": "Department of the Environment",
      "Gvt: Ministry: Department of Enterprise, Trade and Investment":
        "Department of Enterprise, Trade and Investment",
      "Gvt: Ministry: Treasury": "[Tt]reasury",
      "Gvt: Ministry: HMRC": [
        "customs officer",
        "Her Majesty['']s Commissioners for Revenue and Customs",
        "Her Majesty's Revenue and Customs"
      ],
      "Gvt: Ministry:": ["[Mm]inistry", "[Tt]he Department"]
    ]
  end

  defp forces do
    [
      "HM Forces: Navy": "(?:His|Her) Majesty['']s Navy",
      "HM Forces": ["(?:His|Her) Majesty['']s forces", "armed forces"]
    ]
  end

  # ============================================================================
  # Governed Actor Categories
  # ============================================================================

  defp business do
    [
      "Org: Investor": "[Ii]nvestors?",
      "Org: Owner": [
        "[Oo]wners?",
        "mine owner",
        "owner of a non-production installation",
        "installation owner"
      ],
      "Org: Landlord": "[Ll]andlord",
      "Org: Lessee": "[Ll]essee",
      "Org: Occupier": ["[Oo]ccupiers?", "[Pp]erson who is in occupation"],
      "Org: Employer": "[Ee]mployers?",
      Operator: [
        "[Oo]perators?",
        "(?:berth|mine|well|economic|meter)[[:blank:]-]operator",
        "operator of a production installation"
      ],
      "Org: Company": [
        "[Cc]ompany?i?e?s?",
        "[Bb]usinesse?s?",
        "[Ee]nterprises?",
        "[Bb]ody?i?e?s? corporate"
      ],
      "Org: Partnership": [
        "[Pp]artnerships?",
        "[Uu]nincorporated body?i?e?s?"
      ],
      Organisation: ["[Tt]hird party", "[Oo]rganisations?"]
    ]
  end

  defp person do
    [
      "Ind: Employee": "[Ee]mployees?",
      "Ind: Worker": ["[Ww]orkers?", "[Ww]orkmen", "(?:members of the )?[Ww]orkforce"],
      "Ind: Self-employed Worker": "[Ss]elf-employed (?:[Pp]ersons?|diver)",
      "Ind: Responsible Person": "[Rr]esponsible [Pp]ersons?",
      "Ind: Competent Person": ["[Cc]ompetent [Pp]ersons?", "person who is competent"],
      "Ind: Authorised Person": [
        "[Aa]uthorised [Pp]erson",
        "[Aa]uthorised [Bb]ody",
        "[Aa]uthorised Representative",
        "[Pp]erson (?:so|duly) authorised"
      ],
      "Ind: Suitable Person": "suitable person",
      "Ind: Supervisor": ["[Ss]upervisor", "[Pp]erson in control", "individual in charge"],
      "Ind: Manager": ["managers?", "mine manager", "manager of a mine", "installation manager"],
      "Ind: Appointed Person": ["[Aa]ppointed [Pp]ersons?", "[Aa]ppointed body"],
      "Ind: Relevant Person": "[Rr]elevant [Pp]erson",
      Operator: "[Pp]erson who operates the plant",
      "Ind: Young Person": ["young person", "childr?e?n?"],
      "Ind: Person": ["[Pp]ersons?", "[Ii]ndividual"],
      "Ind: Duty Holder": ["[Dd]uty [Hh]olders?", "[Dd]utyholder"],
      "Ind: Licence Holder": "[Ll]icen[sc]e [Hh]olders?",
      "Ind: Holder": "[Hh]olders?",
      "Ind: User": "[Uu]sers?",
      "Ind: Applicant": ["[Rr]elevant applicant", "[Aa]pplicant"],
      "Ind: Licensee": ["[Ll]icensee", "offshore licensee"],
      "Ind: Diver": "[Dd]iver",
      "Ind: Chair": "[Cc]hairman"
    ]
  end

  defp public do
    [
      Public: ["[Pp]ublic", "[Ee]veryone", "[Cc]itizens?"],
      "Public: Parents": "[Pp]arents?"
    ]
  end

  defp specialist do
    [
      "Spc: OH Advisor": [
        "[Nn]urse",
        "[Pp]hysician",
        "(?:[Rr]elevant)?[ ]?[Dd]octor",
        "[Mm]edical examiner",
        "[Ee]mployment medical advis[oe]r"
      ],
      "Spc: Employees' Representative": [
        "[Ee]mployees' representative",
        "[Ss]afety representatives?",
        "[Tt]rade [Uu]nions? representatives?"
      ],
      "Spc: Representative": "(?:[Aa]uthorised)? [Rr]epresentatives? (?!sample)",
      "Spc: Trade Union": "[Tt]rade [Uu]nions?",
      "Spc: Assessor": "[Aa]ssessors?",
      "Spc: Surveyor": "[Ss]urveyor",
      "Spc: Inspector": [
        "[Uu]ser inspectorate",
        "[Ii]nspectors?",
        "[Vv]erifier",
        "[Ww]ell examiner"
      ],
      "Spc: Body":
        "(?:[Aa]ppropriate|[Aa]pproved|[Ss]ampling|(?:UK )?[Nn]otified|[Cc]onformity assessment) (?:] )?[Bb]ody",
      "Spc: Advisor": "[Aa]dvis[oe]r",
      "Spc: Engineer": "[Ee]ngineer",
      "Spc: Technician": ["[Tt]echnician", "geotechnical specialist"]
    ]
  end

  defp supply_chain do
    [
      "SC: Agent": "(?<![Bb]iological )[Aa]gents?",
      "SC: Keeper": "person who.*?keeps*?",
      "SC: Manufacturer": "[Mm]anufacturer",
      "SC: Producer": ["[Pp]roducer", "person who.*?produces*?"],
      "SC: C: Principal Designer": "[Pp]rincipal [Dd]esigner",
      "SC: C: Designer": ["[Dd]esigner", "designs for another"],
      "SC: C: Constructor": "[Cc]onstructor",
      "SC: C: Principal Contractor": "[Pp]rincipal [Cc]ontractor",
      "SC: C: Contractor": [
        "[Cc]ontractors?",
        "[Dd]iving contractor",
        "[Cc]ompressed air contractor"
      ],
      "SC: Marketer": ["[Aa]dvertiser", "[Mm]arketer"],
      "SC: Supplier": ["[Ss]upplier", "[Pp]erson who supplies"],
      "SC: Generator": "[Gg]enerators?",
      "SC: Distributor": "[Dd]istributors?",
      "SC: Seller": "[Ss]eller",
      "SC: Dealer": "(?:[Ss]crap metal )?[Dd]ealer",
      "SC: Retailer": "[Rr]etailer",
      "SC: Domestic Client": "[Dd]omestic [Cc]lient",
      "SC: Client": "[Cc]lients?",
      "SC: Customer": "[Cc]ustomer",
      "SC: Consumer": "[Cc]onsumer",
      "SC: Storer": "[Ss]torer",
      "SC: T&L: Consignor": "[Cc]onsignor",
      "SC: T&L: Handler": ["[Hh]andler", "person who.*?(?:loads|unloads)"],
      "SC: T&L: Consignee": "[Cc]onsignee",
      "SC: T&L: Carrier": [
        "[Tt]ransporter",
        "person who.*?(?:carries|transports)",
        "[Cc]arriers?"
      ],
      "SC: T&L: Driver": "[Dd]river",
      "SC: Importer": ["[Ii]mporter", "person who.*?imports*?"],
      "SC: Exporter": ["[Ee]xporter", "person who.*?exports*?"]
    ]
  end

  defp servicer do
    [
      "Svc: Installer": "[Ii]nstaller",
      "Svc: Maintainer": "[Mm]aintainer",
      "Svc: Repairer": ["[Rr]epairer", "person who modifies or repairs", "person who repairs"]
    ]
  end

  defp maritime do
    [
      "Maritime: crew": "crew of a ship",
      "Maritime: master": ["master.*?of a ship", "master.*?of (?:the|an?y?) vessel"]
    ]
  end

  defp environmentalist do
    [
      "Env: Reuser": "[Rr]euser",
      "Env: Treater": " person who.*?treats*?",
      "Env: Recycler": "[Rr]ecycler",
      "Env: Disposer": "[Dd]isposer",
      "Env: Polluter": "[Pp]olluter"
    ]
  end

  defp he do
    [": He": "[Hh]e"]
  end

  # ============================================================================
  # Library Processing
  # ============================================================================

  @doc """
  Wraps regex patterns with word boundary markers.

  Single patterns become: `[[:blank:][:punct:]]pattern[[:blank:][:punct:]]`
  List patterns become: `(?:pattern1|pattern2|...)` with boundaries
  """
  @spec process_library(list()) :: list({atom() | String.t(), String.t()})
  def process_library(library) do
    library
    |> Enum.reduce([], fn
      {k, v}, acc when is_binary(v) ->
        [{k, "[[:blank:][:punct:]]#{v}[[:blank:][:punct:]]"} | acc]

      {k, v}, acc when is_list(v) ->
        pattern =
          v
          |> Enum.map(&"[[:blank:][:punct:]]#{&1}[[:blank:][:punct:]]")
          |> Enum.join("|")

        [{k, "(?:#{pattern})"} | acc]
    end)
    |> Enum.reverse()
  end
end
