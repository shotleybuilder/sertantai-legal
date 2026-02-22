defmodule SertantaiLegal.Legal.Lat.SectionType do
  @moduledoc """
  Structural type enum for LAT rows.

  Normalised across jurisdictions — each country's scraper maps
  its local terminology to this set.
  """

  use Ash.Type.Enum,
    values: [
      :title,
      :part,
      :chapter,
      :heading,
      :section,
      :sub_section,
      :article,
      :sub_article,
      :paragraph,
      :sub_paragraph,
      :schedule,
      :commencement,
      :table,
      :note,
      :signed
    ]
end
