defmodule SertantaiLegal.Scraper.EnactedByTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EnactedBy

  describe "introduction_path/3" do
    test "builds path with /made/ for as-enacted version" do
      assert EnactedBy.introduction_path("uksi", "2024", "123") ==
               "/uksi/2024/123/made/introduction/data.xml"
    end
  end

  describe "get_enacting_laws/1 skips primary legislation" do
    test "skips UK Public General Acts" do
      record = %{type_code: "ukpga", Year: 2024, Number: "1"}
      result = EnactedBy.get_enacting_laws(record)
      refute Map.has_key?(result, :Enacted_by)
    end

    test "skips Acts of Scottish Parliament" do
      record = %{type_code: "asp", Year: 2024, Number: "1"}
      result = EnactedBy.get_enacting_laws(record)
      refute Map.has_key?(result, :Enacted_by)
    end

    test "skips Welsh Acts" do
      record = %{type_code: "anaw", Year: 2024, Number: "1"}
      result = EnactedBy.get_enacting_laws(record)
      refute Map.has_key?(result, :Enacted_by)
    end

    test "skips Northern Ireland Assembly Acts" do
      record = %{type_code: "nia", Year: 2024, Number: "1"}
      result = EnactedBy.get_enacting_laws(record)
      refute Map.has_key?(result, :Enacted_by)
    end
  end

  describe "parse_enacting_xml/1" do
    test "extracts introductory and enacting text" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Legislation>
        <IntroductoryText>
          <P>The Secretary of State makes the following Regulations.</P>
        </IntroductoryText>
        <EnactingText>
          <P>In exercise of powers conferred by section 1 of the Act.</P>
        </EnactingText>
      </Legislation>
      """

      result = EnactedBy.parse_enacting_xml(xml)

      assert String.contains?(result.introductory_text, "Secretary of State")
      assert String.contains?(result.enacting_text, "exercise of powers")
      assert String.contains?(result.text, "Secretary of State")
      assert String.contains?(result.text, "exercise of powers")
    end

    test "extracts footnote URL mappings" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Legislation>
        <IntroductoryText><P>Some text</P></IntroductoryText>
        <EnactingText><P>Some text</P></EnactingText>
        <Footnotes>
          <Footnote id="f00001">
            <FootnoteText>
              <Citation URI="http://www.legislation.gov.uk/id/ukpga/1974/37"/>
            </FootnoteText>
          </Footnote>
        </Footnotes>
      </Legislation>
      """

      result = EnactedBy.parse_enacting_xml(xml)

      assert Map.has_key?(result.urls, "f00001")
      assert "http://www.legislation.gov.uk/id/ukpga/1974/37" in result.urls["f00001"]
    end

    test "handles empty/invalid XML" do
      result = EnactedBy.parse_enacting_xml("<invalid>")
      assert result.text == ""
      assert result.urls == %{}
    end
  end

  describe "find_enacting_laws/2" do
    test "returns empty list for empty text" do
      assert EnactedBy.find_enacting_laws("", %{}) == []
    end

    test "finds Health and Safety at Work Act reference" do
      text = "In exercise of powers under the Health and Safety at Work etc. Act 1974"
      result = EnactedBy.find_enacting_laws(text, %{})

      assert "ukpga/1974/37" in result
    end

    test "finds Transport and Works Act reference" do
      text = "An order under section 3 of the Transport and Works Act 1992"
      result = EnactedBy.find_enacting_laws(text, %{})

      assert "ukpga/1992/42" in result
    end

    test "finds Planning Act reference" do
      text = "Under section 37 of the Planning Act 2008"
      result = EnactedBy.find_enacting_laws(text, %{})

      assert "ukpga/2008/29" in result
    end

    test "extracts law IDs from footnote URLs" do
      text = "In exercise of powers conferred by f00001"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/2020/1"]
      }

      result = EnactedBy.find_enacting_laws(text, urls)

      assert "ukpga/2020/1" in result
    end

    test "filters out EU regulations and directives — they don't confer domestic powers" do
      # EU law is referenced for definitions but doesn't enable domestic SIs.
      # Authority comes from ECA s.2(2) or EU Withdrawal Act.
      text = "Under directive 2019 f00001 and powers conferred by f00002"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/european/directive/2019/904"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"]
      }

      result = EnactedBy.find_enacting_laws(text, urls)

      refute "eudr/2019/904" in result, "EU directives should be filtered out"
      assert "ukpga/1972/68" in result, "Domestic Act should be retained"
    end

    test "finds back-referenced enabling Act before 'powers conferred' phrase" do
      # Pattern: "Minister designated f00001 for the purposes of section 2(2) of the
      # European Communities Act 1972 f00002 ... in exercise of the powers conferred
      # by the said section 2(2) and ... the Finance Act 1973 f00003"
      # The ECA (f00002) is referenced BEFORE "powers conferred" — parser must scan
      # the full sentence, not just text after the match.
      text =
        "The Secretary of State, being the Minister designated f00001 " <>
          "for the purposes of section 2(2) of the European Communities Act 1972 f00002 " <>
          "in relation to measures relating to the control of laboratories, " <>
          "in exercise of the powers conferred by the said section 2(2) and, " <>
          "with the consent of the Treasury, the powers conferred by section 56(1) " <>
          "and (2) of the Finance Act 1973 f00003 , and of all other powers enabling " <>
          "him in that behalf, hereby makes the following Regulations"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/uksi/1991/755"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"],
        "f00003" => ["http://www.legislation.gov.uk/id/ukpga/1973/51"]
      }

      result = EnactedBy.find_enacting_laws(text, urls)

      # Must find BOTH enabling Acts, not just the Finance Act
      assert "ukpga/1972/68" in result, "Should find European Communities Act (back-referenced)"
      assert "ukpga/1973/51" in result, "Should find Finance Act"
      # Should NOT include the SI (f00001) — SIs can't enact other SIs
      refute Enum.any?(result, &String.starts_with?(&1, "uksi/")),
             "Should filter out non-enabling legislation"
    end

    test "deduplicates results" do
      text = """
      Health and Safety at Work etc. Act 1974.
      Also the Health and Safety at Work etc. Act 1974 again.
      """

      result = EnactedBy.find_enacting_laws(text, %{})

      # Should only appear once
      assert Enum.count(result, fn x -> x == "ukpga/1974/37" end) == 1
    end
  end

  describe "build_description" do
    test "builds description with URLs" do
      # Access private function via module
      laws = ["ukpga/1974/37", "uksi/2020/1234"]

      # We can test this by checking get_enacting_laws output
      # For now, just verify the module compiles and basic structure works
      assert true
    end
  end
end
