# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :sertantai_legal,
  ecto_repos: [SertantaiLegal.Repo],
  ash_domains: [SertantaiLegal.Api],
  generators: [timestamp_type: :utc_datetime]

# The families whose labels come from the change vocabulary (CV-06,
# `ChangeVocabulary.LabelSwitch`): every other law keeps the change
# register's. Set when a family's switch-over is applied, with Jason's
# approval of its dry run (`mix lat.label_switch`). OH&S applied 2026-11-02
# (Jason: "Apply"); Maritime Safety 2026-11-07 (Jason: "Apply"). A family is
# matched by its exact name, the register's display marker dropped
# (`LabelSwitch.family_in?/2`).
config :sertantai_legal,
  label_families: ["OH&S: Occupational / Personal Safety", "TRANSPORT: Maritime Safety"]

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
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
