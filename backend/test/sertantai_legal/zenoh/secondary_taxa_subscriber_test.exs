defmodule SertantaiLegal.Zenoh.SecondaryTaxaSubscriberTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Zenoh.SecondaryTaxaSubscriber

  describe "normalize_taxa/1" do
    test "maps drrp_types directly" do
      row = %{
        "drrp_types" => ["Obligation", "Recommendation"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation", "Recommendation"]
    end

    test "maps governed_actors directly" do
      row = %{
        "governed_actors" => ["CO", "ODH", "Contractor"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "ODH", "Contractor"]
    end

    test "merges government_actors into governed_actors" do
      row = %{
        "governed_actors" => ["CO", "ODH"],
        "government_actors" => ["DSA", "Minister"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "ODH", "DSA", "Minister"]
    end

    test "government_actors alone populates governed_actors" do
      row = %{
        "government_actors" => ["DSA"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["DSA"]
    end

    test "deduplicates when merging government_actors" do
      row = %{
        "governed_actors" => ["CO", "DSA"],
        "government_actors" => ["DSA", "Minister"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.governed_actors == ["CO", "DSA", "Minister"]
    end

    test "ignores Phase 2 columns" do
      row = %{
        "drrp_types" => ["Obligation"],
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
        "drrp_types" => ["Obligation"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      refute Map.has_key?(result, :section_id)
      assert result.drrp_types == ["Obligation"]
    end

    test "ignores unknown columns" do
      row = %{
        "drrp_types" => ["Obligation"],
        "some_future_column" => "unexpected"
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Obligation"]
      refute Map.has_key?(result, :some_future_column)
      refute Map.has_key?(result, "some_future_column")
    end

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
        "drrp_types" => ["Obligation"],
        "governed_actors" => ["CO"],
        "government_actors" => ["DSA"]
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      assert Enum.all?(Map.keys(result), &is_atom/1)
    end

    test "full realistic secondary source payload" do
      row = %{
        "section_id" => "JSP_mod_2026_JSP375CH23:part-1-directive/policy-statements.para.23",
        "drrp_types" => ["Obligation", "Permission"],
        "governed_actors" => ["CO", "ODH", "Contractor"],
        "government_actors" => ["DSA"],
        "obligation_strength" => "Mandatory",
        "modal_verb" => "shall",
        "clause_refined" => "As part of the risk assessment the commander must..."
      }

      result = SecondaryTaxaSubscriber.normalize_taxa(row)

      # Mapped fields
      assert result.drrp_types == ["Obligation", "Permission"]
      assert result.governed_actors == ["CO", "ODH", "Contractor", "DSA"]

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
end
