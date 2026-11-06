defmodule SertantaiLegal.Scraper.Amendment.ReadPassTest do
  @moduledoc """
  The read pass's staleness: an amending law is read again for a law that
  points to it but was not read for (one given LAT rows since).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.ReadPass

  test "a law pointing here that the index was not read for is new (1992 c.12 → the Ports Act 1991)" do
    index = %{"laws" => ["UK_ukpga_1970_36"]}

    assert ReadPass.laws_new?(index, ["UK_ukpga_1970_36", "UK_ukpga_1991_52"])
    refute ReadPass.laws_new?(index, ["UK_ukpga_1970_36"])
    refute ReadPass.laws_new?(index, [])
  end
end
