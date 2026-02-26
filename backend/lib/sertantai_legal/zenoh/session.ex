defmodule SertantaiLegal.Zenoh.Session do
  @moduledoc """
  Manages the Zenoh session lifecycle.

  Opens a Zenoh session in peer mode with optional connect endpoints.
  Other GenServers retrieve the session_id via `session_id/0`.
  """

  use GenServer
  require Logger

  @retry_interval :timer.seconds(5)

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec session_id() :: {:ok, reference()} | {:error, :not_ready}
  def session_id do
    GenServer.call(__MODULE__, :session_id)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    send(self(), :open)
    {:ok, %{session_id: nil, config: zenoh_config()}}
  end

  @impl true
  def handle_call(:session_id, _from, %{session_id: nil} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:session_id, _from, state) do
    {:reply, {:ok, state.session_id}, state}
  end

  @impl true
  def handle_info(:open, state) do
    case Zenohex.Session.open(state.config) do
      {:ok, session_id} ->
        Logger.info("[Zenoh] Session opened successfully")
        {:noreply, %{state | session_id: session_id}}

      {:error, reason} ->
        Logger.warning("[Zenoh] Failed to open session: #{inspect(reason)}, retrying in 5s")
        Process.send_after(self(), :open, @retry_interval)
        {:noreply, state}
    end
  end

  # --- Private ---

  defp zenoh_config do
    app_config = Application.get_env(:sertantai_legal, :zenoh, [])
    endpoints = Keyword.get(app_config, :connect_endpoints, [])

    config = Zenohex.Config.default()

    config =
      Zenohex.Config.update_in(config, ["mode"], fn _ -> "peer" end)

    if endpoints != [] do
      Zenohex.Config.update_in(config, ["connect", "endpoints"], fn _ -> endpoints end)
    else
      config
    end
  end
end
