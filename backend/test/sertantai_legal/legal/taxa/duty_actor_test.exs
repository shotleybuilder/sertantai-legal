defmodule SertantaiLegal.Legal.Taxa.DutyActorTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.DutyActor

  describe "get_actors_in_text/1" do
    test "extracts governed actors (employers, employees)" do
      text = "The employer shall ensure the health and safety of employees."
      result = DutyActor.get_actors_in_text(text)

      assert "Org: Employer" in result.actors
      assert "Ind: Employee" in result.actors
      assert result.actors_gvt == []
    end

    test "extracts government actors (authorities, ministers)" do
      text = "The Secretary of State may by regulations prescribe requirements."
      result = DutyActor.get_actors_in_text(text)

      assert "Gvt: Minister" in result.actors_gvt
      assert result.actors == []
    end

    test "extracts both governed and government actors" do
      text = """
      The employer shall notify the local authority of any dangerous occurrence.
      The authority must investigate within 7 days.
      """
      result = DutyActor.get_actors_in_text(text)

      assert "Org: Employer" in result.actors
      assert "Gvt: Authority: Local" in result.actors_gvt
    end

    test "handles empty text" do
      assert DutyActor.get_actors_in_text("") == %{actors: [], actors_gvt: []}
    end

    test "handles nil input" do
      assert DutyActor.get_actors_in_text(nil) == %{actors: [], actors_gvt: []}
    end

    test "extracts contractors and designers" do
      text = "The principal contractor shall ensure the principal designer is appointed."
      result = DutyActor.get_actors_in_text(text)

      assert "SC: C: Principal Contractor" in result.actors
      assert "SC: C: Principal Designer" in result.actors
    end

    test "extracts supply chain actors" do
      text = "The manufacturer shall provide instructions to the supplier and importer."
      result = DutyActor.get_actors_in_text(text)

      assert "SC: Manufacturer" in result.actors
      assert "SC: Supplier" in result.actors
      assert "SC: Importer" in result.actors
    end

    test "extracts specialist actors" do
      text = "The competent person shall advise the employer. The inspector may issue notices."
      result = DutyActor.get_actors_in_text(text)

      assert "Ind: Competent Person" in result.actors
      assert "Org: Employer" in result.actors
      assert "Spc: Inspector" in result.actors
    end

    test "extracts agency actors" do
      text = "The Health and Safety Executive shall enforce these Regulations."
      result = DutyActor.get_actors_in_text(text)

      assert "Gvt: Agency: Health and Safety Executive" in result.actors_gvt
    end
  end

  describe "get_governed_actors/1" do
    test "returns only governed actors" do
      text = "The employer and the Secretary of State shall cooperate."
      result = DutyActor.get_governed_actors(text)

      assert "Org: Employer" in result
      refute Enum.any?(result, &String.starts_with?(&1, "Gvt:"))
    end

    test "handles text with no governed actors" do
      text = "The Minister may make regulations."
      assert DutyActor.get_governed_actors(text) == []
    end
  end

  describe "get_government_actors/1" do
    test "returns only government actors" do
      text = "The employer and the local authority shall cooperate."
      result = DutyActor.get_government_actors(text)

      assert "Gvt: Authority: Local" in result
      refute Enum.any?(result, &String.starts_with?(&1, "Org:"))
    end

    test "handles text with no government actors" do
      text = "The employer shall ensure safety."
      assert DutyActor.get_government_actors(text) == []
    end
  end

  describe "process_record/1" do
    test "processes record with atom keys" do
      record = %{text: "The employer shall ensure the safety of workers."}
      result = DutyActor.process_record(record)

      assert is_list(result.role)
      assert is_list(result.role_gvt)
      assert "Org: Employer" in result.role
      assert "Ind: Worker" in result.role
    end

    test "processes record with string keys" do
      record = %{"text" => "The local authority must enforce regulations."}
      result = DutyActor.process_record(record)

      assert is_list(result["role"])
      assert is_list(result["role_gvt"])
      assert "Gvt: Authority: Local" in result["role_gvt"]
    end

    test "handles record without text" do
      record = %{id: 123}
      assert DutyActor.process_record(record) == record
    end

    test "handles record with empty text" do
      record = %{text: ""}
      assert DutyActor.process_record(record) == record
    end
  end

  describe "process_records/1" do
    test "processes multiple records" do
      records = [
        %{text: "The employer shall ensure safety."},
        %{text: "The Minister may prescribe requirements."},
        %{text: ""}
      ]

      results = DutyActor.process_records(records)

      assert length(results) == 3
      assert "Org: Employer" in Enum.at(results, 0).role
      assert "Gvt: Minister" in Enum.at(results, 1).role_gvt
    end
  end

  describe "blacklist filtering" do
    test "filters out 'public' when followed by excluded terms" do
      # "public interest" should not match "Public" actor
      text = "This is in the public interest."
      result = DutyActor.get_actors_in_text(text)

      refute "Public" in result.actors
    end

    test "filters out 'representatives of'" do
      text = "The representatives of employees shall be consulted."
      result = DutyActor.get_actors_in_text(text)

      # Should match employees but not create false positive on "representatives"
      assert "Ind: Employee" in result.actors
    end
  end
end
