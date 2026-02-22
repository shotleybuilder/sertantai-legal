defmodule SertantaiLegal.Scraper.CommentaryParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CommentaryParser

  @fixtures_path Path.join([__DIR__, "..", "..", "fixtures", "body_xml"])

  defp read_fixture(name) do
    @fixtures_path |> Path.join(name) |> File.read!()
  end

  # ── parse/3 with fixture XML ───────────────────────────────────

  describe "parse/3 with simple_act fixture" do
    setup do
      xml = read_fixture("simple_act.xml")
      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      %{annotations: annotations, xml: xml}
    end

    test "extracts all 3 commentaries", %{annotations: annotations} do
      assert length(annotations) == 3
    end

    test "extracts F-type as amendment", %{annotations: annotations} do
      f = Enum.find(annotations, &(&1.code_type == :amendment))
      assert f != nil
      assert f.code == "F1"
      assert String.contains?(f.text, "Words in s. 3 substituted")
    end

    test "extracts C-type as modification", %{annotations: annotations} do
      c = Enum.find(annotations, &(&1.code_type == :modification))
      assert c != nil
      assert c.code == "C1"
      assert String.contains?(c.text, "S. 3 modified")
    end

    test "extracts I-type as commencement", %{annotations: annotations} do
      i = Enum.find(annotations, &(&1.code_type == :commencement))
      assert i != nil
      # Internal key — not a simple "I1" code
      assert String.contains?(i.code, "key-abc123")
      assert String.contains?(i.text, "in force at 1.1.2025")
    end

    test "assigns sequential IDs per code_type", %{annotations: annotations} do
      ids = Enum.map(annotations, & &1.id)
      assert "UK_ukpga_2024_1:amendment:1" in ids
      assert "UK_ukpga_2024_1:modification:1" in ids
      assert "UK_ukpga_2024_1:commencement:1" in ids
    end

    test "sets source to lat_parser", %{annotations: annotations} do
      for ann <- annotations do
        assert ann.source == "lat_parser"
      end
    end

    test "sets law_name on all annotations", %{annotations: annotations} do
      for ann <- annotations do
        assert ann.law_name == "UK_ukpga_2024_1"
      end
    end
  end

  # ── parse/3 with ref_to_sections mapping ───────────────────────

  describe "parse/3 with ref_to_sections" do
    test "populates affected_sections from ref mapping" do
      xml = """
      <Legislation>
      <Primary><Body>
        <P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><Text><CommentaryRef Ref="F1"/>text</Text></P1para>
        </P1>
      </Body></Primary>
      <Commentaries>
        <Commentary id="F1" Type="F">
          <Para><Text>Words substituted by S.I. 2024/1</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      ref_to_sections = %{
        "F1" => ["UK_ukpga_2024_1:s.1", "UK_ukpga_2024_1:s.2"]
      }

      annotations =
        CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"}, ref_to_sections)

      assert length(annotations) == 1
      ann = hd(annotations)
      assert ann.affected_sections == ["UK_ukpga_2024_1:s.1", "UK_ukpga_2024_1:s.2"]
    end

    test "leaves affected_sections nil when no refs match" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F99" Type="F">
          <Para><Text>Some amendment text</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"}, %{})
      ann = hd(annotations)
      assert ann.affected_sections == nil
    end
  end

  # ── Type mapping ───────────────────────────────────────────────

  describe "Commentary Type mapping" do
    test "maps all 6 XML types correctly" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"><Para><Text>F text</Text></Para></Commentary>
        <Commentary id="C1" Type="C"><Para><Text>C text</Text></Para></Commentary>
        <Commentary id="M1" Type="M"><Para><Text>M text</Text></Para></Commentary>
        <Commentary id="I1" Type="I"><Para><Text>I text</Text></Para></Commentary>
        <Commentary id="E1" Type="E"><Para><Text>E text</Text></Para></Commentary>
        <Commentary id="X1" Type="X"><Para><Text>X text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      types = Enum.map(annotations, & &1.code_type) |> Enum.sort()

      assert :amendment in types
      assert :commencement in types
      assert :modification in types
      assert :extent_editorial in types

      # C and M both map to modification — should have 2 modifications
      mod_count = Enum.count(annotations, &(&1.code_type == :modification))
      assert mod_count == 2

      # E and X both map to extent_editorial — should have 2
      ext_count = Enum.count(annotations, &(&1.code_type == :extent_editorial))
      assert ext_count == 2
    end

    test "skips unknown Type values" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="Z1" Type="Z"><Para><Text>Unknown type</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      assert annotations == []
    end
  end

  # ── Sequential ID assignment ───────────────────────────────────

  describe "sequential ID assignment" do
    test "assigns per-type sequential IDs" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"><Para><Text>First F</Text></Para></Commentary>
        <Commentary id="F2" Type="F"><Para><Text>Second F</Text></Para></Commentary>
        <Commentary id="F3" Type="F"><Para><Text>Third F</Text></Para></Commentary>
        <Commentary id="C1" Type="C"><Para><Text>First C</Text></Para></Commentary>
        <Commentary id="C2" Type="C"><Para><Text>Second C</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})

      f_ids =
        annotations
        |> Enum.filter(&(&1.code_type == :amendment))
        |> Enum.map(& &1.id)

      assert f_ids == [
               "UK_test_2024_1:amendment:1",
               "UK_test_2024_1:amendment:2",
               "UK_test_2024_1:amendment:3"
             ]

      c_ids =
        annotations
        |> Enum.filter(&(&1.code_type == :modification))
        |> Enum.map(& &1.id)

      assert c_ids == [
               "UK_test_2024_1:modification:1",
               "UK_test_2024_1:modification:2"
             ]
    end
  end

  # ── Text extraction ────────────────────────────────────────────

  describe "text extraction" do
    test "joins multiple Para/Text elements" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F">
          <Para><Text>First paragraph.</Text></Para>
          <Para><Text>Second paragraph.</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.text == "First paragraph. Second paragraph."
    end

    test "handles empty Commentary gracefully" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.text == ""
    end
  end

  # ── Edge cases ─────────────────────────────────────────────────

  describe "edge cases" do
    test "empty Commentaries block returns empty list" do
      xml = """
      <Legislation>
      <Commentaries></Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert annotations == []
    end

    test "no Commentaries block returns empty list" do
      xml = """
      <Legislation>
      <Primary><Body>
        <P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><Text>Some text.</Text></P1para>
        </P1>
      </Body></Primary>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert annotations == []
    end

    test "skips Commentary with empty id" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="" Type="F"><Para><Text>No ID</Text></Para></Commentary>
        <Commentary id="F1" Type="F"><Para><Text>Has ID</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert length(annotations) == 1
      assert hd(annotations).code == "F1"
    end
  end

  # ── build_ref_to_sections/1 ────────────────────────────────────

  describe "build_ref_to_sections/1" do
    test "inverts commentary_refs from LAT rows" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: ["F1", "C1"]},
        %{section_id: "law:s.2", commentary_refs: ["F1"]},
        %{section_id: "law:s.3", commentary_refs: []}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)

      assert result["F1"] == ["law:s.1", "law:s.2"]
      assert result["C1"] == ["law:s.1"]
      refute Map.has_key?(result, "")
    end

    test "handles rows with nil commentary_refs" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: nil},
        %{section_id: "law:s.2"}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)
      assert result == %{}
    end

    test "deduplicates section_ids per ref" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: ["F1"]},
        %{section_id: "law:s.1", commentary_refs: ["F1"]}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)
      assert result["F1"] == ["law:s.1"]
    end
  end

  # ── Code derivation ────────────────────────────────────────────

  describe "code derivation" do
    test "uses ref_id directly for simple codes like F1, C42" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F42" Type="F"><Para><Text>Text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.code == "F42"
    end

    test "prefixes internal keys with type letter" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="key-abc123" Type="F"><Para><Text>Text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.code == "F:key-abc123"
    end
  end
end
