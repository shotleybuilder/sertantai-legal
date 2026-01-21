defmodule SertantaiLegal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SertantaiLegalWeb.Telemetry,
      SertantaiLegal.Repo,
      {DNSCluster, query: Application.get_env(:sertantai_legal, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SertantaiLegal.PubSub},
      # Start a worker by calling: SertantaiLegal.Worker.start_link(arg)
      # {SertantaiLegal.Worker, arg},
      # Start to serve requests, typically the last entry
      SertantaiLegalWeb.Endpoint
    ]

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
