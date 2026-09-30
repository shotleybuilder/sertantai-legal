defmodule SertantaiLegal.Legal.ActorDictionaryTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Legal.ActorDictionary

  # The GenServer is started by the application supervisor.
  # These tests run against the snapshot-loaded dictionary.

  describe "canonical_labels/0" do
    test "returns a non-empty list" do
      labels = ActorDictionary.canonical_labels()
      assert length(labels) > 100
    end

    test "snapshot carries fractalaw's newer labels" do
      labels = ActorDictionary.canonical_labels()
      assert "Gvt: Devolved Admin: Scottish Ministers" in labels
      assert "Ind: Person in Control" in labels
    end

    test "includes known actors" do
      labels = ActorDictionary.canonical_labels()
      assert "Org: Employer" in labels
      assert "Ind: Employee" in labels
      assert "Gvt: Minister" in labels
    end

    test "labels are sorted" do
      labels = ActorDictionary.canonical_labels()
      assert labels == Enum.sort(labels)
    end
  end

  describe "governed_labels/0" do
    test "includes Org and Ind actors" do
      labels = ActorDictionary.governed_labels()
      assert "Org: Employer" in labels
      assert "Ind: Employee" in labels
    end

    test "excludes Gvt and EU actors" do
      labels = ActorDictionary.governed_labels()
      refute Enum.any?(labels, &String.starts_with?(&1, "Gvt:"))
      refute Enum.any?(labels, &String.starts_with?(&1, "EU:"))
    end
  end

  describe "government_labels/0" do
    test "includes Gvt and EU actors" do
      labels = ActorDictionary.government_labels()
      assert Enum.any?(labels, &String.starts_with?(&1, "Gvt:"))
      assert Enum.any?(labels, &String.starts_with?(&1, "EU:"))
    end

    test "excludes Org and Ind actors" do
      labels = ActorDictionary.government_labels()
      refute Enum.any?(labels, &String.starts_with?(&1, "Org:"))
      refute Enum.any?(labels, &String.starts_with?(&1, "Ind:"))
    end
  end

  describe "category/1" do
    test "returns category for known label" do
      assert ActorDictionary.category("Org: Employer") == "Org"
      assert ActorDictionary.category("Gvt: Minister") == "Gvt"
    end

    test "returns nil for unknown label" do
      assert ActorDictionary.category("Nonexistent Actor") == nil
    end
  end

  describe "valid?/1" do
    test "true for dictionary labels" do
      assert ActorDictionary.valid?("Org: Employer")
      assert ActorDictionary.valid?("Ind: Employee")
    end

    test "false for invented labels" do
      refute ActorDictionary.valid?("Org_Employer")
      refute ActorDictionary.valid?("Some Random Actor")
    end
  end

  describe "government?/1" do
    test "true for Gvt/EU labels" do
      assert ActorDictionary.government?("Gvt: Minister")
      assert ActorDictionary.government?("EU: Commission")
    end

    test "false for governed labels" do
      refute ActorDictionary.government?("Org: Employer")
      refute ActorDictionary.government?("Ind: Employee")
    end

    test "government by the dictionary type, not the prefix (Crown, HM Forces, Notifying Authority)" do
      assert ActorDictionary.government?("Crown")
      assert ActorDictionary.government?("HM Forces")
      assert ActorDictionary.government?("Spc: Notifying Authority")
      refute ActorDictionary.government?("Spc: Inspector")
      assert "Crown" in ActorDictionary.government_labels()
      refute "Crown" in ActorDictionary.governed_labels()
    end
  end

  describe "agreement with ActorDefinitions" do
    test "legal's role rule matches the dictionary type for every label" do
      mismatches =
        for label <- ActorDictionary.canonical_labels(),
            ActorDictionary.government?(label) !=
              SertantaiLegal.Legal.Taxa.ActorDefinitions.government_label?(label),
            do: label

      assert mismatches == [],
             "fractalaw's dictionary and ActorDefinitions disagree on: #{inspect(mismatches)}"
    end
  end

  describe "normalize_entries/1" do
    test "reads fractalaw's format (label, type) and the older one (canonical)" do
      entries = [
        %{
          "label" => "Crown",
          "type" => "government",
          "category" => "other",
          "triggers" => ["crown"]
        },
        %{"label" => "Ind: Claimant", "type" => "governed", "category" => "Ind"},
        %{"canonical" => "Gvt: Minister", "category" => "Gvt", "triggers" => ["minister"]},
        %{"category" => "Org"}
      ]

      assert ActorDictionary.normalize_entries(entries) == [
               {"Crown", "other", ["crown"], true},
               {"Ind: Claimant", "Ind", [], false},
               {"Gvt: Minister", "Gvt", ["minister"], true}
             ]
    end
  end

  describe "categories/0" do
    test "returns map of category → labels" do
      cats = ActorDictionary.categories()
      assert is_map(cats)
      assert Map.has_key?(cats, "Org")
      assert Map.has_key?(cats, "Gvt")
      assert "Org: Employer" in cats["Org"]
    end
  end

  describe "count/0" do
    test "matches canonical_labels length" do
      assert ActorDictionary.count() == length(ActorDictionary.canonical_labels())
    end
  end
end
