defmodule SertantaiLegal.Zenoh.ProvisionSubscriberTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Zenoh.ProvisionSubscriber

  describe "normalize_taxa/1" do
    test "maps simple scalar and array fields" do
      row = %{
        "drrp_types" => ["DUTY"],
        "duty_family" => "General Safety",
        "extraction_method" => "regex",
        "taxa_confidence" => 0.95
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["DUTY"]
      assert result.duty_family == "General Safety"
      assert result.extraction_method == "regex"
      assert result.taxa_confidence == 0.95
    end

    test "maps actors struct column as array of maps with role enrichment" do
      row = %{
        "actors" => [
          %{
            "label" => "Org: Employer",
            "position" => "active",
            "relates_to" => nil,
            "label_source" => "canonical",
            "reason" => nil
          },
          %{
            "label" => "Ind: Employee",
            "position" => "counterparty",
            "relates_to" => nil,
            "label_source" => "canonical",
            "reason" => nil
          }
        ]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert length(result.actors) == 2
      assert hd(result.actors)["label"] == "Org: Employer"
      assert hd(result.actors)["position"] == "active"
      assert hd(result.actors)["role"] == "governed"
    end

    test "enriches government actors with role" do
      row = %{
        "actors" => [
          %{"label" => "Gvt: Minister", "position" => "active"},
          %{"label" => "Crown", "position" => "mentioned"},
          %{"label" => "HM Forces", "position" => "mentioned"},
          %{"label" => "Org: Employer", "position" => "active"}
        ]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      roles = Enum.map(result.actors, & &1["role"])
      assert roles == ["government", "government", "government", "governed"]
    end

    test "enriches actors from JSON string with role" do
      actors_json =
        Jason.encode!([
          %{"label" => "EU: Commission", "position" => "active"},
          %{"label" => "Ind: Person", "position" => "mentioned"}
        ])

      row = %{"actors" => actors_json}
      result = ProvisionSubscriber.normalize_taxa(row)

      assert length(result.actors) == 2
      assert Enum.at(result.actors, 0)["role"] == "government"
      assert Enum.at(result.actors, 1)["role"] == "governed"
    end

    test "maps holder_inferred_from and ancestor_distance" do
      row = %{
        "extraction_method" => "inherited",
        "holder_inferred_from" => "parent",
        "ancestor_distance" => 2
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.extraction_method == "inherited"
      assert result.holder_inferred_from == "parent"
      assert result.ancestor_distance == 2
    end

    test "omits nil values from result" do
      row = %{
        "drrp_types" => ["DUTY"],
        "duty_family" => nil,
        "holder_inferred_from" => nil,
        "ancestor_distance" => nil,
        "actors" => nil
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["DUTY"]
      refute Map.has_key?(result, :duty_family)
      refute Map.has_key?(result, :holder_inferred_from)
      refute Map.has_key?(result, :ancestor_distance)
      refute Map.has_key?(result, :actors)
    end

    test "ignores unknown columns" do
      row = %{
        "drrp_types" => ["DUTY"],
        "some_future_column" => "unexpected"
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["DUTY"]
      refute Map.has_key?(result, :some_future_column)
      refute Map.has_key?(result, "some_future_column")
    end

    test "all keys are atoms" do
      row = %{
        "drrp_types" => ["POWER"],
        "extraction_method" => "agentic",
        "holder_inferred_from" => "self",
        "ancestor_distance" => 0,
        "actors" => [%{"label" => "Spc: Inspector", "position" => "active"}]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert Enum.all?(Map.keys(result), &is_atom/1)
    end

    test "handles empty row" do
      assert ProvisionSubscriber.normalize_taxa(%{}) == %{}
    end

    test "full realistic provision payload" do
      row = %{
        "section_id" => "UK_ukpga_1974_37:s.2(1)",
        "drrp_types" => ["DUTY"],
        "duty_family" => "General Safety",
        "duty_sub_type" => "Absolute",
        "clause_refined" => "employer must ensure health and safety of employees",
        "purposes" => ["Application+Scope"],
        "popimar" => ["Organisation"],
        "taxa_confidence" => 0.92,
        "extraction_method" => "regex",
        "holder_inferred_from" => "self",
        "ancestor_distance" => nil,
        "actors" => [
          %{
            "label" => "Org: Employer",
            "position" => "active",
            "relates_to" => nil,
            "label_source" => "canonical",
            "reason" => nil
          },
          %{
            "label" => "Ind: Employee",
            "position" => "counterparty",
            "relates_to" => nil,
            "label_source" => "canonical",
            "reason" => nil
          }
        ]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      # section_id is NOT in @field_atoms — it's handled separately by upsert_provision
      refute Map.has_key?(result, :section_id)

      # Scalar fields
      assert result.duty_family == "General Safety"
      assert result.extraction_method == "regex"
      assert result.holder_inferred_from == "self"
      assert result.taxa_confidence == 0.92

      # nil ancestor_distance omitted
      refute Map.has_key?(result, :ancestor_distance)

      # Array fields
      assert result.drrp_types == ["DUTY"]

      # Struct column
      assert length(result.actors) == 2

      # All atom keys
      assert Enum.all?(Map.keys(result), &is_atom/1)
    end
  end

  describe "map_drrp_types/1 (#134)" do
    # Obligation mappings
    test "maps Obligation → Duty when provision has governed actor" do
      taxa = %{
        drrp_types: ["Obligation"],
        actors: [%{"label" => "Org: Employer", "role" => "governed"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Duty"]
    end

    test "maps Obligation → Responsibility when provision has only government actors" do
      taxa = %{
        drrp_types: ["Obligation"],
        actors: [%{"label" => "Gvt: Minister", "role" => "government"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Responsibility"]
    end

    # Liberty mappings
    test "maps Liberty → Right when provision has governed actor" do
      taxa = %{
        drrp_types: ["Liberty"],
        actors: [%{"label" => "Ind: Person", "role" => "governed"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Right"]
    end

    test "maps Liberty → Power when provision has only government actors" do
      taxa = %{
        drrp_types: ["Liberty"],
        actors: [%{"label" => "Gvt: Minister", "role" => "government"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Power"]
    end

    # Mixed actor priority: governed wins
    test "governed takes priority over government (Obligation → Duty)" do
      taxa = %{
        drrp_types: ["Obligation"],
        actors: [
          %{"label" => "Gvt: Agency: Health and Safety Executive", "role" => "government"},
          %{"label" => "Org: Employer", "role" => "governed"}
        ]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Duty"]
    end

    test "governed takes priority over government (Liberty → Right)" do
      taxa = %{
        drrp_types: ["Liberty"],
        actors: [
          %{"label" => "Gvt: Agency: Health and Safety Executive", "role" => "government"},
          %{"label" => "Ind: Person", "role" => "governed"}
        ]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Right"]
    end

    # Mixed drrp_types
    test "maps both Obligation and Liberty in same provision" do
      taxa = %{
        drrp_types: ["Obligation", "Liberty"],
        actors: [%{"label" => "Ind: Person", "role" => "governed"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Duty", "Right"]
    end

    test "maps both with government-only actors" do
      taxa = %{
        drrp_types: ["Obligation", "Liberty"],
        actors: [%{"label" => "Gvt: Minister", "role" => "government"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Responsibility", "Power"]
    end

    # Edge cases
    test "passes through when no drrp_types" do
      taxa = %{actors: [%{"label" => "Ind: Person", "role" => "governed"}]}

      result = ProvisionSubscriber.map_drrp_types(taxa)

      refute Map.has_key?(result, :drrp_types)
    end

    test "passes through when no actors" do
      taxa = %{drrp_types: ["Liberty"]}

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Liberty"]
    end

    test "does not touch already-mapped DRRP types" do
      taxa = %{
        drrp_types: ["Duty", "Right"],
        actors: [%{"label" => "Org: Employer", "role" => "governed"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Duty", "Right"]
    end

    test "works with atom-keyed actor maps" do
      taxa = %{
        drrp_types: ["Obligation"],
        actors: [%{label: "Org: Employer", role: "governed"}]
      }

      result = ProvisionSubscriber.map_drrp_types(taxa)

      assert result.drrp_types == ["Duty"]
    end

    # End-to-end through normalize_taxa
    test "normalize_taxa maps Obligation → Duty end-to-end" do
      row = %{
        "drrp_types" => ["Obligation"],
        "duty_family" => "Governed",
        "actors" => [%{"label" => "Org: Employer", "position" => "active"}]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Duty"]
      assert hd(result.actors)["role"] == "governed"
    end

    test "normalize_taxa maps Liberty → Right end-to-end" do
      row = %{
        "drrp_types" => ["Liberty"],
        "duty_family" => "Governed",
        "duty_sub_type" => "Prohibitive",
        "actors" => [%{"label" => "Ind: Person", "position" => "active"}]
      }

      result = ProvisionSubscriber.normalize_taxa(row)

      assert result.drrp_types == ["Right"]
      assert hd(result.actors)["role"] == "governed"
    end
  end
end
