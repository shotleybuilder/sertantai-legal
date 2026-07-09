defmodule SertantaiLegal.Zenoh.TaxaSubscriberTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Zenoh.TaxaSubscriber

  describe "normalize_taxa/1" do
    test "converts holder map fields to %{values: list} format" do
      row = %{
        "duty_holder" => ["Employer", "Occupier"],
        "rights_holder" => ["Employee"],
        "responsibility_holder" => nil,
        "power_holder" => nil,
        "duty_type" => ["Absolute"],
        "role" => nil,
        "role_gvt" => nil,
        "duties" => nil,
        "rights" => nil,
        "responsibilities" => nil,
        "powers" => nil
      }

      result = TaxaSubscriber.normalize_taxa(row)

      assert result.duty_holder == %{values: ["Employer", "Occupier"]}
      assert result.rights_holder == %{values: ["Employee"]}
      assert result.duty_type == %{values: ["Absolute"]}
      refute Map.has_key?(result, :responsibility_holder)
      refute Map.has_key?(result, :power_holder)
    end

    test "converts role as plain list (not wrapped in values map)" do
      row = %{"role" => ["Regulator", "Inspector"]}

      result = TaxaSubscriber.normalize_taxa(row)

      assert result.role == ["Regulator", "Inspector"]
    end

    test "converts entries map fields to %{entries: list} format" do
      row = %{
        "duties" => [
          %{"holder" => "Employer", "duty_type" => "Absolute", "clause" => "s.2(1)"}
        ],
        "rights" => [],
        "responsibilities" => nil,
        "powers" => nil
      }

      result = TaxaSubscriber.normalize_taxa(row)

      assert %{entries: [%{"holder" => "Employer"}]} = result.duties
      assert result.rights == %{entries: []}
      refute Map.has_key?(result, :responsibilities)
    end

    test "handles completely empty row" do
      row = %{}

      result = TaxaSubscriber.normalize_taxa(row)

      assert result == %{}
    end

    test "ignores unknown columns from Arrow payload" do
      row = %{
        "duty_holder" => ["Employer"],
        "some_new_column" => ["unexpected"]
      }

      result = TaxaSubscriber.normalize_taxa(row)

      assert result.duty_holder == %{values: ["Employer"]}
      refute Map.has_key?(result, :some_new_column)
      refute Map.has_key?(result, "some_new_column")
    end

    test "all holder map fields produce atom keys" do
      row = %{
        "duty_holder" => ["A"],
        "rights_holder" => ["B"],
        "responsibility_holder" => ["C"],
        "power_holder" => ["D"],
        "duty_type" => ["E"],
        "role_gvt" => ["F"]
      }

      result = TaxaSubscriber.normalize_taxa(row)

      for key <- [
            :duty_holder,
            :rights_holder,
            :responsibility_holder,
            :power_holder,
            :duty_type,
            :role_gvt
          ] do
        assert Map.has_key?(result, key), "expected atom key #{inspect(key)} in result"
        assert %{values: [_]} = result[key]
      end
    end

    test "all entries map fields produce atom keys" do
      row = %{
        "duties" => [%{"clause" => "s.1"}],
        "rights" => [%{"clause" => "s.2"}],
        "responsibilities" => [%{"clause" => "s.3"}],
        "powers" => [%{"clause" => "s.4"}]
      }

      result = TaxaSubscriber.normalize_taxa(row)

      for key <- [:duties, :rights, :responsibilities, :powers] do
        assert Map.has_key?(result, key), "expected atom key #{inspect(key)} in result"
        assert %{entries: [_]} = result[key]
      end
    end

    test "full realistic payload" do
      row = %{
        "duty_holder" => ["Employer", "Self-employed person"],
        "rights_holder" => ["Employee"],
        "responsibility_holder" => nil,
        "power_holder" => ["HSE Inspector"],
        "duty_type" => ["Absolute", "Qualified"],
        "role" => ["Regulator"],
        "role_gvt" => ["Secretary of State"],
        "duties" => [
          %{
            "holder" => "Employer",
            "duty_type" => "Absolute",
            "clause" => "s.2(1)",
            "article" => nil
          },
          %{
            "holder" => "Self-employed",
            "duty_type" => "Qualified",
            "clause" => "s.3(2)",
            "article" => nil
          }
        ],
        "rights" => [],
        "responsibilities" => nil,
        "powers" => [
          %{
            "holder" => "HSE Inspector",
            "duty_type" => nil,
            "clause" => "s.20(1)",
            "article" => nil
          }
        ]
      }

      result = TaxaSubscriber.normalize_taxa(row)

      # Holder maps
      assert result.duty_holder == %{values: ["Employer", "Self-employed person"]}
      assert result.rights_holder == %{values: ["Employee"]}
      assert result.power_holder == %{values: ["HSE Inspector"]}
      assert result.duty_type == %{values: ["Absolute", "Qualified"]}
      assert result.role_gvt == %{values: ["Secretary of State"]}
      refute Map.has_key?(result, :responsibility_holder)

      # List field
      assert result.role == ["Regulator"]

      # Entries maps
      assert length(result.duties.entries) == 2
      assert result.rights == %{entries: []}
      refute Map.has_key?(result, :responsibilities)
      assert length(result.powers.entries) == 1

      # All keys are atoms
      assert Enum.all?(Map.keys(result), &is_atom/1)
    end
  end

  describe "derive_enrichment_result/2 (via normalize + derive)" do
    # derive_enrichment_result is private, so we test via the module's
    # classify_enrichment/2 helper (exposed for testing).
    # These tests document the DRRP vocabulary contract.

    test "duty_type with 'Duty' → Making" do
      taxa = %{duty_type: %{values: ["Duty", "Power"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == true
      assert result.function == %{"Making" => true}
    end

    test "duty_type with 'Responsibility' → Making" do
      taxa = %{duty_type: %{values: ["Responsibility"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == true
      assert result.function == %{"Making" => true}
    end

    test "duty_type with 'Obligation' → Making (new DRRP vocabulary)" do
      taxa = %{duty_type: %{values: ["Obligation", "Liberty"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == true,
             "Obligation should be treated as making — this is the new DRRP vocabulary equivalent of Duty"

      assert result.function == %{"Making" => true}
    end

    test "duty_type with only 'Power' → Empowering" do
      taxa = %{duty_type: %{values: ["Power"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == false
      assert result.function == %{"Empowering" => true}
    end

    test "duty_type with only 'Liberty' → Empowering" do
      taxa = %{duty_type: %{values: ["Liberty"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == false
      assert result.function == %{"Empowering" => true}
    end

    test "duty_type with only 'Right' → Empowering" do
      taxa = %{duty_type: %{values: ["Right"]}}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == false
      assert result.function == %{"Empowering" => true}
    end

    test "empty taxa → Housekeeping" do
      taxa = %{}
      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.function == %{"Housekeeping" => true}
    end

    test "preserves existing relationship function labels" do
      taxa = %{duty_type: %{values: ["Duty"]}}

      record = %{
        function: %{"Amending Maker" => true, "Revoking" => true},
        duties: nil,
        rights: nil,
        responsibilities: nil,
        powers: nil
      }

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == true
      assert result.function == %{"Making" => true, "Amending Maker" => true, "Revoking" => true}
    end

    test "replaces existing enrichment label" do
      taxa = %{duty_type: %{values: ["Obligation"]}}

      record = %{
        function: %{"Empowering" => true, "Amending" => true},
        duties: nil,
        rights: nil,
        responsibilities: nil,
        powers: nil
      }

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert result.is_making == true
      assert result.function == %{"Making" => true, "Amending" => true}
      refute Map.has_key?(result.function, "Empowering")
    end
  end

  describe "convert_duty_type (via classify_enrichment)" do
    test "derives Duty from duties entries" do
      taxa = %{
        duty_type: %{values: ["Obligation"]},
        duties: %{entries: [%{"holder" => "Employer", "clause" => "s.2(1)"}]},
        rights: %{entries: []},
        responsibilities: nil,
        powers: nil
      }

      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert %{values: values} = result.duty_type
      assert "Duty" in values
      refute "Obligation" in values
      assert result.is_making == true
    end

    test "derives Right from rights entries" do
      taxa = %{
        duty_type: %{values: ["Liberty"]},
        duties: nil,
        rights: %{entries: [%{"holder" => "Employee", "clause" => "s.5"}]},
        responsibilities: nil,
        powers: nil
      }

      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert %{values: values} = result.duty_type
      assert "Right" in values
      refute "Liberty" in values
    end

    test "derives all four DRRP types from mixed entries" do
      taxa = %{
        duty_type: %{values: ["Obligation", "Liberty"]},
        duties: %{entries: [%{"holder" => "Employer"}]},
        rights: %{entries: [%{"holder" => "Employee"}]},
        responsibilities: %{entries: [%{"holder" => "HSE"}]},
        powers: %{entries: [%{"holder" => "Inspector"}]}
      }

      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert %{values: values} = result.duty_type
      assert "Duty" in values
      assert "Right" in values
      assert "Responsibility" in values
      assert "Power" in values
      refute "Obligation" in values
      refute "Liberty" in values
      assert result.is_making == true
    end

    test "falls back to raw duty_type when no structured entries anywhere" do
      taxa = %{
        duty_type: %{values: ["Obligation"]},
        duties: nil,
        rights: nil,
        responsibilities: nil,
        powers: nil
      }

      record = %{function: %{}, duties: nil, rights: nil, responsibilities: nil, powers: nil}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      # Raw Obligation kept as fallback, still classified as Making
      assert %{values: ["Obligation"]} = result.duty_type
      assert result.is_making == true
    end

    test "falls back to record's entries when taxa has none (amendment SI scenario)" do
      # Law-level enrichment arrives with no duties entries, but the record
      # already has duties from a prior provision-level enrichment
      taxa = %{
        duty_type: %{values: ["Obligation"]},
        duties: nil,
        rights: nil,
        responsibilities: nil,
        powers: nil
      }

      record = %{
        function: %{},
        duties: %{entries: [%{"holder" => "Operator", "clause" => "reg.6"}]},
        rights: nil,
        responsibilities: nil,
        powers: nil
      }

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert %{values: values} = result.duty_type
      assert "Duty" in values
      assert result.is_making == true
    end

    test "Confined Spaces scenario: Obligation vocab + duties entries → Making" do
      # Real-world case: Confined Spaces Regulations was misclassified as Empowering
      taxa = %{
        duty_type: %{values: ["Liberty", "Obligation"]},
        duty_holder: %{values: ["Org: Employer", "Ind: Self-employed Worker"]},
        rights_holder: %{values: ["Ind: Person"]},
        responsibility_holder: %{values: ["Gvt: Agency: Health and Safety Executive"]},
        power_holder: %{values: ["Gvt: Agency: Health and Safety Executive"]},
        duties: %{entries: [%{"holder" => "Employer", "clause" => "reg.4"}]},
        rights: %{entries: [%{"holder" => "Person", "clause" => "reg.5"}]},
        responsibilities: %{entries: [%{"holder" => "HSE", "clause" => "reg.10"}]},
        powers: %{entries: [%{"holder" => "Inspector", "clause" => "reg.11"}]}
      }

      record = %{function: %{"Empowering" => true}}

      result = TaxaSubscriber.classify_enrichment(record, taxa)

      assert %{values: values} = result.duty_type
      assert "Duty" in values
      assert "Responsibility" in values
      assert result.is_making == true
      assert result.function == %{"Making" => true}
      refute Map.has_key?(result.function, "Empowering")
    end
  end
end
