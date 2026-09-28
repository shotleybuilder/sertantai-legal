defmodule Mix.Tasks.Live.Recompute do
  @moduledoc """
  Recompute `live`, `live_description` and `live_evidence` for every UK law
  from its stored revocation rows (`Scraper.LiveStatus.Recompute`).

  Dry run by default: prints the transitions and writes a CSV of every law
  whose `live` would change or that conflicts with the new rule.

      mix live.recompute --batch 0  # dry run, laws of one fetch batch only
      mix live.recompute --batch 0 --with-effects   # preview with the batch's cached effects applied (in memory)
      mix live.recompute            # dry run
      mix live.recompute --apply    # snapshot to live_status_snapshot_<YYYYMMDD>, then write
      mix live.recompute --trust-revoker-extent   # also trust UK-level revokers' recorded extent

  Report: `data/reports/live-status/recompute-<timestamp>.csv`.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LiveStatus.Recompute

  @shortdoc "Recompute live status from stored revocation rows (dry run by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          apply: :boolean,
          trust_revoker_extent: :boolean,
          batch: :string,
          with_effects: :boolean
        ]
      )

    Mix.Task.run("app.start")

    if opts[:with_effects] && opts[:apply],
      do: Mix.raise("--with-effects is a preview: run mix live.apply_effects --apply first")

    plan =
      Recompute.plan(
        trust_revoker_extent: opts[:trust_revoker_extent] || false,
        overrides: if(opts[:with_effects], do: effect_overrides(), else: %{})
      )
      |> only_batch(opts[:batch])

    report(plan)
    path = write_csv(plan)
    Mix.shell().info("\nReport: #{path}")

    if opts[:apply] do
      suffix = if opts[:batch], do: "_b" <> String.replace(opts[:batch], ".", "_"), else: ""
      table = "live_status_snapshot_" <> Calendar.strftime(Date.utc_today(), "%Y%m%d") <> suffix
      counts = Recompute.apply!(plan, table)
      Mix.shell().info("\nApplied (snapshot #{table}): #{inspect(counts)}")
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end

  defp effect_overrides do
    alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

    Map.new(EffectsBackfill.plan(), fn c ->
      {c.name,
       %{
         stats: c.stats,
         geo_extent: if(EffectsBackfill.extent_change?(c), do: c.new_extent)
       }}
    end)
  end

  defp only_batch(plan, nil), do: plan

  defp only_batch(plan, label) do
    alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

    case EffectsBackfill.batch(EffectsBackfill.target_laws(), label) do
      nil ->
        Mix.raise("No batch #{label}; see mix live.fetch_effects --batches")

      names ->
        set = MapSet.new(names)
        Enum.filter(plan, &MapSet.member?(set, &1.name))
    end
  end

  defp report(plan) do
    Mix.shell().info("UK laws: #{length(plan)}")

    for {action, n} <- Enum.frequencies_by(plan, & &1.action) |> Enum.sort(),
        do: Mix.shell().info("  #{action}: #{n}")

    changes = Enum.filter(plan, &(&1.action == :change))
    Mix.shell().info("\nlive transitions:")

    for {{from, to, kind}, n} <-
          changes
          |> Enum.frequencies_by(&{&1.live, &1.new_live, &1.kind})
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: Mix.shell().info("  #{from} → #{to} (#{kind}): #{n}")

    Mix.shell().info(
      "\nRevoked with an extent gap (UK-level revoker's recorded extent, for review): #{Enum.count(plan, &gap?/1)}"
    )

    making = Enum.count(changes, &(&1.is_making and &1.live =~ "Revoked"))

    Mix.shell().info(
      "\nRevoked + Making laws leaving Revoked (re-enter the Making funnel): #{making}"
    )
  end

  defp write_csv(plan) do
    dir = Path.join(["data", "reports", "live-status"])
    File.mkdir_p!(dir)
    stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%dT%H%M%S")
    path = Path.join(dir, "recompute-#{stamp}.csv")

    header =
      ~w(name action live old_rule_live new_live kind is_making description extent_gap revokers title)

    rows =
      plan
      |> Enum.filter(&(&1.action in [:change, :conflict] or gap?(&1)))
      |> Enum.map(fn c ->
        [
          c.name,
          if(c.action in [:change, :conflict], do: c.action, else: :review_extent_gap),
          c.live,
          c.old_rule_live,
          c.new_live,
          c.kind,
          c.is_making,
          c.description,
          Enum.join((c.evidence || %{})["extent_gap"] || [], "+"),
          revokers(c.evidence),
          c.title
        ]
      end)

    File.write!(path, Enum.map_join([header | rows], "\n", &csv_line/1) <> "\n")
    path
  end

  defp gap?(%{evidence: %{"extent_gap" => [_ | _]}}), do: true
  defp gap?(_), do: false

  defp revokers(%{"revokers" => rs}),
    do:
      Enum.map_join(
        rs,
        "; ",
        &"#{&1["by"]} [#{&1["basis"]}: #{Enum.join(&1["regions"] || [], "+")}]"
      )

  defp revokers(_), do: ""

  defp csv_line(fields) do
    Enum.map_join(fields, ",", fn f ->
      s = to_string(f)

      if String.contains?(s, [",", "\"", "\n"]),
        do: "\"" <> String.replace(s, "\"", "\"\"") <> "\"",
        else: s
    end)
  end
end
