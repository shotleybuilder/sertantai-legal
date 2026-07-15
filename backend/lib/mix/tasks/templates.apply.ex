defmodule Mix.Tasks.Templates.Apply do
  @shortdoc "Apply compliance templates to a customer's Baserow workspace"

  @moduledoc """
  Apply compliance templates to a customer's Baserow workspace.

  Authenticates once, resolves the database ID, loads existing table IDs,
  applies templates via the Applicator, and persists new table IDs back
  to the sync configuration.

  ## Usage

      mix templates.apply                                    # default config, personnel template
      mix templates.apply --templates personnel              # specific template
      mix templates.apply --templates personnel,compliance_assessment
      mix templates.apply --config UUID                      # specific sync config (customer)
      mix templates.apply --database-id 494412               # target a specific Baserow database
      mix templates.apply --people linked                    # sub-pattern override
      mix templates.apply --list                             # show available templates
      mix templates.apply --help

  ## Sub-pattern overrides

      --people flat|linked|workspace_member|hybrid
      --risk simple|matrix
      --grain law|provision
      --review manual|scheduled
      --storage embedded|reference
  """

  use Mix.Task

  alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
  alias SertantaiLegal.Sync.Templates.{Applicator, Registry, SubPatterns}
  alias SertantaiLegal.Sync.Providers.Baserow

  require Logger

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [
          config: :string,
          database_id: :integer,
          fresh: :boolean,
          templates: :string,
          people: :string,
          risk: :string,
          grain: :string,
          review: :string,
          storage: :string,
          calibration: :string,
          safety_argument: :string,
          list: :boolean,
          help: :boolean
        ]
      )

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    Mix.Task.run("app.start")

    if opts[:list] do
      list_templates()
      return()
    end

    config_id = opts[:config] || List.first(positional) || find_default_config()

    unless config_id do
      Mix.shell().error("No sync configuration found. Provide a config UUID.")
      System.halt(1)
    end

    # Load and authenticate
    sync_config = SertantaiLegal.Repo.get!(SyncConfiguration, config_id)
    creds = Credentials.decrypt(sync_config.encrypted_credentials, sync_config.credentials_iv)

    provider_config = %{
      "base_url" => sync_config.target_config["base_url"],
      "credentials" => creds
    }

    {:ok, authed_config} = Baserow.authenticate(provider_config)
    Mix.shell().info("Authenticated with Baserow")

    # Resolve database_id: CLI flag > target_config > infer from existing tables
    database_id =
      opts[:database_id] ||
        sync_config.target_config["database_id"] ||
        resolve_database_id_from_tables(authed_config, sync_config.target_config)

    authed_config = Map.put(authed_config, "database_id", database_id)
    Mix.shell().info("Database ID: #{database_id}")

    # If --database-id was explicitly provided and differs from stored,
    # clear old table IDs (fresh DB, start clean)
    {sync_config, table_ids} =
      if opts[:fresh] ||
           (opts[:database_id] && sync_config.target_config["database_id"] != database_id) do
        # Strip all old table IDs, keep non-table settings
        keep_keys = [
          "base_url",
          "lat_aggregated",
          "lat_drrp_types",
          "lat_governed_only",
          "lat_min_provision_significance"
        ]

        clean_config =
          sync_config.target_config
          |> Map.take(keep_keys)
          |> Map.put("database_id", database_id)

        {:ok, id_bin} = Ecto.UUID.dump(sync_config.id)

        SertantaiLegal.Repo.query!(
          "UPDATE sync_configurations SET target_config = $1 WHERE id = $2",
          [clean_config, id_bin]
        )

        Mix.shell().info("  New database #{database_id} — cleared old table IDs")
        {%{sync_config | target_config: clean_config}, %{}}
      else
        # Persist database_id if not already there
        unless sync_config.target_config["database_id"] == database_id do
          new_config = Map.put(sync_config.target_config, "database_id", database_id)
          {:ok, id_bin} = Ecto.UUID.dump(sync_config.id)

          SertantaiLegal.Repo.query!(
            "UPDATE sync_configurations SET target_config = $1 WHERE id = $2",
            [new_config, id_bin]
          )

          Mix.shell().info("  Saved database_id #{database_id} to sync config")
        end

        {sync_config, load_table_ids(sync_config.target_config)}
      end

    Mix.shell().info("Existing tables: #{map_size(table_ids)}")

    # Parse templates
    template_ids = parse_templates(opts[:templates])

    # Build sub-patterns from defaults + CLI overrides
    sp = build_sub_patterns(opts)
    Mix.shell().info("Sub-patterns: people=#{sp.people}, risk=#{sp.risk_scoring}")

    # Build table specs from templates
    {:ok, table_specs} = Applicator.build_table_specs(template_ids, sp)
    Mix.shell().info("Table specs: #{length(table_specs)} tables")
    Mix.shell().info("\nApplying schema (4-phase)...")

    # Apply via SchemaManager (4-phase: tables → fields → formulas → views)
    case SertantaiLegal.Baserow.SchemaManager.apply_schema(
           authed_config,
           database_id,
           table_specs
         ) do
      {:ok, result} ->
        Mix.shell().info("\nSuccess!")
        Mix.shell().info("  Tables created: #{result.tables_created}")
        Mix.shell().info("  Fields created: #{result.fields_created}")
        Mix.shell().info("  Views created: #{result.views_created}")

        # Save table IDs back to sync config
        save_table_ids(sync_config, result.table_ids)

        Mix.shell().info("\nDone.")

      {:error, reason} ->
        Mix.shell().error("Failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp list_templates do
    {:ok, modules} = Registry.resolve(Registry.all_ids())

    Mix.shell().info("Available templates:\n")

    for mod <- modules do
      deps =
        if mod.requires() == [],
          do: "(no dependencies)",
          else: "requires: #{inspect(mod.requires())}"

      Mix.shell().info("  #{mod.id()} — #{mod.name()} #{deps}")
    end
  end

  defp parse_templates(nil), do: [:personnel]
  defp parse_templates(""), do: [:personnel]

  defp parse_templates(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp build_sub_patterns(opts) do
    overrides =
      []
      |> maybe_add(:people, opts[:people])
      |> maybe_add(:risk_scoring, opts[:risk])
      |> maybe_add(:assessment_grain, opts[:grain])
      |> maybe_add(:review_cycle, opts[:review])
      |> maybe_add(:storage_mode, opts[:storage])
      |> maybe_add(:calibration_mode, opts[:calibration])
      |> maybe_add(:safety_argument, opts[:safety_argument])

    SubPatterns.new(overrides)
  end

  defp maybe_add(acc, _key, nil), do: acc
  defp maybe_add(acc, key, value), do: [{key, String.to_atom(value)} | acc]

  # Fallback: infer database_id from an existing table ID via the Baserow API
  defp resolve_database_id_from_tables(config, target_config) do
    table_id =
      target_config["lrt_table_id"] ||
        target_config["lat_table_id"] ||
        target_config["actor_tuples_table_id"]

    if table_id do
      headers = [{"Authorization", "JWT #{config["jwt"]}"}]

      case Req.get("#{config["base_url"]}/api/database/tables/#{table_id}/",
             headers: headers,
             receive_timeout: 15_000
           ) do
        {:ok, %{status: 200, body: %{"database_id" => db_id}}} ->
          db_id

        _ ->
          Mix.shell().error("Could not resolve database_id from table #{table_id}")
          System.halt(1)
      end
    else
      Mix.shell().error(
        "No database_id in config and no existing tables to infer from.\n" <>
          "Use --database-id N or set database_id in target_config."
      )

      System.halt(1)
    end
  end

  defp load_table_ids(target_config) do
    base = %{}

    base
    |> maybe_put_table(:lrt, target_config["lrt_table_id"])
    |> maybe_put_table(:lat, target_config["lat_table_id"])
    |> maybe_put_table(:actor_tuples, target_config["actor_tuples_table_id"])
    |> maybe_put_table(:personnel, target_config["personnel_table_id"])
    |> maybe_put_table(:assessments, target_config["assessments_table_id"])
    |> maybe_put_table(:actions, target_config["actions_table_id"])
    |> maybe_put_table(:evidence, target_config["evidence_table_id"])
    |> maybe_put_table(:incidents, target_config["incidents_table_id"])
    |> maybe_put_table(:audits, target_config["audits_table_id"])
    |> maybe_put_table(:training, target_config["training_table_id"])
    |> maybe_put_table(:documents, target_config["documents_table_id"])
    |> maybe_put_table(:raci, target_config["raci_table_id"])
    |> maybe_put_table(:pdca, target_config["pdca_table_id"])
    |> maybe_put_table(:sites, target_config["sites_table_id"])
    |> maybe_put_table(:divisions, target_config["divisions_table_id"])
    |> maybe_put_table(:hierarchy, target_config["hierarchy_table_id"])
    |> maybe_put_table(:controls, target_config["controls_table_id"])
    |> maybe_put_table(:control_mappings, target_config["control_mappings_table_id"])
    |> maybe_put_table(:artefacts, target_config["artefacts_table_id"])
    |> maybe_put_table(:judgements, target_config["judgements_table_id"])
    |> maybe_put_table(:gaps, target_config["gaps_table_id"])
    |> maybe_put_table(:compliance_events, target_config["compliance_events_table_id"])
  end

  defp maybe_put_table(map, _key, nil), do: map
  defp maybe_put_table(map, key, id), do: Map.put(map, key, id)

  defp save_table_ids(sync_config, table_ids) do
    # Save ALL table IDs — foundation (lrt, lat) and templates
    updates =
      Enum.reduce(table_ids, %{}, fn {key, id}, acc ->
        Map.put(acc, "#{key}_table_id", id)
      end)

    if map_size(updates) > 0 do
      new_config = Map.merge(sync_config.target_config, updates)
      {:ok, id_bin} = Ecto.UUID.dump(sync_config.id)

      case SertantaiLegal.Repo.query(
             "UPDATE sync_configurations SET target_config = $1 WHERE id = $2",
             [new_config, id_bin]
           ) do
        {:ok, %{num_rows: 1}} ->
          Mix.shell().info("  Saved #{map_size(updates)} table ID(s) to sync config")

        other ->
          Mix.shell().error("  Failed to save table IDs: #{inspect(other)}")
      end
    end
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end

  defp return, do: System.halt(0)
end
