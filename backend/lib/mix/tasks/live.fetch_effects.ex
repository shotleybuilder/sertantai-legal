defmodule Mix.Tasks.Live.FetchEffects do
  @moduledoc """
  Fetch legislation.gov.uk changes feeds into the local cache
  (`data/cache/changes-feed/`) for `mix live.apply_effects`
  (`Scraper.LiveStatus.EffectsBackfill`). Resumable: cached laws are skipped.
  Read-only on the database.

      mix live.fetch_effects --batches        # list the batch plan (no fetching)
      mix live.fetch_effects --batch 1        # fetch batch 1 (1,000 laws, ~40 min)
      mix live.fetch_effects --names UK_a,UK_b

  Batches follow `EffectsBackfill.target_laws/0` priority order (Revoked,
  part-revoked, other laws with revocation rows, then extent-only; Making
  laws first within each group). Cached laws are skipped, so a batch can be
  re-run to resume it.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Cache legislation.gov.uk changes feeds for the live status backfill"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [names: :string, batch: :integer, batches: :boolean])

    Mix.Task.run("app.start")

    cond do
      opts[:batches] -> list_batches()
      opts[:batch] -> fetch(EffectsBackfill.batch(EffectsBackfill.target_laws(), opts[:batch]))
      opts[:names] -> fetch(String.split(opts[:names], ",", trim: true))
      true -> Mix.shell().error("Give --batches, --batch N or --names")
    end
  end

  defp list_batches do
    for b <- EffectsBackfill.batches(EffectsBackfill.target_laws()) do
      Mix.shell().info(
        "  batch #{b.batch}: #{b.laws} laws (#{Enum.join(b.groups, ", ")}), cached #{b.cached}"
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
