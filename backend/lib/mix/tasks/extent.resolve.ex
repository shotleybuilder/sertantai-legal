defmodule Mix.Tasks.Extent.Resolve do
  @moduledoc """
  Re-resolve `geo_extent` for UK laws with `ExtentResolver` (#162).

  Dry run by default: reports changes by (old → new, source), runs the
  type-code lint, and writes a CSV of every change. Nothing is written
  without `--apply`.

      mix extent.resolve                      # dry run, all UK laws
      mix extent.resolve --names UK_a,UK_b    # dry run, named laws
      mix extent.resolve --apply              # snapshot, then write

  With `--apply`, `id, name, geo_extent, geo_region, geo_extent_source` are
  first copied to `extent_backfill_snapshot_<YYYYMMDD>` (once per day). To
  roll back:

      UPDATE legal_register l SET geo_extent = s.geo_extent,
             geo_region = s.geo_region, geo_extent_source = s.geo_extent_source
      FROM extent_backfill_snapshot_<YYYYMMDD> s WHERE s.id = l.id;

  Report: `data/reports/extent/resolve-<timestamp>.csv`.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ExtentBackfill

  @shortdoc "Re-resolve geo_extent from DB-held sources (dry run by default)"

  @devolved ~w(ssi asp ssa nisr nia apni nisi wsi anaw asc mwa)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean, names: :string])
    Mix.Task.run("app.start")

    names = opts[:names] && String.split(opts[:names], ",", trim: true)
    now = DateTime.utc_now()
    plans = names |> ExtentBackfill.load_rows() |> Enum.map(&ExtentBackfill.plan/1)
    changes = Enum.filter(plans, & &1.change?)

    report(plans, changes)
    Mix.shell().info("\nChange report: #{write_csv(changes, now)}")

    if opts[:apply], do: apply!(plans, now), else: Mix.shell().info("\nDry run: nothing written.")
  end

  defp report(plans, changes) do
    Mix.shell().info("UK laws: #{length(plans)}; changes: #{length(changes)}\n")

    changes
    |> Enum.frequencies_by(fn %{row: r, resolution: res} ->
      {r.geo_extent || "nil", res.geo_extent || "nil", res.source || "unknown"}
    end)
    |> Enum.sort_by(fn {_k, n} -> -n end)
    |> Enum.take(25)
    |> Enum.each(fn {{old, new, source}, n} ->
      Mix.shell().info(
        "  #{String.pad_trailing(old, 6)} → #{String.pad_trailing(new, 6)} by #{source}: #{n}"
      )
    end)

    after_state = Enum.map(plans, &final_state/1)

    Mix.shell().info("\nResolved by source (after):")

    after_state
    |> Enum.frequencies_by(& &1.source)
    |> Enum.sort_by(fn {_k, n} -> -n end)
    |> Enum.each(fn {source, n} -> Mix.shell().info("  #{source || "unknown"}: #{n}") end)

    lint =
      Enum.filter(after_state, fn s ->
        s.type_code in @devolved and s.geo_extent in ["UK", "GB"]
      end)

    Mix.shell().info("\nLint: devolved type codes still UK/GB after: #{length(lint)}")

    Enum.each(Enum.take(lint, 10), fn s ->
      Mix.shell().info("  #{s.name} #{s.geo_extent} (#{s.source})")
    end)
  end

  defp final_state(%{row: r, resolution: res, change?: true}),
    do: %{name: r.name, type_code: r.type_code, geo_extent: res.geo_extent, source: res.source}

  defp final_state(%{row: r}),
    do: %{
      name: r.name,
      type_code: r.type_code,
      geo_extent: r.geo_extent,
      source: r.geo_extent_source
    }

  defp write_csv(changes, now) do
    dir = Path.join(["data", "reports", "extent"])
    File.mkdir_p!(dir)
    path = Path.join(dir, "resolve-#{Calendar.strftime(now, "%Y%m%dT%H%M")}.csv")

    lines =
      Enum.map(changes, fn %{row: r, resolution: res} ->
        Enum.join([r.name, r.type_code, r.geo_extent, res.geo_extent, res.source], ",")
      end)

    File.write!(path, [
      "name,type_code,old_geo_extent,new_geo_extent,source\n",
      Enum.join(lines, "\n"),
      "\n"
    ])

    path
  end

  defp apply!(plans, now) do
    snapshot = "extent_backfill_snapshot_" <> Calendar.strftime(now, "%Y%m%d")

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{snapshot} AS
    SELECT id, name, geo_extent, geo_region, geo_extent_source
    FROM legal_register WHERE country = 'uk'
    """)

    written = ExtentBackfill.apply!(plans)
    Mix.shell().info("\nSnapshot: #{snapshot}. Written: #{written}")
  end
end
