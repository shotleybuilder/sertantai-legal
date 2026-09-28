defmodule Mix.Tasks.Live.Application do
  @moduledoc """
  Resolve `needs_application` laws for a fetch batch: laws whose live status
  would be territorial on extent alone (`LiveStatus` `application_unknown`),
  so their own application clause must be read first.

      mix live.application --batch 0            # list them (read-only)
      mix live.application --batch 0 --parse    # LAT-parse them, then discard not-Making LAT
      mix live.application --names A,B --parse  # re-read named laws (e.g. after a rule change)

  With `--parse`, each law goes through the normal LAT pipeline
  (`LatReparse`, snapshot `lat_reparse_live_app_<batch>`): the LAT persist
  refreshes extent and `application_clause` and re-decides live status
  (`ExtentBackfill.refresh/1`). LAT parsed only for this — the law held none
  and is not Making — is then discarded with an archive
  (`LatArchive.discard(law, "application_clause")`), per the lean-LAT policy;
  the application stays on the law.

  Run after `mix live.apply_effects --batch N --apply`, so live status is
  re-decided on the batch's effect data.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatArchive
  alias SertantaiLegal.Scraper.LatReparse
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill
  alias SertantaiLegal.Scraper.LiveStatus.Recompute

  @shortdoc "LAT-parse a batch's needs_application laws to read their application clause"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [batch: :string, names: :string, parse: :boolean])

    Mix.Task.run("app.start")

    if opts[:names] do
      names = String.split(opts[:names], ",", trim: true)
      Mix.shell().info("Re-reading #{length(names)} named laws")
      if opts[:parse], do: parse(names, "names"), else: :ok
    else
      run_batch(opts)
    end
  end

  defp run_batch(opts) do
    label = opts[:batch] || Mix.raise("Give --batch N")

    names =
      EffectsBackfill.batch(EffectsBackfill.target_laws(), label) ||
        Mix.raise("No batch #{label}; see mix live.fetch_effects --batches")

    # Listing previews the batch's cached effect data; --parse runs on stored
    # data, so apply the effects first (mix live.apply_effects --batch N --apply).
    overrides = if opts[:parse], do: %{}, else: effect_overrides(names)

    laws =
      [names: names, overrides: overrides]
      |> Recompute.plan()
      |> Enum.filter(&(&1.action == :needs_application))

    Mix.shell().info("Batch #{label}: #{length(laws)} laws need their application clause")

    for c <- laws,
        do: Mix.shell().info("  #{c.name} #{c.title} — #{c.evidence["law_regions_basis"]}")

    if opts[:parse] && laws != [], do: parse(Enum.map(laws, & &1.name), label)
  end

  defp effect_overrides(names) do
    set = MapSet.new(names)

    for c <- EffectsBackfill.plan(),
        MapSet.member?(set, c.name),
        into: %{},
        do:
          {c.name,
           %{stats: c.stats, geo_extent: if(EffectsBackfill.extent_change?(c), do: c.new_extent)}}
  end

  defp parse(names, label) do
    before = lat_state(names)
    tag = "live_app_" <> String.replace(label, ".", "_")

    report = LatReparse.run(names, snapshot: "lat_reparse_" <> tag)
    Mix.shell().info("\nLAT parse: #{inspect(report.status)}")

    discard =
      for name <- names,
          {held_before, making} = Map.fetch!(before, name),
          not held_before and not making,
          do: name

    for name <- discard do
      case LatArchive.discard(name, "application_clause", source: "live_application") do
        {:ok, r} -> Mix.shell().info("  discarded #{name}: #{r.deleted} rows (#{r.archive_ref})")
        {:error, e} -> Mix.shell().error("  #{name}: #{e}")
      end
    end

    after_state = Recompute.plan(names: names)

    for c <- after_state do
      Mix.shell().info(
        "  #{c.name}: #{c.new_live} — #{c.description} (#{c.evidence && c.evidence["law_regions_basis"]})"
      )
    end
  end

  # name => {held LAT before, is_making}
  defp lat_state(names) do
    %{rows: rows} =
      Repo.query!(
        "SELECT name, coalesce(lat_count, 0) > 0, coalesce(is_making, false) FROM legal_register WHERE country = 'uk' AND name = ANY($1)",
        [names]
      )

    Map.new(rows, fn [n, held, making] -> {n, {held, making}} end)
  end
end
