defmodule Mix.Tasks.Lat.Timeline do
  @moduledoc """
  Report the labels timeline `LabelTimeline` builds from the change register
  (lat-refactor LR-24) for each law. Report only: `lat_label_timeline` is
  written by `LabelRefresh` alone — after each parse (the LR-25 hook) or by
  `mix lat.relabel`.

      mix lat.timeline --laws A,B             # named laws
      mix lat.timeline --all                  # every law with LAT
      mix lat.timeline --all --tag lr24       # report name (default: timeline)

  Reports, written as they go (resumable, `<tag>.csv.done`):

  - `data/reports/lat-refactor/<tag>.csv`: per law — rows, periods, rows
    with no start (J1), markup conflicts (J2), outstanding effects (J4), and
    the as-at-today diff of a fresh build against the stored timeline
    (`lat_labels_today`: status, effective_from, changed_by)
  - `<tag>.diff.csv`: each differing field (law, section_id, field,
    "timeline", stored, fresh)
  - `<tag>.gaps.csv`: each provision the timeline can't fully answer (law,
    section_id, gap): `no_start`, `insertion_not_in_register`,
    `undated_change`, `markup_conflict`, `outstanding_effect`,
    `commenced_by_order` (LR-34: in force as at the text, since unknown)
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelProjection, LabelTimeline}

  @shortdoc "Report each law's label timeline (report only)"

  @cols ~w(law rows periods territory_unknown_before_today no_start insertion_not_in_register undated_change markup_conflicts outstanding commenced_by_order pending_change status_same status_changed from_same from_changed from_emptied from_gained by_same by_changed)

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
    tag = opts[:tag] || "timeline"
    csv = Path.join(dir, "#{tag}.csv")
    diff = Path.join(dir, "#{tag}.diff.csv")
    gaps_csv = Path.join(dir, "#{tag}.gaps.csv")
    done_file = csv <> ".done"
    done = if File.exists?(done_file), do: done_file |> File.read!() |> String.split(), else: []

    if done == [] do
      File.write!(csv, Enum.join(@cols, ",") <> "\n")
      File.write!(diff, "law,section_id,field,today_source,old,new\n")
      File.write!(gaps_csv, "law,section_id,gap\n")
    end

    today = LabelProjection.uk_today()
    todo = laws -- done

    Mix.shell().info("#{length(todo)} laws (#{length(done)} done); as at #{today}; report only")

    for {law, i} <- Enum.with_index(todo, 1) do
      %{periods: periods, gaps: gaps, rows: rows} = LabelTimeline.build(law, today)

      File.write!(gaps_csv, Enum.map(gaps, fn {sid, kind} -> "#{law},#{sid},#{kind}\n" end), [
        :append
      ])

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
        periods
        |> Enum.filter(
          &(Date.compare(&1.valid_from, today) == :lt and &1.territory == nil and
              &1.status not in ~w(repealed repealed_saved))
        )
        |> Enum.uniq_by(& &1.section_id)
        |> length(),
        Enum.count(gaps, &(elem(&1, 1) == :no_start)),
        Enum.count(gaps, &(elem(&1, 1) == :insertion_not_in_register)),
        Enum.count(gaps, &(elem(&1, 1) == :undated_change)),
        Enum.count(gaps, &(elem(&1, 1) == :markup_conflict)),
        Enum.count(gaps, &(elem(&1, 1) == :outstanding_effect)),
        Enum.count(gaps, &(elem(&1, 1) == :commenced_by_order)),
        Enum.count(gaps, &(elem(&1, 1) == :pending_change)),
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

  # the stored timeline as at today vs the fresh build's (nil: unknown)
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

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
