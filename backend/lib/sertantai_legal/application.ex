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
        {DNSCluster, query: Application.get_env(:sertantai_legal, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: SertantaiLegal.PubSub},
        # JWKS client — fetches EdDSA public key from sertantai-auth for JWT verification
        # In test mode, skips HTTP fetch — tests call set_test_key/1 instead
        SertantaiLegal.Auth.JwksClient,
        # Start to serve requests, typically the last entry
        SertantaiLegalWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SertantaiLegal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SertantaiLegalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
