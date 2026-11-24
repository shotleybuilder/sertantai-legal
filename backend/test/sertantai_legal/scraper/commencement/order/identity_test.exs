defmodule SertantaiLegal.Scraper.Commencement.Order.IdentityTest do
  @moduledoc "Which Act a commencement order names and commences (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Identity

  @act %{law: "UK_ukpga_2012_11", title: "Scotland Act", year: "2012"}

  test "named?/2: the Act's title and year, never inside another title" do
    assert Identity.named?("section 2 of the Scotland Act 2012", @act)
    refute Identity.named?("the Police and Fire Reform (Scotland) Act 2012", @act)
  end
end
