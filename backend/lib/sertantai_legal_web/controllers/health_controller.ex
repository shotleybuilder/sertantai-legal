defmodule SertantaiLegalWeb.HealthController do
  @moduledoc """
  Health check endpoints for monitoring and load balancing.

  Provides two endpoints:
  - GET /health - Basic health check (fast, for load balancers)
  - GET /health/detailed - Comprehensive health check (includes database connectivity)
  """

  use SertantaiLegalWeb, :controller

  @doc """
  Basic health check endpoint.
  Returns 200 OK if service is running.
  Used by load balancers, Docker health checks, and uptime monitors.
  """
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      service: "sertantai-legal",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Detailed health check endpoint.
  Includes database connectivity and service information.
  Returns 200 if healthy, 503 if any check fails.
  """
  def show(conn, _params) do
    health_status = %{
      status: "healthy",
      service: "sertantai-legal",
      version: Application.spec(:sertantai_legal, :vsn) |> to_string(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: %{
        database: check_database(),
        application: check_application()
      }
    }

    # Return 200 if healthy, 503 if any check fails
    status_code = if all_checks_healthy?(health_status), do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(health_status)
  end

  # Private helper functions

  defp check_database do
    try do
      # Simple query to verify database connectivity
      case Ecto.Adapters.SQL.query(SertantaiLegal.Repo, "SELECT 1", []) do
        {:ok, _} ->
          %{status: "healthy", message: "Database connection successful"}

        {:error, reason} ->
          %{status: "unhealthy", message: "Database error: #{inspect(reason)}"}
      end
    rescue
      error ->
        %{status: "unhealthy", message: "Database exception: #{inspect(error)}"}
    end
  end

  defp check_application do
    %{
      status: "healthy",
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      node: Node.self(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version()
    }
  end

  defp all_checks_healthy?(health_status) do
    health_status.checks
    |> Map.values()
    |> Enum.all?(fn check ->
      case check do
        %{status: "healthy"} -> true
        _ -> false
      end
    end)
  end
end
