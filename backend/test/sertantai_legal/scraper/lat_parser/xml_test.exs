defmodule SertantaiLegal.Scraper.LatParser.XmlTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.Xml

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  test "element_name/1 and local_name/1" do
    assert Xml.element_name(el(~s(<P1 id="x"/>))) == "P1"
    assert Xml.local_name(:"xhtml:td") == "td"
    assert Xml.local_name("{http://www.w3.org/1999/xhtml}td") == "td"
    assert Xml.local_name("Text") == "Text"
  end

  test "blank_to_nil/1" do
    assert Xml.blank_to_nil("") == nil
    assert Xml.blank_to_nil("x") == "x"
  end

  test "xml_id/1, change_id/1" do
    assert Xml.xml_id(el(~s(<P1 id="section-1"/>))) == "section-1"
    assert Xml.xml_id(el(~s(<P1/>))) == nil
    assert Xml.change_id(el(~s(<Addition ChangeId="c1"/>))) == "c1"
    assert Xml.change_id(el(~s(<Addition/>))) == nil
  end

  test "element_extent/1 normalises RestrictExtent; prospective?/1 reads Status" do
    assert Xml.element_extent(el(~s(<P1 RestrictExtent="E+W"/>))) == "E+W"
    assert Xml.element_extent(el(~s(<P1/>))) == nil
    assert Xml.prospective?(el(~s(<P1group Status="Prospective"/>)))
    refute Xml.prospective?(el(~s(<P1group/>)))
  end

  test "root_extent/1 is the document's RestrictExtent" do
    assert Xml.root_extent(~s(<Legislation RestrictExtent="S"><Body/></Legislation>)) == "S"
    assert Xml.root_extent(~s(<Legislation><Body/></Legislation>)) == nil
  end

  test "element-name sets" do
    assert "P1" in Xml.row_elements()
    assert "P4" in Xml.provision_rows()
    refute "Part" in Xml.provision_rows()
    assert "BlockAmendment" in Xml.skip_elements()
    assert "AppendText" in Xml.quoted_elements()
    assert "Pnumber" in Xml.no_text_elements()
    assert "P1para" in Xml.container_elements()
  end
end
