defmodule Mix.Tasks.Lat.Relabel do
  @moduledoc """
  Rebuild laws' change register and label timeline without a re-parse
  (lat-refactor LR-25): `LabelRefresh.run/1` per law, from the CLML store.
  For when only label code changed (`LabelVersion`) or a refresh failed; a
  parser change needs a re-parse instead (the parse refreshes the labels).
  Writes the register and timeline: dry run the label change with `mix
  lat.collect_changes` / `mix lat.timeline` first, take a NAS backup, and
  run this only on Jason's approval.

      mix lat.relabel --laws A,B
      mix lat.relabel --stale             # laws stale for a label reason
      mix lat.relabel --all
      mix lat.relabel --stale --workers 1   # one law at a time (default: 5 at once, LR-31)

  Resumable: laws done are listed in `data/reports/lat-refactor/<tag>.done`
  (default tag: `relabel_<LabelVersion>`, so a resume never skips a law
  relabelled by older code). Never fetches.
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Scraper.{
    LabelRefresh,
    LabelStaleness,
    LabelVersion,
    LawRunner,
    ParserVersion
  }

  @shortdoc "Rebuild laws' register + timeline from the store (writes)"

  @label_reasons [:labels_behind_parse, :labels_version, :labels_failed]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, stale: :boolean, all: :boolean, tag: :string, workers: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:stale] -> stale_for_labels()
        opts[:all] -> laws_with_lat()
        true -> Mix.raise("--laws A,B, --stale or --all")
      end

    dir = "data/reports/lat-refactor"
    File.mkdir_p!(dir)
    # resumable within one label code version only: a done file from an
    # earlier version's run must never skip a law now stale (LR-34: the
    # default `relabel.done` from LR-33's apply skipped all 1,066)
    done_file = Path.join(dir, "#{opts[:tag] || "relabel_#{LabelVersion.current()}"}.done")
    done = if File.exists?(done_file), do: done_file |> File.read!() |> String.split(), else: []
    todo = laws -- done
    Mix.shell().info("#{length(todo)} laws (#{length(done)} done)")

    total = length(todo)
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        todo,
        &LabelRefresh.run/1,
        fn law, result ->
          File.write!(done_file, law <> "\n", [:append])
          :counters.add(counter, 1, 1)
          i = :counters.get(counter, 1)
          if rem(i, 50) == 0, do: Mix.shell().info("  [#{i}/#{total}]")

          case result do
            :ok -> :ok
            {:error, reason} -> Mix.shell().error("  #{law}: #{inspect(reason)}")
          end
        end,
        workers: opts[:workers] || LawRunner.default_workers()
      )

    failed = Enum.count(results, fn {_, r} -> r != :ok end)

    Mix.shell().info("done; #{failed} failed (labels_failed events)")
  end

  defp stale_for_labels do
    current = %{parser: ParserVersion.current(), labels: LabelVersion.current()}

    for {law, facts} <- LabelStaleness.facts(),
        Enum.any?(LabelStaleness.reasons(facts, current), &(&1 in @label_reasons)),
        do: law
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
