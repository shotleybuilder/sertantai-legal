defmodule SertantaiLegal.Scraper.Terms.Environment do
  @moduledoc """
  Environment-related search terms for filtering UK legislation.

  Ported from Legl.Countries.Uk.UkSearch.Terms.Environment
  """

  @agriculture ~w[
    agricultur
    heather\ and\ grass
    organic
    feed
    feeding\ stuff
    arable
    pastoral
    animal\ feed
    potato
    pigs
    croft
    farmer
    farm\ and\ conservation
    hill\ farm
    farmland
    moor
    set-aside
    fertiliser
    milk
    carcase
    products\ of\ animal\ origin
    less\ favoured\ area\ support\ scheme
    rural\ support
    rural\ payments
  ]

  @air ~w[
    air\ quality
    sulphur
    smoke\ control
  ]

  @climate_change ~w[
    carbon\ accounting
    climate\ change
    energy\ conservation
    sustainable\ energy
    greenhouse\ gas
    ozone\ depleting
    ozone-depleting
  ]

  @energy ~w[
    oil
    gas
    electric
    wind\ farm
    solar\ farm
    solar\ park
    heat\ network
    heat\ incentive
    energy
    renewable
    non-fossil\ fuel
    hydrocarbon
    petroleum
    utilities
  ]

  @finance ~w[
    plastic\ packaging\ tax
  ]

  @general ~w[
    environment
    circular\ economy
  ]

  @gmos ~w[
    genetically\ modified\ organisms
  ]

  @marine ~w[
    marine\ pollution
    marine\ conservation
    marine\ protected\ area
    fish\ conservation
    deep\ sea\ mining
    eels
    edible\ crab
    coastal\ access
    river\ pollution
    river\ conservation
    sea\ fish
    aquatic\ animal
    shark\ fin
  ]

  @planning ~w[
    planning
    harbour\ revision\ order
  ]

  @pollution ~w[
    control\ of\ pollution
    oil\ pollution
    pollution\ prevention
    nitrate\ pollution
    prevention\ of\ pollution
    control\ of\ agricultural\ pollution
  ]

  @radiological ~w[
    nuclear
    radioactive
    atomic\ energy
  ]

  @tft ~w[
    farm\ woodland
  ]

  @waste ~w[
    waste\ management
    special\ waste
    hazardous\ waste
    waste\ incineration
    landfill
    list\ of\ waste
    shipment\ of\ waste
    waste\ electrical
    packaging\ waste
    controlled\ waste
    contaminated\ land
  ]

  @water ~w[
    water\ abstraction
    water\ pollution
    discharge\ consent
    water\ and\ sewerage
  ]

  @wildlife_countryside ~w[
    countryside
    country\ park
    national\ park
    countryside\ stewardship
    wildlife
    badger
    beaver
    reptile
    wild\ bird
    rabbit
    weed
    ragwort
    nature\ conservation
    nature\ reserve
    habitat
    species
    sites\ of\ special\ scientific\ interest
    hedgerows
    biodiversity
    rights\ of\ way
    byway
    historic\ site
    archeological\ service
    spring\ trap
    hunting
    felling\ of\ trees
  ]

  @doc """
  Returns environment search terms as a keyword list.

  Keys are family names, values are lists of search terms.
  """
  @spec search_terms() :: keyword(list(String.t()))
  def search_terms do
    [
      "💚 AGRICULTURE": @agriculture,
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
      "💚 GMOs": @gmos
    ]
  end
end
