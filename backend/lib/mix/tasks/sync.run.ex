defmodule Mix.Tasks.Sync.Run do
  @moduledoc """
  Run a full Baserow sync for a sync configuration.

  ## Usage

      mix sync.run                          # Uses the first (only) sync config
      mix sync.run CONFIG_UUID              # Specific config
      mix sync.run --clean                  # Delete existing rows first (fresh sync)
      mix sync.run --clean --config UUID    # Clean + specific config

  ## What it does

  1. Authenticates with Baserow
  2. (If --clean) Deletes all existing rows from LRT, LAT, and Actor Tuples tables
  3. Clears row mappings (if --clean)
  4. Runs Engine.run (creates LRT → LAT → Actor Tuples → links)
  5. Reports results
  """

  use Mix.Task

  @shortdoc "Run Baserow sync (--clean for fresh sync)"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [clean: :boolean, config: :string],
        aliases: [c: :clean]
      )

    config_id = opts[:config] || List.first(positional) || find_default_config()

    unless config_id do
      Mix.shell().error("No sync configuration found. Provide a config UUID.")
      System.halt(1)
    end

    Mix.shell().info("Sync configuration: #{config_id}")

    if opts[:clean] do
      Mix.shell().info("Cleaning existing Baserow data...")
      clean_baserow(config_id)
    end

    Mix.shell().info("Running sync...")

    case SertantaiLegal.Sync.Engine.run(config_id) do
      {:ok, job} ->
        Mix.shell().info("""

        Sync complete!
          LRT laws:    #{job.law_count}
          LAT duties:  #{Map.get(job, :lat_count, 0)}
          Status:      #{job.status}
          Duration:    #{duration(job)}
        """)

      {:error, reason} ->
        Mix.shell().error("Sync failed: #{inspect(reason, limit: 300)}")
    end
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end

  defp clean_baserow(config_id) do
    alias SertantaiLegal.Repo
    alias SertantaiLegal.Sync.{Credentials, Providers.Baserow}

    {:ok, bin} = Ecto.UUID.dump(config_id)

    {:ok, %{rows: [[cj, ec, iv]]}} =
      Repo.query(
        "SELECT target_config, encrypted_credentials, credentials_iv FROM sync_configurations WHERE id = $1",
        [bin]
      )

    config = Map.merge(cj, %{"credentials" => Credentials.decrypt(ec, iv)})
    {:ok, config} = Baserow.authenticate(config)

    headers = [
      {"Authorization", "JWT #{config["jwt"]}"},
      {"Content-Type", "application/json"}
    ]

    tables =
      [
        {config["lrt_table_id"], "LRT"},
        {config["lat_table_id"], "LAT"},
        {config["actor_tuples_table_id"], "Actor Tuples"}
      ]
      |> Enum.reject(fn {id, _} -> is_nil(id) end)

    for {table_id, label} <- tables do
      delete_all_rows(config["base_url"], headers, table_id, label)
    end

    # Clear row mappings
    Repo.query!("DELETE FROM sync_row_mappings WHERE sync_configuration_id = $1", [bin])
    Mix.shell().info("  Row mappings cleared")
  end

  defp delete_all_rows(base_url, headers, table_id, label) do
    {:ok, %{body: %{"count" => count}}} =
      Req.get("#{base_url}/api/database/rows/table/#{table_id}/?size=1",
        headers: headers,
        receive_timeout: 30_000
      )

    if count > 0 do
      ids =
        Enum.flat_map(1..max(ceil(count / 200), 1), fn page ->
          {:ok, %{body: %{"results" => results}}} =
            Req.get(
              "#{base_url}/api/database/rows/table/#{table_id}/?size=200&page=#{page}&fields=",
              headers: headers,
              receive_timeout: 30_000
            )

          Enum.map(results, & &1["id"])
        end)

      ids
      |> Enum.chunk_every(200)
      |> Enum.each(fn chunk ->
        Req.post!(
          "#{base_url}/api/database/rows/table/#{table_id}/batch-delete/",
          headers: headers,
          json: %{"items" => chunk},
          receive_timeout: 120_000
        )
      end)

      Mix.shell().info("  #{label}: deleted #{length(ids)} rows")
    else
      Mix.shell().info("  #{label}: empty")
    end
  end

  defp duration(job) do
    if job.started_at && job.completed_at do
      seconds = DateTime.diff(job.completed_at, job.started_at)
      "#{seconds}s"
    else
      "unknown"
    end
  end
end
