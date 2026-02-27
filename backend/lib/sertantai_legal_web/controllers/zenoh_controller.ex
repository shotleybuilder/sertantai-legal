defmodule SertantaiLegalWeb.ZenohController do
  @moduledoc """
  Admin API endpoints for Zenoh P2P mesh monitoring.

  Provides status, counters, and recent activity for:
  - Subscriptions (TaxaSubscriber)
  - Queryables (DataServer) and Publishers (ChangeNotifier)

  Gracefully handles Zenoh being disabled (ZENOH_ENABLED=false).
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Zenoh.{ActivityLog, TaxaSubscriber, DataServer, ChangeNotifier}

  @doc "GET /api/zenoh/subscriptions — TaxaSubscriber status + activity"
  def subscriptions(conn, _params) do
    if zenoh_enabled?() do
      status = TaxaSubscriber.status()
      stats = safe_get_stats(:taxa_subscriber)
      recent = safe_get_recent(:taxa_subscriber)

      json(conn, %{status: status, stats: stats, recent: recent})
    else
      json(conn, %{
        status: %{state: :disabled},
        stats: %{status: :disabled},
        recent: []
      })
    end
  end

  @doc "GET /api/zenoh/queryables — DataServer + ChangeNotifier status + activity"
  def queryables(conn, _params) do
    if zenoh_enabled?() do
      json(conn, %{
        data_server: %{
          status: DataServer.status(),
          stats: safe_get_stats(:data_server),
          recent: safe_get_recent(:data_server)
        },
        change_notifier: %{
          status: ChangeNotifier.status(),
          stats: safe_get_stats(:change_notifier),
          recent: safe_get_recent(:change_notifier)
        }
      })
    else
      disabled = %{status: %{state: :disabled}, stats: %{status: :disabled}, recent: []}
      json(conn, %{data_server: disabled, change_notifier: disabled})
    end
  end

  defp zenoh_enabled? do
    Application.get_env(:sertantai_legal, :zenoh, [])[:enabled] == true
  end

  defp safe_get_stats(service) do
    ActivityLog.get_stats(service)
  catch
    :exit, _ -> %{status: :stopped}
  end

  defp safe_get_recent(service) do
    ActivityLog.get_recent(service, 50)
  catch
    :exit, _ -> []
  end
end
