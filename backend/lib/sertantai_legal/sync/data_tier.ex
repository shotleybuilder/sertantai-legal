defmodule SertantaiLegal.Sync.DataTier do
  @moduledoc """
  Controls which tables an org can sync.

  - lrt_only: UK LRT reference data only
  - lrt_lat: LRT + article-level text (LAT)
  - lrt_lat_amendments: LRT + LAT + amendment annotations
  """

  use Ash.Type.Enum,
    values: [
      :lrt_only,
      :lrt_lat,
      :lrt_lat_amendments
    ]
end
