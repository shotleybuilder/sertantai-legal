defmodule SertantaiLegal.Scraper.LawTerritoryTest do
  @moduledoc """
  Where a law's changes reach (V1-04): one rule for the register's records
  (AR-09, V1-03) and the parse's territory claims.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawTerritory

  describe "territory/3" do
    test "a devolved law's type sets it, whatever its register extent (Welsh law extends to E+W)" do
      assert LawTerritory.territory("UK_wsi_2010_1", "E+W") == "W"
      assert LawTerritory.territory("UK_asc_2016_3", "E+W") == "W"
      assert LawTerritory.territory("UK_ssi_2006_181", nil) == "S"
      assert LawTerritory.territory("UK_asp_2018_8", "S") == "S"
      assert LawTerritory.territory("UK_nisr_2009_248", "NI") == "NI"
      assert LawTerritory.territory("UK_nisi_1981_154", "NI") == "NI"
    end

    test "a UK-level law's extent, only when narrower than the UK" do
      assert LawTerritory.territory("UK_uksi_2023_911", "E") == "E"
      assert LawTerritory.territory("UK_ukpga_1974_37", "GB") == "E+W+S"
      assert LawTerritory.territory("UK_ukpga_2000_27", "UK") == nil
      assert LawTerritory.territory("UK_ukpga_2000_27", "E+W+S+NI") == nil
      assert LawTerritory.territory("UK_uksi_2001_1", nil) == nil
      assert LawTerritory.territory("UK_uksi_2001_1", "") == nil
    end

    test "none when the amended law is devolved to the same territory" do
      assert LawTerritory.territory("UK_wsi_2020_1", "E+W", "UK_anaw_2017_2") == nil
      assert LawTerritory.territory("UK_ssi_2006_3", "S", "UK_ukpga_1990_43") == "S"
    end
  end

  describe "extent/2" do
    test "the law's own title place first, else its register extent (V1-03)" do
      assert LawTerritory.extent(
               "Building Regulations etc. (Amendment) (England) Regulations 2023",
               "E+W"
             ) == "E"

      assert LawTerritory.extent("Environment Act", "E+W+S+NI") == "E+W+S+NI"
      assert LawTerritory.extent(nil, "E+W") == "E+W"
      assert LawTerritory.extent(nil, nil) == nil
    end
  end

  test "title_place/1: the law's own place, never one in a law it cites" do
    assert LawTerritory.title_place(
             "Water Supply (Water Quality) (Wales) (Amendment) Regulations"
           ) ==
             "W"

    assert LawTerritory.title_place("Mines Act (Northern Ireland)") == "NI"

    assert LawTerritory.title_place(
             "Forestry and Land Management (Scotland) Act 2018 (Consequential Provisions and Modifications) Order"
           ) == nil

    assert LawTerritory.title_place(nil) == nil
  end
end
