defmodule Mix.Tasks.Lat.RewriteSortKeys do
  @moduledoc """
  Rewrite stored LAT `sort_key`s in place for the 2026-09-26
  `build_sort_key` fixes (paragraph letters read as Roman numerals; signed row
  sorting first), without re-parsing — so section ids, text and fractalaw's
  provision enrichment are kept. See `SertantaiLegal.Legal.Lat.SortKeyRewrite`.

      mix lat.rewrite_sort_keys                     # dry run, all laws
      mix lat.rewrite_sort_keys --law UK_uksi_2015_10
      mix lat.rewrite_sort_keys --apply             # snapshot, then write

  `--apply` first copies every changed row's old key into
  `sort_key_rewrite_snapshot_<YYYYMMDD>` (rollback: set sort_key =
  old_sort_key from it). Each law is one UPDATE, so the LAT triggers refresh
  its `lat_hash` and fractalaw's manifest re-pulls it.

  Keys in older formats (not 23 segments) are skipped: those laws need a
  re-parse.
  """

  use Mix.Task

  alias SertantaiLegal.Legal.Lat.SortKeyRewrite.Store

  @shortdoc "Rewrite stored LAT sort_keys in place (dry run by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean, law: :keep])
    Mix.Task.run("app.start")

    laws =
      case Keyword.get_values(opts, :law) do
        [] -> :all
        names -> names
      end

    changes = Store.plan(laws)
    law_count = changes |> Enum.map(& &1.law_name) |> Enum.uniq() |> length()

    Mix.shell().info("Rows to rewrite: #{length(changes)} in #{law_count} laws")

    changes
    |> Enum.take(5)
    |> Enum.each(&Mix.shell().info("  #{&1.section_id}\n    #{&1.old}\n  → #{&1.new}"))

    if Keyword.get(opts, :apply, false) and changes != [] do
      table = "sort_key_rewrite_snapshot_" <> Calendar.strftime(Date.utc_today(), "%Y%m%d")
      result = Store.apply!(changes, table)

      Mix.shell().info(
        "\nApplied: #{result.rows} rows in #{result.laws} laws (snapshot: #{table})"
      )
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end
end
