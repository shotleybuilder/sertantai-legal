defmodule Mix.Tasks.Live.Enabling do
  @moduledoc """
  Enabling-provision extents for a fetch batch's SIs whose extent has no
  proper source (legacy value or type floor).

      mix live.enabling --batch 0            # fetch/cache introductions; report parents (read-only)
      mix live.enabling --batch 0 --apply    # store enabling_provisions, then re-resolve extents

  Each SI's introduction (the page the LRT enacted_by stage reads; never the
  body) is parsed by `EnactedBy.EnablingProvisions` and cached in
  `data/cache/enabling/<law>.json`. The report lists the parent Acts and
  whether they hold LAT: their section extents come from LAT, so re-parse
  them first (`mix lat.reparse --laws …`) to pick up the LAT parser's extent
  inheritance fix. With `--apply`, `enabling_provisions` is written and each
  SI's extent re-resolved (`ExtentBackfill.refresh/1`, which also re-decides
  its live status).
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache
  alias SertantaiLegal.Scraper.ExtentBackfill
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Enabling-provision extents for a batch's unsourced SIs"

  @acts ~w(ukpga asp anaw asc nia apni mwa ukla ukcm eur eudr eudn)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [batch: :string, apply: :boolean])
    Mix.Task.run("app.start")
    label = opts[:batch] || Mix.raise("Give --batch N")

    names =
      EffectsBackfill.batch(EffectsBackfill.target_laws(), label) ||
        Mix.raise("No batch #{label}; see mix live.fetch_effects --batches")

    sis = weak_extent_sis(names)
    Mix.shell().info("Batch #{label}: #{length(sis)} SIs with no proper extent source")

    provisions = Map.new(sis, &{&1, EnablingCache.get(&1)})
    with_provisions = Enum.filter(provisions, fn {_, p} -> p != [] end)
    Mix.shell().info("  with enabling provisions parsed: #{length(with_provisions)}")

    parents =
      with_provisions
      |> Enum.flat_map(fn {_, ps} -> Enum.map(ps, & &1["law"]) end)
      |> Enum.frequencies()

    report_parents(parents)

    if opts[:apply] do
      for {name, ps} <- with_provisions do
        Repo.query!(
          "UPDATE legal_register SET enabling_provisions = $2 WHERE country = 'uk' AND name = $1",
          [name, %{"provisions" => ps}]
        )

        ExtentBackfill.refresh(name)
      end

      Mix.shell().info(
        "\nApplied: enabling_provisions on #{length(with_provisions)} SIs; extents re-resolved"
      )
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end

  # SIs whose extent is unsourced or rests on a weaker source than enabling provisions
  defp weak_extent_sis(names) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT name FROM legal_register
        WHERE country = 'uk' AND name = ANY($1) AND NOT (type_code = ANY($2))
          AND coalesce(geo_extent_source, '') IN ('', 'type_code', 'affected_effects')
        ORDER BY name
        """,
        [names, @acts]
      )

    List.flatten(rows)
  end

  defp report_parents(parents) do
    %{rows: rows} =
      Repo.query!(
        "SELECT name, coalesce(lat_count, 0), latest_lat_updated_at::date FROM legal_register WHERE country = 'uk' AND name = ANY($1)",
        [Map.keys(parents)]
      )

    held = Map.new(rows, fn [n, c, d] -> {n, {c, d}} end)
    Mix.shell().info("\nParent laws (#{map_size(parents)}): SIs citing · LAT rows · LAT updated")

    for {p, n} <- Enum.sort_by(parents, &(-elem(&1, 1))) do
      {c, d} = Map.get(held, p, {0, nil})
      Mix.shell().info("  #{p}: #{n} · #{c} · #{d || "-"}")
    end
  end
end
