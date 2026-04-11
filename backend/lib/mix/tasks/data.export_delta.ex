defmodule Mix.Tasks.Data.ExportDelta do
  @shortdoc "Export differential SQL from dev DB for promotion to prod"

  @moduledoc """
  Exports rows changed since the last sync (or a given timestamp) as idempotent SQL.

  ## Usage

      mix data.export_delta [options]

  ## Options

    * `--since TIMESTAMP` — Export rows changed after this ISO 8601 timestamp.
      If omitted, uses per-table watermarks from `scripts/sync/last_sync.json`.
    * `--tables t1,t2` — Only export specific tables (comma-separated).
    * `--limit N` — Limit rows per table (for testing).
    * `--dry-run` — Show counts only, don't write files.
    * `--output-dir DIR` — Output directory (default: `scripts/sync/`).

  ## Examples

      mix data.export_delta --since "2026-04-01T00:00:00Z"
      mix data.export_delta --dry-run --limit 10
      mix data.export_delta --tables uk_lrt,lat
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [
          since: :string,
          tables: :string,
          limit: :integer,
          dry_run: :boolean,
          output_dir: :string
        ],
        aliases: [s: :since, t: :tables, n: :limit, d: :dry_run]
      )

    SertantaiLegal.Sync.Delta.Exporter.run(opts)
  end
end
