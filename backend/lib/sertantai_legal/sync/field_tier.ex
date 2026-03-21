defmodule SertantaiLegal.Sync.FieldTier do
  @moduledoc """
  Controls which LRT columns an org can sync.

  - essential: name, title_en, family, year, number, type_desc, live, geo_extent, leg_gov_uk_url
  - standard: + function, holders, purpose, duty_type, fitness tags, domain, geo_region, making_classification
  - full: + popimar, si_code, amendment arrays, stats, all dates, role, md_description
  """

  use Ash.Type.Enum,
    values: [
      :essential,
      :standard,
      :full
    ]
end
