defmodule SertantaiLegal.Zenoh.SecondaryTaxaSubscriberTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Zenoh.SecondaryTaxaSubscriber

  describe "normalize_taxa/1" do
    # --- Comma-separated string inputs (DuckDB format) ---

    test "splits comma-separated drrp_types string" do
      row = %{"drrp_types" => "Obligation,Permission"}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation", "Permission"]
    end

    test "splits comma-separated governed_actors string" do
      row = %{"governed_actors" => "MoD: Commanding Officer,MoD: Contractor"}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["MoD: Commanding Officer", "MoD: Contractor"]
    end

    test "handles single-value string (no comma)" do
      row = %{"drrp_types" => "Obligation"}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation"]
    end

    test "trims whitespace around comma-separated values" do
      row = %{"drrp_types" => "Obligation , Permission , Recommendation"}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation", "Permission", "Recommendation"]
    end

    test "handles empty string as no values" do
      row = %{"drrp_types" => ""}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result == %{}
    end

    # --- List inputs (still supported for compatibility) ---

    test "passes through list values" do
      row = %{"drrp_types" => ["Obligation", "Recommendation"]}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation", "Recommendation"]
    end

    test "passes through governed_actors list" do
      row = %{"governed_actors" => ["CO", "ODH", "Contractor"]}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "ODH", "Contractor"]
    end

    # --- government_actors merging ---

    test "merges comma-separated government_actors into governed_actors" do
      row = %{
        "governed_actors" => "CO,ODH",
        "government_actors" => "DSA,Minister"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "ODH", "DSA", "Minister"]
    end

    test "government_actors alone populates governed_actors" do
      row = %{"government_actors" => "DSA"}

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["DSA"]
    end

    test "deduplicates when merging government_actors" do
      row = %{
        "governed_actors" => "CO,DSA",
        "government_actors" => "DSA,Minister"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "DSA", "Minister"]
    end

    # --- Phase 2 / ignored columns ---

    test "ignores Phase 2 columns" do
      row = %{
        "drrp_types" => "Obligation",
        "obligation_strength" => "Mandatory",
        "modal_verb" => "shall",
        "clause_refined" => "The commander must ensure..."
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation"]
      refute Map.has_key?(result, :obligation_strength)
      refute Map.has_key?(result, :modal_verb)
      refute Map.has_key?(result, :clause_refined)
    end

    test "ignores section_id (handled separately)" do
      row = %{
        "section_id" => "JSP_mod_2026_JSP375CH23:part-1-directive/policy-statements.para.23",
        "drrp_types" => "Obligation"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      refute Map.has_key?(result, :section_id)
      assert result.drrp_types == ["Obligation"]
    end

    test "ignores unknown columns" do
      row = %{
        "drrp_types" => "Obligation",
        "some_future_column" => "unexpected"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation"]
      refute Map.has_key?(result, :some_future_column)
      refute Map.has_key?(result, "some_future_column")
    end

    # --- Edge cases ---

    test "omits nil values" do
      row = %{
        "drrp_types" => nil,
        "governed_actors" => nil,
        "government_actors" => nil
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result == %{}
    end

    test "handles empty row" do
      assert SecondaryTaxaSubscriber.normalize_taxa(%{}) == %{}
    end

    test "all keys are atoms" do
      row = %{
        "drrp_types" => "Obligation",
        "governed_actors" => "CO",
        "government_actors" => "DSA"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert Enum.all?(Map.keys(result), &is_atom/1)
    end

    # --- Full realistic payload (DuckDB format) ---

    test "full realistic secondary source payload" do
      row = %{
        "section_id" => "JSP_mod_2026_JSP375CH23:part-1-directive/policy-statements.para.23",
        "drrp_types" => "Obligation,Permission",
        "governed_actors" => "MoD: Commanding Officer,MoD: ODH,MoD: Contractor",
        "government_actors" => "MoD: Defence Safety Authority",
        "obligation_strength" => "Mandatory",
        "modal_verb" => "shall",
        "clause_refined" => "As part of the risk assessment the commander must..."
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      # Mapped fields — comma-separated strings split into arrays
      assert result.drrp_types == ["Obligation", "Permission"]

      assert result.governed_actors == [
               "MoD: Commanding Officer",
               "MoD: ODH",
               "MoD: Contractor",
               "MoD: Defence Safety Authority"
             ]

      # Phase 2 ignored
      refute Map.has_key?(result, :obligation_strength)
      refute Map.has_key?(result, :modal_verb)
      refute Map.has_key?(result, :clause_refined)

      # section_id not included
      refute Map.has_key?(result, :section_id)

      # All atom keys
      assert Enum.all?(Map.keys(result), &is_atom/1)
    end
  end

  describe "parse_references/1" do
    test "parses JSON array" do
      json =
        ~s([{"target_type": "legislation", "target_id": "UK_uksi_1989_635", "citation": "Electricity at Work Regulations 1989"}])

      result = SecondaryTaxaSubscriber.parse_references(json)

      assert length(result) == 1
      assert hd(result)["target_type"] == "legislation"
      assert hd(result)["target_id"] == "UK_uksi_1989_635"
      assert hd(result)["citation"] == "Electricity at Work Regulations 1989"
    end

    test "parses DuckDB struct syntax" do
      duckdb =
        "[{'target_type': legislation, 'target_id': UK_uksi_1989_635, 'citation': Electricity at Work Regulations 1989}]"

      result = SecondaryTaxaSubscriber.parse_references(duckdb)

      assert length(result) == 1
      assert hd(result)["target_type"] == "legislation"
      assert hd(result)["target_id"] == "UK_uksi_1989_635"
      assert hd(result)["citation"] == "Electricity at Work Regulations 1989"
    end

    test "parses multiple references" do
      json =
        ~s([{"target_type": "legislation", "target_id": "UK_uksi_1989_635", "citation": "EWR 1989"}, {"target_type": "jsp", "target_id": "JSP-375-CH08", "citation": "JSP 375 Ch 8"}])

      result = SecondaryTaxaSubscriber.parse_references(json)

      assert length(result) == 2
      assert Enum.at(result, 0)["target_type"] == "legislation"
      assert Enum.at(result, 1)["target_type"] == "jsp"
    end

    test "returns empty list for nil" do
      assert SecondaryTaxaSubscriber.parse_references(nil) == []
    end

    test "returns empty list for empty string" do
      assert SecondaryTaxaSubscriber.parse_references("") == []
    end

    test "passes through list values" do
      refs = [%{"target_type" => "legislation", "target_id" => "UK_uksi_1989_635"}]
      assert SecondaryTaxaSubscriber.parse_references(refs) == refs
    end

    test "returns empty list for unparseable string" do
      assert SecondaryTaxaSubscriber.parse_references("not valid at all") == []
    end

    test "DuckDB with unquoted citation" do
      duckdb =
        "[{'target_type': legislation, 'target_id': UK_ukpga_1974_37, 'citation': Health and Safety at Work etc. Act 1974}]"

      result = SecondaryTaxaSubscriber.parse_references(duckdb)

      assert length(result) == 1
      assert hd(result)["target_id"] == "UK_ukpga_1974_37"
      assert hd(result)["citation"] == "Health and Safety at Work etc. Act 1974"
    end

    test "DuckDB with single-quoted value containing commas" do
      duckdb =
        "[{'target_type': jsp, 'target_id': JSP-375-CH03, 'citation': 'JSP 375 Volume 3, Chapter 3'}]"

      result = SecondaryTaxaSubscriber.parse_references(duckdb)

      assert length(result) == 1
      assert hd(result)["target_type"] == "jsp"
      assert hd(result)["target_id"] == "JSP-375-CH03"
      assert hd(result)["citation"] == "JSP 375 Volume 3, Chapter 3"
    end

    test "DuckDB multiple structs with mixed quoting" do
      duckdb =
        "[{'target_type': legislation, 'target_id': UK_uksi_1989_635, 'citation': the Electricity at Work Regulations 1989}, {'target_type': jsp, 'target_id': JSP-375-CH08, 'citation': 'JSP 375 Volume 1, Chapter 8'}]"

      result = SecondaryTaxaSubscriber.parse_references(duckdb)

      assert length(result) == 2
      assert Enum.at(result, 0)["target_type"] == "legislation"
      assert Enum.at(result, 0)["target_id"] == "UK_uksi_1989_635"
      assert Enum.at(result, 1)["target_type"] == "jsp"
      assert Enum.at(result, 1)["citation"] == "JSP 375 Volume 1, Chapter 8"
    end
  end
end
