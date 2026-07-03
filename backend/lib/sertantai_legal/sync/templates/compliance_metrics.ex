defmodule SertantaiLegal.Sync.Templates.ComplianceMetrics do
  @moduledoc """
  Processes webhook events from customer compliance workspaces
  and maintains aggregate metrics in sertantai.

  Only processes status-level data — never stores free text,
  files, or PII from the customer's workspace.

  Metrics stored per org in the `compliance_metrics` cache (ETS).
  Persisted to DB on periodic flush.
  """

  alias SertantaiLegal.Sync.Templates.WebhookEvent

  require Logger

  # ETS table for in-memory metrics
  @table :compliance_metrics

  @doc "Initialize the ETS metrics table (call from Application supervisor)."
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end

    :ok
  end

  @doc """
  Process a webhook event and update compliance metrics.

  Only handles events with compliance-relevant fields:
  - SA_Compliance_Status changes on Assessments
  - SA_Status changes on Actions
  - SA_Status changes on Evidence (expiry tracking)
  """
  def process_event(%WebhookEvent{event_type: :row_updated} = event, org_id) do
    cond do
      compliance_status_changed?(event) ->
        update_assessment_metric(org_id, event)

      action_status_changed?(event) ->
        update_action_metric(org_id, event)

      true ->
        :ignored
    end
  end

  def process_event(%WebhookEvent{event_type: :row_created} = event, org_id) do
    if action_status_changed?(event) do
      update_action_metric(org_id, event)
    else
      :ignored
    end
  end

  def process_event(_event, _org_id), do: :ignored

  @doc "Get current compliance metrics for an org."
  def get_metrics(org_id) do
    case :ets.lookup(@table, org_id) do
      [{^org_id, metrics}] -> metrics
      [] -> default_metrics()
    end
  end

  @doc "Get metrics for all orgs."
  def all_metrics do
    :ets.tab2list(@table)
    |> Map.new(fn {org_id, metrics} -> {org_id, metrics} end)
  end

  # ── Internal ──────────────────────────────────────────────────

  defp compliance_status_changed?(%{changed_fields: fields}) do
    Map.has_key?(fields, "Compliance_Status")
  end

  defp action_status_changed?(%{changed_fields: fields}) do
    Map.has_key?(fields, "Status")
  end

  defp update_assessment_metric(org_id, event) do
    new_status = event.changed_fields["Compliance_Status"]
    metrics = get_metrics(org_id)

    updated =
      case new_status do
        "Compliant" ->
          %{metrics | compliant: metrics.compliant + 1, last_assessment_at: event.timestamp}

        "Non-Compliant" ->
          %{
            metrics
            | non_compliant: metrics.non_compliant + 1,
              last_assessment_at: event.timestamp
          }

        "Partially Compliant" ->
          %{
            metrics
            | partially_compliant: metrics.partially_compliant + 1,
              last_assessment_at: event.timestamp
          }

        _ ->
          metrics
      end

    :ets.insert(@table, {org_id, updated})

    Logger.info("[ComplianceMetrics] Org #{org_id}: assessment status → #{new_status}")

    :ok
  end

  defp update_action_metric(org_id, event) do
    new_status = event.changed_fields["Status"]
    metrics = get_metrics(org_id)

    updated =
      case new_status do
        "Completed" ->
          %{metrics | actions_completed: metrics.actions_completed + 1}

        "Open" ->
          %{metrics | actions_open: metrics.actions_open + 1}

        _ ->
          metrics
      end

    :ets.insert(@table, {org_id, updated})
    :ok
  end

  defp default_metrics do
    %{
      compliant: 0,
      non_compliant: 0,
      partially_compliant: 0,
      not_assessed: 0,
      actions_open: 0,
      actions_completed: 0,
      last_assessment_at: nil,
      last_synced_at: nil
    }
  end
end
