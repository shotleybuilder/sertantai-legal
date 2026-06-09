defmodule SertantaiLegal.Sync.Templates.AuditManagement do
  @moduledoc """
  Audit Management template — plan, conduct, and track audits.

  Informed by ISO 19011. Links findings to actions for follow-up.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @audit_types ["Internal", "External", "Regulatory"]
  @conclusions ["Conforming", "Minor Non-Conformance", "Major Non-Conformance", "Observation"]

  @impl true
  def id, do: :audit_management

  @impl true
  def name, do: "Audit Management"

  @impl true
  def requires, do: [:compliance_assessment, :action_tracker]

  @impl true
  def tables, do: [:audits]

  @impl true
  def field_specs(sp) do
    %{
      audits:
        [
          %{name: "SA_Audit_Name", type: :text, description: "Title/scope"},
          %{name: "SA_Type", type: :single_select, options: @audit_types}
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Audit_Date", type: :date, description: "When conducted"},
            %{name: "SA_Scope", type: :long_text, description: "What was audited"},
            %{name: "SA_Findings", type: :long_text, description: "Summary of findings"},
            %{
              name: "SA_Related_Actions",
              type: :link_row,
              target: :actions,
              description: "Actions raised from audit"
            }
          ] ++
          report_fields(sp.storage_mode) ++
          [
            %{name: "SA_Conclusion", type: :single_select, options: @conclusions},
            %{name: "SA_Next_Audit_Date", type: :date, description: "Scheduled follow-up"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      audits: [
        %{name: "All Audits", type: :grid},
        %{name: "By Type", type: :grid, group_by: "SA_Type"},
        %{name: "Audit Calendar", type: :calendar, date_field: "SA_Next_Audit_Date"},
        %{name: "By Conclusion", type: :grid, group_by: "SA_Conclusion"}
      ]
    }
  end

  defp people_fields(:linked) do
    [%{name: "SA_Auditor", type: :link_row, target: :personnel, description: "Who conducted"}]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Auditor", type: :text, description: "Who conducted"}]
  end

  defp report_fields(:embedded) do
    [%{name: "SA_Report", type: :file, description: "Audit report document"}]
  end

  defp report_fields(:reference) do
    [%{name: "SA_Report_URL", type: :url, description: "Link to audit report in DMS"}]
  end
end
