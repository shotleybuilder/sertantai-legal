defmodule SertantaiLegal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach telemetry handler for metrics collection (dev only, not test)
    # Test runs generate many telemetry events that pollute the metrics files
    unless Application.get_env(:sertantai_legal, :test_mode, false) do
      SertantaiLegal.Metrics.TelemetryHandler.attach()
    end

    children =
      [
        SertantaiLegalWeb.Telemetry,
        SertantaiLegal.Repo,
        {Oban, Application.fetch_env!(:sertantai_legal, Oban)},
        {DNSCluster, query: Application.get_env(:sertantai_legal, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: SertantaiLegal.PubSub},
        # JWKS client — fetches EdDSA public key from sertantai-auth for JWT verification
        # In test mode, skips HTTP fetch — tests call set_test_key/1 instead
        SertantaiLegal.Auth.JwksClient,
        # Supervised async tasks (used by HubNotifier for fire-and-forget HTTP)
        {Task.Supervisor, name: SertantaiLegal.TaskSupervisor},
        # Zenoh P2P mesh — publishes LRT/LAT/amendments to fractalaw
        # Suppressed in mix task context to avoid port conflicts with the running server
        if(Application.get_env(:sertantai_legal, :zenoh)[:enabled] and server_mode?(),
          do: SertantaiLegal.Zenoh.Supervisor
        ),
        # Actor dictionary — loaded from Zenoh (must start after Zenoh), falls back to YAML snapshot
        SertantaiLegal.Legal.ActorDictionary,
        # Start to serve requests, typically the last entry
        SertantaiLegalWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SertantaiLegal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Suppress Zenoh in mix task context to avoid port conflicts with the running server.
  # Cannot check Endpoint[:server] — Phoenix sets it after Application.start/2.
  # Instead, check :phoenix :serve_endpoints which mix phx.server sets before app start.
  defp server_mode? do
    Application.get_env(:phoenix, :serve_endpoints, false) == true
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SertantaiLegalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
