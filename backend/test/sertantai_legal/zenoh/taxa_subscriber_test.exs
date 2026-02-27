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

    test "all known taxa field atoms are resolvable" do
      fields = ~w(duty_holder rights_holder responsibility_holder power_holder
                  duty_type role role_gvt duties rights responsibilities powers)

      for field <- fields do
        assert String.to_existing_atom(field),
               "atom :#{field} should exist for String.to_existing_atom/1"
      end
    end
  end
end
