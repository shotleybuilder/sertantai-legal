defmodule SertantaiLegal.Scraper.Terms.Environment do
  @moduledoc """
  Environment-related search terms for filtering UK legislation.

  Ported from Legl.Countries.Uk.UkSearch.Terms.Environment

  NOTE: Terms use explicit string lists, NOT ~w[]. The ~w[] sigil splits
  backslash-escaped spaces into individual words, producing false matches
  from fragments like "and", "at", "of".
  """

  @agriculture [
    "agricultur",
    "heather and grass",
    "organic",
    "feed",
    "feeding stuff",
    "arable",
    "pastoral",
    "animal feed",
    "potato",
    "pigs",
    "croft",
    "farmer",
    "farm and conservation",
    "hill farm",
    "farmland",
    "moor",
    "set-aside",
    "fertiliser",
    "milk",
    "carcase",
    "products of animal origin",
    "less favoured area support scheme",
    "rural support",
    "rural payments"
  ]

  @pesticides [
    "pesticide",
    "pest"
  ]

  @air [
    "air quality",
    "sulphur",
    "smoke control"
  ]

  @climate_change [
    "carbon accounting",
    "climate change",
    "energy conservation",
    "sustainable energy",
    "greenhouse gas",
    "ozone depleting",
    "ozone-depleting"
  ]

  @energy [
    "oil",
    "gas",
    "electric",
    "wind farm",
    "solar farm",
    "solar park",
    "heat network",
    "heat incentive",
    "energy",
    "renewable",
    "non-fossil fuel",
    "hydrocarbon",
    "petroleum",
    "utilities"
  ]

  @finance [
    "plastic packaging tax"
  ]

  @general [
    "environment",
    "circular economy",
    "mercury",
    "sustainability"
  ]

  @gmos [
    "genetically modified organisms"
  ]

  @plant_health [
    "plant health",
    "plant varieties",
    "plant breeders",
    "plant protection",
    "seed",
    "phytosanitary"
  ]

  @marine [
    "marine pollution",
    "marine conservation",
    "marine protected area",
    "fish conservation",
    "deep sea mining",
    "eels",
    "edible crab",
    "coastal access",
    "river pollution",
    "river conservation",
    "sea fish",
    "aquatic animal",
    "shark fin"
  ]

  @planning [
    "planning",
    "harbour revision order"
  ]

  @pollution [
    "control of pollution",
    "oil pollution",
    "pollution prevention",
    "nitrate pollution",
    "prevention of pollution",
    "control of agricultural pollution"
  ]

  @radiological [
    "nuclear",
    "radioactive",
    "atomic energy",
    "ionising radiation"
  ]

  @tft [
    "farm woodland"
  ]

  @waste [
    "waste management",
    "special waste",
    "hazardous waste",
    "waste incineration",
    "landfill",
    "list of waste",
    "shipment of waste",
    "waste electrical",
    "packaging waste",
    "controlled waste",
    "contaminated land"
  ]

  @water [
    "water abstraction",
    "water pollution",
    "discharge consent",
    "water and sewerage"
  ]

  @wildlife_countryside [
    "countryside",
    "country park",
    "national park",
    "countryside stewardship",
    "wildlife",
    "badger",
    "beaver",
    "reptile",
    "wild bird",
    "rabbit",
    "weed",
    "ragwort",
    "nature conservation",
    "nature reserve",
    "habitat",
    "species",
    "sites of special scientific interest",
    "hedgerows",
    "biodiversity",
    "rights of way",
    "byway",
    "historic site",
    "archeological service",
    "spring trap",
    "hunting",
    "felling of trees"
  ]

  @doc """
  Returns environment search terms as a keyword list.

  Keys are family names, values are lists of search terms.
  """
  @spec search_terms() :: keyword(list(String.t()))
  def search_terms do
    [
      "💚 AGRICULTURE": @agriculture,
      "💚 AGRICULTURE: Pesticides": @pesticides,
      "💚 AIR QUALITY": @air,
      "💚 CLIMATE CHANGE": @climate_change,
      "💚 ENERGY": @energy,
      "💚 ENVIRONMENTAL PROTECTION": @general,
      "💚 FINANCE": @finance,
      "💚 MARINE & RIVERINE": @marine,
      "💚 PLANNING & INFRASTRUCTURE": @planning,
      "💚 POLLUTION": @pollution,
      "💚 NUCLEAR & RADIOLOGICAL": @radiological,
      "💚 TREES: Forestry & Timber": @tft,
      "💚 WASTE": @waste,
      "💚 WATER & WASTEWATER": @water,
      "💚 WILDLIFE & COUNTRYSIDE": @wildlife_countryside,
      "💚 GMOs": @gmos,
      "💚 PLANT HEALTH": @plant_health
    ]
  end
end
