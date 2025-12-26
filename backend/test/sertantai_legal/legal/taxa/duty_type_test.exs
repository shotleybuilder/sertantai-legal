defmodule SertantaiLegal.Legal.Taxa.DutyTypeTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyType

  describe "get_duty_types/1" do
    test "identifies enactment/citation/commencement" do
      text = "This Act may be cited as the Health and Safety at Work Act 1974."
      result = DutyType.get_duty_types(text)

      assert "Enactment, Citation, Commencement" in result
    end

    test "identifies commencement with 'comes into force'" do
      text = "These Regulations come into force on 1st January 2024."
      result = DutyType.get_duty_types(text)

      assert "Enactment, Citation, Commencement" in result
    end

    test "identifies interpretation/definition" do
      # The pattern matches "Interpretation" as a keyword
      text = "Interpretation of these Regulations."
      result = DutyType.get_duty_types(text)

      assert "Interpretation, Definition" in result
    end

    test "identifies application/scope" do
      text = "These Regulations apply to all workplaces in Great Britain."
      result = DutyType.get_duty_types(text)

      assert "Application, Scope" in result
    end

    test "identifies extent provisions" do
      text = "This Act extends to England and Wales only."
      result = DutyType.get_duty_types(text)

      assert "Extent" in result
    end

    test "identifies exemption provisions" do
      text = "The requirements shall not apply in any case where an exemption is granted."
      result = DutyType.get_duty_types(text)

      assert "Exemption" in result
    end

    test "identifies amendment provisions" do
      text = "The following amendments are made to the 1974 Act."
      result = DutyType.get_duty_types(text)

      assert "Amendment" in result
    end

    test "identifies repeal/revocation" do
      text = "The 1992 Regulations are hereby revoked."
      result = DutyType.get_duty_types(text)

      assert "Repeal, Revocation" in result
    end

    test "identifies offence provisions" do
      text = "A person who contravenes this regulation commits an offence."
      result = DutyType.get_duty_types(text)

      assert "Offence" in result
    end

    test "identifies charge/fee provisions" do
      text = "The authority may charge a fee for the inspection."
      result = DutyType.get_duty_types(text)

      assert "Charge, Fee" in result
    end

    test "identifies defence/appeal provisions" do
      text = "It is a defence for a person to prove that they took all reasonable steps."
      result = DutyType.get_duty_types(text)

      assert "Defence, Appeal" in result
    end

    test "identifies enforcement/prosecution" do
      # The patterns match "proceedings" and "conviction" (case-sensitive)
      text = "The proceedings may be brought in any court of summary jurisdiction."
      result = DutyType.get_duty_types(text)

      assert "Enforcement, Prosecution" in result
    end

    test "defaults to Process/Rule when no specific match" do
      text = "The maximum weight shall not exceed 25 kilograms."
      result = DutyType.get_duty_types(text)

      assert "Process, Rule, Constraint, Condition" in result
    end

    test "handles empty text" do
      assert DutyType.get_duty_types("") == []
    end

    test "handles nil input" do
      assert DutyType.get_duty_types(nil) == []
    end
  end

  describe "process_record/1 with role holders" do
    test "identifies duty with duty holder" do
      record = %{
        text: "The employer shall ensure the health and safety of employees.",
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      assert "Duty" in result.duty_type
      assert result.duty_holder != nil
      assert "Org: Employer" in result.duty_holder["items"]
    end

    test "identifies right with rights holder" do
      record = %{
        text: "The employee may request a copy of the risk assessment.",
        role: ["Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      assert "Right" in result.duty_type
      assert result.rights_holder != nil
      assert "Ind: Employee" in result.rights_holder["items"]
    end

    test "identifies responsibility with responsibility holder" do
      record = %{
        text: "The local authority must investigate all complaints.",
        role: [],
        role_gvt: ["Gvt: Authority: Local"]
      }

      result = DutyType.process_record(record)

      assert "Responsibility" in result.duty_type
      assert result.responsibility_holder != nil
      assert "Gvt: Authority: Local" in result.responsibility_holder["items"]
    end

    test "identifies power with power holder" do
      record = %{
        text: "The Secretary of State may by regulations prescribe requirements.",
        role: [],
        role_gvt: ["Gvt: Minister"]
      }

      result = DutyType.process_record(record)

      assert "Power" in result.duty_type or "Power Conferred" in result.duty_type
      assert result.power_holder != nil
    end

    test "processes record with string keys" do
      record = %{
        "text" => "The employer shall ensure safety.",
        "role" => ["Org: Employer"],
        "role_gvt" => []
      }

      result = DutyType.process_record(record)

      assert is_list(result["duty_type"])
      # "Duty" or a default type should be present
      assert length(result["duty_type"]) > 0
    end

    test "handles record without role fields" do
      record = %{text: "The employer shall ensure safety."}
      result = DutyType.process_record(record)

      # Should still process duty types even without role fields
      assert is_list(result.duty_type)
    end

    test "handles record with empty text" do
      record = %{text: "", role: [], role_gvt: []}
      assert DutyType.process_record(record) == record
    end
  end

  describe "duty_type_sorter/1" do
    test "sorts duty types by priority" do
      duty_types = [
        "Amendment",
        "Duty",
        "Responsibility",
        "Right",
        "Power Conferred"
      ]

      sorted = DutyType.duty_type_sorter(duty_types)

      # Duty should come before Right, Right before Responsibility, etc.
      duty_idx = Enum.find_index(sorted, &(&1 == "Duty"))
      right_idx = Enum.find_index(sorted, &(&1 == "Right"))
      resp_idx = Enum.find_index(sorted, &(&1 == "Responsibility"))

      assert duty_idx < right_idx
      assert right_idx < resp_idx
    end

    test "handles unknown duty types gracefully" do
      duty_types = ["Duty", "Unknown Type", "Right"]
      sorted = DutyType.duty_type_sorter(duty_types)

      # Unknown types should be filtered out
      refute "Unknown Type" in sorted
      assert "Duty" in sorted
      assert "Right" in sorted
    end

    test "handles empty list" do
      assert DutyType.duty_type_sorter([]) == []
    end
  end

  describe "process_records/1" do
    test "processes multiple records" do
      records = [
        %{text: "The employer shall ensure safety.", role: ["Org: Employer"], role_gvt: []},
        %{text: "This Act may be cited as the Test Act.", role: [], role_gvt: []},
        %{text: "", role: [], role_gvt: []}
      ]

      results = DutyType.process_records(records)

      assert length(results) == 3
      assert "Duty" in Enum.at(results, 0).duty_type
      assert "Enactment, Citation, Commencement" in Enum.at(results, 1).duty_type
    end
  end

  describe "amendment detection" do
    test "amendment stops further processing" do
      # Amendment clauses should not have duty holders assigned
      record = %{
        text: "The following amendments are made to the 1974 Act.",
        role: ["Org: Employer"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      assert "Amendment" in result.duty_type
      # Duty holder should not be set for amendments (key may not exist)
      duty_holder = Map.get(result, :duty_holder)
      assert duty_holder == nil or duty_holder == %{"items" => []}
    end
  end
end
