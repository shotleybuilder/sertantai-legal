defmodule Mix.Tasks.Templates.Status do
  @shortdoc "Show applied template status for a Baserow workspace"

  @moduledoc """
  Show which templates are applied, their table IDs, and field/row counts.

  ## Usage

      mix templates.status                   # default config
      mix templates.status --config UUID     # specific config
  """

  use Mix.Task

  alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
  alias SertantaiLegal.Sync.Providers.Baserow

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [config: :string, help: :boolean])

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      System.halt(0)
    end

    Mix.Task.run("app.start")

    config_id = opts[:config] || List.first(positional) || find_default_config()

    unless config_id do
      Mix.shell().error("No sync configuration found.")
      System.halt(1)
    end

    sync_config = SertantaiLegal.Repo.get!(SyncConfiguration, config_id)
    tc = sync_config.target_config

    Mix.shell().info("── Template Status: #{sync_config.name} ──\n")

    # Base data tables
    Mix.shell().info("  Base Data:")
    print_table_status("Legal Register", tc["lrt_table_id"])
    print_table_status("Duties", tc["lat_table_id"])
    print_table_status("Actors", tc["actor_tuples_table_id"])

    Mix.shell().info("")
    Mix.shell().info("  Templates:")

    # Template tables — check which have IDs in config
    template_tables = [
      {:personnel, "Personnel", tc["personnel_table_id"]},
      {:assessments, "Assessments", tc["assessments_table_id"]},
      {:actions, "Actions", tc["actions_table_id"]},
      {:evidence, "Evidence", tc["evidence_table_id"]},
      {:incidents, "Incidents", tc["incidents_table_id"]},
      {:audits, "Audits", tc["audits_table_id"]},
      {:training, "Training", tc["training_table_id"]},
      {:documents, "Documents", tc["documents_table_id"]},
      {:raci, "RACI", tc["raci_table_id"]},
      {:pdca, "PDCA", tc["pdca_table_id"]},
      {:sites, "Sites", tc["sites_table_id"]},
      {:divisions, "Divisions", tc["divisions_table_id"]}
    ]

    applied = Enum.filter(template_tables, fn {_, _, id} -> id != nil end)
    pending = Enum.filter(template_tables, fn {_, _, id} -> id == nil end)

    for {_key, name, table_id} <- applied do
      print_table_status(name, table_id)
    end

    if pending != [] do
      Mix.shell().info("")
      Mix.shell().info("  Not Applied:")

      for {_key, name, _} <- pending do
        Mix.shell().info("    #{String.pad_trailing(name, 20)} —")
      end
    end

    # Try to get row/field counts if we can authenticate
    if applied != [] do
      try_print_details(sync_config, applied)
    end
  end

  defp print_table_status(name, nil) do
    Mix.shell().info("    #{String.pad_trailing(name, 20)} —")
  end

  defp print_table_status(name, table_id) do
    Mix.shell().info("    #{String.pad_trailing(name, 20)} #{table_id}")
  end

  defp try_print_details(sync_config, applied) do
    creds = Credentials.decrypt(sync_config.encrypted_credentials, sync_config.credentials_iv)

    case Baserow.authenticate(%{
           "base_url" => sync_config.target_config["base_url"],
           "credentials" => creds
         }) do
      {:ok, config} ->
        Mix.shell().info("\n  Field Counts:")

        for {_key, name, table_id} <- applied do
          case Baserow.list_fields(config, table_id) do
            {:ok, fields} ->
              managed =
                Enum.count(fields, &String.contains?(&1["description"] || "", "SertantAI"))

              Mix.shell().info(
                "    #{String.pad_trailing(name, 20)} #{length(fields)} fields (#{managed} managed)"
              )

            _ ->
              Mix.shell().info("    #{String.pad_trailing(name, 20)} (could not fetch)")
          end
        end

      {:error, _} ->
        Mix.shell().info("\n  (Could not authenticate to fetch details)")
    end
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end
end
