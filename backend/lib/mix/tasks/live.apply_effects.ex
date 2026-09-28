defmodule Mix.Tasks.Live.ApplyEffects do
  @moduledoc """
  Apply cached changes-feed effects (`mix live.fetch_effects`) to existing
  laws (`Scraper.LiveStatus.EffectsBackfill`): extents on stored revocation
  rows, and `geo_extent` re-resolved (source `affected_effects`) where it had
  no source or only the type floor.

      mix live.apply_effects --batch 0            # dry run for one fetch batch
      mix live.apply_effects --batch 0 --apply    # snapshot to effects_backfill_snapshot_<YYYYMMDD>[_<batch>], then write
      mix live.apply_effects                      # every cached law

  Then run `mix live.recompute`.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Apply cached changes-feed effects to revocation rows and extents (dry run by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean, batch: :string])
    Mix.Task.run("app.start")

    plan = EffectsBackfill.plan() |> only_batch(opts[:batch])
    extent = Enum.filter(plan, &EffectsBackfill.extent_change?/1)

    Mix.shell().info("Cached laws: #{length(plan)}")

    Mix.shell().info(
      "Revocation rows matched: #{sum(plan, :matched)}/#{sum(plan, :revocation_rows)}"
    )

    Mix.shell().info("Laws with revocation rows updated: #{Enum.count(plan, & &1.stats)}")
    Mix.shell().info("Extent changes: #{length(extent)}")

    for {{from, to}, n} <-
          extent
          |> Enum.frequencies_by(&{&1.old_extent || "∅", &1.new_extent})
          |> Enum.sort_by(&(-elem(&1, 1)))
          |> Enum.take(15),
        do: Mix.shell().info("  #{from} → #{to}: #{n}")

    path = write_csv(extent)
    Mix.shell().info("\nExtent report: #{path}")

    if opts[:apply] do
      table = snapshot_name("effects_backfill_snapshot", opts[:batch])

      counts =
        EffectsBackfill.apply!(
          Enum.filter(plan, &(&1.stats || EffectsBackfill.extent_change?(&1))),
          table
        )

      Mix.shell().info("\nApplied (snapshot #{table}): #{inspect(counts)}")
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end

  defp only_batch(plan, nil), do: plan

  defp only_batch(plan, label) do
    case EffectsBackfill.batch(EffectsBackfill.target_laws(), label) do
      nil ->
        Mix.raise("No batch #{label}; see mix live.fetch_effects --batches")

      names ->
        set = MapSet.new(names)
        Enum.filter(plan, &MapSet.member?(set, &1.name))
    end
  end

  defp snapshot_name(prefix, batch) do
    suffix = if batch, do: "_b" <> String.replace(batch, ".", "_"), else: ""
    prefix <> "_" <> Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M") <> suffix
  end

  defp sum(plan, key), do: plan |> Enum.map(&(Map.get(&1, key) || 0)) |> Enum.sum()

  defp write_csv(extent) do
    dir = Path.join(["data", "reports", "live-status"])
    File.mkdir_p!(dir)

    path =
      Path.join(
        dir,
        "effects-extent-#{Calendar.strftime(DateTime.utc_now(), "%Y%m%dT%H%M%S")}.csv"
      )

    lines =
      ["name,old_extent,old_source,new_extent,new_source"] ++
        Enum.map(
          extent,
          &"#{&1.name},#{&1.old_extent},#{&1.old_source},#{&1.new_extent},#{&1.new_source}"
        )

    File.write!(path, Enum.join(lines, "\n") <> "\n")
    path
  end
end
