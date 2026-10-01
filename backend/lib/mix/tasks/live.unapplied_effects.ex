defmodule Mix.Tasks.Live.UnappliedEffects do
  @moduledoc """
  Attach legislation.gov.uk in-force data (#168) to the unapplied effects
  stored on laws with LAT (`🔻_affected_by_stats_per_law` details whose
  `applied` is "Not yet…"), via `LatEffects.enrich/2`. The manifest's
  `effects_unapplied` then carries `in_force_date`, `prospective`, `saved`
  and ref-based `section_id`s.

      mix live.unapplied_effects --fetch            # cache the feeds (resumable; read-only on the DB)
      mix live.unapplied_effects                    # dry run: matched / unapplied per law, totals
      mix live.unapplied_effects --apply            # snapshot the column to unapplied_effects_snapshot_<stamp>, then write
      mix live.unapplied_effects --law UK_a,UK_b    # limit to named laws

  Feeds are cached in `data/cache/changes-feed-inforce/` (separate from the
  live status cache, whose entries predate the in-force fields).
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatEffects
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Attach in-force data to unapplied effects (dry run by default)"
  @cache_dir Path.join(["data", "cache", "changes-feed-inforce"])
  @column ~s("🔻_affected_by_stats_per_law")

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [law: :string, fetch: :boolean, apply: :boolean])

    Mix.Task.run("app.start")

    laws = laws(opts[:law])
    Mix.shell().info("Laws with unapplied effects: #{length(laws)}")

    if opts[:fetch] do
      counts =
        EffectsBackfill.fetch_all(Enum.map(laws, &hd/1),
          dir: @cache_dir,
          on_progress: fn {i, n, name} ->
            if rem(i, 25) == 0 or i == n, do: Mix.shell().info("  #{i}/#{n} #{name}")
          end
        )

      Mix.shell().info(
        "Fetched #{counts.fetched}, cached #{counts.cached}, failed #{counts.failed}"
      )
    else
      plan = plan(laws)
      report(plan)
      if opts[:apply], do: apply!(plan)
    end
  end

  defp laws(nil) do
    Repo.query!(
      "SELECT name, #{@column} FROM legal_register WHERE lat_count > 0 AND #{@column}::text LIKE '%Not yet%' ORDER BY name",
      [],
      timeout: :infinity
    ).rows
  end

  defp laws(list) do
    Repo.query!(
      "SELECT name, #{@column} FROM legal_register WHERE name = ANY($1) ORDER BY name",
      [String.split(list, ",", trim: true)]
    ).rows
  end

  defp plan(laws) do
    for [name, stats] <- laws do
      case EffectsBackfill.load(name, dir: @cache_dir) do
        nil ->
          %{name: name, cached?: false, matched: 0, unapplied: 0, stats: stats, new: stats}

        effects ->
          {new, matched, unapplied} = LatEffects.enrich(stats, effects)

          %{
            name: name,
            cached?: true,
            matched: matched,
            unapplied: unapplied,
            stats: stats,
            new: new
          }
      end
    end
  end

  defp report(plan) do
    cached = Enum.filter(plan, & &1.cached?)
    matched = Enum.sum(Enum.map(cached, & &1.matched))
    unapplied = Enum.sum(Enum.map(cached, & &1.unapplied))
    changed = Enum.count(cached, &(&1.new != &1.stats))

    Mix.shell().info(
      "Cached #{length(cached)}/#{length(plan)} laws; unapplied details #{unapplied}, matched to a feed effect #{matched} " <>
        "(#{if unapplied > 0, do: round(100 * matched / unapplied), else: 0}%); laws to update #{changed}"
    )
  end

  defp apply!(plan) do
    changes = for p <- plan, p.cached?, p.new != p.stats, do: p
    table = "unapplied_effects_snapshot_" <> Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M")

    Repo.transaction(
      fn ->
        Repo.query!(
          "CREATE TABLE #{table} AS SELECT name, #{@column} AS stats FROM legal_register WHERE name = ANY($1)",
          [Enum.map(changes, & &1.name)]
        )

        for p <- changes,
            do:
              Repo.query!("UPDATE legal_register SET #{@column} = $2 WHERE name = $1", [
                p.name,
                p.new
              ])
      end,
      timeout: :infinity
    )

    Mix.shell().info("\nApplied: #{length(changes)} laws (snapshot #{table})")
  end
end
