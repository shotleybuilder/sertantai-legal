defmodule SertantaiLegal.Sync.Templates.ComplianceEvents do
  @moduledoc """
  Compliance Events template — the L6 Events & Change Intelligence interface.

  Logs events that affect compliance status: regulatory changes, enforcement
  actions, reputational signals, internal triggers. Tracks the full lifecycle
  from detection through triage, impact assessment, response, to close-out.

  The compliance framework is source-agnostic — events arrive from fractalaw
  (legislative change detection), sertantai-enforcement (external intelligence),
  or customer direct feeds (manual entry, own webhooks). All use the same schema.

  Sub-pattern support:
  - `people: :linked` — Owner links to Personnel table
  - `people: :flat` — text field for owner name

  See `docs/compliance/l6-events/EVENTS-SCHEMA.md`.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @event_types [
    "Regulatory Change",
    "Enforcement Action",
    "Permit Change",
    "Reputational",
    "Internal Control Failure",
    "Internal Organisational",
    "Audit Finding",
    "Whistleblowing"
  ]

  @event_sources [
    "External Regulatory",
    "External Enforcement",
    "External Reputational",
    "Internal Operational",
    "Internal Organisational"
  ]

  @signal_sources [
    "fractalaw",
    "sertantai-enforcement",
    "Customer Feed",
    "Manual Entry",
    "Regulator Direct"
  ]

  @urgencies ["Immediate", "Scheduled", "Monitoring", "Background"]

  @triage_statuses ["Material", "Monitor", "Not Applicable"]

  @response_statuses ["Detected", "Triaged", "Assessing Impact", "Responding", "Closed"]

  @impl true
  def id, do: :compliance_events

  @impl true
  def name, do: "Compliance Events — L6 Change Intelligence"

  @impl true
  def requires, do: [:foundation, :controls, :compliance_assessment]

  @impl true
  def tables, do: [:compliance_events]

  @impl true
  def field_specs(sp) do
    %{
      compliance_events:
        [
          %{
            name: "Name",
            type: :text,
            primary: true,
            description: "Event name"
          },
          %{
            name: "Event",
            type: :formula,
            expression: %{baserow: "concat(field('Event_Type'), ': ', field('Title'))"},
            description: "Display: Event Type: Title"
          },
          %{name: "Title", type: :text, description: "Short description of the event"},
          %{
            name: "Event_Type",
            type: :single_select,
            options: @event_types,
            description: "Classification of the event"
          },
          %{
            name: "Event_Source",
            type: :single_select,
            options: @event_sources,
            description: "External regulatory / enforcement / reputational / internal"
          },
          %{
            name: "Signal_Source",
            type: :single_select,
            options: @signal_sources,
            description: "Which system generated this signal"
          },
          %{
            name: "Signal_Ref",
            type: :text,
            description:
              "External reference for traceability (fractalaw change ID, HSE notice number, SI number)"
          },
          %{name: "Date_Detected", type: :date, description: "When the signal was received"},
          %{
            name: "Date_Effective",
            type: :date,
            description: "When the event takes effect (commencement date, notice date)"
          },
          %{name: "Date_Closed", type: :date, description: "When the response was completed"},
          %{
            name: "Urgency",
            type: :single_select,
            options: @urgencies,
            description: "Immediate / Scheduled / Monitoring / Background"
          },
          %{
            name: "Triage_Status",
            type: :single_select,
            options: @triage_statuses,
            description: "Material / Monitor / Not Applicable"
          },
          %{
            name: "Triage_Rationale",
            type: :long_text,
            description: "Why this triage decision was made. Required for Not Applicable."
          },
          %{name: "Description", type: :long_text, description: "Full description and context"},
          %{
            name: "Impact_Summary",
            type: :long_text,
            description: "What parts of the compliance register are affected and how"
          },
          %{
            name: "Response_Status",
            type: :single_select,
            options: @response_statuses,
            description: "Detected / Triaged / Assessing Impact / Responding / Closed"
          },
          %{
            name: "Legal_Register",
            type: :link_row,
            target: :lrt,
            description: "Which laws are affected by this event"
          },
          %{
            name: "Controls",
            type: :link_row,
            target: :controls,
            description: "Which controls need review because of this event"
          },
          %{
            name: "Assessments",
            type: :link_row,
            target: :assessments,
            description: "Which assessments need re-evaluation"
          },
          %{
            name: "Artefacts",
            type: :link_row,
            target: :artefacts,
            description:
              "If this event produced an artefact (enforcement notice, consultation response)"
          }
        ] ++
          owner_fields(sp.people) ++
          [
            %{name: "Notes", type: :long_text, description: "Additional context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      compliance_events: [
        %{name: "All Events", type: :grid},
        %{
          name: "Open Events",
          type: :grid,
          filters: [%{field: "Response_Status", op: :not_equal, value: "Closed"}]
        },
        %{
          name: "Material Events",
          type: :grid,
          filters: [%{field: "Triage_Status", op: :equal, value: "Material"}]
        },
        %{name: "By Type", type: :grid, group_by: "Event_Type"},
        %{name: "By Urgency", type: :kanban, stack_by: "Urgency"},
        %{name: "Event Board", type: :kanban, stack_by: "Response_Status"},
        %{
          name: "Monitoring",
          type: :grid,
          filters: [%{field: "Triage_Status", op: :equal, value: "Monitor"}]
        }
      ]
    }
  end

  # No seed — events are created by signal sources or manual entry.

  # ── Owner fields (people sub-pattern) ────────────────────────

  defp owner_fields(:linked) do
    [
      %{
        name: "Owner",
        type: :link_row,
        target: :personnel,
        description: "Who owns the response to this event"
      }
    ]
  end

  defp owner_fields(:workspace_member) do
    [%{name: "Owner", type: :workspace_member, description: "Who owns the response"}]
  end

  defp owner_fields(:hybrid) do
    [
      %{name: "Owner", type: :workspace_member, description: "Who owns the response"},
      %{
        name: "Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Accountable person in org"
      }
    ]
  end

  defp owner_fields(:flat) do
    [%{name: "Owner", type: :text, description: "Who owns the response to this event"}]
  end
end
