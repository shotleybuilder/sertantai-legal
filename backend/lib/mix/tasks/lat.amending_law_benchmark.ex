defmodule Mix.Tasks.Lat.AmendingLawBenchmark do
  @moduledoc """
  Benchmark the amending-law collector against the changes feed
  (lat-refactor LR-08): on rows where the feed already holds a dated change
  by a law a note names, read that law's text and compare. A law record
  agrees when the feed has a change on the same row by the same law with
  the same operation and, where both are dated, the same date.

      mix lat.amending_law_benchmark --laws A,B
      mix lat.amending_law_benchmark --all --tag lr08_bench

  Writes `data/reports/lat-refactor/<tag>.csv` (one line per law record:
  law, section_id, amending law, provision read, operation, law date, the
  feed's operations and dates on the row by that law, verdict). Read-only.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeCollector, LatStagedParser, LatStatus}
  alias SertantaiLegal.Scraper.ChangeCollector.Feed

  @shortdoc "Compare the amending-law collector with the changes feed (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [laws: :string, all: :boolean, tag: :string])
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws =
      cond do
        opts[:laws] ->
          String.split(opts[:laws], ",", trim: true)

        opts[:all] ->
          Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1").rows
          |> List.flatten()

        true ->
          Mix.raise("--laws A,B or --all")
      end

    path = Path.join("data/reports/lat-refactor", "#{opts[:tag] || "amending_law_benchmark"}.csv")

    File.write!(
      path,
      "law,section_id,amending_law,provision,law_operation,law_date,feed_operations,feed_dates,verdict\n"
    )

    totals =
      Enum.reduce(laws, %{}, fn law, acc ->
        lines = bench(law)
        File.write!(path, Enum.map(lines, &(Enum.join(&1, ",") <> "\n")), [:append])
        Enum.reduce(lines, acc, fn l, a -> Map.update(a, List.last(l), 1, &(&1 + 1)) end)
      end)

    Mix.shell().info("#{inspect(totals)}\nreport #{path}")
  end

  defp bench(law) do
    case LatStagedParser.fetch_changes(law, store: :only) do
      {:ok, %{rows: rows, notes: notes, effects: effects}} ->
        feed = Feed.records(law, rows, notes, effects)
        by_law = Enum.group_by(feed, & &1.affecting_law)

        for r <-
              ChangeCollector.amending_law(law, Enum.map(rows, & &1.section_id), feed, :benchmark) do
          family = MapSet.new(LatStatus.ancestors(r.section_id))

          theirs =
            for f <- Map.get(by_law, r.affecting_law, []),
                f.section_id != nil,
                MapSet.member?(family, f.section_id) or
                  String.starts_with?(f.section_id, r.section_id <> "("),
                do: f

          ops = theirs |> Enum.map(& &1.operation) |> Enum.uniq()
          dates = theirs |> Enum.map(& &1.effective_from) |> Enum.reject(&is_nil/1) |> Enum.uniq()

          [
            law,
            r.section_id,
            r.affecting_law,
            r.affecting_ref,
            r.operation,
            r.effective_from,
            Enum.join(ops, "|"),
            Enum.join(dates, "|"),
            verdict(r, ops, dates)
          ]
        end

      _ ->
        []
    end
  end

  defp verdict(_r, [], _dates), do: "no_feed_change_on_row"

  defp verdict(r, ops, dates) do
    cond do
      r.operation not in ops -> "operation_differs"
      r.effective_from == nil -> "agrees_undated"
      dates == [] or r.effective_from in dates -> "agrees"
      true -> "date_differs"
    end
  end
end
