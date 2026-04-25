defmodule SertantaiLegal.Legal.FamilyRules do
  @moduledoc """
  Single source of truth for family classification rules.

  Maps title keywords to families for:
  - Title-based family confirmation (graph QA)
  - Future: parse-time family inference from title when SI code is absent

  See also `SertantaiLegal.Scraper.Models` for SI code → family mappings.
  Both modules should be consulted when classifying a law.
  """

  @title_keywords %{
    "💙 FIRE" => ["fire"],
    "💙 FIRE: Dangerous and Explosive Substances" => [
      "explosive",
      "petroleum",
      "dangerous substance"
    ],
    "💙 FOOD" => ["food safety", "food hygiene"],
    "💙 HEALTH: Coronavirus" => ["coronavirus", "covid"],
    "💙 HEALTH: Drug & Medicine Safety" => ["medicine", "pharmaceutical", "drug"],
    "💙 HEALTH: Patient Safety" => ["patient safety", "medical device"],
    "💙 HEALTH: Public" => ["public health"],
    "💙 OH&S: Gas & Electrical Safety" => ["gas safety", "electrical safety", "electricity"],
    "💙 OH&S: Mines & Quarries" => ["mines", "quarries"],
    "💙 OH&S: Occupational / Personal Safety" => ["health and safety", "workplace"],
    "💙 OH&S: Offshore Safety" => ["offshore"],
    "💙 PUBLIC" => ["public safety"],
    "💙 PUBLIC: Building Safety" => ["building"],
    "💙 PUBLIC: Consumer / Product Safety" => ["consumer", "product safety"],
    "💙 TRANSPORT: Air Safety" => ["aviation", "air navigation", "aircraft"],
    "💙 TRANSPORT: Rail Safety" => ["railway", "rail"],
    "💙 TRANSPORT: Road Safety" => ["road traffic", "motor vehicle", "road safety"],
    "💙 TRANSPORT: Maritime Safety" => ["merchant shipping", "maritime"],
    "💚 AGRICULTURE" => [
      "agriculture",
      "agricultural",
      "feeding stuffs",
      "animal feed",
      "animals and animal products",
      "products of animal origin"
    ],
    "💚 AGRICULTURE: Pesticides" => ["pesticide", "biocidal", "plant protection products"],
    "💚 AIR QUALITY" => ["air quality", "clean air", "emission"],
    "💚 ANIMALS & ANIMAL HEALTH" => ["animal health", "animal welfare", "welfare of animals"],
    "💚 BUILDINGS" => ["building regulation"],
    "💚 CLIMATE CHANGE" => ["climate change", "greenhouse gas", "carbon"],
    "💚 ENERGY" => ["energy efficiency", "renewable energy"],
    "💚 ENVIRONMENTAL PROTECTION" => [
      "environmental protection",
      "environment act",
      "environmental permitting",
      "environmental impact assessment",
      "environmental assessment"
    ],
    "💚 FISHERIES & FISHING" => ["fisheries", "fishing", "sea fish"],
    "💚 GMOs" => ["genetically modified"],
    "💚 MARINE & RIVERINE" => ["marine", "coastal"],
    "💚 NOISE" => ["noise"],
    "💚 NUCLEAR & RADIOLOGICAL" => ["nuclear", "radioactive", "radiological"],
    "💚 PLANNING & INFRASTRUCTURE" => ["planning", "infrastructure"],
    "💚 PLANT HEALTH" => ["plant health"],
    # Note: "environmental permitting" also implies family_ii = POLLUTION
    "💚 POLLUTION" => ["pollution", "contaminated land"],
    "💚 TOWN & COUNTRY PLANNING" => ["town and country planning", "planning framework"],
    "💚 WASTE" => [
      "waste",
      "landfill",
      "fly-tipping",
      "litter",
      "dog fouling",
      "removal, storage and disposal of vehicles",
      "single use carrier bag"
    ],
    "💚 WATER & WASTEWATER" => ["water supply", "water industry", "wastewater", "sewerage"],
    "💚 WILDLIFE & COUNTRYSIDE" => [
      "wildlife",
      "countryside",
      "conservation",
      "environmentally sensitive areas"
    ],
    "💜 HR: Employment" => ["employment"],
    "💜 HR: Working Time" => ["working time"]
  }

  @doc """
  Returns the full title keyword → family map.
  """
  @spec title_keywords() :: %{String.t() => [String.t()]}
  def title_keywords, do: @title_keywords

  @doc """
  Check if a law's title contains keywords confirming the assigned family.

  Returns true if the title contains any keyword mapped to the given family.
  """
  @spec title_confirms_family?(String.t() | nil, String.t() | nil) :: boolean()
  def title_confirms_family?(nil, _family), do: false
  def title_confirms_family?(_title, nil), do: false

  def title_confirms_family?(title, family) do
    keywords = Map.get(@title_keywords, family, [])
    lower_title = String.downcase(title)
    Enum.any?(keywords, fn kw -> String.contains?(lower_title, kw) end)
  end

  @doc """
  Infer a family from a law title by checking all keyword patterns.

  Returns `{family, keywords_matched}` or `nil` if no match.
  """
  @spec infer_from_title(String.t() | nil) :: {String.t(), [String.t()]} | nil
  def infer_from_title(nil), do: nil

  def infer_from_title(title) do
    lower_title = String.downcase(title)

    @title_keywords
    |> Enum.find_value(fn {family, keywords} ->
      matched = Enum.filter(keywords, fn kw -> String.contains?(lower_title, kw) end)
      if matched != [], do: {family, matched}
    end)
  end
end
