defmodule Mix.Tasks.Lat.Verdicts do
  @moduledoc """
  An acceptance check's pass bound from its agents' verdict files (change
  vocabulary CV-S10; `ChangeVocabulary.Measures.Verdicts`): the files
  since the step's last fix pooled, each item once, and the 95% upper
  bounds on wrong items (own faults) and wrong groups against the step's
  limits (default 2% and 5%). Also prints the end-to-end figure (every
  wrong item, whoever's fault), the gaps and the doubtful items. Read-only.

  Verdict files live under `backend/data/reports/change-vocabulary/verdicts/`
  (NAS-backed, not in git: items may carry effect ids).

      mix lat.verdicts FILE [FILE ...]
      mix lat.verdicts --dir DIR [--limit 0.02 --group-limit 0.05]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Verdicts

  @shortdoc "Pool an acceptance check's verdict files into its pass bound (read-only)"

  @usage "usage: mix lat.verdicts FILE ... | --dir DIR [--limit L --group-limit G]"

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} =
      OptionParser.parse(args, strict: [dir: :string, limit: :float, group_limit: :float])

    paths = paths ++ dir(opts[:dir])
    if paths == [], do: Mix.raise(@usage)

    files = Enum.map(paths, &load/1)
    pool = Verdicts.pool(files)
    tally = Verdicts.tally(pool)
    limit = opts[:limit] || 0.02
    group_limit = opts[:group_limit] || 0.05
    v = Verdicts.verdict(tally, limit, group_limit)

    if length(pool.steps) > 1,
      do: Mix.shell().error("warning: files from several steps: #{Enum.join(pool.steps, ", ")}")

    IO.puts("""
    #{length(files)} files; step #{Enum.join(pool.steps, ", ")}; seeds #{inspect(pool.seeds, charlists: :as_lists)}; rounds #{inspect(pool.rounds, charlists: :as_lists)}
    items:  #{line(tally.items, v.items_upper, limit)}
    groups: #{line(tally.groups, v.groups_upper, group_limit)}
    end to end (every wrong item): #{tally.end_to_end.wrong}/#{tally.end_to_end.n} (#{pct(tally.end_to_end.wrong / max(tally.end_to_end.n, 1))})
    gaps: #{length(tally.gaps)}; doubtful: #{length(tally.doubtful)} #{inspect(tally.doubtful)}
    #{if v.pass, do: "PASS", else: "NOT PASSED"}\
    """)
  end

  defp dir(nil), do: []
  defp dir(d), do: d |> Path.join("*.json") |> Path.wildcard() |> Enum.sort()

  defp load(path) do
    with {:ok, body} <- File.read(path),
         {:ok, raw} <- Jason.decode(body),
         {:ok, file} <- Verdicts.read(raw) do
      file
    else
      {:error, why} -> Mix.raise("#{path}: #{inspect(why)}")
    end
  end

  defp line(%{n: n, wrong: wrong}, upper, limit),
    do: "#{wrong}/#{n} wrong; 95% upper #{pct(upper)} (limit #{pct(limit)})"

  defp pct(nil), do: "n/a"
  defp pct(x), do: "#{:erlang.float_to_binary(100 * x, decimals: 2)}%"
end
