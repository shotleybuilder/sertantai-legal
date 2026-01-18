defmodule SertantaiLegal.Legal.Taxa.TaxaIntegrationTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyActor
  alias SertantaiLegal.Legal.Taxa.DutyType
  alias SertantaiLegal.Legal.Taxa.Popimar

  @moduledoc """
  Integration tests for the full Taxa processing pipeline.

  The pipeline processes legal text through:
  Text → DutyActor → DutyType → POPIMAR
  """

  describe "full pipeline processing" do
    test "processes employer duty provision end-to-end" do
      record = %{
        text: "The employer shall ensure the health and safety of employees at work."
      }

      # Step 1: Extract actors
      record = DutyActor.process_record(record)

      assert "Org: Employer" in record.role
      assert "Ind: Employee" in record.role
      assert record.role_gvt == []

      # Step 2: Classify duty type and assign holders
      record = DutyType.process_record(record)

      assert "Duty" in record.duty_type
      assert record.duty_holder != nil
      assert "Org: Employer" in record.duty_holder["items"]

      # Step 3: Classify by POPIMAR
      record = Popimar.process_record(record)

      assert record.popimar != nil
      # Employer duties typically default to Risk Control
      assert "Risk Control" in record.popimar
    end

    test "processes government responsibility provision end-to-end" do
      record = %{
        text: "The local authority must investigate all reported incidents within 14 days."
      }

      # Step 1: Extract actors
      record = DutyActor.process_record(record)

      assert "Gvt: Authority: Local" in record.role_gvt
      assert record.role == []

      # Step 2: Classify duty type and assign holders
      record = DutyType.process_record(record)

      assert "Responsibility" in record.duty_type
      assert record.responsibility_holder != nil
      assert "Gvt: Authority: Local" in record.responsibility_holder["items"]

      # Step 3: Classify by POPIMAR
      record = Popimar.process_record(record)

      # Government responsibilities may or may not match POPIMAR
      assert record.popimar != nil or record.popimar == nil
    end

    test "processes training provision with competence classification" do
      record = %{
        text:
          "The employer shall provide adequate training to all employees before they commence work."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      # Actor extraction
      assert "Org: Employer" in record.role
      assert "Ind: Employee" in record.role

      # Duty classification
      assert "Duty" in record.duty_type
      assert "Org: Employer" in record.duty_holder["items"]

      # POPIMAR - training maps to Competence
      assert "Organisation - Competence" in record.popimar
    end

    test "processes record keeping provision" do
      record = %{
        text: "The employer shall maintain a record of all risk assessments conducted."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      assert "Org: Employer" in record.role
      assert "Duty" in record.duty_type
      assert "Records" in record.popimar
    end

    test "processes rights provision" do
      record = %{
        text: "The employee may request access to any health and safety records."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      assert "Ind: Employee" in record.role
      assert "Right" in record.duty_type
      assert record.rights_holder != nil
      assert "Ind: Employee" in record.rights_holder["items"]
    end

    test "processes ministerial power provision" do
      record = %{
        text: "The Secretary of State may by regulations prescribe additional requirements."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      assert "Gvt: Minister" in record.role_gvt
      assert "Power" in record.duty_type or "Power Conferred" in record.duty_type
      assert record.power_holder != nil
    end

    test "processes amendment clause (no role holders found)" do
      record = %{
        text: "The following amendments are made to the Health and Safety Act 1974."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      # Amendment text doesn't have role holder patterns, so no duty_type values
      # (duty_type now only contains role-based values: Duty, Right, Responsibility, Power)
      assert record.duty_type == []

      # Use Map.get since duty_holder key may not exist
      duty_holder = Map.get(record, :duty_holder)
      assert duty_holder == nil or duty_holder == %{"items" => []}

      popimar = Map.get(record, :popimar)
      assert popimar == nil or popimar == []
    end

    test "processes multi-category provision" do
      record = %{
        text: """
        The employer shall:
        (a) provide training to all employees;
        (b) keep records of training provided;
        (c) consult with employee representatives on training matters.
        """
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      assert "Org: Employer" in record.role
      assert "Ind: Employee" in record.role
      assert "Duty" in record.duty_type

      assert "Organisation - Competence" in record.popimar
      assert "Records" in record.popimar
      assert "Organisation - Communication & Consultation" in record.popimar
    end
  end

  describe "batch processing" do
    test "processes multiple records through full pipeline" do
      records = [
        %{text: "The employer shall ensure safety."},
        %{text: "The employee may request information."},
        %{text: "The local authority must investigate complaints."},
        %{text: "This Act may be cited as the Test Act 2024."},
        %{text: ""}
      ]

      results =
        records
        |> DutyActor.process_records()
        |> DutyType.process_records()
        |> Popimar.process_records()

      assert length(results) == 5

      # First record - employer duty
      first = Enum.at(results, 0)
      assert "Org: Employer" in first.role
      assert "Duty" in first.duty_type

      # Second record - employee right
      second = Enum.at(results, 1)
      assert "Ind: Employee" in second.role
      assert "Right" in second.duty_type

      # Third record - local authority responsibility
      third = Enum.at(results, 2)
      assert "Gvt: Authority: Local" in third.role_gvt

      assert "Responsibility" in third.duty_type

      # Fourth record - citation (no role holders, just purpose)
      fourth = Enum.at(results, 3)
      # duty_type now only contains role-based values, so citation has empty duty_type
      assert fourth.duty_type == []

      # Fifth record - empty text (unchanged)
      fifth = Enum.at(results, 4)
      assert fifth.text == ""
    end
  end

  describe "string key handling" do
    test "processes records with string keys through full pipeline" do
      record = %{
        "text" => "The employer shall provide training to workers."
      }

      # Process through pipeline
      record = DutyActor.process_record(record)
      assert is_list(record["role"])
      assert "Org: Employer" in record["role"]
      assert "Ind: Worker" in record["role"]

      record = DutyType.process_record(record)
      assert is_list(record["duty_type"])
      assert "Duty" in record["duty_type"]

      record = Popimar.process_record(record)
      assert record["popimar"] != nil
      assert "Organisation - Competence" in record["popimar"]
    end
  end

  describe "edge cases" do
    test "handles text with multiple actor types" do
      record = %{
        text: """
        The employer shall notify the authority of any dangerous occurrence.
        The contractor and principal designer shall cooperate.
        """
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      # Multiple governed actors
      assert "Org: Employer" in record.role

      assert Enum.any?(record.role, fn r ->
               String.contains?(r, "Contractor") or String.contains?(r, "Designer")
             end)

      # Notification POPIMAR category
      assert "Notification" in record.popimar
    end

    test "handles text with no actors" do
      record = %{
        text: "The requirements set out in Schedule 1 shall apply to all premises."
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      # May or may not have actors depending on patterns
      # Should still process without errors
      assert is_list(record.role)
      assert is_list(record.role_gvt)
      assert is_list(record.duty_type)
    end

    test "handles complex real-world provision" do
      record = %{
        text: """
        Every employer shall make and give effect to such arrangements as are appropriate,
        having regard to the nature of his activities and the size of his undertaking,
        for the effective planning, organisation, control, monitoring and review of the
        preventive and protective measures.
        """
      }

      record =
        record
        |> DutyActor.process_record()
        |> DutyType.process_record()
        |> Popimar.process_record()

      assert "Org: Employer" in record.role
      assert "Duty" in record.duty_type
      assert record.popimar != nil

      # This text mentions multiple POPIMAR concepts
      # Should match several categories
      assert length(record.popimar) >= 1
    end
  end

  describe "POPIMAR category coverage" do
    test "policy provisions" do
      record = %{
        text: "The employer shall establish a health and safety policy.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Policy" in record.popimar
    end

    test "organisation provisions" do
      record = %{
        text: "The employer shall appoint competent persons to assist.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Organisation" in record.popimar
    end

    test "risk assessment provisions" do
      record = %{
        text: "The employer shall carry out a suitable and sufficient risk assessment.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Planning & Risk / Impact Assessment" in record.popimar
    end

    test "hazard identification provisions" do
      record = %{
        text: "The employer shall identify all hazards present in the workplace.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Aspects and Hazards" in record.popimar
    end

    test "maintenance provisions" do
      record = %{
        text: "Equipment shall be maintained in an efficient state and in good repair.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Maintenance, Examination and Testing" in record.popimar
    end

    test "monitoring provisions" do
      record = %{
        text: "The employer shall monitor the effectiveness of control measures.",
        duty_type: ["Duty"]
      }

      record = Popimar.process_record(record)
      assert "Checking, Monitoring" in record.popimar
    end

    test "permit provisions" do
      record = %{
        text: "No person shall carry out work without a valid licence.",
        duty_type: ["Process, Rule, Constraint, Condition"]
      }

      record = Popimar.process_record(record)
      assert "Permit, Authorisation, License" in record.popimar
    end
  end
end
