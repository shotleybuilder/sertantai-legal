import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sertantai_legal, SertantaiLegal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5436,
  database: "sertantai_legal_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sertantai_legal, SertantaiLegalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "HCp9ifzqJOPrl5gDO/Zy1T68zrYUtBeEwnj1zDnoLK111ULv/+Iq9uzmS6amq0lV",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable test mode for HTTP client mocking
config :sertantai_legal, test_mode: true

# Auth + Electric config for tests
# jwks_req_plug routes JWKS HTTP calls through Req.Test stubs
config :sertantai_legal,
  electric_url: "http://localhost:3002",
  auth_url: "http://localhost:4000",
  jwks_req_plug: {Req.Test, SertantaiLegal.Auth.JwksClient}

# Admin OAuth config for tests
config :sertantai_legal,
       :token_signing_secret,
       "test-only-secret-not-for-production"

config :sertantai_legal, :github_admin, allowed_users: ["test-admin"]

config :sertantai_legal, :frontend_url, "http://localhost:5175"
