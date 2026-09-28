defmodule Mix.Tasks.Live.FetchEffects do
  @moduledoc """
  Fetch legislation.gov.uk changes feeds into the local cache
  (`data/cache/changes-feed/`) for `mix live.apply_effects`
  (`Scraper.LiveStatus.EffectsBackfill`). Resumable: cached laws are skipped.
  Read-only on the database.

      mix live.fetch_effects --batches        # list the batch plan (no fetching)
      mix live.fetch_effects --batch 0        # Tier 0: QQ's register
      mix live.fetch_effects --batch 1a       # Tier 1 cluster (OH&S + FIRE)
      mix live.fetch_effects --batch 2.01     # Tier 2 with a Family, first 1,000
      mix live.fetch_effects --batch 2n.01    # Tier 2 without a Family (last)
      mix live.fetch_effects --names UK_a,UK_b

  Meta-batched by readiness tier (`Legal.ReadinessTiers`); ≤ 1,000 laws
  (~40 min) per batch. Cached laws are skipped, so a batch can be re-run to
  resume it.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Cache legislation.gov.uk changes feeds for the live status backfill"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [names: :string, batch: :string, batches: :boolean])

    Mix.Task.run("app.start")

    cond do
      opts[:batches] -> list_batches()
      opts[:batch] -> fetch_batch(opts[:batch])
      opts[:names] -> fetch(String.split(opts[:names], ",", trim: true))
      true -> Mix.shell().error("Give --batches, --batch N or --names")
    end
  end

  defp fetch_batch(label) do
    case EffectsBackfill.batch(EffectsBackfill.target_laws(), label) do
      nil -> Mix.shell().error("No batch #{label}; see --batches")
      names -> fetch(names)
    end
  end

  defp list_batches do
    for b <- EffectsBackfill.batches(EffectsBackfill.target_laws()) do
      Mix.shell().info(
        "  #{String.pad_trailing(b.batch, 5)} #{b.laws} laws (#{Enum.join(b.groups, ", ")}), cached #{b.cached}"
      )
    end
  end

  defp fetch(names) do
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
