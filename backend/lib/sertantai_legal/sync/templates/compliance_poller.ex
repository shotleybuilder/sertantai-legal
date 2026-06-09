defmodule SertantaiLegal.Sync.Templates.CompliancePoller do
  @moduledoc """
  Periodic polling fallback for compliance metrics.

  Baserow webhooks are fire-and-forget — if sertantai is down when an
  event fires, it's lost. This poller reconciles by fetching assessment
  and action status directly from Baserow every N hours.

  Runs as a periodic Task under the application supervisor.
  Default interval: 6 hours.
  """

  use GenServer
  require Logger

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.Templates.ComplianceMetrics

  @default_interval_ms :timer.hours(6)

  # ── Client API ──────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger an immediate poll for all orgs (e.g., from mix task or admin endpoint)."
  def poll_now do
    GenServer.cast(__MODULE__, :poll_now)
  end

  # ── Server Callbacks ────────────────────────────────────────

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval_ms)

    # Don't poll immediately on startup — wait one interval
    timer = Process.send_after(self(), :poll, interval)

    {:ok, %{interval: interval, timer: timer}}
  end

  @impl true
  def handle_info(:poll, state) do
    do_poll()
    timer = Process.send_after(self(), :poll, state.interval)
    {:noreply, %{state | timer: timer}}
  end

  @impl true
  def handle_cast(:poll_now, state) do
    do_poll()
    {:noreply, state}
  end

  # ── Polling Logic ───────────────────────────────────────────

  defp do_poll do
    Logger.info("[CompliancePoller] Starting reconciliation poll")

    case load_orgs_with_sync_configs() do
      [] ->
        Logger.debug("[CompliancePoller] No orgs with sync configurations")

      orgs ->
        Enum.each(orgs, fn {org_id, config} ->
          poll_org(org_id, config)
        end)

        Logger.info("[CompliancePoller] Reconciliation complete for #{length(orgs)} org(s)")
    end
  end

  defp poll_org(org_id, config) do
    # Poll assessment table for compliance status distribution
    assessments_table = config["assessments_table_id"]
    actions_table = config["actions_table_id"]

    if assessments_table do
      case poll_assessment_counts(config, assessments_table) do
        {:ok, counts} ->
          reconcile_metrics(org_id, counts)

        {:error, reason} ->
          Logger.warning("[CompliancePoller] Failed to poll assessments for #{org_id}: #{reason}")
      end
    end

    if actions_table do
      case poll_action_counts(config, actions_table) do
        {:ok, counts} ->
          reconcile_action_metrics(org_id, counts)

        {:error, reason} ->
          Logger.warning("[CompliancePoller] Failed to poll actions for #{org_id}: #{reason}")
      end
    end
  end

  defp poll_assessment_counts(config, table_id) do
    provider = SertantaiLegal.Sync.Providers.Baserow

    # Use Baserow's row list with field filters to count by status
    # This is a simple GET with search params — no batch needed
    base_url = config["base_url"] || ""
    jwt = config["jwt"]

    if jwt do
      url =
        "#{base_url}/api/database/rows/table/#{table_id}/" <>
          "?user_field_names=true&size=1&count=true" <>
          "&filter__SA_Compliance_Status__not_empty=true"

      case Req.get(url,
             headers: [
               {"Authorization", "JWT #{jwt}"},
               {"Content-Type", "application/json"}
             ],
             receive_timeout: 30_000
           ) do
        {:ok, %{status: 200, body: %{"count" => _total} = body}} ->
          # For now, return total count — detailed status breakdown
          # requires multiple filtered queries or processing all rows
          {:ok, %{total: body["count"]}}

        {:ok, %{status: status}} ->
          {:error, "Baserow returned #{status}"}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
    else
      {:error, "No JWT — authenticate first"}
    end
  end

  defp poll_action_counts(_config, _table_id) do
    # Stub — same pattern as assessment polling
    {:ok, %{}}
  end

  defp reconcile_metrics(org_id, polled_counts) do
    current = ComplianceMetrics.get_metrics(org_id)

    # If polled total differs significantly from ETS total, log a warning
    ets_total = current.compliant + current.non_compliant + current.partially_compliant
    polled_total = polled_counts[:total] || 0

    if polled_total > 0 and abs(ets_total - polled_total) > 5 do
      Logger.warning(
        "[CompliancePoller] Org #{org_id}: ETS has #{ets_total} assessed, " <>
          "Baserow has #{polled_total} — drift detected, webhooks may have been missed"
      )
    end

    # Update last_synced_at
    updated = %{current | last_synced_at: DateTime.utc_now()}
    :ets.insert(:compliance_metrics, {org_id, updated})
  end

  defp reconcile_action_metrics(_org_id, _polled_counts) do
    # Stub — same reconciliation pattern
    :ok
  end

  # ── Data helpers ────────────────────────────────────────────

  defp load_orgs_with_sync_configs do
    case Repo.query("""
         SELECT sc.organization_id,
                sc.target_config
         FROM sync_configurations sc
         WHERE sc.sync_status != 'failed'
           AND sc.target_config IS NOT NULL
         """) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [org_id, config] ->
          org_str =
            case Ecto.UUID.load(org_id) do
              {:ok, str} -> str
              _ -> org_id
            end

          {org_str, config || %{}}
        end)

      _ ->
        []
    end
  end
end
