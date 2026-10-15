defmodule Mix.Tasks.Lat.CollectChanges do
  @moduledoc """
  Report what `ChangeCollector` would put in the change register
  `lat_change_log` (lat-refactor LR-23) for each law, from the CLML store.
  Report only: the register is written by `LabelRefresh` alone — after each
  parse (the LR-25 hook) or by `mix lat.relabel`.

      mix lat.collect_changes --laws A,B          # named laws
      mix lat.collect_changes --all               # every law with LAT
      mix lat.collect_changes --all --tag lr23    # report name (default: collect)

  Writes `data/reports/lat-refactor/<tag>.csv` as it goes (law, feed
  records, effects, unreached effects, each `via`, markup records, records
  stored (compact), fidelity differences). A law failing the fidelity gate
  (`ChangeCollector.fidelity/3`) is reported; a re-run skips the laws
  already in the report (`<tag>.csv.done`). Never fetches.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeCollector

  @shortdoc "Report the change register's records per law (report only)"

  @vias ~w(markup whole ref instrument note_markup note_own note_cited)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, tag: :string]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:all] -> laws_with_lat()
        true -> Mix.raise("--laws A,B or --all")
      end

    dir = "data/reports/lat-refactor"
    File.mkdir_p!(dir)
    csv = Path.join(dir, "#{opts[:tag] || "collect"}.csv")
    done_file = csv <> ".done"
    done = if File.exists?(done_file), do: done_file |> File.read!() |> String.split(), else: []

    if done == [],
      do:
        File.write!(
          csv,
          Enum.join(
            ~w(law feed_records effects unreached) ++
              @vias ++ ~w(markup_records amending_law_records stored fidelity_diffs),
            ","
          ) <>
            "\n"
        )

    todo = laws -- done

    Mix.shell().info("#{length(todo)} laws (#{length(done)} done); report only")

    for {law, i} <- Enum.with_index(todo, 1) do
      line =
        case ChangeCollector.collect(law) do
          {:ok, %{records: by, per_row: per_row}} ->
            diffs = ChangeCollector.fidelity(by, per_row, ChangeCollector.db_order(law))

            if diffs != [],
              do:
                Mix.shell().error(
                  "  #{law}: fidelity gate failed (#{length(diffs)}): #{inspect(Enum.take(diffs, 3))}"
                )

            summary(law, per_row["feed"]) <>
              ",#{length(per_row["markup"])},#{length(per_row["amending_law"])},#{by |> Map.values() |> Enum.map(&length/1) |> Enum.sum()},#{length(diffs)}"

          {:error, reason} ->
            Mix.shell().error("  #{law}: #{inspect(reason)}")
            "#{law},error,,,"
        end

      File.write!(csv, line <> "\n", [:append])
      File.write!(done_file, law <> "\n", [:append])
      if rem(i, 50) == 0, do: Mix.shell().info("  [#{i}/#{length(todo)}]")
    end

    Mix.shell().info("report #{csv}")
  end

  defp summary(law, records) do
    effects = records |> Enum.map(& &1.evidence) |> Enum.uniq() |> length()
    unreached = Enum.count(records, &is_nil(&1.section_id))
    vias = for v <- @vias, do: Enum.count(records, &(v in &1.via))
    Enum.join([law, length(records), effects, unreached | vias], ",")
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
