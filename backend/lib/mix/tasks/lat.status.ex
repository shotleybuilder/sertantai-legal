defmodule Mix.Tasks.Lat.Status do
  @moduledoc """
  Backfill / recompute per-row LAT status (#167, L8.1) from text and amendment
  notes (`SertantaiLegal.Scraper.LatStatus`).

      mix lat.status                         # dry run, every law with LAT
      mix lat.status --law UK_uksi_2012_3030 # dry run, named laws (comma-separated)
      mix lat.status --apply                 # snapshot (section_id, status) to lat_status_snapshot_<stamp>, then write

  `prospective` needs the CLML `Status` attribute, so a backfill can't set it:
  rows get it on their next parse.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStatus.Apply

  @shortdoc "Backfill per-row LAT status (dry run by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [law: :string, apply: :boolean])
    Mix.Task.run("app.start")

    laws =
      case opts[:law] do
        nil ->
          %{rows: rows} =
            Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
              timeout: :infinity
            )

          List.flatten(rows)

        list ->
          String.split(list, ",", trim: true)
      end

    if opts[:apply], do: snapshot!(laws)

    results = Enum.map(laws, &Apply.refresh(&1, dry_run: !opts[:apply]))

    changed = Enum.filter(results, &(&1.changed > 0))

    Mix.shell().info(
      "Laws: #{length(results)}; rows: #{Enum.sum(Enum.map(results, & &1.rows))}; " <>
        "to change: #{Enum.sum(Enum.map(changed, & &1.changed))} in #{length(changed)} laws"
    )

    for {{from, to}, n} <-
          results
          |> Enum.flat_map(&Map.to_list(&1.transitions))
          |> Enum.reduce(%{}, fn {k, n}, acc -> Map.update(acc, k, n, &(&1 + n)) end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: Mix.shell().info("  #{from || "nil"} → #{to}: #{n}")

    Mix.shell().info(if opts[:apply], do: "\nApplied.", else: "\nDry run: nothing written.")
  end

  defp snapshot!(laws) do
    table = "lat_status_snapshot_" <> Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M")

    Repo.query!(
      "CREATE TABLE #{table} AS SELECT section_id, law_name, status FROM legal_articles WHERE law_name = ANY($1)",
      [laws],
      timeout: :infinity
    )

    Mix.shell().info("Snapshot: #{table}")
  end
end
