defmodule SertantaiLegal.Integrations.HubNotifier do
  @moduledoc """
  Notifies sertantai-hub of law changes for user notification matching.

  Called after the scraper persists new or updated laws. Sends a batch
  of change summaries to the hub's webhook endpoint. The hub matches
  changes against user notification subscriptions and delivers alerts.

  Fire-and-forget via Task.Supervisor — does not block the scraper pipeline.
  No-op when `:hub` config has `enabled: false`.
  """

  require Logger

  @doc """
  Notify hub that laws were created or updated.

  `changes` is a list of maps with keys:
    `:law_name`, `:law_title`, `:change_type`, `:families`,
    `:geo_extent`, `:type_code`, `:year`

  Runs async under Task.Supervisor. Returns immediately.
  """
  @spec notify(list(map()), String.t() | nil) :: :ok
  def notify(changes, batch_id \\ nil)
  def notify([], _batch_id), do: :ok

  def notify(changes, batch_id) do
    config = Application.get_env(:sertantai_legal, :hub, [])

    if config[:enabled] do
      Task.Supervisor.start_child(SertantaiLegal.TaskSupervisor, fn ->
        do_notify(changes, batch_id || generate_batch_id(), config)
      end)
    end

    :ok
  end

  defp do_notify(changes, batch_id, config) do
    url = "#{config[:url]}/api/webhooks/law-change"

    payload = %{
      changes: changes,
      batch_id: batch_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Req.post(url,
           json: payload,
           headers: [{"x-api-key", config[:api_key] || ""}],
           receive_timeout: 10_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("[HubNotifier] Sent #{length(changes)} changes (batch: #{batch_id})")

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("[HubNotifier] Hub returned #{status}: #{inspect(body)}")

      {:error, reason} ->
        Logger.warning("[HubNotifier] Failed to reach hub: #{inspect(reason)}")
    end
  end

  defp generate_batch_id do
    "persist-#{DateTime.utc_now() |> DateTime.to_unix()}"
  end
end
