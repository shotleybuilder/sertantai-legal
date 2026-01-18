defmodule SertantaiLegal.Legal.Taxa.PopimarTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.Popimar

  describe "categories/0" do
    test "returns all 16 POPIMAR categories" do
      categories = Popimar.categories()

      assert length(categories) == 16
      assert "Policy" in categories
      assert "Organisation" in categories
      assert "Risk Control" in categories
      assert "Review" in categories
    end
  end

  describe "get_popimar/1" do
    test "identifies policy provisions" do
      text = "The employer shall establish a health and safety policy."
      result = Popimar.get_popimar(text)

      assert "Policy" in result
    end

    test "identifies organisation provisions (appointments)" do
      text = "The employer shall appoint a competent person to assist."
      result = Popimar.get_popimar(text)

      assert "Organisation" in result
    end

    test "identifies organisation control (procedures)" do
      text = "The employer shall establish procedures to ensure compliance."
      result = Popimar.get_popimar(text)

      assert "Organisation - Control" in result
    end

    test "identifies communication and consultation" do
      text = "The employer shall consult with employees on safety matters."
      result = Popimar.get_popimar(text)

      assert "Organisation - Communication & Consultation" in result
    end

    test "identifies collaboration/coordination/cooperation" do
      text = "Employers shall cooperate with other employers on site."
      result = Popimar.get_popimar(text)

      assert "Organisation - Collaboration, Coordination, Cooperation" in result
    end

    test "identifies competence (training)" do
      text = "The employer shall provide training to all employees."
      result = Popimar.get_popimar(text)

      assert "Organisation - Competence" in result
    end

    test "identifies costs provisions" do
      text = "The fee charged shall not exceed the cost of the inspection."
      result = Popimar.get_popimar(text)

      assert "Organisation - Costs" in result
    end

    test "identifies records provisions" do
      text = "The employer shall keep a record of all assessments."
      result = Popimar.get_popimar(text)

      assert "Records" in result
    end

    test "identifies permit/authorisation/license" do
      text = "No person shall carry out work without a valid licence."
      result = Popimar.get_popimar(text)

      assert "Permit, Authorisation, License" in result
    end

    test "identifies aspects and hazards" do
      text = "The employer shall identify all hazards in the workplace."
      result = Popimar.get_popimar(text)

      assert "Aspects and Hazards" in result
    end

    test "identifies planning and risk assessment" do
      text = "The employer shall carry out a suitable and sufficient risk assessment."
      result = Popimar.get_popimar(text)

      assert "Planning & Risk / Impact Assessment" in result
    end

    test "identifies risk control" do
      text = "The employer shall take all reasonable steps to reduce the risk."
      result = Popimar.get_popimar(text)

      assert "Risk Control" in result
    end

    test "identifies notification" do
      text = "The employer shall notify the authority of any dangerous occurrence."
      result = Popimar.get_popimar(text)

      assert "Notification" in result
    end

    test "identifies maintenance/examination/testing" do
      text = "Equipment shall be subject to regular maintenance and inspection."
      result = Popimar.get_popimar(text)

      assert "Maintenance, Examination and Testing" in result
    end

    test "identifies checking/monitoring" do
      text = "The employer shall monitor the effectiveness of control measures."
      result = Popimar.get_popimar(text)

      assert "Checking, Monitoring" in result
    end

    test "identifies review" do
      text = "The employer shall review the assessment whenever circumstances change."
      result = Popimar.get_popimar(text)

      assert "Review" in result
    end

    test "handles empty text" do
      assert Popimar.get_popimar("") == []
    end

    test "handles nil input" do
      assert Popimar.get_popimar(nil) == []
    end

    test "returns multiple categories when applicable" do
      text = """
      The employer shall provide training and keep records of all training provided.
      The training shall be reviewed annually.
      """

      result = Popimar.get_popimar(text)

      assert "Organisation - Competence" in result
      assert "Records" in result
      assert "Review" in result
    end
  end

  describe "get_popimar/2 with duty types" do
    test "defaults to Risk Control when no match but has Duty type" do
      text = "The employer shall ensure safe systems of work."
      result = Popimar.get_popimar(text, ["Duty"])

      assert "Risk Control" in result
    end

    test "defaults to Risk Control for Process/Rule type" do
      text = "The requirements apply to all workplaces."
      result = Popimar.get_popimar(text, ["Process, Rule, Constraint, Condition"])

      assert "Risk Control" in result
    end

    test "does not default for non-relevant duty types" do
      text = "This Act may be cited as the Test Act."
      result = Popimar.get_popimar(text, ["Enactment, Citation, Commencement"])

      refute "Risk Control" in result
    end

    test "returns actual match over default" do
      text = "The employer shall provide training to employees."
      result = Popimar.get_popimar(text, ["Duty"])

      assert "Organisation - Competence" in result
      # Should have actual match, not just default
    end
  end

  describe "process_record/1" do
    test "processes record with atom keys" do
      record = %{
        text: "The employer shall provide training.",
        duty_type: ["Duty"]
      }

      result = Popimar.process_record(record)

      assert result.popimar != nil
      assert is_list(result.popimar)
      assert "Organisation - Competence" in result.popimar
    end

    test "processes record with string keys" do
      record = %{
        "text" => "The employer shall keep records.",
        "duty_type" => ["Duty"]
      }

      result = Popimar.process_record(record)

      assert result["popimar"] != nil
      assert "Records" in result["popimar"]
    end

    test "handles record without duty_type" do
      record = %{text: "The employer shall provide training."}
      result = Popimar.process_record(record)

      assert result.popimar != nil
    end

    test "handles record with empty text" do
      record = %{text: "", duty_type: ["Duty"]}
      result = Popimar.process_record(record)

      # Empty text records are returned unchanged (no popimar key added)
      assert Map.get(result, :popimar) == nil
    end

    test "skips processing for non-relevant duty types" do
      record = %{
        text: "The following amendments are made.",
        duty_type: ["Amendment"]
      }

      result = Popimar.process_record(record)

      # Should return nil or empty for amendments
      assert result.popimar == nil or result.popimar == []
    end
  end

  describe "process_records/1" do
    test "processes multiple records" do
      records = [
        %{text: "The employer shall provide training.", duty_type: ["Duty"]},
        %{text: "Keep records of all incidents.", duty_type: ["Duty"]},
        %{text: "", duty_type: []}
      ]

      results = Popimar.process_records(records)

      assert length(results) == 3
      assert "Organisation - Competence" in Enum.at(results, 0).popimar
      assert "Records" in Enum.at(results, 1).popimar
    end
  end

  describe "popimar_sorter/1" do
    test "sorts POPIMAR categories by priority" do
      categories = [
        "Review",
        "Policy",
        "Risk Control",
        "Organisation"
      ]

      sorted = Popimar.popimar_sorter(categories)

      # Policy should come before Organisation, Organisation before Risk Control
      policy_idx = Enum.find_index(sorted, &(&1 == "Policy"))
      org_idx = Enum.find_index(sorted, &(&1 == "Organisation"))
      risk_idx = Enum.find_index(sorted, &(&1 == "Risk Control"))
      review_idx = Enum.find_index(sorted, &(&1 == "Review"))

      assert policy_idx < org_idx
      assert org_idx < risk_idx
      assert risk_idx < review_idx
    end

    test "handles empty list" do
      assert Popimar.popimar_sorter([]) == []
    end
  end
end
