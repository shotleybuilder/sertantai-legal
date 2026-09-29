defmodule Mix.Tasks.Lat.Scope do
  @moduledoc """
  Scoped LAT (#166, `Scraper.LatScope`).

      # A law's relevant part (never narrows; logged in the scope's history)
      mix lat.scope --law UK_ukpga_2006_46 --add part/15/chapter/5 --purpose relevance \\
        --reason "QQ: environmental reporting" [--create] [--parse]

      # Enabling-extent scopes for a fetch batch (after `mix live.enabling --batch N`):
      # non-Making parent Acts without LAT get LAT of just the cited sections
      mix lat.scope --enabling --batch 1a            # dry run
      mix lat.scope --enabling --batch 1a --apply    # set scopes and parse

  `--create` scopes a law that holds no LAT (an unscoped law with LAT is
  whole and is never narrowed here). Parsing goes through `LatStagedParser`,
  which fetches only the scoped fragments.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatScope
  alias SertantaiLegal.Scraper.LatStagedParser
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  @shortdoc "Set a law's scoped LAT fragments (#166)"

  @enabling_cache Path.join(["data", "cache", "enabling"])

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          add: :string,
          purpose: :string,
          reason: :string,
          create: :boolean,
          parse: :boolean,
          enabling: :boolean,
          batch: :string,
          apply: :boolean
        ]
      )

    Mix.Task.run("app.start")

    if opts[:enabling], do: enabling(opts), else: one(opts)
  end

  defp one(opts) do
    law = opts[:law] || Mix.raise("Give --law")
    fragments = String.split(opts[:add] || Mix.raise("Give --add"), ",", trim: true)

    result =
      LatScope.set!(law,
        fragments: fragments,
        purpose: opts[:purpose] || "relevance",
        reason: opts[:reason],
        set_by: "mix lat.scope",
        create: opts[:create] || false
      )

    Mix.shell().info("#{law}: #{inspect(result)}")
    if opts[:parse] && is_map(result), do: parse(law)
  end

  defp enabling(opts) do
    label = opts[:batch] || Mix.raise("Give --batch N")

    names =
      EffectsBackfill.batch(EffectsBackfill.target_laws(), label) ||
        Mix.raise("No batch #{label}")

    wanted =
      for name <- names,
          {:ok, json} <- [File.read(Path.join(@enabling_cache, name <> ".json"))],
          p <- Jason.decode!(json),
          reduce: %{} do
        acc ->
          Map.update(
            acc,
            p["law"],
            LatScope.fragments_for(p),
            &Enum.uniq(&1 ++ LatScope.fragments_for(p))
          )
      end

    %{rows: rows} =
      Repo.query!(
        "SELECT name, coalesce(is_making, false), coalesce(lat_count, 0), lat_scope FROM legal_register WHERE country = 'uk' AND name = ANY($1)",
        [Map.keys(wanted)]
      )

    targets =
      for [name, making, lat, scope] <- rows,
          not making,
          lat == 0 or scope != nil,
          do: {name, Map.fetch!(wanted, name)}

    Mix.shell().info(
      "Batch #{label}: #{length(targets)} non-Making parents to scope (enabling extent)"
    )

    for {name, fragments} <- targets,
        do: Mix.shell().info("  #{name}: #{Enum.join(fragments, ", ")}")

    if opts[:apply] do
      for {name, fragments} <- targets do
        case LatScope.set!(name,
               fragments: fragments,
               purpose: "enabling_extent",
               reason: "enabling provisions of batch #{label} SIs",
               set_by: "mix lat.scope --enabling",
               create: true
             ) do
          %{} -> parse(name)
          {:unchanged, _} -> :ok
          other -> Mix.shell().info("  #{name}: #{inspect(other)}")
        end
      end
    else
      Mix.shell().info("\nDry run: nothing written.")
    end
  end

  defp parse(law) do
    case LatStagedParser.parse(law) do
      {:ok, %{has_errors: false, lat: lat}} ->
        Mix.shell().info("  parsed #{law}: #{lat.inserted} rows")

      {:ok, r} ->
        Mix.shell().error("  #{law}: #{r[:error]}")

      {:error, e} ->
        Mix.shell().error("  #{law}: #{e}")
    end
  end
end
