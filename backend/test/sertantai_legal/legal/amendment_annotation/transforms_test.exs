defmodule SertantaiLegal.Legal.AmendmentAnnotation.TransformsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.AmendmentAnnotation.Transforms

  # ── detect_uk_column/1 ───────────────────────────────────────────

  describe "detect_uk_column/1" do
    test "detects standard UK column" do
      assert Transforms.detect_uk_column(["ID", "UK", "Articles", "Ef Code", "Text"]) == "UK"
    end

    test "detects UK (from Articles) column" do
      headers = ["ID", "UK (from Articles)", "Articles", "Ef Code", "Text"]
      assert Transforms.detect_uk_column(headers) == "UK (from Articles)"
    end

    test "prefers UK over UK (from Articles) when both present" do
      headers = ["ID", "UK (from Articles)", "UK", "Articles", "Ef Code", "Text"]
      assert Transforms.detect_uk_column(headers) == "UK"
    end

    test "returns nil when no UK column" do
      assert Transforms.detect_uk_column(["ID", "Articles", "Ef Code", "Text"]) == nil
    end
  end

  # ── extract_law_name/1 ──────────────────────────────────────────

  describe "extract_law_name/1" do
    test "strips acronym suffix" do
      assert Transforms.extract_law_name("UK_ukpga_1974_37_HSWA") == "UK_ukpga_1974_37"
    end

    test "strips acronym prefix" do
      assert Transforms.extract_law_name("UK_MANI_apni_1969_6") == "UK_apni_1969_6"
    end

    test "passes through already-normalised name" do
      assert Transforms.extract_law_name("UK_ukpga_1974_37") == "UK_ukpga_1974_37"
    end

    test "handles complex acronyms with ampersand" do
      assert Transforms.extract_law_name("UK_nisr_2010_160_CDGUTPERNI") == "UK_nisr_2010_160"
    end

    test "returns nil for regnal year format" do
      assert Transforms.extract_law_name("UK_ukpga_1875_Vict/38-39/17_EA") == nil
    end

    test "returns nil for apostrophe in acronym" do
      assert Transforms.extract_law_name("UK_ukpga_1969_37_E'LDEA") == nil
    end

    test "returns nil for nil" do
      assert Transforms.extract_law_name(nil) == nil
    end

    test "returns nil for empty string" do
      assert Transforms.extract_law_name("") == nil
    end
  end

  # ── derive_law_name_from_id/1 ───────────────────────────────────

  describe "derive_law_name_from_id/1" do
    test "extracts law_name from standard amendment ID" do
      assert Transforms.derive_law_name_from_id("UK_ukpga_2006_19_CCSEA_F1") ==
               "UK_ukpga_2006_19"
    end

    test "handles multi-digit F-codes" do
      assert Transforms.derive_law_name_from_id("UK_ukpga_2008_27_CCA_F123") ==
               "UK_ukpga_2008_27"
    end

    test "handles C-codes" do
      assert Transforms.derive_law_name_from_id("UK_ukpga_1974_37_HSWA_C5") ==
               "UK_ukpga_1974_37"
    end

    test "handles I-codes" do
      assert Transforms.derive_law_name_from_id("UK_uksi_2002_2677_COSHHSI_I3") ==
               "UK_uksi_2002_2677"
    end

    test "returns nil for broken IDs" do
      assert Transforms.derive_law_name_from_id("_F25") == nil
    end

    test "returns nil for empty string" do
      assert Transforms.derive_law_name_from_id("") == nil
    end

    test "returns nil for nil" do
      assert Transforms.derive_law_name_from_id(nil) == nil
    end
  end

  # ── classify_code_type/1 ────────────────────────────────────────

  describe "classify_code_type/1" do
    test "F-codes → :amendment" do
      assert Transforms.classify_code_type("F1") == :amendment
      assert Transforms.classify_code_type("F123") == :amendment
    end

    test "C-codes → :modification" do
      assert Transforms.classify_code_type("C42") == :modification
    end

    test "I-codes → :commencement" do
      assert Transforms.classify_code_type("I7") == :commencement
    end

    test "E-codes → :extent_editorial" do
      assert Transforms.classify_code_type("E3") == :extent_editorial
    end

    test "unknown codes → nil" do
      assert Transforms.classify_code_type("X1") == nil
      assert Transforms.classify_code_type("") == nil
    end
  end

  # ── parse_affected_legacy_ids/1 ─────────────────────────────────

  describe "parse_affected_legacy_ids/1" do
    test "parses single article" do
      assert Transforms.parse_affected_legacy_ids("UK_MANI_apni_1969_6_1___1___NI") ==
               ["UK_MANI_apni_1969_6_1___1___NI"]
    end

    test "parses comma-separated articles" do
      input = "UK_ukpga_2008_27_CCA_5__71_71_2__EW,UK_ukpga_2008_27_CCA_5__71_71_3__EW"

      assert Transforms.parse_affected_legacy_ids(input) == [
               "UK_ukpga_2008_27_CCA_5__71_71_2__EW",
               "UK_ukpga_2008_27_CCA_5__71_71_3__EW"
             ]
    end

    test "trims whitespace around entries" do
      input = " UK_a , UK_b , UK_c "
      assert Transforms.parse_affected_legacy_ids(input) == ["UK_a", "UK_b", "UK_c"]
    end

    test "returns nil for empty string" do
      assert Transforms.parse_affected_legacy_ids("") == nil
    end

    test "returns nil for nil" do
      assert Transforms.parse_affected_legacy_ids(nil) == nil
    end

    test "returns nil for whitespace-only" do
      assert Transforms.parse_affected_legacy_ids("   ") == nil
    end
  end

  # ── build_annotation_id/3 ───────────────────────────────────────

  describe "build_annotation_id/3" do
    test "builds standard amendment ID" do
      assert Transforms.build_annotation_id("UK_ukpga_1974_37", :amendment, 1) ==
               "UK_ukpga_1974_37:amendment:1"
    end

    test "builds modification ID" do
      assert Transforms.build_annotation_id("UK_uksi_2002_2677", :modification, 42) ==
               "UK_uksi_2002_2677:modification:42"
    end

    test "builds commencement ID" do
      assert Transforms.build_annotation_id("UK_ukpga_2008_27", :commencement, 7) ==
               "UK_ukpga_2008_27:commencement:7"
    end
  end

  # ── strip_bom/1 ─────────────────────────────────────────────────

  describe "strip_bom/1" do
    test "strips UTF-8 BOM" do
      assert Transforms.strip_bom(<<0xEF, 0xBB, 0xBF, "ID,UK">>) == "ID,UK"
    end

    test "passes through string without BOM" do
      assert Transforms.strip_bom("ID,UK") == "ID,UK"
    end

    test "passes through empty string" do
      assert Transforms.strip_bom("") == ""
    end
  end
end
