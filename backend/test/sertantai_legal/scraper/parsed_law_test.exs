defmodule SertantaiLegal.Scraper.ParsedLawTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ParsedLaw

  describe "from_map/1" do
    test "creates struct from map with lowercase keys" do
      map = %{
        title_en: "Test Act 2024",
        year: 2024,
        number: "123",
        type_code: "uksi"
      }

      law = ParsedLaw.from_map(map)

      assert law.title_en == "Test Act 2024"
      assert law.year == 2024
      assert law.number == "123"
      assert law.type_code == "uksi"
    end

    test "normalizes capitalized keys to lowercase" do
      map = %{
        "Title_EN" => "Test Act 2024",
        "Year" => 2024,
        "Number" => "123"
      }

      law = ParsedLaw.from_map(map)

      assert law.title_en == "Test Act 2024"
      assert law.year == 2024
      assert law.number == "123"
    end

    test "normalizes atom capitalized keys" do
      map = %{
        Title_EN: "Test Act 2024",
        Year: 2024,
        Number: "123"
      }

      law = ParsedLaw.from_map(map)

      assert law.title_en == "Test Act 2024"
      assert law.year == 2024
      assert law.number == "123"
    end

    test "handles mixed key formats" do
      map = %{
        "Title_EN" => "Test Act",
        :year => 2024,
        "type_code" => "uksi",
        Number: "456"
      }

      law = ParsedLaw.from_map(map)

      assert law.title_en == "Test Act"
      assert law.year == 2024
      assert law.type_code == "uksi"
      assert law.number == "456"
    end

    test "converts string year to integer" do
      law = ParsedLaw.from_map(%{year: "2024"})
      assert law.year == 2024
    end

    test "converts float year to integer" do
      law = ParsedLaw.from_map(%{year: 2024.0})
      assert law.year == 2024
    end

    test "handles si_code as list" do
      law = ParsedLaw.from_map(%{si_code: ["CODE1", "CODE2"]})
      assert law.si_code == ["CODE1", "CODE2"]
    end

    test "unwraps si_code from JSONB values format" do
      law = ParsedLaw.from_map(%{si_code: %{"values" => ["CODE1", "CODE2"]}})
      assert law.si_code == ["CODE1", "CODE2"]
    end

    test "unwraps role_gvt from JSONB key map format" do
      law = ParsedLaw.from_map(%{role_gvt: %{"Secretary of State" => true, "Minister" => true}})
      assert Enum.sort(law.role_gvt) == ["Minister", "Secretary of State"]
    end

    test "handles date strings" do
      law = ParsedLaw.from_map(%{md_date: "2024-01-15"})
      assert law.md_date == ~D[2024-01-15]
    end

    test "handles Date structs" do
      law = ParsedLaw.from_map(%{md_date: ~D[2024-01-15]})
      assert law.md_date == ~D[2024-01-15]
    end

    test "handles boolean values" do
      law = ParsedLaw.from_map(%{is_making: true, is_amending: false})
      assert law.is_making == true
      assert law.is_amending == false
    end

    test "handles boolean string values" do
      law = ParsedLaw.from_map(%{is_making: "true", is_amending: "false"})
      assert law.is_making == true
      assert law.is_amending == false
    end

    test "initializes list fields to empty list when nil" do
      law = ParsedLaw.from_map(%{})

      assert law.si_code == []
      assert law.enacted_by == []
      assert law.amending == []
      assert law.role == []
    end

    test "maps legacy donor field names - atom keys" do
      map = %{
        actor: ["Employer", "Employee"],
        actor_gvt: ["Secretary of State"]
      }

      law = ParsedLaw.from_map(map)

      assert law.role == ["Employer", "Employee"]
      assert law.role_gvt == ["Secretary of State"]
    end

    test "maps legacy donor field names - string keys" do
      map = %{
        "Revoking" => ["UK_uksi_2020_100"],
        "Revoked_by" => ["UK_uksi_2024_200"]
      }

      law = ParsedLaw.from_map(map)

      assert law.rescinding == ["UK_uksi_2020_100"]
      assert law.rescinded_by == ["UK_uksi_2024_200"]
    end

    test "converts empty string to nil for string fields" do
      law = ParsedLaw.from_map(%{title_en: ""})
      assert law.title_en == nil
    end
  end

  describe "merge/2" do
    test "merges new data into existing law" do
      law = ParsedLaw.from_map(%{title_en: "Test Act", year: 2024})
      merged = ParsedLaw.merge(law, %{si_code: ["CODE1"], type_code: "uksi"})

      assert merged.title_en == "Test Act"
      assert merged.year == 2024
      assert merged.si_code == ["CODE1"]
      assert merged.type_code == "uksi"
    end

    test "preserves existing values when new is nil" do
      law = ParsedLaw.from_map(%{title_en: "Test Act", year: 2024})
      merged = ParsedLaw.merge(law, %{title_en: nil, si_code: ["CODE1"]})

      assert merged.title_en == "Test Act"
      assert merged.si_code == ["CODE1"]
    end

    test "preserves existing values when new is empty list" do
      law = ParsedLaw.from_map(%{si_code: ["EXISTING"]})
      merged = ParsedLaw.merge(law, %{si_code: [], title_en: "New Title"})

      assert merged.si_code == ["EXISTING"]
      assert merged.title_en == "New Title"
    end

    test "preserves existing values when new is empty string" do
      law = ParsedLaw.from_map(%{title_en: "Existing Title"})
      merged = ParsedLaw.merge(law, %{title_en: "", year: 2024})

      assert merged.title_en == "Existing Title"
      assert merged.year == 2024
    end

    test "normalizes keys in merge data" do
      law = ParsedLaw.from_map(%{})
      merged = ParsedLaw.merge(law, %{"Title_EN" => "From Merge", "Year" => 2024})

      assert merged.title_en == "From Merge"
      assert merged.year == 2024
    end
  end

  describe "to_db_attrs/1" do
    test "converts struct to map" do
      law = ParsedLaw.from_map(%{title_en: "Test", year: 2024})
      attrs = ParsedLaw.to_db_attrs(law)

      assert is_map(attrs)
      assert attrs[:title_en] == "Test"
      assert attrs[:year] == 2024
    end

    test "wraps si_code in values JSONB format" do
      law = ParsedLaw.from_map(%{si_code: ["CODE1", "CODE2"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:si_code] == %{"values" => ["CODE1", "CODE2"]}
    end

    test "wraps md_subjects in values JSONB format" do
      law = ParsedLaw.from_map(%{md_subjects: ["Subject1", "Subject2"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:md_subjects] == %{"values" => ["Subject1", "Subject2"]}
    end

    test "wraps duty_type in values JSONB format" do
      law = ParsedLaw.from_map(%{duty_type: ["Type1", "Type2"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:duty_type] == %{"values" => ["Type1", "Type2"]}
    end

    test "wraps role_gvt in key map JSONB format" do
      law = ParsedLaw.from_map(%{role_gvt: ["Secretary of State", "Minister"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:role_gvt] == %{"Secretary of State" => true, "Minister" => true}
    end

    test "wraps duty_holder in key map JSONB format" do
      law = ParsedLaw.from_map(%{duty_holder: ["Employer", "Owner"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:duty_holder] == %{"Employer" => true, "Owner" => true}
    end

    test "wraps all holder fields in key map JSONB format" do
      law =
        ParsedLaw.from_map(%{
          duty_holder: ["Duty1"],
          rights_holder: ["Rights1"],
          responsibility_holder: ["Resp1"],
          power_holder: ["Power1"],
          popimar: ["Popimar1"]
        })

      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:duty_holder] == %{"Duty1" => true}
      assert attrs[:rights_holder] == %{"Rights1" => true}
      assert attrs[:responsibility_holder] == %{"Resp1" => true}
      assert attrs[:power_holder] == %{"Power1" => true}
      assert attrs[:popimar] == %{"Popimar1" => true}
    end

    test "excludes nil values" do
      law = ParsedLaw.from_map(%{title_en: "Test"})
      attrs = ParsedLaw.to_db_attrs(law)

      refute Map.has_key?(attrs, :year)
      refute Map.has_key?(attrs, :family)
    end

    test "excludes empty lists" do
      law = ParsedLaw.from_map(%{title_en: "Test", si_code: []})
      attrs = ParsedLaw.to_db_attrs(law)

      refute Map.has_key?(attrs, :si_code)
    end

    test "excludes internal fields" do
      law = ParsedLaw.from_map(%{title_en: "Test"})
      law = %{law | parse_stages: %{metadata: :ok}, parse_errors: ["error"]}
      attrs = ParsedLaw.to_db_attrs(law)

      refute Map.has_key?(attrs, :parse_stages)
      refute Map.has_key?(attrs, :parse_errors)
    end

    test "keeps array fields as arrays" do
      law = ParsedLaw.from_map(%{role: ["Role1", "Role2"], enacted_by: ["UK_ukpga_2020_1"]})
      attrs = ParsedLaw.to_db_attrs(law)

      assert attrs[:role] == ["Role1", "Role2"]
      assert attrs[:enacted_by] == ["UK_ukpga_2020_1"]
    end
  end

  describe "to_comparison_map/1" do
    test "keeps lists as lists (no JSONB wrapping)" do
      law = ParsedLaw.from_map(%{si_code: ["CODE1"], role_gvt: ["Minister"]})
      map = ParsedLaw.to_comparison_map(law)

      assert map[:si_code] == ["CODE1"]
      assert map[:role_gvt] == ["Minister"]
    end

    test "excludes internal fields" do
      law = %{ParsedLaw.from_map(%{}) | parse_stages: %{test: :ok}}
      map = ParsedLaw.to_comparison_map(law)

      refute Map.has_key?(map, :parse_stages)
    end
  end

  describe "from_db_record/1" do
    test "unwraps JSONB values format" do
      record = %{
        title_en: "Test",
        si_code: %{"values" => ["CODE1", "CODE2"]}
      }

      law = ParsedLaw.from_db_record(record)

      assert law.si_code == ["CODE1", "CODE2"]
    end

    test "unwraps JSONB key map format" do
      record = %{
        title_en: "Test",
        role_gvt: %{"Secretary of State" => true, "Minister" => true}
      }

      law = ParsedLaw.from_db_record(record)

      assert Enum.sort(law.role_gvt) == ["Minister", "Secretary of State"]
    end

    test "handles struct input" do
      # Simulate a UkLrt struct
      record = %{
        __struct__: SertantaiLegal.Legal.UkLrt,
        __meta__: %{},
        id: "test-id",
        title_en: "Test Act",
        si_code: %{"values" => ["CODE"]},
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      law = ParsedLaw.from_db_record(record)

      assert law.title_en == "Test Act"
      assert law.si_code == ["CODE"]
    end
  end

  describe "struct_fields/0" do
    test "returns list of field names" do
      fields = ParsedLaw.struct_fields()

      assert is_list(fields)
      assert :title_en in fields
      assert :year in fields
      assert :si_code in fields
      assert :parse_stages in fields
    end

    test "does not include __struct__" do
      fields = ParsedLaw.struct_fields()

      refute :__struct__ in fields
    end
  end

  describe "roundtrip: from_map -> to_db_attrs -> from_db_record" do
    test "preserves data through full roundtrip" do
      original = %{
        title_en: "Test Act 2024",
        year: 2024,
        number: "123",
        type_code: "uksi",
        si_code: ["CODE1", "CODE2"],
        role_gvt: ["Secretary of State"],
        duty_holder: ["Employer"],
        enacted_by: ["UK_ukpga_2020_1"],
        md_date: ~D[2024-01-15],
        is_making: true
      }

      # Create struct from original
      law = ParsedLaw.from_map(original)

      # Convert to DB format
      db_attrs = ParsedLaw.to_db_attrs(law)

      # Simulate reading back from DB (with JSONB format)
      restored = ParsedLaw.from_db_record(db_attrs)

      # Verify all values match
      assert restored.title_en == "Test Act 2024"
      assert restored.year == 2024
      assert restored.number == "123"
      assert restored.type_code == "uksi"
      assert restored.si_code == ["CODE1", "CODE2"]
      assert restored.role_gvt == ["Secretary of State"]
      assert restored.duty_holder == ["Employer"]
      assert restored.enacted_by == ["UK_ukpga_2020_1"]
      assert restored.md_date == ~D[2024-01-15]
      assert restored.is_making == true
    end
  end
end
