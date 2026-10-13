defmodule Mix.Tasks.Lat.CollectChanges do
  @moduledoc """
  Fill the change register `lat_change_log` (lat-refactor LR-23) from the
  CLML store via `ChangeCollector`. Dry run by default.

      mix lat.collect_changes --laws A,B          # dry run, named laws
      mix lat.collect_changes --all               # dry run, every law with LAT
      mix lat.collect_changes --all --apply       # write (per law: delete + insert)
      mix lat.collect_changes --all --tag lr23    # report name (default: collect)

  Writes `data/reports/lat-refactor/<tag>.csv` as it goes (law, records,
  rows reached, unreached effects, each `via`); a re-run skips the laws
  already in the report (`<tag>.csv.done`). Never fetches.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeCollector

  @shortdoc "Fill lat_change_log from the CLML store (dry run by default)"

  @vias ~w(markup whole ref note_markup note_own note_cited)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, apply: :boolean, tag: :string]
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
      do: File.write!(csv, Enum.join(~w(law records effects unreached) ++ @vias, ",") <> "\n")

    todo = laws -- done

    Mix.shell().info(
      "#{length(todo)} laws (#{length(done)} done); #{if opts[:apply], do: "APPLY", else: "dry run"}"
    )

    for {law, i} <- Enum.with_index(todo, 1) do
      line =
        case ChangeCollector.collect(law) do
          {:ok, %{"feed" => records} = by} ->
            if opts[:apply], do: {:ok, _} = ChangeCollector.write(law, by)
            summary(law, records)

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
