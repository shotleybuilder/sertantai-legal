defmodule SertantaiLegal.Sync.Templates.DocumentControl do
  @moduledoc """
  Document Control template — governing documents (policies, procedures, work instructions).

  Distinct from Evidence Vault — these are the org's own documents that
  demonstrate their compliance management system. Tracks versioning,
  ownership, approval, and review cycles.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @doc_types ["Policy", "Procedure", "Work Instruction", "Form", "Register", "Other"]
  @statuses ["Approved", "Draft", "Under Review", "Obsolete"]

  @impl true
  def id, do: :document_control

  @impl true
  def name, do: "Document Control"

  @impl true
  def requires, do: [:foundation]

  @impl true
  def tables, do: [:documents]

  @impl true
  def field_specs(sp) do
    %{
      documents:
        [
          %{name: "SA_Document_Title", type: :text, description: "Name"},
          %{name: "SA_Type", type: :single_select, options: @doc_types},
          %{name: "SA_Version", type: :text, description: "Current version"}
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Approval_Date", type: :date, description: "When approved"},
            %{name: "SA_Review_Date", type: :date, description: "When next review due"},
            %{name: "SA_Status", type: :single_select, options: @statuses}
          ] ++
          file_fields(sp.storage_mode) ++
          [
            %{
              name: "SA_Related_Laws",
              type: :link_row,
              target: :lrt,
              description: "Laws this document addresses"
            },
            %{name: "SA_Notes", type: :long_text, description: "Context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      documents: [
        %{name: "All Documents", type: :grid},
        %{name: "By Type", type: :grid, group_by: "SA_Type"},
        %{name: "By Status", type: :kanban, stack_by: "SA_Status"},
        %{name: "Review Calendar", type: :calendar, date_field: "SA_Review_Date"}
      ]
    }
  end

  defp people_fields(:linked) do
    [%{name: "SA_Owner", type: :link_row, target: :personnel, description: "Document owner"}]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Owner", type: :text, description: "Document owner"}]
  end

  defp file_fields(:embedded) do
    [%{name: "SA_File", type: :file, description: "The document"}]
  end

  defp file_fields(:reference) do
    [%{name: "SA_Document_URL", type: :url, description: "Link to document in DMS"}]
  end
end
