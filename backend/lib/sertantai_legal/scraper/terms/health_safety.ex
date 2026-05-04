defmodule SertantaiLegal.Scraper.Terms.HealthSafety do
  @moduledoc """
  Health & Safety related search terms for filtering UK legislation.

  Ported from Legl.Countries.Uk.UkSearch.Terms.HealthSafety
  """

  @building_safety ~w[
    building\ safety
    building\ regulation
    building\ standard
  ]

  @dangerous_explosive_substances ~w[
    explosive
    dangerous
  ]

  @oh_s ~w[
    health\ and\ safety
    safety\ and\ security
    accident
    consultation\ of\ employee
    protection\ at\ work
    reach
  ]

  @fire_safety ~w[
    fire\
    explosive
  ]

  @food_safety ~w[
    food
    food\ safety
    contact\ with\ food
    hygiene
    food\ irradiation
  ]

  @gas_electric_safety ~w[
    gas\ safety
    electricity\ safety
  ]

  @hr_employment ~w[
    workers
    working\ time
    agency\ worker
    employment\ right
    employment\ tribunal
    employment\ relation
    maternity
    protection\ from\ redundancy
  ]

  @hr_pay ~w[
    mesothelioma
    pneumoconiosis
    wage
    industrial\ injuries
    unpaid\ work
  ]

  @hr_working_time ~w[
    working\ time
  ]

  @mine_quarry_safety ~w[
    mine
    quarrie
    coal\ industry
  ]

  @offshore_safety ~w[
    offshore\ installation
    offshore\ safety
  ]

  @patient_safety ~w[
    medical\ device
    national\ health\ service
    nhs
  ]

  @product_safety ~w[
    product\ safety
    cosmetic\ products
    toys
    consumer
  ]

  @public_safety ~w[
    firework
    firearm
    sex-based\ harassment
  ]

  @public_health ~w[
    public\ health
    smoking
    smoke_free
    health\ protection
    coronavirus
    care
    cqc
    nutritional\ requirements
  ]

  @air_safety ~w[
    aviation\ safety
    air\ navigation
    air\ traffic
    civil\ aviation
  ]

  @rail_safety ~w[
    railway
    rail\ vehicle
    train\ driv
  ]

  @ship_safety ~w[
    merchant\ shipping
  ]

  @road_safety ~w[
    road\ transport
    road\ safety
    road\ traffic
    road\ vehicle
    motor\ vehicle
    goods\ vehicle
    passenger
    driver
    pedestrian
    disabled\ persons'\ vehicles
    parking
  ]

  @drug_safety ~w[
    drug
    medicine
  ]

  @doc """
  Returns health & safety search terms as a keyword list.

  Keys are family names, values are lists of search terms.
  """
  @spec search_terms() :: keyword(list(String.t()))
  def search_terms do
    [
      "💙 OH&S: Occupational / Personal Safety": @oh_s,
      "💙 FIRE": @fire_safety,
      "💙 FOOD": @food_safety,
      "💙 PUBLIC: Consumer / Product Safety": @product_safety,
      "💙 TRANS: Road Safety": @road_safety,
      "💙 HEALTH: Public": @public_health,
      "💜 HR: Employment": @hr_employment,
      "💙 PUBLIC": @public_safety,
      "💙 PUBLIC: Building Safety": @building_safety,
      "💙 PUBLIC: Data": ["data protection", "online safety"],
      "💙 FIRE: Dangerous and Explosive Substances": @dangerous_explosive_substances,
      "💙 OH&S: Gas & Electrical Safety": @gas_electric_safety,
      "💙 HEALTH: Drug & Medicine Safety": @drug_safety,
      "💙 HEALTH: Patient Safety": @patient_safety,
      "💜 HR: Insurance / Compensation / Wages / Benefits": @hr_pay,
      "💙 TRANS: Rail Safety": @rail_safety,
      "💙 TRANS: Maritime Safety": @ship_safety,
      "💙 OH&S: Offshore Safety": @offshore_safety,
      "💜 HR: Working Time": @hr_working_time,
      "💙 TRANS: Air Safety": @air_safety,
      "💙 OH&S: Mines & Quarries": @mine_quarry_safety
    ]
  end
end
