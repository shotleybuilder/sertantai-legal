defmodule SertantaiLegal.Sync.Workers.SyncWorker do
  @moduledoc """
  Oban worker that wraps Engine.run and Engine.clean for persistent,
  retryable sync job execution.

  Args:
    - "sync_config_id" — UUID of the SyncConfiguration
    - "operation" — "sync", "clean", or "clean_and_sync"
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [
      period: 300,
      fields: [:args],
      keys: [:sync_config_id, :operation],
      states: :incomplete
    ]

  require Logger

  alias SertantaiLegal.Sync.Engine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"sync_config_id" => config_id, "operation" => operation}}) do
    case load_and_validate_config(config_id) do
      {:ok, _config} ->
        execute(config_id, operation)

      {:error, :not_found} ->
        Logger.warning("[SyncWorker] Config #{config_id} not found, discarding job")
        {:discard, "Sync configuration not found"}

      {:error, :inactive} ->
        Logger.info("[SyncWorker] Config #{config_id} is inactive, discarding job")
        {:discard, "Sync configuration inactive"}
    end
  end

  defp execute(config_id, operation) do
    broadcast(config_id, :started, %{operation: operation})

    result =
      case operation do
        "clean_and_sync" ->
          with {:ok, _} <- Engine.clean(config_id), do: Engine.run(config_id)

        "clean" ->
          Engine.clean(config_id)

        _sync ->
          Engine.run(config_id)
      end

    case result do
      {:ok, job} ->
        broadcast(config_id, :completed, %{
          rows_created: Map.get(job, :rows_created, 0),
          rows_updated: Map.get(job, :rows_updated, 0),
          rows_deleted: Map.get(job, :rows_deleted, 0)
        })

        :ok

      {:error, reason} ->
        broadcast(config_id, :failed, %{reason: inspect(reason)})
        {:error, reason}
    end
  end

  defp load_and_validate_config(config_id) do
    case Ash.get(SertantaiLegal.Sync.SyncConfiguration, config_id) do
      {:ok, config} ->
        if config.is_active do
          {:ok, config}
        else
          {:error, :inactive}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp broadcast(config_id, event, payload) do
    Phoenix.PubSub.broadcast(
      SertantaiLegal.PubSub,
      "sync:#{config_id}",
      {:sync_progress, event, payload}
    )
  end
end
