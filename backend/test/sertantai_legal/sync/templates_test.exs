defmodule SertantaiLegal.Sync.TemplatesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Sync.Templates.{
    Registry,
    SubPatterns,
    Foundation,
    Personnel,
    ComplianceAssessment,
    ActionTracker,
    EvidenceVault,
    IncidentRegister,
    AuditManagement,
    TrainingTracker,
    DocumentControl,
    RACI,
    PDCA,
    OrgStructure
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
      assert "Name" in names
      assert "Email" in names
      assert "Role" in names
      assert "Department" in names
      assert "Active" in names
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
      assert "Law" in names
      assert "Compliance_Status" in names
      assert "Risk_Level" in names
      refute "Likelihood" in names
      refute "Impact" in names
      refute "Risk_Score" in names
    end

    test "field specs with matrix risk" do
      sp = SubPatterns.new(risk_scoring: :matrix, people: :linked, review_cycle: :scheduled)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "Risk_Level" in names
      assert "Likelihood" in names
      assert "Impact" in names
      assert "Risk_Score" in names
    end

    test "linked people sub-pattern uses link_row" do
      sp = SubPatterns.new(people: :linked)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      owner = Enum.find(fields, &(&1.name == "Assessment_Owner"))
      assert owner.type == :link_row
      assert owner.target == :personnel
    end

    test "flat people sub-pattern uses text" do
      sp = SubPatterns.new(people: :flat)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      owner = Enum.find(fields, &(&1.name == "Assessment_Owner"))
      assert owner.type == :text
    end

    test "scheduled review adds frequency + formula fields" do
      sp = SubPatterns.new(review_cycle: :scheduled)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "Review_Frequency" in names
      assert "Days_Until_Review" in names
      assert "Review_Status" in names
    end

    test "manual review has only next review date" do
      sp = SubPatterns.new(review_cycle: :manual)
      %{assessments: fields} = ComplianceAssessment.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "Next_Review_Date" in names
      refute "Review_Frequency" in names
      refute "Days_Until_Review" in names
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
      assert "Title" in names
      assert "Assessment" in names
      assert "Status" in names
      assert "Priority" in names
      assert "Action_Type" in names
      assert "Due_Date" in names
      assert "Overdue" in names
    end

    test "linked people uses link_row for assigned to" do
      sp = SubPatterns.new(people: :linked)
      %{actions: fields} = ActionTracker.field_specs(sp)

      assigned = Enum.find(fields, &(&1.name == "Assigned_To"))
      assert assigned.type == :link_row
      assert assigned.target == :personnel
    end

    test "flat people uses text for assigned to" do
      sp = SubPatterns.new(people: :flat)
      %{actions: fields} = ActionTracker.field_specs(sp)

      assigned = Enum.find(fields, &(&1.name == "Assigned_To"))
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
      assert rollup.name == "Open_Actions"
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
      assert "File" in names
      refute "Document_URL" in names
    end

    test "reference storage_mode uses url fields" do
      sp = SubPatterns.new(storage_mode: :reference)
      %{evidence: fields} = EvidenceVault.field_specs(sp)

      names = Enum.map(fields, & &1.name)
      assert "Document_URL" in names
      assert "Document_Location" in names
      refute "File" in names
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
      assert "Expiry_Date" in names
      assert "Status" in names
      assert "Version" in names
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
      assert rollup.name == "Evidence_Count"
    end
  end

  # ── Phase 6 templates ─────────────────────────────────────────

  describe "IncidentRegister template" do
    test "requires assessment + action tracker" do
      assert :compliance_assessment in IncidentRegister.requires()
      assert :action_tracker in IncidentRegister.requires()
    end

    test "has corrective and preventative action links" do
      sp = SubPatterns.new()
      %{incidents: fields} = IncidentRegister.field_specs(sp)
      names = Enum.map(fields, & &1.name)
      assert "Corrective_Action" in names
      assert "Preventative_Action" in names
    end

    test "has form view for reporting" do
      sp = SubPatterns.new()
      %{incidents: views} = IncidentRegister.view_specs(sp)
      types = Enum.map(views, & &1.type)
      assert :form in types
    end
  end

  describe "AuditManagement template" do
    test "adapts report field by storage_mode" do
      embedded = SubPatterns.new(storage_mode: :embedded)
      %{audits: fields_e} = AuditManagement.field_specs(embedded)
      names_e = Enum.map(fields_e, & &1.name)
      assert "Report" in names_e

      reference = SubPatterns.new(storage_mode: :reference)
      %{audits: fields_r} = AuditManagement.field_specs(reference)
      names_r = Enum.map(fields_r, & &1.name)
      assert "Report_URL" in names_r
      refute "Report" in names_r
    end

    test "has calendar view for next audit dates" do
      sp = SubPatterns.new()
      %{audits: views} = AuditManagement.view_specs(sp)
      calendar = Enum.find(views, &(&1.type == :calendar))
      assert calendar.date_field == "Next_Audit_Date"
    end
  end

  describe "TrainingTracker template" do
    test "requires only foundation" do
      assert TrainingTracker.requires() == [:foundation]
    end

    test "has days until due formula" do
      sp = SubPatterns.new()
      %{training: fields} = TrainingTracker.field_specs(sp)
      formula = Enum.find(fields, &(&1.name == "Days_Until_Due"))
      assert formula.type == :formula
    end

    test "adapts certificate by storage_mode" do
      embedded = SubPatterns.new(storage_mode: :embedded)
      %{training: fields} = TrainingTracker.field_specs(embedded)
      names = Enum.map(fields, & &1.name)
      assert "Certificate" in names

      reference = SubPatterns.new(storage_mode: :reference)
      %{training: fields_r} = TrainingTracker.field_specs(reference)
      names_r = Enum.map(fields_r, & &1.name)
      assert "Certificate_URL" in names_r
    end
  end

  describe "DocumentControl template" do
    test "requires only foundation" do
      assert DocumentControl.requires() == [:foundation]
    end

    test "links to LRT for related laws" do
      sp = SubPatterns.new()
      %{documents: fields} = DocumentControl.field_specs(sp)
      related = Enum.find(fields, &(&1.name == "Related_Laws"))
      assert related.type == :link_row
      assert related.target == :lrt
    end

    test "has review calendar" do
      sp = SubPatterns.new()
      %{documents: views} = DocumentControl.view_specs(sp)
      calendar = Enum.find(views, &(&1.type == :calendar))
      assert calendar.date_field == "Review_Date"
    end
  end

  describe "RACI template" do
    test "requires only foundation" do
      assert RACI.requires() == [:foundation]
    end

    test "provision grain links to LAT" do
      sp = SubPatterns.new(assessment_grain: :provision)
      %{raci: fields} = RACI.field_specs(sp)
      provision = Enum.find(fields, &(&1.name == "Provision"))
      assert provision.type == :link_row
      assert provision.target == :lat
    end

    test "law grain links to LRT" do
      sp = SubPatterns.new(assessment_grain: :law)
      %{raci: fields} = RACI.field_specs(sp)
      law = Enum.find(fields, &(&1.name == "Law"))
      assert law.type == :link_row
      assert law.target == :lrt
    end

    test "linked people has all four RACI roles as link_row" do
      sp = SubPatterns.new(people: :linked)
      %{raci: fields} = RACI.field_specs(sp)
      link_names = fields |> Enum.filter(&(&1.type == :link_row)) |> Enum.map(& &1.name)
      assert "Responsible" in link_names
      assert "Accountable" in link_names
      assert "Consulted" in link_names
      assert "Informed" in link_names
    end
  end

  describe "PDCA template" do
    test "requires assessment + action tracker" do
      assert :compliance_assessment in PDCA.requires()
      assert :action_tracker in PDCA.requires()
    end

    test "has PDCA phases" do
      sp = SubPatterns.new()
      %{improvements: fields} = PDCA.field_specs(sp)
      phase = Enum.find(fields, &(&1.name == "Phase"))
      assert "Plan" in phase.options
      assert "Do" in phase.options
      assert "Check" in phase.options
      assert "Act" in phase.options
    end

    test "has kanban board by phase" do
      sp = SubPatterns.new()
      %{improvements: views} = PDCA.view_specs(sp)
      kanban = Enum.find(views, &(&1.type == :kanban))
      assert kanban.stack_by == "Phase"
    end
  end

  describe "OrgStructure template" do
    test "site pattern creates sites table only" do
      sp = SubPatterns.new(org_structure: :site)
      specs = OrgStructure.field_specs(sp)
      assert Map.has_key?(specs, :sites)
      refute Map.has_key?(specs, :divisions)
    end

    test "division_site pattern creates both tables" do
      sp = SubPatterns.new(org_structure: :division_site)
      specs = OrgStructure.field_specs(sp)
      assert Map.has_key?(specs, :sites)
      assert Map.has_key?(specs, :divisions)
    end

    test "division_site sites link to divisions" do
      sp = SubPatterns.new(org_structure: :division_site)
      %{sites: fields} = OrgStructure.field_specs(sp)
      div_link = Enum.find(fields, &(&1.name == "Division"))
      assert div_link.type == :link_row
      assert div_link.target == :divisions
    end

    test "flat pattern produces no field specs" do
      sp = SubPatterns.new(org_structure: :flat)
      assert OrgStructure.field_specs(sp) == %{}
    end
  end

  describe "Registry — full template set" do
    test "all 12 templates registered" do
      assert map_size(Registry.all()) == 12
    end

    test "resolves full stack" do
      {:ok, modules} =
        Registry.resolve([
          :incident_register,
          :audit_management,
          :training_tracker,
          :document_control,
          :raci,
          :pdca,
          :org_structure
        ])

      ids = Enum.map(modules, & &1.id())

      # All 12 should be present (transitive deps pull in foundation, personnel, assessment, actions, evidence isn't needed)
      assert :foundation in ids
      assert :personnel in ids
      assert :compliance_assessment in ids
      assert :action_tracker in ids
      assert :incident_register in ids
      assert :raci in ids
      assert :pdca in ids
    end
  end
end
