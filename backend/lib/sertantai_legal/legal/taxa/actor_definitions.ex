defmodule SertantaiLegal.Legal.Taxa.ActorDefinitions do
  @moduledoc """
  Regex pattern definitions for identifying actors (duty holders) in legal text.

  Actors are categorized into two main groups:
  - **Government**: Crown, authorities, agencies, ministers, devolved administrations
  - **Governed**: Businesses, individuals, specialists, supply chain actors

  Each pattern is wrapped with word boundary markers `[[:blank:][:punct:]]` to ensure
  accurate matching without partial word matches.

  ## Performance

  All regex patterns are pre-compiled at module load time to avoid runtime compilation
  overhead. Use `government_compiled/0` and `governed_compiled/0` for pre-compiled regexes.

  ## Usage

      iex> ActorDefinitions.government_compiled()
      [{"Crown", ~r/.../, ...}]

      iex> ActorDefinitions.governed_compiled()
      [{"Org: Employer", ~r/.../, ...}]
  """

  # Pre-compile all patterns at module load time
  @government_patterns_raw [
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
                             "Gvt: Emergency Services": "[Ee]mergency [Ss]ervices?",
                             # Authority
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
                             "Gvt: Authority: Harbour": [
                               "[Hh]arbour [Aa]uthority?i?e?s?",
                               "harbour master"
                             ],
                             "Gvt: Authority: Licensing": "[Ll]icen[cs]ing [Aa]uthority?i?e?s?",
                             "Gvt: Authority: Market":
                               "(?:market surveillance|weights and measures) authority?i?e?s?",
                             "Gvt: Authority: Planning": "[Pp]lanning [Aa]uthority?i?e?s?",
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
                             "Gvt: Official": "Official",
                             # Secretary of State
                             "Gvt: Minister: Secretary of State for Defence":
                               "Secretary of State for Defence",
                             "Gvt: Minister: Secretary of State for Transport":
                               "Secretary of State for Transport",
                             "Gvt: Minister: Attorney General": "Attorney General",
                             "Gvt: Minister": [
                               "Secretary of State",
                               "[Mm]inisters?"
                             ],
                             # Ministries
                             "Gvt: Ministry: Ministry of Defence": "Ministry of Defence",
                             "Gvt: Ministry: Department of the Environment":
                               "Department of the Environment",
                             "Gvt: Ministry: Department of Enterprise, Trade and Investment":
                               "Department of Enterprise, Trade and Investment",
                             "Gvt: Ministry: Treasury": "[Tt]reasury",
                             "Gvt: Ministry: HMRC": [
                               "customs officer",
                               "Her Majesty['']s Commissioners for Revenue and Customs",
                               "Her Majesty's Revenue and Customs"
                             ],
                             "Gvt: Ministry:": ["[Mm]inistry", "[Tt]he Department"],
                             # Agencies
                             "Gvt: Agency: Environment Agency": "Environment Agency",
                             "Gvt: Agency: Health and Safety Executive for Northern Ireland": [
                               "Health and Safety Executive for Northern Ireland",
                               "HSENI"
                             ],
                             "Gvt: Agency: Health and Safety Executive": [
                               "Health and Safety Executive",
                               "[Tt]he Executive"
                             ],
                             "Gvt: Agency: Natural Resources Body for Wales":
                               "Natural Resources Body for Wales",
                             "Gvt: Agency: Office for Environmental Protection": [
                               "Office for Environmental Protection",
                               "OEP"
                             ],
                             "Gvt: Agency: Office for Nuclear Regulation": [
                               "Office for Nuclear Regulations?",
                               "ONR"
                             ],
                             "Gvt: Agency: Office of Rail and Road": "Office of Rail and Road?",
                             "Gvt: Agency: Scottish Environment Protection Agency": [
                               "Scottish Environment Protection Agency",
                               "SEPA"
                             ],
                             "Gvt: Agency: OFCOM": ["Office of Communications?", "OFCOM"],
                             "Gvt: Agency:": "[Aa]gency",
                             # Devolved Administrations
                             "Gvt: Devolved Admin: National Assembly for Wales": [
                               "National Assembly for Wales",
                               "Senedd",
                               "Welsh Parliament"
                             ],
                             "Gvt: Devolved Admin: Scottish Parliament": "Scottish Parliament",
                             "Gvt: Devolved Admin: Northern Ireland Assembly":
                               "Northern Ireland Assembly",
                             "Gvt: Devolved Admin:": "Assembly",
                             # Forces
                             "HM Forces: Navy": "(?:His|Her) Majesty['']s Navy",
                             "HM Forces": ["(?:His|Her) Majesty['']s forces", "armed forces"]
                           ]
                           |> Enum.sort(:desc)

  @government_patterns @government_patterns_raw
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

  # Note: compiled regexes are computed at runtime via government_compiled/0
  # because Regex structs contain NIF references that can't be stored in module attributes.

  @governed_patterns_raw [
    # Business
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
    Organisation: ["[Tt]hird party", "[Oo]rganisations?"],
    # Person
    "Ind: Employee": "[Ee]mployees?",
    "Ind: Worker": [
      "[Ww]orkers?",
      "[Ww]orkmen",
      "(?:members of the )?[Ww]orkforce"
    ],
    "Ind: Self-employed Worker": "[Ss]elf-employed (?:[Pp]ersons?|diver)",
    "Ind: Responsible Person": "[Rr]esponsible [Pp]ersons?",
    "Ind: Competent Person": [
      "[Cc]ompetent [Pp]ersons?",
      "person who is competent"
    ],
    "Ind: Authorised Person": [
      "[Aa]uthorised [Pp]erson",
      "[Aa]uthorised [Bb]ody",
      "[Aa]uthorised Representative",
      "[Pp]erson (?:so|duly) authorised"
    ],
    "Ind: Suitable Person": "suitable person",
    "Ind: Supervisor": [
      "[Ss]upervisor",
      "[Pp]erson in control",
      "individual in charge"
    ],
    "Ind: Manager": [
      "managers?",
      "mine manager",
      "manager of a mine",
      "installation manager"
    ],
    "Ind: Appointed Person": [
      "[Aa]ppointed [Pp]ersons?",
      "[Aa]ppointed body"
    ],
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
    "Ind: Chair": "[Cc]hairman",
    # Public
    Public: ["[Pp]ublic", "[Ee]veryone", "[Cc]itizens?"],
    "Public: Parents": "[Pp]arents?",
    # Specialist
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
    "Spc: Technician": ["[Tt]echnician", "geotechnical specialist"],
    # Supply Chain
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
    "SC: Exporter": ["[Ee]xporter", "person who.*?exports*?"],
    # Servicer
    "Svc: Installer": "[Ii]nstaller",
    "Svc: Maintainer": "[Mm]aintainer",
    "Svc: Repairer": [
      "[Rr]epairer",
      "person who modifies or repairs",
      "person who repairs"
    ],
    # Maritime
    "Maritime: crew": "crew of a ship",
    "Maritime: master": [
      "master.*?of a ship",
      "master.*?of (?:the|an?y?) vessel"
    ],
    # Environmentalist
    "Env: Reuser": "[Rr]euser",
    "Env: Treater": " person who.*?treats*?",
    "Env: Recycler": "[Rr]ecycler",
    "Env: Disposer": "[Dd]isposer",
    "Env: Polluter": "[Pp]olluter",
    # He
    ": He": "[Hh]e"
  ]

  @governed_patterns @governed_patterns_raw
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

  # Note: compiled regexes are computed at runtime via governed_compiled/0 and blacklist_compiled/0
  # because Regex structs contain NIF references that can't be stored in module attributes.

  @doc """
  Returns the complete dutyholder library combining government and governed actors.
  Returns string patterns (legacy interface).
  """
  @spec dutyholder_library() :: list({atom() | String.t(), String.t()})
  def dutyholder_library do
    government() ++ governed()
  end

  @doc """
  Returns government actor patterns (authorities, agencies, ministers, etc.).
  Returns string patterns (legacy interface).
  """
  @spec government() :: list({atom() | String.t(), String.t()})
  def government, do: @government_patterns

  @doc """
  Returns governed actor patterns (businesses, individuals, specialists, etc.).
  Returns string patterns (legacy interface).
  """
  @spec governed() :: list({atom() | String.t(), String.t()})
  def governed, do: @governed_patterns

  @doc """
  Returns pre-compiled government actor regexes.
  Compiled at runtime and cached via :persistent_term.
  """
  @spec government_compiled() :: list({atom() | String.t(), Regex.t()})
  def government_compiled do
    case :persistent_term.get({__MODULE__, :government_compiled}, nil) do
      nil ->
        compiled =
          Enum.map(@government_patterns, fn {actor, pattern} ->
            {actor, Regex.compile!(pattern, "m")}
          end)

        :persistent_term.put({__MODULE__, :government_compiled}, compiled)
        compiled

      cached ->
        cached
    end
  end

  @doc """
  Returns pre-compiled governed actor regexes.
  Compiled at runtime and cached via :persistent_term.
  """
  @spec governed_compiled() :: list({atom() | String.t(), Regex.t()})
  def governed_compiled do
    case :persistent_term.get({__MODULE__, :governed_compiled}, nil) do
      nil ->
        compiled =
          Enum.map(@governed_patterns, fn {actor, pattern} ->
            {actor, Regex.compile!(pattern, "m")}
          end)

        :persistent_term.put({__MODULE__, :governed_compiled}, compiled)
        compiled

      cached ->
        cached
    end
  end

  @doc """
  Returns terms to exclude from actor matching (false positives).
  Returns string patterns (legacy interface).
  """
  @spec blacklist() :: list(String.t())
  def blacklist do
    [
      "local authority collected municipal waste",
      "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
      "[Rr]epresentatives? of"
    ]
  end

  @doc """
  Returns pre-compiled blacklist regexes.
  Compiled at runtime and cached via :persistent_term.
  """
  @spec blacklist_compiled() :: list(Regex.t())
  def blacklist_compiled do
    case :persistent_term.get({__MODULE__, :blacklist_compiled}, nil) do
      nil ->
        compiled = blacklist() |> Enum.map(fn pattern -> Regex.compile!(pattern, "m") end)
        :persistent_term.put({__MODULE__, :blacklist_compiled}, compiled)
        compiled

      cached ->
        cached
    end
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
