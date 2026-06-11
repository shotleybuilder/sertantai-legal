# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :sertantai_legal,
  ecto_repos: [SertantaiLegal.Repo],
  ash_domains: [SertantaiLegal.Api, SertantaiLegal.Sync],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :sertantai_legal, SertantaiLegalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: SertantaiLegalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SertantaiLegal.PubSub,
  live_view: [signing_salt: "xjXQzhFq"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Oban job queue
config :sertantai_legal, Oban,
  repo: SertantaiLegal.Repo,
  queues: [default: 10, sync: 2],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 */6 * * *", SertantaiLegal.Sync.Workers.SchedulerWorker}
     ]}
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
