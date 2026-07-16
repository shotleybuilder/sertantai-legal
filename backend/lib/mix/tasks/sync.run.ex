defmodule Mix.Tasks.Sync.Run do
  @moduledoc """
  Run a full Baserow sync for a sync configuration.

  ## Usage

      mix sync.run                          # Uses the first (only) sync config
      mix sync.run CONFIG_UUID              # Specific config
      mix sync.run --clean                  # Delete existing rows first (fresh sync)
      mix sync.run --clean --config UUID    # Clean + specific config
      mix sync.run --wait                   # Enqueue via Oban and wait for completion
      mix sync.run --direct                 # Bypass Oban, run Engine directly
      mix sync.run --direct --tables control_mappings  # Sync specific tables only
      mix sync.run --direct --tables controls,control_mappings

  ## Tables

  Valid table names: lrt, lat, actor_tuples, controls, control_mappings

  ## What it does

  By default, enqueues an Oban job for persistent, retryable execution.
  Use --wait to block until the job completes.
  Use --direct to bypass Oban and run Engine.run directly (debugging).
  """

  use Mix.Task

  alias SertantaiLegal.Sync.Workers.SyncWorker

  @shortdoc "Run Baserow sync (--clean for fresh, --wait to block)"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [
          clean: :boolean,
          config: :string,
          wait: :boolean,
          direct: :boolean,
          tables: :string
        ],
        aliases: [c: :clean, w: :wait, d: :direct, t: :tables]
      )

    config_id = opts[:config] || List.first(positional) || find_default_config()

    unless config_id do
      Mix.shell().error("No sync configuration found. Provide a config UUID.")
      System.halt(1)
    end

    Mix.shell().info("Sync configuration: #{config_id}")

    if opts[:clean] && Mix.env() == :prod do
      Mix.shell().error("""
      WARNING: You are about to delete ALL synced data from Baserow in PRODUCTION.
      This will destroy any customer enrichment (notes, actions, evidence).
      This action is IRREVERSIBLE.
      """)

      unless Mix.shell().yes?("Are you sure you want to proceed?") do
        Mix.shell().info("Aborted.")
        System.halt(0)
      end
    end

    if opts[:direct] do
      run_direct(config_id, opts)
    else
      run_via_oban(config_id, opts)
    end
  end

  defp run_direct(config_id, opts) do
    if opts[:clean] do
      Mix.shell().info("Cleaning existing Baserow data...")

      case SertantaiLegal.Sync.Engine.clean(config_id) do
        {:ok, result} ->
          Mix.shell().info(
            "  Cleaned: #{result.rows_deleted} rows from #{result.tables_cleaned} tables"
          )

        {:error, reason} ->
          Mix.shell().error("Clean failed: #{inspect(reason)}")
          System.halt(1)
      end
    end

    only_tables =
      case opts[:tables] do
        nil -> nil
        tables_str -> tables_str |> String.split(",") |> Enum.map(&String.to_atom/1)
      end

    if only_tables do
      Mix.shell().info("Running sync directly — tables: #{inspect(only_tables)}")
    else
      Mix.shell().info("Running sync directly (bypassing Oban)...")
    end

    case SertantaiLegal.Sync.Engine.run(config_id, only_tables: only_tables) do
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

  defp run_via_oban(config_id, opts) do
    operation = if opts[:clean], do: "clean_and_sync", else: "sync"

    case SyncWorker.new(%{"sync_config_id" => config_id, "operation" => operation})
         |> Oban.insert() do
      {:ok, oban_job} ->
        Mix.shell().info("Sync job enqueued (Oban ##{oban_job.id}, operation: #{operation})")

        if opts[:wait] do
          Mix.shell().info("Waiting for completion...")
          wait_for_completion(oban_job.id)
        else
          Mix.shell().info("Job will run in background. Use --wait to block until complete.")
        end

      {:error, changeset} ->
        Mix.shell().error("Failed to enqueue: #{inspect(changeset)}")
    end
  end

  defp wait_for_completion(oban_job_id) do
    case poll_job(oban_job_id, 0) do
      :completed ->
        Mix.shell().info("Sync completed successfully.")

      {:failed, errors} ->
        Mix.shell().error("Sync failed: #{inspect(errors)}")

      :timeout ->
        Mix.shell().error("Timed out waiting for job (30 min). Check oban_jobs table.")
    end
  end

  defp poll_job(_id, attempts) when attempts > 360 do
    # 360 * 5s = 30 min timeout
    :timeout
  end

  defp poll_job(id, attempts) do
    Process.sleep(5_000)

    case SertantaiLegal.Repo.query(
           "SELECT state, errors FROM oban_jobs WHERE id = $1",
           [id]
         ) do
      {:ok, %{rows: [["completed", _]]}} ->
        :completed

      {:ok, %{rows: [["discarded", errors]]}} ->
        {:failed, errors}

      {:ok, %{rows: [[state, errors]]}} when state in ["retryable", "cancelled"] ->
        {:failed, errors}

      _ ->
        if rem(attempts, 12) == 0 do
          Mix.shell().info("  Still running... (#{div(attempts * 5, 60)} min)")
        end

        poll_job(id, attempts + 1)
    end
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
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
