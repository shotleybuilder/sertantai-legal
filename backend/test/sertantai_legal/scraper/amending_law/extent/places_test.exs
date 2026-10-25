defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PlacesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Places

  test "places named, as one territory code" do
    assert Places.places("England and Wales and Scotland") == "E+W+S"
    assert Places.places("the United Kingdom") == "E+W+S+NI"
    assert Places.places("Northern Ireland") == "NI"
  end

  test "the place list matches a list of places whole" do
    re = Regex.compile!("^(?:#{Places.place_list()})$", "iu")
    assert "England and Wales, Scotland and Northern Ireland" =~ re
    assert "Scotland or Northern Ireland" =~ re
  end
end
