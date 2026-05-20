defmodule SertantaiLegal.Countries.Au do
  @moduledoc """
  Australia country module.

  Provides AU-specific legal data: type codes, geographic extents (federal vs
  state/territory), family taxonomy, actor definitions, and source URL builders
  for each jurisdiction's legislation portal.

  ## Jurisdiction Structure
  9 jurisdictions: 1 Commonwealth (federal) + 6 states + 2 territories.

  ## Key Differences from UK
  - PCBU (Person Conducting a Business or Undertaking) replaces "employer" as primary duty holder
  - Model WHS Act adopted by 8/9 jurisdictions (Victoria has its own OHS Act)
  - Fair Work Act 2009 federalises most employment law (except WA state system)
  - Modern Awards (121 instruments) have no UK equivalent
  - Legislative instruments automatically sunset after 10 years
  """

  @behaviour SertantaiLegal.Countries.Country

  # ── Identity ──────────────────────────────────────────────────────

  @impl true
  def code, do: "au"

  @impl true
  def name, do: "Australia"

  @impl true
  def jurisdictions do
    [
      {"cth", "Commonwealth (Federal)"},
      {"nsw", "New South Wales"},
      {"vic", "Victoria"},
      {"qld", "Queensland"},
      {"wa", "Western Australia"},
      {"sa", "South Australia"},
      {"tas", "Tasmania"},
      {"act", "Australian Capital Territory"},
      {"nt", "Northern Territory"}
    ]
  end

  # ── Type Codes ────────────────────────────────────────────────────

  # Type taxonomy — jurisdiction-neutral. Jurisdiction is in the `jurisdiction` column.
  # Matches the federal register's flat taxonomy (Act vs LegislativeInstrument)
  # with finer distinctions derived from title text.
  @type_codes %{
    "act" => "Act of Parliament",
    "reg" => "Regulation",
    "rule" => "Rules",
    "li" => "Legislative Instrument (general subordinate)",
    "obj" => "Objective (subordinate instrument)",
    "cop" => "Code of Practice",
    "model_cop" => "Model Code of Practice (Safe Work Australia)",
    "standard" => "Australian/NZ Standard",
    "nepm" => "National Environment Protection Measure",
    "award" => "Modern Award (Fair Work Commission)",
    "nes" => "National Employment Standard"
  }

  @impl true
  def type_codes, do: @type_codes

  @impl true
  def type_code_name(code), do: Map.get(@type_codes, code)

  @impl true
  def type_class_from_title(title) do
    cond do
      Regex.match?(~r/Act(?:\s+\d{4})?(?:\s+\([A-Z]{2,3}\))?[ ]?$/, title) ->
        "Act"

      Regex.match?(~r/Regulations?(?:\s+\d{4})?(?:\s+\([A-Z]{2,3}\))?[ ]?$/, title) ->
        "Regulation"

      Regex.match?(~r/Rules?(?:\s+\d{4})?[ ]?$/, title) ->
        "Rules"

      Regex.match?(~r/Order(?:\s+\d{4})?[ ]?$/, title) ->
        "Order"

      Regex.match?(~r/Code of Practice/i, title) ->
        "Code of Practice"

      Regex.match?(~r/Award(?:\s+\d{4})?[ ]?$/, title) ->
        "Award"

      true ->
        nil
    end
  end

  # ── Geographic Extents ────────────────────────────────────────────

  @geo_extents [
    {"au", "Australia-wide (all jurisdictions)"},
    {"cth", "Commonwealth (Federal)"},
    {"nsw", "New South Wales"},
    {"vic", "Victoria"},
    {"qld", "Queensland"},
    {"wa", "Western Australia"},
    {"sa", "South Australia"},
    {"tas", "Tasmania"},
    {"act", "Australian Capital Territory"},
    {"nt", "Northern Territory"}
  ]

  @impl true
  def geo_extents, do: @geo_extents

  # ── Family Taxonomy ───────────────────────────────────────────────
  # Reuses UK families where applicable, adds AU-specific families.

  @family_keywords %{
    # Health & Safety (shared with UK, AU-specific keywords added)
    "💙 OH&S: Occupational / Personal Safety" => [
      "work health and safety",
      "occupational health",
      "workplace safety",
      "WHS"
    ],
    "💙 OH&S: Mines & Quarries" => ["mines safety", "mining"],
    "💙 FIRE" => ["fire"],
    "💙 FIRE: Dangerous and Explosive Substances" => [
      "dangerous goods",
      "explosive",
      "hazardous chemicals"
    ],
    "💙 FOOD" => ["food safety", "food standards"],
    "💙 HEALTH: Public" => ["public health"],
    "💙 OH&S: Gas & Electrical Safety" => ["electrical safety", "gas safety"],
    "💙 PUBLIC: Building Safety" => ["building", "construction safety"],
    "💙 PUBLIC: Consumer / Product Safety" => ["consumer", "product safety"],
    "💙 TRANSPORT: Air Safety" => ["aviation", "civil aviation", "aircraft"],
    "💙 TRANSPORT: Rail Safety" => ["rail safety"],
    "💙 TRANSPORT: Road Safety" => ["road transport", "motor vehicle", "road safety"],
    "💙 TRANSPORT: Maritime Safety" => ["maritime safety", "marine safety", "navigation"],
    # Environment (shared with UK, AU-specific keywords added)
    "💚 AGRICULTURE" => ["agriculture", "biosecurity", "animal feed"],
    "💚 AGRICULTURE: Pesticides" => ["pesticide", "agricultural chemicals"],
    "💚 AIR QUALITY" => ["air quality", "clean air", "emission"],
    "💚 ANIMALS & ANIMAL HEALTH" => ["animal health", "animal welfare"],
    "💚 CLIMATE CHANGE" => ["climate change", "greenhouse", "carbon"],
    "💚 ENERGY" => ["energy efficiency", "renewable energy"],
    "💚 ENVIRONMENTAL PROTECTION" => [
      "environment protection",
      "environmental impact",
      "environmental assessment"
    ],
    "💚 FISHERIES & FISHING" => ["fisheries", "fishing"],
    "💚 GMOs" => ["genetically modified", "gene technology"],
    "💚 MARINE & RIVERINE" => ["marine", "coastal", "great barrier reef"],
    "💚 NUCLEAR & RADIOLOGICAL" => ["nuclear", "radioactive", "radiation"],
    "💚 PLANNING & INFRASTRUCTURE" => ["planning", "infrastructure"],
    "💚 POLLUTION" => ["pollution", "contaminated"],
    "💚 WASTE" => ["waste", "landfill"],
    "💚 WATER & WASTEWATER" => ["water supply", "water management", "wastewater"],
    "💚 WILDLIFE & COUNTRYSIDE" => [
      "wildlife",
      "biodiversity",
      "conservation",
      "endangered species",
      "national parks"
    ],
    # HR (shared with UK + AU-specific)
    "💜 HR: Employment" => ["fair work", "employment", "industrial relations"],
    "💜 HR: Working Time" => ["working time", "working hours"],
    # AU-specific families
    "💜 HR: Modern Awards" => ["modern award", "fair work commission award"],
    "💜 HR: Superannuation" => ["superannuation", "super guarantee"],
    "💜 HR: Anti-Discrimination" => [
      "discrimination",
      "equal opportunity",
      "human rights",
      "racial discrimination",
      "sex discrimination",
      "disability discrimination",
      "age discrimination"
    ],
    "💜 HR: Workers Compensation" => ["workers compensation", "comcare", "safety rehabilitation"]
  }

  @impl true
  def family_keywords, do: @family_keywords

  @impl true
  def families do
    @family_keywords |> Map.keys() |> Enum.sort()
  end

  # ── Actor Definitions ─────────────────────────────────────────────
  # AU government structure and PCBU-based duty holder model.

  @government_actors [
    {"Crown", "Crown"},
    {"Gvt: Minister", "[Mm]inisters?"},
    {"Gvt: Authority: Regulator",
     "(?:[Rr]egulators?|[Ee]nforcement [Aa]uthority|[Ww]orkplace [Hh]ealth [Aa]nd [Ss]afety [Aa]uthority)"},
    {"Gvt: Agency: Safe Work Australia", "Safe Work Australia"},
    {"Gvt: Agency: Comcare", "Comcare"},
    {"Gvt: Agency: Fair Work Commission", "Fair Work Commission"},
    {"Gvt: Agency: Fair Work Ombudsman", "Fair Work Ombudsman"},
    {"Gvt: Agency: Australian Human Rights Commission",
     "(?:Australian )?Human Rights Commission"},
    {"Gvt: Agency: SafeWork NSW", "SafeWork NSW"},
    {"Gvt: Agency: WorkSafe Victoria", "WorkSafe Victoria"},
    {"Gvt: Agency: WHSQ", "Workplace Health (?:and|&) Safety Queensland"},
    {"Gvt: Agency: SafeWork SA", "SafeWork SA"},
    {"Gvt: Agency: WorkSafe WA", "WorkSafe WA"},
    {"Gvt: Agency: WorkSafe Tasmania", "WorkSafe Tasmania"},
    {"Gvt: Agency: WorkSafe ACT", "WorkSafe ACT"},
    {"Gvt: Agency: NT WorkSafe", "NT WorkSafe"},
    {"Gvt: Agency: Environment Protection Authority", "(?:Environment Protection Authority|EPA)"},
    {"Gvt: Agency: NOPSEMA",
     "(?:National Offshore Petroleum Safety and Environmental Management Authority|NOPSEMA)"},
    {"Gvt: Inspector", "[Ii]nspectors?"},
    {"Gvt: Judiciary", "(?:[Cc]ourt|[Tt]ribunal|[Mm]agistrate)"},
    {"Gvt: Authority: Local", "[Ll]ocal [Gg]overnment|[Cc]ouncil"},
    {"Gvt: Parliament: Commonwealth", "Commonwealth Parliament"},
    {"Gvt: Parliament: State", "(?:State|Territory) Parliament"}
  ]

  @governed_actors [
    # PCBU model (broader than UK employer)
    {"PCBU", "(?:PCBU|[Pp]erson [Cc]onducting a [Bb]usiness or [Uu]ndertaking)"},
    {"PCBU: Officer", "(?:[Oo]fficers?|[Dd]irectors?|[Cc]ompany [Oo]fficer|[Dd]ue [Dd]iligence)"},
    # Workers and representatives
    {"Ind: Worker", "(?:[Ww]orkers?|[Ww]orkforce)"},
    {"Ind: Employee", "[Ee]mployees?"},
    {"Ind: HSR", "(?:[Hh]ealth [Aa]nd [Ss]afety [Rr]epresentatives?|HSR)"},
    {"Ind: Self-employed", "[Ss]elf-employed"},
    # Business entities
    {"Org: Employer", "[Ee]mployers?"},
    {"Org: Company", "(?:[Cc]ompany|[Cc]orporation|[Bb]usiness)"},
    {"Org: Partnership", "[Pp]artnership"},
    {"Org: Principal Contractor", "[Pp]rincipal [Cc]ontractor"},
    {"Org: Contractor", "[Cc]ontractors?"},
    {"Org: Subcontractor", "[Ss]ubcontractors?"},
    {"Org: Labour Hire", "(?:[Ll]abour [Hh]ire|[Hh]ost [Ee]mployer)"},
    # Supply chain
    {"SC: Manufacturer", "[Mm]anufacturers?"},
    {"SC: Supplier", "[Ss]uppliers?"},
    {"SC: Importer", "[Ii]mporters?"},
    {"SC: Designer", "[Dd]esigners?"},
    {"SC: Installer", "[Ii]nstallers?"},
    # Specialists
    {"Spc: Inspector", "[Ii]nspectors?"},
    {"Spc: Assessor", "[Aa]ssessors?"},
    {"Spc: Auditor", "[Aa]uditors?"},
    # Public
    {"Public", "(?:[Pp]ublic|[Cc]ommunity)"},
    # Persons
    {"Ind: Person", "[Pp]ersons?"},
    {"Ind: Volunteer", "[Vv]olunteers?"},
    {"Ind: Visitor", "[Vv]isitors?"}
  ]

  @impl true
  def government_actors, do: @government_actors

  @impl true
  def governed_actors, do: @governed_actors

  # ── Source URL Builders ───────────────────────────────────────────
  # Each AU jurisdiction has its own legislation portal.

  @jurisdiction_urls %{
    "cth" => "https://www.legislation.gov.au",
    "nsw" => "https://legislation.nsw.gov.au",
    "vic" => "https://www.legislation.vic.gov.au",
    "qld" => "https://www.legislation.qld.gov.au",
    "wa" => "https://www.legislation.wa.gov.au",
    "sa" => "https://www.legislation.sa.gov.au",
    "tas" => "https://www.legislation.tas.gov.au",
    "act" => "https://www.legislation.act.gov.au",
    "nt" => "https://legislation.nt.gov.au"
  }

  @doc "Return the base legislation portal URL for a jurisdiction."
  def portal_url(jurisdiction), do: Map.get(@jurisdiction_urls, jurisdiction)

  @impl true
  def source_url(_type_code, _year, _number) do
    # AU legislation portals don't follow a simple type/year/number URL pattern
    # like legislation.gov.uk does. URLs are constructed per-jurisdiction and
    # often use title-based slugs. Source URLs will be populated during scraping.
    nil
  end
end
