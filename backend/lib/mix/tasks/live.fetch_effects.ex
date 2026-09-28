defmodule Mix.Tasks.Live.FetchEffects do
  @moduledoc """
  Fetch legislation.gov.uk changes feeds into the local cache
  (`data/cache/changes-feed/`) for `mix live.apply_effects`
  (`Scraper.LiveStatus.EffectsBackfill`). Resumable: cached laws are skipped.
  Read-only on the database.

      mix live.fetch_effects                  # every target law
      mix live.fetch_effects --names UK_a,UK_b
      mix live.fetch_effects --limit 100
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Cache legislation.gov.uk changes feeds for the live status backfill"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [names: :string, limit: :integer])
    Mix.Task.run("app.start")

    names =
      case opts[:names] do
        nil -> EffectsBackfill.target_laws()
        s -> String.split(s, ",", trim: true)
      end

    names = if opts[:limit], do: Enum.take(names, opts[:limit]), else: names
    Mix.shell().info("Laws: #{length(names)}")

    counts =
      EffectsBackfill.fetch_all(names,
        on_progress: fn {i, n, name} ->
          if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{n} #{name}")
        end
      )

    Mix.shell().info(
      "Done: #{inspect(counts)} (errors: #{EffectsBackfill.cache_dir()}/errors.log)"
    )
  end
end
