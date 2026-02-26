import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/sertantai_legal start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :sertantai_legal, SertantaiLegalWeb.Endpoint, server: true
end

# ElectricSQL upstream URL — env var overrides config files
if electric_url = System.get_env("ELECTRIC_URL") do
  config :sertantai_legal,
    electric_url: electric_url
end

# Auth service URL for Gatekeeper shape validation
if auth_url = System.get_env("AUTH_URL") do
  config :sertantai_legal,
    auth_url: auth_url
end

# ElectricSQL secret — required in production (ELECTRIC_INSECURE=true bypasses in dev)
if electric_secret = System.get_env("ELECTRIC_SECRET") do
  config :sertantai_legal,
    electric_secret: electric_secret
end

# GitHub OAuth admin configuration (all environments)
if github_client_id =
     System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_ID") || System.get_env("GITHUB_CLIENT_ID") do
  if github_client_secret =
       System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_SECRET") ||
         System.get_env("GITHUB_CLIENT_SECRET") do
    config :sertantai_legal, :github_oauth,
      client_id: github_client_id,
      client_secret: github_client_secret,
      redirect_uri:
        System.get_env("SERTANTAI_LEGAL_GITHUB_REDIRECT_URI") ||
          System.get_env("GITHUB_REDIRECT_URI") ||
          "http://localhost:4003/auth/user/github/callback"
  end
end

if allowed_users =
     System.get_env("SERTANTAI_LEGAL_GITHUB_ALLOWED_USERS") ||
       System.get_env("GITHUB_ALLOWED_USERS") do
  config :sertantai_legal, :github_admin,
    allowed_users:
      allowed_users
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
end

if token_secret = System.get_env("TOKEN_SIGNING_SECRET") do
  config :sertantai_legal, :token_signing_secret, token_secret
end

if frontend_url = System.get_env("FRONTEND_URL") do
  config :sertantai_legal, :frontend_url, frontend_url
end

# Hub notifier — notify sertantai-hub of law changes for user notifications
# Supports both SERTANTAI_LEGAL_HUB_* (infrastructure) and HUB_* (local dev) prefixes
if hub_enabled =
     System.get_env("SERTANTAI_LEGAL_HUB_ENABLED") || System.get_env("HUB_ENABLED") do
  config :sertantai_legal, :hub,
    enabled: hub_enabled in ~w(true 1),
    url:
      System.get_env("SERTANTAI_LEGAL_HUB_URL") ||
        System.get_env("HUB_URL", "http://localhost:4000"),
    api_key: System.get_env("SERTANTAI_LEGAL_HUB_API_KEY") || System.get_env("HUB_API_KEY")
end

# Zenoh P2P mesh configuration
# Supports both SERTANTAI_LEGAL_ZENOH_* (infrastructure) and ZENOH_* (local dev) prefixes
if zenoh_enabled =
     System.get_env("SERTANTAI_LEGAL_ZENOH_ENABLED") || System.get_env("ZENOH_ENABLED") do
  connect_endpoints =
    (System.get_env("SERTANTAI_LEGAL_ZENOH_CONNECT") || System.get_env("ZENOH_CONNECT") || "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))

  config :sertantai_legal, :zenoh,
    enabled: zenoh_enabled in ~w(true 1),
    tenant:
      System.get_env("SERTANTAI_LEGAL_ZENOH_TENANT") || System.get_env("ZENOH_TENANT", "dev"),
    connect_endpoints: connect_endpoints
end

if config_env() == :prod do
  # Production uses DATABASE_URL (standard for most hosting platforms)
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :sertantai_legal, SertantaiLegal.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "legal.sertantai.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :sertantai_legal, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :sertantai_legal, SertantaiLegalWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # AUTH_URL is optional — without it, JwksClient runs in degraded mode
  # (JWT tenant auth disabled, but GitHub OAuth admin auth still works)
  unless System.get_env("AUTH_URL") do
    IO.puts("[warning] AUTH_URL not set — JWT tenant auth will be unavailable")
  end

  # GitHub OAuth is required in production
  unless System.get_env("GITHUB_CLIENT_ID") || System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_ID") do
    raise """
    environment variable GITHUB_CLIENT_ID is missing.
    Required for GitHub OAuth admin authentication.
    """
  end

  unless System.get_env("GITHUB_CLIENT_SECRET") ||
           System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_SECRET") do
    raise """
    environment variable GITHUB_CLIENT_SECRET is missing.
    Required for GitHub OAuth admin authentication.
    """
  end

  unless System.get_env("TOKEN_SIGNING_SECRET") do
    raise """
    environment variable TOKEN_SIGNING_SECRET is missing.
    Required for OAuth session token signing.
    """
  end
end
