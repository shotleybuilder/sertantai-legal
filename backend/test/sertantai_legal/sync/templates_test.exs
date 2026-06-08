defmodule SertantaiLegal.Sync.TemplatesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Sync.Templates.{
    Registry,
    SubPatterns,
    Foundation,
    Personnel,
    ComplianceAssessment,
    ActionTracker,
    EvidenceVault
  }

  describe "Registry.resolve/1" do
    test "resolves foundation alone" do
      {:ok, modules} = Registry.resolve([:foundation])
      assert modules == [Foundation]
    end

    test "resolves personnel alone" do
      {:ok, modules} = Registry.resolve([:personnel])
      assert modules == [Personnel]
    end

    test "resolves compliance_assessment with dependencies" do
      {:ok, modules} = Registry.resolve([:compliance_assessment])

      # Should include foundation and personnel as prerequisites
      ids = Enum.map(modules, & &1.id())
      assert :foundation in ids
      assert :personnel in ids
      assert :compliance_assessment in ids

      # compliance_assessment must come after its dependencies
      assessment_idx = Enum.find_index(ids, &(&1 == :compliance_assessment))
      foundation_idx = Enum.find_index(ids, &(&1 == :foundation))
      personnel_idx = Enum.find_index(ids, &(&1 == :personnel))

      assert foundation_idx < assessment_idx
      assert personnel_idx < assessment_idx
    end

    test "resolves explicit list in dependency order" do
      {:ok, modules} = Registry.resolve([:compliance_assessment, :foundation, :personnel])
      ids = Enum.map(modules, & &1.id())

      assessment_idx = Enum.find_index(ids, &(&1 == :compliance_assessment))
      foundation_idx = Enum.find_index(ids, &(&1 == :foundation))

      assert foundation_idx < assessment_idx
    end

    test "rejects unknown templates" do
      assert {:error, {:unknown_templates, [:nonexistent]}} =
               Registry.resolve([:nonexistent])
    end
  end

  describe "SubPatterns" do
    test "defaults are valid" do
      sp = SubPatterns.new()
      assert :ok = SubPatterns.validate(sp)
    end

    test "custom patterns validate" do
      sp = SubPatterns.new(risk_scoring: :matrix, people: :linked, org_structure: :site)
      assert :ok = SubPatterns.validate(sp)
    end

    test "invalid pattern value rejected" do
      sp = SubPatterns.new(risk_scoring: :invalid)
      assert {:error, errors} = SubPatterns.validate(sp)
      assert Keyword.has_key?(errors, :risk_scoring)
    end
  end

  describe "Foundation template" do
    test "has no dependencies" do
      assert Foundation.requires() == []
    end

    test "declares lrt and lat tables" do
      assert Foundation.tables() == [:lrt, :lat]
    end

    test "field specs are empty (managed by Engine.run)" do
      sp = SubPatterns.new()
      specs = Foundation.field_specs(sp)
      assert specs == %{lrt: [], lat: []}
    end
  end

  describe "Personnel template" do
    test "has no dependencies" do
      assert Personnel.requires() == []
    end

    test "declares personnel table" do
      assert Personnel.tables() == [:personnel]
    end

    test "field specs include name, email, role, department" do
      sp = SubPatterns.new()
      %{personnel: fields} = Personnel.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Name" in names
      assert "SA_Email" in names
      assert "SA_Role" in names
      assert "SA_Department" in names
      assert "SA_Active" in names
    end

    test "has views" do
      sp = SubPatterns.new()
      %{personnel: views} = Personnel.view_specs(sp)
      assert length(views) == 4
    end
  end

  describe "ComplianceAssessment template" do
    test "requires foundation and personnel" do
      assert :foundation in ComplianceAssessment.requires()
      assert :personnel in ComplianceAssessment.requires()
    end

    test "field specs with simple risk" do
      sp = SubPatterns.new(risk_scoring: :simple, people: :linked, review_cycle: :scheduled)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Law" in names
      assert "SA_Compliance_Status" in names
      assert "SA_Risk_Level" in names
      refute "SA_Likelihood" in names
      refute "SA_Impact" in names
      refute "SA_Risk_Score" in names
    end

    test "field specs with matrix risk" do
      sp = SubPatterns.new(risk_scoring: :matrix, people: :linked, review_cycle: :scheduled)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Risk_Level" in names
      assert "SA_Likelihood" in names
      assert "SA_Impact" in names
      assert "SA_Risk_Score" in names
    end

    test "linked people sub-pattern uses link_row" do
      sp = SubPatterns.new(people: :linked)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      owner = Enum.find(fields, &(&1.name == "SA_Assessment_Owner"))
      assert owner.type == :link_row
      assert owner.target == :personnel
    end

    test "flat people sub-pattern uses text" do
      sp = SubPatterns.new(people: :flat)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      owner = Enum.find(fields, &(&1.name == "SA_Assessment_Owner"))
      assert owner.type == :text
    end

    test "scheduled review adds frequency + formula fields" do
      sp = SubPatterns.new(review_cycle: :scheduled)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Review_Frequency" in names
      assert "SA_Days_Until_Review" in names
      assert "SA_Review_Status" in names
    end

    test "manual review has only next review date" do
      sp = SubPatterns.new(review_cycle: :manual)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Next_Review_Date" in names
      refute "SA_Review_Frequency" in names
      refute "SA_Days_Until_Review" in names
    end

    test "has cross-table rollup on LRT" do
      sp = SubPatterns.new()
      cross = ComplianceAssessment.cross_table_fields(sp)
      assert Map.has_key?(cross, :lrt)
      assert length(cross.lrt) >= 1
    end

    test "has webhook spec for assessments updates" do
      specs = ComplianceAssessment.webhook_specs()
      assert [%{table: :assessments, events: [:updated]}] = specs
    end

    test "has views including kanban and calendar" do
      sp = SubPatterns.new()
      %{assessments: views} = ComplianceAssessment.view_specs(sp)

      types = Enum.map(views, & &1.type)
      assert :grid in types
      assert :kanban in types
      assert :calendar in types
    end
  end

  describe "ActionTracker template" do
    test "requires compliance_assessment" do
      assert :compliance_assessment in ActionTracker.requires()
    end

    test "declares actions table" do
      assert ActionTracker.tables() == [:actions]
    end

    test "field specs include status, priority, action type" do
      sp = SubPatterns.new()
      %{actions: fields} = ActionTracker.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Title" in names
      assert "SA_Assessment" in names
      assert "SA_Status" in names
      assert "SA_Priority" in names
      assert "SA_Action_Type" in names
      assert "SA_Due_Date" in names
      assert "SA_Overdue" in names
    end

    test "linked people uses link_row for assigned to" do
      sp = SubPatterns.new(people: :linked)
      %{actions: fields} = ActionTracker.field_specs(sp)

      assigned = Enum.find(fields, &(&1.name == "SA_Assigned_To"))
      assert assigned.type == :link_row
      assert assigned.target == :personnel
    end

    test "flat people uses text for assigned to" do
      sp = SubPatterns.new(people: :flat)
      %{actions: fields} = ActionTracker.field_specs(sp)

      assigned = Enum.find(fields, &(&1.name == "SA_Assigned_To"))
      assert assigned.type == :text
    end

    test "has kanban and calendar views" do
      sp = SubPatterns.new()
      %{actions: views} = ActionTracker.view_specs(sp)

      types = Enum.map(views, & &1.type)
      assert :kanban in types
      assert :calendar in types
    end

    test "adds rollup to assessments table" do
      sp = SubPatterns.new()
      cross = ActionTracker.cross_table_fields(sp)
      assert Map.has_key?(cross, :assessments)

      rollup = hd(cross.assessments)
      assert rollup.name == "SA_Open_Actions"
      assert rollup.type == :rollup
    end

    test "resolves full dependency chain" do
      {:ok, modules} = Registry.resolve([:action_tracker])
      ids = Enum.map(modules, & &1.id())

      assert :foundation in ids
      assert :personnel in ids
      assert :compliance_assessment in ids
      assert :action_tracker in ids

      # Order: dependencies before dependents
      assert Enum.find_index(ids, &(&1 == :compliance_assessment)) <
               Enum.find_index(ids, &(&1 == :action_tracker))
    end
  end

  describe "EvidenceVault template" do
    test "requires compliance_assessment" do
      assert :compliance_assessment in EvidenceVault.requires()
    end

    test "declares evidence table" do
      assert EvidenceVault.tables() == [:evidence]
    end

    test "embedded storage_mode uses file field" do
      sp = SubPatterns.new(storage_mode: :embedded)
      %{evidence: fields} = EvidenceVault.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_File" in names
      refute "SA_Document_URL" in names
    end

    test "reference storage_mode uses url fields" do
      sp = SubPatterns.new(storage_mode: :reference)
      %{evidence: fields} = EvidenceVault.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Document_URL" in names
      assert "SA_Document_Location" in names
      refute "SA_File" in names
    end

    test "links to both assessments and actions" do
      sp = SubPatterns.new()
      %{evidence: fields} = EvidenceVault.field_specs(sp)

      targets =
        fields
        |> Enum.filter(&(&1.type == :link_row))
        |> Enum.map(& &1.target)

      assert :assessments in targets
      assert :actions in targets
    end

    test "has expiry tracking fields" do
      sp = SubPatterns.new()
      %{evidence: fields} = EvidenceVault.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "SA_Expiry_Date" in names
      assert "SA_Status" in names
      assert "SA_Version" in names
    end

    test "has gallery view" do
      sp = SubPatterns.new()
      %{evidence: views} = EvidenceVault.view_specs(sp)

      types = Enum.map(views, & &1.type)
      assert :gallery in types
    end

    test "adds evidence count rollup to assessments" do
      sp = SubPatterns.new()
      cross = EvidenceVault.cross_table_fields(sp)

      rollup = hd(cross.assessments)
      assert rollup.name == "SA_Evidence_Count"
    end
  end
end
