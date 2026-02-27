defmodule SertantaiLegal.Zenoh.Supervisor do
  @moduledoc """
  Supervises the Zenoh P2P mesh processes.

  Children start in order: Session first (owns the connection),
  then DataServer and ChangeNotifier (depend on Session).

  Uses :rest_for_one — if Session crashes, DataServer and ChangeNotifier
  restart too (they need a fresh session_id).
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      SertantaiLegal.Zenoh.ActivityLog,
      SertantaiLegal.Zenoh.Session,
      SertantaiLegal.Zenoh.DataServer,
      SertantaiLegal.Zenoh.ChangeNotifier,
      SertantaiLegal.Zenoh.TaxaSubscriber
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
