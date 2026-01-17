defmodule SertantaiLegal.Legal.Taxa.DutyTypeTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyType

  describe "all_duty_types/0" do
    test "returns the four role-based duty types" do
      duty_types = DutyType.all_duty_types()

      assert duty_types == ["Duty", "Right", "Responsibility", "Power"]
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

      assert "Power" in result.duty_type
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
      assert "Duty" in result["duty_type"]
    end

    test "handles record without role fields" do
      record = %{text: "The employer shall ensure safety."}
      result = DutyType.process_record(record)

      # Without role fields, no role holders can be found
      assert is_list(result.duty_type)
      assert result.duty_type == []
    end

    test "handles record with empty text" do
      record = %{text: "", role: [], role_gvt: []}
      assert DutyType.process_record(record) == record
    end

    test "returns empty duty_type when no role holders found" do
      record = %{
        text: "This is some generic text without any role patterns.",
        role: [],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # No role holders means no duty types
      assert result.duty_type == []
    end
  end

  describe "duty_type_sorter/1" do
    test "sorts duty types by priority: Duty → Right → Responsibility → Power" do
      duty_types = ["Power", "Duty", "Responsibility", "Right"]
      sorted = DutyType.duty_type_sorter(duty_types)

      assert sorted == ["Duty", "Right", "Responsibility", "Power"]
    end

    test "filters out non-role-based values" do
      duty_types = ["Duty", "Amendment", "Right", "Offence"]
      sorted = DutyType.duty_type_sorter(duty_types)

      # Only role-based values should remain
      assert sorted == ["Duty", "Right"]
      refute "Amendment" in sorted
      refute "Offence" in sorted
    end

    test "handles empty list" do
      assert DutyType.duty_type_sorter([]) == []
    end

    test "handles single value" do
      assert DutyType.duty_type_sorter(["Duty"]) == ["Duty"]
    end
  end

  describe "process_records/1" do
    test "processes multiple records" do
      records = [
        %{text: "The employer shall ensure safety.", role: ["Org: Employer"], role_gvt: []},
        %{
          text: "The Secretary of State may by regulations prescribe.",
          role: [],
          role_gvt: ["Gvt: Minister"]
        },
        %{text: "", role: [], role_gvt: []}
      ]

      results = DutyType.process_records(records)

      assert length(results) == 3
      assert "Duty" in Enum.at(results, 0).duty_type
      assert "Power" in Enum.at(results, 1).duty_type
      # Third record unchanged (empty text)
      assert Enum.at(results, 2).text == ""
    end
  end

  describe "multiple role types in same record" do
    test "identifies both duty and right holders" do
      record = %{
        text: "The employer shall ensure safety. The employee may request information.",
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      assert "Duty" in result.duty_type
      assert "Right" in result.duty_type
      assert result.duty_holder != nil
      assert result.rights_holder != nil
    end

    test "identifies both governed and government role holders" do
      record = %{
        text:
          "The employer shall ensure safety. The local authority must investigate all complaints.",
        role: ["Org: Employer"],
        role_gvt: ["Gvt: Authority: Local"]
      }

      result = DutyType.process_record(record)

      assert "Duty" in result.duty_type
      assert "Responsibility" in result.duty_type
      assert result.duty_holder != nil
      assert result.responsibility_holder != nil
    end
  end
end
