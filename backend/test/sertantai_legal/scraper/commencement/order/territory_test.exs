defmodule SertantaiLegal.Scraper.Commencement.Order.TerritoryTest do
  @moduledoc "Where a commencement order brings provisions into force, as a territory code."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Territory

  test "of/1: the first place a line names" do
    assert Territory.of("section 61 (in relation to Wales)") == "W"
    assert Territory.of("shall come into force in England and Wales on 6th June 1988") == "E+W"
    assert Territory.of("section 3 of the Scotland Act 1998") == nil
  end

  test "of/1: a provision's bracketed heading names no place it comes in (WSI 2015/1786, Water Act 2014 s.41)" do
    assert Territory.of(
             "1 November 2015 is the appointed day for the coming into force of section 41 (disputes about the provision of public sewers: premises in Wales) of the Act"
           ) == nil
  end

  test "all/1 and only/1: every place outside bracketed headings; the one place texts name" do
    assert Territory.all("in England on 1st May, and in relation to Wales on 1st June") == [
             "E",
             "W"
           ]

    assert Territory.all("section 86 (water and sewerage undertakers in England: appointments)") ==
             []

    assert Territory.only(["", "shall come into force in England and Wales on 6th June 1988"]) ==
             "E+W"

    assert Territory.only(["in England on 1st May, and in relation to Wales on 1st June"]) == nil

    # one place named by both the article and the Schedule's reference
    assert Territory.only([
             "shall come into force in England and Wales on 6th June 1988",
             "the provisions specified in this Schedule come into force in England and Wales"
           ]) == "E+W"

    assert Territory.only(["shall come into force in England", "in relation to Wales"]) == nil
    assert Territory.only(["shall come into force on 6th June 1988"]) == nil
  end

  test "of_title/1: one territory, two, none" do
    assert Territory.of_title(
             "The Environment Act 1995 (Commencement No. 16) (England) Order 2000"
           ) ==
             "E"

    assert Territory.of_title(
             "The Fire and Rescue Services Act 2004 (Commencement) (England and Scotland) Order 2004"
           ) == "E+S"

    assert Territory.of_title("The Railways Act 1993 (Commencement No. 1) Order 1994") == nil
    assert Territory.of_title(nil) == nil
  end

  test "of_type/2: a devolved order's territory, but none for its own legislature's Act" do
    assert Territory.of_type("UK_wsi_2022_1", "UK_ukpga_2021_30") == "W"
    assert Territory.of_type("UK_wsi_2023_1149", "UK_asc_2023_2") == nil
    assert Territory.of_type("UK_ssi_2016_370", "UK_asp_2016_2") == nil
    assert Territory.of_type("UK_nisr_2020_58", "UK_ukpga_2020_7") == "NI"
    assert Territory.of_type("UK_uksi_2004_2304", "UK_ukpga_2004_21") == nil
  end
end
