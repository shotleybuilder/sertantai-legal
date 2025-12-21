defmodule SertantaiLegal.Scraper.ExtentTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Extent

  describe "contents_xml_path/3" do
    test "builds standard path" do
      assert Extent.contents_xml_path("uksi", "2024", "123") ==
               "/uksi/2024/123/contents/data.xml"
    end

    test "handles number with slashes" do
      assert Extent.contents_xml_path("uksi", "2024", "123/456") ==
               "/uksi/123/456/contents/data.xml"
    end
  end

  describe "parse_contents_xml/1" do
    test "extracts extent from ContentsItem elements" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Contents>
        <ContentsItem ContentRef="section-1" RestrictExtent="E+W+S+NI"/>
        <ContentsItem ContentRef="section-2" RestrictExtent="E+W"/>
        <ContentsItem ContentRef="section-3" RestrictExtent="S"/>
      </Contents>
      """

      result = Extent.parse_contents_xml(xml)

      assert length(result) == 3
      assert {"section-1", "E+W+S+NI"} in result
      assert {"section-2", "E+W"} in result
      assert {"section-3", "S"} in result
    end

    test "normalizes N.I. to NI" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Contents>
        <ContentsItem ContentRef="section-1" RestrictExtent="E+W+S+N.I."/>
      </Contents>
      """

      result = Extent.parse_contents_xml(xml)
      assert {"section-1", "E+W+S+NI"} in result
    end

    test "skips items without RestrictExtent" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Contents>
        <ContentsItem ContentRef="section-1" RestrictExtent="E+W"/>
        <ContentsItem ContentRef="section-2"/>
      </Contents>
      """

      result = Extent.parse_contents_xml(xml)
      assert length(result) == 1
    end

    test "handles empty XML" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Contents/>
      """

      assert Extent.parse_contents_xml(xml) == []
    end
  end

  describe "transform_extent/1" do
    test "handles empty data" do
      assert Extent.transform_extent([]) == {[], "", ""}
    end

    test "transforms single extent code" do
      data = [
        {"section-1", "E+W+S+NI"},
        {"section-2", "E+W+S+NI"}
      ]

      {geo_region, geo_pan_region, geo_extent} = Extent.transform_extent(data)

      assert geo_region == ["England", "Wales", "Scotland", "Northern Ireland"]
      assert geo_pan_region == "UK"
      assert geo_extent == "E+W+S+NI: All provisions"
    end

    test "transforms multiple extent codes" do
      data = [
        {"section-1", "E+W+S+NI"},
        {"section-2", "E+W"},
        {"section-3", "S"}
      ]

      {geo_region, geo_pan_region, geo_extent} = Extent.transform_extent(data)

      assert geo_region == ["England", "Wales", "Scotland", "Northern Ireland"]
      assert geo_pan_region == "UK"
      assert String.contains?(geo_extent, "E+W+S+NI")
      assert String.contains?(geo_extent, "E+W")
      assert String.contains?(geo_extent, "S")
    end

    test "cleans (E+W) format" do
      data = [{"section-1", "(E+W)"}]
      {geo_region, geo_pan_region, _geo_extent} = Extent.transform_extent(data)

      assert geo_region == ["England", "Wales"]
      assert geo_pan_region == "E+W"
    end

    test "cleans EW format" do
      data = [{"section-1", "EW"}]
      {geo_region, geo_pan_region, _geo_extent} = Extent.transform_extent(data)

      assert geo_region == ["England", "Wales"]
      assert geo_pan_region == "E+W"
    end

    test "cleans EWS format" do
      data = [{"section-1", "EWS"}]
      {geo_region, geo_pan_region, _geo_extent} = Extent.transform_extent(data)

      assert geo_region == ["England", "Wales", "Scotland"]
      assert geo_pan_region == "GB"
    end
  end

  describe "set_extent/1" do
    test "returns record unchanged if missing required fields" do
      record = %{Title_EN: "Some Act"}
      assert Extent.set_extent(record) == record
    end
  end

  describe "geo_pan_region mapping" do
    test "UK for all four nations" do
      data = [{"s1", "E+W+S+NI"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "UK"
    end

    test "GB for England, Wales, Scotland" do
      data = [{"s1", "E+W+S"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "GB"
    end

    test "E+W for England and Wales" do
      data = [{"s1", "E+W"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "E+W"
    end

    test "E for England only" do
      data = [{"s1", "E"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "E"
    end

    test "W for Wales only" do
      data = [{"s1", "W"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "W"
    end

    test "S for Scotland only" do
      data = [{"s1", "S"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "S"
    end

    test "NI for Northern Ireland only" do
      data = [{"s1", "NI"}]
      {_region, pan_region, _extent} = Extent.transform_extent(data)
      assert pan_region == "NI"
    end
  end

  describe "geo_region ordering" do
    test "orders regions correctly" do
      # Mixed order input
      data = [
        {"s1", "NI"},
        {"s2", "E"},
        {"s3", "S"},
        {"s4", "W"}
      ]

      {geo_region, _pan_region, _extent} = Extent.transform_extent(data)

      # Should be in standard order
      assert geo_region == ["England", "Wales", "Scotland", "Northern Ireland"]
    end
  end
end
