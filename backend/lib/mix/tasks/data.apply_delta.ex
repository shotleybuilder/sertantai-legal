defmodule Mix.Tasks.Data.ApplyDelta do
  @shortdoc "Apply a delta SQL file to a target database"

  @moduledoc """
  Applies a previously exported delta SQL file to a non-dev target database.

  ## Usage

      TARGET_DATABASE_URL=postgresql://... mix data.apply_delta <sql_file> [options]

  ## Options

    * `--confirm` — Skip interactive confirmation prompt.
    * `--dry-run` — Validate file and manifest only, don't execute SQL.

  ## Safety

    * Refuses to run against dev databases (`_dev` suffix or port 5436).
    * SHA256 checksum verification against the manifest file.
    * Interactive confirmation unless `--confirm` is passed.
    * SQL executes within a single transaction (all-or-nothing).

  ## Examples

      # Test against local throwaway DB
      TARGET_DATABASE_URL=postgresql://postgres:postgres@localhost:5436/sertantai_legal_sync_test \\
        mix data.apply_delta delta_2026-04-11.sql

      # Prod via SSH tunnel
      TARGET_DATABASE_URL=postgresql://postgres:PWD@localhost:5437/sertantai_legal_prod \\
        mix data.apply_delta delta_2026-04-11.sql --confirm
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, rest} =
      OptionParser.parse!(args,
        strict: [
          confirm: :boolean,
          dry_run: :boolean
        ],
        aliases: [y: :confirm, d: :dry_run]
      )

    case rest do
      [sql_file | _] ->
        SertantaiLegal.Sync.Delta.Applier.run(sql_file, opts)

      [] ->
        Mix.raise("Usage: mix data.apply_delta <sql_file> [--confirm] [--dry-run]")
    end
  end
end
