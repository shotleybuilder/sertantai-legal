defmodule SertantaiLegal.Scraper.ChangeCollectorTitlePlaceTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector

  test "V1-03: title_place/1 — the law's own place, never one in a law it cites" do
    assert ChangeCollector.title_place(
             "Building Regulations etc. (Amendment) (England) Regulations"
           ) == "E"

    assert ChangeCollector.title_place(
             "Building Regulations etc. (Amendment) (England) Regulations 2023"
           ) == "E"

    assert ChangeCollector.title_place(
             "Water Supply (Water Quality) (Wales) (Amendment) Regulations"
           ) == "W"

    assert ChangeCollector.title_place("Housing (Scotland) Act") == "S"

    assert ChangeCollector.title_place("Environmental Protection (England and Wales) Order") ==
             "E+W"

    assert ChangeCollector.title_place(
             "Forestry and Land Management (Scotland) Act 2018 (Consequential Provisions and Modifications) Order"
           ) == nil

    assert ChangeCollector.title_place("Mines Act (Northern Ireland)") == "NI"

    assert ChangeCollector.title_place(
             "Pollution Prevention and Control Regulations (Northern Ireland)"
           ) == "NI"

    assert ChangeCollector.title_place("Building Standards (Scotland) Amendment Regulations") ==
             "S"

    assert ChangeCollector.title_place(
             "Town and Country Planning (Scotland) Act 1972 (repealed 27.5.1997)"
           ) == "S"

    assert ChangeCollector.title_place(
             "Local Government etc. (Scotland) Act 1994 (Commencement No.1) Order"
           ) == nil

    assert ChangeCollector.title_place("Environment Act") == nil
    assert ChangeCollector.title_place(nil) == nil
  end
end
