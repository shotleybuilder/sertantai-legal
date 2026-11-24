defmodule SertantaiLegal.Scraper.LawStart.Provisions.CountriesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Countries

  @row %{section_id: "UK_x:reg.1(2)", text: ""}

  test "a later day for a purpose: in partly from the start, fully from that day" do
    s =
      "in relation to noise arising from works, these Regulations shall come into force on 6th April 2008"

    assert [
             %{treatment: :provision_qualified, qualified_date: ~D[2008-02-23]},
             %{treatment: :provision_dated, date: ~D[2008-04-06]}
           ] = Countries.later_for(s, @row, nil, ~D[2008-02-23])
  end

  test "a place is no purpose" do
    s = "in relation to Wales, these Regulations shall come into force on 6th April 2008"
    assert Countries.later_for(s, @row, nil, ~D[2008-02-23]) == nil
  end

  test "no application by country, no groups" do
    assert Countries.by_application(
             "Regulation 2 comes into force on 1st May 2008",
             @row,
             [],
             nil,
             "UK_x:reg.1"
           ) ==
             nil
  end
end
