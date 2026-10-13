defmodule Mix.Tasks.Lat.Timeline do
  @moduledoc """
  Build the labels timeline `lat_label_timeline` (lat-refactor LR-24) from
  the change register via `LabelTimeline`. Dry run by default.

      mix lat.timeline --laws A,B             # dry run, named laws
      mix lat.timeline --all                  # dry run, every law with LAT
      mix lat.timeline --all --apply          # write (per law: delete + insert)
      mix lat.timeline --all --tag lr24       # report name (default: timeline)

  Reports, written as they go (resumable, `<tag>.csv.done`):

  - `data/reports/lat-refactor/<tag>.csv`: per law — rows, periods, rows
    with no start (J1), markup conflicts (J2), and the as-at-today diff
    against today's columns (status, effective_from, changed_by)
  - `<tag>.diff.csv`: each differing field (law, section_id, field, today's
    change source, old, new)
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelProjection, LabelTimeline}

  @shortdoc "Build lat_label_timeline from the change register (dry run by default)"

  @cols ~w(law rows periods no_start markup_conflicts status_same status_changed from_same from_changed from_emptied from_gained by_same by_changed)

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
    tag = opts[:tag] || "timeline"
    csv = Path.join(dir, "#{tag}.csv")
    diff = Path.join(dir, "#{tag}.diff.csv")
    done_file = csv <> ".done"
    done = if File.exists?(done_file), do: done_file |> File.read!() |> String.split(), else: []

    if done == [] do
      File.write!(csv, Enum.join(@cols, ",") <> "\n")
      File.write!(diff, "law,section_id,field,today_source,old,new\n")
    end

    today = LabelProjection.uk_today()
    version = code_version()
    todo = laws -- done

    Mix.shell().info(
      "#{length(todo)} laws (#{length(done)} done); as at #{today}; #{if opts[:apply], do: "APPLY", else: "dry run"}"
    )

    for {law, i} <- Enum.with_index(todo, 1) do
      %{periods: periods, gaps: gaps, rows: rows} = LabelTimeline.build(law, today)
      if opts[:apply], do: {:ok, _} = LabelTimeline.write(law, periods, version)

      now = LabelProjection.as_at(periods, today)
      diffs = for r <- rows, d <- row_diffs(r, now[r.section_id]), do: {r, d}

      File.write!(
        diff,
        Enum.map(diffs, fn {r, {field, old, new}} ->
          Enum.join([law, r.section_id, field, r.today.source, old, new], ",") <> "\n"
        end),
        [:append]
      )

      counts = Enum.frequencies_by(diffs, fn {_, {field, old, new}} -> kind(field, old, new) end)
      n = length(rows)
      changed = fn k -> Map.get(counts, k, 0) end

      line = [
        law,
        n,
        length(periods),
        Enum.count(gaps, &(elem(&1, 1) == :no_start)),
        Enum.count(gaps, &(elem(&1, 1) == :markup_conflict)),
        n - changed.(:status_changed),
        changed.(:status_changed),
        n - changed.(:from_changed) - changed.(:from_emptied) - changed.(:from_gained),
        changed.(:from_changed),
        changed.(:from_emptied),
        changed.(:from_gained),
        n - changed.(:by_changed),
        changed.(:by_changed)
      ]

      File.write!(csv, Enum.join(line, ",") <> "\n", [:append])
      File.write!(done_file, law <> "\n", [:append])
      if rem(i, 50) == 0, do: Mix.shell().info("  [#{i}/#{length(todo)}]")
    end

    Mix.shell().info("report #{csv}")
  end

  # today's columns vs the period containing today (nil period: unknown)
  defp row_diffs(r, period) do
    new = period || %{status: nil, in_force_from: nil, changed_by: nil}
    old_status = r.today.status

    [
      {"status", old_status, new.status},
      {"effective_from", r.today.effective_from, new.in_force_from},
      {"changed_by", r.today.changed_by, new.changed_by}
    ]
    |> Enum.reject(fn {_, a, b} -> a == b end)
  end

  defp kind("status", _, _), do: :status_changed
  defp kind("changed_by", _, _), do: :by_changed
  defp kind("effective_from", nil, _), do: :from_gained
  defp kind("effective_from", _, nil), do: :from_emptied
  defp kind("effective_from", _, _), do: :from_changed

  defp code_version do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
