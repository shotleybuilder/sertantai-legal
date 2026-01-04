defmodule SertantaiLegal.MixProject do
  use Mix.Project

  def project do
    [
      app: :sertantai_legal,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SertantaiLegal.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:tidewave, "~> 0.5", only: [:dev]},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:corsica, "~> 2.1"},

      # Ash Framework
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_json_api, "~> 1.0"},

      # JWT validation
      {:jose, "~> 1.11"},

      # CSV parsing (for data import scripts)
      {:nimble_csv, "~> 1.2"},

      # Scraper dependencies
      {:req, "~> 0.5"},
      {:floki, "~> 0.36"},
      {:sweet_xml, "~> 0.7"},

      # Dev/Test Tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup"],
      "ash.setup": ["ash_postgres.create", "ash.migrate", "run priv/repo/seeds.exs"],
      "ash.reset": ["ash_postgres.drop", "ash.setup"],
      test: ["ash_postgres.create --quiet", "ash.migrate --quiet", "test"]
    ]
  end

  # Dialyzer configuration
  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit],
      flags: [:error_handling, :underspecs],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end
