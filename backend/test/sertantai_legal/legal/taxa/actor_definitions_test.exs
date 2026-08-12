defmodule SertantaiLegal.Legal.Taxa.ActorDefinitionsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.ActorDefinitions

  describe "actor_role/1" do
    test "Gvt: prefixed labels are government" do
      assert ActorDefinitions.actor_role("Gvt: Minister") == "government"

      assert ActorDefinitions.actor_role("Gvt: Agency: Health and Safety Executive") ==
               "government"

      assert ActorDefinitions.actor_role("Gvt: Authority: Local") == "government"
      assert ActorDefinitions.actor_role("Gvt: Judiciary") == "government"
      assert ActorDefinitions.actor_role("Gvt: Officer") == "government"
      assert ActorDefinitions.actor_role("Gvt: Ministry: Treasury") == "government"
    end

    test "EU: prefixed labels are government" do
      assert ActorDefinitions.actor_role("EU: Commission") == "government"
      assert ActorDefinitions.actor_role("EU: Member State") == "government"
    end

    test "Crown is government" do
      assert ActorDefinitions.actor_role("Crown") == "government"
    end

    test "HM Forces labels are government" do
      assert ActorDefinitions.actor_role("HM Forces") == "government"
      assert ActorDefinitions.actor_role("HM Forces: Navy") == "government"
    end

    test "Ind: prefixed labels are governed" do
      assert ActorDefinitions.actor_role("Ind: Person") == "governed"
      assert ActorDefinitions.actor_role("Ind: Employee") == "governed"
      assert ActorDefinitions.actor_role("Ind: Self-employed Worker") == "governed"
    end

    test "Org: prefixed labels are governed" do
      assert ActorDefinitions.actor_role("Org: Employer") == "governed"
      assert ActorDefinitions.actor_role("Org: Company") == "governed"
    end

    test "SC: prefixed labels are governed" do
      assert ActorDefinitions.actor_role("SC: C: Contractor") == "governed"
      assert ActorDefinitions.actor_role("SC: Distributor") == "governed"
    end

    test "Spc: prefixed labels are governed" do
      assert ActorDefinitions.actor_role("Spc: Inspector") == "governed"
      assert ActorDefinitions.actor_role("Spc: Trade Union") == "governed"
    end

    test "bare labels (Public, Operator) are governed" do
      assert ActorDefinitions.actor_role("Public") == "governed"
      assert ActorDefinitions.actor_role("Operator") == "governed"
    end

    test "other governed prefixes" do
      assert ActorDefinitions.actor_role("Svc: Installer") == "governed"
      assert ActorDefinitions.actor_role("Maritime: crew") == "governed"
      assert ActorDefinitions.actor_role("Env: Recycler") == "governed"
      assert ActorDefinitions.actor_role("Offshore: Licensee") == "governed"
      assert ActorDefinitions.actor_role("Public: Parents") == "governed"
    end
  end

  describe "government_label?/1" do
    test "returns true for government labels" do
      assert ActorDefinitions.government_label?("Gvt: Minister")
      assert ActorDefinitions.government_label?("EU: Commission")
      assert ActorDefinitions.government_label?("Crown")
      assert ActorDefinitions.government_label?("HM Forces")
    end

    test "returns false for governed labels" do
      refute ActorDefinitions.government_label?("Org: Employer")
      refute ActorDefinitions.government_label?("Ind: Person")
      refute ActorDefinitions.government_label?("Public")
      refute ActorDefinitions.government_label?("Operator")
    end
  end
end
