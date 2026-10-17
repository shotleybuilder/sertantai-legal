defmodule Mix.Tasks.Lat.WavePreview do
  @moduledoc """
  Dry run of a re-parse wave (lat-refactor LR-25): for each law, the real
  parse path — `LatStagedParser.parse/2` from the CLML store, the LR-25 hook
  (register + timeline), every write and lat_event — runs inside a
  transaction that is always rolled back, so nothing persists. Before /
  after are compared by `WavePreview`: labels as at today (the timeline) and
  the parse-time columns they are built from. Zenoh is off in mix tasks, so
  nothing is published.

      mix lat.wave_preview --laws A,B --tag lr25_dry
      mix lat.wave_preview --all --tag lr25_dry
      mix lat.wave_preview --all --relabel --tag lr33_dry   # the label path only (`LabelRefresh.run/1`, as `mix lat.relabel`)
      mix lat.wave_preview --all --workers 1 --tag x       # one law at a time (default: 5 at once, LR-31)

  Rows in the reports are in finishing order, not input order.

  Written as it goes (resumable, `<tag>.csv.done`) under
  `data/reports/lat-refactor/`:

  - `<tag>.csv`: per law — rows before / after, the parse's cause, the
    hook's result, timeline periods before / after, provisions unknown
    today before / after, label diffs, gaps by kind after, and the rows
    whose effect_ids / excluded_extent / territory_provenance change
  - `<tag>.diff.csv`: each label that changes as at today (law, section_id,
    field, old, new, class)
  - `<tag>.classes.csv`: diffs counted by class (written at the end)

  The apply is `mix lat.reparse --store only`, or `mix lat.relabel` for a
  `--relabel` preview (Jason's approval, NAS backup first); this task never
  writes.
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Scraper.{
    LabelProjection,
    LabelRefresh,
    LabelTimeline,
    LatStagedParser,
    LawRunner,
    WavePreview
  }

  @shortdoc "Dry run of a re-parse wave: real path, rolled back (never writes)"

  @gaps ~w(no_start insertion_not_in_register undated_change markup_conflict outstanding_effect commenced_by_order pending_change)a
  @cols ~w(law rows_before rows_after cause labels periods_before periods_after unknown_before
           unknown_after label_diffs) ++
          Enum.map(@gaps, &"gap_#{&1}") ++
          ~w(effect_ids_rows excluded_extent_rows territory_provenance_rows rows_added rows_removed error)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, tag: :string, relabel: :boolean, workers: :integer]
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
    tag = opts[:tag] || "wave_preview"
    csv = Path.join(dir, "#{tag}.csv")
    diff_csv = Path.join(dir, "#{tag}.diff.csv")
    done_file = csv <> ".done"
    done = if File.exists?(done_file), do: done_file |> File.read!() |> String.split(), else: []

    if done == [] do
      File.write!(csv, Enum.join(@cols, ",") <> "\n")
      File.write!(diff_csv, "law,section_id,field,old,new,class\n")
    end

    today = LabelProjection.uk_today()
    backlog = Path.join(System.tmp_dir!(), "lat-wave-preview-backlog")
    todo = laws -- done
    Mix.shell().info("#{length(todo)} laws (#{length(done)} done); as at #{today}; never writes")

    total = length(todo)
    counter = :counters.new(1, [])

    LawRunner.run(
      todo,
      &preview(&1, today, backlog, opts[:relabel] == true),
      fn
        law, {:error, reason} ->
          Mix.shell().error("  #{law}: #{inspect(reason)}")

          File.write!(
            csv,
            Enum.join(
              [law | List.duplicate("", length(@cols) - 2)] ++ [csv_safe(inspect(reason))],
              ","
            ) <> "\n",
            [:append]
          )

        law, {line, diffs} ->
          File.write!(
            diff_csv,
            Enum.map(diffs, fn {sid, field, old, new} = d ->
              Enum.join([law, sid, field, old, new, WavePreview.class(d)], ",") <> "\n"
            end),
            [:append]
          )

          File.write!(csv, Enum.join(line, ",") <> "\n", [:append])
          File.write!(done_file, law <> "\n", [:append])
          :counters.add(counter, 1, 1)
          i = :counters.get(counter, 1)
          if rem(i, 25) == 0, do: Mix.shell().info("  [#{i}/#{total}]")
      end,
      workers: opts[:workers] || LawRunner.default_workers()
    )

    write_classes(diff_csv, Path.join(dir, "#{tag}.classes.csv"))
    Mix.shell().info("report #{csv}")
  end

  defp preview(law, today, backlog, relabel?) do
    before = snapshot(law)

    result =
      try do
        Repo.transaction(
          fn ->
            {:ok, parsed} = run_path(law, backlog, relabel?)
            after_ = snapshot(law)

            gaps =
              if parsed[:labels] == :ok,
                do: LabelTimeline.build(law, today).gaps |> Enum.frequencies_by(&elem(&1, 1)),
                else: %{}

            Repo.rollback({:preview, parsed, after_, gaps})
          end,
          timeout: :infinity
        )
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      end

    case result do
      {:error, {:preview, parsed, after_, gaps}} ->
        diffs = WavePreview.label_diffs(before.labels, after_.labels)
        drift = WavePreview.column_drift(before.columns, after_.columns)

        {[
           law,
           map_size(before.columns),
           map_size(after_.columns),
           parsed[:cause],
           labels(parsed[:labels]),
           before.periods,
           after_.periods,
           map_size(before.columns) - map_size(before.labels),
           map_size(after_.columns) - map_size(after_.labels),
           length(diffs)
         ] ++
           Enum.map(@gaps, &Map.get(gaps, &1, 0)) ++
           [
             drift.effect_ids,
             drift.excluded_extent,
             drift.territory_provenance,
             drift.rows_added,
             drift.rows_removed,
             parsed[:error] |> to_string() |> csv_safe()
           ], diffs}

      {:error, reason} ->
        Mix.shell().error("  #{law}: #{inspect(reason)}")

        {[law, map_size(before.columns)] ++
           List.duplicate("", length(@cols) - 3) ++ [csv_safe(inspect(reason))], []}
    end
  end

  # the real path: the parse (with its LR-25 hook), or the label path alone
  defp run_path(law, _backlog, true),
    do: {:ok, %{cause: "relabel", labels: LabelRefresh.run(law)}}

  defp run_path(law, backlog, false),
    do: LatStagedParser.parse(law, store: :only, pdf_backlog_dir: backlog)

  # the law's labels as at today and its parse-time columns, by section_id
  defp snapshot(law) do
    %{rows: labels} =
      Repo.query!(
        "SELECT section_id, status, in_force_from, changed_by, territory FROM lat_labels_today WHERE law_name = $1",
        [law]
      )

    %{rows: cols} =
      Repo.query!(
        "SELECT section_id, effect_ids, excluded_extent, territory_provenance FROM legal_articles WHERE law_name = $1",
        [law]
      )

    %{rows: [[periods]]} =
      Repo.query!("SELECT count(*) FROM lat_label_timeline WHERE law_name = $1", [law])

    %{
      labels:
        Map.new(labels, fn [sid, st, from, by, t] ->
          {sid, %{status: st, effective_from: from, changed_by: by, territory: t}}
        end),
      columns:
        Map.new(cols, fn [sid, ids, ex, tp] ->
          {sid, %{effect_ids: ids, excluded_extent: ex, territory_provenance: tp}}
        end),
      periods: periods
    }
  end

  defp labels(:ok), do: "ok"
  defp labels(:skipped), do: "skipped"
  defp labels({:error, reason}), do: csv_safe("error #{inspect(reason)}")
  defp labels(other), do: csv_safe(inspect(other))

  defp csv_safe(s), do: s |> String.replace(~r/[,\n"]/, " ") |> String.slice(0, 200)

  defp write_classes(diff_csv, out) do
    counts =
      diff_csv
      |> File.stream!()
      |> Stream.drop(1)
      |> Enum.frequencies_by(fn line ->
        line |> String.trim() |> String.split(",") |> List.last()
      end)
      |> Enum.sort_by(fn {_, n} -> -n end)

    File.write!(out, ["class,count\n" | Enum.map(counts, fn {c, n} -> "#{c},#{n}\n" end)])
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1", [],
        timeout: :infinity
      )

    List.flatten(rows)
  end
end
