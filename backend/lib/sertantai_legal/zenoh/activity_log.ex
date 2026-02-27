defmodule SertantaiLegal.Zenoh.ActivityLog do
  @moduledoc """
  ETS-backed activity log and counters for Zenoh services.

  Provides lightweight telemetry for the admin dashboard:
  - Counters: increment-only metrics (received, updated, failed, etc.)
  - Activity log: recent events with timestamps (capped at @max_entries per service)
  - Status tracking: current state of each service
  """

  use GenServer

  @table :zenoh_activity_log
  @max_entries 100

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Record an activity event for a service."
  @spec record(atom(), atom(), map()) :: :ok
  def record(service, event, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record, service, event, metadata})
  end

  @doc "Increment a counter for a service."
  @spec increment(atom(), atom()) :: :ok
  def increment(service, counter) do
    GenServer.cast(__MODULE__, {:increment, service, counter})
  end

  @doc "Set the status for a service."
  @spec set_status(atom(), atom()) :: :ok
  def set_status(service, status) do
    GenServer.cast(__MODULE__, {:set_status, service, status})
  end

  @doc "Get counters for a service."
  @spec get_stats(atom()) :: map()
  def get_stats(service) do
    GenServer.call(__MODULE__, {:get_stats, service})
  end

  @doc "Get recent activity entries for a service."
  @spec get_recent(atom(), pos_integer()) :: list(map())
  def get_recent(service, limit \\ 50) do
    GenServer.call(__MODULE__, {:get_recent, service, limit})
  end

  @doc "Get stats for all tracked services."
  @spec get_all_stats() :: map()
  def get_all_stats do
    GenServer.call(__MODULE__, :get_all_stats)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_cast({:record, service, event, metadata}, state) do
    now = DateTime.utc_now()

    entry = %{
      event: event,
      metadata: metadata,
      timestamp: DateTime.to_iso8601(now)
    }

    key = {:log, service, System.monotonic_time(:nanosecond)}
    :ets.insert(@table, {key, entry})

    trim_log(service)
    {:noreply, state}
  end

  def handle_cast({:increment, service, counter}, state) do
    key = {:counter, service, counter}

    try do
      :ets.update_counter(@table, key, {2, 1})
    rescue
      ArgumentError ->
        :ets.insert(@table, {key, 1})
    end

    {:noreply, state}
  end

  def handle_cast({:set_status, service, status}, state) do
    :ets.insert(@table, {{:status, service}, status})
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_stats, service}, _from, state) do
    counters =
      :ets.match(@table, {{:counter, service, :"$1"}, :"$2"})
      |> Enum.into(%{}, fn [name, value] -> {name, value} end)

    status =
      case :ets.lookup(@table, {:status, service}) do
        [{_, s}] -> s
        [] -> :unknown
      end

    {:reply, Map.put(counters, :status, status), state}
  end

  def handle_call({:get_recent, service, limit}, _from, state) do
    entries =
      :ets.match(@table, {{:log, service, :"$1"}, :"$2"})
      |> Enum.sort_by(fn [ts, _] -> ts end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn [_ts, entry] -> entry end)

    {:reply, entries, state}
  end

  def handle_call(:get_all_stats, _from, state) do
    services = [:taxa_subscriber, :data_server, :change_notifier]

    stats =
      Enum.into(services, %{}, fn service ->
        counters =
          :ets.match(@table, {{:counter, service, :"$1"}, :"$2"})
          |> Enum.into(%{}, fn [name, value] -> {name, value} end)

        status =
          case :ets.lookup(@table, {:status, service}) do
            [{_, s}] -> s
            [] -> :unknown
          end

        {service, Map.put(counters, :status, status)}
      end)

    {:reply, stats, state}
  end

  # --- Private ---

  defp trim_log(service) do
    entries =
      :ets.match(@table, {{:log, service, :"$1"}, :_})
      |> Enum.map(fn [ts] -> ts end)
      |> Enum.sort()

    if length(entries) > @max_entries do
      to_remove = Enum.take(entries, length(entries) - @max_entries)

      Enum.each(to_remove, fn ts ->
        :ets.delete(@table, {:log, service, ts})
      end)
    end
  end
end
