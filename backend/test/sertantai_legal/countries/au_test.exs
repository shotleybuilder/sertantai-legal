defmodule SertantaiLegal.Countries.AuTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Countries.{Country, Au}
  alias SertantaiLegal.Legal.LegalRegister

  describe "registry" do
    test "AU is registered" do
      assert Country.for("au") == Au
      assert "au" in Country.codes()
    end
  end

  describe "identity" do
    test "code and name" do
      assert Au.code() == "au"
      assert Au.name() == "Australia"
    end

    test "jurisdictions" do
      jurisdictions = Au.jurisdictions()
      assert length(jurisdictions) == 9

      codes = Enum.map(jurisdictions, &elem(&1, 0))
      assert "cth" in codes
      assert "nsw" in codes
      assert "vic" in codes
      assert "qld" in codes
      assert "wa" in codes
      assert "sa" in codes
      assert "tas" in codes
      assert "act" in codes
      assert "nt" in codes
    end
  end

  describe "type_codes" do
    test "returns map of type codes" do
      codes = Au.type_codes()
      assert is_map(codes)
      assert map_size(codes) > 20
    end

    test "type_code_name returns correct names" do
      assert Au.type_code_name("cth_act") == "Commonwealth Act"
      assert Au.type_code_name("nsw_reg") == "New South Wales Regulation"
      assert Au.type_code_name("award") == "Modern Award (Fair Work Commission)"
      assert Au.type_code_name("cop") == "Code of Practice"
      assert Au.type_code_name("unknown") == nil
    end

    test "type_class_from_title infers correctly" do
      assert Au.type_class_from_title("Work Health and Safety Act 2011") == "Act"
      assert Au.type_class_from_title("Work Health and Safety Regulation 2017") == "Regulation"
      assert Au.type_class_from_title("Fair Work Act 2009") == "Act"

      assert Au.type_class_from_title("Managing risks of hazardous chemicals Code of Practice") ==
               "Code of Practice"

      assert Au.type_class_from_title("Something random") == nil
    end
  end

  describe "geo_extents" do
    test "returns 10 extents" do
      extents = Au.geo_extents()
      assert length(extents) == 10

      codes = Enum.map(extents, &elem(&1, 0))
      assert "au" in codes
      assert "cth" in codes
      assert "vic" in codes
    end
  end

  describe "family_keywords" do
    test "returns keyword map" do
      keywords = Au.family_keywords()
      assert is_map(keywords)
      assert map_size(keywords) > 30
    end

    test "includes AU-specific families" do
      families = Au.families()
      assert "💜 HR: Modern Awards" in families
      assert "💜 HR: Superannuation" in families
      assert "💜 HR: Anti-Discrimination" in families
      assert "💜 HR: Workers Compensation" in families
    end

    test "includes shared families" do
      families = Au.families()
      assert "💙 OH&S: Occupational / Personal Safety" in families
      assert "💚 ENVIRONMENTAL PROTECTION" in families
      assert "💜 HR: Employment" in families
    end
  end

  describe "actors" do
    test "government actors include AU regulators" do
      actors = Au.government_actors()
      names = Enum.map(actors, &elem(&1, 0))
      assert "Gvt: Agency: Safe Work Australia" in names
      assert "Gvt: Agency: Comcare" in names
      assert "Gvt: Agency: Fair Work Commission" in names
    end

    test "governed actors include PCBU" do
      actors = Au.governed_actors()
      names = Enum.map(actors, &elem(&1, 0))
      assert "PCBU" in names
      assert "PCBU: Officer" in names
      assert "Ind: HSR" in names
      assert "Org: Labour Hire" in names
    end
  end

  describe "source_url" do
    test "returns nil (AU URLs not predictable)" do
      assert Au.source_url("cth_act", 2011, "137") == nil
    end

    test "portal_url returns correct URLs" do
      assert Au.portal_url("cth") == "https://www.legislation.gov.au"
      assert Au.portal_url("nsw") == "https://legislation.nsw.gov.au"
      assert Au.portal_url("qld") == "https://www.legislation.qld.gov.au"
      assert Au.portal_url("unknown") == nil
    end
  end

  describe "AU partition" do
    test "can create and read AU records" do
      {:ok, law} =
        LegalRegister
        |> Ash.Changeset.for_create(:create, %{
          country: "au",
          jurisdiction: "cth",
          name: "AU_cth_act_2011_137",
          title_en: "Work Health and Safety Act 2011",
          type_code: "cth_act",
          year: 2011,
          number: "137",
          family: "💙 OH&S: Occupational / Personal Safety"
        })
        |> Ash.create()

      assert law.country == "au"
      assert law.jurisdiction == "cth"
      assert law.name == "AU_cth_act_2011_137"

      # Read back via by_country (returns paginated result)
      {:ok, page} = LegalRegister.by_country("au")
      assert length(page.results) >= 1
      assert Enum.any?(page.results, &(&1.id == law.id))

      # Clean up
      Ash.destroy!(law)
    end

    test "AU records don't appear in UK queries" do
      {:ok, law} =
        LegalRegister
        |> Ash.Changeset.for_create(:create, %{
          country: "au",
          jurisdiction: "cth",
          name: "AU_test_isolation",
          title_en: "Test Isolation"
        })
        |> Ash.create()

      {:ok, uk_page} = LegalRegister.by_country("uk")
      refute Enum.any?(uk_page.results, &(&1.name == "AU_test_isolation"))

      Ash.destroy!(law)
    end
  end
end
