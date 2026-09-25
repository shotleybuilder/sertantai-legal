defmodule SertantaiLegal.Scraper.ExtentResolverTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ExtentResolver

  @uk ["England", "Wales", "Scotland", "Northern Ireland"]

  defp input(attrs) do
    Map.merge(
      %{
        restrict_extent: nil,
        document_status: nil,
        lat_extent_codes: [],
        contents_item_extents: [],
        extent_clauses: [],
        type_code: "uksi"
      },
      Map.new(attrs)
    )
  end

  describe "parse_regions/1" do
    test "legislation.gov.uk raw form" do
      assert ExtentResolver.parse_regions("E+W+S+N.I.") == @uk
    end

    test "normalised codes, dotted and named variants" do
      assert ExtentResolver.parse_regions("E+W+S+NI") == @uk
      assert ExtentResolver.parse_regions("E.W.") == ["England", "Wales"]
      assert ExtentResolver.parse_regions("N.I.") == ["Northern Ireland"]

      assert ExtentResolver.parse_regions("Scotland,Northern Ireland") == [
               "Scotland",
               "Northern Ireland"
             ]
    end

    test "unknown tokens are ignored" do
      assert ExtentResolver.parse_regions("E+W+S+NI+i") == @uk
    end

    test "empty input gives no regions" do
      assert ExtentResolver.parse_regions(nil) == []
      assert ExtentResolver.parse_regions("") == []
    end
  end

  describe "pan_region/1" do
    test "maps region sets to the stored codes" do
      assert ExtentResolver.pan_region(@uk) == "UK"
      assert ExtentResolver.pan_region(["England", "Wales", "Scotland"]) == "GB"
      assert ExtentResolver.pan_region(["Wales", "England"]) == "E+W"
      assert ExtentResolver.pan_region(["Scotland"]) == "S"
      assert ExtentResolver.pan_region(["Northern Ireland"]) == "NI"
      assert ExtentResolver.pan_region(["Wales"]) == "W"
      assert ExtentResolver.pan_region(["England", "Scotland"]) == "E+S"
    end

    test "other combinations are joined codes; none is nil" do
      assert ExtentResolver.pan_region(["Scotland", "Northern Ireland"]) == "S+NI"
      assert ExtentResolver.pan_region([]) == nil
    end
  end

  describe "extent_clause/1" do
    test "whole-instrument clauses" do
      assert ExtentResolver.extent_clause("These Regulations extend to England and Wales.") ==
               ["England", "Wales"]

      assert ExtentResolver.extent_clause("This Act extends to Scotland only.") == ["Scotland"]

      assert ExtentResolver.extent_clause("(3) These Regulations extend to Great Britain.") ==
               ["England", "Wales", "Scotland"]

      assert ExtentResolver.extent_clause(
               "This Order extends to the whole of the United Kingdom."
             ) ==
               @uk

      assert ExtentResolver.extent_clause(
               "These Regulations extend to England and Wales, Scotland and Northern Ireland."
             ) == @uk
    end

    test "an application statement after the extent is not extent" do
      assert ExtentResolver.extent_clause(
               "(2) These Regulations extend to England and Wales and apply in relation to England only."
             ) == ["England", "Wales"]

      assert ExtentResolver.extent_clause(
               "These Regulations extend to England and Wales but apply in England only."
             ) == ["England", "Wales"]
    end

    test "Crown dependencies are ignored" do
      assert ExtentResolver.extent_clause(
               "These Regulations extend to England and Wales and the Isle of Man."
             ) == ["England", "Wales"]
    end

    test "partial, negative, qualified and list clauses give nil" do
      assert ExtentResolver.extent_clause("Part 2 of this Act extends to Scotland only.") == nil
      assert ExtentResolver.extent_clause("This Act extends to Scotland—") == nil
      assert ExtentResolver.extent_clause("This Act does not extend to Northern Ireland.") == nil

      assert ExtentResolver.extent_clause(
               "This Act extends to the United Kingdom except Scotland."
             ) ==
               nil

      assert ExtentResolver.extent_clause(
               "This Act extends to Scotland only for the purposes of section 15."
             ) == nil
    end

    test "text without a clause gives nil" do
      assert ExtentResolver.extent_clause("The occupier shall ensure that the premises are safe.") ==
               nil

      assert ExtentResolver.extent_clause(nil) == nil
    end
  end

  describe "resolve/1 source priority" do
    test "law-level extent wins" do
      assert %{geo_extent: "E+W", geo_region: ["England", "Wales"], source: "law_level"} =
               ExtentResolver.resolve(
                 input(restrict_extent: "E+W", lat_extent_codes: ["E+W+S+NI"])
               )
    end

    test "law-level is ignored on an unrevised document" do
      assert %{geo_extent: "S", source: "lat_provisions"} =
               ExtentResolver.resolve(
                 input(
                   restrict_extent: "E+W+S+N.I.",
                   document_status: "final",
                   lat_extent_codes: ["S"]
                 )
               )
    end

    test "LAT provisions give the union of their extents" do
      assert %{geo_extent: "S+NI", source: "lat_provisions"} =
               ExtentResolver.resolve(input(lat_extent_codes: ["S", "NI", ""]))
    end

    test "contents items are used only for revised documents" do
      placeholder = input(contents_item_extents: ["E+W+S+N.I."], type_code: "ssi")
      assert %{geo_extent: "S", source: "type_code"} = ExtentResolver.resolve(placeholder)

      revised = input(contents_item_extents: ["E+W", "E+W"], document_status: "revised")
      assert %{geo_extent: "E+W", source: "contents_items"} = ExtentResolver.resolve(revised)
    end

    test "an extent clause beats the type-code floor" do
      assert %{geo_extent: "GB", source: "text_clause"} =
               ExtentResolver.resolve(
                 input(extent_clauses: [["England", "Wales", "Scotland"]], type_code: "wsi")
               )
    end

    test "type-code floors" do
      assert %{geo_extent: "S", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "ssi"))

      assert %{geo_extent: "S", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "asp"))

      assert %{geo_extent: "NI", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "nisr"))

      assert %{geo_extent: "NI", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "nia"))

      assert %{geo_extent: "E+W", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "wsi"))

      assert %{geo_extent: "E+W", source: "type_code"} =
               ExtentResolver.resolve(input(type_code: "asc"))
    end

    test "never defaults to UK: an unrevised uksi with only a placeholder is unknown" do
      assert %{geo_extent: nil, geo_region: [], source: nil} =
               ExtentResolver.resolve(
                 input(document_status: "final", contents_item_extents: ["E+W+S+N.I."])
               )
    end
  end

  describe "overwrite?/2" do
    test "any resolution, including unknown, replaces a legacy (unsourced) value" do
      assert ExtentResolver.overwrite?(nil, "type_code")
      assert ExtentResolver.overwrite?(nil, nil)
    end

    test "unknown never replaces a sourced value" do
      refute ExtentResolver.overwrite?("lat_provisions", nil)
    end

    test "an equal or better source replaces; a worse one doesn't" do
      assert ExtentResolver.overwrite?("lat_provisions", "law_level")
      assert ExtentResolver.overwrite?("type_code", "type_code")
      refute ExtentResolver.overwrite?("law_level", "type_code")
    end
  end

  describe "extent_attrs/2" do
    @resolved %{
      geo_extent: "S",
      geo_region: ["Scotland"],
      geo_extent_source: "type_code",
      title_en: "X"
    }

    test "a better or equal source writes the extent fields as a group" do
      assert ExtentResolver.extent_attrs(@resolved, nil) ==
               %{geo_extent: "S", geo_region: ["Scotland"], geo_extent_source: "type_code"}
    end

    test "a worse source writes nothing" do
      assert ExtentResolver.extent_attrs(@resolved, "law_level") == %{}
    end

    test "an unsourced extent writes nothing" do
      assert ExtentResolver.extent_attrs(%{geo_extent: "UK", geo_region: []}, nil) == %{}
    end
  end
end
