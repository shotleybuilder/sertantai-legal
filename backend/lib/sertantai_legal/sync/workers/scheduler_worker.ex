defmodule SertantaiLegal.Sync.Workers.SchedulerWorker do
  @moduledoc """
  Cron-driven worker that checks for due recurring syncs and enqueues them.

  Runs every 6 hours via Oban.Plugins.Cron. For each active SyncConfiguration
  with a non-manual sync_frequency, checks whether enough time has elapsed
  since last_synced_at and enqueues a SyncWorker job if due.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  require Logger

  alias SertantaiLegal.Sync.SyncConfiguration
  alias SertantaiLegal.Sync.Workers.SyncWorker

  @frequency_intervals %{
    daily: 86_400,
    weekly: 604_800
  }

  @impl Oban.Worker
  def perform(_job) do
    {:ok, configs} = Ash.read(SyncConfiguration)

    due_configs = Enum.filter(configs, &should_sync?/1)

    Enum.each(due_configs, fn config ->
      case SyncWorker.new(%{"sync_config_id" => config.id, "operation" => "sync"})
           |> Oban.insert() do
        {:ok, oban_job} ->
          Logger.info("[SchedulerWorker] Enqueued sync for #{config.name} (Oban ##{oban_job.id})")

        {:error, reason} ->
          Logger.warning(
            "[SchedulerWorker] Failed to enqueue sync for #{config.name}: #{inspect(reason)}"
          )
      end
    end)

    Logger.info(
      "[SchedulerWorker] Checked #{length(configs)} configs, #{length(due_configs)} due"
    )

    :ok
  end

  defp should_sync?(config) do
    config.is_active &&
      config.sync_frequency != :manual &&
      elapsed_since_last_sync(config) >= interval_for(config.sync_frequency)
  end

  defp elapsed_since_last_sync(%{last_synced_at: nil}), do: :infinity

  defp elapsed_since_last_sync(%{last_synced_at: ts}) do
    DateTime.diff(DateTime.utc_now(), ts, :second)
  end

  defp interval_for(frequency) do
    Map.get(@frequency_intervals, frequency, :infinity)
  end
end
