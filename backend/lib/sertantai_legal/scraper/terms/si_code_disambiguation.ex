defmodule SertantaiLegal.Scraper.Terms.SICodeDisambiguation do
  @moduledoc """
  Disambiguates SI codes that map to multiple possible families.

  Some SI codes (e.g. ELECTRICITY, ROAD TRAFFIC, MERCHANT SHIPPING) span
  both safety and environment domains. The SI code narrows the domain;
  title keywords pick the specific family.

  Each disambiguation rule has:
  - A list of {keywords, family} pairs checked in order
  - A default family when no keywords match
  """

  @type rule :: %{
          matches: [{[String.t()], String.t()}],
          default: String.t()
        }

  @ambiguous_codes %{
    "ELECTRICITY" => %{
      matches: [
        {[
           "renewable",
           "obligation",
           "supplier",
           "warm home",
           "network connection",
           "energy company",
           "payment",
           "levy",
           "support",
           "feed-in",
           "capacity",
           "market",
           "trading",
           "settlement"
         ], "💚 ENERGY"},
        {["safety", "installation", "wiring", "equipment"], "💙 OH&S: Gas & Electrical Safety"}
      ],
      default: "💚 ENERGY"
    },
    "GAS" => %{
      matches: [
        {["safety", "installation", "fitting", "appliance", "meter"],
         "💙 OH&S: Gas & Electrical Safety"},
        {["levy", "trading", "energy company", "supplier", "warm home"], "💚 ENERGY"}
      ],
      default: "💚 ENERGY"
    },
    "MERCHANT SHIPPING" => %{
      matches: [
        {[
           "pollution",
           "ballast",
           "emission",
           "carbon dioxide",
           "co2",
           "anti-fouling",
           "oil pollution"
         ], "💚 POLLUTION"},
        {[
           "safety",
           "ism",
           "manning",
           "labour",
           "epirb",
           "registration",
           "radiocommunication",
           "watercraft",
           "navigation",
           "collision",
           "load line",
           "life-saving",
           "fire protection"
         ], "💙 TRANSPORT: Maritime Safety"}
      ],
      default: "💙 TRANSPORT: Maritime Safety"
    },
    "ROAD TRAFFIC" => %{
      matches: [
        {["emission", "pollution", "vehicle standard", "exhaust", "fuel"],
         "💚 TRANSPORT: Roads & Vehicles"},
        {[
           "safety",
           "licence",
           "driving",
           "speed",
           "permit",
           "pedestrian",
           "seat belt",
           "construction and use",
           "motor vehicle"
         ], "💙 TRANSPORT: Road Safety"}
      ],
      default: "💙 TRANSPORT: Road Safety"
    },
    "ROAD TRAFFIC AND VEHICLES" => %{
      matches: [
        {["emission", "pollution", "vehicle standard", "exhaust", "fuel"],
         "💚 TRANSPORT: Roads & Vehicles"},
        {["safety", "licence", "driving", "speed", "permit"], "💙 TRANSPORT: Road Safety"}
      ],
      default: "💙 TRANSPORT: Road Safety"
    },
    "RAILWAYS" => %{
      matches: [
        {["emission", "noise", "pollution"], "💚 TRANSPORT: Railways & Rail Transport"},
        {["safety", "accident", "interoperability"], "💙 TRANSPORT: Rail Safety"}
      ],
      default: "💙 TRANSPORT: Rail Safety"
    },
    "DOCKS" => %{
      matches: [
        {["safety", "health", "labour"], "💙 OH&S: Occupational / Personal Safety"}
      ],
      default: "💙 OH&S: Occupational / Personal Safety"
    }
  }

  # Direct mappings for SI codes that were previously unmapped but are unambiguous
  @direct_mappings %{
    "FIRE AND RESCUE SERVICES" => "💙 FIRE",
    "FIRE SERVICES" => "💙 FIRE",
    "TERMS AND CONDITIONS OF EMPLOYMENT" => "💜 HR: Employment",
    "EMPLOYER'S LIABILITY" => "💜 HR: Insurance / Compensation / Wages / Benefits",
    "INDUSTRIAL TRAINING" => "💜 HR: Employment",
    "FACTORIES" => "💙 OH&S: Occupational / Personal Safety",
    "PENSIONS" => "💜 HR: Insurance / Compensation / Wages / Benefits",
    "STATUTORY SICK PAY" => "💜 HR: Insurance / Compensation / Wages / Benefits",
    "TRADE UNIONS" => "💜 HR: Employment",
    "HOUSING" => "💙 PUBLIC: Building Safety",
    "NUCLEAR ENERGY" => "💚 NUCLEAR & RADIOLOGICAL",
    "AQUACULTURE" => "💚 FISHERIES & FISHING",
    "DEER" => "💚 WILDLIFE & COUNTRYSIDE",
    "DESTRUCTIVE ANIMALS" => "💚 WILDLIFE & COUNTRYSIDE",
    "DOGS" => "💚 WILDLIFE & COUNTRYSIDE",
    "DRAINAGE" => "💚 WATER & WASTEWATER",
    "GAME" => "💚 WILDLIFE & COUNTRYSIDE",
    "LAND" => "💚 TOWN & COUNTRY PLANNING",
    "LAND REFORM" => "💚 TOWN & COUNTRY PLANNING",
    "LAND REGISTRATION" => "💚 TOWN & COUNTRY PLANNING",
    "LAND SEARCHES" => "💚 TOWN & COUNTRY PLANNING",
    "ROADS" => "💚 TRANSPORT: Roads & Vehicles",
    "ROADS AND BRIDGES" => "💚 TRANSPORT: Roads & Vehicles",
    "RURAL AFFAIRS" => "💚 AGRICULTURE",
    "RURAL DEVELOPMENT" => "💚 AGRICULTURE",
    "VETERINARY SURGEONS" => "💚 ANIMALS & ANIMAL HEALTH",
    "PREVENTION OF CRUELTY" => "💚 ANIMALS & ANIMAL HEALTH",
    "PREVENTION OF HARM" => "💚 ENVIRONMENTAL PROTECTION",
    "PORT HEALTH AUTHORITIES" => "💙 HEALTH: Public",
    "RISK ASSESSMENT" => "💚 ENVIRONMENTAL PROTECTION",
    "FUEL" => "💚 ENERGY",
    "CONTROL OF FUEL AND ELECTRICITY" => "💚 ENERGY",
    "TRANSPORT ENGLAND" => "💚 TRANSPORT",
    "WEIGHTS AND MEASURES" => "💙 PUBLIC: Consumer / Product Safety"
  }

  @doc """
  Returns true if the SI code needs title-based disambiguation.
  """
  @spec ambiguous?(String.t()) :: boolean()
  def ambiguous?(si_code), do: Map.has_key?(@ambiguous_codes, si_code)

  @doc """
  Returns a direct family mapping if one exists for this SI code.
  These are SI codes that were previously unmapped (falling back to
  catch-all OH&S or ENVIRONMENTAL PROTECTION) but have a clear family.
  """
  @spec direct_mapping(String.t()) :: String.t() | nil
  def direct_mapping(si_code), do: Map.get(@direct_mappings, si_code)

  @doc """
  Disambiguate an SI code using the law's title.

  Returns the family string, or nil if the SI code is not ambiguous.
  """
  @spec disambiguate(String.t(), String.t()) :: String.t() | nil
  def disambiguate(si_code, title) do
    case Map.get(@ambiguous_codes, si_code) do
      nil ->
        nil

      %{matches: matches, default: default} ->
        title_lower = String.downcase(title)

        Enum.reduce_while(matches, default, fn {keywords, family}, acc ->
          if Enum.any?(keywords, &String.contains?(title_lower, &1)) do
            {:halt, family}
          else
            {:cont, acc}
          end
        end)
    end
  end

  @doc """
  Resolve the family for an SI code, using title disambiguation if needed.

  Priority:
  1. Existing Models.ehs_si_code_family() mapping (most specific)
  2. Title-based disambiguation for ambiguous codes
  3. Direct mapping for previously unmapped codes
  4. nil (no mapping found)
  """
  @spec resolve(String.t(), String.t()) :: String.t() | nil
  def resolve(si_code, title) do
    case disambiguate(si_code, title) do
      nil -> direct_mapping(si_code)
      family -> family
    end
  end
end
