defmodule SertantaiLegal.Zenoh.ChangeNotifier do
  @moduledoc """
  Publishes change notifications to the Zenoh mesh.

  When legislation data is modified (scrape imports, CSV enrichment),
  call `notify/3` to inform connected peers that they should re-query.

  Publishes to: fractalaw/@{tenant}/events/data-changed
  """

  use GenServer
  require Logger

  alias SertantaiLegal.Zenoh.ActivityLog

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns current status for the admin dashboard."
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{state: :stopped}
  end

  @doc """
  Notify connected peers that data has changed.

  ## Examples

      ChangeNotifier.notify("uk_lrt", "bulk_update", %{count: 452})
      ChangeNotifier.notify("lat", "import", %{law_name: "UK_ukpga_1974_37"})
  """
  @spec notify(String.t(), String.t(), map()) :: :ok
  def notify(table, action, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:notify, table, action, metadata})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    ActivityLog.set_status(:change_notifier, :connecting)
    send(self(), :setup)
    {:ok, %{publisher_id: nil, poll_count: 0, key: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = tenant_id()
        key = "fractalaw/@#{tenant}/events/data-changed"

        case Zenohex.Session.declare_publisher(session_id, key) do
          {:ok, pub_id} ->
            Logger.info("[Zenoh.ChangeNotifier] Publisher declared: #{key}")
            ActivityLog.set_status(:change_notifier, :ready)
            ActivityLog.record(:change_notifier, :connected, %{key: key})
            {:noreply, %{state | publisher_id: pub_id, key: key}}

          {:error, reason} ->
            Logger.error("[Zenoh.ChangeNotifier] Failed to declare publisher: #{inspect(reason)}")
            {:stop, :publisher_failed, state}
        end

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.ChangeNotifier] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:notify, _table, _action, _metadata}, %{publisher_id: nil} = state) do
    Logger.warning("[Zenoh.ChangeNotifier] Publisher not ready, dropping notification")
    ActivityLog.increment(:change_notifier, :dropped)
    {:noreply, state}
  end

  def handle_cast({:notify, table, action, metadata}, state) do
    payload =
      Jason.encode!(%{
        table: table,
        action: action,
        metadata: metadata,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    case Zenohex.Publisher.put(state.publisher_id, payload) do
      :ok ->
        ActivityLog.increment(:change_notifier, :published)
        ActivityLog.record(:change_notifier, :published, %{table: table, action: action})
        Logger.debug("[Zenoh.ChangeNotifier] Published: #{table}/#{action}")

      {:error, reason} ->
        ActivityLog.increment(:change_notifier, :errors)
        ActivityLog.record(:change_notifier, :error, %{table: table, reason: inspect(reason)})
        Logger.warning("[Zenoh.ChangeNotifier] Publish failed: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      state: if(state.publisher_id, do: :ready, else: :connecting),
      key: state.key
    }

    {:reply, status, state}
  end

  # --- Private ---

  defp tenant_id do
    Application.get_env(:sertantai_legal, :zenoh, [])
    |> Keyword.get(:tenant, "dev")
  end
end
