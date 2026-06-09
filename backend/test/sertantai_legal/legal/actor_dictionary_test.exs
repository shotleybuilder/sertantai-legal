defmodule SertantaiLegal.Legal.ActorDictionaryTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Legal.ActorDictionary

  # The GenServer is started by the application supervisor.
  # These tests run against the snapshot-loaded dictionary.

  describe "canonical_labels/0" do
    test "returns a non-empty list" do
      labels = ActorDictionary.canonical_labels()
      assert length(labels) > 50
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
