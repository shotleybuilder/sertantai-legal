defmodule SertantaiLegal.Legal.Lat.TransformsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Lat.Transforms, as: T

  # ── 1. ID Normalisation ────────────────────────────────────────

  describe "normalize_law_name/1" do
    test "pattern 1: strips ACRO prefix (UK_ACRO_type_year_num)" do
      assert T.normalize_law_name("UK_CMCHA_ukpga_2007_19") == "UK_ukpga_2007_19"
      assert T.normalize_law_name("UK_HSWA_ukpga_1974_37") == "UK_ukpga_1974_37"
      assert T.normalize_law_name("UK_CDM_uksi_2015_51") == "UK_uksi_2015_51"
    end

    test "pattern 2: strips ACRO suffix (UK_type_year_num_ACRO)" do
      assert T.normalize_law_name("UK_ukpga_1974_37_HSWA") == "UK_ukpga_1974_37"
      assert T.normalize_law_name("UK_uksi_2002_2677_COSHH") == "UK_uksi_2002_2677"
    end

    test "pattern 3: strips ACRO suffix (UK_year_num_ACRO)" do
      assert T.normalize_law_name("UK_2007_19_CMCHA") == "UK_2007_19"
      assert T.normalize_law_name("UK_1988_819_CDWR") == "UK_1988_819"
    end

    test "no change for canonical form" do
      assert T.normalize_law_name("UK_ukpga_1974_37") == "UK_ukpga_1974_37"
      assert T.normalize_law_name("UK_uksi_2002_2677") == "UK_uksi_2002_2677"
    end

    test "handles nil" do
      assert T.normalize_law_name(nil) == nil
    end

    test "trims whitespace" do
      assert T.normalize_law_name("  UK_HSWA_ukpga_1974_37  ") == "UK_ukpga_1974_37"
    end

    test "handles acronyms with ampersand and hyphen" do
      assert T.normalize_law_name("UK_H&S_ukpga_1974_37") == "UK_ukpga_1974_37"
    end
  end

  # ── 2. Record_Type → section_type ──────────────────────────────

  describe "map_section_type/1" do
    test "maps standard types" do
      assert T.map_section_type("section") == "section"
      assert T.map_section_type("part") == "part"
      assert T.map_section_type("chapter") == "chapter"
      assert T.map_section_type("heading") == "heading"
      assert T.map_section_type("title") == "title"
      assert T.map_section_type("schedule") == "schedule"
      assert T.map_section_type("signed") == "signed"
      assert T.map_section_type("commencement") == "commencement"
    end

    test "maps hyphenated to underscored" do
      assert T.map_section_type("sub-section") == "sub_section"
      assert T.map_section_type("sub-article") == "sub_article"
      assert T.map_section_type("sub-paragraph") == "sub_paragraph"
    end

    test "maps compound types" do
      assert T.map_section_type("article,heading") == "heading"
      assert T.map_section_type("article,sub-article") == "sub_article"
      assert T.map_section_type("table,heading") == "heading"
    end

    test "maps aliases" do
      assert T.map_section_type("annex") == "schedule"
      assert T.map_section_type("sub-table") == "table"
      assert T.map_section_type("figure") == "note"
    end

    test "returns nil for unknown types" do
      assert T.map_section_type("unknown_type") == nil
      assert T.map_section_type("") == nil
      assert T.map_section_type(nil) == nil
    end

    test "trims whitespace" do
      assert T.map_section_type("  section  ") == "section"
    end
  end

  # ── 3. Content Row Detection ───────────────────────────────────

  describe "content_row?/1" do
    test "true for content types" do
      assert T.content_row?("section") == true
      assert T.content_row?("sub-section") == true
      assert T.content_row?("article") == true
      assert T.content_row?("heading") == true
      assert T.content_row?("part") == true
      assert T.content_row?("schedule") == true
      assert T.content_row?("title") == true
      assert T.content_row?("signed") == true
      assert T.content_row?("paragraph") == true
    end

    test "false for annotation content rows" do
      assert T.content_row?("modification,content") == false
      assert T.content_row?("commencement,content") == false
      assert T.content_row?("extent,content") == false
    end

    test "false for amendment rows" do
      assert T.content_row?("amendment,textual") == false
      assert T.content_row?("amendment,repeal") == false
    end

    test "false for subordinate/editorial rows" do
      assert T.content_row?("subordinate,content") == false
      assert T.content_row?("editorial,content") == false
    end

    test "false for annotation heading rows" do
      assert T.content_row?("commencement,heading") == false
      assert T.content_row?("modification,heading") == false
      assert T.content_row?("extent,heading") == false
      assert T.content_row?("editorial,heading") == false
      assert T.content_row?("subordinate,heading") == false
    end

    test "false for nil and empty" do
      assert T.content_row?(nil) == false
      assert T.content_row?("") == false
    end
  end

  # ── 4. Provision Merging ───────────────────────────────────────

  describe "merge_provision/1" do
    test "returns trimmed value" do
      assert T.merge_provision("25A") == "25A"
      assert T.merge_provision("  3  ") == "3"
    end

    test "returns nil for empty/nil" do
      assert T.merge_provision(nil) == nil
      assert T.merge_provision("") == nil
    end
  end

  # ── 6. Region → extent_code ────────────────────────────────────

  describe "map_extent_code/1" do
    test "maps all four nations" do
      assert T.map_extent_code("England and Wales and Scotland and Northern Ireland") ==
               "E+W+S+NI"
    end

    test "maps three nations (E+W+S)" do
      assert T.map_extent_code("England and Wales and Scotland") == "E+W+S"
    end

    test "maps E+W+NI" do
      assert T.map_extent_code("England and Wales and Northern Ireland") == "E+W+NI"
    end

    test "maps E+W" do
      assert T.map_extent_code("England and Wales") == "E+W"
    end

    test "maps E+S" do
      assert T.map_extent_code("England and Scotland") == "E+S"
    end

    test "maps single nations" do
      assert T.map_extent_code("England") == "E"
      assert T.map_extent_code("Wales") == "W"
      assert T.map_extent_code("Scotland") == "S"
      assert T.map_extent_code("Northern Ireland") == "NI"
    end

    test "maps GB and UK prefixes" do
      assert T.map_extent_code("GB") == "E+W+S"
      assert T.map_extent_code("UK") == "E+W+S+NI"
    end

    test "passes through unknown values" do
      assert T.map_extent_code("Jersey") == "Jersey"
    end

    test "returns nil for empty/nil" do
      assert T.map_extent_code(nil) == nil
      assert T.map_extent_code("") == nil
    end

    test "E+NI combination" do
      assert T.map_extent_code("England and Northern Ireland") == "E+NI"
    end
  end

  # ── 7. Build Citation ──────────────────────────────────────────

  describe "build_citation/2" do
    test "section with provision" do
      assert T.build_citation("section", provision: "25A") == "s.25A"
    end

    test "section with sub-section" do
      assert T.build_citation("section", provision: "25A", sub: "1") == "s.25A(1)"
    end

    test "section with full hierarchy" do
      assert T.build_citation("section", provision: "25A", sub: "1", paragraph: "a") ==
               "s.25A(1)(a)"
    end

    test "article uses art. prefix" do
      assert T.build_citation("article", provision: "16B") == "art.16B"
    end

    test "article with Regulation class uses reg. prefix" do
      assert T.build_citation("article",
               provision: "2",
               sub: "1",
               paragraph: "b",
               class: "Regulation"
             ) ==
               "reg.2(1)(b)"
    end

    test "schedule" do
      assert T.build_citation("schedule", schedule: "2") == "sch.2"
    end

    test "part" do
      assert T.build_citation("part", part: "1") == "pt.1"
    end

    test "chapter" do
      assert T.build_citation("chapter", chapter: "3") == "ch.3"
    end

    test "heading" do
      assert T.build_citation("heading", heading_group: "18") == "h.18"
    end

    test "title uses position" do
      assert T.build_citation("title", position: 1) == "title.1"
    end

    test "signed uses position" do
      assert T.build_citation("signed", position: 3) == "signed.3"
    end

    test "paragraph" do
      assert T.build_citation("paragraph", paragraph: "3") == "para.3"
    end

    test "paragraph with sub_paragraph" do
      assert T.build_citation("paragraph", paragraph: "3", sub_paragraph: "a") == "para.3(a)"
    end

    test "sub_paragraph" do
      assert T.build_citation("sub_paragraph", paragraph: "3", sub_paragraph: "a") ==
               "para.3(a)"
    end

    test "schedule-scoped section" do
      assert T.build_citation("section", schedule: "2", provision: "5") == "sch.2.s.5"
    end

    test "schedule-scoped heading" do
      assert T.build_citation("heading", schedule: "2", heading_group: "5") == "sch.2.h.5"
    end

    test "schedule-scoped part" do
      assert T.build_citation("part", schedule: "2", part: "1") == "sch.2.pt.1"
    end

    test "schedule-scoped paragraph" do
      assert T.build_citation("paragraph", schedule: "2", paragraph: "3") == "sch.2.para.3"
    end

    test "position fallback when provision missing" do
      assert T.build_citation("section", position: 42) == "s.42"
    end

    test "table uses position" do
      assert T.build_citation("table", position: 50) == "table.50"
    end

    test "note" do
      assert T.build_citation("note", position: 1) == "note.1"
    end
  end

  # ── 8. Sort Key ────────────────────────────────────────────────

  describe "normalize_provision_to_sort_key/1" do
    test "plain number" do
      assert T.normalize_provision_to_sort_key("3") == "003.000.000"
      assert T.normalize_provision_to_sort_key("41") == "041.000.000"
    end

    test "letter suffix" do
      assert T.normalize_provision_to_sort_key("3A") == "003.010.000"
      assert T.normalize_provision_to_sort_key("3B") == "003.020.000"
      assert T.normalize_provision_to_sort_key("41A") == "041.010.000"
    end

    test "Z-prefix suffix" do
      assert T.normalize_provision_to_sort_key("3ZA") == "003.001.000"
      assert T.normalize_provision_to_sort_key("3ZB") == "003.002.000"
    end

    test "double letter suffix" do
      assert T.normalize_provision_to_sort_key("3AA") == "003.010.010"
      assert T.normalize_provision_to_sort_key("3AB") == "003.010.020"
    end

    test "mixed letter and Z-prefix" do
      assert T.normalize_provision_to_sort_key("19DZA") == "019.040.001"
      assert T.normalize_provision_to_sort_key("19AZA") == "019.010.001"
    end

    test "sort order is correct" do
      keys =
        ~w[3 3ZA 3ZB 3A 3AA 3AB 3B 4]
        |> Enum.map(&T.normalize_provision_to_sort_key/1)

      assert keys == Enum.sort(keys)
    end

    test "empty and nil" do
      assert T.normalize_provision_to_sort_key("") == "000.000.000"
      assert T.normalize_provision_to_sort_key(nil) == "000.000.000"
    end

    test "handles lowercase by uppercasing" do
      assert T.normalize_provision_to_sort_key("3a") == "003.010.000"
    end
  end

  describe "build_sort_key/2" do
    test "section uses provision" do
      assert T.build_sort_key("section", provision: "25A") == "025.010.000~"
    end

    test "heading uses heading_group" do
      assert T.build_sort_key("heading", heading_group: "18") == "018.000.000~"
    end

    test "paragraph uses paragraph value" do
      assert T.build_sort_key("paragraph", paragraph: "3") == "003.000.000~"
    end

    test "structural types use 000.000.000" do
      assert T.build_sort_key("title", []) == "000.000.000~"
      assert T.build_sort_key("part", []) == "000.000.000~"
      assert T.build_sort_key("schedule", []) == "000.000.000~"
      assert T.build_sort_key("signed", []) == "000.000.000~"
    end

    test "appends extent suffix" do
      assert T.build_sort_key("section", provision: "23", extent: "E+W") ==
               "023.000.000~E+W"
    end

    test "empty extent gives trailing tilde" do
      assert T.build_sort_key("section", provision: "23") == "023.000.000~"
    end
  end

  # ── 11. Hierarchy Path ─────────────────────────────────────────

  describe "build_hierarchy_path/1" do
    test "returns nil for root-level rows" do
      assert T.build_hierarchy_path([]) == nil
    end

    test "single level" do
      assert T.build_hierarchy_path(part: "1") == "part.1"
    end

    test "two levels" do
      assert T.build_hierarchy_path(part: "1", heading_group: "18") ==
               "part.1/heading.18"
    end

    test "full hierarchy" do
      assert T.build_hierarchy_path(
               part: "1",
               heading_group: "18",
               provision: "25A",
               sub: "1"
             ) == "part.1/heading.18/provision.25A/sub.1"
    end

    test "schedule-scoped" do
      assert T.build_hierarchy_path(schedule: "2", paragraph: "3") ==
               "schedule.2/para.3"
    end

    test "skips nil and empty values" do
      assert T.build_hierarchy_path(part: "1", chapter: nil, heading_group: "18") ==
               "part.1/heading.18"

      assert T.build_hierarchy_path(part: "1", chapter: "", heading_group: "18") ==
               "part.1/heading.18"
    end
  end

  # ── 12. Depth Calculation ──────────────────────────────────────

  describe "calculate_depth/1" do
    test "root level is 0" do
      assert T.calculate_depth([]) == 0
    end

    test "one level" do
      assert T.calculate_depth(part: "1") == 1
    end

    test "section under part/heading is 3" do
      assert T.calculate_depth(part: "1", heading_group: "18", provision: "25A") == 3
    end

    test "full depth" do
      assert T.calculate_depth(
               schedule: "2",
               part: "1",
               chapter: "3",
               heading_group: "5",
               provision: "7",
               sub: "1",
               paragraph: "a"
             ) == 7
    end

    test "skips nil and empty values" do
      assert T.calculate_depth(part: "1", chapter: nil, heading_group: "") == 1
    end
  end

  # ── 13. Amendment Counts ───────────────────────────────────────

  describe "count_amendments/1" do
    test "counts F-codes" do
      assert T.count_amendments("F3,F2,F1") == 3
    end

    test "ignores non-F codes" do
      assert T.count_amendments("F3,C1,F2") == 2
      assert T.count_amendments("C1,I2,E3") == nil
    end

    test "single F-code" do
      assert T.count_amendments("F1") == 1
    end

    test "returns nil for empty/nil" do
      assert T.count_amendments(nil) == nil
      assert T.count_amendments("") == nil
    end
  end

  # ── Schedule from flow ─────────────────────────────────────────

  describe "schedule_from_flow/1" do
    test "returns nil for non-schedule flows" do
      assert T.schedule_from_flow("pre") == nil
      assert T.schedule_from_flow("main") == nil
      assert T.schedule_from_flow("post") == nil
      assert T.schedule_from_flow("signed") == nil
    end

    test "returns schedule number for numeric flows" do
      assert T.schedule_from_flow("1") == "1"
      assert T.schedule_from_flow("2") == "2"
      assert T.schedule_from_flow("10") == "10"
    end

    test "returns nil for nil" do
      assert T.schedule_from_flow(nil) == nil
    end
  end

  # ── XML Element → section_type Mapping ──────────────────────────

  describe "xml_element_to_section_type/2" do
    test "structural elements are mode-independent" do
      assert T.xml_element_to_section_type("Part", :section) == "part"
      assert T.xml_element_to_section_type("Part", :article) == "part"
      assert T.xml_element_to_section_type("Chapter", :section) == "chapter"
      assert T.xml_element_to_section_type("Pblock", :section) == "heading"
      assert T.xml_element_to_section_type("Schedule", :section) == "schedule"
      assert T.xml_element_to_section_type("SignedSection", :article) == "signed"
    end

    test "P1 maps to section for Acts" do
      assert T.xml_element_to_section_type("P1", :section) == "section"
    end

    test "P1 maps to article for SIs" do
      assert T.xml_element_to_section_type("P1", :article) == "article"
    end

    test "P2 maps to sub_section for Acts" do
      assert T.xml_element_to_section_type("P2", :section) == "sub_section"
    end

    test "P2 maps to sub_article for SIs" do
      assert T.xml_element_to_section_type("P2", :article) == "sub_article"
    end

    test "P3 and P4 are mode-independent" do
      assert T.xml_element_to_section_type("P3", :section) == "paragraph"
      assert T.xml_element_to_section_type("P3", :article) == "paragraph"
      assert T.xml_element_to_section_type("P4", :section) == "sub_paragraph"
      assert T.xml_element_to_section_type("P4", :article) == "sub_paragraph"
    end

    test "Tabular maps to table" do
      assert T.xml_element_to_section_type("Tabular", :section) == "table"
    end

    test "Figure maps to note" do
      assert T.xml_element_to_section_type("Figure", :section) == "note"
    end

    test "unknown elements return nil" do
      assert T.xml_element_to_section_type("Body", :section) == nil
      assert T.xml_element_to_section_type("P1para", :section) == nil
      assert T.xml_element_to_section_type("unknown", :section) == nil
    end

    test "default mode is :section" do
      assert T.xml_element_to_section_type("P1") == "section"
      assert T.xml_element_to_section_type("P2") == "sub_section"
    end
  end

  # ── XML Extent Normalisation ───────────────────────────────────

  describe "normalize_xml_extent/1" do
    test "normalises N.I. to NI" do
      assert T.normalize_xml_extent("E+W+S+N.I.") == "E+W+S+NI"
    end

    test "leaves non-NI extents unchanged" do
      assert T.normalize_xml_extent("E+W+S") == "E+W+S"
      assert T.normalize_xml_extent("E+W") == "E+W"
      assert T.normalize_xml_extent("E") == "E"
      assert T.normalize_xml_extent("S") == "S"
    end

    test "normalises standalone N.I." do
      assert T.normalize_xml_extent("N.I.") == "NI"
    end

    test "normalises S+N.I." do
      assert T.normalize_xml_extent("S+N.I.") == "S+NI"
    end

    test "returns nil for nil and empty" do
      assert T.normalize_xml_extent(nil) == nil
      assert T.normalize_xml_extent("") == nil
    end

    test "trims whitespace" do
      assert T.normalize_xml_extent("  E+W+S+N.I.  ") == "E+W+S+NI"
    end
  end

  # ── Parallel Provisions Detection ──────────────────────────────

  describe "detect_parallel_provisions/1" do
    test "detects provisions with multiple extents" do
      pairs = [
        {"23", "E+W"},
        {"23", "NI"},
        {"23", "S"},
        {"24", "E+W+S+NI"},
        {"25", "E+W+S+NI"}
      ]

      result = T.detect_parallel_provisions(pairs)
      assert MapSet.member?(result, "23")
      refute MapSet.member?(result, "24")
      refute MapSet.member?(result, "25")
    end

    test "returns empty set when no parallels" do
      pairs = [
        {"1", "E+W+S+NI"},
        {"2", "E+W+S+NI"},
        {"3", "E+W+S+NI"}
      ]

      assert T.detect_parallel_provisions(pairs) == MapSet.new()
    end

    test "ignores nil/empty provisions and extents" do
      pairs = [
        {nil, "E+W"},
        {"", "E+W"},
        {"1", nil},
        {"1", ""}
      ]

      assert T.detect_parallel_provisions(pairs) == MapSet.new()
    end
  end
end
