defmodule SertantaiLegalWeb.ZenohController do
  @moduledoc """
  Admin API endpoints for Zenoh P2P mesh monitoring.

  Provides status, counters, and recent activity for:
  - Subscriptions (TaxaSubscriber)
  - Queryables (DataServer) and Publishers (ChangeNotifier)

  Gracefully handles Zenoh being disabled (ZENOH_ENABLED=false).
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Zenoh.{
    ActivityLog,
    TaxaSubscriber,
    ProvisionSubscriber,
    DataServer,
    ChangeNotifier
  }

  @doc "GET /api/zenoh/subscriptions — TaxaSubscriber + ProvisionSubscriber status + activity"
  def subscriptions(conn, _params) do
    if zenoh_enabled?() do
      json(conn, %{
        taxa_subscriber: %{
          status: TaxaSubscriber.status(),
          stats: safe_get_stats(:taxa_subscriber),
          recent: safe_get_recent(:taxa_subscriber)
        },
        provision_subscriber: %{
          status: ProvisionSubscriber.status(),
          stats: safe_get_stats(:provision_subscriber),
          recent: safe_get_recent(:provision_subscriber)
        }
      })
    else
      disabled = %{status: %{state: :disabled}, stats: %{status: :disabled}, recent: []}
      json(conn, %{taxa_subscriber: disabled, provision_subscriber: disabled})
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

  @doc "POST /api/zenoh/query — proxy a Zenoh GET to a remote queryable"
  def proxy_query(conn, %{"key" => key} = params) do
    if zenoh_enabled?() do
      case SertantaiLegal.Zenoh.Session.session_id() do
        {:ok, session_id} ->
          timeout = params["timeout"] || 10_000

          # Pass law names as comma-separated query parameter
          selector =
            case params["laws"] do
              nil -> key
              laws when is_list(laws) -> "#{key}?laws=#{Enum.join(laws, ",")}"
              laws when is_binary(laws) -> "#{key}?laws=#{laws}"
            end

          case Zenohex.Session.get(session_id, selector, timeout) do
            {:ok, replies} when replies != [] ->
              %{payload: response} = hd(replies)

              case Jason.decode(response) do
                {:ok, decoded} -> json(conn, decoded)
                {:error, _} -> text(conn, response)
              end

            {:ok, []} ->
              conn |> put_status(404) |> json(%{error: "no_reply"})

            {:error, reason} ->
              conn |> put_status(502) |> json(%{error: inspect(reason)})
          end

        {:error, _} ->
          conn |> put_status(503) |> json(%{error: "zenoh_not_ready"})
      end
    else
      conn |> put_status(503) |> json(%{error: "zenoh_disabled"})
    end
  end

  def proxy_query(conn, _params) do
    conn |> put_status(400) |> json(%{error: "key parameter required"})
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
