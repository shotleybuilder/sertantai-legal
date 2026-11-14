defmodule SertantaiLegal.Scraper.Commencement.HeldAmendersTest do
  @moduledoc """
  The amending laws whose own commencement clause is read for a family
  (`mix lat.commencement --read-amending --family F`): derived from the
  family's changes, never listed by hand — a commencement order is read as
  an order, a law with LAT rows by `--read`, a law not held not at all.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.HeldAmenders

  test "select/2: the amending laws held, less LAT laws and commencement orders; the rest named" do
    amenders = %{
      "UK_uksi_2018_667" => 12,
      "UK_uksi_1996_186" => 4,
      "UK_ukpga_1974_37" => 3,
      "UK_uksi_1993_208" => 2,
      "EU_dir_2000_60" => 1
    }

    picked =
      HeldAmenders.select(amenders, %{
        lat: MapSet.new(["UK_ukpga_1974_37"]),
        orders: MapSet.new(["UK_uksi_1996_186"]),
        held: MapSet.new(["UK_uksi_2018_667", "UK_uksi_1996_186", "UK_ukpga_1974_37"])
      })

    assert picked.read == [{"UK_uksi_2018_667", 12}]
    assert picked.orders == [{"UK_uksi_1996_186", 4}]
    assert picked.lat == [{"UK_ukpga_1974_37", 3}]
    assert picked.not_held == [{"UK_uksi_1993_208", 2}]
  end

  test "order_title?/1: a commencement or appointed-day order by its title" do
    assert HeldAmenders.order_title?("The Environment Act 1995 (Commencement No. 5) Order 1996")
    assert HeldAmenders.order_title?("Gas Act 1995 (Appointed Day and Commencement) Order 1996")
    refute HeldAmenders.order_title?("The Merchant Shipping (Fees) Regulations 2018")
    refute HeldAmenders.order_title?(nil)
  end
end
