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
end
