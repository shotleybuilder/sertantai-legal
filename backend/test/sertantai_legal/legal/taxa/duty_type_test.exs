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
      assert is_list(result.duty_holder)
      assert "Org: Employer" in result.duty_holder
    end

    test "identifies right with rights holder" do
      record = %{
        text: "The employee may request a copy of the risk assessment.",
        role: ["Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      assert "Right" in result.duty_type
      assert is_list(result.rights_holder)
      assert "Ind: Employee" in result.rights_holder
    end

    test "identifies responsibility with responsibility holder" do
      record = %{
        text: "The local authority must investigate all complaints.",
        role: [],
        role_gvt: ["Gvt: Authority: Local"]
      }

      result = DutyType.process_record(record)

      assert "Responsibility" in result.duty_type
      assert is_list(result.responsibility_holder)
      assert "Gvt: Authority: Local" in result.responsibility_holder
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

  describe "windowed search optimization" do
    # The windowed search threshold is 50,000 chars
    # We test that large texts still produce correct results

    test "processes large text with windowed search" do
      # Create a large text that exceeds the windowed search threshold (50,000 chars)
      # by padding with filler text, with duty provisions scattered throughout
      filler = String.duplicate("This is filler text for testing. ", 2000)

      text =
        "The employer shall ensure the health and safety of employees. " <>
          filler <>
          "The employee may request a copy of the assessment. " <>
          filler

      record = %{
        text: text,
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Should still find duty and right even with windowed search
      assert "Duty" in result.duty_type
      assert "Right" in result.duty_type
      assert "Org: Employer" in result.duty_holder
      assert "Ind: Employee" in result.rights_holder
    end

    test "handles actors not mentioned in large text" do
      # Create large text without any actor mentions
      filler = String.duplicate("This is generic filler text without actors. ", 2000)
      text = filler

      record = %{
        text: text,
        role: ["Org: Employer"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Should return empty when actor not found in text
      assert result.duty_type == []
      assert result.duty_holder == []
    end

    test "finds multiple duty types in large text" do
      filler = String.duplicate("Additional content here. ", 2000)

      text =
        "The employer shall ensure safety. " <>
          filler <>
          "The local authority must investigate all incidents. " <>
          filler <>
          "The Secretary of State may by regulations prescribe requirements."

      record = %{
        text: text,
        role: ["Org: Employer"],
        role_gvt: ["Gvt: Authority: Local", "Gvt: Minister"]
      }

      result = DutyType.process_record(record)

      assert "Duty" in result.duty_type
      assert "Responsibility" in result.duty_type
      assert "Power" in result.duty_type
    end
  end

  describe "modal-based windowing (Phase 5)" do
    # Modal-based windowing finds modal verbs (shall, must, may) first,
    # then only searches for actors in windows around those modals.
    # This is more efficient than actor-based windowing because modals
    # are fewer and more specific to duties/rights.

    test "finds duties only near modal verbs in large text" do
      # Create large text with an employer mention far from any modal
      # and another employer mention near a modal
      filler = String.duplicate("General information about workplace safety procedures. ", 1500)

      text =
        "The employer operates in multiple locations. " <>
          filler <>
          "The employer shall ensure adequate ventilation. " <>
          filler

      record = %{
        text: text,
        role: ["Org: Employer"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Should find duty from the "employer shall ensure" near the modal
      assert "Duty" in result.duty_type
      assert "Org: Employer" in result.duty_holder
    end

    test "skips actors that only appear outside modal windows" do
      # Create text where employee is mentioned but never near a modal verb
      # while employer is near a modal
      filler = String.duplicate("Procedures and guidelines for operations. ", 1500)

      text =
        "The employee handbook describes policies. " <>
          filler <>
          "The employer shall provide training. " <>
          filler <>
          "Employee records are maintained by HR."

      record = %{
        text: text,
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Employer near modal should be found
      assert "Org: Employer" in result.duty_holder

      # Employee is only mentioned outside modal windows, so should not have rights
      # (no "employee may" or "employee shall" patterns)
      refute "Ind: Employee" in (result.rights_holder || [])
    end

    test "handles non-modal duty indicators (is liable, remains responsible)" do
      # Test that non-modal patterns like "is liable" are still found
      filler = String.duplicate("Standard operating procedures apply here. ", 1500)

      text =
        filler <>
          "The employer is liable for damages caused by negligence. " <>
          filler

      record = %{
        text: text,
        role: ["Org: Employer"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Should find duty from "is liable" pattern (non-modal anchor)
      assert "Duty" in result.duty_type
      assert "Org: Employer" in result.duty_holder
    end

    test "finds rights with may patterns" do
      filler = String.duplicate("Background information about regulations. ", 1500)

      text =
        filler <>
          "The employee may request a review of the decision. " <>
          filler

      record = %{
        text: text,
        role: ["Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # Should find right from "employee may request"
      assert "Right" in result.duty_type
      assert "Ind: Employee" in result.rights_holder
    end

    test "distinguishes may not (duty) from may (right)" do
      filler = String.duplicate("Regulatory framework and compliance requirements. ", 1500)

      text =
        filler <>
          "The employer may not dismiss an employee without cause. " <>
          filler <>
          "The employee may appeal the decision."

      record = %{
        text: text,
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # "may not" is a duty, "may" (without not) is a right
      assert "Duty" in result.duty_type
      assert "Right" in result.duty_type
    end

    test "handles government actors with modal verbs" do
      filler = String.duplicate("Administrative and procedural matters. ", 1500)

      text =
        filler <>
          "The local authority must ensure compliance. " <>
          filler <>
          "The Minister may by regulations prescribe standards."

      record = %{
        text: text,
        role: [],
        role_gvt: ["Gvt: Authority: Local", "Gvt: Minister"]
      }

      result = DutyType.process_record(record)

      # Local authority with "must" = responsibility
      assert "Responsibility" in result.duty_type
      assert "Gvt: Authority: Local" in result.responsibility_holder

      # Minister with "may by regulations" = power
      assert "Power" in result.duty_type
      assert "Gvt: Minister" in result.power_holder
    end

    test "processes text with no modal verbs returns empty" do
      # Large text with actors but absolutely no modal verbs or duty indicators
      filler = String.duplicate("Description of equipment and processes. ", 1500)

      text =
        "The employer provides equipment. " <>
          filler <>
          "The employee receives training annually."

      record = %{
        text: text,
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: []
      }

      result = DutyType.process_record(record)

      # No modals = no duties/rights
      assert result.duty_type == []
    end
  end
end
